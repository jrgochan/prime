/-
  Cathedral/AbelTail/S2Decay.lean

  ## S₂ Decay: |S₂(N) + 1| ≤ C₂·N^{-1/4}·log(N)

  Bounds the log-weighted PNT sub-sum:
    S₂(N) = Σ_{k=1}^N μ(k)·log(k)/k

  Same architecture as S₁ (finite Abel + PNT triangle).
  The log weight introduces log(M) factors, controlled by M choice.

  STATUS: 2 sorry (finite Abel bound + decay wiring).
-/

import Cathedral.AbelTail.S1Decay
import Cathedral.AbelTail.DiscreteProductRule

noncomputable section
open Real Finset BigOperators

-- ════════════════════════════════════════════════
-- §1. DEFINITION
-- ════════════════════════════════════════════════

/-- S₂(M) = Σ_{k=1}^M μ(k)·log(k)/k (matching FinalDragon.lean). -/
def S₂_at (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) *
    Real.log (k : ℝ) / (k : ℝ)

-- ════════════════════════════════════════════════
-- §2. FINITE ABEL BOUND ON S₂ DIFFERENCE
-- ════════════════════════════════════════════════

/-- **TODO**: Abel bound for S₂ on [N+1, M].
    Same as finite_abel_s1_diff but with weight f(k) = log(k)/k.
    The differences |Δ(log(k)/k)| introduce a log(M) factor. -/
theorem finite_abel_s2_diff
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (N M : ℕ) (hN : 2 ≤ N) (hM : N + 1 ≤ M) :
    |S₂_at M - S₂_at N| ≤
      C_m * Real.log ((M : ℝ) + 1) *
        ((M : ℝ) ^ (-(1:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4) / (M : ℝ) +
         5 * (N : ℝ) ^ (-(1:ℝ)/4)) := by
  sorry

-- ════════════════════════════════════════════════
-- §3. S₂ DECAY VIA LIMIT + CONTROLLED M
-- ════════════════════════════════════════════════

/-- **TODO**: |S₂(N)+1| ≤ C₂·N^{-1/4}·log(N) for all N ≥ 2.
    Same architecture as s1_decay. -/
theorem s2_decay
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (hPNT₂ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        Real.log (k : ℝ) / (k : ℝ))
      Filter.atTop (nhds (-1))) :
    ∃ C₂ : ℝ, C₂ > 0 ∧ ∀ N : ℕ, 2 ≤ N →
      |S₂_at N - (-1)| ≤ C₂ * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := by
  sorry

end
