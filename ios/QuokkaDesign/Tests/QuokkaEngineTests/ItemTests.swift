import Testing
import Foundation
@testable import QuokkaEngine

/// Building an item from a link is where a research finding turns into behaviour, so the
/// consequence gets pinned rather than left implicit in an enum.
struct ItemTests {

    private func item(_ raw: String) -> Item? {
        LinkCanonicaliser.canonicalise(raw).map { Item(link: $0) }
    }

    @Test("Platforms that serve no thumbnail start terminal, not pending")
    func unreachablePlatformsAreNeverQueued() {
        // pendingEnrichment() selects on .pending, so starting these anywhere else would put
        // them in a queue that retries a fetch which cannot succeed, forever.
        #expect(item("https://www.instagram.com/reel/C8xYzAbCdEf/")?.thumbnailState == .unavailable)
        #expect(item("https://x.com/nasa/status/1234567890")?.thumbnailState == .unavailable)
    }

    @Test("Platforms that do serve a thumbnail start pending")
    func reachablePlatformsAreQueued() {
        #expect(item("https://youtu.be/dQw4w9WgXcQ")?.thumbnailState == .pending)
        #expect(item("https://www.pinterest.com/pin/1234567890/")?.thumbnailState == .pending)
        #expect(item("https://www.reddit.com/comments/1abc234/")?.thumbnailState == .pending)
        #expect(item("https://www.tiktok.com/@nasa/video/7234567890123456789")?.thumbnailState == .pending)
    }

    @Test("An item carries the canonical URL, which is the dedupe key")
    func carriesCanonicalURL() {
        let saved = item("https://www.instagram.com/reel/C8xYzAbCdEf/?igshid=xyz")
        #expect(saved?.url == "https://www.instagram.com/p/C8xYzAbCdEf/")
        #expect(saved?.contentID == "C8xYzAbCdEf")
    }

    @Test("The same post from three export sources produces one identical key")
    func exportSourcesDedupe() {
        // This is the whole reason the Instagram import can pull DMs, Saved and Liked in one
        // pass without triplicating the library.
        let dm = Item(link: LinkCanonicaliser.canonicalise("https://www.instagram.com/reel/C8xYzAbCdEf/?igshid=a")!, origin: .instagramDM)
        let saved = Item(link: LinkCanonicaliser.canonicalise("https://instagram.com/p/C8xYzAbCdEf")!, origin: .instagramSaved)
        let liked = Item(link: LinkCanonicaliser.canonicalise("https://www.instagram.com/tv/C8xYzAbCdEf/")!, origin: .instagramLiked)

        #expect(dm.url == saved.url)
        #expect(saved.url == liked.url)
    }
}

struct ItemCursorTests {

    @Test("A cursor pairs the timestamp with an id, because ties are certain in an import")
    func cursorBreaksTies() {
        // A bulk import writes thousands of rows; savedAt collisions are not an edge case
        // there, they are the norm. A timestamp-only cursor would skip or repeat rows.
        let now = Date()
        let a = ItemCursor(savedAt: now, id: 100)
        let b = ItemCursor(savedAt: now, id: 99)
        #expect(a != b)
    }

    @Test("A short page ends the library rather than handing back a cursor")
    func shortPageHasNoCursor() {
        // A cursor on a short page makes the UI fetch an empty page on every scroll, forever.
        let page = ItemPage(items: [], cursor: nil)
        #expect(page.cursor == nil)
    }
}
