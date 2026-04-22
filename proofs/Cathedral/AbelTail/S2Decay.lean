/-
  Cathedral/AbelTail/S2Decay.lean

  ## S₂ Decay: |S₂(N) + 1| ≤ C₂·N^{-1/4}·log(N)

  Bounds the log-weighted PNT sub-sum:
    S₂(N) = Σ_{k=1}^N μ(k)·log(k)/k

  Same architecture as S₁ (finite Abel + PNT triangle).
  Uses s2_discrete_diff_bound from DiscreteProductRule.lean
  for |Δ(log(k)/k)| ≤ (log(k)+1)/k².

  STATUS: 2 sorry (Abel bound calculus + decay assembly).
  Ready for mechanization — same structure as the proved S₁.
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

/-- **Abel bound for S₂ on [N+1, M].**
    Uses abel_summation_abs_bound with:
    - a(k) = μ(k), partial sums bounded by Mertens
    - f(k) = log(k)/k, differences bounded by s2_discrete_diff_bound
    - δ(k) = (log(k)+1)/k² ≤ (log(M)+1)/k²

    Structure matches finite_abel_s1_diff exactly. -/
theorem finite_abel_s2_diff
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (N M : ℕ) (hN : 2 ≤ N) (hM : N + 1 ≤ M) :
    |S₂_at M - S₂_at N| ≤
      C_m * (Real.log (M : ℝ) + 1) *
        ((M : ℝ) ^ (-(1:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4) / (M : ℝ) +
         5 * (N : ℝ) ^ (-(1:ℝ)/4)) := by
  -- Same structure as finite_abel_s1_diff but with:
  --   f(k) = log(k)/k
  --   δ(k) = (log(M)+1) / (k * (k+1))   [from s2_discrete_diff_bound + log monotonicity]
  -- Then the interior sum uses the same telescoping as S₁.
  sorry

-- ════════════════════════════════════════════════
-- §3. S₂ DECAY VIA LIMIT + CONTROLLED M
-- ════════════════════════════════════════════════

/-- **S₂ decay via the same limit+Abel architecture as s1_decay.**

    For each N ≥ 2:
    1. From PNT₂ (S₂ → -1), choose M ≥ N+1 with |S₂(M)+1| < N^{-1/4}·log(N)
    2. Triangle: |S₂(N)+1| ≤ |S₂(M)+1| + |S₂(M) - S₂(N)|
    3. Abel bound (finite_abel_s2_diff): picks up log(M) factor
    4. Since M = max(N+1, M₀): M^{-1/4} ≤ N^{-1/4}, N^{3/4}/M ≤ N^{-1/4}
    5. Total: |S₂(N)+1| ≤ (1+7C_m·(log(M)+1))·N^{-1/4}·log(N) -/
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
  -- Same architecture as s1_decay.
  -- The extra log(M) factor from finite_abel_s2_diff is absorbed:
  --   log(M) ≤ log(max(N+1, M₀)) ≈ log(N) + log(M₀)
  -- So the bound becomes C₂·N^{-1/4}·log(N) with C₂ depending on M₀ and C_m.
  sorry

end
