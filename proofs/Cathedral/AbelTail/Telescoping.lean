/-
  Cathedral/AbelTail/Telescoping.lean

  ## Telescoping Sum Infrastructure

  Provides finite telescoping identities used throughout the Abel tail:
  - Σ (1/k - 1/(k+1)) = 1/a - 1/(a+d+1)  [partial fractions]
  - Σ 1/(k(k+1)) ≤ 1/(N+1)  [consequence]

  These are elementary but need careful Lean formalization
  with cast normalization (ℕ → ℝ).
-/

import Cathedral.Defs

noncomputable section
open Real Finset BigOperators

-- ════════════════════════════════════════════════
-- §1. BASIC TELESCOPING IDENTITY
-- ════════════════════════════════════════════════

/-- **PROVED**: Telescoping identity for 1/k - 1/(k+1). -/
theorem finset_sum_tele (a d : ℕ) :
    (Icc a (a + d)).sum (fun k => 1 / (k : ℝ) - 1 / ((k : ℝ) + 1)) =
    1 / (a : ℝ) - 1 / (((a + d : ℕ) : ℝ) + 1) := by
  induction d with
  | zero => simp [Finset.Icc_self]
  | succ n ih =>
    rw [show a + (n + 1) = a + n + 1 from by omega,
        Finset.sum_Icc_succ_top (by omega : a ≤ a + n + 1), ih]
    push_cast; ring

-- ════════════════════════════════════════════════
-- §2. PARTIAL FRACTION TAIL BOUND
-- ════════════════════════════════════════════════

/-- **PROVED**: Σ_{k=N+1}^{M} 1/(k(k+1)) ≤ 1/(N+1).
    Uses partial fractions + finite telescoping. -/
theorem finite_inv_kk1_bound (N M : ℕ) (hN : 1 ≤ N) (hNM : N + 1 ≤ M) :
    (Icc (N+1) M).sum (fun k => 1 / ((k : ℝ) * ((k : ℝ) + 1))) ≤
    1 / ((N : ℝ) + 1) := by
  -- 1/(k(k+1)) = 1/k - 1/(k+1)
  have hrw : (Icc (N+1) M).sum (fun k => 1 / ((k : ℝ) * ((k : ℝ) + 1))) =
      (Icc (N+1) M).sum (fun k => 1 / (k : ℝ) - 1 / ((k : ℝ) + 1)) := by
    apply Finset.sum_congr rfl
    intro k hk; rw [Finset.mem_Icc] at hk
    have : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
    field_simp; ring
  rw [hrw]
  obtain ⟨d, rfl⟩ := Nat.exists_eq_add_of_le hNM
  rw [finset_sum_tele]
  have h_cast : (1 : ℝ) / ((N + 1 : ℕ) : ℝ) = 1 / ((N : ℝ) + 1) := by push_cast; ring
  rw [h_cast]
  have h_nn : (0 : ℝ) ≤ 1 / (((N + 1 + d : ℕ) : ℝ) + 1) :=
    div_nonneg one_pos.le (by positivity)
  linarith

end
