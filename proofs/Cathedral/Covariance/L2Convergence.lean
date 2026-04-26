/-
  Cathedral/Covariance/L2Convergence.lean

  ## L² Convergence: The Alternative Chain Crown

  Contains:
  - mertens_l2_decay: ∫(1-f)² ≤ K/logN (via mean + quadratic bounds)
  - mertens_34_implies_convergence: x^{3/4} → L² convergence
  - rh_implies_l2_convergence_proved: RH → d²_N → 0 (alternative path)

  NOTE: This is an ALTERNATIVE crown proof path, NOT the primary crown.
  The primary crown uses PerronCrown.lean → MainChain.lean with 4 axioms.
  This path uses the older 6-axiom route via rh_implies_mertens_bound.

  Extracted from FinalDragon.lean §3–§4 (April 22, 2026).
-/

import Cathedral.Covariance.MillenniumWall
import Cathedral.Perron.MertensConversion

noncomputable section
open Real Matrix Finset MeasureTheory Cathedral.Vasyunin

/-- **THEOREM (PROVED!)**: Assembly — the two sub-bounds imply the L² decay.

    ∃ K > 0, ∀ N ≥ 10, ∫(1-f)² ≤ K/log(N)

    By l2_expansion: ∫(1-f)² = 1 - 2∫f + ∫f²
    With |∫f - 1| ≤ K₁/log(N) and ∫f² ≤ 1 + K₂/log(N):
      ∫(1-f)² ≤ (2K₁ + K₂)/log(N)
    Set K = 2K₁ + K₂. -/
theorem mertens_l2_decay
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4)) :
    ∃ K : ℝ, K > 0 ∧ ∀ (N : ℕ), 10 ≤ N →
    ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 ≤
        K / Real.log (N : ℝ) := by
  -- Get existential constants from both bounds
  obtain ⟨K₁, hK₁_pos, h_lin⟩ := linear_mean_bound C_m hC hMertens
  obtain ⟨K₂, hK₂_pos, h_quad⟩ := quadratic_form_bound C_m hC hMertens
  -- Set K = 2K₁ + K₂ (absorbs all constants)
  refine ⟨2 * K₁ + K₂, by linarith, fun N hN => ?_⟩
  have hlogN_pos : (0:ℝ) < Real.log (N:ℝ) := by
    apply Real.log_pos; exact_mod_cast (show 1 < N by omega)
  -- Get concrete bounds for this N
  have h_lin_N := h_lin N hN
  have h_quad_N := h_quad N hN
  set I_f := ∫ x in (0:ℝ)..1, bdLinComb N (bdMoebiusWeight N) x
  have h_lin_lo : 1 - K₁ / Real.log (N:ℝ) ≤ I_f := by
    linarith [neg_abs_le (I_f - 1)]
  -- Expand ∫(1-f)² = 1 - 2∫f + ∫f²
  have h_expand : ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 =
      1 - 2 * I_f + ∫ x in (0:ℝ)..1, (bdLinComb N (bdMoebiusWeight N) x) ^ 2 := by
    have h_eq : (fun x => (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2) =
        (fun x => 1 - 2 * bdLinComb N (bdMoebiusWeight N) x +
          (bdLinComb N (bdMoebiusWeight N) x) ^ 2) := by ext x; ring
    rw [h_eq]
    have h1 := intervalIntegrable_const (c := (1:ℝ)) (μ := volume) (a := (0:ℝ)) (b := (1:ℝ))
    have h2 := (bdLinComb_integrable N (bdMoebiusWeight N)).const_mul 2
    have h3 := bdLinComb_sq_integrable N (bdMoebiusWeight N)
    rw [intervalIntegral.integral_add (h1.sub h2) h3,
        intervalIntegral.integral_sub h1 h2]
    rw [intervalIntegral.integral_const, sub_zero, one_smul,
        intervalIntegral.integral_const_mul]
  rw [h_expand]
  set I_f2 := ∫ x in (0:ℝ)..1, (bdLinComb N (bdMoebiusWeight N) x) ^ 2
  -- Combine: 1 - 2I_f + I_f2 ≤ 1 - 2(1 - K₁/logN) + (1 + K₂/logN) = (2K₁+K₂)/logN
  have h_ub : 1 - 2 * I_f + I_f2 ≤ (2 * K₁ + K₂) / Real.log (N:ℝ) := by
    have h1 : -2 * I_f ≤ -2 * (1 - K₁ / Real.log (N:ℝ)) := by linarith
    have h3 : 1 - 2 * (1 - K₁ / Real.log (N:ℝ)) +
        (1 + K₂ / Real.log (N:ℝ)) =
        (2 * K₁ + K₂) / Real.log (N:ℝ) := by field_simp; ring
    linarith
  linarith

/-- **THEOREM**: Mertens O(x^{3/4}) → L² convergence.

    Given ∃ K, ∫(1-f)² ≤ K/log(N), for any ε > 0,
    choose N > e^{K/ε} so K/log(N) < ε. -/
theorem mertens_34_implies_convergence :
    (∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C * x ^ ((3:ℝ)/4)) →
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀,
      ∃ v : Fin (N - 1) → ℝ,
        ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε := by
  intro ⟨C_m, hC, hMertens⟩ ε hε
  -- Get the existential K from mertens_l2_decay
  obtain ⟨K, hK_pos, hK_bound⟩ := mertens_l2_decay C_m hC hMertens
  -- Choose N₀ large enough that K/log(N₀) < ε
  set N₀ := max 10 (⌈Real.exp (K / ε)⌉₊ + 1)
  refine ⟨N₀, fun N hN => ?_⟩
  have hN10 : 10 ≤ N := by omega
  have hK_N := hK_bound N hN10
  refine ⟨bdMoebiusWeight N, lt_of_le_of_lt hK_N ?_⟩
  have hlogN_pos : (0:ℝ) < Real.log (N:ℝ) := by
    apply Real.log_pos; exact_mod_cast (show 1 < N by omega)
  rw [div_lt_iff₀ hlogN_pos]
  have hN_large : Real.exp (K / ε) < (N:ℝ) := by
    calc Real.exp (K / ε) ≤ ↑⌈Real.exp (K / ε)⌉₊ := Nat.le_ceil _
      _ < (N:ℝ) := by exact_mod_cast (show ⌈Real.exp (K / ε)⌉₊ < N by omega)
  have h_log : K / ε < Real.log (N:ℝ) := by
    rw [← Real.log_exp (K / ε)]
    exact Real.log_lt_log (Real.exp_pos _) hN_large
  calc K = K / ε * ε := (div_mul_cancel₀ K (ne_of_gt hε)).symm
    _ < Real.log (N:ℝ) * ε := mul_lt_mul_of_pos_right h_log hε
    _ = ε * Real.log (N:ℝ) := mul_comm _ _

-- ════════════════════════════════════════════════
-- §4. THE CROWN: rh_implies_l2_convergence (PROVED!)
-- ════════════════════════════════════════════════

/-- **THEOREM**: RH ⟹ d²_N → 0.

    FORMERLY: axiom rh_implies_l2_convergence (OneCrown.lean)
    NOW: theorem via: rh_implies_mertens_34 → mertens_34_implies_convergence -/
theorem rh_implies_l2_convergence_proved :
    RiemannHypothesis →
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀,
      ∃ v : Fin (N - 1) → ℝ,
        ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε := by
  intro hRH
  exact mertens_34_implies_convergence (rh_implies_mertens_34 hRH)

-- ════════════════════════════════════════════════
-- AXIOM AUDIT
-- ════════════════════════════════════════════════

-- #print axioms rh_implies_l2_convergence_proved
-- NOTE: This is the ALTERNATIVE path. It uses more axioms than the
-- primary crown (MainChain.nyman_beurling_equivalence, 4 axioms via PerronCrown).
-- abel_mertens_tail_raw is NO LONGER listed — it graduated to theorem! 🎓

end
