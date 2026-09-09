import Foundation

/// Where a saved item came from.
///
/// The cases are ordered by how much Allim can actually learn about a link from that
/// platform, because that ordering drives the whole thumbnail pipeline. `youtube` and
/// `reddit` hand over a stable image; `tiktok` hands over one that expires in about two
/// days; `instagram`, `pinterest` and `x` hand over nothing at all to an unauthenticated
/// client and always fall through to a typographic tile.
public enum Platform: String, Codable, Sendable, CaseIterable {
    case youtube
    case reddit
    case tiktok
    case instagram
    case pinterest
    case x
    case threads
    case vimeo
    case cosmos
    case web

    /// How the thumbnail for this platform behaves once we have it.
    public enum ThumbnailDurability: Sendable {
        /// The URL keeps working. Cache the bytes anyway, for offline.
        case stable
        /// The URL is signed and expires. Bytes must be captured at save time.
        case expiring
        /// No thumbnail is reachable without authentication. Typographic tile.
        case unreachable
    }

    public var thumbnailDurability: ThumbnailDurability {
        switch self {
        case .youtube, .reddit, .vimeo: .stable
        case .tiktok: .expiring
        case .instagram, .pinterest, .x, .threads, .cosmos: .unreachable
        case .web: .stable
        }
    }

    /// The name shown on a fallback tile.
    public var displayName: String {
        switch self {
        case .youtube: "YouTube"
        case .reddit: "Reddit"
        case .tiktok: "TikTok"
        case .instagram: "Instagram"
        case .pinterest: "Pinterest"
        case .x: "X"
        case .threads: "Threads"
        case .vimeo: "Vimeo"
        case .cosmos: "Cosmos"
        case .web: "Web"
        }
    }

    /// Detects the platform from a host, with or without a `www.` prefix.
    public static func detect(host: String) -> Platform {
        let h = host.lowercased().hasPrefix("www.")
            ? String(host.lowercased().dropFirst(4))
            : host.lowercased()

        switch h {
        case "youtube.com", "m.youtube.com", "youtu.be", "music.youtube.com":
            return .youtube
        case "instagram.com", "instagr.am", "ddinstagram.com":
            return .instagram
        case "tiktok.com", "m.tiktok.com", "vm.tiktok.com", "vt.tiktok.com":
            return .tiktok
        case "pinterest.com", "pin.it", "pinterest.co.uk", "pinterest.ca":
            return .pinterest
        case "reddit.com", "old.reddit.com", "new.reddit.com", "np.reddit.com", "redd.it":
            return .reddit
        case "x.com", "twitter.com", "mobile.twitter.com", "fxtwitter.com", "vxtwitter.com":
            return .x
        case "threads.net", "threads.com":
            return .threads
        case "vimeo.com", "player.vimeo.com":
            return .vimeo
        case "cosmos.so":
            return .cosmos
        default:
            return .web
        }
    }
}
