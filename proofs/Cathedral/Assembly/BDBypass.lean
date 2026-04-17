/-
  Cathedral/Assembly/BDBypass.lean

  ## The Great Pivot: RH → L² Bound (Pillar II Bridge)

  Wires the proved Abel Summation theorem from AbelSiegeProof.lean
  to the Nyman-Beurling distance, completing Pillar II.

  ### Architecture:
  - MertensBound.lean: RH → |M(x)| = O(x^{1/2} log²x)  [Axiom 1]
  - AbelSiegeProof.lean: Mertens → L² witness decay       [Proved + Axiom 2]
  - This file: composition                                 [Proved]
-/

import Cathedral.Defs
import Cathedral.MellinBridge.MertensBound
import Cathedral.MellinBridge.AbelSiegeProof
import Cathedral.NymanBeurling.BDMellin

noncomputable section
open Real Matrix Finset MeasureTheory

-- ════════════════════════════════════════════════
-- THEOREM: RH → BD WITNESS DECAY (Pillar II Bridge)
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: RH implies the BD witness L² error decays.
    Chains: RH → Mertens → Abel summation → L² bound.

    This is the forward direction of the Nyman-Beurling equivalence:
    RH ⟹ d²_N → 0. -/
theorem rh_implies_bd_witness_decay :
    RiemannHypothesis →
    ∃ C_err : ℝ, C_err > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      ∃ v : Fin (N - 1) → ℝ,
        ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 ≤ C_err / Real.log ↑N := by
  intro hRH
  exact abel_summation_bd_l2_bound_proved (rh_implies_mertens_bound hRH)

end
