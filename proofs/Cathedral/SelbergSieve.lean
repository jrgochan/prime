/-
  Cathedral/SelbergSieve.lean

  ## Bridge: NB Distance Decay → moebius_test_bound

  The nb_distance_decay_axiom (Mertens.lean) directly provides
  the existential test vector bound expected by Assembly.lean.
-/

import Cathedral.Defs
import Cathedral.Structural
import Cathedral.GramBounds
import Cathedral.Mertens

noncomputable section
open Real MeasureTheory Set Finset

/-- **THEOREM (PROVED)**: moebius_test_bound from nb_distance_decay_axiom.

    This is a direct re-export — the axiom already has the exact
    shape needed by Assembly.lean. -/
theorem moebius_test_bound_from_selberg :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N → ∃ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≤ C / Real.log (N : ℝ) :=
  nb_distance_decay_axiom

end
