"use client";

export function Footer() {
  return (
    <footer className="border-t border-ink-7 px-6 py-10 md:px-10">
      <div className="font-mono flex flex-col gap-6 text-[10px] uppercase tracking-widest text-ink-5 sm:flex-row sm:items-center sm:justify-between">
        <p>Allim · 알림 · a reminder of what moved you</p>
        <nav className="flex gap-6">
          <a href="/privacy" className="transition-colors hover:text-ink-0">Privacy</a>
          <a href="/terms" className="transition-colors hover:text-ink-0">Terms</a>
          <a href="mailto:hello@allim.app" className="transition-colors hover:text-ink-0">Contact</a>
        </nav>
      </div>
    </footer>
  );
}
