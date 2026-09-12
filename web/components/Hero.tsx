"use client";

import { useEffect, useState } from "react";
import { GlyphType } from "./GlyphType";
import { Collage } from "./Collage";

/// The second line changes its mind, the way the first one changes its typeface.
///
/// One fixed verb and a rotating object: the app does one thing to a lot of different kinds of
/// thing, and a headline that lists them in sequence says that faster than a subheading can.
const TAILS = [
  "STOPPED YOUR THUMB",
  "YOU KEEP RESENDING",
  "YOU MEANT TO MAKE",
  "MOVED YOU ONCE",
];

/// The hook is the habit, not the feature.
///
/// Everyone who needs this app is already doing the broken version of it: sending reels to a
/// second account and never finding them again. Naming that back to them lands harder than any
/// description of what the app does.
export function Hero() {
  const [tail, setTail] = useState(0);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    // Slow. The line has to be read before it is replaced, and a headline that changes while
    // somebody is still on the first half of it reads as a bug rather than as a list.
    const timer = window.setInterval(() => setTail((n) => (n + 1) % TAILS.length), 3800);
    return () => window.clearInterval(timer);
  }, []);

  return (
    <section
      id="top"
      className="hero-fade relative flex min-h-dvh flex-col items-center justify-center px-6 pt-28 pb-32"
    >
      <Collage />

      <div className="relative z-10 flex w-full flex-col items-center">
        <h1 className="sr-only">Save what stopped your thumb, and turn it into something.</h1>

        <div
          aria-hidden="true"
          className="rise flex w-full flex-col items-center text-[clamp(2.6rem,11vw,8.5rem)] leading-[0.92] tracking-[-0.01em]"
          style={{ animationDelay: "0.14s" }}
        >
          <GlyphType text="SAVE WHAT" />
          {/* Keyed on the tail, so React swaps the element rather than mutating it -- which is
              what lets the entrance animation run again on every change. */}
          <GlyphType key={tail} text={TAILS[tail]} className="rise" />
        </div>

        <a
          href="#waitlist"
          className="rise font-mono relative z-30 mt-[6vh] rounded-full bg-ink-0 px-8 py-4 text-[11px] uppercase tracking-widest text-ink-8 transition-transform duration-300 ease-[cubic-bezier(0.16,1,0.3,1)] hover:scale-[1.03]"
          style={{ animationDelay: "0.5s" }}
        >
          Get early access →
        </a>
      </div>

      <HeroMeta />
    </section>
  );
}

/// The three corners.
///
/// Small, monospaced, and set in the margins where a printed page would put a folio. They are
/// the only things on the hero that are not the headline, and keeping them at the edges is
/// what leaves the middle of the screen empty enough for the type to be the whole event.
function HeroMeta() {
  return (
    <div className="font-mono pointer-events-none absolute inset-x-0 bottom-0 z-30 flex items-end justify-between gap-4 px-6 pb-6 text-[9px] uppercase tracking-widest text-ink-4 md:px-10 md:text-[10px]">
      <span className="hidden md:inline">Save · Transcribe · Make</span>
      <span className="max-w-md text-center leading-relaxed">
        Save inspiration from any app, pull the words out of it, build something of your own
      </span>
      <Clock />
    </div>
  );
}

/// A clock, because the page should look like it is running rather than like it was published.
function Clock() {
  // Empty on the server and on the first client render. A time rendered during SSR is already
  // wrong by the time it is hydrated, and React would flag the mismatch.
  const [now, setNow] = useState("");

  useEffect(() => {
    const tick = () =>
      setNow(
        new Date().toLocaleTimeString("en-US", {
          hour12: false,
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
        })
      );
    tick();
    const timer = window.setInterval(tick, 1000);
    return () => window.clearInterval(timer);
  }, []);

  return (
    <span className="hidden tabular-nums md:inline" suppressHydrationWarning>
      {now || "--:--:--"}
    </span>
  );
}
