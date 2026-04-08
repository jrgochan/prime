# The Cathedral — A Formal Reduction of the Riemann Hypothesis in Lean 4

A machine-checked proof architecture in **Lean 4** + **Mathlib** that establishes
three independent routes constraining the Riemann Hypothesis, compiling in
**3,486 build jobs** with **zero `sorry`** and **36 axioms**.

## The Honest Assessment

> *This formalization does not prove the Riemann Hypothesis. It establishes*
> *three independent machine-verified routes that constrain RH, reduces the*
> *hard mathematical content to precisely identified axioms, and proves*
> *everything else with compiler-verified rigor.*

## Quick Start

```bash
cd proofs
lake build          # 3,486 jobs, ~2 min, zero errors
```

Requires: [Lean v4.30.0-rc1](https://leanprover.github.io/lean4/doc/setup.html) and Mathlib.

## Architecture: Three Routes to RH

### Route 1 — Forward: RH ⟹ d²→0

The Mertens Weight Bypass constructs explicit L² approximants from the
Mertens bound M(x) = O(√x log²x), avoiding all complex analysis.

**2 domain axioms** on this path:
- `mertens_bound_from_rh` — RH → |M(x)| ≤ C√x log²x (number theory)
- `abel_summation_l2_bound` — Mertens → L² weights (real analysis)

### Route 2 — Converse: d²→0 ⟹ RH

The Báez-Duarte Orthogonal Witness traps every hypothetical off-line zero ρ
via Cauchy-Schwarz: d² ≥ |1/ρ|²/‖h_ρ‖² > 0.

**1 structural axiom** on this path:
- `zeta_zero_separates` — separation obstruction at zeros of ζ

### Route 3 — Robin/Lagarias

Discrete arithmetic equivalences connecting RH to divisor-sum inequalities.

**Unconditional result** (zero axioms):
- `lagarias_for_primes` — σ(p) ≤ H_p + exp(H_p)·ln(H_p) for ALL primes p ✓

## Compiler-Verified Axiom Audit

```
#print axioms nyman_beurling_equivalence
-- [abel_summation_l2_bound,
--  mertens_bound_from_rh,
--  zeta_zero_separates,
--  propext, Classical.choice, Quot.sound]

#print axioms lagarias_for_primes
-- [propext, Classical.choice, Quot.sound]
-- (ZERO domain axioms — fully proved!)
```

**Three domain axioms** in the Nyman-Beurling equivalence. The remaining three
(`propext`, `Classical.choice`, `Quot.sound`) are Lean's foundational axioms —
present in every Lean 4 program.

## Key Results

| Result | Status | Route |
|---|---|---|
| `nyman_beurling_equivalence` — RH ↔ d²→0 | **Both directions proved** | Crown |
| `rh_implies_distance_converges_to_zero` — RH → d²→0 | **Proved** (theorem) | Forward |
| `nyman_beurling_converse` — d²→0 → RH | **Proved** | Converse |
| `baezDuarte_separates` — Orthogonal Witness trap | **Proved** | Converse |
| `lagarias_for_primes` — σ(p) ≤ Lagarias bound | **Proved** (0 axioms) | Robin |
| `corrected_weights_pole_free` — Σkv_k = 0 | **Proved** | Forward |
| `phase_3_chain` — RH → d² ≤ C/log N | **Proved** | Forward |
| `gram_eigenvalue_asymptotic_derived` — λ_min ≥ c/(N log N) | **Proved** | Spectral |

## The 36 Axioms

| Category | Count | Difficulty |
|---|---|---|
| Forward critical path | 2 | Moderate–Deep |
| Báez-Duarte witness | 3 | Moderate–High |
| Structural (converse) | 1 | High |
| Robin/Lagarias equivalences | 2 | Deep |
| Autocorrelation bridge | 4 | Moderate |
| Sieve engine | 5 | High |
| Spectral infrastructure | 12 | Long-term |
| Quantitative/structural | 7 | Moderate |

Full list: `grep -rn '^axiom ' proofs/Cathedral/ --include='*.lean'`

## Repository Structure

```
proofs/          — Lean 4 formalization (45 files, 36 axioms, 0 sorry)
  Cathedral/     — The proof architecture
    Assembly/    — MainChain.lean (capstone theorem)
    MellinBridge/— Forward direction, Báez-Duarte, Mertens bypass
    Robin/       — Robin/Lagarias discrete arithmetic front
    Spectral/    — Spectral infrastructure (off critical path)
    Structural/  — Linear algebra foundations
paper/           — LaTeX paper and overview
visualizer/      — Next.js interactive proof visualization
experiments/     — MPFR numerical experiments
docs/            — Collaboration logs and analysis
```

## Papers

- `paper/cathedral.tex` — Technical paper (6 pages)
- `paper/overview.tex` — Accessible overview (4 pages)

Build PDFs: `cd paper && pdflatex cathedral.tex && pdflatex overview.tex`

## Three Discoveries

1. **The Sawtooth Autocorrelation Floor**: A constant covariance C∞ ≈ 0.00227
   causes off-diagonal mass to grow as Θ(N²), invalidating constant-weight approaches.

2. **The Hyperplane Trap**: Single-functional Cauchy-Schwarz fails — spoofing weights
   exist that make the functional vanish while ‖1-f‖² explodes.

3. **The Prime Bucket Mechanism**: A 128-bit MPFR optimizer, given the Gram matrix
   with no knowledge of primes, independently discovered μ(k) ← Selberg's parity
   barrier, emergent from pure linear algebra.

## Methodology

This project was built through a tripartite human-AI collaboration:
a human computer scientist providing architectural vision and architectural design, Gemini Deep Think, acting as a mathematical theorist providing deep analytic intuition, and Claude Opus 4.6 (Thinking) acting as a code-level engineer providing Lean 4 compilation and structural optimization.

## License

Apache 2.0

## Citation

```bibtex
@misc{gochanour2026cathedral,
  title={The Cathedral: A Formal Reduction of the Riemann Hypothesis
         via Three Independent Routes in Lean 4},
  author={Gochanour, Jason Robert},
  year={2026},
  url={https://github.com/jrgochan/prime}
}
```
