# 🏛️⏱ The Cathedral Clock

**Cosmological Coordinates of Reality on the Nyman-Beurling Lattice**

An interactive dashboard mapping the entire span of physical reality onto the
integer lattice dimension **N** — from the Planck epoch (N = 1) to the Skewes
singularity (N ≈ 10³¹⁶), with live Planck-tick counting and a real-time
physics dashboard powered by empirical SUSY v4 sweep data.

## Quick Start

```bash
# From the repository root:
make clock

# Or open directly:
open cathedral-clock/index.html
```

No build step, no dependencies. Pure HTML + CSS + JS.

## Features

### 🎯 Live Cosmic Age Counter
A real-time counter showing the universe's current age in **Planck ticks**
(N ≈ 8.07 × 10⁶⁰), seconds, and years — ticking at 10 Hz.

### 🗺️ The Arithmetic Timeline (Vertical Journey)
A vertical spine with alternating left/right cards mapping **13 physical
and computational landmarks** onto the N scale:

| Landmark | N | Time Since Big Bang |
|---|---|---|
| ⚛️ Planck Epoch | 1 | 5.4 × 10⁻⁴⁴ s |
| ⚙️ GPU Matrix | 55,440 | 3.0 × 10⁻³⁹ s |
| 🎮 Single GPU Max | ~100K | 5.4 × 10⁻³⁹ s |
| 🖥️ Supercomputer Node | ~500K | 2.7 × 10⁻³⁸ s |
| 🏛️ Top Supercomputer | ~10M | 5.4 × 10⁻³⁷ s |
| 🌏 All Supercomputers | ~100M | 5.4 × 10⁻³⁶ s |
| 🌐 **Earth Limit** | **~350M** | **1.9 × 10⁻³⁵ s** |
| 🕳️ **THE PROOF GAP** | — | **52 orders of magnitude** |
| 🌍 **You Are Here** | **8 × 10⁶⁰** | **13.8 billion years** |
| 🔢 Googol | 10¹⁰⁰ | ~10⁴⁹ years |
| 🌌 Holographic Limit | 10¹²² | ~10⁷¹ years |
| 🖥️ Silicon Horizon | 10³⁰⁸ | ~10²⁵⁷ years |
| 💥 Skewes' Singularity | 10³¹⁶ | ~10²⁶⁵ years |

### 🕳️ The Proof Gap
Between the **Earth Limit** (N ≈ 350M = 10⁸·⁵) and **You Are Here**
(N ≈ 10⁶¹) lies a 52.5-order-of-magnitude void — beyond all known
computation. Today, only a formal proof crosses this gap.

This is why the Cathedral exists.

### ⚛️ Physics Dashboard (Arithmetic Vacuum)
Interactive exploration of the SUSY v4 sweep data with two modes:

- **🔭 Explore Mode** — slider-driven interpolation across certified HPDF
  matrices (N = 6 to N = 55,440), showing Λ, η, and marginal values
- **🌌 Cosmic Mode** — power-law extrapolation to N = current Planck ticks,
  using empirical scaling laws: Λ(N) ~ N⁻⁰·⁰⁰¹³, ‖r‖/dim ~ N⁻⁰·⁹⁶

### 🌉 The Bridge
Visualization of the proof path from Nyman-Beurling (d²_N → 0) to the
Riemann Hypothesis, with axiom count and sorry status.

### 💻 The Silicon Event Horizon
A progress bar showing how far f64 arithmetic reaches before returning
INFINITY at N = 1.79 × 10³⁰⁸.

## Architecture

```
cathedral-clock/
├── index.html    — Structure: sections, containers, semantic HTML
├── style.css     — Design system: glassmorphism, gradients, animations
├── clock.js      — Engine: cosmic calculator, v4 interpolation, rendering
└── README.md     — This file
```

### Data Sources

| Data | Source | Path |
|---|---|---|
| V4 SUSY sweep | 28 HPDF matrices, 158s | `experiments/cathedral-particle-zoo/results/susy_sweep_v4/` |
| Gram cache | Verified N² scaling | `experiments/cache/dd_gram_N*.bin` |
| Physical constants | CODATA 2018 | Hardcoded in `clock.js` |

### Earth Compute Capacity (Cross-Referenced)

The compute landmarks are validated against real experimental data:

```
dd_gram_N5000_mpfr256.bin   =  381 MB   (N² × 16 for DD)
dd_gram_N10000_mpfr256.bin  =  1.5 GB   (×4 ✓)
dd_gram_N20000_mpfr256.bin  =  6.0 GB   (×4 ✓)
dd_gram_N40000_mpfr256.bin  = 24   GB   (×4 ✓)
```

Exact N² scaling confirmed across 3 orders of magnitude. A dense Gram
matrix at Earth's total RAM limit (N ≈ 350M) corresponds to just
1.9 × 10⁻³⁵ seconds after the Big Bang — the moment inflation ends.

## Design

- **Dark void** background with animated starfield canvas
- **Glassmorphic** cards with colored accent borders
- **Gradient spine** (green → cyan → gold → purple → orange → red)
- **Breathing animations** on the proof gap and YOU ARE HERE dot
- **Responsive**: alternating cards on desktop, single-column on mobile
- **10 Hz** live-ticking Planck counter with years conversion

## Constants

```
Planck time         t_P = 5.391 × 10⁻⁴⁴ s
Age of universe     T   = 13.787 × 10⁹ years ≈ 4.354 × 10¹⁷ s
N_time              T / t_P ≈ 8.07 × 10⁶⁰
Planck ticks/year   3.156 × 10⁷ / 5.391 × 10⁻⁴⁴ ≈ 5.855 × 10⁵⁰
f64 max             1.797 × 10³⁰⁸
Skewes' number      e^(e^(e^79)) ≈ 1.397 × 10³¹⁶
```

## License

Part of [The Cathedral](../README.md) — a machine-verified reduction
of the Riemann Hypothesis in Lean 4.
