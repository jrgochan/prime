/-
  Cathedral/AbelTail/DiscreteProductRule.lean

  ## Discrete Product Rule for log-weighted sums

  The "Discrete Product Rule" bounds the finite differences of
  products like log(k)/k and log²(k)/k using:
    A_k·B_k - A_{k+1}·B_{k+1} = A_k·ΔB_k + B_{k+1}·ΔA_k

  This is crucial for bounding the S₂ and S₃ Abel sums.

  Key results:
  - log(1+1/k) ≤ 1/k  (from Mathlib's log_le_sub_one_of_pos)
  - log(k+1) - log(k) ≤ 1/k
  - |log(k)/k - log(k+1)/(k+1)| ≤ (log(k)+1)/k²
-/

import Cathedral.Defs

noncomputable section
open Real Finset BigOperators

-- ════════════════════════════════════════════════
-- §1. LOG INCREMENT BOUNDS
-- ════════════════════════════════════════════════

/-- **PROVED**: log(1 + 1/k) ≤ 1/k for k ≥ 1.
    From Mathlib: log(x) ≤ x - 1 for x > 0, applied to x = 1+1/k. -/
theorem log_one_plus_inv_le (k : ℕ) (hk : 1 ≤ k) :
    Real.log (1 + 1/(k : ℝ)) ≤ 1/(k : ℝ) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have h1k : (0 : ℝ) < 1 + 1/(k : ℝ) := by positivity
  have := Real.log_le_sub_one_of_pos h1k
  linarith

/-- **PROVED**: log(k+1) - log(k) ≤ 1/k for k ≥ 1.
    Consequence of log(1+1/k) ≤ 1/k. -/
theorem log_diff_le_inv (k : ℕ) (hk : 1 ≤ k) :
    Real.log ((k : ℝ) + 1) - Real.log (k : ℝ) ≤ 1/(k : ℝ) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hk1_ne : ((k : ℝ) + 1) ≠ 0 := by linarith
  have hk_ne : (k : ℝ) ≠ 0 := ne_of_gt hk_pos
  calc Real.log ((k : ℝ) + 1) - Real.log (k : ℝ)
      = Real.log (((k : ℝ) + 1) / (k : ℝ)) := (Real.log_div hk1_ne hk_ne).symm
    _ = Real.log (1 + 1/(k : ℝ)) := by congr 1; field_simp
    _ ≤ 1/(k : ℝ) := log_one_plus_inv_le k hk

-- ════════════════════════════════════════════════
-- §2. DISCRETE PRODUCT RULE FOR log(k)/k
-- ════════════════════════════════════════════════

/-- **PROVED**: Discrete Product Rule for f₂(k) = log(k)/k.
    |log(k)/k - log(k+1)/(k+1)| ≤ (log(k) + 1)/k² -/
theorem s2_discrete_diff_bound (k : ℕ) (hk : 2 ≤ k) :
    |Real.log (k : ℝ) / (k : ℝ) - Real.log ((k : ℝ) + 1) / ((k : ℝ) + 1)| ≤
    (Real.log (k : ℝ) + 1) / (k : ℝ) ^ 2 := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hk1_pos : (0 : ℝ) < (k : ℝ) + 1 := by linarith
  -- Discrete Product Rule: A_k·B_k - A_{k+1}·B_{k+1}
  -- = A_k·(B_k - B_{k+1}) + B_{k+1}·(A_k - A_{k+1})
  have h_split : Real.log (k : ℝ) / (k : ℝ) - Real.log ((k : ℝ) + 1) / ((k : ℝ) + 1) =
      Real.log (k : ℝ) * (1/(k : ℝ) - 1/((k : ℝ) + 1)) +
      1/((k : ℝ) + 1) * (Real.log (k : ℝ) - Real.log ((k : ℝ) + 1)) := by
    field_simp; ring
  rw [h_split]
  calc |Real.log (k : ℝ) * (1/(k : ℝ) - 1/((k : ℝ) + 1)) +
       1/((k : ℝ) + 1) * (Real.log (k : ℝ) - Real.log ((k : ℝ) + 1))|
      ≤ |Real.log (k : ℝ) * (1/(k : ℝ) - 1/((k : ℝ) + 1))| +
        |1/((k : ℝ) + 1) * (Real.log (k : ℝ) - Real.log ((k : ℝ) + 1))| :=
          abs_add_le _ _
    _ = Real.log (k : ℝ) * |1/(k : ℝ) - 1/((k : ℝ) + 1)| +
        1/((k : ℝ) + 1) * |Real.log (k : ℝ) - Real.log ((k : ℝ) + 1)| := by
          have hlog_nn : (0:ℝ) ≤ Real.log (k : ℝ) :=
            Real.log_nonneg (by exact_mod_cast show 1 ≤ k by omega)
          have hinv_nn : (0:ℝ) ≤ 1/((k : ℝ) + 1) := by positivity
          rw [abs_mul, abs_of_nonneg hlog_nn, abs_mul, abs_of_nonneg hinv_nn]
    _ ≤ Real.log (k : ℝ) * (1/((k : ℝ) * ((k : ℝ) + 1))) +
        1/((k : ℝ) + 1) * (1/(k : ℝ)) := by
          apply add_le_add
          · apply mul_le_mul_of_nonneg_left _ (Real.log_nonneg (by exact_mod_cast show 1 ≤ k by omega))
            rw [show 1/(k : ℝ) - 1/((k : ℝ) + 1) = 1/((k : ℝ) * ((k : ℝ) + 1)) from by
              field_simp; ring]
            rw [abs_of_nonneg (by positivity)]
          · apply mul_le_mul_of_nonneg_left _ (by positivity)
            have h_log_nn : 0 ≤ Real.log ((k : ℝ) + 1) - Real.log (k : ℝ) :=
              sub_nonneg.mpr (Real.log_le_log hk_pos (by linarith))
            rw [show Real.log (k : ℝ) - Real.log ((k : ℝ) + 1) =
                -(Real.log ((k : ℝ) + 1) - Real.log (k : ℝ)) from by ring,
                abs_neg, abs_of_nonneg h_log_nn]
            exact log_diff_le_inv k (by omega)
    _ ≤ (Real.log (k : ℝ) + 1) / (k : ℝ) ^ 2 := by
          have ha : (0 : ℝ) ≤ Real.log (k : ℝ) + 1 := by
            have : (1 : ℝ) ≤ (k : ℝ) := by exact_mod_cast show 1 ≤ k by omega
            linarith [Real.log_nonneg this]
          have hkk1_pos : (0 : ℝ) < (k : ℝ) * ((k : ℝ) + 1) := by positivity
          have hk2_pos : (0 : ℝ) < (k : ℝ) ^ 2 := by positivity
          have hkk1 : (k : ℝ) ^ 2 ≤ (k : ℝ) * ((k : ℝ) + 1) := by nlinarith
          have h_lhs : Real.log (k : ℝ) * (1 / ((k : ℝ) * ((k : ℝ) + 1))) +
              1 / ((k : ℝ) + 1) * (1 / (k : ℝ)) =
              (Real.log (k : ℝ) + 1) / ((k : ℝ) * ((k : ℝ) + 1)) := by
            field_simp
          rw [h_lhs]
          exact div_le_div_of_nonneg_left ha hk2_pos hkk1

/-- **PROVED**: Discrete Product Rule for f₃(k) = log²(k)/k.
    |log²(k)/k - log²(k+1)/(k+1)| ≤ (log²(k) + 2·log(k) + 2)/k²

    Uses DPR: A_k·B_k - A_{k+1}·B_{k+1}
    = A_k·(B_k-B_{k+1}) + B_{k+1}·(A_k-A_{k+1})
    where A_k = log²(k), B_k = 1/k.
    |ΔA| = |log²k - log²(k+1)| = |logk-log(k+1)|·|logk+log(k+1)|
         ≤ (1/k)·(2logk+1)
    |ΔB| = |1/k - 1/(k+1)| = 1/(k·(k+1))

    Combined: ≤ log²k/(k·(k+1)) + (2logk+1)/(k·(k+1))
              = (log²k+2logk+1)/(k·(k+1)) ≤ (log²k+2logk+2)/k² -/
theorem s3_discrete_diff_bound (k : ℕ) (hk : 2 ≤ k) :
    |(Real.log (k : ℝ)) ^ 2 / (k : ℝ) -
      (Real.log ((k : ℝ) + 1)) ^ 2 / ((k : ℝ) + 1)| ≤
    ((Real.log (k : ℝ)) ^ 2 + 2 * Real.log (k : ℝ) + 2) / (k : ℝ) ^ 2 := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hk1_pos : (0 : ℝ) < (k : ℝ) + 1 := by linarith
  have hlog_k_nn : 0 ≤ Real.log (k : ℝ) :=
    Real.log_nonneg (by exact_mod_cast show 1 ≤ k by omega)
  have hlog_k1_nn : 0 ≤ Real.log ((k : ℝ) + 1) :=
    Real.log_nonneg (by linarith)
  -- DPR split
  have h_split : (Real.log (k : ℝ)) ^ 2 / (k : ℝ) -
      (Real.log ((k : ℝ) + 1)) ^ 2 / ((k : ℝ) + 1) =
    (Real.log (k : ℝ)) ^ 2 * (1/(k : ℝ) - 1/((k : ℝ) + 1)) +
    1/((k : ℝ) + 1) * ((Real.log (k : ℝ)) ^ 2 - (Real.log ((k : ℝ) + 1)) ^ 2) := by
    field_simp; ring
  rw [h_split]
  calc |(Real.log (k : ℝ)) ^ 2 * (1 / (k : ℝ) - 1 / ((k : ℝ) + 1)) +
        1 / ((k : ℝ) + 1) * ((Real.log (k : ℝ)) ^ 2 - (Real.log ((k : ℝ) + 1)) ^ 2)|
      ≤ |(Real.log (k : ℝ)) ^ 2 * (1 / (k : ℝ) - 1 / ((k : ℝ) + 1))| +
        |1 / ((k : ℝ) + 1) * ((Real.log (k : ℝ)) ^ 2 - (Real.log ((k : ℝ) + 1)) ^ 2)| :=
        abs_add_le _ _
    _ = (Real.log (k : ℝ)) ^ 2 * |1/(k : ℝ) - 1/((k : ℝ) + 1)| +
        1/((k : ℝ) + 1) * |(Real.log (k : ℝ)) ^ 2 - (Real.log ((k : ℝ) + 1)) ^ 2| := by
        rw [abs_mul, abs_of_nonneg (sq_nonneg _), abs_mul,
            abs_of_nonneg (div_nonneg one_pos.le hk1_pos.le)]
    _ ≤ (Real.log (k : ℝ)) ^ 2 * (1/((k : ℝ) * ((k : ℝ) + 1))) +
        1/((k : ℝ) + 1) * ((2 * Real.log (k : ℝ) + 1) / (k : ℝ)) := by
        apply add_le_add
        · apply mul_le_mul_of_nonneg_left _ (sq_nonneg _)
          rw [show 1/(k : ℝ) - 1/((k : ℝ) + 1) = 1/((k : ℝ) * ((k : ℝ) + 1)) from by
            field_simp; ring]
          rw [abs_of_nonneg (by positivity)]
        · apply mul_le_mul_of_nonneg_left _ (by positivity)
          -- |log²k - log²(k+1)| = |logk - log(k+1)| · |logk + log(k+1)|
          rw [show (Real.log (k : ℝ)) ^ 2 - (Real.log ((k : ℝ) + 1)) ^ 2 =
              (Real.log (k : ℝ) - Real.log ((k : ℝ) + 1)) *
                (Real.log (k : ℝ) + Real.log ((k : ℝ) + 1)) from by ring]
          rw [abs_mul]
          -- |logk - log(k+1)| = log(k+1) - logk ≤ 1/k
          have h_log_diff_nn : 0 ≤ Real.log ((k : ℝ) + 1) - Real.log (k : ℝ) :=
            sub_nonneg.mpr (Real.log_le_log hk_pos (by linarith))
          rw [show Real.log (k : ℝ) - Real.log ((k : ℝ) + 1) =
              -(Real.log ((k : ℝ) + 1) - Real.log (k : ℝ)) from by ring,
              abs_neg, abs_of_nonneg h_log_diff_nn]
          -- |logk + log(k+1)| = logk + log(k+1) ≤ 2logk + 1
          rw [abs_of_nonneg (by linarith)]
          -- (log(k+1)-logk) · (logk + log(k+1)) ≤ (1/k) · (2logk + 1)
          have h_inv := log_diff_le_inv k (by omega)
          -- log(k+1) ≤ logk + 1 (since log(k+1)-logk ≤ 1/k ≤ 1)
          have h_diff_le_1 : Real.log ((k : ℝ) + 1) - Real.log (k : ℝ) ≤ 1 := by
            calc Real.log ((k : ℝ) + 1) - Real.log (k : ℝ)
                ≤ 1 / (k : ℝ) := h_inv
              _ ≤ 1 := by
                rw [div_le_one hk_pos]
                exact_mod_cast show 1 ≤ k by omega
          have h_sum_le : Real.log (k : ℝ) + Real.log ((k : ℝ) + 1) ≤
              2 * Real.log (k : ℝ) + 1 := by linarith [h_diff_le_1]
          -- Product bound via calc
          calc (Real.log ((↑k:ℝ) + 1) - Real.log (↑k:ℝ)) *
                (Real.log (↑k:ℝ) + Real.log ((↑k:ℝ) + 1))
              ≤ (1 / (↑k:ℝ)) * (Real.log (↑k:ℝ) + Real.log ((↑k:ℝ) + 1)) := by
                apply mul_le_mul_of_nonneg_right h_inv (by linarith)
            _ ≤ (1 / (↑k:ℝ)) * (2 * Real.log (↑k:ℝ) + 1) := by
                apply mul_le_mul_of_nonneg_left h_sum_le (by positivity)
            _ = (2 * Real.log (↑k:ℝ) + 1) / (↑k:ℝ) := by ring
    _ ≤ ((Real.log (k : ℝ)) ^ 2 + 2 * Real.log (k : ℝ) + 2) / (k : ℝ) ^ 2 := by
        -- Combine: log²k/(k(k+1)) + (2logk+1)/(k(k+1))
        -- = (log²k + 2logk + 1)/(k(k+1)) ≤ (log²k + 2logk + 2)/k²
        have hkk1_pos : (0 : ℝ) < (k : ℝ) * ((k : ℝ) + 1) := by positivity
        have hk2_pos : (0 : ℝ) < (k : ℝ) ^ 2 := by positivity
        have hkk1 : (k : ℝ) ^ 2 ≤ (k : ℝ) * ((k : ℝ) + 1) := by nlinarith
        have h_lhs : (Real.log (k : ℝ)) ^ 2 * (1 / ((k : ℝ) * ((k : ℝ) + 1))) +
            1 / ((k : ℝ) + 1) * ((2 * Real.log (k : ℝ) + 1) / (k : ℝ)) =
            ((Real.log (k : ℝ)) ^ 2 + 2 * Real.log (k : ℝ) + 1) /
              ((k : ℝ) * ((k : ℝ) + 1)) := by
          field_simp; ring
        rw [h_lhs]
        have ha : 0 ≤ (Real.log (k : ℝ)) ^ 2 + 2 * Real.log (k : ℝ) + 2 := by nlinarith
        calc ((Real.log (k : ℝ)) ^ 2 + 2 * Real.log (k : ℝ) + 1) /
              ((k : ℝ) * ((k : ℝ) + 1))
            ≤ ((Real.log (k : ℝ)) ^ 2 + 2 * Real.log (k : ℝ) + 2) /
              ((k : ℝ) * ((k : ℝ) + 1)) := by
              gcongr; linarith
          _ ≤ ((Real.log (k : ℝ)) ^ 2 + 2 * Real.log (k : ℝ) + 2) / (k : ℝ) ^ 2 := by
              apply div_le_div_of_nonneg_left
              · nlinarith
              · exact hk2_pos
              · exact hkk1

end

