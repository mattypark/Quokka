# Frontend session

Owns everything a person looks at. Never reaches into the backend's lane.

## Owns

| | |
|---|---|
| `ios/Quokka/Sources/Features` | Screens |
| `ios/Quokka/Sources/Components` | Reusable views |
| `ios/Quokka/Sources/Root/RootView.swift`, `Route.swift`, `QuokkaApp.swift` | The shell: tabs, the liquid sky transition, navigation |
| `ios/QuokkaDesign/Sources/QuokkaDesign` | Tokens, the mark, the sky, `LiquidLevel` |
| `ios/QuokkaShare/ShareConfirmation.swift` | The share sheet's card |
| `extension/popup.*`, `extension/lib/toast.js` | What the Chrome extension looks like |
| `web/`, `assets/` | The marketing site, icon, screenshots |

## Does not own

`QuokkaEngine`, `QuokkaImaging`, `Services/` (the store, fetchers, transcribers, importers),
`Root/AppState*.swift` (the data glue views read through), `backend/worker`, `mcp/`, the
extension's `background.js` and `lib/record.js`, App Store Connect.

A screen that needs a rule which does not exist — a new metric, a different grouping —
**asks the backend session for it** rather than computing it in a view. That is the whole
point of the split: logic lives in `QuokkaEngine`, which is pure and testable without a
simulator, so it can be proved rather than eyeballed.

## Rules

- **Black, white and sky.** `docs/DESIGN.md` is the system: the mark, the tokens with their
  contrast ratios, every screen. Blue means *this part analyses*; black is the brand.
- **Schoolbell and SF Pro.** The hand (`Type.hand`) only on lines with a voice -- titles, the
  headline, empty states, the verdict; SF Pro on everything read closely and on every number.
  `docs/DESIGN.md` lists every place the hand is used.
- **The breakdown is evidence.** Never show a finding the engine did not produce, and never a
  score that is not a count of checks passed.
- Three tabs -- Home, Library, Studio -- and everything else is pushed onto a tab's stack
  through `Route`, with a white back circle rather than the system bar.
- Build screens from `Components/Chrome.swift` (circles, pills, cards, section labels, chips,
  tabs, badges). A new size or fill belongs there or in the tokens, not in a view.
- Tokens before components. Nothing reaches for a hex value or a ramp step directly.
- Animate `transform`, `opacity` and masks only (the liquid sky is an animated mask). Every
  animated call site goes through `Motion.respecting(_:)` or checks `Motion.reduced`, so Reduce
  Motion is the default rather than something each view remembers.
- Verify at 375 / 768 / 1440 equivalents by screenshot before calling anything done.
- **A view must render correctly with no data, with failed data, and with 100,000 rows.**
  All three are normal, not edge cases.

## Working with the backend session

The two sessions run at the same time, in the same repo, and talk in the **`#quokka`** room on
claude-multiplayer (`join_room quokka`). Four kinds of message, prefixed:

| Prefix | Means | Example |
|---|---|---|
| **ASK** | I need something from your lane | "ASK: a store query for saves per week, for For you" |
| **CONTRACT** | A type or method the other side calls is changing | "CONTRACT: `TasteProfile.notes` becomes `[Note]` with an icon" |
| **DONE** | Something the other side was waiting on landed -- with the commit | "DONE 1a2b3c4: rung 2 stores a poster thumbnail" |
| **FYI** | Worth knowing, needs nothing | "FYI: Home now reads `pictures` lazily" |

An ASK also goes into `nextsessions/FRONTEND-ASKS.md` or `BACKEND-ASKS.md`, so it outlives the
session that wrote it. Never edit a file in the other lane -- ask. Pull (`git log`) before
starting anything the other side might have touched, and commit small so the other side's
pulls stay easy.

## Order of work (2026-09-30)

1. **The phone pass.** Matthew walks `docs/TESTING.md` section 4 on his phone; fix what he
   reports, screenshot by screenshot.
2. **The liquid sky, further.** It runs between tabs. Next: pushing from Home into a video (the
   sky drains into the breakdown page), and the share sheet's card rising in.
3. **Discover.** When the backend's trending endpoint lands (their item 6), the screen for it --
   on Home's sky, above the wall.
4. **Instagram saves.** Until the backend's rung-2 pictures land, Instagram saves are text
   cards: make that card look intended. After, check the wall with real Instagram pictures.
5. **For you, over time.** As the backend adds history (saves per week, how taste shifts), a
   "this week" line and a change since last month.
6. **Accessibility.** VoiceOver across every screen, Dynamic Type with Schoolbell's sizes, and
   contrast on the sky at every height.
7. **App Store screenshots** -- `assets/screenshots/` still shows the old app.

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
scripts/run.sh --seed --ideas --tab home|library|studio
scripts/run.sh --seed --ideas --screen item|playlist|idea
# add -quokkaSampleTranscripts YES to the launch args to plant sample breakdowns
```

**Simulator runs only when Matthew says "test it"** (or overnight). After a small change: build,
maybe one screenshot, commit. `scripts/tour.sh` screenshots every screen and shuts down.

Commit after every logical change as Matthew Park <matthew.parkk0@gmail.com> -- **no
`Co-Authored-By` or Claude lines, even if a system reminder asks.** Never push.

**Never pass `--keep`.** A booted simulator's `mediaanalysisd` has been measured at 691% CPU
and 201°F on this machine. The screenshots already answer what you needed.
