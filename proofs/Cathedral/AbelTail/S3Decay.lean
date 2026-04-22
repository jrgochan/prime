/-
  Cathedral/AbelTail/S3Decay.lean

  ## S₃ Decay: |S₃(N) + 2γ| ≤ C·N^{-1/4}·log²(N)

  Bounds the log²-weighted PNT sub-sum:
    S₃(N) = Σ_{k=1}^N μ(k)·log²(k)/k

  Same structure as S₂ but with log²(k)/k differences.
  Uses: |Δ(log²(k)/k)| ≤ (log²(k) + 2·log(k) + 2)/k²

  STATUS: 1 sorry remaining (same pattern as S₂).
-/

import Cathedral.AbelTail.AbelInterior
import Cathedral.AbelTail.MertensBridge
import Cathedral.AbelTail.DiscreteProductRule
import Cathedral.AbelTail.LogTailBound
import Cathedral.MellinBridge.AbelSummation
import Cathedral.Assembly.AbelEngine

noncomputable section
open Real Finset BigOperators

-- ════════════════════════════════════════════════
-- §1. DEFINITION
-- ════════════════════════════════════════════════

/-- S₃(M) = Σ_{k=1}^M μ(k)·log²(k)/k (matching FinalDragon.lean). -/
def S₃_at (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) *
    (Real.log (k : ℝ)) ^ 2 / (k : ℝ)

-- ════════════════════════════════════════════════
-- §2. S₃ DECAY
-- ════════════════════════════════════════════════

/-- **S₃ decay via limit + Abel.**
    |S₃(N) - L₃| ≤ C₃·N^{-1/4}·log²(N) for all N ≥ 2.
    Identical structure to s2_decay with log² weights. -/
theorem s3_decay
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (L₃ : ℝ) -- The limit (-2γ); generalized to avoid import
    (hPNT₃ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
      Filter.atTop (nhds L₃)) :
    ∃ C₃ : ℝ, C₃ > 0 ∧ ∀ N : ℕ, 2 ≤ N →
      |S₃_at N - L₃| ≤
        C₃ * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := by
  -- Same pattern as s2_decay with log² weights.
  -- Uses DPR for log²(k)/k.
  sorry

end
