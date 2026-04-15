/-
  Cathedral/MellinBridge/Vasyunin/Chain.lean

  The final proof chain: witness bound → divergence → NB distance decay.
-/

import Cathedral.Vasyunin.Proof.WitnessAsymptotics

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- PART XI: THE WITNESS BOUND (FORMERLY AN AXIOM)
-- ════════════════════════════════════════════════

-- **FORMERLY `axiom log_cutoff_witness_bound`.**
-- Now proved in WitnessAsymptotics.lean from:
--   1. witness_numerator_convergence (PNT: bᵀv → 1)
--   2. witness_covariance_decay (RH: vᵀCv ≤ C/ln N)
-- See WitnessAsymptotics.lean for the full decomposition.

/-- The log cutoff witness is nonzero for N ≥ 3. -/
theorem logCutoffWitness_ne_zero (N : ℕ) (hN : N ≥ 3) :
    logCutoffWitness N ≠ 0 := by
  intro h_eq
  have h0 : logCutoffWitness N ⟨0, by omega⟩ = 0 := by rw [h_eq]; rfl
  simp only [logCutoffWitness, moebiusFn] at h0
  rw [ArithmeticFunction.moebius_apply_one] at h0
  simp [Real.log_one] at h0

/-- The log cutoff witness has strictly positive covariance vᵀCv > 0.
    NOW A THEOREM: C is PSD with invertible det and v ≠ 0 → vᵀCv > 0. -/
theorem log_cutoff_witness_pos (N : ℕ) (hN : N ≥ 3) :
    dotProduct (logCutoffWitness N) ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) > 0 :=
  Cathedral.Variational.posSemidef_pos_of_ne_zero
    (vasyuninCovMatrix N)
    (vasyuninCovMatrix_hermitian N)
    (vasyuninCovMatrix_posSemidef N hN)
    (vasyuninCovMatrix_isUnit_det N hN)
    (logCutoffWitness N)
    (logCutoffWitness_ne_zero N hN)

-- ════════════════════════════════════════════════
-- PART XII: THE CHAIN TO RH
-- ════════════════════════════════════════════════

/-- From the witness bound + variational principle: X_N → ∞. -/
theorem quadForm_diverges :
    ∃ c : ℝ, c > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      c * Real.log (N : ℝ) ≤ vasyuninQuadForm N := by
  obtain ⟨c, hc, N₀, hN⟩ := log_cutoff_witness_bound
  refine ⟨c, hc, max N₀ 3, fun N hN₀ => ?_⟩
  have hN₀' : N ≥ N₀ := le_of_max_le_left hN₀
  have hN3 : N ≥ 3 := le_of_max_le_right hN₀
  have hQ := hN N hN₀'
  have hpos := log_cutoff_witness_pos N hN3
  have hvar := variational_lower_bound N hN3 (logCutoffWitness N) hpos
  exact le_trans hQ hvar

/-- **The NB distance squared decays to zero.**
    From X_N ≥ c·ln(N) → ∞ and d²_N = 1/(1+X_N):
    d²_N ≤ 1/(1 + c·ln(N)) → 0. -/
theorem nbDistSq_decays :
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      1 / (1 + vasyuninQuadForm N) < ε := by
  intro ε hε
  obtain ⟨c, hc, N₀, hN_bound⟩ := quadForm_diverges
  have h_arch : ∃ N₁ : ℕ, (1/ε - 1) / c < Real.log (N₁ : ℝ) := by
    have h_tend := Real.tendsto_log_atTop
    rw [Filter.tendsto_atTop_atTop] at h_tend
    obtain ⟨M, hM⟩ := h_tend ((1/ε - 1) / c + 1)
    refine ⟨⌈max M 1⌉₊, ?_⟩
    have hM_bound := hM (max M 1) (le_max_left _ _)
    have h1 : (1:ℝ) ≤ max M 1 := le_max_right _ _
    have h2 : (max M 1 : ℝ) ≤ (⌈max M 1⌉₊ : ℝ) := Nat.le_ceil _
    have := Real.log_le_log (by linarith) h2
    linarith
  obtain ⟨N₁, hN₁⟩ := h_arch
  refine ⟨max N₀ (max N₁ 1), fun N hN => ?_⟩
  have hN₀' : N ≥ N₀ := by omega
  have hN₁' : N ≥ N₁ := by omega
  have hN1 : N ≥ 1 := by omega
  have h_XN := hN_bound N hN₀'
  have h_log_mono : Real.log (N₁ : ℝ) ≤ Real.log (N : ℝ) := by
    rcases Nat.eq_zero_or_pos N₁ with rfl | hN₁_pos
    · simp; exact Real.log_nonneg (by exact_mod_cast hN1)
    · exact Real.log_le_log (Nat.cast_pos.mpr hN₁_pos) (by exact_mod_cast hN₁')
  have h_clog : 1/ε - 1 < c * Real.log (N : ℝ) := by
    have h1 : (1/ε - 1) / c < Real.log (N : ℝ) := lt_of_lt_of_le hN₁ h_log_mono
    rw [div_lt_iff₀ hc] at h1; linarith [mul_comm (Real.log (N : ℝ)) c]
  have h_X_big : 1/ε < 1 + vasyuninQuadForm N := by linarith
  have h_denom_pos : (0:ℝ) < 1 + vasyuninQuadForm N := by
    have : (0:ℝ) < 1/ε := div_pos one_pos hε
    linarith
  rw [div_lt_iff₀ h_denom_pos]
  calc 1 = ε * (1/ε) := by rw [mul_one_div_cancel (ne_of_gt hε)]
    _ < ε * (1 + vasyuninQuadForm N) := by
        apply mul_lt_mul_of_pos_left h_X_big hε

end Cathedral.Vasyunin
