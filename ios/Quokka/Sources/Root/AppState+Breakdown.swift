import Foundation
import QuokkaEngine

/// What the breakdown screens read: counts for the sky, the videos ready to break down and
/// the ones still waiting for words, and a way to ask for a transcript.
///
/// Same shape as the other AppState extensions -- pass-throughs with errors reported in one
/// place, so no view holds a `try`.
@MainActor
extension AppState {

    struct Pulse: Equatable {
        var saved = 0
        var transcribed = 0
        var waiting = 0
    }

    /// The three numbers on the Home sky.
    func pulse() -> Pulse {
        guard let store else { return Pulse() }
        do {
            return Pulse(
                saved: total,
                transcribed: try store.transcribedCount(),
                waiting: try store.untranscribedVideos(limit: 500).count)
        } catch {
            report(error)
            return Pulse(saved: total)
        }
    }

    func transcribedItems(limit: Int = 20) -> [Item] {
        guard let store else { return [] }
        do { return try store.transcribedItems(limit: limit) } catch { report(error); return [] }
    }

    func untranscribedVideos(limit: Int = 20) -> [Item] {
        guard let store else { return [] }
        do { return try store.untranscribedVideos(limit: limit) } catch { report(error); return [] }
    }

    func breakdown(forItem id: Int64) -> Breakdown? {
        transcript(forItem: id).flatMap(Breakdown.analyze)
    }

    func isTranscriptQueued(_ id: Int64) -> Bool {
        guard let store else { return false }
        return (try? store.isTranscriptQueued(itemID: id)) ?? false
    }

    /// The ladder's own sentence, once every rung has been tried. Nil while it is still trying.
    func transcriptFailure(_ id: Int64) -> String? {
        guard let store else { return nil }
        return try? store.exhaustedTranscriptFailure(forItem: id)
    }

    /// Queues the item and starts the queue. Rung 2 renders a web page, so this runs because
    /// someone asked, never on every save.
    func requestTranscript(_ id: Int64) {
        guard let store else { return }
        do {
            try store.enqueueTranscript(itemID: id)
            transcribe()
        } catch {
            report(error)
        }
    }

    enum AddLinkResult: Equatable {
        case saved
        case alreadySaved
        case collection(name: String, added: Int, found: Int)
        case notALink
        case failed(String)
    }

    /// Adds whatever was pasted: one post, or every post in a Pinterest board, Pinterest
    /// profile or Are.na channel.
    ///
    /// A single post is saved exactly as the share sheet saves it. A collection is read by
    /// `CollectionImporter` and inserted in one go; either way enrichment starts straight after,
    /// so the pictures and titles arrive while the person is still looking.
    func addLink(_ raw: String) async -> AddLinkResult {
        guard let store else { return .failed("The library could not be opened.") }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let source = CollectionSource.detect(trimmed) {
            do {
                let items = try await CollectionImporter().items(in: source)
                let added = try store.insert(items)
                try reload()
                enrich()
                return .collection(name: source.displayName, added: added, found: items.count)
            } catch CollectionImporter.Failure.empty {
                return .failed("Nothing public in that \(source.displayName). Is it secret?")
            } catch {
                return .failed("Couldn’t reach \(source.displayName). Try again in a moment.")
            }
        }

        guard let link = LinkCanonicaliser.canonicalise(trimmed) else { return .notALink }
        do {
            let added = try store.insert([Item(link: link, origin: .manual)])
            try reload()
            enrich()
            return added > 0 ? .saved : .alreadySaved
        } catch {
            report(error)
            return .failed("That link couldn’t be saved.")
        }
    }

    /// Adds links given at launch, for screenshot runs. DEBUG-only; `-quokkaAddLinks a,b,c`.
    func addLinksIfRequested() async {
        #if DEBUG
        guard let list = UserDefaults.standard.string(forKey: "quokkaAddLinks") else { return }
        for link in list.split(separator: ",") {
            let result = await addLink(String(link))
            logger.info("Added \(link, privacy: .public): \(String(describing: result), privacy: .public)")
        }
        #endif
    }

    // MARK: - Samples, for screenshots

    private static let sampleIDsKey = "quokkaSampleTranscriptIDs"

    /// Whether this item's transcript was planted by a screenshot run.
    ///
    /// The screen says so in words whenever this is true. A made-up transcript shown as the
    /// real one would be the product lying about someone else's video.
    func isSampleTranscript(_ id: Int64) -> Bool {
        #if DEBUG
        (UserDefaults.standard.array(forKey: Self.sampleIDsKey) as? [Int]).map { $0.contains(Int(id)) } ?? false
        #else
        false
        #endif
    }

    /// Writes the sample transcripts onto the first few seeded videos with pictures.
    /// DEBUG-only, so it cannot ship; driven by `-quokkaSampleTranscripts YES`.
    func seedSampleTranscriptsIfRequested() {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "quokkaSampleTranscripts"), let store else { return }
        let targets = items.filter { $0.platform == .youtube && $0.id != nil }.prefix(SampleTranscripts.all.count)
        var planted: [Int] = []
        for (item, sample) in zip(targets, SampleTranscripts.all) {
            guard let id = item.id else { continue }
            try? store.setTranscript(itemID: id, sample)
            planted.append(Int(id))
        }
        UserDefaults.standard.set(planted, forKey: Self.sampleIDsKey)
        logger.info("Planted \(planted.count) sample transcripts")
        #endif
    }
}
