import Foundation
import GRDB
import QuokkaEngine
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
final class QuokkaStore: Sendable {
    let dbPool: DatabasePool
    private let logger = Logger(subsystem: "com.matthewpark.quokka", category: "store")

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
    static func standard() throws -> QuokkaStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        var directory = base.appendingPathComponent("Quokka", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Set once on the directory rather than per-file. Doing it per-file would mean half a
        // million `setResourceValues` calls, and iCloud backup of a 16 GB thumbnail library is
        // not something anyone wants happening silently over cellular.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)

        return try QuokkaStore(url: directory.appendingPathComponent("quokka.sqlite"))
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

        migrator.registerMigration("v2-tags") { db in
            // A JSON array in a text column. Additive, so an existing library migrates without
            // touching a row.
            try db.alter(table: "item") { t in
                t.add(column: "tags", .text)
            }
        }

        migrator.registerMigration("v3-retries") { db in
            try db.alter(table: "item") { t in
                t.add(column: "enrichAttempts", .integer).notNull().defaults(to: 0)
            }
        }

        migrator.registerMigration("v4-playlists") { db in
            try db.create(table: "playlist") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("note", .text)
                t.column("coverItemID", .integer)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v5-ideas") { db in
            try db.create(table: "idea") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("title", .text).notNull()
                t.column("body", .text).notNull().defaults(to: "")
                t.column("hook", .text)
                t.column("transcript", .text)
                // Nullable, and ON DELETE SET NULL rather than CASCADE: deleting a playlist
                // must not destroy the work inside it. The ideas become loose, not gone.
                t.column("playlistID", .integer).references("playlist", onDelete: .setNull)
                t.column("status", .text).notNull().defaults(to: Idea.Status.todo.rawValue)
                t.column("createdAt", .datetime).notNull()
                t.column("modifiedAt", .datetime).notNull()
            }
            try db.create(index: "idea_on_playlist", on: "idea", columns: ["playlistID", "modifiedAt"])

            // A join, because an idea cites several videos and a video inspires several ideas.
            // The composite primary key is what makes adding the same reel twice a no-op.
            try db.create(table: "idea_source") { t in
                t.column("ideaID", .integer).notNull().references("idea", onDelete: .cascade)
                t.column("itemID", .integer).notNull().references("item", onDelete: .cascade)
                t.column("position", .integer).notNull().defaults(to: 0)
                t.primaryKey(["ideaID", "itemID"])
            }
        }

        migrator.registerMigration("v6-sample-flag") { db in
            try db.alter(table: "idea") { t in
                t.add(column: "isSample", .boolean).notNull().defaults(to: false)
            }
        }

        migrator.registerMigration("v7-journal") { db in
            // One row per day, keyed by a yyyy-MM-dd string rather than a timestamp.
            //
            // A date is what the screen actually asks about -- "what did I write on the 5th" --
            // and keying by timestamp would make that a range query that has to reason about
            // the device's timezone at write time versus read time.
            try db.create(table: "journal") { t in
                t.primaryKey("day", .text)
                t.column("text", .text).notNull()
                t.column("modifiedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v8-transcripts") { db in
            // The result. One row per item, because a second transcript of the same video
            // would be the same words -- there is nothing to version.
            try db.create(table: "item_transcript") { t in
                t.primaryKey("itemID", .integer).references("item", onDelete: .cascade)
                t.column("text", .text).notNull()
                // JSON, in a text column, for the same reason tags are: segments are only
                // ever read alongside their transcript and written as a complete set, so a
                // second table would add a join to support a normalisation nothing needs.
                t.column("segments", .text)
                t.column("locale", .text)
                // Which rung answered. On the row rather than inferred later, because it is
                // what lets the app say how a transcript was obtained -- and `hosted` is the
                // one that means a URL left the device.
                t.column("source", .text).notNull()
                t.column("producedAt", .datetime).notNull()
            }

            // The work queue. Separate from the result so a finished transcript is not
            // carrying dead scheduling columns for the life of the library.
            try db.create(table: "transcript_job") { t in
                t.primaryKey("itemID", .integer).references("item", onDelete: .cascade)
                // Absolute path to a staged video, when the share carried a file. Persisted
                // rather than held in memory because the app can be killed between the save
                // and the transcription, and a file nobody remembers is a file nobody deletes.
                t.column("mediaPath", .text)
                t.column("attempts", .integer).notNull().defaults(to: 0)
                // The last reason, kept so a permanent failure can be shown rather than
                // retried. A private post will never resolve, and saying so beats three more
                // attempts and silence.
                t.column("lastFailure", .text)
                t.column("queuedAt", .datetime).notNull()
            }
            try db.create(index: "idx_job_queuedAt", on: "transcript_job", columns: ["queuedAt"])
        }

        migrator.registerMigration("v9-playlist-items") { db in
            // Items straight onto a playlist, without inventing an Idea first.
            //
            // Until now a playlist reached its videos through its ideas, which is right when
            // the playlist exists to produce scripts and wrong for the thing people actually
            // do first: drop thirty saved reels into "Wellness" and ask what is in them. An
            // idea per video to express that is bookkeeping nobody asked for.
            try db.create(table: "playlist_item") { t in
                t.column("playlistID", .integer).notNull().references("playlist", onDelete: .cascade)
                t.column("itemID", .integer).notNull().references("item", onDelete: .cascade)
                t.column("position", .integer).notNull().defaults(to: 0)
                t.primaryKey(["playlistID", "itemID"])
            }

            // The digest of everything in the playlist. Separate from `note`, which is the
            // user's own text -- overwriting what someone wrote by hand with something a
            // model produced is the kind of data loss that is never worth the saved column.
            try db.alter(table: "playlist") { t in
                t.add(column: "summary", .text)
                // Nil means never summarised. Compared against the playlist's updatedAt to
                // tell "no summary" from "summary is behind the contents".
                t.add(column: "summarisedAt", .datetime)
            }
        }

        migrator.registerMigration("v10-pinterest-thumbnails") { db in
            // Pins saved before Pinterest's oEmbed was found were stored terminal, because
            // the platform was then believed to serve nothing. Putting them back in the queue
            // is what turns a library's worth of pin text cards into pictures on next launch.
            try db.execute(sql: """
                UPDATE item SET thumbnailState = 'pending', enrichAttempts = 0
                WHERE platform = 'pinterest' AND thumbnailState = 'unavailable'
                """)
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
                // Resets the attempt counter: a success means whatever was wrong is no longer
                // wrong, and a later failure deserves its own full budget of retries.
                sql: "UPDATE item SET thumbnailState = ?, aspectRatio = ?, averageColor = ?, enrichAttempts = 0 WHERE id = ?",
                arguments: [Item.ThumbnailState.stored.rawValue, Double(width) / Double(height), averageColor, itemID]
            )
        }
    }

    /// Tags for one item, replacing whatever was there.
    ///
    /// Stored as a JSON array in a text column rather than a join table. Tags are only ever
    /// read alongside their item and written as a complete set, so a second table would add a
    /// join to every read to support a normalisation nothing here benefits from.
    func setTags(itemID: Int64, _ tags: [String]) throws {
        let encoded = String(decoding: (try? JSONEncoder().encode(tags)) ?? Data("[]".utf8), as: UTF8.self)
        try dbPool.write { db in
            try db.execute(sql: "UPDATE item SET tags = ? WHERE id = ?", arguments: [encoded, itemID])
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

    /// How many times a thumbnail fetch is retried before the item is left alone.
    static let maxEnrichAttempts = 3

    /// Items still wanting a thumbnail.
    ///
    /// Includes `.failed` while it is under the retry ceiling: a transient network failure
    /// should not cost a tile its picture permanently, which is what happened when only
    /// `.pending` was ever re-queued. `.unavailable` is excluded by construction, so the three
    /// platforms that serve nothing are never retried at all.
    func pendingEnrichment(limit: Int = 25) throws -> [Item] {
        try dbPool.read { db in
            try Item.fetchAll(
                db,
                sql: """
                    SELECT * FROM item
                    WHERE thumbnailState = ?
                       OR (thumbnailState = ? AND enrichAttempts < ?)
                    ORDER BY savedAt DESC
                    LIMIT ?
                    """,
                arguments: [
                    Item.ThumbnailState.pending.rawValue,
                    Item.ThumbnailState.failed.rawValue,
                    Self.maxEnrichAttempts,
                    limit,
                ]
            )
        }
    }

    /// Marks a failed attempt, counting it so the retry is bounded.
    func recordEnrichFailure(itemID: Int64) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "UPDATE item SET thumbnailState = ?, enrichAttempts = enrichAttempts + 1 WHERE id = ?",
                arguments: [Item.ThumbnailState.failed.rawValue, itemID]
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

    /// A handful of items per author, for building a mosaic cover.
    ///
    /// Prefers items that actually have a thumbnail: a cover made of four blank text cards
    /// tells you nothing about what is inside, which defeats the point of a cover.
    func coverItems(author: String, limit: Int = 4) throws -> [Item] {
        try dbPool.read { db in
            try Item.fetchAll(
                db,
                sql: """
                    SELECT * FROM item
                    WHERE author = ?
                    ORDER BY (thumbnailState = 'stored') DESC, savedAt DESC
                    LIMIT ?
                    """,
                arguments: [author, limit]
            )
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

// GRDB conformance lives here rather than on the model, so QuokkaEngine stays dependency-free
// and testable without a database.
extension Item: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "item"

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
