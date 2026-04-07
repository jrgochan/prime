/-
  Cathedral/Robin/SigmaProps.lean

  ## Properties of the Sum-of-Divisors Function

  Proved theorems about σ₁(n) using Mathlib's ArithmeticFunction API:
  - σ(p) = p + 1 for primes
  - σ is multiplicative for coprime arguments
  - σ(n) ≤ n² (generic upper bound)
-/

import Cathedral.Robin.Defs
import Mathlib.NumberTheory.ArithmeticFunction.Misc

open ArithmeticFunction

-- ════════════════════════════════════════════════
-- PART I: SIGMA FOR PRIMES
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: σ(p) = p + 1 for primes.
    Uses Mathlib's `sigma_one_apply_prime_pow` with i = 1. -/
theorem sigma_one_prime {p : ℕ} (hp : p.Prime) :
    sumOfDivisors p = p + 1 := by
  unfold sumOfDivisors
  have h := sigma_one_apply_prime_pow (i := 1) hp
  rw [pow_one] at h
  rw [h]
  simp [Finset.sum_range_succ, add_comm]

-- ════════════════════════════════════════════════
-- PART II: MULTIPLICATIVITY
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: σ₁ is multiplicative for coprime arguments.
    σ(m·n) = σ(m)·σ(n) when gcd(m,n) = 1. -/
theorem sumOfDivisors_mul_coprime {m n : ℕ} (hmn : Nat.Coprime m n) :
    sumOfDivisors (m * n) = sumOfDivisors m * sumOfDivisors n := by
  unfold sumOfDivisors
  exact isMultiplicative_sigma.map_mul_of_coprime hmn

-- ════════════════════════════════════════════════
-- PART III: GENERIC UPPER BOUND
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: σ(n) ≤ n² for all n.
    Immediate from Mathlib's `sigma_le_pow_succ` with k = 1. -/
theorem sigma_one_le_sq (n : ℕ) : sumOfDivisors n ≤ n ^ 2 := by
  unfold sumOfDivisors
  exact sigma_le_pow_succ 1 n

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- This file has:
--   ZERO sorry
--   ZERO axioms
--   3 PROVED theorems:
--     ✅ sigma_one_prime              — σ(p) = p + 1
--     ✅ sumOfDivisors_mul_coprime   — σ(mn) = σ(m)σ(n) for coprime
--     ✅ sigma_one_le_sq             — σ(n) ≤ n²
