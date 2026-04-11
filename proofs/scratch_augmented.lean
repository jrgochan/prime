/-
  Scratch: G_N PD from H_N PD via embedding w = (0, x).

  For x : Fin N → ℝ, set w = Fin.cons 0 x : Fin (N+1) → ℝ.
  Then wᵀH_Nw = xᵀG_Nx (the cross terms vanish because w(0)=0).
  H_N PD + w ≠ 0 → xᵀG_Nx > 0 for all nonzero x → G_N PD. ∎
-/

import Cathedral.MellinBridge.Vasyunin.AugmentedGram

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

set_option maxHeartbeats 1600000

-- The embedding: w = (0, x)
private noncomputable def embedGram (N : ℕ) (x : Fin N → ℝ) : Fin (N+1) → ℝ :=
  Fin.cons 0 x

-- w ≠ 0 when x ≠ 0
private theorem embedGram_ne_zero (N : ℕ) (x : Fin N → ℝ) (hx : x ≠ 0) :
    embedGram N x ≠ 0 := by
  intro hw
  apply hx
  funext i
  have := congr_fun hw (Fin.succ i)
  simp [embedGram, Fin.cons] at this
  exact this

-- The quadratic form: wᵀH_Nw = xᵀG_Nx
private theorem gram_quadform_eq (N : ℕ) (x : Fin N → ℝ) :
    dotProduct (embedGram N x) ((augmentedGramMatrix N).mulVec (embedGram N x)) =
    dotProduct x ((vasyuninGramMatrix N).mulVec x) := by
  simp only [dotProduct, mulVec]
  rw [Fin.sum_univ_succ]
  -- w(0) = 0
  simp only [embedGram, Fin.cons_zero, zero_mul, zero_add]
  -- Tail: Σᵢ x(i) · Σⱼ H(i+1, j)·w(j)
  apply Finset.sum_congr rfl
  intro i _
  simp only [Fin.cons_succ]
  congr 1
  -- Inner sum: Σⱼ H(i+1, j)·w(j)
  rw [Fin.sum_univ_succ]
  simp only [Fin.cons_zero, mul_zero, zero_add]
  simp only [Fin.cons_succ]
  -- H(i+1, j+1) = G(i, j) when both ≥ 1
  apply Finset.sum_congr rfl
  intro j _
  simp only [augmentedGramMatrix, of_apply, Fin.val_succ]
  have hi : ¬ (i.val + 1 = 0) := by omega
  have hj : ¬ (j.val + 1 = 0) := by omega
  simp only [hi, hj, false_and, ↓reduceIte, and_self]
  simp [vasyuninGramMatrix, of_apply]

-- THE RESULT: G_N PD from H_N PD
theorem gramMatrix_posDef_from_augmented (N : ℕ) (hN : N ≥ 1) :
    (vasyuninGramMatrix N).PosDef := by
  have hH := augmentedGramMatrix_posDef N hN
  refine PosDef.of_dotProduct_mulVec_pos (vasyuninGramMatrix_symmetric N) fun {x} hx => ?_
  simp only [star_trivial]
  rw [← gram_quadform_eq N x]
  have h := hH.dotProduct_mulVec_pos (embedGram_ne_zero N x hx)
  simpa [star_trivial] using h

end Cathedral.Vasyunin
