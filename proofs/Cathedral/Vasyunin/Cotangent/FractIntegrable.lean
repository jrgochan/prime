/-
  Cathedral/Vasyunin/Cotangent/FractIntegrable.lean

  ## INTEGRABILITY OF FRACTIONAL-PART PRODUCTS

  Proves that `u ↦ Int.fract(1/(j'·u)) · Int.fract(1/(k'·u))` is integrable
  on bounded intervals [0, a] and [1, d].

  ### Key Results:
  1. `Int.fract` is bounded by 1 (from Mathlib)
  2. Compositions of measurable functions are measurable
  3. Bounded + measurable on finite-measure sets → integrable

  Created: April 25, 2026 — The Weekend Assault
  Status: Building...
-/

import Mathlib.MeasureTheory.Function.Floor
import Mathlib.MeasureTheory.Integral.IntegrableOn
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

noncomputable section
open Real MeasureTheory Set

namespace Cathedral.Vasyunin.FractIntegrable

-- ════════════════════════════════════════════════
-- §1. FRACTIONAL PART BOUNDS
-- ════════════════════════════════════════════════

/-- The fractional part is bounded: 0 ≤ {x} < 1. -/
theorem fract_nonneg (x : ℝ) : 0 ≤ Int.fract x := Int.fract_nonneg x

theorem fract_lt_one (x : ℝ) : Int.fract x < 1 := Int.fract_lt_one x

/-- The norm of a fractional part is at most 1. -/
theorem norm_fract_le (x : ℝ) : ‖Int.fract x‖ ≤ 1 := by
  rw [Real.norm_eq_abs, abs_of_nonneg (Int.fract_nonneg x)]
  linarith [Int.fract_lt_one x]

/-- Product of fractional parts has norm ≤ 1. -/
theorem norm_fract_mul_fract_le (x y : ℝ) :
    ‖Int.fract x * Int.fract y‖ ≤ 1 := by
  rw [norm_mul]
  calc ‖Int.fract x‖ * ‖Int.fract y‖
      ≤ 1 * 1 := mul_le_mul (norm_fract_le x) (norm_fract_le y)
          (norm_nonneg _) (by linarith)
    _ = 1 := one_mul 1

-- ════════════════════════════════════════════════
-- §2. MEASURABILITY
-- ════════════════════════════════════════════════

/-- The function u ↦ Int.fract(c/u) is measurable for any constant c. -/
theorem measurable_fract_div (c : ℝ) :
    Measurable (fun u : ℝ => Int.fract (c / u)) :=
  Measurable.fract (measurable_const.div measurable_id)

/-- The function u ↦ Int.fract(1/(n·u)) is measurable for any natural n. -/
theorem measurable_fract_inv_mul (n : ℕ) :
    Measurable (fun u : ℝ => Int.fract (1 / ((n:ℝ) * u))) :=
  Measurable.fract (measurable_const.div (measurable_const.mul measurable_id))

/-- Product of two fractional-part functions is measurable. -/
theorem measurable_fract_product (j' k' : ℕ) :
    Measurable (fun u : ℝ =>
      Int.fract (1 / ((j':ℝ) * u)) * Int.fract (1 / ((k':ℝ) * u))) :=
  (measurable_fract_inv_mul j').mul (measurable_fract_inv_mul k')

-- ════════════════════════════════════════════════
-- §3. AE STRONGLY MEASURABLE
-- ════════════════════════════════════════════════

/-- The fractional-part product is AE strongly measurable. -/
theorem aestronglyMeasurable_fract_product (j' k' : ℕ) :
    AEStronglyMeasurable
      (fun u : ℝ => Int.fract (1 / ((j':ℝ) * u)) * Int.fract (1 / ((k':ℝ) * u)))
      MeasureTheory.volume :=
  (measurable_fract_product j' k').aestronglyMeasurable

-- ════════════════════════════════════════════════
-- §4. INTEGRABILITY ON BOUNDED INTERVALS
-- ════════════════════════════════════════════════

/-- The fractional-part product is integrable on any bounded interval [a, b]. -/
theorem integrableOn_fract_product_Icc (j' k' : ℕ) (a b : ℝ) :
    IntegrableOn
      (fun u : ℝ => Int.fract (1 / ((j':ℝ) * u)) * Int.fract (1 / ((k':ℝ) * u)))
      (Set.Icc a b) volume := by
  apply Measure.integrableOn_of_bounded
  · -- μ(Icc a b) ≠ ∞ for Lebesgue measure on ℝ
    exact measure_Icc_lt_top.ne
  · -- AE strongly measurable
    exact (aestronglyMeasurable_fract_product j' k')
  · -- ‖f x‖ ≤ 1 for all x
    apply Filter.Eventually.of_forall
    intro x
    exact norm_fract_mul_fract_le _ _

/-- The fractional-part product is interval-integrable on [0, 1]. -/
theorem intervalIntegrable_fract_product_01 (j' k' : ℕ) :
    IntervalIntegrable
      (fun u : ℝ => Int.fract (1 / ((j':ℝ) * u)) * Int.fract (1 / ((k':ℝ) * u)))
      volume 0 1 := by
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
  exact (integrableOn_fract_product_Icc j' k' 0 1).mono_set Ioc_subset_Icc_self

/-- The fractional-part product is interval-integrable on [1, d]. -/
theorem intervalIntegrable_fract_product_1d (j' k' d : ℕ) (hd : 2 ≤ d) :
    IntervalIntegrable
      (fun u : ℝ => Int.fract (1 / ((j':ℝ) * u)) * Int.fract (1 / ((k':ℝ) * u)))
      volume 1 (d:ℝ) := by
  have h1d : (1:ℝ) ≤ (d:ℝ) := by exact_mod_cast (by omega : 1 ≤ d)
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le h1d]
  exact (integrableOn_fract_product_Icc j' k' 1 d).mono_set Ioc_subset_Icc_self

/-- The fractional-part product is interval-integrable on [0, d]. -/
theorem intervalIntegrable_fract_product_0d (j' k' d : ℕ) (hd : 2 ≤ d) :
    IntervalIntegrable
      (fun u : ℝ => Int.fract (1 / ((j':ℝ) * u)) * Int.fract (1 / ((k':ℝ) * u)))
      volume 0 (d:ℝ) := by
  have h0d : (0:ℝ) ≤ (d:ℝ) := by exact_mod_cast (by omega : 0 ≤ d)
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le h0d]
  exact (integrableOn_fract_product_Icc j' k' 0 d).mono_set Ioc_subset_Icc_self

end Cathedral.Vasyunin.FractIntegrable
