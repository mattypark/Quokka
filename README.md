# Allim

**알림** — Korean for *notification*, *reminder*. A place to put the things that moved you.

Save a post from any app's share sheet — Instagram, TikTok, YouTube, Pinterest, Reddit, X,
Cosmos — and Allim files it, finds a thumbnail for it, and sorts it into collections on its
own. Black, white and grey everywhere except the work itself.

## What it is for

The habit this replaces: DMing reels to a second Instagram account and never finding them
again. Allim takes that whole backlog in one import, then takes over the habit.

## Layout

| Path | |
|---|---|
| `ios/project.yml` | XcodeGen spec. Source of truth — the `.xcodeproj` is generated and gitignored. |
| `ios/Allim` | App target. |
| `ios/AllimShare` | Share extension — the daily capture path. |
| `ios/AllimDesign` | Local SPM package: `AllimDesign` (tokens) + `AllimEngine` (pure, testable logic). |
| `mcp/` | `allim-mcp` — lets Claude Code read and retag the library with no API key. |
| `tools/` | Instagram export importer, dev-side. |
| `docs/` | Decisions, session split, and [the transcript research](docs/RESEARCH-TRANSCRIPTS.md). |

## Running it

```sh
scripts/run.sh          # build, boot a dedicated simulator, screenshot, shut it down
scripts/run.sh --keep   # leave the simulator up to poke at by hand
```

`run.sh` shuts the simulator down on the way out on purpose. A booted runtime leaves
`mediaanalysisd` running, and it has been seen pegging a core.

## Requirements

Xcode 26+, `xcodegen` (`brew install xcodegen`). Run `xcodegen generate` in `ios/` after
changing `project.yml`.
