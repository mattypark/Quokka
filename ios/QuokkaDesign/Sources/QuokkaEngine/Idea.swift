import Foundation

/// A script in progress.
///
/// This is the unit of work the whole product turns on. An `Item` is something you saved; an
/// `Idea` is what you are going to make because of it. Saving is table stakes -- the thing
/// worth building is what happens after.
///
/// Free of any database dependency, like `Item`: GRDB conformance is added in the app layer so
/// everything that reasons about an idea stays testable with `swift test` and no simulator.
public struct Idea: Codable, Sendable, Equatable, Identifiable {
    public var id: Int64?
    /// The idea in one line. What shows in a playlist row.
    public var title: String
    /// The script itself. Editable from the moment the idea exists, because whether the text
    /// arrived from a transcript or was typed by hand, it is the same field on the same screen.
    public var body: String
    /// The opening line -- the bit that stops the scroll.
    ///
    /// Held separately from `body` rather than parsed out of it on demand. A hook is worth
    /// looking at on its own, and re-deriving it from prose every time it is displayed would
    /// mean the answer could change under you between two renders of the same screen.
    public var hook: String?
    /// The source video's words, when there are any. Distinct from `body`: the transcript is
    /// what someone else said, the body is what you are going to say.
    public var transcript: String?
    public var playlistID: Int64?
    public var status: Status
    public var createdAt: Date
    public var modifiedAt: Date
    /// True when `body` is placeholder text rather than anything derived from a real video.
    ///
    /// Carried on the row rather than inferred, so the screen can say so plainly. Showing
    /// invented text as a real transcript would be the product lying, which is categorically
    /// worse than an obvious placeholder.
    public var isSample: Bool

    /// Tracked from the start even though the planner screen is not built yet, so that ideas
    /// created before it exists are not all stranded in a default state when it arrives.
    public enum Status: String, Codable, Sendable, CaseIterable {
        case todo
        case completed
        case skipped
    }

    public init(
        id: Int64? = nil,
        title: String,
        body: String = "",
        hook: String? = nil,
        transcript: String? = nil,
        playlistID: Int64? = nil,
        status: Status = .todo,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        isSample: Bool = false
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.hook = hook
        self.transcript = transcript
        self.playlistID = playlistID
        self.status = status
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isSample = isSample
    }

    /// Whether there is anything to copy. Drives whether the copy control is even offered --
    /// a button that copies an empty string is worse than no button.
    public var hasScript: Bool {
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// "Modified just now", "Modified 2 hours ago".
    ///
    /// Lives on the model rather than in a view because two different screens show it and they
    /// must not drift into two different phrasings of the same fact.
    public func modifiedDescription(relativeTo now: Date = Date()) -> String {
        let elapsed = now.timeIntervalSince(modifiedAt)
        // Under a minute reads as "just now" rather than "0 minutes ago", which is technically
        // true and sounds like a bug.
        if elapsed < 60 { return "Modified just now" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Modified \(formatter.localizedString(for: modifiedAt, relativeTo: now))"
    }
}
