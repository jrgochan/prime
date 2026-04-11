/-
  Cathedral/MellinBridge/Vasyunin/AugmentedGram.lean

  **THE AUGMENTED GRAM MATRIX — THE ULTIMATE MATRIX**

  H_N = [1,    bᵀ  ]     (Gram matrix of {1, f_1, ..., f_N})
        [b,    G_N ]

  where b is the mean vector and G_N is the Gram matrix.

  Key properties (all proven, zero sorry):
  - H_N PD implies G_N PD (trailing principal submatrix, §6b)
  - H_N PD implies bᵀG⁻¹b < 1 (witness vector w=(1,-G⁻¹b), §7)

  This file unifies gramSchurComplement_pos and vasyunin_nbDistSq_pos
  into a single axiom: augmentedSchurComplement_pos.

  Status: 1 axiom (augmentedSchurComplement_pos), replaces 2 axioms.
  All other content: zero sorry, zero axioms.

  Created April 11, 2026.
-/

import Cathedral.MellinBridge.Vasyunin.CovDet3
import Cathedral.LinearAlgebra.Sylvester

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- §1. THE AUGMENTED GRAM MATRIX
-- ════════════════════════════════════════════════

/-- **The augmented Gram matrix H_N.**

    H_N = [1,    bᵀ  ]
          [b,    G_N ]

    This is the Gram matrix of {1, f_1, ..., f_N} in L²(0,1),
    where f_k(x) = {k/x} is the fractional-part sawtooth function.

    Index 0 corresponds to the constant function 1.
    Indices 1..N correspond to f_1, ..., f_N. -/
noncomputable def augmentedGramMatrix (N : ℕ) : Matrix (Fin (N+1)) (Fin (N+1)) ℝ :=
  Matrix.of fun i j =>
    if i.val = 0 ∧ j.val = 0 then
      1  -- ⟨1, 1⟩ = ∫₀¹ 1 dx = 1
    else if i.val = 0 then
      vasyuninMeanEntry j.val  -- ⟨1, f_j⟩ = b_j
    else if j.val = 0 then
      vasyuninMeanEntry i.val  -- ⟨f_i, 1⟩ = b_i
    else
      vasyuninGramEntry i.val j.val  -- ⟨f_i, f_j⟩ = G(i,j)

-- ════════════════════════════════════════════════
-- §2. STRUCTURAL PROPERTIES
-- ════════════════════════════════════════════════

/-- H_N is symmetric (Hermitian over ℝ). -/
theorem augmentedGramMatrix_symmetric (N : ℕ) :
    (augmentedGramMatrix N).IsHermitian := by
  ext i j
  simp only [augmentedGramMatrix, conjTranspose_apply, star_trivial, of_apply]
  by_cases hi : i.val = 0 <;> by_cases hj : j.val = 0 <;> simp_all [vasyuninGramEntry_comm]

/-- The top-left entry of H_N is 1. -/
theorem augmented_corner_eq (N : ℕ) :
    augmentedGramMatrix N ⟨0, Nat.zero_lt_succ N⟩ ⟨0, Nat.zero_lt_succ N⟩ = 1 := by
  simp [augmentedGramMatrix, of_apply]

/-- The leading N×N submatrix of H_{N+1} is H_N. -/
theorem augmented_bordered_eq (N : ℕ) (i j : Fin (N+1)) :
    (augmentedGramMatrix (N+1)) (Fin.castSucc i) (Fin.castSucc j) =
    (augmentedGramMatrix N) i j := by
  simp only [augmentedGramMatrix, of_apply, Fin.castSucc, Fin.val_castAdd]

/-- The border vector of H_{N+1} at the last column. -/
theorem augmented_border_eq (N : ℕ) (i : Fin (N+1)) :
    (augmentedGramMatrix (N+1)) (Fin.castSucc i) (Fin.last (N+1)) =
    if i.val = 0 then vasyuninMeanEntry (N+1)
    else vasyuninGramEntry i.val (N+1) := by
  simp only [augmentedGramMatrix, of_apply, Fin.castSucc, Fin.last]
  by_cases hi : i.val = 0 <;> simp_all

/-- The corner entry of H_{N+1} is GramEntry(N+1, N+1). -/
theorem augmented_last_eq (N : ℕ) :
    (augmentedGramMatrix (N+1)) (Fin.last (N+1)) (Fin.last (N+1)) =
    vasyuninGramEntry (N+1) (N+1) := by
  simp [augmentedGramMatrix, of_apply, Fin.last]

-- ════════════════════════════════════════════════
-- §3. THE SINGLE AXIOM
-- ════════════════════════════════════════════════

/-- **THE AUGMENTED SCHUR COMPLEMENT POSITIVITY.**

    For any N ≥ 1, f_{N+1} has strictly positive distance from
    the augmented subspace span{1, f_1, ..., f_N} in L²(0,1).

    This is the Schur complement of H_{N+1} relative to H_N:
      GramEntry(N+1,N+1) - hᵀ H_N⁻¹ h > 0

    where h is the border vector [b_{N+1}, G(1,N+1), ..., G(N,N+1)].

    **Geometric proof**: f_{N+1} = {(N+1)/x} has a jump discontinuity
    at x = (N+1)/(N+2) that is NOT shared by:
    - The constant function 1 (continuous everywhere)
    - Any f_k with k ≤ N (no discontinuity at that point)

    Since a continuous function plus smooth combinations cannot
    produce a jump discontinuity, f_{N+1} ∉ span{1, f_1, ..., f_N}.

    This single axiom subsumes both:
    - gramSchurComplement_pos (f_{N+1} ∉ span{f_1,...,f_N})
    - vasyunin_nbDistSq_pos (1 ∉ span{f_1,...,f_N})

    The first is weaker (smaller span). The second follows from
    H_N PD via the Schur complement with respect to G_N. -/
axiom augmentedSchurComplement_pos (N : ℕ) (hN : N ≥ 1) :
    let H := augmentedGramMatrix N
    let h := fun i : Fin (N+1) =>
      (augmentedGramMatrix (N+1)) (Fin.castSucc i) (Fin.last (N+1))
    vasyuninGramEntry (N+1) (N+1) -
    dotProduct h (H⁻¹.mulVec h) > 0

-- ════════════════════════════════════════════════
-- §4. THE INDUCTIVE PROOF: H_N PD FOR ALL N
-- ════════════════════════════════════════════════

/-- **THE INDUCTIVE STEP: H_N PD → H_{N+1} PD.** -/
theorem augmented_posDef_step (N : ℕ) (hN : N ≥ 1)
    (hHN : (augmentedGramMatrix N).PosDef) :
    (augmentedGramMatrix (N + 1)).PosDef := by
  apply Cathedral.Variational.bordered_matrix_posDef
    (augmentedGramMatrix (N+1))
    (augmentedGramMatrix_symmetric (N+1))
    (augmentedGramMatrix N)
    (augmented_bordered_eq N)
    hHN
    (fun i => (augmentedGramMatrix (N+1)) (Fin.castSucc i) (Fin.last (N+1)))
    (fun i => rfl)
  -- Schur complement > 0
  simp only [augmentedGramMatrix, of_apply, Fin.last]
  exact augmentedSchurComplement_pos N hN

-- ════════════════════════════════════════════════
-- §5. BASE CASE: H_1 PD (1×1 Gram matrix of {1, f_1})
-- ════════════════════════════════════════════════

-- H_1 = [1,    b_1  ]   is 2×2 with
--        [b_1,  G(1,1)]
-- PD iff 1 > 0 AND G(1,1) - b_1² > 0
-- i.e., G(1,1) > b_1² (positive diagonal dominance)

/-- H_1 is PD: The 2×2 augmented Gram matrix.
    H_1 = [[1, b₁], [b₁, G(1,1)]]
    Uses the 2×2 Sylvester criterion: H(0,0) = 1 > 0 and det = G(1,1) - b₁² > 0.
    The determinant equals the covariance entry C(0,0), proved positive in CovEntries.lean. -/
theorem augmented1_posDef :
    (augmentedGramMatrix 1).PosDef := by
  apply Cathedral.Variational.sylvester_2x2
  · exact augmentedGramMatrix_symmetric 1
  · -- H_1(0,0) = 1 > 0
    simp [augmentedGramMatrix, of_apply]
  · -- det > 0: 1 * G(1,1) - b_1² > 0
    simp only [augmentedGramMatrix, of_apply]
    norm_num
    -- Need: vasyuninGramEntry 1 1 - vasyuninMeanEntry 1 * vasyuninMeanEntry 1 > 0
    -- This is exactly covEntry_00_pos (for the covariance matrix at index (0,0))
    -- C(0,0) = G(1,1) - b₁² > 0
    have h_cov : (vasyuninCovMatrix 3) 0 0 > 0 := covEntry_00_pos
    rw [covEntry_00] at h_cov
    -- covEntry_00: C(0,0) = log(2π) - γ - 1 - (1-γ)²
    -- We need: G(1,1) - b₁·b₁ > 0
    -- G(1,1) = log(2π) - γ - 1, b₁ = 1 - γ
    rw [vasyuninGramEntry_one_one, vasyuninMeanEntry_one]
    -- Now goal is: log(2π) - γ - 1 - (1 - γ) * (1 - γ) > 0
    -- Which is: log(2π) - γ - 1 - (1-γ)² > 0 = covEntry_00_pos
    nlinarith [sq_nonneg (1 - Real.eulerMascheroniConstant)]

-- ════════════════════════════════════════════════
-- §6. THE FULL THEOREM
-- ════════════════════════════════════════════════

/-- **THEOREM: H_N is positive definite for all N ≥ 1.**

    Proved by induction:
    - Base: H_1 PD (2×2 Sylvester criterion)
    - Step: H_N PD → H_{N+1} PD (bordered + augmentedSchurComplement_pos)

    Consequences:
    - G_N PD (leading submatrix of H_N)
    - C_N PD (Schur complement w.r.t. 1×1 block)
    - bᵀG⁻¹b < 1 (Schur complement w.r.t. G_N block) -/
theorem augmentedGramMatrix_posDef (N : ℕ) (hN : N ≥ 1) :
    (augmentedGramMatrix N).PosDef := by
  induction N with
  | zero => omega
  | succ n ih =>
    by_cases hn0 : n = 0
    · subst hn0; exact augmented1_posDef
    · have hn_ge_1 : n ≥ 1 := by omega
      exact augmented_posDef_step n hn_ge_1 (ih hn_ge_1)
-- ════════════════════════════════════════════════
-- §6b. CONSEQUENCE: G_N PD FROM H_N PD
-- ════════════════════════════════════════════════

-- G_N is the trailing N×N submatrix of H_N (indices 1..N).
-- For any x : Fin N → ℝ, set w = (0, x) ∈ ℝᴺ⁺¹.
-- Then wᵀH_Nw = xᵀG_Nx (all cross terms vanish because w(0)=0).

/-- Embed x ∈ ℝᴺ into ℝᴺ⁺¹ as (0, x). -/
private noncomputable def embedGram (N : ℕ) (x : Fin N → ℝ) : Fin (N+1) → ℝ :=
  Fin.cons 0 x

/-- (0, x) ≠ 0 when x ≠ 0. -/
private theorem embedGram_ne_zero (N : ℕ) (x : Fin N → ℝ) (hx : x ≠ 0) :
    embedGram N x ≠ 0 := by
  intro hw
  apply hx
  funext i
  have := congr_fun hw (Fin.succ i)
  simp [embedGram, Fin.cons] at this
  exact this

/-- **THE QUADRATIC FORM IDENTITY: (0,x)ᵀ H_N (0,x) = xᵀ G_N x.** -/
private theorem gram_quadform_eq (N : ℕ) (x : Fin N → ℝ) :
    dotProduct (embedGram N x) ((augmentedGramMatrix N).mulVec (embedGram N x)) =
    dotProduct x ((vasyuninGramMatrix N).mulVec x) := by
  simp only [dotProduct, mulVec]
  rw [Fin.sum_univ_succ]
  simp only [embedGram, Fin.cons_zero, zero_mul, zero_add]
  apply Finset.sum_congr rfl
  intro i _
  simp only [Fin.cons_succ]
  congr 1
  rw [Fin.sum_univ_succ]
  simp only [Fin.cons_zero, mul_zero, zero_add]
  simp only [Fin.cons_succ]
  apply Finset.sum_congr rfl
  intro j _
  simp only [augmentedGramMatrix, of_apply, Fin.val_succ]
  have hi : ¬ (i.val + 1 = 0) := by omega
  have hj : ¬ (j.val + 1 = 0) := by omega
  simp only [hi, hj, ↓reduceIte, and_self]
  simp [vasyuninGramMatrix, of_apply]

/-- **THEOREM: G_N is positive definite for all N ≥ 1.**

    Derived from augmentedGramMatrix_posDef.
    G_N is the trailing submatrix of H_N, so for any nonzero x,
    xᵀG_Nx = (0,x)ᵀH_N(0,x) > 0 (since H_N PD and (0,x) ≠ 0).

    This ELIMINATES gramSchurComplement_pos for deriving G_N PD. -/
theorem gramMatrix_posDef_from_augmented (N : ℕ) (hN : N ≥ 1) :
    (vasyuninGramMatrix N).PosDef := by
  have hH := augmentedGramMatrix_posDef N hN
  refine PosDef.of_dotProduct_mulVec_pos (vasyuninGramMatrix_symmetric N) fun {x} hx => ?_
  simp only [star_trivial]
  rw [← gram_quadform_eq N x]
  have h := hH.dotProduct_mulVec_pos (embedGram_ne_zero N x hx)
  simpa [star_trivial] using h

-- ════════════════════════════════════════════════
-- §7. CONSEQUENCE: bᵀG⁻¹b < 1 FROM H_N PD
-- ════════════════════════════════════════════════

-- The proof uses a specific witness vector w = (1, -G⁻¹b).
-- Key identity: wᵀH_Nw = 1 - bᵀG⁻¹b.
-- Since H_N PD and w ≠ 0, we get 1 - bᵀG⁻¹b > 0, i.e., bᵀG⁻¹b < 1.

set_option maxHeartbeats 1600000

/-- G⁻¹b vector. -/
private noncomputable def nbGinvb (N : ℕ) : Fin N → ℝ :=
  (vasyuninGramMatrix N)⁻¹.mulVec (vasyuninMeanVec N)

/-- The witness vector w = (1, -G⁻¹b) ∈ ℝᴺ⁺¹. -/
private noncomputable def nbWitness (N : ℕ) : Fin (N+1) → ℝ :=
  Fin.cons 1 (fun k => -(nbGinvb N k))

/-- w ≠ 0 since w(0) = 1 ≠ 0. -/
private theorem nbWitness_ne_zero (N : ℕ) : nbWitness N ≠ 0 := by
  intro hw
  have : nbWitness N 0 = 0 := congr_fun hw 0
  simp [nbWitness, Fin.cons] at this

/-- G · G⁻¹b = b (invertibility of G). -/
private theorem G_mul_nbGinvb (N : ℕ) (hG : (vasyuninGramMatrix N).PosDef) :
    (vasyuninGramMatrix N).mulVec (nbGinvb N) = vasyuninMeanVec N := by
  have hdet : IsUnit (vasyuninGramMatrix N).det :=
    (vasyuninGramMatrix N).isUnit_iff_isUnit_det.mp hG.isUnit
  simp only [nbGinvb, Matrix.mulVec_mulVec,
    Matrix.mul_nonsing_inv _ hdet, Matrix.one_mulVec]

/-- **THE QUADRATIC FORM IDENTITY: wᵀH_Nw = 1 - bᵀG⁻¹b.**

    Proved by expanding the double sum over Fin(N+1), splitting at index 0,
    and using G · G⁻¹b = b to show the tail vanishes. -/
private theorem quadform_eq (N : ℕ)
    (hG : (vasyuninGramMatrix N).PosDef) :
    dotProduct (nbWitness N) ((augmentedGramMatrix N).mulVec (nbWitness N)) =
    1 - dotProduct (vasyuninMeanVec N) (nbGinvb N) := by
  simp only [dotProduct, mulVec]
  rw [Fin.sum_univ_succ]
  have h_w0 : nbWitness N 0 = 1 := by simp [nbWitness, Fin.cons]
  -- Inner sum at i=0
  have h_inner0 : ∑ j : Fin (N+1), (augmentedGramMatrix N) 0 j * nbWitness N j =
      1 - dotProduct (vasyuninMeanVec N) (nbGinvb N) := by
    rw [Fin.sum_univ_succ]
    simp only [augmentedGramMatrix, of_apply, Fin.val_zero, Fin.val_succ]
    simp only [nbWitness, Fin.cons_zero, Fin.cons_succ]
    simp only [true_and, Nat.add_one_ne_zero, ↓reduceIte]
    simp only [dotProduct, vasyuninMeanVec, nbGinvb]
    ring_nf
    rw [Finset.sum_neg_distrib]
    ring
  rw [h_w0, one_mul, h_inner0]
  -- Tail sum = 0
  suffices h_tail :
      ∑ i : Fin N, nbWitness N (Fin.succ i) *
      ∑ j : Fin (N+1), (augmentedGramMatrix N) (Fin.succ i) j * nbWitness N j = 0 by
    simp only [dotProduct] at h_tail ⊢
    linarith
  apply Finset.sum_eq_zero
  intro i _
  suffices h_zero :
      ∑ j : Fin (N+1), (augmentedGramMatrix N) (Fin.succ i) j * nbWitness N j = 0 by
    rw [h_zero, mul_zero]
  rw [Fin.sum_univ_succ]
  simp only [augmentedGramMatrix, of_apply, Fin.val_succ, Fin.val_zero,
    Fin.cons_succ, nbWitness, Fin.cons_zero]
  have hi : ¬ (i.val + 1 = 0) := by omega
  simp only [hi, false_and, ↓reduceIte, Nat.add_one_ne_zero]
  have hGg := G_mul_nbGinvb N hG
  have hGg_i : (vasyuninGramMatrix N).mulVec (nbGinvb N) i = vasyuninMeanVec N i :=
    congr_fun hGg i
  simp only [mulVec, dotProduct, vasyuninGramMatrix, of_apply, vasyuninMeanVec] at hGg_i
  rw [mul_one]
  have h_neg : ∑ x : Fin N, vasyuninGramEntry (i.val + 1) (x.val + 1) * -nbGinvb N x =
      -∑ x : Fin N, vasyuninGramEntry (i.val + 1) (x.val + 1) * nbGinvb N x := by
    rw [← Finset.sum_neg_distrib]
    apply Finset.sum_congr rfl
    intro j _
    ring
  rw [h_neg, hGg_i]
  ring

/-- **THEOREM: bᵀG⁻¹b < 1 for all N ≥ 1.**

    Derived from augmentedGramMatrix_posDef via the witness vector w = (1, -G⁻¹b).
    The quadratic form wᵀH_Nw = 1 - bᵀG⁻¹b > 0 (since H_N PD and w ≠ 0).

    This ELIMINATES the vasyunin_nbDistSq_pos axiom. -/
theorem nbDistSq_pos_from_augmented (N : ℕ) (hN : N ≥ 1)
    (hG : (vasyuninGramMatrix N).PosDef) :
    dotProduct (vasyuninMeanVec N) (nbGinvb N) < 1 := by
  have hH := augmentedGramMatrix_posDef N hN
  have hw_ne := nbWitness_ne_zero N
  have hpos := hH.dotProduct_mulVec_pos hw_ne
  simp only [star_trivial] at hpos
  have h_eq := quadform_eq N hG
  linarith

end Cathedral.Vasyunin
