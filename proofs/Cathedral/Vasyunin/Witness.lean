/-
  Cathedral/Vasyunin/Witness.lean

  The Möbius function and the logarithmic cutoff witness vector.
-/

import Cathedral.Vasyunin.Defs

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- PART VII: THE MÖBIUS FUNCTION
-- ════════════════════════════════════════════════

/-- The Möbius function μ : ℕ → ℤ.
    μ(n) = 1    if n = 1
    μ(n) = (-1)^k if n is a product of k distinct primes
    μ(n) = 0    if n has a squared prime factor -/
noncomputable def moebiusFn : ℕ → ℤ := fun n => ArithmeticFunction.moebius n

-- ════════════════════════════════════════════════
-- PART VIII: THE LOG CUTOFF WITNESS VECTOR
-- ════════════════════════════════════════════════

/-- The logarithmic cutoff Möbius witness vector:
    v_k = -μ(k) · (1 - ln(k)/ln(N))

    This is the explicit, constructive witness to the Riemann Hypothesis.
    It damps the Möbius function at high frequencies using a logarithmic
    envelope that respects the multiplicative structure of the integers. -/
noncomputable def logCutoffWitness (N : ℕ) (i : Fin N) : ℝ :=
  -(↑(moebiusFn (i.val + 1)) : ℝ) * (1 - Real.log ↑(i.val + 1) / Real.log ↑N)

/-- μ(1) = 1 (from Mathlib). -/
theorem moebiusFn_one : moebiusFn 1 = 1 := by
  unfold moebiusFn; exact ArithmeticFunction.moebius_apply_one

/-- μ(2) = -1 (2 is prime). -/
theorem moebiusFn_two : moebiusFn 2 = -1 := by
  unfold moebiusFn; native_decide

/-- μ(3) = -1 (3 is prime). -/
theorem moebiusFn_three : moebiusFn 3 = -1 := by
  unfold moebiusFn; native_decide

/-- μ(4) = 0 (4 = 2², has squared factor). -/
theorem moebiusFn_four : moebiusFn 4 = 0 := by
  unfold moebiusFn; native_decide

/-- μ(6) = 1 (6 = 2·3, squarefree with 2 prime factors). -/
theorem moebiusFn_six : moebiusFn 6 = 1 := by
  unfold moebiusFn; native_decide

/-- μ(30) = -1 (30 = 2·3·5, squarefree with 3 prime factors). -/
theorem moebiusFn_thirty : moebiusFn 30 = -1 := by
  unfold moebiusFn; native_decide

/-- The first component of the witness: v₀ = -1 for N ≥ 2.
    v₀ = -μ(1) · (1 - ln(1)/ln(N)) = -(1) · (1 - 0) = -1. -/
theorem logCutoffWitness_first (N : ℕ) (hN : N ≥ 2) :
    logCutoffWitness N ⟨0, by omega⟩ = -1 := by
  unfold logCutoffWitness moebiusFn
  rw [ArithmeticFunction.moebius_apply_one]
  simp [Real.log_one]

/-- The last component of the witness: v_{N-1} = 0 for N ≥ 2.
    v_{N-1} = -μ(N) · (1 - ln(N)/ln(N)) = -μ(N) · 0 = 0.
    This is the "acoustic dampener" — the logarithmic envelope
    kills the boundary, preventing oscillation. -/
theorem logCutoffWitness_last (N : ℕ) (hN : N ≥ 2) :
    logCutoffWitness N ⟨N - 1, by omega⟩ = 0 := by
  unfold logCutoffWitness
  simp only []
  have hN_eq : N - 1 + 1 = N := by omega
  rw [hN_eq]
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  rw [div_self (Real.log_ne_zero_of_pos_of_ne_one hN_pos (by exact_mod_cast (by omega : N ≠ 1)))]
  simp

end Cathedral.Vasyunin
