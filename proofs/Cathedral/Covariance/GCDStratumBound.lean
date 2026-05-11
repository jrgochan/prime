/-
  Cathedral/Covariance/GCDStratumBound.lean

  ## Per-Stratum Growth Bounds for the GCD Partition

  PHYSICS: Energy bounds for each arithmetic locality in the Möbius gas.
  MATH: Bounding |U_d(N)| individually.

  Main result: each GCD stratum is bounded by:
    |U_d(N)| ≤ (1/2) · (N-1)²

  This follows from the pointwise bound |μ(j)μ(k)G(j,k)| ≤ 1/2
  (since |μ| ≤ 1 from Mathlib's `abs_moebius_le_one` and G < 1/2
  from `vasyuninGram_lt_half`).

  Created: May 10, 2026
  Status: Layer 4 — per-stratum bounds. PROVED.
-/

import Cathedral.Vasyunin.Augmented.DiagBound
import Cathedral.Covariance.GCDPartition
import Cathedral.Covariance.EulerProduct
import Mathlib.Data.Real.Basic

noncomputable section
open Real Finset ArithmeticFunction

namespace Cathedral.Covariance.GCDStratumBound

-- ════════════════════════════════════════════════
-- §1. POINTWISE BOUND ON GCD-FILTERED TERMS
-- ════════════════════════════════════════════════

/-- |μ(n)| ≤ 1 as a real number, wrapping Mathlib's `abs_moebius_le_one`. -/
private lemma abs_moebius_cast_le_one (n : ℕ) :
    |((moebius n : ℤ) : ℝ)| ≤ 1 := by
  have h : |moebius n| ≤ 1 := abs_moebius_le_one
  exact_mod_cast h

/-- Each term in U_d is bounded by 1/2 in absolute value.

    Since |μ(j)| ≤ 1, |μ(k)| ≤ 1, and 0 ≤ G(j,k) < 1/2:
      |μ(j)μ(k)G(j,k)| ≤ 1 · 1 · 1/2 = 1/2 -/
theorem gcd_stratum_term_bound (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    |((moebius j : ℤ) : ℝ) * ((moebius k : ℤ) : ℝ) *
      Cathedral.Vasyunin.vasyuninGramEntry j k| ≤ 1 / 2 := by
  have h_nonneg := Cathedral.Vasyunin.vasyuninGram_nonneg j k hj hk
  have h_lt := Cathedral.Vasyunin.vasyuninGram_lt_half j k hj hk
  rw [abs_mul, abs_mul]
  calc |((moebius j : ℤ) : ℝ)| * |((moebius k : ℤ) : ℝ)| *
        |Cathedral.Vasyunin.vasyuninGramEntry j k|
      ≤ 1 * 1 * (1 / 2) := by
        apply mul_le_mul
        · exact mul_le_mul (abs_moebius_cast_le_one j) (abs_moebius_cast_le_one k)
            (abs_nonneg _) (by norm_num)
        · rw [abs_of_nonneg h_nonneg]; exact le_of_lt h_lt
        · exact abs_nonneg _
        · norm_num
    _ = 1 / 2 := by ring

-- ════════════════════════════════════════════════
-- §2. THE MAIN PER-STRATUM BOUND
-- ════════════════════════════════════════════════

/-- **THEOREM (Per-Stratum Bound for U_d)**: The GCD-stratified untapered sum
    is bounded by half the square of the range size.

    |U_d(N)| ≤ (1/2) · (N-1)²

    This follows from:
    - Each pair (j,k) contributes at most 1/2 to |U_d|
    - There are at most (N-1)² pairs in the double sum
    - The indicator function [gcd(j,k) = d] only makes this smaller

    This is a crude but FULLY PROVED bound. The actual behavior from
    GPU experiments shows |U_d| ≈ O(1) for fixed d, much smaller. -/
theorem untaperedSum_gcd_bound (N d : ℕ) (hN : 2 ≤ N) :
    |GCDPartition.untaperedSum_gcd N d| ≤ (1 / 2) * ((N - 1 : ℕ) : ℝ) ^ 2 := by
  unfold GCDPartition.untaperedSum_gcd
  calc |∑ j ∈ Icc 1 (N - 1), ∑ k ∈ Icc 1 (N - 1),
        if Nat.gcd j k = d then
          (moebius j : ℝ) * (moebius k : ℝ) *
          Cathedral.Vasyunin.vasyuninGramEntry j k
        else 0|
      ≤ ∑ j ∈ Icc 1 (N - 1), |∑ k ∈ Icc 1 (N - 1),
        if Nat.gcd j k = d then
          (moebius j : ℝ) * (moebius k : ℝ) *
          Cathedral.Vasyunin.vasyuninGramEntry j k
        else 0| := Finset.abs_sum_le_sum_abs _ _
    _ ≤ ∑ j ∈ Icc 1 (N - 1), ∑ k ∈ Icc 1 (N - 1),
        |if Nat.gcd j k = d then
          (moebius j : ℝ) * (moebius k : ℝ) *
          Cathedral.Vasyunin.vasyuninGramEntry j k
        else 0| := by
          apply Finset.sum_le_sum; intro j _
          exact Finset.abs_sum_le_sum_abs _ _
    _ ≤ ∑ _j ∈ Icc 1 (N - 1), ∑ _k ∈ Icc 1 (N - 1), (1 / 2 : ℝ) := by
        apply Finset.sum_le_sum; intro j hj
        apply Finset.sum_le_sum; intro k hk
        simp only [mem_Icc] at hj hk
        split_ifs with _h
        · exact gcd_stratum_term_bound j k (by omega) (by omega)
        · simp
    _ = (1 / 2) * ((N - 1 : ℕ) : ℝ) ^ 2 := by
        simp only [Finset.sum_const, Nat.card_Icc, nsmul_eq_mul]
        have h : (N - 1 + 1 - 1 : ℕ) = N - 1 := by omega
        rw [show ((N - 1 + 1 - 1 : ℕ) : ℝ) = ((N - 1 : ℕ) : ℝ) from by exact_mod_cast h]
        ring

/-- **THEOREM (Per-Stratum Bound for L_d)**: Similarly for the linear taper stratum.

    |L_d(N)| ≤ (1/2) · ln(N) · (N-1)²

    Each term gains an extra ln(j) ≤ ln(N) factor. -/
theorem linearTaperSum_gcd_bound (N d : ℕ) (hN : 3 ≤ N) :
    |GCDPartition.linearTaperSum_gcd N d| ≤
      (1 / 2) * Real.log (N : ℝ) * ((N - 1 : ℕ) : ℝ) ^ 2 := by
  have hLN : 0 < Real.log (N : ℝ) :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  -- Factor: |L_d| ≤ ln(N) · |U_d| ≤ ln(N) · (1/2) · (N-1)²
  -- More precisely: each term in L_d has an extra ln(j) ≤ ln(N)
  -- Bound via triangle inequality + term-by-term
  unfold GCDPartition.linearTaperSum_gcd
  have h_bound : ∀ j ∈ Icc 1 (N - 1), ∀ k ∈ Icc 1 (N - 1),
      |if Nat.gcd j k = d then
          (moebius j : ℝ) * (moebius k : ℝ) *
          Real.log (j : ℝ) * Cathedral.Vasyunin.vasyuninGramEntry j k
        else 0| ≤ 1 / 2 * Real.log (N : ℝ) := by
    intro j hj k hk
    simp only [mem_Icc] at hj hk
    split_ifs with _h
    · rw [show (moebius j : ℝ) * (moebius k : ℝ) * Real.log ↑j *
              Cathedral.Vasyunin.vasyuninGramEntry j k =
            ((moebius j : ℝ) * (moebius k : ℝ) *
              Cathedral.Vasyunin.vasyuninGramEntry j k) * Real.log ↑j from by ring]
      rw [abs_mul]
      exact mul_le_mul
        (gcd_stratum_term_bound j k (by omega) (by omega))
        (by rw [abs_of_nonneg (Real.log_nonneg (by exact_mod_cast show 1 ≤ j by omega))]
            exact Real.log_le_log (by exact_mod_cast show 0 < j by omega)
              (by exact_mod_cast show j ≤ N by omega))
        (abs_nonneg _)
        (by linarith)
    · simp; linarith
  -- Sum the bounds: |Σ Σ f| ≤ Σ Σ |f| ≤ (N-1)² · (1/2 · ln N)
  calc |∑ j ∈ Icc 1 (N - 1), ∑ k ∈ Icc 1 (N - 1), _|
      ≤ ∑ j ∈ Icc 1 (N - 1), ∑ k ∈ Icc 1 (N - 1), (1 / 2 * Real.log (N : ℝ)) :=
        (Finset.abs_sum_le_sum_abs _ _).trans
          (Finset.sum_le_sum fun j hj =>
            (Finset.abs_sum_le_sum_abs _ _).trans
              (Finset.sum_le_sum fun k hk => h_bound j hj k hk))
    _ = (1 / 2) * Real.log (N : ℝ) * ((N - 1 : ℕ) : ℝ) ^ 2 := by
        have hcard : (Icc 1 (N - 1)).card = N - 1 := by simp [Nat.card_Icc]
        simp_rw [Finset.sum_const, hcard, nsmul_eq_mul]
        ring

-- ════════════════════════════════════════════════
-- §3. COMBINING WITH THE PARTITION
-- ════════════════════════════════════════════════

/-- **THEOREM**: The global bound on U recovers from the per-stratum bounds.

    |U(N)| = |Σ_d U_d(N)| ≤ Σ_d |U_d(N)| ≤ (N-1) · (1/2) · (N-1)² = (1/2)(N-1)³

    This is weaker than what we'd get by bounding U directly (which gives
    |U| ≤ (1/2)·(N-1)²), but it demonstrates the partition architecture:
    local stratum bounds → global bound via triangle inequality. -/
theorem untaperedSum_from_strata (N : ℕ) (hN : 2 ≤ N) :
    |TaperDecomposition.untaperedSum N| ≤
      (1 / 2) * ((N - 1 : ℕ) : ℝ) ^ 3 := by
  rw [GCDPartition.untaperedSum_partition N hN]
  calc |∑ d ∈ Icc 1 (N - 1), GCDPartition.untaperedSum_gcd N d|
      ≤ ∑ d ∈ Icc 1 (N - 1), |GCDPartition.untaperedSum_gcd N d| :=
        Finset.abs_sum_le_sum_abs _ _
    _ ≤ ∑ _d ∈ Icc 1 (N - 1), (1 / 2 * ((N - 1 : ℕ) : ℝ) ^ 2) :=
        Finset.sum_le_sum fun d _ => untaperedSum_gcd_bound N d hN
    _ = (1 / 2) * ((N - 1 : ℕ) : ℝ) ^ 3 := by
        simp only [Finset.sum_const, Nat.card_Icc, nsmul_eq_mul]
        have h : (N - 1 + 1 - 1 : ℕ) = N - 1 := by omega
        rw [show ((N - 1 + 1 - 1 : ℕ) : ℝ) = ((N - 1 : ℕ) : ℝ) from by exact_mod_cast h]
        ring

-- ════════════════════════════════════════════════
-- §4. AUDIT
-- ════════════════════════════════════════════════

/-!
## Audit

### Sorry: 0
### Axioms: 0

### Architecture:
```
  vasyuninGram_lt_half ─────────────┐
  vasyuninGram_nonneg ──────────────┤
  abs_moebius_le_one (Mathlib) ─────┤
                                    ├──→ gcd_stratum_term_bound
                                    │       |μ(j)μ(k)G(j,k)| ≤ 1/2
                                    │
                                    ├──→ untaperedSum_gcd_bound
                                    │       |U_d(N)| ≤ (1/2)·(N-1)²
                                    │
                                    ├──→ linearTaperSum_gcd_bound
                                    │       |L_d(N)| ≤ (1/2)·ln(N)·(N-1)²
                                    │
                                    └──→ untaperedSum_from_strata
                                            |U(N)| ≤ (1/2)·(N-1)³
```

### GPU comparison (N=55,440):
  Proved:  |U_d| ≤ (1/2)·55439² ≈ 1.5 billion
  Actual:  |U_d| ≈ O(1) (GPU data)

The bound is crude but the proof architecture is real:
  pointwise Gram bound → per-term bound → per-stratum bound → global bound

Tighter bounds require cancellation in the Möbius sum, which is
the RH content itself.
-/

end Cathedral.Covariance.GCDStratumBound
