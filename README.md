# Prime — Spectral Riemann Hypothesis Formalization

A formal proof architecture for the Riemann Hypothesis in **Lean 4** against **Mathlib**,
supported by Rust-based numerical experiments.

## Architecture

The proof reduces RH to the **Nyman-Beurling criterion** (Beurling 1955) via a
**Parity Schur complement** decomposition of the Gram matrix:

```
  type_II_sieve_bound (K < 1)        ← Tier 3: Open problem
    → stable_ratio_parity (R < 1)     ← Bridge theorem (BilinearSieve.lean)
    → schur_to_distance_scaling       ← Algebraic bridge
    → nb_distance_scaling             ← d²_N ≤ C/log(N)
    → distance_converges_to_zero      ← PROVED (Assembly.lean)
    → riemann_hypothesis              ← PROVED (Assembly.lean)
```

### Zero-Sorry Core (ParitySchur.lean)

The following are proved with **zero sorry** against Mathlib:

- **Parity projections**: π₊ + π₋ = I, π₊π₋ = 0 (completeness + orthogonality)
- **Block decomposition**: G = A + B + Bᵀ + C (Liouville parity blocks)
- **Schur complement PSD**: G > 0 ⟹ A - BC⁻¹Bᵀ ≥ 0

### The Bilinear Sieve Interface (BilinearSieve.lean)

A **typed interface** encoding the exact boundary between the proved linear algebra
and the analytic number theory needed to close the final gap. Four axioms state
precisely what needs to be proved; a bridge theorem shows these axioms suffice.

## Quick Start

```bash
cd proofs
lake build          # Build all Lean proofs
```

Or use the Makefile:
```bash
make build          # Full project build (Lean + Rust)
make lean-audit     # Scan for sorry/axiom counts
make clean          # Clean all build artifacts
```

## Contributing: The 3-Tier Axiom Roadmap

This project reduces the Riemann Hypothesis to a chain of explicitly stated axioms.
We classify the remaining work into three tiers based on mathematical difficulty:

### Tier 1: Pure Linear Algebra _(PRs welcome!)_

**Targets:** `schur_variational` (axiom) and the `sorry` in `sieve_implies_stable_ratio`

These are finite-dimensional matrix algebra results:
- The variational characterization of the Schur complement quadratic form
- The optimization `2st - t² ≤ s²` applied to the bilinear bound

**No number theory required.** If you know Mathlib's `Matrix.nonsing_inv` API,
these are tractable afternoon projects.

**File:** [`proofs/SpectralRH/BilinearSieve.lean`](proofs/SpectralRH/BilinearSieve.lean)

### Tier 2: Formalizing Published Results _(PhD-level)_

**Targets:** `vasyunin_expansion` and `moebius_uncoupling`

These are NOT open mathematical problems. They formalize:
- The Báez-Duarte–Balazard–Landreau–Saias (2005) divisor-sum expansion of Gram entries
- Vaughan's identity (1977) for decomposing arithmetic sums into Type I/II components

The challenge is **translation** — porting analytic number theory into dependent type
theory using Mathlib's `Nat.ArithmeticFunction`. Suitable for a PhD project or ITP paper.

**File:** [`proofs/SpectralRH/BilinearSieve.lean`](proofs/SpectralRH/BilinearSieve.lean)

### Tier 3: The Millennium Frontier _(Open problem)_

**Target:** `type_II_sieve_bound` (K < 1)

The irreducible analytical content: proving that the cross-parity bilinear form
satisfies a strict Cauchy-Schwarz defect. The obstruction is **Selberg's parity barrier**
— the statistical independence of Liouville parity from divisibility structure.
Techniques from Chen's theorem (1973) and the bilinear sieve suggest K ≈ 0.961,
but proving K < 1 requires new insight.

**Files:** [`proofs/SpectralRH/BilinearSieve.lean`](proofs/SpectralRH/BilinearSieve.lean), [`proofs/SpectralRH/Assembly.lean`](proofs/SpectralRH/Assembly.lean)

## Project Structure

```
proofs/SpectralRH/
├── Defs.lean            # Core definitions (Gram matrix, eigenvalues, Liouville)
├── Structural.lean      # Structural theorems (pos-def, interlacing)
├── ParitySchur.lean     # ★ Zero-sorry parity block decomposition
├── BilinearSieve.lean   # ★ Typed interface for Phase 2
├── Assembly.lean        # Full proof chain assembly
├── Quantitative.lean    # Quantitative eigenvalue bounds
├── PTSymmetry.lean      # PT-symmetry algebra
└── paper/main.tex       # Research paper (LaTeX)

experiments/
├── spectral-gap-analysis/    # Eigenvalue computation (Rust)
├── parity_schur/             # Parity block experiments (Rust)
└── weil_explicit/            # GUE connection tests (Rust)
```

## Paper

The research paper documenting the full architecture, including the Three Gaps
analysis and the three-tier formalization roadmap, is in
[`proofs/SpectralRH/paper/`](proofs/SpectralRH/paper/).

## License

MIT
