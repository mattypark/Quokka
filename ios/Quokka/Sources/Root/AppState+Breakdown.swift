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

    /// Saves a pasted link the same way the share sheet does, and starts its thumbnail.
    ///
    /// Returns false when the text is not a link Quokka can file -- the caller says so rather
    /// than pretending something was saved.
    @discardableResult
    func saveLink(_ raw: String) -> Bool {
        guard let store,
              let link = LinkCanonicaliser.canonicalise(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return false }
        do {
            try store.insert([Item(link: link, origin: .manual)])
            try reload()
            enrich()
            return true
        } catch {
            report(error)
            return false
        }
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
