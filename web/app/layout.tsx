import type { Metadata, Viewport } from "next";
import { fontVariables } from "./fonts";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://quokka.app"),
  title: "Quokka — a place for what moved you",
  description:
    "Save a post from any app and Quokka files it, finds the picture, and sorts it on its own. Instagram, TikTok, YouTube, Pinterest, Reddit, X.",
  openGraph: {
    title: "Quokka — a place for what moved you",
    description:
      "Save a post from any app and Quokka files it, finds the picture, and sorts it on its own.",
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
    <html lang="en" className={fontVariables}>
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
