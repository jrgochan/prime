/-
  Cathedral/LinearAlgebra/Sylvester.lean

  ## Sylvester Criteria & Bordered Matrix PD

  Contains:
  - sylvester_2x2: 2×2 Sylvester criterion via completing the square
  - sylvester_3x3: 3×3 Sylvester criterion via completing the square
  - bordered_matrix_posDef: (n+1)×(n+1) PD from n×n PD + Schur > 0

  All theorems: FULLY PROVED, zero axioms.

  Extracted from Variational.lean (April 11, 2026).
  bordered_matrix_posDef proven April 11, 2026.
-/

import Cathedral.LinearAlgebra.SchurComplement

noncomputable section
open Matrix Finset

namespace Cathedral.Variational

variable {n : ℕ}

-- ════════════════════════════════════════════════
-- SECTION 1: 2×2 SYLVESTER CRITERION
-- ════════════════════════════════════════════════

/-- **2×2 Sylvester criterion via completing the square.**
    For a Hermitian 2×2 matrix M with M(0,0) > 0 and det > 0, M is positive definite.

    Proof: The CTS identity: a·(xᵀMx) = (a·x₀+b·x₁)² + det(M)·x₁²
    where a = M(0,0), b = M(0,1). -/
theorem sylvester_2x2
    (M : Matrix (Fin 2) (Fin 2) ℝ)
    (hH : M.IsHermitian)
    (h1 : M 0 0 > 0)
    (h2 : M 0 0 * M 1 1 - M 0 1 ^ 2 > 0) :
    M.PosDef := by
  have hM10 : M 1 0 = M 0 1 := by
    have := congr_fun (congr_fun hH 1) 0; simp [conjTranspose_apply, star_trivial] at this; exact this.symm
  exact PosDef.of_dotProduct_mulVec_pos hH fun {x} hx => by
    simp only [star_trivial]
    have h_expand : dotProduct x (M.mulVec x) =
        M 0 0 * x 0 ^ 2 + M 1 1 * x 1 ^ 2 + 2 * M 0 1 * x 0 * x 1 := by
      simp only [dotProduct, mulVec, Fin.sum_univ_two, Fin.isValue]
      rw [hM10]; ring
    rw [h_expand]
    have h_cts : M 0 0 * (M 0 0 * x 0 ^ 2 + M 1 1 * x 1 ^ 2 + 2 * M 0 1 * x 0 * x 1) =
        (M 0 0 * x 0 + M 0 1 * x 1) ^ 2 +
        (M 0 0 * M 1 1 - M 0 1 ^ 2) * x 1 ^ 2 := by ring
    by_contra h_neg
    push Not at h_neg
    have h_scaled := mul_nonpos_of_nonneg_of_nonpos (le_of_lt h1) h_neg
    rw [h_cts] at h_scaled
    have ht1 : (0 : ℝ) ≤ (M 0 0 * x 0 + M 0 1 * x 1) ^ 2 := sq_nonneg _
    have ht2 : (0 : ℝ) ≤ (M 0 0 * M 1 1 - M 0 1 ^ 2) * x 1 ^ 2 :=
      mul_nonneg (le_of_lt h2) (sq_nonneg _)
    have heq1 : (M 0 0 * x 0 + M 0 1 * x 1) ^ 2 = 0 := by linarith
    have heq2 : (M 0 0 * M 1 1 - M 0 1 ^ 2) * x 1 ^ 2 = 0 := by linarith
    have hx1 : x 1 = 0 := by
      by_contra h; exact absurd heq2 (ne_of_gt (mul_pos h2 (sq_pos_of_ne_zero h)))
    have hx0 : x 0 = 0 := by
      rw [hx1, mul_zero, add_zero] at heq1
      have h_sq : M 0 0 * x 0 = 0 := sq_eq_zero_iff.mp heq1
      exact (mul_eq_zero.mp h_sq).resolve_left (ne_of_gt h1)
    apply hx; ext i; fin_cases i <;> simp_all

-- ════════════════════════════════════════════════
-- SECTION 2: 3×3 SYLVESTER CRITERION
-- ════════════════════════════════════════════════

/-- **3×3 Sylvester criterion via completing the square.**
    For a Hermitian 3×3 matrix M with positive leading minors, M is positive definite.

    Proof: The CTS algebraic identity (verified by `ring`):
      a·det₂·(xᵀMx) = det₂·(a·x₀+b·x₁+c·x₂)²
                      + (det₂·x₁+(ae-bc)·x₂)²
                      + a·det(M)·x₂²

    where a = M(0,0), det₂ = a·M(1,1) - M(0,1)².
    Since a > 0 and det₂ > 0, the LHS shares sign with xᵀMx.
    The RHS is a sum of non-negative terms, each with a positive coefficient.
    If x ≠ 0: x₂ ≠ 0 → third term > 0; or x₂ = 0, x₁ ≠ 0 → second term > 0;
    or x₁ = x₂ = 0, x₀ ≠ 0 → first term > 0. In all cases xᵀMx > 0. -/
theorem sylvester_3x3
    (M : Matrix (Fin 3) (Fin 3) ℝ)
    (hH : M.IsHermitian)
    (h1 : M 0 0 > 0)
    (h2 : M 0 0 * M 1 1 - M 0 1 ^ 2 > 0)
    (h3 : M 0 0 * (M 1 1 * M 2 2 - M 1 2 ^ 2) -
          M 0 1 * (M 0 1 * M 2 2 - M 1 2 * M 0 2) +
          M 0 2 * (M 0 1 * M 1 2 - M 1 1 * M 0 2) > 0) :
    M.PosDef := by
  have hM10 : M 1 0 = M 0 1 := by
    have := congr_fun (congr_fun hH 1) 0; simp [conjTranspose_apply, star_trivial] at this; exact this.symm
  have hM20 : M 2 0 = M 0 2 := by
    have := congr_fun (congr_fun hH 2) 0; simp [conjTranspose_apply, star_trivial] at this; exact this.symm
  have hM21 : M 2 1 = M 1 2 := by
    have := congr_fun (congr_fun hH 2) 1; simp [conjTranspose_apply, star_trivial] at this; exact this.symm
  exact PosDef.of_dotProduct_mulVec_pos hH fun {x} hx => by
    simp only [star_trivial]
    have h_expand : dotProduct x (M.mulVec x) =
        M 0 0 * x 0 ^ 2 + M 1 1 * x 1 ^ 2 + M 2 2 * x 2 ^ 2 +
        2 * M 0 1 * x 0 * x 1 + 2 * M 0 2 * x 0 * x 2 + 2 * M 1 2 * x 1 * x 2 := by
      simp only [dotProduct, mulVec, Fin.sum_univ_three, Fin.isValue]
      rw [hM10, hM20, hM21]; ring
    rw [h_expand]
    have h_cts :
        M 0 0 * (M 0 0 * M 1 1 - M 0 1 ^ 2) *
          (M 0 0 * x 0 ^ 2 + M 1 1 * x 1 ^ 2 + M 2 2 * x 2 ^ 2 +
          2 * M 0 1 * x 0 * x 1 + 2 * M 0 2 * x 0 * x 2 + 2 * M 1 2 * x 1 * x 2) =
        (M 0 0 * M 1 1 - M 0 1 ^ 2) * (M 0 0 * x 0 + M 0 1 * x 1 + M 0 2 * x 2) ^ 2 +
        ((M 0 0 * M 1 1 - M 0 1 ^ 2) * x 1 + (M 0 0 * M 1 2 - M 0 1 * M 0 2) * x 2) ^ 2 +
        M 0 0 * (M 0 0 * (M 1 1 * M 2 2 - M 1 2 ^ 2) -
          M 0 1 * (M 0 1 * M 2 2 - M 1 2 * M 0 2) +
          M 0 2 * (M 0 1 * M 1 2 - M 1 1 * M 0 2)) * x 2 ^ 2 := by ring
    have had : (0 : ℝ) < M 0 0 * (M 0 0 * M 1 1 - M 0 1 ^ 2) := mul_pos h1 h2
    by_contra h_neg
    push Not at h_neg
    have h_scaled := mul_nonpos_of_nonneg_of_nonpos (le_of_lt had) h_neg
    have h_rhs_le : (M 0 0 * M 1 1 - M 0 1 ^ 2) * (M 0 0 * x 0 + M 0 1 * x 1 + M 0 2 * x 2) ^ 2 +
        ((M 0 0 * M 1 1 - M 0 1 ^ 2) * x 1 + (M 0 0 * M 1 2 - M 0 1 * M 0 2) * x 2) ^ 2 +
        M 0 0 * (M 0 0 * (M 1 1 * M 2 2 - M 1 2 ^ 2) -
          M 0 1 * (M 0 1 * M 2 2 - M 1 2 * M 0 2) +
          M 0 2 * (M 0 1 * M 1 2 - M 1 1 * M 0 2)) * x 2 ^ 2 ≤ 0 := by linarith
    have ht1 : (0 : ℝ) ≤ (M 0 0 * M 1 1 - M 0 1 ^ 2) * (M 0 0 * x 0 + M 0 1 * x 1 + M 0 2 * x 2) ^ 2 :=
      mul_nonneg (le_of_lt h2) (sq_nonneg _)
    have ht2 : (0 : ℝ) ≤ ((M 0 0 * M 1 1 - M 0 1 ^ 2) * x 1 + (M 0 0 * M 1 2 - M 0 1 * M 0 2) * x 2) ^ 2 :=
      sq_nonneg _
    have ht3 : (0 : ℝ) ≤ M 0 0 * (M 0 0 * (M 1 1 * M 2 2 - M 1 2 ^ 2) -
        M 0 1 * (M 0 1 * M 2 2 - M 1 2 * M 0 2) +
        M 0 2 * (M 0 1 * M 1 2 - M 1 1 * M 0 2)) * x 2 ^ 2 :=
      mul_nonneg (mul_nonneg (le_of_lt h1) (le_of_lt h3)) (sq_nonneg _)
    have heq1 : (M 0 0 * M 1 1 - M 0 1 ^ 2) * (M 0 0 * x 0 + M 0 1 * x 1 + M 0 2 * x 2) ^ 2 = 0 := by linarith
    have heq2 : ((M 0 0 * M 1 1 - M 0 1 ^ 2) * x 1 + (M 0 0 * M 1 2 - M 0 1 * M 0 2) * x 2) ^ 2 = 0 := by linarith
    have heq3 : M 0 0 * (M 0 0 * (M 1 1 * M 2 2 - M 1 2 ^ 2) -
        M 0 1 * (M 0 1 * M 2 2 - M 1 2 * M 0 2) +
        M 0 2 * (M 0 1 * M 1 2 - M 1 1 * M 0 2)) * x 2 ^ 2 = 0 := by linarith
    have hx2 : x 2 = 0 := by
      by_contra h; exact absurd heq3 (ne_of_gt (mul_pos (mul_pos h1 h3) (sq_pos_of_ne_zero h)))
    have hx1 : x 1 = 0 := by
      rw [hx2, mul_zero, add_zero] at heq2
      have h_sq : (M 0 0 * M 1 1 - M 0 1 ^ 2) * x 1 = 0 := sq_eq_zero_iff.mp heq2
      exact (mul_eq_zero.mp h_sq).resolve_left (ne_of_gt h2)
    have hx0 : x 0 = 0 := by
      rw [hx1, hx2, mul_zero, add_zero, mul_zero, add_zero] at heq1
      have h_sq := (mul_eq_zero.mp heq1).resolve_left (ne_of_gt h2)
      have h_prod : M 0 0 * x 0 = 0 := sq_eq_zero_iff.mp h_sq
      exact (mul_eq_zero.mp h_prod).resolve_left (ne_of_gt h1)
    apply hx; ext i; fin_cases i <;> simp_all

-- ════════════════════════════════════════════════
-- SECTION 3: BORDERED MATRIX PD (Inductive Step)
-- ════════════════════════════════════════════════

/-- Split dotProduct over Fin (n+1) into Fin n part + last element. -/
private lemma dotProduct_fin_succ' {n : ℕ} (x y : Fin (n+1) → ℝ) :
    dotProduct x y =
    dotProduct (x ∘ Fin.castSucc) (y ∘ Fin.castSucc) +
    x (Fin.last n) * y (Fin.last n) := by
  simp only [dotProduct, Fin.sum_univ_castSucc, Function.comp]

/-- Split mulVec at any index into Fin n sum + last element. -/
private lemma mulVec_split' {n : ℕ} (M : Matrix (Fin (n+1)) (Fin (n+1)) ℝ)
    (x : Fin (n+1) → ℝ) (i : Fin (n+1)) :
    (M.mulVec x) i =
    ∑ j : Fin n, M i (Fin.castSucc j) * x (Fin.castSucc j) +
    M i (Fin.last n) * x (Fin.last n) := by
  simp only [mulVec, dotProduct, Fin.sum_univ_castSucc]

/-- **Bordered matrix positive definiteness.**

    If a Hermitian (n+1)×(n+1) matrix M has:
    - Leading n×n submatrix A that is PD
    - Schur complement s = M(n,n) - gᵀA⁻¹g > 0

    then M is PD.

    This is the key theorem for inductive proofs of Gram matrix PD.

    The proof decomposes x = (y, z) where y ∈ ℝⁿ, z ∈ ℝ, then shows:
      xᵀMx = yᵀAy + 2z(gᵀy) + αz²

    Completing the square via w = y + z·A⁻¹g gives:
      xᵀMx = wᵀAw + (α - gᵀA⁻¹g)·z²

    Both terms are non-negative. For x ≠ 0, at least one is strictly positive. -/
theorem bordered_matrix_posDef {n : ℕ}
    (M : Matrix (Fin (n+1)) (Fin (n+1)) ℝ)
    (hH : M.IsHermitian)
    (A : Matrix (Fin n) (Fin n) ℝ)
    (hA_eq : ∀ i j : Fin n, M (Fin.castSucc i) (Fin.castSucc j) = A i j)
    (hA_pd : A.PosDef)
    (g : Fin n → ℝ)
    (hg_eq : ∀ i : Fin n, M (Fin.castSucc i) (Fin.last n) = g i)
    (hs : M (Fin.last n) (Fin.last n) -
          dotProduct g (A⁻¹.mulVec g) > 0) :
    M.PosDef := by
  have hg_sym : ∀ i : Fin n, M (Fin.last n) (Fin.castSucc i) = g i := by
    intro i
    have := congr_fun (congr_fun hH (Fin.last n)) (Fin.castSucc i)
    simp [conjTranspose_apply, star_trivial] at this
    rw [← this]; exact hg_eq i
  set α := M (Fin.last n) (Fin.last n)
  refine PosDef.of_dotProduct_mulVec_pos hH fun {x} hx => ?_
  simp only [star_trivial]
  set y : Fin n → ℝ := x ∘ Fin.castSucc
  set z : ℝ := x (Fin.last n)
  -- Express (Mx) at each index
  have hMx_cast : ∀ i : Fin n, (M.mulVec x) (Fin.castSucc i) =
      (A.mulVec y) i + g i * z := by
    intro i; rw [mulVec_split']
    simp only [hA_eq, hg_eq]
    show ∑ j, A i j * y j + g i * z = (A.mulVec y) i + g i * z
    simp [mulVec, dotProduct]
  have hMx_last : (M.mulVec x) (Fin.last n) =
      dotProduct g y + α * z := by
    rw [mulVec_split']; simp only [hg_sym]
    show ∑ j, g j * y j + α * z = dotProduct g y + α * z
    simp [dotProduct]
  -- Key identity: xᵀMx = yᵀAy + 2z(gᵀy) + αz²
  have h_quad : dotProduct x (M.mulVec x) =
      dotProduct y (A.mulVec y) + 2 * z * dotProduct g y + α * z ^ 2 := by
    rw [dotProduct_fin_succ']
    have h_top : dotProduct (x ∘ Fin.castSucc) ((M.mulVec x) ∘ Fin.castSucc) =
        dotProduct y (A.mulVec y) + z * dotProduct g y := by
      show ∑ i, y i * (M.mulVec x) (Fin.castSucc i) = _
      simp_rw [hMx_cast, mul_add, Finset.sum_add_distrib]
      simp only [dotProduct]
      congr 1
      · have : ∀ i, y i * (g i * z) = z * (g i * y i) := fun i => by ring
        simp_rw [this, ← Finset.mul_sum]
    have h_bot : x (Fin.last n) * (M.mulVec x) (Fin.last n) =
        z * dotProduct g y + α * z ^ 2 := by
      rw [hMx_last]; ring
    rw [h_top, h_bot]; ring
  rw [h_quad]
  -- Case split on z (last component)
  by_cases hz : z = 0
  · -- z = 0: xᵀMx = yᵀAy > 0
    simp only [hz, zero_mul, mul_zero, add_zero]
    have hy_ne : y ≠ 0 := by
      intro hy_eq; apply hx; ext i
      refine Fin.lastCases ?_ ?_ i
      · exact hz
      · intro j; exact congr_fun hy_eq j
    have := hA_pd.dotProduct_mulVec_pos hy_ne
    simpa [star_trivial] using this
  · -- z ≠ 0: completing the square shows ≥ s·z² > 0
    have h_sz_pos : (α - dotProduct g (A⁻¹.mulVec g)) * z ^ 2 > 0 :=
      mul_pos hs (sq_pos_of_ne_zero hz)
    set w := y + z • A⁻¹.mulVec g
    have h_wAw := hA_pd.posSemidef.dotProduct_mulVec_nonneg w
    simp only [star_trivial] at h_wAw
    have hA_unit : IsUnit A.det := A.isUnit_iff_isUnit_det.mp hA_pd.isUnit
    have hA_inv_g : A.mulVec (A⁻¹.mulVec g) = g := by
      rw [mulVec_mulVec, mul_nonsing_inv A hA_unit, one_mulVec]
    -- Expand wᵀAw = yᵀAy + 2z(gᵀy) + z²(gᵀA⁻¹g)
    have h_expand : dotProduct w (A.mulVec w) =
        dotProduct y (A.mulVec y) +
        z * dotProduct y g +
        z * dotProduct (A⁻¹.mulVec g) (A.mulVec y) +
        z ^ 2 * dotProduct g (A⁻¹.mulVec g) := by
      simp only [w, mulVec_add, mulVec_smul, add_dotProduct, dotProduct_add,
        smul_dotProduct, dotProduct_smul, hA_inv_g,
        dotProduct_comm (A⁻¹.mulVec g) g]; simp [smul_eq_mul]; ring
    -- Key lemma: dot(A⁻¹g, Ay) = dot(g, y) by matrix symmetry
    have h1 : dotProduct (A⁻¹.mulVec g) (A.mulVec y) = dotProduct g y := by
      unfold dotProduct; simp only [mulVec, dotProduct]
      simp_rw [Finset.mul_sum]
      rw [Finset.sum_comm]
      apply Finset.sum_congr rfl; intro i _
      have h_factor : ∀ j, (∑ k, A⁻¹ j k * g k) * (A j i * y i) =
          ((∑ k, A⁻¹ j k * g k) * A j i) * y i := fun j => by ring
      simp_rw [h_factor, ← Finset.sum_mul]
      congr 1
      have hA_sym_ij : ∀ j, A j i = A i j := by
        intro j; have := congr_fun (congr_fun hA_pd.isHermitian j) i
        simp [conjTranspose_apply, star_trivial] at this; exact this.symm
      simp_rw [hA_sym_ij]
      rw [show ∑ j, (∑ k, A⁻¹ j k * g k) * A i j =
          ∑ j, A i j * ∑ k, A⁻¹ j k * g k from by
        congr 1; ext j; ring]
      exact congr_fun hA_inv_g i
    rw [h1, dotProduct_comm y g] at h_expand
    -- From h_wAw ≥ 0: yᵀAy + 2z(gᵀy) + z²(gᵀA⁻¹g) ≥ 0
    -- So yᵀAy + 2z(gᵀy) + αz² ≥ (α - gᵀA⁻¹g)z² > 0
    linarith

end Cathedral.Variational

