# The Cathedral — A Formal Reduction of the Riemann Hypothesis in Lean 4

A machine-checked proof architecture in **Lean 4** + **Mathlib** that reduces
the Riemann Hypothesis to the logarithmic growth of a single explicit
Rayleigh quotient built from the Möbius function and the Vasyunin cotangent
sum. **Zero `sorry`**, **zero warnings**, and **5 axioms** on the crown
theorem's critical path (verified by `#print axioms`).

## The Honest Assessment

> *This formalization does not prove the Riemann Hypothesis. It reduces*
> *its entire mathematical content to a single finite statement about*
> *Möbius-weighted cotangent sums—which IS the RH, expressed as a*
> *computable quantity—plus one definitional bridge (the Vasyunin*
> *integral identity), and combined classical equivalences (Lagarias/Robin).*
> *Everything else—including augmented Gram matrix positivity, covariance*
> *positivity, the mean entry integral identity, and the variational*
> *principle—is compiler-verified.*

## Quick Start

```bash
cd proofs
lake build          # 3,530 jobs, ~2 min, zero errors, zero warnings
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
{1, h_1, ..., h_N} in L²(0,1), where h_k(x) = {1/(kx)} are the Báez-Duarte
basis functions. Schur complement positivity is now a **proved theorem**
(the "Factorial Nuke"), and all geometric properties follow:

- **H_N PD** for all N ≥ 1 (by induction via bordered matrix theorem)
- **G_N PD** (trailing submatrix: xᵀG_Nx = (0,x)ᵀH_N(0,x) > 0)
- **bᵀG⁻¹b < 1** (witness vector: wᵀH_Nw = 1 - bᵀG⁻¹b > 0)
- **C_N = G_N - bbᵀ PD** (Schur complement of G_N)

### The Proof Chain

1. `witness_covariance_decay` — vᵀCv ≤ C/ln(N) (**Axiom — THE RH itself**)
2. `witness_numerator_convergence` — bᵀv → 1 (**Axiom — PNT level**)
3. `vasyunin_eq_integral` — Gram entry = L² integral (**Axiom — Vasyunin 1995**)
4. `algebraic_nb_bridge` — Quadform → integral criterion (**Axiom — structural**)
5. `zeta_zero_separates` — Off-line zero → L² obstruction (**Axiom — converse**)
6. `variational_lower_bound` — Q(v) ≤ X_N (**Theorem** — Cauchy–Schwarz)
7. `log_cutoff_witness_bound` — Q(v_log) ≥ c·ln(N) (**Theorem** — from axioms 1+2)
8. `quadForm_diverges` — X_N ≥ c·ln(N) (**Theorem**)
9. `nbDistSq_decays` — d²_N → 0 (**Theorem**)

### The Robin/Lagarias Front (Independent)

Discrete arithmetic equivalences connecting RH to divisor-sum inequalities.

**Unconditional result** (zero axioms):
- `lagarias_for_primes` — σ(p) ≤ H_p + exp(H_p)·ln(H_p) for ALL primes p ✓

## The 5 Critical-Path Axioms

Verified by `#print axioms nyman_beurling_iff_rh`:

| # | Axiom | File | Nature |
|---|---|---|---|
| 1 | `witness_covariance_decay` | WitnessAsymptotics.lean | **THE RH itself** — vᵀCv ≤ C/ln(N) |
| 2 | `witness_numerator_convergence` | WitnessAsymptotics.lean | **PNT level** — bᵀv → 1 |
| 3 | `vasyunin_eq_integral` | IntegralBridge.lean | **Vasyunin 1995** — L² integral bridge |
| 4 | `algebraic_nb_bridge` | Chain.lean | **Structural** — quadform → integral criterion |
| 5 | `zeta_zero_separates` | Axioms.lean | **Converse** — off-line zero → L² obstruction |

An alternative forward direction (`phase_3_chain`) uses only 2 axioms:
`mertens_bound_from_rh` + `abel_summation_l2_bound`.

48 total axioms support parallel proof paths (sieve engine, spectral theory, Mellin bridge).

### What Was Eliminated (Now Theorems)

| Former Axiom | How It Was Proved |
|---|---|
| `augmentedSchurComplement_pos` | **The Factorial Nuke**: On (1/(N!+1), 1/N!), divisibility (i+1)\|N! forces exact floors. April 12, 2026. |
| `vasyunin_mean_eq_integral` | **Euler-Mascheroni Integral**: Substitution u=kx + series identity Σ(1/(m+1) - log(1+1/(m+1))) = γ. April 12, 2026. |
| `vasyuninGramMatrix_posDef` | Induction via bordered matrix theorem |
| `gramSchurComplement_pos` | Subsumed by augmented induction |
| `vasyunin_nbDistSq_pos` | Witness vector w = (1, -G⁻¹b) |
| `vasyuninCovMatrix_posDef` | Schur complement of G_N PD + bᵀG⁻¹b < 1 |
| `variational_lower_bound` | Abstract Cauchy–Schwarz |
| `log_cutoff_witness_pos` | PosDef + v ≠ 0 |
| `vasyuninCovMatrix_hermitian` | Gram symmetry + bbᵀ symmetry |

## Key Results

| Result | Status |
|---|---|
| `augmentedGramMatrix_posDef` — H_N PD for all N ≥ 1 | **Proved** (induction, 0 axioms) |
| `gramMatrix_posDef_from_augmented` — G_N PD for all N ≥ 1 | **Proved** (trailing submatrix) |
| `nbDistSq_pos_from_augmented` — bᵀG⁻¹b < 1 | **Proved** (witness vector) |
| `mean_entry_eq_integral` — ∫₀¹ {1/(kx)} dx = (ln k + 1 - γ)/k | **Proved** (Euler-Mascheroni) |
| `covMatrix3_det3_pos` — det(C₃) > 0 | **Proved** (polynomial certificates) |
| `vasyuninGram3x3_det_pos_closedForm` — det(G₃) > 0 | **Proved** (quadratic interpolation) |
| `nbDistSq_decays` — d²_N → 0 | **Proved** (from axioms) |
| `quadForm_diverges` — X_N ≥ c·ln(N) | **Proved** (from axioms) |
| `lagarias_for_primes` — σ(p) ≤ Lagarias bound | **Proved** (0 axioms) |
| `nb_dist_via_witness` — d² = 1/(1+X) | **Proved** (0 axioms, Sherman–Morrison) |
| `cross_piece_integral_ftc` — piecewise FTC for ∫(1/(jx)−m)(1/(kx)−n)dx | **Proved** (0 axioms) |
| `tile_n_values_bounded` — Beatty: ≤2 tiles/row when j≤k | **Proved** (0 axioms) |

## Repository Structure

```
proofs/              — Lean 4 formalization (83 active files, 48 axioms, 0 sorry)
  Cathedral/         — The proof architecture
    Defs.lean        — Core definitions (gramEntry, nbLinComb, nbDistSq)
    Axioms.lean      — Axiom registry (zeta_zero_separates)
    LinearAlgebra/   — Sherman-Morrison, Variational, Sylvester, SchurComplement
    Gram/            — L²Bridge, FractIntegral, off-diagonal bounds
    Vasyunin/        — The heart: AugmentedGram, cotangent chain, witness
      Augmented/     — AugmentedGram.lean, IntegralBridge, MeanIntegral, Rayleigh
      Cotangent/     — DigammaReflection, LogDigammaBridge, TelescopeSum
      Matrix/        — CovDet2, CovDet3, Structural
      Proof/         — Chain, WitnessAsymptotics, BartlettWindow
    NymanBeurling/   — Crown theorem (nyman_beurling_iff_rh)
    Assembly/        — QuadFormBridge, MainChain
    Robin/           — Robin/Lagarias discrete arithmetic front
    Structural/      — Eigenvalue interlacing, telescoping
    Spectral/        — Class restriction, constant vector bound
    Sieve/           — Bilinear sieve, parity bridge, Möbius uncoupling
    MellinBridge/    — Mellin-Plancherel, weight construction, Mertens bypass
    IntegralBasis/   — Báez-Duarte, quantitative bounds
    Archive/         — Historical explorations
paper/               — LaTeX paper and overview
experiments/         — Numerical experiments (Rust/MPFR, Python)
visualizer/          — Next.js proof tree visualizer
docs/                — Collaboration logs and analysis
```

## Build Stats

```
Files:      83 active Lean files
Axioms:     48 total (5 on critical path, verified by #print axioms)
Sorry:      0
Warnings:   0
Compiled:   3,530 modules
```

## Papers

- `paper/cathedral.tex` — Technical paper (12 pages)
- `paper/overview.tex` — Accessible overview (6 pages)

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
   is the Gram matrix of {1, h_1, ..., h_N}. Its Schur complement positivity—now
   a proved theorem via the Factorial Nuke—simultaneously establishes G_N PD
   AND bᵀG⁻¹b < 1 (NB distance positivity), collapsing two axioms to zero.

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
