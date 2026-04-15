/-
  Cathedral/Structural/NbLinComb.lean

  ## NB linear combination and Gram L² identity.

  Defines nbLinComb and proves the core L² identity:
    wᵀGw = ∫₀¹ (Σ wᵢ{(i+1)/x})² dx
-/

import Cathedral.Defs
import Cathedral.Archive.HighFrequencyTrap.Spectral.RayleighBridge
import Mathlib.MeasureTheory.Function.Floor

noncomputable section
open Complex Real

-- Note: nbLinComb is defined in Cathedral/Defs.lean

/-- The function x ↦ Int.fract(j/x) * Int.fract(k/x) is measurable. -/
private lemma fract_div_mul_measurable (j k : ℕ) :
    Measurable (fun x : ℝ => Int.fract (↑j / x) * Int.fract (↑k / x)) :=
  (measurable_const.div measurable_id).fract.mul
    (measurable_const.div measurable_id).fract

/-- Products of fractional parts are bounded by 1. -/
private lemma fract_prod_le_one (j k : ℕ) (x : ℝ) :
    ‖Int.fract (↑j / x) * Int.fract (↑k / x)‖ ≤ ‖(1 : ℝ)‖ := by
  rw [Real.norm_eq_abs, Real.norm_eq_abs, abs_one,
      abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _))]
  calc Int.fract (↑j / x) * Int.fract (↑k / x)
      ≤ 1 * 1 := by
        apply mul_le_mul
        · exact le_of_lt (Int.fract_lt_one _)
        · exact le_of_lt (Int.fract_lt_one _)
        · exact Int.fract_nonneg _
        · linarith
    _ = 1 := mul_one 1

/-- Products of fractional parts are IntervalIntegrable on [0,1]. -/
theorem fract_prod_intervalIntegrable (j k : ℕ) :
    IntervalIntegrable
      (fun x : ℝ => Int.fract (↑j / x) * Int.fract (↑k / x))
      MeasureTheory.volume 0 1 :=
  IntervalIntegrable.mono_fun
    (intervalIntegrable_const (c := (1 : ℝ)))
    ((fract_div_mul_measurable j k).aestronglyMeasurable.restrict)
    (Filter.Eventually.of_forall (fract_prod_le_one j k))

/-- Scaled products inherit integrability (const_mul). -/
private lemma scaled_fract_intervalIntegrable (j k : ℕ) (a b : ℝ) :
    IntervalIntegrable
      (fun x : ℝ => a * Int.fract (↑j / x) * (b * Int.fract (↑k / x)))
      MeasureTheory.volume 0 1 := by
  have : (fun x : ℝ => a * Int.fract (↑j / x) * (b * Int.fract (↑k / x))) =
         (fun x : ℝ => (a * b) * (Int.fract (↑j / x) * Int.fract (↑k / x))) := by
    ext x; ring
  rw [this]
  exact (fract_prod_intervalIntegrable j k).const_mul (a * b)

/-- LHS = double sum over gramEntry (pure algebra). -/
private lemma quadForm_as_double_sum (N : ℕ) (w : Fin (N - 1) → ℝ) :
    realQuadForm (gramMatrix N) w =
    ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
      w i * w j * gramEntry (i.val + 1) (j.val + 1) := by
  unfold realQuadForm dotProduct
  congr 1; ext i
  simp only [Matrix.mulVec, dotProduct, gramMatrix, Matrix.of_apply]
  rw [Finset.mul_sum]
  congr 1; ext j; ring

/-- Each weighted integral = weight × gramEntry (constant factor). -/
private lemma integral_fract_prod_eq (j k : ℕ) (a b : ℝ) :
    ∫ x in (0:ℝ)..1,
      (a * Int.fract (↑j / x)) * (b * Int.fract (↑k / x)) =
    a * b * gramEntry j k := by
  unfold gramEntry
  rw [show (fun x : ℝ => a * Int.fract (↑j / x) * (b * Int.fract (↑k / x))) =
      (fun x : ℝ => (a * b) * (Int.fract (↑j / x) * Int.fract (↑k / x))) from
    by ext x; ring]
  exact intervalIntegral.integral_const_mul (a * b) _

/-- RHS = double sum over gramEntry (sum-integral swap + algebra). -/
private lemma integral_sq_as_double_sum (N : ℕ) (w : Fin (N - 1) → ℝ) :
    ∫ x in (0:ℝ)..1, (nbLinComb N w x) ^ 2 =
    ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
      w i * w j * gramEntry (i.val + 1) (j.val + 1) := by
  have h_sq : (fun x : ℝ => (nbLinComb N w x) ^ 2) =
      (fun x => ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
        (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) := by
    ext x; unfold nbLinComb; rw [sq, Finset.sum_mul_sum]
  rw [h_sq]
  rw [show (fun x : ℝ => ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
        (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) =
      (fun x => ∑ i ∈ Finset.univ, ∑ j ∈ Finset.univ,
        (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) from by
    ext x; simp]
  rw [intervalIntegral.integral_finset_sum]
  congr 1; ext i
  rw [show (fun x : ℝ => ∑ j ∈ Finset.univ,
        (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) =
      (fun x => ∑ j ∈ Finset.univ,
        (fun j x => (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) j x) from by
    ext x; simp]
  rw [intervalIntegral.integral_finset_sum]
  congr 1; ext j
  exact integral_fract_prod_eq (i.val + 1) (j.val + 1) (w i) (w j)
  · intro j _
    exact scaled_fract_intervalIntegrable (i.val + 1) (j.val + 1) (w i) (w j)
  · intro i _
    have : (fun x => ∑ j : Fin (N - 1),
        (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) =
      (∑ j : Fin (N - 1), fun x =>
        (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) := by
      ext x; simp [Finset.sum_apply]
    rw [this]
    exact IntervalIntegrable.sum Finset.univ (fun j _ =>
      scaled_fract_intervalIntegrable (i.val + 1) (j.val + 1) (w i) (w j))

/-- **L² norm identity** (PROVEN): wᵀGw = ∫₀¹ (Σᵢ wᵢ fᵢ)² dx. -/
theorem gram_l2_identity (N : ℕ) (_ : 2 ≤ N) (w : Fin (N - 1) → ℝ) :
    realQuadForm (gramMatrix N) w =
    ∫ x in (0:ℝ)..1, (nbLinComb N w x) ^ 2 := by
  rw [quadForm_as_double_sum, integral_sq_as_double_sum]

end
