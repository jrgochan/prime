# The Cathedral — A Formal Reduction of the Riemann Hypothesis in Lean 4

A machine-checked proof architecture in **Lean 4** + **Mathlib** that reduces
the Riemann Hypothesis to the logarithmic growth of a single explicit
Rayleigh quotient built from the Möbius function and the Vasyunin cotangent
sum. Compiles in **3,073 build jobs** with **zero `sorry`**, **zero warnings**,
and **4 axioms** on the active proof chain.

## The Honest Assessment

> *This formalization does not prove the Riemann Hypothesis. It reduces*
> *its entire mathematical content to a single finite statement about*
> *Möbius-weighted cotangent sums—which IS the RH, expressed as a*
> *computable quantity—plus one structural axiom (covariance matrix*
> *positive definiteness, itself provably reducible to Gram matrix PD).*
> *Everything else is compiler-verified.*

## Quick Start

```bash
cd proofs
lake build          # 3,073 jobs, ~2 min, zero errors
```

Requires: [Lean v4.30.0-rc1](https://leanprover.github.io/lean4/doc/setup.html) and Mathlib.

## The Key Reduction

The Riemann Hypothesis is formally equivalent to:

> ∃ c > 0, ∃ N₀, ∀ N ≥ N₀: c · ln(N) ≤ (bᵀv)² / (vᵀCv)

where v_k = -μ(k)(1 - ln k / ln N) is the log cutoff witness, C = G - bbᵀ
is the covariance matrix, G(j,k) is given by the Vasyunin formula (no integrals),
and b_k = (ln k + 1 - γ)/k.

**No continuous integrals. No complex plane. No analytic continuation. No measure theory.**
Only: Möbius function, gcd, logarithm, cotangent, and fractional parts.

## Architecture: The Vasyunin Variational Path

### The Proof Chain

1. `log_cutoff_witness_bound` — Q(v_log) ≥ c·ln(N) (**Axiom — the RH itself**)
2. `variational_lower_bound` — Q(v) ≤ X_N (**Theorem** — Cauchy–Schwarz)
3. `log_cutoff_witness_pos` — vᵀCv > 0 (**Theorem** — PosDef + v ≠ 0)
4. `quadForm_diverges` — X_N ≥ c·ln(N) (**Theorem**)
5. `nbDistSq_decays` — d²_N → 0 (**Theorem**)

### The Robin/Lagarias Front (Independent)

Discrete arithmetic equivalences connecting RH to divisor-sum inequalities.

**Unconditional result** (zero axioms):
- `lagarias_for_primes` — σ(p) ≤ H_p + exp(H_p)·ln(H_p) for ALL primes p ✓

## The 4 Axioms

| Axiom | File | Nature |
|---|---|---|
| `log_cutoff_witness_bound` | Chain.lean | **THE RH itself** — verified numerically to N=50,000 |
| `vasyuninCovMatrix_posDef` | Rayleigh.lean | Structural — reducible to G_N PD |
| `lagarias_iff_rh` | Robin/Defs.lean | Literature (Lagarias 2002) |
| `robin_iff_rh` | Robin/Defs.lean | Literature (Robin 1984) |

All other structural properties—Hermitian symmetry, positive semidefiniteness,
determinant invertibility, witness positivity, and the variational principle—are
**proved theorems**.

## Key Results

| Result | Status |
|---|---|
| `covMatrix3_det3_pos` — det(C₃) > 0 | **Proved** (zero sorry, polynomial certificates) |
| `covMatrix3_det2_pos` — det(C₂) > 0 | **Proved** (double interpolation) |
| `covEntry_00_pos` — C₀₀ > 0 | **Proved** |
| `vasyuninGram3x3_det_pos_closedForm` — det(G₃) > 0 | **Proved** (quadratic interpolation) |
| `vasyuninGram2x2_det_pos` — det(G₂) > 0 | **Proved** |
| `nbDistSq_decays` — d²_N → 0 | **Proved** (from axioms) |
| `quadForm_diverges` — X_N ≥ c·ln(N) | **Proved** (from axioms) |
| `lagarias_for_primes` — σ(p) ≤ Lagarias bound | **Proved** (0 axioms) |
| `nb_dist_via_witness` — d² = 1/(1+X) | **Proved** (0 axioms, Sherman–Morrison) |

## Repository Structure

```
proofs/              — Lean 4 formalization (21 active files, 4 axioms, 0 sorry)
  Cathedral/         — The proof architecture
    Defs.lean        — Core definitions
    LinearAlgebra/   — Sherman-Morrison, Variational principle
    MellinBridge/    — Nyman-Beurling bridge + Vasyunin framework
      Vasyunin/      — The heart: Gram entries, covariance proofs, witness chain
    Robin/           — Robin/Lagarias discrete arithmetic front
    Archive/         — Historical explorations (38 files, off critical path)
paper/               — LaTeX paper and overview
experiments/         — Numerical experiments (Rust/MPFR, Python)
docs/                — Collaboration logs and analysis
```

## Papers

- `paper/cathedral.tex` — Technical paper (8 pages)
- `paper/overview.tex` — Accessible overview (4 pages)

Build PDFs: `cd paper && pdflatex cathedral.tex && pdflatex overview.tex`

## Three Discoveries

1. **The Selberg Sieve Emergence**: Without any input from number theory,
   the L² variational principle independently selects the Selberg sieve weights
   μ(k)(1 - ln k / ln N) as the optimal witness. The multiplicative structure
   of the integers forces the Hilbert space to reinvent sieve theory.

2. **The Prime Bucket Mechanism**: A 128-bit MPFR optimizer, given G_N at N=201
   with no knowledge of primes, independently discovered μ(k) — Selberg's parity
   barrier, emergent from pure linear algebra.

3. **The Covariance Positivity Certificate**: The 3×3 covariance matrix
   determinant, a degree-6 polynomial in 5 transcendentals (ln 2, γ, ln 3,
   π/(18√3), ln π), was formally verified positive via divided differences,
   bilinear interpolation, and Taylor monotonicity — playing Lean's `nlinarith`
   like a virtuoso instrument.

## Methodology

This project was built through a tripartite human-AI collaboration:
a human computer scientist providing architectural vision and experimental design,
Gemini Deep Think acting as a mathematical theorist providing deep analytic
intuition, and Claude (Antigravity) acting as a code-level engineer providing
Lean 4 compilation and structural optimization.

## License

Apache 2.0

## Citation

```bibtex
@misc{gochanour2026cathedral,
  title={The Cathedral: A Formal Reduction of the Riemann Hypothesis
         via Discrete Variational Witness in Lean 4},
  author={Gochanour, Jason Robert},
  year={2026},
  url={https://github.com/jrgochan/prime}
}
```
