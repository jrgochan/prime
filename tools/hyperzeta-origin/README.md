# HYPERZETA — Origin

> *March 27, 2026 — The spark that started the Cathedral*

The original Project HYPERZETA viewer, restored from commits `bdcf51a0` and
`5ddd47f6` — the very first night this project existed. 150,000 sedenion
lattice points computing ζ_𝕊(s) on the critical line Re(s) = ½ in real time.

## What it shows

Each particle represents a 16-dimensional sedenion search vector.  The engine
continuously sweeps the imaginary height t upward, computing an 8-term
Dirichlet series ζ(s) = Σ n⁻ˢ at each point.  The 3D projection plots the
*output* of ζ, not the input.

When the sweep reaches a non-trivial zero (t ≈ 14.134...):

```
cloud → spirals → rings → circle → dot → circle → rings → spirals → cloud
```

The **Collapse** metric tracks the average output magnitude — it drops toward
zero at each zeta zero, then climbs again between zeros.

## Running

```bash
cd tools/hyperzeta-origin
npm install
npm run dev        # http://localhost:3001
```

## Rebuilding the WASM engine

The Rust source is preserved in `core-engine/`:

```bash
cd core-engine
wasm-pack build --target web --release
cp pkg/core_engine* ../src/wasm/
```

## Architecture

```
core-engine/src/
├── lib.rs     — HyperEngine: 150K particles, tick_physics(), collapse metric
└── math.rs    — Cayley-Dickson tower: ℝ → ℂ → ℍ → 𝕆 → 𝕊₁₆
                 with sedenion exp() for Dirichlet series e^(-s·ln(n))

src/app/
└── page.tsx   — Single-file React/Three.js viewer
               — Zero-copy WASM SharedArrayBuffer → InstancedMesh
               — 150K particles at 120Hz on a black canvas
```

---

*This is where it all began.*
