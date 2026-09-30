import Foundation
import os
import QuokkaEngine

/// Reads a pasted Pinterest board, Pinterest profile or Are.na channel and turns every post in
/// it into a save.
///
/// Only the list of posts is fetched here. Each post then goes through the same enrichment as
/// anything saved from the share sheet -- Pinterest's oEmbed for a pin, the block page's
/// og:image for an Are.na block -- so an import is not a second, weaker pipeline.
struct CollectionImporter {
    enum Failure: Error, Equatable {
        /// The feed answered, but with nothing Quokka could keep -- a private board, an empty
        /// channel, or a page that has moved.
        case empty
        case unreachable
    }

    private let session: URLSession
    private let logger = Logger(subsystem: "com.matthewpark.quokka", category: "collections")

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// The items a collection holds, ready to insert, newest first.
    func items(in source: CollectionSource, savedAt now: Date = Date()) async throws -> [Item] {
        var request = URLRequest(url: source.feedURL)
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent")

        let data: Data
        do {
            let (body, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw Failure.unreachable
            }
            data = body
        } catch let failure as Failure {
            throw failure
        } catch {
            throw Failure.unreachable
        }

        let posts = source.posts(from: data)
        logger.info("\(source.displayName, privacy: .public): \(posts.count) posts")

        // Each a millisecond apart, in feed order, so the grid shows the collection in the
        // order its owner arranged it rather than shuffled by an identical timestamp.
        let items = posts.enumerated().compactMap { index, post -> Item? in
            guard let link = LinkCanonicaliser.canonicalise(post.url) else { return nil }
            var item = Item(link: link, savedAt: now.addingTimeInterval(-Double(index) / 1000), origin: .manual)
            if item.title == nil { item.title = post.title }
            return item
        }
        guard !items.isEmpty else { throw Failure.empty }
        return items
    }
}
