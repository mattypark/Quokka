# Decisions

Why Allim is built the way it is. Each entry is a call that would otherwise look arbitrary,
paired with what would go wrong under the obvious alternative.

## Storage lives on the device, and there is no server

**500,000 items is 15.9 GB.** Per item: a ~30 KB thumbnail, ~1 KB of metadata, and 4 bytes
of average colour. The realistic library is 10k–50k items, or 0.3–1.6 GB.

Measured on the first real fetch: a 800x450 YouTube thumbnail encoded to HEIC at q0.8 came
out at **29,840 bytes**, which lands on the 30 KB estimate almost exactly.

Allim never hosts video. It stores a link and one small image, so a remote media layer would
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

## Fonts

| Face | Role | Note |
|---|---|---|
| Bagel Fat One | Wordmark only | Carries full Hangul, so 알림 renders in its own face |
| Keep on Truckin | Collection titles only | **Personal-use licence.** A blocker for TestFlight or App Store |
| Newsreader | Editorial, tile titles | Stands in for Copernicus, which is a licensed foundry face and not distributable |
| SF Pro | All functional text | System |
| JetBrains Mono | Metadata | Counts, timestamps, hosts |

Two heavy display faces is more than a minimal interface normally carries. They work because
their scope is narrow -- everything a person actually reads is SF Pro or mono.
