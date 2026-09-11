# Backend

Owned by a separate session. See `../docs/SESSION-BACKEND.md` for the rules and
`../nextsessions/BACKEND-PROMPT.md` for the prompt to paste.

Nothing in here is built yet. This is the specification the backend session works from.

```
backend/
  README.md          this file
  ANALYTICS.md       per-platform metric coverage, and what is actually obtainable
  MCP.md             quokka-mcp -- the library exposed to Claude Code with no API key
  WAITLIST.md        the website's one endpoint
```

## The contract with the frontend

The frontend owns views. The backend owns everything a view asks a question of.

Backend delivers **`QuokkaEngine` types and `Services` that return them.** The frontend never
fetches, never parses, never derives a metric in a view. If a screen needs a number that does
not exist yet, it asks for it here rather than computing it inline — because logic in
`QuokkaEngine` is pure and runs under `swift test` in a second, and logic in a view can only
be eyeballed in a simulator.

**Do not change these without telling the frontend session.** They are load-bearing and
already have views built against them:

| Type | Where |
|---|---|
| `Item`, `Item.ThumbnailState`, `Item.Origin` | `QuokkaEngine/Item.swift` |
| `ItemPage`, `ItemCursor` | `QuokkaEngine/Item.swift` |
| `Platform`, `Platform.ThumbnailDurability` | `QuokkaEngine/Platform.swift` |
| `CanonicalLink`, `LinkCanonicaliser` | `QuokkaEngine/CanonicalLink.swift` |
| `InstagramExport.Share`, `.Thread` | `QuokkaEngine/InstagramExport.swift` |
| `QuokkaStore` public methods | `Quokka/Sources/Services/QuokkaStore.swift` |

Additive changes are free. Renames and removals are a conversation.
