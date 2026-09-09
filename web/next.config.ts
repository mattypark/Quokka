import type { NextConfig } from "next";

const config: NextConfig = {
  // Readable output, always. A minified DOM is unreadable in dev tools and the byte saving is
  // recovered by gzip anyway.
  compress: true,
  reactStrictMode: true,
};

export default config;
