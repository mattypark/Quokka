import localFont from "next/font/local";
import { Newsreader, JetBrains_Mono } from "next/font/google";

/// The wordmark face. Subsetted to exactly the glyphs the wordmark uses -- 2.6 kB against
/// 1.5 MB for the full character set. Google's own CSS API does the subsetting via `?text=`.
export const display = localFont({
  src: "./fonts/BagelFatOne-wordmark.woff2",
  variable: "--font-display",
  display: "swap",
  // The fallback has to be rounded, or the wordmark degrades into something with the wrong
  // personality entirely during the swap.
  fallback: ["ui-rounded", "system-ui", "sans-serif"],
});

export const editorial = Newsreader({
  subsets: ["latin"],
  variable: "--font-editorial",
  display: "swap",
});

export const mono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-mono",
  display: "swap",
});

/// The alternate letterforms.
///
/// The hero sets one headline in six different display faces at once, a letter at a time, and
/// reshuffles which letter wears which. The effect is a ransom note that keeps rewriting
/// itself -- it reads as hand-set type rather than as a typeface, which is the point: a
/// library of other people's work should not arrive in a single confident voice.
///
/// Every one of these is SIL Open Font License, and every one is subsetted to A-Z and nothing
/// else. All six together are 36 kB, which is less than a single unsubsetted weight of any of
/// them, and the headline is uppercase so the missing lowercase can never be reached.
///
/// Deliberately NOT Canela, Neue Haas Grotesk, or any other licensed foundry face. A trial
/// font on a public marketing site is redistribution, and it is the kind of thing that is
/// invisible right up until it is a letter.
// next/font resolves these at build time by reading the call site, so each one has to be a
// literal call assigned to its own const. A helper that returns localFont(...) is a build
// error, not a style preference.
const alt0 = localFont({ src: "./fonts/alt-bagel.woff2", variable: "--alt-0", display: "swap", fallback: ["ui-rounded", "system-ui", "sans-serif"] });
const alt1 = localFont({ src: "./fonts/alt-bungee.woff2", variable: "--alt-1", display: "swap", fallback: ["ui-rounded", "system-ui", "sans-serif"] });
const alt2 = localFont({ src: "./fonts/alt-glitch.woff2", variable: "--alt-2", display: "swap", fallback: ["ui-rounded", "system-ui", "sans-serif"] });
const alt3 = localFont({ src: "./fonts/alt-rye.woff2", variable: "--alt-3", display: "swap", fallback: ["ui-rounded", "system-ui", "sans-serif"] });
const alt4 = localFont({ src: "./fonts/alt-silkscreen.woff2", variable: "--alt-4", display: "swap", fallback: ["ui-rounded", "system-ui", "sans-serif"] });
const alt5 = localFont({ src: "./fonts/alt-fascinate.woff2", variable: "--alt-5", display: "swap", fallback: ["ui-rounded", "system-ui", "sans-serif"] });

export const alternates = [alt0, alt1, alt2, alt3, alt4, alt5];

/// Every font variable, for the <html> class list.
export const fontVariables = [display, editorial, mono, ...alternates]
  .map((f) => f.variable)
  .join(" ");
