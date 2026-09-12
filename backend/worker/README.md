# quokka worker

Three endpoints, no database, no accounts.

| | |
|---|---|
| `GET /config` | The resolver rules and which rungs are live. **The only endpoint the app needs for rungs 0–2.** |
| `POST /transcript` | Rung 3. Proxies a hosted provider, holding the key. |
| `POST /extract` | A transcript becomes a title and a hook. |

## Why this exists at all

Quokka has no server by design — see `docs/DECISIONS.md`. This is not that server. It stores
nothing, knows no users, and the app works without it.

It exists for one reason: **`src/config.ts` describes someone else's web page.** Instagram and
TikTok change theirs without notice, and a rule compiled into the binary makes every one of
those changes three days of App Review for a regex. Here it is a deploy.

It is also the kill switch. Drop a rung from `enabledRungs` and it is off on every device
within the refresh window, with nothing shipped.

## Deploying

```sh
npm install          # not run automatically -- ask first
npx wrangler deploy
```

Then put the host — **host only, no scheme** — in `ios/Quokka/Secrets.xcconfig`:

```
QUOKKA_WORKER_HOST = quokka.your-subdomain.workers.dev
```

A `//` starts a comment in an xcconfig, so a full URL silently truncates to `https:` and the
failure looks like a dead worker.

## Secrets

```sh
npx wrangler secret put TRANSCRIPT_API_KEY    # optional -- rung 3
npx wrangler secret put ANTHROPIC_API_KEY     # optional -- /extract
```

Both optional. With `TRANSCRIPT_API_KEY` unset, `/config` strips the `hosted` rung and
`/transcript` returns 503 — advertising a rung the worker cannot serve would have every device
try it, fail, and report what looks like a provider outage.

## Turning rung 3 on

Enabling `hosted` is the same moment Quokka's App Privacy declaration stops being
**Data Not Collected**, because a post URL then reaches a server we run. Those are one change,
not two. Do not flip the rung without updating the declaration in App Store Connect.

## What the config says today

| Platform | Strategy | Why |
|---|---|---|
| Instagram | `webView` | `/embed/captioned/` returns a byte-identical ~623 KB app shell for a real shortcode and an invented one. Nothing to match. |
| TikTok | `webView` | The video page returns `statusMsg: "item doesn't exist"` unauthenticated; profile pages carry no video ids in markup. |
| Reddit | `htmlPattern` | Still serves real markup, so the cheap path works — no web process, no render. |

All three measured 2026-09-11. When one breaks, the fix is this file and a deploy.
