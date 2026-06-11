/-
  Cathedral/Geometry/Bounds/NormLowerBoundDefs.lean

  ## Core definitions for the norm lower bound chain

  ════════════════════════════════════════════════════════════════

  Extracted from NormLowerBound.lean to resolve circular imports
  during axiom graduation. The proof files (SquarefreeCountBound,
  UnfilteredTaperSumBound, AbelFilterBound) need these definitions
  but not the axioms or theorems that depend on the proofs.

  Created: June 11, 2026 — Sub-Axiom Graduation Surgery
-/

import Cathedral.Geometry.Bernoulli.BernoulliDiagonal

noncomputable section
open Real Finset

namespace Cathedral.Geometry.Bounds.NormLowerBound

open Cathedral.Vasyunin
open Cathedral.Geometry.Bernoulli.BernoulliDiagonal

-- ════════════════════════════════════════════════════════════════
-- §1. SQUAREFREE COUNTING FUNCTION
-- ════════════════════════════════════════════════════════════════

/-- **SQUAREFREE COUNT FUNCTION**: The number of squarefree k ≤ N.

    Q(N) = #{k ∈ {1,...,N} : k is squarefree}
    Asymptotically Q(N) ~ (6/π²)·N. -/
noncomputable def sqfreeCount (N : ℕ) : ℕ :=
  ((Finset.Icc 1 N).filter (fun k => Squarefree k)).card

-- ════════════════════════════════════════════════════════════════
-- §2. TAPER FUNCTION AND UNFILTERED SUM
-- ════════════════════════════════════════════════════════════════

/-- The taper function: f(k,N) = (1 - ln(k)/ln(N))². -/
noncomputable def taperSq (k N : ℕ) : ℝ :=
  (1 - Real.log ↑k / Real.log ↑N) ^ 2

/-- **UNFILTERED TAPER SUM**: Σ_{k=1}^{N-1} (1-ln(k)/ln(N))².

    This sums the taper squared over ALL integers, not just squarefree.
    It is a lower bound (via Abel) for the squarefree-filtered sum. -/
noncomputable def unfilteredTaperSum (N : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 (N - 1), (1 - Real.log ↑k / Real.log ↑N) ^ 2

end Cathedral.Geometry.Bounds.NormLowerBound

end
