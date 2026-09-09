import type { ReactNode } from "react";

/// Content arriving as it scrolls into view.
///
/// A server component with no JavaScript at all. The animation is attached in CSS through
/// `animation-timeline: view()`, so the browser drives it on the compositor and the element is
/// **visible by default** -- the reveal is an enhancement layered on top rather than a hidden
/// state waiting to be undone.
///
/// The previous version used Framer Motion's `whileInView`, which writes `opacity: 0` into the
/// server-rendered markup. That means a slow, blocked or disabled bundle leaves every section
/// below the fold permanently blank, which is a bad trade for a marketing page whose entire job
/// is to be read.
export function Reveal({
  children,
  delay = 0,
  className,
}: {
  children: ReactNode;
  delay?: number;
  className?: string;
}) {
  return (
    <div
      data-reveal
      className={className}
      // Scroll-driven animations are positional, not temporal, so a delay in seconds means
      // nothing to them. A small translate offset gives the same staggered feel instead.
      style={delay ? { animationRangeStart: `entry ${delay * 40}%` } : undefined}
    >
      {children}
    </div>
  );
}
