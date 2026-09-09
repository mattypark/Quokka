#!/usr/bin/env node
// Builds a synthetic Instagram "Download Your Information" export, shaped like the real one,
// so the importer can be verified without touching anyone's actual data.
//
// Deliberately includes the two things that make the real format awkward: millisecond
// timestamps, and text that has been UTF-8 encoded and then escaped byte-by-byte as Latin-1
// (Meta's mojibake). It also seeds the same reel into all three sources, so deduplication is
// exercised rather than assumed.
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const root = process.argv[2];
if (!root) {
  console.error("usage: seed-export.mjs <output-dir>");
  process.exit(1);
}

const activity = join(root, "your_instagram_activity");
const inbox = join(activity, "messages", "inbox");

// Latin-1-escaped UTF-8, exactly as Meta writes it. Built from char codes so the literal
// bytes stay visible here rather than being pasted as invisible control characters.
// Decodes to "cafe<acute> <sparkling heart>" only after repairEncoding runs.
const mojibake =
  "caf" + String.fromCharCode(0xc3, 0xa9) +
  " " + String.fromCharCode(0xf0, 0x9f, 0x92, 0x96);

const shared = (code, owner, text, ms) => ({
  sender_name: "matthew",
  timestamp_ms: ms,
  share: {
    link: `https://www.instagram.com/reel/${code}/`,
    original_content_owner: owner,
    share_text: text,
  },
});

const base = 1_700_000_000_000;

// The target thread: the alt account reels actually get sent to.
const altThread = join(inbox, "myotheraccount_17841400000000000");
mkdirSync(altThread, { recursive: true });
writeFileSync(
  join(altThread, "message_1.json"),
  JSON.stringify({
    participants: [{ name: "matthew" }, { name: "my.other.account" }],
    title: "my.other.account",
    thread_path: "inbox/myotheraccount_17841400000000000",
    messages: [
      shared("C8xYzAbCdEf", "kitchen.studio", "the lighting in this", base),
      shared("D1aBcDeFgHi", "type.daily", mojibake, base + 60_000),
      shared("D2xKlMnOpQr", "motion.ref", "camera move", base + 120_000),
      shared("D3aaaaaaaaa", "brutal.arch", null, base + 180_000),
      { sender_name: "matthew", timestamp_ms: base + 240_000, content: "no link in this one" },
      // The same reel sent twice. People do this, and it must not double up.
      shared("C8xYzAbCdEf", "kitchen.studio", "still thinking about this", base + 300_000),
    ],
  }, null, 2),
);

// A second conversation, so the picker has something to choose between and the account
// filter has something to exclude.
const otherThread = join(inbox, "someonelse_17841400000000001");
mkdirSync(otherThread, { recursive: true });
writeFileSync(
  join(otherThread, "message_1.json"),
  JSON.stringify({
    participants: [{ name: "matthew" }, { name: "someone.else" }],
    title: "someone.else",
    messages: [shared("E9zzzzzzzzz", "unrelated.acct", "haha", base + 400_000)],
  }, null, 2),
);

// Saved: one overlaps the DM thread, one is new.
const saved = join(activity, "saved");
mkdirSync(saved, { recursive: true });
writeFileSync(
  join(saved, "saved_posts.json"),
  JSON.stringify({
    saved_saved_media: [
      {
        title: "kitchen.studio",
        string_map_data: {
          "Saved on": { href: "https://www.instagram.com/p/C8xYzAbCdEf/", timestamp: 1_700_009_000 },
        },
      },
      {
        title: "paper.goods",
        string_map_data: {
          "Saved on": { href: "https://www.instagram.com/p/F4newSavedAa/", timestamp: 1_700_010_000 },
        },
      },
    ],
  }, null, 2),
);

// Liked: one overlaps again, one is new.
const likes = join(activity, "likes");
mkdirSync(likes, { recursive: true });
writeFileSync(
  join(likes, "liked_posts.json"),
  JSON.stringify({
    likes_media_likes: [
      {
        title: "type.daily",
        string_list_data: [{ href: "https://www.instagram.com/reel/D1aBcDeFgHi/", timestamp: 1_700_011_000 }],
      },
      {
        title: "grid.systems",
        string_list_data: [{ href: "https://www.instagram.com/p/G5newLikedBb/", timestamp: 1_700_012_000 }],
      },
    ],
  }, null, 2),
);

console.log(`seeded a synthetic export at ${root}`);
console.log("  thread 'my.other.account': 6 messages, 5 shares, 4 unique reels");
console.log("  thread 'someone.else':     1 share");
console.log("  saved: 2 (1 overlaps)   liked: 2 (1 overlaps)");
console.log("  expected after import of the alt thread + saved + liked: 6 unique items");
