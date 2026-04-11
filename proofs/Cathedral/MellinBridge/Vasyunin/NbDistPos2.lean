/-
  Cathedral/MellinBridge/Vasyunin/NbDistPos2.lean

  **PROOF: Axioms 2 and 3 hold for N = 2.**

  G₂ PD + C₂ PD → b^T G₂⁻¹ b < 1.
  All from 2×2 Sylvester criterion + existing determinant certificates.
  Zero axioms.
-/

import Cathedral.MellinBridge.Vasyunin.CovDet2

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- §1. ENTRY REWRITING
-- ════════════════════════════════════════════════

private theorem g2_entry (i j : Fin 2) :
    (vasyuninGramMatrix 2) i j = vasyuninGramEntry (i.val + 1) (j.val + 1) := by
  simp [vasyuninGramMatrix, of_apply]

private theorem g2_00 : (vasyuninGramMatrix 2) 0 0 = vasyuninGramEntry 1 1 := g2_entry 0 0
private theorem g2_01 : (vasyuninGramMatrix 2) 0 1 = vasyuninGramEntry 1 2 := g2_entry 0 1
private theorem g2_11 : (vasyuninGramMatrix 2) 1 1 = vasyuninGramEntry 2 2 := g2_entry 1 1

-- ════════════════════════════════════════════════
-- §2. G₂ IS POSITIVE DEFINITE
-- ════════════════════════════════════════════════

/-- The 2×2 Gram matrix is Hermitian. -/
private theorem gramMatrix2_hermitian :
    (vasyuninGramMatrix 2).IsHermitian :=
  vasyuninGramMatrix_symmetric 2

/-- G₂(0,0) = G(1,1) > 0. -/
private theorem g2_00_pos : (vasyuninGramMatrix 2) 0 0 > 0 := by
  rw [g2_00]; exact vasyuninGramEntry_diag_pos 1 (by omega)

/-- det(G₂) > 0. -/
private theorem g2_det_pos :
    (vasyuninGramMatrix 2) 0 0 * (vasyuninGramMatrix 2) 1 1 -
    (vasyuninGramMatrix 2) 0 1 ^ 2 > 0 := by
  rw [g2_00, g2_11, g2_01, sq]
  exact vasyuninGram2x2_det_pos

/-- **G₂ is PD** from 2×2 Sylvester. -/
theorem gramMatrix2_posDef :
    (vasyuninGramMatrix 2).PosDef :=
  Cathedral.Variational.sylvester_2x2
    (vasyuninGramMatrix 2) gramMatrix2_hermitian
    g2_00_pos g2_det_pos

-- ════════════════════════════════════════════════
-- §3. C₂ IS POSITIVE DEFINITE
-- ════════════════════════════════════════════════

/-- The 2×2 covariance matrix is Hermitian. -/
private theorem covMatrix2_hermitian :
    (vasyuninCovMatrix 2).IsHermitian := by
  unfold vasyuninCovMatrix Matrix.IsHermitian
  rw [Matrix.conjTranspose_sub]
  congr 1
  · exact vasyuninGramMatrix_symmetric 2
  · funext i j
    simp [Matrix.conjTranspose_apply, star_trivial, vecMulVec, mul_comm]

/-- The covariance entries don't depend on N: C_N(i,j) = C_M(i,j). -/
private theorem covMatrix_entry_independent (N₁ N₂ : ℕ) (i : Fin N₁) (j : Fin N₁)
    (hi : i.val < N₂) (hj : j.val < N₂) :
    (vasyuninCovMatrix N₁) i j =
    (vasyuninCovMatrix N₂) ⟨i.val, hi⟩ ⟨j.val, hj⟩ := by
  simp [vasyuninCovMatrix, vasyuninGramMatrix, vasyuninMeanVec, of_apply,
        vecMulVec, sub_apply]

/-- C₂(0,0) > 0 (same as C₃(0,0)). -/
private theorem covEntry2_00_pos : (vasyuninCovMatrix 2) 0 0 > 0 := by
  rw [covMatrix_entry_independent 2 3 0 0 (by omega) (by omega)]
  exact covEntry_00_pos

/-- det(C₂) > 0, from identical entries in C₃. -/
private theorem covMatrix2_det_pos :
    (vasyuninCovMatrix 2) 0 0 * (vasyuninCovMatrix 2) 1 1 -
    (vasyuninCovMatrix 2) 0 1 ^ 2 > 0 := by
  rw [covMatrix_entry_independent 2 3 0 0 (by omega) (by omega),
      covMatrix_entry_independent 2 3 1 1 (by omega) (by omega),
      covMatrix_entry_independent 2 3 0 1 (by omega) (by omega)]
  exact covMatrix3_det2_pos

/-- **C₂ is PD** from 2×2 Sylvester. -/
theorem covMatrix2_posDef :
    (vasyuninCovMatrix 2).PosDef :=
  Cathedral.Variational.sylvester_2x2
    (vasyuninCovMatrix 2) covMatrix2_hermitian
    covEntry2_00_pos covMatrix2_det_pos

-- ════════════════════════════════════════════════
-- §4. AXIOM 3 FOR N = 2
-- ════════════════════════════════════════════════

/-- C₂ = G₂ - bb^T. -/
private theorem covMatrix2_eq :
    vasyuninCovMatrix 2 =
    vasyuninGramMatrix 2 -
    vecMulVec (vasyuninMeanVec 2) (vasyuninMeanVec 2) := by
  unfold vasyuninCovMatrix; rfl

/-- **AXIOM 3 HOLDS FOR N = 2: b^T G₂⁻¹ b < 1.** -/
theorem nbDistSq_pos_two :
    dotProduct (vasyuninMeanVec 2)
      ((vasyuninGramMatrix 2)⁻¹.mulVec (vasyuninMeanVec 2)) < 1 :=
  Cathedral.Variational.schur_complement_converse
    (vasyuninGramMatrix 2) (vasyuninMeanVec 2)
    gramMatrix2_posDef
    (covMatrix2_eq ▸ covMatrix2_posDef)

end Cathedral.Vasyunin
