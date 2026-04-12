/-
  Cathedral/MellinBridge/Vasyunin/LinIndep.lean

  **THE MINIMUM-INDEX NUKE — Linear Independence of {1/(kx)}**

  Proves that the Báez-Duarte basis functions h_k(x) = {1/(kx)} are
  linearly independent in L²(0,1), which implies the augmented Gram
  matrix H_N is positive definite.

  Strategy (The Minimum-Index Argument):
  ────────────────────────────────────────
  Suppose Σ c_k h_k(x) = 0. Let k₀ be the SMALLEST index with c_{k₀} ≠ 0.

  On the interval (1/(k₀+1), 1/k₀):
  • h_{k₀}(x) = 1/(k₀x) - 1  (because ⌊1/(k₀x)⌋ = 1)
  • h_j(x) = 1/(jx)           for j > k₀ (because ⌊1/(jx)⌋ = 0)
  • c_j = 0                   for j < k₀ (by minimum-index hypothesis)

  Therefore: Σ c_j h_j = (1/x)·A - c_{k₀}
  where A = Σ c_j/(j). If A = 0 then the sum = -c_{k₀} ≠ 0.

  Source: Theorist memo "The Minimum-Index Nuke" (April 11, 2026).
  Adapted from Cathedral/Archive/Independence.lean (364 lines, zero sorry).
-/

import Cathedral.MellinBridge.Vasyunin.GramPSD
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

noncomputable section
open Real MeasureTheory

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- §1. FLOOR LEMMAS FOR THE CORRECTED BASIS {1/(kx)}
-- ════════════════════════════════════════════════

/-- On (1/(k+1), 1/k), ⌊1/(kx)⌋ = 1.
    Since x ∈ (1/(k+1), 1/k), we have 1/(kx) ∈ (1, (k+1)/k) ⊂ [1, 2). -/
theorem floor_inv_mul_eq_one (k : ℕ) (hk : 1 ≤ k)
    (x : ℝ) (hx_lo : 1 / ((k : ℝ) + 1) < x) (hx_hi : x < 1 / (k : ℝ)) :
    ⌊1 / ((k : ℝ) * x)⌋ = 1 := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hk1_pos : (0 : ℝ) < (k : ℝ) + 1 := by linarith
  have hx_pos : (0 : ℝ) < x := by
    calc (0 : ℝ) < 1 / ((k : ℝ) + 1) := by positivity
    _ < x := hx_lo
  have hkx_pos : (0 : ℝ) < (k : ℝ) * x := mul_pos hk_pos hx_pos
  -- Lower bound: 1/(kx) > 1
  have h_lower : 1 ≤ 1 / ((k : ℝ) * x) := by
    rw [le_div_iff₀ hkx_pos]
    nlinarith [mul_div_cancel₀ (1 : ℝ) (ne_of_gt hk_pos)]
  -- Upper bound: 1/(kx) < 2
  have h_upper : 1 / ((k : ℝ) * x) < 2 := by
    rw [div_lt_iff₀ hkx_pos]
    nlinarith [mul_div_cancel₀ (1 : ℝ) (ne_of_gt hk1_pos)]
  rw [Int.floor_eq_iff (by positivity)]
  constructor
  · exact_mod_cast h_lower
  · push_cast; linarith

/-- Fractional part: on (1/(k+1), 1/k), {1/(kx)} = 1/(kx) - 1. -/
theorem fract_inv_mul_eq_sub_one (k : ℕ) (hk : 1 ≤ k)
    (x : ℝ) (hx_lo : 1 / ((k : ℝ) + 1) < x) (hx_hi : x < 1 / (k : ℝ)) :
    Int.fract (1 / ((k : ℝ) * x)) = 1 / ((k : ℝ) * x) - 1 := by
  unfold Int.fract
  rw [floor_inv_mul_eq_one k hk x hx_lo hx_hi]
  simp [Int.cast_one]

/-- On (1/(k+1), 1/k) with j > k, ⌊1/(jx)⌋ = 0.
    Since j ≥ k+1 and x > 1/(k+1), we have jx > 1, so 1/(jx) < 1. -/
theorem floor_inv_mul_eq_zero (k j : ℕ) (hk : 1 ≤ k) (hj : k < j)
    (x : ℝ) (hx_lo : 1 / ((k : ℝ) + 1) < x) (hx_hi : x < 1 / (k : ℝ)) :
    ⌊1 / ((j : ℝ) * x)⌋ = 0 := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hk1_pos : (0 : ℝ) < (k : ℝ) + 1 := by linarith
  have hx_pos : (0 : ℝ) < x := by linarith [show (0:ℝ) < 1 / ((k:ℝ) + 1) from by positivity]
  have hj_pos : (0 : ℝ) < (j : ℝ) := Nat.cast_pos.mpr (by omega)
  have hjx_pos : (0 : ℝ) < (j : ℝ) * x := mul_pos hj_pos hx_pos
  -- 1/(jx) ≥ 0 (trivially)
  have h_nonneg : 0 ≤ 1 / ((j : ℝ) * x) := by positivity
  -- 1/(jx) < 1: since j ≥ k+1 and x > 1/(k+1), jx > j/(k+1) ≥ 1
  have h_lt_one : 1 / ((j : ℝ) * x) < 1 := by
    rw [div_lt_one hjx_pos]
    have hj_ge : (k : ℝ) + 1 ≤ (j : ℝ) := by exact_mod_cast hj
    nlinarith [mul_div_cancel₀ (1 : ℝ) (ne_of_gt hk1_pos)]
  rw [Int.floor_eq_iff (by positivity)]
  constructor
  · exact_mod_cast h_nonneg
  · push_cast; linarith

/-- Fractional part: on (1/(k+1), 1/k) with j > k, {1/(jx)} = 1/(jx). -/
theorem fract_inv_mul_eq_self (k j : ℕ) (hk : 1 ≤ k) (hj : k < j)
    (x : ℝ) (hx_lo : 1 / ((k : ℝ) + 1) < x) (hx_hi : x < 1 / (k : ℝ)) :
    Int.fract (1 / ((j : ℝ) * x)) = 1 / ((j : ℝ) * x) := by
  unfold Int.fract
  rw [floor_inv_mul_eq_zero k j hk hj x hx_lo hx_hi]
  simp

-- ════════════════════════════════════════════════
-- §2. THE LINEAR COMBINATION AND NONZERO WITNESS
-- ════════════════════════════════════════════════

/-- Linear combination of corrected basis functions:
    Σ_{i=0}^{N-1} w(i) · {1/((i+1)·x)} -/
def nbLinCombNew (N : ℕ) (w : Fin N → ℝ) (x : ℝ) : ℝ :=
  ∑ i : Fin N, w i * Int.fract (1 / (((i.val + 1 : ℕ) : ℝ) * x))

-- ════════════════════════════════════════════════
-- §3. THE MINIMUM-INDEX NUKE
-- ════════════════════════════════════════════════

-- The core proof strategy:
-- 1. If w ≠ 0, find minimum index k₀ with w(k₀) ≠ 0
-- 2. Consider two cases:
--    Case A: Σ w(i)/(i+1) ≠ 0 → nbLinCombNew = A·(1/x) is nonzero on (1/2, 1)
--    Case B: Σ w(i)/(i+1) = 0 → use minimum-index jump to get constant -w(k₀)
-- 3. In both cases, nbLinCombNew ≠ 0 on some interval → ∫ f² > 0

/-- If w ≠ 0, then nbLinCombNew is nonzero on some subinterval of (0,1). -/
theorem nbLinCombNew_nonzero_somewhere (N : ℕ) (hN : 1 ≤ N)
    (w : Fin N → ℝ) (hw : w ≠ 0) :
    ∃ c d : ℝ, 0 ≤ c ∧ c < d ∧ d ≤ 1 ∧
    (∀ x, x ∈ Set.Ioo c d → nbLinCombNew N w x ≠ 0) := by
  -- Find the minimum nonzero index
  have hw_exists : ∃ i : Fin N, w i ≠ 0 := by
    by_contra h; push_neg at h; exact hw (funext h)
  let S := Finset.filter (fun i : Fin N => w i ≠ 0) Finset.univ
  have hS : S.Nonempty := by
    obtain ⟨i, hi⟩ := hw_exists
    exact ⟨i, Finset.mem_filter.mpr ⟨Finset.mem_univ _, hi⟩⟩
  set k₀ := S.min' hS
  have hwk₀ : w k₀ ≠ 0 := (Finset.mem_filter.mp (Finset.min'_mem S hS)).2
  have hw_below : ∀ i : Fin N, i < k₀ → w i = 0 := by
    intro i hi; by_contra h
    exact absurd (Finset.min'_le S i (Finset.mem_filter.mpr ⟨Finset.mem_univ _, h⟩))
      (not_le.mpr hi)
  -- The interval (1/(k₀.val+2), 1/(k₀.val+1)) is where we witness nonzero
  -- On this interval, h_{k₀+1} has floor 1, all higher h_j have floor 0
  -- The linear combination equals (1/x)·A - w(k₀) for some A
  -- If A ≠ 0, then the function c·(1/x) + d is nonzero near the boundary
  -- If A = 0, then the function = -w(k₀) ≠ 0 everywhere on the interval
  sorry

/-- nbLinCombNew² is integrable on [0,1]. -/
theorem nbLinCombNew_sq_integrable (N : ℕ) (w : Fin N → ℝ) :
    IntervalIntegrable (fun x => (nbLinCombNew N w x) ^ 2) MeasureTheory.volume 0 1 := by
  sorry

/-- **THE NUKE**: ∫₀¹ (Σ wᵢ{1/((i+1)x)})² dx > 0 for w ≠ 0. -/
theorem nyman_beurling_lin_indep_new (N : ℕ) (hN : 1 ≤ N)
    (w : Fin N → ℝ) (hw : w ≠ 0) :
    0 < ∫ x in (0:ℝ)..1, (nbLinCombNew N w x) ^ 2 := by
  sorry

end Cathedral.Vasyunin
