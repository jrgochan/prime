/-
  Cathedral/AbelTail/Assembly.lean

  ## The Crown: abel_mertens_tail as THEOREM

  [ON CROWN PATH — abel_mertens_tail_raw GRADUATED to theorem 🎓]

  Combines s1_decay, s2_decay, s3_decay into a single uniform bound.
  When all sorry are closed, this replaces the axiom
  `abel_mertens_tail_raw` in FinalDragon.lean.

  SORRY STATUS:
  - s1_decay: ✅ PROVED
  - s2_decay: ❌ 2 sorry (S2Decay.lean)
  - s3_decay: ❌ 1 sorry (S3Decay.lean)
-/

import Cathedral.AbelTail.S1Decay
import Cathedral.AbelTail.S2Decay
import Cathedral.AbelTail.S3Decay

noncomputable section
open Real Finset BigOperators

-- ════════════════════════════════════════════════
-- THE CROWN: COMBINED TAIL BOUND
-- ════════════════════════════════════════════════

/-- **THE CROWN**: Abel-Mertens tail bound — THEOREM, not axiom.
    Combines s1_decay, s2_decay, s3_decay into a single uniform bound.
    This replaces the axiom `abel_mertens_tail_raw` in FinalDragon.lean. -/
theorem abel_mertens_tail_proved
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (hPNT₁ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ))
      Filter.atTop (nhds 0))
    (hPNT₂ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        Real.log (k : ℝ) / (k : ℝ))
      Filter.atTop (nhds (-1)))
    (L₃ : ℝ) -- The limit -2γ; generalized for import independence
    (hPNT₃ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
      Filter.atTop (nhds L₃)) :
    ∃ C : ℝ, C > 0 ∧ ∀ N : ℕ, 2 ≤ N →
    |S₁_at N| ≤ C * (N : ℝ) ^ (-(1:ℝ)/4) ∧
    |S₂_at N - (-1)| ≤ C * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) ∧
    |S₃_at N - L₃| ≤
      C * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := by
  -- Get individual bounds
  obtain ⟨C₁, hC₁_pos, hC₁⟩ := s1_decay C_m hC hMertens hPNT₁
  obtain ⟨C₂, hC₂_pos, hC₂⟩ := s2_decay C_m hC hMertens hPNT₂
  obtain ⟨C₃, hC₃_pos, hC₃⟩ := s3_decay C_m hC hMertens L₃ hPNT₃
  -- Combine into single C
  use max C₁ (max C₂ C₃)
  refine ⟨by positivity, fun N hN => ?_⟩
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have h_rpow_pos : 0 < (N : ℝ) ^ (-(1:ℝ)/4) := Real.rpow_pos_of_pos hN_pos _
  have h_rpow_nn : 0 ≤ (N : ℝ) ^ (-(1:ℝ)/4) := h_rpow_pos.le
  have hlog_nn : 0 ≤ Real.log (N : ℝ) :=
    Real.log_nonneg (by exact_mod_cast show 1 ≤ N by omega)
  refine ⟨?_, ?_, ?_⟩
  · -- S₁ bound
    calc |S₁_at N| ≤ C₁ * (N : ℝ) ^ (-(1:ℝ)/4) := hC₁ N hN
      _ ≤ max C₁ (max C₂ C₃) * (N : ℝ) ^ (-(1:ℝ)/4) := by
          apply mul_le_mul_of_nonneg_right (le_max_left _ _) h_rpow_nn
  · -- S₂ bound
    calc |S₂_at N - (-1)| ≤ C₂ * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := hC₂ N hN
      _ ≤ max C₁ (max C₂ C₃) * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := by
          apply mul_le_mul_of_nonneg_right _ hlog_nn
          apply mul_le_mul_of_nonneg_right _ h_rpow_nn
          exact le_trans (le_max_left C₂ C₃) (le_max_right C₁ _)
  · -- S₃ bound
    calc |S₃_at N - L₃|
        ≤ C₃ * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := hC₃ N hN
      _ ≤ max C₁ (max C₂ C₃) * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := by
          apply mul_le_mul_of_nonneg_right _ (sq_nonneg _)
          apply mul_le_mul_of_nonneg_right _ h_rpow_nn
          exact le_trans (le_max_right C₂ C₃) (le_max_right C₁ _)

end
