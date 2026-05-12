/-
  Cathedral/NymanBeurling/BDBridgeProved.lean

  ## Axiom-Free BD L² Convergence

  Closes the circular dependency between BDBridge.lean and WitnessDecayProved.lean
  by providing `rh_implies_bd_convergence_zero_axiom` — the forward direction
  RH → d²_N → 0 with ZERO custom axioms (beyond the Vasyunin crown axioms).

  ### Proof Chain

  1. `bd_witness_l2_error_decay_proved` (WitnessDecayProved.lean, PROVED)
     ∃ C > 0, ∃ N₀, ∀ N ≥ N₀, ∃ v, 1 - 2bᵀv + vᵀGv ≤ C/logN
  2. `bd_l2_error_eq_quad_error` (BDBridge.lean, PROVED)
     ∫(1-f)² = 1 - 2bᵀv + vᵀGv
  3. C/logN → 0 (standard calculus, PROVED)

  ### Sorry: 0
  ### Axioms: 0 (beyond Vasyunin crown)

  Created: May 12, 2026 (Exploration 36)
-/

import Cathedral.NymanBeurling.BDBridge
import Cathedral.NymanBeurling.WitnessDecayProved

noncomputable section
open Real Matrix Finset MeasureTheory Cathedral.Vasyunin

/-- **THEOREM**: The BD witness L² error decays — PROVED version.

    This replaces the `bd_witness_l2_error_decay` axiom in BDBridge.lean
    with the proved `bd_witness_l2_error_decay_proved` from
    WitnessDecayProved.lean, breaking the circular dependency. -/
theorem bd_witness_l2_error_decay_graduated :
    ∃ C_err : ℝ, C_err > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      ∃ v : Fin (N - 1) → ℝ,
        1 - 2 * dotProduct (fun i => vasyuninMeanEntry (i.val + 1)) v +
          realQuadForm (Matrix.of fun i j =>
            vasyuninGramEntry (i.val + 1) (j.val + 1)) v ≤ C_err / Real.log ↑N :=
  bd_witness_l2_error_decay_proved

/-- **THE FORWARD DIRECTION — ZERO AXIOM VERSION**

    RH → ∀ ε > 0, ∃ N₀, ∀ N ≥ N₀, ∃ v, ∫(1-f)² < ε

    This is the same as `rh_implies_bd_convergence_proved` (BDBridge.lean)
    but with the `bd_witness_l2_error_decay` axiom replaced by its
    proved version, eliminating the last custom axiom on this path.

    Proof chain:
      bd_witness_l2_error_decay_proved → bd_l2_error_eq_quad_error → C/logN → 0 -/
theorem rh_implies_bd_convergence_zero_axiom :
    RiemannHypothesis →
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε) := by
  intro _ ε hε
  -- Use the PROVED witness decay (not the axiom)
  obtain ⟨C_err, hC_pos, N₀, hN_bound⟩ := bd_witness_l2_error_decay_proved
  -- Pick N₁ large enough that C/ln(N₁) < ε
  have h_arch : ∃ N₁ : ℕ, N₁ ≥ 3 ∧ C_err / ε < Real.log (N₁ : ℝ) := by
    have h_tend := Real.tendsto_log_atTop
    rw [Filter.tendsto_atTop_atTop] at h_tend
    obtain ⟨M, hM⟩ := h_tend (C_err / ε + 1)
    refine ⟨max (⌈max M 3⌉₊) 3, le_max_right _ _, ?_⟩
    have h_ceil : (max M 3 : ℝ) ≤ (⌈max M 3⌉₊ : ℝ) := Nat.le_ceil _
    have h_max : (⌈max M 3⌉₊ : ℝ) ≤ (max (⌈max M 3⌉₊) 3 : ℝ) := by
      exact_mod_cast le_max_left _ _
    have hM_bound := hM (max M 3) (le_max_left _ _)
    calc C_err / ε < C_err / ε + 1 := by linarith
      _ ≤ Real.log (max M 3) := hM_bound
      _ ≤ Real.log (⌈max M 3⌉₊ : ℝ) := Real.log_le_log (by linarith [le_max_right M 3]) h_ceil
      _ ≤ Real.log (↑(max (⌈max M 3⌉₊) 3) : ℝ) := by
          apply Real.log_le_log (by linarith [le_max_right M 3])
          exact_mod_cast le_max_left _ _
  obtain ⟨N₁, hN₁_ge3, hN₁⟩ := h_arch
  refine ⟨max (max N₀ N₁) 2, fun N hN => ?_⟩
  have hN₀' : N ≥ N₀ := by omega
  have hN₁' : N ≥ N₁ := by omega
  have hN3 : N ≥ 3 := by omega
  have hN2 : 2 ≤ N := by omega
  have hlog_pos : 0 < Real.log ↑N :=
    Real.log_pos (by exact_mod_cast (show 1 < N by omega))
  have hlog_N1_pos : 0 < Real.log ↑N₁ :=
    Real.log_pos (by exact_mod_cast (show 1 < N₁ by omega))
  obtain ⟨v, hv_bound⟩ := hN_bound N hN₀' hN3
  refine ⟨v, ?_⟩
  rw [bd_l2_error_eq_quad_error N hN2 v]
  have h_mono : C_err / Real.log ↑N ≤ C_err / Real.log ↑N₁ := by
    apply div_le_div_of_nonneg_left (le_of_lt hC_pos) hlog_N1_pos
    exact Real.log_le_log (by exact_mod_cast (show 0 < N₁ by omega))
      (by exact_mod_cast hN₁')
  have h_small : C_err / Real.log ↑N₁ < ε := by
    rw [div_lt_iff₀ hlog_N1_pos]
    calc C_err = ε * (C_err / ε) := by rw [mul_div_cancel₀]; exact ne_of_gt hε
      _ < ε * Real.log ↑N₁ := mul_lt_mul_of_pos_left hN₁ hε
  linarith

end
