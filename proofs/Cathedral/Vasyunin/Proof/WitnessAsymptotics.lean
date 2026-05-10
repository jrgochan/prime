/-
  Cathedral/Vasyunin/Proof/WitnessAsymptotics.lean

  Decomposition of the log_cutoff_witness_bound axiom into:
  1. witness_numerator_convergence: bᵀv → 1 (from PNT) — GRADUATED 🎓
  2. witness_covariance_decay: vᵀCv ≤ C/ln(N) (the RH content)

  Combined: Q = (bᵀv)²/vᵀCv ≥ (1/4)/(C/ln N) = ln(N)/(4C)

  Status: Zero sorry. One axiom (RH-level only).
         witness_numerator_convergence proved from PNT (May 7, 2026).
-/

import Cathedral.Vasyunin.Augmented.Rayleigh
import Cathedral.Vasyunin.Proof.WitnessNumeratorProved

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- THE NUMERATOR: bᵀv → 1
-- ════════════════════════════════════════════════

/-- **THEOREM** (GRADUATED 🎓 — was axiom, now proved from PNT).

    The dot product of the mean vector with the log-cutoff witness
    converges to 1 as N → ∞:

      bᵀv = Σ_k b_k · v_k → 1

    Proved in WitnessNumeratorProved.lean via:
    1. Dot-product expansion: bᵀv = -((1-γ)·S₁) - S₂ + [(1-γ)·S₂ + S₃]/logN
    2. Error shift: bᵀv - 1 = -(1-γ)·S₁ - (S₂+1) + [(1-γ)·(S₂+1) + (S₃+2γ) - (1+γ)]/logN
    3. PNT limits: S₁→0, S₂+1→0, S₃+2γ→0
    4. Conclusion: bᵀv - 1 → 0

    Dependencies: pnt_mu_div_k, pnt_mu_log_div_k, pnt_mu_log_sq_div_k -/
theorem witness_numerator_convergence :
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      |dotProduct (vasyuninMeanVec N) (logCutoffWitness N) - 1| < ε :=
  witness_numerator_convergence_proved

-- ════════════════════════════════════════════════
-- THE DENOMINATOR: vᵀCv → 0  (THIS IS RH)
-- ════════════════════════════════════════════════

/-- **The Witness Covariance Decay (THE RIEMANN HYPOTHESIS).**

    The covariance quadratic form of the log-cutoff witness decays:

      vᵀCv ≤ C / ln(N)

    Geometric meaning: The log-cutoff Möbius witness approximates
    the constant function 1 in L²(0,1) with error O(1/ln N).

    This IS the Riemann Hypothesis, expressed as a concrete
    statement about a quadratic form over finite sums of
    cotangent values, gcd computations, and the Möbius function.

    No complex analysis. No analytic continuation.
    No functional equation. No critical strip.
    Just: the approximation error of a specific arithmetically-defined
    vector decays at rate 1/ln(N). -/
-- AXIOM CLASS: OFF-CROWN (≡ RH, used by Heisenberg path only)
axiom witness_covariance_decay :
    ∃ C_cov : ℝ, C_cov > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) ≤ C_cov / Real.log ↑N

-- ════════════════════════════════════════════════
-- THE COMBINATION: PROVING log_cutoff_witness_bound
-- ════════════════════════════════════════════════

/-- **Key lemma**: For large N, bᵀv ≥ 1/2.
    From witness_numerator_convergence with ε = 1/2. -/
theorem witness_numerator_lower_bound :
    ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      1 / 2 ≤ dotProduct (vasyuninMeanVec N) (logCutoffWitness N) := by
  obtain ⟨N₀, hN⟩ := witness_numerator_convergence (1/2) (by norm_num : (0:ℝ) < 1/2)
  exact ⟨N₀, fun N hN₀ => by
    have h := hN N hN₀
    rw [abs_lt] at h
    linarith⟩

/-- **Key lemma**: For large N, (bᵀv)² ≥ 1/4.
    From witness_numerator_lower_bound. -/
theorem witness_numerator_sq_lower_bound :
    ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      1 / 4 ≤ (dotProduct (vasyuninMeanVec N) (logCutoffWitness N)) ^ 2 := by
  obtain ⟨N₀, hN⟩ := witness_numerator_lower_bound
  exact ⟨N₀, fun N hN₀ => by
    have h := hN N hN₀
    nlinarith [sq_nonneg (dotProduct (vasyuninMeanVec N) (logCutoffWitness N))]⟩

/-- **THE THEOREM**: The log-cutoff witness bound.

    FORMERLY AN AXIOM. Now proved from:
    1. witness_numerator_convergence (PNT-level)
    2. witness_covariance_decay (RH-level)

    Proof: For N large, bᵀv ≥ 1/2 and vᵀCv ≤ C/ln(N).
    So Q = (bᵀv)²/vᵀCv ≥ (1/4)/(C/ln N) = ln(N)/(4C). -/
theorem log_cutoff_witness_bound :
    ∃ c : ℝ, c > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      c * Real.log (N : ℝ) ≤ rayleighQuotient N (logCutoffWitness N) := by
  obtain ⟨C_cov, hC_pos, N₁, h_cov⟩ := witness_covariance_decay
  obtain ⟨N₂, h_num⟩ := witness_numerator_sq_lower_bound
  refine ⟨1 / (4 * C_cov), div_pos one_pos (mul_pos (by norm_num : (0:ℝ) < 4) hC_pos),
         max (max N₁ N₂) 3, fun N hN => ?_⟩
  have hN₁ : N ≥ N₁ := by omega
  have hN₂ : N ≥ N₂ := by omega
  have hN₃ : N ≥ 3 := by omega
  have hlog_pos : 0 < Real.log ↑N :=
    Real.log_pos (by exact_mod_cast (show 1 < N by omega))
  -- The covariance bound
  have h_vtCv := h_cov N hN₁ hN₃
  -- vᵀCv > 0 (from covariance PD + witness nonzero)
  have h_vtCv_pos : dotProduct (logCutoffWitness N)
      ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) > 0 :=
    Cathedral.Variational.posSemidef_pos_of_ne_zero
      (vasyuninCovMatrix N)
      (vasyuninCovMatrix_hermitian N)
      (vasyuninCovMatrix_posSemidef N hN₃)
      (vasyuninCovMatrix_isUnit_det N hN₃)
      (logCutoffWitness N)
      (by
        intro h_eq
        have h0 : logCutoffWitness N ⟨0, by omega⟩ = 0 := by rw [h_eq]; rfl
        simp only [logCutoffWitness, moebiusFn] at h0
        rw [ArithmeticFunction.moebius_apply_one] at h0
        simp [Real.log_one] at h0)
  -- The numerator bound
  have h_num_sq := h_num N hN₂
  -- Unfold rayleighQuotient
  unfold rayleighQuotient
  -- Goal: 1/(4C) · ln(N) ≤ (bᵀv)² / vᵀCv
  -- i.e., 1/(4C) · ln(N) · vᵀCv ≤ (bᵀv)²
  rw [le_div_iff₀ h_vtCv_pos]
  -- Goal: 1/(4C) · ln(N) · vᵀCv ≤ (bᵀv)²
  -- From h_vtCv: vᵀCv ≤ C/ln(N)
  -- So 1/(4C) · ln(N) · vᵀCv ≤ 1/(4C) · ln(N) · C/ln(N) = 1/4
  -- And from h_num_sq: 1/4 ≤ (bᵀv)²
  calc 1 / (4 * C_cov) * Real.log ↑N *
        dotProduct (logCutoffWitness N)
          ((vasyuninCovMatrix N).mulVec (logCutoffWitness N))
      ≤ 1 / (4 * C_cov) * Real.log ↑N * (C_cov / Real.log ↑N) := by
          apply mul_le_mul_of_nonneg_left h_vtCv
          apply mul_nonneg
          · exact div_nonneg one_pos.le (mul_pos (by norm_num : (0:ℝ) < 4) hC_pos).le
          · exact hlog_pos.le
    _ = 1 / 4 := by field_simp
    _ ≤ (dotProduct (vasyuninMeanVec N) (logCutoffWitness N)) ^ 2 := h_num_sq

end Cathedral.Vasyunin
