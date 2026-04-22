/-
  Cathedral/Assembly/MertensConversion.lean

  ## Mertens Bound Conversion: x^{1/2}·log²x → x^{3/4}

  Proves that the tighter RH-conditional Mertens bound
  |M(x)| ≤ C·x^{1/2}·(log x)² implies the coarser
  |M(x)| ≤ C'·x^{3/4} bound.

  This was formerly THE ONE AXIOM in v5 of the Cathedral.
  Now proved as a corollary of rh_implies_mertens_bound.

  Extracted from FinalDragon.lean §1 (April 22, 2026).
-/

import Cathedral.Defs
import Cathedral.MellinBridge.MertensBound

noncomputable section
open Real

-- ════════════════════════════════════════════════
-- THE TIGHTER BOUND: RH → M(x) = O(x^{1/2}·log²x)
--     Corollary: M(x) = O(x^{3/4}) [PROVED below]
-- ════════════════════════════════════════════════

/-- **THEOREM** (was THE ONE AXIOM — now PROVED from rh_implies_mertens_bound!):
    RH implies the Mertens bound M(x) = O(x^{3/4}).

    Proof: rh_implies_mertens_bound gives |M(x)| ≤ C·x^{1/2}·(log x)².
    Since x^{1/2}·(log x)² = x^{3/4}·(log x)²·x^{-1/4}
    and (log x)²·x^{-1/4} = (x^{-1/4}·log x)·log x ≤ 4·log x ≤ 4·2·x^{1/4}
    (using rpow_quarter_log_bounded), we get |M(x)| ≤ 16C·x^{3/4}.

    This eliminates the axiom by absorbing it into rh_implies_mertens_bound. -/
theorem rh_implies_mertens_34 :
    RiemannHypothesis →
    ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C * x ^ ((3:ℝ)/4) := by
  intro hRH
  obtain ⟨C₀, hC₀_pos, hM⟩ := rh_implies_mertens_bound hRH
  -- We need: C₀ · x^{1/2} · (log x)² ≤ C · x^{3/4}
  -- i.e. C₀ · (log x)² · x^{-1/4} ≤ C
  -- From rpow_quarter_log_bounded: x^{-1/4} · log x ≤ 4 for x ≥ 1
  -- So (log x)² · x^{-1/4} = (x^{-1/4} · log x) · log x
  -- But we need a uniform bound on x^{-1/4} · (log x)²
  -- Use: x^{-1/4} · (log x)² = (x^{-1/8} · log x)² ≤ 8² = 64
  -- because x^{-1/8} · log x ≤ 8 (same technique as rpow_quarter_log_bounded)
  refine ⟨C₀ * 64, by positivity, fun x hx => ?_⟩
  have hx_pos : (0 : ℝ) < x := by linarith
  have hM_bound := hM x hx
  -- Key estimate: x^{1/2} · (log x)² ≤ 64 · x^{3/4}
  -- Equivalently: (log x)² ≤ 64 · x^{1/4}
  -- Proof: set t = x^{1/8}, then log x = 8·log t, t ≥ 1
  -- (log x)² = 64·(log t)² ≤ 64·t² = 64·x^{1/4}
  -- since log t ≤ t for t ≥ 1
  have h_key : x ^ ((1:ℝ)/2) * (Real.log x) ^ 2 ≤ 64 * x ^ ((3:ℝ)/4) := by
    set t := x ^ ((1:ℝ)/8) with ht_def
    have ht_pos : 0 < t := Real.rpow_pos_of_pos hx_pos _
    have ht_ge1 : 1 ≤ t := by
      rw [ht_def, ← Real.rpow_zero x]
      exact Real.rpow_le_rpow_of_exponent_le (by linarith) (by norm_num)
    have h_log_le : Real.log t ≤ t := by
      linarith [Real.add_one_le_exp (Real.log t),
                Real.exp_log (lt_of_lt_of_le one_pos ht_ge1)]
    have h_log_eq : Real.log x = 8 * Real.log t := by
      rw [ht_def, Real.log_rpow hx_pos]; ring
    have h_t_sq : t ^ 2 = x ^ ((1:ℝ)/4) := by
      rw [ht_def, ← Real.rpow_natCast (x ^ ((1:ℝ)/8)) 2,
          ← Real.rpow_mul (le_of_lt hx_pos)]
      norm_num
    calc x ^ ((1:ℝ)/2) * (Real.log x) ^ 2
      _ = x ^ ((1:ℝ)/2) * (8 * Real.log t) ^ 2 := by rw [h_log_eq]
      _ = x ^ ((1:ℝ)/2) * (64 * (Real.log t) ^ 2) := by ring
      _ ≤ x ^ ((1:ℝ)/2) * (64 * t ^ 2) := by
          apply mul_le_mul_of_nonneg_left _ (le_of_lt (Real.rpow_pos_of_pos hx_pos _))
          apply mul_le_mul_of_nonneg_left _ (by norm_num)
          exact pow_le_pow_left₀ (Real.log_nonneg ht_ge1) h_log_le 2
      _ = 64 * (x ^ ((1:ℝ)/2) * x ^ ((1:ℝ)/4)) := by rw [h_t_sq]; ring
      _ = 64 * x ^ ((3:ℝ)/4) := by
          congr 1
          rw [← Real.rpow_add hx_pos]
          norm_num
  calc |((mertensFunction x : ℤ) : ℝ)|
    _ ≤ C₀ * x ^ ((1:ℝ)/2) * (Real.log x) ^ 2 := hM_bound
    _ = C₀ * (x ^ ((1:ℝ)/2) * (Real.log x) ^ 2) := by ring
    _ ≤ C₀ * (64 * x ^ ((3:ℝ)/4)) := by
        apply mul_le_mul_of_nonneg_left h_key (le_of_lt hC₀_pos)
    _ = C₀ * 64 * x ^ ((3:ℝ)/4) := by ring

end
