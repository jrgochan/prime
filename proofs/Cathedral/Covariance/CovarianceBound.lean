/-
  Cathedral/Covariance/CovarianceBound.lean

  ## Self-Contained Covariance Bound (Breaking the Cycle)

  ### The Circular Dependency Problem

  GramFormProof proves: covariance axiom → gram_form
  PerronCrown proves:   gram_form → covariance (redundant with axiom!)

  This creates: GramFormProof ← PerronCrown ← GramFormProof

  ### The Solution

  This file proves `covariance_bound_from_mertens_34` as a THEOREM
  by taking the Mertens bound as input and using:
  1. L² = (1-bᵀv)² + vᵀCv (bias-variance decomposition)
  2. Direct L² bound from linear + quadratic estimates
  3. Since (1-bᵀv)² ≥ 0: vᵀCv ≤ L²

  This does NOT import GramFormProof or PerronCrown.
  It uses the MillenniumWall's mertens_l2_decay (which provides an
  independent L² bound from direct analysis of the bilinear form).

  Created: April 27, 2026 — Breaking the Cycle
-/

import Cathedral.Covariance.L2Convergence
import Cathedral.NymanBeurling.BDBridge
import Cathedral.NymanBeurling.VasyuninBypass

noncomputable section
open Real Matrix Finset MeasureTheory Filter Cathedral.Vasyunin ArithmeticFunction

-- ═══════════════════════════════════════════════
-- THE COVARIANCE BOUND (THEOREM, not axiom)
-- ═══════════════════════════════════════════════

/-- **THEOREM**: Under Mertens x^{3/4}, the covariance vᵀCv ≤ C/logN.

    Proved directly from:
    1. mertens_l2_decay (L2Convergence.lean): ∫(1-f)² ≤ K/logN
    2. bias-variance decomposition: ∫(1-f)² = (1-bᵀv)² + vᵀCv
    3. Non-negativity: (1-bᵀv)² ≥ 0 implies vᵀCv ≤ ∫(1-f)²

    This breaks the circular dependency by providing covariance
    from the MillenniumWall's INDEPENDENT L² bound. -/
theorem covariance_bound_from_mertens_34_proved :
    (∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((_root_.mertensFunction x : ℤ) : ℝ)| ≤ C * x ^ ((3 : ℝ)/4)) →
    ∃ C_cov : ℝ, C_cov > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninCovMatrix N).mulVec
          (logCutoffWitness N)) ≤ C_cov / Real.log ↑N := by
  intro ⟨C_m, hC_m_pos, hM⟩
  -- Step 1: L² decay from Mertens (INDEPENDENT — no covariance axiom needed)
  obtain ⟨K, hK_pos, hK_bound⟩ := mertens_l2_decay C_m hC_m_pos hM
  -- Step 2: Assemble uniform covariance bound
  refine ⟨K, hK_pos, 10, fun N hN hN3 => ?_⟩
  -- Step 3: BD quad form expansion (BDBridge.lean)
  have h_l2 := bd_l2_error_eq_quad_error N (by omega : 2 ≤ N) (bdMoebiusWeight N)
  -- Step 4: Vasyunin index bridge (VasyuninBypass.lean)
  have h_bridge := (Nat.sub_add_cancel (show 1 ≤ N by omega) ▸
    vasyunin_bd_index_bridge (N-1) (by omega : 2 ≤ N-1)).symm
  -- Step 5: Since (1-bᵀv)² ≥ 0, we get vᵀCv ≤ ∫(1-f)²
  have h_sq_nn := sq_nonneg (1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N))
  -- Step 6: ∫(1-f)² ≤ K/logN
  have h_l2_bound := hK_bound N (by omega : 10 ≤ N)
  -- Chain: vᵀCv ≤ (1-bᵀv)² + vᵀCv = ∫(1-f)² ≤ K/logN
  linarith [h_l2, h_bridge, h_sq_nn, h_l2_bound]

end
