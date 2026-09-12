"use client";

import { useEffect, useRef } from "react";

/// The pile that drifts through the headline.
///
/// Every piece is a saved post rendered the way the app renders one it could not find a
/// picture for: a title set in a serif, at size, on paper. That is not a placeholder standing
/// in for photography -- it is the app's actual fallback tile, and leaning on it here is the
/// payoff of committing to black and white. The collage is made of the product.
///
/// They sit in front of the type rather than behind it, because a pile of things you saved
/// getting in the way of the sentence is the entire feeling being described.
const PIECES = [
  { text: "the hook is the first four words", x: 12, y: 18, rot: -8, w: 15, depth: 1.4 },
  { text: "shot on a window, not a light", x: 74, y: 12, rot: 7, w: 13, depth: 2.1 },
  { text: "post it before you think", x: 82, y: 58, rot: -5, w: 12, depth: 1.1 },
  { text: "nobody watches past 0:03", x: 6, y: 62, rot: 6, w: 14, depth: 1.8 },
  { text: "say the thing, then show it", x: 62, y: 76, rot: -11, w: 13, depth: 0.8 },
  { text: "record it twice, keep the second", x: 26, y: 80, rot: 9, w: 14, depth: 2.4 },
  { text: "your taste is the moat", x: 46, y: 8, rot: -4, w: 11, depth: 1.5 },
];

export function Collage() {
  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const el = root.current;
    if (!el) return;

    let queued = false;
    const onMove = (event: PointerEvent) => {
      if (queued) return;
      queued = true;
      requestAnimationFrame(() => {
        queued = false;
        // Offset from the centre of the viewport, normalised to -1..1. Each piece multiplies
        // it by its own depth, so the pile has parallax rather than sliding as one sheet.
        const x = (event.clientX / window.innerWidth - 0.5) * 2;
        const y = (event.clientY / window.innerHeight - 0.5) * 2;
        el.style.setProperty("--px", x.toFixed(3));
        el.style.setProperty("--py", y.toFixed(3));
      });
    };

    window.addEventListener("pointermove", onMove, { passive: true });
    return () => window.removeEventListener("pointermove", onMove);
  }, []);

  return (
    <div
      ref={root}
      aria-hidden="true"
      // Nothing here is content. It cannot be selected, cannot be clicked, and is not read
      // out -- it is texture, and texture that traps the cursor is just a bug.
      className="pointer-events-none absolute inset-0 z-20 select-none overflow-hidden"
      style={{ ["--px" as string]: 0, ["--py" as string]: 0 }}
    >
      {PIECES.map((piece, index) => (
        <figure
          key={index}
          className="absolute hidden rounded-[10px] border border-ink-7 bg-raised px-3 py-2.5 shadow-[0_10px_30px_-18px_rgba(0,0,0,0.45)] md:block"
          style={{
            left: `${piece.x}%`,
            top: `${piece.y}%`,
            width: `${piece.w}rem`,
            transform: `translate3d(calc(var(--px) * ${piece.depth * -18}px), calc(var(--py) * ${
              piece.depth * -18
            }px), 0) rotate(${piece.rot}deg)`,
            transition: "transform 600ms cubic-bezier(0.16,1,0.3,1)",
          }}
        >
          <figcaption className="font-editorial text-[13px] leading-snug text-ink-2">
            {piece.text}
          </figcaption>
          <div className="mt-2 flex items-center gap-1.5">
            <span className="h-1 w-1 rounded-full bg-ink-6" />
            <span className="font-mono text-[8px] uppercase tracking-widest text-ink-5">saved</span>
          </div>
        </figure>
      ))}
    </div>
  );
}
