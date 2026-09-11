import Testing
import Foundation
@testable import AllimEngine

/// The inbox is a file format shared across a process boundary, so it gets pinned like one.
/// A silent encoding change here means saves made by an old extension against a new app
/// disappear without an error.
struct ShareInboxTests {

    @Test("A record round-trips through JSON with its probe intact")
    func roundTrip() throws {
        let record = ShareInboxRecord(
            rawURL: "https://www.instagram.com/reel/C8xYzAbCdEf/",
            rawText: "look at this",
            imageFilename: "abc.heic",
            probe: [ProviderProbe(index: 0, typeIdentifiers: ["public.url", "public.image"])]
        )
        let decoded = try ShareInbox.decoder.decode(
            ShareInboxRecord.self, from: ShareInbox.encoder.encode(record)
        )

        #expect(decoded.id == record.id)
        #expect(decoded.rawURL == record.rawURL)
        #expect(decoded.rawText == record.rawText)
        #expect(decoded.imageFilename == record.imageFilename)
        #expect(decoded.probe == record.probe)
        #expect(decoded.probe.first?.typeIdentifiers.contains("public.image") == true)
    }

    @Test("Timestamps survive to the millisecond, which is the format's stated precision")
    func timestampPrecision() throws {
        // The wire format is ISO-8601 with three fractional digits, so a Date does not come
        // back bit-identical. Milliseconds is a deliberate choice over a lossless Double: the
        // inbox is meant to stay readable with `cat` when a save goes missing, and nobody
        // shares two posts inside one millisecond. What must NOT happen is truncation to whole
        // seconds, which would collapse an entire import batch onto one instant.
        let record = ShareInboxRecord(rawURL: "https://youtu.be/abc", rawText: nil)
        let data = try ShareInbox.encoder.encode(record)
        let decoded = try ShareInbox.decoder.decode(ShareInboxRecord.self, from: data)

        let drift = abs(decoded.receivedAt.timeIntervalSince(record.receivedAt))
        #expect(drift < 0.001)

        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("."), "the encoded date carries fractional seconds")
    }

    @Test("Sub-second saves keep distinct timestamps, so an import batch keeps its order")
    func burstSavesStayOrdered() throws {
        // The failure this guards against: a whole-second format stamps 3,000 imported reels
        // with the same time, and the library loses the order they arrived in.
        let a = ShareInboxRecord(rawURL: "https://youtu.be/a", rawText: nil)
        let b = ShareInboxRecord(receivedAt: a.receivedAt.addingTimeInterval(0.004),
                                 rawURL: "https://youtu.be/b", rawText: nil)

        let da = try ShareInbox.decoder.decode(ShareInboxRecord.self, from: ShareInbox.encoder.encode(a))
        let db = try ShareInbox.decoder.decode(ShareInboxRecord.self, from: ShareInbox.encoder.encode(b))
        #expect(da.receivedAt < db.receivedAt)
    }

    @Test("A URL attachment wins over the shared text")
    func urlBeatsText() {
        let record = ShareInboxRecord(rawURL: "https://youtu.be/abc", rawText: "watch this https://spam.example")
        #expect(record.linkCandidate == "https://youtu.be/abc")
    }

    @Test("Text is used when no URL attachment came through")
    func fallsBackToText() {
        // TikTok's share sheet routinely sends only a sentence, so this is the normal path
        // for one of the platforms, not an edge case.
        let record = ShareInboxRecord(rawURL: nil, rawText: "Check this out https://vm.tiktok.com/ZMxyz/ come watch")
        #expect(LinkCanonicaliser.canonicalise(record.linkCandidate ?? "")?.platform == .tiktok)
    }

    @Test("An empty URL string does not beat usable text")
    func emptyURLIgnored() {
        let record = ShareInboxRecord(rawURL: "", rawText: "https://youtu.be/abc")
        #expect(record.linkCandidate == "https://youtu.be/abc")
    }

    @Test("A shared video is carried in the record and flagged")
    func recordCarriesMovie() throws {
        // The lawful route to a transcript: the user saves a reel to Photos and shares the
        // file. No platform hands a video to the share sheet for a link, and every sanctioned
        // API refuses the media for a video the user does not own -- so this is the only door,
        // and it has to survive the wire format.
        let record = ShareInboxRecord(rawURL: nil, rawText: nil, movieFilename: "abc.mov")
        #expect(record.carriesMovie == true)

        let decoded = try ShareInbox.decoder.decode(
            ShareInboxRecord.self, from: ShareInbox.encoder.encode(record)
        )
        #expect(decoded.movieFilename == "abc.mov")
        #expect(decoded.carriesMovie == true)
    }

    @Test("A link-only share carries no movie")
    func linkShareHasNoMovie() {
        #expect(ShareInboxRecord(rawURL: "https://youtu.be/abc", rawText: nil).carriesMovie == false)
    }

    @Test("Pending records drain oldest first, so import order matches save order")
    func drainOrder() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("allim-inbox-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var written: [UUID] = []
        for index in 0..<3 {
            let record = ShareInboxRecord(rawURL: "https://example.com/\(index)", rawText: nil)
            let url = ShareInbox.recordURL(for: record.id, in: dir)
            try ShareInbox.encoder.encode(record).write(to: url)
            // Distinct modification dates; the filesystem's timestamp resolution is coarse
            // enough that three writes in a tight loop can otherwise land identically.
            try FileManager.default.setAttributes(
                [.modificationDate: Date().addingTimeInterval(TimeInterval(index))], ofItemAtPath: url.path
            )
            written.append(record.id)
        }

        let pending = ShareInbox.pendingRecords(in: dir)
        #expect(pending.count == 3)
        let ids = pending.map { $0.deletingPathExtension().lastPathComponent }
        #expect(ids == written.map(\.uuidString))
    }

    @Test("Non-JSON files in the inbox are ignored rather than parsed")
    func ignoresNonJSON() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("allim-inbox-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Image blobs live alongside their records; the drain must not try to decode them.
        try Data([0xFF, 0xD8]).write(to: dir.appendingPathComponent("payload.heic"))
        #expect(ShareInbox.pendingRecords(in: dir).isEmpty)
    }
}
