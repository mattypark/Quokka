"use client";

import { useEffect, useRef } from "react";
import { Reveal } from "./Reveal";

/// The part where the page stops describing the app and shows it.
///
/// Three phones running the real thing, side by side, because the single most convincing
/// argument a tool like this has is that it already exists. The recordings are captured from
/// the simulator by `scripts/capture-web-demos.sh`, which is the same build that ships.
const SCREENS = [
  {
    src: "/demos/planner.mp4",
    poster: "/demos/planner.jpg",
    label: "One thing to make today",
    side: "left" as const,
  },
  {
    src: "/demos/library.mp4",
    poster: "/demos/library.jpg",
    label: "Everything you saved",
    side: "center" as const,
  },
  {
    src: "/demos/idea.mp4",
    poster: "/demos/idea.jpg",
    label: "Turned into something you can shoot",
    side: "right" as const,
  },
];

export function AppShowcase() {
  return (
    <section id="app" className="relative border-t border-ink-7 px-6 py-24 md:px-10 md:py-32">
      <Reveal>
        <h2 className="mx-auto max-w-3xl text-center text-[clamp(1.6rem,4.4vw,3rem)] font-semibold leading-[1.1] tracking-[-0.02em]">
          Save inspiration, pull the words out, build something of your own.
        </h2>
      </Reveal>

      <Reveal delay={0.08}>
        <p className="font-mono mx-auto mt-8 max-w-2xl text-center text-[11px] uppercase leading-relaxed tracking-widest text-ink-4">
          Quokka is one home for everything that feeds what you make: the posts you saved, the
          scripts inside them, and the ideas you owe yourself.
        </p>
      </Reveal>

      <div className="relative mx-auto mt-16 grid max-w-6xl grid-cols-1 items-center gap-10 md:mt-24 md:grid-cols-[1fr_auto_1fr]">
        <Aside className="md:text-right">
          Everyone tells you to post consistently to grow. Nobody tells you what to post, why it
          worked, or how to sound like yourself doing it.
        </Aside>

        {/* The stack. On a phone these become one column, because three phones rendered at
            thumbnail size inside a phone is a picture of nothing. */}
        <div className="flex items-center justify-center gap-0 md:-space-x-16">
          {SCREENS.map((screen) => (
            <Phone key={screen.src} {...screen} />
          ))}
        </div>

        <Aside>
          The good stuff is already in your saves. Quokka turns it from a pile you scroll past
          into the raw material for the next thing you make.
        </Aside>
      </div>
    </section>
  );
}

function Aside({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return (
    <Reveal>
      <p
        className={`font-mono max-w-xs text-[10px] uppercase leading-[1.9] tracking-widest text-ink-5 ${className}`}
      >
        {children}
      </p>
    </Reveal>
  );
}

/// One phone.
///
/// The frame is drawn rather than photographed: a device mockup PNG is a megabyte of someone
/// else's render, and this is four rounded rectangles.
function Phone({
  src,
  poster,
  label,
  side,
}: {
  src: string;
  poster: string;
  label: string;
  side: "left" | "center" | "right";
}) {
  const video = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const el = video.current;
    if (!el) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    // Only play while on screen. Three autoplaying videos looping behind the fold is battery
    // and decode budget spent on something nobody is looking at.
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) void el.play().catch(() => {});
        else el.pause();
      },
      { threshold: 0.25 }
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  const center = side === "center";

  return (
    <figure
      className={`relative shrink-0 ${
        center ? "z-20 w-[62vw] max-w-[248px]" : "z-10 hidden w-[200px] md:block"
      } ${side === "left" ? "rotate-[-3deg]" : ""} ${side === "right" ? "rotate-[3deg]" : ""}`}
    >
      <div className="relative overflow-hidden rounded-[2.2rem] border border-ink-6 bg-ink-0 p-[5px] shadow-[0_40px_80px_-50px_rgba(0,0,0,0.7)]">
        <div className="relative overflow-hidden rounded-[1.9rem] bg-canvas">
          <video
            ref={video}
            className="block h-auto w-full"
            src={src}
            poster={poster}
            muted
            loop
            playsInline
            preload="metadata"
            // Decorative: the caption underneath says what it is, and a screen recording has
            // no accessible content of its own to offer.
            aria-hidden="true"
          />
        </div>
        {/* The island. Drawn, so it sits over the recording the way it does on the device. */}
        <div className="absolute left-1/2 top-[13px] h-[18px] w-[62px] -translate-x-1/2 rounded-full bg-ink-0" />
      </div>
      <figcaption className="font-mono mt-4 text-center text-[9px] uppercase tracking-widest text-ink-5">
        {label}
      </figcaption>
    </figure>
  );
}
