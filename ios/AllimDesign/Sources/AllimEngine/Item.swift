import Foundation

/// One saved thing.
///
/// Deliberately free of any database dependency: GRDB conformance is added in the app layer,
/// so the model and everything that reasons about it stay testable with `swift test` and no
/// simulator.
public struct Item: Codable, Sendable, Equatable, Identifiable {
    public var id: Int64?
    /// The canonical URL. Unique -- this is the dedupe key, and it is why the same post
    /// arriving from a DM, from Saved and from Liked collapses to one row.
    public var url: String
    public var platform: Platform
    public var contentID: String?
    public var author: String?
    public var title: String?
    public var caption: String?
    /// The keyset cursor, paired with `id` to break ties.
    public var savedAt: Date
    /// Native aspect ratio, so the masonry grid can lay a tile out before its image loads.
    public var aspectRatio: Double?
    /// The average colour of the thumbnail, packed 0x00RRGGBB.
    ///
    /// Four bytes, resident in the row. This replaces a ThumbHash or BlurHash placeholder on
    /// purpose: those hide *network* latency, and there is none here -- the thumbnail is a
    /// local BLOB read. Immich measured a 61% cost for generating both in a near-identical
    /// grid and removed theirs. A flat colour costs nothing to decode and is enough to fill a
    /// cell that resolves in about two milliseconds.
    public var averageColor: Int?
    public var origin: Origin
    public var thumbnailState: ThumbnailState
    /// A JSON array, written by the on-device tagger or by Claude through the mirror.
    public var tags: String?

    public enum Origin: String, Codable, Sendable {
        case shareSheet
        case instagramDM
        case instagramSaved
        case instagramLiked
        case manual
    }

    public enum ThumbnailState: String, Codable, Sendable {
        /// Not fetched yet.
        case pending
        /// Bytes are in the thumbnail table.
        case stored
        /// The platform serves nothing to an unauthenticated client. A terminal state, not a
        /// retry state -- Instagram, Pinterest and X land here and must never be re-queued.
        case unavailable
        /// Tried and failed for a reason that might not repeat. Eligible for one retry.
        case failed
    }

    public init(
        id: Int64? = nil,
        url: String,
        platform: Platform,
        contentID: String? = nil,
        author: String? = nil,
        title: String? = nil,
        caption: String? = nil,
        savedAt: Date = Date(),
        aspectRatio: Double? = nil,
        averageColor: Int? = nil,
        origin: Origin = .shareSheet,
        thumbnailState: ThumbnailState = .pending,
        tags: String? = nil
    ) {
        self.id = id
        self.url = url
        self.platform = platform
        self.contentID = contentID
        self.author = author
        self.title = title
        self.caption = caption
        self.savedAt = savedAt
        self.aspectRatio = aspectRatio
        self.averageColor = averageColor
        self.origin = origin
        self.thumbnailState = thumbnailState
        self.tags = tags
    }

    /// Builds an item from a canonicalised link.
    public init(link: CanonicalLink, savedAt: Date = Date(), origin: Origin = .shareSheet) {
        self.init(
            url: link.url.absoluteString,
            platform: link.platform,
            contentID: link.contentID,
            author: link.author,
            savedAt: savedAt,
            origin: origin,
            // A platform that serves nothing starts terminal rather than pending, so the
            // enrichment queue never picks it up at all.
            thumbnailState: link.platform.thumbnailDurability == .unreachable ? .unavailable : .pending
        )
    }
}

/// A page of items plus the cursor that continues it.
///
/// Keyset, never OFFSET. New saves land at the head of a reverse-chronological list
/// constantly, and OFFSET shifts every row down by one when they do -- so page two either
/// repeats a row or skips one. Meta's TAO pages its association lists exactly this way, for
/// the same stated reason: most of the data is old, but most queries want the newest slice.
public struct ItemPage: Sendable, Equatable {
    public let items: [Item]
    public let cursor: ItemCursor?

    public init(items: [Item], cursor: ItemCursor?) {
        self.items = items
        self.cursor = cursor
    }
}

/// Where the next page starts. `savedAt` alone is not enough: a bulk import writes thousands
/// of rows and ties are certain, so `id` breaks them.
public struct ItemCursor: Sendable, Equatable, Codable {
    public let savedAt: Date
    public let id: Int64

    public init(savedAt: Date, id: Int64) {
        self.savedAt = savedAt
        self.id = id
    }
}
