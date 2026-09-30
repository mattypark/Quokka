# What the frontend needs from the engine

Written by the frontend session, and the mirror of [`FRONTEND-ASKS.md`](FRONTEND-ASKS.md).
**Nothing here has been built** -- except section 5, which the frontend wrote and flags for review. `QuokkaEngine`, `QuokkaStore` and `Services/` are the backend
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

## 3. Three methods, and the transcript screen turns on

**This one blocks a screen that is already built and shipping empty.**

`IdeaDetailView` grew a Transcript pane. It renders four states and it is wired against
`TranscriptReading` in `ios/Quokka/Sources/Features/TranscriptAccess.swift`, backed by
`UnbuiltTranscripts`, which returns nil for everything. Migration v8 already created
`item_transcript` and `transcript_job`, and the ladder already writes to both — but
`QuokkaStore` exposes no way to read either back.

```swift
// QuokkaStore
public func transcript(forItem itemID: Int64) -> Transcript?
public func exhaustedTranscriptFailure(forItem itemID: Int64) -> String?
public func isTranscribing(itemID: Int64) -> Bool
public func enqueueTranscript(itemID: Int64)
```

Then make `QuokkaStore` conform to `TranscriptReading` and the pane lights up. No view moves.

Two things the screen depends on being true:

- `exhaustedTranscriptFailure` returns **nil while retries remain**. The pane prints whatever
  it gets, verbatim, as an instruction to the person. A failure that is about to be retried is
  not something to put in front of anybody.
- `Transcript.segments` being empty is legitimate and the pane treats it as such. It reads
  `.text` and `.source` only.

## 4. Summaries, on device

Decided with Matthew: **on-device first**, `quokka-mcp` second. Not an API key in the app —
that breaks the Data Not Collected declaration and trips Apple's 5.1.2(i) third-party AI
disclosure, and both are avoidable.

iOS 26 ships `FoundationModels`. `SystemLanguageModel` summarises a transcript locally, free,
offline, with no key and nothing leaving the phone. Availability has to be checked rather than
assumed — it needs an Apple-Intelligence-capable device, so `SystemLanguageModel.default`
reports `.unavailable` on plenty of real phones and the summary is then simply absent rather
than the screen being broken.

Suggested shape, so the frontend can build against it the same way:

```swift
public struct Summary: Codable, Sendable {
    public var text: String          // a few sentences
    public var beats: [String]       // the structure, as bullets
    public var generatedAt: Date
}

// QuokkaStore
public func summary(forItem itemID: Int64) -> Summary?
public func enqueueSummary(itemID: Int64)
```

A summary derives from a transcript, so it queues behind one rather than beside it — asking
for a summary of a video with no transcript should enqueue the transcript and then the summary,
not fail.

`quokka-mcp` stays the second route: it already mirrors the library, so Claude on the Mac can
write richer summaries back into the same field. On-device fills it in immediately; the Mac
improves it when it runs. Same column either way.

## 5. Built by the frontend during the Cosmos redesign -- please review

The Search tab and the item page needed queries that did not exist, and the redesign could not
ship half a screen. They were written in the backend's files and are logged here so they can
be reviewed, moved or rewritten rather than discovered:

| Where | What | Worth a look |
|---|---|---|
| `Services/QuokkaStore+Search.swift` | `search(text:)` -- every word must match title, author, caption, tags, url or transcript | LIKE, not FTS5. Fine at 10k rows; FTS5 with triggers is the right answer at 100k |
| same | `search(color:)` -- nearest `averageColor`, weighted RGB 2:4:3 | A full pass over one integer column |
| same | `recentColors()` -- for the swatch row | |
| same | `playlists(containing:)` -- both routes, direct and through an idea | |
| same | `transcribedCount()`, `transcribedItems()`, `untranscribedVideos()` -- Home's rings and lists | `untranscribedVideos` treats `.web` as a video platform, which a shared movie file is |
| same | `isTranscriptQueued(itemID:)` -- the query section 7 was waiting on | |
| `Root/AppState+Breakdown.swift` | `requestTranscript` (enqueue + run the queue), `saveLink` (paste a link, `origin: .manual`), sample-transcript planting for screenshots | Samples are DEBUG-only and flagged on screen |
| `Root/AppState+Browse.swift` | Pass-throughs for the above, plus `playlistItems`, `addToPlaylist`, `removeFromPlaylist`, `playlistDigest`, `page(author:)` | `playlistCards()` reuses `playlistsForMirror()` for its item counts |

## 6. A route from the Chrome extension to the phone

`extension/` queues saves in `chrome.storage.local` and stops there. The record matches
`ShareInboxRecord` (`id`, `receivedAt`, `rawURL`, `rawText`) plus `srcURL`, `pageURL` and
`pageTitle`. The two candidate routes, and what each costs, are in `docs/DECISIONS.md`; the
choice is Matthew's. Whichever lands, `InboxDrain` needs one new rule: an image save's
`srcURL` is its thumbnail, to be fetched rather than downsampled from a file.

## 7. The transcript screen is still wired to `UnbuiltTranscripts`

`QuokkaStore` now has `transcript(forItem:)`, `enqueueTranscript` and
`exhaustedTranscriptFailure`, and the new item page reads the first of them directly. But
`IdeaDetailView` still receives `UnbuiltTranscripts()`. `isTranscriptQueued(itemID:)` now exists
(section 5), so what is left is the adapter conforming `QuokkaStore` to `TranscriptReading`. The
new breakdown page does not wait on it -- it reads the store directly.

## 8. A narrative on top of the breakdown, eventually

`Breakdown` is rules and must stay the thing the checks rest on. A short written read -- "why this
worked", in a sentence or two -- could come from `/extract` on the worker, which already takes a
transcript. It should be labelled as a model's opinion and never change a check.
