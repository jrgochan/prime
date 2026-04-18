/-
  Cathedral/Assembly/AbelEngine.lean

  ## THE ABEL ENGINE — Generic PNT Extraction Tools

  Converts Filter.Tendsto limits into quantitative bounds.
  The key bridge between PNT axioms (eventual convergence)
  and the FinalDragon (uniform bounds for all N ≥ 10).

  Created April 18, 2026 — The Abel Engine.
-/

import Mathlib.Analysis.SpecificLimits.Normed
import Mathlib.Analysis.SpecialFunctions.Log.Basic

noncomputable section
open Real Finset

-- ════════════════════════════════════════════════
-- §1. FILTER EXTRACTION
-- ════════════════════════════════════════════════

/-- From Filter.Tendsto, extract a pointwise bound. -/
lemma tendsto_extract_bound {f : ℕ → ℝ} {L : ℝ} {ε : ℝ} (hε : 0 < ε)
    (hf : Filter.Tendsto f Filter.atTop (nhds L)) :
    ∃ N₀ : ℕ, ∀ M : ℕ, N₀ ≤ M → |f M - L| ≤ ε := by
  rw [Metric.tendsto_atTop] at hf
  obtain ⟨N₀, hN₀⟩ := hf ε hε
  exact ⟨N₀, fun M hM => le_of_lt (by simpa [Real.dist_eq] using hN₀ M hM)⟩

/-- A universal bound: ∃ B ≥ 1, ∀ n, |f(n) - L| ≤ B. -/
lemma tendsto_universal_bound {f : ℕ → ℝ} {L : ℝ}
    (hf : Filter.Tendsto f Filter.atTop (nhds L)) :
    ∃ B : ℝ, B ≥ 1 ∧ ∀ n : ℕ, |f n - L| ≤ B := by
  obtain ⟨N₀, hN₀⟩ := tendsto_extract_bound one_pos hf
  suffices h : ∃ B : ℝ, B ≥ 1 ∧ ∀ n, n < N₀ → |f n - L| ≤ B by
    obtain ⟨B, hB1, hB⟩ := h
    exact ⟨B, hB1, fun n => by
      by_cases hn : n < N₀
      · exact hB n hn
      · linarith [hN₀ n (by omega)]⟩
  clear hN₀; induction N₀ with
  | zero => exact ⟨1, le_refl _, fun _ hn => absurd hn (by omega)⟩
  | succ m ih =>
    obtain ⟨B₀, hB₀_ge, hB₀⟩ := ih
    refine ⟨max B₀ (|f m - L| + 1), ?_, fun n hn => ?_⟩
    · simp only [ge_iff_le, le_max_iff]; left; exact hB₀_ge
    · rcases Nat.lt_succ_iff_lt_or_eq.mp hn with h | h
      · exact le_trans (hB₀ n h) (le_max_left _ _)
      · subst h; linarith [le_max_right B₀ (|f n - L| + 1)]

-- ════════════════════════════════════════════════
-- §2. LOG SHIFT BOUND
-- ════════════════════════════════════════════════

/-- For N ≥ 10 (as ℕ): log(N) ≤ 2 · log(N-1).
    Proof: For N ≥ 3 (Nat), (N-1)*(N-1) ≥ N, so N ≤ (N-1)^2. -/
lemma log_shift_bound {N : ℕ} (hN : 10 ≤ N) :
    Real.log (N : ℝ) ≤ 2 * Real.log ((N - 1 : ℕ) : ℝ) := by
  have hNm1_pos : (0 : ℝ) < ((N - 1 : ℕ) : ℝ) := by
    exact_mod_cast show 0 < N - 1 by omega
  -- N ≤ (N-1)*(N-1) for N ≥ 3 (over ℕ)
  have hN_sq : (N : ℕ) ≤ (N - 1) * (N - 1) := by
    have hge : N - 1 ≥ 9 := by omega
    -- (N-1) ≥ 9, so (N-1)*(N-1) ≥ 9*(N-1) = 9N-9 ≥ N for N ≥ 10
    calc N ≤ 9 * (N - 1) := by omega
      _ ≤ (N - 1) * (N - 1) := Nat.mul_le_mul_right _ hge
  calc Real.log (N : ℝ)
    _ ≤ Real.log (((N - 1 : ℕ) : ℝ) * ((N - 1 : ℕ) : ℝ)) := by
        apply Real.log_le_log (by positivity)
        exact_mod_cast hN_sq
    _ = Real.log ((N - 1 : ℕ) : ℝ) + Real.log ((N - 1 : ℕ) : ℝ) :=
        Real.log_mul (ne_of_gt hNm1_pos) (ne_of_gt hNm1_pos)
    _ = 2 * Real.log ((N - 1 : ℕ) : ℝ) := by ring

/-- Consequence: K/log(N-1) ≤ 2K/log(N) for N ≥ 10 and K > 0. -/
lemma div_log_shift {K : ℝ} {N : ℕ} (hK : 0 < K) (hN : 10 ≤ N) :
    K / Real.log ((N - 1 : ℕ) : ℝ) ≤ 2 * K / Real.log (N : ℝ) := by
  have hlog_N1_pos : 0 < Real.log ((N - 1 : ℕ) : ℝ) :=
    Real.log_pos (by exact_mod_cast show 1 < N - 1 by omega)
  have hlogN_pos : 0 < Real.log (N : ℝ) :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  rw [div_le_div_iff₀ hlog_N1_pos hlogN_pos]
  nlinarith [log_shift_bound hN]

-- ════════════════════════════════════════════════
-- §3. INDEX BRIDGE: Fin(N-1) ↔ Icc 1 (N-1)
-- ════════════════════════════════════════════════

/-- Convert Fin(N-1) sum to Finset.Icc sum.
    Σ_{i : Fin(N-1)} f(i.val+1) = Σ_{k ∈ Icc 1 (N-1)} f(k). -/
lemma fin_sum_eq_icc_sum {N : ℕ} (_hN : 2 ≤ N) (f : ℕ → ℝ) :
    ∑ i : Fin (N - 1), f (i.val + 1) =
    ∑ k ∈ Finset.Icc 1 (N - 1), f k := by
  -- Rewrite Icc 1 (N-1) as image of Fin(N-1) under (·+1)
  have h_eq : Finset.Icc 1 (N - 1) = Finset.image (fun i : Fin (N - 1) => i.val + 1) Finset.univ := by
    ext k
    simp only [Finset.mem_Icc, Finset.mem_image, Finset.mem_univ, true_and]
    constructor
    · intro ⟨hk1, hkN⟩
      refine ⟨⟨k - 1, ?_⟩, ?_⟩
      · omega
      · simp; omega
    · rintro ⟨i, rfl⟩
      exact ⟨by omega, by exact Nat.succ_le_of_lt i.isLt⟩
  rw [h_eq, Finset.sum_image]
  intro a _ b _ hab
  simp only at hab
  exact Fin.ext (by omega)

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- Tools provided:
--   tendsto_extract_bound:    Filter.Tendsto → ∃ N₀, ∀ M ≥ N₀, |f M - L| ≤ ε
--   tendsto_universal_bound:  Filter.Tendsto → ∃ B ≥ 1, ∀ n, |f(n)-L| ≤ B
--   log_shift_bound:          log(N) ≤ 2·log(N-1) for N ≥ 10
--   div_log_shift:            K/log(N-1) ≤ 2K/log(N) for N ≥ 10
--   fin_sum_eq_icc_sum:       Fin(N-1) ↔ Icc 1 (N-1) index bridge
--
-- NO Cathedral imports. Pure Mathlib analysis.

end
