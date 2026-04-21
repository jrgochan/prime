import type { Metadata } from "next";
import { Geist_Mono } from "next/font/google";
import "./globals.css";

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Project HyperZeta — Cathedral Viewport",
  description:
    "Interactive 3D visualization of sedenion lattice dynamics and spectral geometry underlying the Cathedral proof of the Riemann Hypothesis.",
  openGraph: {
    title: "Project HyperZeta — Cathedral Viewport",
    description:
      "150,000-particle sedenion lattice simulation via Rust/WASM + Three.js.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${geistMono.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
