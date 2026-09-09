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
        let probe: [ProviderProbe]
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

            results.append(
                Drained(
                    id: record.id,
                    receivedAt: record.receivedAt,
                    link: record.linkCandidate.flatMap(LinkCanonicaliser.canonicalise),
                    rawText: record.rawText,
                    imageData: imageData,
                    probe: record.probe
                )
            )

            if deleting { try? FileManager.default.removeItem(at: url) }
        }

        if !results.isEmpty { logger.info("Drained \(results.count) record(s) from the inbox") }
        return results
    }
}
