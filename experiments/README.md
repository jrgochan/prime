# 🔬 Experiments — The Cathedral Numerical Engine

All experiments use **256-bit MPFR** or **DD (~31 digit)** precision unless noted.
Shared mathematics lives in `cathedral-utils/`. Archived experiments are in `archive/`.

> **To add an experiment**: create `experiments/<descriptive-name>/`, add to workspace `Cargo.toml`, add a line below.
>
> **To retire an experiment**: `git mv experiments/foo experiments/archive/foo`, update workspace paths.

---

## Shared Library

| Crate | Description |
|-------|-------------|
| `cathedral-utils/` | Canonical math library — arith, gram, DD, abel, mertens, constants, cache, OOC, GPU |

---

## Compute Engines

| Crate | Description | Key Output |
|-------|-------------|------------|
| `nb-distance-gpu/` | Primary GPU solver: cuBLAS matvec + cuSOLVER Cholesky + OOC streaming + CG-DD | d²(N) certificates |
| `gram-scaling-oracle-gpu/` | MPFR-256 Gram matrix builder (GPU parallel, OOC binary output) | `ooc_gram_N*.bin` |
| `gram-scaling-oracle/` | CPU MPFR-256 Gram matrix builder | Gram matrices |
| `nb-distance/` | CPU-only NB distance solver (DD CG) — fallback for non-GPU | d²(N) |

## Certificates & Validation

| Crate | Description | Validates |
|-------|-------------|-----------|
| `certified-distance/` | Multi-tier d² pipeline — JSON certificates for N=100..55,440 | Crown d² claims |
| `mellin-certificate/` | Parseval bridge cross-validation (MPFR-256) | `parseval_bridge_white` |
| `crown-cancellation/` | ζ(s)·D_N(s) ≈ -1 on critical line (512-bit MPFR) | `MellinCrown` axiom |
| `pnt-mobius-sums/` | PNT sum convergence: S₁→0, S₂→-1, S₃→-2γ | `PNT/` axioms |
| `perron-contour/` | Perron contour integral vs direct M(x) comparison | `Perron/` chain |
| `norm-bound-validator/` | ζ norm bound on Borel-Carathéodory disks | `Zeta/` bounds |
| `fejer-kernel/` | Fejér kernel axiom validation (FK2, FK3, FK4) | `Analysis/` |
| `vasyunin-convergence/` | Partial sum → Vasyunin formula convergence | `Vasyunin/` |
| `vasyunin-integral/` | Vasyunin integral verification | `Vasyunin/` |
| `littlewood-maneuver/` | Three-Circles axiom constants certification | `Zeta/` |

## Spectral Analysis

| Crate | Description | Key Output |
|-------|-------------|------------|
| `spectral-observatory/` | Eigenvalue DOS, quantum decoupling, viewport data | Observatory JSON |
| `spectral-road/` | Road 2 (eigenvalue decay) and Road 3 (GRH verification) | Spectral certificates |
| `van-hove-probe/` | DOS, level spacing, thermodynamics of Gram matrix (128-bit) | Van Hove analysis |
| `hilbert-spectral/` | π constant certification for Hilbert inequality | `Analysis/` |

## NB Witness Scan

| Crate | Description | Key Output |
|-------|-------------|------------|
| `nb-witness-scan/` | Systematic d² for N=2..10,000 using explicit Möbius log-cutoff weights | `d_sq_decay.tsv` |
| `nb-witness-scan-gpu/` | GPU-accelerated witness scan (scaffolding for N=120k+) | — |

## Algebraic Structure

| Crate | Description | Key Output |
|-------|-------------|------------|
| `character-spectral/` | Mersenne probe to N=10⁹ — the Particle Zoo | Character spectral data |
| `rotor-spectroscopy/` | Mod-8 energy partition, Gallagher MVT, dispersion | Stained Glass data |
| `siegel-walfisz/` | PNT-in-arithmetic-progressions for q=8 | Siegel-Walfisz bounds |
| `moebius-microscope/` | Möbius cancellation decomposition by GCD, rotor, Vaughan, Liouville | Microscope analysis |

## Vasyunin & Two-Tile

| Crate | Description | Validates |
|-------|-------------|-----------|
| `vasyunin/` | Multi-attack suite for Vasyunin identity proof | `Vasyunin/` (39 files) |
| `two-tile-decomposition/` | Two-tile correction term analysis | `Vasyunin/Cotangent/` |
| `two-tile-decomposition-gpu/` | GPU-accelerated two-tile computation | `Vasyunin/Cotangent/` |
| `two-tile-analyzer/` | Two-tile correction analyzer (512-bit MPFR) | `Vasyunin/Cotangent/` |
| `series-decomposition-verifier/` | Series decomposition verification | `Vasyunin/` |

---

## Archive

**22 archived experiments** in `archive/` — see [archive/README.md](archive/README.md) for provenance.

All 30 active experiments depend on `cathedral-utils` — zero local math duplications.

## Data

- `cache/` — Active OOC certificates and cached coefficient files
- Each experiment stores results in its own `results/` subdirectory

---

## 🏗️ Code Quality Bounty — Production-Grade Hardening

**Status**: `make lint` → ✅ zero clippy warnings (as of June 2026)
**Goal**: Zero warnings *without* crate-level `#![allow(...)]` suppression

### Current State

The experiment crates currently compile warning-free via blanket `#![allow(...)]`
directives at the crate root (e.g. `dead_code`, `unused_variables`, `unused_imports`,
`unused_assignments`, `clippy::needless_range_loop`). This was a necessary first step
to get the full workspace to green, but it **masks real issues** that should be
fixed properly.

### The Bounty

We're looking for contributions that incrementally harden individual experiment
crates toward production-grade Rust:

| Task | Difficulty | Impact |
|------|-----------|--------|
| **Remove a `#![allow(...)]` and fix the underlying warnings** | ⭐–⭐⭐ | High — each removal makes real bugs visible |
| **Replace `dead_code` allows with proper `pub` visibility or deletion** | ⭐ | Medium — clarifies public API surface |
| **Replace `unused_variables` allows with `_` prefixes or removal** | ⭐ | Medium — documents intentional vs accidental unused code |
| **Fix `needless_range_loop` with idiomatic iterators** | ⭐⭐ | Medium — cleaner, faster Rust |
| **Add unit tests to experiment binaries** | ⭐⭐–⭐⭐⭐ | Very high — currently untested |
| **Extract shared patterns into `cathedral-utils`** | ⭐⭐⭐ | Very high — reduces duplication |

### How to Contribute

1. Pick an experiment crate (start small — `bilinear-probe/` or `hc-gram-oracle/`)
2. Remove one `#![allow(...)]` item from the crate root
3. Fix every warning that surfaces — properly, not with more suppression
4. Run `make lint` to verify the full workspace stays green
5. Submit a PR with the crate name in the title (e.g. `chore(bilinear-probe): remove dead_code allow`)

### Priority Crates

These crates are most likely to benefit from hardening (high reuse, complex logic):

- `cathedral-utils/` — the shared math library, used by all 30+ experiments
- `nb-distance-gpu/` — primary GPU solver, production-critical
- `overcancellation-scan/` — largest crate, 25+ binaries, most lint suppression
- `spectral-factorization-probe-gpu/` — GPU eigendecomposition pipeline

> **Rule**: every PR that removes a `#![allow(...)]` and fixes the underlying
> issues is a good PR. The end state is a workspace where `make lint` passes
> with **zero warnings and zero suppression directives**.
