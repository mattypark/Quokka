import Foundation
import AllimEngine
import AllimImaging
import os

/// Executes the plan `ThumbnailResolver` decided on, and stores the result.
///
/// The plan is pure and already unit-tested, so this is deliberately a dumb executor of three
/// verbs. Its own job is the part that cannot be tested without a network: fetching, deciding
/// what counts as an image, and refusing to be fooled by a login page that returns 200.
actor ThumbnailFetcher {
    private let store: AllimStore
    private let session: URLSession
    private let logger = Logger(subsystem: "com.matthewpark.allim", category: "thumbnails")

    /// Anything bigger than this is not a thumbnail and is not worth the memory to find out.
    private static let maxBytes = 5 * 1024 * 1024

    init(store: AllimStore) {
        self.store = store
        let configuration = URLSessionConfiguration.ephemeral
        // Short by design. Enrichment is speculative work in the background; a fetch that
        // takes 30 seconds has already lost to the user scrolling past the tile.
        configuration.timeoutIntervalForRequest = 12
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    /// Drains the pending queue. Returns how many thumbnails were actually stored.
    @discardableResult
    func enrichPending(limit: Int = 25) async -> Int {
        let pending: [Item]
        do {
            pending = try store.pendingEnrichment(limit: limit)
        } catch {
            logger.error("Could not read the queue: \(error.localizedDescription)")
            return 0
        }

        var stored = 0
        for item in pending {
            guard let id = item.id else { continue }
            if await enrich(item, id: id) { stored += 1 }
        }
        return stored
    }

    private func enrich(_ item: Item, id: Int64) async -> Bool {
        guard let url = URL(string: item.url),
              let link = LinkCanonicaliser.canonicalise(item.url)
        else {
            try? store.recordEnrichFailure(itemID: id)
            return false
        }

        _ = url
        let plan = ThumbnailResolver.plan(for: link)

        guard let imageData = await bytes(for: plan, platform: item.platform) else {
            // .failed, not .unavailable: a network blip should be retryable, whereas
            // .unavailable means the platform structurally serves nothing. Conflating them
            // would either retry forever or give up permanently on a transient failure.
            try? store.recordEnrichFailure(itemID: id)
            return false
        }

        guard let thumbnail = ImageDownsampler.thumbnail(from: imageData) else {
            try? store.recordEnrichFailure(itemID: id)
            return false
        }

        do {
            try store.setThumbnail(
                itemID: id,
                bytes: thumbnail.data,
                width: thumbnail.width,
                height: thumbnail.height,
                format: thumbnail.format,
                averageColor: thumbnail.averageColor
            )
            return true
        } catch {
            logger.error("Could not store the thumbnail: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - The three verbs

    private func bytes(for plan: ThumbnailPlan, platform: Platform) async -> Data? {
        switch plan {
        case .unavailable:
            return nil

        case .directCandidates(let urls):
            // Ordered best-first. YouTube's maxresdefault 404s on older uploads, so the walk
            // is the mechanism rather than a fallback.
            for url in urls {
                if let data = await download(url) { return data }
            }
            return nil

        case .oEmbed(let endpoint):
            guard let data = await download(endpoint, expectingImage: false),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let thumbnail = json["thumbnail_url"] as? String,
                  let url = URL(string: thumbnail)
            else { return nil }
            return await download(url)

        case .openGraph(let page):
            guard let data = await download(page, expectingImage: false),
                  let html = String(data: data, encoding: .utf8),
                  let image = Self.openGraphImage(in: html),
                  var url = URL(string: image)
            else { return nil }
            // Turns a signed, expiring preview.redd.it URL into a permanent i.redd.it one.
            // Free durability, and the reason Reddit counts as a stable platform at all.
            if platform == .reddit { url = ThumbnailResolver.permanentRedditURL(url) }
            return await download(url)
        }
    }

    private func download(_ url: URL, expectingImage: Bool = true) async -> Data? {
        do {
            var request = URLRequest(url: url)
            // Several CDNs serve a different response, or none, to a client with no UA.
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15",
                forHTTPHeaderField: "User-Agent"
            )

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            guard data.count <= Self.maxBytes else { return nil }

            if expectingImage {
                // A 200 is not proof of an image. Instagram and Pinterest answer an
                // unauthenticated image request with an HTML login page, and without this
                // check that page gets stored as a thumbnail and renders as a grey square.
                let contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
                guard contentType.hasPrefix("image/") else { return nil }
                guard !data.isEmpty else { return nil }
            }
            return data
        } catch {
            return nil
        }
    }

    /// Pulls `og:image` out of a page head.
    ///
    /// A regex rather than a parser on purpose: this reads one tag out of markup that is
    /// frequently malformed, and a strict parser fails on pages a loose scan handles. It also
    /// accepts the attributes in either order, which real pages vary.
    static func openGraphImage(in html: String) -> String? {
        let patterns = [
            #"<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']"#,
            #"<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']"#,
        ]
        // Only the head is scanned. A full-page regex over a megabyte of markup is slow, and
        // og: tags are required to be in the head anyway.
        let head = String(html.prefix(200_000))

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(head.startIndex..<head.endIndex, in: head)
            if let match = regex.firstMatch(in: head, range: range),
               let captured = Range(match.range(at: 1), in: head) {
                return String(head[captured]).replacingOccurrences(of: "&amp;", with: "&")
            }
        }
        return nil
    }
}
