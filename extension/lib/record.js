// What one right-click becomes, and the queue it waits in.
//
// Pure functions with no chrome.* in them, so they run under `node --test` with nothing
// mocked. The record deliberately mirrors the share extension's ShareInboxRecord (id,
// receivedAt, rawURL, rawText) so that whichever sync path is chosen later only has to carry
// it -- the phone's inbox drain already knows what to do with that shape.

export const LIMITS = Object.freeze({
  url: 2048,
  text: 4000,
  title: 300,
});

/** Oldest saves fall off past this. Chrome's local storage quota is 10 MB. */
export const QUEUE_CAP = 5000;

/** Only http and https. data:, blob:, file: and chrome: URLs mean nothing on a phone. */
export function isWebURL(value) {
  if (typeof value !== "string" || value.length === 0 || value.length > LIMITS.url) {
    return false;
  }
  try {
    const { protocol } = new URL(value);
    return protocol === "http:" || protocol === "https:";
  } catch {
    return false;
  }
}

function webURLOrNull(value) {
  return isWebURL(value) ? value : null;
}

function truncate(value, limit) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (trimmed.length === 0) return null;
  return trimmed.length > limit ? `${trimmed.slice(0, limit - 1)}…` : trimmed;
}

/**
 * Builds a record from a context-menu click (or a synthetic one for "save this page").
 *
 * `info` is chrome.contextMenus.OnClickData: mediaType, srcUrl, linkUrl, pageUrl,
 * selectionText. `tab` supplies the title and a fallback URL. Returns null when there is
 * nothing a phone could use -- no web URL and no text.
 */
export function buildRecord(info, tab, { now = new Date(), id = crypto.randomUUID() } = {}) {
  const pageURL = webURLOrNull(info?.pageUrl) ?? webURLOrNull(tab?.url);
  const linkURL = webURLOrNull(info?.linkUrl);
  const mediaURL = webURLOrNull(info?.srcUrl);
  const text = truncate(info?.selectionText, LIMITS.text);

  // An image whose src is a data: or blob: URL has nothing to carry, so it falls through to
  // saving the page it was on rather than failing outright.
  let kind = "page";
  if (mediaURL && info?.mediaType === "image") kind = "image";
  else if (mediaURL && info?.mediaType === "video") kind = "video";
  else if (linkURL) kind = "link";
  else if (text) kind = "text";

  const rawURL = kind === "link" ? linkURL : pageURL;
  if (!rawURL && !text) return null;

  return {
    // Uppercased like Foundation's UUID().uuidString, so the id reads the same on both sides.
    id: id.toUpperCase(),
    receivedAt: now.toISOString(),
    kind,
    rawURL,
    rawText: text,
    srcURL: kind === "image" || kind === "video" ? mediaURL : null,
    pageURL,
    pageTitle: truncate(tab?.title, LIMITS.title),
    source: "chrome-extension",
  };
}

/** Two saves are the same thing when they point at the same link and the same picture. */
function sameThing(a, b) {
  return a.rawURL === b.rawURL && a.srcURL === b.srcURL && a.rawText === b.rawText;
}

/**
 * Adds a record to the front of the queue.
 *
 * Saving something twice moves it back to the top rather than adding a second copy -- the
 * same thing the phone's canonical-URL dedupe does. Returns a new array; the input is not
 * touched.
 */
export function enqueue(queue, record) {
  const existing = Array.isArray(queue) ? queue : [];
  const duplicate = existing.some((entry) => sameThing(entry, record));
  const rest = existing.filter((entry) => !sameThing(entry, record));
  return {
    queue: [record, ...rest].slice(0, QUEUE_CAP),
    duplicate,
  };
}

/** Removes one record by id. Returns a new array. */
export function remove(queue, id) {
  return (Array.isArray(queue) ? queue : []).filter((entry) => entry.id !== id);
}

/** The host, without www., for a caption under a link card. */
export function hostOf(value) {
  try {
    return new URL(value).hostname.replace(/^www\./, "");
  } catch {
    return "";
  }
}
