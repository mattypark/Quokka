"use client";

import { useLenis } from "@/lib/useLenis";
import { Nav } from "@/components/Nav";
import { Hero } from "@/components/Hero";
import { AppShowcase } from "@/components/AppShowcase";
import { Proof } from "@/components/Proof";
import { Numbers } from "@/components/Numbers";
import { Pricing } from "@/components/Pricing";
import { Faq } from "@/components/Faq";
import { Waitlist } from "@/components/Waitlist";
import { Footer } from "@/components/Footer";

export default function Home() {
  useLenis();

  return (
    <main className="min-h-dvh">
      <Nav />
      <Hero />
      {/* The app comes immediately after the hero, before any explaining. The strongest
          argument this page has is that the thing already exists and here it is running. */}
      <AppShowcase />
      <Proof />
      <Numbers />
      <Pricing />
      <Faq />
      <Waitlist />
      <Footer />
    </main>
  );
}
