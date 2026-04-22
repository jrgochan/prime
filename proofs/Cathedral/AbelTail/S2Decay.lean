/-
  Cathedral/AbelTail/S2Decay.lean

  ## S₂ Decay: |S₂(N) + 1| ≤ C₂·N^{-1/4}·log(N)

  Bounds the log-weighted PNT sub-sum:
    S₂(N) = Σ_{k=1}^N μ(k)·log(k)/k

  Architecture (from Scratch/AbelTailProof.lean §§7-9):
  1. finite_abel_s2_simple: Abel on [N+1,M] with log(k) ≤ log(M) factoring
  2. s2_decay: Triangle + PNT₂ + per-N choice of M

  Key insight: The S₂ Abel interior bound has log(M) factor (unlike S₁).
  We handle this by choosing M = max(N+1, M₀) per N, so log(M) is controlled.
  The constant C₂ absorbs log(M₀) via the PNT₂ extraction.

  STATUS: 2 sorry (Abel interior + decay wiring — mechanizable from Scratch).
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
-- §2. SIMPLIFIED FINITE ABEL BOUND (M-dependent)
-- ════════════════════════════════════════════════

/-- **Abel bound for S₂ on [N+1, M] with log(M) factored out.**

    Uses log(k) ≤ log(M) for k ∈ [N+1, M] to convert:
      |Δ(log(k)/k)| ≤ (log(k)+1)/k²  [from s2_discrete_diff_bound]
                     ≤ (log(M)+1)/k²   [monotonicity of log]

    Then the interior sum becomes (log(M)+1)·Σ C_m·(k^{3/4}+N^{3/4})/k²,
    which has the SAME structure as S₁ (with an extra log(M)+1 factor).
    From S₁'s proof: Σ terms ≤ 5·N^{-1/4}.

    Total: |S₂(M)-S₂(N)| ≤ C_m·(log(M)+1)·(boundary + 5·N^{-1/4})

    This is M-DEPENDENT (via log(M)) but works when M is chosen per N. -/
theorem finite_abel_s2_simple
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (N M : ℕ) (hN : 2 ≤ N) (hM : N + 1 ≤ M) :
    |S₂_at M - S₂_at N| ≤
      C_m * (Real.log (M : ℝ) + 1) *
        ((M : ℝ) ^ (-(1:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4) / (M : ℝ) +
         5 * (N : ℝ) ^ (-(1:ℝ)/4)) := by
  -- Same structure as finite_abel_s1_diff (proved in S1Decay.lean)
  -- but with f(k) = log(k)/k and δ(k) = (log(M)+1)/(k(k+1))
  -- The (log(M)+1) factor multiplies the S₁-type bound uniformly.
  sorry

-- ════════════════════════════════════════════════
-- §3. S₂ DECAY
-- ════════════════════════════════════════════════

/-- **S₂ decay via limit + Abel.**
    |S₂(N)+1| ≤ C₂·N^{-1/4}·log(N) for all N ≥ 2.

    For each N ≥ 2:
    1. From PNT₂ (S₂ → -1), choose M₀ with |S₂(M)+1| < ε for M ≥ M₀
       where ε = N^{-1/4}·log(N)
    2. Set M = max(N+1, M₀)
    3. Triangle: |S₂(N)+1| ≤ |S₂(M)+1| + |S₂(M)-S₂(N)|
    4. |S₂(M)+1| ≤ N^{-1/4}·log(N) by PNT₂
    5. |S₂(M)-S₂(N)| ≤ C_m·(log(M)+1)·(M^{-1/4}+N^{3/4}/M+5N^{-1/4})
       Since M ≥ N+1: M^{-1/4} ≤ N^{-1/4}, N^{3/4}/M ≤ N^{-1/4}
       ≤ C_m·7·(log(M)+1)·N^{-1/4}
       Since M = max(N+1, M₀): log(M)+1 ≤ log(N+M₀+1)+1
       For the per-N bound: this is finite, and dominates log(N).
    6. Total ≤ (1 + 7·C_m·(log(M)+1)/log(N))·N^{-1/4}·log(N)
       The ratio (log(M)+1)/log(N) is bounded for M = max(N+1, M₀).
       C₂ = 1 + 35·C_m covers all N ≥ 2. -/
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
  -- Same architecture as s1_decay (proved) + Scratch/AbelTailProof.lean §9.
  -- The sorry depends on finite_abel_s2_simple (sorry above).
  sorry

end
