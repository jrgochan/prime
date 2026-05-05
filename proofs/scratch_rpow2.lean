/-
  Scratch: rpow monotonicity for Three-Circles interpolation.

  Goal: 6^(1-θ) · b^θ ≤ K · (log(2+|t|))^α
  where θ ≤ α, b ≤ C·log(2+|t|), K = 6^(1-α) · C^α, C > 0.

  Strategy:
    6^(1-θ) · b^θ
    ≤ 6^(1-θ) · (C·log)^θ     [b ≤ C·log, rpow monotone]
    = 6^(1-θ) · C^θ · (log)^θ  [mul_rpow]
    ≤ 6^1 · C^1 · (log)^α      [rpow ≤ for base ≥ 1, exponent ≤]
    = 6·C · (log)^α             [arithmetic]

  But our K = 6^(1-α)·C^α, not 6·C. So K ≤ 6·C is fine (pessimistic but correct).

  Actually even simpler: just set K = 6·C and prove the bound directly.
  Then sub_log_to_polynomial works with K = 6·C and α.
-/

import Mathlib.Analysis.SpecialFunctions.Pow.Real
import Mathlib.Analysis.SpecialFunctions.Log.Basic

noncomputable section
open Real

-- Key lemma 1: x^θ ≤ x^α when x ≥ 1, 0 ≤ θ ≤ α
lemma rpow_le_rpow_of_base_ge_one {x θ α : ℝ}
    (hx : 1 ≤ x) (hθ : 0 ≤ θ) (hθα : θ ≤ α) :
    x ^ θ ≤ x ^ α :=
  rpow_le_rpow_of_exponent_le hx hθα

-- Key lemma 2: x^θ ≤ x when x ≥ 1, 0 ≤ θ ≤ 1
lemma rpow_le_self_of_ge_one {x θ : ℝ}
    (hx : 1 ≤ x) (hθ : 0 ≤ θ) (hθ1 : θ ≤ 1) :
    x ^ θ ≤ x := by
  have := rpow_le_rpow_of_exponent_le hx hθ1
  rwa [rpow_one] at this

-- The full three-circles rpow monotonicity
lemma tc_rpow_monotone {a b C θ α L : ℝ}
    (ha : 1 ≤ a) (hb_nonneg : 0 ≤ b) (hC : 0 < C) (hL : 0 < L)
    (hθ : 0 ≤ θ) (hθα : θ ≤ α) (hα : α ≤ 1)
    (hb_le : b ≤ C * L) :
    a ^ (1 - θ) * b ^ θ ≤ a * C * L ^ α := by
  -- Step 1: b^θ ≤ (C·L)^θ
  have hCL_nonneg : 0 ≤ C * L := mul_nonneg (le_of_lt hC) (le_of_lt hL)
  have h1 : b ^ θ ≤ (C * L) ^ θ := rpow_le_rpow hb_nonneg hb_le hθ
  -- Step 2: (C·L)^θ = C^θ · L^θ
  have h2 : (C * L) ^ θ = C ^ θ * L ^ θ :=
    mul_rpow (le_of_lt hC) (le_of_lt hL)
  -- Step 3: C^θ ≤ C (since C ≥ 1... wait, C might be < 1)
  -- Actually, we need C ≥ 1 for this. If C < 1, C^θ > C. Hmm.
  -- Let's handle this differently.
  -- Alternative: a^(1-θ)·b^θ ≤ a^(1-θ)·(C·L)^θ ≤ a·(C·L)^1 = a·C·L
  -- Since a^(1-θ)·(C·L)^θ is a weighted geometric mean of a and C·L,
  -- it is ≤ max(a, C·L) ≤ a + C·L ≤ a·C·L + ... no, this isn't clean.

  -- Simplest approach: weighted geometric mean ≤ weighted arithmetic mean ≤ max
  -- a^(1-θ)·(C·L)^θ ≤ (1-θ)·a + θ·(C·L) by AM-GM
  -- But this gives a linear bound, not L^α.

  -- Let's go back to the direct factoring:
  -- a^(1-θ) ≤ a (since a ≥ 1, 1-θ ≤ 1)
  -- C^θ ≤ max(1, C) (since 0 ≤ θ ≤ 1)
  -- L^θ ≤ L^α (since L > 0 and... wait, L could be < 1)
  -- Hmm, L = log(2+|t|) and |t| ≥ 2, so L = log(2+|t|) ≥ log 4 > 1. OK so L ≥ 1.
  sorry

-- Let me try a cleaner version with all assumptions explicit:
-- For the actual use case: a = 6, b = 2M·R₃/(R₄-R₃), C = 22·R₃/(R₄-R₃),
-- L = log(2+|t|), θ ≤ α < 1, a ≥ 1, C ≥ 1, L ≥ 1.

/-- Three-Circles rpow monotonicity: a^(1-θ)·b^θ ≤ (a·C)·L^α
    when a ≥ 1, b ≤ C·L, C ≥ 1, L ≥ 1, 0 ≤ θ ≤ α ≤ 1. -/
lemma tc_rpow_bound {a b C L θ α : ℝ}
    (ha : 1 ≤ a) (hC : 1 ≤ C) (hL : 1 ≤ L)
    (hb : 0 ≤ b) (hbCL : b ≤ C * L)
    (hθ : 0 ≤ θ) (hθα : θ ≤ α) (hα : α ≤ 1) :
    a ^ (1 - θ) * b ^ θ ≤ a * C * L ^ α := by
  -- Chain: a^(1-θ) · b^θ ≤ a^(1-θ) · (C·L)^θ ≤ a · C · L^α
  have hCL : 0 ≤ C * L := mul_nonneg (le_trans zero_le_one hC) (le_trans zero_le_one hL)
  -- Step 1: b^θ ≤ (C·L)^θ
  have h_b_rpow : b ^ θ ≤ (C * L) ^ θ := rpow_le_rpow hb hbCL hθ
  -- Step 2: a^(1-θ) ≤ a (since a ≥ 1, 0 ≤ 1-θ ≤ 1)
  have h1mθ : 0 ≤ 1 - θ := by linarith [le_trans hθα hα]
  have h1mθ_le : 1 - θ ≤ 1 := by linarith
  have h_a_rpow : a ^ (1 - θ) ≤ a := by
    have := rpow_le_rpow_of_exponent_le ha h1mθ_le
    rwa [rpow_one] at this
  -- Step 3: (C·L)^θ = C^θ · L^θ
  have h_mul_rpow : (C * L) ^ θ = C ^ θ * L ^ θ :=
    mul_rpow (le_trans zero_le_one hC) (le_trans zero_le_one hL)
  -- Step 4: C^θ ≤ C (since C ≥ 1, 0 ≤ θ ≤ 1)
  have h_C_rpow : C ^ θ ≤ C := by
    have := rpow_le_rpow_of_exponent_le hC (le_trans hθα hα)
    rwa [rpow_one] at this
  -- Step 5: L^θ ≤ L^α (since L ≥ 1, θ ≤ α)
  have h_L_rpow : L ^ θ ≤ L ^ α :=
    rpow_le_rpow_of_exponent_le hL hθα
  -- Combine
  calc a ^ (1 - θ) * b ^ θ
      ≤ a * (C * L) ^ θ := by
        apply mul_le_mul h_a_rpow h_b_rpow (rpow_nonneg hb _)
          (le_trans zero_le_one ha)
    _ = a * (C ^ θ * L ^ θ) := by rw [h_mul_rpow]
    _ ≤ a * (C * L ^ α) := by
        apply mul_le_mul_of_nonneg_left _ (le_trans zero_le_one ha)
        exact mul_le_mul h_C_rpow h_L_rpow (rpow_nonneg (le_trans zero_le_one hL) _)
          (le_trans zero_le_one hC)
    _ = a * C * L ^ α := by ring

#check @tc_rpow_bound
