# Getting Quokka onto TestFlight

Ordered. Each step assumes the one before it worked.

---

## Blockers first — read this before anything else

**1. `KeeponTruckin.ttf` is licensed for personal use only.**

It ships inside the app bundle and it is committed to a **public** repo, which is
redistribution. This is the one hard blocker between here and a submission. Two fixes:

```sh
# Option A — drop it. The type system already falls back cleanly.
git rm --cached ios/Quokka/Resources/Fonts/KeeponTruckin.ttf
echo "ios/Quokka/Resources/Fonts/KeeponTruckin.ttf" >> .gitignore
# then remove it from UIAppFonts in ios/project.yml and from Face.feature
```

Option B: buy a commercial licence, or swap it for an OFL face. `Face.feature` in
`QuokkaDesign/Typography.swift` is the only place it is named — one line.

**2. There is no app icon.** `ASSETCATALOG_COMPILER_APPICON_NAME` points at an `AppIcon` set
with no image in it. A build without one is rejected before a human sees it. 1024×1024, no
alpha, no rounded corners — Apple rounds it.

**3. No App Store Connect record exists yet** for `com.matthewpark.quokka`.

---

## What is already done

- Bundle ID `com.matthewpark.quokka`, team `R43H5332KH`, version `0.1.0 (1)`.
- App Group `group.com.matthewpark.quokka` on both targets.
- URL scheme `quokka://` declared, which the share extension needs to hand off.
- `UIUserInterfaceStyle: Light`, portrait only, iOS 18 minimum.

---

## Steps

### 1. Register the App ID

developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → **+**

- `com.matthewpark.quokka` — enable **App Groups**
- `com.matthewpark.quokka.share` — enable **App Groups**

Both must be in the **same** App Group or the share extension writes into a container the app
cannot read, and every save vanishes silently.

If iCloud sync is wanted later, enable **iCloud → CloudKit** on the app ID too. Without it the
library mirror falls back to the app's own Documents, which still works — see
`docs/DECISIONS.md`.

### 2. Create the App Store Connect record

appstoreconnect.apple.com → Apps → **+** → New App

- Platform iOS, bundle ID `com.matthewpark.quokka`
- SKU: anything unique, e.g. `quokka-001`
- Primary language English (U.S.)

### 3. Make the icon

Run the `ip-as-logo` skill for a Q that matches the mascot — its palette is already in
`Accent` (`#F1B4B2`), so it can be matched rather than approximated.

Drop the 1024 into `ios/Quokka/Resources/Assets.xcassets/AppIcon.appiconset/`.

### 4. Archive and upload

```sh
scripts/testflight.sh
```

Or by hand in Xcode: Product → Destination → **Any iOS Device**, then Product → **Archive**,
then Distribute App → **TestFlight & App Store**.

### 5. Answer the compliance questions

- **Export compliance**: Quokka uses only HTTPS. Answer "uses encryption" → **yes**, then
  "exempt" → **yes** (standard HTTPS only). `ITSAppUsesNonExemptEncryption: false` can be set
  in the Info.plist to stop it asking every build.
- **App Privacy**: Quokka collects nothing and has no accounts or analytics. Everything is on
  device. Answer **"Data Not Collected"** — and keep it true.

### 6. Internal testing

TestFlight → Internal Testing → add yourself. Internal builds skip review and are usually
available within about fifteen minutes of processing.

**External** testers need Beta App Review — a day or two, and it is a real review that can
reject.

---

## What a reviewer will ask about

Write this in the review notes. It is the one part of Quokka that looks like something it is
not:

> Quokka imports a file the user downloads from Meta's own "Download Your Information"
> service. It never signs in to Instagram, never automates an account, never asks for
> Instagram credentials, and makes no request to Instagram's servers. The user unzips the file
> themselves in the Files app and picks the folder.

Reviewers reject things that look like scrapers. This one is visibly not that, and saying so
up front costs nothing.

See `docs/RESEARCH-TRANSCRIPTS.md` for why the transcription path is what it is — the short
version is that no platform permits fetching the audio of a video the user does not own, and
Quokka does not try.

---

## Before calling it done

Walk `~/.claude/rules/10-launch-checklist.md` — all twenty items, each marked done or n/a with
a reason. Then run the `ios-app-store-readiness` skill, which covers the Apple-specific half
this document does not.
