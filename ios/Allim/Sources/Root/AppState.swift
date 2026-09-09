import Foundation
import Observation
import AllimEngine
import os

@MainActor
@Observable
final class AppState {
    private(set) var items: [Item] = []
    private(set) var total = 0
    /// Set when the store cannot be opened. Surfaced rather than swallowed: a library that
    /// silently stops persisting looks exactly like a library with nothing in it.
    private(set) var storeFailure: String?

    /// The probe readouts from the most recent drain, kept only in memory. They answer a
    /// build-time question about what each app hands the share sheet; they are not library
    /// data and have no business in the database.
    private(set) var lastProbe: [InboxDrain.Drained] = []

    private let inbox = InboxDrain()
    private let logger = Logger(subsystem: "com.matthewpark.allim", category: "state")
    private var store: AllimStore?
    private var cursor: ItemCursor?

    init() {
        do {
            store = try AllimStore.standard()
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
        } catch {
            storeFailure = error.localizedDescription
            logger.error("Write failed: \(error.localizedDescription)")
        }
    }

    /// Reloads from the top. Used after a write, where a cursor from before the write would
    /// skip whatever was just inserted.
    func reload() throws {
        guard let store else { return }
        let page = try store.page()
        items = page.items
        cursor = page.cursor
        total = try store.count()
    }

    /// Appends the next page. Does nothing at the end of the library, where `cursor` is nil.
    func loadMore() {
        guard let store, let cursor else { return }
        do {
            let page = try store.page(after: cursor)
            items.append(contentsOf: page.items)
            self.cursor = page.cursor
        } catch {
            logger.error("Paging failed: \(error.localizedDescription)")
        }
    }
}
