/-
  Cathedral/Mertens/GramSum.lean

  ## Gram sum tight bound: Q(N) ≤ (N-1)²/4 + C·N.

  The main theorem gram_sum_tight, with helper lemmas extracted
  from the original monolithic proof for clarity.
-/

import Cathedral.Defs
import Cathedral.Structural
import Cathedral.GramBounds
import Cathedral.GramDiag
import Cathedral.GramOffDiag
import Cathedral.Mertens.Defs
import Cathedral.Mertens.Algebraic
import Cathedral.Mertens.GramEntry

noncomputable section
open Real MeasureTheory Set Finset Matrix

-- ════════════════════════════════════════════════
-- EXTRACTED HELPER LEMMAS
-- ════════════════════════════════════════════════

/-- Off-diagonal Gram matrix entries are at most 1/3. -/
lemma gramMatrix_offdiag_le_third (N : ℕ) (hN3 : 3 ≤ N) :
    ∀ i j : Fin (N - 1), i ≠ j → gramMatrix N i j ≤ 1 / 3 := by
  intros i j hij
  simp only [gramMatrix, Matrix.of_apply]
  exact gram_entry_offdiag_le_third (i.val + 1) (j.val + 1) (by omega) (by omega)
    (by intro h; exact hij (Fin.ext (by omega)))

/-- Diagonal Gram matrix entries satisfy G(i,i) ≤ 1/3 + 1/(i+1)². -/
lemma gramMatrix_diag_upper (N : ℕ) :
    ∀ i : Fin (N - 1),
    gramMatrix N i i ≤ 1 / 3 + 1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1)) := by
  intro i
  simp only [gramMatrix, Matrix.of_apply]
  have h := gram_entry_diag_upper (i.val + 1) (by omega)
  have hcast : ((i.val + 1 : ℕ) : ℝ) = (i.val : ℝ) + 1 := by push_cast; ring
  rw [show ((i.val + 1 : ℕ) : ℝ) ^ 2 = ((i.val : ℝ) + 1) * ((i.val : ℝ) + 1) from by
    rw [hcast]; ring] at h
  linarith

/-- Row sum bound using 1/3 off-diagonal:
    Σ_j G(i,j) ≤ (N-1)/3 + 1/(i+1)². -/
lemma gramMatrix_row_sum_le (N : ℕ) (hN3 : 3 ≤ N) :
    ∀ i : Fin (N - 1),
    ∑ j : Fin (N - 1), gramMatrix N i j ≤
    (N - 1 : ℝ) / 3 + 1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1)) := by
  intro i
  have hentry_offdiag_third := gramMatrix_offdiag_le_third N hN3
  have hentry_diag := gramMatrix_diag_upper N
  calc ∑ j : Fin (N - 1), gramMatrix N i j
      = gramMatrix N i i + ∑ j ∈ Finset.univ.erase i, gramMatrix N i j := by
        rw [← Finset.add_sum_erase _ _ (Finset.mem_univ i)]
    _ ≤ (1 / 3 + 1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1))) +
        ∑ j ∈ Finset.univ.erase i, (1 / 3 : ℝ) := by
        apply add_le_add (hentry_diag i)
        exact Finset.sum_le_sum (fun j hj =>
          hentry_offdiag_third i j (Ne.symm (Finset.ne_of_mem_erase hj)))
    _ = (1 / 3 + 1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1))) +
        (((N - 1 : ℕ) - 1 : ℕ) : ℝ) * (1 / 3) := by
        rw [Finset.sum_const, Finset.card_erase_of_mem (Finset.mem_univ i),
            Finset.card_fin, nsmul_eq_mul]
    _ ≤ (N - 1 : ℝ) / 3 + 1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1)) := by
        have : ((N - 1 : ℕ) - 1 : ℕ) = N - 2 := by omega
        rw [this]
        push_cast [Nat.cast_sub (show 2 ≤ N from by omega)]
        linarith

/-- Off-diagonal Gram matrix entries with gcd bound:
    G(i,j) ≤ 1/4 + gcd(i+1,j+1)/((i+1)(j+1)) for i ≠ j. -/
lemma gramMatrix_offdiag_gcd (N : ℕ) :
    ∀ i j : Fin (N - 1), i ≠ j →
    gramMatrix N i j ≤ 1 / 4 +
      (Nat.gcd (i.val + 1) (j.val + 1) : ℝ) /
        (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1)) := by
  intros i j hij
  simp only [gramMatrix, Matrix.of_apply]
  have hi_ne_j : i.val + 1 ≠ j.val + 1 := by intro h; exact hij (Fin.ext (by omega))
  have h := gram_entry_offdiag_upper (i.val + 1) (j.val + 1) (by omega) (by omega) hi_ne_j
  convert h using 2 <;> push_cast <;> ring

/-- Row sum with gcd-based off-diagonal bound:
    Σ_j G(i,j) ≤ (N-1)/4 + 1/12 + 1/(i+1)² + Σ_{j≠i} gcd/(ij). -/
lemma gramMatrix_row_sum_gcd (N : ℕ) (hN3 : 3 ≤ N) :
    ∀ i : Fin (N - 1),
    ∑ j : Fin (N - 1), gramMatrix N i j ≤
    (N - 1 : ℝ) / 4 + 1 / 12 + 1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1)) +
    ∑ j ∈ Finset.univ.erase i,
      ((Nat.gcd (i.val + 1) (j.val + 1) : ℝ) /
        (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) := by
  intro i
  have hN1 : 1 ≤ N - 1 := by omega
  have hentry_diag := gramMatrix_diag_upper N
  have hentry_offdiag := gramMatrix_offdiag_gcd N
  calc ∑ j : Fin (N - 1), gramMatrix N i j
      = gramMatrix N i i + ∑ j ∈ Finset.univ.erase i, gramMatrix N i j := by
        rw [← Finset.add_sum_erase _ _ (Finset.mem_univ i)]
    _ ≤ (1 / 3 + 1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1))) +
        ∑ j ∈ Finset.univ.erase i,
          (1 / 4 + (Nat.gcd (i.val + 1) (j.val + 1) : ℝ) /
            (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) := by
        apply add_le_add (hentry_diag i)
        exact Finset.sum_le_sum (fun j hj =>
          hentry_offdiag i j (Ne.symm (Finset.ne_of_mem_erase hj)))
    _ = (1 / 3 + 1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1))) +
        ((Finset.univ.erase i).card • (1 / 4 : ℝ) +
          ∑ j ∈ Finset.univ.erase i,
            ((Nat.gcd (i.val + 1) (j.val + 1) : ℝ) /
              (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1)))) := by
        congr 1; rw [Finset.sum_add_distrib, Finset.sum_const]
    _ ≤ (N - 1 : ℝ) / 4 + 1 / 12 + 1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1)) +
        ∑ j ∈ Finset.univ.erase i,
          ((Nat.gcd (i.val + 1) (j.val + 1) : ℝ) /
            (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) := by
        rw [Finset.card_erase_of_mem (Finset.mem_univ i), Finset.card_fin, nsmul_eq_mul]
        have : ((N - 1 : ℕ) - 1 : ℕ) = N - 2 := by omega
        push_cast [this, Nat.cast_sub (show 2 ≤ N from by omega),
                   Nat.cast_sub (show 1 ≤ N from by omega)]
        linarith

-- ════════════════════════════════════════════════
-- MAIN THEOREM
-- ════════════════════════════════════════════════

/-- **THEOREM**: Q(N) ≤ (N-1)²/4 + C·N.
    Uses the gcd-based off-diagonal axiom for the 1/4 structure,
    sum_inv_sq_le_two for Σ 1/(i+1)², and gcd_offdiag_sum_le
    for the pairwise gcd sum. -/
theorem gram_sum_tight :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N →
    gramSum N ≤ (N - 1 : ℝ) ^ 2 / 4 + C * (N : ℝ) := by
  obtain ⟨N_L, hNL, hLogSq⟩ := log_sq_le_self
  refine ⟨5, by norm_num, max N_L 3, by omega, fun N hN => ?_⟩
  have hN3 : 3 ≤ N := by omega
  have hN1 : 1 ≤ N - 1 := by omega
  -- Use extracted lemmas
  have h_row_axiom := gramMatrix_row_sum_gcd N hN3
  -- Sum over all rows
  calc ∑ i : Fin (N - 1), ∑ j : Fin (N - 1), gramMatrix N i j
      ≤ ∑ i : Fin (N - 1), ((N - 1 : ℝ) / 4 + 1 / 12 +
          1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1)) +
          ∑ j ∈ Finset.univ.erase i,
            ((Nat.gcd (i.val + 1) (j.val + 1) : ℝ) /
              (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1)))) :=
        Finset.sum_le_sum (fun i _ => h_row_axiom i)
    _ ≤ (N - 1 : ℝ) ^ 2 / 4 + (N - 1 : ℝ) / 12 + 2 + 2 * (N - 1 : ℝ) := by
        have h_sq_bound : ∑ i : Fin (N - 1),
            (1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1))) ≤ 2 :=
          sum_inv_sq_le_two (N - 1) hN1
        have h_gcd_bound : ∑ i : Fin (N - 1), ∑ j ∈ Finset.univ.erase i,
            ((Nat.gcd (i.val + 1) (j.val + 1) : ℝ) /
              (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) ≤ 2 * (N - 1 : ℝ) := by
          have h := gcd_offdiag_sum_le (N - 1)
          push_cast [Nat.cast_sub (show 1 ≤ N from by omega)] at h
          linarith
        simp only [Finset.sum_add_distrib, Finset.sum_const, Finset.card_fin, nsmul_eq_mul]
        push_cast [Nat.cast_sub (show 1 ≤ N from by omega)]
        linarith
    _ ≤ (N - 1 : ℝ) ^ 2 / 4 + 5 * (N : ℝ) := by
        nlinarith

end
