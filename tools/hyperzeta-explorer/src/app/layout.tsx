import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "HYPERZETA Explorer — Cayley-Dickson Tower",
  description: "4-mode sedenion visualization: Origin sweep, Teardrop Sphere (Riemann stereographic), Glass Staircase (ℝ→ℂ→ℍ→𝕆→𝕊 decomposition), Division by Zero (Möbius inverse 1/ζ). 150K particles × 16 dimensions × 60fps.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
