import Foundation

/// Parses a Meta "Download Your Information" export.
///
/// This is the only lawful way to get at an Instagram DM history. The Graph API's messaging
/// surface is business-accounts-only, inbound-only and 24-hour windowed, and automating a
/// personal inbox violates Instagram's terms and gets accounts banned. The export has no such
/// problem, and it is strictly better data: the complete history, in one file, with no rate
/// limit.
///
/// Everything here is pure -- it takes bytes and returns values -- so the whole parser is
/// testable against fixtures without a device, a network or a real export.
public enum InstagramExport {

    /// One extracted share, before canonicalisation.
    public struct Share: Sendable, Equatable {
        public let link: String
        /// The reel's own author, where the export records it. This is the single most useful
        /// field in the file: Instagram serves no metadata to an unauthenticated client, so
        /// without it a saved reel is an opaque URL forever.
        public let contentOwner: String?
        /// Any text sent alongside, which is often what the post is about.
        public let shareText: String?
        public let sentAt: Date
        public let sender: String?
        public let origin: Item.Origin
        /// The thread this came from, so an import can be filtered to one conversation.
        public let threadTitle: String?

        public init(
            link: String,
            contentOwner: String? = nil,
            shareText: String? = nil,
            sentAt: Date,
            sender: String? = nil,
            origin: Item.Origin,
            threadTitle: String? = nil
        ) {
            self.link = link
            self.contentOwner = contentOwner
            self.shareText = shareText
            self.sentAt = sentAt
            self.sender = sender
            self.origin = origin
            self.threadTitle = threadTitle
        }
    }

    /// A conversation found in the export, for letting someone pick which one to import.
    public struct Thread: Sendable, Equatable, Identifiable {
        public var id: String { path }
        public let path: String
        public let title: String
        public let participants: [String]
        public let shareCount: Int

        public init(path: String, title: String, participants: [String], shareCount: Int) {
            self.path = path
            self.title = title
            self.participants = participants
            self.shareCount = shareCount
        }
    }

    // MARK: - Mojibake

    /// Repairs Instagram's broken text encoding.
    ///
    /// Meta writes UTF-8 bytes and then escapes each *byte* as a separate JSON `\u00XX`
    /// codepoint, so a decoder that does the right thing produces "Ã°Å¸â€™â€“" where the
    /// original had an emoji. Re-encoding the string as Latin-1 recovers the original byte
    /// sequence, which then decodes as the UTF-8 it always was.
    ///
    /// Applied defensively: if the round-trip fails, the original is returned rather than
    /// throwing away text that was already correct.
    public static func repairEncoding(_ text: String) -> String {
        guard text.unicodeScalars.contains(where: { $0.value > 0x7F && $0.value <= 0xFF }) else {
            return text
        }
        guard let latin1 = text.data(using: .isoLatin1),
              let repaired = String(data: latin1, encoding: .utf8)
        else { return text }
        return repaired
    }

    // MARK: - Direct messages

    /// Reads one `message_*.json`.
    ///
    /// `only` filters to a conversation by participant or title, case-insensitively and by
    /// substring, because the export's folder names are mangled (`someone_1234567890`) and
    /// nobody knows their own thread's exact recorded title.
    public static func shares(inMessageFile data: Data, only participant: String? = nil) throws -> [Share] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }

        let participants = (root["participants"] as? [[String: Any]] ?? [])
            .compactMap { ($0["name"] as? String).map(repairEncoding) }
        let title = (root["title"] as? String).map(repairEncoding)

        if let wanted = participant?.lowercased(), !wanted.isEmpty {
            let haystack = (participants + [title].compactMap { $0 }).map { $0.lowercased() }
            guard haystack.contains(where: { $0.contains(wanted) || wanted.contains($0) }) else { return [] }
        }

        let messages = root["messages"] as? [[String: Any]] ?? []
        return messages.compactMap { message in
            guard let share = message["share"] as? [String: Any],
                  let link = share["link"] as? String,
                  !link.isEmpty
            else { return nil }

            // timestamp_ms is milliseconds. Reading it as seconds dates the whole library to
            // the year 55000, which sorts every import above everything else forever.
            let millis = (message["timestamp_ms"] as? Double) ?? 0

            return Share(
                link: link,
                contentOwner: (share["original_content_owner"] as? String).map(repairEncoding),
                shareText: (share["share_text"] as? String).map(repairEncoding)
                    ?? (message["content"] as? String).map(repairEncoding),
                sentAt: Date(timeIntervalSince1970: millis / 1000),
                sender: (message["sender_name"] as? String).map(repairEncoding),
                origin: .instagramDM,
                threadTitle: title
            )
        }
    }

    /// Summarises a thread without importing it, so a picker can list conversations by how
    /// many shares each holds.
    public static func thread(inMessageFile data: Data, path: String) throws -> Thread? {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let participants = (root["participants"] as? [[String: Any]] ?? [])
            .compactMap { ($0["name"] as? String).map(repairEncoding) }
        let title = (root["title"] as? String).map(repairEncoding) ?? participants.first ?? path
        let count = (root["messages"] as? [[String: Any]] ?? []).count { $0["share"] != nil }
        return Thread(path: path, title: title, participants: participants, shareCount: count)
    }

    // MARK: - Saved and liked

    /// Reads `saved_posts.json`. The href sits inside a `string_map_data` dictionary whose key
    /// is a human-readable label ("Saved on"), so the value is found by shape rather than by
    /// that key -- Meta localises and renames it.
    public static func shares(inSavedFile data: Data) throws -> [Share] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let entries = (root["saved_saved_media"] as? [[String: Any]])
            ?? (root.values.first { $0 is [[String: Any]] } as? [[String: Any]])
            ?? []

        return entries.compactMap { entry in
            let owner = (entry["title"] as? String).map(repairEncoding)
            guard let map = entry["string_map_data"] as? [String: Any] else { return nil }
            for value in map.values {
                guard let field = value as? [String: Any],
                      let href = field["href"] as? String, !href.isEmpty
                else { continue }
                let timestamp = (field["timestamp"] as? Double) ?? 0
                return Share(
                    link: href,
                    contentOwner: owner,
                    sentAt: Date(timeIntervalSince1970: timestamp),
                    origin: .instagramSaved
                )
            }
            return nil
        }
    }

    /// Reads `liked_posts.json`, which uses a list rather than a map for the same data.
    public static func shares(inLikedFile data: Data) throws -> [Share] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let entries = (root["likes_media_likes"] as? [[String: Any]])
            ?? (root.values.first { $0 is [[String: Any]] } as? [[String: Any]])
            ?? []

        return entries.compactMap { entry in
            let owner = (entry["title"] as? String).map(repairEncoding)
            guard let list = entry["string_list_data"] as? [[String: Any]],
                  let first = list.first,
                  let href = first["href"] as? String, !href.isEmpty
            else { return nil }
            let timestamp = (first["timestamp"] as? Double) ?? 0
            return Share(
                link: href,
                contentOwner: owner,
                sentAt: Date(timeIntervalSince1970: timestamp),
                origin: .instagramLiked
            )
        }
    }

    // MARK: - Turning shares into items

    /// Canonicalises, drops anything unparseable, and collapses duplicates.
    ///
    /// The same reel routinely appears in all three sources -- DM'd to yourself, then saved,
    /// then liked. Earliest wins, so the library records when a thing was first noticed rather
    /// than when it was last touched.
    public static func items(from shares: [Share]) -> [Item] {
        var byURL: [String: Item] = [:]

        for share in shares {
            guard let link = LinkCanonicaliser.canonicalise(share.link) else { continue }
            let key = link.url.absoluteString

            var item = Item(link: link, savedAt: share.sentAt, origin: share.origin)
            // The author from the export beats the one parsed out of the URL: a reel URL
            // usually has no handle in it at all, and this field is the only place the
            // author survives for a platform that publishes nothing.
            item.author = share.contentOwner ?? link.author
            item.caption = share.shareText

            if let existing = byURL[key] {
                var merged = existing.savedAt <= item.savedAt ? existing : item
                // Keep whichever copy actually carried metadata, regardless of which is older.
                merged.author = existing.author ?? item.author
                merged.caption = existing.caption ?? item.caption
                byURL[key] = merged
            } else {
                byURL[key] = item
            }
        }

        return byURL.values.sorted { $0.savedAt < $1.savedAt }
    }
}

private extension Array {
    func count(where predicate: (Element) -> Bool) -> Int {
        reduce(0) { predicate($1) ? $0 + 1 : $0 }
    }
}
