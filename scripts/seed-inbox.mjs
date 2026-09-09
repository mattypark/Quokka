#!/usr/bin/env node
// Writes sample records into the App Group inbox, in the exact shape the share extension
// produces. Used by `scripts/run.sh --seed` to exercise the drain path without driving
// another app's share sheet by hand.
import { mkdirSync, writeFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { join } from "node:path";

const dir = process.argv[2];
if (!dir) {
  console.error("usage: seed-inbox.mjs <inbox-dir>");
  process.exit(1);
}
mkdirSync(dir, { recursive: true });

// A mix chosen to exercise every path the grid has.
//
// The YouTube ids are real posts, and their thumbnails derive from the id alone, so they
// resolve without depending on any post lookup -- which makes them the only reliable way to
// see real images in a seeded run. Instagram, Pinterest and X are here to render the
// typographic fallback tile, which is their designed state rather than a failure. The
// fabricated TikTok and Reddit links exercise the failure path: a row reading FAILED there is
// the pipeline working.
const youtube = [
  "dQw4w9WgXcQ", "jNQXAC9IVRw", "9bZkp7q19f0", "kJQP7kW5RZs",
  "fJ9rUzIMcZQ", "OPf0YbXqDm0", "ZbZSe6N_BXs", "60ItHLz5WEA",
];

// Fallbacks first so they land oldest; the real YouTube thumbnails then sort to the top,
// where a screenshot of the first screen actually shows the grid doing its job.
const samples = [
  { url: "https://www.instagram.com/nasa/reel/C8xYzAbCdEf/?igshid=abc", types: ["public.url", "public.image"] },
  { url: "https://www.instagram.com/reel/D1aBcDeFgHi/", types: ["public.url"] },
  { url: "https://www.pinterest.com/pin/1234567890/", types: ["public.url"] },
  { url: "https://x.com/nasa/status/1234567890", types: ["public.url"] },
  { url: "https://www.tiktok.com/@nasa/video/7234567890123456789", types: ["public.url"] },
  { url: null, text: "Check this out https://vm.tiktok.com/ZMhqKvXYZ/ come watch", types: ["public.plain-text"] },
  { url: "https://www.reddit.com/r/design/comments/1abc234/some_slug/", types: ["public.url"] },
  ...youtube.map((id) => ({
    url: `https://www.youtube.com/watch?v=${id}`,
    types: ["public.url", "public.plain-text"],
  })),
];

const base = Date.now();
samples.forEach((sample, index) => {
  const id = randomUUID().toUpperCase();
  // Fractional seconds on purpose: the format keeps millisecond precision so a burst of
  // saves does not collapse onto one instant.
  const receivedAt = new Date(base + index * 40).toISOString().replace("Z", "Z");
  const record = {
    id,
    receivedAt,
    rawURL: sample.url,
    rawText: sample.text ?? null,
    imageFilename: null,
    probe: [{ index: 0, typeIdentifiers: sample.types }],
  };
  writeFileSync(join(dir, `${id}.json`), JSON.stringify(record, null, 2));
});

console.log(`seeded ${samples.length} inbox records into ${dir}`);
