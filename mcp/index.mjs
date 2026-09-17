#!/usr/bin/env node
// quokka-mcp — the Quokka library, exposed to Claude Code.
//
// No API key and no per-save cost: this runs on the Claude Code subscription already on the
// machine. It reads the JSONL mirror the iOS app writes and appends tags back for the app to
// pick up on its next launch.
//
// Zero dependencies on purpose. MCP over stdio is line-delimited JSON-RPC 2.0, which is about
// eighty lines of plumbing — less than the cost of a dependency tree that has to be audited
// and kept current for a tool that reads two local files.
//
//   claude mcp add quokka -- node /path/to/mcp/index.mjs
//
// Point it somewhere specific with QUOKKA_DIR; otherwise it looks in the app's iCloud container
// and then in a couple of obvious fallbacks.

import { readFileSync, appendFileSync, existsSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { createInterface } from "node:readline";

const CANDIDATES = [
  process.env.QUOKKA_DIR,
  join(homedir(), "Library/Mobile Documents/iCloud~com~matthewpark~quokka/Documents"),
  join(homedir(), "Library/Mobile Documents/com~apple~CloudDocs/Quokka"),
  join(homedir(), "Downloads/Quokka"),
].filter(Boolean);

function libraryDir() {
  for (const dir of CANDIDATES) {
    if (existsSync(join(dir, "library.jsonl"))) return dir;
  }
  return null;
}

/// Reads the mirror. Bad lines are skipped rather than fatal: the file is written by another
/// process and may be mid-sync, and one truncated line should not take the whole library down.
function readLibrary() {
  const dir = libraryDir();
  if (!dir) return { items: [], dir: null, error: `No library.jsonl found. Looked in:\n${CANDIDATES.map((c) => `  ${c}`).join("\n")}\n\nTurn on "Let Claude read your library" in Quokka's settings, or set QUOKKA_DIR.` };

  const path = join(dir, "library.jsonl");
  const items = [];
  for (const line of readFileSync(path, "utf8").split("\n")) {
    if (!line.trim()) continue;
    try {
      items.push(JSON.parse(line));
    } catch {
      // skip
    }
  }
  return { items, dir, error: null, updated: statSync(path).mtime.toISOString() };
}

/// Reads the playlists mirror. Absent is normal -- an app with no playlists writes no file.
function readPlaylists() {
  const dir = libraryDir();
  if (!dir) return [];
  const path = join(dir, "playlists.jsonl");
  if (!existsSync(path)) return [];
  const out = [];
  for (const line of readFileSync(path, "utf8").split("\n")) {
    if (!line.trim()) continue;
    try {
      out.push(JSON.parse(line));
    } catch {
      // skip, same reasoning as the library
    }
  }
  return out;
}

function tagList(item) {
  if (!item.tags) return [];
  try {
    return typeof item.tags === "string" ? JSON.parse(item.tags) : item.tags;
  } catch {
    return [];
  }
}

const TOOLS = [
  {
    name: "quokka_search",
    description:
      "Search the Quokka library by free text across author, caption, tags, platform and URL. This is the main way to ask questions of a saved library, e.g. 'lighting', 'kitchen', a creator's handle.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Free text. Matches author, caption, tags, platform, URL." },
        platform: { type: "string", description: "Optional filter: instagram, tiktok, youtube, pinterest, reddit, x." },
        limit: { type: "number", description: "Max results (default 40)." },
      },
      required: ["query"],
    },
  },
  {
    name: "quokka_list_untagged",
    description:
      "Items with no tags yet, oldest first. Use this to work through a backlog in batches, then call quokka_tag_item for each.",
    inputSchema: {
      type: "object",
      properties: { limit: { type: "number", description: "Max items (default 25)." } },
    },
  },
  {
    name: "quokka_tag_item",
    description:
      "Write tags for one item. Appends to tags.jsonl, which Quokka reads and clears on its next launch. Tags should be short, lowercase, and describe the subject rather than the platform.",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "number", description: "The item id from a search or listing." },
        tags: { type: "array", items: { type: "string" }, description: "Two to five short tags." },
      },
      required: ["id", "tags"],
    },
  },
  {
    name: "quokka_list_playlists",
    description:
      "List the playlists, with how many videos are in each and whether the summary is current. Start here when asked to summarise something.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "quokka_read_playlist",
    description:
      "Everything in one playlist: each video's author, title, caption and — where it has been transcribed — what was actually said. This is what you summarise from.",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "number", description: "Playlist id from quokka_list_playlists" },
      },
      required: ["id"],
    },
  },
  {
    name: "quokka_write_summary",
    description:
      "Write a summary back to a playlist. Quokka applies it on its next launch. Summarise only from quokka_read_playlist output — never invent content for a video with no transcript.",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "number", description: "Playlist id" },
        summary: { type: "string", description: "The digest. Plain text, no markdown headings." },
      },
      required: ["id", "summary"],
    },
  },
  {
    name: "quokka_stats",
    description: "Counts across the library: by platform, by origin, by author, and by tag.",
    inputSchema: { type: "object", properties: {} },
  },
];

function call(name, args = {}) {
  const { items, dir, error, updated } = readLibrary();
  if (error) return error;

  switch (name) {
    case "quokka_search": {
      const q = String(args.query || "").toLowerCase();
      const limit = args.limit ?? 40;
      let found = items.filter((item) => {
        if (args.platform && item.platform !== args.platform) return false;
        // The transcript is in the haystack deliberately. Captions are marketing and a
        // YouTube title is frequently the URL, so searching what was *said* is the difference
        // between finding "the reel called something about lighting" and finding "the reel
        // where someone explained three-point lighting".
        const hay = [item.author, item.caption, item.title, item.platform, item.url, item.transcript, ...tagList(item)]
          .filter(Boolean)
          .join(" ")
          .toLowerCase();
        return hay.includes(q);
      });
      found = found.slice(0, limit);
      if (!found.length) return `Nothing matched "${args.query}" in ${items.length} items.`;
      return [
        `${found.length} of ${items.length} items matched "${args.query}":`,
        "",
        ...found.map(
          (i) =>
            `[${i.id}] ${i.platform}${i.author ? ` · ${i.author}` : ""}\n     ${i.url}${i.caption ? `\n     "${i.caption}"` : ""}${tagList(i).length ? `\n     tags: ${tagList(i).join(", ")}` : ""}`,
        ),
      ].join("\n");
    }

    case "quokka_list_untagged": {
      const limit = args.limit ?? 25;
      const untagged = items.filter((i) => tagList(i).length === 0).slice(0, limit);
      if (!untagged.length) return `Everything is tagged (${items.length} items).`;
      return [
        `${untagged.length} untagged, of ${items.length} total:`,
        "",
        ...untagged.map(
          (i) => `[${i.id}] ${i.platform}${i.author ? ` · ${i.author}` : ""}${i.caption ? ` — "${i.caption}"` : ""}\n     ${i.url}`,
        ),
      ].join("\n");
    }

    case "quokka_tag_item": {
      if (!dir) return "No library directory.";
      const id = Number(args.id);
      const tags = (args.tags || []).map((t) => String(t).trim().toLowerCase()).filter(Boolean);
      if (!Number.isFinite(id) || !tags.length) return "Need an id and at least one tag.";
      appendFileSync(join(dir, "tags.jsonl"), JSON.stringify({ id, tags }) + "\n", "utf8");
      return `Tagged [${id}] with ${tags.join(", ")}. Quokka applies this on its next launch.`;
    }

    case "quokka_list_playlists": {
      const playlists = readPlaylists();
      if (!playlists.length) {
        return "No playlists yet. Make one in Quokka and add some saves to it.";
      }
      return playlists
          .map((p) => {
            const state = !p.summary
              ? "no summary"
              : p.summaryIsStale
                ? "summary is behind the contents"
                : "summarised";
            return `[${p.id}] ${p.name} — ${p.itemCount} video${p.itemCount === 1 ? "" : "s"}, ${state}`;
          })
          .join("\n");
    }

    case "quokka_read_playlist": {
      const playlists = readPlaylists();
      const playlist = playlists.find((p) => p.id === args.id);
      if (!playlist) return `No playlist ${args.id}. Run quokka_list_playlists.`;

      const { items, error } = readLibrary();
      if (error) return error;

      const byID = new Map(items.map((i) => [i.id, i]));
      const chosen = playlist.itemIDs.map((id) => byID.get(id)).filter(Boolean);

      // Said plainly, because it changes what an honest summary can claim. A playlist where
      // most videos have no transcript can only be summarised from captions and titles, and
      // the summary should say so rather than sounding equally confident about both.
      const withWords = chosen.filter((i) => i.transcript).length;
      const header =
        `${playlist.name} — ${chosen.length} video${chosen.length === 1 ? "" : "s"}, ` +
        `${withWords} transcribed.` +
        (withWords < chosen.length
          ? ` ${chosen.length - withWords} ${chosen.length - withWords === 1 ? "has" : "have"} no transcript: summarise those from title and caption only, and do not invent what was said in them.`
          : "");

      const body = chosen
        .map((i, n) => {
          const lines = [`--- ${n + 1}. ${i.author ?? "unknown"} — ${i.title ?? i.url}`];
          if (i.caption) lines.push(`caption: ${i.caption}`);
          lines.push(i.transcript ? `transcript: ${i.transcript}` : "transcript: (none)");
          return lines.join("\n");
        })
        .join("\n\n");

      return `${header}\n\n${body}`;
    }

    case "quokka_write_summary": {
      const dir = libraryDir();
      if (!dir) return "No library directory found.";
      const summary = String(args.summary ?? "").trim();
      if (!summary) return "Refusing to write an empty summary.";
      // Appended as a queue the app drains and deletes, exactly like tags.jsonl -- this file
      // is work that has been done, never a second source of truth competing with the database.
      appendFileSync(
        join(dir, "summaries.jsonl"),
        JSON.stringify({ playlistID: args.id, summary }) + "\n",
      );
      return `Queued a summary for playlist ${args.id}. Quokka applies it on next launch.`;
    }

    case "quokka_stats": {
      const tally = (key) => {
        const counts = new Map();
        for (const item of items) {
          const value = item[key];
          if (value) counts.set(value, (counts.get(value) || 0) + 1);
        }
        return [...counts.entries()].sort((a, b) => b[1] - a[1]);
      };
      const tags = new Map();
      for (const item of items) {
        for (const tag of tagList(item)) tags.set(tag, (tags.get(tag) || 0) + 1);
      }
      const show = (rows, n = 12) => rows.slice(0, n).map(([k, v]) => `  ${v}  ${k}`).join("\n") || "  (none)";
      return [
        `${items.length} items · mirror updated ${updated}`,
        "",
        "By platform:", show(tally("platform")),
        "",
        "By origin:", show(tally("origin")),
        "",
        "Top authors:", show(tally("author")),
        "",
        "Top tags:", show([...tags.entries()].sort((a, b) => b[1] - a[1])),
      ].join("\n");
    }

    default:
      return `Unknown tool: ${name}`;
  }
}

// ---- JSON-RPC over stdio -----------------------------------------------------------------

function send(message) {
  process.stdout.write(JSON.stringify(message) + "\n");
}

createInterface({ input: process.stdin }).on("line", (line) => {
  if (!line.trim()) return;

  let request;
  try {
    request = JSON.parse(line);
  } catch {
    return;
  }

  const { id, method, params } = request;
  // Notifications have no id and must never be answered.
  const reply = (result) => id !== undefined && send({ jsonrpc: "2.0", id, result });

  switch (method) {
    case "initialize":
      reply({
        protocolVersion: params?.protocolVersion ?? "2024-11-05",
        capabilities: { tools: {} },
        serverInfo: { name: "quokka", version: "0.1.0" },
      });
      break;

    case "tools/list":
      reply({ tools: TOOLS });
      break;

    case "tools/call":
      try {
        reply({ content: [{ type: "text", text: call(params?.name, params?.arguments) }] });
      } catch (error) {
        reply({ content: [{ type: "text", text: `Error: ${error.message}` }], isError: true });
      }
      break;

    default:
      // Unknown methods still need an answer, or the client waits forever.
      if (id !== undefined) send({ jsonrpc: "2.0", id, error: { code: -32601, message: `Unknown method: ${method}` } });
  }
});
