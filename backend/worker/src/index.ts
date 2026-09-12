/**
 * Quokka's worker. Three endpoints, no database, no accounts.
 *
 *   GET  /config      the resolver rules and which rungs are live
 *   POST /transcript  rung 3 -- proxies a hosted provider, holding the key
 *   POST /extract     a transcript becomes a hook and a title
 *
 * The app never talks to a vendor directly. A vendor key in an app bundle is a published key,
 * and routing through one endpoint makes swapping providers a deploy rather than a release.
 */

import { CURRENT, type ResolverConfig } from "./config";

export interface Env {
  /** Hosted transcript provider. Absent disables rung 3 at the endpoint as well as in config. */
  TRANSCRIPT_API_KEY?: string;
  /** Anthropic key for /extract. Absent means the app falls back to its local heuristic. */
  ANTHROPIC_API_KEY?: string;
}

const JSON_HEADERS = { "content-type": "application/json; charset=utf-8" };

/** A device that cannot parse a response must not be left guessing what went wrong. */
const fail = (status: number, reason: string) =>
  new Response(JSON.stringify({ error: reason }), { status, headers: JSON_HEADERS });

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);

    switch (`${request.method} ${pathname}`) {
      case "GET /config":
        return serveConfig(env);
      case "POST /transcript":
        return transcribe(request, env);
      case "POST /extract":
        return extract(request, env);
      default:
        return fail(404, "no such endpoint");
    }
  },
};

/**
 * Served with a short cache so a switch thrown here reaches devices quickly, and so a burst
 * of app launches does not become a burst of worker invocations.
 *
 * Rung 3 is stripped when no provider key is configured. Advertising a rung the worker cannot
 * serve would have every device try it, fail, and report a transport error -- which looks like
 * a provider outage rather than a deployment that was never finished.
 */
function serveConfig(env: Env): Response {
  const config: ResolverConfig = {
    ...CURRENT,
    enabledRungs: env.TRANSCRIPT_API_KEY
      ? CURRENT.enabledRungs
      : CURRENT.enabledRungs.filter((r) => r !== "hosted"),
  };
  return new Response(JSON.stringify(config), {
    headers: { ...JSON_HEADERS, "cache-control": "public, max-age=900" },
  });
}

/**
 * Rung 3. One call covers YouTube, TikTok, Instagram, X and Facebook; the provider tries
 * native captions first and falls back to speech recognition.
 *
 * This buys robustness and buys no legal cover: the provider's terms put compliance with every
 * platform's own terms back on us, and run the indemnity the same way. It is a convenience.
 */
async function transcribe(request: Request, env: Env): Promise<Response> {
  if (!env.TRANSCRIPT_API_KEY) return fail(503, "rung 3 is not configured");

  let body: { url?: string; lang?: string };
  try {
    body = await request.json();
  } catch {
    return fail(400, "body must be JSON");
  }
  if (!body.url) return fail(400, "url is required");

  const upstream = new URL("https://api.supadata.ai/v1/transcript");
  upstream.searchParams.set("url", body.url);
  upstream.searchParams.set("mode", "auto");
  upstream.searchParams.set("text", "false");
  if (body.lang) upstream.searchParams.set("lang", body.lang);

  const response = await fetch(upstream, { headers: { "x-api-key": env.TRANSCRIPT_API_KEY } });

  // 202 means the provider queued a job for a long video. Passed through rather than polled
  // here: a worker that sits in a polling loop is billed for the wait and times out anyway.
  if (response.status === 202) return fail(503, "queued upstream; retry");
  if (!response.ok) return fail(response.status, "upstream refused");

  const data = (await response.json()) as {
    content?: string | Array<{ text: string; offset: number; duration: number }>;
    lang?: string;
  };

  const chunks = Array.isArray(data.content) ? data.content : [];
  const text = Array.isArray(data.content)
    ? chunks.map((c) => c.text).join(" ")
    : (data.content ?? "");

  return new Response(
    JSON.stringify({
      text: text.trim(),
      lang: data.lang ?? null,
      // Offsets arrive in milliseconds and the app works in seconds. Converted here so the
      // unit mismatch cannot survive into stored rows, where it would read as a video hours long.
      segments: chunks.map((c) => ({
        text: c.text,
        start: c.offset / 1000,
        duration: c.duration / 1000,
      })),
    }),
    { headers: JSON_HEADERS },
  );
}

/**
 * A transcript becomes a title and a hook.
 *
 * Small model on purpose: this is a short, shaped extraction over text that is already in
 * hand, not a reasoning problem, and the app has a local fallback for when this is
 * unavailable. Nothing is stored here -- the text arrives, is transformed, and is returned.
 */
async function extract(request: Request, env: Env): Promise<Response> {
  if (!env.ANTHROPIC_API_KEY) return fail(503, "extraction is not configured");

  let body: { transcript?: string };
  try {
    body = await request.json();
  } catch {
    return fail(400, "body must be JSON");
  }
  const transcript = (body.transcript ?? "").trim();
  if (!transcript) return fail(400, "transcript is required");

  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 400,
      system:
        "You are given the transcript of a short-form video someone saved for reference. " +
        "Return JSON only: {\"title\": string, \"hook\": string}. The title is at most eight " +
        "words and names what the video is about. The hook is the opening line, quoted from " +
        "the transcript verbatim -- never invented. If the transcript has no usable opening " +
        "line, set hook to null.",
      messages: [{ role: "user", content: transcript.slice(0, 12000) }],
    }),
  });

  if (!response.ok) return fail(response.status, "extraction failed");

  const data = (await response.json()) as { content?: Array<{ text?: string }> };
  const raw = data.content?.[0]?.text?.trim() ?? "";
  try {
    // The model is asked for JSON and usually complies. When it does not, this is a failure
    // and not a salvage job -- the app's local heuristic is better than a half-parsed title.
    const parsed = JSON.parse(raw) as { title?: string; hook?: string | null };
    return new Response(
      JSON.stringify({ title: parsed.title ?? null, hook: parsed.hook ?? null }),
      { headers: JSON_HEADERS },
    );
  } catch {
    return fail(502, "extraction was not JSON");
  }
}
