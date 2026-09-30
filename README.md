# Quokka

**Save someone else's video, and see what made it work.**

Share a post from any app — Instagram, TikTok, YouTube, Pinterest, Reddit, X — and Quokka
files it. Then it helps you turn what you saved into a script you can actually use.

Saving is table stakes. The product is what happens after.

---

## Start here

| | |
|---|---|
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Why the architecture is what it is. Read before changing anything structural. |
| [`docs/DESIGN.md`](docs/DESIGN.md) | Black, white and sky: the mark, the tokens, every screen. |
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
scripts/run.sh --tab home|library|studio
scripts/run.sh --screen item|playlist|idea   # push straight into a page
swift scripts/render-icon.swift         # app icon + extension icons, from code
scripts/run.sh --relaunch               # relaunch, to prove data persisted
```

**Never pass `--keep`.** A booted simulator's `mediaanalysisd` was measured at 691% CPU and
201°F on this machine.

```sh
cd ios/QuokkaDesign && swift test       # 104 tests, ~1s, no simulator
cd extension && npm test                # 11 tests, no dependencies
```

## Layout

```
ios/
  project.yml              XcodeGen spec. Source of truth; the .xcodeproj is generated.
  Quokka/                  App target
  QuokkaShare/             Share extension — the daily capture path
  QuokkaDesign/            Local SPM package:
    QuokkaDesign             tokens and tile shapes
    QuokkaEngine             pure logic — models, canonicaliser, export parser
    QuokkaImaging            downsampling, encoding, average colour
extension/                 Save to Quokka — right-click Chrome extension (queues locally for now)
mcp/                       quokka-mcp — lets Claude Code read and tag the library, no API key
web/                       Marketing site (paused; app is the priority)
tools/  docs/  scripts/  nextsessions/
```

## What works today

- **Save from any share sheet.** URL, text, image, or a video file.
- **Instagram import** — DMs filtered to one conversation, plus Saved and Liked, deduplicated
  across all three.
- **Thumbnails** per platform, cached at save time, stored as SQLite BLOBs.
- **Breakdowns** — any transcribed video, read on the phone: the hook and when it lands, the
  pace, the numbered beats, the ending's ask, and seven checks with the evidence for each.
  *Use this hook* starts an idea from it.
- **Home / Library / Studio** — black, white and sky, under Matthew's mark. See `docs/DESIGN.md`.
- **Search** — by word (titles, creators, captions, tags, transcripts) and by colour.
- **Transcribe on request** — a video with no words gets a Transcribe button that queues the
  ladder; the timed transcript is searchable and shareable.
- **Playlists** — Organize (multi-select remove), Add, Share, and a script editor per idea.
- **Planner** — to-dos, completed, skipped, and a daily journal, under Studio → Ideas.
- **Save to Quokka** — a Chrome extension: right-click an image, link, video, text or page.
- **`quokka-mcp`** — ask your terminal "what did I save about lighting?"

## What does not work yet

- **Real transcription.** The `public.movie` branch that feeds it is in; the
  Photos → `SpeechAnalyzer` pipeline is not built. Sample scripts stand in, and every one is
  labelled as such on screen.
- **Metrics.** See `backend/ANALYTICS.md` for what is actually obtainable per platform.
- **The blob shape mode.** The seam is in `QuokkaDesign/TileShape.swift`; the shapes are not.
- **Extension → phone.** Saves wait in the browser; the two candidate routes are in
  `docs/DECISIONS.md`.

## Known blockers

1. Instagram, Pinterest and X publish no thumbnail to an unauthenticated client. Settled and
   designed around — the typographic tile is their intended state. It does mean an
   Instagram-heavy library is mostly text cards, which is the strongest argument for the
   extension: on a computer, the right-click carries the image itself.
