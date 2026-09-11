# Timeline

Three phases, run by two sessions in parallel. Days are working days.

| Phase | Days | Owner | Ships |
|---|---|---|---|
| **1 — Website UI** | 1–3 | Frontend | `web/` — landing, waitlist, about, contact, privacy |
| **2 — Backend** | 3–6 | Backend | Analytics, `quokka-mcp`, waitlist API, collections engine |
| **3 — Apple** | 6–9 | Backend | Icon, screenshots, privacy manifest, review notes, submission |

The phases overlap on purpose. Backend starts on day 3 while the website is still being
finished, and Apple prep starts on day 6 while backend work is still landing — because App
Review's queue is the long pole and nothing else can shorten it.

## Phase 1 — Website (days 1–3)

Koino-inspired, in Quokka's own voice rather than a copy. Black on white, one display face,
photographic collage.

- **Day 1** — tokens shared with the app, hero, nav, footer. Wordmark treatment.
- **Day 2** — the three proof sections: save from anywhere, sorted for you, the numbers.
  Device mockups using real app screenshots, not placeholder art.
- **Day 3** — waitlist form (UI only; the endpoint is backend's), about, contact, privacy,
  responsive at 375 / 768 / 1440, both themes, Lighthouse pass.

## Phase 2 — Backend (days 3–6)

- **Day 3** — analytics fetchers. YouTube Data API v3 first, since it is the only one that
  is both official and complete.
- **Day 4** — `quokka-mcp`: the library exposed to Claude Code with no API key.
- **Day 5** — author-grouped collections, on-device tagging.
- **Day 6** — waitlist endpoint, deploy.

## Phase 3 — Apple (days 6–9)

- **Day 6** — app icon through `ip-as-logo`. Replace the personal-use display face (see
  DECISIONS.md) — **this is a submission blocker, not a nice-to-have.**
- **Day 7** — screenshots at every required size, privacy manifest, App Privacy answers,
  export compliance.
- **Day 8** — TestFlight build, internal test, `ios-app-store-readiness` pass, the 20-item
  launch checklist.
- **Day 9** — submit. Review notes must explain the Instagram import in plain terms: Quokka
  reads a file the user downloaded from Meta. It never signs in to Instagram, never automates
  an account, and never asks for Instagram credentials. Reviewers reject things that look
  like scrapers, and this one needs to be visibly not that.

## Known blockers, in the order they will bite

1. **Keep on Truckin is personal-use-only.** Ships as-is on a personal build; blocks
   TestFlight and the App Store. Swap is a one-line change.
2. **App Review turnaround** is 24h–7 days and cannot be compressed. Everything else bends
   around it.
3. **Instagram analytics do not exist** without auth. The UI has to be honest about that on
   day one rather than promising numbers it cannot produce.
