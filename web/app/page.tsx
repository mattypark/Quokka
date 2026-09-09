"use client";

import { useLenis } from "@/lib/useLenis";
import { Nav } from "@/components/Nav";
import { Hero } from "@/components/Hero";
import { Proof } from "@/components/Proof";
import { Numbers } from "@/components/Numbers";
import { Waitlist } from "@/components/Waitlist";
import { Footer } from "@/components/Footer";

export default function Home() {
  useLenis();

  return (
    <main className="min-h-dvh">
      <Nav />
      <Hero />
      <Proof />
      <Numbers />
      <Waitlist />
      <Footer />
    </main>
  );
}
