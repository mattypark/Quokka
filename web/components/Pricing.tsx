"use client";

import { useState } from "react";
import { Reveal } from "./Reveal";

/// Pricing, with the numbers still to be decided.
///
/// TODO(matthew): set the real figures before launch. Everything here that is not yet a
/// decision is marked, so an unfinished price cannot quietly ship looking finished. Nothing on
/// this page is wired to a payment of any kind -- the app has no in-app purchase and no
/// account, and a pricing table is a promise, not a checkout.
const PRICING = {
  pro: { monthly: "4.99", yearly: "2.49", billedYearly: "29.99", saving: "50%" },
};

const FREE = [
  "Save from any app, as much as you like",
  "Import your whole Instagram history",
  "Sorted by creator, automatically",
  "Transcripts on the posts that allow it",
  "Playlists and the daily planner",
];

const PRO = [
  "Transcripts on everything, in one pass",
  "The whole backlog transcribed overnight",
  "Ask your library questions from your Mac",
  "Metrics on the posts that publish them",
  "Everything in Free, without the ceiling",
];

export function Pricing() {
  const [yearly, setYearly] = useState(true);

  return (
    <section id="pricing" className="border-t border-ink-7 px-6 py-24 md:px-10 md:py-32">
      <Reveal>
        <p className="font-mono text-center text-[10px] uppercase tracking-widest text-ink-5">
          Pricing
        </p>
        <h2 className="mt-5 text-center text-[clamp(1.9rem,5vw,3.25rem)] font-semibold tracking-[-0.02em]">
          Free does the whole job.
        </h2>
      </Reveal>

      <Reveal delay={0.06}>
        <div className="mt-10 flex justify-center">
          {/* Hand-rolled rather than a checkbox with appearance hacks: the pill has to slide
              between the two labels, and a native control cannot be pushed there without
              styling that breaks on the next OS. */}
          <div
            role="radiogroup"
            aria-label="Billing period"
            className="inline-flex rounded-full border border-ink-7 bg-raised p-1"
          >
            {[
              { value: false, label: "Monthly" },
              { value: true, label: "Yearly" },
            ].map((option) => (
              <button
                key={option.label}
                role="radio"
                aria-checked={yearly === option.value}
                onClick={() => setYearly(option.value)}
                className={`font-mono rounded-full px-5 py-2 text-[10px] uppercase tracking-widest transition-colors duration-200 ${
                  yearly === option.value
                    ? "bg-ink-0 text-ink-8"
                    : "text-ink-4 hover:text-ink-0"
                }`}
              >
                {option.label}
                {option.value ? (
                  <span className="ml-2 opacity-70">save {PRICING.pro.saving}</span>
                ) : null}
              </button>
            ))}
          </div>
        </div>
      </Reveal>

      <div className="mx-auto mt-14 grid max-w-4xl gap-5 md:grid-cols-2">
        <Reveal>
          <Plan
            name="Free"
            price="0"
            note="Free forever. No account, no card."
            features={FREE}
            cta="Get early access"
          />
        </Reveal>
        <Reveal delay={0.08}>
          <Plan
            name="Pro"
            price={yearly ? PRICING.pro.yearly : PRICING.pro.monthly}
            note={
              yearly
                ? `Billed $${PRICING.pro.billedYearly} a year`
                : "Billed monthly, cancel whenever"
            }
            features={PRO}
            cta="Get early access"
            featured
          />
        </Reveal>
      </div>

      <Reveal>
        <p className="font-mono mx-auto mt-10 max-w-md text-center text-[9px] uppercase leading-relaxed tracking-widest text-ink-5">
          Prices are not final. Quokka is pre-launch and nothing here charges anybody anything.
        </p>
      </Reveal>
    </section>
  );
}

function Plan({
  name,
  price,
  note,
  features,
  cta,
  featured = false,
}: {
  name: string;
  price: string;
  note: string;
  features: string[];
  cta: string;
  featured?: boolean;
}) {
  return (
    <article
      className={`relative flex h-full flex-col rounded-[20px] border p-8 ${
        featured ? "border-ink-0 bg-raised" : "border-ink-7 bg-canvas"
      }`}
    >
      {featured ? (
        <span className="font-mono absolute -top-2.5 left-8 rounded-full bg-ink-0 px-3 py-1 text-[8px] uppercase tracking-widest text-ink-8">
          When you outgrow it
        </span>
      ) : null}

      <h3 className="text-xl font-semibold">{name}</h3>

      <p className="mt-6 flex items-baseline gap-1.5">
        <span className="text-[2.75rem] font-semibold leading-none tracking-[-0.03em]">
          ${price}
        </span>
        <span className="text-sm text-ink-4">/ month</span>
      </p>
      <p className="font-mono mt-2 text-[10px] uppercase tracking-widest text-ink-5">{note}</p>

      <ul className="mt-8 flex flex-col gap-3.5 border-t border-ink-7 pt-8">
        {features.map((feature) => (
          <li key={feature} className="flex gap-3 text-sm leading-snug text-ink-2">
            <span aria-hidden="true" className="mt-[7px] h-1 w-1 shrink-0 rounded-full bg-ink-0" />
            {feature}
          </li>
        ))}
      </ul>

      <a
        href="#waitlist"
        className={`font-mono mt-8 rounded-full px-6 py-3.5 text-center text-[10px] uppercase tracking-widest transition-colors ${
          featured
            ? "bg-ink-0 text-ink-8 hover:bg-ink-2"
            : "border border-ink-0 hover:bg-ink-0 hover:text-ink-8"
        }`}
      >
        {cta}
      </a>
    </article>
  );
}
