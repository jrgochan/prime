/-
  Cathedral/LinearAlgebra/SchurComplement.lean

  ## Schur Complement & Rank-1 Matrix Properties

  Contains:
  - vecMulVec_self_hermitian, vecMulVec_self_posSemidef (rank-1 matrices)
  - schur_complement_posDef: G PD + bᵀG⁻¹b < 1 → C PD
  - schur_complement_converse: G PD + C PD → bᵀG⁻¹b < 1

  All theorems: FULLY PROVED, zero axioms.

  Extracted from Variational.lean (April 11, 2026).
-/

import Cathedral.LinearAlgebra.Variational

noncomputable section
open Matrix Finset

namespace Cathedral.Variational

variable {n : ℕ}

-- ════════════════════════════════════════════════
-- SECTION 1: RANK-1 MATRIX PROPERTIES
-- ════════════════════════════════════════════════

/-- The rank-1 matrix bbᵀ = vecMulVec b b is Hermitian (symmetric over ℝ). -/
theorem vecMulVec_self_hermitian (b : Fin n → ℝ) :
    (vecMulVec b b).IsHermitian := by
  ext i j
  simp [vecMulVec, conjTranspose_apply, star_trivial, mul_comm]

/-- The rank-1 matrix bbᵀ is positive semidefinite.
    Proof: xᵀ(bbᵀ)x = (bᵀx)² ≥ 0. -/
theorem vecMulVec_self_posSemidef (b : Fin n → ℝ) :
    (vecMulVec b b).PosSemidef := by
  refine ⟨vecMulVec_self_hermitian b, fun x => ?_⟩
  simp only [star_trivial, vecMulVec, Matrix.of_apply]
  have h_eq : x.sum (fun i xi => x.sum (fun j xj =>
      xi * (b i * b j) * xj)) =
      (x.sum (fun i xi => xi * b i)) ^ 2 := by
    simp only [sq, Finsupp.sum_mul, mul_assoc]
    congr 1
    ext i
    simp only [← mul_assoc, Finsupp.mul_sum]
    congr 1
    ext j
    ring
  rw [h_eq]
  exact sq_nonneg _

-- ════════════════════════════════════════════════
-- SECTION 2: SCHUR COMPLEMENT (1×1 BLOCK)
-- ════════════════════════════════════════════════

/-- **The Schur Complement Theorem (1×1 top-left block).**

    If G is positive definite and bᵀG⁻¹b < 1, then
    C = G - bbᵀ is positive definite.

    This provides a reduction path for the PosDef axiom:
    - If G is PD (Gram matrix of L² basis functions)
    - And bᵀG⁻¹b < 1 (i.e., d²_N > 0 via Sherman-Morrison)
    - Then C = G - bbᵀ is PD. ∎

    The proof uses our Cauchy-Schwarz result to show that
    (bᵀx)² ≤ (bᵀG⁻¹b)(xᵀGx), so
    xᵀCx = xᵀGx - (bᵀx)² ≥ (1 - bᵀG⁻¹b)·xᵀGx > 0. -/
theorem schur_complement_posDef
    (G : Matrix (Fin n) (Fin n) ℝ)
    (b : Fin n → ℝ)
    (hG : G.PosDef)
    (h_schur : dotProduct b (G⁻¹.mulVec b) < 1) :
    (G - vecMulVec b b).PosDef := by
  -- Step 1: Hermitian
  have h_herm : (G - vecMulVec b b).IsHermitian :=
    hG.isHermitian.sub (vecMulVec_self_hermitian b)
  -- Step 2: Use of_dotProduct_mulVec_pos
  exact Matrix.PosDef.of_dotProduct_mulVec_pos h_herm fun {x} hx => by
    simp only [star_trivial]
    -- We need: 0 < x ⬝ᵥ (G - bbᵀ) *ᵥ x
    rw [Matrix.sub_mulVec, dotProduct_sub]
    -- x ⬝ᵥ G *ᵥ x > 0 (from G PosDef)
    have h_Gx_pos : 0 < dotProduct x (G.mulVec x) := by
      have := hG.dotProduct_mulVec_pos hx
      simpa [star_trivial] using this
    -- x ⬝ᵥ (bbᵀ) *ᵥ x = (b ⬝ᵥ x)²
    have h_bb_eq : dotProduct x ((vecMulVec b b).mulVec x) =
        (dotProduct b x) ^ 2 := by
      have h_mul : (vecMulVec b b).mulVec x = (dotProduct b x) • b := by
        ext i; simp only [mulVec, vecMulVec, dotProduct, Finset.sum_mul,
          Matrix.of_apply, Pi.smul_apply, smul_eq_mul]
        congr 1; ext j; ring
      rw [h_mul, dotProduct_smul, smul_eq_mul]
      rw [show dotProduct x b = dotProduct b x from by
        simp [dotProduct]; congr 1; ext; exact mul_comm _ _]
      ring
    rw [h_bb_eq]
    -- Cauchy-Schwarz: (b ⬝ᵥ x)² / (x ⬝ᵥ Gx) ≤ b ⬝ᵥ G⁻¹b
    have h_unit : IsUnit G.det :=
      G.isUnit_iff_isUnit_det.mp hG.isUnit
    have h_cs := cauchy_schwarz_quadform G b x
      hG.isHermitian hG.posSemidef h_unit h_Gx_pos
    have h_cs_bound : (dotProduct b x) ^ 2 ≤
        dotProduct b (G⁻¹.mulVec b) * dotProduct x (G.mulVec x) := by
      rw [show dotProduct b (G⁻¹.mulVec b) * dotProduct x (G.mulVec x) =
          realQuadForm G x * dotProduct b (G⁻¹.mulVec b) from mul_comm _ _]
      exact h_cs
    nlinarith

/-- **Converse Schur Complement.**
    If G is PD and C = G - bbᵀ is PD, then bᵀG⁻¹b < 1.

    Proof: From C PD, for any nonzero x, xᵀCx > 0.
    Take x = G⁻¹b (nonzero if b ≠ 0).
    Then xᵀGx = bᵀG⁻¹b and bᵀx = bᵀG⁻¹b.
    So bᵀG⁻¹b > (bᵀG⁻¹b)², giving 0 < bᵀG⁻¹b < 1.
    If b = 0 then bᵀG⁻¹b = 0 < 1 trivially. -/
theorem schur_complement_converse
    (G : Matrix (Fin n) (Fin n) ℝ)
    (b : Fin n → ℝ)
    (hG : G.PosDef)
    (hC : (G - vecMulVec b b).PosDef) :
    dotProduct b (G⁻¹.mulVec b) < 1 := by
  by_cases hb : b = 0
  · -- b = 0: bᵀG⁻¹b = 0 < 1
    subst hb
    simp [dotProduct, mulVec]
  · -- b ≠ 0: use C PD on x = G⁻¹b
    set x := G⁻¹.mulVec b
    have hdet : IsUnit G.det := G.isUnit_iff_isUnit_det.mp hG.isUnit
    -- G * G⁻¹ = 1, so G.mulVec (G⁻¹.mulVec b) = b
    have hGx : G.mulVec x = b := by
      simp only [x, Matrix.mulVec_mulVec,
          Matrix.mul_nonsing_inv G hdet, Matrix.one_mulVec]
    -- x ≠ 0 since Gx = b ≠ 0
    have hx_ne : x ≠ 0 := by
      intro hx_eq; rw [hx_eq, Matrix.mulVec_zero] at hGx; exact hb hGx.symm
    -- xᵀCx > 0 (from C PD and x ≠ 0)
    have hCx := hC.dotProduct_mulVec_pos hx_ne
    simp only [star_trivial] at hCx
    -- Expand: xᵀ(G - bbᵀ)x = xᵀGx - (bᵀx)²
    rw [Matrix.sub_mulVec, dotProduct_sub] at hCx
    have h_bb_eq : dotProduct x ((vecMulVec b b).mulVec x) =
        (dotProduct b x) ^ 2 := by
      have h_mul : (vecMulVec b b).mulVec x = (dotProduct b x) • b := by
        ext i; simp only [mulVec, vecMulVec, dotProduct, Finset.sum_mul,
          Matrix.of_apply, Pi.smul_apply, smul_eq_mul]
        congr 1; ext j; ring
      rw [h_mul, dotProduct_smul, smul_eq_mul]
      rw [show dotProduct x b = dotProduct b x from dotProduct_comm x b]
      ring
    rw [h_bb_eq] at hCx
    -- xᵀGx = bᵀx (since Gx = b, xᵀGx = xᵀb = bᵀx)
    have hXGx : dotProduct x (G.mulVec x) = dotProduct b x := by
      rw [hGx]; exact dotProduct_comm x b
    -- Let X = bᵀx = bᵀG⁻¹b
    set X := dotProduct b x
    -- hCx: 0 < xᵀGx - X² = X - X²
    rw [hXGx] at hCx
    -- X - X² > 0 and X > 0 → X < 1
    have hX_pos : 0 < X := by
      have : 0 < X - X ^ 2 := hCx
      nlinarith [sq_nonneg X]
    nlinarith [sq_nonneg X]

end Cathedral.Variational
