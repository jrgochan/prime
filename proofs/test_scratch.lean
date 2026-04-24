/-
  Scratch file: testing rpow lemmas needed for PerronMoebius assembly.
  These will be pulled into AssemblyHelpers or PerronMoebius once verified.
-/

import Mathlib.Analysis.SpecialFunctions.Pow.Real
import Mathlib.Analysis.Real.Pi.Bounds

open Real

-- ═══════════════════════════════════════════
-- §1. rpow lemmas for T = X²
-- ═══════════════════════════════════════════

/-- (X²)^{-1/2} = X^{-1} for X > 0. -/
lemma rpow_sq_neg_half {X : ℝ} (hX : 0 < X) :
    (X ^ (2 : ℝ)) ^ (-((1:ℝ)/2)) = X ^ (-(1 : ℝ)) := by
  rw [← rpow_mul hX.le]; norm_num

/-- (X²)^{e} = X^{2e} for X > 0. -/
lemma rpow_sq_mul {X e : ℝ} (hX : 0 < X) :
    (X ^ (2 : ℝ)) ^ e = X ^ (2 * e) := by
  rw [← rpow_mul hX.le]

/-- X^{a} / X^{(2:ℝ)} = X^{a-2} for X > 0. -/
lemma rpow_div_sq {X a : ℝ} (hX : 0 < X) :
    X ^ a / X ^ (2 : ℝ) = X ^ (a - 2) := by
  rw [← rpow_sub hX]

-- ═══════════════════════════════════════════
-- §2. The exponent collapse lemmas (with T = X²)
-- ═══════════════════════════════════════════

/-- Perron term: K * X^{c+1} / X² = K * X^{c-1}. -/
lemma perron_exp_collapse {K X c : ℝ} (hX : 0 < X) :
    K * X ^ (c + 1) / X ^ (2 : ℝ) = K * X ^ (c - 1) := by
  rw [mul_div_assoc, rpow_div_sq hX]; congr 1; ring

/-- Shift term: K₁ * X^c * (X²)^{-1/2} = K₁ * X^{c-1}. -/
lemma shift_exp_collapse {K₁ X c : ℝ} (hX : 0 < X) :
    K₁ * X ^ c * (X ^ (2 : ℝ)) ^ (-((1:ℝ)/2)) = K₁ * X ^ (c - 1) := by
  rw [rpow_sq_neg_half hX, mul_assoc, ← rpow_add hX]; ring_nf

/-- Vertical term: K₂ * X^σ₀ * (X²)^{eps'} = K₂ * X^{σ₀ + 2*eps'}. -/
lemma vert_exp_collapse {K₂ X sigma0 eps' : ℝ} (hX : 0 < X) :
    K₂ * X ^ sigma0 * (X ^ (2 : ℝ)) ^ eps' = K₂ * X ^ (sigma0 + 2 * eps') := by
  rw [rpow_sq_mul hX, mul_assoc, ← rpow_add hX]

-- ═══════════════════════════════════════════
-- §3. The 1/(2π) extraction lemma
-- ═══════════════════════════════════════════

/-- ‖1/(2π)‖ ≤ 1 (needed to extract prefactor from shift bound). -/
lemma norm_one_div_two_pi_le : ‖(1 / (2 * ↑Real.pi) : ℂ)‖ ≤ 1 := by
  rw [norm_div, norm_one, norm_mul, Complex.norm_ofNat]
  rw [show ‖(↑Real.pi : ℂ)‖ = Real.pi from by
    rw [Complex.norm_real]; exact abs_of_pos Real.pi_pos]
  rw [div_le_one (by positivity : (0:ℝ) < 2 * Real.pi)]
  linarith [pi_gt_three]

-- ═══════════════════════════════════════════
-- §4. Push X → x via X ≤ (3/2)*x
-- ═══════════════════════════════════════════

/-- X^α ≤ (a*x)^α for X ≤ a*x, X > 0, α > 0. -/
lemma rpow_le_mul_rpow {X x a α : ℝ} (hX : 0 < X) (hx : 0 < x) (ha : 0 < a)
    (hα : 0 < α) (h : X ≤ a * x) :
    X ^ α ≤ a ^ α * x ^ α := by
  calc X ^ α ≤ (a * x) ^ α := rpow_le_rpow hX.le h hα.le
    _ = a ^ α * x ^ α := mul_rpow ha.le hx.le
