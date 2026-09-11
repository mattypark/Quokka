import Foundation
import GRDB
import AllimEngine

/// Playlists and ideas, on top of the same database as the library.
///
/// A separate file rather than more methods on `AllimStore`: that type is already the largest
/// in the app, and these are a different concern -- the library is things you collected,
/// these are things you are making. They share a `DatabasePool` because they are one database
/// and two connections to the same SQLite file is how you get a lock contention bug.
extension AllimStore {

    // MARK: - Playlists

    @discardableResult
    func createPlaylist(name: String, note: String? = nil) throws -> Playlist {
        var playlist = Playlist(name: name, note: note)
        try dbPool.write { db in try playlist.insert(db) }
        return playlist
    }

    func playlists() throws -> [PlaylistSummary] {
        try dbPool.read { db in
            // The idea count comes from a join rather than a stored counter. A denormalised
            // count is one more thing that can disagree with the table it summarises, and this
            // is an indexed lookup rather than a scan.
            try PlaylistSummary.fetchAll(
                db,
                sql: """
                    SELECT playlist.*, COUNT(idea.id) AS ideaCount
                    FROM playlist
                    LEFT JOIN idea ON idea.playlistID = playlist.id
                    GROUP BY playlist.id
                    ORDER BY playlist.updatedAt DESC
                    """
            )
        }
    }

    func playlist(id: Int64) throws -> Playlist? {
        try dbPool.read { db in try Playlist.fetchOne(db, key: id) }
    }

    func renamePlaylist(id: Int64, to name: String) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "UPDATE playlist SET name = ?, updatedAt = ? WHERE id = ?",
                arguments: [name, Date(), id]
            )
        }
    }

    func deletePlaylist(id: Int64) throws {
        try dbPool.write { db in
            // Ideas survive their playlist rather than being cascaded away. Deleting a folder
            // should not destroy the work inside it -- they become loose ideas.
            try db.execute(sql: "UPDATE idea SET playlistID = NULL WHERE playlistID = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM playlist WHERE id = ?", arguments: [id])
        }
    }

    // MARK: - Ideas

    @discardableResult
    func createIdea(title: String, playlistID: Int64? = nil, body: String = "") throws -> Idea {
        var idea = Idea(title: title, body: body, playlistID: playlistID)
        try dbPool.write { db in
            try idea.insert(db)
            if let playlistID { try Self.touch(playlist: playlistID, in: db) }
        }
        return idea
    }

    func ideas(inPlaylist playlistID: Int64) throws -> [Idea] {
        try dbPool.read { db in
            try Idea.fetchAll(
                db,
                sql: "SELECT * FROM idea WHERE playlistID = ? ORDER BY modifiedAt DESC",
                arguments: [playlistID]
            )
        }
    }

    func ideas(status: Idea.Status? = nil, limit: Int = 100) throws -> [Idea] {
        try dbPool.read { db in
            if let status {
                return try Idea.fetchAll(
                    db,
                    sql: "SELECT * FROM idea WHERE status = ? ORDER BY modifiedAt DESC LIMIT ?",
                    arguments: [status.rawValue, limit]
                )
            }
            return try Idea.fetchAll(
                db,
                sql: "SELECT * FROM idea ORDER BY modifiedAt DESC LIMIT ?",
                arguments: [limit]
            )
        }
    }

    func save(_ idea: Idea) throws {
        var updated = idea
        updated.modifiedAt = Date()
        try dbPool.write { db in
            try updated.update(db)
            if let playlistID = updated.playlistID { try Self.touch(playlist: playlistID, in: db) }
        }
    }

    func deleteIdea(id: Int64) throws {
        try dbPool.write { db in try db.execute(sql: "DELETE FROM idea WHERE id = ?", arguments: [id]) }
    }

    // MARK: - What an idea was built from

    func addSource(itemID: Int64, to ideaID: Int64) throws {
        try dbPool.write { db in
            // Position lands at the end. INSERT OR IGNORE against the composite key means
            // adding the same reel twice is a no-op rather than two tiles of one video.
            let next = try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(MAX(position), -1) + 1 FROM idea_source WHERE ideaID = ?",
                arguments: [ideaID]
            ) ?? 0
            try db.execute(
                sql: "INSERT OR IGNORE INTO idea_source (ideaID, itemID, position) VALUES (?, ?, ?)",
                arguments: [ideaID, itemID, next]
            )
        }
    }

    func removeSource(itemID: Int64, from ideaID: Int64) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "DELETE FROM idea_source WHERE ideaID = ? AND itemID = ?",
                arguments: [ideaID, itemID]
            )
        }
    }

    /// The videos behind an idea, in the order they were arranged.
    func sources(for ideaID: Int64) throws -> [Item] {
        try dbPool.read { db in
            try Item.fetchAll(
                db,
                sql: """
                    SELECT item.* FROM item
                    JOIN idea_source ON idea_source.itemID = item.id
                    WHERE idea_source.ideaID = ?
                    ORDER BY idea_source.position ASC
                    """,
                arguments: [ideaID]
            )
        }
    }

    /// Bumps a playlist's timestamp so "Updated 2hr ago" means what it says.
    private static func touch(playlist id: Int64, in db: Database) throws {
        try db.execute(sql: "UPDATE playlist SET updatedAt = ? WHERE id = ?", arguments: [Date(), id])
    }
}

/// A playlist plus the count the subtitle needs, fetched in one query rather than N+1.
struct PlaylistSummary: FetchableRecord, Decodable, Identifiable, Equatable {
    var id: Int64?
    var name: String
    var note: String?
    var coverItemID: Int64?
    var createdAt: Date
    var updatedAt: Date
    var ideaCount: Int

    var playlist: Playlist {
        Playlist(id: id, name: name, note: note, coverItemID: coverItemID,
                 createdAt: createdAt, updatedAt: updatedAt)
    }
}

extension Playlist: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "playlist"
    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

extension Idea: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "idea"
    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
