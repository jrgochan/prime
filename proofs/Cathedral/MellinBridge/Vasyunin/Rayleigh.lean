/-
  Cathedral/MellinBridge/Vasyunin/Rayleigh.lean

  The Rayleigh quotient, quadratic form, covariance PD axiom,
  and the Dual Variational Principle.
-/

import Cathedral.MellinBridge.Vasyunin.Structural
import Cathedral.MellinBridge.Vasyunin.Witness
import Cathedral.MellinBridge.Vasyunin.GramInduction

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- PART IX: THE RAYLEIGH QUOTIENT
-- ════════════════════════════════════════════════

/-- The Rayleigh quotient of a test vector v against the covariance:
    Q(v) = (bᵀv)² / (vᵀCv) -/
noncomputable def rayleighQuotient (N : ℕ) (v : Fin N → ℝ) : ℝ :=
  let b := vasyuninMeanVec N
  let C := vasyuninCovMatrix N
  let btv := dotProduct b v
  let vtCv := dotProduct v (C.mulVec v)
  btv ^ 2 / vtCv

/-- The discrete quadratic form X_N = bᵀ C⁻¹ b.
    By Sherman-Morrison: d²_N = 1 / (1 + X_N) -/
noncomputable def vasyuninQuadForm (N : ℕ) : ℝ :=
  dotProduct (vasyuninMeanVec N)
    ((vasyuninCovMatrix N)⁻¹.mulVec (vasyuninMeanVec N))

-- ════════════════════════════════════════════════
-- PART X: THE VARIATIONAL PRINCIPLE (NOW A THEOREM)
-- ════════════════════════════════════════════════

/-- The covariance matrix is symmetric (Hermitian over ℝ). -/
theorem vasyuninCovMatrix_hermitian (N : ℕ) :
    (vasyuninCovMatrix N).IsHermitian := by
  unfold vasyuninCovMatrix Matrix.IsHermitian
  rw [Matrix.conjTranspose_sub]
  congr 1
  · exact vasyuninGramMatrix_symmetric N
  · funext i j
    simp [Matrix.conjTranspose_apply, star_trivial, vecMulVec, mul_comm]

-- ════════════════════════════════════════════════
-- PART X-A: THE GEOMETRY HEIST — AXIOM DECOMPOSITION
--
-- The old opaque axiom `vasyuninCovMatrix_posDef` hid two
-- profound geometric facts. We now expose them separately:
--
-- Axiom 1: "The fractional sawtooth waves {k/x} are linearly
--           independent in L²(0,1)."  → Gram matrix is PD
--
-- Axiom 2: "The constant function 1 cannot be perfectly
--           reconstructed from finitely many sawtooth waves."
--           → Nyman-Beurling distance d²_N > 0
--
-- Together, Schur complement gives C = G - bbᵀ PD. ∎
-- ════════════════════════════════════════════════

/-- **GEOMETRIC FACT 1: The Gram matrix is positive definite.**

    The discrete Vasyunin Gram matrix G_N(j,k) = ∫₀¹ {j/x}{k/x}dx
    is positive definite for N ≥ 3.

    Geometric meaning: The fractional-part basis functions
    {1/x}, {2/x}, ..., {N/x} are linearly independent in L²(0,1).

    FORMERLY AN AXIOM — now proved by induction using:
    - Base case: G₂ PD (Sylvester 2×2 criterion)
    - Inductive step: bordered_matrix_posDef + gramSchurComplement_pos -/
theorem vasyuninGramMatrix_posDef (N : ℕ) (hN : N ≥ 3) :
    (vasyuninGramMatrix N).PosDef :=
  vasyuninGramMatrix_posDef_inductive N (by omega)

/-- **GEOMETRIC AXIOM 2: The NB distance is strictly positive.**

    For any finite truncation N, the constant function 1 is NOT
    in the closed span of {1/x}, ..., {N/x}, i.e., d²_N > 0.

    Equivalently: bᵀG⁻¹b < 1, where b is the mean vector.

    This is unconditionally true for all finite N — the NB
    equivalence says d²_N → 0 iff RH, but d²_N > 0 always.
    In the Gram matrix picture: the projection of 1 onto the
    finite sawtooth subspace always falls short. -/
axiom vasyunin_nbDistSq_pos (N : ℕ) (hN : N ≥ 3) :
    dotProduct (vasyuninMeanVec N)
      ((vasyuninGramMatrix N)⁻¹.mulVec (vasyuninMeanVec N)) < 1

/-- **The covariance matrix is positive definite for N ≥ 3.**
    NOW A THEOREM: derived from the two geometric axioms via
    Schur complement (Variational.lean). -/
theorem vasyuninCovMatrix_posDef (N : ℕ) (hN : N ≥ 3) :
    (vasyuninCovMatrix N).PosDef := by
  unfold vasyuninCovMatrix
  exact Cathedral.Variational.schur_complement_posDef
    (vasyuninGramMatrix N) (vasyuninMeanVec N)
    (vasyuninGramMatrix_posDef N hN) (vasyunin_nbDistSq_pos N hN)

/-- The covariance matrix is positive semidefinite (derived from PosDef). -/
theorem vasyuninCovMatrix_posSemidef (N : ℕ) (hN : N ≥ 3) :
    (vasyuninCovMatrix N).PosSemidef :=
  (vasyuninCovMatrix_posDef N hN).posSemidef

/-- The covariance matrix has invertible determinant (derived from PosDef). -/
theorem vasyuninCovMatrix_isUnit_det (N : ℕ) (hN : N ≥ 3) :
    IsUnit (vasyuninCovMatrix N).det :=
  (vasyuninCovMatrix N).isUnit_iff_isUnit_det.mp (vasyuninCovMatrix_posDef N hN).isUnit

/-- **The Dual Variational Principle — NOW A THEOREM.**
    Derived from abstract Cauchy-Schwarz (Variational.lean). -/
theorem variational_lower_bound (N : ℕ) (hN : N ≥ 3)
    (v : Fin N → ℝ)
    (hv : dotProduct v ((vasyuninCovMatrix N).mulVec v) > 0) :
    rayleighQuotient N v ≤ vasyuninQuadForm N := by
  unfold rayleighQuotient vasyuninQuadForm
  have h_rq : Cathedral.Variational.realQuadForm (vasyuninCovMatrix N) v =
      dotProduct v ((vasyuninCovMatrix N).mulVec v) := rfl
  have h_cs := Cathedral.Variational.cauchy_schwarz_quadform
    (vasyuninCovMatrix N) (vasyuninMeanVec N) v
    (vasyuninCovMatrix_hermitian N) (vasyuninCovMatrix_posSemidef N hN)
    (vasyuninCovMatrix_isUnit_det N hN) (h_rq ▸ hv)
  rw [h_rq] at h_cs
  have h_comm := mul_comm (dotProduct v ((vasyuninCovMatrix N).mulVec v))
    (dotProduct (vasyuninMeanVec N) ((vasyuninCovMatrix N)⁻¹.mulVec (vasyuninMeanVec N)))
  rw [h_comm] at h_cs
  exact div_le_of_le_mul₀ (le_of_lt hv)
    (by nlinarith [h_cs, sq_nonneg (dotProduct (vasyuninMeanVec N) v)])
    h_cs

end Cathedral.Vasyunin
