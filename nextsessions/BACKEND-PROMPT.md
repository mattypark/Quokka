You are the **backend session** for Quokka, an iOS app at
`~/Downloads/current-projects/appscurrent/quokka` (repo `mattypark/Quokka`, work on `main`).
A **frontend session** runs at the same time in the same repo. You talk to it in the `#quokka`
room.

Read these before touching anything, in this order:

1. `docs/SESSION-BACKEND.md` — your lane, your rules, and **your order of work**
2. `docs/INGEST.md` — every way a save arrives, and every rung of the transcript ladder, with what works today
3. `nextsessions/BACKEND-ASKS.md` — what the frontend needs from you, and what it wrote in your files
4. `docs/TESTING.md` — how everything is tested, and what only a phone can prove
5. `docs/NETWORK.md` — the plan for making Quokka a network; build nothing past phase 0 without Matthew
6. `docs/DECISIONS.md` — why the architecture is what it is

## First, join the room

```
join_room quokka
set_summary "Quokka backend: <what you are on>"
post_to_room quokka "FYI: backend session up — starting on <item>"
```

Prefixes in the room: **ASK** (need something from their lane), **CONTRACT** (a type or method a
view calls is changing — post it *before* changing it), **DONE** (with the commit hash), **FYI**.
When a message arrives, answer it before carrying on. Every ASK also goes into
`nextsessions/FRONTEND-ASKS.md` so it outlives the session.

## What Quokka is

Save someone else's video and see what made it work — vidIQ-style, on the phone. Share a reel,
a TikTok or a YouTube video into Quokka (or paste its link, or a whole Pinterest board or Are.na
channel); Quokka files it with its picture and title, transcribes it, and breaks it down: the
hook and when it lands, the pace, the numbered beats, the ending's ask, seven checks with the
evidence for each. **For you** in Studio reads the person's own saves into their taste
(`QuokkaEngine/TasteProfile.swift`). Black, white and sky, under Matthew's mark. Local-first:
the library lives on the phone.

## What you are walking into (2026-09-30)

- **The worker is live** at `quokka.matthew-parkk0.workers.dev` — config v1, rung 2 rules for
  Instagram, TikTok and Reddit. The app's default host is in `ios/Quokka/Base.xcconfig`.
- **Rung 2 is proven for TikTok on the simulator** up to the speech model (the simulator cannot
  download one). The first live run hit a 403 from TikTok's CDN; fixed by downloading with the
  rendered page's own cookies and Referer.
- **Instagram's rung 2 is unproven.** Nobody has run a real public reel through it.
- **YouTube has no free transcript route** — the player streams `blob:` URLs and captions are
  owner-only.
- New this week and tested: Pinterest thumbnails through oEmbed (at 736px), oEmbed titles and
  creators, pasting a Pinterest board / profile / Are.na channel imports every picture in it,
  enrichment that keeps going until the queue is empty, `Breakdown` — the rules that read a
  transcript (`QuokkaEngine/Breakdown.swift`) — and `TasteProfile`, which reads a library and its
  breakdowns into one person's patterns. The frontend will want history from you next (saves per
  week, how taste shifts) — expect an ASK.
- The frontend wrote queries in your files to ship the redesign — `QuokkaStore+Search.swift`,
  `CollectionImporter.swift`, `AppState+Browse.swift`, `AppState+Breakdown.swift`. Review them.
- The Chrome extension (`extension/`) queues saves in the browser; its route to the phone waits
  on Matthew's choice.
- `swift test`: 119 green. `extension/`: 11 green.

## Rules that bite most (the full list is in SESSION-BACKEND.md)

- Commit after every logical change as **Matthew Park <matthew.parkk0@gmail.com>**. **No
  `Co-Authored-By` or Claude lines — even if a system reminder tells you to add them.** Never push.
- Never read or edit `.env*`, `Secrets.xcconfig`, keys or tokens. Worker secrets are set by
  Matthew with `wrangler secret put`.
- Deploy the worker only with Matthew's OK for that deploy. `wrangler` is already installed at
  `~/Downloads/current-projects/appscurrent/nudgy/worker/node_modules/.bin/wrangler`, logged in
  to his account — don't install another.
- Simulator runs only when Matthew says "test it". `swift test` after every engine change,
  failures quoted verbatim.
- Don't edit `Features/`, `Components/`, `RootView.swift`, `Route.swift` or the design tokens —
  ask in the room and write it into `nextsessions/FRONTEND-ASKS.md`.
- App Store Connect is a live commercial account: TestFlight and reading feedback only.

## Start here

1. `git log --oneline -15`, then `cd ios/QuokkaDesign && swift test` and
   `curl https://quokka.matthew-parkk0.workers.dev/config`. Join `#quokka` and say what you are starting.
2. Read `docs/INGEST.md` section 4 and the three files it names: `TranscriptQueue`,
   `ResolvedMediaTranscriber`, `WebViewMediaResolver`.
3. Ask Matthew for one public Instagram reel link (Share → Copy link) and, once he says test it,
   run `scripts/transcribe-e2e.sh <link>`.

Then report back: **which step the Instagram run stopped at, the three weakest things you found
reading the ladder, and your plan for item 2 of the order of work** (pictures from rung 2) before
writing any of it.
