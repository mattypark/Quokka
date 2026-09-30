import Foundation

/// A link to a whole collection rather than one post: a Pinterest board or profile, or an
/// Are.na channel. Pasting one imports everything in it.
///
/// This is how Cosmos fills a new account on day one -- "import from anywhere" -- and the
/// reason a library can start with hundreds of pictures instead of one. Both sources are open
/// to a client with no login, measured 2026-09-30:
///
/// - A Pinterest board or profile has an RSS feed at the same path plus `.rss`, carrying the
///   latest 25 pins with their pin URLs. Each pin then gets its picture through Pinterest's
///   oEmbed like any other saved pin.
/// - An Are.na channel's contents are public through Are.na's own API, 100 blocks a page, and
///   every block page carries an `og:image` the normal fetcher already reads.
public enum CollectionSource: Equatable, Sendable {
    case pinterestBoard(user: String, board: String)
    case pinterestProfile(user: String)
    case arenaChannel(slug: String)

    /// Path segments that look like a Pinterest user but are Pinterest's own pages.
    private static let pinterestReserved: Set<String> = [
        "pin", "ideas", "search", "today", "_", "settings", "business", "explore", "categories", "about",
    ]

    /// Recognises a collection link, or returns nil for anything else -- a single post, a
    /// search page, another site.
    public static func detect(_ raw: String) -> CollectionSource? {
        guard let components = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = components.host?.lowercased()
        else { return nil }
        let parts = components.path.split(separator: "/").map(String.init).filter { !$0.isEmpty }

        if host.hasSuffix("pinterest.com") || host.contains(".pinterest.") || host.hasPrefix("pinterest.") {
            guard let user = parts.first, !pinterestReserved.contains(user.lowercased()) else { return nil }
            switch parts.count {
            case 1: return .pinterestProfile(user: user)
            case 2: return .pinterestBoard(user: user, board: parts[1])
            default: return nil
            }
        }

        if host == "are.na" || host == "www.are.na" {
            // are.na/{user}/{channel}. Block and search pages have their own first segment.
            guard parts.count == 2, !["block", "search", "explore", "about"].contains(parts[0].lowercased())
            else { return nil }
            return .arenaChannel(slug: parts[1])
        }
        return nil
    }

    /// Where the collection's contents are read from.
    public var feedURL: URL {
        switch self {
        case .pinterestBoard(let user, let board):
            URL(string: "https://www.pinterest.com/\(user)/\(board).rss")!
        case .pinterestProfile(let user):
            URL(string: "https://www.pinterest.com/\(user)/feed.rss")!
        case .arenaChannel(let slug):
            URL(string: "https://api.are.na/v2/channels/\(slug)/contents?per=100&page=1")!
        }
    }

    /// How the import is described back to the person, e.g. "Pinterest board ‘kitchens’".
    public var displayName: String {
        switch self {
        case .pinterestBoard(_, let board): "Pinterest board “\(board.replacingOccurrences(of: "-", with: " "))”"
        case .pinterestProfile(let user): "\(user)’s Pinterest"
        case .arenaChannel(let slug): "Are.na channel “\(slug.replacingOccurrences(of: "-", with: " "))”"
        }
    }

    /// Reads the posts out of whatever `feedURL` returned.
    public func posts(from data: Data) -> [CollectedPost] {
        switch self {
        case .pinterestBoard, .pinterestProfile:
            CollectionParser.pinterestRSS(String(decoding: data, as: UTF8.self))
        case .arenaChannel:
            CollectionParser.arenaContents(data)
        }
    }
}

/// One post found in a collection, before it becomes an `Item`.
public struct CollectedPost: Equatable, Sendable {
    public var url: String
    public var title: String?

    public init(url: String, title: String?) {
        self.url = url
        self.title = title
    }
}

public enum CollectionParser {

    /// The `<item>`s of a Pinterest RSS feed: each pin's link and title.
    static func pinterestRSS(_ xml: String) -> [CollectedPost] {
        xml.components(separatedBy: "<item>").dropFirst().compactMap { chunk in
            guard let link = between(chunk, "<link>", "</link>")?.trimmingCharacters(in: .whitespacesAndNewlines),
                  link.contains("/pin/")
            else { return nil }
            let title = between(chunk, "<title>", "</title>").map(decodeEntities)
            return CollectedPost(url: link, title: title.flatMap { $0.isEmpty ? nil : $0 })
        }
    }

    /// The blocks of an Are.na channel that carry a picture, as block pages.
    ///
    /// Text and nested-channel blocks are skipped: they have no image, and a library of text
    /// cards is the thing importing a channel is meant to fix.
    static func arenaContents(_ data: Data) -> [CollectedPost] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contents = json["contents"] as? [[String: Any]]
        else { return [] }
        return contents.compactMap { block in
            guard let id = block["id"] as? Int, block["image"] is [String: Any] else { return nil }
            let title = (block["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return CollectedPost(url: "https://www.are.na/block/\(id)", title: title?.isEmpty == false ? title : nil)
        }
    }

    private static func between(_ text: String, _ open: String, _ close: String) -> String? {
        guard let start = text.range(of: open), let end = text.range(of: close, range: start.upperBound..<text.endIndex)
        else { return nil }
        return String(text[start.upperBound..<end.lowerBound])
    }

    private static func decodeEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "<![CDATA[", with: "")
            .replacingOccurrences(of: "]]>", with: "")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
