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
import Mathlib.MeasureTheory.Function.Floor

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
    (hA : (∑ i : Fin N, w i / ((i.val + 1 : ℕ) : ℝ)) = 0)
    (x : ℝ)
    (hx_lo : 1 / ((k₀.val : ℝ) + 2) < x)
    (hx_hi : x < 1 / ((k₀.val : ℝ) + 1)) :
    nbLinCombNew N w x = -(w k₀) := by
  have hk₀_pos_r : (0 : ℝ) < (k₀.val : ℝ) + 1 := by positivity
  have hx_pos : (0 : ℝ) < x := by linarith [show (0:ℝ) < 1 / ((k₀.val : ℝ) + 2) from by positivity]
  -- Helper cast lemma
  set k₀v := k₀.val with hk₀v_def
  -- The floor lemmas use k : ℕ with k = k₀v + 1, interval (1/(k+1), 1/k):
  --   fract_inv_mul_eq_sub_one (k₀v + 1) ... needs (1/((k₀v+1:ℝ)+1), 1/(k₀v+1:ℝ))
  --   = (1/(k₀v+2), 1/(k₀v+1)) which is exactly our (hx_lo, hx_hi)
  -- Nat cast helper: ↑(k₀v + 1) = ↑k₀v + 1
  have hcast_k : ((k₀v + 1 : ℕ) : ℝ) = (k₀v : ℝ) + 1 := by push_cast; ring
  -- Step 1: Rewrite each term using floor lemmas
  have h_term : ∀ i : Fin N,
      w i * Int.fract (1 / (((i.val + 1 : ℕ) : ℝ) * x)) =
      if i < k₀ then 0
      else w i / (((i.val + 1 : ℕ) : ℝ) * x) -
           (if i = k₀ then w k₀ else 0) := by
    intro i
    have hicast : ((i.val + 1 : ℕ) : ℝ) = (i.val : ℝ) + 1 := by push_cast; ring
    by_cases hi_below : i < k₀
    · simp only [hi_below, ↓reduceIte, hw_below i hi_below, zero_mul]
    · push Not at hi_below
      simp only [show ¬(i < k₀) from not_lt.mpr hi_below, ↓reduceIte]
      by_cases hi_eq : i = k₀
      · -- i = k₀
        subst hi_eq; simp only [↓reduceIte]
        have hk_ge : 1 ≤ k₀v + 1 := by omega
        have h1 : 1 / ((↑(k₀v + 1) : ℝ) + 1) < x := by
          have : ((↑(k₀v + 1) : ℝ) + 1) = (↑k₀v + 2) := by rw [hcast_k]; ring
          rw [this]; exact hx_lo
        have h2 : x < 1 / (↑(k₀v + 1) : ℝ) := by rw [hcast_k]; exact hx_hi
        -- The goal has ↑(↑i + 1) which after subst equals ↑(k₀v + 1)
        -- Both are ((Fin.val i + 1 : ℕ) : ℝ), which Lean prints as ↑(↑i + 1)
        -- With k₀v = ↑i, these are definitionally equal
        conv_lhs => rw [show ((↑i + 1 : ℕ) : ℝ) = (↑(k₀v + 1) : ℝ) from by norm_cast]
        conv_rhs => rw [show ((↑i + 1 : ℕ) : ℝ) = (↑(k₀v + 1) : ℝ) from by norm_cast]
        rw [fract_inv_mul_eq_sub_one (k₀v + 1) hk_ge x h1 h2]; ring
      · -- i > k₀
        have hi_above : k₀ < i := lt_of_le_of_ne hi_below (Ne.symm hi_eq)
        simp only [hi_eq, ↓reduceIte, sub_zero]
        have hk_ge : 1 ≤ k₀v + 1 := by omega
        have hij : k₀v + 1 < i.val + 1 := by omega
        have h1 : 1 / ((↑(k₀v + 1) : ℝ) + 1) < x := by
          have : ((↑(k₀v + 1) : ℝ) + 1) = (↑k₀v + 2) := by rw [hcast_k]; ring
          rw [this]; exact hx_lo
        have h2 : x < 1 / (↑(k₀v + 1) : ℝ) := by rw [hcast_k]; exact hx_hi
        conv_lhs => rw [show ((↑i + 1 : ℕ) : ℝ) = (↑(i.val + 1) : ℝ) from by norm_cast]
        rw [fract_inv_mul_eq_self (k₀v + 1) (i.val + 1) hk_ge hij x h1 h2]
        rw [show (↑(i.val + 1) : ℝ) = ((↑i + 1 : ℕ) : ℝ) from by norm_cast]
        field_simp
  -- Step 2: Apply the rewrite
  unfold nbLinCombNew; simp_rw [h_term]
  -- Step 3: Eliminate the if-else by using w(i)=0 for i < k₀
  have h_ite_sum : ∀ i : Fin N,
      (if i < k₀ then (0 : ℝ)
       else w i / (((i.val + 1 : ℕ) : ℝ) * x) - (if i = k₀ then w k₀ else 0)) =
      w i / (((i.val + 1 : ℕ) : ℝ) * x) - (if i = k₀ then w k₀ else 0) := by
    intro i; split_ifs with h1 h2
    · rw [hw_below i h1]; simp; exact absurd (Eq.symm h2) (ne_of_lt h1 |>.symm)
    · rw [hw_below i h1]; simp
    · rfl
    · rfl
  simp_rw [h_ite_sum, Finset.sum_sub_distrib]
  -- Sum₂: Σ (if i = k₀ then w k₀ else 0) = w k₀
  have h_sum2 : ∑ i : Fin N, (if i = k₀ then w k₀ else (0 : ℝ)) = w k₀ := by
    rw [Finset.sum_ite_eq' Finset.univ k₀ (fun _ => w k₀)]
    simp [Finset.mem_univ]
  rw [h_sum2]
  have h_factor : ∑ i : Fin N, w i / (((i.val + 1 : ℕ) : ℝ) * x) =
      (1 / x) * ∑ i : Fin N, w i / ((i.val + 1 : ℕ) : ℝ) := by
    rw [Finset.mul_sum]; congr 1; ext i
    have : (0 : ℝ) < ((i.val + 1 : ℕ) : ℝ) := by positivity
    field_simp
  rw [h_factor, hA, mul_zero, zero_sub]

/-- **General evaluation** (without A = 0 assumption):
    nbLinCombNew = A/x - w(k₀) on (1/(k₀+2), 1/(k₀+1)). -/
theorem nbLinCombNew_eq_affine_on_critical_interval (N : ℕ) (w : Fin N → ℝ)
    (k₀ : Fin N) (hw_below : ∀ i : Fin N, i < k₀ → w i = 0)
    (x : ℝ)
    (hx_lo : 1 / ((k₀.val : ℝ) + 2) < x)
    (hx_hi : x < 1 / ((k₀.val : ℝ) + 1)) :
    nbLinCombNew N w x =
    (∑ i : Fin N, w i / ((i.val + 1 : ℕ) : ℝ)) / x - w k₀ := by
  -- Same proof as nbLinCombNew_eq_neg_on_critical_interval, but keep A
  have hx_pos : (0 : ℝ) < x := by linarith [show (0:ℝ) < 1 / ((k₀.val : ℝ) + 2) from by positivity]
  set k₀v := k₀.val with hk₀v_def
  have hcast_k : ((k₀v + 1 : ℕ) : ℝ) = (k₀v : ℝ) + 1 := by push_cast; ring
  have h_term : ∀ i : Fin N,
      w i * Int.fract (1 / (((i.val + 1 : ℕ) : ℝ) * x)) =
      if i < k₀ then 0
      else w i / (((i.val + 1 : ℕ) : ℝ) * x) -
           (if i = k₀ then w k₀ else 0) := by
    intro i
    have hicast : ((i.val + 1 : ℕ) : ℝ) = (i.val : ℝ) + 1 := by push_cast; ring
    by_cases hi_below : i < k₀
    · simp only [hi_below, ↓reduceIte, hw_below i hi_below, zero_mul]
    · push Not at hi_below
      simp only [show ¬(i < k₀) from not_lt.mpr hi_below, ↓reduceIte]
      by_cases hi_eq : i = k₀
      · subst hi_eq; simp only [↓reduceIte]
        have hk_ge : 1 ≤ k₀v + 1 := by omega
        have h1 : 1 / ((↑(k₀v + 1) : ℝ) + 1) < x := by
          have : ((↑(k₀v + 1) : ℝ) + 1) = (↑k₀v + 2) := by rw [hcast_k]; ring
          rw [this]; exact hx_lo
        have h2 : x < 1 / (↑(k₀v + 1) : ℝ) := by rw [hcast_k]; exact hx_hi
        conv_lhs => rw [show ((↑i + 1 : ℕ) : ℝ) = (↑(k₀v + 1) : ℝ) from by norm_cast]
        conv_rhs => rw [show ((↑i + 1 : ℕ) : ℝ) = (↑(k₀v + 1) : ℝ) from by norm_cast]
        rw [fract_inv_mul_eq_sub_one (k₀v + 1) hk_ge x h1 h2]; ring
      · have hi_above : k₀ < i := lt_of_le_of_ne hi_below (Ne.symm hi_eq)
        simp only [hi_eq, ↓reduceIte, sub_zero]
        have hk_ge : 1 ≤ k₀v + 1 := by omega
        have hij : k₀v + 1 < i.val + 1 := by omega
        have h1 : 1 / ((↑(k₀v + 1) : ℝ) + 1) < x := by
          have : ((↑(k₀v + 1) : ℝ) + 1) = (↑k₀v + 2) := by rw [hcast_k]; ring
          rw [this]; exact hx_lo
        have h2 : x < 1 / (↑(k₀v + 1) : ℝ) := by rw [hcast_k]; exact hx_hi
        conv_lhs => rw [show ((↑i + 1 : ℕ) : ℝ) = (↑(i.val + 1) : ℝ) from by norm_cast]
        rw [fract_inv_mul_eq_self (k₀v + 1) (i.val + 1) hk_ge hij x h1 h2]
        rw [show (↑(i.val + 1) : ℝ) = ((↑i + 1 : ℕ) : ℝ) from by norm_cast]
        field_simp
  unfold nbLinCombNew; simp_rw [h_term]
  have h_ite_sum : ∀ i : Fin N,
      (if i < k₀ then (0 : ℝ)
       else w i / (((i.val + 1 : ℕ) : ℝ) * x) - (if i = k₀ then w k₀ else 0)) =
      w i / (((i.val + 1 : ℕ) : ℝ) * x) - (if i = k₀ then w k₀ else 0) := by
    intro i; split_ifs with h1 h2
    · rw [hw_below i h1]; simp; exact absurd (Eq.symm h2) (ne_of_lt h1 |>.symm)
    · rw [hw_below i h1]; simp
    · rfl
    · rfl
  simp_rw [h_ite_sum, Finset.sum_sub_distrib]
  have h_sum2 : ∑ i : Fin N, (if i = k₀ then w k₀ else (0 : ℝ)) = w k₀ := by
    rw [Finset.sum_ite_eq' Finset.univ k₀ (fun _ => w k₀)]
    simp [Finset.mem_univ]
  rw [h_sum2]
  have h_factor : ∑ i : Fin N, w i / (((i.val + 1 : ℕ) : ℝ) * x) =
      (1 / x) * ∑ i : Fin N, w i / ((i.val + 1 : ℕ) : ℝ) := by
    rw [Finset.mul_sum]; congr 1; ext i
    have : (0 : ℝ) < ((i.val + 1 : ℕ) : ℝ) := by positivity
    field_simp
  rw [h_factor]
  have hx_ne : x ≠ 0 := ne_of_gt hx_pos
  field_simp

/-- **A/x - B is nonzero on a subinterval** when A ≠ 0 and 0 < a < b. -/
private theorem affine_inv_nonzero_subinterval (A B a b : ℝ) (hA : A ≠ 0)
    (ha : 0 < a) (hab : a < b) :
    ∃ c d : ℝ, a ≤ c ∧ c < d ∧ d ≤ b ∧
    ∀ x, x ∈ Set.Ioo c d → A / x - B ≠ 0 := by
  -- A/x - B = 0 ⟺ x = A/B. So f is nonzero except at one point.
  -- For x ∈ (a, (a+b)/2) or ((a+b)/2, b), f ≠ 0 on whichever avoids x₀.
  -- The function A/x is strictly monotone, so A/x₁ ≠ A/x₂ for x₁ ≠ x₂.
  -- Therefore A/x - B ≠ 0 for all x ≠ A/B.
  set m := (a + b) / 2 with hm_def
  have hm_pos : 0 < m := by linarith
  have ham : a < m := by linarith
  have hmb : m < b := by linarith
  -- f is nonzero on (a, m) because:
  -- for x ∈ (a, m), if A/x = B, then x = A/B.
  -- But 1/x is injective, so at most one x in (a, m) has A/x = B.
  -- If there's no such x: use (a, m).
  -- If there is: use (m, b) instead (since the zero can be in at most one half).
  by_cases hfm : A / m - B = 0
  · -- f(m) = 0, so A/m = B. For x ≠ m, A/x ≠ A/m, so f(x) ≠ 0.
    -- Use either (a, m) or (m, b). Take (a, m).
    refine ⟨a, m, le_refl a, ham, le_of_lt hmb, ?_⟩
    intro x ⟨hx_lo, hx_hi⟩
    have hx_ne_m : x ≠ m := ne_of_lt hx_hi
    have hx_pos : 0 < x := by linarith
    intro h_eq
    -- h_eq : A/x - B = 0, and hfm : A/m - B = 0
    -- So A/x = B = A/m, hence 1/x = 1/m (since A ≠ 0)
    have : A / x = A / m := by linarith
    have : 1 / x = 1 / m := by
      field_simp at this ⊢; linarith
    have : x = m := by
      have hx_pos' : x ≠ 0 := ne_of_gt hx_pos
      have hm_pos' : m ≠ 0 := ne_of_gt hm_pos
      field_simp at this; linarith
    exact hx_ne_m this
  · -- f(m) ≠ 0. Use an interval containing m.
    -- Since A/x - B is continuous and nonzero at m, it's nonzero on a neighborhood.
    -- We can use (a, b) restricted to avoiding any zero.
    -- Simpler: pick any x ∈ (a, m): if A/x = B = A/m + something ≠ ...
    -- Actually, just use (a, m) and argue each x satisfies x ≠ A/B:
    -- If no x ∈ (a, m) has f(x) = 0, done.
    -- If some x₀ ∈ (a, m) has f(x₀) = 0, then x₀ = A/B and m ≠ A/B.
    -- Use (x₀, m) or (a, x₀).
    -- But this gets recursive. Simpler: use (m, b) as our subinterval.
    -- We know f(m) ≠ 0. For any x ∈ (a, b) with f(x) = 0, x = A/B.
    -- So at most one zero in (a, b). The intervals (a, A/B) and (A/B, b) are zero-free.
    -- Since f(m) ≠ 0, m ≠ A/B, so m is in one of these zero-free intervals.
    by_cases hzero_lt : ∀ x₀, a < x₀ → x₀ < b → A / x₀ - B ≠ 0
    · exact ⟨a, b, le_refl a, hab, le_refl b, fun x hx => hzero_lt x hx.1 hx.2⟩
    · push Not at hzero_lt
      obtain ⟨x₀, hx₀_lo, hx₀_hi, hfx₀⟩ := hzero_lt
      -- x₀ is the unique zero. m ≠ x₀ since f(m) ≠ 0.
      by_cases hm_lt_x₀ : m < x₀
      · -- m < x₀. Use (a, x₀): for x ∈ (a, x₀), x ≠ x₀ so A/x ≠ A/x₀ = B.
        refine ⟨a, x₀, le_refl a, by linarith, le_of_lt hx₀_hi, ?_⟩
        intro x ⟨hx_lo, hx_hi⟩
        have hx_ne : x ≠ x₀ := ne_of_lt hx_hi
        have hx_pos : 0 < x := by linarith
        have hx₀_pos : 0 < x₀ := by linarith
        intro h_eq
        have : A / x = A / x₀ := by linarith
        have hx_eq : x = x₀ := by
          have hx_ne : x ≠ 0 := ne_of_gt hx_pos
          have hx₀_ne : x₀ ≠ 0 := ne_of_gt hx₀_pos
          field_simp at this
          nlinarith
        exact hx_ne hx_eq
      · -- x₀ ≤ m. Since m ≠ x₀, x₀ < m. Use (x₀, b).
        have hx₀_lt_m : x₀ < m := by
          rcases lt_or_eq_of_le (not_lt.mp hm_lt_x₀) with h | h
          · exact h
          · exfalso; apply hfm; rw [← h]; linarith
        refine ⟨x₀, b, le_of_lt hx₀_lo, by linarith, le_refl b, ?_⟩
        intro x ⟨hx_lo, hx_hi⟩
        have hx_ne : x ≠ x₀ := ne_of_gt hx_lo
        have hx_pos : 0 < x := by linarith
        have hx₀_pos : 0 < x₀ := by linarith
        intro h_eq
        have : A / x = A / x₀ := by linarith
        have hx_eq : x = x₀ := by
          have hx_ne : x ≠ 0 := ne_of_gt hx_pos
          have hx₀_ne : x₀ ≠ 0 := ne_of_gt hx₀_pos
          field_simp at this
          nlinarith
        exact hx_ne hx_eq

/-- If w ≠ 0, then nbLinCombNew is nonzero on some subinterval of (0,1). -/
theorem nbLinCombNew_nonzero_somewhere (N : ℕ) (_hN : 1 ≤ N)
    (w : Fin N → ℝ) (hw : w ≠ 0) :
    ∃ c d : ℝ, 0 ≤ c ∧ c < d ∧ d ≤ 1 ∧
    (∀ x, x ∈ Set.Ioo c d → nbLinCombNew N w x ≠ 0) := by
  -- Find the minimum nonzero index
  have hw_exists : ∃ i : Fin N, w i ≠ 0 := by
    by_contra h; push Not at h; exact hw (funext h)
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
  · -- k₀ = 0: same evaluation lemma applies since hk₀_pos was removed
    by_cases hA_zero : A = 0
    · refine ⟨a, b, ha_nn, hab, hb_le_1, ?_⟩
      intro x ⟨hx_lo, hx_hi⟩
      have ha_eq : a = 1 / ((k₀.val : ℝ) + 2) := by
        simp only [a]; congr 1; simp only [hk_def]; push_cast; ring
      have hb_eq : b = 1 / ((k₀.val : ℝ) + 1) := by
        simp only [b]; congr 1; simp only [hk_def]; push_cast; ring
      rw [nbLinCombNew_eq_neg_on_critical_interval N w k₀ hw_below hA_zero x
          (by linarith) (by linarith)]
      exact neg_ne_zero.mpr hwk₀
    · -- k₀=0, A≠ 0: use affine_inv_nonzero_subinterval
      have ha_eq : a = 1 / ((k₀.val : ℝ) + 2) := by
        simp only [a]; congr 1; simp only [hk_def]; push_cast; ring
      have hb_eq : b = 1 / ((k₀.val : ℝ) + 1) := by
        simp only [b]; congr 1; simp only [hk_def]; push_cast; ring
      have ha_pos : (0 : ℝ) < a := by positivity
      obtain ⟨c, d, hac, hcd, hdb, hne⟩ :=
        affine_inv_nonzero_subinterval A (w k₀) a b hA_zero ha_pos hab
      refine ⟨c, d, by linarith, hcd, by linarith, ?_⟩
      intro x ⟨hx_lo, hx_hi⟩
      rw [nbLinCombNew_eq_affine_on_critical_interval N w k₀ hw_below x
          (by linarith) (by linarith)]
      exact hne x ⟨hx_lo, hx_hi⟩
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
      rw [nbLinCombNew_eq_neg_on_critical_interval N w k₀ hw_below hA_zero x
          (by linarith) (by linarith)]
      exact neg_ne_zero.mpr hwk₀
    · -- Case A ≠ 0: use affine_inv_nonzero_subinterval
      have ha_eq : a = 1 / ((k₀.val : ℝ) + 2) := by
        simp only [a]; congr 1; simp only [hk_def]; push_cast; ring
      have hb_eq : b = 1 / ((k₀.val : ℝ) + 1) := by
        simp only [b]; congr 1; simp only [hk_def]; push_cast; ring
      have ha_pos : (0 : ℝ) < a := by positivity
      obtain ⟨c, d, hac, hcd, hdb, hne⟩ :=
        affine_inv_nonzero_subinterval A (w k₀) a b hA_zero ha_pos hab
      refine ⟨c, d, by linarith, hcd, by linarith, ?_⟩
      intro x ⟨hx_lo, hx_hi⟩
      rw [nbLinCombNew_eq_affine_on_critical_interval N w k₀ hw_below x
          (by linarith) (by linarith)]
      exact hne x ⟨hx_lo, hx_hi⟩

-- ════════════════════════════════════════════════
-- §4. INTEGRABILITY AND MAIN THEOREM
-- ════════════════════════════════════════════════

/-- Products of fractional parts of 1/(j*x) and 1/(k*x) are measurable. -/
private lemma fract_inv_mul_measurable (j k : ℕ) :
    Measurable (fun x : ℝ => Int.fract (1 / (↑j * x)) * Int.fract (1 / (↑k * x))) := by
  apply Measurable.mul
  · exact (measurable_const.div (measurable_const.mul measurable_id)).fract
  · exact (measurable_const.div (measurable_const.mul measurable_id)).fract

/-- Products of fractional parts are bounded by 1. -/
private lemma fract_inv_prod_le_one (j k : ℕ) (x : ℝ) :
    ‖Int.fract (1 / (↑j * x)) * Int.fract (1 / (↑k * x))‖ ≤ ‖(1 : ℝ)‖ := by
  rw [Real.norm_eq_abs, Real.norm_eq_abs, abs_one,
      abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _))]
  calc Int.fract (1 / (↑j * x)) * Int.fract (1 / (↑k * x))
      ≤ 1 * 1 := by
        apply mul_le_mul
        · exact le_of_lt (Int.fract_lt_one _)
        · exact le_of_lt (Int.fract_lt_one _)
        · exact Int.fract_nonneg _
        · linarith
    _ = 1 := mul_one 1

/-- Products of fractional parts of 1/(j*x) are IntervalIntegrable on [0,1]. -/
private theorem fract_inv_prod_intervalIntegrable (j k : ℕ) :
    IntervalIntegrable
      (fun x : ℝ => Int.fract (1 / (↑j * x)) * Int.fract (1 / (↑k * x)))
      MeasureTheory.volume 0 1 :=
  IntervalIntegrable.mono_fun
    (intervalIntegrable_const (c := (1 : ℝ)))
    ((fract_inv_mul_measurable j k).aestronglyMeasurable.restrict)
    (Filter.Eventually.of_forall (fract_inv_prod_le_one j k))

/-- nbLinCombNew² is integrable on [0,1]. -/
theorem nbLinCombNew_sq_integrable (N : ℕ) (w : Fin N → ℝ) :
    IntervalIntegrable (fun x => (nbLinCombNew N w x) ^ 2) MeasureTheory.volume 0 1 := by
  have h_sq : (fun x => (nbLinCombNew N w x) ^ 2) =
      (fun x => ∑ i : Fin N, ∑ j : Fin N,
        (w i * Int.fract (1 / (((i.val + 1 : ℕ) : ℝ) * x))) *
        (w j * Int.fract (1 / (((j.val + 1 : ℕ) : ℝ) * x)))) := by
    ext x; unfold nbLinCombNew; rw [sq, Finset.sum_mul_sum]
  rw [h_sq]
  have : (fun x : ℝ => ∑ i : Fin N, ∑ j : Fin N,
      (w i * Int.fract (1 / (((i.val + 1 : ℕ) : ℝ) * x))) *
      (w j * Int.fract (1 / (((j.val + 1 : ℕ) : ℝ) * x)))) =
    (∑ i : Fin N, ∑ j : Fin N, fun x =>
      (w i * Int.fract (1 / (((i.val + 1 : ℕ) : ℝ) * x))) *
      (w j * Int.fract (1 / (((j.val + 1 : ℕ) : ℝ) * x)))) := by
    ext x; simp [Finset.sum_apply]
  rw [this]
  apply IntervalIntegrable.sum; intro i _
  apply IntervalIntegrable.sum; intro j _
  have : (fun x : ℝ => (w i * Int.fract (1 / (((i.val + 1 : ℕ) : ℝ) * x))) *
      (w j * Int.fract (1 / (((j.val + 1 : ℕ) : ℝ) * x)))) =
    (fun x : ℝ => (w i * w j) * (Int.fract (1 / (((i.val + 1 : ℕ) : ℝ) * x)) *
      Int.fract (1 / (((j.val + 1 : ℕ) : ℝ) * x)))) := by ext x; ring
  rw [this]
  exact (fract_inv_prod_intervalIntegrable (i.val + 1) (j.val + 1)).const_mul _

/-- **THE NUKE**: ∫₀¹ (Σ wᵢ{1/((i+1)x)})² dx > 0 for w ≠ 0.

    Proof: nonzero-somewhere + ∫ f² > 0 for f not a.e. zero. -/
theorem nyman_beurling_lin_indep_new (N : ℕ) (hN : 1 ≤ N)
    (w : Fin N → ℝ) (hw : w ≠ 0) :
    0 < ∫ x in (0:ℝ)..1, (nbLinCombNew N w x) ^ 2 := by
  obtain ⟨c, d, hc0, hcd, hd1, hne⟩ := nbLinCombNew_nonzero_somewhere N hN w hw
  have hpos_sub : ∀ x, x ∈ Set.Ioo c d → 0 < (nbLinCombNew N w x) ^ 2 :=
    fun x hx => sq_pos_of_ne_zero (hne x hx)
  have hisub : IntervalIntegrable (fun x => (nbLinCombNew N w x) ^ 2) MeasureTheory.volume c d :=
    (nbLinCombNew_sq_integrable N w).mono_set (by
      simp only [Set.uIcc_of_le (le_of_lt hcd), Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc hc0 hd1)
  have hint_sub : 0 < ∫ x in c..d, (nbLinCombNew N w x) ^ 2 :=
    intervalIntegral.intervalIntegral_pos_of_pos_on hisub hpos_sub hcd
  have hi0c : IntervalIntegrable (fun x => (nbLinCombNew N w x) ^ 2) MeasureTheory.volume 0 c :=
    (nbLinCombNew_sq_integrable N w).mono_set (by
      simp only [Set.uIcc_of_le hc0, Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc le_rfl (hcd.le.trans hd1))
  have hid1 : IntervalIntegrable (fun x => (nbLinCombNew N w x) ^ 2) MeasureTheory.volume d 1 :=
    (nbLinCombNew_sq_integrable N w).mono_set (by
      simp only [Set.uIcc_of_le hd1, Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc (hc0.trans hcd.le) le_rfl)
  have h_01 : (∫ x in (0:ℝ)..1, (nbLinCombNew N w x) ^ 2) =
    (∫ x in (0:ℝ)..c, (nbLinCombNew N w x) ^ 2) +
    (∫ x in c..d, (nbLinCombNew N w x) ^ 2) +
    (∫ x in d..1, (nbLinCombNew N w x) ^ 2) := by
    have h1 := intervalIntegral.integral_add_adjacent_intervals hi0c hisub
    have h2 := intervalIntegral.integral_add_adjacent_intervals (hi0c.trans hisub) hid1
    linarith
  rw [h_01]
  have h1 : 0 ≤ ∫ x in (0:ℝ)..c, (nbLinCombNew N w x) ^ 2 :=
    intervalIntegral.integral_nonneg hc0 (fun x _ => sq_nonneg _)
  have h2 : 0 ≤ ∫ x in d..1, (nbLinCombNew N w x) ^ 2 :=
    intervalIntegral.integral_nonneg hd1 (fun x _ => sq_nonneg _)
  linarith

end Cathedral.Vasyunin
