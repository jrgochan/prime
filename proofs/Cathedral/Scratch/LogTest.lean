import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Analysis.SpecialFunctions.ExpDeriv

open Real

-- Test: can we prove log 2 ≥ 1/2?
-- Approach: 2 ≥ exp(1/2), i.e., exp(1/2) ≤ 2
-- Via: exp(1) ≤ 4, so (exp(1/2))² ≤ 4, so exp(1/2) ≤ 2
-- Or: just prove exp(1/2) ≤ 2 directly

example : (1:ℝ)/2 ≤ Real.log 2 := by
  rw [le_log_iff_exp_le (by norm_num : (0:ℝ) < 2)]
  -- Goal: exp(1/2) ≤ 2
  -- exp(1/2) = sqrt(e) ≈ 1.649
  have h1 : Real.exp (1/2 : ℝ) * Real.exp (1/2 : ℝ) = Real.exp 1 := by
    rw [← Real.exp_add]; norm_num
  -- exp(1) < 3 < 4 = 2*2
  -- So exp(1/2)² < 4 = 2², hence exp(1/2) < 2
  nlinarith [Real.exp_one_lt_d9, sq_nonneg (Real.exp (1/2 : ℝ) - 2)]
