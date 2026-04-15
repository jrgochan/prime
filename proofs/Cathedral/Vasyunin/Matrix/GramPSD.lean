/-
  Cathedral/Vasyunin/Matrix/GramPSD.lean

  **THE GEOMETRY HEIST — PHASE B**

  Establishes that the Gram matrix G_N is positive semidefinite
  by combining:
  - N ≥ 3: the PosDef geometric axiom (Rayleigh.lean)
  - N < 3: direct computation (empty matrix or diagonal positivity)

  Also introduces the integral bridge axiom connecting the Vasyunin
  discrete formula to the L²(0,1) inner product.

  Status: 1 definitional axiom (integral bridge). gramQuadForm_nonneg
  is NOW A THEOREM (was axiom). vasyuninGramMatrix_posSemidef is proved.
-/

import Cathedral.Vasyunin.Augmented.Rayleigh
import Cathedral.Vasyunin.Matrix.GramEntries
import Cathedral.Vasyunin.Augmented.IntegralBridge
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- §1. THE INTEGRAL BRIDGE AXIOMS
--     (now defined in IntegralBridge.lean, re-exported here)
-- ════════════════════════════════════════════════

-- ════════════════════════════════════════════════
-- §2. GRAM PSD: THEOREM (not axiom!)
--
-- For N ≥ 3: follows from vasyuninGramMatrix_posDef (Rayleigh.lean)
-- For N = 0: trivial (empty matrix)
-- For N = 1: v₀² · G(0,0) ≥ 0 since G(0,0) > 0
-- For N = 2: v₀² G₀₀ + 2·v₀·v₁·G₀₁ + v₁² G₁₁ ≥ 0
--            via completing the square and diagonal positivity
-- ════════════════════════════════════════════════

/-- For N = 0, the quadratic form is trivially zero. -/
private theorem gramQuadForm_nonneg_zero (v : Fin 0 → ℝ) :
    0 ≤ dotProduct v ((vasyuninGramMatrix 0).mulVec v) := by
  simp [dotProduct, Finset.univ_eq_empty]

/-- For N = 1, vᵀGv = v₀² · G(1,1) ≥ 0. -/
private theorem gramQuadForm_nonneg_one (v : Fin 1 → ℝ) :
    0 ≤ dotProduct v ((vasyuninGramMatrix 1).mulVec v) := by
  simp only [dotProduct, mulVec, Fin.sum_univ_one, Fin.isValue,
    vasyuninGramMatrix, of_apply]
  norm_num
  have hG := vasyuninGramEntry_diag_pos 1 (by omega)
  nlinarith [sq_nonneg (v 0)]

/-- det(G₂) > 0: The 2×2 Gram determinant is positive.
    G(1,1)·G(2,2) - G(1,2)² > 0.
    Numerical: 0.2607·0.3803 - 0.2722² ≈ 0.0251 > 0.
    PROVED in GramEntries.lean (vasyuninGram2x2_det_pos). -/
theorem gramDet2_pos :
    vasyuninGramEntry 1 1 * vasyuninGramEntry 2 2 -
    vasyuninGramEntry 1 2 ^ 2 > 0 := by
  have h := vasyuninGram2x2_det_pos
  -- vasyuninGram2x2_det_pos uses a*a, we need a^2
  have hsq : vasyuninGramEntry 1 2 ^ 2 =
      vasyuninGramEntry 1 2 * vasyuninGramEntry 1 2 := sq (vasyuninGramEntry 1 2)
  linarith

/-- For N = 2, vᵀGv ≥ 0.
    Proof: Complete the square using G(1,1) > 0 and det(G₂) > 0. -/
private theorem gramQuadForm_nonneg_two (v : Fin 2 → ℝ) :
    0 ≤ dotProduct v ((vasyuninGramMatrix 2).mulVec v) := by
  simp only [dotProduct, mulVec, Fin.sum_univ_two, Fin.isValue,
    vasyuninGramMatrix, of_apply]
  -- Reduce ↑0 + 1 = 1, ↑1 + 1 = 2
  norm_num
  -- G(2,1) = G(1,2) by symmetry
  rw [vasyuninGramEntry_comm 2 1]
  -- Now: 0 ≤ v0*(G11*v0 + G12*v1) + v1*(G12*v0 + G22*v1)
  set a := vasyuninGramEntry 1 1
  set b := vasyuninGramEntry 1 2
  set c := vasyuninGramEntry 2 2
  have ha : a > 0 := vasyuninGramEntry_diag_pos 1 (by omega)
  have hdet : a * c - b ^ 2 > 0 := gramDet2_pos
  nlinarith [sq_nonneg (a * v 0 + b * v 1), sq_nonneg (v 1), ha, hdet]

/-- **The Gram quadratic form is non-negative — NOW A THEOREM.**

    For N ≥ 3: from vasyuninGramMatrix_posDef (PD → PSD → nonneg)
    For N < 3: direct computation -/
theorem gramQuadForm_nonneg (N : ℕ) (v : Fin N → ℝ) :
    0 ≤ dotProduct v ((vasyuninGramMatrix N).mulVec v) := by
  by_cases hN : N ≥ 3
  · -- N ≥ 3: PD implies nonneg quadratic form
    have hPSD := (vasyuninGramMatrix_posDef N hN).posSemidef
    have := hPSD.dotProduct_mulVec_nonneg v
    simpa [star_trivial] using this
  · -- N < 3: case split on 0, 1, 2
    push Not at hN
    interval_cases N
    · -- N = 0
      exact gramQuadForm_nonneg_zero v
    · -- N = 1
      exact gramQuadForm_nonneg_one v
    · -- N = 2
      exact gramQuadForm_nonneg_two v

/-- **THE GRAM MATRIX IS POSITIVE SEMIDEFINITE.**
    Direct consequence of the quadratic form being non-negative. -/
theorem vasyuninGramMatrix_posSemidef (N : ℕ) :
    (vasyuninGramMatrix N).PosSemidef :=
  Matrix.PosSemidef.of_dotProduct_mulVec_nonneg
    (vasyuninGramMatrix_symmetric N) fun x => by
      simp only [star_trivial]
      exact gramQuadForm_nonneg N x

/-- The Gram matrix has positive diagonal (direct from the formula). -/
theorem vasyuninGramMatrix_diag_pos' (N : ℕ) (i : Fin N) :
    0 < vasyuninGramMatrix N i i :=
  vasyuninGramMatrix_diag_pos N i

/-- Every diagonal entry of a PSD matrix is non-negative. -/
theorem vasyuninGramMatrix_diag_nonneg (N : ℕ) (i : Fin N) :
    0 ≤ vasyuninGramMatrix N i i :=
  (vasyuninGramMatrix_posSemidef N).diag_nonneg

end Cathedral.Vasyunin
