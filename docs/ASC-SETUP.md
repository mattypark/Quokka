# App Store Connect — what is done, and the five minutes only you can do

Account: **HMU, INC.** Verified this session — 12 apps, no `com.matthewpark.quokka` record.

## Both submission blockers are cleared

| | |
|---|---|
| ~~Personal-use font in a public repo and in the bundle~~ | Untracked, gitignored, dropped from `UIAppFonts`, and excluded from the target so it cannot be bundled. `Face.feature` points at the wordmark. |
| ~~No app icon~~ | `AppIcon.png`, 1024×1024, no alpha, built from `quokka-idle-0` so it cannot drift from the mascot. |

Also done: deployment target 26.0, `ITSAppUsesNonExemptEncryption: false`.

---

## The part the MCP cannot do

The App Store Connect MCP available in this session exposes `apps_*` (metadata), `beta_*`,
`builds_*`, `build_uploads_*` and `export_compliance_*`. It has **no `apps_create` and no
`provisioning_*`**. Registering an App ID and creating an app record are both portal actions,
so they are yours. Everything after them is mine.

### 1. Register two App IDs

developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → **+** → App IDs → App

| Bundle ID | Description | Capability |
|---|---|---|
| `com.matthewpark.quokka` | Quokka | **App Groups** |
| `com.matthewpark.quokka.share` | Quokka Share | **App Groups** |

Then on each, App Groups → Configure → **`group.com.matthewpark.quokka`** (create it on the
first one, tick it on the second).

**Both must be in the same group.** If they are not, the share extension writes into a
container the app cannot read and every save vanishes silently — with no error anywhere.

### 2. Create the app record

appstoreconnect.apple.com → Apps → **+** → New App

| Field | Value |
|---|---|
| Platforms | iOS |
| Name | Quokka |
| Primary language | English (U.S.) |
| Bundle ID | `com.matthewpark.quokka` |
| SKU | `quokka-001` |
| User Access | Full Access |

That is it. Tell me when both are done.

---

## What I do from there

1. `apps_update_metadata` — set **`contentRightsDeclaration: USES_THIRD_PARTY_CONTENT`**.
   Honest: the library is other people's posts. Two other HMU apps already declare it.
2. `beta_app_update_localization` — TestFlight description, feedback email, what to test.
3. `beta_app_update_review_details` — the review notes below.
4. `export_compliance_*` — the HTTPS-only exemption.
5. `build_uploads_*` — upload the archive from `scripts/testflight.sh`.
6. `beta_groups_create` — an external group; `beta_testers_*` to add people.
7. `beta_app_submit_for_review` — Beta App Review, **2–7 days in 2026**, and builds with AI
   features sit longer in the queue.
8. `builds_get_processing_state` and `beta_app_get_submission` read back afterwards, rather
   than assuming the upload landed.

---

## Review notes, ready to paste

> Quokka is a place to keep short videos you saved and turn them into notes.
>
> **Transcription runs on the user's device**, using Apple's `SpeechAnalyzer`. There are three
> sources, tried in order: a video file the user shares from Photos; a video the creator has
> explicitly enabled downloads for; or the audio of a public post, read on device and
> **discarded immediately**. Nothing is ever saved to the device's library, offered as a
> download, re-hosted, or re-published. Quokka has no media library of its own and hosts
> nothing.
>
> Quokka also imports a file the user downloads from Meta's own "Download Your Information"
> service. It never signs in to Instagram, never automates an account, never asks for
> Instagram credentials, and makes no authenticated request to Instagram. The user unzips the
> file themselves in the Files app and picks the folder.
>
> The app has no accounts, no analytics and no advertising, and collects no data.

---

## App Privacy

**Data Not Collected** — and true for this build. Rungs 0–2 send nothing to any server Quokka
runs, and rung 3 ships disabled in `backend/worker/src/config.ts`.

> **Enabling the `hosted` rung and updating this declaration are one task, not two.** The
> moment that rung is on, a post URL reaches a server we run, and the answer changes.

---

## Before calling it done

`~/.claude/rules/10-launch-checklist.md`, all twenty, each done or n/a with a reason. Then the
`ios-app-store-readiness` skill for the Apple-specific half.
