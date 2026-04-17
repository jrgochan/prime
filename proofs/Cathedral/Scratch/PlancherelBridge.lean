/-
  PlancherelBridge: Measurability + Integrability of flattenedResidualC.
-/

import Cathedral.MellinBridge.PlancherelDefs
import Mathlib.MeasureTheory.Integral.ExpDecay
import Mathlib.MeasureTheory.Function.Floor
import Mathlib.Analysis.Fourier.LpSpace

noncomputable section
open Real MeasureTheory Finset BigOperators Set
open scoped FourierTransform

-- ═══════════════════════════════════════════
-- PROVED: Measurability
-- ═══════════════════════════════════════════

theorem flatResV_measurable (N : ℕ) (v : Fin (N - 1) → ℝ) :
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

theorem flatResC_aesm (N : ℕ) (v : Fin (N - 1) → ℝ) :
    AEStronglyMeasurable (flattenedResidualC N v) volume := by
  unfold flattenedResidualC
  exact (Complex.ofRealCLM.continuous.measurable.comp
    (flatResV_measurable N v)).aestronglyMeasurable

-- ═══════════════════════════════════════════
-- PROVED: Integrable
-- ═══════════════════════════════════════════

theorem flatResV_integrable (N : ℕ) (v : Fin (N - 1) → ℝ) :
    Integrable (flattenedResidualV N v) volume := by
  set C := 1 + ∑ i : Fin (N - 1), |v i|
  rw [← integrableOn_univ]
  -- Split: univ = Ici 0 ∪ Iio 0
  have huniv : (Set.univ : Set ℝ) = Set.Ici 0 ∪ Set.Iio 0 := by
    ext x; simp only [Set.mem_univ, Set.mem_union, Set.mem_Ici, Set.mem_Iio, true_iff]
    exact le_or_gt 0 x
  rw [huniv, integrableOn_union]
  refine ⟨?_, ?_⟩
  · -- IntegrableOn [0, ∞): bounded by exp decay on (0, ∞), single point doesn't matter
    have hIoi : IntegrableOn (flattenedResidualV N v) (Set.Ioi 0) volume :=
      ((exp_neg_integrableOn_Ioi 0
        (show (0:ℝ) < 1/2 by positivity)).const_mul C).mono'
        ((flatResV_measurable N v).aestronglyMeasurable.restrict)
        (ae_of_all _ fun u => by
          simp only [norm_eq_abs]
          calc |flattenedResidualV N v u|
              ≤ C * rexp (-u / 2) := flattenedResidualV_bound N v u
            _ = C * rexp (-(1/2) * u) := by ring_nf)
    -- Ici 0 = Ioi 0 ∪ {0}, and IntegrableOn {0} is trivial
    rw [show Set.Ici (0:ℝ) = Set.Ioi 0 ∪ {0} from by ext; simp [le_iff_lt_or_eq, eq_comm]]
    exact hIoi.union (integrableOn_singleton (hx := by simp))
  · -- IntegrableOn (-∞, 0): f = 0 there
    apply integrableOn_zero.congr_fun _ measurableSet_Iio
    intro u hu; simp only [Set.mem_Iio] at hu
    unfold flattenedResidualV; simp [show ¬(0 ≤ u) from not_le.mpr hu]

theorem flatResC_integrable (N : ℕ) (v : Fin (N - 1) → ℝ) :
    Integrable (flattenedResidualC N v) volume := by
  unfold flattenedResidualC
  exact (flatResV_integrable N v).ofReal

end
