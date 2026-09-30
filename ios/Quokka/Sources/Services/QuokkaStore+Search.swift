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

    // MARK: - Breakdowns

    /// How many items have usable words, for the counts on the sky.
    func transcribedCount() throws -> Int {
        try dbPool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item_transcript WHERE TRIM(text) <> ''") ?? 0
        }
    }

    /// Items that have a transcript, newest save first -- the ones a breakdown can be read from.
    func transcribedItems(limit: Int = 20) throws -> [Item] {
        try dbPool.read { db in
            try Item.fetchAll(
                db,
                sql: """
                    SELECT i.* FROM item i
                    JOIN item_transcript t ON t.itemID = i.id
                    WHERE TRIM(t.text) <> ''
                    ORDER BY i.savedAt DESC, i.id DESC
                    LIMIT ?
                    """,
                arguments: [limit])
        }
    }

    /// Video saves with no transcript and no job that has given up -- the ones worth asking for.
    ///
    /// Video platforms only: a Pinterest pin or an X post has no audio to read, and offering
    /// to transcribe one would be a button that can only fail.
    func untranscribedVideos(limit: Int = 20) throws -> [Item] {
        let platforms = [Platform.youtube, .tiktok, .instagram, .vimeo, .web].map(\.rawValue)
        let marks = platforms.map { _ in "?" }.joined(separator: ", ")
        var arguments: [(any DatabaseValueConvertible)?] = platforms.map { $0 }
        arguments.append(Self.transcriptAttemptLimit)
        arguments.append(limit)
        return try dbPool.read { db in
            try Item.fetchAll(
                db,
                sql: """
                    SELECT i.* FROM item i
                    LEFT JOIN item_transcript t ON t.itemID = i.id
                    LEFT JOIN transcript_job j ON j.itemID = i.id
                    WHERE t.itemID IS NULL
                      AND i.platform IN (\(marks))
                      AND (j.itemID IS NULL OR j.attempts < ?)
                    ORDER BY i.savedAt DESC, i.id DESC
                    LIMIT ?
                    """,
                arguments: StatementArguments(arguments))
        }
    }

    /// Whether a transcript is queued and still has attempts left. Answers the one question
    /// `TranscriptReading.isTranscribing` needs -- see BACKEND-ASKS section 7.
    func isTranscriptQueued(itemID: Int64) throws -> Bool {
        try dbPool.read { db in
            try Bool.fetchOne(
                db,
                sql: """
                    SELECT EXISTS(
                        SELECT 1 FROM transcript_job j
                        LEFT JOIN item_transcript t ON t.itemID = j.itemID
                        WHERE j.itemID = ? AND t.itemID IS NULL AND j.attempts < ?
                    )
                    """,
                arguments: [itemID, Self.transcriptAttemptLimit]) ?? false
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
