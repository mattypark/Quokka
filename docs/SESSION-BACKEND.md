# Backend session

Owns everything a view asks a question of. Never edits a screen.

## Owns

| | |
|---|---|
| `ios/AllimDesign/Sources/AllimEngine` | Pure logic: models, canonicaliser, export parser |
| `ios/AllimDesign/Sources/AllimImaging` | Downsampling, encoding, average colour |
| `ios/Allim/Sources/Services` | Store, fetchers, cache, scanner |
| `mcp/` | `allim-mcp` |
| `backend/` | Specs, and the waitlist endpoint |
| App Store Connect | Submission, TestFlight |

## Does not own

`Features/`, `Components/`, `AllimDesign/` tokens, `web/`. If a screen needs to change to show
something new, **ask the frontend session** rather than editing the view.

## Order of work

1. **YouTube metrics.** Biggest quality win available, and the only official complete source.
   It also gives real titles, which the app currently lacks entirely — a YouTube save shows
   its URL today.
2. **`allim-mcp`.** See `backend/MCP.md`. Crosses the lane boundary; coordinate first.
3. **Author-grouped collections.** The Instagram import lands ~4,000 items with an author on
   each. Grouping by author is the highest-value organisation available and needs no AI.
4. **TikTok metrics.** Fragile by nature. Degrade to nothing, never to wrong.
5. **Waitlist endpoint.**
6. **Apple submission.**

## Rules

- **Never read or edit `.env*`, keys or credentials.** Ship `Secrets.xcconfig.example`;
  Matthew fills the real one.
- Real features get tests, written alongside, and actually run. Never report "tests pass"
  without running them; quote failures verbatim.
- `AllimEngine` and `AllimImaging` must keep building for macOS so `swift test` runs in a
  second without a simulator. Guard UIKit behind `#if canImport(UIKit)`.
- **`NULL` is not `0`.** A metric that was never fetched is absent. Storing a zero there makes
  the app lie, and the UI has no way to tell the difference afterwards.
- Store raw counts, derive rates at display time. A stored rate is stale the moment a count
  updates.
- Commit after every change. **Never push** without being asked.

## Live Apple account

App Store Connect is a **real commercial account**. Never submit for release, never touch
anything involving money, never delete, never create a public link unasked. TestFlight
configuration and reading feedback only.

## Running tests

```sh
cd ios/AllimDesign && swift test     # 58 tests, no simulator needed
```
