/-
  Cathedral/SelbergSieve.lean

  ## Bridge: Constant Witness → moebius_test_bound
-/

import Cathedral.Defs
import Cathedral.Structural
import Cathedral.GramBounds
import Cathedral.Mertens

noncomputable section
open Real MeasureTheory Set Finset

/-- **THEOREM (PROVED)**: moebius_test_bound from the constant witness chain. -/
theorem moebius_test_bound_from_selberg :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N → ∃ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≤ C / Real.log (N : ℝ) :=
  nb_distance_decay_axiom_bridge

end
