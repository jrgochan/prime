/-
  Cathedral/Robin/PrimeBounds.lean

  ## Prime Power Bounds for Robin/Lagarias

  Key results:
  - geom_sum_le_two_pow: Σ_{j=0}^k P^j ≤ 2·P^k for P ≥ 2
  - sigma_one_prime_pow_bound: σ(p^k) ≤ 2·p^k for primes p

  The geometric sum lemma is proved by induction, bypassing
  complex fractional/algebraic rewrites.
-/

import Cathedral.Robin.Defs
import Cathedral.Robin.SigmaProps

open Real ArithmeticFunction

-- ════════════════════════════════════════════════
-- PART I: GEOMETRIC SUM BOUND
-- ════════════════════════════════════════════════

/-- **LEMMA (PROVED)**: Geometric sum bound by induction.
    Σ_{j=0}^k P^j ≤ 2·P^k for P ≥ 2.

    Avoids the closed-form (P^{k+1}-1)/(P-1) and its Nat division issues. -/
lemma geom_sum_le_two_pow (P : ℝ) (hP : 2 ≤ P) (k : ℕ) :
    ∑ j ∈ Finset.range (k + 1), P ^ j ≤ 2 * P ^ k := by
  induction k with
  | zero =>
    simp only [Finset.range_one, Finset.sum_singleton, pow_zero, mul_one]
    -- Goal: 1 ≤ 2
    norm_num
  | succ k ih =>
    rw [Finset.sum_range_succ]
    -- Goal: Σ_{j=0}^k P^j + P^{k+1} ≤ 2 * P^{k+1}
    calc ∑ j ∈ Finset.range (k + 1), P ^ j + P ^ (k + 1)
      _ ≤ 2 * P ^ k + P ^ (k + 1) := by linarith
      _ ≤ P * P ^ k + P ^ (k + 1) := by
          have : 2 * P ^ k ≤ P * P ^ k :=
            mul_le_mul_of_nonneg_right hP (by positivity)
          linarith
      _ = P ^ (k + 1) + P ^ (k + 1) := by ring_nf
      _ = 2 * P ^ (k + 1) := by ring

-- ════════════════════════════════════════════════
-- PART II: PRIME POWER SIGMA BOUND
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: σ(p^k) ≤ 2·p^k for prime powers.

    Uses the geometric sum bound to avoid closed-form division. -/
theorem sigma_one_prime_pow_bound {p k : ℕ} (hp : p.Prime) (hk : 1 ≤ k) :
    (sumOfDivisors (p ^ k) : ℝ) ≤ 2 * (p ^ k : ℝ) := by
  unfold sumOfDivisors
  have h_apply := sigma_one_apply_prime_pow (i := k) hp
  have h_cast : ((sigma 1) (p ^ k) : ℝ) = ∑ j ∈ Finset.range (k + 1), (p : ℝ) ^ j := by
    rw [h_apply]
    push_cast
    rfl
  rw [h_cast]
  have hp2 : 2 ≤ (p : ℝ) := by exact_mod_cast hp.two_le
  exact geom_sum_le_two_pow (p : ℝ) hp2 k

-- ════════════════════════════════════════════════
-- PART III: LAGARIAS FOR PRIMES (SCAFFOLDING)
-- ════════════════════════════════════════════════

/-- **THEOREM (SCAFFOLDING)**: Lagarias holds for all primes.

    The Theorist's Bypass:
    For p ≥ 11: H_p ≥ log(p+1), so exp(H_p) ≥ p+1.
    Since H_p > e for p ≥ 11, log(H_p) > 1.
    Therefore exp(H_p)·log(H_p) ≥ p+1 = σ(p).

    For p ∈ {2,3,5,7}: Taylor polynomial bounds
    (as pioneered in GramDiag.lean). -/
theorem lagarias_for_primes {p : ℕ} (hp : p.Prime) :
    (sumOfDivisors p : ℝ) ≤
      harmonicR p + exp (harmonicR p) * log (harmonicR p) := by
  sorry

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- This file has:
--   1 sorry (lagarias_for_primes — uses Theorist's Bypass strategy)
--   ZERO axioms
--   2 PROVED theorems + 1 PROVED lemma:
--     ✅ geom_sum_le_two_pow           — Σ P^j ≤ 2·P^k
--     ✅ sigma_one_prime_pow_bound     — σ(p^k) ≤ 2p^k
--     ⚠️  lagarias_for_primes          — scaffolding
