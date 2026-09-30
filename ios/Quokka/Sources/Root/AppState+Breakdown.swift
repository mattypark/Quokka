import Foundation
import QuokkaEngine

/// What the breakdown screens read: the videos ready to break down and the ones still waiting
/// for words, a way to ask for a transcript, and a way to add by link.
///
/// Same shape as the other AppState extensions -- pass-throughs with errors reported in one
/// place, so no view holds a `try`.
@MainActor
extension AppState {

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

    /// What this person's saves say about their taste. Read from the whole library and every
    /// breakdown, on the phone -- the recent five thousand saves and five hundred breakdowns,
    /// which is plenty for a pattern and bounded so a huge library stays quick.
    func tasteProfile() -> TasteProfile {
        guard let store else { return TasteProfile.build(items: [], breakdowns: []) }
        var all: [Item] = []
        var cursor: ItemCursor?
        repeat {
            guard let page = try? store.page(after: cursor, limit: 500) else { break }
            all.append(contentsOf: page.items)
            cursor = page.cursor
        } while cursor != nil && all.count < 5_000
        let breakdowns = transcribedItems(limit: 500).compactMap { item in
            item.id.flatMap(breakdown(forItem:))
        }
        return TasteProfile.build(items: all, breakdowns: breakdowns)
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

    /// Transcribes the newest video of a platform at launch, to prove the ladder end to end
    /// without a hand on the simulator. DEBUG-only; `-quokkaTranscribe tiktok`.
    func transcribeIfRequested() {
        #if DEBUG
        guard let name = UserDefaults.standard.string(forKey: "quokkaTranscribe"),
              let platform = Platform(rawValue: name),
              let target = untranscribedVideos(limit: 50).first(where: { $0.platform == platform }),
              let id = target.id
        else { return }
        logger.info("Transcribing \(target.url, privacy: .public) on request")
        requestTranscript(id)
        #endif
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
