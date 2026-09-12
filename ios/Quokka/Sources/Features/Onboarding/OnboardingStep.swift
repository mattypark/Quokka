import Foundation
import QuokkaEngine

/// One screen of the intro, as data.
///
/// The flow is a list rather than a tree because nothing a person answers here changes which
/// question comes next. Keeping it linear means the progress indicator is honest -- step 3 of
/// 8 is a fact, not an estimate -- and a branching flow can be added later by making `next`
/// a function of the answers rather than by rewriting the container.
struct OnboardingStep: Identifiable {
    let id: Key
    let kind: Kind
    /// The question, set large. One line where it can be.
    let title: String
    /// The line under it. Nil where the question needs no explaining.
    let helper: String?
    let cta: String

    /// Stable identifiers, so an answer is filed against a name rather than an index and
    /// reordering the script cannot silently rewrite what somebody said.
    enum Key: String, CaseIterable {
        case welcome
        case craft
        case platforms
        case interests
        case intent
        case teachShareSheet
        case teachDownload
        case finish
    }

    enum Kind {
        /// No input. A title card.
        case statement
        /// Exactly one choice. Selecting advances on its own.
        case single([Choice])
        /// Any number of choices, including none where `minimum` is 0.
        case multi([Choice], minimum: Int)
        /// An instruction, numbered. Teaches a gesture rather than asking anything.
        case teach([String])
        /// The last card: legal, and the button that finishes.
        case finish
    }

    struct Choice: Identifiable, Hashable {
        let id: String
        let label: String
        /// A second line, where the label alone is not the whole thought.
        let detail: String?

        init(_ id: String, _ label: String, detail: String? = nil) {
            self.id = id
            self.label = label
            self.detail = detail
        }

        /// Built from the real `Platform` cases, so the list on screen cannot drift away from
        /// what the canonicaliser actually recognises.
        init(_ platform: Platform) {
            self.id = platform.rawValue
            self.label = platform.displayName
            self.detail = nil
        }
    }
}

extension OnboardingStep.Kind {
    /// Whether the step can be left without an answer. A statement always can; a question
    /// with a minimum cannot until it is met.
    func isSatisfied(by answers: OnboardingAnswers, for key: OnboardingStep.Key) -> Bool {
        switch self {
        case .statement, .teach, .finish:
            true
        case .single:
            !answers[key].isEmpty
        case .multi(_, let minimum):
            answers[key].count >= minimum
        }
    }

    /// Single-select advances on tap. Everything else waits for the button, because a
    /// multi-select that jumped forward on the first tap would make the second one impossible.
    var advancesOnSelection: Bool {
        if case .single = self { return true }
        return false
    }
}
