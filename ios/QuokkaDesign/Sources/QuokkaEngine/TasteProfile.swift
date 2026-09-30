import Foundation

/// What one person's saves say about their taste, read on their own phone.
///
/// Personal by construction: it is built from this library and nobody else's, it runs on the
/// device, and it gets sharper with every save and every breakdown -- the opposite of a feed
/// tuned on everyone. Rules, like `Breakdown`: every observation is a count someone could
/// check ("7 of 12 hooks you saved warn you off something"), never a guess dressed as insight.
public struct TasteProfile: Sendable, Equatable {
    public struct Share: Sendable, Equatable {
        public var name: String
        public var count: Int
    }

    public struct HookShare: Sendable, Equatable {
        public var kind: Breakdown.HookKind
        public var count: Int
    }

    public struct CheckRate: Sendable, Equatable {
        public var title: String
        public var passed: Int
        public var of: Int
        public var rate: Double { of == 0 ? 0 : Double(passed) / Double(of) }
    }

    public var saves: Int
    public var breakdowns: Int
    public var creators: [Share]
    public var platforms: [Share]
    public var hooks: [HookShare]
    public var checks: [CheckRate]
    /// The median pace of the videos broken down, in words a minute.
    public var medianPace: Int?
    /// 1 = Sunday ... 7 = Saturday, as `Calendar` counts.
    public var busiestWeekday: Int?
    public var busiestHour: Int?
    public var firstSave: Date?
    /// Plain sentences, strongest first. Each one is built from the counts above.
    public var notes: [String]
    /// A hook to try, shaped like the kind this person saves most.
    public var suggestedHook: String?

    /// Below this many breakdowns the patterns are noise, and the screen says so.
    public static let breakdownsToMatter = 3

    public var isEarly: Bool { breakdowns < Self.breakdownsToMatter }

    // MARK: - Building

    public static func build(
        items: [Item],
        breakdowns: [Breakdown],
        calendar: Calendar = .current
    ) -> TasteProfile {
        let creators = top(items.compactMap(\.author).filter { !$0.isEmpty }, limit: 5)
        let platforms = top(items.map(\.platform.displayName), limit: 6)

        var hookCounts: [Breakdown.HookKind: Int] = [:]
        for breakdown in breakdowns {
            for kind in breakdown.hook.kinds { hookCounts[kind, default: 0] += 1 }
        }
        let hooks = hookCounts
            .map { HookShare(kind: $0.key, count: $0.value) }
            .sorted { ($0.count, $1.kind.rawValue) > ($1.count, $0.kind.rawValue) }

        var checkTally: [String: (title: String, passed: Int, of: Int)] = [:]
        for breakdown in breakdowns {
            for check in breakdown.checks {
                var tally = checkTally[check.id] ?? (check.title, 0, 0)
                tally.of += 1
                if check.passed { tally.passed += 1 }
                checkTally[check.id] = tally
            }
        }
        let checks = checkTally.values
            .map { CheckRate(title: $0.title, passed: $0.passed, of: $0.of) }
            .sorted { ($0.rate, $1.title) > ($1.rate, $0.title) }

        let paces = breakdowns.compactMap(\.pacing.wordsPerMinute).sorted()
        let medianPace = paces.isEmpty ? nil : paces[paces.count / 2]

        let weekdays = items.map { calendar.component(.weekday, from: $0.savedAt) }
        let hours = items.map { calendar.component(.hour, from: $0.savedAt) }

        var profile = TasteProfile(
            saves: items.count,
            breakdowns: breakdowns.count,
            creators: creators,
            platforms: platforms,
            hooks: hooks,
            checks: checks,
            medianPace: medianPace,
            busiestWeekday: mode(weekdays),
            busiestHour: mode(hours),
            firstSave: items.map(\.savedAt).min(),
            notes: [],
            suggestedHook: hooks.first.map { Self.hookShape(for: $0.kind) })
        profile.notes = Self.notes(for: profile, calendar: calendar)
        return profile
    }

    // MARK: - Sentences

    static func notes(for profile: TasteProfile, calendar: Calendar) -> [String] {
        var notes: [String] = []
        let broken = profile.breakdowns

        if let top = profile.hooks.first, broken >= breakdownsToMatter {
            notes.append("\(top.count) of the \(broken) hooks you broke down \(verb(for: top.kind)).")
        }
        if let pace = profile.medianPace, broken >= breakdownsToMatter {
            let tempo = Breakdown.Tempo.of(wordsPerMinute: pace)
            notes.append("The videos you save talk at \(pace) words a minute — \(tempo.label.lowercased()).")
        }
        if let strongest = profile.checks.first, strongest.of >= breakdownsToMatter, strongest.rate >= 0.6 {
            notes.append("“\(strongest.title)” — \(strongest.passed) of \(strongest.of) of them do it. That is what you are drawn to.")
        }
        if let weakest = profile.checks.last, weakest.of >= breakdownsToMatter, weakest.rate <= 0.4,
           weakest.title != profile.checks.first?.title {
            notes.append("“\(weakest.title)” — only \(weakest.passed) of \(weakest.of). Room to do it better than they did.")
        }
        if let creator = profile.creators.first, creator.count >= 3 {
            notes.append("You keep coming back to \(creator.name): \(creator.count) saves.")
        }
        if let weekday = profile.busiestWeekday, let hour = profile.busiestHour, profile.saves >= 10 {
            // The whole weekday name in the person's own language.
            let formatter = DateFormatter()
            formatter.locale = calendar.locale ?? Locale(identifier: "en_US")
            let day = formatter.weekdaySymbols[(weekday - 1) % 7]
            notes.append("You save most on \(day) \(partOfDay(hour)).")
        }
        return notes
    }

    private static func verb(for kind: Breakdown.HookKind) -> String {
        switch kind {
        case .question: "ask a question"
        case .number: "put a number up front"
        case .warning: "warn you off something"
        case .claim: "make a bold claim"
        case .you: "talk straight to you"
        case .story: "open on a story"
        }
    }

    /// A fill-in-the-blank hook in the shape this person saves most.
    static func hookShape(for kind: Breakdown.HookKind) -> String {
        switch kind {
        case .question: "Why does nobody talk about [your topic]?"
        case .number: "3 things I wish I knew before [doing your thing]."
        case .warning: "Stop [doing the common thing] like this."
        case .claim: "The best [thing] nobody is using."
        case .you: "You’re [doing the thing] wrong. Here’s the fix."
        case .story: "I tried [your thing] for 30 days. Here’s what happened."
        }
    }

    private static func partOfDay(_ hour: Int) -> String {
        switch hour {
        case 5..<12: "mornings"
        case 12..<17: "afternoons"
        case 17..<22: "evenings"
        default: "late at night"
        }
    }

    // MARK: - Counting

    private static func top(_ values: [String], limit: Int) -> [Share] {
        Dictionary(grouping: values, by: { $0 })
            .map { Share(name: $0.key, count: $0.value.count) }
            .sorted { ($0.count, $1.name) > ($1.count, $0.name) }
            .prefix(limit)
            .map { $0 }
    }

    private static func mode(_ values: [Int]) -> Int? {
        Dictionary(grouping: values, by: { $0 })
            .max { ($0.value.count, $1.key) < ($1.value.count, $0.key) }?
            .key
    }
}
