import Foundation
import QuokkaEngine

/// What the transcript screen needs, and does not yet have.
///
/// The ladder runs and writes into `item_transcript` and `transcript_job` -- migration v8
/// created both tables -- but `QuokkaStore` exposes no way to read either back. So the screen
/// is built against this instead of against the store directly, and it ships showing the
/// honest empty state until the backend session adds the three methods.
///
/// When they land, `QuokkaStore` conforms to this and the only change is the value handed to
/// `IdeaDetailView`. No view moves. See `nextsessions/BACKEND-ASKS.md`.
protocol TranscriptReading {
    /// The words, if this item has been transcribed.
    func transcript(forItem itemID: Int64) -> Transcript?

    /// A sentence saying what to do, and only once no retry remains.
    ///
    /// Nil while the ladder still has rungs left to try. A failure that is about to be retried
    /// is not something to put in front of somebody.
    func transcriptFailure(forItem itemID: Int64) -> String?

    /// Whether this item is queued or running right now.
    func isTranscribing(itemID: Int64) -> Bool

    /// Ask for one. Rung 2 renders a web page, so it deliberately does not run on every save --
    /// a four thousand row import would mean four thousand renders. It needs a control.
    func requestTranscript(itemID: Int64)
}

/// The state before the backend session has built any of it.
///
/// Deliberately not a fake transcript. Invented words presented as a real one would be the
/// product lying, and the screen has to be able to tell "nothing yet" from "nothing there".
struct UnbuiltTranscripts: TranscriptReading {
    func transcript(forItem itemID: Int64) -> Transcript? { nil }
    func transcriptFailure(forItem itemID: Int64) -> String? { nil }
    func isTranscribing(itemID: Int64) -> Bool { false }
    func requestTranscript(itemID: Int64) {}
}
