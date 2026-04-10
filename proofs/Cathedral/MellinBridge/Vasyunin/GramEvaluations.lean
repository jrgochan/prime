/-
  Cathedral/MellinBridge/Vasyunin/GramEvaluations.lean

  Exact evaluations of small Gram matrix entries:
  V(2,1) = 0, G(1,2) exact form, G(1,2) > 0, trace formula.
-/

import Cathedral.MellinBridge.Vasyunin.Structural

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

/-- Euler-Mascheroni constant γ ≈ 0.5772 -/
local notation "γ" => Real.eulerMascheroniConstant

-- ════════════════════════════════════════════════
-- GRAM MATRIX TRACE AND SMALL CASES
-- ════════════════════════════════════════════════

/-- **V(2,1) = 0**: The only term has cot(π/2) = cos(π/2)/sin(π/2) = 0.
    Sum: {1·1/2}·cot(π·1/2) = (1/2)·0 = 0. -/
theorem vasyuninSum_two_one : vasyuninSum 2 1 = 0 := by
  unfold vasyuninSum
  simp only [show ¬(2 ≤ 1) from by omega, ↓reduceIte]
  have h_ico : Ico 1 2 = ({1} : Finset ℕ) := by
    ext x; simp
  rw [h_ico, Finset.sum_singleton]
  unfold cot
  have h_cos : Real.cos (Real.pi * (1 : ℕ) / (2 : ℕ)) = 0 := by
    rw [show (Real.pi * (1 : ℕ) / (2 : ℕ) : ℝ) = Real.pi / 2 by push_cast; ring]
    exact Real.cos_pi_div_two
  rw [h_cos]
  simp

/-- The trace of the N×N Gram matrix equals the sum of diagonal entries. -/
theorem vasyuninGramMatrix_trace (N : ℕ) :
    (vasyuninGramMatrix N).trace =
    ∑ i : Fin N, ((Real.log (2 * Real.pi) - γ) / (↑i.val + 1) -
                   1 / (↑i.val + 1) ^ 2) := by
  unfold Matrix.trace
  congr 1
  ext i
  exact vasyuninGramMatrix_diag N i

/-- **G(1,2) exact form**: Since gcd(1,2)=1, j'=1, k'=2, and
    V(1,2) = V(2,1) = 0 (both vanish), we get:
    G(1,2) = 3A/4 - ln(2)/4 - 1/2
    where A = ln(2π) - γ. -/
theorem vasyuninGramEntry_one_two :
    vasyuninGramEntry 1 2 =
    3 * (Real.log (2 * Real.pi) - γ) / 4 -
    Real.log 2 / 4 - 1 / 2 := by
  unfold vasyuninGramEntry
  simp only [show 1 ≠ 2 from by omega, ↓reduceIte]
  simp only [show Nat.gcd 1 2 = 1 from by norm_num,
             show 1 / 1 = 1 from by norm_num,
             show 2 / 1 = 2 from by norm_num]
  rw [vasyuninSum_one, vasyuninSum_two_one]
  push_cast
  rw [show (2 : ℝ) / (1 : ℝ) = 2 by norm_num]
  rw [show Real.log (2 : ℝ) = Real.log 2 from rfl]
  ring

/-- **G(1,2) > 0**: The off-diagonal Gram entry is strictly positive.
    From the exact form G(1,2) = 3A/4 - ln(2)/4 - 1/2, we need 3A > ln(2) + 2.
    Using ln(2) > 0.693, ln(π) > 1, γ < 2/3:
    LHS > 2·0.693 + 3 = 4.386 > 4 > 2 + 2 = RHS. -/
theorem vasyuninGramEntry_one_two_pos : vasyuninGramEntry 1 2 > 0 := by
  rw [vasyuninGramEntry_one_two]
  have h_log2 : (0.6931471803 : ℝ) < Real.log 2 := Real.log_two_gt_d9
  have h_e_lt_3 : Real.exp 1 < 3 := Real.exp_one_lt_three
  have h_pi_gt : (3 : ℝ) < Real.pi := pi_gt_three
  have h_gamma : Real.eulerMascheroniConstant < 2 / 3 :=
    Real.eulerMascheroniConstant_lt_two_thirds
  have h_log3 : 1 < Real.log 3 := by
    rw [show (1 : ℝ) = Real.log (Real.exp 1) from (Real.log_exp 1).symm]
    exact Real.log_lt_log (Real.exp_pos 1) h_e_lt_3
  have h_logpi : 1 < Real.log Real.pi :=
    lt_trans h_log3 (Real.log_lt_log (by norm_num : (0:ℝ) < 3) h_pi_gt)
  have h_log2pi : Real.log (2 * Real.pi) = Real.log 2 + Real.log Real.pi :=
    Real.log_mul (by norm_num : (2:ℝ) ≠ 0) (ne_of_gt Real.pi_pos)
  rw [h_log2pi]
  linarith

/-- **3⁷ ≥ 2¹¹** (2187 ≥ 2048), hence ln(3) ≥ 11·ln(2)/7 ≈ 1.089.
    This is the crucial number-theoretic bound that unlocks det(G₂) > 0. -/
theorem log_three_ge_11_log_two_div_7 :
    Real.log 3 ≥ 11 * Real.log 2 / 7 := by
  rw [ge_iff_le, div_le_iff₀ (by norm_num : (0:ℝ) < 7)]
  rw [show 11 * Real.log 2 = Real.log (2 ^ 11) by rw [Real.log_pow]; ring]
  rw [show Real.log 3 * 7 = Real.log (3 ^ 7) by rw [Real.log_pow]; ring]
  exact Real.log_le_log (by norm_num : (0:ℝ) < 2 ^ 11) (by norm_num)

/-- **det(G₂) > 0**: The 2×2 leading minor of the Gram matrix has positive
    determinant. Combined with G(1,1) > 0, this proves the 2×2 Gram matrix
    is positive definite (Sylvester's criterion).

    det(G₂) = G(1,1)·G(2,2) - G(1,2)²
    where G(1,1) = A - 1, G(2,2) = A/2 - 1/4, G(1,2) = 3A/4 - L/4 - 1/2
    and A = ln(2π) - γ, L = ln(2).

    Numerically: det ≈ 0.025 > 0.

    The proof uses the key bound 3⁷ ≥ 2¹¹ to establish
    ln(π) > 11·ln(2)/7 ≈ 1.089, which provides enough arithmetic
    precision for nlinarith to close the polynomial inequality. -/
theorem vasyuninGram2x2_det_pos :
    vasyuninGramEntry 1 1 * vasyuninGramEntry 2 2 -
    vasyuninGramEntry 1 2 * vasyuninGramEntry 1 2 > 0 := by
  rw [vasyuninGramEntry_diag 1, vasyuninGramEntry_diag 2, vasyuninGramEntry_one_two]
  have h_log2pi : Real.log (2 * Real.pi) = Real.log 2 + Real.log Real.pi :=
    Real.log_mul (by norm_num : (2:ℝ) ≠ 0) (ne_of_gt Real.pi_pos)
  rw [h_log2pi]
  set l := Real.log 2
  set p := Real.log Real.pi
  set g := Real.eulerMascheroniConstant
  -- Bounds
  have hl : (0.6931471803 : ℝ) < l := Real.log_two_gt_d9
  have hg_lo : (1:ℝ)/2 < g := Real.one_half_lt_eulerMascheroniConstant
  have hg_hi : g < 2/3 := Real.eulerMascheroniConstant_lt_two_thirds
  -- The crucial bound: ln(π) > 11·ln(2)/7 (from 3^7 > 2^11 and π > 3)
  have h_logpi : p > 11 * l / 7 := by
    calc p > Real.log 3 :=
              Real.log_lt_log (by norm_num : (0:ℝ) < 3) pi_gt_three
         _ ≥ 11 * l / 7 := log_three_ge_11_log_two_div_7
  -- Upper bound: ln(π) ≤ 2·ln(2) (from π ≤ 4)
  have h_p_le : p ≤ 2 * l := by
    rw [show 2 * l = Real.log (2 ^ 2) from by rw [Real.log_pow]; ring]
    exact Real.log_le_log Real.pi_pos (by norm_num; exact pi_le_four)
  -- Normalize Nat casts
  push_cast
  -- nlinarith closes with the tight bound on p
  nlinarith [sq_nonneg (p - 11*l/7), sq_nonneg (g - 1/2), sq_nonneg (l - 0.7),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < p by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l - g by linarith)]

end Cathedral.Vasyunin

