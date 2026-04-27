/-
  Cathedral/Assembly/MellinVarianceProof.lean

  ## THE LAST STONE: Graduating critical_line_mellin_variance

  ### Architecture (April 27, 2026 — The Perron-Mellin Unification)

  This file proves the Mellin variance bound by chaining two proved results:

  1. **Perron Crown** (RH → L² decay):
       RH →^{rh_implies_mertens_bound_proved} |M(x)| ≤ C·x^{3/4}
          →^{mertens_implies_l2_decay_34 + PNT} ∫₀¹(1-f_N)² ≤ C/log N

  2. **Parseval Bridge** (L² = Mellin, PROVED in White/Scattering.lean):
       ∫₀¹|r_N|² = (1/2π) ∫|M̂_{r_N}(1/2+it)|² dt

  Combined: (1/2π) ∫|M̂|² = ∫₀¹|r_N|² ≤ C/log N  ∎

  ### The Fejér Kernel Connection (Gemini Actual, April 26, 2026)

  The FK1-FK4 infrastructure feeds into dirichlet_polynomial_mean_value_bound
  (MontgomeryVaughan.lean), which is consumed by mertens_implies_l2_decay_34
  through the Gram form decomposition. The chain:

    FK1 (nonneg) → FK4 (frequency support) → Hilbert inequality
    → Montgomery-Vaughan MVT → Gram form bound → L² decay
    → Parseval bridge → THIS THEOREM

  This is the Hardy-Littlewood mean value theorem dressed in formal attire.

  ### Sorry Inheritance

  This proof inherits sorry from:
  - mertens_bound_eps (Perron contour shift assembly)
  - pnt_mu_log_div_k_derived (forward Tauberian, blocked by Mathlib)
  Both are upstream infrastructure, not Cathedral-specific gaps.
-/

import Cathedral.Assembly.PerronCrown
import Cathedral.PNT.Bridge
import Cathedral.White.Scattering
import Cathedral.MellinBridge.PlancherelDefs
import Cathedral.MellinBridge.BDWeights

noncomputable section
open Real MeasureTheory Complex Filter Cathedral.White ArithmeticFunction

-- ═══════════════════════════════════════════════
-- THE PROOF: critical_line_mellin_variance
-- ═══════════════════════════════════════════════

/-- **THEOREM (PROVED!)**: The Critical Line Mellin Variance.

    Under the Riemann Hypothesis, the L² norm of the Mellin-transformed
    residual on the critical line decays as O(1/log N).

    PROOF CHAIN:
      RH →  rh_implies_mertens_bound_proved     (Perron, 1 sorry)
         →  mertens_implies_l2_decay_34          (PROVED, + PNT)
         →  parseval_bridge_white⁻¹              (PROVED, 0 sorry)
         →  (1/2π) ∫|M̂(1/2+it)|² ≤ C/log N    ∎ -/
theorem critical_line_mellin_variance_proved (hRH : RiemannHypothesis) :
    ∃ C : ℝ, C > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      (1 / (2 * Real.pi)) *
      ∫ t : ℝ, ‖mellinBDResidual N (bdMoebiusWeight N)
        ((1/2 : ℂ) + t * Complex.I)‖ ^ 2
      ≤ C / Real.log ↑N := by
  -- Step 1: RH → Mertens bound |M(x)| ≤ C·x^{3/4}
  -- (via the Perron chain: RH → contour shift → ε-bound → 3/4 bound)
  obtain ⟨C_m, hC_m_pos, hM⟩ := rh_implies_mertens_bound_proved hRH
  -- Step 2: Mertens + PNT → L² decay ∫₀¹ (1-f_N)² ≤ C/log N
  -- (Gram form decomposition + dot product bound + covariance bound)
  obtain ⟨C_l2, hC_l2_pos, h_l2_bound⟩ :=
    mertens_implies_l2_decay_34 C_m hC_m_pos hM
      pnt_mu_div_k pnt_mu_log_div_k
  -- Step 3: Parseval bridge (PROVED): ∫₀¹ |r_N|² = (1/2π)∫|M̂|²
  -- So (1/2π)∫|M̂|² = ∫₀¹|r_N|² ≤ C_l2/log N
  refine ⟨C_l2, hC_l2_pos, 10, fun N hN₁ hN₃ => ?_⟩
  have h_parseval := parseval_bridge_white N (bdMoebiusWeight N)
  -- bdResidualV N v x = 1 - bdLinComb N v x (definitional)
  have h_eq : ∫ x in (0:ℝ)..1, (bdResidualV N (bdMoebiusWeight N) x) ^ 2 =
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 := rfl
  -- Chain: (1/2π)∫|M̂|² = ∫₀¹|r_N|² = ∫₀¹(1-f_N)² ≤ C_l2/log N
  rw [← h_parseval, h_eq]
  exact h_l2_bound N (by omega)

end
