/-
  Cathedral/MellinBridge/Vasyunin/GramInduction.lean

  **THE INDUCTIVE FRAMEWORK FOR GRAM PD**

  Goal: Prove G_N is PD for ALL N ≥ 1 (and hence remove axiom 2).

  Strategy: Induction on N using the bordered matrix Schur complement.
  If G_N is PD and the (N+1)-th sawtooth {(N+1)/x} is linearly
  independent from {1/x}, ..., {N/x}, then G_{N+1} is PD.

  The linear independence follows from the DISCONTINUITY ARGUMENT:
  {k/x} has a jump discontinuity at x = k/m for each m | k,
  and specifically has a unique discontinuity pattern at x = 1/(N+1).
  No finite linear combination of {1/x}, ..., {N/x} can reproduce
  this discontinuity, so {(N+1)/x} ∉ span{...}.

  Architecture:
  - §1: Bordered matrix theorem (abstract linear algebra)
  - §2: Application to Gram matrices
  - §3: The discontinuity argument (topology → independence)
  - §4: The inductive proof

  Status: SCAFFOLDING. The abstract framework is set up.
  The discontinuity argument (§3) requires Mathlib's measure theory.
-/

import Cathedral.MellinBridge.Vasyunin.NbDistPos3
import Cathedral.MellinBridge.Vasyunin.NbDistPos2

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- §1. BORDERED MATRIX PD (Abstract)
-- ════════════════════════════════════════════════

/-
  **THE BORDERED MATRIX THEOREM.**

  Given:
  - A : (Fin n) → (Fin n) → ℝ, PD
  - g : Fin n → ℝ (the border vector)
  - α : ℝ (the corner entry)
  - α - gᵀA⁻¹g > 0 (the Schur complement is positive)

  Then the bordered matrix:
    M = [A  g]
        [gᵀ α]
  is PD.

  This is the standard bordered matrix extension lemma.
  It's the KEY tool for proving G_{N+1} PD from G_N PD.
-/

-- For now, we state the bordered PD theorem for the
-- specific Gram matrix structure.

-- ════════════════════════════════════════════════
-- §2. GRAM MATRIX MONOTONICITY
-- ════════════════════════════════════════════════

/-- **Gram matrix embedding**: G_N is the leading principal submatrix of G_{N+1}.
    This is because G(i,j) = vasyuninGramEntry(i+1,j+1) doesn't depend on N. -/
theorem gramMatrix_entry_independent (N₁ N₂ : ℕ) (i : Fin N₁) (j : Fin N₁)
    (hi : i.val < N₂) (hj : j.val < N₂) :
    (vasyuninGramMatrix N₁) i j =
    (vasyuninGramMatrix N₂) ⟨i.val, hi⟩ ⟨j.val, hj⟩ := by
  simp [vasyuninGramMatrix, of_apply]

-- ════════════════════════════════════════════════
-- §3. THE DISCONTINUITY ARGUMENT
-- ════════════════════════════════════════════════

/-
  **WHY {(N+1)/x} IS INDEPENDENT FROM {1/x}, ..., {N/x}**

  Consider the fractional-part function f_k(x) = {k/x} on (0,1].

  Key observation: f_k has jump discontinuities at x = k/m for each
  positive integer m. In particular:
  - f_1 has discontinuities at x = 1, 1/2, 1/3, ...
  - f_2 has discontinuities at x = 1, 1/2, 2/3, 1/3, 2/5, ...
  - f_k has a discontinuity at x = k/(k+1) that is NOT shared
    by any f_j with j < k.

  The point x₀ = (N+1)/(N+2) is a discontinuity of f_{N+1}
  but NOT of any f_k with k ≤ N. (Because k/(m) = (N+1)/(N+2)
  implies k·(N+2) = m·(N+1). If k ≤ N, then k < N+1, so
  k/(N+1) < 1, meaning m < N+2, so m ≤ N+1. But then
  k = m·(N+1)/(N+2), which is not an integer since gcd(N+1,N+2)=1
  and m < N+2 implies m is not divisible by N+2.)

  Therefore: any finite linear combination of f_1, ..., f_N is
  continuous at x₀, but f_{N+1} has a jump there. So f_{N+1}
  is NOT in span(f_1, ..., f_N).

  In L²(0,1): this means the projection of f_{N+1} onto
  span(f_1, ..., f_N) has strictly positive residual, which is
  exactly α - gᵀG_N⁻¹g > 0 (the Schur complement).
-/

-- The formal proof of the discontinuity argument would require:
-- 1. Defining the fractional-part function on (0,1]
-- 2. Proving it has specific discontinuities
-- 3. Showing linear combinations preserve continuity at non-discontinuity points
-- 4. Concluding linear independence
--
-- This is a significant formalization effort, requiring Mathlib's
-- topology and measure theory. We leave it as a documented axiom
-- with a clear mathematical proof.

/-- **THE SCHUR COMPLEMENT POSITIVITY (for Gram matrices).**

    For any N ≥ 1, the Schur complement of the bordered Gram matrix
    G_{N+1} relative to G_N is strictly positive.

    This is equivalent to: {(N+1)/x} is NOT in span{f_1,...,f_N} in L²(0,1).
    The proof follows from the discontinuity argument above.

    This axiom, combined with any base case, yields G_N PD for ALL N. -/
axiom gramSchurComplement_pos (N : ℕ) (hN : N ≥ 1) :
    vasyuninGramEntry (N+1) (N+1) -
    dotProduct
      (fun i : Fin N => vasyuninGramEntry (i.val+1) (N+1))
      ((vasyuninGramMatrix N)⁻¹.mulVec
        (fun i : Fin N => vasyuninGramEntry (i.val+1) (N+1))) > 0

-- ════════════════════════════════════════════════
-- §4. CONSEQUENCES
-- ════════════════════════════════════════════════

/-- The diagonal entries of the Gram matrix are strictly positive. -/
theorem gramMatrix_diag_pos (N : ℕ) (i : Fin N) :
    (vasyuninGramMatrix N) i i > 0 := by
  rw [gramMatrix_entry_independent N N i i i.isLt i.isLt]
  simp [vasyuninGramMatrix, of_apply]
  exact vasyuninGramEntry_diag_pos (i.val + 1) (by omega)

-- ════════════════════════════════════════════════
-- §5. THE INDUCTIVE PROOF
-- ════════════════════════════════════════════════

/-- **The Gram matrix G_{N+1} is a bordered extension of G_N.**
    This connects the Gram matrix definition to the bordered matrix framework. -/
theorem gramMatrix_bordered_eq (N : ℕ) (i j : Fin N) :
    (vasyuninGramMatrix (N+1)) (Fin.castSucc i) (Fin.castSucc j) =
    (vasyuninGramMatrix N) i j := by
  simp [vasyuninGramMatrix, of_apply, Fin.castSucc]

/-- The border vector of G_{N+1} is the cross-correlation with f_{N+1}. -/
theorem gramMatrix_border_eq (N : ℕ) (i : Fin N) :
    (vasyuninGramMatrix (N+1)) (Fin.castSucc i) (Fin.last N) =
    vasyuninGramEntry (i.val + 1) (N + 1) := by
  simp [vasyuninGramMatrix, of_apply, Fin.castSucc, Fin.last]

/-- The corner entry of G_{N+1} is G(N+1, N+1). -/
theorem gramMatrix_corner_eq (N : ℕ) :
    (vasyuninGramMatrix (N+1)) (Fin.last N) (Fin.last N) =
    vasyuninGramEntry (N + 1) (N + 1) := by
  simp [vasyuninGramMatrix, of_apply, Fin.last]

/-- **THE INDUCTIVE STEP: G_N PD implies G_{N+1} PD.**
    Uses bordered_matrix_posDef + gramSchurComplement_pos. -/
theorem gramMatrix_posDef_step (N : ℕ) (hN : N ≥ 1)
    (hGN : (vasyuninGramMatrix N).PosDef) :
    (vasyuninGramMatrix (N + 1)).PosDef := by
  apply Cathedral.Variational.bordered_matrix_posDef
    (vasyuninGramMatrix (N+1))
    (vasyuninGramMatrix_symmetric (N+1))
    (vasyuninGramMatrix N)
    (gramMatrix_bordered_eq N)
    hGN
    (fun i => vasyuninGramEntry (i.val + 1) (N + 1))
    (gramMatrix_border_eq N)
  -- Schur complement: α - gᵀG_N⁻¹g > 0
  simp only [vasyuninGramMatrix, of_apply]
  exact gramSchurComplement_pos N hN

/-- **THEOREM: G_N is positive definite for all N ≥ 2.**

    Proved by induction:
    - Base: G₂ PD (NbDistPos2.lean: gramMatrix2_posDef)
    - Step: G_N PD → G_{N+1} PD (bordered_matrix_posDef + gramSchurComplement_pos)

    This theorem REPLACES the axiom `vasyuninGramMatrix_posDef` in Rayleigh.lean.
    The only remaining axiom is `gramSchurComplement_pos`. -/
theorem vasyuninGramMatrix_posDef_inductive (N : ℕ) (hN : N ≥ 2) :
    (vasyuninGramMatrix N).PosDef := by
  -- Induction on N starting from base case N = 2
  induction N with
  | zero => omega
  | succ n ih =>
    by_cases hn2 : n = 1
    · -- Base case: N = 2
      subst hn2; exact gramMatrix2_posDef
    · -- Inductive step: n + 1, with n ≥ 2
      have hn_ge_2 : n ≥ 2 := by omega
      have hn_ge_1 : n ≥ 1 := by omega
      exact gramMatrix_posDef_step n hn_ge_1 (ih hn_ge_2)

end Cathedral.Vasyunin
