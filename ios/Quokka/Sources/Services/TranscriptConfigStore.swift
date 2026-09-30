import Foundation
import os
import QuokkaEngine

/// Holds the current `ResolverConfig`, fetches a new one when it is stale, and refuses to
/// widen what the app is allowed to do when it cannot.
///
/// The refusal is the feature. Every failure path with no config younger than `maximumAge`
/// lands on `ResolverConfig.failClosed`, which enables rung 0 and nothing else. A device that cannot reach the worker -- offline, or
/// behind something hostile, or running after the worker has been taken down deliberately --
/// is exactly the device whose behaviour nobody can observe or stop. It gets the least
/// latitude, not the most.
///
/// The last good config is cached so an offline launch keeps working as it did yesterday
/// rather than degrading for the duration of a flight. It expires, though: a kill switch that
/// a device can outrun by staying offline is not a kill switch.
actor TranscriptConfigStore {
    /// How long a cached config keeps its rungs. Past this, the app drops to fail-closed until
    /// it can ask again.
    private static let maximumAge: TimeInterval = 60 * 60 * 24 * 7
    /// How long before a refresh is attempted. Short enough that a switch thrown in the morning
    /// is live by the afternoon; long enough not to be a request on every screen.
    private static let refreshAfter: TimeInterval = 60 * 60 * 6

    private let endpoint: URL?
    private let session: URLSession
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.matthewpark.quokka", category: "config")

    private var cached: ResolverConfig?
    private var inFlight: Task<ResolverConfig?, Never>?

    private static let storageKey = "quokka.resolverConfig"

    init(
        endpoint: URL? = HostedTranscriber.configuredEndpoint,
        session: URLSession = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.endpoint = endpoint
        self.session = session
        self.defaults = defaults
    }

    /// The config to run a ladder against, refreshing in the background when it is getting old.
    func current() async -> ResolverConfig {
        let known = cached ?? loadFromDisk()
        cached = known

        if let known, age(of: known) < Self.refreshAfter { return known }
        if let known, age(of: known) < Self.maximumAge {
            // Usable but stale. Serve it and refresh behind the caller rather than making a
            // transcription wait on a config fetch -- the user tapped a button, not a settings
            // screen.
            Task { _ = await refresh() }
            return known
        }
        return await refresh()
    }

    /// Forces a fetch. On failure, falls back to the last good config while it is inside
    /// `maximumAge`, and to fail-closed once it is not -- never to a config past its age.
    @discardableResult
    func refresh() async -> ResolverConfig {
        let fetched: ResolverConfig?
        if let inFlight {
            fetched = await inFlight.value
        } else {
            let task = Task { () -> ResolverConfig? in
                guard let endpoint else { return nil }
                var request = URLRequest(url: endpoint.appendingPathComponent("config"))
                request.timeoutInterval = 15
                request.cachePolicy = .reloadIgnoringLocalCacheData

                do {
                    let (data, response) = try await session.data(for: request)
                    guard let http = response as? HTTPURLResponse,
                          (200..<300).contains(http.statusCode)
                    else { return nil }

                    var decoded = try JSONDecoder().decode(ResolverConfig.self, from: data)
                    decoded.fetchedAt = Date()
                    persist(decoded)
                    logger.info("resolver config v\(decoded.version, privacy: .public), rungs: \(decoded.enabledRungs.map(\.rawValue).sorted().joined(separator: ","), privacy: .public)")
                    return decoded
                } catch {
                    // Includes a malformed payload, which is the dangerous case: a partial decode
                    // must never leave a rung on by accident, so anything that does not decode
                    // whole is treated as no config at all.
                    logger.error("config fetch failed: \(error.localizedDescription, privacy: .public)")
                    return nil
                }
            }
            inFlight = task
            fetched = await task.value
            inFlight = nil
        }

        if let fetched {
            cached = fetched
            return fetched
        }
        // A failed fetch is not a new config. Replacing a good one with fail-closed would let
        // one dropped request -- a tunnel, captive Wi-Fi -- switch rung 2 off for the rest of
        // the session and make every later transcription wait on a 15-second fetch. The age
        // limit is what makes the kill switch hold.
        if let known = cached ?? loadFromDisk(), age(of: known) < Self.maximumAge {
            cached = known
            return known
        }
        return .failClosed
    }

    // MARK: - Cache

    private func age(of config: ResolverConfig) -> TimeInterval {
        guard let fetchedAt = config.fetchedAt else { return .greatestFiniteMagnitude }
        return Date().timeIntervalSince(fetchedAt)
    }

    private func loadFromDisk() -> ResolverConfig? {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(ResolverConfig.self, from: data)
        else { return nil }
        return decoded
    }

    private func persist(_ config: ResolverConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
