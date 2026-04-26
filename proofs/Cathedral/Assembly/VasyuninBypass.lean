/-
  Cathedral/Assembly/VasyuninBypass.lean

  ## The Vasyunin Bypass: RH → d² → 0 via Covariance Decomposition

  Replaces the BDBypass path (which goes through bd_gram_form_decay)
  with a direct proof using the Vasyunin tower's covariance decomposition.

  The key identity: ∫₀¹ |r_N|² = (1 - bᵀv)² + vᵀCv

  The two pieces:
    - witness_numerator_convergence: |bᵀv - 1| → 0 (PNT)
    - abel_summation_covariance_bound: vᵀCv ≤ C_cov/log(N) (RH)

  Combined: the Nyman-Beurling L² error → 0 under RH.
-/

import Cathedral.Defs
import Cathedral.Vasyunin.Proof.WitnessConditional
import Cathedral.Assembly.BDBridge
import Cathedral.MellinBridge.BDWeights
import Cathedral.MellinBridge.PlancherelDefs

set_option maxHeartbeats 1600000

noncomputable section
open Real MeasureTheory Finset BigOperators Matrix Cathedral.Vasyunin

-- ═══════════════════════════════════════════════
-- THE INDEX BRIDGE
-- ═══════════════════════════════════════════════

/-- **Weight equivalence**: The Vasyunin logCutoffWitness restricted to
    Fin(N-1) equals the BD bdMoebiusWeight.

    Both compute: -μ(k) · (1 - log(k)/log(N)) for k = i+1. -/
theorem bdWitness_eq_bdMoebiusWeight (N : ℕ) (i : Fin (N - 1)) :
    logCutoffWitness N ⟨i.val, by omega⟩ = bdMoebiusWeight N i := by
  unfold logCutoffWitness bdMoebiusWeight logWeight moebiusFn
  simp

/-- Helper: dot product bridge, parameterized as N = m+1.
    bᵀv over Fin(m+1) = bᵀv over Fin m when last weight is 0. -/
theorem dotProduct_bridge_aux (m : ℕ) (hm : 2 ≤ m) :
    dotProduct (vasyuninMeanVec (m+1)) (logCutoffWitness (m+1)) =
    dotProduct (fun (i : Fin m) => vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight (m+1)) := by
  unfold dotProduct
  rw [Fin.sum_univ_castSucc]
  have h_last : logCutoffWitness (m + 1) (Fin.last m) = 0 :=
    logCutoffWitness_last (m + 1) (by omega)
  simp only [h_last, mul_zero, add_zero]
  simp only [vasyuninMeanVec, Fin.castSucc, logCutoffWitness, bdMoebiusWeight, logWeight, moebiusFn]
  apply Finset.sum_congr rfl; intro i _; congr 2

/-- Helper: quad form bridge, parameterized as N = m+1.
    vᵀGv over Fin(m+1) = vᵀGv over Fin m when last weight is 0. -/
theorem quadForm_bridge_aux (m : ℕ) (hm : 2 ≤ m) :
    dotProduct (logCutoffWitness (m+1)) ((vasyuninGramMatrix (m+1)).mulVec (logCutoffWitness (m+1))) =
    realQuadForm (of fun (i j : Fin m) => vasyuninGramEntry (i.val + 1) (j.val + 1)) (bdMoebiusWeight (m+1)) := by
  unfold dotProduct Matrix.mulVec realQuadForm
  rw [Fin.sum_univ_castSucc]
  have h_last : logCutoffWitness (m + 1) (Fin.last m) = 0 :=
    logCutoffWitness_last (m + 1) (by omega)
  simp only [h_last, zero_mul, add_zero]
  apply Finset.sum_congr rfl; intro i _
  have h_wt : logCutoffWitness (m + 1) (Fin.castSucc i) = bdMoebiusWeight (m + 1) i := by
    unfold logCutoffWitness bdMoebiusWeight logWeight moebiusFn
    simp [Fin.castSucc, Fin.castAdd]
  rw [h_wt]; congr 1
  unfold dotProduct; rw [Fin.sum_univ_castSucc]
  simp only [h_last, mul_zero, add_zero]
  apply Finset.sum_congr rfl; intro j _
  have h_gram : (vasyuninGramMatrix (m+1)) (Fin.castSucc i) (Fin.castSucc j) =
      (of fun (a b : Fin m) => vasyuninGramEntry (a.val + 1) (b.val + 1)) i j := by
    simp [vasyuninGramMatrix, Matrix.of_apply, Fin.castSucc, Fin.castAdd]
  have h_wt_j : logCutoffWitness (m+1) (Fin.castSucc j) = bdMoebiusWeight (m+1) j := by
    unfold logCutoffWitness bdMoebiusWeight logWeight moebiusFn
    simp [Fin.castSucc, Fin.castAdd]
  rw [h_gram, h_wt_j]

/-- **INDEX BRIDGE (PROVED)**: The Vasyunin covariance decomposition over Fin(m+1)
    equals the BD Gram form over Fin m, because the (m+1)-th weight is 0.

    Proof: algebraic identity + Fin.sum_univ_castSucc with last term = 0. -/
theorem vasyunin_bd_index_bridge (m : ℕ) (hm : 2 ≤ m) :
    (1 - dotProduct (vasyuninMeanVec (m+1)) (logCutoffWitness (m+1))) ^ 2 +
    dotProduct (logCutoffWitness (m+1)) ((vasyuninCovMatrix (m+1)).mulVec (logCutoffWitness (m+1))) =
    1 - 2 * dotProduct (fun i => vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight (m+1)) +
    realQuadForm (of fun i j => vasyuninGramEntry (i.val + 1) (j.val + 1)) (bdMoebiusWeight (m+1)) := by
  -- Step 1: Algebraic: LHS = 1 - 2bᵀv + vᵀGv
  have h_alg : (1 - dotProduct (vasyuninMeanVec (m+1)) (logCutoffWitness (m+1))) ^ 2 +
      dotProduct (logCutoffWitness (m+1)) ((vasyuninCovMatrix (m+1)).mulVec (logCutoffWitness (m+1))) =
      1 - 2 * dotProduct (vasyuninMeanVec (m+1)) (logCutoffWitness (m+1)) +
      dotProduct (logCutoffWitness (m+1)) ((vasyuninGramMatrix (m+1)).mulVec (logCutoffWitness (m+1))) := by
    unfold vasyuninCovMatrix
    simp [Matrix.sub_mulVec, dotProduct_sub, vecMulVec_mulVec]
    have hdc := dotProduct_comm (logCutoffWitness (m+1)) (vasyuninMeanVec (m+1))
    have hsq := sq_nonneg (dotProduct (vasyuninMeanVec (m+1)) (logCutoffWitness (m+1)))
    -- After simp: goal involves v⬝b * b⬝v terms
    -- We know v⬝b = b⬝v (dotProduct_comm), so v⬝b * b⬝v = (b⬝v)²
    linarith [mul_self_nonneg (dotProduct (vasyuninMeanVec (m+1)) (logCutoffWitness (m+1))),
              show dotProduct (logCutoffWitness (m+1)) (vasyuninMeanVec (m+1)) *
                   dotProduct (vasyuninMeanVec (m+1)) (logCutoffWitness (m+1)) =
                   (dotProduct (vasyuninMeanVec (m+1)) (logCutoffWitness (m+1)))^2
              from by rw [hdc]; ring]
  -- h_alg is proved. Now chain the rewrites.
  rw [h_alg]
  -- After rw [h_alg], goal should be:
  -- 1 - 2*bᵀv(Fin m+1) + vᵀGv(Fin m+1) = 1 - 2*bᵀv(Fin m) + realQuadForm(Fin m)
  -- Now bridge the dot products
  congr 1
  · congr 1; congr 1
    exact dotProduct_bridge_aux m hm
  · exact quadForm_bridge_aux m hm

-- ═══════════════════════════════════════════════
-- THE THEOREM: RH → BD L² CONVERGENCE
-- ═══════════════════════════════════════════════

/-- **THEOREM**: RH implies the BD basis L² error converges to 0.

    This is the forward direction of the Nyman-Beurling equivalence,
    proved via the Vasyunin covariance decomposition.

    Proof chain:
      RH → rh_implies_mertens_bound → |M(x)| = O(√x log²x)
        → abel_summation_covariance_bound → vᵀCv ≤ C/log(N)
        + witness_numerator_convergence → bᵀv → 1
        → ∫₀¹ |r_N|² = (1-bᵀv)² + vᵀCv → 0 -/
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
  -- Step 3: Get the numerator convergence with √(ε/2)
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
  -- Step 6: Use bdMoebiusWeight as the witness
  refine ⟨bdMoebiusWeight N, ?_⟩
  -- Step 7: Convert integral to quad form (PROVED)
  have h_eq := bd_l2_error_eq_quad_error N (by omega : 2 ≤ N) (bdMoebiusWeight N)
  -- The integral of (1 - bdLinComb)² equals the quad form
  -- We need to show: ∫ (1 - bdLinComb)² < ε
  -- Using h_eq: ∫ (1 - bdLinComb)² = 1 - 2bᵀv + vᵀGv
  -- Using index bridge: 1 - 2bᵀv + vᵀGv = (1-bᵀv_V)² + vᵀCv_V
  -- So: ∫ (1 - bdLinComb)² = (1-bᵀv_V)² + vᵀCv_V < ε
  calc ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2
      = 1 - 2 * dotProduct (fun i => vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight N) +
        realQuadForm (of fun i j => vasyuninGramEntry (i.val + 1) (j.val + 1)) (bdMoebiusWeight N) := h_eq
    _ = (1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N)) ^ 2 +
        dotProduct (logCutoffWitness N) ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) :=
        (Nat.sub_add_cancel (show 1 ≤ N by omega) ▸ vasyunin_bd_index_bridge (N-1) (by omega)).symm
    _ < ε := by
      -- Goal: (1 - bᵀv)² + vᵀCv < ε
      -- Bound each piece
      have h_vtCv := h_cov N hN₁ hN3
      have h_bv := h_num N hN₂
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
