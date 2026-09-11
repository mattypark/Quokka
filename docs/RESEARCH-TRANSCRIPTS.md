# Transcripts — what is actually possible

Researched 2026-09-11. This is the finding the whole product turns on, so it lives in the repo
rather than in a chat log.

**Short version:** there is no sanctioned route to the audio of a video the user does not own,
on any platform. The route that works is the user sharing their own file.

---

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

## 2. The share sheet never hands over a video for a link

Checked across platforms: it is a URL, every time. No file, no asset reference.

Two details worth keeping:

- **YouTube arrives as `public.plain-text`, not `public.url`.** This is the most common way a
  share extension silently drops a save. Allim handles it — `linkCandidate` falls back to text
  and `LinkCanonicaliser.extractFirstURL` digs the link out of a sentence.
- Instagram, Pinterest and X hand over nothing useful at all, which is the same wall the
  thumbnail pipeline already hit.

## 3. A third legal axis: DMCA §1201

Beyond copyright and contract there is **anti-circumvention**, and fair use is **not a defence**
to it.

A direct competitor has already taken this position publicly. Mymind:

> "We will not circumvent these protections, as it's in violation of DMCA anti-circumvention
> laws."

## 4. Apps that do it anyway

Matthew's point was that such apps exist, and that is true — `transcriptfromreel.com` and
`wordsify.io` both do exactly this and are live.

What the research does not find is a *defensible* basis for it. They are operating in the gap
between "nobody has sued yet" and "this is permitted", and they are web services rather than
App Store apps, which is a materially lower-risk posture than shipping through Apple review.

The relevant App Review guidelines are **5.2.2** and **5.2.3** — not 1.4.3, which is about
tobacco and drugs and gets miscited constantly.

## 5. The route that works

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
