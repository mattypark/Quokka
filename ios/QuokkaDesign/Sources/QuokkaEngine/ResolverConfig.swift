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
    public var platform: Platform
    /// The URL to fetch, with `{id}` replaced by the item's content ID and `{url}` by the
    /// percent-encoded canonical post URL.
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
        requestTemplate: String,
        headers: [String: String] = [:],
        mediaPatterns: [String],
        maxBytes: Int = 120_000_000
    ) {
        self.platform = platform
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
        if out.contains("{url}") {
            guard let postURL,
                  let encoded = postURL.addingPercentEncoding(
                      withAllowedCharacters: .alphanumerics)
            else { return nil }
            out = out.replacingOccurrences(of: "{url}", with: encoded)
        }
        return out
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
