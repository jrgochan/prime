/-
  Complete det(C₂) > 0 proof for the covariance matrix.
  
  Strategy: 
  1. covDet2Expr is concave quadratic in p = ln(π) (coeff -1/16)
  2. Each p-endpoint eval is concave quadratic in g = γ (coeff -1/16)
  3. Double interpolation reduces to 4 univariate checks in l = ln(2)
  4. Each check closes with nlinarith using l ∈ (0.6931, 0.7)
-/

import Cathedral.MellinBridge.Vasyunin.GramEvaluations

set_option maxHeartbeats 3200000
noncomputable section
open Real Matrix

namespace Cathedral.Vasyunin

local notation "γ" => Real.eulerMascheroniConstant

-- ════════════════════════════════════════════════
-- THE COVARIANCE DET₂ EXPRESSION
-- ════════════════════════════════════════════════

/-- det(C₂) as a polynomial in (l, p, g) = (ln 2, ln π, γ). -/
private def covDet2Expr (l p g : ℝ) : ℝ :=
  (l + p + g - 2 - g ^ 2) * (p / 2 - l ^ 2 / 4 - 1 / 2 + l * g / 2 - g ^ 2 / 4) -
  (3 * p / 4 + g / 4 + l * g / 2 - g ^ 2 / 2 - 1) ^ 2

/-- covDet2Expr matches the actual covariance matrix expression. -/
private theorem covDet2_eq (l p g : ℝ) :
    (l + p - g - 1 - (1 - g) ^ 2) *
    ((l + p - g) / 2 - 1 / 4 - ((l + 1 - g) / 2) ^ 2) -
    (3 / 4 * (l + p - g) - l / 4 - 1 / 2 - (1 - g) * ((l + 1 - g) / 2)) ^ 2 =
    covDet2Expr l p g := by
  unfold covDet2Expr; ring

-- ════════════════════════════════════════════════
-- BOUND: ln(2) < 7/10
-- ════════════════════════════════════════════════

/-- ln(2) < 7/10. Via Taylor: exp(7/10) ≥ Σᵢ₌₀³ (7/10)ⁱ/i! > 2. -/
theorem log_two_lt_seven_tenths : Real.log 2 < 7 / 10 := by
  rw [show (7:ℝ) / 10 = Real.log (Real.exp (7/10)) from (Real.log_exp (7/10)).symm]
  apply Real.log_lt_log (by norm_num : (0:ℝ) < 2)
  have h := Real.sum_le_exp_of_nonneg (by norm_num : (0:ℝ) ≤ 7/10) 4
  simp [Finset.sum_range_succ] at h
  linarith

-- ════════════════════════════════════════════════
-- 4 CORNER CERTIFICATES
-- ════════════════════════════════════════════════

/-- Corner (p=11l/7, γ=1/2): margin ≈ 0.001. -/
private theorem covDet2_corner_1 (l : ℝ) (hl : 6931 / 10000 < l) (hl2 : l < 7 / 10) :
    covDet2Expr l (11 * l / 7) (1/2 : ℝ) > 0 := by
  unfold covDet2Expr; ring_nf
  nlinarith [sq_nonneg (l - 6931/10000), sq_nonneg (7/10 - l),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l - 6931/10000 by linarith)]

/-- Corner (p=11l/7, γ=2/3): tightest corner, margin ≈ 0.00015. -/
private theorem covDet2_corner_2 (l : ℝ) (hl : 6931 / 10000 < l) (hl2 : l < 7 / 10) :
    covDet2Expr l (11 * l / 7) (2/3 : ℝ) > 0 := by
  unfold covDet2Expr; ring_nf
  nlinarith [sq_nonneg (l - 6931/10000), sq_nonneg (7/10 - l),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l - 6931/10000 by linarith)]

/-- Corner (p=2l, γ=1/2): margin ≈ 0.015. -/
private theorem covDet2_corner_3 (l : ℝ) (hl : 6931 / 10000 < l) (hl2 : l < 7 / 10) :
    covDet2Expr l (2 * l) (1/2 : ℝ) > 0 := by
  unfold covDet2Expr; ring_nf
  nlinarith [sq_nonneg (l - 6931/10000), sq_nonneg (7/10 - l),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith)]

/-- Corner (p=2l, γ=2/3): margin ≈ 0.012. -/
private theorem covDet2_corner_4 (l : ℝ) (hl : 6931 / 10000 < l) (hl2 : l < 7 / 10) :
    covDet2Expr l (2 * l) (2/3 : ℝ) > 0 := by
  unfold covDet2Expr; ring_nf
  nlinarith [sq_nonneg (l - 6931/10000), sq_nonneg (7/10 - l),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith)]

-- ════════════════════════════════════════════════
-- QUADRATIC INTERPOLATION LEMMAS
-- ════════════════════════════════════════════════


-- Simpler version: if product is positive and multiplier is positive, result is positive
private theorem pos_of_pos_mul (a b : ℝ) (ha : 0 < a) (hab : 0 < a * b) : 0 < b := by
  by_contra h; push Not at h
  linarith [mul_nonpos_of_nonneg_of_nonpos (le_of_lt ha) h]

-- ════════════════════════════════════════════════
-- γ-INTERPOLATION FOR EACH p-ENDPOINT
-- ════════════════════════════════════════════════

/-- f(11l/7, g) > 0 via γ-interpolation from corners 1 and 2. -/
private theorem covDet2_at_p11l7 (l g : ℝ)
    (hl : 6931 / 10000 < l) (hl2 : l < 7 / 10)
    (hg_lo : 1 / 2 < g) (hg_hi : g < 2 / 3) :
    covDet2Expr l (11 * l / 7) g > 0 := by
  -- Identity: (1/6)·f(g) = f(1/2)·(2/3-g) + f(2/3)·(g-1/2) + (1/96)·(g-1/2)·(2/3-g)
  -- Multiply by 6:
  -- f(g) = 6·f(1/2)·(2/3-g) + 6·f(2/3)·(g-1/2) + (1/16)·(g-1/2)·(2/3-g)
  -- Wait, that's (b-a) = 1/6. The identity is:
  -- (1/6)·f(g) = f(1/2)(2/3-g) + f(2/3)(g-1/2) + (1/16)(1/6)(g-1/2)(2/3-g)
  have h_identity : (2/3 - 1/2) * covDet2Expr l (11*l/7) g =
      covDet2Expr l (11*l/7) (1/2) * (2/3 - g) +
      covDet2Expr l (11*l/7) (2/3) * (g - 1/2) +
      1 / 16 * (2/3 - 1/2) * (g - 1/2) * (2/3 - g) := by
    unfold covDet2Expr; ring
  have hD : (0:ℝ) < 2/3 - 1/2 := by norm_num
  have hu : (0:ℝ) ≤ g - 1/2 := by linarith
  have hv : (0:ℝ) ≤ 2/3 - g := by linarith
  have h1 := covDet2_corner_1 l hl hl2
  have h2 := covDet2_corner_2 l hl hl2
  have hA : covDet2Expr l (11*l/7) (1/2) * (2/3 - g) ≥ 0 := mul_nonneg (le_of_lt h1) hv
  have hB : covDet2Expr l (11*l/7) (2/3) * (g - 1/2) ≥ 0 := mul_nonneg (le_of_lt h2) hu
  have hC : 1 / 16 * (2/3 - 1/2) * (g - 1/2) * (2/3 - g) ≥ 0 := by positivity
  by_cases hg_eq : g = 1/2
  · rw [hg_eq]; exact h1
  · have hu_pos : 0 < g - 1/2 := lt_of_le_of_ne hu (fun h => hg_eq (by linarith))
    have hB_pos : 0 < covDet2Expr l (11*l/7) (2/3) * (g - 1/2) := mul_pos h2 hu_pos
    have h_prod : 0 < (2/3 - 1/2) * covDet2Expr l (11*l/7) g := by linarith [h_identity, hA, hC]
    exact pos_of_pos_mul _ _ hD h_prod

/-- f(2l, g) > 0 via γ-interpolation from corners 3 and 4. -/
private theorem covDet2_at_p2l (l g : ℝ)
    (hl : 6931 / 10000 < l) (hl2 : l < 7 / 10)
    (hg_lo : 1 / 2 < g) (hg_hi : g < 2 / 3) :
    covDet2Expr l (2 * l) g > 0 := by
  have h_identity : (2/3 - 1/2) * covDet2Expr l (2*l) g =
      covDet2Expr l (2*l) (1/2) * (2/3 - g) +
      covDet2Expr l (2*l) (2/3) * (g - 1/2) +
      1 / 16 * (2/3 - 1/2) * (g - 1/2) * (2/3 - g) := by
    unfold covDet2Expr; ring
  have hD : (0:ℝ) < 2/3 - 1/2 := by norm_num
  have hu : (0:ℝ) ≤ g - 1/2 := by linarith
  have hv : (0:ℝ) ≤ 2/3 - g := by linarith
  have h3 := covDet2_corner_3 l hl hl2
  have h4 := covDet2_corner_4 l hl hl2
  have hA : covDet2Expr l (2*l) (1/2) * (2/3 - g) ≥ 0 := mul_nonneg (le_of_lt h3) hv
  have hB : covDet2Expr l (2*l) (2/3) * (g - 1/2) ≥ 0 := mul_nonneg (le_of_lt h4) hu
  have hC : 1 / 16 * (2/3 - 1/2) * (g - 1/2) * (2/3 - g) ≥ 0 := by positivity
  by_cases hg_eq : g = 1/2
  · rw [hg_eq]; exact h3
  · have hu_pos : 0 < g - 1/2 := lt_of_le_of_ne hu (fun h => hg_eq (by linarith))
    have hB_pos : 0 < covDet2Expr l (2*l) (2/3) * (g - 1/2) := mul_pos h4 hu_pos
    have h_prod : 0 < (2/3 - 1/2) * covDet2Expr l (2*l) g := by linarith [h_identity, hA, hC]
    exact pos_of_pos_mul _ _ hD h_prod

-- ════════════════════════════════════════════════
-- p-INTERPOLATION: MAIN PROOF
-- ════════════════════════════════════════════════

/-- covDet2Expr l p g > 0 for all (l,p,g) in the valid range. -/
private theorem covDet2_pos (l p g : ℝ)
    (hl : 6931 / 10000 < l) (hl2 : l < 7 / 10)
    (hp_lo : 11 * l / 7 ≤ p) (hp_hi : p ≤ 2 * l)
    (hg_lo : 1 / 2 < g) (hg_hi : g < 2 / 3) :
    covDet2Expr l p g > 0 := by
  have h_identity : (2*l - 11*l/7) * covDet2Expr l p g =
      covDet2Expr l (11*l/7) g * (2*l - p) +
      covDet2Expr l (2*l) g * (p - 11*l/7) +
      1 / 16 * (2*l - 11*l/7) * (p - 11*l/7) * (2*l - p) := by
    unfold covDet2Expr; ring
  have hl_pos : (0:ℝ) < l := by linarith
  have hD : 0 < 2*l - 11*l/7 := by linarith
  have hu : 0 ≤ p - 11*l/7 := by linarith
  have hv : 0 ≤ 2*l - p := by linarith
  have h_lo := covDet2_at_p11l7 l g hl hl2 hg_lo hg_hi
  have h_hi := covDet2_at_p2l l g hl hl2 hg_lo hg_hi
  have hA : covDet2Expr l (11*l/7) g * (2*l - p) ≥ 0 := mul_nonneg (le_of_lt h_lo) hv
  have hB : covDet2Expr l (2*l) g * (p - 11*l/7) ≥ 0 := mul_nonneg (le_of_lt h_hi) hu
  have hC : 1 / 16 * (2*l - 11*l/7) * (p - 11*l/7) * (2*l - p) ≥ 0 := by positivity
  by_cases hp_eq : p = 11*l/7
  · rw [hp_eq]; exact h_lo
  · have hu_pos : 0 < p - 11*l/7 := lt_of_le_of_ne hu (fun h => hp_eq (by linarith))
    have hB_pos : 0 < covDet2Expr l (2*l) g * (p - 11*l/7) := mul_pos h_hi hu_pos
    have h_prod : 0 < (2*l - 11*l/7) * covDet2Expr l p g := by linarith [h_identity, hA, hC]
    exact pos_of_pos_mul _ _ hD h_prod

end Cathedral.Vasyunin
