# Contributing to The Cathedral

Thank you for your interest in contributing to the Cathedral — a machine-verified
reduction of the Riemann Hypothesis in Lean 4.

## How Can I Help?

### 1. Eliminate an Axiom

The crown theorem depends on **7 mathematical axioms**. Each one that gets
proved as a theorem from Mathlib makes the reduction stronger.

**Low-hanging fruit** (classical analysis, likely in Mathlib or close):
- `abel_mertens_tail_raw` — Abel summation tail bounds
- `vasyunin_offdiag_integral` — Off-diagonal Gram integral identity
  (the diagonal case is already proved!)

**Medium difficulty** (requires PNT infrastructure):
- `pnt_mu_div_k` — Σ μ(k)/k → 0
- `pnt_mu_log_div_k` — Σ μ(k)log(k)/k → −1
- `pnt_mu_log_sq_div_k` — Σ μ(k)log²(k)/k → −2γ

**Hard** (deep analytic number theory):
- `rh_implies_mertens_bound` — Encodes the RH content itself
- `millennium_covariance_cancellation` — 2D covariance cancellation

### 2. Improve the Formalization

- Replace `sorry` with proofs (2 remain on alternative paths)
- Simplify existing proofs
- Improve Lean style and documentation

### 3. Run Experiments

- Extend numerical validation to larger N
- Verify additional Gram matrix entries
- Explore the spectral gap convergence rate

## Building

```bash
# Lean proofs
cd proofs && lake build

# Papers
cd papers && ./build.sh

# Experiments (any one)
cd experiments/vasyunin-integral && cargo run --release
```

## Requirements

- **Lean 4**: v4.30.0-rc1 or later
- **Mathlib**: via lakefile
- **Rust**: 1.75+ (for experiments)
- **LaTeX**: pdflatex (for papers)

## Project Structure

See [README.md](README.md) for the three-tier structure.
See [ORIGIN-STORY.md](ORIGIN-STORY.md) for how the project began.

## Code Style

- Follow Mathlib conventions for Lean code
- Each file should have a module docstring explaining its role
- Axioms go in `Axioms.lean` with tier annotations

## License

Apache 2.0 — all contributions are under the same license.
