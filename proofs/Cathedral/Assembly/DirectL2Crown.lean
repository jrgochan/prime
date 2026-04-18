/-
  Cathedral/Assembly/DirectL2Crown.lean

  ## The Direct L² Crown: RH → d² → 0 Without Vasyunin Matrices

  ELIMINATES THREE AXIOMS in one stroke:
    - vasyunin_eq_integral (the off-diagonal integral identity)
    - abel_summation_covariance_bound (the covariance quadratic form bound)
    - witness_numerator_convergence (the PNT numerator convergence)

  By using the PROVED abel_summation_bd_l2_bound_proved directly,
  which gives ∫₀¹ (1-f_N)² ≤ C·loglog(N)/log(N) from the Mertens bound alone,
  we bypass the entire Vasyunin covariance decomposition.

  FINAL CROWN: ONE Cathedral axiom — rh_implies_mertens_bound.

  Created: April 18, 2026 (The Crown Restructure)
-/

import Cathedral.Defs
import Cathedral.MellinBridge.AbelSiegeProof
import Cathedral.NymanBeurling.BDMellin

noncomputable section
open Real Matrix Finset MeasureTheory Filter

-- ═══════════════════════════════════════════════
-- LEMMA: C·loglog(N)/log(N) → 0
-- ═══════════════════════════════════════════════

/-- For x ≥ 1, log(x) ≤ x. Standard bound. -/
private lemma log_le_self {x : ℝ} (hx : 1 ≤ x) : Real.log x ≤ x := by
  have := Real.add_one_le_exp (Real.log x)
  calc Real.log x ≤ Real.log x + 1 := le_add_of_nonneg_right one_pos.le
    _ ≤ Real.exp (Real.log x) := this
    _ = x := Real.exp_log (by linarith)

/-- **loglog(N)/log(N) → 0**: For N large enough, C·loglog(N)/log(N) < ε.

    Proof strategy: use log(y) ≤ y for y ≥ 1.
    Let y = log N. Then loglog N = log(y) ≤ y = log N.
    So loglog(N)/log(N) ≤ 1. Not tight enough!

    Better: For the SECOND application, we need C/log(N) < ε,
    which holds for log(N) > C/ε, i.e., N > e^{C/ε}.

    Even better: loglog(N)/log(N) = log(log N)/log(N).
    Since log(N) → ∞, and log(y)/y → 0, we get the result.

    Concrete: use log(y) ≤ y^{1/2} · 2 for y ≥ 1 (follows from log ≤ id).
    Wait: log(y) ≤ 2·sqrt(y) for y ≥ 1? log(1)=0 ≤ 2, log(e)=1 ≤ 2√e ≈ 3.3. ✓
    Actually log(y) ≤ 2(√y - 1) ≤ 2√y for y ≥ 1. Proof: set u = √y,
    log(y) = 2log(u). Need 2log(u) ≤ 2u, i.e., log(u) ≤ u. This is log_le_self! -/
private theorem loglog_div_log_lt_eps (C : ℝ) (hC : 0 < C) :
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      C * Real.log (Real.log ↑N) / Real.log ↑N < ε := by
  intro ε hε
  -- We need N large enough that:
  -- (1) log N ≥ 1 (so loglog is defined and nonneg)
  -- (2) log N > (2C/ε)² (so 2C/√(log N) < ε)
  have h_tend := Real.tendsto_log_atTop
  rw [Filter.tendsto_atTop_atTop] at h_tend
  set L := max ((2 * C / ε) ^ 2 + 1) (Real.exp 1 + 1)
  obtain ⟨M, hM⟩ := h_tend L
  refine ⟨max (⌈max M 3⌉₊) 10, fun N hN => ?_⟩
  -- Establish log N ≥ L
  have hN_big : (max M 3 : ℝ) ≤ ↑N := by
    calc (max M 3 : ℝ) ≤ (⌈max M 3⌉₊ : ℝ) := Nat.le_ceil _
      _ ≤ ↑(max (⌈max M 3⌉₊) 10) := by exact_mod_cast le_max_left _ _
      _ ≤ ↑N := by exact_mod_cast hN
  have hlogN_ge_L : L ≤ Real.log ↑N := by
    calc L ≤ Real.log (max M 3) := hM _ (le_max_left M 3)
      _ ≤ Real.log ↑N := Real.log_le_log (by positivity) hN_big
  -- Extract bounds
  have hlogN_pos : 0 < Real.log ↑N := by
    linarith [le_max_right ((2 * C / ε) ^ 2 + 1) (Real.exp 1 + 1), Real.exp_pos 1]
  have hlogN_ge1 : 1 ≤ Real.log ↑N := by linarith [Real.exp_pos 1, le_max_right ((2 * C / ε) ^ 2 + 1) (Real.exp 1 + 1)]
  have hlogN_sq : (2 * C / ε) ^ 2 < Real.log ↑N := by
    linarith [le_max_left ((2 * C / ε) ^ 2 + 1) (Real.exp 1 + 1)]
  -- Key: log(log N) ≤ log N (since log x ≤ x for x ≥ 1)
  have h_loglog_le : Real.log (Real.log ↑N) ≤ Real.log ↑N :=
    log_le_self hlogN_ge1
  -- Key: loglog(N) ≤ 2·√(log N), because log(y) = 2·log(√y) ≤ 2·√y
  -- when √y ≥ 1, i.e., y ≥ 1.
  have h_sqrt_logN_ge1 : 1 ≤ Real.sqrt (Real.log ↑N) := by
    rw [← Real.sqrt_one]; exact Real.sqrt_le_sqrt hlogN_ge1
  have h_loglog_le_sqrt : Real.log (Real.log ↑N) ≤ 2 * Real.sqrt (Real.log ↑N) := by
    calc Real.log (Real.log ↑N)
        = Real.log (Real.sqrt (Real.log ↑N) ^ 2) := by
            rw [Real.sq_sqrt (le_of_lt hlogN_pos)]
      _ = 2 * Real.log (Real.sqrt (Real.log ↑N)) := by
            rw [Real.log_pow]; ring
      _ ≤ 2 * Real.sqrt (Real.log ↑N) := by
            apply mul_le_mul_of_nonneg_left (log_le_self h_sqrt_logN_ge1) (by norm_num)
  -- Now: C·loglog(N)/log(N) ≤ C·2·√(log N)/log(N) = 2C/√(log N)
  -- And 2C/√(log N) < ε because log N > (2C/ε)²
  have h_main : C * Real.log (Real.log ↑N) / Real.log ↑N ≤
      2 * C / Real.sqrt (Real.log ↑N) := by
    rw [div_le_div_iff₀ hlogN_pos (Real.sqrt_pos.mpr hlogN_pos)]
    calc C * Real.log (Real.log ↑N) * Real.sqrt (Real.log ↑N)
        ≤ C * (2 * Real.sqrt (Real.log ↑N)) * Real.sqrt (Real.log ↑N) := by
            apply mul_le_mul_of_nonneg_right
            · exact mul_le_mul_of_nonneg_left h_loglog_le_sqrt hC.le
            · exact (Real.sqrt_nonneg _)
      _ = 2 * C * (Real.sqrt (Real.log ↑N) * Real.sqrt (Real.log ↑N)) := by ring
      _ = 2 * C * Real.log ↑N := by
            rw [Real.mul_self_sqrt (le_of_lt hlogN_pos)]
  have h_final : 2 * C / Real.sqrt (Real.log ↑N) < ε := by
    rw [div_lt_iff₀ (Real.sqrt_pos.mpr hlogN_pos)]
    have h2C_lt : 2 * C / ε < Real.sqrt (Real.log ↑N) := by
      rw [← Real.sqrt_sq (div_nonneg (mul_nonneg (by norm_num) hC.le) hε.le)]
      exact Real.sqrt_lt_sqrt (sq_nonneg _) hlogN_sq
    have := mul_lt_mul_of_pos_right h2C_lt hε
    rw [div_mul_cancel₀ _ (ne_of_gt hε)] at this
    linarith [mul_comm (Real.sqrt (Real.log ↑N)) ε]
  linarith

-- ═══════════════════════════════════════════════
-- THE DIRECT CROWN: RH → d² → 0
-- ═══════════════════════════════════════════════

/-- **THE DIRECT CROWN**: RH → d²_BD → 0.

    Uses abel_summation_bd_l2_bound_proved DIRECTLY,
    bypassing vasyunin_eq_integral, abel_summation_covariance_bound,
    AND witness_numerator_convergence.

    PROOF CHAIN (all verified):
      RH →^{rh_implies_mertens_bound} Mertens bound
         →^{abel_summation_bd_l2_bound_proved} ∫(1-f_N)² ≤ C·loglog(N)/logN
         →^{loglog_div_log_lt_eps} C·loglog(N)/logN < ε

    AXIOM COUNT: Depends on rh_implies_mertens_bound ONLY. -/
theorem rh_implies_bd_convergence_direct :
    RiemannHypothesis →
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε) := by
  intro hRH ε hε
  -- Step 1: Get the Mertens bound from RH (ONE AXIOM)
  obtain ⟨C_m, hC_pos, hM⟩ := rh_implies_mertens_bound hRH
  -- Step 2: Get the L² bound DIRECTLY from AbelSiegeProof (PROVED!)
  obtain ⟨C_err, hC_err_pos, N₀, h_l2⟩ :=
    abel_summation_bd_l2_bound_proved ⟨C_m, hC_pos, hM⟩
  -- Step 3: Get N large enough that C_err · loglog(N)/log(N) < ε (PROVED!)
  obtain ⟨N₁, h_decay⟩ :=
    loglog_div_log_lt_eps C_err hC_err_pos ε hε
  -- Step 4: Combine thresholds
  refine ⟨max (max N₀ N₁) 10, fun N hN => ?_⟩
  have hN₀ : N ≥ N₀ := by omega
  have hN₁ : N ≥ N₁ := by omega
  have hN3 : N ≥ 3 := by omega
  -- Step 5: Get the witness and bound
  obtain ⟨v, hv⟩ := h_l2 N hN₀ hN3
  exact ⟨v, lt_of_le_of_lt hv (h_decay N hN₁)⟩

-- ═══════════════════════════════════════════════
-- AUDIT
-- ═══════════════════════════════════════════════

-- #print axioms rh_implies_bd_convergence_direct

-- EXPECTED: [propext, Classical.choice, Quot.sound,
--            Cathedral.rh_implies_mertens_bound]
--
-- ELIMINATED (3 axioms gone):
--   ❌ abel_summation_covariance_bound — bypassed by direct L² path
--   ❌ vasyunin_eq_integral — bypassed by direct L² path
--   ❌ witness_numerator_convergence — bypassed by direct L² path
--
-- From FOUR axioms to ONE.

end
