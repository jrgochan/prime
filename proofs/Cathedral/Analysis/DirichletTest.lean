/-
  Cathedral/Analysis/DirichletTest.lean

  ## THE DIRICHLET TEST FOR SERIES CONVERGENCE

  Infrastructure for proving convergence of Σ aₙ·bₙ when (aₙ) has
  bounded partial sums and (bₙ) decreases to 0.

  ### Includes:
  - Abel summation by parts (discrete integration by parts)
  - Bounded × tends-to-zero → tends-to-zero
  - Telescoping sum for antitone sequences
  - Absolute convergence of the Abel transform

  NOTE: The Abel summation proof was originally proved in
  Cathedral/Archive/HighFrequencyTrap/MellinBridge/AbelSummation.lean
  (zero sorry, zero axiom). It is inlined here since the Archive
  is not part of the main Cathedral build target.

  Created: April 25, 2026
  Status: COMPLETE — 6 theorems proved, 0 sorry, 0 axiom
-/

import Cathedral.Defs
import Mathlib.Analysis.SpecificLimits.Basic

noncomputable section
open Filter Finset

namespace Cathedral.Analysis.DirichletTest

-- ════════════════════════════════════════════════
-- §1. ABEL SUMMATION (from Archive, zero sorry)
-- ════════════════════════════════════════════════

/-- The partial sum A(k) = Σ_{j=0}^{k-1} a(j). -/
def partialSum₀ (a : ℕ → ℝ) (k : ℕ) : ℝ :=
  ∑ j ∈ Finset.range k, a j

/-- **Abel Summation by Parts** (discrete, 0-indexed):
    Σ_{m=0}^{n-1} a(m)·b(m)
      = partialSum₀(a,n)·b(n) - Σ_{m=0}^{n-1} partialSum₀(a,m+1)·(b(m+1)-b(m))

    This is Σ f·Δg = [f·g] - Σ Δf·g (discrete IBP). -/
theorem abel_summation_range (a b : ℕ → ℝ) (n : ℕ) :
    ∑ m ∈ Finset.range n, a m * b m =
    partialSum₀ a n * b n -
    ∑ m ∈ Finset.range n, partialSum₀ a (m + 1) * (b (m + 1) - b m) := by
  unfold partialSum₀
  induction n with
  | zero => simp
  | succ k ih =>
    simp only [Finset.sum_range_succ]
    rw [ih]
    simp only [Finset.sum_range_succ]
    ring

-- ════════════════════════════════════════════════
-- §2. HELPER LEMMAS (all proved, zero sorry)
-- ════════════════════════════════════════════════

/-- **BOUNDED × TENDS-TO-ZERO**: If |f(n)| ≤ C for all n and g(n) → 0,
    then f(n) * g(n) → 0. -/
theorem bounded_mul_tendsto_zero (f g : ℕ → ℝ) (C : ℝ)
    (hf : ∀ n, |f n| ≤ C)
    (hg : Tendsto g atTop (nhds 0)) :
    Tendsto (fun n => f n * g n) atTop (nhds 0) := by
  have hC_nn : 0 ≤ C := le_trans (abs_nonneg (f 0)) (hf 0)
  rw [Metric.tendsto_atTop] at hg ⊢
  intro ε hε
  obtain ⟨N, hN⟩ := hg (ε / (C + 1)) (div_pos hε (by linarith))
  refine ⟨N, fun n hn => ?_⟩
  simp only [dist_zero_right, Real.norm_eq_abs] at hN ⊢
  -- When C = 0, f = 0 so the product is 0
  by_cases hC_pos : C = 0
  · simp only [hC_pos] at hf
    have : f n = 0 := by
      have h1 := abs_nonneg (f n)
      have h2 := hf n
      exact abs_eq_zero.mp (le_antisymm h2 h1)
    rw [this, zero_mul, abs_zero]; exact hε
  · have hCp : 0 < C := lt_of_le_of_ne hC_nn (Ne.symm hC_pos)
    calc |f n * g n| = |f n| * |g n| := abs_mul (f n) (g n)
      _ ≤ C * |g n| := by nlinarith [hf n, abs_nonneg (g n)]
      _ < C * (ε / (C + 1)) := by nlinarith [hN n hn, abs_nonneg (g n)]
      _ ≤ ε := by
          have hC1 : (0:ℝ) < C + 1 := by linarith
          rw [mul_div_assoc' C ε (C + 1), div_le_iff₀ hC1]
          nlinarith

/-- The differences b(m) - b(m+1) are nonneg for antitone b. -/
theorem antitone_diff_nonneg (b : ℕ → ℝ) (hb_anti : Antitone b) (m : ℕ) :
    0 ≤ b m - b (m + 1) :=
  sub_nonneg.mpr (hb_anti (Nat.le_succ m))

/-- **MONOTONE DECREASING TELESCOPE SUM**:
    Σ_{m=0}^{n-1} (b(m) - b(m+1)) = b(0) - b(n). -/
theorem telescope_antitone_sum (b : ℕ → ℝ) (n : ℕ) :
    ∑ m ∈ Finset.range n, (b m - b (m + 1)) = b 0 - b n := by
  induction n with
  | zero => simp
  | succ k ih => rw [Finset.sum_range_succ, ih]; ring

/-- **ABSOLUTE CONVERGENCE OF ABEL TRANSFORM**:
    If |S(m)| ≤ C and b is antitone nonneg,
    then |Σ S(m)*(b(m)-b(m+1))| ≤ C · b(0) for all partial sums. -/
theorem abel_transform_abs_bound (S : ℕ → ℝ) (b : ℕ → ℝ) (C : ℝ)
    (hS : ∀ m, |S m| ≤ C)
    (hb_nn : ∀ m, 0 ≤ b m)
    (hb_anti : Antitone b) :
    ∀ n, ∑ m ∈ Finset.range n, |S m * (b m - b (m + 1))| ≤ C * b 0 := by
  intro n
  calc ∑ m ∈ Finset.range n, |S m * (b m - b (m + 1))|
      = ∑ m ∈ Finset.range n, (|S m| * (b m - b (m + 1))) := by
        congr 1; ext m
        rw [abs_mul, abs_of_nonneg (antitone_diff_nonneg b hb_anti m)]
    _ ≤ ∑ m ∈ Finset.range n, (C * (b m - b (m + 1))) := by
        apply Finset.sum_le_sum; intro m _
        exact mul_le_mul_of_nonneg_right (hS m) (antitone_diff_nonneg b hb_anti m)
    _ = C * ∑ m ∈ Finset.range n, (b m - b (m + 1)) := by rw [Finset.mul_sum]
    _ = C * (b 0 - b n) := by rw [telescope_antitone_sum]
    _ ≤ C * b 0 := by nlinarith [hb_nn n, le_trans (abs_nonneg (S 0)) (hS 0)]

-- ════════════════════════════════════════════════
-- §3. THE DIRICHLET TEST
-- ════════════════════════════════════════════════

/-- **DIRICHLET TEST**: If (aₙ) has bounded partial sums and (bₙ)
    is nonneg, antitone, and tends to 0, then Σ aₙ·bₙ converges.

    Proof: Abel summation + monotone bounded convergence + bounded×zero. -/
theorem dirichlet_test (a b : ℕ → ℝ) (C : ℝ)
    (hC : ∀ n, |partialSum₀ a n| ≤ C)
    (hb_nn : ∀ n, 0 ≤ b n)
    (hb_antitone : Antitone b)
    (hb_tendsto : Tendsto b atTop (nhds 0)) :
    ∃ L : ℝ, Tendsto (fun n => ∑ m ∈ Finset.range n, a m * b m) atTop (nhds L) := by
  -- Step 1: Abel summation rewrites each partial sum
  -- Σ_{m<n} a(m)*b(m) = S(n)*b(n) - Σ_{m<n} S(m+1)*(b(m+1)-b(m))
  -- where S(k) = partialSum₀ a k

  -- Step 2: Define the Abel-transformed partial sums (with sign flip for monotonicity)
  -- T(n) = Σ_{m<n} S(m+1)*(b(m) - b(m+1))  (note: b(m) - b(m+1) ≥ 0)
  set T := fun n => ∑ m ∈ Finset.range n,
    partialSum₀ a (m + 1) * (b m - b (m + 1))

  -- Step 3: For the Abel-transformed sum, the tail is small:
  -- |Σ_{m=N}^{n-1} S(m+1)·Δb(m)| ≤ C·(b(N)-b(n)) ≤ C·b(N) → 0
  -- This means the partial sums of the Abel sum form a Cauchy sequence.
  -- Combined with S(n)·b(n) → 0, the original partial sums converge.

  -- For now, use the absolute convergence bound to get convergence.
  -- The key: Σ |S(m+1)|·|Δb(m)| ≤ C·b(0), and the partial sums
  -- of |terms| form a bounded monotone sequence.
  -- So Σ |S(m+1)·Δb(m)| converges, hence Σ S(m+1)·Δb(m) converges absolutely.

  -- Define the absolute sum: U(n) = Σ_{m<n} |S(m+1)·Δb(m)|
  set U := fun n => ∑ m ∈ Finset.range n,
    |partialSum₀ a (m + 1) * (b m - b (m + 1))|

  have hU_mono : Monotone U := by
    intro m n hmn
    simp only [U]
    exact Finset.sum_le_sum_of_subset_of_nonneg (Finset.range_mono hmn)
      (fun k _ _ => abs_nonneg _)

  have hU_bdd : BddAbove (Set.range U) := by
    use C * b 0
    intro y hy
    obtain ⟨n, rfl⟩ := hy
    exact abel_transform_abs_bound (fun m => partialSum₀ a (m + 1)) b C
      (fun m => hC (m + 1)) hb_nn hb_antitone n

  -- U converges by monotone bounded convergence
  obtain ⟨L_U, hL_U⟩ : ∃ L, Tendsto U atTop (nhds L) :=
    ⟨iSup U, tendsto_atTop_ciSup hU_mono hU_bdd⟩

  -- The Abel-transformed sum T has absolutely convergent partial sums,
  -- so T is Cauchy. Tail bound: for N ≤ n, N ≤ m:
  -- |T(n) - T(m)| ≤ Σ_{k=min(m,n)}^{max(m,n)-1} |term_k| ≤ L_U - U(min(m,n))
  -- which tends to 0.
  have hT_cauchy : CauchySeq T := by
    apply cauchySeq_of_le_tendsto_0 (fun N => 2 * (L_U - U N))
    · intro n m N hNn hNm
      -- dist(T n, T m) = |T n - T m| ≤ |T n - T N| + |T m - T N|
      -- Each piece: |T k - T N| = |Σ_{i=N}^{k-1} term_i| ≤ Σ |term_i| = U k - U N ≤ L_U - U N
      have hU_le_LU : ∀ k, U k ≤ L_U := by
        intro k; rw [show L_U = iSup U from by
          have := tendsto_nhds_unique hL_U (tendsto_atTop_ciSup hU_mono hU_bdd)
          exact this]
        exact le_ciSup hU_bdd k
      -- |T k - T N| ≤ U(max(k,N)) - U(min(k,N)) ≤ L_U - U N for N ≤ k
      have hT_diff_le : ∀ k, N ≤ k → dist (T k) (T N) ≤ L_U - U N := by
        intro k hNk
        have hsubset : Finset.range N ⊆ Finset.range k := Finset.range_mono hNk
        simp only [dist_eq_norm, Real.norm_eq_abs, T]
        rw [show (∑ i ∈ Finset.range k, partialSum₀ a (i + 1) * (b i - b (i + 1))) -
              (∑ i ∈ Finset.range N, partialSum₀ a (i + 1) * (b i - b (i + 1))) =
              ∑ i ∈ (Finset.range k \ Finset.range N), partialSum₀ a (i + 1) * (b i - b (i + 1))
            from by linarith [Finset.sum_sdiff hsubset (f := fun i =>
              partialSum₀ a (i + 1) * (b i - b (i + 1)))]]
        have h_abs : |∑ i ∈ (Finset.range k \ Finset.range N),
            partialSum₀ a (i + 1) * (b i - b (i + 1))| ≤
            ∑ i ∈ (Finset.range k \ Finset.range N),
            |partialSum₀ a (i + 1) * (b i - b (i + 1))| :=
          Finset.abs_sum_le_sum_abs _ _
        have h_sdiff : ∑ i ∈ (Finset.range k \ Finset.range N),
            |partialSum₀ a (i + 1) * (b i - b (i + 1))| = U k - U N := by
          simp only [U]
          linarith [Finset.sum_sdiff hsubset (f := fun i =>
            |partialSum₀ a (i + 1) * (b i - b (i + 1))|)]
        linarith [hU_le_LU k]
      calc dist (T n) (T m) ≤ dist (T n) (T N) + dist (T N) (T m) := dist_triangle _ _ _
        _ = dist (T n) (T N) + dist (T m) (T N) := by rw [dist_comm (T N) (T m)]
        _ ≤ (L_U - U N) + (L_U - U N) := add_le_add (hT_diff_le n hNn) (hT_diff_le m hNm)
        _ = 2 * (L_U - U N) := by ring
    · have h1 : Tendsto (fun N => L_U - U N) atTop (nhds (L_U - L_U)) :=
        tendsto_const_nhds.sub hL_U
      simp only [sub_self] at h1
      have h2 : Tendsto (fun N => 2 * (L_U - U N)) atTop (nhds (2 * 0)) :=
        tendsto_const_nhds.mul h1
      simp only [mul_zero] at h2
      exact h2

  -- T converges since ℝ is complete
  have ⟨L_T, hL_T⟩ := cauchySeq_tendsto_of_complete hT_cauchy

  -- Step 6: S(n)*b(n) → 0 by bounded_mul_tendsto_zero
  have hSb_zero : Tendsto (fun n => partialSum₀ a n * b n) atTop (nhds 0) :=
    bounded_mul_tendsto_zero (partialSum₀ a) b C hC hb_tendsto

  -- Step 7: By Abel summation, Σ a*b = S(n)*b(n) + T(n)
  have hAbel : ∀ n, ∑ m ∈ Finset.range n, a m * b m =
      partialSum₀ a n * b n + T n := by
    intro n
    rw [abel_summation_range a b n]
    simp only [T]
    rw [show (fun m => partialSum₀ a (m + 1) * (b (m + 1) - b m)) =
        (fun m => -(partialSum₀ a (m + 1) * (b m - b (m + 1)))) from by ext m; ring]
    rw [Finset.sum_neg_distrib]; ring

  -- Step 8: The partial sums converge to 0 + L_T = L_T
  refine ⟨L_T, ?_⟩
  have : Tendsto (fun n => partialSum₀ a n * b n + T n) atTop (nhds (0 + L_T)) :=
    hSb_zero.add hL_T
  simp only [zero_add] at this
  exact this.congr (fun n => (hAbel n).symm)

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- PROVED (zero sorry, zero axiom):
--   ✅ abel_summation_range           — Discrete Abel summation (0-indexed)
--   ✅ bounded_mul_tendsto_zero       — |f|≤C, g→0 ⟹ fg→0
--   ✅ antitone_diff_nonneg           — b antitone ⟹ Δb ≥ 0
--   ✅ telescope_antitone_sum         — Σ Δb = b(0) - b(n)
--   ✅ abel_transform_abs_bound       — |Σ S·Δb| ≤ C·b(0)
--   ✅ dirichlet_test                 — THE DIRICHLET TEST (PROVED!)
--
-- Proof architecture:
--   Abel summation → absolute convergence (monotone bounded) →
--   Cauchy sequence (via sdiff bounds) → convergent (ℝ complete) →
--   Dirichlet test (Abel + bounded×zero + convergent sum)

end Cathedral.Analysis.DirichletTest

