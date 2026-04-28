import Cathedral.Assembly.PerronCrown
import Cathedral.White.Scattering

/-!
  Cathedral/Assembly/MellinPerronBridge.lean

  ## The Bridge: Perron Path → Mellin Variance

  Uses the Perron Crown's L² rate bound and parseval_bridge_white
  to prove critical_line_mellin_variance without sorry.

  Chain:
    RH → Mertens x^{3/4} (Perron, 1 sorry)
       → ∫₀¹(1-f_N)² ≤ C/logN (mertens_implies_l2_decay_34)
       → (1/2π)∫|M(1/2+it)|² ≤ C/logN (parseval_bridge_white⁻¹)

  This bridges the Perron proof to eliminate the Mellin sorry.
-/

noncomputable section
open Real MeasureTheory Complex Filter Cathedral.White ArithmeticFunction

/-- **THE BRIDGE**: Perron Crown → Mellin Variance.

    Uses:
    1. rh_implies_mertens_bound_proved (Perron: RH → |M(x)| ≤ C·x^{3/4})
    2. mertens_implies_l2_decay_34 (L² rate: ∫(1-f)² ≤ C/logN)
    3. parseval_bridge_white (Parseval: L²(0,1) = Mellin L²)

    This closes the sorry in MellinVarianceProof.lean. -/
theorem critical_line_mellin_variance_from_perron (hRH : RiemannHypothesis) :
    ∃ C : ℝ, C > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      (1 / (2 * Real.pi)) *
      ∫ t : ℝ, ‖mellinBDResidual N (bdMoebiusWeight N)
        ((1/2 : ℂ) + t * Complex.I)‖ ^ 2
      ≤ C / Real.log ↑N := by
  -- Step 1: Get x^{3/4} Mertens bound from Perron
  obtain ⟨C_m, hC_pos, hM⟩ := rh_implies_mertens_bound_proved hRH
  -- Step 2: Get the L² rate from Perron chain
  obtain ⟨C_l2, hC_l2_pos, h_l2⟩ :=
    mertens_implies_l2_decay_34 C_m hC_pos hM pnt_mu_div_k pnt_mu_log_div_k
  -- Step 3: Bridge via Parseval: L²(0,1) = (1/2π)∫|M|²
  refine ⟨C_l2, hC_l2_pos, 10, fun N hN hN3 => ?_⟩
  -- parseval_bridge_white gives the EQUALITY:
  --   ∫₀¹ (bdResidualV N v x)² = (1/2π) * ∫ ‖M(1/2+it)‖²
  have h_parseval := Cathedral.White.parseval_bridge_white N (bdMoebiusWeight N)
  -- bdResidualV N v x = 1 - bdLinComb N v x by definition
  have h_residual : ∀ x : ℝ,
      (bdResidualV N (bdMoebiusWeight N) x) ^ 2 =
      (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 := by
    intro x; simp [bdResidualV]
  have h_eq : ∫ x in (0:ℝ)..1, (bdResidualV N (bdMoebiusWeight N) x) ^ 2 =
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 := by
    apply intervalIntegral.integral_congr; intro x _; exact h_residual x
  rw [h_eq] at h_parseval
  -- Now: (1/2π)∫|M|² = ∫₀¹(1-f)² ≤ C_l2/logN
  linarith [h_l2 N hN]

end
