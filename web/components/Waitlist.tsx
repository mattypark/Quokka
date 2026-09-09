"use client";

import { useState, type FormEvent } from "react";
import { Reveal } from "./Reveal";
import { Wordmark } from "./Wordmark";

type State = "idle" | "sending" | "done" | "error";

export function Waitlist() {
  const [email, setEmail] = useState("");
  const [state, setState] = useState<State>("idle");
  // Honeypot. A real person never fills a field they cannot see, and this stops most bots
  // without asking anyone to identify a bus.
  const [company, setCompany] = useState("");

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (state === "sending" || company) return;
    setState("sending");

    try {
      const response = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });
      setState(response.ok ? "done" : "error");
    } catch {
      setState("error");
    }
  }

  return (
    <section id="waitlist" className="border-t border-ink-7 px-6 py-28 md:py-36">
      <Reveal className="mx-auto flex max-w-xl flex-col items-center text-center">
        <Wordmark size="text-[clamp(2.25rem,7vw,4rem)]" animate={false} />

        <h2 className="font-editorial mt-10 text-[clamp(1.5rem,3.5vw,2.25rem)] leading-tight tracking-[-0.02em]">
          Get it before everyone else.
        </h2>
        <p className="mt-4 text-[15px] leading-relaxed text-ink-3">
          One email when it is ready. Nothing else, ever.
        </p>

        {state === "done" ? (
          <p className="font-mono mt-10 text-[12px] uppercase tracking-widest">
            You are on the list.
          </p>
        ) : (
          <form onSubmit={submit} className="mt-10 flex w-full max-w-md flex-col gap-3 sm:flex-row">
            <label className="sr-only" htmlFor="email">Email address</label>
            <input
              id="email"
              type="email"
              required
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="you@example.com"
              className="flex-1 rounded-full border border-ink-6 bg-canvas px-6 py-4 text-[15px] outline-none transition-colors placeholder:text-ink-5 focus:border-ink-0"
            />

            {/* Hidden from people and from screen readers, visible to naive bots. */}
            <input
              type="text"
              name="company"
              tabIndex={-1}
              autoComplete="off"
              aria-hidden="true"
              value={company}
              onChange={(event) => setCompany(event.target.value)}
              className="pointer-events-none absolute h-0 w-0 opacity-0"
            />

            <button
              type="submit"
              disabled={state === "sending"}
              className="font-mono rounded-full bg-ink-0 px-8 py-4 text-[11px] uppercase tracking-widest text-ink-8 transition-transform duration-300 ease-[cubic-bezier(0.16,1,0.3,1)] hover:scale-[1.03] disabled:opacity-50"
            >
              {state === "sending" ? "…" : "Join"}
            </button>
          </form>
        )}

        {state === "error" && (
          <p className="font-mono mt-4 text-[11px] text-ink-3">
            That did not go through. Try again in a moment.
          </p>
        )}
      </Reveal>
    </section>
  );
}
