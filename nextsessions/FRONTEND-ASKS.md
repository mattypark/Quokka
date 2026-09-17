# What the backend needs from a screen

> **Already changed in your lane, two lines, sorry:** `ImportView`'s `allowedContentTypes`
> was `[.folder]` and is now `[.zip, .folder]`. Without it the archive reader is unreachable
> and the import still requires finding "Uncompress" in a Files context menu. If you rewrite
> the view, carry it.


Written by the backend session. **Nothing here has been built** — `Features/`, `Components/`
and the design tokens are the frontend session's, and reaching into them mid-session is how
two people end up with the same file open.

Transcription is wired end to end: the ladder runs, results land in `item_transcript`, and
`AppState.transcribe()` drives it exactly like `enrich()` drives thumbnails. It is currently
invisible, because nothing on screen reads it.

## 1. A transcript on the item, when there is one

`QuokkaStore.transcript(forItem:) -> Transcript?`

`Transcript.text` is the words. `Transcript.segments` are timed chunks and are frequently
empty — that is a legitimate state, not a failure. `Transcript.source` says which route
produced it and is worth showing somewhere quiet, because `.hosted` is the only value that
means anything left the device.

## 2. A way to ask for one

Rung 2 renders a web page, so it deliberately does **not** run on every save — a 4,000-row
Instagram import would mean four thousand renders. It needs a control.

`QuokkaStore.enqueueTranscript(itemID:)` then `AppState.transcribe()`. A saved item with no
transcript is the empty state for it.

## 3. An in-progress state

A download, an audio export and a speech model, on a video the user is waiting on. It is
seconds, not milliseconds, and the first run also downloads a speech model.

## 4. A failure state that says what to do

This is the one that matters most, and it is why `TranscriptQueue.describe` returns a sentence
rather than an error code.

`QuokkaStore.exhaustedTranscriptFailure(forItem:) -> String?` — nil while retries remain, on
purpose. A failure that will be retried is not something to put in front of someone.

The common one reads:

> This post will not hand over its audio. Open it in the app, tap Share, then Download, and
> share the file into Quokka.

That instruction is the product working, not an apology. The creator-authorised download is
the **most reliable** route there is, and the only reason it is not the default is that people
do not know the button exists.

## 5. An onboarding beat teaching that button

Instagram shipped a Download button for public reels where the creator allowed it; TikTok's
*Save video* has always been there. Both save to the camera roll, and Quokka's share extension
already accepts `public.movie`.

**Rung 1 is not code — it is this screen.** A reel downloaded with Instagram's own button and
a clip from the camera roll arrive identically, so the only thing standing between a user and
the safest, fastest, most reliable transcript is knowing to tap Download first.

## 6. Somewhere for a video-only save

A share carrying a file and no link used to be dropped on the floor. It is now a real row with
a synthesised `quokka://movie/<uuid>` URL, platform `.web`, and `thumbnailState .unavailable`.

It will render as a typographic tile like Instagram and X do, which is survivable. A first
frame out of the video would be better, and the imaging package can already downsample — but
what it should look like is a design decision, not mine.


---

# Added since: the import and the playlist

## 7. The import now takes the .zip

`ExportScanner.scan(root:)` and `.shares(from:root:...)` are unchanged — hand them the `.zip`
or the unzipped folder and both work. `ExportScanner.isArchive(url)` says which one you got.

The instructions screen should now say something much shorter. The real flow is:

1. Instagram → Settings → **Download your information** → request it (Meta emails a link, takes
   a few hours to a day)
2. Download the `.zip` on the phone
3. Quokka → Import → pick the `.zip`

There is no longer an unzip step, and `ExportScanner.Contents.isEmpty` distinguishes "picked
the wrong thing" from "your account is empty" — worth different copy.

## 8. Videos onto a playlist, without inventing an Idea

New and this is the one that matters for the way the app is actually used: pick saves in the
library, drop them in a playlist, ask what is in them.

- `QuokkaStore.addToPlaylist(_:itemIDs:)` → returns how many were *new*, so a confirmation can
  honestly say "added 24 of 30, six were already there"
- `QuokkaStore.playlistItems(_:)` → everything in it, directly-added and idea-sourced, deduped
- `QuokkaStore.removeFromPlaylist(_:itemIDs:)`

The old playlist → idea → item route still works and still matters; this is the other
direction, and no screen should have to know which one put something there.

## 9. The playlist summary

`Playlist.summary` and `Playlist.summarisedAt`, plus `Playlist.summaryIsStale`.

Three states, and they are genuinely different:

| State | What it means | What it should say |
|---|---|---|
| `summary == nil` | never summarised | offer to summarise |
| `summaryIsStale` | videos added since | show it, marked as behind |
| otherwise | current | show it |

`summary` is **not** `note`. `note` is the user's own writing and must never be overwritten by
something a model produced.

## 10. Where the summary comes from

Claude Code, over the MCP, on the subscription already on the machine — no API key, no
per-summary cost. The app writes `playlists.jsonl` and `library.jsonl` (now carrying
transcripts) into the mirror; `quokka_write_summary` appends to `summaries.jsonl`; the app
drains and clears it on next launch.

So the UI affordance is closer to "ask Claude to summarise this" than to a spinner: the work
happens on the Mac and lands on the next launch. Copy should not promise it is instant.

Requires **"Let Claude read your library"** in settings — the mirror is off by default, and
without it none of this exists.
