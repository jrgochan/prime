/-
  Cathedral/Covariance/GCDSignLaw.lean

  ## The Möbius Sign Law for GCD Strata

  Created: May 10, 2026
  Status: All theorems PROVED. Zero admitted steps in this file.
-/

import Cathedral.Covariance.GCDPartition
import Cathedral.Covariance.EulerProduct
import Mathlib.Data.Real.Basic
import Mathlib.Data.Nat.GCD.Basic

noncomputable section
open Real Finset ArithmeticFunction

namespace Cathedral.Covariance.GCDSignLaw

-- ════════════════════════════════════════════════
-- §1. MÖBIUS MULTIPLICATIVITY
-- ════════════════════════════════════════════════

theorem moebius_mul_coprime (a b : ℕ) (hab : Nat.Coprime a b) :
    (moebius (a * b) : ℤ) = (moebius a : ℤ) * (moebius b : ℤ) :=
  IsMultiplicative.map_mul_of_coprime isMultiplicative_moebius hab

theorem moebius_coprime_mul_eq (d a : ℕ) (hcop : Nat.Coprime d a) :
    (moebius (d * a) : ℤ) = (moebius d : ℤ) * (moebius a : ℤ) :=
  moebius_mul_coprime d a hcop

theorem moebius_sq_of_squarefree (d : ℕ) (_hd : 1 ≤ d) (hsq : Squarefree d) :
    ((moebius d : ℤ) : ℝ) ^ 2 = 1 := by
  have h : (moebius d : ℤ) = 1 ∨ (moebius d : ℤ) = -1 := by
    have hne : (moebius d : ℤ) ≠ 0 := by
      rwa [ArithmeticFunction.moebius_ne_zero_iff_squarefree]
    have habs := abs_moebius_le_one (n := d)
    rw [abs_le] at habs; omega
  rcases h with h1 | h1 <;> simp [h1]

-- ════════════════════════════════════════════════
-- §2. GCD ARITHMETIC HELPERS
-- ════════════════════════════════════════════════

theorem inner_sum_zero_of_not_dvd (N d j : ℕ) (_hd : 1 ≤ d)
    (hnd : ¬ d ∣ j) (f : ℕ → ℕ → ℝ) :
    (∑ k ∈ Icc 1 (N - 1),
      if Nat.gcd j k = d then f j k else 0) = 0 := by
  apply Finset.sum_eq_zero; intro k _
  simp only [ite_eq_right_iff]; intro hgcd
  exact absurd (hgcd ▸ Nat.gcd_dvd_left j k) hnd

theorem gcd_mul_left_eq (d a b : ℕ) :
    Nat.gcd (d * a) (d * b) = d * Nat.gcd a b :=
  Nat.gcd_mul_left d a b

theorem gcd_mul_eq_d_iff (d a b : ℕ) (hd : 1 ≤ d) :
    Nat.gcd (d * a) (d * b) = d ↔ Nat.gcd a b = 1 := by
  rw [gcd_mul_left_eq]; constructor
  · intro h
    -- h : d * Nat.gcd a b = d
    -- Since d ≥ 1, cancel d from both sides
    have hd_pos : 0 < d := by omega
    have h2 : d * Nat.gcd a b = d * 1 := by linarith [h, mul_one d]
    exact Nat.eq_of_mul_eq_mul_left hd_pos h2
  · intro h; rw [h, mul_one]

/-- d ∣ k when gcd(d*a, k) = d. -/
private lemma dvd_of_gcd_eq (d a k : ℕ) (h : Nat.gcd (d * a) k = d) : d ∣ k := by
  calc d = Nat.gcd (d * a) k := h.symm
    _ ∣ k := Nat.gcd_dvd_right (d * a) k

-- ════════════════════════════════════════════════
-- §3. SINGLE-SUM REINDEXING
-- ════════════════════════════════════════════════

private lemma inner_sum_reindex (N d a : ℕ) (hd : 1 ≤ d) (f : ℕ → ℝ) :
    (∑ k ∈ Icc 1 (N - 1), if Nat.gcd (d * a) k = d then f k else 0) =
    ∑ b ∈ Icc 1 ((N - 1) / d), if Nat.gcd a b = 1 then f (d * b) else 0 := by
  rw [← Finset.sum_filter, ← Finset.sum_filter]
  -- k ↦ k/d maps LHS → RHS; b ↦ d*b maps RHS → LHS
  apply Finset.sum_nbij' (fun k => k / d) (fun b => d * b)
  -- (hi) k/d ∈ RHS filter
  · intro k hk
    simp only [Finset.mem_filter, mem_Icc] at hk ⊢
    have hdk := dvd_of_gcd_eq d a k hk.2
    constructor
    · constructor
      · exact Nat.div_pos (Nat.le_of_dvd (by omega) hdk) (by omega)
      · exact Nat.div_le_div_right hk.1.2
    · rw [← gcd_mul_eq_d_iff d a (k / d) hd, Nat.mul_div_cancel' hdk]; exact hk.2
  -- (hi') d*b ∈ LHS filter
  · intro b hb
    simp only [Finset.mem_filter, mem_Icc] at hb ⊢
    constructor
    · constructor
      · exact Nat.one_le_iff_ne_zero.mpr (Nat.mul_ne_zero (by omega) (by omega))
      · calc d * b ≤ d * ((N - 1) / d) := Nat.mul_le_mul_left d hb.1.2
          _ ≤ N - 1 := Nat.mul_div_le (N - 1) d
    · rw [gcd_mul_eq_d_iff d a b hd]; exact hb.2
  -- (left_inv) d * b / d = b
  · intro k hk
    simp only [Finset.mem_filter] at hk
    have h1 := Nat.div_mul_cancel (dvd_of_gcd_eq d a k hk.2)
    -- h1 : k / d * d = k, but goal is k / d = (d * (k / d)) / d
    -- Wait, the left_inv goal is: forward (inverse x) = x
    -- forward = (·/d), inverse = (d*·)
    -- So goal: (d * (k/d)) / d = k/d ??? No, that's wrong.
    -- Actually left_inv: inverse (forward x) = x
    -- forward = (·/d), inverse = (d*·)
    -- So goal: d * (k/d) = k
    linarith
  -- (right_inv) (d*b)/d * d... wait, need d * (k/d) = k
  -- Actually: for sum_nbij', right_inv asks: forward ∘ inverse = id
  -- forward = (·/d), inverse = (d*·), so (d*b)/d = b
  · intro b _
    exact Nat.mul_div_cancel_left b (by omega)
  -- (h) value equality
  · intro k hk
    simp only [Finset.mem_filter] at hk
    congr 1
    exact (Nat.mul_div_cancel' (dvd_of_gcd_eq d a k hk.2)).symm

-- ════════════════════════════════════════════════
-- §4. DOUBLE-SUM REINDEXING
-- ════════════════════════════════════════════════

theorem gcd_stratum_reindex (N d : ℕ) (hd : 1 ≤ d) (f : ℕ → ℕ → ℝ) :
    (∑ j ∈ Icc 1 (N - 1), ∑ k ∈ Icc 1 (N - 1),
      if Nat.gcd j k = d then f j k else 0) =
    ∑ a ∈ Icc 1 ((N - 1) / d), ∑ b ∈ Icc 1 ((N - 1) / d),
      if Nat.gcd a b = 1 then f (d * a) (d * b) else 0 := by
  -- Insert d|j filter (non-multiples vanish)
  have h_eq : ∀ j ∈ Icc 1 (N - 1),
      (∑ k ∈ Icc 1 (N - 1), if Nat.gcd j k = d then f j k else 0) =
      if d ∣ j then
        ∑ k ∈ Icc 1 (N - 1), if Nat.gcd j k = d then f j k else 0
      else 0 := by
    intro j _; split_ifs with h; · rfl
    · exact inner_sum_zero_of_not_dvd N d j hd h f
  rw [Finset.sum_congr rfl h_eq, ← Finset.sum_filter]
  -- j ↦ j/d maps LHS → RHS; a ↦ d*a maps RHS → LHS
  apply Finset.sum_nbij' (fun j => j / d) (fun a => d * a)
  -- (hi) j/d ∈ RHS
  · intro j hj
    simp only [Finset.mem_filter, mem_Icc] at hj ⊢
    exact ⟨Nat.div_pos (Nat.le_of_dvd (by omega) hj.2) (by omega),
           Nat.div_le_div_right hj.1.2⟩
  -- (hi') d*a ∈ LHS filter
  · intro a ha
    simp only [Finset.mem_filter, mem_Icc] at ha ⊢
    exact ⟨⟨Nat.one_le_iff_ne_zero.mpr (Nat.mul_ne_zero (by omega) (by omega)),
            le_trans (Nat.mul_le_mul_left d ha.2) (Nat.mul_div_le (N - 1) d)⟩,
           dvd_mul_right d a⟩
  -- (left_inv) (d*a)/d = a
  · intro j hj
    simp only [Finset.mem_filter] at hj
    have h1 := Nat.div_mul_cancel hj.2
    linarith
  -- (right_inv) d * (j/d)... no, forward ∘ inverse = (d*a)/d = a
  · intro a _
    exact Nat.mul_div_cancel_left a (by omega)
  -- (h) value equality
  · intro j hj
    simp only [Finset.mem_filter, mem_Icc] at hj
    -- j = d * (j/d) since d | j (from filter condition)
    have hj_eq : d * (j / d) = j := Nat.mul_div_cancel' hj.2
    conv_lhs => rw [← hj_eq]
    exact inner_sum_reindex N d (j / d) hd (fun k => f (d * (j / d)) k)

-- ════════════════════════════════════════════════
-- §5. SIGN EXTRACTION
-- ════════════════════════════════════════════════

theorem sign_extraction_simplified (N d : ℕ) (hd : 1 ≤ d) (_hN : 2 ≤ N)
    (_hsq : Squarefree d) :
    GCDPartition.untaperedSum_gcd N d =
    ∑ a ∈ Icc 1 ((N - 1) / d), ∑ b ∈ Icc 1 ((N - 1) / d),
      if Nat.gcd a b = 1 then
        ((moebius (d * a) : ℤ) : ℝ) * ((moebius (d * b) : ℤ) : ℝ) *
        Cathedral.Vasyunin.vasyuninGramEntry (d * a) (d * b)
      else 0 := by
  unfold GCDPartition.untaperedSum_gcd
  exact gcd_stratum_reindex N d hd _

-- ════════════════════════════════════════════════
-- §6. EULER PRODUCT POSITIVITY
-- ════════════════════════════════════════════════

theorem leading_term_local_factor_pos (p : ℕ) (hp : Nat.Prime p) :
    localFactor (fun j k => 1 / ((j:ℝ) * (k:ℝ))) p > 0 := by
  rw [trivial_local_factor p (by exact_mod_cast hp.one_le)]
  have hp2 : (2 : ℝ) ≤ (p : ℝ) := by exact_mod_cast hp.two_le
  have : 1 / (p : ℝ) < 1 := by rw [div_lt_one (by linarith : (0:ℝ) < p)]; linarith
  have : 0 < 1 - 1 / (p : ℝ) := by linarith
  exact pow_pos this 2

theorem gcd_term_local_factor_pos (p : ℕ) (hp : Nat.Prime p) :
    localFactor (fun j k => (Nat.gcd j k : ℝ) / ((j:ℝ) * (k:ℝ))) p > 0 := by
  rw [gcd_local_factor p (by exact_mod_cast hp.one_le) hp]
  have hp2 : (2 : ℝ) ≤ (p : ℝ) := by exact_mod_cast hp.two_le
  have : 1 / (p : ℝ) ≤ 1 / 2 := one_div_le_one_div_of_le (by norm_num : (0:ℝ) < 2) hp2
  linarith

end Cathedral.Covariance.GCDSignLaw
