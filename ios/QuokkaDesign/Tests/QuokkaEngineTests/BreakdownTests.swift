import Testing
import Foundation
@testable import QuokkaEngine

/// The breakdown is the screen the redesign is built around, and every line of it is a claim
/// about someone else's video. These pin that each claim is read out of the words, the same
/// way every time.
struct BreakdownTests {

    /// Segments laid end to end, `seconds` each, so timings are predictable.
    private func transcript(_ lines: [String], seconds: TimeInterval = 2) -> Transcript {
        let segments = lines.enumerated().map { index, line in
            Transcript.Segment(text: line, start: Double(index) * seconds, duration: seconds)
        }
        return Transcript(text: lines.joined(separator: " "), segments: segments, source: .sharedFile)
    }

    private let listVideo = [
        "Stop editing your videos like this.",
        "Here are three fixes that doubled my watch time.",
        "First, cut the first two seconds of every clip.",
        "Second, put a caption on screen in the first frame.",
        "Third, end on the next question, not a goodbye.",
        "Follow for part two.",
    ]

    @Test("Nothing to read gives no breakdown")
    func emptyTranscript() {
        #expect(Breakdown.analyze(Transcript(text: "   \n ", source: .sharedFile)) == nil)
    }

    @Test("The hook is the first line, and lands when that line finishes")
    func hookTiming() throws {
        let breakdown = try #require(Breakdown.analyze(transcript(listVideo)))
        #expect(breakdown.hook.text == "Stop editing your videos like this.")
        let landsAt = try #require(breakdown.hook.landsAt)
        #expect(landsAt > 0 && landsAt <= 2.5)
        #expect(breakdown.checks.first { $0.id == "hook-fast" }?.passed == true)
    }

    @Test("A warning that talks to you is read as both")
    func hookKinds() throws {
        let breakdown = try #require(Breakdown.analyze(transcript(listVideo)))
        #expect(breakdown.hook.kinds.contains(.warning))
        #expect(breakdown.hook.kinds.contains(.you))
        #expect(!breakdown.hook.kinds.contains(.question))
    }

    @Test("A throat-clearing opener borrows the next line")
    func throatClear() throws {
        let breakdown = try #require(Breakdown.analyze(transcript(["Okay, so.", "Why does nobody talk about this?"])))
        #expect(breakdown.hook.text == "Okay, so. Why does nobody talk about this?")
        #expect(breakdown.hook.kinds.contains(.question))
        #expect(breakdown.hook.kinds.contains(.claim))
    }

    @Test("Ordinals and numbered lines are beats; a number in a hook is not")
    func beats() throws {
        let breakdown = try #require(Breakdown.analyze(transcript(listVideo)))
        #expect(breakdown.beats.count == 3)
        #expect(breakdown.beats.first?.text.hasPrefix("First") == true)
        #expect(breakdown.beats.first?.start == 4)

        #expect(Breakdown.isBeat("1. Launch fast and iterate."))
        #expect(Breakdown.isBeat("Number two, the lighting."))
        #expect(Breakdown.isBeat("#3: batch your filming."))
        #expect(!Breakdown.isBeat("3 things nobody tells you about lighting."))
        #expect(!Breakdown.isBeat("2026 was the year I quit."))
    }

    @Test("A numbered script split on its full stops keeps each marker with its line")
    func numberedScript() {
        let sentences = Breakdown.sentences(in: "Three rules.\n1. Launch fast.\n2. Listen to customers.")
        #expect(sentences == ["Three rules.", "1. Launch fast.", "2. Listen to customers."])
    }

    @Test("Pace comes from the timing, and is left out when there is none")
    func pacing() throws {
        let timed = try #require(Breakdown.analyze(transcript(listVideo, seconds: 2)))
        let words = timed.pacing.words
        #expect(timed.pacing.duration == 12)
        #expect(timed.pacing.wordsPerMinute == Int((Double(words) / 0.2).rounded()))
        #expect(timed.checks.contains { $0.id == "pace" })

        let untimed = try #require(Breakdown.analyze(
            Transcript(text: listVideo.joined(separator: " "), source: .hosted)))
        #expect(untimed.pacing.wordsPerMinute == nil)
        #expect(untimed.pacing.tempo == .unknown)
        #expect(!untimed.checks.contains { $0.id == "pace" })
        // Without timing, "lands in 3 seconds" becomes "is short", judged on words.
        #expect(untimed.checks.first { $0.id == "hook-fast" }?.title == "Hook is short")
    }

    @Test("The ending's ask is found in the last two lines")
    func endingAsk() throws {
        let breakdown = try #require(Breakdown.analyze(transcript(listVideo)))
        #expect(breakdown.ending.ask == .follow)
        #expect(breakdown.checks.first { $0.id == "ask" }?.passed == true)

        let noAsk = try #require(Breakdown.analyze(transcript(["Here is my kitchen.", "That is all."])))
        #expect(noAsk.ending.ask == nil)
        #expect(noAsk.checks.first { $0.id == "ask" }?.passed == false)
    }

    @Test("Every check carries evidence, and the same words always give the same result")
    func deterministicWithEvidence() throws {
        let one = try #require(Breakdown.analyze(transcript(listVideo)))
        let two = try #require(Breakdown.analyze(transcript(listVideo)))
        #expect(one == two)
        #expect(one.checks.allSatisfy { !$0.evidence.isEmpty })
        #expect(one.passed == one.checks.filter(\.passed).count)
    }

    @Test("Curly apostrophes read the same as straight ones")
    func curlyApostrophes() throws {
        let breakdown = try #require(Breakdown.analyze(transcript(["Don’t film like this.", "Save this for later."])))
        #expect(breakdown.hook.kinds.contains(.warning))
        #expect(breakdown.ending.ask == .save)
    }
}
