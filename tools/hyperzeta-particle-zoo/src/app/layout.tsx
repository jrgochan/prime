import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Particle Zoo — Every Integer Has a Soul",
  description: "Interactive 3D visualization of the arithmetic particle zoo: how primes, semiprimes, and composites compete inside the Riemann Hypothesis. 55,440 integers classified.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&family=JetBrains+Mono:wght@400;500;600;700;800&display=swap"
          rel="stylesheet"
        />
      </head>
      <body style={{ margin: 0, padding: 0, overflow: 'hidden', background: '#030712' }}>
        {children}
      </body>
    </html>
  );
}
