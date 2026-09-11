"use client";

export function Nav() {
  return (
    <nav className="fixed inset-x-0 top-0 z-50 flex items-center justify-between px-6 py-5 md:px-10">
      {/* Backdrop rather than a solid fill: the hero type scrolls underneath and a hard bar
          would chop it off mid-letter. */}
      <div className="pointer-events-none absolute inset-0 bg-canvas/70 backdrop-blur-md" />

      <a href="#top" className="font-display relative text-xl tracking-tight">
        QUOKKA
      </a>

      <div className="font-mono relative hidden gap-8 text-[11px] uppercase tracking-widest text-ink-3 md:flex">
        <a href="#how" className="transition-colors hover:text-ink-0">How it works</a>
        <a href="#numbers" className="transition-colors hover:text-ink-0">The numbers</a>
      </div>

      <a
        href="#waitlist"
        className="font-mono relative rounded-full border border-ink-0 px-5 py-2 text-[11px] uppercase tracking-widest transition-colors hover:bg-ink-0 hover:text-ink-8"
      >
        Get early access
      </a>
    </nav>
  );
}
