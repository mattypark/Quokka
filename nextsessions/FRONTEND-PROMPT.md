You are the **frontend session** for Quokka, an iOS app and marketing site at
`~/Downloads/current-projects/appscurrent/quokka`.

Read these before touching anything:

- `docs/SESSION-FRONTEND.md` — your lane, and what you must not edit
- `docs/DECISIONS.md` — why the design is what it is
- `docs/TIMELINE.md` — where this sits in the schedule

## What Quokka is

A place to put the things that moved you. Save a post from any app's share sheet and Quokka
files it, finds a thumbnail, and sorts it on its own. It replaces the habit of DMing reels to
a second Instagram account.

**White ground, black text, no accent colour, ever.** The only colour on screen belongs to the
saved work. The grid is masonry at native aspect ratio — a reel is 9:16, a YouTube thumbnail
16:9 — because cropping to a common shape discards the composition of the thing being saved,
which is the reason it was saved.

## Current state

The app renders a working masonry library with real thumbnails, a typographic fallback tile
for platforms that serve no image, an Instagram import flow, and a wordmark that spells itself
out with a haptic tap per glyph. The palette was recently inverted from black to white.

## Your order of work

1. **The website** (`web/`), days 1–3. Koino-inspired but in Quokka's own voice, not a copy.
2. **Analytics UI** — stat tiles for a saved post. Read the honesty rules below first.
3. **Collections UI** — once the backend delivers author grouping.
4. **App icon and App Store screenshots.**

## Honesty rules for analytics UI

Coverage is not uniform and pretending otherwise makes the app look broken:

| Platform | What exists |
|---|---|
| YouTube | Views, likes, comments — official API, complete |
| TikTok | Views, likes, comments, shares, saves — best-effort |
| Instagram, Pinterest, X | **Nothing** |

**Never render `0` for a metric that was never fetched.** Show a dash, or omit the tile
entirely. A zero is a claim and it would be a false one. Design the panel so a post with two
metrics looks deliberate rather than broken.

## Hard rules

- Tokens before components. Nothing reaches for a hex value or a ramp step directly.
- Animate `transform` and `opacity` only. Every animated call goes through
  `Motion.respecting(_:)` so Reduce Motion is the default.
- **A view must render correctly with no data, with failed data, and with 100,000 rows.**
  All three are normal.
- Verify at 375 / 768 / 1440 by screenshot before calling anything done.
- Do not edit `QuokkaEngine`, `QuokkaImaging`, `Services/`, or `mcp/`. Ask the backend session.
- Commit after every change. **Never push** unless asked.

## Verifying

```sh
scripts/run.sh --seed --relaunch
```

**Never pass `--keep`.** A booted simulator's `mediaanalysisd` has been measured at 691% CPU
and 201°F on this machine.
