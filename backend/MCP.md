# quokka-mcp

The library, exposed to Claude Code. **No API key, no per-save cost** — it runs on the Claude
Code subscription already on the machine.

This is the answer to "I want it to connect to Claude almost like an MCP". It is not a
metaphor; it is an MCP server.

## Why this shape

An iOS app cannot hand a Mac process a SQLite file, and putting an Anthropic key on-device
would mean a key in the app bundle and a bill per save. Both are avoidable.

Instead the app mirrors its library to a JSONL file in its **iCloud Drive container**. On the
Mac that container is an ordinary folder, so a local Node process reads it directly. iCloud
does the syncing; nobody writes a server.

```
iPhone                              Mac
  Quokka ──writes──> library.jsonl ──reads──> quokka-mcp ──> Claude Code
  Quokka <──reads─── tags.jsonl   <──writes──┘
```

The payoff is bidirectional, and the second direction is the better one:

- Claude retags a 4,000-item Instagram backlog in bulk.
- **Matthew asks his terminal "what did I save about lighting?" and gets an answer out of his
  own library.**

## Files

`library.jsonl` — one item per line, written by the app, read-only to the server.

```json
{"id":41,"url":"https://www.instagram.com/p/C8xYzAbCdEf/","platform":"instagram",
 "author":"kitchen.studio","caption":"the lighting in this","savedAt":"2026-09-09T08:55:01.220Z",
 "tags":["kitchen","lighting"],"origin":"instagramDM"}
```

`tags.jsonl` — written by the server, ingested by the app on next launch.

```json
{"id":41,"tags":["warm lighting","kitchen","interiors"],"collection":"Interiors"}
```

JSONL rather than one JSON document on purpose: a 500,000-line file appends in constant time
and streams line by line, where a single array has to be parsed whole on both ends.

## Tools

| Tool | Does |
|---|---|
| `quokka_search` | Free-text over author, caption, tags, host. **The one Matthew will actually use.** |
| `quokka_list_untagged` | Items with no tags, oldest first, for bulk passes |
| `quokka_tag_item` | Writes tags for one id |
| `quokka_create_collection` | A named saved filter over tags |
| `quokka_stats` | Counts by platform, origin, author, tag |

## Rules

- **Read-only against `library.jsonl`.** The app owns that file. The server writes only
  `tags.jsonl`. One writer per file, always.
- **Never block on iCloud.** A file that has not synced yet is normal, not an error. Report
  what is there.
- Node, stdio transport, as few dependencies as the job allows.
- Registered with `claude mcp add quokka -- node /path/to/mcp/index.mjs`.

## The app's half

The frontend session has **not** built the mirror yet. It needs:

- A writer that appends to `library.jsonl` on insert and on tag change
- A reader that ingests `tags.jsonl` on launch and clears it after
- A Settings toggle, since a synced library is a privacy decision and belongs to the user

Coordinate before building — this one crosses the lane boundary in both directions.
