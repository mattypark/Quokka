/// The same mark as the app: ALLIM in Bagel Fat One, 알림 beneath in the same face.
///
/// Setting both lines in one typeface is the whole point. Bagel Fat One is a Korean-designed
/// face carrying full Hangul, so the Korean is not a translation pinned under a logo -- it is
/// the same mark, written the other way.
///
/// Deliberately a server component with a CSS animation. This is the top of the page and it
/// must paint without waiting for a JavaScript bundle.
export function Wordmark({
  size = "text-[clamp(3rem,12vw,9rem)]",
  animate = true,
}: {
  size?: string;
  animate?: boolean;
}) {
  const letters = "ALLIM".split("");

  return (
    <div className="flex flex-col items-center leading-none">
      <div className={`font-display flex ${size} tracking-[-0.01em]`}>
        {letters.map((letter, index) => (
          <span
            key={index}
            className={animate ? "rise" : undefined}
            style={animate ? { animationDelay: `${index * 0.045}s` } : undefined}
          >
            {letter}
          </span>
        ))}
      </div>
      <div
        className={`font-display mt-[0.12em] text-ink-5 text-[clamp(1rem,4vw,3rem)] ${animate ? "rise" : ""}`}
        style={animate ? { animationDelay: "0.25s" } : undefined}
      >
        알림
      </div>
    </div>
  );
}
