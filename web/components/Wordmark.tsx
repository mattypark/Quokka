/// QUOKKA, set in Bagel Fat One.
///
/// A server component with a CSS animation. This is the top of the page and must paint without
/// waiting for a JavaScript bundle.
export function Wordmark({
  size = "text-[clamp(3rem,12vw,9rem)]",
  animate = true,
}: {
  size?: string;
  animate?: boolean;
}) {
  const letters = "QUOKKA".split("");

  return (
    <div className={`font-display flex ${size} leading-none tracking-[-0.01em]`}>
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
  );
}
