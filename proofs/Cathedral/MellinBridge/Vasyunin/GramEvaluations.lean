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

-- NOTE: det(G₂) > 0 requires tighter numerical bounds on ln(2), ln(π), γ.
-- The margin is only approx 0.025, needing 4+ decimal precision.
-- This will be proved here once we have tighter Mathlib bounds.

end Cathedral.Vasyunin
