# Transcripts — what is actually possible

Researched 2026-09-11, then re-tested the same day after Matthew pushed back that the
landscape had moved. He was right about the landscape and wrong about the APIs, and the
difference is the whole of this document.

**Short version:** every official API still refuses, and that was re-verified rather than
assumed. What changed is everything around them — Apple is approving this category, Instagram
shipped a Download button, and neither platform will hand a page to a plain HTTP client any
more. Quokka now has four routes, ordered safest first.

---

## Update — the second pass

### 1. Two apps are live on the App Store doing exactly this

| App | ID | Shape |
|---|---|---|
| **ReSerch: Transcribe Video** | `6762029537` | Free. TikTok / Instagram / YouTube links. *"transcribes everything locally on your iPhone… No AI, no server, nothing leaves your device."* Ships iPhone, Mac, Vision. |
| **GetTranscribe Video to Text** | `6754332901` | Paid credits, ~$0.06/min. Instagram, TikTok, YouTube Shorts, Facebook, X, Pinterest. |

The first pass argued that the apps doing this were web services, *"a materially lower-risk
posture than shipping through Apple review."* That argument is dead. Review is approving it.

### 2. Instagram shipped a Download button

Public reels where the creator enabled downloads now save to the camera roll, watermarked,
from the share menu. TikTok's *Save video* has always worked the same way, under the same
creator-controlled setting.

This is bigger than it looks. The first pass treated "the user saves it to Photos first" as a
theoretical route. It is now two taps, and it is **permissioned by the creator** — a stronger
position than fair use, because the setting exists specifically to grant it.

### 3. Neither platform serves a page to a plain client any more — measured

| Target | Result |
|---|---|
| `instagram.com/p/{shortcode}/embed/captioned/` | **HTTP 200, ~623 KB, byte-identical for real and invented shortcodes.** 623536 / 623560 / 623563 bytes across three live NASA posts and one made up. No `video_url`, no `video_versions`, nothing. It is the application shell. |
| `tiktok.com/@user/video/{id}` | Returns `__UNIVERSAL_DATA_FOR_REHYDRATION__` with `statusCode: 10204`, `statusMsg: "item doesn't exist"`, unauthenticated. |
| `tiktok.com/@nasa` | 370 KB, **zero video ids in the markup.** |
| `tiktok.com/oembed` | HTTP 400, both with and without correct parameter encoding. |

**So a regex over a fetched document has nothing to match.** Any design built on server-side
page-scraping of these two platforms was already broken before it was written.

What is left is rendering the page the way the user's browser would. `WKWebView` runs the
page's own JavaScript from the user's own device and address and builds the same `<video>`
element Safari builds. Reading that element is the page working normally. It is also what
keeps the route honestly on-device: no server of Quokka's is involved.

### 4. OAuth does not unlock other people's audio — re-verified

Matthew's proposal was that signing the user in with a Meta / YouTube / TikTok key would open
the door. It opens a different door, and the distinction matters:

| Platform | With the user's own OAuth token |
|---|---|
| YouTube | `captions.download` **403s** for anyone but the video's owner. Not quota, not scope — the contract. |
| TikTok | Display API `video.list` returns the authenticated user's **own uploads**. No favourites endpoint, no saved endpoint. |
| Instagram | Graph API is Business/Creator, own media only. No saved-posts endpoint. |

What OAuth *does* give, officially and with no scraping, is **the list of what the user saved**:

- **YouTube** — `playlistItems.list` on playlist `LL` returns liked videos, plus every playlist
  they own, with real titles, channels and counts. This also fixes a live defect: a YouTube
  save currently displays its own URL as its title.
- **TikTok** — the *Download your data* JSON export carries a **Favorite Videos** list and a
  **Like List**, both with links and dates. Same lawful shape as the Instagram export already
  parsed.

That work is worth doing. It belongs to **import**, not to transcription.

### 5. A hosted provider is leverage, not cover

Supadata's one endpoint covers YouTube, TikTok, Instagram, X and Facebook, tries native
captions first and falls back to ASR. $17/mo for 3,000 credits; one existing transcript is one
credit, generated is two per minute.

Their terms, read directly:

- **§5** — *"You are solely responsible for ensuring that your use of the API and any data
  obtained complies with … the terms of service of any platform to which the data relates."*
- **§11** — the indemnity runs Quokka → them.
- **§3** — resale, sub-licensing or white-labelling needs prior written consent.

So it absorbs the *breakage* and none of the *risk*. Useful, and not a shield.

### 6. `SpeechAnalyzer` forces iOS 26

Verified against the iPhoneOS26.5 SDK. `SFSpeechRecognizer` caps a session at **one minute**
plus 1,000 requests per device per hour, which cannot transcribe a reel — so a lower
deployment target buys a dead feature and an `#available` fence. The target is now 26.0.

Two details from the interface that are easy to get wrong:

- `SpeechAnalyzer.analyzeSequence(from: AVAudioFile)` is the batch path, and **results must be
  drained concurrently** — collecting after `finalizeAndFinishThroughEndOfInput()` deadlocks.
- **`AVAudioFile` cannot open an `.mp4`.** A container carrying video needs its audio exported
  first. This is the single most likely way the whole path breaks while looking like the
  speech model's fault.

---

## What ships: four rungs, one protocol

| | Route | Cost | Footing | Fragility |
|---|---|---|---|---|
| **0** | A video file the share sheet handed over | $0 | Their file, given by the system | None |
| **1** | Creator-authorised download → Photos → rung 0 | $0 | The creator ticked the box | None |
| **2** | `WKWebView` renders the post, media read and **discarded** | $0 | ReSerch precedent, live | High |
| **3** | Quokka's worker → hosted provider | ~$17–47/mo | Pushed back onto us | Low |

Three `TranscriptSource` cases for four rungs, and the missing one is the point: a reel
downloaded with Instagram's own button and a clip from the camera roll arrive **identically** —
same share sheet, same `public.movie`, same bytes. Rung 1 is not a code path. It is rung 0
reached by someone who knows the button exists, which makes it an onboarding problem.

**The rules for rung 2 are fetched, never compiled in** (`backend/worker/src/config.ts`).
They describe someone else's web page, which changes without notice; in the binary, each of
those changes is three days of App Review for a regex. The same mechanism is the kill switch,
and it **fails closed** to rung 0 — a device that cannot reach the worker is the one nobody
can observe or stop, so it gets the least latitude, not the most.

---

## The thing that kills this app

**Building the server-side fetcher because it demos better.** Still true, and now also
pointless: the fetch returns an application shell.

---

## The first pass, kept

Still accurate on the APIs. Superseded where the update above says so.

## 1. Every official API refuses

| Platform | Endpoint | Verdict |
|---|---|---|
| YouTube | `captions.download` | **Owner-only.** `captions.list` works on third-party videos but only confirms captions exist. |
| YouTube | `timedtext` | Gated. See below. |
| TikTok | Display API | OAuth'd to the content owner. |
| TikTok | Research API | Academic approval, non-commercial. |
| Instagram | Graph API | Business accounts, own media only. |

And the policies are explicit rather than merely silent:

- **YouTube Developer Policies III.I.7** — forbids "separate, isolate, or modify the audio or
  video components". *That clause is this feature.*
- **III.E.1.a** — forbids downloading or caching.
- **III.E.6** — forbids obtaining **scraped** YouTube content. Buying transcripts from a
  reseller is the same violation with an invoice attached, not a way around it.

### `timedtext` was tested, not assumed

A bare request, a freshly-signed URL, every format: **HTTP 200 with zero bytes.** A corrupted
signature returns **404**.

That difference is the finding. A 200-with-nothing is a second gate answering — the PO Token
(`exp=xpe`) — not an endpoint that has been removed.

## 2. The share sheet never hands over a video for a link (still true)

Checked across platforms: it is a URL, every time. No file, no asset reference.

Two details worth keeping:

- **YouTube arrives as `public.plain-text`, not `public.url`.** This is the most common way a
  share extension silently drops a save. Quokka handles it — `linkCandidate` falls back to text
  and `LinkCanonicaliser.extractFirstURL` digs the link out of a sentence.
- Instagram, Pinterest and X hand over nothing useful at all, which is the same wall the
  thumbnail pipeline already hit.

## 3. A third legal axis: DMCA §1201

Beyond copyright and contract there is **anti-circumvention**, and fair use is **not a defence**
to it.

A direct competitor has already taken this position publicly. Mymind:

> "We will not circumvent these protections, as it's in violation of DMCA anti-circumvention
> laws."

## 4. Apps that do it anyway (superseded — they are on the App Store now, see the update)

Matthew's point was that such apps exist, and that is true — `transcriptfromreel.com` and
`wordsify.io` both do exactly this and are live.

What the research does not find is a *defensible* basis for it. They are operating in the gap
between "nobody has sued yet" and "this is permitted", and they are web services rather than
App Store apps, which is a materially lower-risk posture than shipping through Apple review.

The relevant App Review guidelines are **5.2.2** and **5.2.3** — not 1.4.3, which is about
tobacco and drugs and gets miscited constantly.

## 5. The route that works (superseded — see the update above, which adds three more)

**User saves the video to Photos → shares the file → transcribed on device.**

It is their file. The system hands it over. Nothing is fetched and nothing is circumvented.

- **`SpeechAnalyzer` / `SpeechTranscriber`** (iOS 26). Verified against the local SDK: batch
  file transcription is first-class, timestamps confirmed, no duration cap, and **no Apple
  Intelligence gate** in the availability annotation.
- Hook, title and outline extraction from the resulting text goes to a small hosted model.

**Roughly $8/month at 1,000 users**, against $100–230 for any server-side design.

### Not WhisperKit

Rejected on **cold start**, not memory — which was the obvious-looking objection and the wrong
one. Core ML keeps ANE weights out of the process footprint, so a 626 MB model runs at ~85 MB
resident and `tiny`/`base` would fit an extension fine. They are simply too inaccurate
(`base` = 10.67 WER) with no headroom, and the model worth shipping needs a **627 MB download
plus ~67 seconds of on-device compilation** on first run.

## 6. Koino

Has **not shipped**. No App Store listing, no Terms page, waitlist only. Their privacy policy
names Supabase and OpenRouter, meters "video imports per day" by tier, and **discloses no ASR
vendor** — which suggests they have not solved this either. Two solo-dev apps in the category
are already live.

---

## The thing that kills this app

**Building the server-side fetcher because it demos better.**

---

## Sources

Apple
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionCreation.html
- https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/AppExtensionKeys.html
- https://developer.apple.com/documentation/foundation/nsextensioncontext/open(_:completionhandler:)

YouTube
- https://developers.google.com/youtube/terms/developer-policies
- https://developers.google.com/youtube/v3/docs/captions/download
- https://developers.google.com/youtube/v3/docs/captions/list
- https://www.youtube.com/t/terms
- https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide
- https://github.com/FreeTubeApp/FreeTube/pull/7484

TikTok / Meta
- https://developers.tiktok.com/doc/display-api-overview
- https://developers.tiktok.com/doc/research-api-specs-query-videos
- https://developers.facebook.com/devpolicy/
- https://developers.facebook.com/docs/instagram-platform/reference/instagram-media
- https://developers.facebook.com/docs/instagram-platform/changelog

Transcription
- https://huggingface.co/argmaxinc/whisperkit-coreml
- https://huggingface.co/datasets/argmaxinc/whisperkit-evals-dataset/tree/main/benchmark_data
- https://app.argmaxinc.com/docs/wiki/supported-platforms
- https://www.argmaxinc.com/pricing
- https://console.groq.com/docs/speech-to-text
- https://deepgram.com/pricing
- https://www.assemblyai.com/pricing
- https://developers.cloudflare.com/workers-ai/platform/pricing/

Models
- https://ai.google.dev/gemini-api/docs/audio
- https://ai.google.dev/gemini-api/docs/pricing
- https://platform.claude.com/docs/en/about-claude/pricing

Competitors and precedent
- https://joinkoino.com/privacy
- https://mymind.helpscoutdocs.com/article/69-why-is-my-saved-video-showing-an-incorrect-thumbnail
- https://transcriptfromreel.com/faq
- https://transcriptfromreel.com/privacy
- https://wordsify.io/terms
- https://help.opus.pro/docs/article/youtube-ownership-verification
- https://en.wikisource.org/wiki/Fox_News_Network_v._TVEyes
