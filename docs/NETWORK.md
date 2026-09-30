# Making Quokka a network

How Pinterest, Instagram and TikTok are always full, and what it would take for Quokka to work
that way. Written 2026-09-30. Not built -- this is the plan and the price.

**Cloudflare is not the obstacle.** The worker is live, and storing everyone's saves on R2 would
cost about a dollar a month at a thousand users. What a network costs is accounts, moderation,
copyright handling and the empty-room problem at launch. Those are product decisions, not hosting.

---

## 1. How they actually work

Every one of them is the same four pieces:

| Piece | What it is | Pinterest | Instagram / TikTok |
|---|---|---|---|
| **Content** | Things people post or save, copied onto the company's own storage and CDN | Pins: an image saved from the web, re-hosted at several sizes | Photos and videos uploaded by their makers |
| **Graph** | Who follows whom, what is in which board, who saved what | Boards, follows, re-pins | Follows, likes, shares |
| **Feed** | A ranked list built from content + graph | "For You" -- visual similarity over the pin graph (PinSage) | Following + For You -- engagement-ranked |
| **Safety** | Reporting, blocking, scanning, takedowns, a team that acts on them | All of it | All of it |

**Why they are always full:** your feed is other people's content. A single-user app can only
ever show you what *you* saved; a network shows you what everyone saved.

## 2. Quokka's version

Quokka would not be a place to upload your own videos. It would be a place where **what you
save and break down is public if you choose**, the way Cosmos and Pinterest work -- and every
public save links back to the original post.

**What gets shared:** the save's picture (the 600px thumbnail Quokka already stores on the
phone), its title and creator, the link to the original, and optionally its breakdown. Never the
video file -- Quokka never keeps one.

### Data model

| Table | Holds |
|---|---|
| `profiles` | Handle, name, picture. One per Apple ID |
| `posts` | A public save: owner, source URL, platform, image key, title, creator, breakdown summary |
| `boards` | A public playlist: owner, name, cover |
| `board_posts` | Which posts are in which board |
| `follows` | Follower → followed |
| `saves` | Someone re-saving someone else's post (the "re-pin") -- the strongest signal there is |
| `reports`, `blocks` | Safety |

### Feeds, in the order they would be built

1. **Following** -- posts from people you follow, newest first. Built on read (one query), which
   is fine to tens of thousands of users. Instagram moved to building timelines on write only at a
   scale Quokka will not see for years.
2. **For You v1** -- recent public posts ranked by how many people re-saved them. No machine
   learning; honest and good enough to start.
3. **For You v2** -- "more like this": an image embedding (CLIP) per post, nearest neighbours by
   vector search. This is what Cosmos's "search by image" is.
4. **For You v3** -- your own signals: what you open, save and break down.

## 3. The stack

| Option | Good at | Weak at |
|---|---|---|
| **Supabase** (Postgres + Auth + Storage + pgvector) | Sign in with Apple built in, row-level security, the graph and feeds are plain SQL joins, vector search in the same database | One more vendor next to Cloudflare |
| **All Cloudflare** (Worker + D1 + R2 + Vectorize) | Everything next to the worker that already exists; R2 has no egress fees | Auth is yours to build; D1 is SQLite with one writer and a 10 GB database |
| Firebase (Firestore) | Excellent iOS SDK, realtime | A feed is a join, and Firestore does not join |

**Recommendation: Supabase for accounts, graph and feeds; keep the Cloudflare worker for what it
already does** (the transcript config). A social graph is relational, pgvector gives "more like
this" without another service, and building auth on a Worker is weeks of work Supabase has
already done. Images can start in Supabase Storage and move to R2 if bandwidth ever costs.

## 4. What has to exist before it ships

| Requirement | Why | Rough effort |
|---|---|---|
| **Report, block, filter** | App Store guideline 1.2: any app showing other users' content must have them, plus a way to act on a report within 24 hours | Days |
| **Image scanning** | Showing user-supplied images means scanning for child abuse material and reporting what is found; Cloudflare's CSAM Scanning Tool is free | A day to wire |
| **DMCA agent + takedown flow** | Public re-hosted images from other sites; registering an agent with the US Copyright Office is $6 | A day, plus doing takedowns when they come |
| **Account deletion in the app** | Guideline 5.1.1(v) | A day |
| **Privacy label + policy rewrite** | "Data Not Collected" stops being true | A day |
| **Age rating review** | User-generated content raises it | Minutes |

## 5. The empty room

A network with ten people in it is emptier than your own library. How the big ones solved it,
and what Quokka would do:

- **Pinterest** launched invite-only and hand-seeded boards. → Quokka: **starter walls** --
  a few curated public boards by topic (hooks that work, lighting, editing) visible on day one.
- **Cosmos** made import the first thing you do. → Quokka already has it: a pasted Pinterest board
  or Are.na channel, and the Instagram export.
- **TikTok** did not need your friends -- For You worked from the first swipe. → Quokka:
  **Discover**, trending YouTube through the worker, is For You before there is anyone to follow.

## 6. Phases

| Phase | Ships | Needs |
|---|---|---|
| **0 -- Discover** | Trending videos on the wall, every one breakdown-able | A YouTube Data API key on the worker. No accounts |
| **1 -- Public walls** | Sign in, make a board public, share a link to it that opens on the web | Supabase, report/block, scanning, policy |
| **2 -- Following** | Follow people; a Following feed | Phase 1 |
| **3 -- For You** | Ranked by re-saves, then by image similarity | Phase 2 and enough public posts to rank |

**Start with phase 0.** It makes the app feel full without any of section 4, and it tests the
real question -- do people want to break down videos they did not save themselves -- before
paying for a network.
