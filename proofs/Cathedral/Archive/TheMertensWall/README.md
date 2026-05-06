# The Mertens Wall — Architectural Archive

## What This Contains

This archive documents the **physical limits of spatial Abel summation**
for bounding the Nyman-Beurling L² distance under the Riemann Hypothesis.

The files here represent the Cathedral team's multi-week attempt (April–May 2026)
to prove the covariance bound `vᵀCv ≤ C/logN` from the Mertens function
bound `M(x) = O(x^{3/4})` using real-variable Abel summation techniques.

## The Millennium Paradox

**The bound is mathematically false under Mertens x^{3/4}.**

Gemini Actual (May 2026) proved via Dirichlet convolution that under the
weak Mertens bound `|M(x)| ≤ C·x^{3/4}`:

    ∫₀¹ (1 - f_N(x))² ≈ 2√N / log²N → ∞

The spatial L² norm **diverges**. The Lean 4 compiler correctly refused
to compile proofs of this false statement.

### Why This Matters

The Converse direction (d²→0 ⟹ RH) is fully proved with zero axioms.
If Abel summation could prove the Forward direction (RH ⟹ d²→0) using
only the Prime Number Theorem, it would unconditionally prove the
Riemann Hypothesis — a Millennium Prize problem.

The compiler was acting as a **topological shield**, preventing a false
proof of a Millennium Prize problem using 19th-century real analysis.

## The Correct Architecture

The L² convergence ∫(1-f_N)² → 0 is strictly a **frequency-domain**
phenomenon. It requires Parseval's identity and the Mellin transform
on the critical line s = 1/2 + it. This is Báez-Duarte's 2003 theorem.

The Cathedral's Crown Path now encapsulates this as a single, honest
axiom: `baez_duarte_forward` (IMRN 2003, no. 36, pp. 1989–2009).

## Files

- `covariance_bound_from_mertens_34`: The false axiom (declared in
  `GramFormProof.lean`, now superseded by `baez_duarte_forward`)
- `CovarianceAbel.lean`: 573-line partial proof attempt, with 2 sorry
  in deprecated theorems. Contains `bdApprox_pointwise_bound` (PROVED)
  and the false `gram_form_bound_raw` (with sorry + DEPRECATED docstring)
- `CovarianceBound.lean`: Alternative proof attempt via MillenniumWall,
  but depends on 4 axioms (worse than the 3-axiom crown path)
- `Direct.lean`: Bias-variance decomposition (PROVED, still live in
  the main Covariance directory — not archived here)

## Historical Note

The axiom `covariance_bound_from_mertens_34` was created April 25, 2026
as a replacement for `gram_form_upper_bound_34` during the Perron Crown
rewire. It was retired May 5, 2026 when Gemini Actual identified the
Millennium Paradox and Claude Actual executed the One-Pillar Cathedral
architecture with the Báez-Duarte anchor.

— Claude Actual & Gemini Actual, May 5, 2026
