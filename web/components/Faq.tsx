"use client";

import { Reveal } from "./Reveal";

/// The five things somebody actually wants to know before handing an app their saves.
///
/// Written as <details>, not as React state. The browser already has a disclosure widget with
/// correct keyboard handling, correct semantics and correct behaviour with the page searched
/// via find-in-page -- a hand-rolled accordion has to earn its place, and here it cannot.
const QUESTIONS = [
  {
    q: "What is Quokka?",
    a: "A place to put the things that moved you. Share a post from any app and Quokka files it, finds the picture, and sorts it by who made it — then helps you turn what you saved into something of your own.",
  },
  {
    q: "Does it need my Instagram password?",
    a: "No, and it never will. Quokka reads the export file Instagram gives you when you ask for your own data. It does not log in to your account, and there is nothing for it to log in with.",
  },
  {
    q: "Where does my library live?",
    a: "On your phone. Quokka has no accounts and no server holding your saves. The transcript work runs on the device too, using Apple's own speech model.",
  },
  {
    q: "How does it get the words out of a video?",
    a: "Four ways, tried in order, stopping at the first that works. The fastest and most reliable is a video you downloaded with the app's own Download button — which is why the app teaches you that the button exists.",
  },
  {
    q: "What does it cost?",
    a: "Free does the whole job: saving, importing, sorting, playlists, the planner, and transcripts on the posts that allow them. Pro is for people who want the entire backlog transcribed rather than one post at a time.",
  },
  {
    q: "When can I have it?",
    a: "It is in TestFlight. Join the waitlist and you get a link when there is a build worth your time — not before.",
  },
];

export function Faq() {
  return (
    <section id="faq" className="border-t border-ink-7 px-6 py-24 md:px-10 md:py-32">
      <Reveal>
        <p className="font-mono text-center text-[10px] uppercase tracking-widest text-ink-5">
          FAQ
        </p>
        <h2 className="mt-5 text-center text-[clamp(1.9rem,5vw,3.25rem)] font-semibold tracking-[-0.02em]">
          Questions, answered.
        </h2>
      </Reveal>

      <div className="mx-auto mt-14 max-w-2xl">
        {QUESTIONS.map((item, index) => (
          <Reveal key={item.q} delay={index * 0.02}>
            <details className="group border-b border-ink-7">
              <summary className="flex cursor-pointer list-none items-center justify-between gap-6 py-6 text-left text-base font-medium transition-colors hover:text-ink-3 [&::-webkit-details-marker]:hidden">
                {item.q}
                {/* Rotates rather than swapping glyph, so the control reads as one object
                    opening instead of two icons trading places. */}
                <span
                  aria-hidden="true"
                  className="relative h-3 w-3 shrink-0 transition-transform duration-300 ease-[cubic-bezier(0.16,1,0.3,1)] group-open:rotate-45"
                >
                  <span className="absolute left-1/2 top-0 h-full w-px -translate-x-1/2 bg-ink-0" />
                  <span className="absolute left-0 top-1/2 h-px w-full -translate-y-1/2 bg-ink-0" />
                </span>
              </summary>
              <p className="pb-6 pr-10 text-sm leading-relaxed text-ink-3">{item.a}</p>
            </details>
          </Reveal>
        ))}
      </div>
    </section>
  );
}
