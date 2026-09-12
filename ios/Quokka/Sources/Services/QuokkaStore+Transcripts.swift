import Foundation
import GRDB
import QuokkaEngine

/// The transcript queue's storage.
///
/// Split from `QuokkaStore` rather than added to it because that file is already the largest
/// in the app and this is a self-contained concern with its own two tables.
extension QuokkaStore {

    /// How many times a transcript is attempted before the item is left alone.
    ///
    /// The same bounded-retry reasoning as thumbnails: a network blip should not cost a video
    /// its transcript forever, and a private post should not be retried on every launch until
    /// the end of time. Three attempts tells those apart without anyone having to classify
    /// the failure.
    static let transcriptAttemptLimit = 3

    struct TranscriptJob: Sendable, Equatable {
        let itemID: Int64
        let mediaPath: String?
        let attempts: Int
    }

    /// One item by id.
    ///
    /// The queue needs a row's URL, platform and content ID to build a request, and the paging
    /// reads cannot answer for a single id without scanning.
    func item(id: Int64) throws -> Item? {
        try dbPool.read { db in
            try Item.fetchOne(db, sql: "SELECT * FROM item WHERE id = ?", arguments: [id])
        }
    }

    /// The stored id for a canonical URL.
    ///
    /// Needed because an insert that deduped against an existing row returns no id, and the
    /// transcript belongs on the row that survived rather than on one that was never written.
    func itemID(forURL url: String) throws -> Int64? {
        try dbPool.read { db in
            try Int64.fetchOne(db, sql: "SELECT id FROM item WHERE url = ?", arguments: [url])
        }
    }

    // MARK: - Queue

    /// Queues an item for transcription, or updates the staged file of one already queued.
    ///
    /// `INSERT .. ON CONFLICT DO UPDATE` rather than a check and a write: the share extension
    /// and a foreground drain can both land on the same item, and a pre-flight SELECT leaves a
    /// window where both decide to insert.
    func enqueueTranscript(itemID: Int64, mediaPath: String? = nil) throws {
        try dbPool.write { db in
            try db.execute(
                sql: """
                    INSERT INTO transcript_job (itemID, mediaPath, attempts, queuedAt)
                    VALUES (?, ?, 0, ?)
                    ON CONFLICT(itemID) DO UPDATE SET
                        mediaPath = COALESCE(excluded.mediaPath, transcript_job.mediaPath)
                    """,
                arguments: [itemID, mediaPath, Date()])
        }
    }

    /// The oldest jobs still worth trying.
    ///
    /// Ordered by `queuedAt` so a save made ten minutes ago is not starved by one made now,
    /// and filtered against `item_transcript` so an item that already has words is never
    /// picked up again.
    func pendingTranscriptJobs(limit: Int = 5) throws -> [TranscriptJob] {
        try dbPool.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT j.itemID, j.mediaPath, j.attempts
                    FROM transcript_job j
                    LEFT JOIN item_transcript t ON t.itemID = j.itemID
                    WHERE t.itemID IS NULL AND j.attempts < ?
                    ORDER BY j.queuedAt ASC
                    LIMIT ?
                    """,
                arguments: [Self.transcriptAttemptLimit, limit]
            ).map {
                TranscriptJob(itemID: $0["itemID"], mediaPath: $0["mediaPath"], attempts: $0["attempts"])
            }
        }
    }

    // MARK: - Results

    func setTranscript(itemID: Int64, _ transcript: Transcript) throws {
        let segments = (try? JSONEncoder().encode(transcript.segments)).map {
            String(decoding: $0, as: UTF8.self)
        }
        try dbPool.write { db in
            try db.execute(
                sql: """
                    INSERT INTO item_transcript (itemID, text, segments, locale, source, producedAt)
                    VALUES (?, ?, ?, ?, ?, ?)
                    ON CONFLICT(itemID) DO UPDATE SET
                        text = excluded.text, segments = excluded.segments,
                        locale = excluded.locale, source = excluded.source,
                        producedAt = excluded.producedAt
                    """,
                arguments: [
                    itemID, transcript.text, segments, transcript.locale,
                    transcript.source.rawValue, transcript.producedAt,
                ])
            // The job is done, so it goes. Leaving it would mean the queue grows with the
            // library and every poll scans rows that can never be picked.
            try db.execute(sql: "DELETE FROM transcript_job WHERE itemID = ?", arguments: [itemID])
        }
    }

    /// Records a failure and burns one attempt.
    func failTranscript(itemID: Int64, reason: String) throws {
        try dbPool.write { db in
            try db.execute(
                sql: """
                    UPDATE transcript_job
                    SET attempts = attempts + 1, lastFailure = ?
                    WHERE itemID = ?
                    """,
                arguments: [reason, itemID])
        }
    }

    func transcript(forItem itemID: Int64) throws -> Transcript? {
        try dbPool.read { db in
            guard let row = try Row.fetchOne(
                db, sql: "SELECT * FROM item_transcript WHERE itemID = ?", arguments: [itemID])
            else { return nil }
            return Self.decodeTranscript(row)
        }
    }

    /// The last reason a transcript could not be produced, once the attempts are spent.
    ///
    /// Nil while there are attempts left. A failure that is still going to be retried is not
    /// something to put in front of someone -- it is a state the app should resolve itself.
    func exhaustedTranscriptFailure(forItem itemID: Int64) throws -> String? {
        try dbPool.read { db in
            try String.fetchOne(
                db,
                sql: """
                    SELECT lastFailure FROM transcript_job
                    WHERE itemID = ? AND attempts >= ?
                    """,
                arguments: [itemID, Self.transcriptAttemptLimit])
        }
    }

    private static func decodeTranscript(_ row: Row) -> Transcript? {
        guard let source = TranscriptSource(rawValue: row["source"]) else { return nil }
        let segments: [Transcript.Segment] = (row["segments"] as String?)
            .flatMap { try? JSONDecoder().decode([Transcript.Segment].self, from: Data($0.utf8)) }
            ?? []
        return Transcript(
            text: row["text"],
            segments: segments,
            locale: row["locale"],
            source: source,
            producedAt: row["producedAt"])
    }
}
