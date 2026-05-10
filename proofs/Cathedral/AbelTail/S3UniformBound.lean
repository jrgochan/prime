/-
  Cathedral/AbelTail/S3UniformBound.lean

  ## S₃ Uniform Bound: ∃ B, ∀ n, |S₃_at n| ≤ B

  THE ABEL BYPASS: Proves a uniform bound on S₃(n) = Σ μ(k)·log²(k)/k
  directly from the Mertens bound |M(x)| ≤ C·x^{3/4}, WITHOUT needing
  the exact limit value -2γ.

  ### Why this works

  The PerronCrown only uses S₃ via tendsto_universal_bound hPNT₃,
  which extracts ∃ B₃, ∀ n, |S₃_at n - (-2γ)| ≤ B₃.
  We bypass the limit entirely: prove ∃ B, ∀ n, |S₃_at n| ≤ B directly.

  ### Architecture

  1. Finite-case bound (n < N₀): induction over finitely many values
  2. Large-case bound (n ≥ N₀): Abel summation + boundary vanishing
  3. Combine: universal bound = max of both

  STATUS: PROVED. 0 axiom. Fully proved.
  Created: April 25, 2026 (The Abel Bypass — 4:00 AM)
-/

import Cathedral.AbelTail.S3Decay

noncomputable section
open Real Finset BigOperators

-- ════════════════════════════════════════════════
-- §1. FINITE-CASE BOUND
-- ════════════════════════════════════════════════

/-- Finite bound: ∃ B ≥ 1, ∀ n < N₀, |S₃_at n| ≤ B.
    By induction, the max of finitely many bounded values exists. -/
private lemma finite_s3_bound (N₀ : ℕ) :
    ∃ B : ℝ, B ≥ 1 ∧ ∀ n : ℕ, n < N₀ → |S₃_at n| ≤ B := by
  induction N₀ with
  | zero => exact ⟨1, le_refl _, fun _ hn => absurd hn (by omega)⟩
  | succ m ih =>
    obtain ⟨B₀, hB₀_ge, hB₀⟩ := ih
    refine ⟨max B₀ (|S₃_at m| + 1), ?_, fun n hn => ?_⟩
    · exact le_max_of_le_left hB₀_ge
    · rcases Nat.lt_succ_iff_lt_or_eq.mp hn with h | h
      · exact le_trans (hB₀ n h) (le_max_left _ _)
      · subst h; linarith [le_max_right B₀ (|S₃_at n| + 1)]

-- ════════════════════════════════════════════════
-- §2. BASE CASE: |S₃_at 2| is finite (trivially)
-- ════════════════════════════════════════════════

/-- |S₃_at 2| is a specific real number, hence bounded by itself + 1. -/
private lemma s3_at_two_finite : |S₃_at 2| < |S₃_at 2| + 1 := lt_add_one _

-- ════════════════════════════════════════════════
-- §3. THE UNIFORM BOUND (MAIN THEOREM)
-- ════════════════════════════════════════════════

/-- **THE ABEL BYPASS**: ∃ B ≥ 1, ∀ n, |S₃_at n| ≤ B.

    Proved purely from the Mertens bound |M(x)| ≤ C·x^{3/4}.
    No forward Tauberian theorem needed. No exact limit value.

    PROOF SKETCH:
    1. boundary_vanishes_nat_logsq gives M₁ where Abel boundary < 1
    2. For n ≥ max 3 M₁: |S₃_at n| ≤ |S₃_at 2| + boundary(<1) + interior(=K)
    3. For n < max 3 M₁: finite_s3_bound gives the max
    4. Universal bound = max of both

    STATUS: 0 sorry. ZERO AXIOM. -/
theorem s3_uniform_bound_from_mertens
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4)) :
    ∃ B : ℝ, B ≥ 1 ∧ ∀ n : ℕ, |S₃_at n| ≤ B := by
  -- Step 1: Get M₁ such that Abel boundary < 1 for M ≥ M₁
  obtain ⟨M₁, hM₁⟩ := boundary_vanishes_nat_logsq 2 (by omega) C_m hC 1 one_pos
  -- The interior constant from finite_abel_s3_diff with N=2
  set K_int := C_m * (8 * (Real.log (2 : ℝ)) ^ 2 + 96 * Real.log (2 : ℝ) + 496) *
    (2 : ℝ) ^ (-(1:ℝ)/4) with hK_int_def
  have hK_int_nn : 0 ≤ K_int := by
    apply mul_nonneg
    · apply mul_nonneg hC.le
      have := Real.log_nonneg (by norm_num : (1:ℝ) ≤ 2)
      nlinarith [sq_nonneg (Real.log (2:ℝ))]
    · positivity
  set N₀ := max 3 M₁ with hN₀_def
  -- Step 2: Bound for large n (n ≥ N₀)
  -- For these n: |S₃_at n - S₃_at 2| ≤ Abel bound = boundary + interior
  -- boundary < 1 (from M₁), interior = K_int
  -- So |S₃_at n| ≤ |S₃_at 2| + 1 + K_int
  have h_large : ∀ n : ℕ, N₀ ≤ n → |S₃_at n| ≤ |S₃_at 2| + 1 + K_int := by
    intro n hn
    have hn3 : 3 ≤ n := le_trans (le_max_left _ _) hn
    have hnM1 : M₁ ≤ n := le_trans (le_max_right _ _) hn
    -- Triangle inequality: |S₃_at n| ≤ |S₃_at 2| + |S₃_at n - S₃_at 2|
    have h_tri : |S₃_at n| ≤ |S₃_at 2| + |S₃_at n - S₃_at 2| := by
      have h := abs_sub_abs_le_abs_sub (S₃_at n) (S₃_at 2)
      -- h : |S₃_at n| - |S₃_at 2| ≤ |S₃_at n - S₃_at 2|
      linarith
    -- Abel summation bound
    have hAbel := finite_abel_s3_diff C_m hC hMertens 2 n (le_refl _) (by omega : 2 + 1 ≤ n)
    -- Boundary < 1
    have hBdry := hM₁ n hnM1
    -- Assemble: |S₃_at n - S₃_at 2| < 1 + K_int
    have h_diff : |S₃_at n - S₃_at 2| < 1 + K_int := by linarith
    -- Combine with triangle
    linarith
  -- Step 3: Bound for small n (n < N₀)
  obtain ⟨B_fin, hB_fin_ge, h_small⟩ := finite_s3_bound N₀
  -- Step 4: Universal bound = max of both
  set B := max B_fin (|S₃_at 2| + 1 + K_int + 1) with hB_def
  refine ⟨B, le_max_of_le_left hB_fin_ge, fun n => ?_⟩
  by_cases hn : N₀ ≤ n
  · -- Large case
    have := h_large n hn
    have := le_max_right B_fin (|S₃_at 2| + 1 + K_int + 1)
    linarith
  · -- Small case
    push Not at hn
    exact le_trans (h_small n hn) (le_max_left _ _)

end
