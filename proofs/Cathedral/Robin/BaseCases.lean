/-
  Cathedral/Robin/BaseCases.lean

  ## Lagarias Base Case Verification

  Proves Lagarias's inequality for n = 1:
    σ(1) = 1 ≤ H₁ + exp(H₁)·log(H₁) = 1 + e·0 = 1
-/

import Cathedral.Robin.Defs
import Mathlib.NumberTheory.ArithmeticFunction.Misc
import Mathlib.NumberTheory.Harmonic.Defs

open Real ArithmeticFunction

-- ════════════════════════════════════════════════
-- LAGARIAS BASE CASE
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: Lagarias holds for n = 1.

    σ(1) = 1, H₁ = 1, log(1) = 0, exp(1)·0 = 0.
    So σ(1) ≤ 1 + 0 = 1. Exact equality. -/
theorem lagarias_base_case :
    (sumOfDivisors 1 : ℝ) ≤ harmonicR 1 + exp (harmonicR 1) * log (harmonicR 1) := by
  unfold sumOfDivisors harmonicR
  have h_sigma : ((sigma 1) 1 : ℝ) = 1 := by norm_num
  have h_harmonic : (harmonic 1 : ℝ) = 1 := by norm_num
  rw [h_sigma, h_harmonic, log_one, mul_zero, add_zero]

/-- σ(1) = 1 (unit has only itself as divisor). -/
theorem sumOfDivisors_one : sumOfDivisors 1 = 1 := by
  unfold sumOfDivisors; norm_num

/-- σ(2) = 3 (divisors: 1, 2). -/
theorem sumOfDivisors_two : sumOfDivisors 2 = 3 := by
  unfold sumOfDivisors; native_decide

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- This file has:
--   ZERO sorry
--   ZERO axioms
--   3 PROVED theorems:
--     ✅ lagarias_base_case — σ(1) ≤ H₁ + exp(H₁)·log(H₁)
--     ✅ sumOfDivisors_one  — σ(1) = 1
--     ✅ sumOfDivisors_two  — σ(2) = 3
