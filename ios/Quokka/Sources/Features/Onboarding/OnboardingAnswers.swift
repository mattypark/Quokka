import Foundation

/// What somebody told us on the way in.
///
/// Selections are keyed by `OnboardingStep.Key` rather than by index, so the script can be
/// reordered or a question dropped without rewriting anybody's stored answers. A key that is
/// absent means the question was never reached; a key holding an empty set means it was
/// reached and skipped. Those are different facts and the library treats them differently.
struct OnboardingAnswers: Codable, Equatable {
    /// Choice ids, by question.
    private(set) var selections: [String: Set<String>] = [:]
    var finishedAt: Date?

    subscript(key: OnboardingStep.Key) -> Set<String> {
        get { selections[key.rawValue] ?? [] }
        set { selections[key.rawValue] = newValue }
    }

    mutating func toggle(_ choice: OnboardingStep.Choice, for key: OnboardingStep.Key, exclusive: Bool) {
        if exclusive {
            selections[key.rawValue] = [choice.id]
            return
        }
        var current = selections[key.rawValue] ?? []
        if current.contains(choice.id) {
            current.remove(choice.id)
        } else {
            current.insert(choice.id)
        }
        selections[key.rawValue] = current
    }

    func contains(_ choice: OnboardingStep.Choice, for key: OnboardingStep.Key) -> Bool {
        selections[key.rawValue]?.contains(choice.id) == true
    }

    /// Records that the question was seen, so "reached and skipped" survives as a distinct
    /// state from "never got there".
    mutating func markReached(_ key: OnboardingStep.Key) {
        if selections[key.rawValue] == nil { selections[key.rawValue] = [] }
    }
}

/// Where the answers go.
///
/// A seam rather than a call, because the real home for this is a `UserProfile` in
/// `QuokkaEngine` and that belongs to the backend session (see `nextsessions/BACKEND-ASKS.md`).
/// When it lands, `QuokkaStore` conforms to this and the only change is the sink handed to
/// `OnboardingFlow`. No view moves.
protocol OnboardingAnswerSink {
    func save(_ answers: OnboardingAnswers)
    func load() -> OnboardingAnswers
}

/// On-device, and nowhere else.
///
/// One `UserDefaults` key holding JSON, alongside the `quokkaOnboarded` Bool that already
/// lives there. Nothing is sent anywhere, which is what keeps the App Privacy declaration in
/// `docs/ASC-SETUP.md` -- Data Not Collected -- true of this build.
struct LocalAnswerSink: OnboardingAnswerSink {
    static let key = "quokkaOnboardingProfile"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ answers: OnboardingAnswers) {
        guard let data = try? JSONEncoder().encode(answers) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func load() -> OnboardingAnswers {
        guard let data = defaults.data(forKey: Self.key),
              let answers = try? JSONDecoder().decode(OnboardingAnswers.self, from: data)
        else { return OnboardingAnswers() }
        return answers
    }
}
