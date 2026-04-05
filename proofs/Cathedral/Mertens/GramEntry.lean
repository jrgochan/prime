/-
  Cathedral/Mertens/GramEntry.lean

  ## Per-entry Gram matrix bounds and sum tools.

  Contains:
  - gram_entry_diag_upper (theorem via GramDiag)
  - gram_entry_offdiag_upper (axiom — corrected gcd-based)
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

/-- **AXIOM**: Per-entry Gram upper bound (off-diagonal case).
    G_{j,k} = ∫₀¹ {j/x}·{k/x} dx ≤ 1/4 + gcd(j,k)/(j·k)  for j ≠ k.

    For j ≠ k, the fractional parts {j/x} and {k/x} are approximately
    independent (Weyl equidistribution), so their product integral
    approaches E[{j/x}]·E[{k/x}] = (1/2)·(1/2) = 1/4.
    The correction gcd(j,k)/(jk) accounts for periodicity correlation
    when gcd > 1. Numerically verified for all j,k ≤ 30. -/
axiom gram_entry_offdiag_upper (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hjk : j ≠ k) :
    gramEntry j k ≤ 1 / 4 + (Nat.gcd j k : ℝ) / ((j : ℝ) * (k : ℝ))

/-- Off-diagonal entries are at most 1/3.
    Follows from gramEntry_le_avg_diag (AM-GM) + gramEntry_le_third_all. -/
lemma gram_entry_offdiag_le_third (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hjk : j ≠ k) :
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

/-- **AXIOM** (elementary number theory):
    Σ_{i≠j, Fin n} gcd(i+1,j+1)/((i+1)(j+1)) ≤ 2n.

    Proof sketch: gcd(a,b) ≤ min(a,b), so gcd/(ab) ≤ 1/max(a,b).
    By symmetry, Σ_{i≠j} 1/max = 2·Σ_{i<j} 1/(j+1) = 2·Σ_j j/(j+1) ≤ 2n.
    The exchange-of-summation-order formalization is technically complex. -/
axiom gcd_offdiag_sum_le (n : ℕ) :
    ∑ i : Fin n, ∑ j ∈ Finset.univ.erase i,
      ((Nat.gcd (i.val + 1) (j.val + 1) : ℝ) /
        (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) ≤ 2 * (n : ℝ)

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
