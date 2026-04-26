/-
  Cathedral/Assembly/CovarianceDirect.lean

  ## Direct Covariance Bound: Graduating covariance_bound_from_mertens_34

  ### Key Identity (PROVED here):
    vᵀCv = ∫₀¹(1-f_N)² - (1 - bᵀv)²

  ### Reduction Theorem (PROVED here):
    ANY uniform L² bound ∫(1-f)² ≤ C/logN implies vᵀCv ≤ C/logN.

  ### Remaining Work:
    Proving ∫₀¹(1-f_N)² ≤ C/logN directly under x^{3/4} Mertens
    requires the centered pointwise bound (Phase 2 of exploration8).

  Created: April 26, 2026 — Exploration 8
-/

import Cathedral.Assembly.GramFormProof

noncomputable section
open Real Matrix Finset MeasureTheory Filter Cathedral.Vasyunin ArithmeticFunction

-- ═══════════════════════════════════════════════
-- §1. THE KEY IDENTITY: vᵀCv = ∫(1-f)² - (1-bᵀv)²
-- ═══════════════════════════════════════════════

/-- **PROVED**: The L² error decomposes as bias² + covariance.

    ∫₀¹(1-f_N)² = (1-bᵀv)² + vᵀCv

    This follows from the BDBridge identity and the index bridge.
    Pattern from PerronCrown.lean lines 194-204. -/
theorem l2_eq_bias_sq_plus_covariance (N : ℕ) (hN : 3 ≤ N) :
    ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 =
    (1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N)) ^ 2 +
    dotProduct (logCutoffWitness N)
      ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) := by
  -- Step 1: ∫(1-f)² = 1 - 2bᵀv_BD + vᵀGv_BD  (BDBridge)
  have h_l2 := bd_l2_error_eq_quad_error N (by omega : 2 ≤ N) (bdMoebiusWeight N)
  -- Step 2: ∫(1-f)² = (1-bᵀv_V)² + vᵀCv_V via calc (PerronCrown pattern)
  calc ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2
      = 1 - 2 * dotProduct (fun i => vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight N) +
        realQuadForm (Matrix.of fun i j => vasyuninGramEntry (i.val + 1) (j.val + 1))
          (bdMoebiusWeight N) := h_l2
    _ = (1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N)) ^ 2 +
        dotProduct (logCutoffWitness N)
          ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) :=
      (Nat.sub_add_cancel (show 1 ≤ N by omega) ▸
        vasyunin_bd_index_bridge (N-1) (by omega)).symm

-- ═══════════════════════════════════════════════
-- §2. REDUCTION: L² BOUND ⟹ COVARIANCE BOUND
-- ═══════════════════════════════════════════════

/-- **PROVED**: Any L² bound immediately gives a covariance bound.
    Since (1-bᵀv)² ≥ 0, the L² error ≥ vᵀCv. -/
theorem covariance_from_l2_bound (N : ℕ) (hN : 3 ≤ N)
    (C_err : ℝ) (_hC : 0 < C_err)
    (h_l2 : ∫ x in (0:ℝ)..1,
      (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 ≤ C_err / Real.log ↑N) :
    dotProduct (logCutoffWitness N)
      ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) ≤ C_err / Real.log ↑N := by
  have h_decomp := l2_eq_bias_sq_plus_covariance N hN
  have h_sq := sq_nonneg (1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N))
  linarith

/-- **PROVED**: Uniform L² bound assembles into the covariance axiom shape. -/
theorem covariance_bound_from_l2_uniform
    (C_err : ℝ) (hC : 0 < C_err) (N₀ : ℕ)
    (h_l2 : ∀ N : ℕ, N ≥ N₀ → N ≥ 3 →
      ∫ x in (0:ℝ)..1,
        (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 ≤ C_err / Real.log ↑N) :
    ∃ C_cov : ℝ, C_cov > 0 ∧ ∃ N₀' : ℕ, ∀ N : ℕ, N ≥ N₀' →
      N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninCovMatrix N).mulVec
          (logCutoffWitness N)) ≤ C_cov / Real.log ↑N :=
  ⟨C_err, hC, N₀, fun N hN hN3 =>
    covariance_from_l2_bound N (by omega) C_err hC (h_l2 N hN hN3)⟩

-- ═══════════════════════════════════════════════
-- §3. AUDIT
-- ═══════════════════════════════════════════════

-- PROVED (zero sorry, zero axioms in THIS file):
--   ✅ l2_eq_bias_sq_plus_covariance   — The bias-variance identity
--   ✅ covariance_from_l2_bound        — Pointwise reduction
--   ✅ covariance_bound_from_l2_uniform — Uniform assembler
--
-- REMAINING (to graduate covariance_bound_from_mertens_34):
--   Need: ∫₀¹(1-f_N)² ≤ C/logN under |M(x)| ≤ C·x^{3/4}
--   This requires a direct L² bound via centered Abel summation
--   (exploration8 Phase 2 — centered pointwise bound).
--
-- The reduction is COMPLETE: once the L² bound is proved,
-- covariance_bound_from_l2_uniform immediately graduates the axiom.

end
