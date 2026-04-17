/-
  Testing MemLp proof — simplest approach.
-/

import Cathedral.MellinBridge.PlancherelDefs
import Mathlib.MeasureTheory.Integral.ExpDecay
import Mathlib.MeasureTheory.Function.Floor
import Mathlib.MeasureTheory.Function.L2Space

noncomputable section
open Real MeasureTheory Finset BigOperators Set

private theorem flatResV_meas (N : ℕ) (v : Fin (N - 1) → ℝ) :
    Measurable (flattenedResidualV N v) := by
  unfold flattenedResidualV bdResidualV bdLinComb
  apply Measurable.ite measurableSet_Ici
  · apply Measurable.mul
    · apply Measurable.sub measurable_const
      apply Finset.measurable_sum; intro i _
      apply Measurable.const_mul; apply Measurable.fract
      apply Measurable.div measurable_const
      exact (measurable_const.mul measurable_neg.exp)
    · exact (measurable_neg.div_const _).exp
  · exact measurable_const

-- MemLp 2: Use memLp_two_iff_integrable_sq_norm
-- then prove Integrable (‖f·‖²) by the same Ioi/Iio decomposition

theorem flatResC_memLp2 (N : ℕ) (v : Fin (N - 1) → ℝ) :
    MemLp (flattenedResidualC N v) 2 volume := by
  have haesm : AEStronglyMeasurable (flattenedResidualC N v) volume := by
    unfold flattenedResidualC
    exact (Complex.ofRealCLM.continuous.measurable.comp (flatResV_meas N v)).aestronglyMeasurable
  refine (memLp_two_iff_integrable_sq_norm haesm).mpr ?_
  -- Goal: Integrable (fun x => ‖flattenedResidualC N v x‖ ^ 2) volume
  -- ‖flattenedResidualC N v u‖ = |flattenedResidualV N v u|
  -- So ‖f u‖² = |flattenedResidualV N v u|²
  -- |flattenedResidualV N v u|² ≤ (C * exp(-u/2))² = C² * exp(-u) on Ioi 0
  -- And |flattenedResidualV N v u|² = 0 on Iio 0

  -- The squared function has the same support as f:
  have hsq_zero : ∀ u : ℝ, u < 0 →
      (fun x => ‖flattenedResidualC N v x‖ ^ 2) u = 0 := by
    intro u hu
    unfold flattenedResidualC flattenedResidualV
    simp [show ¬(0 ≤ u) from not_le.mpr hu]

  set C := 1 + ∑ i : Fin (N - 1), |v i|

  rw [← integrableOn_univ]
  rw [show (Set.univ : Set ℝ) = Set.Ioi 0 ∪ {(0:ℝ)} ∪ Set.Iio 0 from by
    ext x; simp only [Set.mem_univ, Set.mem_union, Set.mem_Ioi, Set.mem_singleton_iff,
      Set.mem_Iio, true_iff]; rcases lt_trichotomy x 0 with h | h | h
    · exact Or.inr h
    · exact Or.inl (Or.inr h)
    · exact Or.inl (Or.inl h)]
  apply IntegrableOn.union
  · apply IntegrableOn.union
    · -- On Ioi 0: ‖f u‖² ≤ C² * exp(-u)
      have hbnd : IntegrableOn (fun u => C ^ 2 * rexp (-(1:ℝ) * u)) (Set.Ioi 0) volume :=
        (exp_neg_integrableOn_Ioi 0 (show (0:ℝ) < 1 by positivity)).const_mul (C ^ 2)
      apply hbnd.mono'
      · -- AEStronglyMeasurable of ‖f·‖²
        apply AEStronglyMeasurable.restrict
        exact (haesm.norm.mul haesm.norm).congr
          (ae_of_all _ fun u => by simp [sq])
      · -- Pointwise bound
        filter_upwards with u
        simp only [norm_eq_abs, Function.comp]
        unfold flattenedResidualC
        simp only [Complex.norm_real, abs_abs]
        -- Goal: |flattenedResidualV N v u| ^ 2 ≤ |C ^ 2 * rexp (-(1:ℝ) * u)|
        rw [abs_of_nonneg (by positivity)]
        have hb := flattenedResidualV_bound N v u
        calc |flattenedResidualV N v u| ^ 2
            ≤ (C * rexp (-u / 2)) ^ 2 := by
              apply sq_le_sq' <;> linarith [abs_nonneg (flattenedResidualV N v u)]
          _ = C ^ 2 * rexp (-(1:ℝ) * u) := by
              rw [mul_pow, sq (rexp _), ← Real.exp_add]
              ring_nf
    · exact integrableOn_singleton (hx := by simp)
  · -- On Iio 0: f = 0 so ‖f‖² = 0
    exact integrableOn_zero.congr_fun (fun u hu => by
      exact (hsq_zero u (Set.mem_Iio.mp hu)).symm) measurableSet_Iio

end
