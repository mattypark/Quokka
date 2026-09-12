"use client";

import { useCallback, useEffect, useRef, useState } from "react";

const FACES = 6;

/// Type that keeps changing its mind about which typeface it is.
///
/// Every letter picks one of six display faces and holds it until something disturbs it: a
/// slow shuffle on a timer, or the cursor passing underneath. The headline is never quite the
/// same twice, and it never animates -- a letter simply *is* a different face the next time
/// you look at it, which is far stranger and cheaper than a transition would be.
///
/// Two things this deliberately does not do:
///
/// It does not randomise during render. A random face chosen on the server is a different
/// random face on the client, and React would tear the whole headline down and rebuild it on
/// hydration. The first paint is the base face, and the shuffle starts after mount -- which
/// also means the LCP element paints without waiting for any of this.
///
/// It does not animate the swap. Cross-fading between two faces means painting both, and at
/// hero size that is two full text layers compositing on every tick.
export function GlyphType({
  text,
  className = "",
  as: Tag = "span",
}: {
  text: string;
  className?: string;
  as?: "span" | "h1" | "h2";
}) {
  const chars = [...text];
  // null until mounted: the server and the first client render must agree, so both draw the
  // base face and nothing else.
  const [faces, setFaces] = useState<number[] | null>(null);
  const spans = useRef<(HTMLSpanElement | null)[]>([]);
  const boxes = useRef<{ x: number; y: number }[]>([]);
  const last = useRef(-1);

  const measure = useCallback(() => {
    boxes.current = spans.current.map((el) => {
      if (!el) return { x: -9999, y: -9999 };
      const r = el.getBoundingClientRect();
      return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
    });
  }, []);

  useEffect(() => {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const roll = () => Math.floor(Math.random() * FACES);

    // One shuffle either way, so the headline is mixed type even for somebody who has asked
    // for less motion. What they lose is the movement, not the design.
    setFaces(chars.map(roll));
    if (reduced) return;

    measure();
    window.addEventListener("resize", measure);
    window.addEventListener("scroll", measure, { passive: true });

    // Two letters at a time, not all of them. A whole-headline reshuffle reads as a glitch;
    // two letters reads as the type being restless.
    const timer = window.setInterval(() => {
      setFaces((current) => {
        if (!current) return current;
        const next = [...current];
        for (let i = 0; i < 2; i++) {
          const at = Math.floor(Math.random() * next.length);
          if (chars[at] === " ") continue;
          next[at] = (next[at] + 1 + Math.floor(Math.random() * (FACES - 1))) % FACES;
        }
        return next;
      });
    }, 2200);

    let queued = false;
    const onMove = (event: PointerEvent) => {
      if (queued) return;
      queued = true;
      // Coalesced into a frame: pointermove fires far faster than the screen refreshes, and
      // the work here ends in a state update.
      requestAnimationFrame(() => {
        queued = false;
        let nearest = -1;
        let best = 90 * 90;
        boxes.current.forEach((box, index) => {
          if (chars[index] === " ") return;
          const dx = box.x - event.clientX;
          const dy = box.y - event.clientY;
          const distance = dx * dx + dy * dy;
          if (distance < best) {
            best = distance;
            nearest = index;
          }
        });
        // Only when the cursor moves on to a *different* letter, or dragging slowly across one
        // glyph would strobe it.
        if (nearest < 0 || nearest === last.current) return;
        last.current = nearest;
        setFaces((current) => {
          if (!current) return current;
          const next = [...current];
          next[nearest] = (next[nearest] + 1 + Math.floor(Math.random() * (FACES - 1))) % FACES;
          return next;
        });
      });
    };

    window.addEventListener("pointermove", onMove, { passive: true });
    return () => {
      window.clearInterval(timer);
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("resize", measure);
      window.removeEventListener("scroll", measure);
    };
    // The headline text is a constant per instance; re-running this on every render would
    // reset the shuffle on every tick of it.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [text]);

  return (
    <Tag className={className} aria-label={text}>
      {chars.map((char, index) => (
        <span
          key={index}
          ref={(el) => {
            spans.current[index] = el;
          }}
          aria-hidden="true"
          className="inline-block"
          style={{
            fontFamily: faces ? `var(--alt-${faces[index]})` : "var(--alt-0)",
            // Every face has different sidebearings, so swapping one changes the width of the
            // line and shoves its neighbours sideways. A fixed advance per glyph keeps the
            // headline still while the letters underneath it change.
            width: char === " " ? "0.3em" : "0.78em",
            textAlign: "center",
          }}
        >
          {char === " " ? " " : char}
        </span>
      ))}
    </Tag>
  );
}
