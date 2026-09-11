# Quokka

**Save what stopped your thumb, and turn it into something.**

Share a post from any app — Instagram, TikTok, YouTube, Pinterest, Reddit, X — and Quokka
files it. Then it helps you turn what you saved into a script you can actually use.

Saving is table stakes. The product is what happens after.

---

## Start here

| | |
|---|---|
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Why the architecture is what it is. Read before changing anything structural. |
| [`docs/RESEARCH-TRANSCRIPTS.md`](docs/RESEARCH-TRANSCRIPTS.md) | What is actually possible for transcripts, with 33 sources. The finding the product turns on. |
| [`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md) | Getting it onto a phone that is not yours. **Read the blockers at the top.** |
| [`docs/TIMELINE.md`](docs/TIMELINE.md) | Phases and what ships when. |
| [`nextsessions/`](nextsessions/) | Paste-ready prompts for the two parallel sessions. |

## Running it

```sh
scripts/run.sh                          # build, screenshot, shut the simulator down
scripts/run.sh --seed                   # sample saves
scripts/run.sh --ideas                  # sample playlists and ideas
scripts/run.sh --export                 # a synthetic Instagram export, imported
scripts/run.sh --tab today|library|playlists|settings
scripts/run.sh --screen playlist|idea   # deep-link into a sheet
scripts/run.sh --relaunch               # relaunch, to prove data persisted
```

**Never pass `--keep`.** A booted simulator's `mediaanalysisd` was measured at 691% CPU and
201°F on this machine.

```sh
cd ios/QuokkaDesign && swift test       # 73 tests, ~1s, no simulator
```

## Layout

```
ios/
  project.yml              XcodeGen spec. Source of truth; the .xcodeproj is generated.
  Quokka/                  App target
  QuokkaShare/             Share extension — the daily capture path
  QuokkaDesign/            Local SPM package:
    QuokkaDesign             tokens, the mascot, tile shapes
    QuokkaEngine             pure logic — models, canonicaliser, export parser
    QuokkaImaging            downsampling, encoding, average colour
mcp/                       quokka-mcp — lets Claude Code read and tag the library, no API key
web/                       Marketing site (paused; app is the priority)
tools/  docs/  scripts/  nextsessions/
```

## What works today

- **Save from any share sheet.** URL, text, image, or a video file.
- **Instagram import** — DMs filtered to one conversation, plus Saved and Liked, deduplicated
  across all three.
- **Thumbnails** per platform, cached at save time, stored as SQLite BLOBs.
- **Library** — masonry at native aspect ratio, grouped by creator.
- **Playlists → Ideas** — script editor with hook, copy, and the videos behind it.
- **Planner** — to-dos, completed, skipped, and a daily journal.
- **`quokka-mcp`** — ask your terminal "what did I save about lighting?"

## What does not work yet

- **Real transcription.** The `public.movie` branch that feeds it is in; the
  Photos → `SpeechAnalyzer` pipeline is not built. Sample scripts stand in, and every one is
  labelled as such on screen.
- **Metrics.** See `backend/ANALYTICS.md` for what is actually obtainable per platform.
- **The blob shape mode.** The seam is in `QuokkaDesign/TileShape.swift`; the shapes are not.

## Known blockers

1. **`KeeponTruckin.ttf` is personal-use licensed** and is committed to a public repo. Blocks
   submission. One line to fix — see `docs/TESTFLIGHT.md`.
2. **No app icon.**
3. Instagram, Pinterest and X publish no thumbnail to an unauthenticated client. Settled and
   designed around — the typographic tile is their intended state.
