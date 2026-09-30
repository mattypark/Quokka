import Foundation
import os
import QuokkaEngine

/// Runs the transcript ladder over whatever is queued.
///
/// Shaped like `ThumbnailFetcher.enrichPending` on purpose -- same bounded batch, same
/// cancellable background work, same rule that it never blocks a save. Two queues that behave
/// differently for no reason is two things to hold in your head.
actor TranscriptQueue {
    private let store: QuokkaStore
    private let ladder: TranscriptLadder
    private let config: TranscriptConfigStore
    private let logger = Logger(subsystem: "com.matthewpark.quokka", category: "transcribe")

    /// Whether a walk is in progress. An actor is re-entered at every `await`, so without this a
    /// second `run` -- a foreground, a second tap -- would read the same pending jobs and render
    /// the same page in a second web view, spending two attempts on one try.
    private var running = false
    /// Set when `run` is called while one is in progress, so what was queued meanwhile gets its
    /// pass as soon as the current one ends rather than waiting for the next foreground.
    private var rerunRequested = false

    @MainActor
    init(store: QuokkaStore, config: TranscriptConfigStore = TranscriptConfigStore()) {
        self.store = store
        self.config = config
        self.ladder = TranscriptLadder(providers: [
            OnDeviceTranscriber(),
            ResolvedMediaTranscriber(),
            HostedTranscriber(),
        ])
    }

    /// Works through the queue, returning how many transcripts were produced.
    ///
    /// Small batch because each one is a real amount of work -- a download, an audio export
    /// and a speech model -- and because the user is looking at the screen while it happens.
    /// Five at a time keeps the first result close rather than making everything wait for the
    /// batch.
    ///
    /// A call made while a walk is running returns 0 at once and turns into one more pass at
    /// the end of that walk, which reports everything it produced.
    @discardableResult
    func run(limit: Int = 5) async -> Int {
        if running {
            rerunRequested = true
            return 0
        }
        running = true
        defer { running = false }

        var produced = 0
        repeat {
            rerunRequested = false
            produced += await pass(limit: limit)
        } while rerunRequested && !Task.isCancelled
        return produced
    }

    private func pass(limit: Int) async -> Int {
        let current = await config.current()
        guard let jobs = try? store.pendingTranscriptJobs(limit: limit), !jobs.isEmpty else {
            return 0
        }

        var produced = 0
        for job in jobs {
            if Task.isCancelled { break }
            guard let item = try? store.item(id: job.itemID) else { continue }

            let request = TranscriptRequest(
                itemID: job.itemID,
                url: item.url,
                contentID: item.contentID,
                localMediaPath: job.mediaPath,
                platform: item.platform)

            let outcome = await ladder.run(request, config: current)

            if let transcript = outcome.transcript {
                try? store.setTranscript(itemID: job.itemID, transcript)
                // The staged video has done its job. Deleted here rather than at save time
                // because the app can be killed in between, and a file nobody remembers is a
                // file nobody deletes -- which for a 200 MB video is the whole disk budget.
                discardStagedMedia(at: job.mediaPath)
                produced += 1
                logger.info("transcribed item \(job.itemID) via \(transcript.source.rawValue, privacy: .public)")
            } else if Task.isCancelled {
                // Stopped from outside, not failed. The rung reports a cancelled web view as a
                // transport failure, and counting it would let three app switches mid-resolve
                // exhaust a post that was never actually refused.
                logger.info("item \(job.itemID) interrupted; attempt not counted")
                break
            } else {
                let reason = describe(outcome.reportableFailure)
                try? store.failTranscript(itemID: job.itemID, reason: reason)
                // Only once the budget is spent. A retry might still find the media, and
                // deleting the file early would take the safest rung away from the attempt
                // most likely to need it.
                if job.attempts + 1 >= QuokkaStore.transcriptAttemptLimit {
                    discardStagedMedia(at: job.mediaPath)
                }
                logger.info("item \(job.itemID) not transcribed: \(reason, privacy: .public)")
            }
        }
        return produced
    }

    private func discardStagedMedia(at path: String?) {
        guard let path else { return }
        try? FileManager.default.removeItem(atPath: path)
    }

    /// A failure someone could act on, in words rather than a case name.
    ///
    /// Written here rather than in a view because the frontend session owns screens and this
    /// is the backend's answer to "why is there no transcript" -- and because the instruction
    /// in the media case is the single most useful sentence the feature has: the creator-
    /// authorised download always works when the creator allowed it.
    private nonisolated func describe(_ failure: TranscriptFailure?) -> String {
        switch failure {
        case .mediaUnreachable:
            "This post will not hand over its audio. Open it in the app, tap Share, then Download, and share the file into Quokka."
        case .localeUnavailable(let code):
            "No speech model for \(code) on this device yet."
        case .producedNothing:
            "Nothing was said in this one."
        case .transport(let status?):
            "The source refused (\(status))."
        case .transport(nil):
            "Could not reach the source."
        case .disabled, .notApplicable, .noResolverRule, .none:
            "No route to this video's audio."
        }
    }
}
