import Foundation

/// The words that were said in a saved video.
///
/// Distinct from `Idea.body` in the same way `Idea` documents: a transcript is what someone
/// else said, the body is what you are going to say. This type is what the ladder produces;
/// turning it into a hook and a title is a separate step that can fail on its own.
///
/// Free of any database dependency, like `Item` and `Idea`, so the whole pipeline stays
/// testable under `swift test` with no simulator and no network.
public struct Transcript: Codable, Sendable, Equatable {
    /// The full text, already joined. Held alongside `segments` rather than derived from them
    /// on demand, because the overwhelmingly common read is "give me the words" and rebuilding
    /// a string from a thousand segments on every render is work for nothing.
    public var text: String
    /// Timed chunks, when the route that produced this could supply them.
    ///
    /// Empty is a legitimate state, not a failure: a hosted provider asked for plain text
    /// returns no offsets, and the product does not currently need them. They are carried
    /// because `SpeechAnalyzer` hands them over for free and throwing them away would mean
    /// re-transcribing to get them back.
    public var segments: [Segment]
    /// BCP-47, as reported by whatever produced the text. Absent when nothing said.
    public var locale: String?
    /// Which rung of the ladder answered. Recorded on the row, not inferred later.
    ///
    /// This is what lets the app tell a user *how* a transcript was obtained, and what lets a
    /// support question be answered without guessing. It is also the honest half of the
    /// privacy story: `.hosted` means the URL left the device and `.sharedFile` means nothing did.
    public var source: TranscriptSource
    public var producedAt: Date

    public struct Segment: Codable, Sendable, Equatable {
        public var text: String
        /// Seconds from the start of the media.
        public var start: TimeInterval
        public var duration: TimeInterval

        public init(text: String, start: TimeInterval, duration: TimeInterval) {
            self.text = text
            self.start = start
            self.duration = duration
        }
    }

    public init(
        text: String,
        segments: [Segment] = [],
        locale: String? = nil,
        source: TranscriptSource,
        producedAt: Date = Date()
    ) {
        self.text = text
        self.segments = segments
        self.locale = locale
        self.source = source
        self.producedAt = producedAt
    }

    /// Whether there is anything worth showing.
    ///
    /// A transcriber handed a silent clip returns successfully with nothing in it, and that
    /// has to read as "no transcript" rather than as an empty one -- otherwise the idea screen
    /// shows a blank field where a sample used to be, which looks like lost work.
    public var isUsable: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Where a transcript came from.
///
/// Three cases, not four, and the missing one is the point. The ladder has four rungs but a
/// video file the user downloaded with Instagram's own Download button and a video file out of
/// their own camera arrive *identically* -- same share sheet, same `public.movie`, same bytes
/// on disk. The app cannot tell them apart and should not pretend to.
///
/// So creator-authorised download is not a code path. It is the same code path, reached by a
/// user who knows the button exists, which makes it an onboarding problem rather than an
/// engineering one.
public enum TranscriptSource: String, Codable, Sendable, CaseIterable {
    /// Rungs 0 and 1. A file the system handed over. Nothing fetched, nothing left the device.
    case sharedFile
    /// Rung 2. The app resolved the post URL to media, read it on device, and discarded it.
    case resolvedOnDevice
    /// Rung 3. The URL went to Quokka's worker and a hosted provider produced the text.
    case hosted

    /// True when producing this required contacting something that is not the user's device.
    ///
    /// Drives the App Privacy answer and the settings copy. `.resolvedOnDevice` counts as
    /// false for the *developer* -- Quokka's servers never see it -- which is the same
    /// distinction Apple's own declaration draws.
    public var leavesTheDevice: Bool { self == .hosted }
}
