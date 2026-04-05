/-
  Cathedral/Assembly/DropAssembly.lean

  ## Algebraic Drop Bounds (not on critical path to RH)

  These show that IF alignment decays as N^{-β} with β > 1, THEN eigenvalue
  drops decay as N^{1-2β}. Valid algebra, useful for finite-N analysis,
  but superseded by the variational approach for the main theorem.
-/

import Cathedral.Defs
import Cathedral.Structural
import Cathedral.Quantitative
import Cathedral.AlignmentDecay
import Cathedral.BilinearSieve
import Cathedral.ParityBridge

noncomputable section
open Complex Real

/-- **THEOREM**: Algebraic assembly for the drop bound. -/
theorem drop_assembly_at (N : ℕ) (hN : 10 ≤ N)
    (C₁ : ℝ) (hC₁ : 0 < C₁) (β : ℝ) (_hβ : 1 < β)
    (h_cos : cosAlignment (N - 1) ≤ C₁ * (N - 1 : ℝ) ^ (-β))
    (C₂ : ℝ) (hC₂ : 0 < C₂)
    (h_cross : dotProduct (crossCorrVec (N - 1)) (crossCorrVec (N - 1)) ≤ C₂ * (N - 1 : ℝ))
    (h_schur : schurComplement (N - 1) ≥ 1 / 20)
    (h_drop : eigenDrop N ≤ (cosAlignment (N - 1))^2 *
                dotProduct (crossCorrVec (N - 1)) (crossCorrVec (N - 1)) /
                schurComplement (N - 1)) :
    eigenDrop N ≤ 20 * C₁^2 * C₂ * (N - 1 : ℝ) ^ (1 - 2 * β) := by
  set M := (N - 1 : ℝ) with hM_def
  set cosθ := cosAlignment (N - 1)
  set g2 := dotProduct (crossCorrVec (N - 1)) (crossCorrVec (N - 1))
  set S := schurComplement (N - 1)
  have hM_pos : (0 : ℝ) < M := by
    simp only [hM_def]; linarith [show (10 : ℝ) ≤ (N : ℝ) from Nat.ofNat_le_cast.mpr hN]
  have hS_pos : 0 < S := by linarith
  have hMβ_pos : 0 < M ^ (-β) := rpow_pos_of_pos hM_pos (-β)
  have hcos_nn : 0 ≤ cosθ := by
    dsimp only [cosθ]
    unfold cosAlignment
    split_ifs <;> first
      | exact le_refl (0 : ℝ)
      | exact div_nonneg (Real.sqrt_nonneg _) (Real.sqrt_nonneg _)
      | positivity
  have hCMβ_nn : 0 ≤ C₁ * M ^ (-β) := le_of_lt (mul_pos hC₁ hMβ_pos)
  have hcos_sq : cosθ ^ 2 ≤ (C₁ * M ^ (-β)) ^ 2 := by
    apply sq_le_sq'
    · linarith
    · exact h_cos
  have hg2_nn : 0 ≤ g2 := by
    simp only [g2, dotProduct]; apply Finset.sum_nonneg
    intro i _; exact mul_self_nonneg (crossCorrVec (N - 1) i)
  have hnum : cosθ ^ 2 * g2 ≤ (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) :=
    mul_le_mul hcos_sq h_cross hg2_nn (sq_nonneg _)
  have hfrac : cosθ ^ 2 * g2 / S ≤ (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) * 20 := by
    have h1 : cosθ ^ 2 * g2 / S ≤ (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) / S :=
      div_le_div_of_nonneg_right hnum (le_of_lt hS_pos)
    have hval_nn : 0 ≤ (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) := by
      apply mul_nonneg (sq_nonneg _); exact mul_nonneg (le_of_lt hC₂) (le_of_lt hM_pos)
    have h2 : (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) / S ≤
              (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) * 20 := by
      have : (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) * 20 =
             (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) * (20 * S) / S := by
        field_simp
      rw [this]
      apply div_le_div_of_nonneg_right _ (le_of_lt hS_pos)
      nlinarith
    linarith
  have hexp : (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) * 20 =
              20 * C₁ ^ 2 * C₂ * M ^ (1 - 2 * β) := by
    have h1 : (C₁ * M ^ (-β)) ^ 2 = C₁ ^ 2 * (M ^ (-β)) ^ 2 := mul_pow C₁ _ 2
    have h2 : (M ^ (-β)) ^ 2 = M ^ (-β * 2) := by
      rw [← rpow_natCast (M ^ (-β)) 2, ← rpow_mul (le_of_lt hM_pos)]
      norm_cast
    have h3 : M ^ (-β * 2) * M = M ^ (1 - 2 * β) := by
      calc M ^ (-β * 2) * M
          = M ^ (-β * 2) * M ^ (1 : ℝ) := by rw [rpow_one]
        _ = M ^ (-β * 2 + 1) := (rpow_add hM_pos (-β * 2) 1).symm
        _ = M ^ (1 - 2 * β) := by congr 1; ring
    calc (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) * 20
        = C₁ ^ 2 * (M ^ (-β)) ^ 2 * (C₂ * M) * 20 := by rw [h1]
      _ = C₁ ^ 2 * M ^ (-β * 2) * (C₂ * M) * 20 := by rw [h2]
      _ = 20 * C₁ ^ 2 * C₂ * (M ^ (-β * 2) * M) := by ring
      _ = 20 * C₁ ^ 2 * C₂ * M ^ (1 - 2 * β) := by rw [h3]
  linarith [h_drop, hfrac, hexp]

/-- **Uniform drop bound**: Extracts constants from global axioms. -/
theorem drop_bound_uniform :
    ∃ C : ℝ, 0 < C ∧ ∃ γ : ℝ, 1 < γ ∧
    ∀ N : ℕ, 11 ≤ N → eigenDrop N ≤ C * (N - 1 : ℝ) ^ (-γ) := by
  obtain ⟨C₁, hC₁_pos, β, hβ_gt1, h_cos⟩ := alignment_decay
  obtain ⟨C_lower, C₂, hC_lower_pos, hC2_le, h_cross⟩ := cross_norm_growth
  have hC₂_pos : 0 < C₂ := lt_of_lt_of_le hC_lower_pos hC2_le
  use 20 * C₁^2 * C₂, by positivity, 2 * β - 1, by linarith
  intro N hN
  have hN10 : 10 ≤ N := by omega
  have hNm1 : 10 ≤ N - 1 := by omega
  have hcast : (↑(N - 1) : ℝ) = (↑N : ℝ) - 1 := by
    simp [Nat.cast_sub (show 1 ≤ N by omega)]
  have h_cos' : cosAlignment (N - 1) ≤ C₁ * (↑N - 1 : ℝ) ^ (-β) := by
    rw [← hcast]; exact h_cos (N - 1) hNm1
  have h_cross' : dotProduct (crossCorrVec (N - 1)) (crossCorrVec (N - 1)) ≤ C₂ * (↑N - 1 : ℝ) := by
    rw [← hcast]; exact (h_cross (N - 1) hNm1).2
  have h_asm := drop_assembly_at N hN10 C₁ hC₁_pos β hβ_gt1 h_cos' C₂ hC₂_pos
    h_cross' (schur_lower_bound (N - 1) (by omega)) (drop_formula N (by omega))
  convert h_asm using 2
  congr 1; ring

end
