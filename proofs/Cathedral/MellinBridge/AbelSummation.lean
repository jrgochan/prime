/-
  Cathedral/MellinBridge/AbelSummation.lean

  ## Discrete Summation by Parts (Abel's Lemma)

  The algebraic core of Axiom 2 (abel_summation_l2_bound).

  This file proves the discrete summation-by-parts identity:
    Σ_{k=M}^N a(k)·f(k) = A(N)·f(N) - Σ_{k=M}^{N-1} A(k)·(f(k+1) - f(k))

  where A(k) = Σ_{j=M}^k a(j).

  Once proved, this is the engine that converts:
    - a(k) = μ(k)/k  →  A(k) = partial Mertens function
    - f(k) = 1 - log(k)/log(N)  →  f(k+1) - f(k) ≈ -1/(k·log N)
    - Mertens bound |A(k)| ≤ C√k·log²k  →  L² error ≤ C/log(N)
-/

import Cathedral.Defs

open Finset BigOperators

noncomputable section

-- ════════════════════════════════════════════════
-- THE CORE IDENTITY
-- ════════════════════════════════════════════════

/-- The partial sum A(k) = Σ_{j=M}^k a(j). -/
def partialSum (a : ℕ → ℝ) (M k : ℕ) : ℝ :=
  (Finset.Icc M k).sum a

/-- **THEOREM (Discrete Summation by Parts — Abel's Lemma)**

    Σ_{k=M}^N a(k)·f(k) = A(N)·f(N) - Σ_{k=M}^{N-1} A(k)·(f(k+1) - f(k))

    where A(k) = Σ_{j=M}^k a(j).

    This is the discrete analogue of integration by parts.
    Proof by induction on the difference N - M. -/
theorem abel_summation (a f : ℕ → ℝ) (M N : ℕ) (hMN : M ≤ N) :
    (Icc M N).sum (fun k => a k * f k) =
    partialSum a M N * f N -
    (Ico M N).sum (fun k => partialSum a M k * (f (k + 1) - f k)) := by
  unfold partialSum
  -- Induction on the difference N - M
  obtain ⟨d, rfl⟩ := Nat.exists_eq_add_of_le hMN
  induction d with
  | zero =>
    simp [Finset.Icc_self]
  | succ n ih =>
    have hle : M ≤ M + n := Nat.le_add_right M n
    -- Normalize: Lean sees M + (n + 1), we need M + n + 1
    change (Icc M (M + n + 1)).sum (fun k => a k * f k) =
      (Icc M (M + n + 1)).sum a * f (M + n + 1) -
      (Ico M (M + n + 1)).sum (fun k => (Icc M k).sum a * (f (k + 1) - f k))
    -- Split the intervals
    have h_icc : Icc M (M + n + 1) = Icc M (M + n) ∪ {M + n + 1} := by
      ext x; simp [Finset.mem_Icc]; omega
    have h_disj_icc : Disjoint (Icc M (M + n)) {M + n + 1} := by
      simp [Finset.disjoint_singleton_right, Finset.mem_Icc]
    have h_ico : Ico M (M + n + 1) = Ico M (M + n) ∪ {M + n} := by
      ext x; simp [Finset.mem_Ico]
    have h_disj_ico : Disjoint (Ico M (M + n)) {M + n} := by
      simp [Finset.disjoint_singleton_right, Finset.mem_Ico]
    -- Expand the LHS
    rw [h_icc, Finset.sum_union h_disj_icc, Finset.sum_singleton]
    -- Expand the RHS sums
    rw [h_ico, Finset.sum_union h_disj_ico, Finset.sum_singleton]
    -- Apply IH to rewrite the Icc sum
    rw [ih (by omega)]
    -- Expand the union partial sum on the RHS
    rw [Finset.sum_union h_disj_icc, Finset.sum_singleton]
    -- The goal is now pure algebra over ℝ
    ring

-- ════════════════════════════════════════════════
-- COROLLARIES FOR THE WEIGHT CONSTRUCTION
-- ════════════════════════════════════════════════

/-- **PROVED**: Abel summation with absolute value bound on the partial sums.
    This strictly isolates the triangle inequality and monotonic bounding logic.

    Given:
    - |A(k)| ≤ C_bound(k) for all M ≤ k ≤ N
    - |f(k+1) - f(k)| ≤ δ(k) for all M ≤ k < N

    Produces:
    - |Σ a(k)·f(k)| ≤ C_bound(N)·|f(N)| + Σ C_bound(k)·δ(k) -/
theorem abel_summation_abs_bound (a f : ℕ → ℝ) (M N : ℕ) (hMN : M ≤ N)
    (C_bound : ℕ → ℝ) (δ : ℕ → ℝ)
    (hA : ∀ k, M ≤ k → k ≤ N → |partialSum a M k| ≤ C_bound k)
    (hf_mono : ∀ k, M ≤ k → k < N → |f (k + 1) - f k| ≤ δ k) :
    |(Icc M N).sum (fun k => a k * f k)| ≤
    C_bound N * |f N| +
    (Ico M N).sum (fun k => C_bound k * δ k) := by
  -- Step 1: Apply the exact Abel identity
  rw [abel_summation a f M N hMN]
  -- Step 2: Triangle inequality: |x - y| ≤ |x| + |y|
  have h_tri : ∀ x y : ℝ, |x - y| ≤ |x| + |y| := fun x y => by
    rcases le_or_gt 0 (x - y) with h | h
    · rw [abs_of_nonneg h]
      linarith [le_abs_self x, neg_abs_le y]
    · rw [abs_of_neg h]
      linarith [neg_abs_le x, abs_nonneg y, le_abs_self y]
  -- Step 3: Bound the first term |A(N) * f(N)| ≤ C_bound(N) * |f(N)|
  have h_first : |partialSum a M N * f N| ≤ C_bound N * |f N| := by
    rw [abs_mul]
    exact mul_le_mul_of_nonneg_right (hA N hMN le_rfl) (abs_nonneg _)
  -- Step 4: Bound the sum term |Σ A(k)·Δf(k)| ≤ Σ C_bound(k)·δ(k)
  have h_second : |(Ico M N).sum (fun k => partialSum a M k * (f (k + 1) - f k))| ≤
      (Ico M N).sum (fun k => C_bound k * δ k) := by
    calc |(Ico M N).sum (fun k => partialSum a M k * (f (k + 1) - f k))|
      _ ≤ (Ico M N).sum (fun k => |partialSum a M k * (f (k + 1) - f k)|) :=
            Finset.abs_sum_le_sum_abs _ _
      _ = (Ico M N).sum (fun k => |partialSum a M k| * |f (k + 1) - f k|) := by
            congr 1; ext k; exact abs_mul _ _
      _ ≤ (Ico M N).sum (fun k => C_bound k * δ k) := by
            apply Finset.sum_le_sum
            intro k hk
            rw [Finset.mem_Ico] at hk
            exact mul_le_mul (hA k hk.1 (le_of_lt hk.2))
              (hf_mono k hk.1 hk.2) (abs_nonneg _)
              (le_trans (abs_nonneg _) (hA k hk.1 (le_of_lt hk.2)))
  -- Step 5: Combine via linarith
  linarith [h_tri (partialSum a M N * f N)
    ((Ico M N).sum (fun k => partialSum a M k * (f (k + 1) - f k)))]

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- This file has:
--   ✅ abel_summation              — The discrete identity (PROVED!)
--   ✅ abel_summation_abs_bound    — Triangle inequality (PROVED!)
--   FULLY PROVED, 0 axiom
--
-- NEXT: Instantiate with Möbius weights to close Axiom 2.

end
