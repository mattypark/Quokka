import Foundation

/// A link reduced to the one form Allim stores it under.
///
/// Two saves of the same post collapse into one row if and only if they produce the same
/// `url` here, so this type is what makes "the reel I DM'd myself", "the post I saved" and
/// "the post I liked" turn into a single item after an Instagram export import rather than
/// three near-duplicates.
public struct CanonicalLink: Equatable, Sendable {
    /// The canonical form. Used both as the dedupe key and as the URL that opens on tap.
    public let url: URL
    public let platform: Platform
    /// Shortcode or numeric id, when the platform's URL shape exposes one.
    public let contentID: String?
    /// The author handle, when the URL carries it. Cheap metadata that survives even when
    /// no thumbnail is reachable, so a fallback tile still has something to say.
    public let author: String?
    /// True for shortener domains (`vm.tiktok.com`, `pin.it`, Reddit `/s/` links) whose real
    /// destination is only knowable by following a redirect. Canonicalisation is pure, so it
    /// flags these rather than resolving them; the caller re-canonicalises after the hop.
    public let needsNetworkResolution: Bool

    public init(
        url: URL,
        platform: Platform,
        contentID: String? = nil,
        author: String? = nil,
        needsNetworkResolution: Bool = false
    ) {
        self.url = url
        self.platform = platform
        self.contentID = contentID
        self.author = author
        self.needsNetworkResolution = needsNetworkResolution
    }
}

public enum LinkCanonicaliser {

    /// Query parameters that identify the sharer rather than the thing shared. Dropping them
    /// is what stops the same post arriving twice from two different shares.
    ///
    /// `t` and `si` are here on purpose. On YouTube they carry a start timestamp and a share
    /// token; keeping either would file the same video twice because it was shared from two
    /// different points. Allim is a library, not a bookmark of a moment.
    private static let trackingKeys: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id",
        "igshid", "igsh", "fbclid", "gclid", "mc_cid", "mc_eid",
        "si", "t", "ref", "ref_src", "ref_url", "source", "src",
        "share_id", "share_app_id", "sender_device", "sender_web_id", "web_id",
        "is_from_webapp", "is_copy_url", "_r", "_t", "feature", "app", "pp",
    ]

    // MARK: - Entry points

    /// Pulls the first http(s) URL out of arbitrary shared text.
    ///
    /// Share sheets rarely hand over a bare URL. TikTok in particular sends a sentence with
    /// the link buried in it, so the extension gets text like
    /// `"check this out https://vm.tiktok.com/ZMxyz/ - come watch"`.
    public static func extractFirstURL(from text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in detector.matches(in: text, range: range) {
            guard let url = match.url else { continue }
            if url.scheme == "http" || url.scheme == "https" { return url.absoluteString }
        }
        return nil
    }

    /// Reduces a raw string to its canonical form. Returns nil only when there is no URL in it.
    public static func canonicalise(_ raw: String) -> CanonicalLink? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Accept a bare host ("instagram.com/p/abc") as well as a full URL, and dig a URL out
        // of surrounding prose when there is one.
        let candidate: String
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            candidate = trimmed
        } else if let found = extractFirstURL(from: trimmed) {
            candidate = found
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            candidate = "https://" + trimmed
        } else {
            return nil
        }

        guard var components = URLComponents(string: candidate), let rawHost = components.host else {
            return nil
        }

        // Scheme and host are case-insensitive and get normalised. Paths are NOT: Instagram
        // shortcodes and YouTube ids are case-sensitive, and lowercasing them breaks the link.
        components.scheme = "https"
        components.fragment = nil
        let host = rawHost.lowercased().hasPrefix("www.")
            ? String(rawHost.lowercased().dropFirst(4))
            : rawHost.lowercased()

        let segments = components.percentEncodedPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        let platform = Platform.detect(host: rawHost)

        switch platform {
        case .youtube: return youtube(host: host, segments: segments, components: components)
        case .instagram: return instagram(host: host, segments: segments, components: components)
        case .tiktok: return tiktok(host: host, segments: segments, components: components)
        case .pinterest: return pinterest(host: host, segments: segments, components: components)
        case .reddit: return reddit(host: host, segments: segments, components: components)
        case .x: return xDotCom(segments: segments, components: components)
        case .threads: return threads(segments: segments, components: components)
        case .vimeo: return vimeo(segments: segments, components: components)
        case .cosmos, .web: return generic(host: host, platform: platform, components: components)
        }
    }

    // MARK: - Per-platform shapes

    private static func youtube(host: String, segments: [String], components: URLComponents) -> CanonicalLink? {
        var id: String?
        if host == "youtu.be" {
            id = segments.first
        } else if let first = segments.first {
            switch first {
            case "watch": id = queryValue("v", in: components)
            case "shorts", "embed", "live", "v": id = segments.count > 1 ? segments[1] : nil
            default: break
            }
        }
        guard let id, isPlausibleID(id) else { return generic(host: host, platform: .youtube, components: components) }
        return build("https://www.youtube.com/watch?v=\(id)", .youtube, id: id)
    }

    private static func instagram(host: String, segments: [String], components: URLComponents) -> CanonicalLink? {
        // Instagram serves one shortcode under /p/, /reel/, /reels/ and /tv/, and it also
        // accepts a /{user}/p/{code}/ form. All four collapse to /p/{code}/, which is what
        // makes a DM'd reel and the same post from Saved dedupe against each other.
        let kinds: Set<String> = ["p", "reel", "reels", "tv"]
        var author: String?
        var code: String?

        for (index, segment) in segments.enumerated() where kinds.contains(segment) {
            if index > 0 { author = segments[index - 1] }
            code = segments.count > index + 1 ? segments[index + 1] : nil
            break
        }
        guard let code, isPlausibleID(code) else {
            return generic(host: host, platform: .instagram, components: components)
        }
        return build("https://www.instagram.com/p/\(code)/", .instagram, id: code, author: author)
    }

    private static func tiktok(host: String, segments: [String], components: URLComponents) -> CanonicalLink? {
        // vm./vt. shortlinks and /t/ links hide the real post behind a redirect.
        if host == "vm.tiktok.com" || host == "vt.tiktok.com" || segments.first == "t" {
            return build(stripped(components, host: host), .tiktok, needsResolution: true)
        }
        if let videoIndex = segments.firstIndex(of: "video"), segments.count > videoIndex + 1 {
            let id = segments[videoIndex + 1]
            let author = videoIndex > 0 ? segments[videoIndex - 1] : nil
            let handle = author?.hasPrefix("@") == true ? author! : "@\(author ?? "")"
            return build("https://www.tiktok.com/\(handle)/video/\(id)", .tiktok, id: id,
                         author: author.map { $0.hasPrefix("@") ? String($0.dropFirst()) : $0 })
        }
        return generic(host: host, platform: .tiktok, components: components)
    }

    private static func pinterest(host: String, segments: [String], components: URLComponents) -> CanonicalLink? {
        if host == "pin.it" {
            return build(stripped(components, host: host), .pinterest, needsResolution: true)
        }
        if let pinIndex = segments.firstIndex(of: "pin"), segments.count > pinIndex + 1 {
            let id = segments[pinIndex + 1]
            return build("https://www.pinterest.com/pin/\(id)/", .pinterest, id: id)
        }
        return generic(host: host, platform: .pinterest, components: components)
    }

    private static func reddit(host: String, segments: [String], components: URLComponents) -> CanonicalLink? {
        // redd.it/{id} already IS the post id -- no redirect needed. The newer /r/{sub}/s/{code}
        // share links are genuine shorteners and do need one.
        if host == "redd.it", let id = segments.first {
            return build("https://www.reddit.com/comments/\(id)/", .reddit, id: id)
        }
        if segments.contains("s") {
            return build(stripped(components, host: host), .reddit, needsResolution: true)
        }
        if let index = segments.firstIndex(of: "comments"), segments.count > index + 1 {
            let id = segments[index + 1]
            let subreddit = segments.firstIndex(of: "r").flatMap { rIndex -> String? in
                segments.count > rIndex + 1 ? segments[rIndex + 1] : nil
            }
            return build("https://www.reddit.com/comments/\(id)/", .reddit, id: id, author: subreddit.map { "r/\($0)" })
        }
        return generic(host: host, platform: .reddit, components: components)
    }

    private static func xDotCom(segments: [String], components: URLComponents) -> CanonicalLink? {
        // twitter.com, fxtwitter.com and vxtwitter.com all address the same tweet. Normalising
        // the host is what stops the same post filing twice from two different share paths.
        if let index = segments.firstIndex(of: "status"), segments.count > index + 1 {
            let id = segments[index + 1]
            let author = index > 0 ? segments[index - 1] : nil
            return build("https://x.com/\(author ?? "i")/status/\(id)", .x, id: id, author: author)
        }
        return generic(host: "x.com", platform: .x, components: components)
    }

    private static func threads(segments: [String], components: URLComponents) -> CanonicalLink? {
        if let index = segments.firstIndex(of: "post"), segments.count > index + 1 {
            let code = segments[index + 1]
            let author = index > 0 ? segments[index - 1] : nil
            let handle = author.map { $0.hasPrefix("@") ? $0 : "@\($0)" } ?? "@"
            return build("https://www.threads.net/\(handle)/post/\(code)", .threads, id: code,
                         author: author.map { $0.hasPrefix("@") ? String($0.dropFirst()) : $0 })
        }
        return generic(host: "threads.net", platform: .threads, components: components)
    }

    private static func vimeo(segments: [String], components: URLComponents) -> CanonicalLink? {
        if let id = segments.first(where: { $0.allSatisfy(\.isNumber) }) {
            return build("https://vimeo.com/\(id)", .vimeo, id: id)
        }
        return generic(host: "vimeo.com", platform: .vimeo, components: components)
    }

    /// Everything with no known shape: keep the path, drop tracking, drop the fragment.
    private static func generic(host: String, platform: Platform, components: URLComponents) -> CanonicalLink? {
        build(stripped(components, host: host), platform)
    }

    // MARK: - Helpers

    private static func stripped(_ components: URLComponents, host: String) -> String {
        var c = components
        c.scheme = "https"
        c.host = host
        c.fragment = nil
        let kept = (c.queryItems ?? []).filter { !trackingKeys.contains($0.name.lowercased()) }
        c.queryItems = kept.isEmpty ? nil : kept

        var path = c.percentEncodedPath
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        c.percentEncodedPath = path

        return c.string ?? "https://\(host)"
    }

    private static func queryValue(_ name: String, in components: URLComponents) -> String? {
        components.queryItems?.first { $0.name == name }?.value
    }

    /// Guards against reading a trailing slash or a stray path word as an id.
    private static func isPlausibleID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 64 && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    private static func build(
        _ string: String,
        _ platform: Platform,
        id: String? = nil,
        author: String? = nil,
        needsResolution: Bool = false
    ) -> CanonicalLink? {
        guard let url = URL(string: string) else { return nil }
        return CanonicalLink(
            url: url,
            platform: platform,
            contentID: id,
            author: author,
            needsNetworkResolution: needsResolution
        )
    }
}
