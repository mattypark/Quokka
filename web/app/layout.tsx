import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import { Newsreader, JetBrains_Mono } from "next/font/google";
import "./globals.css";

// The same three faces as the app, all SIL Open Font License.
//
// Keep on Truckin is deliberately absent. It is licensed for personal use only, which is
// defensible on a private build running on one phone and is not defensible on a public
// marketing site. See docs/DECISIONS.md.
// Bagel Fat One, subsetted to exactly the glyphs the wordmark uses: A L I M and 알림.
//
// Self-hosted rather than pulled from next/font/google, because the Google loader only offers
// this face's latin subsets -- the Hangul would silently fall back to a system font and quietly
// destroy the one idea the mark is built on, that both lines are the same typeface. Google's
// own CSS API will subset by glyph via ?text=, which turns a 1.5 MB file into 2.6 kB.
const display = localFont({
  src: "./fonts/BagelFatOne-wordmark.woff2",
  variable: "--font-display",
  display: "swap",
  // The fallback has to be rounded, or the wordmark degrades into something with the wrong
  // personality entirely during the swap.
  fallback: ["ui-rounded", "system-ui", "sans-serif"],
});

const editorial = Newsreader({
  subsets: ["latin"],
  variable: "--font-editorial",
  display: "swap",
});

const mono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-mono",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://allim.app"),
  title: "Allim — a place for what moved you",
  description:
    "Save a post from any app and Allim files it, finds the picture, and sorts it on its own. Instagram, TikTok, YouTube, Pinterest, Reddit, X.",
  openGraph: {
    title: "Allim — a place for what moved you",
    description:
      "Save a post from any app and Allim files it, finds the picture, and sorts it on its own.",
    type: "website",
    locale: "en_US",
  },
  twitter: { card: "summary_large_image" },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  themeColor: "#ffffff",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${display.variable} ${editorial.variable} ${mono.variable}`}>
      <body className="bg-canvas text-ink-0 antialiased">
        {/* Scroll reveals are hidden by JavaScript, so without JavaScript they must be
            visible. A <noscript> cannot add a class to <html>, but it can carry a stylesheet,
            which is the one thing it is genuinely good for. */}
        <noscript>
          <style>{`[data-reveal]{opacity:1 !important;transform:none !important}`}</style>
        </noscript>
        {children}
      </body>
    </html>
  );
}
