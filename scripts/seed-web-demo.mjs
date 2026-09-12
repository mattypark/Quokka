#!/usr/bin/env node
// Seeds the library for the marketing site's screen recordings.
//
// Deliberately NOT seed-inbox.mjs. That fixture leans on real YouTube ids because their
// thumbnails derive from the id alone, which makes it the only reliable way to see real
// images in a local run -- and it is exactly why it cannot be filmed for a public page. Those
// images are other people's cover art, and a marketing site is publication.
//
// So every link here is on a platform that serves nothing to an unauthenticated client:
// Instagram, Pinterest, X, Threads, TikTok, Cosmos. Each one lands as `.unavailable` and
// renders the app's own fallback tile -- a handle and a title set in a serif, on paper. That
// is not a degraded state standing in for a picture. It is the design, and it is the payoff of
// an app that committed to black and white: the case where there is no image is on brand.
//
// The handles and titles below are invented.
import { mkdirSync, writeFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { join } from "node:path";

const dir = process.argv[2];
if (!dir) {
  console.error("usage: seed-web-demo.mjs <inbox-dir>");
  process.exit(1);
}
mkdirSync(dir, { recursive: true });

const samples = [
  "https://www.instagram.com/thequietedit/reel/CqAa11bBcCd/",
  "https://www.instagram.com/paper.and.salt/reel/CqBb22cCdDe/",
  "https://www.instagram.com/ninetysecondfilm/reel/CqCc33dDeEf/",
  "https://www.instagram.com/slow.mornings.co/reel/CqDd44eEfFg/",
  "https://www.tiktok.com/@hookwriting/video/7300000000000000001",
  "https://www.tiktok.com/@thecutroom/video/7300000000000000002",
  "https://www.tiktok.com/@filmgrainclub/video/7300000000000000003",
  "https://www.pinterest.com/kitchenlightnotes/pin/9900000001/",
  "https://www.pinterest.com/studiofloorplans/pin/9900000002/",
  "https://x.com/onesentenceedit/status/1800000000000000001",
  "https://x.com/draftsandhooks/status/1800000000000000002",
  "https://www.threads.net/@theshotlist/post/CqEe55fFgGh",
  "https://www.threads.net/@brandvoicediary/post/CqFf66gGhHi",
  "https://www.cosmos.so/e/9001",
  "https://www.cosmos.so/e/9002",
].map((url) => ({ url, types: ["public.url"] }));

const base = Date.now();
samples.forEach((sample, index) => {
  const id = randomUUID().toUpperCase();
  // Fractional seconds on purpose: the format keeps millisecond precision so a burst of
  // saves does not collapse onto one instant.
  const receivedAt = new Date(base + index * 40).toISOString();
  writeFileSync(
    join(dir, `${id}.json`),
    JSON.stringify(
      {
        id,
        receivedAt,
        rawURL: sample.url,
        rawText: null,
        imageFilename: null,
        probe: [{ index: 0, typeIdentifiers: sample.types }],
      },
      null,
      2
    )
  );
});

console.log(`seeded ${samples.length} web-demo records into ${dir}`);
