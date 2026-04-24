import Mathlib

open Complex Real MeasureTheory Set Filter ArithmeticFunction Finset
open scoped LSeries.notation ArithmeticFunction.Moebius ArithmeticFunction.zeta Topology

-- Lemma: X^c = X^{c-1} * X
lemma rpow_eq_pred_mul (X c : ℝ) (hX : 0 < X) : X ^ c = X ^ (c - 1) * X := by
  have : X ^ c = X ^ ((c - 1) + 1) := by congr 1; ring
  rw [this, rpow_add hX, rpow_one]

-- Full test
example (C_tail X T : ℝ) (c : ℝ) (N : ℕ)
    (hC : 0 < C_tail) (hX_pos : 0 < X) (hX_gt1 : 1 < X)
    (hT_pos : 0 < T) (hc : 1 < c) (hN_pos : 0 < N)
    (h_inv : (N : ℝ) ^ (1 - c) = 1 / (N : ℝ) ^ (c - 1))
    (hN_c1_pos : 0 < (N : ℝ) ^ (c - 1))
    (h_N_rpow : C_tail * T ^ 2 * X < (N : ℝ) ^ (c - 1)) :
    C_tail * (N : ℝ) ^ (1 - c) * X ^ c * T ≤ X ^ (c + 1) / T := by
  rw [h_inv]
  have hstep : C_tail / (N : ℝ) ^ (c - 1) ≤ 1 / (T ^ 2 * X) := by
    rw [div_le_div_iff₀ hN_c1_pos (by positivity : (0:ℝ) < T ^ 2 * X)]
    linarith
  rw [show C_tail * (1 / (N : ℝ) ^ (c - 1)) = C_tail / (N : ℝ) ^ (c - 1) from by ring]
  have h_exp : X ^ (c - 1) ≤ X ^ (c + 1) :=
    rpow_le_rpow_of_exponent_le hX_gt1.le (by linarith)
  have h_lhs : C_tail / (N : ℝ) ^ (c - 1) * X ^ c * T ≤ X ^ (c - 1) / T := by
    calc C_tail / (N : ℝ) ^ (c - 1) * X ^ c * T
        ≤ 1 / (T ^ 2 * X) * X ^ c * T := by
          apply mul_le_mul_of_nonneg_right _ hT_pos.le
          exact mul_le_mul_of_nonneg_right hstep (rpow_nonneg hX_pos.le _)
      _ = X ^ (c - 1) / T := by
          rw [rpow_eq_pred_mul X c hX_pos]
          field_simp
  linarith [div_le_div_of_nonneg_right h_exp hT_pos.le]
