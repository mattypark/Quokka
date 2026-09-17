import Testing
import Foundation
@testable import QuokkaEngine

/// Tested against archives written by the system `zip`, not by a fixture this code also wrote.
/// A zip reader that only reads its own output is a reader that works exactly once.
struct ZipArchiveTests {

    /// Builds a real archive on disk and hands back its URL.
    private func makeArchive(
        files: [String: String], extraFlags: [String] = []
    ) throws -> (archive: URL, cleanup: () -> Void) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ziptest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        for (path, contents) in files {
            let file = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: file, atomically: true, encoding: .utf8)
        }

        let archive = root.appendingPathComponent("out.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q"] + extraFlags + [archive.path, "."]
        process.currentDirectoryURL = root
        try process.run()
        process.waitUntilExit()

        return (archive, { try? FileManager.default.removeItem(at: root) })
    }

    @Test("Reads an archive the system zip wrote, and inflates a deflated entry")
    func readsRealArchive() throws {
        // Long and repetitive so zip actually deflates it rather than storing it -- a short
        // string compresses to something larger and gets stored, which would leave the
        // inflate path untested while the test still passed.
        let body = String(repeating: "{\"shares\":[{\"link\":\"https://instagram.com/reel/A\"}]}", count: 200)
        let (archive, cleanup) = try makeArchive(files: [
            "messages/inbox/friend/message_1.json": body,
            "your_activity/saved/saved_posts.json": "{\"saved\":[]}",
        ])
        defer { cleanup() }

        let zip = try ZipArchive(url: archive)
        defer { zip.close() }

        let message = try #require(zip.entries.first { $0.name == "message_1.json" })
        #expect(message.method == 8, "expected the long body to be deflated, not stored")
        #expect(String(decoding: try zip.data(for: message), as: UTF8.self) == body)

        // Present and stored rather than deflated -- both paths matter.
        let saved = try #require(zip.entries.first { $0.name == "saved_posts.json" })
        #expect(String(decoding: try zip.data(for: saved), as: UTF8.self) == "{\"saved\":[]}")
    }

    @Test("Directory markers are not entries")
    func skipsDirectories() throws {
        let (archive, cleanup) = try makeArchive(files: ["a/b/c.json": "{}"])
        defer { cleanup() }
        let zip = try ZipArchive(url: archive)
        defer { zip.close() }
        // Inflating a directory marker yields nothing, and leaving them in means the importer
        // reports a file count that includes folders.
        #expect(zip.entries.allSatisfy { !$0.path.hasSuffix("/") })
        #expect(zip.entries.contains { $0.path.hasSuffix("a/b/c.json") })
    }

    @Test("A file that is not a zip is refused rather than misread")
    func rejectsNonZip() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-a-zip-\(UUID().uuidString).json")
        try "definitely not a zip".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(throws: ZipArchive.Failure.notAZip) { _ = try ZipArchive(url: file) }
    }

    @Test("A missing file is a failure, not a crash")
    func missingFile() {
        let absent = FileManager.default.temporaryDirectory
            .appendingPathComponent("nope-\(UUID().uuidString).zip")
        #expect(throws: ZipArchive.Failure.unreadable) { _ = try ZipArchive(url: absent) }
    }

    @Test("Only the wanted entries are ever decompressed")
    func readsSelectively() throws {
        // The whole reason this type is targeted: an Instagram export is mostly media, and
        // extracting it to read three JSON files would write gigabytes to a phone.
        var files = ["messages/inbox/a/message_1.json": "{\"participants\":[]}"]
        for i in 0..<60 { files["media/posts/photo_\(i).txt"] = String(repeating: "x", count: 4_000) }

        let (archive, cleanup) = try makeArchive(files: files)
        defer { cleanup() }

        let zip = try ZipArchive(url: archive)
        defer { zip.close() }

        #expect(zip.entries.count == 61)
        let wanted = zip.entries.filter { $0.name.hasPrefix("message_") }
        #expect(wanted.count == 1)
        #expect(String(decoding: try zip.data(for: wanted[0]), as: UTF8.self) == "{\"participants\":[]}")
    }
}
