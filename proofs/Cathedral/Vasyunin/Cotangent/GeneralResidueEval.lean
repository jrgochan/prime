/-
  Cathedral/Vasyunin/Cotangent/GeneralResidueEval.lean

  ## GENERALIZED RESIDUE-CLASS EVALUATION — Phase 3-4 of Axiom Graduation

  Generalizes the residue-class decomposition from FractSeriesEval (a=1)
  to general coprime (a,b). The key insight: since gcd(a,b) = 1, the map
  m ↦ am mod b is a permutation of {0,...,b-1}, so the structure is
  identical with permuted weights.

  ### Key Results

  §1. fract_general_residue_class: {a(jb+r)/b} = {ar/b}
  §2. fractCorrection_general_at_residue: unfold at residue class
  §3. fractCorrection_general_zero_at_multiple: vanishes at multiples of b
  §4. partial_sum_residue_decomp_general: partial sum = weighted residue sum
  §5. tsum_fract_general_eq_residue_sum: tsum = finite logΓ + digamma sum

  Created: May 3, 2026 (Phase 3 — Generalized Residue Decomposition)
  Status: PROVED — zero sorry
-/

import Cathedral.Vasyunin.Cotangent.GeneralFractSeriesEval
import Cathedral.Vasyunin.Cotangent.FractSeriesEval

noncomputable section
open Real MeasureTheory Filter Finset
open Cathedral.Vasyunin.FractSeriesEval (inner_sum_limit)

namespace Cathedral.Vasyunin.GeneralResidueEval

-- ════════════════════════════════════════════════
-- §1. FRACT AT GENERAL RESIDUE CLASS
-- ════════════════════════════════════════════════

/-- At residue class m = jb + r, the generalized fract {a·m/b} = {ar/b}.
    This is because a·(jb+r)/b = aj + ar/b, and aj is an integer. -/
lemma fract_general_residue_class (a b : ℕ) (_ha : 1 ≤ a) (hb : 2 ≤ b)
    (r : ℕ) (_hr1 : 1 ≤ r) (_hr2 : r ≤ b - 1) (j : ℕ) :
    Int.fract ((a:ℝ) * ((j * b + r : ℕ):ℝ) / (b:ℝ)) =
    Int.fract ((a:ℝ) * (r:ℝ) / (b:ℝ)) := by
  have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr (by omega)
  have hb_ne : (b:ℝ) ≠ 0 := ne_of_gt hb_pos
  -- Key: a*(jb+r)/b = a*j + a*r/b
  suffices h : (a:ℝ) * ((j * b + r : ℕ):ℝ) / (b:ℝ) =
      (a:ℝ) * (r:ℝ) / (b:ℝ) + ((a * j : ℕ):ℝ) by
    rw [h, Int.fract_add_natCast]
  push_cast; field_simp; ring

-- ════════════════════════════════════════════════
-- §2. UNFOLD AT RESIDUE CLASS
-- ════════════════════════════════════════════════

/-- At residue class m = jb + r, fractCorrection_general(a,b,jb+r) =
    {ar/b} · gap(jb+r). -/
lemma fractCorrection_general_at_residue (a b : ℕ) (ha : 1 ≤ a) (hb : 2 ≤ b)
    (j r : ℕ) (hr1 : 1 ≤ r) (hr2 : r ≤ b - 1) :
    GeneralFractSeriesEval.fractCorrection_general a b (j * b + r) =
    Int.fract ((a:ℝ) * (r:ℝ) / (b:ℝ)) *
      (Real.log ((↑(j * b + r) + 1) / ↑(j * b + r)) -
       1 / (↑(j * b + r) + 1)) := by
  unfold GeneralFractSeriesEval.fractCorrection_general
  rw [fract_general_residue_class a b ha hb r hr1 hr2 j]

-- ════════════════════════════════════════════════
-- §3. ZERO AT MULTIPLES OF b
-- ════════════════════════════════════════════════

/-- fractCorrection_general vanishes at multiples of b, since {a·(jb)/b} = {aj} = 0. -/
lemma fractCorrection_general_zero_at_multiple (a b j : ℕ) (ha : 1 ≤ a) (hb : 2 ≤ b)
    (_hj : 1 ≤ j) :
    GeneralFractSeriesEval.fractCorrection_general a b (j * b) = 0 := by
  unfold GeneralFractSeriesEval.fractCorrection_general
  have hb_ne : (b:ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have h_eq : (a:ℝ) * ((j * b : ℕ):ℝ) / (b:ℝ) = ((a * j : ℕ):ℝ) := by
    push_cast; field_simp
  rw [h_eq, Int.fract_natCast, zero_mul]

-- ════════════════════════════════════════════════
-- §4. PARTIAL SUM RESIDUE DECOMPOSITION (GENERAL a)
-- ════════════════════════════════════════════════

/-- The partial sum at M = Kb-1 decomposes by residue class mod b.
    For general a, the weight {ar/b} replaces r/b from the a=1 case. -/
theorem partial_sum_residue_decomp_general (a b : ℕ) (ha : 1 ≤ a) (hb : 2 ≤ b)
    (K : ℕ) (_hK : 1 ≤ K) :
    ∑ m ∈ range (K * b - 1),
      GeneralFractSeriesEval.fractCorrection_general a b (m + 1) =
    ∑ r ∈ Icc 1 (b - 1), Int.fract ((a:ℝ) * (r:ℝ) / (b:ℝ)) *
      ∑ j ∈ range K,
        (Real.log ((↑(j * b + r) + 1) / ↑(j * b + r)) -
         1 / (↑(j * b + r) + 1)) := by
  have hb_pos : 0 < b := by omega
  -- Split: multiples of b contribute 0
  have h_mult_zero : ∀ m ∈ (range (K * b - 1)).filter
      (fun m => ¬((m + 1) % b ≠ 0)),
      GeneralFractSeriesEval.fractCorrection_general a b (m + 1) = 0 := by
    intro m hm
    simp only [Finset.mem_filter, Finset.mem_range, not_not] at hm
    obtain ⟨j, hj⟩ := Nat.dvd_of_mod_eq_zero hm.2
    rw [hj, mul_comm]
    apply fractCorrection_general_zero_at_multiple a b j ha hb
    rcases j with _ | j
    · simp at hj
    · omega
  suffices h_nonmult :
      ∑ m ∈ (range (K * b - 1)).filter (fun m => (m + 1) % b ≠ 0),
        GeneralFractSeriesEval.fractCorrection_general a b (m + 1) =
      ∑ r ∈ Icc 1 (b - 1), Int.fract ((a:ℝ) * (r:ℝ) / (b:ℝ)) *
        ∑ j ∈ range K,
          (Real.log ((↑(j * b + r) + 1) / ↑(j * b + r)) -
           1 / (↑(j * b + r) + 1)) by
    have h_split := Finset.sum_filter_add_sum_filter_not
      (range (K * b - 1)) (fun m => (m + 1) % b ≠ 0)
      (fun m => GeneralFractSeriesEval.fractCorrection_general a b (m + 1))
    linarith [Finset.sum_eq_zero h_mult_zero]
  -- Bijection: filtered sum = product sum
  have h_bij :
      ∑ m ∈ (range (K * b - 1)).filter (fun m => (m + 1) % b ≠ 0),
        GeneralFractSeriesEval.fractCorrection_general a b (m + 1) =
      ∑ p ∈ (range K) ×ˢ (Icc 1 (b - 1)),
        GeneralFractSeriesEval.fractCorrection_general a b (p.1 * b + p.2) := by
    apply Finset.sum_nbij' (fun m => ((m + 1) / b, (m + 1) % b))
      (fun p : ℕ × ℕ => p.1 * b + p.2 - 1)
    · intro m hm
      simp only [Finset.mem_filter, Finset.mem_range] at hm
      obtain ⟨hm_range, hm_mod⟩ := hm
      have hm_lt : m + 1 < K * b := by omega
      simp only [Finset.mem_product, Finset.mem_range, Finset.mem_Icc]
      exact ⟨Nat.div_lt_of_lt_mul (mul_comm K b ▸ hm_lt),
             by omega, Nat.le_sub_one_of_lt (Nat.mod_lt (m + 1) hb_pos)⟩
    · intro ⟨j, r⟩ hp
      simp only [Finset.mem_product, Finset.mem_range, Finset.mem_Icc] at hp
      obtain ⟨hj, hr1, hr2⟩ := hp
      simp only [Finset.mem_filter, Finset.mem_range]
      have hr_lt : r < b := by omega
      constructor
      · show j * b + r - 1 < K * b - 1
        have hj_le : j + 1 ≤ K := hj
        have : (j + 1) * b ≤ K * b := Nat.mul_le_mul_right b hj_le
        have hj_mul : j * b + b ≤ K * b := by linarith
        omega
      · rw [show j * b + r - 1 + 1 = j * b + r from by omega]
        rw [mul_comm j b, Nat.mul_add_mod, Nat.mod_eq_of_lt hr_lt]
        omega
    · intro m hm
      simp only [Finset.mem_filter, Finset.mem_range] at hm
      obtain ⟨_, hm_mod⟩ := hm
      show ((m + 1) / b) * b + ((m + 1) % b) - 1 = m
      set q := (m + 1) / b
      set r_val := (m + 1) % b
      have h_da : b * q + r_val = m + 1 := Nat.div_add_mod (m + 1) b
      have hr_pos : r_val ≥ 1 := Nat.one_le_iff_ne_zero.mpr hm_mod
      have : q * b = b * q := mul_comm q b
      omega
    · intro ⟨j, r⟩ hp
      simp only [Finset.mem_product, Finset.mem_range, Finset.mem_Icc] at hp
      obtain ⟨hj, hr1, hr2⟩ := hp
      have hr_lt : r < b := by omega
      have h_eq : j * b + r - 1 + 1 = j * b + r := by omega
      ext
      · change (j * b + r - 1 + 1) / b = j
        rw [h_eq, mul_comm j b, Nat.add_comm, Nat.add_mul_div_left _ _ hb_pos,
            Nat.div_eq_of_lt hr_lt, zero_add]
      · change (j * b + r - 1 + 1) % b = r
        rw [h_eq, mul_comm j b, Nat.mul_add_mod, Nat.mod_eq_of_lt hr_lt]
    · intro m hm
      simp only [Finset.mem_filter, Finset.mem_range] at hm
      obtain ⟨_, hm_mod⟩ := hm
      show GeneralFractSeriesEval.fractCorrection_general a b (m + 1) =
        GeneralFractSeriesEval.fractCorrection_general a b
          ((m + 1) / b * b + (m + 1) % b)
      congr 1
      set q := (m + 1) / b
      set r_val := (m + 1) % b
      have h_da : b * q + r_val = m + 1 := Nat.div_add_mod (m + 1) b
      have : q * b = b * q := mul_comm q b
      omega
  -- Unfold at residue class
  have h_expand :
      ∑ p ∈ (range K) ×ˢ (Icc 1 (b - 1)),
        GeneralFractSeriesEval.fractCorrection_general a b (p.1 * b + p.2) =
      ∑ p ∈ (range K) ×ˢ (Icc 1 (b - 1)),
        (Int.fract ((a:ℝ) * (p.2:ℝ) / (b:ℝ)) *
          (Real.log ((↑(p.1 * b + p.2) + 1) / ↑(p.1 * b + p.2)) -
           1 / (↑(p.1 * b + p.2) + 1))) := by
    apply Finset.sum_congr rfl
    intro ⟨j, r⟩ hp
    simp only [Finset.mem_product, Finset.mem_Icc, Finset.mem_range] at hp
    exact fractCorrection_general_at_residue a b ha hb j r hp.2.1 hp.2.2
  rw [h_bij, h_expand]
  rw [Finset.sum_product, Finset.sum_comm]
  congr 1; ext r
  rw [Finset.mul_sum]

-- ════════════════════════════════════════════════
-- §5. TSUM = RESIDUE SUM (GENERAL a)
-- ════════════════════════════════════════════════

/-- **PHASE 3 CORE**: The generalized fract correction tsum equals a finite
    residue-class sum of log-Gamma and digamma values.

    ∑' n, fractCorrection_general(a,b,n+1) =
      Σ_{r=1}^{b-1} {ar/b} · (logΓ(r/b) - logΓ((r+1)/b) + (1/b)·ψ((r+1)/b))

    The only difference from a=1: the weight `r/b` is replaced by `{ar/b}`.
    The inner sum limit (per residue class) is IDENTICAL and reused from
    FractSeriesEval.inner_sum_limit. -/
theorem tsum_fract_general_eq_residue_sum (a b : ℕ) (ha : 1 ≤ a) (hb : 2 ≤ b) :
    ∑' n, GeneralFractSeriesEval.fractCorrection_general a b (n + 1) =
    ∑ r ∈ Icc 1 (b - 1),
      Int.fract ((a:ℝ) * (r:ℝ) / (b:ℝ)) *
        (Real.log (Real.Gamma ((r:ℝ)/(b:ℝ))) -
         Real.log (Real.Gamma (((r:ℝ)+1)/(b:ℝ))) +
         (1/(b:ℝ)) * logDeriv Real.Gamma (((r:ℝ)+1)/(b:ℝ))) := by
  -- Strategy: subsequential limit along M = Kb (same as a=1)
  have hF := GeneralFractSeriesEval.fractCorrection_general_summable a b ha hb
  have h_tendsto := hF.hasSum.tendsto_sum_nat
  set target := ∑ r ∈ Icc 1 (b - 1),
    Int.fract ((a:ℝ) * (r:ℝ) / (b:ℝ)) *
      (Real.log (Real.Gamma ((r:ℝ)/(b:ℝ))) -
       Real.log (Real.Gamma (((r:ℝ)+1)/(b:ℝ))) +
       (1/(b:ℝ)) * logDeriv Real.Gamma (((r:ℝ)+1)/(b:ℝ)))
  -- Subsequence along k*b - 1
  have h_sub : Tendsto (fun k : ℕ => ∑ m ∈ range (k * b - 1),
      GeneralFractSeriesEval.fractCorrection_general a b (m + 1))
      atTop (nhds target) := by
    -- Residue decomposition
    have h_decomp : ∀ᶠ k : ℕ in atTop,
        ∑ m ∈ range (k * b - 1),
          GeneralFractSeriesEval.fractCorrection_general a b (m + 1) =
        ∑ r ∈ Icc 1 (b - 1), Int.fract ((a:ℝ) * (r:ℝ) / (b:ℝ)) *
          ∑ j ∈ range k,
            (Real.log ((↑(j * b + r) + 1) / ↑(j * b + r)) -
             1 / (↑(j * b + r) + 1)) := by
      filter_upwards [Filter.eventually_ge_atTop 1] with k hk
      exact partial_sum_residue_decomp_general a b ha hb k hk
    -- Each inner sum converges (reuse FractSeriesEval.inner_sum_limit)
    have h_rhs_conv : Tendsto (fun k : ℕ =>
        ∑ r ∈ Icc 1 (b - 1), Int.fract ((a:ℝ) * (r:ℝ) / (b:ℝ)) *
          ∑ j ∈ range k,
            (Real.log ((↑(j * b + r) + 1) / ↑(j * b + r)) -
             1 / (↑(j * b + r) + 1))) atTop (nhds target) := by
      simp only [target]
      apply tendsto_finset_sum; intro r hr
      simp only [Finset.mem_Icc] at hr
      exact (inner_sum_limit b hb r hr.1 hr.2).const_mul _
    exact h_rhs_conv.congr' (Filter.EventuallyEq.symm h_decomp)
  -- Subsequence also → tsum
  have h_sub_to_tsum : Tendsto (fun k : ℕ => ∑ m ∈ range (k * b - 1),
      GeneralFractSeriesEval.fractCorrection_general a b (m + 1)) atTop
      (nhds (∑' n, GeneralFractSeriesEval.fractCorrection_general a b (n + 1))) := by
    apply h_tendsto.comp
    apply tendsto_atTop_atTop.mpr
    intro N; exact ⟨N + 1, fun k hk => by
      have h1 : 1 ≤ k := by omega
      have h2 : k ≤ k * b := Nat.le_mul_of_pos_right k (by omega)
      omega⟩
  exact tendsto_nhds_unique h_sub_to_tsum h_sub

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- PROVED (zero sorry):
--   ✅ fract_general_residue_class             — {a(jb+r)/b} = {ar/b}
--   ✅ fractCorrection_general_at_residue      — Unfold at residue class
--   ✅ fractCorrection_general_zero_at_multiple — Vanishes at b-multiples
--   ✅ partial_sum_residue_decomp_general      — Partial sum = residue sum
--   ✅ tsum_fract_general_eq_residue_sum       — Tsum = logΓ + digamma sum
--
-- KEY DEPENDENCY:
--   FractSeriesEval.inner_sum_limit — reused WITHOUT change
--   (The per-residue convergence is independent of a)
--
-- NEXT:
--   Phase 4: Evaluate the weighted sum
--     Σ_{r=1}^{b-1} {ar/b} · (logΓ(r/b) - logΓ((r+1)/b) + (1/b)·ψ((r+1)/b))
--   using the coprime permutation {ar/b} and digamma reflection.

end Cathedral.Vasyunin.GeneralResidueEval
