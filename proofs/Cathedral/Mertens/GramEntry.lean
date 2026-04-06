/-
  Cathedral/Mertens/GramEntry.lean

  ## Per-entry Gram matrix bounds and sum tools.

  Contains:
  - gram_entry_diag_upper (theorem via GramDiag)
  - gram_entry_offdiag_upper (DELETED — proved false, see OffDiagExcess.lean)
  - gram_entry_offdiag_le_third (theorem via AM-GM)
  - gram_entry_upper (unified bound)
  - basis_sum_tight (theorem)
  - sum_inv_sq_le_two (theorem — telescoping)
  - gcd_offdiag_sum_le (axiom — elementary number theory)
  - double_sum_reciprocal (helper)
-/

import Cathedral.Defs
import Cathedral.Structural
import Cathedral.GramBounds
import Cathedral.FractIntegral
import Cathedral.GramDiag
import Cathedral.GramOffDiag
import Cathedral.Mertens.Defs
import Cathedral.Mertens.Harmonic

noncomputable section
open Real MeasureTheory Set Finset Matrix

-- ════════════════════════════════════════════════
-- PER-ENTRY BOUNDS
-- ════════════════════════════════════════════════

/-- **THEOREM** (was axiom): Per-entry Gram upper bound (diagonal case).
    G_{j,j} = ∫₀¹ {j/x}² dx ≤ 1/3 + 1/j².
    See Cathedral.GramDiag for the proof architecture. -/
theorem gram_entry_diag_upper (j : ℕ) (hj : 1 ≤ j) :
    gramEntry j j ≤ 1 / 3 + 1 / ((j : ℝ) ^ 2) := gram_entry_diag_upper' j hj

/- **DELETED AXIOM (2026-04-06)**: gram_entry_offdiag_upper was PROVED FALSE.
    The pointwise bound G_{j,k} ≤ 1/4 + gcd²/(12jk) + 1/(4·max(j,k))
    fails for j ≥ 109, k = j+1 due to the Sawtooth Autocorrelation Floor:
      C_∞ = ∫₀¹ B₂(t)/2 · ψ₁(t+1) dt ≈ 0.00227
    exceeds 1/(4·110) ≈ 0.00227 for adjacent coprime pairs.

    The RH proof now uses an AGGREGATE sum axiom (offdiag_excess_sum_le)
    instead of pointwise per-entry bounds. See OffDiagExcess.lean. -/

/-- Off-diagonal entries are at most 1/3.
    Follows from gramEntry_le_avg_diag (AM-GM) + gramEntry_le_third_all. -/
lemma gram_entry_offdiag_le_third (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (_hjk : j ≠ k) :
    gramEntry j k ≤ 1 / 3 := by
  have h_avg := gramEntry_le_avg_diag j k
  have h1 := gramEntry_le_third_all j hj
  have h2 := gramEntry_le_third_all k hk
  linarith

/-- Unified bound: G_{j,k} ≤ 1/3 + 1/(j·k).
    Diagonal: from gram_entry_diag_upper (1/j² ≤ 1/(jk) when j=k).
    Off-diagonal: from gramEntry_le_third_all since 1/3 ≤ 1/3 + 1/(jk). -/
lemma gram_entry_upper (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    gramEntry j k ≤ 1 / 3 + 1 / ((j : ℝ) * (k : ℝ)) := by
  by_cases hjk : j = k
  · subst hjk
    have h := gram_entry_diag_upper j hj
    rw [show (j : ℝ) ^ 2 = (j : ℝ) * (j : ℝ) from sq (j : ℝ)] at h
    linarith
  · have h := gram_entry_offdiag_le_third j k hj hk hjk
    have : 0 ≤ 1 / ((j : ℝ) * (k : ℝ)) := by positivity
    linarith

-- ════════════════════════════════════════════════
-- SUM BOUNDS
-- ════════════════════════════════════════════════

/-- Helper: The double sum Σᵢ Σⱼ 1/((i+1)(j+1)) = H_{N-1}². -/
lemma double_sum_reciprocal (n : ℕ) :
    ∑ i : Fin n, ∑ j : Fin n,
      (1 / (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1)))
    = harmonicFin n ^ 2 := by
  unfold harmonicFin
  have : ∀ i : Fin n, ∑ j : Fin n,
      (1 / (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1)))
    = (1 / ((i.val : ℝ) + 1)) * ∑ j : Fin n, (1 / ((j.val : ℝ) + 1)) := by
    intro i
    rw [Finset.mul_sum]
    congr 1; ext j
    rw [div_mul_div_comm]; ring_nf
  simp_rw [this]
  rw [← Finset.sum_mul]
  ring

/-- Strengthened bound: Σ_{i=0}^{n-1} 1/(i+1)² ≤ 2 - 1/n.
    Proof by induction using telescoping: 1/(k+1)² ≤ 1/k - 1/(k+1) for k ≥ 1. -/
private lemma sum_inv_sq_le_two_sub (n : ℕ) (hn : 1 ≤ n) :
    ∑ i : Fin n, (1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1))) ≤ 2 - 1 / (n : ℝ) := by
  induction n with
  | zero => omega
  | succ m ih =>
    by_cases hm : m = 0
    · subst hm; simp; norm_num
    · have hm1 : 1 ≤ m := by omega
      rw [Fin.sum_univ_castSucc]
      specialize ih hm1
      have hm_pos : (0 : ℝ) < (m : ℝ) := Nat.cast_pos.mpr (by omega)
      have hm1_pos : (0 : ℝ) < (m : ℝ) + 1 := by linarith
      have h_tele : 1 / (((m : ℝ) + 1) * ((m : ℝ) + 1)) ≤
          1 / (m : ℝ) - 1 / ((m : ℝ) + 1) := by
        have h1 : 1 / (m : ℝ) - 1 / ((m : ℝ) + 1) =
            1 / ((m : ℝ) * ((m : ℝ) + 1)) := by
          field_simp; ring
        rw [h1]
        apply div_le_div_of_nonneg_left (le_of_lt one_pos) (by positivity)
        nlinarith
      have h_last_val : (Fin.last m).val = m := rfl
      simp only [Fin.val_castSucc, h_last_val]
      push_cast
      linarith

/-- Σ_{i=0}^{n-1} 1/(i+1)² ≤ 2 for all n ≥ 1. -/
lemma sum_inv_sq_le_two (n : ℕ) (hn : 1 ≤ n) :
    ∑ i : Fin n, (1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1))) ≤ 2 := by
  have h := sum_inv_sq_le_two_sub n hn
  have : 0 ≤ 1 / (n : ℝ) := by positivity
  linarith


-- ─── Per-term bounds ───

private lemma gcd_le_inv_fst {n : ℕ} (i j : Fin n) :
    (Nat.gcd (i.val + 1) (j.val + 1) : ℝ) /
      (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1)) ≤
    1 / ((i.val : ℝ) + 1) := by
  have hi : (0 : ℝ) < (i.val : ℝ) + 1 := by positivity
  have hj : (0 : ℝ) < (j.val : ℝ) + 1 := by positivity
  rw [div_le_div_iff₀ (mul_pos hi hj) hi, one_mul]
  have : (Nat.gcd (i.val + 1) (j.val + 1) : ℝ) ≤ (j.val : ℝ) + 1 := by
    exact_mod_cast Nat.gcd_le_right (i.val + 1) (by omega : 0 < j.val + 1)
  nlinarith

private lemma gcd_le_inv_snd {n : ℕ} (i j : Fin n) :
    (Nat.gcd (i.val + 1) (j.val + 1) : ℝ) /
      (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1)) ≤
    1 / ((j.val : ℝ) + 1) := by
  have hi : (0 : ℝ) < (i.val : ℝ) + 1 := by positivity
  have hj : (0 : ℝ) < (j.val : ℝ) + 1 := by positivity
  rw [div_le_div_iff₀ (mul_pos hi hj) hj, one_mul]
  have : (Nat.gcd (i.val + 1) (j.val + 1) : ℝ) ≤ (i.val : ℝ) + 1 := by
    exact_mod_cast Nat.gcd_le_left (j.val + 1) (by omega : 0 < i.val + 1)
  nlinarith

-- ─── Ratio sum bound ───

private lemma sum_ratio_le (n : ℕ) :
    ∑ i : Fin n, ((i.val : ℝ) / ((i.val : ℝ) + 1)) ≤ (n : ℝ) := by
  calc ∑ i : Fin n, ((i.val : ℝ) / ((i.val : ℝ) + 1))
      ≤ ∑ _i : Fin n, (1 : ℝ) := by
        apply Finset.sum_le_sum; intro i _
        rw [div_le_one (by positivity : (0:ℝ) < (i.val : ℝ) + 1)]
        linarith [Nat.cast_nonneg (α := ℝ) i.val]
    _ = (n : ℝ) := by simp [Finset.sum_const, Finset.card_univ, Fintype.card_fin]

-- ─── Card of {i : Fin n | i.val < j.val} = j.val ───

private lemma card_lt_j {n : ℕ} (j : Fin n) :
    ((Finset.univ : Finset (Fin n)).filter (fun i : Fin n => i.val < j.val)).card = j.val := by
  -- The elements with val < j.val are exactly the image of Fin.castLE applied to Fin j.val
  have h_eq : (Finset.univ : Finset (Fin n)).filter (fun i => i.val < j.val) =
      (Finset.univ : Finset (Fin j.val)).image (fun k : Fin j.val => ⟨k.val, by omega⟩) := by
    ext i; simp [Finset.mem_filter, Finset.mem_image, Fin.ext_iff]
    constructor
    · intro hi; exact ⟨⟨i.val, hi⟩, rfl⟩
    · rintro ⟨k, hk⟩
      have h1 : k.val < j.val := k.isLt
      have h2 : k.val = i.val := by exact_mod_cast hk
      exact Fin.mk_lt_mk.mpr (by omega)
  rw [h_eq, Finset.card_image_of_injective _ (fun a b h => Fin.ext (by simpa [Fin.ext_iff] using h))]
  simp [Finset.card_univ, Fintype.card_fin]

-- ─── Main theorem ───

set_option maxHeartbeats 800000 in
theorem gcd_offdiag_sum_le (n : ℕ) :
    ∑ i : Fin n, ∑ j ∈ Finset.univ.erase i,
      ((Nat.gcd (i.val + 1) (j.val + 1) : ℝ) /
        (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) ≤ 2 * (n : ℝ) := by
  -- Split erase i into {j < i} ∪ {j > i}
  have h_split : ∀ i : Fin n, Finset.univ.erase i =
      (Finset.univ.filter (fun j : Fin n => j.val < i.val)) ∪
      (Finset.univ.filter (fun j : Fin n => i.val < j.val)) := by
    intro i; ext j; constructor
    · intro hj; simp [Finset.mem_erase] at hj; simp [Finset.mem_filter]; omega
    · intro hj; simp [Finset.mem_filter] at hj; simp [Finset.mem_erase, Fin.ext_iff]; omega
  have h_disj : ∀ i : Fin n, Disjoint
      (Finset.univ.filter (fun j : Fin n => j.val < i.val))
      (Finset.univ.filter (fun j : Fin n => i.val < j.val)) := by
    intro i
    rw [Finset.disjoint_filter]
    intro j _ h1 h2; omega
  -- The main calc chain (inline the term)
  -- The main calc chain (inline the term, don't use set)
  calc ∑ i : Fin n, ∑ j ∈ Finset.univ.erase i,
        ((Nat.gcd (i.val + 1) (j.val + 1) : ℝ) /
          (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1)))
      = ∑ i : Fin n, (∑ j ∈ Finset.univ.filter (fun j : Fin n => j.val < i.val),
            ((Nat.gcd (i.val + 1) (j.val + 1) : ℝ) /
              (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) +
           ∑ j ∈ Finset.univ.filter (fun j : Fin n => i.val < j.val),
            ((Nat.gcd (i.val + 1) (j.val + 1) : ℝ) /
              (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1)))) := by
        congr 1; ext i; rw [h_split i, Finset.sum_union (h_disj i)]
    _ ≤ ∑ i : Fin n, ((i.val : ℝ) / ((i.val : ℝ) + 1) +
              ∑ j ∈ Finset.univ.filter (fun j : Fin n => i.val < j.val),
                (1 / ((j.val : ℝ) + 1))) := by
        apply Finset.sum_le_sum; intro i _
        apply add_le_add
        · -- j < i: each term ≤ 1/(i+1), count = i.val
          calc ∑ j ∈ Finset.univ.filter (fun j : Fin n => j.val < i.val),
                ((Nat.gcd (i.val + 1) (j.val + 1) : ℝ) /
                  (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1)))
              ≤ ∑ _j ∈ Finset.univ.filter (fun j : Fin n => j.val < i.val),
                  (1 / ((i.val : ℝ) + 1)) :=
                Finset.sum_le_sum (fun j _ => gcd_le_inv_fst i j)
            _ = (i.val : ℝ) / ((i.val : ℝ) + 1) := by
                rw [Finset.sum_const, nsmul_eq_mul, card_lt_j i]; ring
        · -- j > i: each term ≤ 1/(j+1)
          exact Finset.sum_le_sum (fun j _ => gcd_le_inv_snd i j)
    _ = ∑ i : Fin n, ((i.val : ℝ) / ((i.val : ℝ) + 1)) +
        ∑ i : Fin n, ∑ j ∈ Finset.univ.filter (fun j : Fin n => i.val < j.val),
          (1 / ((j.val : ℝ) + 1)) := by
        rw [← Finset.sum_add_distrib]
    _ ≤ (n : ℝ) + (n : ℝ) := by
        apply add_le_add (sum_ratio_le n)
        -- Swap summation: Σ_i Σ_{j>i} 1/(j+1) = Σ_j (card{i<j})/(j+1) = Σ_j j/(j+1)
        calc ∑ i : Fin n, ∑ j ∈ Finset.univ.filter (fun j : Fin n => i.val < j.val),
              (1 / ((j.val : ℝ) + 1))
            = ∑ j : Fin n, ∑ i ∈ Finset.univ.filter (fun i : Fin n => i.val < j.val),
                (1 / ((j.val : ℝ) + 1)) := by
              -- Swap: Σ_i Σ_{j ∈ F(i)} g(j) = Σ_j Σ_{i ∈ F'(j)} g(j)
              -- where F(i) = {j | i < j} and F'(j) = {i | i < j}
              apply Finset.sum_comm'
              intro i j; simp [Finset.mem_filter]
          _ = ∑ j : Fin n, ((j.val : ℝ) / ((j.val : ℝ) + 1)) := by
              congr 1; ext j
              rw [Finset.sum_const, nsmul_eq_mul, card_lt_j j]; ring
          _ ≤ (n : ℝ) := sum_ratio_le n
    _ = 2 * (n : ℝ) := by ring



-- ════════════════════════════════════════════════
-- BASIS SUM TIGHT
-- ════════════════════════════════════════════════

/-- **THEOREM**: B(N) ≥ (N-1)/2 - C·log(N).
    Uses basis_entry_lower (from FractIntegral.lean) + harmonicFin_le. -/
theorem basis_sum_tight :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N →
    basisSum N ≥ (N - 1 : ℝ) / 2 - C * Real.log (N : ℝ) := by
  refine ⟨1, one_pos, 3, by omega, fun N hN => ?_⟩
  have h1 : basisSum N ≥
      ∑ i : Fin (N - 1), ((1:ℝ)/2 - 1 / (2 * ((i.val : ℝ) + 1))) := by
    unfold basisSum
    apply Finset.sum_le_sum
    intro i _
    unfold basisInnerProd
    have h := basis_entry_lower (i.val + 1) (by omega)
    show _ ≥ _
    simp only [] at *
    have : ((i.val + 1 : ℕ) : ℝ) = (i.val : ℝ) + 1 := by push_cast; ring
    rw [this]
    convert h using 1 <;> push_cast <;> ring
  have h2 : ∑ i : Fin (N - 1), ((1:ℝ)/2 - 1 / (2 * ((i.val : ℝ) + 1)))
      = (↑(N - 1) : ℝ) / 2 - (1/2) * harmonicFin (N - 1) := by
    unfold harmonicFin
    simp only [Finset.sum_sub_distrib, Fin.sum_const, nsmul_eq_mul]
    ring_nf
    suffices hsuff : ∑ x : Fin (N - 1), (2 + (x.val : ℝ) * 2)⁻¹
        = (1/2) * ∑ x : Fin (N - 1), (1 + (x.val : ℝ))⁻¹ by linarith
    rw [Finset.mul_sum]
    congr 1; ext x
    rw [show (2 : ℝ) + (x.val : ℝ) * 2 = 2 * (1 + (x.val : ℝ)) from by ring]
    rw [_root_.mul_inv_rev, mul_comm]
    norm_num
  have hN1 : 1 ≤ N - 1 := by omega
  have h3 : harmonicFin (N - 1) ≤ 1 + Real.log (N : ℝ) := by
    calc harmonicFin (N - 1) ≤ 1 + Real.log (↑(N - 1)) := harmonicFin_le _ hN1
      _ ≤ 1 + Real.log (N : ℝ) := by
          gcongr
          exact_mod_cast Nat.sub_le N 1
  have hlogN : 1 ≤ Real.log (N : ℝ) := by
    rw [← Real.log_exp 1]
    apply Real.log_le_log (Real.exp_pos 1)
    calc Real.exp 1 ≤ 3 := by
          have := Real.exp_bound' (n := 3) (by norm_num : (0:ℝ) ≤ 1)
            (by norm_num : (1:ℝ) ≤ 1)
          simp [Finset.sum_range_succ] at this; linarith
      _ ≤ (N : ℝ) := by exact_mod_cast hN
  have hNR : (N - 1 : ℝ) = (↑(N - 1) : ℝ) := by
    push_cast [Nat.cast_sub (by omega : 1 ≤ N)]; ring
  calc basisSum N
      ≥ (↑(N - 1) : ℝ) / 2 - (1/2) * harmonicFin (N - 1) := by linarith [h1, h2]
    _ ≥ (↑(N - 1) : ℝ) / 2 - (1/2) * (1 + Real.log (N : ℝ)) := by linarith [h3]
    _ = (↑(N - 1) : ℝ) / 2 - 1/2 - Real.log (N : ℝ) / 2 := by ring
    _ ≥ (N - 1 : ℝ) / 2 - 1 * Real.log (N : ℝ) := by rw [hNR]; linarith

end
