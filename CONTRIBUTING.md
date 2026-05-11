# Contributing to The Cathedral

Thank you for your interest in contributing to the Cathedral — a machine-verified
reduction of the Riemann Hypothesis in Lean 4.

## Current Status (v17 — Oracle Capstone, Dual Crown)

The crown theorem `nyman_beurling_equivalence` depends on **1 literature axiom**
(verified by `#print axioms`). The forward chain from RH to d²_N → 0 is a
continuous, compiler-verified path with **zero sorry** and **zero warning**.

## How Can I Help?

### 1. Close the Crown Axiom

The crown path depends on **1 axiom**. Closing it makes the reduction
fully machine-verified (zero axioms).

| # | Axiom | Content | Difficulty |
|---|-------|---------|------------|
| 1 | `baez_duarte_forward` | RH → ∀ε>0, ∃N₀, ∀N≥N₀, ∃v: d²_N < ε | ⭐⭐⭐⭐ |

See [BOUNTY_BOARD.md](BOUNTY_BOARD.md) for detailed specifications with
existing infrastructure, Mathlib status, and graduation paths.

### 2. Close an Alternative-Path Axiom

The alternative forward paths use **2–4 axioms** each. Closing these strengthens
the alternative chains:

- `critical_line_mellin_variance` — Mellin Crown (⭐⭐⭐⭐)
- `rh_zeta_lower_bound_from_zero_counting` — shared Hadamard bound (⭐⭐⭐⭐⭐)
- `covariance_bound` — Virial theorem (⭐⭐⭐)
- `pnt_mu_log_div_k` — Σ μ(k)log(k)/k → -1 (⭐⭐, 95% complete)
- `partial_integral_tends_to_formula` — Vasyunin convergence (⭐⭐⭐⭐)

### 3. Close Off-Path Sorries

17 `sorry` markers remain in the active tree, all off the crown path:

- `PNT/Bridge.lean` (2) — Forward Tauberian gap (needs Mathlib)
- `PNT/LogBridge.lean` (1) — Same Tauberian gap
- `PNT/UnconditionalMertens.lean` (8) — Scaffold for unconditional Mertens
- `Covariance/CovarianceAbel.lean` (2) — Deprecated spatial integrals
- `Covariance/AbelCovarianceBound.lean` (1) — Off-path Abel covariance
- `Covariance/EulerProduct.lean` (1) — Off-path Mertens third
- `Covariance/MertensBridge.lean` (1) — Off-path Mertens bridge
- `Assembly/QualitativeForward.lean` (1) — Off-path PNT convergence

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
- Run `character-spectral` Mersenne probe to higher N (currently N = 10⁹)
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

- **Lean 4**: v4.29.0 or later
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
