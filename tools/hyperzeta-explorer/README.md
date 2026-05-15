# HYPERZETA Explorer — The Cayley-Dickson Tower

Extended from [HYPERZETA Origin](../hyperzeta-origin/) (March 27, 2026).  
4 visualization modes for the sedenion zeta landscape.

## Modes

| Key | Mode | What It Shows |
|-----|------|---------------|
| `1` | **ORIGIN** | Classic 150K sedenion sweep. The spark that started the Cathedral. |
| `2` | **TEARDROP** | Stereographic projection to the Riemann sphere. Zeros appear as symmetric pairs across the equator — the functional equation ξ(s)=ξ(1-s) made visible. |
| `3` | **GLASS STAIRCASE** | Energy decomposition by Cayley-Dickson layer (ℝ→ℂ→ℍ→𝕆→𝕊). Watch energy redistribute as the sweep crosses glass lift boundaries. |
| `4` | **DIVISION BY ZERO** | Möbius inverse 1/ζ(s) = Σ μ(n)/nˢ. Blue (+1) and red (-1) particles — the dark sector made visible. Non-squarefree terms vanish. |

## Running

```bash
# From the Cathedral root:
make hyperzeta-explorer

# Or directly:
cd tools/hyperzeta-explorer
npm install
npm run dev    # → http://localhost:3002
```

## Architecture

- **WASM Engine**: Rust sedenion arithmetic (Cayley-Dickson tower: ℝ→ℂ→ℍ→𝕆→𝕊)
- **Frontend**: Next.js + React Three Fiber + InstancedMesh
- **Zero-Copy**: Float32Array bound directly to WASM linear memory
- **Particle Count**: 150,000 × 16 dimensions = 2.4M coordinates per frame

## The Three New Modes

### Teardrop Sphere
Maps ζ(s) output to the Riemann sphere via stereographic projection:
- `(x,y) → (2x/(1+r²), 2y/(1+r²), (r²-1)/(1+r²))`
- At zeros: output → origin → south pole
- Conjugate pairs ρ, ρ̄ map to reflections across the equator

### Glass Staircase  
Decomposes each particle's ζ output by Cayley-Dickson level:
- **ℝ** (white): `a.a.r` — the real axis, locked to ½
- **ℂ** (blue): `a.a.i` — the imaginary height t
- **ℍ** (gold): `a.a.{j,k}` — quaternionic extension
- **𝕆** (green): `a.b` — octonionic extension  
- **𝕊** (magenta): `b` — sedenion extension

### Division by Zero
The Möbius function μ(n) acts as the inverse filter:
- μ(n) = +1 (blue): squarefree, even number of prime factors
- μ(n) = -1 (red): squarefree, odd number of prime factors
- μ(n) = 0 (invisible): contains a squared prime factor

This is the dark cathedral — the same data viewed through the Möbius glass.
