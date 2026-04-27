-- Scratch: full FK2 pipeline
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Sinc
import Mathlib.Analysis.SpecialFunctions.ImproperIntegrals
import Mathlib.MeasureTheory.Integral.Bochner.Basic

open Real MeasureTheory

noncomputable section

-- |sinc(y)| ≤ |y|⁻¹ for y ≠ 0
lemma abs_sinc_le_inv (y : ℝ) (hy : y ≠ 0) : |sinc y| ≤ |y|⁻¹ := by
  rw [sinc_of_ne_zero hy, abs_div, inv_eq_one_div]
  exact div_le_div_of_nonneg_right (abs_sin_le_one y) (abs_pos.mpr hy).le

-- sinc²(y) ≤ |y|⁻² for y ≠ 0
lemma sinc_sq_le_inv_sq (y : ℝ) (hy : y ≠ 0) : sinc y ^ 2 ≤ |y|⁻¹ ^ 2 := by
  rw [← sq_abs (sinc y)]
  exact pow_le_pow_left₀ (abs_nonneg _) (abs_sinc_le_inv y hy) 2

-- sinc²(πx) * (1+x²) ≤ 2 for all x
lemma sinc_sq_mul_one_add_sq (x : ℝ) : sinc (π * x) ^ 2 * (1 + x ^ 2) ≤ 2 := by
  by_cases hx : x = 0
  · simp [hx, sinc_zero]
  · have hx2 : (0 : ℝ) < x ^ 2 := by positivity
    have hpx : π * x ≠ 0 := mul_ne_zero pi_ne_zero hx
    have h_sinc_sq_le_1 : sinc (π * x) ^ 2 ≤ 1 := by
      nlinarith [sinc_le_one (π * x), neg_one_le_sinc (π * x)]
    by_cases hle : x ^ 2 ≤ 1
    · -- sinc² ≤ 1 and 1+x² ≤ 2
      nlinarith
    · -- x² > 1: use sinc² ≤ |πx|⁻²
      push_neg at hle
      have h_sq := sinc_sq_le_inv_sq (π * x) hpx
      -- |πx|⁻² ≤ 1/x² (since |πx| ≥ |x|, so |πx|⁻¹ ≤ |x|⁻¹)
      have h_pi_bound : |π * x|⁻¹ ≤ |x|⁻¹ := by
        apply inv_anti₀ (abs_pos.mpr hx)
        rw [abs_mul, abs_of_pos pi_pos]
        nlinarith [abs_nonneg x, two_le_pi]
      -- |πx|⁻² ≤ |x|⁻² = 1/x²
      have h_sq_bound : |π * x|⁻¹ ^ 2 ≤ |x|⁻¹ ^ 2 := by
        exact pow_le_pow_left₀ (by positivity) h_pi_bound 2
      -- sinc²(πx) ≤ 1/x²
      have h_sinc_le_invx : sinc (π * x) ^ 2 ≤ |x|⁻¹ ^ 2 := by linarith
      -- Simplify |x|⁻² to 1/x²
      have h_inv_eq : |x|⁻¹ ^ 2 = 1 / x ^ 2 := by
        field_simp; rw [sq_abs]
      rw [h_inv_eq] at h_sinc_le_invx
      -- sinc²*(1+x²) ≤ (1/x²)*(1+x²) = 1+1/x² ≤ 2
      have : (1 / x ^ 2) * (1 + x ^ 2) = 1 + 1 / x ^ 2 := by field_simp; ring
      nlinarith [show 1 / x ^ 2 ≤ 1 from by rw [div_le_one₀ hx2]; linarith]
