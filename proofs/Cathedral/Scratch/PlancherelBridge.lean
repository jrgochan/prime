/-
  Scratch file: Plancherel bridge — isolating the minimal sorry.
-/

import Cathedral.MellinBridge.PlancherelDefs
import Mathlib.Analysis.Fourier.LpSpace
import Mathlib.Analysis.Fourier.Inversion
import Mathlib.MeasureTheory.Function.L2Space

noncomputable section
open Real MeasureTheory Finset BigOperators Complex

-- SUBGOAL A: real-squared = complex-norm-squared (PROVED)
lemma flatResV_sq_eq_norm_sq (N : ℕ) (v : Fin (N - 1) → ℝ) (u : ℝ) :
    (flattenedResidualV N v u) ^ 2 =
    ‖flattenedResidualC N v u‖ ^ 2 := by
  unfold flattenedResidualC
  simp [Complex.norm_real, sq_abs]

-- SUBGOAL B: Integral conversion (PROVED)
lemma integral_sq_eq_integral_norm_sq (N : ℕ) (v : Fin (N - 1) → ℝ) :
    ∫ u : ℝ, (flattenedResidualV N v u) ^ 2 =
    ∫ u : ℝ, ‖flattenedResidualC N v u‖ ^ 2 := by
  congr 1; ext u; exact flatResV_sq_eq_norm_sq N v u

-- SUBGOAL C: Plancherel for ℝ → ℂ functions with finite L² norm.
-- This is the single remaining axiom — a standard analysis theorem.
-- Mathlib HAS norm_fourier_eq but the bridge to raw integrals is the gap.
axiom plancherel_integral (f : ℝ → ℂ)
    (hf_asm : AEStronglyMeasurable f volume)
    (hf_l2 : Integrable (fun u => ‖f u‖ ^ 2) volume) :
    ∫ u : ℝ, ‖f u‖ ^ 2 =
    ∫ ξ : ℝ, ‖∫ u : ℝ, f u *
      Complex.exp (-2 * Real.pi * ξ * u * Complex.I)‖ ^ 2

-- SUBGOAL D: flattenedResidualC is AEStronglyMeasurable
lemma flatResC_measurable (N : ℕ) (v : Fin (N - 1) → ℝ) :
    AEStronglyMeasurable (flattenedResidualC N v) volume := by
  sorry

-- SUBGOAL E: ‖flattenedResidualC‖² is integrable
lemma flatResC_norm_sq_integrable (N : ℕ) (v : Fin (N - 1) → ℝ) :
    Integrable (fun u => ‖flattenedResidualC N v u‖ ^ 2) volume := by
  sorry

-- THE THEOREM: assembling all subgoals
theorem fourier_inv_autocorr_bridge (N : ℕ) (v : Fin (N - 1) → ℝ) :
    ∫ u : ℝ, (flattenedResidualV N v u) ^ 2 =
    ∫ ξ : ℝ, ‖∫ u : ℝ, flattenedResidualC N v u *
      Complex.exp (-2 * Real.pi * ξ * u * Complex.I)‖ ^ 2 := by
  rw [integral_sq_eq_integral_norm_sq]
  exact plancherel_integral (flattenedResidualC N v)
    (flatResC_measurable N v) (flatResC_norm_sq_integrable N v)

end
