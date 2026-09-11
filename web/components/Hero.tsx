import { Wordmark } from "./Wordmark";

/// The hook is the habit, not the feature.
///
/// Everyone who needs this app is already doing the broken version of it: sending reels to a
/// second account and never finding them again. Naming that back to them lands harder than any
/// description of what the app does, so the headline is the confession and the product is the
/// answer to it.
///
/// A server component with CSS animation. The headline is the LCP element and cannot be made
/// to wait on a JavaScript bundle.
export function Hero() {
  const words = "You have been sending reels to your other account for years.".split(" ");

  return (
    <section
      id="top"
      className="relative flex min-h-dvh flex-col items-center justify-center px-6 pt-28 pb-20"
    >
      <Wordmark />

      <h1 className="font-editorial mx-auto mt-[8vh] max-w-4xl text-center text-[clamp(1.75rem,5.2vw,3.75rem)] leading-[1.12] tracking-[-0.02em]">
        {words.map((word, index) => (
          <span
            key={index}
            className="rise inline-block"
            // Staggered by word, but deliberately fast. LCP is measured when content
            // actually paints, so every millisecond of delay on the headline is a millisecond
            // added to the score -- a leisurely stagger is a metric regression wearing a
            // costume. Everything is on screen inside ~600ms.
            style={{ animationDelay: `${0.18 + Math.min(index, 14) * 0.028}s` }}
          >
            {word}
            {index < words.length - 1 ? " " : ""}
          </span>
        ))}
      </h1>

      <p
        className="rise mt-8 max-w-md text-center text-base leading-relaxed text-ink-3"
        style={{ animationDelay: "0.56s" }}
      >
        They are still in there. Quokka is where they should have been going — and it can pull
        every one of them out in a single pass.
      </p>

      <a
        href="#waitlist"
        className="rise font-mono mt-10 rounded-full bg-ink-0 px-8 py-4 text-[11px] uppercase tracking-widest text-ink-8 transition-transform duration-300 ease-[cubic-bezier(0.16,1,0.3,1)] hover:scale-[1.03]"
        style={{ animationDelay: "0.64s" }}
      >
        Get early access →
      </a>

      <p
        className="rise font-mono mt-6 text-[10px] uppercase tracking-widest text-ink-5"
        style={{ animationDelay: "0.7s" }}
      >
        Instagram · TikTok · YouTube · Pinterest · Reddit · X
      </p>
    </section>
  );
}
