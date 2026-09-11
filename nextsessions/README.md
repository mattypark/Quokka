# Next sessions

Two sessions run in parallel on Quokka. Open a terminal for each, paste the matching prompt,
and leave them in their lanes.

| | Owns | Prompt |
|---|---|---|
| **Frontend** | Screens, components, design tokens, the website | [`FRONTEND-PROMPT.md`](FRONTEND-PROMPT.md) |
| **Backend** | Engine, store, fetchers, MCP, Apple | [`BACKEND-PROMPT.md`](BACKEND-PROMPT.md) |

Full detail is in [`../docs/SESSION-FRONTEND.md`](../docs/SESSION-FRONTEND.md) and
[`../docs/SESSION-BACKEND.md`](../docs/SESSION-BACKEND.md). The prompts point at those, so the
rules stay in one place rather than being duplicated into a prompt that then drifts.

## Why this split

The line is drawn where two sessions would otherwise collide. Frontend owns everything a
person looks at; backend owns the rules, the data, and Apple. Neither reaches into the other.

A screen that needs a number which does not exist — a new metric, a different grouping —
**asks the backend session for it** rather than computing it in a view. Logic in `QuokkaEngine`
is pure and provable in a second; logic in a view can only be eyeballed in a simulator.

## Before you paste

- Both sessions commit after every change and **never push unless asked**.
- The backend session is connected to a **live commercial Apple account**. Its prompt carries
  hard limits; do not loosen them when editing.
- Update the "current state" line in each prompt when it goes stale.
