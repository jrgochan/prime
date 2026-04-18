/-
  Cathedral/White/Infrastructure/PerronKernel.lean

  ## The Quantitative Perron Kernel

  PHYSICS: The propagator in momentum space — single particle contribution.
  MATH: The contour integral of y^s/s over a vertical line, bounded by rectangle.

  ### Strategy (The Theorist's Blueprint):
  For a single y > 0, y ≠ 1:
    (1/2πi) ∫_{c-iT}^{c+iT} y^s/s ds ≈ { 1  if y > 1
                                           { 0  if y < 1
  with error O(y^c / (πT|log y|)).

  Proof: Complete the contour to a rectangle using Mathlib's
  `integral_boundary_rect_eq_zero_of_differentiable_on_off_countable`.
  - y > 1: close left, pick up residue at s = 0 (= 1)
  - y < 1: close right, no poles (= 0)
  Horizontal segments give the error bound.

  ### Mathlib Dependencies:
  - `Analysis.Complex.CauchyIntegral` (rectangle integral vanishing)
  - `Analysis.Complex.CauchyIntegral` (Cauchy integral formula for residue)

  ### Cathedral Dependencies: None (pure complex analysis).
-/

import Mathlib.Analysis.Complex.CauchyIntegral
import Mathlib.Analysis.SpecialFunctions.Complex.LogDeriv
import Mathlib.Analysis.SpecialFunctions.Pow.Deriv
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

noncomputable section
open Complex Real MeasureTheory Set BigOperators

namespace Cathedral.White.Infrastructure

-- ═══════════════════════════════════════════
-- §1. The Perron Kernel Integrand
-- ═══════════════════════════════════════════

/-- The Perron kernel integrand: y^s / s. -/
def perronIntegrand (y : ℝ) (s : ℂ) : ℂ :=
  (y : ℂ) ^ s / s

/-- The vertical line integral over [c-iT, c+iT] of y^s/s. -/
def perronIntegral (y c T : ℝ) : ℂ :=
  (1 / (2 * Real.pi * I)) *
    ∫ t in (-T)..T, perronIntegrand y (c + t * I)

-- ═══════════════════════════════════════════
-- §2. Differentiability of y^s/s away from s=0
-- ═══════════════════════════════════════════

/-- y^s is differentiable for y > 0. -/
private lemma differentiableAt_cpow_const {y : ℝ} (hy : 0 < y) (s : ℂ) :
    DifferentiableAt ℂ (fun z => (y : ℂ) ^ z) s := by
  have hy_ne : (y : ℂ) ≠ 0 := Complex.ofReal_ne_zero.mpr (ne_of_gt hy)
  exact DifferentiableAt.const_cpow differentiableAt_id (Or.inl hy_ne)

/-- y^s/s is differentiable away from s = 0, for y > 0. -/
lemma perronIntegrand_differentiableAt {y : ℝ} (hy : 0 < y) {s : ℂ} (hs : s ≠ 0) :
    DifferentiableAt ℂ (perronIntegrand y) s := by
  exact (differentiableAt_cpow_const hy s).div differentiableAt_id hs

-- ═══════════════════════════════════════════
-- §3. Horizontal Segment Bounds
-- ═══════════════════════════════════════════

/-- On a horizontal segment at height T, the integrand is bounded by y^σ/T. -/
lemma perronIntegrand_horizontal_bound {y : ℝ} (hy : 0 < y) {σ T : ℝ} (hT : 0 < T)
    (s : ℂ) (hs_im : s.im = T ∨ s.im = -T) (hs_re_range : s.re ∈ Set.Icc 0 σ ∨ s.re ∈ Set.Icc σ 0) :
    ‖perronIntegrand y s‖ ≤ y ^ (max σ 0) / T := by
  sorry -- Straightforward: ‖y^s‖ = y^(Re s), ‖s‖ ≥ |Im s| = T

/-- The integral over a horizontal segment vanishes as O(σ·y^σ/T). -/
lemma horizontal_segment_bound {y σ T : ℝ} (hy : 0 < y) (hT : 0 < T) (hσ : 0 < σ) :
    ‖∫ x in (0:ℝ)..σ, perronIntegrand y (x + T * I)‖ ≤ σ * y ^ σ / T := by
  sorry -- Apply MeasureTheory.norm_integral_le_of_norm_le + perronIntegrand_horizontal_bound

-- ═══════════════════════════════════════════
-- §4. The Perron Kernel for y > 1 (Residue = 1)
-- ═══════════════════════════════════════════

/-- **KEY LEMMA**: For y > 1 and c > 0, the Perron integral equals 1 up to O(y^c / (T·|log y|)).

    Proof strategy:
    1. Apply `integral_boundary_rect_eq_zero_of_differentiable_on_off_countable`
       to the rectangle with corners c-iT, c+iT, -R-iT, -R+iT.
    2. The integrand y^s/s is holomorphic everywhere except s=0.
    3. The rectangle contains s=0 (since c > 0, R > 0), so apply
       Cauchy integral formula: residue at s=0 of y^s/s = y^0 = 1.
    4. As R → ∞, the left vertical segment → 0 (since y > 1, y^{-R} → 0).
    5. Horizontal segments bounded by O(y^c/T).
    6. Combine: ∫_vertical = 2πi·1 - horizontal errors = 2πi + O(y^c/T). -/
theorem perron_kernel_gt_one (y c T : ℝ) (hy : 1 < y) (hc : 0 < c) (hT : 0 < T) :
    ‖perronIntegral y c T - 1‖ ≤ y ^ c / (Real.pi * T * |Real.log y|) := by
  sorry -- Rectangle contour argument via integral_boundary_rect_eq_zero

-- ═══════════════════════════════════════════
-- §5. The Perron Kernel for y < 1 (Residue = 0)
-- ═══════════════════════════════════════════

/-- **KEY LEMMA**: For 0 < y < 1 and c > 0, the Perron integral equals 0 up to O(y^c / (T·|log y|)).

    Proof strategy:
    1. Close the contour to the RIGHT: rectangle c-iT, c+iT, R+iT, R-iT.
    2. No poles inside (s=0 is to the left of c).
    3. By Cauchy-Goursat, the boundary integral = 0.
    4. As R → ∞, the right vertical segment → 0 (since y < 1, y^R → 0).
    5. Horizontal segments bounded by O(y^c/T).
    6. Combine: ∫_vertical = 0 - horizontal errors = O(y^c/T). -/
theorem perron_kernel_lt_one (y c T : ℝ) (hy_pos : 0 < y) (hy_lt : y < 1)
    (hc : 0 < c) (hT : 0 < T) :
    ‖perronIntegral y c T‖ ≤ y ^ c / (Real.pi * T * |Real.log y|) := by
  sorry -- Rectangle contour argument (no residue case)

-- ═══════════════════════════════════════════
-- §6. The Unified Perron Kernel Bound
-- ═══════════════════════════════════════════

/-- **UNIFIED PERRON KERNEL**: The Perron integral approximates the step function.

    For any y > 0, y ≠ 1:
    |(1/2πi) ∫_{c-iT}^{c+iT} y^s/s ds - 𝟙(y > 1)| ≤ y^c / (π·T·|log y|) -/
theorem perron_kernel_bound (y c T : ℝ) (hy : 0 < y) (hy_ne : y ≠ 1)
    (hc : 0 < c) (hT : 0 < T) :
    ‖perronIntegral y c T - (if 1 < y then 1 else 0)‖ ≤
    y ^ c / (Real.pi * T * |Real.log y|) := by
  by_cases h : 1 < y
  · simp only [h, ↑ite_true]
    exact perron_kernel_gt_one y c T h hc hT
  · push_neg at h
    have hlt : y < 1 := lt_of_le_of_ne h hy_ne
    simp only [show ¬(1 < y) from not_lt.mpr (le_of_lt hlt), ↑ite_false]
    simp only [sub_zero]
    exact perron_kernel_lt_one y c T hy hlt hc hT

-- ═══════════════════════════════════════════
-- §7. From Kernel to Summatory Function (The Assembly)
-- ═══════════════════════════════════════════

/-- **PERRON'S FORMULA**: The truncated Perron formula for summatory functions.

    For a : ℕ → ℂ with absolute convergence on Re(s) > 1:
    ∑_{n ≤ x} a(n) = (1/2πi) ∫_{c-iT}^{c+iT} (∑ a(n)/n^s) · x^s/s ds + O(x^c/T)

    This follows by summing `perron_kernel_bound` over n ≤ x,
    applied to y = x/n. The finite sum allows swapping ∑ and ∫. -/
theorem perron_formula_from_kernel
    (a : ℕ → ℂ) (x c T : ℝ) (hx : 0 < x) (hc : 1 < c) (hT : 0 < T)
    (hx_frac : Int.fract x ≠ 0) :
    ‖(∑ n ∈ Finset.Icc 1 ⌊x⌋₊, a n) -
      (1 / (2 * Real.pi * I)) *
      ∫ t in (-T)..T, (∑ n ∈ Finset.Icc 1 ⌊x⌋₊, a n * (n : ℂ) ^ (-(↑c + ↑t * I))) *
        (x : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)‖ ≤
    x ^ c / T := by
  sorry -- Sum over n of perron_kernel_bound(x/n) + swap ∑ and ∫

end Cathedral.White.Infrastructure
