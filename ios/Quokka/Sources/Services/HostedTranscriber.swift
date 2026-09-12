import Foundation
import os
import QuokkaEngine

/// Rung 3: Quokka's own worker, which calls a hosted transcript provider.
///
/// The only rung where anything leaves the device, and the app talks to **Quokka's worker and
/// never to a vendor directly**. Two reasons, and neither is style: a vendor key in an app
/// bundle is a published key, and routing through one endpoint means swapping providers is a
/// deploy rather than a release.
///
/// It buys robustness -- one call covers YouTube, TikTok, Instagram, X and Facebook, native
/// captions first with ASR behind them -- and it buys no legal cover at all. Supadata's terms
/// §5 put compliance with every platform's own terms back on Quokka, and §11 runs the indemnity
/// the same way. This rung is a convenience, not a shield, and the plan treats it as one.
///
/// **Ships disabled.** `ResolverConfig` has to turn it on, which is also the moment the App
/// Privacy declaration stops being "Data Not Collected" and has to be updated. Those are one
/// task, not two.
struct HostedTranscriber: TranscriptProvider {
    let rung: TranscriptRung = .hosted

    private let endpoint: URL?
    private let session: URLSession
    private let logger = Logger(subsystem: "com.matthewpark.quokka", category: "hosted")

    init(endpoint: URL? = HostedTranscriber.configuredEndpoint, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    /// Read from the build settings, so a checkout with no worker configured simply has this
    /// rung unavailable rather than failing to build. `canAttempt` then reports it as not
    /// applicable and the ladder moves on, which is the correct behaviour for a developer who
    /// has never deployed one.
    /// A host, with the scheme added here. The build setting cannot hold a full URL: `//`
    /// starts a comment in an xcconfig, so `https://host` arrives as `https:` and the failure
    /// reads as a dead worker rather than as a truncated string.
    static var configuredEndpoint: URL? {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "QuokkaWorkerHost") as? String,
              !host.isEmpty, !host.hasPrefix("$(")
        else { return nil }
        return URL(string: "https://\(host)")
    }

    func canAttempt(_ request: TranscriptRequest, config: ResolverConfig) -> Bool {
        endpoint != nil && request.url != nil
    }

    func transcribe(
        _ request: TranscriptRequest,
        config: ResolverConfig
    ) async throws -> Transcript {
        guard let endpoint, let url = request.url else { throw TranscriptFailure.notApplicable }

        var req = URLRequest(url: endpoint.appendingPathComponent("transcript"))
        req.httpMethod = "POST"
        req.timeoutInterval = 90
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(
            Payload(url: url, platform: request.platform.rawValue, lang: request.preferredLocale))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw TranscriptFailure.transport(nil)
        }
        guard let http = response as? HTTPURLResponse else { throw TranscriptFailure.transport(nil) }
        guard (200..<300).contains(http.statusCode) else {
            // 402 and 429 are the two that mean "this will keep happening" rather than "try
            // again". Logged distinctly because a quota that quietly ran out looks exactly like
            // a resolver that quietly broke.
            logger.error("worker returned \(http.statusCode, privacy: .public)")
            throw TranscriptFailure.transport(http.statusCode)
        }

        guard let decoded = try? JSONDecoder().decode(Reply.self, from: data) else {
            throw TranscriptFailure.producedNothing
        }
        return Transcript(
            text: decoded.text,
            segments: decoded.segments?.map {
                Transcript.Segment(text: $0.text, start: $0.start, duration: $0.duration)
            } ?? [],
            locale: decoded.lang,
            source: rung.source)
    }

    private struct Payload: Encodable {
        let url: String
        let platform: String
        let lang: String?
    }

    private struct Reply: Decodable {
        let text: String
        let lang: String?
        let segments: [Segment]?

        struct Segment: Decodable {
            let text: String
            let start: TimeInterval
            let duration: TimeInterval
        }
    }
}
