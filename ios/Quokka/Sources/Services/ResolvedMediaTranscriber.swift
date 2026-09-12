import Foundation
import os
import QuokkaEngine

/// Rung 2: resolve a post URL to its media, read it on this device, delete it.
///
/// The rung that makes the product work for the way people actually save -- a link, from the
/// share sheet, with no file attached. Free, and nothing reaches any Quokka server: the device
/// talks to the platform's own CDN and the audio never leaves it.
///
/// **Every rule this runs on is fetched, never compiled in.** Instagram and TikTok change their
/// page payloads without notice, and a pattern in the binary turns each of those into three
/// days of App Review for a regex. It is also why this rung can be switched off from outside
/// without shipping anything.
///
/// The media is downloaded to a temporary file and deleted in a `defer` before this returns.
/// It is never written to Photos, never added to the library, and never offered as a download.
/// That distinction is the whole basis for the rung existing -- see `docs/RESEARCH-TRANSCRIPTS.md`.
struct ResolvedMediaTranscriber: TranscriptProvider {
    let rung: TranscriptRung = .resolveOnDevice

    private let session: URLSession
    private let onDevice: OnDeviceTranscriber
    private let webResolver: WebViewMediaResolver
    private let logger = Logger(subsystem: "com.matthewpark.quokka", category: "resolve")

    @MainActor
    init(session: URLSession = .shared, onDevice: OnDeviceTranscriber = OnDeviceTranscriber()) {
        self.session = session
        self.onDevice = onDevice
        self.webResolver = WebViewMediaResolver()
    }

    func canAttempt(_ request: TranscriptRequest, config: ResolverConfig) -> Bool {
        guard let rule = config.rule(for: request.platform) else { return false }
        // A webView rule with no script is a misconfiguration, not a route. Caught here so the
        // ladder records it as inapplicable and moves on rather than spinning up a web process
        // to run nothing.
        if rule.strategy == .webView, rule.script?.isEmpty != false { return false }
        if rule.strategy == .htmlPattern, rule.mediaPatterns.isEmpty { return false }
        return rule.requestURL(contentID: request.contentID, postURL: request.url) != nil
    }

    func transcribe(
        _ request: TranscriptRequest,
        config: ResolverConfig
    ) async throws -> Transcript {
        guard let rule = config.rule(for: request.platform) else {
            throw TranscriptFailure.noResolverRule
        }
        guard let endpoint = rule.requestURL(contentID: request.contentID, postURL: request.url),
              let url = URL(string: endpoint)
        else { throw TranscriptFailure.notApplicable }

        let mediaURL: URL
        switch rule.strategy {
        case .htmlPattern:
            let body = try await fetchPage(url, rule: rule)
            guard let found = rule.extractMediaURL(from: body),
                  let parsed = URL(string: found)
            else {
                // The single most common real failure, and the one with a user-facing answer:
                // open the post, tap Share, tap Download, share the file into Quokka. The
                // config version is logged because when this starts happening to everyone at
                // once, the question is always "which config were they on".
                logger.info("no media in payload for \(request.platform.rawValue, privacy: .public), config v\(config.version)")
                throw TranscriptFailure.mediaUnreachable("no media in payload")
            }
            mediaURL = parsed
        case .webView:
            // Instagram and TikTok both serve an application shell to a plain client, so there
            // is no document to pattern-match. Rendering the page is what makes their media
            // reachable at all -- see WebViewMediaResolver.
            mediaURL = try await webResolver.mediaURL(for: url, rule: rule)
        }

        let media = try await download(mediaURL, rule: rule)
        defer {
            // Not optional and not best-effort-later. The file exists only for as long as it
            // takes to read it, and leaving it behind would turn a transcriber into exactly
            // the thing guideline 5.2.3 is about.
            try? FileManager.default.removeItem(at: media)
        }

        return try await onDevice.transcribe(fileAt: media, request: request)
    }

    // MARK: - Network

    private func fetchPage(_ url: URL, rule: ResolverRule) async throws -> String {
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        for (field, value) in rule.headers { req.setValue(value, forHTTPHeaderField: field) }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw TranscriptFailure.transport(nil)
        }
        guard let http = response as? HTTPURLResponse else { throw TranscriptFailure.transport(nil) }
        guard (200..<300).contains(http.statusCode) else {
            throw TranscriptFailure.transport(http.statusCode)
        }
        guard let body = String(data: data, encoding: .utf8) else {
            throw TranscriptFailure.mediaUnreachable("payload was not text")
        }
        return body
    }

    private func download(_ url: URL, rule: ResolverRule) async throws -> URL {
        var req = URLRequest(url: url)
        req.timeoutInterval = 60
        for (field, value) in rule.headers { req.setValue(value, forHTTPHeaderField: field) }

        let temp: URL
        let response: URLResponse
        do {
            (temp, response) = try await session.download(for: req)
        } catch {
            throw TranscriptFailure.transport(nil)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            try? FileManager.default.removeItem(at: temp)
            throw TranscriptFailure.transport(http.statusCode)
        }
        // A CDN that redirects to something enormous must not be allowed to fill the disk.
        // Checked after the fact rather than from Content-Length, which these hosts routinely
        // omit on a chunked response.
        let attributes = try? FileManager.default.attributesOfItem(atPath: temp.path)
        let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        guard size <= rule.maxBytes else {
            try? FileManager.default.removeItem(at: temp)
            throw TranscriptFailure.mediaUnreachable("media exceeded \(rule.maxBytes) bytes")
        }

        // URLSession deletes its own temp file the moment this call returns, so it has to be
        // moved before anything else touches it.
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("quokka-media-\(UUID().uuidString)")
            .appendingPathExtension(url.pathExtension.isEmpty ? "mp4" : url.pathExtension)
        do {
            try FileManager.default.moveItem(at: temp, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw TranscriptFailure.mediaUnreachable("could not stage media")
        }
        return destination
    }
}
