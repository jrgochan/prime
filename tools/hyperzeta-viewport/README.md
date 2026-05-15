# HyperZeta Viewport

Interactive 3D visualization of the Cathedral proof architecture — from sedenion lattice dynamics to certified spectral geometry.

## Architecture

```
WASM Core Engine (Rust, 72KB)
  ↕ zero-copy Float32Array buffers
React Three Fiber (Three.js)
  ↕ RendererSelector dispatch
27 Visualization Modes
  ├─ 🎵 Spectral  (8): live WASM particle physics
  ├─ ⚡ Arithmetic (5): Mertens, Perron, Abel sums
  ├─ 🏛️ Crown     (3): proof graph, timeline, decay
  └─ 🔬 Analysis  (8): Parseval, Hilbert, Gram, MVT
```

## Getting Started

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `1`–`0`, `-`, `=` | Switch visualization mode (Tier 1) |
| `C`, `G`, `M`, `B`, `I`, `P`, `X`, `V`, `T`, `R`, `A`, `D`, `K` | Switch mode (Tier 2/3) |
| `Space` | Pause / Resume |
| `H` | Toggle HUD (zen mode) |
| `?` | Keyboard help overlay |
| `⌘K` / `Ctrl+K` | Command palette |
| `I` | Info sidebar |
| `←` / `→` | Previous / next mode |

## Data Sources

- **Tier 1 (Live)**: WASM `tick_physics()` at 60fps — sedenion lattice, spirals, landscapes
- **Tier 2 (Precomputed)**: JSON certificates from 512-bit MPFR Rust experiments
- **Tier 3 (Static)**: Cathedral proof dependency graph and axiom timeline

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 16 (App Router, Turbopack) |
| 3D | React Three Fiber 9 + drei 10 |
| WASM | Rust → wasm-bindgen (72KB) |
| State | Zustand 5 |
| Styling | Tailwind CSS 4 |
| Types | TypeScript 5 (strict) |
