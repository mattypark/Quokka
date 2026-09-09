"use client";

import { useEffect } from "react";
import Lenis from "lenis";

/// Smooth scrolling, disabled outright for anyone who has asked for reduced motion.
///
/// Lenis hijacks the scroll wheel, which is exactly the kind of thing that makes people
/// motion-sick, so the preference is checked before it is ever constructed rather than being
/// papered over with a CSS override afterwards.
export function useLenis() {
  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    if (query.matches) return;

    const lenis = new Lenis({
      duration: 1.05,
      // Expo-out. The default easing overshoots enough to read as a bounce, which is wrong
      // for a page whose whole tone is "this is a calm place to keep things".
      easing: (t: number) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      smoothWheel: true,
    });

    let frame = 0;
    const raf = (time: number) => {
      lenis.raf(time);
      frame = requestAnimationFrame(raf);
    };
    frame = requestAnimationFrame(raf);

    return () => {
      cancelAnimationFrame(frame);
      lenis.destroy();
    };
  }, []);
}
