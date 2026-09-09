# Frontend session

Owns everything a person looks at. Never reaches into the backend's lane.

## Owns

| | |
|---|---|
| `ios/Allim/Sources/Features` | Screens |
| `ios/Allim/Sources/Components` | Reusable views |
| `ios/AllimDesign/Sources/AllimDesign` | Tokens: palette, type, spacing, motion |
| `web/` | The marketing site |
| `assets/` | Icon, screenshots, marketing art |

## Does not own

`AllimEngine`, `AllimImaging`, `AllimStore`, the fetchers, `mcp/`, App Store Connect.

A screen that needs a rule which does not exist — a new metric, a different grouping —
**asks the backend session for it** rather than computing it in a view. That is the whole
point of the split: logic lives in `AllimEngine`, which is pure and testable without a
simulator, so it can be proved rather than eyeballed.

## Rules

- **White ground, black text, no accent colour, ever.** The only colour on screen belongs to
  the saved work. See `docs/DECISIONS.md`.
- Tokens before components. Nothing reaches for a hex value or a ramp step directly.
- Animate `transform` and `opacity` only. Every animated call site goes through
  `Motion.respecting(_:)` so Reduce Motion is the default rather than something each view
  remembers.
- Verify at 375 / 768 / 1440 equivalents by screenshot before calling anything done.
- **A view must render correctly with no data, with failed data, and with 100,000 rows.**
  All three are normal, not edge cases.

## Honesty rules for analytics UI

This matters more than it sounds. Coverage is not uniform, and pretending otherwise makes
the app look broken:

| Platform | What exists |
|---|---|
| YouTube | Views, likes, comments — official API, complete |
| TikTok | Views, likes, comments, shares — page-embedded, best-effort |
| Instagram, Pinterest, X | **Nothing.** No auth, no numbers |

Never render `0` for a metric that was never fetchable. An absent metric is absent — show a
dash, or omit the tile. A zero is a claim, and it is a false one.

## Running it

```sh
scripts/run.sh                    # build, screenshot, shut the simulator down
scripts/run.sh --seed             # plant sample saves
scripts/run.sh --export           # plant a synthetic Instagram export and import it
scripts/run.sh --relaunch         # relaunch, to prove data actually persisted
```

**Never pass `--keep`.** A booted simulator's `mediaanalysisd` has been measured at 691% CPU
and 201°F on this machine. The screenshots already answer what you needed.
