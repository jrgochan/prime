/-
  Cathedral/ZeroAxiom/FejerCesaro.lean

  ## Fejér-Cesàro Summability: Weighted Average of Null Sequences

  **Main theorems** (all 0 sorry):
  1. `weighted_cesaro_tendsto_zero` -- general weighted Cesàro
  2. `fejer_weighted_sum_tendsto_zero` -- Fejér-weighted sums -> 0
  3. `harmonic_le_one_add_log` -- H_N ≤ 1 + lnN

  Created: June 2, 2026
-/

import Mathlib.Analysis.SpecialFunctions.Log.Deriv
import Mathlib.Order.Filter.AtTopBot.Archimedean
import Mathlib.Topology.Algebra.Order.LiminfLimsup
import Mathlib.Algebra.BigOperators.Field
import Mathlib.Analysis.Complex.ExponentialBounds
import Cathedral.ZeroAxiom.AbelEngine

set_option maxHeartbeats 1200000

noncomputable section
open Real Finset Filter BigOperators

namespace Cathedral.ZeroAxiom.FejerCesaro

-- =============================================
-- S1. WEIGHTED CESARO MEAN (0 sorry)
-- =============================================

/-- **THEOREM**: Weighted Cesàro mean of a null sequence -> 0. (0 sorry) -/
theorem weighted_cesaro_tendsto_zero
    (f : ℕ → ℝ) (hf : Tendsto f atTop (nhds 0))
    (w : ℕ → ℝ) (hw_nonneg : ∀ k, 0 ≤ w k)
    (hW_tend : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N, w k) atTop atTop) :
    Tendsto (fun N =>
      (∑ k ∈ Finset.Icc 1 N, f k * w k) /
      (∑ k ∈ Finset.Icc 1 N, w k))
    atTop (nhds 0) := by
  rw [Metric.tendsto_atTop]
  intro ε hε
  have hε2 : (0:ℝ) < ε / 2 := by linarith
  rw [Metric.tendsto_atTop] at hf
  obtain ⟨K, hK⟩ := hf (ε / 2) hε2
  set C_K := ∑ k ∈ Finset.Icc 1 K, |f k| * w k
  have hC_K_nonneg : 0 ≤ C_K :=
    Finset.sum_nonneg fun k _ => mul_nonneg (abs_nonneg _) (hw_nonneg k)
  have hW_ev := hW_tend.eventually_ge_atTop (2 * C_K / ε + 1)
  rw [Filter.Eventually, Filter.mem_atTop_sets] at hW_ev
  obtain ⟨N₀, hN₀⟩ := hW_ev
  refine ⟨max K N₀, fun N hN => ?_⟩
  have hN_ge_K : K ≤ N := le_trans (le_max_left K N₀) hN
  have hN_ge_N₀ : N₀ ≤ N := le_trans (le_max_right K N₀) hN
  have hW_large : 2 * C_K / ε + 1 ≤ ∑ k ∈ Finset.Icc 1 N, w k := by
    have := hN₀ N hN_ge_N₀
    simp only [Set.mem_setOf_eq] at this; exact this
  have hW_pos : 0 < ∑ k ∈ Finset.Icc 1 N, w k := by
    have h1 : (0:ℝ) < 2 * C_K / ε + 1 := by positivity
    linarith
  rw [dist_zero_right]
  rw [show ‖(∑ k ∈ Finset.Icc 1 N, f k * w k) / ∑ k ∈ Finset.Icc 1 N, w k‖ =
      |(∑ k ∈ Finset.Icc 1 N, f k * w k)| / (∑ k ∈ Finset.Icc 1 N, w k) from by
    rw [Real.norm_eq_abs, abs_div, abs_of_pos hW_pos]]
  have h_split : ∀ (g : ℕ → ℝ),
      ∑ k ∈ Finset.Icc 1 N, g k =
      ∑ k ∈ Finset.Icc 1 K, g k + ∑ k ∈ Finset.Ioc K N, g k := by
    intro g
    have h_union : Finset.Icc 1 N = Finset.Icc 1 K ∪ Finset.Ioc K N := by
      ext x; simp [Finset.mem_Icc, Finset.mem_Ioc, Finset.mem_union]; omega
    have h_disj : Disjoint (Finset.Icc 1 K) (Finset.Ioc K N) := by
      simp [Finset.disjoint_left, Finset.mem_Icc, Finset.mem_Ioc]; omega
    rw [h_union, Finset.sum_union h_disj]
  have h_head : |∑ k ∈ Finset.Icc 1 K, f k * w k| ≤ C_K := by
    calc |∑ k ∈ Finset.Icc 1 K, f k * w k|
        ≤ ∑ k ∈ Finset.Icc 1 K, |f k * w k| := Finset.abs_sum_le_sum_abs _ _
      _ = ∑ k ∈ Finset.Icc 1 K, |f k| * w k := by
          congr 1; ext k; rw [abs_mul, abs_of_nonneg (hw_nonneg k)]
  have h_tail : |∑ k ∈ Finset.Ioc K N, f k * w k| ≤
      (ε / 2) * ∑ k ∈ Finset.Ioc K N, w k := by
    calc |∑ k ∈ Finset.Ioc K N, f k * w k|
        ≤ ∑ k ∈ Finset.Ioc K N, |f k * w k| := Finset.abs_sum_le_sum_abs _ _
      _ = ∑ k ∈ Finset.Ioc K N, |f k| * w k := by
          congr 1; ext k; rw [abs_mul, abs_of_nonneg (hw_nonneg k)]
      _ ≤ ∑ k ∈ Finset.Ioc K N, (ε / 2) * w k := by
          apply Finset.sum_le_sum; intro k hk
          rw [Finset.mem_Ioc] at hk
          have hfk : dist (f k) 0 < ε / 2 := hK k (le_of_lt hk.1)
          rw [Real.dist_eq, sub_zero] at hfk
          exact mul_le_mul_of_nonneg_right (le_of_lt hfk) (hw_nonneg k)
      _ = (ε / 2) * ∑ k ∈ Finset.Ioc K N, w k := by rw [← Finset.mul_sum]
  have h_tail_le_W : ∑ k ∈ Finset.Ioc K N, w k ≤ ∑ k ∈ Finset.Icc 1 N, w k := by
    rw [h_split w]
    linarith [Finset.sum_nonneg (fun k (_ : k ∈ Finset.Icc 1 K) => hw_nonneg k)]
  have h_num : |∑ k ∈ Finset.Icc 1 N, f k * w k| ≤
      C_K + (ε / 2) * ∑ k ∈ Finset.Icc 1 N, w k := by
    rw [h_split (fun k => f k * w k)]
    calc |∑ k ∈ Finset.Icc 1 K, f k * w k + ∑ k ∈ Finset.Ioc K N, f k * w k|
        ≤ |∑ k ∈ Finset.Icc 1 K, f k * w k| + |∑ k ∈ Finset.Ioc K N, f k * w k| :=
          abs_add_le _ _
      _ ≤ C_K + (ε / 2) * ∑ k ∈ Finset.Ioc K N, w k := by linarith [h_head, h_tail]
      _ ≤ C_K + (ε / 2) * ∑ k ∈ Finset.Icc 1 N, w k := by
          linarith [mul_le_mul_of_nonneg_left h_tail_le_W (le_of_lt hε2)]
  set W := ∑ k ∈ Finset.Icc 1 N, w k
  have h_CK_lt : C_K < (ε / 2) * W := by
    have h1 : ε * (2 * C_K / ε + 1) ≤ ε * W :=
      mul_le_mul_of_nonneg_left hW_large (le_of_lt hε)
    have h2 : ε * (2 * C_K / ε + 1) = 2 * C_K + ε := by field_simp
    linarith
  have h_CK_div : C_K / W < ε / 2 := by rwa [div_lt_iff₀ hW_pos]
  calc |∑ k ∈ Finset.Icc 1 N, f k * w k| / W
      ≤ (C_K + (ε / 2) * W) / W := div_le_div_of_nonneg_right h_num hW_pos.le
    _ = C_K / W + ε / 2 := by
        rw [add_div, mul_div_cancel_right₀ (ε / 2) (ne_of_gt hW_pos)]
    _ < ε / 2 + ε / 2 := by linarith
    _ = ε := by ring

-- =============================================
-- S2. HARMONIC NUMBER BOUND (0 sorry)
-- =============================================

/-- `1/(n+1) ≤ ln(n+1) - ln(n)` for n ≥ 1.
    From `ln(s) ≤ s-1` applied to `s = n/(n+1)`. -/
private lemma recip_succ_le_log_diff (n : ℕ) (hn : 1 ≤ n) :
    1 / ((↑n : ℝ) + 1) ≤ Real.log ((↑n : ℝ) + 1) - Real.log (↑n : ℝ) := by
  have hn_pos : (0:ℝ) < (↑n:ℝ) := Nat.cast_pos.mpr (by omega)
  have hn1_pos : (0:ℝ) < (↑n:ℝ) + 1 := by linarith
  have h_bound := Real.log_le_sub_one_of_pos (div_pos hn_pos hn1_pos)
  rw [Real.log_div (ne_of_gt hn_pos) (ne_of_gt hn1_pos)] at h_bound
  have : (↑n : ℝ) / ((↑n : ℝ) + 1) - 1 = -(1 / ((↑n : ℝ) + 1)) := by field_simp; ring
  linarith

/-- **Harmonic bound**: H_N ≤ 1 + ln(N) for N ≥ 1. Proved by induction + telescoping. -/
private lemma harmonic_le_one_add_log (N : ℕ) (hN : 1 ≤ N) :
    ∑ k ∈ Finset.Icc 1 N, 1 / (↑k : ℝ) ≤ 1 + Real.log (↑N : ℝ) := by
  induction N with
  | zero => omega
  | succ n ih =>
    by_cases hn0 : n = 0
    · subst hn0; simp [Finset.Icc_self, Real.log_one]
    · have hn1 : 1 ≤ n := by omega
      have h_split : Finset.Icc 1 (n + 1) = Finset.Icc 1 n ∪ {n + 1} := by
        ext x; simp [Finset.mem_Icc]; omega
      have h_disj : Disjoint (Finset.Icc 1 n) ({n + 1} : Finset ℕ) := by
        simp [Finset.disjoint_right, Finset.mem_Icc]
      rw [h_split, Finset.sum_union h_disj, Finset.sum_singleton]
      have h_ih := ih hn1
      have h_step := recip_succ_le_log_diff n hn1
      have h_cast : (1:ℝ) / ((↑(n + 1) : ℕ) : ℝ) = 1 / ((↑n : ℝ) + 1) := by push_cast; ring
      have h_cast2 : Real.log ((↑(n + 1) : ℕ) : ℝ) = Real.log ((↑n : ℝ) + 1) := by
        congr 1; push_cast; ring
      rw [h_cast, h_cast2]
      linarith

-- =============================================
-- S3. FEJER-WEIGHTED SUM CONVERGENCE
-- =============================================

/-- **THEOREM**: Fejer-weighted sum of a null partial-sum sequence tends to 0.

    If A(N) = sum_{k=1}^N a(k) tends to 0, then:
      sum_{k=1}^N a(k) * (1 - ln(k)/ln(N)) tends to 0

    **Proof**: Abel's summation-by-parts + epsilon-delta argument.
    Uses Abel's boundary vanishing (f(N)=0) and |Delta f| <= 1/(k*lnN).

    **Sorry count**: 1 (harmonic number bound) -/
theorem fejer_weighted_sum_tendsto_zero
    (a : ℕ → ℝ)
    (hA : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N, a k) atTop (nhds 0)) :
    Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, a k * (1 - Real.log (k : ℝ) / Real.log (N : ℝ)))
    atTop (nhds 0) := by
  rw [Metric.tendsto_atTop]
  intro ε hε
  have hε4 : (0:ℝ) < ε / 4 := by linarith
  rw [Metric.tendsto_atTop] at hA
  obtain ⟨K, hK⟩ := hA (ε / 4) hε4
  set A := fun k => ∑ j ∈ Finset.Icc 1 k, a j
  set C_K := ∑ k ∈ Finset.Icc 1 K, |A k| / (k : ℝ)
  have hC_K_nonneg : 0 ≤ C_K :=
    Finset.sum_nonneg fun k _ => div_nonneg (abs_nonneg _) (Nat.cast_nonneg k)
  set N₁ := max (K + 3) (⌈Real.exp (4 * C_K / ε + 1)⌉₊ + 1)
  refine ⟨N₁, fun N hN => ?_⟩
  have hN_ge3 : 3 ≤ N := by
    have := le_trans (le_max_left (K + 3) _) hN; omega
  have hN_ge2 : 2 ≤ N := by omega
  have hN_ge_K : K < N := by
    have := le_trans (le_max_left (K + 3) _) hN; omega
  have hlogN_pos : 0 < Real.log (N:ℝ) :=
    Real.log_pos (by exact_mod_cast (show 1 < N by omega))
  have hlogN_large : 4 * C_K / ε < Real.log (N : ℝ) := by
    have hN_large : ⌈Real.exp (4 * C_K / ε + 1)⌉₊ + 1 ≤ N :=
      le_trans (le_max_right _ _) hN
    have hexp_le : Real.exp (4 * C_K / ε + 1) ≤ (N : ℝ) :=
      calc Real.exp (4 * C_K / ε + 1)
          ≤ ↑(⌈Real.exp (4 * C_K / ε + 1)⌉₊) := Nat.le_ceil _
        _ ≤ ↑(⌈Real.exp (4 * C_K / ε + 1)⌉₊ + 1) := by exact_mod_cast Nat.le_succ _
        _ ≤ (N : ℝ) := by exact_mod_cast hN_large
    calc 4 * C_K / ε < 4 * C_K / ε + 1 := by linarith
      _ ≤ Real.log (Real.exp (4 * C_K / ε + 1)) := by rw [Real.log_exp]
      _ ≤ Real.log (N : ℝ) := Real.log_le_log (Real.exp_pos _) hexp_le
  -- Goal: dist (sum) 0 < ε
  rw [dist_zero_right, Real.norm_eq_abs]
  -- Rewrite sum as fejerWeight form
  have h_rw : ∑ k ∈ Finset.Icc 1 N,
      a k * (1 - Real.log (k : ℝ) / Real.log (N : ℝ)) =
      ∑ k ∈ Finset.Icc 1 N,
      a k * Cathedral.ZeroAxiom.Abel.fejerWeight N k :=
    Finset.sum_congr rfl (fun k _ => rfl)
  rw [h_rw]
  -- Apply Abel abs bound
  have h_abel := Cathedral.ZeroAxiom.Abel.abel_summation_abs_bound
    a (Cathedral.ZeroAxiom.Abel.fejerWeight N) 1 N (by omega)
    (fun k => |A k|)
    (fun k => 1 / ((k : ℝ) * Real.log (N : ℝ)))
    (fun k _ _ => le_refl _)
    (fun k hk1 _ =>
      Cathedral.ZeroAxiom.Abel.fejerWeight_diff_bound N k hN_ge2 hk1)
  -- f(N) = 0
  have hfN : Cathedral.ZeroAxiom.Abel.fejerWeight N N = 0 := by
    unfold Cathedral.ZeroAxiom.Abel.fejerWeight
    simp [div_self (ne_of_gt hlogN_pos)]
  rw [hfN, abs_zero, mul_zero, zero_add] at h_abel
  -- h_abel : |sum| <= S where S = sum_{Ico 1 N} |A(k)| / (k * lnN)
  -- Now bound S by C_K/lnN + eps/2
  -- Then C_K/lnN < eps/4, so total < 3eps/4 < eps.
  --
  -- Head/tail split + harmonic bound to show the Abel remainder is bounded.
  have h_bound : ∑ k ∈ Finset.Ico 1 N,
      |A k| * (1 / ((k : ℝ) * Real.log (N : ℝ))) ≤
      C_K / Real.log (N : ℝ) + ε / 2 := by
    -- Split Ico 1 N = Icc 1 K ∪ Ioc K (N-1)
    have h_split : Finset.Ico 1 N = Finset.Icc 1 K ∪ Finset.Ioc K (N - 1) := by
      ext x; simp [Finset.mem_Ico, Finset.mem_Icc, Finset.mem_Ioc, Finset.mem_union]; omega
    have h_disj : Disjoint (Finset.Icc 1 K) (Finset.Ioc K (N - 1)) := by
      simp [Finset.disjoint_left, Finset.mem_Icc, Finset.mem_Ioc]; omega
    rw [h_split, Finset.sum_union h_disj]
    -- Head: Σ_{k≤K} |A(k)|/(k·lnN) ≤ C_K/lnN
    have h_head : ∑ k ∈ Finset.Icc 1 K,
        |A k| * (1 / ((k : ℝ) * Real.log (N : ℝ))) ≤
        C_K / Real.log (N : ℝ) := by
      have hlnN_ne : Real.log (N : ℝ) ≠ 0 := ne_of_gt hlogN_pos
      rw [show C_K / Real.log (N : ℝ) =
          ∑ k ∈ Finset.Icc 1 K, |A k| / (k : ℝ) / Real.log (N : ℝ) from by
        rw [← Finset.sum_div]]
      apply Finset.sum_le_sum; intro k _
      rw [show |A k| * (1 / ((k : ℝ) * Real.log (N : ℝ))) =
          |A k| / (k : ℝ) / Real.log (N : ℝ) from by ring]
    -- Tail: Σ_{K<k<N} |A(k)|/(k·lnN) ≤ (ε/4)·Σ 1/(k·lnN) ≤ ε/2
    have h_tail : ∑ k ∈ Finset.Ioc K (N - 1),
        |A k| * (1 / ((k : ℝ) * Real.log (N : ℝ))) ≤ ε / 2 := by
      -- Each |A(k)| < ε/4 for k > K
      have h1 : ∑ k ∈ Finset.Ioc K (N - 1),
          |A k| * (1 / ((k : ℝ) * Real.log (N : ℝ))) ≤
          (ε / 4) * ∑ k ∈ Finset.Ioc K (N - 1),
          1 / ((k : ℝ) * Real.log (N : ℝ)) := by
        rw [Finset.mul_sum]
        apply Finset.sum_le_sum; intro k hk
        rw [Finset.mem_Ioc] at hk
        have hk_pos : (0:ℝ) < (k:ℝ) := Nat.cast_pos.mpr (by omega)
        have hklnN_pos : 0 < (k : ℝ) * Real.log (N : ℝ) := mul_pos hk_pos hlogN_pos
        have hAk : dist (A k) 0 < ε / 4 := hK k (by omega)
        rw [Real.dist_eq, sub_zero] at hAk
        exact mul_le_mul_of_nonneg_right (le_of_lt hAk) (by positivity)
      -- Σ 1/(k·lnN) = (1/lnN)·Σ 1/k ≤ (1/lnN)·(1+lnN) ≤ 2
      have h2 : ∑ k ∈ Finset.Ioc K (N - 1),
          1 / ((k : ℝ) * Real.log (N : ℝ)) ≤ 2 := by
        calc ∑ k ∈ Finset.Ioc K (N - 1), 1 / ((k : ℝ) * Real.log (N : ℝ))
            ≤ ∑ k ∈ Finset.Icc 1 N, 1 / ((k : ℝ) * Real.log (N : ℝ)) := by
              apply Finset.sum_le_sum_of_subset_of_nonneg
              · intro x hx; rw [Finset.mem_Ioc] at hx; rw [Finset.mem_Icc]; omega
              · intro k _ _; positivity
          _ = (∑ k ∈ Finset.Icc 1 N, 1 / (k : ℝ)) / Real.log (N : ℝ) := by
              simp_rw [show ∀ k : ℕ, 1 / ((k : ℝ) * Real.log (N : ℝ)) =
                  1 / (k : ℝ) / Real.log (N : ℝ) from fun k => by ring]
              rw [← Finset.sum_div]
          _ ≤ 2 := by
              rw [div_le_iff₀ hlogN_pos]
              -- Goal: Σ 1/k ≤ 2 * lnN
              -- From: H_N ≤ 1 + lnN and lnN ≥ 1 (since N ≥ 3)
              have h_harm := harmonic_le_one_add_log N (by omega)
              have hlogN_ge_1 : 1 ≤ Real.log (↑N : ℝ) := by
                calc (1:ℝ) = Real.log (Real.exp 1) := (Real.log_exp 1).symm
                  _ ≤ Real.log (↑N : ℝ) := by
                      apply Real.log_le_log (Real.exp_pos 1)
                      have : (3:ℝ) ≤ (↑N:ℝ) := by exact_mod_cast hN_ge3
                      linarith [exp_one_lt_three]
              linarith
      linarith [mul_le_mul_of_nonneg_left h2 (le_of_lt hε4)]
    linarith
  have h_CK_small : C_K / Real.log (N : ℝ) < ε / 4 := by
    rw [div_lt_div_iff₀ hlogN_pos (by linarith : (0:ℝ) < 4)]
    have h := mul_lt_mul_of_pos_right hlogN_large hε
    rw [mul_comm (4 * C_K / ε) ε] at h
    rw [show ε * (4 * C_K / ε) = 4 * C_K from by field_simp] at h
    linarith
  linarith

end Cathedral.ZeroAxiom.FejerCesaro

end
