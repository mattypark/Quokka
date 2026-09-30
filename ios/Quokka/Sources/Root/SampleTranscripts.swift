import Foundation
import QuokkaEngine

#if DEBUG
/// Three short scripts, written for screenshot runs, that exercise every part of a breakdown:
/// a fast numbered list with a follow ask, a story with a comment ask, and a question hook
/// with no structure and no ask at all.
///
/// Original text, not taken from any real video. Every screen that shows one says it is a
/// sample -- see `AppState.isSampleTranscript`.
enum SampleTranscripts {
    static let all: [Transcript] = [
        timed([
            "Stop filming with the light behind you.",
            "Here are three fixes that took my videos from grainy to clean.",
            "First, face the window, not your back to it.",
            "Second, turn off the overhead light, it makes everyone look tired.",
            "Third, at night, one lamp bounced off a white wall beats a ring light.",
            "Try one of these on your next video.",
            "Follow for part two, where I fix your audio.",
        ], wordsPerSecond: 2.95),
        timed([
            "I quit my job six months ago to make videos full time.",
            "Here's what nobody warned me about.",
            "The hard part isn't ideas.",
            "It's filming on the days you don't feel like it.",
            "So I started batching, four videos every Sunday, no exceptions.",
            "My views went up, but more than that, I stopped dreading the camera.",
            "What's the part you find hardest? Tell me in the comments.",
        ], wordsPerSecond: 2.3),
        timed([
            "Why do some cooking videos get a million views and others get nine?",
            "It's almost never the recipe.",
            "It's the first bite.",
            "The good ones show you the finished plate before a single ingredient.",
            "You already know how it ends, so you stay to see how it gets there.",
        ], wordsPerSecond: 2.6),
    ]

    /// Lays the lines end to end, each lasting as long as its words take at the given rate.
    private static func timed(_ lines: [String], wordsPerSecond: Double) -> Transcript {
        var clock: TimeInterval = 0
        let segments = lines.map { line -> Transcript.Segment in
            let words = Double(line.split(separator: " ").count)
            let duration = (words / wordsPerSecond * 10).rounded() / 10
            defer { clock += duration }
            return Transcript.Segment(text: line, start: clock, duration: duration)
        }
        return Transcript(
            text: lines.joined(separator: " "),
            segments: segments,
            locale: "en-US",
            source: .sharedFile)
    }
}
#endif
