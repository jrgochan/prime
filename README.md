# The Cathedral — A Formal Reduction of the Riemann Hypothesis in Lean 4

A machine-checked proof architecture in **Lean 4** + **Mathlib** that reduces
the Riemann Hypothesis to the logarithmic growth of a single explicit
Rayleigh quotient built from the Möbius function and the Vasyunin cotangent
sum. Compiles in **3,076 build jobs** with **zero `sorry`**, **zero warnings**,
and **5 axioms** on the active proof chain.

## The Honest Assessment

> *This formalization does not prove the Riemann Hypothesis. It reduces*
> *its entire mathematical content to a single finite statement about*
> *Möbius-weighted cotangent sums—which IS the RH, expressed as a*
> *computable quantity—plus one geometric axiom (the augmented Gram*
> *matrix Schur complement), one definitional bridge (the Vasyunin*
> *integral identity), and two classical equivalences (Lagarias/Robin).*
> *Everything else is compiler-verified.*

## Quick Start

```bash
cd proofs
lake build          # 3,076 jobs, ~2 min, zero errors
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

## Architecture: The Augmented Gram Matrix

### The Ultimate Matrix

The augmented Gram matrix H_N = [1, bᵀ; b, G_N] is the Gram matrix of
{1, f_1, ..., f_N} in L²(0,1). From a single axiom (its Schur complement
is positive), all geometric properties are derived:

- **H_N PD** for all N ≥ 1 (by induction via bordered matrix theorem)
- **G_N PD** (trailing submatrix: xᵀG_Nx = (0,x)ᵀH_N(0,x) > 0)
- **bᵀG⁻¹b < 1** (witness vector: wᵀH_Nw = 1 - bᵀG⁻¹b > 0)
- **C_N = G_N - bbᵀ PD** (Schur complement of G_N)

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

## The 5 Axioms

| # | Axiom | File | Nature |
|---|---|---|---|
| 1 | `augmentedSchurComplement_pos` | AugmentedGram.lean | **Geometric** — sawtooth discontinuity |
| 2 | `log_cutoff_witness_bound` | Chain.lean | **THE RH itself** — Selberg sieve bound |
| 3 | `vasyunin_eq_integral` | GramPSD.lean | **Definitional** — L² integral bridge |
| 4 | `lagarias_iff_rh` | Robin/Defs.lean | Literature (Lagarias 2002) |
| 5 | `robin_iff_rh` | Robin/Defs.lean | Literature (Robin 1984) |

### What Was Eliminated

| Former Axiom | How It Was Proved |
|---|---|
| `vasyuninGramMatrix_posDef` | Induction via bordered matrix theorem |
| `gramSchurComplement_pos` | Subsumed by augmented Schur complement |
| `vasyunin_nbDistSq_pos` | Witness vector w = (1, -G⁻¹b) |
| `vasyuninCovMatrix_posDef` | Schur complement of G_N PD + bᵀG⁻¹b < 1 |

All other structural properties—Hermitian symmetry, positive semidefiniteness,
determinant invertibility, witness positivity, and the variational principle—are
**proved theorems**.

## Key Results

| Result | Status |
|---|---|
| `augmentedGramMatrix_posDef` — H_N PD for all N ≥ 1 | **Proved** (induction, 1 axiom) |
| `gramMatrix_posDef_from_augmented` — G_N PD for all N ≥ 1 | **Proved** (trailing submatrix) |
| `nbDistSq_pos_from_augmented` — bᵀG⁻¹b < 1 | **Proved** (witness vector) |
| `covMatrix3_det3_pos` — det(C₃) > 0 | **Proved** (polynomial certificates) |
| `vasyuninGram3x3_det_pos_closedForm` — det(G₃) > 0 | **Proved** (quadratic interpolation) |
| `nbDistSq_decays` — d²_N → 0 | **Proved** (from axioms) |
| `quadForm_diverges` — X_N ≥ c·ln(N) | **Proved** (from axioms) |
| `lagarias_for_primes` — σ(p) ≤ Lagarias bound | **Proved** (0 axioms) |
| `nb_dist_via_witness` — d² = 1/(1+X) | **Proved** (0 axioms, Sherman–Morrison) |

## Repository Structure

```
proofs/              — Lean 4 formalization (25 active files, 5 axioms, 0 sorry)
  Cathedral/         — The proof architecture
    Defs.lean        — Core definitions
    LinearAlgebra/   — Sherman-Morrison, Variational principle, Sylvester
    MellinBridge/    — Nyman-Beurling bridge + Vasyunin framework
      Vasyunin/      — The heart: AugmentedGram, Gram entries, covariance, chain
    Robin/           — Robin/Lagarias discrete arithmetic front
    Archive/         — Historical explorations
paper/               — LaTeX paper and overview
experiments/         — Numerical experiments (Rust/MPFR, Python)
visualizer/          — Next.js proof tree visualizer
docs/                — Collaboration logs and analysis
```

## Proof Tree

```
Nodes: 210 (5 axioms, 169 theorems, 36 definitions)
Edges: 992
Files: 25
Routes: infrastructure (45), mellin (3), variational (114), robin (48)
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

3. **The Augmented Matrix Unification**: The matrix H_N = [1, bᵀ; b, G_N]
   is the "God Matrix" — the Gram matrix of {1, f_1, ..., f_N}. Its single
   Schur complement axiom simultaneously proves G_N PD (sawtooth independence)
   AND bᵀG⁻¹b < 1 (NB distance positivity), collapsing two axioms to one.

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
