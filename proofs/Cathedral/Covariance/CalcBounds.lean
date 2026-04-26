/-
  Cathedral/Assembly/CalcBounds.lean

  ## Calculus Bounds for the Dot Product Assembly

  STATUS: 1 sorry (rpow_quarter_logsq — log²·rpow bound)
-/

import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Analysis.SpecialFunctions.Pow.Real
import Mathlib.Analysis.SpecialFunctions.Pow.Asymptotics
import Mathlib.Analysis.SpecialFunctions.Exp
import Mathlib.Analysis.Complex.ExponentialBounds

noncomputable section
open Real

-- ════════════════════════════════════════════════
-- §0. AUXILIARY LEMMAS
-- ════════════════════════════════════════════════

/-- 4 · exp(-1) ≤ 3/2. -/
private lemma four_exp_neg_one_le : 4 * Real.exp (-1) ≤ 3/2 := by
  have he : (2.7182818283 : ℝ) < Real.exp 1 := exp_one_gt_d9
  rw [Real.exp_neg, mul_inv_le_iff₀ (exp_pos 1)]
  linarith

/-- For x ≥ 1: log(x) · x^{-1/4} ≤ 3/2. -/
private lemma log_mul_rpow_neg_quarter_le (x : ℝ) (hx : 1 ≤ x) :
    Real.log x * x ^ (-(1:ℝ)/4) ≤ 3/2 := by
  have hx0 : 0 < x := lt_of_lt_of_le one_pos hx
  have h := mul_exp_neg_le_exp_neg_one (Real.log x / 4)
  have h_exp : Real.exp (-(Real.log x / 4)) = x ^ (-(1:ℝ)/4) := by
    rw [show -(Real.log x / 4) = Real.log x * (-(1:ℝ)/4) from by ring]
    rw [← rpow_def_of_pos hx0]
  rw [h_exp] at h; linarith [four_exp_neg_one_le]

-- ════════════════════════════════════════════════
-- §1. KEY CALCULUS BOUNDS
-- ════════════════════════════════════════════════

/-- **PROVED**: For N ≥ 10, ↑(N-1)^{-1/4} · log↑N ≤ 2. -/
theorem rpow_quarter_logN_le_two (N : ℕ) (hN : 10 ≤ N) :
    (↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log ↑N ≤ 2 := by
  -- Cast setup
  have hN1 : (N - 1 : ℕ) ≥ 9 := by omega
  have hM_pos : (0:ℝ) < ↑(N - 1) := Nat.cast_pos.mpr (by omega)
  have hM_ge1 : (1:ℝ) ≤ ↑(N - 1) := by exact_mod_cast (show (N-1 : ℕ) ≥ 1 from by omega)
  have hM_ge9 : (9:ℝ) ≤ ↑(N - 1) := by exact_mod_cast hN1
  -- N = (N-1) + 1 as reals
  have hN_eq : (↑N : ℝ) = ↑(N - 1) + 1 := by
    rw [Nat.cast_sub (by omega : 1 ≤ N)]; ring
  -- Step 1: (N-1)^{-1/4} ≤ 1
  have h_rpow_le1 : (↑(N-1) : ℝ) ^ (-(1:ℝ)/4) ≤ 1 := by
    have h1 : (1:ℝ) ≤ (↑(N-1) : ℝ) ^ ((1:ℝ)/4) :=
      one_le_rpow hM_ge1 (by norm_num)
    calc (↑(N-1) : ℝ) ^ (-(1:ℝ)/4)
        = ((↑(N-1) : ℝ) ^ ((1:ℝ)/4))⁻¹ := by
          rw [← rpow_neg hM_pos.le]; congr 1; ring
      _ ≤ 1 := inv_le_one_of_one_le₀ h1
  -- Step 2: log(N) ≤ log(N-1) + 1/(N-1)
  have h_logN_le : Real.log ↑N ≤ Real.log ↑(N-1) + 1 / ↑(N-1) := by
    rw [hN_eq]
    have hM1_pos : (0:ℝ) < ↑(N-1) + 1 := by linarith
    calc Real.log (↑(N-1) + 1)
        = Real.log (↑(N-1) * ((↑(N-1) + 1) / ↑(N-1))) := by
          rw [mul_div_cancel₀ _ (ne_of_gt hM_pos)]
      _ = Real.log ↑(N-1) + Real.log ((↑(N-1) + 1) / ↑(N-1)) :=
          Real.log_mul (ne_of_gt hM_pos) (ne_of_gt (div_pos hM1_pos hM_pos))
      _ ≤ Real.log ↑(N-1) + ((↑(N-1) + 1) / ↑(N-1) - 1) := by
          linarith [Real.log_le_sub_one_of_pos (div_pos hM1_pos hM_pos)]
      _ = Real.log ↑(N-1) + 1 / ↑(N-1) := by
          have hne : (↑(N-1) : ℝ) ≠ 0 := ne_of_gt hM_pos
          congr 1
          -- Goal after congr 1: (M+1)/M - 1 = 1/M
          rw [show (1:ℝ) = ↑(N-1) / ↑(N-1) from (div_self hne).symm,
              div_sub_div_same]
          congr 1; ring
  -- Step 3: Assembly
  have h_first := log_mul_rpow_neg_quarter_le ↑(N-1) hM_ge1
  have h_rpow_pos : 0 < (↑(N-1) : ℝ) ^ (-(1:ℝ)/4) := rpow_pos_of_pos hM_pos _
  calc (↑(N-1) : ℝ) ^ (-(1:ℝ)/4) * Real.log ↑N
      ≤ (↑(N-1) : ℝ) ^ (-(1:ℝ)/4) * (Real.log ↑(N-1) + 1 / ↑(N-1)) :=
        mul_le_mul_of_nonneg_left h_logN_le h_rpow_pos.le
    _ = Real.log ↑(N-1) * (↑(N-1) : ℝ) ^ (-(1:ℝ)/4) +
        (↑(N-1) : ℝ) ^ (-(1:ℝ)/4) * (1 / ↑(N-1)) := by ring
    _ ≤ 3/2 + 1 * (1 / ↑(N-1)) := by
        linarith [mul_le_mul_of_nonneg_right h_rpow_le1
          (div_nonneg one_pos.le hM_pos.le)]
    _ = 3/2 + 1 / ↑(N-1) := by ring
    _ ≤ 3/2 + 1/9 := by
        have : 1 / (↑(N-1) : ℝ) ≤ 1/9 := by
          apply div_le_div_of_nonneg_left one_pos.le (by norm_num : (0:ℝ) < 9)
          linarith
        linarith
    _ ≤ 2 := by norm_num

/-- 64 · exp(-2) · (10/9) ≤ 10. Equivalently, 640 ≤ 90·e². -/
private lemma sixtyFour_exp_neg_two_le : 64 * Real.exp (-2) * (10/9) ≤ 10 := by
  have he : (2.7182818283 : ℝ) < Real.exp 1 := exp_one_gt_d9
  have he_pos : 0 < Real.exp 1 := exp_pos 1
  -- exp(-2) = 1/(exp(1))^2
  have hexp2 : Real.exp (-2) = (Real.exp 1 * Real.exp 1)⁻¹ := by
    rw [show (-2:ℝ) = (-1) + (-1) from by ring, Real.exp_add, Real.exp_neg,
        mul_inv]
  rw [hexp2]
  have he2_pos : 0 < Real.exp 1 * Real.exp 1 := mul_pos he_pos he_pos
  rw [show 64 * (Real.exp 1 * Real.exp 1)⁻¹ * (10/9) =
    (64 * (10/9)) * (Real.exp 1 * Real.exp 1)⁻¹ from by ring]
  rw [mul_inv_le_iff₀ he2_pos]
  nlinarith [mul_self_nonneg (Real.exp 1 - 2.7182818283)]

/-- For x ≥ 1: log(x) · x^{-1/8} ≤ 8/e.
    Proof: y·e^{-y} ≤ e^{-1} with y = log(x)/8. -/
private lemma log_mul_rpow_neg_eighth_le (x : ℝ) (hx : 1 ≤ x) :
    Real.log x * x ^ (-(1:ℝ)/8) ≤ 8 * Real.exp (-1) := by
  have hx0 : 0 < x := lt_of_lt_of_le one_pos hx
  have h := mul_exp_neg_le_exp_neg_one (Real.log x / 8)
  have h_exp : Real.exp (-(Real.log x / 8)) = x ^ (-(1:ℝ)/8) := by
    rw [show -(Real.log x / 8) = Real.log x * (-(1:ℝ)/8) from by ring]
    rw [← rpow_def_of_pos hx0]
  rw [h_exp] at h; linarith

/-- **PROVED**: For N ≥ 10, ↑(N-1)^{-1/4} · log↑(N-1) · log↑N ≤ 10.

    Proof: Split M^{-1/4} = M^{-1/8} · M^{-1/8}.
    logM · M^{-1/8} ≤ 8/e (from log_mul_rpow_neg_eighth_le).
    logN · M^{-1/8} ≤ logN · N^{-1/8} · (N/M)^{1/8}
                    ≤ (8/e) · (10/9)^{1/8} ≤ (8/e) · (10/9).
    Product ≤ (8/e)² · (10/9) = (64/e²)·(10/9) ≤ 10. -/
theorem rpow_quarter_logsq_le_ten (N : ℕ) (hN : 10 ≤ N) :
    (↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log (↑(N - 1) : ℝ) *
    Real.log ↑N ≤ 10 := by
  have hM_pos : (0:ℝ) < ↑(N - 1) := Nat.cast_pos.mpr (by omega)
  have hM_ge1 : (1:ℝ) ≤ ↑(N - 1) := by exact_mod_cast (show (N-1 : ℕ) ≥ 1 from by omega)
  have hM_ge9 : (9:ℝ) ≤ ↑(N - 1) := by exact_mod_cast (show (N-1 : ℕ) ≥ 9 from by omega)
  have hN_pos : (0:ℝ) < ↑N := Nat.cast_pos.mpr (by omega)
  have hN_ge1 : (1:ℝ) ≤ ↑N := by exact_mod_cast (show N ≥ 1 from by omega)
  -- Step 1: Split M^{-1/4} = M^{-1/8} · M^{-1/8}
  have h_split : (↑(N-1) : ℝ) ^ (-(1:ℝ)/4) =
      (↑(N-1) : ℝ) ^ (-(1:ℝ)/8) * (↑(N-1) : ℝ) ^ (-(1:ℝ)/8) := by
    rw [← rpow_add hM_pos]; congr 1; ring
  -- Step 2: Factor bounds
  have h_factor1 := log_mul_rpow_neg_eighth_le ↑(N-1) hM_ge1
  have h_factor2_base := log_mul_rpow_neg_eighth_le ↑N hN_ge1
  -- Step 3: N/M ratio bound
  have h_NM_ratio : ((↑N : ℝ) / (↑(N-1) : ℝ)) ≤ 10/9 := by
    rw [div_le_div_iff₀ hM_pos (by norm_num : (0:ℝ) < 9)]
    have : (↑N : ℝ) = (↑(N-1) : ℝ) + 1 := by
      rw [Nat.cast_sub (by omega : 1 ≤ N)]; ring
    nlinarith
  have h_NM_ge1 : (1:ℝ) ≤ (↑N : ℝ) / (↑(N-1) : ℝ) := by
    rw [le_div_iff₀ hM_pos]
    have : (↑N : ℝ) = (↑(N-1) : ℝ) + 1 := by
      rw [Nat.cast_sub (by omega : 1 ≤ N)]; ring
    linarith
  -- Step 4: (N/M)^{1/8} ≤ N/M (since N/M ≥ 1 and 1/8 ≤ 1)
  have h_rpow_eighth_le : ((↑N : ℝ) / (↑(N-1) : ℝ)) ^ ((1:ℝ)/8) ≤ (↑N : ℝ) / (↑(N-1) : ℝ) := by
    calc ((↑N : ℝ) / (↑(N-1) : ℝ)) ^ ((1:ℝ)/8)
        ≤ ((↑N : ℝ) / (↑(N-1) : ℝ)) ^ (1:ℝ) :=
          rpow_le_rpow_of_exponent_le h_NM_ge1 (by norm_num)
      _ = (↑N : ℝ) / (↑(N-1) : ℝ) := rpow_one _
  -- Step 5: N^{1/8} · M^{-1/8} = (N/M)^{1/8}
  have h_rpow_ratio : (↑N : ℝ) ^ ((1:ℝ)/8) * (↑(N-1) : ℝ) ^ (-(1:ℝ)/8) =
      ((↑N : ℝ) / (↑(N-1) : ℝ)) ^ ((1:ℝ)/8) := by
    rw [show (-(1:ℝ)/8) = -(((1:ℝ)/8)) from by ring, rpow_neg hM_pos.le,
        ← div_eq_mul_inv, div_rpow hN_pos.le hM_pos.le]
  -- Step 6: logN · M^{-1/8} ≤ 8·exp(-1) · (10/9)
  have h_logN_nn : 0 ≤ Real.log ↑N := Real.log_nonneg hN_ge1
  have h_rpow_nn : 0 ≤ (↑(N-1) : ℝ) ^ (-(1:ℝ)/8) := (rpow_pos_of_pos hM_pos _).le
  have h_factor2 : Real.log ↑N * (↑(N-1) : ℝ) ^ (-(1:ℝ)/8) ≤
      8 * Real.exp (-1) * (10/9) := by
    have h_expand : Real.log ↑N * (↑(N-1) : ℝ) ^ (-(1:ℝ)/8) =
        (Real.log ↑N * (↑N : ℝ) ^ (-(1:ℝ)/8)) *
        ((↑N : ℝ) ^ ((1:ℝ)/8) * (↑(N-1) : ℝ) ^ (-(1:ℝ)/8)) := by
      have h1 : (↑N : ℝ) ^ (-(1:ℝ)/8) * (↑N : ℝ) ^ ((1:ℝ)/8) = 1 := by
        rw [← rpow_add hN_pos]
        simp only [show (-(1:ℝ)/8 + (1:ℝ)/8 : ℝ) = 0 from by ring]
        exact rpow_zero _
      calc Real.log ↑N * (↑(N-1) : ℝ) ^ (-(1:ℝ)/8)
          = Real.log ↑N * 1 * (↑(N-1) : ℝ) ^ (-(1:ℝ)/8) := by ring
        _ = Real.log ↑N * ((↑N : ℝ) ^ (-(1:ℝ)/8) * (↑N : ℝ) ^ ((1:ℝ)/8)) *
            (↑(N-1) : ℝ) ^ (-(1:ℝ)/8) := by rw [h1]
        _ = (Real.log ↑N * (↑N : ℝ) ^ (-(1:ℝ)/8)) *
            ((↑N : ℝ) ^ ((1:ℝ)/8) * (↑(N-1) : ℝ) ^ (-(1:ℝ)/8)) := by ring
    rw [h_expand, h_rpow_ratio]
    calc (Real.log ↑N * (↑N : ℝ) ^ (-(1:ℝ)/8)) * (((↑N : ℝ) / (↑(N-1) : ℝ)) ^ ((1:ℝ)/8))
        ≤ (8 * Real.exp (-1)) * ((↑N : ℝ) / (↑(N-1) : ℝ)) :=
          mul_le_mul h_factor2_base (le_trans h_rpow_eighth_le (le_refl _))
            (rpow_pos_of_pos (div_pos hN_pos hM_pos) _).le
            (by linarith [exp_pos (-1)])
      _ ≤ (8 * Real.exp (-1)) * (10/9) :=
          mul_le_mul_of_nonneg_left h_NM_ratio (by linarith [exp_pos (-1)])
  -- Step 7: Assembly
  rw [h_split]
  calc (↑(N-1) : ℝ) ^ (-(1:ℝ)/8) * (↑(N-1) : ℝ) ^ (-(1:ℝ)/8) *
      Real.log ↑(N-1) * Real.log ↑N
      = (Real.log ↑(N-1) * (↑(N-1) : ℝ) ^ (-(1:ℝ)/8)) *
        (Real.log ↑N * (↑(N-1) : ℝ) ^ (-(1:ℝ)/8)) := by ring
    _ ≤ (8 * Real.exp (-1)) * (8 * Real.exp (-1) * (10/9)) :=
        mul_le_mul h_factor1 h_factor2
          (mul_nonneg h_logN_nn h_rpow_nn) (by linarith [exp_pos (-1)])
    _ = 64 * (Real.exp (-1) * Real.exp (-1)) * (10/9) := by ring
    _ = 64 * Real.exp ((-1) + (-1)) * (10/9) := by rw [← Real.exp_add]
    _ = 64 * Real.exp (-2) * (10/9) := by norm_num
    _ ≤ 10 := sixtyFour_exp_neg_two_le

end

