import Foundation
import CryptoKit

/// How to get a thumbnail for a link, decided without touching the network.
///
/// Keeping the decision pure means the whole per-platform table is unit-testable, and the
/// fetcher becomes a dumb executor of three verbs instead of a pile of per-site branching.
public enum ThumbnailPlan: Equatable, Sendable {
    /// Try these in order; the first that returns 2xx with image bytes wins. YouTube is the
    /// only platform whose thumbnail is derivable from the URL alone, and it needs a walk
    /// because `maxresdefault` 404s on older or lower-resolution uploads.
    case directCandidates([URL])
    /// Fetch this oEmbed endpoint and read `thumbnail_url` out of the JSON.
    case oEmbed(URL)
    /// Fetch the page and read `og:image` out of the head.
    case openGraph(URL)
    /// Nothing is reachable without authentication. The typographic tile is the designed
    /// result here, not a failure -- so the pipeline must not queue a retry.
    case unavailable
}

public enum ThumbnailResolver {

    public static func plan(for link: CanonicalLink) -> ThumbnailPlan {
        switch link.platform {
        case .youtube:
            guard let id = link.contentID else { return .unavailable }
            // Descending quality. maxres exists only for uploads at 1280x720 or better.
            let names = ["maxresdefault", "sddefault", "hqdefault"]
            return .directCandidates(names.compactMap { URL(string: "https://i.ytimg.com/vi/\(id)/\($0).jpg") })

        case .tiktok:
            guard let encoded = encode(link.url) else { return .unavailable }
            return .oEmbed(URL(string: "https://www.tiktok.com/oembed?url=\(encoded)")!)

        case .vimeo:
            guard let encoded = encode(link.url) else { return .unavailable }
            return .oEmbed(URL(string: "https://vimeo.com/api/oembed.json?url=\(encoded)")!)

        case .pinterest:
            // Measured 2026-09-30: the pin page serves an app shell, but the oEmbed endpoint
            // answers an unauthenticated client with the pin's title, its board owner and a
            // thumbnail_url on the permanent i.pinimg.com CDN. The fetcher asks for the 736px
            // rendition rather than the 236px one oEmbed names.
            guard let encoded = encode(link.url) else { return .unavailable }
            return .oEmbed(URL(string: "https://www.pinterest.com/oembed.json?url=\(encoded)")!)

        case .reddit:
            // Reddit does serve og:image, but as a signed preview.redd.it URL. The fetcher
            // runs the result through `permanentRedditURL` to turn it into a durable one.
            return .openGraph(link.url)

        case .instagram, .x, .threads, .cosmos:
            // Researched and confirmed: no og:image and no open oEmbed to an unauthenticated
            // client. Anything usable for these comes from the share sheet payload at save
            // time, or from the Chrome extension's right-click, not from a fetch.
            return .unavailable

        case .web:
            return .openGraph(link.url)
        }
    }

    /// Rewrites a signed `preview.redd.it` URL onto the permanent `i.redd.it` host.
    ///
    /// Both hosts address the same media id; `preview` adds an `s=`/`auth=` signature and an
    /// expiry, `i.redd.it` does not. This is a free upgrade from an expiring URL to one that
    /// keeps working, and it is the reason Reddit sits in the `stable` durability bucket.
    public static func permanentRedditURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased(),
              host == "preview.redd.it" || host == "external-preview.redd.it"
        else { return url }

        // Only the last path component is the media id; `width=`/`crop=` and the signature
        // all live in the query and are dropped with it.
        components.host = "i.redd.it"
        components.query = nil
        components.fragment = nil
        return components.url ?? url
    }

    /// The oEmbed endpoint that names a post's title and its creator, where one is open.
    ///
    /// Separate from the thumbnail plan because YouTube's thumbnail needs no request at all
    /// but its title does -- and a library full of tiles captioned "YouTube" is the most
    /// visible thing wrong with a fresh save. Instagram and X have no open oEmbed.
    public static func metadataEndpoint(for link: CanonicalLink) -> URL? {
        guard let encoded = encode(link.url) else { return nil }
        switch link.platform {
        case .youtube: return URL(string: "https://www.youtube.com/oembed?format=json&url=\(encoded)")
        case .tiktok: return URL(string: "https://www.tiktok.com/oembed?url=\(encoded)")
        case .vimeo: return URL(string: "https://vimeo.com/api/oembed.json?url=\(encoded)")
        case .pinterest: return URL(string: "https://www.pinterest.com/oembed.json?url=\(encoded)")
        case .reddit, .instagram, .x, .threads, .cosmos, .web: return nil
        }
    }

    /// Asks Pinterest's CDN for the 736px rendition instead of the 236px one oEmbed names.
    ///
    /// Same image, same permanent host; the size is only a path segment. 236px is a third of
    /// what a two-column tile draws at 3x, and a blurry pin is the thing that makes a grid look
    /// cheap.
    public static func largerPinterestImage(_ url: URL) -> URL {
        guard url.host?.lowercased() == "i.pinimg.com" else { return url }
        let upgraded = url.absoluteString.replacingOccurrences(of: "/236x/", with: "/736x/")
        return URL(string: upgraded) ?? url
    }

    private static func encode(_ url: URL) -> String? {
        url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
    }
}

/// The two fields worth keeping from an oEmbed response.
public struct OEmbedMetadata: Equatable, Sendable {
    public var title: String?
    public var author: String?

    /// Reads `title` and `author_name`, trimmed, with empties treated as absent. Nil when the
    /// payload is not JSON or carries neither.
    public static func parse(_ data: Data) -> OEmbedMetadata? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        func clean(_ key: String) -> String? {
            guard let value = (json[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty
            else { return nil }
            return value
        }
        let result = OEmbedMetadata(title: clean("title"), author: clean("author_name"))
        return result.title == nil && result.author == nil ? nil : result
    }
}

public enum StorageKey {
    /// The filename/row key a thumbnail is stored under.
    ///
    /// Keyed on the *post* URL, never on the image URL. TikTok and Instagram re-mint their
    /// CDN URLs on every resolve, so hashing the image URL would silently store the same
    /// thumbnail again under a new name on every refresh.
    ///
    /// SHA-256 truncated rather than MD5: nothing here needs to interoperate with another
    /// tool's naming, so there is no reason to reach for a broken hash.
    public static func forPost(_ url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined().prefix(32).description
    }
}
