import Foundation

/// Placeholder script text, so the idea screen can be built and demonstrated before real
/// transcription exists.
///
/// **This is scaffolding and it is labelled as such everywhere it appears.** An idea filled
/// this way carries `isSample = true`, and the screen shows a badge saying so. Presenting
/// invented text as a real transcript of someone's video would be a lie told by the product,
/// which is a different and much worse thing than an obvious placeholder.
///
/// Real transcription is the Photos route: the user shares their own video file and
/// `SpeechAnalyzer` reads it on device. See `docs/RESEARCH-TRANSCRIPTS.md`.
public enum SampleScript {

    /// Deterministic from the title, so the same idea shows the same sample every time.
    ///
    /// A different placeholder on every render would read as the app losing work.
    public static func body(for title: String) -> String {
        let shape = shapes[abs(title.hashValue) % shapes.count]
        return """
        \(shape.opening)

        1. \(shape.first)
        \(shape.firstDetail)

        2. \(shape.second)
        \(shape.secondDetail)

        3. \(shape.third)
        \(shape.thirdDetail)
        """
    }

    public static func hook(for title: String) -> String {
        shapes[abs(title.hashValue) % shapes.count].opening
    }

    private struct Shape {
        let opening: String
        let first: String, firstDetail: String
        let second: String, secondDetail: String
        let third: String, thirdDetail: String
    }

    /// Structures rather than sentences. Each one is a real short-form shape -- a listicle, a
    /// day-in-the-life, a lesson -- so the screen is exercised with text of a realistic length
    /// and rhythm rather than lorem ipsum.
    private static let shapes: [Shape] = [
        Shape(
            opening: "here are the three things I wish someone had told me before I started",
            first: "start before it is ready",
            firstDetail: "the version you are embarrassed by teaches you more in a week than planning does in a month.",
            second: "pick one thing and go deep",
            secondDetail: "breadth feels productive and reads as noise. depth is what people follow.",
            third: "keep the receipts",
            thirdDetail: "save everything that stopped your scroll. that archive becomes your voice."
        ),
        Shape(
            opening: "a day in the life of building something nobody has asked for yet",
            first: "mornings are for the hard thing",
            firstDetail: "the work that needs a clear head gets the hours where you have one.",
            second: "ship something every day",
            secondDetail: "not something good. something real. good is a consequence of volume.",
            third: "end the day with a note to tomorrow",
            thirdDetail: "you lose more time reloading context than you do actually working."
        ),
        Shape(
            opening: "nobody talks about the part where it stops being fun",
            first: "the plateau is the job",
            firstDetail: "everyone quits at the same place, which is why the place is empty.",
            second: "measure what you can control",
            secondDetail: "output is yours. reach is not. tracking the wrong one will end you.",
            third: "make it easy to start again",
            thirdDetail: "lower the bar for a bad day until showing up costs nothing."
        ),
    ]
}
