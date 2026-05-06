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

## Other

| Crate | Description |
|-------|-------------|
| `baez-duarte/` | Original Báez-Duarte exploration (early, pre-cathedral-utils) |

---

## Archive

**21 archived experiments** in `archive/` — see [archive/README.md](archive/README.md) for provenance.

## Data

- `cache/` — Active OOC certificates and cached coefficient files
- Each experiment stores results in its own `results/` subdirectory
