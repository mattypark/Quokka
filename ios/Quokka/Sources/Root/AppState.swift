import Foundation
import Observation
import QuokkaEngine
import os

@MainActor
@Observable
final class AppState {
    private(set) var items: [Item] = []
    private(set) var total = 0
    private(set) var authors: [AuthorGroup] = []
    /// nil means the whole library. Set to filter to one author.
    private(set) var selectedAuthor: String?
    /// Set when the store cannot be opened. Surfaced rather than swallowed: a library that
    /// silently stops persisting looks exactly like a library with nothing in it.
    private(set) var storeFailure: String?

    /// The probe readouts from the most recent drain, kept only in memory. They answer a
    /// build-time question about what each app hands the share sheet; they are not library
    /// data and have no business in the database.
    private(set) var lastProbe: [InboxDrain.Drained] = []

    private let inbox = InboxDrain()
    private let mirror = LibraryMirror()
    let logger = Logger(subsystem: "com.matthewpark.quokka", category: "state")
    private(set) var store: QuokkaStore?
    private var fetcher: ThumbnailFetcher?
    private var transcripts: TranscriptQueue?
    private(set) var loader: ThumbnailLoader?
    private var cursor: ItemCursor?
    private var enrichment: Task<Void, Never>?
    private var transcription: Task<Void, Never>?

    init() {
        do {
            let store = try QuokkaStore.standard()
            self.store = store
            fetcher = ThumbnailFetcher(store: store)
            transcripts = TranscriptQueue(store: store)
            loader = ThumbnailLoader(store: store)
        } catch {
            storeFailure = error.localizedDescription
            logger.error("Could not open the store: \(error.localizedDescription)")
        }
    }

    /// Called on launch and every foreground. The share extension writes while the app is not
    /// running, so this is the only moment saves actually arrive.
    func drainInbox() {
        let drained = inbox.drain()
        lastProbe = drained.filter { !$0.probe.isEmpty }

        // A share that carried a video and no link used to be dropped here, which made rung 0
        // -- the free, private, unbreakable one -- unreachable in practice. It gets a
        // synthesised URL so it can be a row like anything else; the dedupe key stays unique
        // because it is a fresh UUID per save.
        let saves: [(item: Item, movie: URL?)] = drained.compactMap { record in
            if let link = record.link {
                return (Item(link: link, savedAt: record.receivedAt, origin: .shareSheet), record.movieURL)
            }
            guard let movie = record.movieURL else { return nil }
            return (
                Item(
                    url: "quokka://movie/\(record.id.uuidString)",
                    platform: .web,
                    title: movie.deletingPathExtension().lastPathComponent,
                    savedAt: record.receivedAt,
                    origin: .shareSheet,
                    // Nothing will ever fetch a thumbnail for a local file, so it starts
                    // terminal rather than sitting in the enrichment queue forever.
                    thumbnailState: .unavailable),
                movie)
        }

        guard let store else { return }
        do {
            let items = saves.map(\.item)
            if !items.isEmpty {
                let inserted = try store.insert(items)
                logger.info("Drained \(drained.count), inserted \(inserted)")
            }
            try queueTranscripts(for: saves, in: store)
            try reload()
            enrich()
            transcribe()
        } catch {
            storeFailure = error.localizedDescription
            logger.error("Write failed: \(error.localizedDescription)")
        }
    }

    /// Fetches thumbnails for anything still pending.
    ///
    /// Speculative background work, so it is cancellable and never blocks a save. iOS gives no
    /// guarantee that a BGProcessingTask ever runs, which is why this is driven from the
    /// foreground: the background task is a bonus, not the mechanism.
    func enrich() {
        guard let fetcher else { return }
        enrichment?.cancel()
        enrichment = Task { [weak self] in
            // Pass after pass until one stores nothing. A single pass is 25, and an imported
            // board or channel is up to a hundred -- stopping after one left three quarters of
            // an import as grey rectangles until the next launch. A pass that stores nothing
            // means what is left is failing, and it gets its retry on the next foreground.
            while !Task.isCancelled {
                let stored = await fetcher.enrichPending()
                guard !Task.isCancelled, stored > 0 else { return }
                await MainActor.run {
                    // Reloads so the newly-stored thumbnails and aspect ratios appear as each
                    // pass lands, not only at the end.
                    try? self?.reload()
                }
            }
        }
    }

    /// Queues transcription for anything that arrived with a video file.
    ///
    /// Only the file-carrying saves. A link-only save could go up the ladder to rung 2, but
    /// doing it for every save would mean a web view rendering a page for every item in a
    /// 4,000-row Instagram import -- so rung 2 runs when someone asks for it, and rung 0 runs
    /// on its own because the file is already in hand and will otherwise be deleted.
    private func queueTranscripts(for saves: [(item: Item, movie: URL?)], in store: QuokkaStore) throws {
        for save in saves {
            guard let movie = save.movie else { continue }
            guard let staged = Self.stage(movie) else { continue }
            // Re-read rather than trusting the insert: a save that deduped against an existing
            // row has no id of its own, and the transcript belongs on the row that survived.
            guard let id = try store.itemID(forURL: save.item.url) else { continue }
            try store.enqueueTranscript(itemID: id, mediaPath: staged.path)
        }
    }

    /// Moves a shared video out of the inbox's temporary home into one the app owns.
    ///
    /// Application Support rather than Caches: the system may purge Caches at any time, and a
    /// video purged before it was transcribed is gone -- the share sheet will not hand it over
    /// twice.
    private static func stage(_ movie: URL) -> URL? {
        guard let support = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        else { return nil }
        let directory = support.appendingPathComponent("staged-media", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(
            "\(UUID().uuidString).\(movie.pathExtension.isEmpty ? "mov" : movie.pathExtension)")
        do {
            try FileManager.default.moveItem(at: movie, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    /// Works the transcript queue. Never blocking, like `enrich` -- but unlike `enrich`, a run in
    /// progress is not cancelled and restarted. It is usually a web view halfway through a page,
    /// and this is called on every foreground; the queue folds a second call into one more pass.
    func transcribe() {
        guard let transcripts else { return }
        transcription = Task { [weak self] in
            let produced = await transcripts.run()
            guard !Task.isCancelled, produced > 0 else { return }
            await MainActor.run { try? self?.reload() }
        }
    }

    /// A debug hook for verifying the importer without driving a document picker.
    ///
    /// Reads a folder planted in Documents and runs the real scan, parse, dedupe and insert
    /// path -- only the file picker is bypassed. DEBUG-only so it cannot ship.
    func importFixtureIfRequested() {
        #if DEBUG
        guard let name = UserDefaults.standard.string(forKey: "quokkaImportFixture") else { return }
        guard let documents = try? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return }

        // Not `isDirectory: true`: that appends a trailing slash, which is right for a folder
        // and produces an unopenable URL for a .zip -- and the whole point of the fixture is
        // that it exercises whichever one the user would actually have picked.
        let root = documents.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: root.path) else {
            logger.error("No fixture at \(root.path)")
            return
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            let scanner = ExportScanner()
            let contents = scanner.scan(root: root)
            // Mirrors what the UI does by default: the largest thread, plus saved and liked.
            let account = contents.threads.first?.title
            let shares = scanner.shares(
                from: contents, root: root, account: account, includeSaved: true, includeLiked: true
            )
            let items = InstagramExport.items(from: shares)
            let added = await self?.importItems(items) ?? 0
            await MainActor.run {
                self?.logger.info(
                    "Fixture import: thread '\(account ?? "-")', \(shares.count) shares, \(items.count) unique, \(added) added"
                )
            }
        }
        #endif
    }

    /// Bulk-inserts imported items and returns how many were new.
    ///
    /// Enrichment is deliberately NOT kicked off here. An Instagram import is thousands of
    /// rows, all of them .unavailable by construction, so there is nothing to fetch -- and
    /// starting a queue drain after every import would just walk the whole table for nothing.
    func importItems(_ items: [Item]) async -> Int {
        guard let store else { return 0 }
        do {
            let added = try store.insert(items)
            try reload()
            logger.info("Imported \(items.count), added \(added)")
            return added
        } catch {
            storeFailure = error.localizedDescription
            logger.error("Import failed: \(error.localizedDescription)")
            return 0
        }
    }

    /// Reloads from the top. Used after a write, where a cursor from before the write would
    /// skip whatever was just inserted.
    func reload() throws {
        guard let store else { return }
        let page = try selectedAuthor.map { try store.page(author: $0) } ?? store.page()
        items = page.items
        cursor = page.cursor
        total = try store.count()
        authors = (try? store.authors()) ?? []
    }

    /// Whether the library is mirrored to a file Claude Code can read.
    ///
    /// Off by default, and deliberately so. Writing a person's whole saved library into iCloud
    /// is a privacy decision that belongs to them, not a convenience to switch on quietly
    /// because it makes a feature work.
    var mirrorsToClaude: Bool {
        get { UserDefaults.standard.bool(forKey: "quokkaMirrorEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "quokkaMirrorEnabled")
            if newValue { syncMirror() }
        }
    }

    /// Rewrites the mirror and applies anything Claude tagged since last time.
    func syncMirror() {
        guard mirrorsToClaude, let store else { return }
        do {
            // The whole library, not the current page: the mirror is for a program that will
            // ask its own questions, and a page is an artefact of this app's scrolling.
            var all: [Item] = []
            var cursor: ItemCursor?
            repeat {
                let page = try store.page(after: cursor, limit: 500)
                all.append(contentsOf: page.items)
                cursor = page.cursor
            } while cursor != nil && all.count < 200_000

            // Transcripts go out with the library. They are what makes the mirror worth
            // reading: captions are marketing and a YouTube title is often the URL, so the
            // transcript is the only place the actual content of a video lives.
            var transcripts: [Int64: String] = [:]
            for item in all {
                guard let id = item.id,
                      let transcript = try? store.transcript(forItem: id),
                      transcript.isUsable
                else { continue }
                transcripts[id] = transcript.text
            }
            mirror.write(all, transcripts: transcripts)

            let playlists = (try? store.playlistsForMirror()) ?? []
            mirror.writePlaylists(playlists.compactMap { entry in
                guard let id = entry.playlist.id else { return nil }
                let items = (try? store.playlistItems(id)) ?? []
                return LibraryMirror.PlaylistMirror(
                    id: id,
                    name: entry.playlist.name,
                    note: entry.playlist.note,
                    itemCount: entry.itemCount,
                    summary: entry.playlist.summary,
                    summaryIsStale: entry.playlist.summaryIsStale,
                    itemIDs: items.compactMap(\.id))
            })

            let applied = mirror.ingestTags { id, tags in
                try? store.setTags(itemID: id, tags)
            }
            let summarised = mirror.ingestSummaries { playlistID, summary in
                try? store.setPlaylistSummary(playlistID, summary)
            }
            if applied > 0 || summarised > 0 { try reload() }
        } catch {
            logger.error("Mirror sync failed: \(error.localizedDescription)")
        }
    }

    /// One place database errors are surfaced.
    ///
    /// A view has nothing useful to do with one, and making every call site handle it would
    /// scatter `try?` through the UI instead of keeping it here.
    func report(_ error: Error) {
        storeFailure = error.localizedDescription
        logger.error("\(error.localizedDescription)")
    }

    /// Cover items for one author, for the collections grid.
    func coverItems(for author: String) -> [Item] {
        (try? store?.coverItems(author: author)) ?? []
    }

    func select(author: String?) {
        selectedAuthor = author
        try? reload()
    }

    /// Appends the next page. Does nothing at the end of the library, where `cursor` is nil.
    func loadMore() {
        guard let store, let cursor else { return }
        do {
            let page = try selectedAuthor.map { try store.page(author: $0, after: cursor) }
                ?? store.page(after: cursor)
            items.append(contentsOf: page.items)
            self.cursor = page.cursor
        } catch {
            logger.error("Paging failed: \(error.localizedDescription)")
        }
    }
}
