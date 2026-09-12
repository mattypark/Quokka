import Foundation

/// Walks the rungs in order and stops at the first one that answers.
///
/// Pure coordination and nothing else: it owns no network, no filesystem and no speech model.
/// Providers are injected, so the entire decision -- which rung is tried, in what order, what
/// happens when each fails -- runs under `swift test` against fakes, in milliseconds, with no
/// simulator and no real Instagram URL.
///
/// That matters more here than usual. Rung 2 is the part most likely to break, and the part
/// hardest to exercise on demand; keeping the *logic* separable from the fetching means a
/// broken resolver cannot take the ladder's correctness down with it.
public struct TranscriptLadder: Sendable {
    /// Sorted by rung on init, so a caller cannot accidentally register the hosted provider
    /// first and have it quietly win every time.
    private let providers: [any TranscriptProvider]

    public init(providers: [any TranscriptProvider]) {
        self.providers = providers.sorted { $0.rung < $1.rung }
    }

    /// What one walk of the ladder produced.
    public struct Outcome: Sendable, Equatable {
        public var transcript: Transcript?
        /// Every rung considered, in the order it was considered, whether or not it ran.
        ///
        /// Kept even on success: knowing that rung 0 was skipped and rung 2 answered is what
        /// lets the app suggest the download-it-yourself route, which is both free and more
        /// reliable than the one that just worked.
        public var attempts: [TranscriptAttempt]

        public var succeeded: Bool { transcript != nil }

        /// The first failure worth showing someone, or nil when it worked.
        ///
        /// Skips `.disabled` and `.notApplicable`: a rung that was switched off or had nothing
        /// to work from did not fail at anything, and surfacing it as the reason would send a
        /// user chasing a problem that is not theirs.
        public var reportableFailure: TranscriptFailure? {
            guard transcript == nil else { return nil }
            let real = attempts.compactMap(\.failure).first {
                $0 != .disabled && $0 != .notApplicable && $0 != .noResolverRule
            }
            return real ?? attempts.compactMap(\.failure).first
        }
    }

    public func run(
        _ request: TranscriptRequest,
        config: ResolverConfig
    ) async -> Outcome {
        var attempts: [TranscriptAttempt] = []

        for provider in providers {
            guard config.isEnabled(provider.rung) else {
                attempts.append(.init(rung: provider.rung, failure: .disabled))
                continue
            }
            guard provider.canAttempt(request, config: config) else {
                attempts.append(.init(rung: provider.rung, failure: .notApplicable))
                continue
            }
            do {
                let transcript = try await provider.transcribe(request, config: config)
                // A provider that returns successfully with nothing in it has not succeeded.
                // Silence, a language with no model, a clip that was all music -- all of them
                // come back as an empty string, and storing that would replace a labelled
                // sample with a blank field, which reads as lost work rather than as no result.
                guard transcript.isUsable else {
                    attempts.append(.init(rung: provider.rung, failure: .producedNothing))
                    continue
                }
                attempts.append(.init(rung: provider.rung))
                return Outcome(transcript: transcript, attempts: attempts)
            } catch let failure as TranscriptFailure {
                attempts.append(.init(rung: provider.rung, failure: failure))
            } catch {
                attempts.append(.init(rung: provider.rung, failure: .transport(nil)))
            }
        }

        return Outcome(transcript: nil, attempts: attempts)
    }
}
