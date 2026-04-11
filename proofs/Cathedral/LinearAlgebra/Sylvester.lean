/-
  Cathedral/LinearAlgebra/Sylvester.lean

  ## Sylvester Criteria & Bordered Matrix PD

  Contains:
  - sylvester_2x2: 2×2 Sylvester criterion via completing the square
  - sylvester_3x3: 3×3 Sylvester criterion via completing the square
  - bordered_matrix_posDef: (n+1)×(n+1) PD from n×n PD + Schur > 0

  sylvester_2x2: zero sorry
  sylvester_3x3: zero sorry
  bordered_matrix_posDef: 1 sorry (Fin plumbing TBD)

  Extracted from Variational.lean (April 11, 2026).
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

/-- **Bordered matrix positive definiteness.**

    If a Hermitian (n+1)×(n+1) matrix M has:
    - Leading n×n submatrix A that is PD
    - Schur complement s = M(n,n) - gᵀA⁻¹g > 0

    then M is PD.

    This is the key theorem for inductive proofs of Gram matrix PD.

    The proof uses completing the square:
    xᵀMx = (x_top + A⁻¹g · x_n)ᵀ A (x_top + A⁻¹g · x_n) + s · x_n²

    where x_top ∈ ℝⁿ, x_n ∈ ℝ is the last component,
    g = border vector, s = Schur complement.

    Both terms are non-negative, and for x ≠ 0, at least one is positive.
-/
theorem bordered_matrix_posDef {n : ℕ}
    (M : Matrix (Fin (n+1)) (Fin (n+1)) ℝ)
    (hH : M.IsHermitian)
    (A : Matrix (Fin n) (Fin n) ℝ)
    (hA_eq : ∀ i j : Fin n, M ⟨i.val, Nat.lt_succ_of_lt i.isLt⟩ ⟨j.val, Nat.lt_succ_of_lt j.isLt⟩ = A i j)
    (hA_pd : A.PosDef)
    (g : Fin n → ℝ)
    (hg_eq : ∀ i : Fin n, M ⟨i.val, Nat.lt_succ_of_lt i.isLt⟩ ⟨n, Nat.lt_succ_iff.mpr le_rfl⟩ = g i)
    (hs : M ⟨n, Nat.lt_succ_iff.mpr le_rfl⟩ ⟨n, Nat.lt_succ_iff.mpr le_rfl⟩ -
          dotProduct g (A⁻¹.mulVec g) > 0) :
    M.PosDef := by
  -- PROOF SKETCH (standard linear algebra, Fin plumbing TBD):
  --
  -- Decompose x : Fin(n+1) → ℝ as (y, z) where y = x ∘ castSucc, z = x (last n).
  -- Then xᵀMx = yᵀAy + 2z(gᵀy) + αz²  (sum splitting over Fin)
  -- Complete the square:
  --   = (y + A⁻¹g·z)ᵀ A (y + A⁻¹g·z) + (α - gᵀA⁻¹g)·z²
  -- Term 1 ≥ 0 (A PSD from PD), term 2 ≥ 0 (Schur > 0).
  -- If x ≠ 0: z ≠ 0 → term 2 > 0; z = 0 and y ≠ 0 → term 1 > 0 (A PD).
  --
  -- Alternatively: use Mathlib's fromBlocks₁₁ via Fin(n+1) ≃ Fin n ⊕ Fin 1.
  -- This gives PSD. Upgrade to PD by showing the kernel is trivial
  -- (PSD + all leading minors positive → PD by Sylvester).
  sorry

end Cathedral.Variational
