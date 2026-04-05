/-
  Cathedral/Mertens/Defs.lean

  ## Definitions for the constant-witness NB distance decay.

  Defines basisSum, gramSum, and the constant test vector helpers.
-/

import Cathedral.Defs
import Cathedral.Structural

noncomputable section
open Real MeasureTheory Set Finset Matrix

/-- Sum of basis inner products: B(N) = Σ_{k=1}^{N-1} b_k = Σ ∫₀¹ {k/x} dx. -/
noncomputable def basisSum (N : ℕ) : ℝ :=
  ∑ i : Fin (N - 1), basisInnerProd N i

/-- Total Gram mass: Q(N) = 𝟙ᵀG𝟙 = Σ_{j,k} G_{jk}. -/
noncomputable def gramSum (N : ℕ) : ℝ :=
  ∑ i : Fin (N - 1), ∑ j : Fin (N - 1), gramMatrix N i j

/-- Constant test vector: w_k = c for all k. -/
def constVec (N : ℕ) (c : ℝ) : Fin (N - 1) → ℝ := fun _ => c

lemma dot_const (N : ℕ) (c : ℝ) :
    dotProduct (basisInnerProd N) (constVec N c) = c * basisSum N := by
  unfold dotProduct basisSum constVec
  simp [Finset.mul_sum]
  congr 1; ext i; ring

lemma quad_const (N : ℕ) (c : ℝ) :
    realQuadForm (gramMatrix N) (constVec N c) = c ^ 2 * gramSum N := by
  simp only [realQuadForm, constVec, gramSum, dotProduct, Matrix.mulVec,
             Finset.mul_sum]
  ring_nf

end
