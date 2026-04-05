/-
  Cathedral/Mertens/Algebraic.lean

  ## Pure ℝ algebraic helper lemmas.

  These are generic real-analysis utilities used by the NB distance decay proof.
  None depend on Gram matrices or number theory — just real arithmetic.
-/

import Cathedral.Defs

noncomputable section
open Real MeasureTheory Set Finset

-- ════════════════════════════════════════════════
-- QUADRATIC ERROR BOUND
-- ════════════════════════════════════════════════

lemma quadratic_bound_of_bounds
    (M L A D B Q : ℝ) (hM : M > 0) (_hL : L > 0)
    (_hA : A > 0) (_hD : D > 0)
    (hB : B ≥ M / 2 - A * L)
    (hQ : Q ≤ M ^ 2 / 4 + D * (M + 1)) :
    1 - 2 * (2 / M * B) + (2 / M) ^ 2 * Q ≤
    4 * A * L / M + 4 * D * (M + 1) / M ^ 2 := by
  have hM2 : M ^ 2 > 0 := by positivity
  have hMne : M ≠ 0 := ne_of_gt hM
  rw [div_add_div _ _ (ne_of_gt hM) (ne_of_gt hM2)]
  rw [le_div_iff₀ (mul_pos hM hM2)]
  have h1 : B * M ≥ M ^ 2 / 2 - A * L * M := by nlinarith
  have h2 : Q * 4 ≤ M ^ 2 + 4 * D * (M + 1) := by nlinarith
  have : (1 - 2 * (2 / M * B) + (2 / M) ^ 2 * Q) * (M * M ^ 2) =
         M ^ 3 - 4 * B * M ^ 2 + 4 * Q * M := by
    field_simp; ring
  rw [this]
  nlinarith [sq_nonneg M, sq_nonneg B]

-- ════════════════════════════════════════════════
-- ERROR SIMPLIFICATION
-- ════════════════════════════════════════════════

lemma simplify_error_bound (M L A D : ℝ) (hM : M ≥ 2) (hL : L ≥ 1)
    (hA : A > 0) (hD : D > 0) :
    4 * A * L / M + 4 * D * (M + 1) / M ^ 2 ≤
    (8 * A + 8 * D) * L / M := by
  have hMpos : M > 0 := by linarith
  have hM2pos : M ^ 2 > 0 := by positivity
  rw [div_add_div _ _ (ne_of_gt hMpos) (ne_of_gt hM2pos)]
  rw [div_le_div_iff₀ (mul_pos hMpos hM2pos) hMpos]
  have hM3 : M ^ 3 > 0 := by positivity
  have lhs_expand : (4 * A * L * M ^ 2 + M * (4 * D * (M + 1))) * M =
    4 * A * L * M ^ 3 + 4 * D * M ^ 2 * (M + 1) := by ring
  have rhs_expand : (8 * A + 8 * D) * L * (M * M ^ 2) =
    8 * A * L * M ^ 3 + 8 * D * L * M ^ 3 := by ring
  rw [lhs_expand, rhs_expand]
  have h1 : 4 * D * M ^ 2 * (M + 1) ≤ 8 * D * M ^ 3 := by
    have : 4 * D * M ^ 2 * (M + 1) = 4 * D * M ^ 3 + 4 * D * M ^ 2 := by ring
    have : 8 * D * M ^ 3 = 4 * D * M ^ 3 + 4 * D * M ^ 3 := by ring
    have hD_M2_pos : 0 < D * M ^ 2 := by positivity
    have hM_ge_1 : M - 1 ≥ 1 := by linarith
    nlinarith [mul_pos hD_M2_pos (show 0 < M - 1 by linarith)]
  have h2 : 8 * D * M ^ 3 ≤ 8 * D * L * M ^ 3 := by
    have : 0 < 8 * D * M ^ 3 := by positivity
    nlinarith
  have h3 : 4 * A * L * M ^ 3 ≤ 8 * A * L * M ^ 3 := by
    nlinarith [show 0 ≤ A * L * M ^ 3 from by positivity]
  linarith

-- ════════════════════════════════════════════════
-- RATIO FLIP
-- ════════════════════════════════════════════════

lemma ratio_flip (K C L M : ℝ) (hL : L > 0) (hM : M > 0)
    (hK : K ≥ 0) (hKC : K ≤ C) (hL2 : L ^ 2 ≤ M) :
    K * L / M ≤ C / L := by
  rw [div_le_div_iff₀ hM hL]
  calc K * L * L = K * L ^ 2 := by ring
    _ ≤ K * M := by nlinarith
    _ ≤ C * M := by nlinarith

-- ════════════════════════════════════════════════
-- LOG² ≤ N
-- ════════════════════════════════════════════════

theorem log_sq_le_self :
    ∃ N₀ : ℕ, 4 ≤ N₀ ∧ ∀ N : ℕ, N₀ ≤ N →
    Real.log (N : ℝ) ^ 2 ≤ ((N : ℝ) - 1) := by
  refine ⟨258, by omega, fun N hN => ?_⟩
  have hNge : (258 : ℝ) ≤ (N : ℝ) := by exact_mod_cast hN
  have hNnn : (0 : ℝ) ≤ (N : ℝ) := by linarith
  have h1 := Real.log_le_rpow_div hNnn (show (0:ℝ) < 1/4 by norm_num)
  set s := Real.sqrt (N : ℝ) with hs_def
  have hSnn : 0 ≤ s := Real.sqrt_nonneg _
  have hSsq : s * s = (N : ℝ) := Real.mul_self_sqrt hNnn
  have hN14 : (N : ℝ) ^ ((1:ℝ)/4) = Real.sqrt s := by
    rw [show (1:ℝ)/4 = (1/2) * (1/2) from by norm_num,
        Real.rpow_mul hNnn]
    conv_lhs => rw [show (N:ℝ) ^ ((1:ℝ)/2) = s from by rw [hs_def, Real.sqrt_eq_rpow]]
    rw [Real.sqrt_eq_rpow]
  rw [hN14] at h1
  have h1' : Real.log (N : ℝ) ≤ 4 * Real.sqrt s := by linarith [show (0:ℝ) < 1/4 from by norm_num]
  have hs16 : s ≥ 16 := by
    rw [ge_iff_le, hs_def, ← Real.sqrt_sq (show (0:ℝ) ≤ 16 by norm_num)]
    apply Real.sqrt_le_sqrt
    nlinarith
  have hSs_nn : 0 ≤ Real.sqrt s := Real.sqrt_nonneg _
  have hSs4 : Real.sqrt s ≥ 4 := by
    rw [ge_iff_le, ← Real.sqrt_sq (show (0:ℝ) ≤ 4 by norm_num)]
    apply Real.sqrt_le_sqrt; nlinarith
  have hSsSsq : Real.sqrt s * Real.sqrt s = s := Real.mul_self_sqrt hSnn
  have hlog_nn : 0 ≤ Real.log (N : ℝ) := Real.log_nonneg (by linarith : (1:ℝ) ≤ (N:ℝ))
  have h2 : Real.log (N : ℝ) ^ 2 ≤ 16 * s := by
    have : Real.log (N:ℝ) ^ 2 ≤ (4 * Real.sqrt s) ^ 2 :=
      sq_le_sq' (by linarith) h1'
    calc Real.log (N:ℝ) ^ 2 ≤ (4 * Real.sqrt s) ^ 2 := this
      _ = 16 * (Real.sqrt s * Real.sqrt s) := by ring
      _ = 16 * s := by rw [hSsSsq]
  have h3 : 16 * s ≤ (N : ℝ) - 1 := by
    rw [← hSsq]
    nlinarith [sq_nonneg (s - 16)]
  linarith

end
