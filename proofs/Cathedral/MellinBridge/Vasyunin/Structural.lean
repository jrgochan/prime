/-
  Cathedral/MellinBridge/Vasyunin/Structural.lean

  Structural properties of the Vasyunin Gram matrix:
  symmetry, decomposition, diagonal positivity, mean vector positivity.
-/

import Cathedral.MellinBridge.Vasyunin.Defs

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

/-- Euler-Mascheroni constant γ ≈ 0.5772 -/
local notation "γ" => Real.eulerMascheroniConstant

-- ════════════════════════════════════════════════
-- PART VI: STRUCTURAL PROPERTIES
-- ════════════════════════════════════════════════

/-- The Gram entry is symmetric: G(j,k) = G(k,j).
    Proof sketch:
    - j = k case: trivial (same branch)
    - j ≠ k case: gcd(j,k) = gcd(k,j), so d, jp, kp swap correctly
      term1: (1/j + 1/k) = (1/k + 1/j) by add_comm
      term2: (j-k)/(2jk)·ln(k/j) = (k-j)/(2kj)·ln(j/k) by neg·neg
      term3: V(j',k') + V(k',j') = V(k',j') + V(j',k') by add_comm
      term4: 1/(jk) = 1/(kj) by mul_comm -/
theorem vasyuninGramEntry_comm (j k : ℕ) :
    vasyuninGramEntry j k = vasyuninGramEntry k j := by
  unfold vasyuninGramEntry
  by_cases hjk : j = k
  · subst hjk; rfl
  · have hkj : k ≠ j := Ne.symm hjk
    simp only [hjk, hkj, ↓reduceIte, Nat.gcd_comm]
    by_cases hj0 : (j : ℕ) = 0
    · subst hj0; simp
    · by_cases hk0 : (k : ℕ) = 0
      · subst hk0; simp
      · have hj : (↑j : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr hj0
        have hk : (↑k : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr hk0
        rw [Real.log_div (Nat.cast_ne_zero.mpr hk0) (Nat.cast_ne_zero.mpr hj0),
            Real.log_div (Nat.cast_ne_zero.mpr hj0) (Nat.cast_ne_zero.mpr hk0)]
        ring

/-- The Vasyunin Gram matrix is symmetric. -/
theorem vasyuninGramMatrix_symmetric (N : ℕ) :
    (vasyuninGramMatrix N).IsHermitian := by
  unfold IsHermitian
  funext i j
  simp only [conjTranspose_apply, star_trivial, vasyuninGramMatrix, of_apply]
  exact vasyuninGramEntry_comm (j.val + 1) (i.val + 1)

/-- G = C + bbᵀ (decomposition for Sherman-Morrison). -/
theorem vasyuninGram_eq_cov_plus_mean (N : ℕ) :
    vasyuninGramMatrix N =
    vasyuninCovMatrix N + vecMulVec (vasyuninMeanVec N) (vasyuninMeanVec N) := by
  unfold vasyuninCovMatrix
  simp [sub_add_cancel]

/-- The mean outer product bbᵀ is positive semidefinite (rank-1 PSD).
    Direct application of vecMulVec_self_posSemidef. -/
theorem vasyuninMeanOuterProduct_posSemidef (N : ℕ) :
    (vecMulVec (vasyuninMeanVec N) (vasyuninMeanVec N)).PosSemidef :=
  Cathedral.Variational.vecMulVec_self_posSemidef _

/-- The mean outer product bbᵀ is Hermitian (symmetric). -/
theorem vasyuninMeanOuterProduct_hermitian (N : ℕ) :
    (vecMulVec (vasyuninMeanVec N) (vasyuninMeanVec N)).IsHermitian :=
  Cathedral.Variational.vecMulVec_self_hermitian _

-- ════════════════════════════════════════════════
-- PART VI-B: MEAN VECTOR POSITIVITY
-- ════════════════════════════════════════════════

/-- The mean entry b_k is strictly positive for all k ≥ 1.
    b_k = (ln(k) + 1 - γ) / k > 0 since:
    - ln(k) ≥ 0 for k ≥ 1
    - 1 - γ > 1 - 2/3 = 1/3 > 0
    - k > 0 -/
theorem vasyuninMeanEntry_pos (k : ℕ) (hk : k ≥ 1) :
    vasyuninMeanEntry k > 0 := by
  unfold vasyuninMeanEntry
  have hk_pos : (k : ℝ) > 0 := Nat.cast_pos.mpr (by omega)
  apply div_pos _ hk_pos
  have h_gamma : Real.eulerMascheroniConstant < 2 / 3 :=
    Real.eulerMascheroniConstant_lt_two_thirds
  have h_log_nn : Real.log (k : ℝ) ≥ 0 := Real.log_nonneg (by exact_mod_cast hk)
  linarith

/-- All entries of the mean vector are positive for N ≥ 1. -/
theorem vasyuninMeanVec_pos (N : ℕ) (_hN : N ≥ 1) (i : Fin N) :
    vasyuninMeanVec N i > 0 := by
  unfold vasyuninMeanVec
  exact vasyuninMeanEntry_pos (i.val + 1) (by omega)

-- ════════════════════════════════════════════════
-- PART VI-C: GRAM DIAGONAL POSITIVITY
-- ════════════════════════════════════════════════

/-- Key constant bound: ln(2π) - γ > 1.
    Proof chain: ln(2π) = ln(2) + ln(π) > 0.693 + 1 = 1.693,
    and γ < 2/3 = 0.667, so ln(2π) - γ > 1.026 > 1. -/
theorem log_two_pi_sub_euler_gt_one :
    Real.log (2 * Real.pi) - Real.eulerMascheroniConstant > 1 := by
  have h_log2 : (0.6931471803 : ℝ) < Real.log 2 := Real.log_two_gt_d9
  have h_e_lt_3 : Real.exp 1 < 3 := Real.exp_one_lt_three
  have h_pi_gt : (3 : ℝ) < Real.pi := pi_gt_three
  have h_gamma : Real.eulerMascheroniConstant < 2 / 3 :=
    Real.eulerMascheroniConstant_lt_two_thirds
  have h_log3 : 1 < Real.log 3 := by
    rw [show (1 : ℝ) = Real.log (Real.exp 1) from (Real.log_exp 1).symm]
    exact Real.log_lt_log (Real.exp_pos 1) h_e_lt_3
  have h_logpi : 1 < Real.log Real.pi := by
    calc 1 < Real.log 3 := h_log3
         _ < Real.log Real.pi := by
           exact Real.log_lt_log (by norm_num : (0 : ℝ) < 3) h_pi_gt
  have h_log2pi : Real.log (2 * Real.pi) = Real.log 2 + Real.log Real.pi := by
    rw [Real.log_mul (by norm_num : (2 : ℝ) ≠ 0) (ne_of_gt Real.pi_pos)]
  rw [h_log2pi]
  linarith

/-- **Gram Diagonal Positivity**: G(k,k) > 0 for all k ≥ 1. -/
theorem vasyuninGramEntry_diag_pos (k : ℕ) (hk : k ≥ 1) :
    vasyuninGramEntry k k > 0 := by
  unfold vasyuninGramEntry
  simp only [ite_true]
  have hk_pos : (k : ℝ) > 0 := Nat.cast_pos.mpr (by omega)
  have hk_ne : (k : ℝ) ≠ 0 := ne_of_gt hk_pos
  have hk_sq_pos : (k : ℝ) ^ 2 > 0 := pow_pos hk_pos 2
  have h_const := log_two_pi_sub_euler_gt_one
  rw [show (log (2 * Real.pi) - γ) / (k : ℝ) -
      1 / (k : ℝ) ^ 2 =
      ((log (2 * Real.pi) - γ) * k - 1) /
      (k : ℝ) ^ 2 by field_simp]
  apply div_pos _ hk_sq_pos
  have hk1 : (1 : ℝ) ≤ (k : ℝ) := by exact_mod_cast hk
  nlinarith [mul_le_mul_of_nonneg_left hk1 (by linarith : (0 : ℝ) ≤ log (2 * Real.pi) - γ)]

/-- Every diagonal entry of the Gram matrix is strictly positive. -/
theorem vasyuninGramMatrix_diag_pos (N : ℕ) (i : Fin N) :
    vasyuninGramMatrix N i i > 0 := by
  unfold vasyuninGramMatrix
  simp only [of_apply]
  exact vasyuninGramEntry_diag_pos (i.val + 1) (by omega)

-- NOTE: The Gram diagonal G(k,k) = A/k - 1/k² is NOT monotone for all k.
-- In fact G(1,1) = A - 1 ≈ 0.026 < G(2,2) = A/2 - 1/4 ≈ 0.263.
-- The function f(x) = A/x - 1/x² has f'(x) = (-Ax+2)/x³, so it
-- INCREASES for x < 2/A ≈ 1.95 and decreases for x > 2/A.
-- Maximum is at x = 2/A, between k=1 and k=2.

end Cathedral.Vasyunin
