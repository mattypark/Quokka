# Testing Quokka

Four layers, cheapest first. The first two run on the Mac in seconds; the simulator shows every
screen; **only a phone proves transcription**, because the simulator cannot download Apple's
speech models.

---

## 1. Automated -- run after any change

```sh
cd ios/QuokkaDesign && swift test     # 114 tests, ~1s: links, thumbnails, imports, breakdowns
cd extension && npm test              # 11 tests: what a right-click saves, the queue
```

What they cover: link canonicalisation for every platform, which platforms get a picture and
how, oEmbed titles, Pinterest board / Are.na channel imports, the Instagram export reader, the
transcript ladder's rules, and every check in a breakdown. Views are not unit-tested -- the
screens are checked by looking at them (below).

## 2. The worker

```sh
curl https://quokka.matthew-parkk0.workers.dev/config
```

Should answer `"version":1` with rules for instagram, tiktok and reddit. If it does not, pasted
links fall back to "share the file" -- the app stays working, just with fewer routes.

## 3. Every screen, on the simulator

```sh
scripts/tour.sh              # ~2 min: builds, screenshots all 11 screens, shuts the simulator down
scripts/tour.sh --imports    # ~3 min: also pastes a real Are.na channel, Pinterest board and TikTok
```

Screenshots land in `build/screenshots/tour/`. The breakdowns use **sample transcripts**, and each
screen showing one says so in a banner.

```sh
scripts/transcribe-e2e.sh    # pastes a real TikTok and transcribes it through the live worker
```

Expected on the simulator: config fetched → video found by the web view → downloaded → **"No
speech model for en_US"**. That last line is the simulator's limit, not a bug. Every step before it
is proven.

Never leave a simulator booted -- both scripts shut theirs down, even on Ctrl-C.

## 4. On your phone -- the real test

**Install it** (once): `cd ios && xcodegen generate && open Quokka.xcodeproj`, plug the phone in,
pick it as the run destination, press Run. The first time, the phone asks you to turn on
Settings → Privacy & Security → **Developer Mode** and restart. (Or ship a TestFlight build with
`scripts/testflight.sh --upload` -- see `docs/TESTFLIGHT.md`.)

**Then walk this list.** Each line is one thing to do and what should happen.

| # | Do | Expect |
|---|---|---|
| 1 | Open it fresh | All-sky first screen, the mark blinks, *Get started* |
| 2 | TikTok → a video → Share → Quokka | "Saved to Quokka" card; on Home the video appears with its picture and creator |
| 3 | Tap **Transcribe** on it | "Reading the audio…". The first one also downloads the speech model -- give it a minute on Wi-Fi |
| 4 | Open it | *What worked* with seven checks, the hook and when it lands, the pace, the beats, the ending. Transcript tab shows timed lines |
| 5 | **Use this hook** | An idea opens with the hook filled in and the video attached |
| 6 | Instagram → a reel → Download → share the *file* to Quokka | Transcribes with nothing leaving the phone (rung 0) -- the route that always works |
| 7 | Home → **Add a link** → paste a Pinterest board | "Added 25 from Pinterest board …"; the wall fills with pins |
| 8 | Paste an Are.na channel | Up to 100 pictures on the wall |
| 9 | Paste a YouTube link | Saved with its real title and channel. Transcribe will fail -- YouTube has no free route (see `INGEST.md`) |
| 10 | Library: search a word from a transcript, then tap the colour wheel and pick a swatch | Matching videos; then pictures near that colour |
| 11 | Studio: **+** a playlist → open a video → Save tab → add it; playlist → Organize, Add, Share | All four work |
| 12 | Library → **Import** → your Instagram export `.zip` | Saved / liked / sent-to-self arrive, deduped |
| 13 | Airplane mode, reopen | Everything already saved is still there, pictures included |

Write down anything that looks wrong with a screenshot -- that is the whole bug report.

## 5. The Chrome extension

1. `comet://extensions` (or `chrome://extensions`) → **Developer mode** on → **Load unpacked** → pick `extension/`.
2. Pin Quokka from the puzzle-piece menu.
3. Right-click any image → **Save to Quokka**: a small card slides up bottom-right.
4. Click the toolbar icon: the popup lists the save.
5. Alt+Shift+S on any page saves the page.

Saves stay in the browser for now -- the extension has no route to the phone yet
(`DECISIONS.md`).

## What cannot be tested on the simulator

| Thing | Why | Where to test |
|---|---|---|
| Speech to text | Speech models only download on a device | Phone, step 3 |
| The share sheet from TikTok / Instagram | Those apps are not on the simulator | Phone, steps 2 and 6 |
| Haptics | No Taptic Engine | Phone |
| Real performance with thousands of saves | Simulator runs on the Mac's CPU | Phone, after a big import |
