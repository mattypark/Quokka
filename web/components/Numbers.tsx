"use client";

import { useEffect, useRef, useState } from "react";
import { animate } from "animejs";
import { Reveal } from "./Reveal";

/// The numbers section, and the honesty that has to go with it.
///
/// Coverage is genuinely uneven -- YouTube publishes an official API, TikTok publishes stats
/// on the page, and Instagram publishes nothing at all to anyone who is not logged in. Saying
/// so on the marketing site is not a weakness; it is the difference between a product that
/// under-promises and one that gets a one-star review in week two for showing zeros.
const metrics = [
  { label: "Views", value: 2379697, format: "compact" as const },
  { label: "Like rate", value: 7.37, format: "percent" as const },
  { label: "Share rate", value: 2.62, format: "percent" as const },
  { label: "Save rate", value: 6.71, format: "percent" as const },
];

function Metric({ label, value, format, active }: (typeof metrics)[number] & { active: boolean }) {
  const [shown, setShown] = useState(0);
  const done = useRef(false);

  useEffect(() => {
    if (!active || done.current) return;
    done.current = true;

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setShown(value);
      return;
    }

    // Counting up is the one animation that carries meaning here rather than decorating:
    // it reads as the number being measured.
    const target = { n: 0 };
    animate(target, {
      n: value,
      duration: 1600,
      ease: "outExpo",
      onUpdate: () => setShown(target.n),
    });
  }, [active, value]);

  const text =
    format === "percent"
      ? `${shown.toFixed(2)}%`
      : Intl.NumberFormat("en", { notation: "compact", maximumFractionDigits: 1 }).format(
          Math.round(shown),
        );

  return (
    <div className="rounded-2xl bg-raised px-6 py-7">
      <p className="font-mono text-[10px] uppercase tracking-widest text-ink-5">{label}</p>
      <p className="font-editorial mt-2 text-3xl tabular-nums md:text-4xl">{text}</p>
    </div>
  );
}

export function Numbers() {
  const section = useRef<HTMLElement>(null);
  const [active, setActive] = useState(false);

  useEffect(() => {
    const node = section.current;
    if (!node) return;
    const observer = new IntersectionObserver(
      ([entry]) => entry.isIntersecting && setActive(true),
      { threshold: 0.35 },
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  return (
    <section id="numbers" ref={section} className="border-t border-ink-7 px-6 py-24 md:px-10 md:py-32">
      <Reveal>
        <p className="font-mono mb-4 text-[11px] uppercase tracking-widest text-ink-5">
          The numbers
        </p>
        <h2 className="font-editorial max-w-2xl text-[clamp(1.6rem,4vw,2.75rem)] leading-tight tracking-[-0.02em]">
          Saving something is one thing. Knowing why it worked is another.
        </h2>
        <p className="mt-5 max-w-xl text-[15px] leading-relaxed text-ink-3">
          Raw counts cannot be compared across videos — a two-million-view post and a
          forty-thousand-view post are not the same kind of thing. Rates can. Allim stores the
          counts and shows you the rates.
        </p>
      </Reveal>

      <Reveal delay={0.1}>
        <div className="mt-12 grid grid-cols-2 gap-3 md:max-w-3xl md:grid-cols-4">
          {metrics.map((metric) => (
            <Metric key={metric.label} {...metric} active={active} />
          ))}
        </div>
      </Reveal>

      <Reveal delay={0.18}>
        {/* Stated plainly, on the marketing site, before anyone downloads it. A product that
            tells you its limits up front is trusted on the ones it does not have. */}
        <p className="font-mono mt-8 max-w-2xl text-[11px] leading-relaxed text-ink-5">
          Full numbers on YouTube. Best-effort on TikTok. Instagram, Pinterest and X publish
          nothing to anyone who is not logged in, so Allim shows no numbers there rather than
          inventing them.
        </p>
      </Reveal>
    </section>
  );
}
