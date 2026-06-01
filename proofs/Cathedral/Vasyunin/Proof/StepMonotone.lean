/-
  Cathedral/Vasyunin/Proof/StepMonotone.lean

  ## The Step Monotonicity: d²(N+1) ≤ d²(N)

  Proof that adding a basis function can only decrease the optimal
  NB distance. Uses the variational bound from Variational.lean
  combined with the block structure of the Gram matrix.

  Key identity: padding the N-dim optimizer with 0 gives a valid
  test vector in (N+1)-dim that achieves exactly d²(N).
  Since d²(N+1) is the MINIMUM, it must be ≤ d²(N).

  Status: PROVED ✅ (0 sorry, 0 axioms)
-/

import Cathedral.Vasyunin.Augmented.AugmentedGram
import Cathedral.LinearAlgebra.Variational

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin.StepMonotone

-- ════════════════════════════════════════════════
-- §1. THE GRAM BLOCK STRUCTURE
-- ════════════════════════════════════════════════

/-- G_{N+1}'s leading N×N block is G_N. -/
private theorem gram_block_eq (N : ℕ) (i j : Fin N) :
    (vasyuninGramMatrix (N+1)) (Fin.castSucc i) (Fin.castSucc j) =
    (vasyuninGramMatrix N) i j := by
  simp [vasyuninGramMatrix, of_apply, Fin.castSucc]

/-- b_{N+1}'s first N entries equal b_N. -/
private theorem meanVec_castSucc_eq (N : ℕ) (i : Fin N) :
    vasyuninMeanVec (N+1) (Fin.castSucc i) = vasyuninMeanVec N i := by
  simp [vasyuninMeanVec, Fin.castSucc]

-- ════════════════════════════════════════════════
-- §2. THE PADDED VECTOR
-- ════════════════════════════════════════════════

/-- Pad v ∈ ℝ^N to (v, 0) ∈ ℝ^{N+1}. -/
def padVec {N : ℕ} (v : Fin N → ℝ) : Fin (N + 1) → ℝ :=
  Fin.snoc v 0

/-- The last component of padVec is 0. -/
lemma padVec_last {N : ℕ} (v : Fin N → ℝ) :
    padVec v (Fin.last N) = 0 := by
  simp [padVec, Fin.snoc]

/-- The i-th component of padVec agrees with v. -/
lemma padVec_castSucc {N : ℕ} (v : Fin N → ℝ) (i : Fin N) :
    padVec v (Fin.castSucc i) = v i := by
  simp [padVec, Fin.snoc, Fin.castSucc]

-- ════════════════════════════════════════════════
-- §3. BLOCK STRUCTURE IDENTITIES
-- ════════════════════════════════════════════════

/-- (v,0)ᵀ G_{N+1} (v,0) = vᵀ G_N v -/
theorem padVec_quadForm (N : ℕ) (v : Fin N → ℝ) :
    dotProduct (padVec v) ((vasyuninGramMatrix (N+1)).mulVec (padVec v)) =
    dotProduct v ((vasyuninGramMatrix N).mulVec v) := by
  simp only [dotProduct, mulVec]
  -- Split both outer and inner sums: Σ_{i : Fin(N+1)} = Σ_{castSucc} + last
  rw [Fin.sum_univ_castSucc]
  simp only [padVec_last, zero_mul, add_zero]
  apply Finset.sum_congr rfl; intro i _
  simp only [padVec_castSucc]
  congr 1
  rw [Fin.sum_univ_castSucc]
  simp only [padVec_last, mul_zero, add_zero]
  apply Finset.sum_congr rfl; intro j _
  simp only [padVec_castSucc, gram_block_eq]

/-- b_{N+1}ᵀ (v,0) = b_Nᵀ v -/
theorem padVec_meanVec_dot (N : ℕ) (v : Fin N → ℝ) :
    dotProduct (vasyuninMeanVec (N+1)) (padVec v) =
    dotProduct (vasyuninMeanVec N) v := by
  simp only [dotProduct]
  rw [Fin.sum_univ_castSucc]
  simp only [padVec_last, mul_zero, add_zero]
  apply Finset.sum_congr rfl; intro i _
  rw [padVec_castSucc, meanVec_castSucc_eq]

-- ════════════════════════════════════════════════
-- §4. THE STEP THEOREM
-- ════════════════════════════════════════════════

/-- **THEOREM: d²(N+1) ≤ d²(N).**

    For N ≥ 1: use the variational bound with the padded optimizer.
    For N = 0: d²(0) = 1 ≥ d²(1) (direct from Rayleigh). -/
theorem nbDistSq_step_proved (N : ℕ) :
    1 - dotProduct (vasyuninMeanVec (N+1))
      ((vasyuninGramMatrix (N+1))⁻¹.mulVec (vasyuninMeanVec (N+1))) ≤
    1 - dotProduct (vasyuninMeanVec N)
      ((vasyuninGramMatrix N)⁻¹.mulVec (vasyuninMeanVec N)) := by
  -- Suffices: bᵀ_N G_N⁻¹ b_N ≤ bᵀ_{N+1} G_{N+1}⁻¹ b_{N+1}
  suffices h : dotProduct (vasyuninMeanVec N)
      ((vasyuninGramMatrix N)⁻¹.mulVec (vasyuninMeanVec N)) ≤
    dotProduct (vasyuninMeanVec (N+1))
      ((vasyuninGramMatrix (N+1))⁻¹.mulVec (vasyuninMeanVec (N+1))) by linarith
  -- Handle N = 0: left side = 0 (empty dotProduct), right side ≥ 0
  by_cases hN : N = 0
  · subst hN
    simp only [vasyuninMeanVec, dotProduct, Finset.univ_eq_empty, Finset.sum_empty]
    -- Need: 0 ≤ bᵀ₁ G₁⁻¹ b₁
    -- For PD G: set y = G⁻¹b, then bᵀG⁻¹b = yᵀGy ≥ 0
    have hPD := gramMatrix_posDef_from_augmented 1 (by omega)
    have h_det : IsUnit (vasyuninGramMatrix 1).det :=
      (vasyuninGramMatrix 1).isUnit_iff_isUnit_det.mp hPD.isUnit
    set y := (vasyuninGramMatrix 1)⁻¹.mulVec (vasyuninMeanVec 1)
    have h_Gy : (vasyuninGramMatrix 1).mulVec y = vasyuninMeanVec 1 := by
      rw [mulVec_mulVec, Matrix.mul_nonsing_inv _ h_det, one_mulVec]
    calc (0 : ℝ) ≤ dotProduct y ((vasyuninGramMatrix 1).mulVec y) := by
            have := hPD.posSemidef.dotProduct_mulVec_nonneg y
            simpa [star_trivial] using this
      _ = dotProduct ((vasyuninGramMatrix 1).mulVec y) y := (dotProduct_comm _ _)
      _ = dotProduct (vasyuninMeanVec 1) y := by rw [h_Gy]
  -- N ≥ 1: variational bound argument
  have hN1 : N ≥ 1 := Nat.one_le_iff_ne_zero.mpr hN
  -- G_{N+1} is PD
  have hGN1_pd := gramMatrix_posDef_from_augmented (N+1) (by omega)
  have hGN1_herm := vasyuninGramMatrix_symmetric (N+1)
  have hGN1_unit : IsUnit (vasyuninGramMatrix (N+1)).det :=
    (vasyuninGramMatrix (N+1)).isUnit_iff_isUnit_det.mp hGN1_pd.isUnit
  -- G_N is PD
  have hGN_pd := gramMatrix_posDef_from_augmented N hN1
  have hGN_unit : IsUnit (vasyuninGramMatrix N).det :=
    (vasyuninGramMatrix N).isUnit_iff_isUnit_det.mp hGN_pd.isUnit
  -- Test vector: v' = padVec(G_N⁻¹ b_N)
  set v_opt := (vasyuninGramMatrix N)⁻¹.mulVec (vasyuninMeanVec N) with hv_opt
  set v' := padVec v_opt
  -- Variational bound: v'ᵀ G v' - 2 bᵀ v' + bᵀ G⁻¹ b ≥ 0
  have h_var := Cathedral.Variational.variational_bound
    (vasyuninGramMatrix (N+1))
    (vasyuninMeanVec (N+1))
    v'
    hGN1_herm
    hGN1_pd.posSemidef
    hGN1_unit
  -- Substitute block identities
  have h_quad := padVec_quadForm N v_opt
  have h_dot := padVec_meanVec_dot N v_opt
  unfold Cathedral.Variational.realQuadForm at h_var
  rw [h_quad, h_dot] at h_var
  -- Key: G_N v_opt = b_N
  have h_Gv : (vasyuninGramMatrix N).mulVec v_opt = vasyuninMeanVec N := by
    rw [hv_opt, mulVec_mulVec, Matrix.mul_nonsing_inv _ hGN_unit, one_mulVec]
  -- v_optᵀ G_N v_opt = bᵀ_N v_opt
  have h_vGv : dotProduct v_opt ((vasyuninGramMatrix N).mulVec v_opt) =
      dotProduct (vasyuninMeanVec N) v_opt := by
    rw [h_Gv]; exact dotProduct_comm v_opt (vasyuninMeanVec N)
  rw [h_vGv] at h_var
  -- h_var: bᵀ_N v_opt - 2 bᵀ_N v_opt + bᵀ_{N+1} G_{N+1}⁻¹ b_{N+1} ≥ 0
  -- i.e.: bᵀ_{N+1} G_{N+1}⁻¹ b_{N+1} ≥ bᵀ_N v_opt = bᵀ_N G_N⁻¹ b_N
  linarith

end Cathedral.Vasyunin.StepMonotone
