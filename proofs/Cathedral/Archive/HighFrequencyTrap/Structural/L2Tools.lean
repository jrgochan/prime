/-
  Cathedral/Structural/L2Tools.lean

  ## The L² ↔ Matrix Bridge.

  Provides the integration tools connecting the continuous L²(0,1)
  approximation distance to the discrete matrix quadratic form:
    ∫₀¹ (1 - Σ wᵢ{(i+1)/x})² dx = 1 - 2·bᵀw + wᵀGw
-/

import Cathedral.Defs
import Cathedral.Structural.NbLinComb
import Cathedral.Structural.Independence

noncomputable section
open Complex Real

/-- Each w_i * fract((i+1)/x) is integrable on [0,1]. -/
private lemma single_fract_integrable (k : ℕ) (c : ℝ) :
    IntervalIntegrable (fun x : ℝ => c * Int.fract (↑k / x))
      MeasureTheory.volume 0 1 := by
  have hm : Measurable (fun x : ℝ => c * Int.fract (↑k / x)) :=
    (measurable_const.div measurable_id).fract.const_mul c
  exact IntervalIntegrable.mono_fun (intervalIntegrable_const (c := |c|))
    hm.aestronglyMeasurable.restrict
    (Filter.Eventually.of_forall (fun x => by
      simp only [Real.norm_eq_abs, abs_abs]
      calc |c * Int.fract (↑k / x)|
          = |c| * |Int.fract (↑k / x)| := abs_mul _ _
        _ ≤ |c| * 1 := by
            apply mul_le_mul_of_nonneg_left _ (abs_nonneg _)
            rw [abs_of_nonneg (Int.fract_nonneg _)]
            exact le_of_lt (Int.fract_lt_one _)
        _ = |c| := mul_one _))

/-- nbLinComb is integrable on [0,1]. -/
theorem nbLinComb_integrable (N : ℕ) (w : Fin (N - 1) → ℝ) :
    IntervalIntegrable (nbLinComb N w) MeasureTheory.volume 0 1 := by
  unfold nbLinComb
  have h_sum : (fun x : ℝ => ∑ i : Fin (N - 1), w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) =
    (∑ i : Fin (N - 1), fun x : ℝ => w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) := by
    ext x; simp [Finset.sum_apply]
  rw [h_sum]
  apply IntervalIntegrable.sum; intro i _
  exact single_fract_integrable (i.val + 1) (w i)

/-- ∫₀¹ nbLinComb = bᵀw. -/
theorem integral_nbLinComb_eq_dotProduct (N : ℕ) (w : Fin (N - 1) → ℝ) :
    ∫ x in (0:ℝ)..1, nbLinComb N w x =
    dotProduct (basisInnerProd N) w := by
  unfold nbLinComb dotProduct basisInnerProd
  conv_lhs =>
    rw [show (fun x : ℝ => ∑ i : Fin (N - 1), w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) =
      (fun x => ∑ i ∈ Finset.univ, (fun i x => w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) i x) from by
      ext x; simp]
  rw [intervalIntegral.integral_finset_sum]
  · congr 1; ext i
    rw [intervalIntegral.integral_const_mul, mul_comm]
  · intro i _
    exact single_fract_integrable (i.val + 1) (w i)

/-- **THE L² ↔ MATRIX BRIDGE** (PROVEN):
    ∫₀¹ (1 - Σ wᵢ{(i+1)/x})² dx = 1 - 2·bᵀw + wᵀGw. -/
theorem l2_error_eq_quad_error (N : ℕ) (hN : 2 ≤ N) (w : Fin (N - 1) → ℝ) :
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N w x) ^ 2 =
    1 - 2 * dotProduct (basisInnerProd N) w + realQuadForm (gramMatrix N) w := by
  have h_expand : (fun x : ℝ => (1 - nbLinComb N w x) ^ 2) =
      (fun x : ℝ => 1 - 2 * nbLinComb N w x + (nbLinComb N w x) ^ 2) := by
    ext x; ring
  rw [h_expand]
  have hi_const : IntervalIntegrable (fun _ : ℝ => (1:ℝ)) MeasureTheory.volume 0 1 :=
    intervalIntegrable_const
  have hi_2f : IntervalIntegrable (fun x => 2 * nbLinComb N w x) MeasureTheory.volume 0 1 :=
    (nbLinComb_integrable N w).const_mul 2
  have hi_sq : IntervalIntegrable (fun x => (nbLinComb N w x) ^ 2) MeasureTheory.volume 0 1 :=
    nbLinComb_sq_integrable N w
  have h_sub_add : ∫ x in (0:ℝ)..1, (1 - 2 * nbLinComb N w x + (nbLinComb N w x) ^ 2) =
      (∫ x in (0:ℝ)..1, (1:ℝ)) - (∫ x in (0:ℝ)..1, 2 * nbLinComb N w x) +
      (∫ x in (0:ℝ)..1, (nbLinComb N w x) ^ 2) := by
    rw [show (fun x : ℝ => 1 - 2 * nbLinComb N w x + (nbLinComb N w x) ^ 2) =
        (fun x => (1 - 2 * nbLinComb N w x) + (nbLinComb N w x) ^ 2) from by ext x; ring]
    rw [intervalIntegral.integral_add (hi_const.sub hi_2f) hi_sq]
    rw [show (fun x : ℝ => 1 - 2 * nbLinComb N w x) =
        (fun x => (1:ℝ) - 2 * nbLinComb N w x) from rfl]
    rw [intervalIntegral.integral_sub hi_const hi_2f]
  rw [h_sub_add]
  rw [intervalIntegral.integral_const, sub_zero, smul_eq_mul, mul_one]
  rw [show (fun x : ℝ => 2 * nbLinComb N w x) = (fun x => (2:ℝ) * nbLinComb N w x) from rfl,
      intervalIntegral.integral_const_mul, integral_nbLinComb_eq_dotProduct]
  rw [gram_l2_identity N hN w]

end
