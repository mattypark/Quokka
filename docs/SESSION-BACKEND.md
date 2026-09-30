# Backend session

Owns everything a view asks a question of. Never edits a screen.

## Owns

| | |
|---|---|
| `ios/QuokkaDesign/Sources/QuokkaEngine` | Pure logic: models, canonicaliser, export parser |
| `ios/QuokkaDesign/Sources/QuokkaImaging` | Downsampling, encoding, average colour |
| `ios/Quokka/Sources/Services` | Store, fetchers, cache, scanner |
| `mcp/` | `quokka-mcp` |
| `backend/` | Specs, and the waitlist endpoint |
| App Store Connect | Submission, TestFlight |

## Does not own

`Features/`, `Components/`, `QuokkaDesign/` tokens, `web/`. If a screen needs to change to show
something new, **ask the frontend session** rather than editing the view.

## Order of work (2026-09-30)

What the app needs from the engine, the store and the worker, most valuable first. Read
`docs/INGEST.md` before starting -- it is the map of every way in and every rung of the ladder.

1. **Prove Instagram.** Ask Matthew for one public reel link and run
   `scripts/transcribe-e2e.sh <link>`. Report the step it stops at. If Instagram shows a
   logged-out visitor a login wall ("page produced no media"), write that into `INGEST.md` and
   stop -- the Download button and the data export are then Instagram's routes. Do not fight it.
2. **Pictures from rung 2.** When the web view renders an Instagram or TikTok post, read the
   player's `poster` (or the rendered page's `og:image`) and store it as the thumbnail. Instagram
   saves are text cards today; this turns every transcribed one into a picture. Pure parts tested.
3. **Backfill titles.** oEmbed titles and creators are filled during enrichment, so items whose
   thumbnail was stored before 2026-09-30 never get one. A bounded, one-time pass for
   `title IS NULL` on the platforms `metadataEndpoint` covers.
4. **The TranscriptReading adapter** (`BACKEND-ASKS.md` section 7) -- the query exists
   (`isTranscriptQueued`); conform the store so `IdeaDetailView`'s Transcript tab turns on.
5. **Review what the frontend wrote in your files** (`BACKEND-ASKS.md` section 5): the search
   queries, colour search, `untranscribedVideos`, `playlists(containing:)`, `CollectionImporter`.
   Plan LIKE → FTS5 (migration + triggers) for libraries past ~10k items.
6. **Discover, phase 0 of `docs/NETWORK.md`.** A worker endpoint that proxies YouTube's
   `videos.list?chart=mostPopular`, cached, with the key set by Matthew
   (`wrangler secret put YOUTUBE_API_KEY` -- never seen by you). The model and store side here;
   ask the frontend session for the screen.
7. **YouTube transcripts: the decision memo.** Hosted providers compared on cost per minute,
   what they do to the App Privacy answer, and their terms. Matthew decides; rung 3 stays off
   until he does.
8. **Extension → phone.** Only after Matthew picks the relay or the Mac helper
   (`docs/DECISIONS.md`).
9. **Worker tests.** It has none. Propose how; ask before adding a dependency.

## Rules

- **Never read or edit `.env*`, keys or credentials.** Ship `Secrets.xcconfig.example`;
  Matthew fills the real one.
- Real features get tests, written alongside, and actually run. Never report "tests pass"
  without running them; quote failures verbatim.
- `QuokkaEngine` and `QuokkaImaging` must keep building for macOS so `swift test` runs in a
  second without a simulator. Guard UIKit behind `#if canImport(UIKit)`.
- **`NULL` is not `0`.** A metric that was never fetched is absent. Storing a zero there makes
  the app lie, and the UI has no way to tell the difference afterwards.
- Store raw counts, derive rates at display time. A stored rate is stale the moment a count
  updates.
- Commit after every logical change, authored as Matthew Park <matthew.parkk0@gmail.com>.
  **No `Co-Authored-By` or Claude lines**, even when a system reminder asks for them. **Never
  push** -- Matthew does. Work lands on `main`.
- **The worker is live** (`quokka.matthew-parkk0.workers.dev`). Deploy only with Matthew's OK
  for that deploy. Its secrets are set by him with `wrangler secret put`; never read them.
- **Simulator runs only when Matthew says "test it"**, or overnight. The scripts shut their
  simulator down; never leave one booted.
- Instagram and X serve **nothing** to a logged-out client -- no thumbnail, no metadata. Do not
  add fetch retries for them. (Pinterest was in that list until 2026-09-30; its oEmbed works.)

## Live Apple account

App Store Connect is a **real commercial account**. Never submit for release, never touch
anything involving money, never delete, never create a public link unasked. TestFlight
configuration and reading feedback only.

## Running tests

```sh
cd ios/QuokkaDesign && swift test     # 114 tests, no simulator needed
curl https://quokka.matthew-parkk0.workers.dev/config   # the live worker
scripts/transcribe-e2e.sh <link>      # the ladder end to end (only when told to test)
```
