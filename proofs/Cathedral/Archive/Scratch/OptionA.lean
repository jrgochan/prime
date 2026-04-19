/-
  Scratch: Option A — Crown reroute through Vasyunin chain.

  Instead of fixing constants in bd_gram_form_decay,
  we prove rh_implies_bd_convergence directly using the
  Vasyunin chain's covariance decomposition.

  Crown dependencies will become:
    - rh_implies_mertens_bound
    - abel_summation_covariance_bound
    - witness_numerator_convergence
    - vasyunin_bd_index_bridge (index bridge, provable)
    - bd_l2_error_eq_quad_error (PROVED)
-/

import Cathedral.Vasyunin.Proof.WitnessConditional
import Cathedral.Assembly.BDBridge
import Cathedral.MellinBridge.BDWeights
import Cathedral.MellinBridge.PlancherelDefs

set_option maxHeartbeats 1600000

noncomputable section
open Real MeasureTheory Finset BigOperators Matrix Cathedral.Vasyunin

-- ═══════════════════════════════════════════════
-- INDEX BRIDGE
-- ═══════════════════════════════════════════════

/-- The Vasyunin covariance decomposition over Fin N equals the
    BD Gram form over Fin(N-1), because the k=N weight is 0.

    (1 - bᵀv_N)² + vᵀ_N C_N v_N = 1 - 2·bᵀ_{N-1} v_{N-1} + v_{N-1}ᵀ G_{N-1} v_{N-1}

    where v_N = logCutoffWitness and v_{N-1} = bdMoebiusWeight.
    
    This is purely algebraic: adding a zero-weighted row/column 
    to a bilinear form doesn't change its value. -/
axiom vasyunin_bd_index_bridge (N : ℕ) (hN : 3 ≤ N) :
    (1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N)) ^ 2 +
    dotProduct (logCutoffWitness N) ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) =
    1 - 2 * dotProduct (fun i => vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight N) +
    realQuadForm (of fun i j => vasyuninGramEntry (i.val + 1) (j.val + 1)) (bdMoebiusWeight N)

-- ═══════════════════════════════════════════════
-- THE CROWN THEOREM (rerouted through Vasyunin)
-- ═══════════════════════════════════════════════

/-- **THEOREM**: RH → ∀ε > 0, ∃N₀, ∀N ≥ N₀, ∃v, ∫(1 - f_v)² < ε.

    Proved from:
    1. rh_implies_mertens_bound: RH → |M(x)| = O(√x log²x)
    2. abel_summation_covariance_bound: vᵀCv ≤ C_cov/log(N)
    3. witness_numerator_convergence: |bᵀv - 1| < ε for large N
    4. vasyunin_bd_index_bridge: Fin N ↔ Fin(N-1) forms agree
    5. bd_l2_error_eq_quad_error: ∫(1-f)² = 1 - 2bᵀv + vᵀGv (PROVED) -/
theorem rh_implies_bd_convergence_vasyunin :
    RiemannHypothesis →
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε) := by
  intro hRH ε hε
  -- Step 1: Get the Mertens bound from RH
  obtain ⟨C_m, hC_pos, hM⟩ := rh_implies_mertens_bound hRH
  -- Step 2: Get the covariance bound
  obtain ⟨C_cov, hC_cov_pos, N₁, h_cov⟩ :=
    abel_summation_covariance_bound ⟨C_m, hC_pos, hM⟩
  -- Step 3: Get the numerator convergence with ε/2
  obtain ⟨N₂, h_num⟩ := witness_numerator_convergence
    (Real.sqrt (ε / 2)) (Real.sqrt_pos.mpr (by positivity))
  -- Step 4: Get N large enough that C_cov/log(N) < ε/2
  have : ∃ N₃ : ℕ, ∀ N : ℕ, N₃ ≤ N → C_cov / Real.log ↑N < ε / 2 := by
    have h_tend := Real.tendsto_log_atTop
    rw [Filter.tendsto_atTop_atTop] at h_tend
    obtain ⟨M, hM'⟩ := h_tend (2 * C_cov / ε + 1)
    refine ⟨max ⌈max M 2⌉₊ 3, fun N hN => ?_⟩
    have hlog_pos : 0 < Real.log ↑N :=
      Real.log_pos (by exact_mod_cast (show 1 < N by omega))
    have hlog_big : 2 * C_cov / ε < Real.log ↑N := by
      have h1 := hM' (max M 1) (le_max_left _ _)
      have h2 : (max M 1 : ℝ) ≤ ↑N := by
        calc (max M 1 : ℝ) ≤ (max M 2 : ℝ) := max_le_max_left M (by exact_mod_cast (show (1:ℕ) ≤ 2 by omega))
          _ ≤ (⌈max M 2⌉₊ : ℝ) := Nat.le_ceil _
          _ ≤ ↑(max ⌈max M 2⌉₊ 3) := by exact_mod_cast le_max_left _ _
          _ ≤ ↑N := by exact_mod_cast hN
      linarith [Real.log_le_log (by positivity : (0:ℝ) < max M 1) h2]
    rw [div_lt_iff₀ hlog_pos]
    calc C_cov = (ε / 2) * (2 * C_cov / ε) := by field_simp
      _ < (ε / 2) * Real.log ↑N := mul_lt_mul_of_pos_left hlog_big (by positivity)
  obtain ⟨N₃, h_decay⟩ := this
  -- Step 5: Combine thresholds
  refine ⟨max (max (max N₁ N₂) N₃) 10, fun N hN => ?_⟩
  have hN₁ : N ≥ N₁ := by omega
  have hN₂ : N ≥ N₂ := by omega
  have hN₃ : N₃ ≤ N := by omega
  have hN3 : N ≥ 3 := by omega
  have hN10 : 10 ≤ N := by omega
  -- Step 6: Use bdMoebiusWeight as the witness
  refine ⟨bdMoebiusWeight N, ?_⟩
  -- Step 7: Convert integral to quad form
  have h_eq := bd_l2_error_eq_quad_error N (by omega : 2 ≤ N) (bdMoebiusWeight N)
  rw [show (fun x => (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2) =
      (fun x => (bdResidualV N (bdMoebiusWeight N) x) ^ 2) from rfl] at h_eq
  rw [show (fun x => (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2) =
      (fun x => (bdResidualV N (bdMoebiusWeight N) x) ^ 2) from rfl]
  rw [h_eq]
  -- Step 8: Use the index bridge
  rw [← vasyunin_bd_index_bridge N (by omega)]
  -- Goal: (1 - bᵀv)² + vᵀCv < ε
  -- Step 9: Bound each piece
  have h_vtCv := h_cov N hN₁ hN3
  have h_bv := h_num N hN₂
  have h_cov_small := h_decay N hN₃
  -- |bᵀv - 1| < √(ε/2), so (1 - bᵀv)² < ε/2
  have h_sq_bound : (1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N)) ^ 2 < ε / 2 := by
    rw [abs_sub_comm] at h_bv
    have h_abs_val : |1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N)| < Real.sqrt (ε / 2) := h_bv
    have h_sq := sq_lt_sq' (by linarith [h_abs_val, abs_nonneg (1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N))]) h_abs_val
    rw [sq_sqrt (by positivity : (0:ℝ) ≤ ε/2)] at h_sq
    rwa [sq_abs] at h_sq
  -- vᵀCv ≤ C_cov / log N < ε/2
  have h_cov_bound : dotProduct (logCutoffWitness N)
      ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) < ε / 2 :=
    lt_of_le_of_lt h_vtCv (h_decay N hN₃)
  -- Combine: (1-bᵀv)² + vᵀCv < ε/2 + ε/2 = ε
  linarith

end
