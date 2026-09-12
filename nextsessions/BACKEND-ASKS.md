# What the frontend needs from the engine

Written by the frontend session, and the mirror of [`FRONTEND-ASKS.md`](FRONTEND-ASKS.md).
**Nothing here has been built.** `QuokkaEngine`, `QuokkaStore` and `Services/` are the backend
session's, and reaching into them mid-session is how two people end up with the same file open.

## 1. A profile to write onboarding into

Onboarding is no longer one screen and one Bool. It asks five questions — what a person makes,
which platforms they save from, what they are collecting, what they want out of it — and today
those answers have nowhere to live. `UserDefaults` holds exactly `quokkaOnboarded`, and there
is no `UserProfile` type anywhere in the repo.

The flow ships against a seam rather than a guess:

```swift
// Features/Onboarding/OnboardingAnswers.swift
protocol OnboardingAnswerSink {
    func save(_ answers: OnboardingAnswers)
    func load() -> OnboardingAnswers
}
```

It is backed by `LocalAnswerSink` — one `UserDefaults` key, `quokkaOnboardingProfile`, holding
JSON. That works, and it is deliberately the wrong long-term home: the answers are product
data that the library, the planner and `quokka-mcp` all have a use for, and none of those can
reasonably read a view layer's defaults key.

**What would replace it:** a `UserProfile` in `QuokkaEngine` and two methods on `QuokkaStore`.

```swift
public struct UserProfile: Codable, Sendable, Equatable {
    /// Choice ids by question key. Free-form on purpose -- the question set will change, and a
    /// stored profile should survive a question being added or dropped.
    public var selections: [String: Set<String>]
    public var onboardedAt: Date?
}

// QuokkaStore
public func profile() -> UserProfile?
public func saveProfile(_ profile: UserProfile)
```

`QuokkaStore` then conforms to `OnboardingAnswerSink` and the only frontend change is the sink
handed to `OnboardingFlow` at the `RootView` call site. No view moves.

This is **additive**, so it is free under the contract in `backend/README.md` — nothing is
renamed and nothing is removed.

### Why the keys are strings and not an enum

An enum in `QuokkaEngine` would have to be edited by the backend session every time the
frontend adds a question, which puts a copy change on the wrong side of the line. The frontend
owns `OnboardingStep.Key`; the engine stores whatever it is handed. A profile written by an
older build then still decodes.

### What it must not do

App Privacy is declared **Data Not Collected** (`docs/ASC-SETUP.md`), and the review notes say
the app has no accounts and collects no data. That stays true only while the profile is
on-device. It must not ride along on the `quokka-mcp` mirror without that being a deliberate,
separate decision, and it must never reach a server Quokka runs.

## 2. Seed tags from the interests answer, eventually

Question 4 asks what somebody is collecting — Hooks, Editing, Lighting, and so on — and those
are the same shape as `Item.tags`. There is an obvious follow-on where a newly imported item
gets scored against the profile's interests, but that is a rule, which means it is the engine's
and not a view's. Raised here rather than built.

Not urgent. The onboarding ships without it.
