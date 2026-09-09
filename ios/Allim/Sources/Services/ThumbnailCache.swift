import UIKit
import os

/// A real LRU, hand-rolled, because `NSCache` is the wrong shape for a thumbnail grid.
///
/// `NSCache` orders its eviction list **by cost and evicts the cheapest first**, not by
/// recency, and its purge loop runs **only on insertion**. For a grid of similarly-sized
/// thumbnails that is precisely inverted: the small tiles get discarded while a few large ones
/// survive, and a fast flick blows past `totalCostLimit` before anything is reclaimed.
/// Default-configured, with both limits at zero, it never evicts at all. Kingfisher's memory
/// backend is `NSCache` underneath and inherits every one of these.
///
/// This is a dictionary plus an intrusive doubly-linked recency list behind an actor:
/// O(1) lookup, O(1) promotion, deterministic eviction from the tail.
actor ThumbnailCache {
    private final class Node {
        let key: Int64
        var image: UIImage
        var cost: Int
        var previous: Node?
        var next: Node?

        init(key: Int64, image: UIImage, cost: Int) {
            self.key = key
            self.image = image
            self.cost = cost
        }
    }

    private var nodes: [Int64: Node] = [:]
    private var head: Node?   // most recently used
    private var tail: Node?   // first to go
    private var totalCost = 0

    private let costLimit: Int
    /// No single entry may exceed this share of the budget. Borrowed from Nuke: without it one
    /// oversized image evicts the entire rest of the cache on insertion.
    private let entryCostLimit: Double = 0.1
    private let logger = Logger(subsystem: "com.matthewpark.allim", category: "cache")

    /// 64 MB holds roughly 200 decoded 800px tiles -- several screens of scrollback, well
    /// inside what a phone tolerates.
    init(costLimit: Int = 64 * 1024 * 1024) {
        self.costLimit = costLimit
    }

    func image(for key: Int64) -> UIImage? {
        guard let node = nodes[key] else { return nil }
        promote(node)
        return node.image
    }

    func insert(_ image: UIImage, for key: Int64) {
        // A decoded bitmap costs width x height x 4 regardless of the compressed size, which
        // is the number that actually matters for a memory budget.
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        guard Double(cost) <= Double(costLimit) * entryCostLimit else { return }

        if let existing = nodes[key] {
            totalCost += cost - existing.cost
            existing.image = image
            existing.cost = cost
            promote(existing)
        } else {
            let node = Node(key: key, image: image, cost: cost)
            nodes[key] = node
            pushFront(node)
            totalCost += cost
        }
        evictIfNeeded()
    }

    /// Dropped wholesale under memory pressure. Every entry is reconstructible from a local
    /// BLOB read, so keeping any of it is a worse trade than being terminated.
    func removeAll() {
        nodes.removeAll()
        head = nil
        tail = nil
        totalCost = 0
    }

    // MARK: - List surgery

    private func promote(_ node: Node) {
        guard head !== node else { return }
        unlink(node)
        pushFront(node)
    }

    private func pushFront(_ node: Node) {
        node.previous = nil
        node.next = head
        head?.previous = node
        head = node
        if tail == nil { tail = node }
    }

    private func unlink(_ node: Node) {
        node.previous?.next = node.next
        node.next?.previous = node.previous
        if head === node { head = node.next }
        if tail === node { tail = node.previous }
        node.previous = nil
        node.next = nil
    }

    private func evictIfNeeded() {
        // Evicts on every insert, not only when a limit is crossed on a later one -- the
        // failure mode being avoided is unbounded growth during a fast scroll.
        while totalCost > costLimit, let victim = tail {
            unlink(victim)
            nodes.removeValue(forKey: victim.key)
            totalCost -= victim.cost
        }
    }
}

/// Reads thumbnails out of the store and decodes them off the main thread.
@MainActor
@Observable
final class ThumbnailLoader {
    private let store: AllimStore
    private let cache = ThumbnailCache()
    private var inFlight: [Int64: Task<UIImage?, Never>] = [:]

    init(store: AllimStore) {
        self.store = store
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Hand-rolled rather than inherited: NSCache's behaviour on memory warnings is
            // undocumented, and community reports of it contradict each other.
            Task { await self?.cache.removeAll() }
        }
    }

    func image(for id: Int64) async -> UIImage? {
        if let cached = await cache.image(for: id) { return cached }
        if let running = inFlight[id] { return await running.value }

        let task = Task<UIImage?, Never> { [store, cache] in
            guard let data = try? store.thumbnailBytes(itemID: id), let raw = UIImage(data: data) else {
                return nil
            }
            // UIImage defers decompression to draw time, on the main thread -- the classic
            // invisible scroll hitch. This forces it here, off the main actor, so the image
            // handed to SwiftUI is already a decoded bitmap.
            let decoded = await raw.byPreparingForDisplay() ?? raw
            await cache.insert(decoded, for: id)
            return decoded
        }
        inFlight[id] = task
        let image = await task.value
        inFlight[id] = nil
        return image
    }
}
