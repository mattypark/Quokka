# Getting things in, and getting the words out

How a save gets into Quokka, how it gets a picture and a title, and how a video becomes a
transcript and a breakdown -- plus why Pinterest and Cosmos have so many pictures, and what
Quokka can and cannot copy from that. Written 2026-09-30, every claim below measured that day.

---

## 1. Why Pinterest and Cosmos are full of pictures

**They are networks, and your feed is other people's saves.** That is the whole trick, and it is
not something a design change can copy.

| | Where the pictures come from |
|---|---|
| **Pinterest** | Every pin is someone saving an image -- from the Save button in a browser, the share sheet, or an upload. Pinterest copies the image onto its own CDN (`i.pinimg.com`, in 236 / 474 / 736 / original sizes), reads the page's Open Graph and Rich Pin tags for the title, and pools every save from every user into one corpus of hundreds of billions of pins. Your home feed is a recommendation over that pool. |
| **Cosmos** | The same model, smaller and more curated. "Save to Cosmos" from the Chrome extension, the share sheet, and a hover button on Instagram; **"import from anywhere"** -- whole Pinterest boards and Are.na channels -- so a new account starts full; every element copied to Cosmos's CDN; "For You" is other people's elements, searchable by colour and by image. |

What makes them *feel* dense is mostly layout: small thumbnails, a masonry grid at each image's
own shape, a placeholder colour before the image lands, and prefetching the next screen before
you reach it. Quokka already does all four -- 600px thumbnails stored as BLOBs, masonry at native
ratio, the average colour as the placeholder, keyset paging.

**What Quokka can do without becoming a network**, in order of how much it adds:

1. **Every save gets a picture.** Done for YouTube, TikTok, Vimeo, Reddit, any web page, and --
   new today -- Pinterest, whose oEmbed was found to serve a thumbnail with no login. Instagram and X
   still serve nothing to a logged-out client; the Chrome extension's right-click is the way
   around that, because it carries the image itself.
2. **Import whole collections.** Done today: paste a Pinterest board (its latest 25 pins), a
   Pinterest profile, or an Are.na channel (up to 100 pictures). Measured: three pasted links took
   a 15-item library to 140, and every Are.na block and 24 of 25 pins arrived with a picture.
3. **A Discover feed from licensed sources** (not built). The one that fits the product is
   **YouTube's `videos.list?chart=mostPopular`** -- trending videos with thumbnails, every one of them
   something to break down. It needs a YouTube Data API key, which belongs on the worker, never in
   the app. Are.na's public channels and Openverse (Creative Commons images) are the no-key options
   for plain inspiration.
4. **A shared layer** (not planned). Accounts, a server that stores other people's saves, and
   moderation. This is Cosmos's actual moat and it is a different product with a different bill.

---

## 2. Every way in

| Way in | What arrives | Picture | Title / creator | Can be transcribed |
|---|---|---|---|---|
| **Share sheet**, from any app | A link, text, an image or a video file | By platform (below) | By platform | A shared **video file** always can (rung 0) |
| **Add a link** -- one post | The post | By platform | From oEmbed, where it is open | Once the worker is live, for TikTok / Instagram / Reddit |
| **Add a link** -- a Pinterest board or profile | Its latest 25 pins | Yes, via Pinterest oEmbed at 736px | Yes | No -- pins are pictures |
| **Add a link** -- an Are.na channel | Up to 100 blocks with pictures | Yes, via each block page's og:image | Block title | No |
| **Import** -- Instagram's export `.zip` | Saved, liked and sent-to-self, deduped | No (Instagram serves none) | The creator's handle | Once the worker is live |
| **Chrome extension** | Any image, link, text or page | The image itself, for an image save | The page title | Not yet -- **the extension has no route to the phone** (see `DECISIONS.md`) |

**Add a link** is on Home and at the top of the Library. It uses the system Paste button, which
reads the clipboard without the "Allow Paste" prompt because the tap is the permission.

---

## 3. What happens after a link lands

```
paste / share / import
        │
        ▼
LinkCanonicaliser ── strips tracking, resolves the platform and the content id
        │
        ▼
insert ── the canonical URL is unique, so the same post from three places is one row
        │                 pinterest, youtube, tiktok, reddit, vimeo, web → pending
        │                 instagram, x, threads → unavailable (typographic tile, never retried)
        ▼
enrichment, pass after pass until a pass stores nothing
        ├─ oEmbed metadata  → fills title and creator where empty (never overwrites)
        └─ ThumbnailPlan    → YouTube: i.ytimg.com by id, best size first
                              TikTok, Vimeo, Pinterest: oEmbed thumbnail_url
                              Reddit, web pages: og:image (Reddit made permanent)
        │
        ▼
600px HEIC in SQLite + its average colour → the grid, the wall, the breakdown
```

---

## 4. From a video to a breakdown

Tapping **Transcribe** -- on Home, on the video's page, or in its **⋯** menu -- queues a job;
`TranscriptQueue` runs the **ladder**, trying the safest route first and stopping at the first
that produces words. The words then go through `Breakdown` (rules, on the phone) and the page
fills in.

| Rung | What it does | Status today |
|---|---|---|
| **0 -- shared file** | A video file handed over by the share sheet, read by `SpeechAnalyzer` on the phone | **Works.** Nothing leaves the phone |
| **1 -- creator download** | The same as rung 0, reached by saving the video with the app's own Download button first | Works -- it *is* rung 0. An onboarding job, not code |
| **2 -- resolve on device** | Renders the post in an offscreen web view (Instagram, TikTok) or reads its page (Reddit), downloads the media, transcribes it, deletes it | **Off.** Its rules come from the worker, and **the worker is not deployed** (`quokka.matthew-parkk0.workers.dev` answers Cloudflare 1042, no such worker). With no config the app fails closed to rung 0 -- on purpose |
| **3 -- hosted** | The URL goes to a paid transcript provider through the worker | Off by design. Switching it on changes the App Privacy answer from "Data Not Collected" |

**Per platform**, once rung 2 is on:

| Platform | Route to the words |
|---|---|
| TikTok, Instagram | Rung 2 (web view). Private or region-locked posts fail with the sentence to download and share the file |
| Reddit | Rung 2 (page pattern) |
| **YouTube** | **No free route.** The player streams through `blob:` URLs, so rung 2 finds nothing, and the captions API only serves a video's owner. Rung 0 (share the file) or rung 3 (a provider) |
| X, Threads | None |

Simulator caveat: `SpeechAnalyzer` needs on-device speech models, so real transcription has to
be proved on a phone. Screenshot runs use the sample transcripts, and the screen says so.

---

## 5. What to do next, in order

1. **Deploy the worker.** No new Cloudflare account: the same one that runs Nudgy takes a second
   worker on the free plan. `cd backend/worker && npx wrangler deploy`, then put its host in
   `ios/Quokka/Secrets.xcconfig` as `QUOKKA_WORKER_HOST` (host only, no `https://`). That turns on
   rung 2 for TikTok, Instagram and Reddit. It needs no secrets.
2. **Prove it on a phone.** Paste a TikTok, tap Transcribe, watch the breakdown fill.
3. **Decide YouTube.** Share-the-file only, or a hosted provider for rung 3 (a key on the worker,
   a per-minute cost, and the privacy answer changes).
4. **Give the extension its route to the phone** (the relay or the Mac helper -- `DECISIONS.md`).
5. **Discover**: trending YouTube through the worker, so the wall is full on the first day.
