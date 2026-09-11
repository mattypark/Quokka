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
        // Six beats rather than three. A real short-form script runs long enough to scroll,
        // and a sample that fits on one screen never exercises the floating video overlapping
        // the text -- which is the whole layout question this screen exists to answer.
        return """
        \(shape.opening)

        1. \(shape.first)
        \(shape.firstDetail)

        2. \(shape.second)
        \(shape.secondDetail)

        3. \(shape.third)
        \(shape.thirdDetail)

        4. \(shape.fourth)
        \(shape.fourthDetail)

        5. \(shape.fifth)
        \(shape.fifthDetail)

        6. \(shape.sixth)
        \(shape.sixthDetail)
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
        let fourth: String, fourthDetail: String
        let fifth: String, fifthDetail: String
        let sixth: String, sixthDetail: String
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
            thirdDetail: "save everything that stopped your scroll. that archive becomes your voice.",
            fourth: "post before you feel ready",
            fourthDetail: "readiness is a feeling that arrives after, never before. waiting for it is the trap.",
            fifth: "steal structure, not sentences",
            fifthDetail: "the shape of a video is the transferable part. the words have to be yours.",
            sixth: "finish badly rather than not at all",
            sixthDetail: "a finished thing teaches you something. an unfinished one only teaches you to start."
        ),
        Shape(
            opening: "a day in the life of building something nobody has asked for yet",
            first: "mornings are for the hard thing",
            firstDetail: "the work that needs a clear head gets the hours where you have one.",
            second: "ship something every day",
            secondDetail: "not something good. something real. good is a consequence of volume.",
            third: "end the day with a note to tomorrow",
            thirdDetail: "you lose more time reloading context than you do actually working.",
            fourth: "protect one block, not the whole day",
            fourthDetail: "a day you have to defend entirely is a day you will lose entirely.",
            fifth: "keep a done list",
            fifthDetail: "a to-do list measures what is left. a done list measures what happened.",
            sixth: "stop while you still know the next move",
            sixthDetail: "stopping at a cliffhanger is how tomorrow starts in ten seconds instead of an hour."
        ),
        Shape(
            opening: "nobody talks about the part where it stops being fun",
            first: "the plateau is the job",
            firstDetail: "everyone quits at the same place, which is why the place is empty.",
            second: "measure what you can control",
            secondDetail: "output is yours. reach is not. tracking the wrong one will end you.",
            third: "make it easy to start again",
            thirdDetail: "lower the bar for a bad day until showing up costs nothing.",
            fourth: "the algorithm is not your problem yet",
            fourthDetail: "at low volume it is noise. at high volume it is signal. get to volume.",
            fifth: "your first hundred are practice",
            fifthDetail: "nobody watches them, which is the point. spend them learning, not performing.",
            sixth: "the boring consistent one wins",
            sixthDetail: "not because it is fair. because everyone else stopped."
        ),
    ]
}
