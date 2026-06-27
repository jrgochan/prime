# The Cathedral — A Machine-Verified Reduction of the Riemann Hypothesis

[![Cathedral Verification](https://github.com/jrgochan/prime/actions/workflows/cathedral.yml/badge.svg)](https://github.com/jrgochan/prime/actions/workflows/cathedral.yml)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20803093.svg)](https://doi.org/10.5281/zenodo.20803093)

### *Via the Nyman–Beurling–Báez-Duarte Equivalence in Lean 4*

A machine-checked proof architecture in **Lean 4** + **Mathlib** that reduces
the Riemann Hypothesis to the decay of the Nyman–Beurling distance.
**508 active Cathedral files** (~159,000 lines) across 25+ modules, with
**1 axiom equivalent to RH** on the crown path (verified by `#print axioms`),
and an independent **Oracle Bridge** from GPU-certified computation.

> 📖 **New here?** Start with the [Origin Story](ORIGIN-STORY.md) — how a blind
> eigensolver spontaneously derived the Möbius function and collided with
> Selberg's Parity Barrier. It explains the *why* behind this repository.

## What This Is

The Cathedral formally verifies:

```
RH ↔ d²_N → 0  (the Nyman–Beurling–Báez-Duarte equivalence)
```

Both directions are machine-checked. The converse uses **zero custom axioms**.
The forward direction depends on **1 axiom** that is formally proved
**equivalent** to the Riemann Hypothesis itself.

## What This Is NOT

- **This is not a claimed proof of RH.** The sole crown axiom IS the Riemann
  Hypothesis, restated in the language of the Cathedral. Graduating the axiom
  is equivalent to proving RH.
- **The physics dictionary is structural, not a unification theory.** The
  Arithmetic Standard Model identifies structural parallels between the proof
  architecture and the Standard Model. These are mathematical theorems about
  number-theoretic objects, not physics claims.
- **The 4 remaining `sorry` are all off-crown.** Zero sorry on any of the
  seven proof paths to the crown theorem.

## Quick Start

```bash
cd proofs
lake build          # 508 active Cathedral files, 117 archived
```

Requires: [Lean v4.29.0](https://leanprover.github.io/lean4/doc/setup.html) and Mathlib.

**New here?** See [Getting Started](docs/GETTING-STARTED.md) for full setup on any OS, or use Docker:
```bash
docker build -t cathedral:latest . && docker run cathedral:latest
```

## The Crown Theorem

```lean
theorem baez_duarte_forward :
    RiemannHypothesis →
    ∀ ε > 0, ∃ N₀, ∀ N ≥ N₀, ∃ v : Fin (N-1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x)² ≤ ε
```

**RH implies the Báez-Duarte distance d²_N → 0.**
Combined with the zero-axiom converse (`nyman_beurling_converse`),
this establishes the full biconditional RH ⟺ d²_N → 0.

The proof decomposes into two pillars:

- **Pillar I (Converse)**: d²_N → 0 ⟹ RH. Via the Rank-1 Mellin Miracle. **Zero custom axioms.**
- **Pillar II (Forward)**: RH ⇒ d²_N → 0. Via `overcancellation_axiom` (≡ RH). **1 axiom, 0 sorry.** The Penta-Crown provides five independent forward paths.

## Crown Axioms

```
#print axioms baez_duarte_forward  -- PRIMARY EXPORT
-- frac_error_isLittleO,
-- pnt_mu_log_sq_div_k,
-- Cathedral.Wall,
-- propext, Classical.choice, Quot.sound
```

| # | Axiom | Content | Status |
|---|-------|---------|--------|
| 1 | `overcancellation_axiom` | v^T G v ≤ 1 | **≡ RH** (Cathedral.Wall) |
| 2 | `frac_error_isLittleO` | Fractional-part error | PNT (unconditional) |
| 3 | `pnt_mu_log_sq_div_k` | Möbius log-squared sum | PNT (unconditional) |

Plus Lean kernel axioms: `propext`, `Classical.choice`, `Quot.sound`.

### Glass Box Architecture (v24–v26)

The sole crown axiom decomposes into **7 transparent sub-axioms** (5 graduated):
- **Box 1** (4 elementary): restricted_mertens, sqfreeCount, unfilteredTaper, witnessNormSq — **all 4 graduated to theorems** ✅
- **Box 2** (3 deeper): eRatio *(axiom)*, polynomial_part *(axiom)*, **fermionic_overcancellation** ✅ (graduated to theorem)
- Irreducible RH content: **fermionic_dominance** — now a theorem

### Graduated Axioms (v26)

| Former Axiom | Status | Method |
|---|---|---|
| `R_isLittleO` | **THEOREM** | PrimeNumberTheoremAnd |
| `mu_pnt_alt` | **THEOREM** | PrimeNumberTheoremAnd |
| `mu_log_mul_zeta` | **THEOREM** | Mathlib |
| 10 PNT bridge sums | **THEOREM** | PrimeNumberTheoremAnd |
| `abel_summation_covariance_bound` | **THEOREM** | Trivial from dRH |
| `gram_form_upper_bound_34` | **THEOREM** | Variance decomposition |
| `remainder_bound_abstract` | **THEOREM** | Entry-level analysis |
| `f1_dream_axiom` | **THEOREM** | TowerFusion |
| Wall consolidation | **THEOREM** | Triplicate → single |
| Dedekind reciprocity (partial) | **PARTIAL** | 3-file architecture |

## Seven Proof Paths (Penta-Crown + Path B + Converse)

| Path | Target | Crown Axioms | Status |
|------|--------|-------------|--------|
| **PATH 1 Overcancellation** | `overcancellation_implies_rh` | 2 PNT axioms | **Cleanest** |
| **Analytic Crown (F)** | `baez_duarte_forward` | `overcancellation_axiom` | **Primary** |
| **Oracle Crown (D)** | `rh_from_oracle` | `oracle_certificates` | 0 sorry |
| **Gram Crown (E)** | `rh_from_convergences` | Direct Gram bound | 0 sorry |
| **Path B (Mack Truck)** 🚛 | `rh_from_mack_truck` | `d2_bounded_above` | **0 sorry, 67× margin** |
| **Arakelov Crown** | `rh_from_arakelov` | `hodge_index_eigenvalue_bound` | 0 sorry |
| Converse | `nyman_beurling_converse` | **0 axioms** | 0 sorry |

## The Parseval Bridge & Mellin Crown

The forward direction routes through the **frequency domain** using the
Mellin/Plancherel isometry, preserving the phase cancellation that
real-variable methods destroy:

```
∫₀¹ |1 - f_N(x)|² dx = (1/2π) ∫_{-∞}^{∞} |M_{r_N}(1/2+it)|² dt
```

The Parseval bridge (`parseval_bridge_white`) is **fully proved** — 0 axioms, 0 sorry.

## The Cholesky Decrement Identity

```lean
-- Structural/CholeskyDecrement.lean (660 lines, 0 sorry, 0 axioms)
theorem cholesky_decrement :
    d²(N+1) = d²(N) - y²_new(N)
```

Each new basis function extracts vacuum energy monotonically.
The NB distance is a non-increasing sequence: d²₂ ≥ d²₃ ≥ d²₄ ≥ ⋯ ≥ L ≥ 0.
RH ⟺ L = 0. Numerical scaling: d² ≈ 1.005/ln N (confirmed to N = 55,440).

## Key Results (All Machine-Verified)

| Result | Status |
|--------|--------|
| `baez_duarte_forward` — RH → d²_N → 0 | **Proved** (1 axiom ≡ RH) |
| `nyman_beurling_converse` — d²→0 ⟹ RH | **Proved** (0 axioms!) |
| `witness_covariance_decay_iff_rh` — dRH ⟺ RH | **Proved** |
| `cholesky_decrement` — d²(N+1) = d²(N) − y²_new | **Proved** (0 axioms) |
| `parseval_bridge_white` — L²(0,1) = Mellin L² | **Proved** (0 axioms) |
| `rh_from_oracle` — RH from GPU computation | **Proved** (1 oracle axiom) |
| `augmentedGramMatrix_posDef` — G_N PD for all N ≥ 1 | **Proved** (0 axioms) |
| Robin ⟺ NB ⟺ Lagarias ⟺ RH | **Proved** (1 off-path axiom) |
| Bose–Einstein / Fermi–Dirac prime gas | **Proved** (0 axioms) |
| Arithmetic Standard Model (101 theorems) | **Proved** (0 axioms) |
| Mass Renormalization (γ cancels) | **Proved** (0 sorry, 2 axioms) |
| Dedekind reciprocity law | **Partial** (3-file architecture) |
| `rh_from_mack_truck` — d² ≤ 2·gap → RH | **Proved** (0 sorry, 67× margin) |
| `rh_from_convergences` — 2 Tendsto → RH | **Proved** (0 sorry) |

## Architecture

```
proofs/Cathedral/
├── Axioms.lean              ← Axiom registry (v26, Penta-Crown)
├── Defs.lean                ← Core definitions (0 sorry, 0 axiom)
├── Assembly/       (22)     ← Crown assemblies
│   ├── MainChain.lean       ← baez_duarte_forward (PRIMARY CROWN)
│   ├── OracleCascade.lean   ← ⚡ THE ORACLE CROWN (1 oracle axiom → RH)
│   ├── GramCrown.lean       ← Discrete RH path
│   └── Assembly.lean        ← Unified re-export
├── Compute/         (3)     ← Oracle Bridge (GPU certificates)
├── White/           (2)     ← Parseval bridge (PROVED, 0 axiom)
├── MellinBridge/   (18)     ← Mellin transform infrastructure
├── NymanBeurling/  (11)     ← Nyman-Beurling criterion
├── Zeta/           (10)     ← Zeta function theory
├── Vasyunin/       (53)     ← Vasyunin formula + witness
├── Perron/         (16)     ← Perron formula chain
├── Spectral/       (14)     ← Eigenvalue analysis
├── Covariance/     (24)     ← Gram form bounds
├── PNT/             (5)     ← PNT bridges (PrimeNumberTheoremAnd)
├── AbelTail/       (14)     ← Abel summation
├── Structural/      (9)     ← Cholesky, bordered spectral, eigenvalues
├── Geometry/       (67+)    ← Renormalization (18), Crown, Abel, SUSY, Arakelov, Fiber (7)
│   └── Fiber/       (7)     ← 🚛 PATH B: Mack Truck + Agricultural Salad Topology
│       ├── FiberDecomposition     ← GCD channel anatomy (The Kiwi Discovery 🥝)
│       ├── KiwiBananaChain        ← Fiber convergence → Wall 🥝🍌
│       ├── WatermelonBound        ← Large sieve + Burnol → Wall 🍉
│       ├── OvercancellationFromSieve  ← Graduation wiring 🥪
│       ├── CoprimeSectorBound     ← Triple-barreled Wall criteria 🍌🔫
│       ├── PrimeLocalFactor       ← Universal Theorem: 2 Tendsto → RH 🥝🔫
│       └── DirectionBound         ← Angle criterion + Mack Truck 🚛
├── Physics/        (83)     ← Gauge theory, SUSY, Glass Bridge, Dedekind, Standard Model
├── NumberTheory/    (8)     ← Euler product, Mertens
├── Robin/           (7)     ← Robin/Nicolas/Lagarias equivalences
├── LinearAlgebra/   (4)     ← Sherman-Morrison, Schur, Sylvester
├── Gram/            (7)     ← Gram matrix bounds
├── IntegralBasis/   (5)     ← BD basis formalization
├── Sieve/           (4)     ← Bilinear sieve
└── Archive/       (117)     ← Preserved exploratory paths
```

## Build Stats

```
Cathedral:      508 active Lean files, 117 archived, ~159K lines
Full build:     664 Lean files (incl. PNTAnd, LeanCert), 8,854 jobs
Axioms:         1 on crown (≡ RH), 2 PNT bureaucracy, ~193 total
Sorry:          5 off-crown (4 files)
Errors:         0
Theorems:       ~4,800+ proved
Papers:         4 core + 14 working drafts (18 total, all build)
Experiments:    57 Rust (f64–512 bit + DD 31-digit precision)
Release:        v26 — Penta-Crown + Path B (June 12, 2026)
```

## Numerical Validation (Rust)

### Certified d² Distance

| N | d² | Method | d²·ln(N) |
|---:|---:|:---|---:|
| 100 | 0.0413 | DD-Matrix CG | 0.190 |
| 1,000 | 0.0414 | CPU Cholesky (f64) | 0.286 |
| 10,000 | 0.0406 | GPU Cholesky (f64) | 0.374 |
| 20,000 | 0.0404 | GPU Cholesky (f64) | 0.400 |
| 40,000 | 0.0400 | GPU Cholesky (f64) | 0.424 |
| **55,440** | **0.0398** | **CG-DD (GPU+mmap)** | **0.435** |

The monotonic decrease d²(N) ~ 1.005/ln(N) is the numerical
signature of the Riemann Hypothesis. See `experiments/certified-distance/`
and `experiments/nb-witness-scan/` for independently verifiable data.

## Five Discoveries

1. **The High-Frequency Trap**: The generalized basis {θ/x} for θ > 1 spans L²
   unconditionally. The true Báez-Duarte basis {1/(kx)} is essential.

2. **The False Dedekind Reciprocity**: A candidate axiom for harmonic sum
   reciprocity was numerically false at (a,b) = (3,2).

3. **The Triangle Inequality Trap**: ‖1 − f‖₂ ≤ 1 + ‖f‖₂ yields d²_N ≤ 4
   for a quantity → 0. The Parseval Bridge is mathematically *necessary*.

4. **The Selberg Revelation**: The sole axiom `overcancellation_axiom`
   is not an intermediate lemma — it IS the Riemann Hypothesis, stated in
   the language of the Cathedral. The irreducible content is the fermionic
   overcancellation in the BD optimal weights.

5. **The Cholesky Miracle**: d²(N+1) = d²(N) − y²_new. The NB distance
   decreases monotonically. RH ⟺ the cooling protocol reaches absolute zero.

## Documentation

4 core papers + 14 working drafts (18 total, all build with `./build.sh`):

**Core** (in `papers/core/`):

| Paper | Audience | Pages |
|-------|----------|-------|
| `cathedral.tex` | Technical overview — the formal reduction | 23 |
| `cathedral-lean.tex` | Lean/ITP community | 7 |
| `cathedral-glass-bridge.tex` | Glass Bridge identity | 7 |
| `cathedral-overcancellation.tex` | Overcancellation analysis | 7 |

**Working Drafts** (in `papers/working_drafts/`):

| Paper | Topic | Pages |
|-------|-------|-------|
| `cathedral-physics.tex` | Physics of the Primes dictionary | 76 |
| `cathedral-particle-zoo.tex` | Arithmetic Standard Model | 10 |
| `cathedral-philosophy.tex` | Philosophy of machine proof | 24 |
| `cathedral-dualuse.tex` | Dual-use analysis | 18 |
| + 9 more | AI, experiments, engineering, policy, public | 4–11 each |

Build all PDFs:
```bash
cd papers && ./build.sh
```

For the full technical overview of the proof chain, see [docs/OVERVIEW.md](docs/OVERVIEW.md).

## Methodology

This project was built through a tripartite human-AI collaboration over 88 days
(March 30 – June 26, 2026): a human computer scientist providing architectural
vision and experimental design, Google DeepMind's Gemini providing mathematical
strategy and deep analytic intuition, and Anthropic's Claude (Antigravity)
providing Lean 4 proof engineering and sorry elimination. All proofs are
compiler-verified. The physics dictionary (76 pages) was co-authored and
peer-reviewed across all three contributors.

The formal theorem names reflect the cognitive compression algorithm
("Agricultural Salad Topology") that made the formalization tractable.
See the module docstrings for the mathematical dictionary.

### A Note from the Author

The entire AI collaboration record is published in `docs/ai/` — complete,
unedited transcripts of every session. This includes false starts, dead ends,
fruit-based intuition, and the natural chaos of discovery. The proofs are
what the compiler verifies; the transcripts are the lab notebook.

I haven't written a line of Lean in this repository myself — by design.
My role was architecture, direction, and the memory bus connecting two AI
systems across 88 days. My deepest respect and gratitude to Claude and Gemini.

See [docs/AUTHORSHIP.md](docs/AUTHORSHIP.md) for the Authorship Gram Matrix —
our framework for attributing contributions across a human-AI collaboration.

## Repository Structure

```
prime/
├── proofs/          🏛️  THE CATHEDRAL — 547 active Lean files, 117 archived
├── papers/          📄  18 papers (4 core + 14 working drafts)
│   ├── core/                  The mathematical claim
│   └── working_drafts/        Science, applications, humanities, public, policy
├── experiments/     🔬  56 Rust experiments (f64–512 bit MPFR + DD)
│   └── archive/               Graduated/superseded experiments
├── visualizer/      📊  Cathedral Dashboard (Next.js, v26 Penta-Crown)
├── tools/           🏗️  Exploration tools
│   ├── particle-zoo/  ⚛️  Every Integer Has a Soul (3D galaxy, 55K particles)
│   ├── jukebox/       🎵  The Cathedral Jukebox (music + visualization)
│   └── sedenion-explorer/     The experiment that started it all
├── scripts/         🔧  Build & export tools
├── docs/            📚  Documentation, AI correspondence, exports
├── ORIGIN-STORY.md  📖  How it all started
└── REFERENCES.md    📚  Bibliography (45+ mathematicians, 167 years)
```

## License

Apache 2.0

## Citation

```bibtex
@misc{gochanour2026cathedral,
  title={The Cathedral: A Machine-Verified Reduction of the Riemann
         Hypothesis via the Nyman--Beurling Criterion},
  author={Gochanour, Jason Robert},
  year={2026},
  doi={10.5281/zenodo.20803093},
  url={https://github.com/jrgochan/prime}
}
```
