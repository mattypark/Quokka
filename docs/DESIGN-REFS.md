# Design reference — Cosmos

Quokka's interface copies the layout and interaction of [Cosmos](https://www.cosmos.so) as
closely as it can, on Matthew's call (2026-09-28): the app is a creative-direction library,
and Cosmos is the best-made one. What is copied is **structure** — screen anatomy, spacing,
type sizes, the way chrome floats. What is **not** copied: the dots logo, the ABC Oracle
typeface (a paid Dinamo licence; SF Pro stands in), any Cosmos image, and any Cosmos copy.

Measured, not eyeballed. Desktop values are computed styles read from cosmos.so in a
logged-in browser. Phone values are measured off Cosmos's seven App Store screenshots,
where the phone frame is 466px wide for a 393pt screen — **1.186px per point**. The
screenshots are kept out of this public repo, in `~/Documents/Reference images/cosmos/`.

---

## Tokens

| Token | Cosmos | Quokka |
|---|---|---|
| Ground | `#FFFFFF` | `Surface.canvas` |
| Primary text | lab(3.6) ≈ `#0A0A0A` | `Label.primary` |
| Inactive text | lab(45) ≈ `#6B6B6B` | `Label.secondary` |
| Field fill (search pill) | lab(98.7) ≈ `#FBFAF8` | `Surface.field` |
| Pill hairline | 0.5px black @ 10–12% | `Surface.hairline` / `Surface.hairlineStrong` |
| Face | cosmosOracle (ABC Oracle) | SF Pro |
| Nav | 15 / 500 / −0.28 | `Type.nav` |
| Body | 16 / 400 / 24 line | `Type.body` |
| Search placeholder | 14 / 400 / −0.28 | `Type.field` |
| Grid tile radius | 0 desktop, ~2pt phone | `Radius.tile` = 2 |
| Cluster card radius | ~18pt | `Radius.cover` = 18 |
| Grid gutter (phone) | 15px ≈ **12pt** | `Grid.gutter` = `Space.base` |
| Grid margin (phone) | 14px ≈ **12pt** | `Grid.margin` = `Space.base` |

The 12pt gutter lands exactly on the existing `Space.base` step, so the spacing scale did
not have to change.

## Screens

### Home (screenshot 05)
- Top bar, three slots: mark on the left, **text tabs centered** ("For You" inactive grey,
  "Following" black, both 15 medium), a bolt icon on the right. No title, no subtitle.
- Two-column masonry at native aspect ratio, directly under the bar.

### Tab bar (screenshot 03)
- A **small** floating white pill, ~155 × 44pt, centered, soft shadow. Three glyphs only:
  home (filled when active), search, and the person's avatar as a 22pt circle.
- Not full width. It reads as an object resting on the grid, not a bar across it.

### Profile (screenshot 03)
- Avatar 56pt, name 20 medium, `@handle` 16 grey, bio 16, link grey, a followers line with
  stacked 18pt avatars.
- A black **Follow** pill (~40pt tall, fills the row) beside 40pt hairline icon circles.
- Two tabs split the width: **Elements** with a small outlined count badge ("2.1K", 11pt),
  and **Clusters**. Active tab is black with a 2pt black underline across its half; a
  hairline runs under the whole row.
- Three-column masonry.

### Cluster (screenshot 07)
- 40pt grey-fill circles: back (top left), search (top right).
- Centered title 22 medium, then `@user · 229 elements · 🔒` in 15 grey, then collaborator
  avatars with a `+` circle.
- Two-column masonry.
- A floating white action pill, ~287 × 59pt: **Organize · Add · Share · More**, each an icon
  over a 12pt grey label.

### Search (screenshots 01, 02, 04)
- "Search Cosmos" pill: 56 tall, full radius, `#FBFAF8` fill, 0.5px hairline, an inset white
  highlight along the top edge; magnifier on the left, a colour wheel on the right.
- Landing: a horizontal row of **cluster cards** (square cover at 18pt radius, then a 32pt
  avatar, the cluster name 15 black and `@handle` 14 grey), then masonry.
- Colour search: the pill turns into a hex field with a swatch dot, and results are masonry.

### Element (desktop)
- The image at its own aspect ratio, a back circle, `…` on the right.
- "Saved by N others", then rows: 32pt thumb, cluster name, `N elements · @handle`.
- A cluster picker dropdown next to a black **Save** pill.
- "Similar elements" masonry underneath.

### Chrome extension
- Context menu item **Save to Cosmos** on images, links, selected text and the page.
- Pinned toolbar button saves the current page in one click.
- A hover button on Instagram posts.

## What Quokka maps it to

| Cosmos | Quokka |
|---|---|
| For You / Following | **Saved / Creators** |
| Bolt (activity) | **+** (import) |
| Elements / Clusters | **Saves / Playlists / Ideas** |
| Follow + social icons | **Import** + Instagram + settings circles |
| Saved by others | **In playlists** |
| Similar elements | **More from @author** |
| Save to Cosmos | **Save to Quokka** (`extension/`) |
