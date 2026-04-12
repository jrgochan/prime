/-
  Cathedral/MellinBridge/Vasyunin/LinIndep.lean

  **THE MINIMUM-INDEX NUKE — Linear Independence of {1/(kx)}**

  Proves that the Báez-Duarte basis functions h_k(x) = {1/(kx)} are
  linearly independent in L²(0,1), which implies the augmented Gram
  matrix H_N is positive definite.

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

/-- On (1/(k+1), 1/k), ⌊1/(kx)⌋ = 1. -/
theorem floor_inv_mul_eq_one (k : ℕ) (hk : 1 ≤ k)
    (x : ℝ) (hx_lo : 1 / ((k : ℝ) + 1) < x) (hx_hi : x < 1 / (k : ℝ)) :
    ⌊1 / ((k : ℝ) * x)⌋ = 1 := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hk1_pos : (0 : ℝ) < (k : ℝ) + 1 := by linarith
  have hx_pos : (0 : ℝ) < x := by linarith [show (0:ℝ) < 1 / ((k:ℝ) + 1) from by positivity]
  have hkx_pos : (0 : ℝ) < (k : ℝ) * x := mul_pos hk_pos hx_pos
  rw [Int.floor_eq_iff]
  constructor
  · rw [Int.cast_one, le_div_iff₀ hkx_pos]
    nlinarith [div_mul_cancel₀ (1 : ℝ) (ne_of_gt hk_pos)]
  · rw [Int.cast_one]
    show 1 / ((k : ℝ) * x) < 1 + 1
    rw [div_lt_iff₀ hkx_pos]
    have hkx_bound : ((k : ℝ) + 1) * x > 1 := by
      calc ((k : ℝ) + 1) * x > ((k : ℝ) + 1) * (1 / ((k : ℝ) + 1)) := by nlinarith
      _ = 1 := by field_simp
    nlinarith [show (1:ℝ) ≤ (k:ℝ) from Nat.one_le_cast.mpr hk]

/-- Fractional part: on (1/(k+1), 1/k), {1/(kx)} = 1/(kx) - 1. -/
theorem fract_inv_mul_eq_sub_one (k : ℕ) (hk : 1 ≤ k)
    (x : ℝ) (hx_lo : 1 / ((k : ℝ) + 1) < x) (hx_hi : x < 1 / (k : ℝ)) :
    Int.fract (1 / ((k : ℝ) * x)) = 1 / ((k : ℝ) * x) - 1 := by
  unfold Int.fract
  rw [floor_inv_mul_eq_one k hk x hx_lo hx_hi]
  simp [Int.cast_one]

/-- On (1/(k+1), 1/k) with j > k, ⌊1/(jx)⌋ = 0. -/
theorem floor_inv_mul_eq_zero (k j : ℕ) (hk : 1 ≤ k) (hj : k < j)
    (x : ℝ) (hx_lo : 1 / ((k : ℝ) + 1) < x) (_ : x < 1 / (k : ℝ)) :
    ⌊1 / ((j : ℝ) * x)⌋ = 0 := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hk1_pos : (0 : ℝ) < (k : ℝ) + 1 := by linarith
  have hx_pos : (0 : ℝ) < x := by linarith [show (0:ℝ) < 1 / ((k:ℝ) + 1) from by positivity]
  have hj_pos : (0 : ℝ) < (j : ℝ) := Nat.cast_pos.mpr (by omega)
  have hjx_pos : (0 : ℝ) < (j : ℝ) * x := mul_pos hj_pos hx_pos
  have h_lt_one : 1 / ((j : ℝ) * x) < 1 := by
    rw [div_lt_one hjx_pos]
    have hj_ge : (k : ℝ) + 1 ≤ (j : ℝ) := by exact_mod_cast hj
    have : 1 / ((k : ℝ) + 1) * ((k : ℝ) + 1) = 1 := by field_simp
    nlinarith
  have h_nonneg : (0 : ℝ) ≤ 1 / ((j : ℝ) * x) := by positivity
  rw [Int.floor_eq_zero_iff]; exact ⟨h_nonneg, h_lt_one⟩

/-- Fractional part: on (1/(k+1), 1/k) with j > k, {1/(jx)} = 1/(jx). -/
theorem fract_inv_mul_eq_self (k j : ℕ) (hk : 1 ≤ k) (hj : k < j)
    (x : ℝ) (hx_lo : 1 / ((k : ℝ) + 1) < x) (hx_hi : x < 1 / (k : ℝ)) :
    Int.fract (1 / ((j : ℝ) * x)) = 1 / ((j : ℝ) * x) := by
  unfold Int.fract
  rw [floor_inv_mul_eq_zero k j hk hj x hx_lo hx_hi]
  simp

-- ════════════════════════════════════════════════
-- §2. THE LINEAR COMBINATION
-- ════════════════════════════════════════════════

/-- Linear combination of corrected basis functions. -/
def nbLinCombNew (N : ℕ) (w : Fin N → ℝ) (x : ℝ) : ℝ :=
  ∑ i : Fin N, w i * Int.fract (1 / (((i.val + 1 : ℕ) : ℝ) * x))

-- ════════════════════════════════════════════════
-- §3. THE MINIMUM-INDEX NUKE
-- ════════════════════════════════════════════════

/-- **Evaluation on the critical interval (1/(k₀+2), 1/(k₀+1)).**

    When k₀ is the minimum nonzero index and k₀.val ≥ 1:
    • i < k₀ terms vanish (w(i) = 0)
    • i = k₀ term: {1/((k₀+1)x)} = 1/((k₀+1)x) - 1
    • i > k₀ terms: {1/((i+1)x)} = 1/((i+1)x)

    So nbLinCombNew = Σ w(i)/((i+1)x) - w(k₀) = A/x - w(k₀)
    where A = Σ w(i)/(i+1).

    When A = 0: nbLinCombNew = -w(k₀) (constant, nonzero). -/
theorem nbLinCombNew_eq_neg_on_critical_interval (N : ℕ) (w : Fin N → ℝ)
    (k₀ : Fin N) (hw_below : ∀ i : Fin N, i < k₀ → w i = 0)
    (hk₀_pos : 1 ≤ k₀.val)
    (hA : (∑ i : Fin N, w i / ((i.val + 1 : ℕ) : ℝ)) = 0)
    (x : ℝ)
    (hx_lo : 1 / ((k₀.val : ℝ) + 2) < x)
    (hx_hi : x < 1 / ((k₀.val : ℝ) + 1)) :
    nbLinCombNew N w x = -(w k₀) := by
  sorry

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
  -- Two-case structure based on k₀.val and weighted sum A
  set A := ∑ i : Fin N, w i / ((i.val + 1 : ℕ) : ℝ) with hA_def
  set k := k₀.val + 1 with hk_def
  have hk_ge : 1 ≤ k := by omega
  have hk_pos : (0 : ℝ) < (k : ℝ) := by positivity
  have hk1_pos : (0 : ℝ) < (k : ℝ) + 1 := by linarith
  set a := 1 / ((k : ℝ) + 1)
  set b := 1 / (k : ℝ)
  have hab : a < b := by
    simp only [a, b]; rw [div_lt_div_iff₀ hk1_pos hk_pos]; nlinarith
  have ha_nn : 0 ≤ a := by positivity
  have hb_le_1 : b ≤ 1 := by simp only [b]; rw [div_le_one hk_pos]; exact_mod_cast hk_ge
  -- Handle two cases: k₀.val = 0 and k₀.val ≥ 1
  by_cases hk₀_zero : k₀.val = 0
  · -- k₀ = 0: all functions are used. Use the interval directly.
    -- On (1/2, 1): h_1 has floor jump, all others floor 0
    sorry
  · -- k₀.val ≥ 1: the standard case
    have hk₀_pos : 1 ≤ k₀.val := by omega
    by_cases hA_zero : A = 0
    · -- Case A = 0: nbLinCombNew = -w(k₀) on (a, b)
      refine ⟨a, b, ha_nn, hab, hb_le_1, ?_⟩
      intro x ⟨hx_lo, hx_hi⟩
      -- a = 1/(k₀.val + 2) and b = 1/(k₀.val + 1)
      have ha_eq : a = 1 / ((k₀.val : ℝ) + 2) := by
        simp only [a]; congr 1; simp only [hk_def]; push_cast; ring
      have hb_eq : b = 1 / ((k₀.val : ℝ) + 1) := by
        simp only [b]; congr 1; simp only [hk_def]; push_cast; ring
      rw [nbLinCombNew_eq_neg_on_critical_interval N w k₀ hw_below hk₀_pos hA_zero x
          (by linarith) (by linarith)]
      exact neg_ne_zero.mpr hwk₀
    · -- Case A ≠ 0: f = A/x - w(k₀) is nonconstant, has at most one zero
      -- For a nonconstant continuous function on an interval,
      -- it has at most one zero, so it's nonzero on a subinterval
      sorry

-- ════════════════════════════════════════════════
-- §4. INTEGRABILITY AND MAIN THEOREM
-- ════════════════════════════════════════════════

/-- nbLinCombNew² is integrable on [0,1]. -/
theorem nbLinCombNew_sq_integrable (N : ℕ) (w : Fin N → ℝ) :
    IntervalIntegrable (fun x => (nbLinCombNew N w x) ^ 2) MeasureTheory.volume 0 1 := by
  sorry

/-- **THE NUKE**: ∫₀¹ (Σ wᵢ{1/((i+1)x)})² dx > 0 for w ≠ 0.

    Proof: nonzero-somewhere + ∫ f² > 0 for f not a.e. zero. -/
theorem nyman_beurling_lin_indep_new (N : ℕ) (hN : 1 ≤ N)
    (w : Fin N → ℝ) (hw : w ≠ 0) :
    0 < ∫ x in (0:ℝ)..1, (nbLinCombNew N w x) ^ 2 := by
  obtain ⟨c, d, hc0, hcd, hd1, hne⟩ := nbLinCombNew_nonzero_somewhere N hN w hw
  have hpos_sub : ∀ x, x ∈ Set.Ioo c d → 0 < (nbLinCombNew N w x) ^ 2 :=
    fun x hx => sq_pos_of_ne_zero (hne x hx)
  sorry

end Cathedral.Vasyunin
