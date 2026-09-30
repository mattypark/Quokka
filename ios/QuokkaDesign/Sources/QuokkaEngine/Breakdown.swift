import Foundation

/// What a video did, read out of its transcript: the hook and when it lands, how fast it is
/// spoken, the beats it is built on, how it ends, and a short list of checks it passes or
/// misses.
///
/// Rules, not a model. Every finding is something you can point at in the words -- "lands at
/// 1.8s", "172 words a minute", "ends by asking for a follow" -- so a check that passes is
/// evidence rather than an opinion, and the same transcript always breaks down the same way.
/// It runs on the phone in microseconds, needs no key and sends nothing anywhere. A hosted
/// model can add a narrative on top later; it should never be what the checks rest on.
///
/// Pure and dependency-free like the rest of the engine, so it is proved under `swift test`.
public struct Breakdown: Sendable, Equatable {
    public var hook: Hook
    public var pacing: Pacing
    public var beats: [Beat]
    public var ending: Ending
    public var checks: [Check]

    public var passed: Int { checks.filter(\.passed).count }

    // MARK: - Parts

    public struct Hook: Sendable, Equatable {
        /// The opening line, as said.
        public var text: String
        /// When the opening line finishes, in seconds. Nil when the transcript has no timing.
        public var landsAt: TimeInterval?
        public var words: Int
        public var kinds: [HookKind]
    }

    /// The moves an opening line can make. A hook can make several at once.
    public enum HookKind: String, Sendable, CaseIterable {
        case question
        case number
        case warning
        case claim
        case you
        case story

        public var label: String {
            switch self {
            case .question: "Asks a question"
            case .number: "Puts a number up front"
            case .warning: "Warns you off something"
            case .claim: "Makes a bold claim"
            case .you: "Talks to you"
            case .story: "Opens on a story"
            }
        }
    }

    public struct Pacing: Sendable, Equatable {
        public var words: Int
        /// Seconds, from the last timed segment. Nil without timing.
        public var duration: TimeInterval?
        public var wordsPerMinute: Int?
        public var sentences: Int
        public var averageSentenceWords: Double
        public var tempo: Tempo
    }

    /// Everyday conversation runs about 150 words a minute; short-form creators run faster.
    public enum Tempo: String, Sendable {
        case fast
        case conversational
        case slow
        case unknown

        public var label: String {
            switch self {
            case .fast: "Fast"
            case .conversational: "Conversational"
            case .slow: "Slow"
            case .unknown: "Untimed"
            }
        }

        static func of(wordsPerMinute: Int?) -> Tempo {
            guard let wordsPerMinute else { return .unknown }
            if wordsPerMinute >= 170 { return .fast }
            if wordsPerMinute >= 130 { return .conversational }
            return .slow
        }
    }

    /// One step of a list-shaped video: "first", "number two", "3.", "finally".
    public struct Beat: Sendable, Equatable {
        public var text: String
        public var start: TimeInterval?
    }

    public struct Ending: Sendable, Equatable {
        public var text: String
        public var ask: Ask?
    }

    /// What the last lines ask the viewer to do.
    public enum Ask: String, Sendable, CaseIterable {
        case follow
        case subscribe
        case comment
        case share
        case save
        case like
        case link
        case nextPart

        public var label: String {
            switch self {
            case .follow: "Asks for a follow"
            case .subscribe: "Asks for a subscribe"
            case .comment: "Asks for a comment"
            case .share: "Asks for a share"
            case .save: "Asks for a save"
            case .like: "Asks for a like"
            case .link: "Points to a link"
            case .nextPart: "Teases a part two"
            }
        }
    }

    public struct Check: Sendable, Equatable, Identifiable {
        public var id: String
        public var title: String
        public var passed: Bool
        /// What in the transcript decided it, in words a person can check.
        public var evidence: String
    }

    // MARK: - Analysis

    /// Nil when there are no words to read.
    public static func analyze(_ transcript: Transcript) -> Breakdown? {
        guard transcript.isUsable else { return nil }
        let text = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let sentences = Self.sentences(in: text)
        guard let first = sentences.first else { return nil }

        let timeline = Timeline(transcript.segments)

        // A two-word opener ("Okay, so.") is a throat-clear, not the hook; the hook is the
        // line it clears its throat for.
        var hookText = first
        if Self.words(in: first).count < 4, sentences.count > 1 {
            hookText = first + " " + sentences[1]
        }
        let hookEndOffset = Self.offset(of: hookText, in: text).map { $0 + hookText.count }
        let hook = Hook(
            text: hookText,
            landsAt: hookEndOffset.flatMap { timeline.time(atCharacter: $0, of: text) },
            words: Self.words(in: hookText).count,
            kinds: HookKind.allCases.filter { Self.hookMakes($0, hookText) })

        let wordCount = Self.words(in: text).count
        let duration = timeline.duration
        // Under three seconds of timing is too little to call a pace from.
        var wordsPerMinute: Int?
        if let duration, duration >= 3 {
            let perMinute = Double(wordCount) / (duration / 60)
            wordsPerMinute = Int(perMinute.rounded())
        }
        let pacing = Pacing(
            words: wordCount,
            duration: duration,
            wordsPerMinute: wordsPerMinute,
            sentences: sentences.count,
            averageSentenceWords: Double(wordCount) / Double(max(sentences.count, 1)),
            tempo: .of(wordsPerMinute: wordsPerMinute))

        var beats: [Beat] = []
        for sentence in sentences where Self.isBeat(sentence) {
            var start: TimeInterval?
            if let position = Self.offset(of: sentence, in: text) {
                start = timeline.time(atCharacter: position, of: text, start: true)
            }
            beats.append(Beat(text: Self.clip(sentence, to: 90), start: start))
        }

        let closing = sentences.suffix(2).joined(separator: " ")
        let ending = Ending(
            text: Self.clip(sentences.last ?? first, to: 160),
            ask: Ask.allCases.first { Self.asks($0, closing) })

        let checks = Self.checks(hook: hook, pacing: pacing, beats: beats, ending: ending, sentences: sentences)
        return Breakdown(hook: hook, pacing: pacing, beats: beats, ending: ending, checks: checks)
    }

    // MARK: - Checks

    private static func checks(
        hook: Hook, pacing: Pacing, beats: [Beat], ending: Ending, sentences: [String]
    ) -> [Check] {
        var checks: [Check] = []

        if let landsAt = hook.landsAt {
            checks.append(Check(
                id: "hook-fast",
                title: "Hook lands in 3 seconds",
                passed: landsAt <= 3.0,
                evidence: "The opening line ends at \(Self.seconds(landsAt))."))
        } else {
            checks.append(Check(
                id: "hook-fast",
                title: "Hook is short",
                passed: hook.words <= 15,
                evidence: "The opening line is \(hook.words) words."))
        }

        let loops = hook.kinds.filter { $0 != .you && $0 != .story }
        checks.append(Check(
            id: "hook-loop",
            title: "Hook opens a loop",
            passed: !loops.isEmpty,
            evidence: loops.isEmpty
                ? "No question, number, warning or claim in the first line."
                : loops.map(\.label).joined(separator: ", ") + "."))

        let early = sentences.prefix(3).joined(separator: " ")
        let yous = Self.count(of: ["you", "your", "you're", "yourself"], in: early)
        checks.append(Check(
            id: "speaks-to-you",
            title: "Talks to the viewer",
            passed: yous > 0,
            evidence: yous > 0
                ? "Says “you” \(yous == 1 ? "once" : "\(yous) times") in the first three lines."
                : "No “you” in the first three lines."))

        if let wordsPerMinute = pacing.wordsPerMinute {
            checks.append(Check(
                id: "pace",
                title: "Keeps the pace up",
                passed: wordsPerMinute >= 150,
                evidence: "\(wordsPerMinute) words a minute."))
        }

        checks.append(Check(
            id: "structure",
            title: "Has a clear structure",
            passed: beats.count >= 2,
            evidence: beats.count >= 2
                ? "\(beats.count) numbered beats."
                : "No numbered steps or list to follow."))

        checks.append(Check(
            id: "short-lines",
            title: "Short, punchy lines",
            passed: pacing.averageSentenceWords <= 14,
            evidence: String(format: "%.0f words a sentence on average.", pacing.averageSentenceWords)))

        checks.append(Check(
            id: "ask",
            title: "Ends with an ask",
            passed: ending.ask != nil,
            evidence: ending.ask.map { "\($0.label)." } ?? "The last lines ask for nothing."))

        return checks
    }

    // MARK: - Reading the words

    /// Splits on sentence punctuation and on line breaks, keeping the punctuation.
    static func sentences(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in text {
            if character == "\n" {
                if !current.trimmingCharacters(in: .whitespaces).isEmpty { result.append(current) }
                current = ""
                continue
            }
            current.append(character)
            if ".!?".contains(character) {
                result.append(current)
                current = ""
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty { result.append(current) }
        return result
            .map { $0.trimmingCharacters(in: .whitespaces) }
            // "1." on its own is the start of a numbered beat, not a sentence.
            .reduce(into: [String]()) { merged, piece in
                if let last = merged.last, Self.isBareMarker(last) {
                    merged[merged.count - 1] = last + " " + piece
                } else if !piece.isEmpty {
                    merged.append(piece)
                }
            }
    }

    static func words(in text: String) -> [Substring] {
        text.split { !$0.isLetter && !$0.isNumber && $0 != "'" && $0 != "’" }
    }

    private static func lowerWords(_ text: String) -> [String] {
        words(in: text.lowercased()).map { String($0).replacingOccurrences(of: "’", with: "'") }
    }

    private static func count(of targets: Set<String>, in text: String) -> Int {
        lowerWords(text).filter(targets.contains).count
    }

    private static let numberWords: Set<String> = [
        "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "twenty", "hundred", "thousand", "million", "billion", "half", "double",
    ]
    private static let warningWords: Set<String> = [
        "stop", "don't", "never", "mistake", "mistakes", "wrong", "avoid", "quit", "worst", "ruin", "ruining",
    ]
    private static let claimWords: Set<String> = [
        "best", "greatest", "only", "secret", "nobody", "everyone", "always", "biggest", "fastest",
        "easiest", "insane", "changed", "truth", "actually", "literally",
    ]
    private static let storyOpeners = ["i ", "i'm ", "when i", "so i", "yesterday", "last week", "last year", "this is how i", "my "]

    static func hookMakes(_ kind: HookKind, _ hook: String) -> Bool {
        let lower = hook.lowercased()
        let tokens = Set(lowerWords(hook))
        switch kind {
        case .question: return hook.contains("?")
        case .number: return hook.contains(where: \.isNumber) || !tokens.isDisjoint(with: numberWords)
        case .warning: return !tokens.isDisjoint(with: warningWords)
        case .claim: return !tokens.isDisjoint(with: claimWords)
        case .you: return !tokens.isDisjoint(with: ["you", "your", "you're", "yourself"])
        case .story: return storyOpeners.contains { lower.hasPrefix($0) }
        }
    }

    private static let ordinals = [
        "first", "firstly", "second", "secondly", "third", "thirdly", "fourth", "fifth", "sixth",
        "next", "finally", "lastly", "step", "tip", "rule", "number",
    ]

    /// A sentence that starts a new step of a list.
    static func isBeat(_ sentence: String) -> Bool {
        let lower = sentence.lowercased()
        // "1." "2)" "#3:" "4 -" at the very start -- but not "3 things", which is a hook.
        let head = lower.prefix(5)
        if let firstChar = head.first, firstChar.isNumber || firstChar == "#" {
            let rest = head.drop { $0.isNumber || $0 == "#" }.drop { $0 == " " }
            if let marker = rest.first, ".):-".contains(marker) { return true }
            if firstChar == "#", head.dropFirst().first?.isNumber == true { return true }
        }
        guard let firstWord = lowerWords(sentence).first else { return false }
        if ["step", "tip", "rule", "number"].contains(firstWord) {
            let second = lowerWords(sentence).dropFirst().first ?? ""
            return second.first?.isNumber == true || numberWords.contains(second)
        }
        if ["the"].contains(firstWord) {
            let second = lowerWords(sentence).dropFirst().first ?? ""
            return ["first", "second", "third", "next", "last", "final"].contains(second)
        }
        return ordinals.contains(firstWord) && !["step", "tip", "rule", "number"].contains(firstWord)
    }

    private static func isBareMarker(_ piece: String) -> Bool {
        let trimmed = piece.trimmingCharacters(in: .whitespaces)
        guard trimmed.count <= 4, let last = trimmed.last, ".)".contains(last) else { return false }
        return trimmed.dropLast().allSatisfy(\.isNumber) && trimmed.count > 1
    }

    private static let askPhrases: [(Ask, [String])] = [
        (.follow, ["follow for", "follow me", "hit follow", "give me a follow", "follow if", "follow along"]),
        (.subscribe, ["subscribe"]),
        (.comment, ["comment", "let me know", "tell me below", "drop a", "in the comments"]),
        (.share, ["share this", "send this", "send it to", "tag someone", "tag a friend"]),
        (.save, ["save this", "save it", "bookmark"]),
        (.like, ["like this", "leave a like", "hit like", "smash that like"]),
        (.link, ["link in bio", "link in my bio", "link below", "link in the description"]),
        (.nextPart, ["part two", "part 2", "part three", "part 3", "next video", "stay tuned"]),
    ]

    static func asks(_ ask: Ask, _ closing: String) -> Bool {
        let lower = closing.lowercased().replacingOccurrences(of: "’", with: "'")
        return askPhrases.first { $0.0 == ask }?.1.contains { lower.contains($0) } ?? false
    }

    private static func offset(of needle: String, in haystack: String) -> Int? {
        guard let range = haystack.range(of: needle) else { return nil }
        return haystack.distance(from: haystack.startIndex, to: range.lowerBound)
    }

    private static func clip(_ text: String, to limit: Int) -> String {
        text.count > limit ? String(text.prefix(limit - 1)) + "…" : text
    }

    static func seconds(_ value: TimeInterval) -> String {
        String(format: "%.1fs", value)
    }
}

/// Maps a character position in the joined text to a time, using the segments' own text.
///
/// Segments are laid end to end in character space in the same order as the text, and a
/// position is interpolated inside the segment it falls in. That is exact at segment edges
/// and close inside them, which is all "the hook lands at 1.8s" needs.
private struct Timeline {
    private struct Span {
        var from: Int
        var to: Int
        var start: TimeInterval
        var end: TimeInterval
    }

    private let spans: [Span]

    init(_ segments: [Transcript.Segment]) {
        var cursor = 0
        spans = segments.map { segment in
            let length = segment.text.count + 1
            defer { cursor += length }
            return Span(from: cursor, to: cursor + length, start: segment.start, end: segment.start + segment.duration)
        }
    }

    var duration: TimeInterval? { spans.last.map(\.end) }

    /// `start` rounds to the beginning of the segment rather than interpolating, which is the
    /// right answer for "when does this beat begin".
    func time(atCharacter position: Int, of text: String, start: Bool = false) -> TimeInterval? {
        guard let total = spans.last?.to, total > 0 else { return nil }
        // Scale: segment text and joined text rarely match character for character.
        let scaled = Int(Double(position) / Double(max(text.count, 1)) * Double(total))
        guard let span = spans.first(where: { scaled < $0.to }) ?? spans.last else { return nil }
        if start { return span.start }
        let fraction = Double(scaled - span.from) / Double(max(span.to - span.from, 1))
        return span.start + (span.end - span.start) * min(max(fraction, 0), 1)
    }
}
