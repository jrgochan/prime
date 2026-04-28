# Contributing to The Cathedral

Thank you for your interest in contributing to the Cathedral — a machine-verified
reduction of the Riemann Hypothesis in Lean 4.

## Current Status (v12 — Crown Graduation)

The crown theorem `nyman_beurling_equivalence` depends on **2 mathematical axioms**
(verified by `#print axioms`). The forward chain from RH to d²_N → 0 is a
continuous, compiler-verified path with **zero sorry** and **zero warning**.

## How Can I Help?

### 1. Close a Crown Axiom

The crown path depends on **2 axioms**. Closing either one makes the reduction
strictly stronger.

| # | Axiom | Content | Difficulty |
|---|-------|---------|------------|
| 1 | `critical_line_mellin_variance` | RH → Mellin L² variance ≤ C/logN | ⭐⭐⭐⭐ |
| 2 | `rh_zeta_lower_bound_from_zero_counting` | RH → |ζ(s)| ≥ c/|t|^A | ⭐⭐⭐⭐⭐ |

See [BOUNTY_BOARD.md](BOUNTY_BOARD.md) for detailed specifications with
existing infrastructure, Mathlib status, and graduation paths.

### 2. Close a Spatial-Path Axiom

The spatial (alternative) path uses **4 axioms**. Closing these strengthens
the alternative chain:

- `covariance_bound` — Virial theorem (⭐⭐⭐)
- `pnt_mu_log_div_k` — Σ μ(k)log(k)/k → -1 (⭐⭐, 95% complete)
- `partial_integral_tends_to_formula` — Vasyunin convergence (⭐⭐⭐⭐)
- `rh_zeta_lower_bound_from_zero_counting` — shared with crown (⭐⭐⭐⭐⭐)

### 3. Close Off-Path Sorries

16 `sorry` markers remain in the active tree, all off the crown path:

- `PNT/Bridge.lean` (2) — Forward Tauberian gap (needs Mathlib)
- `PNT/LogBridge.lean` (1) — Same Tauberian gap
- `Covariance/CovarianceAbel.lean` (2) — Deprecated spatial integrals
- `Covariance/QuadFormIdentity.lean` (1) — Numerically falsified (deprecated)
- `Scratch/*` (10) — Exploratory files

### 4. Contribute to Mathlib

Several Mathlib PRs would unlock axiom closures:

- **Gauss digamma formula** at rational arguments (`ψ(p/q)`)
- **Hadamard factorization** for entire functions of order 1
- **Weierstrass canonical product**
- **Riemann–von Mangoldt formula** N(T) for ζ
- **Signed Wiener-Ikehara theorem** (extension of PrimeNumberTheoremAnd)

### 5. Run Experiments

- Extend `hilbert-spectral` to larger N (512-bit MPFR, massively parallel)
- Extend `siegel-walfisz` beyond N = 10⁹
- Explore new spectral diagnostics

## Building

```bash
# Lean proofs
cd proofs && lake build

# Rust experiments (any one)
cd experiments/hilbert-spectral && cargo run --release -- --N 1000

# Papers
cd papers && ./build.sh
```

## Requirements

- **Lean 4**: v4.30.0-rc1 or later
- **Mathlib**: via lakefile
- **Rust**: 1.75+ (for experiments, with `rug` crate for MPFR)
- **LaTeX**: pdflatex (for papers)

## Project Structure

See [README.md](README.md) for the full architecture.
See [OVERVIEW.md](OVERVIEW.md) for the detailed proof chain.
See [BOUNTY_BOARD.md](BOUNTY_BOARD.md) for open problems.
See [ORIGIN-STORY.md](ORIGIN-STORY.md) for how the project began.

## Code Style

- Follow Mathlib conventions for Lean code
- Each file should have a module docstring explaining its role
- Axioms go in `Axioms.lean` with tier annotations
- Crown path modifications must maintain zero sorry, zero warning

## License

Apache 2.0 — all contributions are under the same license.
