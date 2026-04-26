/-!
  Cathedral/Perron/Defs.lean

  Core definitions for the Perron formula contour integration:
  Perron kernel, vertical integrals, rectangle contours, and
  the Dirichlet series cutoff machinery.

  Zero sorry. Zero axioms.
-/
import Mathlib.Analysis.Complex.CauchyIntegral
import Mathlib.Analysis.Complex.RemovableSingularity
import Mathlib.Analysis.SpecialFunctions.Complex.LogDeriv
import Mathlib.Analysis.SpecialFunctions.Pow.Deriv
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Bounds
import Mathlib.Analysis.Real.Pi.Bounds

/-!
# Perron Kernel: Definitions and Basic Properties

This file defines the Perron kernel integrand `y^s/s`, the truncated Perron integral
`(1/2π) ∫_{-T}^{T} y^(c+tI)/(c+tI) dt`, and establishes basic differentiability,
norm bounds, and prefactor absorption lemmas.

## Main definitions

* `perronIntegrand y s` : the function `y^s / s` for `y : ℝ` and `s : ℂ`
* `perronIntegral y c T` : the truncated vertical line integral `(1/2π) ∫_{-T}^T y^(c+tI)/(c+tI) dt`

## Main results

* `perronIntegrand_differentiableAt` : `y^s/s` is differentiable for `y > 0`, `s ≠ 0`
* `perronIntegrand_norm` : `‖y^s/s‖ = y^(Re s) / ‖s‖`
* `perronIntegrand_bound_on_horizontal` : `‖y^s/s‖ ≤ y^σ/T` on horizontal lines
* `norm_one_div_two_pi_le` : `‖1/(2π)‖ ≤ 1`
-/

noncomputable section
open Complex Real MeasureTheory Set BigOperators ComplexConjugate

namespace Cathedral.Perron

-- ═══════════════════════════════════════════
-- §1. The Perron Kernel Integrand
-- ═══════════════════════════════════════════

/-- The Perron kernel integrand: y^s / s. -/
def perronIntegrand (y : ℝ) (s : ℂ) : ℂ :=
  (y : ℂ) ^ s / s

/-- The vertical line integral over [c-iT, c+iT] of y^s/s.
    With s = c + it, ds = i·dt, so (1/2πi)·∫f·ds = (1/2π)·∫f·dt. -/
def perronIntegral (y c T : ℝ) : ℂ :=
  (1 / (2 * ↑Real.pi)) *
    ∫ t in (-T)..T, perronIntegrand y (c + t * I)

-- ═══════════════════════════════════════════
-- §2. Differentiability of y^s/s away from s=0
-- ═══════════════════════════════════════════

/-- y^s is differentiable for y > 0. -/
lemma differentiableAt_cpow_const {y : ℝ} (hy : 0 < y) (s : ℂ) :
    DifferentiableAt ℂ (fun z => (y : ℂ) ^ z) s := by
  have hy_ne : (y : ℂ) ≠ 0 := Complex.ofReal_ne_zero.mpr (ne_of_gt hy)
  exact DifferentiableAt.const_cpow differentiableAt_id (Or.inl hy_ne)

/-- y^s/s is differentiable away from s = 0, for y > 0. -/
lemma perronIntegrand_differentiableAt {y : ℝ} (hy : 0 < y) {s : ℂ} (hs : s ≠ 0) :
    DifferentiableAt ℂ (perronIntegrand y) s := by
  exact (differentiableAt_cpow_const hy s).div differentiableAt_id hs

-- ═══════════════════════════════════════════
-- §3. Basic Norm Bounds
-- ═══════════════════════════════════════════

/-- The norm of the Perron integrand: ‖y^s/s‖ = y^(Re s) / ‖s‖ for y > 0, s ≠ 0. -/
lemma perronIntegrand_norm {y : ℝ} (hy : 0 < y) {s : ℂ} (_hs : s ≠ 0) :
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
-- §4. Prefactor Bounds
-- ═══════════════════════════════════════════

/-- ‖1/(2π)‖ ≤ 1. Used in every Perron formula application to absorb the prefactor.
    Proof: 1/(2π) < 1 since 2π > 1. -/
lemma norm_one_div_two_pi_le : ‖(1 : ℂ) / (2 * ↑Real.pi)‖ ≤ 1 := by
  rw [norm_div, norm_one, norm_mul, Complex.norm_ofNat]
  rw [show ‖(↑Real.pi : ℂ)‖ = Real.pi from by
    rw [Complex.norm_real]; exact abs_of_pos Real.pi_pos]
  rw [div_le_one (by positivity : (0:ℝ) < 2 * Real.pi)]
  linarith [Real.pi_gt_three]

/-- Absorbing the 1/(2π) prefactor: ‖(1/(2π)) * z‖ ≤ ‖z‖. -/
lemma norm_one_div_two_pi_mul_le (z : ℂ) :
    ‖(1 / (2 * ↑Real.pi)) * z‖ ≤ ‖z‖ := by
  rw [norm_mul]
  calc ‖(1 : ℂ) / (2 * ↑Real.pi)‖ * ‖z‖ ≤ 1 * ‖z‖ :=
        mul_le_mul_of_nonneg_right norm_one_div_two_pi_le (norm_nonneg _)
    _ = ‖z‖ := one_mul _

end Cathedral.Perron
