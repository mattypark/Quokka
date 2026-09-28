import Foundation
import QuokkaEngine

/// What the Cosmos-style screens read: one item, one creator's saves, a playlist's contents,
/// search, and the colours to search by.
///
/// Same shape as `AppState+Ideas`: pass-throughs to the store with errors reported in one
/// place, so no view ever holds a `try`.
@MainActor
extension AppState {

    // MARK: - Items

    func item(id: Int64) -> Item? {
        guard let store else { return nil }
        do { return try store.item(id: id) } catch { report(error); return nil }
    }

    func transcript(forItem id: Int64) -> Transcript? {
        guard let store else { return nil }
        do { return try store.transcript(forItem: id) } catch { report(error); return nil }
    }

    /// One page of a creator's saves. Held by the creator screen itself rather than by
    /// `selectedAuthor`, so opening a creator never filters the home grid behind it.
    func page(author: String, after cursor: ItemCursor? = nil) -> ItemPage? {
        guard let store else { return nil }
        do { return try store.page(author: author, after: cursor) } catch { report(error); return nil }
    }

    // MARK: - Playlists

    func playlistItems(_ playlistID: Int64) -> [Item] {
        guard let store else { return [] }
        do { return try store.playlistItems(playlistID) } catch { report(error); return [] }
    }

    @discardableResult
    func addToPlaylist(_ playlistID: Int64, itemIDs: [Int64]) -> Int {
        guard let store else { return 0 }
        do { return try store.addToPlaylist(playlistID, itemIDs: itemIDs) } catch { report(error); return 0 }
    }

    @discardableResult
    func removeFromPlaylist(_ playlistID: Int64, itemIDs: [Int64]) -> Int {
        guard let store else { return 0 }
        do { return try store.removeFromPlaylist(playlistID, itemIDs: itemIDs) } catch { report(error); return 0 }
    }

    func playlistDigest(_ playlistID: Int64) -> QuokkaStore.PlaylistDigest? {
        guard let store else { return nil }
        do { return try store.playlistDigest(playlistID) } catch { report(error); return nil }
    }

    func playlists(containing itemID: Int64) -> [Playlist] {
        guard let store else { return [] }
        do { return try store.playlists(containing: itemID) } catch { report(error); return [] }
    }

    /// Every playlist with how many things are on it, in one query.
    ///
    /// The count is items, not ideas -- a Cosmos cluster says "229 elements", and a playlist
    /// someone dropped thirty reels into is not empty just because no script is written yet.
    func playlistCards() -> [PlaylistCard.Model] {
        guard let store else { return [] }
        do {
            return try store.playlistsForMirror().compactMap { entry in
                guard let id = entry.playlist.id else { return nil }
                return PlaylistCard.Model(id: id, name: entry.playlist.name, count: entry.itemCount)
            }
        } catch {
            report(error)
            return []
        }
    }

    /// Up to four items with pictures, for a playlist cover.
    func playlistCover(_ playlistID: Int64, limit: Int = 4) -> [Item] {
        Array(playlistItems(playlistID).filter { $0.thumbnailState == .stored }.prefix(limit))
    }

    // MARK: - Search

    func search(text: String) -> [Item] {
        guard let store else { return [] }
        do { return try store.search(text: text) } catch { report(error); return [] }
    }

    func search(color: Int) -> [Item] {
        guard let store else { return [] }
        do { return try store.search(color: color) } catch { report(error); return [] }
    }

    /// A few colours that are actually in the library, for the swatch row.
    ///
    /// Each recent average colour is dropped into a coarse bucket (three bits a channel) and
    /// the fullest buckets win, so the row shows the library's real palette rather than a
    /// colour wheel's -- tapping a swatch always finds something.
    func swatches(count: Int = 8) -> [Int] {
        guard let store, let colors = try? store.recentColors() else { return [] }
        var buckets: [Int: (total: Int, sample: Int)] = [:]
        for color in colors {
            let key = ((color >> 21) & 0x7) << 6 | ((color >> 13) & 0x7) << 3 | ((color >> 5) & 0x7)
            let current = buckets[key]
            buckets[key] = ((current?.total ?? 0) + 1, current?.sample ?? color)
        }
        return buckets.values
            .sorted { $0.total > $1.total }
            .prefix(count)
            .map(\.sample)
    }
}
