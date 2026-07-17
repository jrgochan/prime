/-
  Cathedral/Physics/GaugeTheory/GravitationalUniversality.lean

  ## THE GRAVITATIONAL UNIVERSALITY THEOREM — FULLY PROVED

  Proves: Every Gram entry G(j,k) is strictly positive for j,k ≥ 1.
  Graduates the axiom `gravitational_universality` from ArithmeticGravity.lean.

  Status: 0 sorry. 0 axioms. FULLY PROVED.
  Created: July 16, 2026 — The Pie (Day 108)
-/

import Cathedral.Vasyunin.Defs
import Cathedral.Vasyunin.Matrix.Structural
import Cathedral.Vasyunin.Augmented.VasyuninIntegralProof
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

noncomputable section

open Real MeasureTheory Cathedral.Vasyunin intervalIntegral

namespace Cathedral.GravitationalUniversality

/-- When n < y < n + 1, the fractional part is y - n > 0. -/
private lemma fract_pos_between_ints {y : ℝ} {n : ℤ} (h1 : (n : ℝ) < y) (h2 : y < n + 1) :
    0 < Int.fract y := by
  have : ⌊y⌋ = n := Int.floor_eq_iff.mpr ⟨by linarith, by linarith⟩
  rw [Int.fract, this]; push_cast; linarith

/-- When 1 < y < 2, {y} = y - 1 > 0. -/
private lemma fract_pos_in_unit {y : ℝ} (h1 : 1 < y) (h2 : y < 2) :
    0 < Int.fract y :=
  fract_pos_between_ints (n := 1) (by exact_mod_cast h1) (by exact_mod_cast h2)

-- Helper: product of fract parts is nonneg
private lemma fract_prod_nn (j k : ℕ) (x : ℝ) :
    0 ≤ Int.fract (1/((j:ℝ)*x)) * Int.fract (1/((k:ℝ)*x)) :=
  mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _)

-- ════════════════════════════════════════════════════════════════
-- THE OFF-DIAGONAL INTEGRAL POSITIVITY (j < k)
-- ════════════════════════════════════════════════════════════════

private theorem integral_pos_of_lt (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hjk : j < k) :
    0 < ∫ x in (0:ℝ)..1,
      Int.fract (1 / ((j : ℝ) * x)) * Int.fract (1 / ((k : ℝ) * x)) := by
  have hj_pos : (0 : ℝ) < j := Nat.cast_pos.mpr (by omega)
  have hk_pos : (0 : ℝ) < k := Nat.cast_pos.mpr (by omega)
  have hf_int := IntegralProof.fract_prod_intervalIntegrable j k
  -- Strategy: find (c, d) ⊆ (0,1) where the product > 0 pointwise
  suffices h : ∃ c d : ℝ, 0 ≤ c ∧ c < d ∧ d ≤ 1 ∧
      (∀ x ∈ Set.Ioo c d,
        0 < Int.fract (1/((j:ℝ)*x)) * Int.fract (1/((k:ℝ)*x))) by
    obtain ⟨c, d, hc, hcd, hd, hpos⟩ := h
    have hp : 0 < ∫ x in c..d, Int.fract (1/((j:ℝ)*x)) * Int.fract (1/((k:ℝ)*x)) :=
      intervalIntegral.intervalIntegral_pos_of_pos_on (hf_int c d) hpos hcd
    have h1 : ∫ x in (0:ℝ)..1, Int.fract (1/((j:ℝ)*x)) * Int.fract (1/((k:ℝ)*x)) =
      (∫ x in (0:ℝ)..c, Int.fract (1/((j:ℝ)*x)) * Int.fract (1/((k:ℝ)*x))) +
      (∫ x in c..d, Int.fract (1/((j:ℝ)*x)) * Int.fract (1/((k:ℝ)*x))) +
      (∫ x in d..(1:ℝ), Int.fract (1/((j:ℝ)*x)) * Int.fract (1/((k:ℝ)*x))) := by
        linarith [integral_add_adjacent_intervals (hf_int 0 c) (hf_int c d),
                  integral_add_adjacent_intervals (hf_int 0 d) (hf_int d 1)]
    linarith [integral_nonneg_of_forall (μ := volume) hc (fun u => fract_prod_nn j k u),
              integral_nonneg_of_forall (μ := volume) hd (fun u => fract_prod_nn j k u)]
  -- Two cases
  by_cases hdvd : j ∣ k
  · -- Case j | k: k = j*q, q ≥ 2. Use (1/(j+k), 1/k).
    obtain ⟨q, hq⟩ := hdvd
    have hq_ge : q ≥ 2 := by nlinarith
    refine ⟨1 / ((j:ℝ) + (k:ℝ)), 1 / (k:ℝ), by positivity,
            one_div_lt_one_div_of_lt hk_pos (by linarith),
            by rw [div_le_one hk_pos]; exact Nat.one_le_cast.mpr hk,
            fun x ⟨hxa, hxb⟩ => ?_⟩
    have hx_pos : (0:ℝ) < x := by linarith [show (0:ℝ) < 1/((j:ℝ)+(k:ℝ)) from by positivity]
    apply mul_pos
    · -- {1/(jx)} > 0: 1/(jx) ∈ (q, q+1)
      apply fract_pos_between_ints (n := (q:ℤ))
      · -- q < 1/(jx) ↔ q*j*x < 1 ↔ k*x < 1 ↔ x < 1/k
        rw [Int.cast_natCast, lt_div_iff₀ (by positivity : (0:ℝ) < (j:ℝ)*x)]
        have h1 : (k:ℝ) * (1/(k:ℝ)) = 1 := by field_simp
        have h2 : (q:ℝ) * ((j:ℝ) * x) = (k:ℝ) * x := by rw [hq]; push_cast; ring
        nlinarith
      · -- 1/(jx) < q+1 ↔ (q+1)*j*x > 1 ↔ (k+j)*x > 1 ↔ x > 1/(k+j)
        rw [Int.cast_natCast]; push_cast
        rw [div_lt_iff₀ (by positivity : (0:ℝ) < (j:ℝ)*x)]
        have h1 : ((j:ℝ)+(k:ℝ)) * (1/((j:ℝ)+(k:ℝ))) = 1 := by field_simp
        have h2 : ((q:ℝ)+1) * ((j:ℝ)*x) = ((k:ℝ)+(j:ℝ)) * x := by rw [hq]; push_cast; ring
        nlinarith
    · -- {1/(kx)} > 0: 1/(kx) ∈ (1, 2)
      apply fract_pos_in_unit
      · rw [one_lt_div (by positivity : (0:ℝ) < (k:ℝ)*x)]
        have : (k:ℝ) * (1/(k:ℝ)) = 1 := by field_simp
        nlinarith
      · rw [div_lt_iff₀ (by positivity : (0:ℝ) < (k:ℝ)*x)]
        -- kx > k/(j+k) ≥ 1/2
        have h1 : (k:ℝ) * (1/((j:ℝ)+(k:ℝ))) = (k:ℝ)/((j:ℝ)+(k:ℝ)) := by ring
        have h2 : (k:ℝ)/((j:ℝ)+(k:ℝ)) ≥ 1/2 := by
          rw [ge_iff_le, div_le_div_iff₀ (by norm_num : (0:ℝ)<2) (by positivity)]
          have : (j:ℝ) < (k:ℝ) := Nat.cast_lt.mpr hjk
          linarith
        nlinarith
  · -- Case j ∤ k: m = ⌈k/j⌉. Use (1/(j*m), 1/k).
    have hmod : k % j ≠ 0 := by intro h; exact hdvd (Nat.dvd_of_mod_eq_zero h)
    have hmod_pos : 0 < k % j := by omega
    have hm_val : ∃ m : ℕ, k < j * m ∧ j * m ≤ j + k ∧ 2 ≤ m := by
      use k / j + 1
      have hd := Nat.div_add_mod k j
      refine ⟨?_, ?_, ?_⟩
      · -- k < j * (k/j + 1): since k = j*(k/j) + k%j and k%j > 0
        have := Nat.mod_lt k (by omega : 0 < j)
        nlinarith [hd]
      · -- j * (k/j + 1) ≤ j + k: since j*(k/j) = k - k%j ≤ k
        have := Nat.mod_lt k (by omega : 0 < j)
        nlinarith [hd]
      · -- 2 ≤ k/j + 1: since k/j ≥ 1 (because k ≥ j+1 > j)
        have := Nat.div_pos (by omega : j ≤ k) (by omega : 0 < j)
        omega
    obtain ⟨m, hjm_gt, hjm_le, hm_ge⟩ := hm_val
    have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
    have hjm_r_pos : (0:ℝ) < (j:ℝ)*(m:ℝ) := by positivity
    have h_lt : 1/((j:ℝ)*(m:ℝ)) < 1/(k:ℝ) :=
      one_div_lt_one_div_of_lt hk_pos (by push_cast; exact_mod_cast hjm_gt)
    refine ⟨1/((j:ℝ)*(m:ℝ)), 1/(k:ℝ), by positivity, h_lt,
            by rw [div_le_one hk_pos]; exact Nat.one_le_cast.mpr hk,
            fun x ⟨hxa, hxb⟩ => ?_⟩
    have hx_pos : (0:ℝ) < x := by linarith [show (0:ℝ) < 1/((j:ℝ)*(m:ℝ)) from by positivity]
    apply mul_pos
    · -- {1/(jx)} > 0: 1/(jx) ∈ (k/j, m) so floor = m-1
      apply fract_pos_between_ints (n := (m:ℤ) - 1)
      · -- (m-1) < 1/(jx) ↔ (m-1)*j*x < 1
        push_cast
        rw [lt_div_iff₀ (by positivity : (0:ℝ) < (j:ℝ)*x)]
        -- (m-1)*j*x < (m-1)*j/k = (j*m - j)/k ≤ 1
        have h1 : (j:ℝ) * (1/(k:ℝ)) = (j:ℝ)/(k:ℝ) := by ring
        have h2 : ((j:ℝ)*(m:ℝ) - (j:ℝ))/(k:ℝ) ≤ 1 := by
          rw [div_le_one hk_pos]
          have : (j:ℝ) * (m:ℝ) ≤ (j:ℝ) + (k:ℝ) := by exact_mod_cast hjm_le
          linarith
        have h3 : (j:ℝ) * x < (j:ℝ) * (1/(k:ℝ)) := by nlinarith
        have hm1 : (m:ℝ) - 1 > 0 := by
          have : (m:ℝ) ≥ 2 := by exact_mod_cast hm_ge
          linarith
        have h4 : ((m:ℝ) - 1) * ((j:ℝ) * x) < ((m:ℝ) - 1) * ((j:ℝ) / (k:ℝ)) := by
          apply mul_lt_mul_of_pos_left _ hm1
          linarith [h1]
        have h5 : ((m:ℝ) - 1) * ((j:ℝ) / (k:ℝ)) = ((j:ℝ)*(m:ℝ) - (j:ℝ)) / (k:ℝ) := by ring
        linarith
      · -- 1/(jx) < m ↔ m*j*x > 1
        push_cast
        rw [div_lt_iff₀ (by positivity : (0:ℝ) < (j:ℝ)*x)]
        ring_nf
        -- m*j*x > m*j*(1/(j*m)) = 1
        have h3 : (j:ℝ) * x > (j:ℝ) * (1/((j:ℝ)*(m:ℝ))) := by nlinarith
        have h4 : (m:ℝ) * ((j:ℝ) * (1/((j:ℝ)*(m:ℝ)))) = 1 := by field_simp
        nlinarith
    · -- {1/(kx)} > 0: x ∈ (1/(j*m), 1/k) ⊂ (1/(2k), 1/k) so 1/(kx) ∈ (1, 2)
      -- 1/(j*m) > 1/(2k) since j*m ≤ j+k ≤ 2k
      have h_x_lb : x > 1/(2*(k:ℝ)) := by
        linarith [show 1/(2*(k:ℝ)) < 1/((j:ℝ)*(m:ℝ)) from
          one_div_lt_one_div_of_lt hjm_r_pos (by
            have : (j:ℝ)*(m:ℝ) ≤ (j:ℝ) + (k:ℝ) := by exact_mod_cast hjm_le
            have : (j:ℝ) < (k:ℝ) := Nat.cast_lt.mpr hjk
            linarith)]
      apply fract_pos_in_unit
      · rw [one_lt_div (by positivity : (0:ℝ) < (k:ℝ)*x)]
        have : (k:ℝ) * (1/(k:ℝ)) = 1 := by field_simp
        nlinarith
      · rw [div_lt_iff₀ (by positivity : (0:ℝ) < (k:ℝ)*x)]
        have : (k:ℝ) * (1/(2*(k:ℝ))) = 1/2 := by field_simp
        nlinarith

-- ════════════════════════════════════════════════════════════════
-- THE INTEGRAL POSITIVITY (general case, by symmetry)
-- ════════════════════════════════════════════════════════════════

private theorem fract_integral_pos (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hjk : j ≠ k) :
    0 < ∫ x in (0:ℝ)..1,
      Int.fract (1 / ((j : ℝ) * x)) * Int.fract (1 / ((k : ℝ) * x)) := by
  rcases Nat.lt_or_gt_of_ne hjk with h | h
  · exact integral_pos_of_lt j k hj hk h
  · -- j > k: swap using mul_comm
    have hsym : (∫ x in (0:ℝ)..1, Int.fract (1/((j:ℝ)*x)) * Int.fract (1/((k:ℝ)*x))) =
                (∫ x in (0:ℝ)..1, Int.fract (1/((k:ℝ)*x)) * Int.fract (1/((j:ℝ)*x))) := by
      congr 1; ext x; exact mul_comm _ _
    rw [hsym]
    exact integral_pos_of_lt k j hk hj h

-- ════════════════════════════════════════════════════════════════
-- THE POSITIVITY THEOREM
-- ════════════════════════════════════════════════════════════════

/-- **GRAM ENTRY POSITIVITY**: G(j,k) > 0 for all j,k ≥ 1. -/
theorem gramEntry_pos (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    0 < vasyuninGramEntry j k := by
  by_cases hjk : j = k
  · subst hjk; exact vasyuninGramEntry_diag_pos j (by omega)
  · rw [IntegralProof.vasyunin_eq_integral_proved j k (by omega) (by omega)]
    exact fract_integral_pos j k hj hk hjk

/-- **GRAVITATIONAL UNIVERSALITY**: G(j,k) ≠ 0 for all j,k ≥ 1. -/
theorem gravitational_universality (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    vasyuninGramEntry j k ≠ 0 :=
  ne_of_gt (gramEntry_pos j k hj hk)

/-- **GRAM ENTRY NONNEG**: G(j,k) ≥ 0 for all j,k ≥ 1. -/
theorem gramEntry_nonneg (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    0 ≤ vasyuninGramEntry j k :=
  le_of_lt (gramEntry_pos j k hj hk)

/-! ## Audit — 0 sorry, 0 axioms, 3 theorems proved. -/

end Cathedral.GravitationalUniversality
