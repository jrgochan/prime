/-
  Cathedral/Vasyunin/Matrix/CovEntries.lean

  Closed-form evaluations of covariance matrix entries C(0,0), C(0,1), C(1,1)
  and positivity of C(0,0).
-/

import Cathedral.Vasyunin.Matrix.GramEntries

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

/-- Euler-Mascheroni constant γ ≈ 0.5772 -/
local notation "γ" => Real.eulerMascheroniConstant

-- ════════════════════════════════════════════════
-- COVARIANCE MATRIX EVALUATIONS (N=3)
-- ════════════════════════════════════════════════

/-- Covariance entry C(0,0) = G(1,1) - b₁². -/
theorem covEntry_00 :
    (vasyuninCovMatrix 3) 0 0 =
    Real.log (2 * Real.pi) - γ - 1 - (1 - γ) ^ 2 := by
  unfold vasyuninCovMatrix vasyuninGramMatrix vasyuninMeanVec
  simp only [Matrix.sub_apply, Matrix.of_apply, vecMulVec, Matrix.of_apply, Fin.val_zero]
  rw [vasyuninGramEntry_one_one, vasyuninMeanEntry_one]
  ring

/-- C₃(0,0) > 0. Margin ≈ 0.082. -/
theorem covEntry_00_pos : (vasyuninCovMatrix 3) 0 0 > 0 := by
  rw [covEntry_00]
  have h_log2 : (0.6931471803 : ℝ) < Real.log 2 := Real.log_two_gt_d9
  have h_gamma_lt : γ < 2 / 3 := Real.eulerMascheroniConstant_lt_two_thirds
  have h_gamma_gt : 1 / 2 < γ := Real.one_half_lt_eulerMascheroniConstant
  have h_log3 : 11 * Real.log 2 / 7 ≤ Real.log 3 := log_three_ge_11_log_two_div_7
  have h_pi_gt : (3 : ℝ) < Real.pi := pi_gt_three
  have h_logpi : Real.log 3 ≤ Real.log Real.pi :=
    Real.log_le_log (by norm_num : (0 : ℝ) < 3) (le_of_lt h_pi_gt)
  have h_log2pi : Real.log (2 * Real.pi) = Real.log 2 + Real.log Real.pi :=
    Real.log_mul (by norm_num : (2 : ℝ) ≠ 0) (ne_of_gt Real.pi_pos)
  rw [h_log2pi]
  nlinarith [sq_nonneg (γ - 1/2), sq_nonneg (2/3 - γ)]

/-- Closed form for C(0,1) = G(1,2) - b₁·b₂. -/
theorem covEntry_01 :
    (vasyuninCovMatrix 3) 0 1 =
    3 / 4 * (Real.log (2 * Real.pi) - γ) -
    Real.log 2 / 4 - 1 / 2 -
    (1 - γ) * ((Real.log 2 + 1 - γ) / 2) := by
  unfold vasyuninCovMatrix vasyuninGramMatrix vasyuninMeanVec
  simp only [Matrix.sub_apply, Matrix.of_apply, vecMulVec, Matrix.of_apply,
             Fin.val_zero, Fin.val_one]
  show vasyuninGramEntry 1 2 - vasyuninMeanEntry 1 * vasyuninMeanEntry 2 = _
  rw [vasyuninGramEntry_one_two, vasyuninMeanEntry_one, vasyuninMeanEntry_two]
  ring

/-- Closed form for C(1,1) = G(2,2) - b₂². -/
theorem covEntry_11 :
    (vasyuninCovMatrix 3) 1 1 =
    (Real.log (2 * Real.pi) - γ) / 2 - 1 / 4 -
    ((Real.log 2 + 1 - γ) / 2) ^ 2 := by
  unfold vasyuninCovMatrix vasyuninGramMatrix vasyuninMeanVec
  simp only [Matrix.sub_apply, Matrix.of_apply, vecMulVec, Matrix.of_apply, Fin.val_one]
  show vasyuninGramEntry 2 2 - vasyuninMeanEntry 2 * vasyuninMeanEntry 2 = _
  rw [vasyuninGramEntry_two_two, vasyuninMeanEntry_two]
  ring

end Cathedral.Vasyunin
