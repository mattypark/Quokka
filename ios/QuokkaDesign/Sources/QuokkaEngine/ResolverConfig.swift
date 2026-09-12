import Foundation

/// Which rungs are live, and how rung 2 resolves each platform.
///
/// **This is fetched, not compiled in, and that is the load-bearing decision.**
///
/// Instagram and TikTok change the shape of their page payloads without notice. A parser built
/// into the binary means every one of those changes is an App Store update: three days of
/// review for a regex. Fetching the patterns turns that into a JSON edit that is live in
/// minutes -- and turns "Apple objected to rung 2" from a resubmission into a flag flip.
///
/// The same mechanism is the kill switch. If a resolver starts misbehaving, if a platform
/// sends a letter, or if the hosted provider has to be cut off, it is one field.
public struct ResolverConfig: Codable, Sendable, Equatable {
    /// Bumped by the worker whenever the rules change. Logged, so a misbehaving device can be
    /// matched to the config it was actually running rather than the one currently served.
    public var version: Int
    /// Rungs explicitly switched on. Absent means off -- see `failClosed`.
    public var enabledRungs: Set<TranscriptRung>
    /// Rung 2's per-platform extraction rules.
    public var rules: [ResolverRule]
    /// When this device last got a config. Nil for the built-in fallback.
    public var fetchedAt: Date?

    public init(
        version: Int,
        enabledRungs: Set<TranscriptRung>,
        rules: [ResolverRule] = [],
        fetchedAt: Date? = nil
    ) {
        self.version = version
        self.enabledRungs = enabledRungs
        self.rules = rules
        self.fetchedAt = fetchedAt
    }

    /// What the app runs on when it has never reached the worker, or got something it could
    /// not parse.
    ///
    /// **Only rung 0.** The failure mode of a config fetch must be "the safest thing still
    /// works", never "the app falls back to the riskiest path because that is what was
    /// compiled in". A device that cannot reach the worker is exactly the device whose
    /// behaviour nobody can observe or stop, so it gets the least latitude, not the most.
    public static let failClosed = ResolverConfig(
        version: 0,
        enabledRungs: [.sharedFile],
        rules: []
    )

    public func isEnabled(_ rung: TranscriptRung) -> Bool { enabledRungs.contains(rung) }

    public func rule(for platform: Platform) -> ResolverRule? {
        rules.first { $0.platform == platform }
    }
}

/// How to get from a post URL to a media URL, for one platform.
///
/// Expressed as data rather than code so it can arrive over the wire. The cost of that is that
/// it can only express the shape of extraction that has actually been needed -- fetch a page
/// with some headers, find a media URL in the response -- and anything more exotic needs a
/// release. That has been true of every platform looked at so far.
public struct ResolverRule: Codable, Sendable, Equatable {

    /// How to get from a page to a media URL.
    ///
    /// Two strategies because one of them stopped working. Fetching Instagram's embed endpoint
    /// with a plain client returns an identical ~623 KB app shell for a real shortcode and for
    /// an invented one -- no media, no metadata, nothing. TikTok's video page returns its
    /// rehydration blob but no media for an unauthenticated client. Both were measured, not
    /// assumed, and both mean a regex over a fetched document has nothing to match.
    ///
    /// What is left is rendering the page the way the user's own browser would. That is what
    /// `webView` is, and it is why rung 2 can still be called on-device: the device loads a
    /// public page with its own engine and its own address, and reads the media element the
    /// page itself created.
    public enum Strategy: String, Codable, Sendable {
        /// Fetch the document, match `mediaPatterns` against it. Works where a platform still
        /// serves real markup -- Reddit and Vimeo do.
        case htmlPattern
        /// Load the page in a `WKWebView`, run `script`, take the URL it returns.
        case webView
    }

    public var platform: Platform
    /// Defaults to `htmlPattern` when a config omits it, so an older worker keeps working.
    public var strategy: Strategy
    /// JavaScript evaluated in the rendered page. Must evaluate to a media URL string, or to
    /// null when the page has not produced one yet -- it is retried while the page settles.
    ///
    /// Supplied by the worker rather than written in Swift for the same reason the patterns
    /// are: this is the part that breaks, and it must be fixable without a release.
    public var script: String?
    /// The page to open, with `{id}` replaced by the item's content ID, `{url}` by the
    /// percent-encoded post URL (for a template that puts it in a query parameter), and
    /// `{rawurl}` by the post URL verbatim -- which is what a `webView` rule almost always
    /// wants, because the page it needs to render *is* the post.
    public var requestTemplate: String
    /// Sent verbatim. Platforms serve different payloads to different clients, and which
    /// headers matter changes -- which is the whole reason this is config.
    public var headers: [String: String]
    /// Regexes tried in order against the response body. **The first capture group is the
    /// media URL.** First pattern that matches wins.
    ///
    /// Several rather than one because these pages carry the media under different keys
    /// depending on how the post was published, and a single pattern that covers all of them
    /// is unreadable and unmaintainable next to three that each cover one.
    public var mediaPatterns: [String]
    /// Hard ceiling on the download, in bytes. A resolver that is handed a redirect to
    /// something enormous must give up rather than fill the disk.
    public var maxBytes: Int

    public init(
        platform: Platform,
        strategy: Strategy = .htmlPattern,
        requestTemplate: String,
        headers: [String: String] = [:],
        mediaPatterns: [String] = [],
        script: String? = nil,
        maxBytes: Int = 120_000_000
    ) {
        self.platform = platform
        self.strategy = strategy
        self.script = script
        self.requestTemplate = requestTemplate
        self.headers = headers
        self.mediaPatterns = mediaPatterns
        self.maxBytes = maxBytes
    }

    /// The concrete URL to fetch for one item, or nil when the template needs something this
    /// item does not have.
    public func requestURL(contentID: String?, postURL: String?) -> String? {
        var out = requestTemplate
        if out.contains("{id}") {
            guard let contentID, !contentID.isEmpty else { return nil }
            out = out.replacingOccurrences(of: "{id}", with: contentID)
        }
        if out.contains("{rawurl}") {
            guard let postURL, !postURL.isEmpty else { return nil }
            out = out.replacingOccurrences(of: "{rawurl}", with: postURL)
        }
        if out.contains("{url}") {
            guard let postURL,
                  let encoded = postURL.addingPercentEncoding(
                      withAllowedCharacters: .alphanumerics)
            else { return nil }
            out = out.replacingOccurrences(of: "{url}", with: encoded)
        }
        return out
    }

    /// Decoded with defaults, so a rule written before a field existed still loads.
    ///
    /// Hand-written rather than synthesised because the alternative is that adding a field to
    /// this type silently invalidates every config already deployed -- and the devices running
    /// them fall back to rung 0 with no way to tell why.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        platform = try c.decode(Platform.self, forKey: .platform)
        strategy = try c.decodeIfPresent(Strategy.self, forKey: .strategy) ?? .htmlPattern
        requestTemplate = try c.decode(String.self, forKey: .requestTemplate)
        headers = try c.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
        mediaPatterns = try c.decodeIfPresent([String].self, forKey: .mediaPatterns) ?? []
        script = try c.decodeIfPresent(String.self, forKey: .script)
        maxBytes = try c.decodeIfPresent(Int.self, forKey: .maxBytes) ?? 120_000_000
    }

    /// The first media URL any pattern finds in the response body.
    ///
    /// Unescapes `\/` before matching. These payloads are JSON embedded in HTML, so every
    /// slash in a URL arrives escaped, and a pattern written against the readable form would
    /// silently never match.
    public func extractMediaURL(from body: String) -> String? {
        let unescaped = body.replacingOccurrences(of: "\\/", with: "/")
        for pattern in mediaPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(unescaped.startIndex..., in: unescaped)
            guard let match = regex.firstMatch(in: unescaped, range: range),
                  match.numberOfRanges > 1,
                  let captured = Range(match.range(at: 1), in: unescaped)
            else { continue }
            let candidate = String(unescaped[captured])
            if candidate.hasPrefix("http") { return candidate }
        }
        return nil
    }
}
