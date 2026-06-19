# Contributing to The Cathedral

Thank you for your interest in contributing to the Cathedral — a machine-verified
reduction of the Riemann Hypothesis in Lean 4.

## Current Status (v26 — Penta-Crown, June 19 2026)

The crown theorem `baez_duarte_forward` depends on **1 axiom**
(`overcancellation_axiom`, formally equivalent to RH) plus
2 PNT bureaucracy axioms (unconditional, provable from Mathlib's PNT infrastructure).
The forward chain has **zero sorry** and **zero warning**.

## How Can I Help?

### 1. Close the Crown Axiom

The crown path depends on **1 axiom ≡ RH**. Closing it is equivalent to
proving the Riemann Hypothesis itself.

| # | Axiom | Content | Difficulty |
|---|-------|---------|------------|
| 1 | `overcancellation_axiom` | v^T G v ≤ 1 | ⭐⭐⭐⭐⭐ (≡ RH) |

Promising angles:
- **Fourth moment of zeta** — unconditional L⁴ control on the critical line
- **Bombieri–Vinogradov** — "RH on average" over arithmetic progressions
- **Cholesky divergence** — proving the sum Σ y²_new = d²₂ diverges
- **GCD stratum analysis** — Möbius stratum sign agreement via Glass Bridge

See [BOUNTY_BOARD.md](BOUNTY_BOARD.md) for detailed specifications.

### 2. Close PNT Bureaucracy Axioms

Two unconditional PNT axioms remain:

| # | Axiom | Content | Difficulty |
|---|-------|---------|------------|
| 2 | `frac_error_isLittleO` | Fractional-part error | ⭐⭐ (PNT infrastructure) |
| 3 | `pnt_mu_log_sq_div_k` | Möbius log-squared sum | ⭐⭐ (PNT infrastructure) |

These are unconditionally true and provable from Mathlib's PNT + PrimeNumberTheoremAnd.
Closing them is a formalization exercise, not a mathematical one.

### 3. Close Off-Path Sorries

4 `sorry` markers remain in the active tree, all off the crown path:

- `Assembly/DirectMellinBound.lean` (2) — Exploratory direct path
- `Geometry/Bernoulli/BernoulliCrown.lean` (1) — Exploratory Bernoulli path
- `Geometry/Fiber/DragonfruitNegativity.lean` (1) — Exploratory fiber path
- `Physics/Bridges/DedekindReciprocity.lean` (1) — Dedekind reciprocity

### 4. Contribute to Mathlib

Several Mathlib PRs would unlock further improvements:

- **Gauss digamma formula** at rational arguments (`ψ(p/q)`)
- **Hadamard factorization** for entire functions of order 1
- **Riemann–von Mangoldt formula** N(T) for ζ
- **Signed Wiener-Ikehara theorem** (extension of PrimeNumberTheoremAnd)
- **Fourth moment of zeta** (Ingham, Heath-Brown)

### 5. Run Experiments

- Extend `nb-witness-scan` to N = 120,000+ (DD-precision)
- Explore Möbius stratum convergence at large HC numbers
- Validate Cholesky extraction scaling y²_new(k) ~ c/k² ln k
- Run spectral diagnostics beyond N = 55,440

## Building

```bash
# Lean proofs
cd proofs && lake build    # 504 files, 8818+ jobs

# Papers (all 18)
cd papers && ./build.sh

# Rust experiments (any one)
cd experiments/hilbert-spectral && cargo run --release -- --N 1000
```

## Requirements

- **Lean 4**: v4.29.0 or later
- **Mathlib**: via lakefile (includes PrimeNumberTheoremAnd)
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
