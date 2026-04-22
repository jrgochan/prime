/-
  Cathedral/AbelTail/MertensBridge.lean

  ## Mertens Function ↔ Finset Sum Bridge

  Provides the casting firewall (Theorist "Bypass B") and the
  key identity connecting mertensFunction to Finset.Icc sums:
    M(k) = Σ_{n=1}^k μ(n)

  This is needed to apply abel_summation_abs_bound (which works
  with Finset sums) to Mertens function bounds (which are stated
  in terms of mertensFunction).
-/

import Cathedral.MellinBridge.MertensBound
import Cathedral.MellinBridge.AbelSummation
import Cathedral.Defs

noncomputable section
open Real Finset BigOperators

-- ════════════════════════════════════════════════
-- §1. CASTING FIREWALL (Bypass B)
-- ════════════════════════════════════════════════

/-- **PROVED**: Mertens bound in pure ℝ form. Pay the coercion tax ONCE. -/
theorem mertens_bound_real
    (C_m : ℝ) (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (k : ℕ) (hk : 2 ≤ k) :
    |((mertensFunction (k : ℝ) : ℤ) : ℝ)| ≤ C_m * (k : ℝ) ^ ((3:ℝ)/4) :=
  hMertens (k : ℝ) (by exact_mod_cast hk)

-- ════════════════════════════════════════════════
-- §2. MERTENS ↔ FINSET IDENTITY
-- ════════════════════════════════════════════════

/-- **PROVED**: M(k) = Σ_{n=1}^k μ(n) for k ≥ 1. -/
theorem mertens_eq_icc_sum (k : ℕ) (hk : 1 ≤ k) :
    ((mertensFunction (k : ℝ) : ℤ) : ℝ) =
    (Icc 1 k).sum (fun n => (↑(ArithmeticFunction.moebius n) : ℝ)) := by
  unfold mertensFunction
  push_cast
  congr 1
  ext n
  simp only [Finset.mem_filter, Finset.mem_range, Finset.mem_Icc]
  rw [Nat.floor_natCast]
  constructor
  · rintro ⟨h1, h2, h3⟩
    exact ⟨h3, by exact_mod_cast h2⟩
  · rintro ⟨h1, h2⟩
    exact ⟨by omega, by exact_mod_cast h2, h1⟩

/-- **PROVED**: The partial sum over [N+1, k] equals M(k) - M(N). -/
theorem partial_sum_eq_mertens_diff (N k : ℕ) (hN : 1 ≤ N) (hk : N + 1 ≤ k) :
    (Icc (N+1) k).sum (fun n => (↑(ArithmeticFunction.moebius n) : ℝ)) =
    ((mertensFunction (k:ℝ) : ℤ) : ℝ) - ((mertensFunction (N:ℝ) : ℤ) : ℝ) := by
  rw [mertens_eq_icc_sum k (by omega), mertens_eq_icc_sum N hN]
  rw [show Icc 1 k = Icc 1 N ∪ Icc (N+1) k from by
    ext x; simp [Finset.mem_Icc, Finset.mem_union]; omega]
  rw [Finset.sum_union (by
    rw [Finset.disjoint_left]; intro x hx1 hx2
    simp [Finset.mem_Icc] at hx1 hx2; omega)]
  ring

end
