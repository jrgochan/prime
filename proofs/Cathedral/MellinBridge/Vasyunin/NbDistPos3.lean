/-
  Cathedral/MellinBridge/Vasyunin/NbDistPos3.lean

  **PROOF: Axiom 3 holds for N = 3.**

  Proves b^T G₃⁻¹ b < 1 (the NB distance d²₃ > 0) WITHOUT
  using axiom 2 or axiom 3. All ingredients:
  - C₃ PD: Sylvester from CovDet2 + CovDet3 + covEntry_00_pos
  - G₃ PD: Sylvester from GramEntries determinant certificates
  - Converse Schur: G PD + C PD → b^T G⁻¹ b < 1

  Zero axioms. Zero circularity.
-/

import Cathedral.MellinBridge.Vasyunin.CovDet3

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- §1. GRAM MATRIX ENTRY REWRITING LEMMAS
-- ════════════════════════════════════════════════

/-- Rewrite: G₃(i,j) = vasyuninGramEntry (i+1) (j+1). -/
private theorem gram3_entry (i j : Fin 3) :
    (vasyuninGramMatrix 3) i j = vasyuninGramEntry (i.val + 1) (j.val + 1) := by
  simp [vasyuninGramMatrix, of_apply]

-- Concrete entry lemmas for Fin 3
private theorem g3_00 : (vasyuninGramMatrix 3) 0 0 = vasyuninGramEntry 1 1 := gram3_entry 0 0
private theorem g3_01 : (vasyuninGramMatrix 3) 0 1 = vasyuninGramEntry 1 2 := gram3_entry 0 1
private theorem g3_02 : (vasyuninGramMatrix 3) 0 2 = vasyuninGramEntry 1 3 := gram3_entry 0 2
private theorem g3_11 : (vasyuninGramMatrix 3) 1 1 = vasyuninGramEntry 2 2 := gram3_entry 1 1
private theorem g3_12 : (vasyuninGramMatrix 3) 1 2 = vasyuninGramEntry 2 3 := gram3_entry 1 2
private theorem g3_22 : (vasyuninGramMatrix 3) 2 2 = vasyuninGramEntry 3 3 := gram3_entry 2 2

-- ════════════════════════════════════════════════
-- §2. C₃ IS POSITIVE DEFINITE (from Sylvester)
-- ════════════════════════════════════════════════

/-- The 3×3 covariance matrix is Hermitian (symmetric over ℝ). -/
private theorem covMatrix3_hermitian :
    (vasyuninCovMatrix 3).IsHermitian := by
  unfold vasyuninCovMatrix Matrix.IsHermitian
  rw [Matrix.conjTranspose_sub]
  congr 1
  · exact vasyuninGramMatrix_symmetric 3
  · funext i j
    simp [Matrix.conjTranspose_apply, star_trivial, vecMulVec, mul_comm]

/-- **C₃ is Positive Definite.**
    From Sylvester's criterion: covEntry_00_pos, covMatrix3_det2_pos, covMatrix3_det3_pos. -/
theorem covMatrix3_posDef :
    (vasyuninCovMatrix 3).PosDef :=
  Cathedral.Variational.sylvester_3x3
    (vasyuninCovMatrix 3) covMatrix3_hermitian
    covEntry_00_pos covMatrix3_det2_pos covMatrix3_det3_pos

-- ════════════════════════════════════════════════
-- §3. G₃ IS POSITIVE DEFINITE (from Sylvester)
-- ════════════════════════════════════════════════

/-- The 3×3 Gram matrix is Hermitian (symmetric over ℝ). -/
private theorem gramMatrix3_hermitian :
    (vasyuninGramMatrix 3).IsHermitian :=
  vasyuninGramMatrix_symmetric 3

/-- **G₃(0,0) = G(1,1) > 0**. -/
private theorem g3_00_pos : (vasyuninGramMatrix 3) 0 0 > 0 := by
  rw [g3_00]; exact vasyuninGramEntry_diag_pos 1 (by omega)

/-- **Leading 2×2 minor of G₃ has positive determinant.** -/
private theorem g3_det2_pos :
    (vasyuninGramMatrix 3) 0 0 * (vasyuninGramMatrix 3) 1 1 -
    (vasyuninGramMatrix 3) 0 1 ^ 2 > 0 := by
  rw [g3_00, g3_11, g3_01]
  -- Expand: a^2 = a * a
  rw [sq]
  exact vasyuninGram2x2_det_pos

set_option maxHeartbeats 12800000 in
/-- **3×3 determinant of G₃ > 0.** Bridges from GramEntries' closed forms
    to the cofactor expansion form needed by Sylvester.

    Strategy: rewrite G-matrix entries to closed forms, then show the
    cofactor expansion equals the `detExpr` polynomial already proved
    positive in `vasyuninGram3x3_det_pos_closedForm`. -/
private theorem g3_det3_pos :
    (vasyuninGramMatrix 3) 0 0 *
      ((vasyuninGramMatrix 3) 1 1 * (vasyuninGramMatrix 3) 2 2 -
       (vasyuninGramMatrix 3) 1 2 ^ 2) -
    (vasyuninGramMatrix 3) 0 1 *
      ((vasyuninGramMatrix 3) 0 1 * (vasyuninGramMatrix 3) 2 2 -
       (vasyuninGramMatrix 3) 1 2 * (vasyuninGramMatrix 3) 0 2) +
    (vasyuninGramMatrix 3) 0 2 *
      ((vasyuninGramMatrix 3) 0 1 * (vasyuninGramMatrix 3) 1 2 -
       (vasyuninGramMatrix 3) 1 1 * (vasyuninGramMatrix 3) 0 2) > 0 := by
  -- Rewrite entries to GramEntry closed forms
  rw [g3_00, g3_01, g3_02, g3_11, g3_12, g3_22]
  -- Use specific closed-form theorems
  rw [vasyuninGramEntry_one_two, vasyuninGramEntry_one_three,
      vasyuninGramEntry_two_three, vasyuninGramEntry_three_three]
  -- Diagonal entries
  rw [vasyuninGramEntry_diag 1, vasyuninGramEntry_diag 2]
  -- Split log(2π)
  rw [Real.log_mul (by norm_num : (2:ℝ) ≠ 0) (ne_of_gt Real.pi_pos)]
  -- Split log(3/2) = log 3 - log 2
  rw [show Real.log (3/2 : ℝ) = Real.log 3 - Real.log 2 from by
    rw [show (3:ℝ)/2 = 3 * 2⁻¹ from by ring,
        Real.log_mul (by norm_num) (by norm_num : (2:ℝ)⁻¹ ≠ 0),
        Real.log_inv]; ring]
  -- Set variables
  set l := Real.log 2
  set p := Real.log Real.pi
  set g := Real.eulerMascheroniConstant
  set q := Real.log 3
  set t := Real.pi / (18 * Real.sqrt 3)
  -- Normalize π/(36√3) → t/2
  have ht2 : Real.pi / (36 * Real.sqrt 3) = t / 2 := by
    show Real.pi / (36 * Real.sqrt 3) = Real.pi / (18 * Real.sqrt 3) / 2; ring
  rw [ht2]
  -- Normalize 1/2^2 → 1/4
  norm_num
  -- Now the goal should be a polynomial in (l, p, g, q, t)
  -- This is exactly the detExpr polynomial, which we can invoke
  -- Use the existing proof by massaging further
  -- Set A = l + p - g
  set A := l + p - g
  -- The existing proof says detExpr A l q t > 0 where A = ln(2π) - γ
  have h_det := vasyuninGram3x3_det_pos_closedForm
  -- h_det says: let A := ... ; detExpr A l q t > 0
  -- We need to show our goal equals detExpr
  -- Since detExpr is private, we bridge via ring
  simp only [show Real.log (2 * Real.pi) - Real.eulerMascheroniConstant =
    Real.log 2 + Real.log Real.pi - Real.eulerMascheroniConstant from by
    rw [Real.log_mul (by norm_num : (2:ℝ) ≠ 0) (ne_of_gt Real.pi_pos)]] at h_det
  unfold Cathedral.Vasyunin.detExpr at h_det
  -- h_det is now the same polynomial as our goal
  linarith

/-- **G₃ is PD** from Sylvester. -/
theorem gramMatrix3_posDef :
    (vasyuninGramMatrix 3).PosDef :=
  Cathedral.Variational.sylvester_3x3
    (vasyuninGramMatrix 3) gramMatrix3_hermitian
    g3_00_pos g3_det2_pos g3_det3_pos

-- ════════════════════════════════════════════════
-- §4. AXIOM 3 FOR N = 3: b^T G⁻¹ b < 1
-- ════════════════════════════════════════════════

/-- C₃ = G₃ - bb^T (definitional). -/
private theorem covMatrix3_eq :
    vasyuninCovMatrix 3 =
    vasyuninGramMatrix 3 -
    vecMulVec (vasyuninMeanVec 3) (vasyuninMeanVec 3) := by
  unfold vasyuninCovMatrix; rfl

/-- **AXIOM 3 HOLDS FOR N = 3: b^T G₃⁻¹ b < 1.**
    Proved from the converse Schur complement:
    G₃ PD + C₃ PD → b^T G⁻¹ b < 1.
    NO axiom 2, NO axiom 3 used. Pure determinant certificates. -/
theorem nbDistSq_pos_three :
    dotProduct (vasyuninMeanVec 3)
      ((vasyuninGramMatrix 3)⁻¹.mulVec (vasyuninMeanVec 3)) < 1 :=
  Cathedral.Variational.schur_complement_converse
    (vasyuninGramMatrix 3) (vasyuninMeanVec 3)
    gramMatrix3_posDef
    (covMatrix3_eq ▸ covMatrix3_posDef)

end Cathedral.Vasyunin
