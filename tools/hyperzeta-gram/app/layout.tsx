import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "HyperZeta Gram — 3D Gram Matrix Visualizer",
  description: "Interactive 3D visualization of the Vasyunin Gram matrix G(j,k) for the Nyman-Beurling Riemann Hypothesis framework.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap"
          rel="stylesheet"
        />
      </head>
      <body style={{
        margin: 0,
        padding: 0,
        background: '#050508',
        color: '#ffffff',
        fontFamily: "'Inter', sans-serif",
        overflow: 'hidden',
        width: '100vw',
        height: '100vh',
      }}>
        {children}
      </body>
    </html>
  );
}
