import Foundation
import Observation
import AllimEngine
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
    private let logger = Logger(subsystem: "com.matthewpark.allim", category: "state")
    private var store: AllimStore?
    private var fetcher: ThumbnailFetcher?
    private(set) var loader: ThumbnailLoader?
    private var cursor: ItemCursor?
    private var enrichment: Task<Void, Never>?

    init() {
        do {
            let store = try AllimStore.standard()
            self.store = store
            fetcher = ThumbnailFetcher(store: store)
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

        let items = drained.compactMap { record -> Item? in
            guard let link = record.link else { return nil }
            return Item(link: link, savedAt: record.receivedAt, origin: .shareSheet)
        }

        guard let store else { return }
        do {
            if !items.isEmpty {
                let inserted = try store.insert(items)
                logger.info("Drained \(drained.count), inserted \(inserted)")
            }
            try reload()
            enrich()
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
            let stored = await fetcher.enrichPending()
            guard !Task.isCancelled, stored > 0 else { return }
            await MainActor.run {
                // Reloads so the newly-stored thumbnails and aspect ratios are picked up.
                try? self?.reload()
            }
        }
    }

    /// A debug hook for verifying the importer without driving a document picker.
    ///
    /// Reads a folder planted in Documents and runs the real scan, parse, dedupe and insert
    /// path -- only the file picker is bypassed. DEBUG-only so it cannot ship.
    func importFixtureIfRequested() {
        #if DEBUG
        guard let name = UserDefaults.standard.string(forKey: "allimImportFixture") else { return }
        guard let documents = try? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return }

        let root = documents.appendingPathComponent(name, isDirectory: true)
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
        get { UserDefaults.standard.bool(forKey: "allimMirrorEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "allimMirrorEnabled")
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

            mirror.write(all)

            let applied = mirror.ingestTags { id, tags in
                try? store.setTags(itemID: id, tags)
            }
            if applied > 0 { try reload() }
        } catch {
            logger.error("Mirror sync failed: \(error.localizedDescription)")
        }
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
