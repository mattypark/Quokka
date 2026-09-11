"use client";

import { Reveal } from "./Reveal";

const steps = [
  {
    number: "01",
    title: "Save from anywhere",
    body: "Tap the three dots in any app, then Quokka. Instagram, TikTok, YouTube, Pinterest, Reddit, X — anything with a share sheet. It saves and gets out of the way in under half a second.",
  },
  {
    number: "02",
    title: "Bring the backlog",
    body: "Everything you have ever sent yourself, saved, or liked on Instagram, imported in one pass. Quokka reads the file Instagram gives you. It never signs in to your account.",
  },
  {
    number: "03",
    title: "Sorted for you",
    body: "It groups what you save by who made it, so twelve reels from one account become a place rather than twelve scattered links. No folders to keep tidy.",
  },
];

export function Proof() {
  return (
    <section id="how" className="border-t border-ink-7 px-6 py-24 md:px-10 md:py-32">
      <Reveal>
        <p className="font-mono mb-16 text-[11px] uppercase tracking-widest text-ink-5">
          How it works
        </p>
      </Reveal>

      <div className="grid gap-14 md:grid-cols-3 md:gap-10">
        {steps.map((step, index) => (
          <Reveal key={step.number} delay={index * 0.08}>
            <article className="max-w-sm">
              <p className="font-mono text-[11px] tracking-widest text-ink-5">{step.number}</p>
              <h2 className="font-editorial mt-4 text-2xl leading-tight md:text-3xl">
                {step.title}
              </h2>
              <p className="mt-4 text-[15px] leading-relaxed text-ink-3">{step.body}</p>
            </article>
          </Reveal>
        ))}
      </div>
    </section>
  );
}
