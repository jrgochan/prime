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

/-- The norm of the Perron integrand: ‖y^s/s‖ = y^(Re s) / ‖s‖ for y > 0, s ≠ 0. -/
lemma perronIntegrand_norm {y : ℝ} (hy : 0 < y) {s : ℂ} (hs : s ≠ 0) :
    ‖perronIntegrand y s‖ = y ^ s.re / ‖s‖ := by
  unfold perronIntegrand
  rw [norm_div, norm_cpow_eq_rpow_re_of_pos hy]

/-- On a horizontal line at height ±T with Re(s) = σ, ‖y^s/s‖ ≤ y^σ/T. -/
lemma perronIntegrand_bound_on_horizontal {y σ : ℝ} (hy : 0 < y) {T : ℝ} (hT : 0 < T)
    {s : ℂ} (hs_re : s.re = σ) (hs_im : |s.im| = T) (hs_ne : s ≠ 0) :
    ‖perronIntegrand y s‖ ≤ y ^ σ / T := by
  rw [perronIntegrand_norm hy hs_ne, hs_re]
  gcongr
  -- Need: T ≤ ‖s‖
  rw [← hs_im]
  exact abs_im_le_norm s

-- ═══════════════════════════════════════════
-- §4. Exponential Decay Integral
-- ═══════════════════════════════════════════

/-- For 0 < y < 1, the integral of y^σ over [c,R] is at most y^c/|log y|. -/
lemma integral_rpow_le_of_lt_one {y c R : ℝ} (hy_pos : 0 < y) (hy_lt : y < 1)
    (hc : 0 ≤ c) (hR : c ≤ R) :
    ∫ σ in c..R, y ^ σ ≤ y ^ c / |Real.log y| := by
  sorry

/-- For y > 1, the integral of y^σ over [-R,c] is at most y^c/log y. -/
lemma integral_rpow_le_of_gt_one {y c R : ℝ} (hy : 1 < y) (hR : 0 ≤ R) :
    ∫ σ in (-R)..c, y ^ σ ≤ y ^ c / Real.log y := by
  sorry

-- ═══════════════════════════════════════════
-- §5. Rectangle Sub-lemmas
-- ═══════════════════════════════════════════

/-- The rectangle integral of y^s/s vanishes when s=0 is outside.
    For the rectangle [c, R] × [-T, T] with c > 0, y^s/s is holomorphic inside.
    Uses Mathlib's integral_boundary_rect_eq_zero_of_differentiable_on_off_countable. -/
lemma rectangle_integral_perron_vanishes {y c R T : ℝ} (hy : 0 < y)
    (hc : 0 < c) (hR : c < R) (hT : 0 < T) :
    (∫ x in c..R, perronIntegrand y (x + (-T) * I)) -
    (∫ x in c..R, perronIntegrand y (x + T * I)) +
    I * (∫ t in (-T)..T, perronIntegrand y (R + t * I)) -
    I * (∫ t in (-T)..T, perronIntegrand y (c + t * I)) = 0 := by
  sorry -- The proof uses integral_boundary_rect_eq_zero with z = ⟨c,-T⟩, w = ⟨R,T⟩
        -- ContinuousOn: perronIntegrand is continuous on [c,R]×[-T,T] (c > 0 so s ≠ 0)
        -- DifferentiableAt: perronIntegrand_differentiableAt at all interior points

/-- The right vertical segment is bounded by 2T·y^R/R for y < 1. -/
lemma right_vertical_bound {y R T : ℝ} (hy_pos : 0 < y) (hy_lt : y < 1)
    (hR : 0 < R) (hT : 0 < T) :
    ‖∫ t in (-T)..T, perronIntegrand y (R + t * I)‖ ≤ 2 * T * y ^ R / R := by
  sorry

-- ═══════════════════════════════════════════
-- §6. The Perron Kernel for y > 1 (Residue = 1)
-- ═══════════════════════════════════════════

/-- **KEY LEMMA**: For y > 1, Perron integral = 1 + O(y^c/(T|log y|)). -/
theorem perron_kernel_gt_one (y c T : ℝ) (hy : 1 < y) (hc : 0 < c) (hT : 0 < T) :
    ‖perronIntegral y c T - 1‖ ≤ y ^ c / (Real.pi * T * |Real.log y|) := by
  sorry

-- ═══════════════════════════════════════════
-- §7. The Perron Kernel for y < 1 (Residue = 0)
-- ═══════════════════════════════════════════

/-- **KEY LEMMA**: For 0 < y < 1, Perron integral = 0 + O(y^c/(T|log y|)). -/
theorem perron_kernel_lt_one (y c T : ℝ) (hy_pos : 0 < y) (hy_lt : y < 1)
    (hc : 0 < c) (hT : 0 < T) :
    ‖perronIntegral y c T‖ ≤ y ^ c / (Real.pi * T * |Real.log y|) := by
  sorry

-- ═══════════════════════════════════════════
-- §8. The Unified Perron Kernel Bound
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
-- §9. From Kernel to Summatory Function (The Assembly)
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
