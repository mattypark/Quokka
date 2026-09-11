import Testing
import Foundation
@testable import QuokkaEngine

/// Fixtures are shaped like the real export, including its two genuinely awkward properties:
/// millisecond timestamps, and text that has been UTF-8 encoded and then escaped byte-by-byte
/// as Latin-1.
struct InstagramExportTests {

    private func json(_ object: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    private func messageFile(
        participants: [String],
        title: String,
        messages: [[String: Any]]
    ) -> Data {
        json([
            "participants": participants.map { ["name": $0] },
            "title": title,
            "messages": messages,
        ])
    }

    // MARK: - Direct messages

    @Test("Shared reels are pulled out of a DM thread with their author and timestamp")
    func extractsShares() throws {
        let data = messageFile(
            participants: ["matthew", "my.other.account"],
            title: "my.other.account",
            messages: [
                [
                    "sender_name": "matthew",
                    "timestamp_ms": 1_700_000_000_000,
                    "share": [
                        "link": "https://www.instagram.com/reel/C8xYzAbCdEf/",
                        "original_content_owner": "kitchen.studio",
                        "share_text": "the lighting here",
                    ],
                ],
                ["sender_name": "matthew", "timestamp_ms": 1_700_000_001_000, "content": "no link in this one"],
            ]
        )

        let shares = try InstagramExport.shares(inMessageFile: data)
        #expect(shares.count == 1)
        #expect(shares.first?.contentOwner == "kitchen.studio")
        #expect(shares.first?.shareText == "the lighting here")
        #expect(shares.first?.origin == .instagramDM)
    }

    @Test("timestamp_ms is milliseconds, not seconds")
    func timestampIsMilliseconds() throws {
        // Reading this field as seconds dates the library to the year 55000, which sorts an
        // entire import above everything else, permanently.
        let data = messageFile(
            participants: ["matthew"], title: "t",
            messages: [[
                "timestamp_ms": 1_700_000_000_000,
                "share": ["link": "https://www.instagram.com/reel/AAA/"],
            ]]
        )
        let sent = try #require(try InstagramExport.shares(inMessageFile: data).first?.sentAt)
        #expect(abs(sent.timeIntervalSince1970 - 1_700_000_000) < 1)
    }

    @Test("An import can be filtered to one conversation")
    func filtersToOneAccount() throws {
        let wanted = messageFile(
            participants: ["matthew", "my.other.account"], title: "my.other.account",
            messages: [["timestamp_ms": 1, "share": ["link": "https://www.instagram.com/reel/AAA/"]]]
        )
        let other = messageFile(
            participants: ["matthew", "someone.else"], title: "someone.else",
            messages: [["timestamp_ms": 1, "share": ["link": "https://www.instagram.com/reel/BBB/"]]]
        )

        #expect(try InstagramExport.shares(inMessageFile: wanted, only: "my.other.account").count == 1)
        #expect(try InstagramExport.shares(inMessageFile: other, only: "my.other.account").isEmpty)
        // Substring and case-insensitive: nobody knows the exact title the export recorded,
        // and the folder names are mangled with a numeric suffix.
        #expect(try InstagramExport.shares(inMessageFile: wanted, only: "My.Other").count == 1)
    }

    @Test("A thread can be summarised without importing it")
    func summarisesThreads() throws {
        let data = messageFile(
            participants: ["matthew", "my.other.account"], title: "my.other.account",
            messages: [
                ["timestamp_ms": 1, "share": ["link": "https://www.instagram.com/reel/AAA/"]],
                ["timestamp_ms": 2, "share": ["link": "https://www.instagram.com/reel/BBB/"]],
                ["timestamp_ms": 3, "content": "just talking"],
            ]
        )
        let thread = try #require(try InstagramExport.thread(inMessageFile: data, path: "inbox/x_123"))
        #expect(thread.shareCount == 2)
        #expect(thread.participants.contains("my.other.account"))
    }

    // MARK: - Mojibake

    @Test("Instagram's byte-escaped UTF-8 is repaired")
    func repairsMojibake() {
        // What the file literally contains for an emoji: each UTF-8 byte escaped as its own
        // \u00XX codepoint. A correct JSON decoder produces this, and it is wrong.
        #expect(InstagramExport.repairEncoding("\u{00f0}\u{009f}\u{0092}\u{0096}") == "💖")
        #expect(InstagramExport.repairEncoding("caf\u{00c3}\u{00a9}") == "café")
    }

    @Test("Text that is already correct is left alone")
    func leavesCleanTextAlone() {
        // The repair must be safe to apply to everything, since there is no flag in the file
        // saying which strings are affected.
        #expect(InstagramExport.repairEncoding("plain ascii") == "plain ascii")
        #expect(InstagramExport.repairEncoding("한글") == "한글")
        #expect(InstagramExport.repairEncoding("💖") == "💖")
    }

    // MARK: - Saved and liked

    @Test("Saved posts are read despite the label-keyed structure")
    func readsSaved() throws {
        // The href hides inside a dictionary keyed by a human-readable label that Meta
        // localises and renames, so it is found by shape rather than by key.
        let data = json([
            "saved_saved_media": [[
                "title": "kitchen.studio",
                "string_map_data": ["Saved on": [
                    "href": "https://www.instagram.com/p/C8xYzAbCdEf/",
                    "timestamp": 1_700_000_000,
                ]],
            ]]
        ])
        let shares = try InstagramExport.shares(inSavedFile: data)
        #expect(shares.count == 1)
        #expect(shares.first?.origin == .instagramSaved)
        #expect(shares.first?.contentOwner == "kitchen.studio")
    }

    @Test("Liked posts use a list rather than a map for the same data")
    func readsLiked() throws {
        let data = json([
            "likes_media_likes": [[
                "title": "someone",
                "string_list_data": [[
                    "href": "https://www.instagram.com/reel/D1aBcDeFgHi/",
                    "timestamp": 1_700_000_500,
                ]],
            ]]
        ])
        #expect(try InstagramExport.shares(inLikedFile: data).first?.origin == .instagramLiked)
    }

    // MARK: - Deduplication

    @Test("The same reel from all three sources collapses to one item, earliest wins")
    func dedupesAcrossSources() {
        // This is the whole reason all three can be imported in one pass. A reel gets DM'd,
        // then saved, then liked -- three entries, one thing.
        let shares = [
            InstagramExport.Share(
                link: "https://www.instagram.com/reel/C8xYzAbCdEf/?igshid=abc",
                contentOwner: "kitchen.studio",
                sentAt: Date(timeIntervalSince1970: 1_700_000_000),
                origin: .instagramDM
            ),
            InstagramExport.Share(
                link: "https://instagram.com/p/C8xYzAbCdEf",
                sentAt: Date(timeIntervalSince1970: 1_700_009_000),
                origin: .instagramSaved
            ),
            InstagramExport.Share(
                link: "https://www.instagram.com/tv/C8xYzAbCdEf/",
                sentAt: Date(timeIntervalSince1970: 1_700_005_000),
                origin: .instagramLiked
            ),
        ]

        let items = InstagramExport.items(from: shares)
        #expect(items.count == 1)
        #expect(items.first?.url == "https://www.instagram.com/p/C8xYzAbCdEf/")
        #expect(items.first?.savedAt.timeIntervalSince1970 == 1_700_000_000)
        // The author survives even though it was only recorded on one of the three.
        #expect(items.first?.author == "kitchen.studio")
    }

    @Test("Imported Instagram items never enter the enrichment queue")
    func importedItemsAreTerminal() {
        // Instagram serves nothing to an unauthenticated client, so a few thousand imported
        // reels marked .pending would be a queue grinding against a wall forever.
        let items = InstagramExport.items(from: [
            InstagramExport.Share(
                link: "https://www.instagram.com/reel/AAA/",
                sentAt: Date(),
                origin: .instagramDM
            )
        ])
        #expect(items.first?.thumbnailState == .unavailable)
    }

    @Test("Unparseable links are dropped rather than stored as junk rows")
    func dropsGarbage() {
        let items = InstagramExport.items(from: [
            InstagramExport.Share(link: "", sentAt: Date(), origin: .instagramDM),
            InstagramExport.Share(link: "not a url at all", sentAt: Date(), origin: .instagramDM),
        ])
        #expect(items.isEmpty)
    }
}
