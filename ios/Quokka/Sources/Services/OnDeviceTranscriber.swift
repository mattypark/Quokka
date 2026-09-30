import AVFoundation
import Foundation
import os
import QuokkaEngine
import Speech

/// Rung 0: a video file the system handed over, read on this device.
///
/// The only route that is free, private and unbreakable at the same time. Nothing is fetched,
/// nothing is circumvented, and no platform can change anything that stops it working -- it is
/// the user's file and `SpeechAnalyzer` reads it.
///
/// `SpeechAnalyzer` rather than `SFSpeechRecognizer` because the old API caps a session at one
/// minute, which does not fit a reel, and rather than WhisperKit because the model worth
/// shipping needs a 627 MB download and about 67 seconds of on-device compilation on first run.
/// See `docs/RESEARCH-TRANSCRIPTS.md`.
struct OnDeviceTranscriber: TranscriptProvider {
    let rung: TranscriptRung = .sharedFile

    private let logger = Logger(subsystem: "com.matthewpark.quokka", category: "transcribe")

    func canAttempt(_ request: TranscriptRequest, config: ResolverConfig) -> Bool {
        guard let path = request.localMediaPath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    func transcribe(
        _ request: TranscriptRequest,
        config: ResolverConfig
    ) async throws -> Transcript {
        guard let path = request.localMediaPath else { throw TranscriptFailure.notApplicable }
        return try await transcribe(fileAt: URL(fileURLWithPath: path), request: request)
    }

    /// Shared with rung 2, which downloads to a temp file and then lands here.
    ///
    /// Deliberately the same code from this point down: once there is a file on disk, how it
    /// got there is somebody else's problem, and having one transcription implementation means
    /// a bug in it cannot be fixed on one rung and left on the other.
    func transcribe(fileAt media: URL, request: TranscriptRequest) async throws -> Transcript {
        let locale = try await resolveLocale(preferred: request.preferredLocale)
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        try await installModelIfNeeded(for: transcriber, locale: locale)

        let audio = try await audioFile(from: media)
        defer {
            // The extracted audio is scratch. Rung 2's video is deleted by rung 2; this is the
            // copy this type made, and it owns it.
            if audio.isTemporary { try? FileManager.default.removeItem(at: audio.url) }
        }

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: audio.url)
        } catch {
            throw TranscriptFailure.mediaUnreachable("unreadable audio: \(error.localizedDescription)")
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])

        // Results have to be drained concurrently with the analysis. The sequence finishes when
        // the analyzer finalises, so collecting after the fact would deadlock waiting on a
        // sequence that is waiting on a call that already returned.
        let collector = Task { () -> [Transcript.Segment] in
            var segments: [Transcript.Segment] = []
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                segments.append(
                    Transcript.Segment(
                        text: text,
                        start: result.range.start.seconds,
                        duration: result.range.duration.seconds))
            }
            return segments
        }

        do {
            _ = try await analyzer.analyzeSequence(from: file)
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            collector.cancel()
            logger.error("analysis failed: \(error.localizedDescription, privacy: .public)")
            throw TranscriptFailure.mediaUnreachable("analysis failed")
        }

        let segments = (try? await collector.value) ?? []
        // A CMTime that is not numeric prints as a huge negative, and a segment list sorted by
        // a bogus start reads as the transcript being out of order rather than as a timing
        // problem. Sorting on a validated start keeps the failure to the timestamps.
        let ordered = segments.sorted { $0.start < $1.start }
        let text = ordered.map(\.text).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Transcript(
            text: text,
            segments: ordered,
            locale: locale.identifier(.bcp47),
            source: rung.source)
    }

    // MARK: - Locale

    /// The locale to transcribe in, preferring one whose model is already on the device.
    ///
    /// Order matters. A model that is already installed transcribes immediately; one that is
    /// merely supported costs a download the user did not ask for at the moment they tapped a
    /// button. So an installed match wins over an exact-but-absent one.
    private func resolveLocale(preferred: String?) async throws -> Locale {
        let installed = await SpeechTranscriber.installedLocales
        let candidates = [preferred, Locale.current.identifier(.bcp47)].compactMap { $0 }

        for identifier in candidates {
            let wanted = Locale(identifier: identifier)
            if let match = installed.first(where: {
                $0.language.languageCode == wanted.language.languageCode
            }) {
                return match
            }
        }
        for identifier in candidates {
            if let supported = await SpeechTranscriber.supportedLocale(
                equivalentTo: Locale(identifier: identifier)) {
                return supported
            }
        }
        // Anything already installed beats failing outright: a transcript in the wrong language
        // is visibly wrong and recoverable, where no transcript at all just looks broken.
        if let fallback = installed.first { return fallback }
        throw TranscriptFailure.localeUnavailable(candidates.first ?? "und")
    }

    private func installModelIfNeeded(for transcriber: SpeechTranscriber, locale: Locale) async throws {
        guard await AssetInventory.status(forModules: [transcriber]) != .installed else { return }
        do {
            guard let request = try await AssetInventory.assetInstallationRequest(
                supporting: [transcriber]) else { return }
            logger.info("downloading speech model for \(locale.identifier, privacy: .public)")
            try await request.downloadAndInstall()
        } catch {
            // Said in the log as well as mapped: the Simulator cannot download speech assets
            // at all, and "no model" on a phone means something else -- storage, or no network
            // -- so the real reason is what makes the two tell-apart-able.
            logger.error("speech model for \(locale.identifier, privacy: .public) not installed: \(error.localizedDescription, privacy: .public)")
            throw TranscriptFailure.localeUnavailable(locale.identifier)
        }
    }

    // MARK: - Audio

    private struct AudioSource {
        let url: URL
        let isTemporary: Bool
    }

    /// An audio file `AVAudioFile` can open.
    ///
    /// `AVAudioFile` reads audio files, not video containers -- handing it an `.mp4` fails, and
    /// that is the single most likely way this whole path breaks in a way that looks like the
    /// speech model being at fault. So a container carrying video gets its audio track exported
    /// first, through AVFoundation's hardware decoder.
    private func audioFile(from media: URL) async throws -> AudioSource {
        let asset = AVURLAsset(url: media)
        let hasVideo = try? await asset.loadTracks(withMediaType: .video)
        if hasVideo?.isEmpty == true, (try? AVAudioFile(forReading: media)) != nil {
            return AudioSource(url: media, isTemporary: false)
        }

        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
        else { throw TranscriptFailure.mediaUnreachable("no audio export path") }

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("quokka-audio-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        do {
            try await export.export(to: output, as: .m4a)
        } catch {
            throw TranscriptFailure.mediaUnreachable("audio extraction failed")
        }
        return AudioSource(url: output, isTemporary: true)
    }
}
