import Foundation
import GRDB
import QuokkaEngine

/// Finding things again: by words, by colour, and by which playlists hold an item.
///
/// Written by the frontend session for the Cosmos redesign's Search tab and item page, and
/// logged in `nextsessions/BACKEND-ASKS.md` for review -- the store is the backend's lane.
extension QuokkaStore {

    /// Items matching every word, newest first.
    ///
    /// LIKE rather than FTS5 for now: it needs no migration and no triggers to keep an index in
    /// step with four columns and a second table. Every term has to match somewhere, so "key
    /// light" finds the video that says both rather than every video that says either. The
    /// transcript is searched too -- it is the only place the content of a video actually
    /// lives, since captions are marketing and a YouTube title is frequently the URL.
    func search(text: String, limit: Int = 200) throws -> [Item] {
        let terms = text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
            .prefix(6)
        guard !terms.isEmpty else { return [] }

        let columns = ["i.title", "i.author", "i.caption", "i.tags", "i.url", "t.text"]
        var clauses: [String] = []
        var arguments: [(any DatabaseValueConvertible)?] = []
        for term in terms {
            let pattern = "%\(Self.escapeLike(term))%"
            clauses.append("(" + columns.map { "\($0) LIKE ? ESCAPE '\\'" }.joined(separator: " OR ") + ")")
            arguments.append(contentsOf: Array(repeating: pattern, count: columns.count))
        }
        arguments.append(limit)

        return try dbPool.read { db in
            try Item.fetchAll(
                db,
                sql: """
                    SELECT i.* FROM item i
                    LEFT JOIN item_transcript t ON t.itemID = i.id
                    WHERE \(clauses.joined(separator: " AND "))
                    ORDER BY i.savedAt DESC, i.id DESC
                    LIMIT ?
                    """,
                arguments: StatementArguments(arguments))
        }
    }

    /// Items whose average colour is nearest the one asked for.
    ///
    /// Weighted RGB distance (2:4:3), the cheap approximation of perceptual difference that
    /// keeps green from dominating. The average colour is already stored inline on every row
    /// with a thumbnail, so this is one pass over an integer column with no decoding at all.
    func search(color packed: Int, limit: Int = 200) throws -> [Item] {
        let red = (packed >> 16) & 0xFF
        let green = (packed >> 8) & 0xFF
        let blue = packed & 0xFF
        return try dbPool.read { db in
            try Item.fetchAll(
                db,
                sql: """
                    SELECT * FROM item
                    WHERE averageColor IS NOT NULL
                    ORDER BY
                        2 * (((averageColor >> 16) & 255) - ?) * (((averageColor >> 16) & 255) - ?)
                      + 4 * (((averageColor >> 8) & 255) - ?) * (((averageColor >> 8) & 255) - ?)
                      + 3 * ((averageColor & 255) - ?) * ((averageColor & 255) - ?)
                    LIMIT ?
                    """,
                arguments: [red, red, green, green, blue, blue, limit])
        }
    }

    /// Recent average colours, for the swatch row under the search pill.
    func recentColors(limit: Int = 400) throws -> [Int] {
        try dbPool.read { db in
            try Int.fetchAll(
                db,
                sql: """
                    SELECT averageColor FROM item
                    WHERE averageColor IS NOT NULL
                    ORDER BY savedAt DESC
                    LIMIT ?
                    """,
                arguments: [limit])
        }
    }

    /// Every playlist an item is on, however it got there -- directly, or through an idea.
    func playlists(containing itemID: Int64) throws -> [Playlist] {
        try dbPool.read { db in
            try Playlist.fetchAll(
                db,
                sql: """
                    SELECT * FROM playlist
                    WHERE id IN (
                        SELECT playlistID FROM playlist_item WHERE itemID = ?
                        UNION
                        SELECT d.playlistID FROM idea_source s
                        JOIN idea d ON d.id = s.ideaID
                        WHERE s.itemID = ? AND d.playlistID IS NOT NULL
                    )
                    ORDER BY updatedAt DESC
                    """,
                arguments: [itemID, itemID])
        }
    }

    /// `%` and `_` in what someone typed are text, not wildcards.
    private static func escapeLike(_ term: String) -> String {
        term
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}
