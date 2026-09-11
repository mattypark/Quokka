import Foundation
import AllimEngine

/// Playlists and ideas, as the views see them.
///
/// Thin on purpose: every method is a pass-through to the store with the errors logged rather
/// than thrown. A view has nothing useful to do with a database error, and making each call
/// site handle one would mean `try?` scattered through the UI instead of in one place.
@MainActor
extension AppState {

    // MARK: - Playlists

    func playlists() -> [PlaylistSummary] {
        guard let store else { return [] }
        do { return try store.playlists() } catch { report(error); return [] }
    }

    func playlist(id: Int64) -> Playlist? {
        guard let store else { return nil }
        do { return try store.playlist(id: id) } catch { report(error); return nil }
    }

    @discardableResult
    func createPlaylist(name: String) -> Playlist? {
        guard let store else { return nil }
        do { return try store.createPlaylist(name: name) } catch { report(error); return nil }
    }

    func renamePlaylist(id: Int64, to name: String) {
        guard let store else { return }
        do { try store.renamePlaylist(id: id, to: name) } catch { report(error) }
    }

    func deletePlaylist(id: Int64) {
        guard let store else { return }
        do { try store.deletePlaylist(id: id) } catch { report(error) }
    }

    // MARK: - Ideas

    func ideas(inPlaylist playlistID: Int64) -> [Idea] {
        guard let store else { return [] }
        do { return try store.ideas(inPlaylist: playlistID) } catch { report(error); return [] }
    }

    func idea(id: Int64) -> Idea? {
        guard let store else { return nil }
        do { return try store.ideas().first { $0.id == id } } catch { report(error); return nil }
    }

    @discardableResult
    func createIdea(title: String, playlistID: Int64?) -> Idea? {
        guard let store else { return nil }
        do { return try store.createIdea(title: title, playlistID: playlistID) } catch { report(error); return nil }
    }

    func save(_ idea: Idea) {
        guard let store else { return }
        do { try store.save(idea) } catch { report(error) }
    }

    func deleteIdea(id: Int64) {
        guard let store else { return }
        do { try store.deleteIdea(id: id) } catch { report(error) }
    }

    // MARK: - What an idea was built from

    func sources(forIdea ideaID: Int64) -> [Item] {
        guard let store else { return [] }
        do { return try store.sources(for: ideaID) } catch { report(error); return [] }
    }

    func addSource(itemID: Int64, toIdea ideaID: Int64) {
        guard let store else { return }
        do { try store.addSource(itemID: itemID, to: ideaID) } catch { report(error) }
    }

    /// Everything cited by any idea in this playlist -- the playlist's Media tab.
    ///
    /// Derived rather than stored: media belongs to a playlist because an idea in it points at
    /// that video, so a separate playlist-to-item table would be a second answer to the same
    /// question, free to disagree with the first.
    func mediaItems(forPlaylist playlistID: Int64) -> [Item] {
        let ideas = ideas(inPlaylist: playlistID)
        var seen = Set<Int64>()
        var result: [Item] = []
        for idea in ideas {
            guard let id = idea.id else { continue }
            for item in sources(forIdea: id) {
                guard let itemID = item.id, seen.insert(itemID).inserted else { continue }
                result.append(item)
            }
        }
        return result
    }

    /// Sample playlists and ideas, for screenshots. DEBUG-only so it cannot ship.
    ///
    /// Writes through the real create/save path rather than inserting rows directly, so a
    /// seeded run exercises the same code a real one does -- a fixture that takes a shortcut
    /// tests the shortcut.
    func seedIdeasIfRequested() {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "allimSeedIdeas") else { return }
        guard playlists().isEmpty else { return }

        let script = """
        day in the life of building a multimillion-dollar wellness brand — these are the 5 \
        things I recommend every entrepreneur do when they're just starting out.

        1. launch fast and iterate
        don't wait for perfect. when we launched Arrae, our packaging wasn't what I \
        envisioned, the color was off, the label was wrong. we had two choices: fix it and \
        delay for months, or launch anyway. we launched — and it was the best decision we \
        ever made. getting real feedback from real customers mattered way more than perfection.

        2. make your customers feel like influencers
        when I look at what brands do, oftentimes they place too much focus on influencers \
        and VIPs, and not enough on the customer.
        """

        let seeds: [(String, [(String, String, String?)])] = [
            ("Wellness Series", [
                ("Day in my life as a 25 year old entrepreneur", script,
                 "day in the life of building a multimillion-dollar wellness brand"),
                ("Rich & unemployed: how I'm becoming my own boss in 2026", "", nil),
                ("Day X of trying [side hustle] until I make $k / month", "", nil),
                ("Turning my 5-9 into my 9-5: day X", "", nil),
            ]),
            ("Hooks that worked", [
                ("The greatest scam of the decade", "", "nobody talks about this"),
                ("20 ways to get better before 2026", "", nil),
            ]),
            ("Moving to NYC", []),
        ]

        for (name, ideas) in seeds {
            guard let playlist = createPlaylist(name: name), let playlistID = playlist.id else { continue }
            for (title, body, hook) in ideas {
                guard var idea = createIdea(title: title, playlistID: playlistID) else { continue }
                idea.body = body.isEmpty ? SampleScript.body(for: title) : body
                idea.hook = hook ?? SampleScript.hook(for: title)
                // Flagged, always. The screen says so, and a placeholder that does not
                // announce itself is indistinguishable from a lie.
                idea.isSample = true
                save(idea)

                // Attach a couple of real saved videos so the Inspiration grid and the floating
                // chip have something to show.
                if let ideaID = idea.id {
                    for item in items.prefix(4) where item.id != nil {
                        addSource(itemID: item.id!, toIdea: ideaID)
                    }
                }
            }
        }
        logger.info("Seeded \(seeds.count) playlists")
        #endif
    }

    func coverItems(forPlaylist playlistID: Int64, limit: Int = 4) -> [Item] {
        Array(mediaItems(forPlaylist: playlistID).filter { $0.thumbnailState == .stored }.prefix(limit))
    }
}
