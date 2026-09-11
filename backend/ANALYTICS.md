# Analytics

What Quokka can actually know about a saved post, per platform. The short version: **YouTube
is complete and official, TikTok is best-effort, and everything else has nothing.**

Designing around that honestly is the whole job here. A metric that was never fetchable must
render as absent, never as `0` — a zero is a claim, and it would be a false one.

## Coverage

| Metric | YouTube | TikTok | Instagram | Pinterest | X |
|---|---|---|---|---|---|
| Views | official API | page JSON | — | — | — |
| Likes | official API | page JSON | — | — | — |
| Comments | official API | page JSON | — | — | — |
| Shares | — | page JSON | — | — | — |
| Saves | — | page JSON | — | — | — |
| Author, title, published | official API | page JSON | — | — | — |

Instagram, Pinterest and X are the same wall the thumbnail pipeline already hit: no public,
unauthenticated surface. This is not a gap to close later. It is the shape of the problem.

For those platforms the app already has something better than nothing — for imported items,
the **author comes out of the Instagram export's `original_content_owner` field**, and the
caption is whatever the user typed when they sent it. Lean on that instead of pretending
numbers exist.

## What VidIQ actually does, and the part worth copying

VidIQ is a YouTube tool. Its public numbers come from the **YouTube Data API v3** — the same
endpoint anyone can call with a free key. It does not have privileged access to view counts.

The part worth copying is not the fetching, it is the **framing**. Raw counts are close to
useless for comparison: a 2.3M-view video and a 40k-view video cannot be judged side by side.
Rates can. That is why every number in Koino's own screenshots is a rate —
`Like rate 7.37%`, `Share rate 2.62%`, `Save rate 6.71%` — and why the raw counts sit smaller
above them.

So: **fetch raw counts, store raw counts, derive rates for display.** All the rates are one
division:

```
like rate    = likes    / views
comment rate = comments / views
share rate   = shares   / views
save rate    = saves    / views
```

Store the raw values, never the derived ones. Rates recompute for free and a stored rate goes
stale the moment a count updates.

VidIQ's proprietary "scores" are derived from historical baselines it accumulated over years.
Quokka has no such corpus and should not pretend to. What Quokka *can* do honestly, once the
library is large enough, is compare a video against **the user's own saved set** — "this is in
the top 10% of what you save for share rate" is a real, defensible statement built entirely
from local data.

## Implementation

### YouTube — do this first

`GET https://www.googleapis.com/youtube/v3/videos?part=statistics,snippet&id={id}&key={key}`

Returns `viewCount`, `likeCount`, `commentCount`, plus title, channel and publish date.
Free quota is generous — a `videos.list` call is 1 unit against a 10,000/day allowance, and
up to 50 ids can be batched per call, so a full library refresh is cheap.

**Verify before building:** confirm the current quota cost and that `likeCount` is still
returned (it has been withheld for some videos in the past). Do not take these figures from
this document — check the live docs.

This also fixes something the app currently lacks: real **titles**. Right now a YouTube save
shows its URL. The API gives the actual title and channel, which is a bigger quality win than
any metric.

The key belongs in `Secrets.xcconfig`, which is gitignored. `Secrets.xcconfig.example` is
committed and documents it. **Never commit a real key, and never read Matthew's `.env`.**

### TikTok — second, and expect it to break

Stats are embedded in the page as JSON. There is no official public endpoint for another
user's video — TikTok's Display API is OAuth'd to the content owner.

This makes it **fragile and ToS-grey**. Build it so that when it breaks, it degrades to no
metrics rather than to wrong ones, and so a failure never blocks the save. Rate-limit it and
cache aggressively; do not refresh on every scroll.

Flag this one to Matthew before shipping to the App Store. It is the kind of thing that
turns into a review question, and the honest answer — "the app reads a public web page the
same way a browser does" — is easier to give if it is designed that way from the start.

### Instagram, Pinterest, X

Do not implement. Do not add a "retry" for these. The UI already treats them as terminal.

## Storage

Metrics are their own table, joined to `item` by id — same reasoning as thumbnails: the rows
that get sorted and filtered stay narrow.

```sql
CREATE TABLE metrics (
  itemId   INTEGER PRIMARY KEY REFERENCES item(id) ON DELETE CASCADE,
  views    INTEGER,   -- nullable throughout. NULL means "never fetched",
  likes    INTEGER,   -- which is a different fact from 0.
  comments INTEGER,
  shares   INTEGER,
  saves    INTEGER,
  title    TEXT,
  channel  TEXT,
  fetchedAt DOUBLE NOT NULL
);
```

Every column nullable, deliberately. `NULL` means never fetched; `0` means fetched and
genuinely zero. Collapsing those two is the single easiest way to make this feature lie.
