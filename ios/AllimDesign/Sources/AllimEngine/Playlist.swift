import Foundation

/// A named collection a person actually works out of.
///
/// Deliberately separate from the author grouping the library already has. Those are derived
/// -- "everything from kitchen.studio" is a fact about the data, true whether or not anyone
/// wanted it. A playlist is a decision: "Wellness Series" exists because somebody made it, and
/// it means whatever they say it means.
///
/// Both are useful and they are not the same thing, which is why author grouping stays a
/// filter over the library rather than being promoted into this table.
public struct Playlist: Codable, Sendable, Equatable, Identifiable {
    public var id: Int64?
    public var name: String
    public var note: String?
    /// The item whose thumbnail is the cover. Nil means fall back to a mosaic of contents.
    public var coverItemID: Int64?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: Int64? = nil,
        name: String,
        note: String? = nil,
        coverItemID: Int64? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.note = note
        self.coverItemID = coverItemID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// "4 ideas | Updated 2hr ago" -- the subtitle under a playlist's name.
    ///
    /// The count is passed in rather than stored on the row. A denormalised counter is one
    /// more thing that can disagree with the table it summarises, and counting ideas is an
    /// indexed lookup, not a table scan.
    public func subtitle(ideaCount: Int, relativeTo now: Date = Date()) -> String {
        let ideas = ideaCount == 1 ? "1 idea" : "\(ideaCount) ideas"

        let elapsed = now.timeIntervalSince(updatedAt)
        if elapsed < 60 { return "\(ideas) | Updated just now" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "\(ideas) | Updated \(formatter.localizedString(for: updatedAt, relativeTo: now))"
    }
}

/// Which videos a given idea was built from.
///
/// A join rather than a column on either side: one idea cites several videos, and one video
/// inspires several ideas. Modelling it as an array on `Idea` would make "what did this reel
/// lead to?" a scan of every idea in the library.
public struct IdeaSource: Codable, Sendable, Equatable, Hashable {
    public let ideaID: Int64
    public let itemID: Int64
    /// Keeps the inspiration grid in the order it was assembled rather than in insertion order
    /// by id, so a person can arrange it and have it stay arranged.
    public let position: Int

    public init(ideaID: Int64, itemID: Int64, position: Int = 0) {
        self.ideaID = ideaID
        self.itemID = itemID
        self.position = position
    }
}
