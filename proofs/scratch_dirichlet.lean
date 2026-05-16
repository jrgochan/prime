import Mathlib.NumberTheory.ArithmeticFunction.Moebius
import Mathlib.Data.Real.Basic

open Finset ArithmeticFunction

axiom moebius_divisor_sum (n : ℕ) (hn : 0 < n) :
    ∑ d ∈ n.divisors, (moebius d : ℤ) = if n = 1 then 1 else 0

lemma reindexed_eq (h : ℕ → ℝ) (M : ℕ) (hM : 0 < M) :
    ∑ n ∈ range M,
      (∑ r ∈ (n + 1).divisors, (moebius r : ℝ)) * h (n + 1) = h 1 := by
  have hmob : ∀ n, (∑ r ∈ (n + 1).divisors, (moebius r : ℝ)) =
      if n = 0 then (1 : ℝ) else 0 := by
    intro n
    have h1 := moebius_divisor_sum (n + 1) (by omega)
    have h1' : (∑ d ∈ (n + 1).divisors, moebius d : ℤ) = if n = 0 then 1 else 0 := by
      convert h1 using 2; omega
    exact_mod_cast h1'
  simp_rw [hmob]
  simp only [ite_mul, one_mul, zero_mul]
  rw [sum_ite_eq' (range M) 0]
  simp [show 0 ∈ range M from mem_range.mpr hM]
