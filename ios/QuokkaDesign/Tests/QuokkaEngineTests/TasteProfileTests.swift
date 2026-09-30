import Testing
import Foundation
@testable import QuokkaEngine

/// "For you" is built from one person's saves, on their phone. These pin that every sentence
/// on it is a count someone could check, and that it stays quiet until there is enough to say.
struct TasteProfileTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        // The test runner's own locale is the root locale, whose weekday names are "Sun".
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    /// Sunday 2026-09-27 at 21:00 UTC, plus `days`.
    private func date(days: Int, hour: Int = 21) -> Date {
        let base = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: hour))!
        return calendar.date(byAdding: .day, value: days, to: base)!
    }

    private func item(_ author: String?, _ platform: Platform = .tiktok, at date: Date) -> Item {
        Item(url: "https://example.com/\(UUID().uuidString)", platform: platform, author: author,
             savedAt: date, origin: .manual, thumbnailState: .stored)
    }

    private func breakdown(_ lines: [String], seconds: Double = 2) -> Breakdown {
        let segments = lines.enumerated().map { Transcript.Segment(text: $1, start: Double($0) * seconds, duration: seconds) }
        return Breakdown.analyze(Transcript(text: lines.joined(separator: " "), segments: segments, source: .sharedFile))!
    }

    private var warningVideos: [Breakdown] {
        [
            breakdown(["Stop filming like this.", "First, face the window.", "Second, lose the ring light.", "Follow for more."]),
            breakdown(["Never post at noon.", "Here is why you should wait.", "Save this for later."]),
            breakdown(["Don't buy a new camera.", "Use your phone.", "Comment what you use."]),
            breakdown(["Why does this work?", "Nobody knows.", "That is all."]),
        ]
    }

    @Test("The hook this person saves most leads, as a count out of their breakdowns")
    func hookNote() {
        let profile = TasteProfile.build(items: [], breakdowns: warningVideos, calendar: calendar)
        #expect(profile.hooks.first?.kind == .warning)
        #expect(profile.hooks.first?.count == 3)
        #expect(profile.notes.first == "3 of the 4 hooks you broke down warn you off something.")
        #expect(profile.suggestedHook == "Stop [doing the common thing] like this.")
    }

    @Test("Check rates are counts, strongest first")
    func checkRates() {
        let profile = TasteProfile.build(items: [], breakdowns: warningVideos, calendar: calendar)
        #expect(profile.checks.first?.rate ?? 0 >= profile.checks.last?.rate ?? 1)
        #expect(profile.checks.allSatisfy { $0.of == 4 })
    }

    @Test("Creators, platforms and the saving rhythm come from the saves themselves")
    func savesSide() {
        let items = (0..<12).map { index in
            item(index < 5 ? "lightingschool" : "someone\(index)", index < 8 ? .tiktok : .youtube, at: date(days: (index % 2) * 7))
        }
        let profile = TasteProfile.build(items: items, breakdowns: warningVideos, calendar: calendar)
        #expect(profile.creators.first == TasteProfile.Share(name: "lightingschool", count: 5))
        #expect(profile.platforms.first == TasteProfile.Share(name: "TikTok", count: 8))
        #expect(profile.busiestWeekday == 1)
        #expect(profile.busiestHour == 21)
        #expect(profile.notes.contains("You keep coming back to lightingschool: 5 saves."))
        #expect(profile.notes.contains("You save most on Sunday evenings."), "\(profile.notes)")
        #expect(profile.notes.contains { $0.hasPrefix("“Keeps the pace up” — only 0 of 4.") })
    }

    @Test("With fewer than three breakdowns it says nothing about hooks, pace or checks")
    func quietWhenEarly() {
        let profile = TasteProfile.build(items: [], breakdowns: Array(warningVideos.prefix(2)), calendar: calendar)
        #expect(profile.isEarly)
        #expect(profile.notes.isEmpty)
    }

    @Test("An empty library builds an empty, early profile without crashing")
    func empty() {
        let profile = TasteProfile.build(items: [], breakdowns: [], calendar: calendar)
        #expect(profile.saves == 0 && profile.isEarly && profile.notes.isEmpty)
        #expect(profile.suggestedHook == nil && profile.medianPace == nil && profile.busiestWeekday == nil)
    }
}
