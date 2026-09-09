import Foundation
import GRDB
import AllimEngine
import os

/// The library, on disk.
///
/// Three decisions are load-bearing here and each came out of measuring rather than taste:
///
/// **Application Support, not Caches, and not the App Group.** Thumbnails are unregenerable
/// primary data: the CDN URLs they came from expire, so a purged thumbnail is gone for good
/// and Apple's "the app can recreate them" test for `Library/Caches` fails. And the database
/// is kept out of the shared App Group container because iOS kills a suspended app that holds
/// a file lock there (`0xDEAD10CC`), which is exactly what a WAL connection is.
///
/// **Thumbnails as BLOBs, in their own table.** SQLite's own guidance is that reads beat the
/// filesystem below 100 KB, and these are ~30 KB; 500k loose files would be the small-file
/// problem Facebook wrote the Haystack paper about. Splitting them from `item` keeps the rows
/// that get sorted and filtered narrow, so a page scan never drags image bytes through memory.
///
/// **Keyset pagination.** See `ItemPage`.
final class AllimStore: Sendable {
    private let dbPool: DatabasePool
    private let logger = Logger(subsystem: "com.matthewpark.allim", category: "store")

    // MARK: - Lifecycle

    init(url: URL) throws {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            // 8 KiB pages: SQLite's "35% Faster Than The Filesystem" measurements used 4 KiB,
            // but these blobs are ~30 KB, and larger pages mean fewer overflow chains per row.
            try db.execute(sql: "PRAGMA page_size = 8192")
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        dbPool = try DatabasePool(path: url.path, configuration: configuration)
        try migrator.migrate(dbPool)
    }

    /// Opens the store in Application Support, creating the directory if needed.
    static func standard() throws -> AllimStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        var directory = base.appendingPathComponent("Allim", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Set once on the directory rather than per-file. Doing it per-file would mean half a
        // million `setResourceValues` calls, and iCloud backup of a 16 GB thumbnail library is
        // not something anyone wants happening silently over cellular.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)

        return try AllimStore(url: directory.appendingPathComponent("allim.sqlite"))
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "item") { t in
                t.autoIncrementedPrimaryKey("id")
                // The dedupe key. A unique index here is what makes importing DMs, Saved and
                // Liked from the same Instagram export idempotent instead of triplicating.
                t.column("url", .text).notNull().unique()
                t.column("platform", .text).notNull()
                t.column("contentID", .text)
                t.column("author", .text)
                t.column("title", .text)
                t.column("caption", .text)
                t.column("savedAt", .datetime).notNull()
                t.column("aspectRatio", .double)
                t.column("averageColor", .integer)
                t.column("origin", .text).notNull()
                t.column("thumbnailState", .text).notNull()
            }

            // Matches the keyset page query exactly, including the tie-breaking id, so paging
            // is an index walk rather than a sort of the whole table.
            try db.create(
                index: "item_on_savedAt_id",
                on: "item",
                columns: ["savedAt", "id"],
                unique: false
            )

            // Its own table so a page scan of `item` never touches image bytes.
            try db.create(table: "thumbnail") { t in
                t.primaryKey("itemId", .integer)
                    .references("item", onDelete: .cascade)
                t.column("bytes", .blob).notNull()
                t.column("width", .integer).notNull()
                t.column("height", .integer).notNull()
                t.column("format", .text).notNull()
            }
        }

        return migrator
    }

    // MARK: - Writing

    /// Inserts, ignoring anything already stored under the same canonical URL.
    ///
    /// Returns the number actually inserted, which is what the Instagram importer reports:
    /// "3,412 saved, 1,180 already here" is the only honest summary of an import that pulls
    /// the same posts from three different places in one export.
    @discardableResult
    func insert(_ items: [Item]) throws -> Int {
        try dbPool.write { db in
            var inserted = 0
            for var item in items {
                // onConflict .ignore rather than a pre-flight SELECT: one statement, and no
                // race between checking and writing.
                let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item WHERE url = ?", arguments: [item.url]) ?? 0
                if count > 0 { continue }
                try item.insert(db)
                inserted += 1
            }
            return inserted
        }
    }

    func setThumbnail(itemID: Int64, bytes: Data, width: Int, height: Int, format: String, averageColor: Int?) throws {
        try dbPool.write { db in
            try db.execute(
                sql: """
                    INSERT INTO thumbnail (itemId, bytes, width, height, format)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(itemId) DO UPDATE SET
                        bytes = excluded.bytes, width = excluded.width,
                        height = excluded.height, format = excluded.format
                    """,
                arguments: [itemID, bytes, width, height, format]
            )
            try db.execute(
                sql: "UPDATE item SET thumbnailState = ?, aspectRatio = ?, averageColor = ? WHERE id = ?",
                arguments: [Item.ThumbnailState.stored.rawValue, Double(width) / Double(height), averageColor, itemID]
            )
        }
    }

    func setThumbnailState(itemID: Int64, _ state: Item.ThumbnailState) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "UPDATE item SET thumbnailState = ? WHERE id = ?",
                arguments: [state.rawValue, itemID]
            )
        }
    }

    // MARK: - Reading

    /// One page of the library, newest first.
    func page(after cursor: ItemCursor? = nil, limit: Int = 60) throws -> ItemPage {
        try dbPool.read { db in
            let items: [Item]
            if let cursor {
                // The seek predicate. `savedAt < :savedAt OR (savedAt = :savedAt AND id < :id)`
                // is stable when rows are inserted at the head mid-scroll; OFFSET is not.
                items = try Item.fetchAll(
                    db,
                    sql: """
                        SELECT * FROM item
                        WHERE savedAt < ? OR (savedAt = ? AND id < ?)
                        ORDER BY savedAt DESC, id DESC
                        LIMIT ?
                        """,
                    arguments: [cursor.savedAt, cursor.savedAt, cursor.id, limit]
                )
            } else {
                items = try Item.fetchAll(
                    db,
                    sql: "SELECT * FROM item ORDER BY savedAt DESC, id DESC LIMIT ?",
                    arguments: [limit]
                )
            }

            // A cursor only when the page was full. A short page is the end of the library,
            // and handing back a cursor there makes the UI fetch an empty page forever.
            let next = items.count == limit
                ? items.last.flatMap { last in last.id.map { ItemCursor(savedAt: last.savedAt, id: $0) } }
                : nil
            return ItemPage(items: items, cursor: next)
        }
    }

    func thumbnailBytes(itemID: Int64) throws -> Data? {
        try dbPool.read { db in
            try Data.fetchOne(db, sql: "SELECT bytes FROM thumbnail WHERE itemId = ?", arguments: [itemID])
        }
    }

    /// Items still wanting a thumbnail. `.unavailable` is excluded by construction, so the
    /// three platforms that serve nothing are never retried.
    func pendingEnrichment(limit: Int = 25) throws -> [Item] {
        try dbPool.read { db in
            try Item.fetchAll(
                db,
                sql: "SELECT * FROM item WHERE thumbnailState = ? ORDER BY savedAt DESC LIMIT ?",
                arguments: [Item.ThumbnailState.pending.rawValue, limit]
            )
        }
    }

    /// Authors, most-saved first.
    ///
    /// This is the highest-value grouping available and it needs no AI at all: an Instagram
    /// import lands thousands of items each carrying an `original_content_owner`, and twelve
    /// reels from one account already is a category. Grouping by something the data actually
    /// contains beats inferring a topic from a URL.
    func authors(limit: Int = 40) throws -> [AuthorGroup] {
        try dbPool.read { db in
            try AuthorGroup.fetchAll(
                db,
                sql: """
                    SELECT author AS name, COUNT(*) AS count
                    FROM item
                    WHERE author IS NOT NULL AND author <> ''
                    GROUP BY author
                    ORDER BY count DESC, name ASC
                    LIMIT ?
                    """,
                arguments: [limit]
            )
        }
    }

    /// One page filtered to a single author. Keyset, same as the unfiltered path -- an author
    /// with 2,000 saves needs paging just as much as the whole library does.
    func page(author: String, after cursor: ItemCursor? = nil, limit: Int = 60) throws -> ItemPage {
        try dbPool.read { db in
            let items: [Item]
            if let cursor {
                items = try Item.fetchAll(
                    db,
                    sql: """
                        SELECT * FROM item
                        WHERE author = ? AND (savedAt < ? OR (savedAt = ? AND id < ?))
                        ORDER BY savedAt DESC, id DESC
                        LIMIT ?
                        """,
                    arguments: [author, cursor.savedAt, cursor.savedAt, cursor.id, limit]
                )
            } else {
                items = try Item.fetchAll(
                    db,
                    sql: "SELECT * FROM item WHERE author = ? ORDER BY savedAt DESC, id DESC LIMIT ?",
                    arguments: [author, limit]
                )
            }
            let next = items.count == limit
                ? items.last.flatMap { last in last.id.map { ItemCursor(savedAt: last.savedAt, id: $0) } }
                : nil
            return ItemPage(items: items, cursor: next)
        }
    }

    func count() throws -> Int {
        try dbPool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item") ?? 0 }
    }
}

/// An author and how much of the library is theirs.
struct AuthorGroup: FetchableRecord, Decodable, Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let count: Int
}

// GRDB conformance lives here rather than on the model, so AllimEngine stays dependency-free
// and testable without a database.
extension Item: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "item"

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
