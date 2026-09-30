# Design — black, white and sky

**Current direction (2026-09-30).** Quokka takes someone else's video and shows what went well
in it — vidIQ-style, but on the phone. The look is about a third Nudgy's (a live-feeling sky
behind the header, big bold titles, white cards on paper) and the rest Quokka's own. It
replaces the Cosmos pass in [`DESIGN-REFS.md`](DESIGN-REFS.md), which is kept as history.

## The mark

Matthew's logo: a black square with two round eyes and a smile. The master is
`assets/logo/quokka-mark.png`; `QuokkaMark.swift` redraws it as vector shapes from measured
proportions, so it is sharp at 16pt and can blink.

| Part | Proportion of the side |
|---|---|
| Eyes | 13.3% across, centred at 24.95% and 74.75% across, 51.3% down |
| Smile | round-capped quadratic from 42.2% to 57.2% across at 59.6% down, dipping to 64.2%; stroke 6.27% |

It is the app icon (62% of a white canvas, as the master), the extension icons (full-bleed at
16–48px, where white margin would lose the face), the corner of the sky, the share-sheet
confirmation and every empty state. `scripts/render-icon.swift` renders all icon sizes.

## Tokens

| Role | Value | Contrast |
|---|---|---|
| Brand, primary text, tab bar | `#0A0A0A` | paper 18.4:1 |
| Page | `#F3F5F8` cool paper | — |
| Cards | `#FFFFFF` | — |
| Secondary text | `#5E6573` | paper 5.4:1 |
| Tertiary text | `#646B78` | paper 4.9:1 |
| Sky gradient | `#1560D4` → `#2A7FE3` → `#4E9DEB`, with an 18% shade low down | white on top 5.6:1 |
| Sky as ink: links, passed checks, primary button | `#1A66D1` | white 5.4:1, paper 5.0:1 |
| Sky tint: chips behind blue text | `#E7F1FD` | accent on it 4.8:1 |

Blue means *this part analyses*: the sky, a passed check, the button that does something to a
video. Black is the brand and everything else.

## Type

Two faces, Matthew's pick (2026-09-30): **Schoolbell** and **SF Pro**.

| Face | Where | Why |
|---|---|---|
| **Schoolbell** (Font Diner, Apache 2.0, bundled) | Screen titles (38), the onboarding headline (46), the date on the sky, empty-state lines, "What worked", playlist and creator titles, the share sheet's "Saved to Quokka", the extension popup's wordmark | The lines with a voice -- the mark talking, the way Nudgy's hand is Mushy talking |
| **SF Pro** | Everything read for information: transcripts, hooks as said, evidence, captions, controls -- and every number | Someone else's words have to read as exact, and a hand-drawn digit next to another reads as sloppy |

`Type.hand(size)` sets Schoolbell 12% larger than asked, because its x-height runs small beside
SF Pro, and relative to `.title` so it follows Dynamic Type. Never tracked tighter -- a hand face
collides. Body is 16 regular; section labels are 12 semibold, uppercase, tracked 1.1.

## Screens

| Screen | What is on it |
|---|---|
| **Home** | Sky header: the mark, the date, a gear; three rings (saved, transcribed, waiting); glass pills to paste a link or import. Then on paper: *Ready to break down* (hook + check dots), *Needs a transcript* (Transcribe button), *Recently saved* |
| **Library** | Bold title, search pill with a colour wheel, platform chips, the masonry grid |
| **Studio** | Playlists, Ideas (the planner and script editor), Creators |
| **Breakdown** (a video) | Hero card; tabs **Breakdown** (what worked: ring + seven checks with evidence; hook with timing and *Use this hook*; pace; beats; ending), **Transcript** (timed lines, search, share), **Save** (playlists, more from the creator) |
| **Tab bar** | A black capsule floating on the page; the open tab white with a sky dot |
| **Onboarding** | The whole page is sky: the blinking mark, one headline, three glass promises, a white pill |

## What stayed from the Cosmos pass

Pushed pages instead of sheets (`Route`), the masonry grid at native aspect ratio, search by
word and colour, the floating Organize / Add / Share / More pill on a playlist, and SF Pro as
the only face so far.
