import Foundation
import AllimEngine
import os

/// Moves records out of the App Group inbox and into the app.
///
/// The extension writes and never reads; the app reads and deletes. Coordinated reads are not
/// optional here -- the extension can be mid-write when the app wakes, and an uncoordinated
/// read gets a truncated file that decodes to nothing and silently loses a save.
@MainActor
final class InboxDrain {
    private let logger = Logger(subsystem: "com.matthewpark.allim", category: "inbox")

    /// A drained save, still raw. Canonicalisation happens here rather than in the extension
    /// so the extension stays as small and as fast as possible.
    struct Drained: Identifiable, Sendable {
        let id: UUID
        let receivedAt: Date
        let link: CanonicalLink?
        let rawText: String?
        let imageData: Data?
        /// Where the shared video now lives in the app's own storage.
        ///
        /// A path, not bytes. Videos are too large to carry in memory, and transcription reads
        /// from a file anyway.
        let movieURL: URL?
        let probe: [ProviderProbe]
    }

    /// Moves a shared video into the app's own Application Support directory.
    ///
    /// A move, not a copy: the file is often hundreds of megabytes and duplicating it to delete
    /// the original a moment later is a pointless round trip through the disk.
    private static func adoptMovie(named filename: String, from inbox: URL) -> URL? {
        let manager = FileManager.default
        guard let support = try? manager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }

        let videos = support.appendingPathComponent("Allim/Videos", isDirectory: true)
        try? manager.createDirectory(at: videos, withIntermediateDirectories: true)

        let source = inbox.appendingPathComponent(filename)
        let destination = videos.appendingPathComponent(filename)
        do {
            if manager.fileExists(atPath: destination.path) { try manager.removeItem(at: destination) }
            try manager.moveItem(at: source, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    func drain(deleting: Bool = true) -> [Drained] {
        guard let directory = ShareInbox.directory() else {
            logger.error("No App Group container. Check the entitlement on both targets.")
            return []
        }

        var results: [Drained] = []
        let coordinator = NSFileCoordinator()

        for url in ShareInbox.pendingRecords(in: directory) {
            var coordinationError: NSError?
            var record: ShareInboxRecord?

            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
                guard let data = try? Data(contentsOf: readURL) else { return }
                record = try? ShareInbox.decoder.decode(ShareInboxRecord.self, from: data)
            }

            if let coordinationError {
                logger.error("Could not read \(url.lastPathComponent): \(coordinationError.localizedDescription)")
                continue
            }
            guard let record else {
                // A record that will never decode would otherwise be retried on every launch.
                logger.error("Undecodable record \(url.lastPathComponent); discarding")
                if deleting { try? FileManager.default.removeItem(at: url) }
                continue
            }

            var imageData: Data?
            if let filename = record.imageFilename {
                let imageURL = directory.appendingPathComponent(filename)
                imageData = try? Data(contentsOf: imageURL)
                if deleting { try? FileManager.default.removeItem(at: imageURL) }
            }

            // Moved out of the shared container rather than read. The App Group is an inbox,
            // not storage -- leaving a 200 MB video there means the extension's container grows
            // without anything owning the cleanup.
            var movieURL: URL?
            if let filename = record.movieFilename {
                movieURL = Self.adoptMovie(named: filename, from: directory)
            }

            results.append(
                Drained(
                    id: record.id,
                    receivedAt: record.receivedAt,
                    link: record.linkCandidate.flatMap(LinkCanonicaliser.canonicalise),
                    rawText: record.rawText,
                    imageData: imageData,
                    movieURL: movieURL,
                    probe: record.probe
                )
            )

            if deleting { try? FileManager.default.removeItem(at: url) }
        }

        if !results.isEmpty { logger.info("Drained \(results.count) record(s) from the inbox") }
        return results
    }
}
