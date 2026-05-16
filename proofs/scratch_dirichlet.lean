import Cathedral.Physics.SmithWitness
import Cathedral.Physics.RamanujanBridge
import Mathlib.Tactic.FieldSimp

open Finset

-- Helper: entry-wise product R(j,k)·w(k) simplification
-- R(j,k)·12k·q = gcd(j,k)²·q/j
private lemma rw_cancel (j k : ℕ) (hj : 0 < j) (hk : 0 < k) (q : ℝ) :
    RamanujanBridge.ramanujanEntry j k * (12 * (k : ℝ) * q) =
    (Nat.gcd j k : ℝ) ^ 2 / (j : ℝ) * q := by
  unfold RamanujanBridge.ramanujanEntry
  have : (j : ℝ) ≠ 0 := by positivity
  have : (k : ℝ) ≠ 0 := by positivity
  field_simp

-- Test: does this integrate into the sum?
set_option maxHeartbeats 400000 in
example (N j : ℕ) (hN : 0 < N) (hj : 0 < j) :
    ∑ k ∈ range N,
      RamanujanBridge.ramanujanEntry j (k + 1) * SmithWitness.smithWitness N (k + 1) =
    ∑ k ∈ range N,
      (Nat.gcd j (k + 1) : ℝ) ^ 2 / (j : ℝ) *
      ∑ m ∈ range (N / (k + 1)),
        (SmithWitness.mu (m + 1) : ℝ) * SmithWitness.eulerPhi ((k + 1) * (m + 1)) /
        RamanujanBridge.jordanTotient2 ((k + 1) * (m + 1)) := by
  apply sum_congr rfl
  intro k hk
  simp only [SmithWitness.smithWitness]
  rw [rw_cancel j (k + 1) hj (by omega)]
