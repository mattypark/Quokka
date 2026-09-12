/**
 * The resolver config every device runs on.
 *
 * This is the whole point of the worker existing. The rules below are the part of Quokka most
 * likely to break -- they describe someone else's web page, and that page changes without
 * notice -- so they live here, where fixing them is a deploy, rather than in the app, where
 * fixing them is three days of App Review for a regex.
 *
 * It is also the kill switch. Removing a rung from `enabledRungs` disables it on every device
 * within the refresh window, with no release involved.
 */

export type Rung = "sharedFile" | "resolveOnDevice" | "hosted";

export interface ResolverRule {
  platform: string;
  strategy: "htmlPattern" | "webView";
  requestTemplate: string;
  headers?: Record<string, string>;
  mediaPatterns?: string[];
  script?: string;
  maxBytes?: number;
}

export interface ResolverConfig {
  version: number;
  enabledRungs: Rung[];
  rules: ResolverRule[];
}

/**
 * Read the media element the page built for itself.
 *
 * Returns null until the player exists, and the app polls -- these pages finish loading long
 * before they finish constructing a <video>, so a single evaluation on load reliably returns
 * nothing on a page that works perfectly.
 *
 * `blob:` is skipped deliberately. A blob URL is a handle into that web view's own memory and
 * means nothing to a downloader; treating it as a hit would produce a confident failure
 * instead of a retry.
 */
const READ_VIDEO_ELEMENT = `
(() => {
  const usable = (s) => typeof s === 'string' && /^https?:/.test(s);
  for (const v of document.querySelectorAll('video')) {
    if (usable(v.currentSrc)) return v.currentSrc;
    if (usable(v.src)) return v.src;
    for (const s of v.querySelectorAll('source')) if (usable(s.src)) return s.src;
  }
  return null;
})()
`.trim();

const MOBILE_SAFARI =
  "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 " +
  "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1";

export const CURRENT: ResolverConfig = {
  version: 1,

  // Rung 3 is absent on purpose. It is written, it works, and enabling it is the same moment
  // the App Privacy declaration stops being "Data Not Collected" -- so it turns on in a
  // deliberate change to this line, together with that declaration, and not before.
  enabledRungs: ["sharedFile", "resolveOnDevice"],

  rules: [
    {
      // Measured 2026-09-11: /embed/captioned/ returns a byte-identical ~623 KB application
      // shell for a real shortcode and an invented one. There is no document to match, so
      // this can only be done by rendering.
      platform: "instagram",
      strategy: "webView",
      requestTemplate: "{rawurl}",
      headers: { "User-Agent": MOBILE_SAFARI },
      script: READ_VIDEO_ELEMENT,
      maxBytes: 120000000,
    },
    {
      // Measured the same day: the video page returns its rehydration blob with
      // statusMsg "item doesn't exist" unauthenticated, and profile pages carry no video ids
      // in markup at all.
      platform: "tiktok",
      strategy: "webView",
      requestTemplate: "{rawurl}",
      headers: { "User-Agent": MOBILE_SAFARI },
      script: READ_VIDEO_ELEMENT,
      maxBytes: 120000000,
    },
    {
      // Reddit still serves real markup, so the cheap strategy works and should be used --
      // no web process, no render, just a fetch and a match.
      platform: "reddit",
      strategy: "htmlPattern",
      requestTemplate: "{rawurl}",
      headers: { "User-Agent": MOBILE_SAFARI },
      mediaPatterns: [
        String.raw`"fallback_url":\s*"([^"]+\.mp4[^"]*)"`,
        String.raw`<source\s+src="([^"]+\.mp4[^"]*)"`,
      ],
      maxBytes: 120000000,
    },
  ],
};
