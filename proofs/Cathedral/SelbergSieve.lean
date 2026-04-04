/-
  Cathedral/SelbergSieve.lean

  ## The Selberg Sieve: From Mertens-Vasyunin to RH

  **STATUS (post-Wuuthrad shift)**: The k=1 gap is CLOSED. With the
  Cathedral basis {1/x},...,{(N-1)/x}, the Selberg weight λ₁ = μ(1) = 1
  is now included at i=0, providing the essential DC component.

  ### Architecture

  Sub-axioms (Mertens.lean):
    mertens_sum + vasyunin_bound + basisInnerProd_approx
      ↓ [mertens_selberg_part_a, _part_b — sorry pending Mertens formalization]
  mertens_selberg (Mertens.lean — THEOREM from parts a+b)
      ↓ [selberg_l2_bound — PROVED by addition]
  selberg_l2_bound (this file)
      ↓ [moebius_test_bound_from_selberg — PROVED by existential witness]
  moebius_test_bound (Assembly — THEOREM)
-/

import Cathedral.Mertens

noncomputable section
open Real MeasureTheory Set

-- ════════════════════════════════════════════════
-- SECTION 1: GRAM QUADFORM BOUND (PROVED)
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: vᵀGv ≤ (Σ|vᵢ|)².

    This bound is NOT tight for Selberg weights (gives O(log²N)),
    but is useful for general vectors. The tight bound for Selberg
    weights comes from mertens_selberg part (b) in Mertens.lean. -/
theorem gram_quadform_le_sum_abs_sq (N : ℕ) (v : Fin (N - 1) → ℝ) :
    realQuadForm (gramMatrix N) v ≤
    (∑ i : Fin (N - 1), |v i|) ^ 2 := by
  unfold realQuadForm
  simp only [dotProduct, Matrix.mulVec, gramMatrix, Matrix.of]
  simp_rw [Finset.mul_sum]
  rw [sq, Finset.sum_mul]
  simp_rw [Finset.mul_sum]
  apply Finset.sum_le_sum
  intro i _hi
  apply Finset.sum_le_sum
  intro j _hj
  calc v i * (gramEntry (i.val + 1) (j.val + 1) * v j)
      = (v i * v j) * gramEntry (i.val + 1) (j.val + 1) := by ring
    _ ≤ |v i * v j| * gramEntry (i.val + 1) (j.val + 1) :=
        mul_le_mul_of_nonneg_right (le_abs_self _) (gramEntry_nonneg _ _)
    _ ≤ |v i * v j| * 1 :=
        mul_le_mul_of_nonneg_left (gramEntry_le_one _ _) (abs_nonneg _)
    _ = |v i| * |v j| := by rw [mul_one, abs_mul]

-- ════════════════════════════════════════════════
-- SECTION 2: SELBERG L² BOUND (PROVED from mertens_selberg)
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: selberg_l2_bound from mertens_selberg.

    ∫₀¹ (1 - Σ vₖ{k/x})² dx ≤ C/log(N) -/
theorem selberg_l2_bound :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N →
    ∫ x in (0:ℝ)..1,
      (1 - nbLinComb N (selbergTestVec N N) x) ^ 2 ≤
    C / Real.log (N : ℝ) := by
  obtain ⟨C, hC, N₀, hN₀, h_mertens⟩ := mertens_selberg
  refine ⟨3 * C, by linarith, N₀, hN₀, fun N hN => ?_⟩
  have hN2 : 2 ≤ N := by omega
  rw [l2_error_eq_quad_error N hN2 (selbergTestVec N N)]
  obtain ⟨h_lin, h_quad⟩ := h_mertens N hN
  set bv := dotProduct (basisInnerProd N) (selbergTestVec N N)
  set L := C / Real.log (↑N)
  have h1 : -L ≤ bv - 1/2 := (abs_le.mp h_lin).1
  have hL2 : 2 * L = 2 * C / Real.log (↑N) := by ring
  have h_linear : 1 - 2 * bv ≤ 2 * L := by linarith
  have h3 : 3 * L = 3 * C / Real.log (↑N) := by ring
  linarith

-- ════════════════════════════════════════════════
-- SECTION 3: BRIDGE TO moebius_test_bound
-- ════════════════════════════════════════════════

/-- **THEOREM**: moebius_test_bound from selberg_l2_bound. -/
theorem moebius_test_bound_from_selberg :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N → ∃ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≤ C / Real.log (N : ℝ) := by
  obtain ⟨C, hC, N₀, hN₀, h_selberg⟩ := selberg_l2_bound
  exact ⟨C, hC, N₀, hN₀, fun N hN =>
    ⟨selbergTestVec N N, h_selberg N hN⟩⟩

end
