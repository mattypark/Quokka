import Testing
import Foundation
@testable import QuokkaEngine

/// The ladder is the one piece of the transcription pipeline that can be fully exercised
/// without a device, a network or a real Instagram URL -- so it is where the behaviour that
/// actually matters gets pinned. Everything below it is fetching, which breaks for reasons no
/// test can hold still.
struct TranscriptLadderTests {

    /// A rung that answers, fails, or returns silence, on command.
    private struct FakeProvider: TranscriptProvider {
        let rung: TranscriptRung
        var applicable = true
        var result: Result<Transcript, TranscriptFailure>

        func canAttempt(_ request: TranscriptRequest, config: ResolverConfig) -> Bool {
            applicable
        }

        func transcribe(
            _ request: TranscriptRequest,
            config: ResolverConfig
        ) async throws -> Transcript {
            try result.get()
        }
    }

    private func text(_ body: String, _ rung: TranscriptRung) -> Transcript {
        Transcript(text: body, source: rung.source)
    }

    private let request = TranscriptRequest(platform: .instagram)

    private func allRungs(_ rules: [ResolverRule] = []) -> ResolverConfig {
        ResolverConfig(version: 1, enabledRungs: Set(TranscriptRung.allCases), rules: rules)
    }

    @Test("The safest rung that can answer is the one that does")
    func safestRungWins() async {
        // Registered worst-first on purpose: the ladder sorts, so a caller cannot make the
        // hosted provider win by listing it first.
        let ladder = TranscriptLadder(providers: [
            FakeProvider(rung: .hosted, result: .success(text("paid", .hosted))),
            FakeProvider(rung: .resolveOnDevice, result: .success(text("fetched", .resolveOnDevice))),
            FakeProvider(rung: .sharedFile, result: .success(text("free", .sharedFile))),
        ])

        let outcome = await ladder.run(request, config: allRungs())

        #expect(outcome.transcript?.source == .sharedFile)
        // The expensive rungs were never reached, which is the point -- they cost money and
        // send a URL off the device.
        #expect(outcome.attempts.count == 1)
    }

    @Test("A disabled rung is skipped without being run")
    func killSwitchStopsARung() async {
        let ladder = TranscriptLadder(providers: [
            FakeProvider(rung: .sharedFile, applicable: false, result: .failure(.notApplicable)),
            FakeProvider(rung: .resolveOnDevice, result: .success(text("fetched", .resolveOnDevice))),
        ])

        let config = ResolverConfig(version: 2, enabledRungs: [.sharedFile])
        let outcome = await ladder.run(request, config: config)

        #expect(outcome.succeeded == false)
        #expect(outcome.attempts.last?.failure == .disabled)
    }

    @Test("An unreachable worker leaves only the rung that needs nothing")
    func failClosedEnablesOnlyTheLocalRung() {
        // The device that cannot reach the worker is the one whose behaviour nobody can
        // observe or stop. It gets the least latitude, not the most.
        #expect(ResolverConfig.failClosed.isEnabled(.sharedFile))
        #expect(ResolverConfig.failClosed.isEnabled(.resolveOnDevice) == false)
        #expect(ResolverConfig.failClosed.isEnabled(.hosted) == false)
    }

    @Test("A rung that succeeds with an empty transcript has not succeeded")
    func silenceFallsThroughToTheNextRung() async {
        // A silent clip, or one that was all music, comes back as a successful empty string.
        // Storing that would replace a labelled sample with a blank field, which reads as the
        // app losing work.
        let ladder = TranscriptLadder(providers: [
            FakeProvider(rung: .sharedFile, result: .success(text("   \n ", .sharedFile))),
            FakeProvider(rung: .hosted, result: .success(text("real words", .hosted))),
        ])

        let outcome = await ladder.run(request, config: allRungs())

        #expect(outcome.transcript?.text == "real words")
        #expect(outcome.attempts.first?.failure == .producedNothing)
    }

    @Test("The failure shown is one someone could act on")
    func reportableFailureSkipsHousekeeping() async {
        let ladder = TranscriptLadder(providers: [
            FakeProvider(rung: .sharedFile, applicable: false, result: .failure(.notApplicable)),
            FakeProvider(rung: .resolveOnDevice, result: .failure(.mediaUnreachable("403"))),
        ])

        let outcome = await ladder.run(request, config: allRungs())

        // "This rung had no file to work from" is not a problem the user has. "Instagram would
        // not serve the media" is, and it has an answer: tap Download, share the file.
        #expect(outcome.reportableFailure == .mediaUnreachable("403"))
    }

    @Test("Every rung failing is a failure, not an empty transcript")
    func totalFailureProducesNoTranscript() async {
        let ladder = TranscriptLadder(providers: [
            FakeProvider(rung: .sharedFile, applicable: false, result: .failure(.notApplicable)),
            FakeProvider(rung: .resolveOnDevice, result: .failure(.transport(500))),
            FakeProvider(rung: .hosted, result: .failure(.transport(429))),
        ])

        let outcome = await ladder.run(request, config: allRungs())

        #expect(outcome.transcript == nil)
        #expect(outcome.attempts.count == 3)
    }

    @Test("Only the hosted rung is recorded as having left the device")
    func provenanceIsHonestAboutPrivacy() {
        // This drives the App Privacy answer. Rung 2 fetches from Instagram directly, which is
        // not Quokka collecting anything -- rung 3 goes through Quokka's own worker, which is.
        #expect(TranscriptSource.sharedFile.leavesTheDevice == false)
        #expect(TranscriptSource.resolvedOnDevice.leavesTheDevice == false)
        #expect(TranscriptSource.hosted.leavesTheDevice == true)
    }
}
