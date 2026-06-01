/-
  Cathedral/NymanBeurling/WitnessDecayProved.lean

  ## Graduation of `bd_witness_l2_error_decay`

  This file proves the former axiom `bd_witness_l2_error_decay` as a theorem,
  by connecting the Heisenberg Bypass path to the Vasyunin λ-trick chain.

  ### Proof Strategy

  From WitnessAsymptotics.lean:
    log_cutoff_witness_bound: ∃ c > 0, ∃ N₀, ∀ M ≥ N₀,
      c · ln M ≤ rayleighQuotient M (logCutoffWitness M)

  The scalar λ-trick (LambdaTrick.lean):
    For v = (bᵀw/wᵀGw) · w, the L² error equals:
      ∫(1-f)² = 1 - S²/P = 1/(1 + S²/Q)

  Since S²/Q = rayleighQuotient ≥ c·ln M:
    1/(1 + S²/Q) ≤ 1/(c·ln M)

  And ∫(1-f)² = 1 - 2bᵀv + vᵀGv  (by bd_l2_error_eq_quad_error).

  So for N with M = N-1:
    1 - 2bᵀv + vᵀGv ≤ 1/(c·ln(N-1)) ≤ 2/(c·ln N)

  ### Axiom Dependencies

  The theorem inherits from the Vasyunin chain:
  - witness_numerator_convergence (PNT-level, unconditional)
  - discrete_riemann_hypothesis (THE Riemann Hypothesis — The Final Stone)

  ### Status: PROVED.
-/

import Cathedral.Vasyunin.Proof.Chain

noncomputable section
open Real Matrix Finset MeasureTheory Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- AUXILIARY LEMMAS (inline replicas of private lemmas from LambdaTrick)
-- ════════════════════════════════════════════════

/-- P > 0 for the BD Gram matrix applied to logCutoffWitness.
    (Replica of the private bd_gram_pos from LambdaTrick.lean.) -/
private theorem bd_gram_pos' (N : ℕ) (hN3 : N - 1 ≥ 3) :
    0 < realQuadForm
      (Matrix.of fun i j : Fin (N - 1) =>
        vasyuninGramEntry (i.val + 1) (j.val + 1))
      (logCutoffWitness (N - 1)) := by
  rw [show (Matrix.of fun i j : Fin (N - 1) =>
      vasyuninGramEntry (i.val + 1) (j.val + 1)) =
    vasyuninGramMatrix (N - 1) from bd_gram_eq_vasyunin N]
  have hPD := vasyuninGramMatrix_posDef (N - 1) hN3
  have hne := logCutoffWitness_ne_zero (N - 1) hN3
  unfold realQuadForm
  exact Cathedral.Variational.posSemidef_pos_of_ne_zero
    (vasyuninGramMatrix (N - 1))
    hPD.isHermitian hPD.posSemidef
    (by have := hPD.isUnit; rwa [isUnit_iff_isUnit_det] at this)
    (logCutoffWitness (N - 1)) hne

/-- Q > 0 for the Vasyunin covariance applied to logCutoffWitness.
    (Replica of the private bd_cov_pos from LambdaTrick.lean.) -/
private theorem bd_cov_pos' (N : ℕ) (hN3 : N - 1 ≥ 3) :
    0 < realQuadForm
      (vasyuninCovMatrix (N - 1))
      (logCutoffWitness (N - 1)) := by
  unfold realQuadForm
  exact Cathedral.Variational.posSemidef_pos_of_ne_zero
    (vasyuninCovMatrix (N - 1))
    (vasyuninCovMatrix_hermitian (N - 1))
    (vasyuninCovMatrix_posSemidef (N - 1) hN3)
    (vasyuninCovMatrix_isUnit_det (N - 1) hN3)
    (logCutoffWitness (N - 1))
    (logCutoffWitness_ne_zero (N - 1) hN3)

/-- The Gram decomposition for the BD/Vasyunin matrices.
    (Replica of the private bd_gram_decomp from LambdaTrick.lean.) -/
private theorem bd_gram_decomp' (N : ℕ) :
    realQuadForm (Matrix.of fun i j : Fin (N - 1) =>
      vasyuninGramEntry (i.val + 1) (j.val + 1))
      (logCutoffWitness (N - 1)) =
    realQuadForm (vasyuninCovMatrix (N - 1))
      (logCutoffWitness (N - 1)) +
    (dotProduct (vasyuninMeanVec (N - 1))
      (logCutoffWitness (N - 1))) ^ 2 := by
  rw [bd_gram_eq_vasyunin N]
  exact gram_cov_decomposition
    (vasyuninMeanVec (N - 1))
    (vasyuninCovMatrix (N - 1))
    (vasyuninGramMatrix (N - 1))
    (logCutoffWitness (N - 1))
    (by ext i j; simp [vasyuninCovMatrix, vasyuninGramMatrix,
          vecMulVec, vasyuninMeanVec, Matrix.of_apply])

-- ════════════════════════════════════════════════
-- THE GRADUATION: bd_witness_l2_error_decay IS A THEOREM
-- ════════════════════════════════════════════════

/-- **THEOREM (formerly axiom)**: The BD witness L² error decays as O(1/ln N).

    There exists a witness vector v such that:
      1 - 2·bᵀv + vᵀGv ≤ C/ln N

    Proof: From the Vasyunin chain's log_cutoff_witness_bound
    (which gives rayleighQuotient ≥ c·ln M), apply the scalar λ-trick
    to construct v = (bᵀw/wᵀGw)·w achieving ∫(1-f)² = 1/(1+Q).
    Then bd_l2_error_eq_quad_error converts the integral to the
    algebraic form. Since Q ≥ c·ln M, this gives the O(1/ln N) bound. -/
theorem bd_witness_l2_error_decay_proved :
    ∃ C_err : ℝ, C_err > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      ∃ v : Fin (N - 1) → ℝ,
        1 - 2 * dotProduct (fun i => vasyuninMeanEntry (i.val + 1)) v +
          realQuadForm (Matrix.of fun i j =>
            vasyuninGramEntry (i.val + 1) (j.val + 1)) v ≤ C_err / Real.log ↑N := by
  -- Step 1: Get the Rayleigh quotient lower bound from the Vasyunin chain
  obtain ⟨c, hc, M₀, h_rayleigh⟩ := log_cutoff_witness_bound
  -- Set C_err = 2/c, N₀ = max (M₀+1) 5
  refine ⟨2 / c, div_pos (by norm_num : (0:ℝ) < 2) hc,
         max (M₀ + 1) 5, fun N hN_ge hN3 => ?_⟩
  have hN5 : N ≥ 5 := le_of_max_le_right hN_ge
  have hN2 : 2 ≤ N := by omega
  have hN4 : N ≥ 4 := by omega
  have hM_ge : N - 1 ≥ M₀ := by omega
  have hM3 : N - 1 ≥ 3 := by omega
  -- Step 2: Set up the λ-trick
  -- (Following the exact pattern from forward_bridge_from_lambda_trick in LambdaTrick.lean)
  set M := N - 1
  set y := logCutoffWitness M
  set G_bd := Matrix.of fun i j : Fin (N - 1) =>
    vasyuninGramEntry (i.val + 1) (j.val + 1)
  set b_bd := fun i : Fin (N - 1) => vasyuninMeanEntry (i.val + 1)
  set S := dotProduct b_bd y
  set P := realQuadForm G_bd y
  set Q := realQuadForm (vasyuninCovMatrix M) y
  -- Step 3: Key properties (using the auxiliary lemmas above)
  have hP_pos : 0 < P := bd_gram_pos' N hM3
  have hQ_pos : 0 < Q := bd_cov_pos' N hM3
  have hP_eq : P = Q + S ^ 2 := by
    show realQuadForm G_bd y = Q + (dotProduct b_bd y) ^ 2
    rw [show b_bd = vasyuninMeanVec M from (bd_mean_eq_vasyunin N).symm]
    exact bd_gram_decomp' N
  -- Step 4: The Rayleigh quotient bound S²/Q ≥ c·ln M
  have h_SQ : c * Real.log (M : ℝ) ≤ S ^ 2 / Q := by
    have h_rq := h_rayleigh M hM_ge
    unfold rayleighQuotient at h_rq
    rw [show vasyuninMeanVec M = b_bd from (bd_mean_eq_vasyunin N)] at h_rq
    exact h_rq
  -- Step 5: Construct the witness v = (S/P) · y
  set v := fun i : Fin (N - 1) => (S / P) * y i
  refine ⟨v, ?_⟩
  -- Step 6: The λ-trick: ∫(1-f)² = 1 - S²/P
  have h_integral := lambda_trick_integral N hN2 y hP_pos
  -- bd_l2_error_eq_quad_error: ∫(1-f)² = 1 - 2bᵀv + vᵀGv
  have h_quad := bd_l2_error_eq_quad_error N hN2 v
  -- Therefore: 1 - 2bᵀv + vᵀGv = 1 - S²/P
  have h_eq : 1 - 2 * dotProduct b_bd v + realQuadForm G_bd v = 1 - S ^ 2 / P := by
    linarith
  rw [h_eq]
  -- Step 7: 1 - S²/P = 1/(1 + S²/Q) since P = Q + S²
  rw [show S ^ 2 / P = S ^ 2 / (Q + S ^ 2) from by rw [hP_eq]]
  rw [parabola_to_rayleigh S Q hQ_pos]
  -- Step 8: 1/(1 + S²/Q) ≤ 2/(c·ln N)
  have hlogM_pos : 0 < Real.log (↑(N - 1) : ℝ) :=
    Real.log_pos (by exact_mod_cast (show 1 < N - 1 by omega))
  have hlogN_pos : 0 < Real.log (↑N : ℝ) :=
    Real.log_pos (by exact_mod_cast (show 1 < N by omega))
  have h_denom_pos : 0 < 1 + S ^ 2 / Q := by positivity
  -- ln(N-1) ≥ ln(N)/2 for N ≥ 4 (since N-1 ≥ N/2)
  have h_log_half : Real.log ↑N / 2 ≤ Real.log ↑(N - 1) := by
    have hN_half : (↑N : ℝ) / 2 ≤ ↑(N - 1) := by
      have : (N : ℝ) ≤ 2 * ↑(N - 1) := by exact_mod_cast (show N ≤ 2 * (N - 1) by omega)
      linarith
    have h_mono := Real.log_le_log (by positivity : (0:ℝ) < ↑N / 2) hN_half
    have h_ln2 : Real.log 2 ≤ Real.log ↑(N - 1) :=
      Real.log_le_log (by norm_num : (0:ℝ) < 2) (by exact_mod_cast (show 2 ≤ N - 1 by omega))
    rw [Real.log_div (by positivity) (by norm_num : (2:ℝ) ≠ 0)] at h_mono
    linarith
  -- M = N - 1 so log M = log (N - 1)
  have hM_eq : (M : ℝ) = (↑(N - 1) : ℝ) := by norm_cast
  -- Final chain: 1/(1 + S²/Q) ≤ 1/(c·ln(N-1)) ≤ 2/(c·ln N)
  calc 1 / (1 + S ^ 2 / Q)
      ≤ 1 / (1 + c * Real.log (↑(N - 1) : ℝ)) := by
        apply one_div_le_one_div_of_le
        · linarith [mul_pos hc hlogM_pos]
        · have : c * Real.log (M : ℝ) = c * Real.log (↑(N - 1) : ℝ) := by rw [hM_eq]
          linarith [h_SQ]
    _ ≤ 1 / (c * Real.log ↑(N - 1)) := by
        apply one_div_le_one_div_of_le (mul_pos hc hlogM_pos)
        linarith [mul_pos hc hlogM_pos]
    _ ≤ 2 / (c * Real.log ↑N) := by
        -- Need: 1/(c·ln(N-1)) ≤ 2/(c·ln N)
        -- i.e., c·ln N ≤ 2·c·ln(N-1), i.e., ln N ≤ 2·ln(N-1)
        -- From h_log_half: ln N / 2 ≤ ln(N-1)
        rw [div_le_div_iff₀ (mul_pos hc hlogM_pos) (mul_pos hc hlogN_pos)]
        nlinarith [h_log_half, hc]
    _ = 2 / c / Real.log ↑N := by ring

end
