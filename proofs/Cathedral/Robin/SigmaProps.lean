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
    Each divisor d | n satisfies d ≤ n, so d^1 ≤ n^1.
    Thus σ₁(n) = Σ d|n d ≤ Σ d|n n = n · |divisors(n)| ≤ n · n = n². -/
theorem sigma_one_le_sq (n : ℕ) : sumOfDivisors n ≤ n ^ 2 := by
  unfold sumOfDivisors
  rw [sigma_one_apply, sq]
  calc ∑ d ∈ Nat.divisors n, d
      ≤ ∑ _d ∈ Nat.divisors n, n := by
        apply Finset.sum_le_sum
        intro d hd
        exact Nat.le_of_dvd (Nat.pos_of_ne_zero (by intro h; simp [h] at hd))
          (Nat.dvd_of_mem_divisors hd)
    _ = (Nat.divisors n).card * n := by rw [Finset.sum_const, smul_eq_mul]
    _ ≤ n * n := by
        apply Nat.mul_le_mul_right
        exact Nat.card_divisors_le_self n

-- ════════════════════════════════════════════════
-- PART IV: SIGMA LOWER BOUND
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: σ(n) ≥ n + 1 for n ≥ 2.
    Every n ≥ 2 has at least 1 and n as distinct divisors. -/
theorem sigma_one_ge_succ (n : ℕ) (hn : 2 ≤ n) :
    n + 1 ≤ sumOfDivisors n := by
  unfold sumOfDivisors
  have h_le : ({1, n} : Finset ℕ).sum _root_.id ≤ (sigma 1) n := by
    rw [sigma_one_apply]
    apply Finset.sum_le_sum_of_subset
    intro x hx
    simp only [Finset.mem_insert, Finset.mem_singleton] at hx
    rcases hx with rfl | rfl
    · simp; omega
    · simp; omega
  have h_sum : ({1, n} : Finset ℕ).sum _root_.id = 1 + n := by
    rw [Finset.sum_pair (by omega : (1:ℕ) ≠ n)]
    rfl
  omega

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- This file has:
--   ZERO sorry
--   ZERO axioms
--   4 PROVED theorems:
--     ✅ sigma_one_prime              — σ(p) = p + 1
--     ✅ sumOfDivisors_mul_coprime   — σ(mn) = σ(m)σ(n) for coprime
--     ✅ sigma_one_le_sq             — σ(n) ≤ n²
--     ✅ sigma_one_ge_succ           — σ(n) ≥ n + 1
