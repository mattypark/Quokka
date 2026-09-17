import Foundation
import GRDB
import QuokkaEngine

/// Items on a playlist directly, and the digest of what is in one.
///
/// The playlist→idea→item route still exists and still matters — that is how a script knows
/// which videos it came from. This is the other direction people reach for first: a pile of
/// saved reels dropped into a named list, with no idea written yet.
extension QuokkaStore {

    /// Everything in a playlist, however it got there.
    ///
    /// Unions the directly-added items with the ones reached through the playlist's ideas,
    /// deduplicated. Two routes in, one answer out — a screen asking "what is in this
    /// playlist" should never have to know which mechanism put something there.
    func playlistItems(_ playlistID: Int64) throws -> [Item] {
        try dbPool.read { db in
            try Item.fetchAll(
                db,
                sql: """
                    SELECT i.* FROM item i
                    WHERE i.id IN (
                        SELECT itemID FROM playlist_item WHERE playlistID = ?
                        UNION
                        SELECT s.itemID FROM idea_source s
                        JOIN idea d ON d.id = s.ideaID
                        WHERE d.playlistID = ?
                    )
                    ORDER BY i.savedAt DESC, i.id DESC
                    """,
                arguments: [playlistID, playlistID])
        }
    }

    /// Adds items to a playlist, ignoring any already on it.
    ///
    /// Returns how many were actually new, which is what a "added 24 of 30" confirmation needs
    /// — and what tells someone that six of the reels they picked were already in there.
    @discardableResult
    func addToPlaylist(_ playlistID: Int64, itemIDs: [Int64]) throws -> Int {
        try dbPool.write { db in
            let start = try Int.fetchOne(
                db, sql: "SELECT COALESCE(MAX(position), -1) + 1 FROM playlist_item WHERE playlistID = ?",
                arguments: [playlistID]) ?? 0
            var added = 0
            for (offset, itemID) in itemIDs.enumerated() {
                let changes = try db.execute(
                    sql: """
                        INSERT INTO playlist_item (playlistID, itemID, position)
                        VALUES (?, ?, ?) ON CONFLICT DO NOTHING
                        """,
                    arguments: [playlistID, itemID, start + offset])
                _ = changes
                if db.changesCount > 0 { added += 1 }
            }
            // The playlist changed, so anything derived from its contents is now behind.
            try db.execute(
                sql: "UPDATE playlist SET updatedAt = ? WHERE id = ?",
                arguments: [Date(), playlistID])
            return added
        }
    }

    @discardableResult
    func removeFromPlaylist(_ playlistID: Int64, itemIDs: [Int64]) throws -> Int {
        try dbPool.write { db in
            var removed = 0
            for itemID in itemIDs {
                try db.execute(
                    sql: "DELETE FROM playlist_item WHERE playlistID = ? AND itemID = ?",
                    arguments: [playlistID, itemID])
                removed += db.changesCount
            }
            try db.execute(
                sql: "UPDATE playlist SET updatedAt = ? WHERE id = ?",
                arguments: [Date(), playlistID])
            return removed
        }
    }

    // MARK: - Summaries

    /// The digest, and when it was written.
    ///
    /// `summarisedAt` rather than a bare flag so a screen can say the summary is *behind* the
    /// playlist rather than merely absent — adding ten videos to a summarised playlist should
    /// not leave a stale paragraph presenting itself as current.
    func setPlaylistSummary(_ playlistID: Int64, _ summary: String) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "UPDATE playlist SET summary = ?, summarisedAt = ? WHERE id = ?",
                arguments: [summary, Date(), playlistID])
        }
    }

    struct PlaylistDigest: Sendable, Equatable {
        public let summary: String?
        public let summarisedAt: Date?
        public let updatedAt: Date

        /// True when the playlist has changed since the summary was written.
        ///
        /// A second of slack: `addToPlaylist` touches `updatedAt` and the summary lands a
        /// moment later, so an exact comparison would report every fresh summary as stale.
        public var isStale: Bool {
            guard let summarisedAt else { return false }
            return updatedAt.timeIntervalSince(summarisedAt) > 1
        }
    }

    func playlistDigest(_ playlistID: Int64) throws -> PlaylistDigest? {
        try dbPool.read { db in
            guard let row = try Row.fetchOne(
                db, sql: "SELECT summary, summarisedAt, updatedAt FROM playlist WHERE id = ?",
                arguments: [playlistID])
            else { return nil }
            return PlaylistDigest(
                summary: row["summary"], summarisedAt: row["summarisedAt"], updatedAt: row["updatedAt"])
        }
    }

    /// Every playlist, with its item count and whether it has a current digest.
    ///
    /// One query rather than a count per playlist: the mirror writes all of them on every
    /// launch, and N+1 over a few dozen playlists is a visible pause on a cold start.
    func playlistsForMirror() throws -> [(playlist: Playlist, itemCount: Int)] {
        try dbPool.read { db in
            let playlists = try Playlist.fetchAll(db, sql: "SELECT * FROM playlist ORDER BY updatedAt DESC")
            let counts = try Row.fetchAll(
                db,
                sql: """
                    SELECT playlistID, COUNT(*) AS n FROM (
                        SELECT playlistID, itemID FROM playlist_item
                        UNION
                        SELECT d.playlistID, s.itemID FROM idea_source s
                        JOIN idea d ON d.id = s.ideaID
                        WHERE d.playlistID IS NOT NULL
                    ) GROUP BY playlistID
                    """)
            var byID: [Int64: Int] = [:]
            for row in counts { byID[row["playlistID"]] = row["n"] }
            return playlists.map { ($0, byID[$0.id ?? -1] ?? 0) }
        }
    }
}
