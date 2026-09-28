// node --test extension/test
import { test } from "node:test";
import assert from "node:assert/strict";
import { buildRecord, enqueue, hostOf, isWebURL, LIMITS, QUEUE_CAP, remove } from "../lib/record.js";

const now = new Date("2026-09-28T12:00:00.000Z");
const fixed = { now, id: "abc-123" };
const tab = { url: "https://example.com/post", title: "  A post  " };

test("an image right-click keeps the image and the page it was on", () => {
  const record = buildRecord(
    { mediaType: "image", srcUrl: "https://cdn.example.com/a.jpg", pageUrl: "https://example.com/post" },
    tab,
    fixed,
  );
  assert.equal(record.kind, "image");
  assert.equal(record.srcURL, "https://cdn.example.com/a.jpg");
  assert.equal(record.rawURL, "https://example.com/post");
  assert.equal(record.pageTitle, "A post");
  assert.equal(record.id, "ABC-123");
  assert.equal(record.receivedAt, "2026-09-28T12:00:00.000Z");
});

test("an image with a data: src saves the page instead of failing", () => {
  const record = buildRecord(
    { mediaType: "image", srcUrl: "data:image/png;base64,AAAA", pageUrl: "https://example.com/post" },
    tab,
    fixed,
  );
  assert.equal(record.kind, "page");
  assert.equal(record.srcURL, null);
  assert.equal(record.rawURL, "https://example.com/post");
});

test("a link right-click saves the link, not the page", () => {
  const record = buildRecord({ linkUrl: "https://youtube.com/watch?v=x", pageUrl: tab.url }, tab, fixed);
  assert.equal(record.kind, "link");
  assert.equal(record.rawURL, "https://youtube.com/watch?v=x");
  assert.equal(record.pageURL, tab.url);
});

test("selected text is trimmed and kept with its page", () => {
  const record = buildRecord({ selectionText: "  key light  ", pageUrl: tab.url }, tab, fixed);
  assert.equal(record.kind, "text");
  assert.equal(record.rawText, "key light");
  assert.equal(record.rawURL, tab.url);
});

test("long selections are cut to the limit", () => {
  const record = buildRecord({ selectionText: "x".repeat(LIMITS.text + 50), pageUrl: tab.url }, tab, fixed);
  assert.equal(record.rawText.length, LIMITS.text);
  assert.ok(record.rawText.endsWith("…"));
});

test("pages a phone cannot open give nothing to save", () => {
  assert.equal(buildRecord({ pageUrl: "chrome://extensions" }, { url: "chrome://extensions" }, fixed), null);
  assert.equal(buildRecord({ pageUrl: "file:///Users/me/a.html" }, {}, fixed), null);
});

test("javascript: and oversized URLs are refused", () => {
  assert.equal(isWebURL("javascript:alert(1)"), false);
  assert.equal(isWebURL(`https://example.com/${"a".repeat(LIMITS.url)}`), false);
  assert.equal(isWebURL("https://example.com"), true);
  assert.equal(isWebURL(undefined), false);
});

test("saving the same thing twice moves it to the top instead of duplicating it", () => {
  const first = buildRecord({ linkUrl: "https://a.com/1", pageUrl: tab.url }, tab, { now, id: "one" });
  const second = buildRecord({ linkUrl: "https://a.com/2", pageUrl: tab.url }, tab, { now, id: "two" });
  const again = buildRecord({ linkUrl: "https://a.com/1", pageUrl: tab.url }, tab, { now, id: "three" });

  let state = enqueue([], first);
  state = enqueue(state.queue, second);
  assert.equal(state.duplicate, false);
  state = enqueue(state.queue, again);
  assert.equal(state.duplicate, true);
  assert.deepEqual(state.queue.map((r) => r.id), ["THREE", "TWO"]);
});

test("the queue never grows past its cap, dropping the oldest", () => {
  const queue = Array.from({ length: QUEUE_CAP }, (_, i) => ({ id: `R${i}`, rawURL: `https://a.com/${i}`, srcURL: null, rawText: null }));
  const record = buildRecord({ linkUrl: "https://a.com/new", pageUrl: tab.url }, tab, fixed);
  const { queue: next } = enqueue(queue, record);
  assert.equal(next.length, QUEUE_CAP);
  assert.equal(next[0].id, "ABC-123");
  assert.equal(next.at(-1).id, `R${QUEUE_CAP - 2}`);
});

test("enqueue and remove never mutate what they were given", () => {
  const queue = Object.freeze([Object.freeze({ id: "A", rawURL: "https://a.com", srcURL: null, rawText: null })]);
  const record = buildRecord({ linkUrl: "https://b.com", pageUrl: tab.url }, tab, fixed);
  assert.doesNotThrow(() => enqueue(queue, record));
  assert.deepEqual(remove(queue, "A"), []);
  assert.equal(queue.length, 1);
});

test("hostOf drops www. and survives garbage", () => {
  assert.equal(hostOf("https://www.instagram.com/p/x"), "instagram.com");
  assert.equal(hostOf("not a url"), "");
});
