import Testing
import Foundation
@testable import AllimEngine

/// The model behind the screen Matthew called the product. These pin the behaviours two
/// different views depend on, so they cannot drift into two phrasings of the same fact.
struct IdeaTests {

    @Test("An idea with no script does not offer a copy button")
    func emptyScriptHasNothingToCopy() {
        // A copy control that copies an empty string is worse than no control: it reports
        // success and puts nothing on the pasteboard.
        #expect(Idea(title: "Untitled").hasScript == false)
        #expect(Idea(title: "Untitled", body: "   \n  ").hasScript == false)
        #expect(Idea(title: "Untitled", body: "day in my life").hasScript == true)
    }

    @Test("Under a minute reads as just now, not as zero minutes ago")
    func recentModificationReadsNaturally() {
        let now = Date()
        let idea = Idea(title: "x", modifiedAt: now.addingTimeInterval(-5))
        #expect(idea.modifiedDescription(relativeTo: now) == "Modified just now")
    }

    @Test("Older modifications are relative and human")
    func olderModificationIsRelative() {
        let now = Date()
        let idea = Idea(title: "x", modifiedAt: now.addingTimeInterval(-3600))
        let text = idea.modifiedDescription(relativeTo: now)
        #expect(text.hasPrefix("Modified "))
        #expect(text != "Modified just now")
    }

    @Test("An idea round-trips through JSON with its hook and transcript intact")
    func roundTrip() throws {
        // Hook and transcript are separate fields on purpose -- a hook re-derived from prose on
        // every render could change between two draws of the same screen.
        let idea = Idea(
            title: "Day in my life as a 25 year old entrepreneur",
            body: "1. launch fast and iterate",
            hook: "day in the life of building a multimillion-dollar wellness brand",
            transcript: "day in the life of building...",
            playlistID: 7,
            status: .completed
        )
        let data = try JSONEncoder().encode(idea)
        let decoded = try JSONDecoder().decode(Idea.self, from: data)

        #expect(decoded.title == idea.title)
        #expect(decoded.hook == idea.hook)
        #expect(decoded.transcript == idea.transcript)
        #expect(decoded.playlistID == 7)
        #expect(decoded.status == .completed)
    }

    @Test("Status defaults to todo, so the planner has something to show later")
    func defaultStatus() {
        // Tracked from the start even though the planner screen does not exist yet -- otherwise
        // every idea created before it arrives is stranded in whatever default it picks then.
        #expect(Idea(title: "x").status == .todo)
        #expect(Idea.Status.allCases.count == 3)
    }
}

struct PlaylistTests {

    @Test("The subtitle reads the way the reference does")
    func subtitleShape() {
        let now = Date()
        let playlist = Playlist(name: "Wellness Series", updatedAt: now.addingTimeInterval(-7200))
        let text = playlist.subtitle(ideaCount: 4, relativeTo: now)
        #expect(text.hasPrefix("4 ideas | Updated "))
    }

    @Test("One idea is singular")
    func singularIdea() {
        let now = Date()
        let playlist = Playlist(name: "x", updatedAt: now)
        #expect(playlist.subtitle(ideaCount: 1, relativeTo: now) == "1 idea | Updated just now")
        #expect(playlist.subtitle(ideaCount: 0, relativeTo: now) == "0 ideas | Updated just now")
    }

    @Test("A source pairs an idea with an item and keeps its position")
    func sourceOrdering() {
        // The inspiration grid has to stay in the order it was arranged, not in id order.
        let first = IdeaSource(ideaID: 1, itemID: 40, position: 0)
        let second = IdeaSource(ideaID: 1, itemID: 12, position: 1)
        #expect(first != second)
        #expect([second, first].sorted { $0.position < $1.position }.first == first)
    }

    @Test("Sources are hashable, so a set of them dedupes")
    func sourcesDedupe() {
        // Adding the same video to an idea twice should be a no-op rather than two grid tiles
        // of the same reel.
        let a = IdeaSource(ideaID: 1, itemID: 40, position: 0)
        let b = IdeaSource(ideaID: 1, itemID: 40, position: 0)
        #expect(Set([a, b]).count == 1)
    }
}
