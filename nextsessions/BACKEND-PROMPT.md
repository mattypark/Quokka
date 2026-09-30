You are the **backend session** for Quokka, an iOS app at
`~/Downloads/current-projects/appscurrent/quokka`.

Read these before touching anything:

- `docs/SESSION-BACKEND.md` — your lane, and what you must not edit
- `docs/DECISIONS.md` — why the architecture is what it is
- `docs/TIMELINE.md` — where this sits in the schedule
- `backend/ANALYTICS.md`, `backend/MCP.md`, `backend/WAITLIST.md` — your specs
- `backend/README.md` — the frozen contract with the frontend

## What Quokka is

A place to put the things that moved you. Save a post from any app's share sheet — Instagram,
TikTok, YouTube, Pinterest, Reddit, X — and Quokka files it, finds a thumbnail, and sorts it on
its own. White ground, black text, no accent colour; the only colour on screen belongs to the
saved work. It replaces the habit of DMing reels to a second Instagram account.

## Current state

**Redesigned 2026-09-30 around the breakdown** (branch `quokka-sky`, off `cosmos-redesign`;
neither merged, neither pushed). Black, white and sky under Matthew's mark -- see
`docs/DESIGN.md`. Three tabs: Home (sky header, rings, ready / waiting / recent), Library
(search by word or colour, platform chips) and Studio (playlists, ideas, creators). A video's
page is its breakdown, read by `QuokkaEngine/Breakdown.swift` from the transcript. Each
screen was verified by screenshot in the simulator. A custom display face is still to come.

`extension/` is a Chrome extension, Save to Quokka, that queues right-click saves in the
browser. **It has no route to the phone yet** -- the two candidates are in
`docs/DECISIONS.md`, and the choice is Matthew's.

Real transcription is **not** built. Sample scripts stand in and are labelled on screen as
samples. `docs/RESEARCH-TRANSCRIPTS.md` explains why, and what the lawful path is.


## Your order of work

1. **YouTube metrics** via the Data API v3. The biggest quality win available: it gives real
   titles and channels, which the app completely lacks today — a YouTube save currently
   displays its own URL. Views, likes and comments come with it.
2. **`quokka-mcp`** — the library exposed to Claude Code with no API key. See `backend/MCP.md`.
   This one crosses into the frontend's lane; coordinate before building.
3. **Author-grouped collections.** An Instagram import lands thousands of items each carrying
   an author. Grouping by author is the highest-value organisation available and needs no AI
   at all.
4. **TikTok metrics.** Fragile by nature; degrade to nothing, never to wrong.
5. **Waitlist endpoint.**
6. **Apple submission prep.**

## What the frontend is waiting on

[`BACKEND-ASKS.md`](BACKEND-ASKS.md), in full. The one that blocks nothing but is owed: a
`UserProfile` in `QuokkaEngine` plus `QuokkaStore.profile()` / `saveProfile(_:)`, so the new
multi-question onboarding stops writing its answers into a `UserDefaults` key owned by a view.
Additive, therefore free under the contract.

## Hard rules

- **Never read, print or edit `.env*`, keys or credentials.** Ship `Secrets.xcconfig.example`
  and let Matthew fill the real one.
- **`NULL` is not `0`.** A metric that was never fetchable is absent. Writing a zero makes the
  app lie and the UI cannot tell the difference afterwards.
- Store raw counts and derive rates at display time. A stored rate goes stale immediately.
- Instagram, Pinterest and X serve **nothing** to an unauthenticated client — no thumbnail, no
  metadata, no metrics. Do not add retries for them. This is researched and settled.
- `QuokkaEngine` and `QuokkaImaging` must keep compiling for macOS so tests run without a
  simulator. Guard UIKit behind `#if canImport(UIKit)`.
- Do not edit `Features/`, `Components/`, the design tokens, or `web/`. Ask instead.
- Commit after every change. **Never push** unless asked.
- App Store Connect is a **live commercial account**: TestFlight config and reading feedback
  only. Never submit for release, never touch anything involving money, never delete.

## Verifying

```sh
cd ios/QuokkaDesign && swift test      # 58 tests, ~1s, no simulator
scripts/run.sh --seed --relaunch      # build, screenshot, prove persistence, shut down
```

**Never pass `--keep`.** A booted simulator's `mediaanalysisd` has been measured at 691% CPU
and 201°F on this machine. Screenshots already answer the question.
