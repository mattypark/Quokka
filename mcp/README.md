# allim-mcp

Your Allim library, readable by Claude Code. **No API key, no per-save cost** — it runs on the
Claude Code subscription already on your Mac.

```
iPhone                                    Mac
  Allim ──writes──> library.jsonl ──reads──> allim-mcp ──> Claude Code
  Allim <──reads─── tags.jsonl    <─writes──┘
```

## Setup

1. In Allim: **Settings → Let Claude read your library**.
2. On your Mac:

```sh
claude mcp add allim -- node ~/Downloads/current-projects/appscurrent/allim/mcp/index.mjs
```

That's it. No install step — the server has **zero dependencies**.

## Then ask

> what did I save about lighting?
>
> show me everything from kitchen.studio
>
> go through my untagged Instagram saves and tag them

Tags are appended to `tags.jsonl` and applied by Allim on its next launch.

## Where it looks

In order, first hit wins:

1. `$ALLIM_DIR`
2. `~/Library/Mobile Documents/iCloud~com~matthewpark~allim/Documents`
3. `~/Library/Mobile Documents/com~apple~CloudDocs/Allim`
4. `~/Downloads/Allim`

If the iCloud entitlement is not set up on the App ID yet, Allim writes the mirror to its own
Documents folder instead — visible in **Files → On My iPhone → Allim**. AirDrop it to
`~/Downloads/Allim` and everything below works unchanged.

## Tools

| Tool | Does |
|---|---|
| `allim_search` | Free text over author, caption, tags, platform, URL |
| `allim_list_untagged` | Untagged items, oldest first, for working a backlog |
| `allim_tag_item` | Writes tags for one item |
| `allim_stats` | Counts by platform, origin, author and tag |

## Notes

Read-only against `library.jsonl` — the app owns that file and this server never writes it.
One writer per file, always.

A missing or half-synced library is normal rather than an error: bad lines are skipped, and an
absent file returns instructions instead of a stack trace.
