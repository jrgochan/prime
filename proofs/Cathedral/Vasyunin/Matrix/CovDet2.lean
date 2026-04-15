/-
  Cathedral/Vasyunin/Matrix/CovDet2.lean

  det(C₂) > 0 for the 2×2 leading minor of the covariance matrix,
  via double quadratic interpolation on (ln π, γ).
-/

import Cathedral.Vasyunin.Matrix.CovEntries

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

/-- Euler-Mascheroni constant γ ≈ 0.5772 -/
local notation "γ" => Real.eulerMascheroniConstant

-- ════════════════════════════════════════════════
-- det(C₂) > 0 VIA DOUBLE INTERPOLATION
-- ════════════════════════════════════════════════

/-- ln(2) < 7/10. Via Taylor: exp(7/10) ≥ Σᵢ₌₀³ (7/10)ⁱ/i! > 2. -/
theorem log_two_lt_seven_tenths : Real.log 2 < 7 / 10 := by
  rw [show (7:ℝ) / 10 = Real.log (Real.exp (7/10)) from (Real.log_exp (7/10)).symm]
  apply Real.log_lt_log (by norm_num : (0:ℝ) < 2)
  have h := Real.sum_le_exp_of_nonneg (by norm_num : (0:ℝ) ≤ 7/10) 4
  simp [Finset.sum_range_succ] at h
  linarith

/-- det(C₂) as a polynomial in (l, p, g) = (ln 2, ln π, γ).
    Concave quadratic in p with leading coefficient -1/16. -/
private def covDet2Expr (l p g : ℝ) : ℝ :=
  (l + p + g - 2 - g ^ 2) * (p / 2 - l ^ 2 / 4 - 1 / 2 + l * g / 2 - g ^ 2 / 4) -
  (3 * p / 4 + g / 4 + l * g / 2 - g ^ 2 / 2 - 1) ^ 2

/-- Algebraic identity: covDet2Expr matches the det expression from covariance entries. -/
private theorem covDet2_eq (l p g : ℝ) :
    (l + p - g - 1 - (1 - g) ^ 2) *
    ((l + p - g) / 2 - 1 / 4 - ((l + 1 - g) / 2) ^ 2) -
    (3 / 4 * (l + p - g) - l / 4 - 1 / 2 - (1 - g) * ((l + 1 - g) / 2)) ^ 2 =
    covDet2Expr l p g := by
  unfold covDet2Expr; ring

-- Helper: if a > 0 and a * b > 0 then b > 0
private theorem pos_of_pos_mul' (a b : ℝ) (ha : 0 < a) (hab : 0 < a * b) : 0 < b := by
  by_contra h; push Not at h
  linarith [mul_nonpos_of_nonneg_of_nonpos (le_of_lt ha) h]

-- Corner certificates: each is a univariate polynomial in l with l ∈ (0.6931, 0.7)
private theorem covDet2_corner_1 (l : ℝ) (hl : 6931/10000 < l) (hl2 : l < 7/10) :
    covDet2Expr l (11*l/7) (1/2) > 0 := by
  unfold covDet2Expr; ring_nf
  nlinarith [sq_nonneg (l - 6931/10000), sq_nonneg (7/10 - l),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l - 6931/10000 by linarith)]

private theorem covDet2_corner_2 (l : ℝ) (hl : 6931/10000 < l) (hl2 : l < 7/10) :
    covDet2Expr l (11*l/7) (2/3) > 0 := by
  unfold covDet2Expr; ring_nf
  nlinarith [sq_nonneg (l - 6931/10000), sq_nonneg (7/10 - l),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l - 6931/10000 by linarith)]

private theorem covDet2_corner_3 (l : ℝ) (hl : 6931/10000 < l) (hl2 : l < 7/10) :
    covDet2Expr l (2*l) (1/2) > 0 := by
  unfold covDet2Expr; ring_nf
  nlinarith [sq_nonneg (l - 6931/10000), sq_nonneg (7/10 - l),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith)]

private theorem covDet2_corner_4 (l : ℝ) (hl : 6931/10000 < l) (hl2 : l < 7/10) :
    covDet2Expr l (2*l) (2/3) > 0 := by
  unfold covDet2Expr; ring_nf
  nlinarith [sq_nonneg (l - 6931/10000), sq_nonneg (7/10 - l),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith)]

-- γ-interpolation: for each p-endpoint, interpolate on γ ∈ [1/2, 2/3]
private theorem covDet2_at_p11l7 (l g : ℝ) (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (hg_lo : 1/2 < g) (hg_hi : g < 2/3) : covDet2Expr l (11*l/7) g > 0 := by
  have h_id : (2/3 - 1/2) * covDet2Expr l (11*l/7) g =
      covDet2Expr l (11*l/7) (1/2) * (2/3 - g) +
      covDet2Expr l (11*l/7) (2/3) * (g - 1/2) +
      1/16 * (2/3 - 1/2) * (g - 1/2) * (2/3 - g) := by unfold covDet2Expr; ring
  have h1 := covDet2_corner_1 l hl hl2
  have h2 := covDet2_corner_2 l hl hl2
  by_cases hg_eq : g = 1/2; · rw [hg_eq]; exact h1
  have hu : 0 < g - 1/2 := lt_of_le_of_ne (by linarith) (fun h => hg_eq (by linarith))
  have hA := mul_nonneg (le_of_lt h1) (by linarith : (0:ℝ) ≤ 2/3 - g)
  have hB := mul_pos h2 hu
  have hC : (0:ℝ) ≤ 1/16 * (2/3 - 1/2) * (g - 1/2) * (2/3 - g) := by nlinarith
  exact pos_of_pos_mul' _ _ (by norm_num : (0:ℝ) < 2/3 - 1/2) (by linarith [h_id])

private theorem covDet2_at_p2l (l g : ℝ) (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (hg_lo : 1/2 < g) (hg_hi : g < 2/3) : covDet2Expr l (2*l) g > 0 := by
  have h_id : (2/3 - 1/2) * covDet2Expr l (2*l) g =
      covDet2Expr l (2*l) (1/2) * (2/3 - g) +
      covDet2Expr l (2*l) (2/3) * (g - 1/2) +
      1/16 * (2/3 - 1/2) * (g - 1/2) * (2/3 - g) := by unfold covDet2Expr; ring
  have h3 := covDet2_corner_3 l hl hl2
  have h4 := covDet2_corner_4 l hl hl2
  by_cases hg_eq : g = 1/2; · rw [hg_eq]; exact h3
  have hu : 0 < g - 1/2 := lt_of_le_of_ne (by linarith) (fun h => hg_eq (by linarith))
  have hA := mul_nonneg (le_of_lt h3) (by linarith : (0:ℝ) ≤ 2/3 - g)
  have hB := mul_pos h4 hu
  have hC : (0:ℝ) ≤ 1/16 * (2/3 - 1/2) * (g - 1/2) * (2/3 - g) := by nlinarith
  exact pos_of_pos_mul' _ _ (by norm_num : (0:ℝ) < 2/3 - 1/2) (by linarith [h_id])

-- p-interpolation: main det(C₂) > 0
private theorem covDet2_pos (l p g : ℝ) (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (hp_lo : 11*l/7 ≤ p) (hp_hi : p ≤ 2*l)
    (hg_lo : 1/2 < g) (hg_hi : g < 2/3) : covDet2Expr l p g > 0 := by
  have h_id : (2*l - 11*l/7) * covDet2Expr l p g =
      covDet2Expr l (11*l/7) g * (2*l - p) +
      covDet2Expr l (2*l) g * (p - 11*l/7) +
      1/16 * (2*l - 11*l/7) * (p - 11*l/7) * (2*l - p) := by unfold covDet2Expr; ring
  have h_lo := covDet2_at_p11l7 l g hl hl2 hg_lo hg_hi
  have h_hi := covDet2_at_p2l l g hl hl2 hg_lo hg_hi
  by_cases hp_eq : p = 11*l/7; · rw [hp_eq]; exact h_lo
  have hu : 0 < p - 11*l/7 := lt_of_le_of_ne (by linarith) (fun h => hp_eq (by linarith))
  have hD : 0 < 2*l - 11*l/7 := by linarith
  have hA := mul_nonneg (le_of_lt h_lo) (by linarith : (0:ℝ) ≤ 2*l - p)
  have hB := mul_pos h_hi hu
  have hv : (0:ℝ) ≤ 2*l - p := by linarith
  have hC : (0:ℝ) ≤ 1/16 * (2*l - 11*l/7) * (p - 11*l/7) * (2*l - p) := by
    have := mul_nonneg (mul_nonneg (mul_nonneg (by norm_num : (0:ℝ) ≤ 1/16) (le_of_lt hD)) (le_of_lt hu)) hv
    linarith
  exact pos_of_pos_mul' _ _ hD (by linarith [h_id])

/-- **det(C₂) > 0** for the covariance matrix. Margin ≈ 0.0043.
    Proven via double quadratic interpolation on (p = ln π, γ). -/
theorem covMatrix3_det2_pos :
    (vasyuninCovMatrix 3) 0 0 * (vasyuninCovMatrix 3) 1 1 -
    (vasyuninCovMatrix 3) 0 1 ^ 2 > 0 := by
  rw [covEntry_00, covEntry_01, covEntry_11]
  have h_log2pi : Real.log (2 * Real.pi) = Real.log 2 + Real.log Real.pi :=
    Real.log_mul (by norm_num : (2 : ℝ) ≠ 0) (ne_of_gt Real.pi_pos)
  rw [h_log2pi]
  rw [covDet2_eq]
  exact covDet2_pos _ _ _
    (by linarith [Real.log_two_gt_d9] : (6931 : ℝ) / 10000 < Real.log 2)
    log_two_lt_seven_tenths
    (le_trans (log_three_ge_11_log_two_div_7) (Real.log_le_log (by norm_num) (le_of_lt pi_gt_three)))
    (by have : Real.log Real.pi ≤ Real.log 4 :=
          Real.log_le_log (by positivity) (le_of_lt Real.pi_lt_four)
        have : Real.log 4 = 2 * Real.log 2 := by
          rw [show (4:ℝ) = 2^2 from by norm_num, Real.log_pow]; ring
        linarith)
    Real.one_half_lt_eulerMascheroniConstant
    Real.eulerMascheroniConstant_lt_two_thirds

end Cathedral.Vasyunin
