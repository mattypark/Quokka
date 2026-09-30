# Decisions

Why Quokka is built the way it is. Each entry is a call that would otherwise look arbitrary,
paired with what would go wrong under the obvious alternative.

## Storage lives on the device, and there is no server

**500,000 items is 12.4 GB, measured.** Per item: a ~25 KB thumbnail, ~1 KB of metadata, and
4 bytes of average colour. The realistic library is 10k–50k items, or 0.25–1.3 GB.

That number is measured rather than estimated, and the first measurement corrected the plan.
At 800px on the long edge and q0.8, real YouTube thumbnails averaged **41,385 bytes**, not the
30,000 the projection assumed -- which put 500k items at 20.7 GB, right at the threshold where
a remote tier starts to be worth building. Dropping to 600px and q0.75 brought the average to
**25,604 bytes** and the projection to 12.4 GB.

600px is not a compromise: a two-column grid on a 393pt phone gives each tile ~195pt, which is
585px at 3x, and the tile is never a viewer because tapping opens the original post. The 800px
version was storing pixels nothing would ever render.

Quokka never hosts video. It stores a link and one small image, so a remote media layer would
be a monthly bill and a second system to maintain in exchange for nothing. Cloudflare R2 is
the right tool for a problem this app does not have.

**When that flips**, in likelihood order: a second derivative size (500k x (30 KB + 120 KB) =
76.8 GB, which does not fit -- so there is exactly one derivative, and tapping opens the
original post); a second client, web or iPad, which flips it immediately; wanting eviction at
all; or roughly 20–25 GB.

## Thumbnails are BLOBs, in their own table

SQLite's own guidance is that reads beat the filesystem below 100 KB, and these are ~30 KB.
Half a million loose files is the small-file problem Facebook wrote the Haystack paper about
in 2010 -- cited as the problem they solved then, not as current infrastructure, since
Tectonic has replaced both Haystack and f4.

They live in a separate table from the metadata that gets sorted and filtered, so a page scan
never drags image bytes through memory.

## GRDB, not SwiftData

SwiftData model classes are `@MainActor`-isolated, so a 3,000-row Instagram import marshals
onto the main thread. And `@Attribute(.externalStorage)` spills blobs to loose files, which
recreates precisely the problem the BLOB decision exists to avoid.

## The database is in Application Support, not Caches and not the App Group

Thumbnails are **unregenerable primary data**. The CDN URLs they came from expire, so a purged
thumbnail is gone permanently -- which fails Apple's "the app can create them again from
source" test for `Library/Caches`. There is no eviction policy: 15.9 GB is a budget, not a
cache ceiling.

The App Group is ruled out separately. iOS terminates a suspended app holding a file lock in a
shared container (`0xDEAD10CC`), and a WAL-mode connection is exactly that lock. The App Group
holds an inbox of JSON records and nothing else.

Kingfisher and SDWebImage are disqualified as the store for the same reason: their 7-day
default disk TTL is silent total data loss on a one-week-old library.

## Paging is keyset, never OFFSET

`savedAt < ? OR (savedAt = ? AND id < ?)`, with an index matching that predicate exactly.

New saves land at the head of a reverse-chronological list constantly, and `OFFSET` shifts
every row down when they do -- so page two repeats a row or skips one. Meta's TAO pages its
association lists this way for the same stated reason: *"most of the data is old, but many of
the queries are for the newest subset."*

The `id` is not decoration. A bulk import writes thousands of rows and `savedAt` ties are the
norm there, not an edge case.

## Three platforms never get a thumbnail, and that is a designed state

Instagram, Pinterest and X serve no `og:image` to an unauthenticated client. Pinterest and X
do have permanently durable CDN URLs, but they are undiscoverable without auth, which makes
their durability irrelevant.

Items from those platforms are constructed `.unavailable` rather than `.pending`, so the
enrichment queue cannot pick them up and retry a fetch that can never succeed. Their tile is a
typographic mark in the display face, which is the payoff of committing to black and white:
the failure case is on-brand.

The one open question is whether their **share sheet** payload carries an image even though
their HTTP responses do not. Every inbox record logs the type identifiers it arrived with so
that can be answered on a device.

## Bytes are cached at save time, always

Re-resolution is not a fallback. TikTok's thumbnail URL is signed and expires in about 48
hours, and once it does the image is unrecoverable if the post has since been deleted or made
private. Of nine read-later apps surveyed, eight cache the bytes; only Readwise Reader
hotlinks.

Files are keyed on a hash of the **post** URL, never the image URL: TikTok and Instagram
re-mint CDN URLs on every resolve, so an image-keyed name re-stores the same thumbnail under a
new key every time.

Reddit is the happy exception. Its `og:image` is a signed `preview.redd.it` URL, and rewriting
the host to `i.redd.it` addresses the same media id with no signature and no expiry -- a free
upgrade from expiring to permanent.

## A flat average colour, not ThumbHash or BlurHash

Four bytes per row, 2 MB across 500,000 items, zero decode.

Placeholders exist to hide **network** latency. This architecture has none: the thumbnail is a
local BLOB read. Immich measured the same comparison in a near-identical grid and found
generating placeholders alongside thumbnails cost 2500 ms against 1550 ms -- a 61% penalty to
mask a read already faster than a frame -- and removed theirs.

Reinstate ThumbHash only if CloudKit sync is added. That is the one case with real latency to
hide, because a new device paints the whole grid before any thumbnail arrives.

## A hand-rolled LRU, not NSCache

`NSCache` orders its eviction list **by cost and evicts the cheapest first**, not by recency,
and its purge loop runs **only on insertion**. For a grid of similarly-sized thumbnails that is
inverted: small tiles are discarded while large ones survive, and a fast flick blows past
`totalCostLimit` before anything is reclaimed. Default-configured, it never evicts at all.
Kingfisher's memory backend is `NSCache` underneath and inherits all of it.

## HEIC, not WebP

HEIC is roughly half the size of JPEG at equivalent quality -- the difference between ~16 GB
and ~30 GB at half a million items. This inverts the WebP standard in `fittie` for a checkable
reason: that decision rejected HEIC because browsers cannot decode it, and nothing outside
this device will ever read these bytes. Capability is checked rather than assumed, since
`CGImageDestination` creation returns nil without a hardware HEVC encoder.

## The share extension does no network and materialises no bitmaps

It runs under a ~120 MB ceiling (`EXC_RESOURCE RESOURCE_TYPE_MEMORY`) and is killed for being
slow. A decoded 4000x3000 photo is ~48 MB, and the canonical way to hit the limit is exactly
this workload: a `UIImage` from a file, then a second resized one. Everything goes through
`CGImageSourceCreateThumbnailAtIndex`, which never decodes the full image.

So the extension writes a deliberately dumb record and gets out. The app does the thinking.

## Black, white and sky, and the breakdown is the product

**Decided 2026-09-30, superseding the Cosmos pass below.** Matthew: the app exists to take other
people's videos and show *what went well* -- vidIQ-style, on the phone -- and the look is about a
third Nudgy's sky with the rest Quokka's own, under his logo. See `docs/DESIGN.md`.

**The breakdown is rules, not a model** (`QuokkaEngine/Breakdown.swift`). Every finding points at
the words -- "the opening line ends at 1.8s", "172 words a minute", "asks for a follow" -- so a
passed check is evidence, the same transcript always breaks down the same way, and it runs on the
phone with no key and nothing sent. A hosted model can narrate on top later; the checks must never
rest on one, because then two people looking at the same video would see different verdicts and
neither could check why.

**No invented metrics.** Views and likes are shown only where a platform actually gives them to an
unauthenticated client (see `backend/ANALYTICS.md`); a breakdown never makes up a score that is not
a count of checks passed.

## One face, and the interface copies Cosmos

*Superseded 2026-09-30 by the entry above; kept because the structure it set -- pushed pages,
masonry at native ratio, search by colour, SF Pro -- is still in the app.*


**Decided 2026-09-28.** The app was redesigned to copy [Cosmos](https://www.cosmos.so)'s layout
and interaction one for one -- measured, in `docs/DESIGN-REFS.md` -- and the mascot was removed.

It used to carry five faces: Bagel Fat One for the wordmark, two personal-use display faces,
Newsreader for tile titles and JetBrains Mono for metadata. Each had one job, and together
they were five voices on a screen whose only colour is supposed to be the saved work. Cosmos
sets everything in one neutral grotesk at two weights and lets the images be the only
expressive thing on screen. It is the right call for a library that is all pictures.

Cosmos's face is ABC Oracle, a paid Dinamo licence. **SF Pro stands in**: it is the closest
neutral grotesk the OS ships, so it costs no licence, no bundle bytes and no fallback path.
The personal-use submission blocker went with the rest.

What is copied is structure -- screen anatomy, spacing, type sizes, the way chrome floats.
What is not: the dots logo, the typeface file, any Cosmos image and any Cosmos copy.

## The Chrome extension queues locally until a sync path is chosen

**Decided 2026-09-28.** `extension/` saves images, links, videos, text and pages from a
right-click, and holds them in `chrome.storage.local`. Nothing leaves the browser yet.

The library lives only on the phone and there is no server, so a save made on a computer has
no route to it today. Matthew chose to see the redesigned app before picking one. The two
candidates:

| Route | How | Trade |
|---|---|---|
| **Worker relay** | Quokka's worker gets a small D1 inbox. The app shows a pairing code once; the extension posts to the inbox; the app pulls on foreground and the rows are deleted on delivery | Works from any computer. It is the first server-side storage this app has had, even though it only holds what has not been delivered yet |
| **Mac iCloud helper** | A native-messaging helper writes records into Quokka's iCloud Drive folder, the one `LibraryMirror` already uses, and the app drains them like the App Group inbox | No server. Macs only, one helper to install, and it needs the iCloud capability registered in the portal |

Either way, **the record is already the inbox's shape**. `extension/lib/record.js` builds `id`,
`receivedAt`, `rawURL` and `rawText` exactly as `ShareInboxRecord` has them, plus `srcURL`,
`pageURL` and `pageTitle`, so the sync is a transport and nothing else. `InboxDrain` will
need to learn one thing: an image save's `srcURL` is the thumbnail, fetched rather than
downsampled from a file.

## The mirror, and Claude with no API key

The library is written to `library.jsonl` in the app's iCloud container, which on a Mac is an
ordinary folder — so `mcp/quokka-mcp` reads it directly with no server and no key, running on
the Claude Code subscription already on the machine. Tags come back through `tags.jsonl`,
which the app applies and then clears.

JSONL rather than a JSON document: a half-million-line file appends in constant time and
streams line by line, where a single array must be parsed whole at both ends. The row shape is
its own type rather than `Item`, because the mirror is a published interface read by a separate
program and has to stay stable while the stored model moves.

**Off by default.** Writing someone's entire saved library into iCloud is their decision, and
the toggle says plainly what it does at the point the decision is made.

It falls back to the app's own Documents when the iCloud entitlement is absent — that
capability is a portal change and is not always in place, and `UIFileSharingEnabled` keeps the
fallback reachable through Files. The feature degrades from "syncs by itself" to "move one
file" rather than disappearing.


## Transcripts — the door that is actually open

Researched, and the answer was not the one assumed going in.

**There is no sanctioned route to the audio of a video the user does not own.** On any
platform. `captions.download` is owner-only. YouTube's Developer Policies **III.I.7** forbid
separating or isolating the audio component — that clause *is* this feature — and **III.E.6**
forbids obtaining scraped YouTube content, so buying transcripts from Supadata or Apify is the
same violation rather than a way around it.

`timedtext` was tested live rather than assumed: a freshly-signed URL returns **HTTP 200 with
zero bytes**, while a corrupted signature returns 404. That difference proves a second gate
(the PO Token), not an absent one.

**No platform hands the share sheet a video file for a link.** It is a URL every time. Worth
knowing separately: **YouTube arrives as `public.plain-text`, not `public.url`** — the most
common way a share extension silently drops a save, and the reason `linkCandidate` falls back
to text.

**A competitor already refused this category on the same grounds.** Mymind, publicly: *"We
will not circumvent these protections, as it's in violation of DMCA anti-circumvention laws."*
That is a third legal axis beyond copyright and contract, and fair use is not a defence to
circumvention.

### What ships instead

The user saves the video to Photos, then shares the **file**. It is their file, handed over by
the system. Transcription runs on device with `SpeechAnalyzer` (iOS 26 — batch file
transcription is first-class, timestamps confirmed, no duration cap, no Apple Intelligence
gate). Hook and title extraction goes to a small hosted model.

Roughly **$8/month at 1,000 users**, against $100–230 for any server-side design.

Not WhisperKit: the accurate models need a ~627 MB download and about 67 seconds of on-device
compilation on first run, and the small ones are too inaccurate to be worth shipping. Memory
was never the problem — Core ML keeps ANE weights out of the process footprint — cold start is.

**The thing that kills this app is building the server-side fetcher because it demos better.**

### Koino, for the record

Still has not shipped. No App Store listing, no Terms page, waitlist only. Their privacy
policy names Supabase and OpenRouter and conspicuously discloses no ASR vendor. Two solo-dev
apps in the same category are already live.
