import Foundation
import QuokkaEngine
import os

/// Writes the library to a file Claude Code can read, and reads back what it writes.
///
/// This is how Quokka connects to Claude with **no API key and no per-save cost**: it runs on
/// the Claude Code subscription already on the machine rather than billing an Anthropic key
/// embedded in an app bundle.
///
/// The transport is a file, not a server, because an iOS app cannot hand a Mac process a
/// SQLite handle and neither end should have to run a service. iCloud Drive does the syncing;
/// on the Mac the container is an ordinary folder.
///
/// JSONL rather than one JSON document: a half-million-line file appends in constant time and
/// streams line by line, where a single array has to be parsed whole on both ends.
struct LibraryMirror {
    private let logger = Logger(subsystem: "com.matthewpark.quokka", category: "mirror")

    static let libraryFile = "library.jsonl"
    static let tagsFile = "tags.jsonl"
    static let playlistsFile = "playlists.jsonl"
    static let summariesFile = "summaries.jsonl"

    /// The iCloud container when it is available, the app's own Documents when it is not.
    ///
    /// Falling back rather than failing is deliberate. The iCloud entitlement needs the
    /// capability enabled on the App ID, which is a portal change and not always in place; a
    /// mirror in Documents is still reachable over AirDrop and through Files, so the feature
    /// degrades from "syncs by itself" to "you move one file" instead of vanishing.
    static func directory(fileManager: FileManager = .default) -> (url: URL, synced: Bool)? {
        if let ubiquity = fileManager.url(forUbiquityContainerIdentifier: nil) {
            let documents = ubiquity.appendingPathComponent("Documents", isDirectory: true)
            try? fileManager.createDirectory(at: documents, withIntermediateDirectories: true)
            return (documents, true)
        }
        guard let local = try? fileManager.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        return (local, false)
    }

    // MARK: - Writing

    /// Rewrites the whole mirror.
    ///
    /// A full rewrite rather than an append: the library is small in text terms -- roughly
    /// 200 bytes a row, so 500,000 items is about 100 MB and a realistic library is a few
    /// megabytes -- and a rewrite cannot drift out of sync with the database the way an
    /// incremental append eventually does.
    func write(_ items: [Item], transcripts: [Int64: String] = [:]) {
        guard let (directory, synced) = Self.directory() else {
            logger.error("No writable mirror directory")
            return
        }
        let url = directory.appendingPathComponent(Self.libraryFile)

        var text = ""
        text.reserveCapacity(items.count * 220)
        let encoder = ShareInbox.encoder
        // One object per line, so the file streams. Pretty-printing would defeat that.
        encoder.outputFormatting = [.sortedKeys]

        for item in items {
            guard let data = try? encoder.encode(MirrorRow(item, transcript: item.id.flatMap { transcripts[$0] })),
                  let line = String(data: data, encoding: .utf8)
            else { continue }
            text += line + "\n"
        }

        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            logger.info("Mirrored \(items.count) items (\(synced ? "iCloud" : "local"))")
        } catch {
            logger.error("Mirror write failed: \(error.localizedDescription)")
        }
    }

    /// The playlists, each with the items in it.
    ///
    /// A separate file rather than a field on the library rows. An item can be in several
    /// playlists, so putting the relationship on the item would repeat it, and the reader
    /// wanting "what is in Wellness" would have to scan the entire library to answer.
    func writePlaylists(_ playlists: [PlaylistMirror]) {
        guard let (directory, _) = Self.directory() else { return }
        let url = directory.appendingPathComponent(Self.playlistsFile)

        let encoder = ShareInbox.encoder
        encoder.outputFormatting = [.sortedKeys]

        var text = ""
        for playlist in playlists {
            guard let data = try? encoder.encode(playlist),
                  let line = String(data: data, encoding: .utf8)
            else { continue }
            text += line + "\n"
        }
        try? text.write(to: url, atomically: true, encoding: .utf8)
        logger.info("Mirrored \(playlists.count) playlists")
    }

    /// One playlist as the mirror publishes it.
    struct PlaylistMirror: Codable {
        let id: Int64
        let name: String
        let note: String?
        let itemCount: Int
        let summary: String?
        let summaryIsStale: Bool
        /// The ids of the items in it. The rows themselves live in `library.jsonl`, keyed by
        /// the same id -- repeating them here would double a large file for no gain.
        let itemIDs: [Int64]
    }

    /// Applies summaries Claude wrote, then clears the file.
    ///
    /// Same queue-not-a-source-of-truth discipline as tags: the file is work that has been
    /// done, and clearing it is what makes running this on every launch safe.
    func ingestSummaries(applying: (Int64, String) -> Void) -> Int {
        guard let (directory, _) = Self.directory() else { return 0 }
        let url = directory.appendingPathComponent(Self.summariesFile)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return 0 }

        var applied = 0
        for line in text.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let row = try? JSONDecoder().decode(SummaryRow.self, from: data),
                  !row.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }
            applying(row.playlistID, row.summary)
            applied += 1
        }

        if applied > 0 {
            try? FileManager.default.removeItem(at: url)
            logger.info("Applied \(applied) summaries and cleared the queue")
        }
        return applied
    }

    // MARK: - Reading tags back

    /// Applies tags Claude wrote, then clears the file.
    ///
    /// Clearing is what makes this safe to run on every launch: the file is a queue of work
    /// that has been done, not a second source of truth competing with the database.
    func ingestTags(applying: (Int64, [String]) -> Void) -> Int {
        guard let (directory, _) = Self.directory() else { return 0 }
        let url = directory.appendingPathComponent(Self.tagsFile)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return 0 }

        var applied = 0
        for line in text.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let row = try? JSONDecoder().decode(TagRow.self, from: data)
            else { continue }
            applying(row.id, row.tags)
            applied += 1
        }

        if applied > 0 {
            try? FileManager.default.removeItem(at: url)
            logger.info("Applied \(applied) tag rows and cleared the queue")
        }
        return applied
    }

    // MARK: - Wire format

    /// Deliberately not `Item` itself. The mirror is a published interface read by a separate
    /// program, so it gets its own shape that can stay stable while the stored model changes.
    private struct MirrorRow: Codable {
        let id: Int64?
        let url: String
        let platform: String
        let author: String?
        let title: String?
        let caption: String?
        let savedAt: Date
        let origin: String
        let hasImage: Bool
        /// What was actually said in the video, when it has been transcribed.
        ///
        /// The single most valuable field in the file. Captions are marketing and titles are
        /// often the URL; the transcript is the only place the *content* lives, so searching
        /// it is the difference between "find the reel called something about lighting" and
        /// "find the reel where someone explained three-point lighting".
        let transcript: String?

        init(_ item: Item, transcript: String? = nil) {
            self.transcript = transcript
            id = item.id
            url = item.url
            platform = item.platform.rawValue
            author = item.author
            title = item.title
            caption = item.caption
            savedAt = item.savedAt
            origin = item.origin.rawValue
            hasImage = item.thumbnailState == .stored
        }
    }

    private struct TagRow: Decodable {
        let id: Int64
        let tags: [String]
    }

    private struct SummaryRow: Decodable {
        let playlistID: Int64
        let summary: String
    }
}
