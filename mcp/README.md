# quokka-mcp

Your Quokka library, readable by Claude Code. **No API key, no per-save cost** — it runs on the
Claude Code subscription already on your Mac.

```
iPhone                                    Mac
  Quokka ──writes──> library.jsonl ──reads──> quokka-mcp ──> Claude Code
  Quokka <──reads─── tags.jsonl    <─writes──┘
```

## Setup

1. In Quokka: **Settings → Let Claude read your library**.
2. On your Mac:

```sh
claude mcp add quokka -- node ~/Downloads/current-projects/appscurrent/quokka/mcp/index.mjs
```

That's it. No install step — the server has **zero dependencies**.

## Then ask

> what did I save about lighting?
>
> show me everything from kitchen.studio
>
> go through my untagged Instagram saves and tag them

Tags are appended to `tags.jsonl` and applied by Quokka on its next launch.

## Where it looks

In order, first hit wins:

1. `$QUOKKA_DIR`
2. `~/Library/Mobile Documents/iCloud~com~matthewpark~quokka/Documents`
3. `~/Library/Mobile Documents/com~apple~CloudDocs/Quokka`
4. `~/Downloads/Quokka`

If the iCloud entitlement is not set up on the App ID yet, Quokka writes the mirror to its own
Documents folder instead — visible in **Files → On My iPhone → Quokka**. AirDrop it to
`~/Downloads/Quokka` and everything below works unchanged.

## Tools

| Tool | Does |
|---|---|
| `quokka_search` | Free text over author, caption, tags, platform, URL |
| `quokka_list_untagged` | Untagged items, oldest first, for working a backlog |
| `quokka_tag_item` | Writes tags for one item |
| `quokka_stats` | Counts by platform, origin, author and tag |

## Notes

Read-only against `library.jsonl` — the app owns that file and this server never writes it.
One writer per file, always.

A missing or half-synced library is normal rather than an error: bad lines are skipped, and an
absent file returns instructions instead of a stack trace.
