/-
  Cathedral/AbelTail/S2Decay.lean

  ## S₂ Decay: |S₂(N) + 1| ≤ C·N^{-1/4}·log(N)

  Bounds the log-weighted PNT sub-sum:
    S₂(N) = Σ_{k=1}^N μ(k)·log(k)/k

  Same structure as S₁ but with log(k)/k differences,
  handled by the Discrete Product Rule (DiscreteProductRule.lean).

  KEY ISSUE: The interior Abel sum contains log(M) factors that
  must be controlled. We choose M = max(N², M₀) so
  log(M) ≤ 2·log(N), making the bound N-uniform.

  STATUS: 2 sorry remaining (finite tail bound + wiring).
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
-- §2. FINITE ABEL BOUND (M-DEPENDENT)
-- ════════════════════════════════════════════════

/-- Abel bound for S₂ using log(k) ≤ log(M) factoring.
    The interior bound contains log(M), handled by the caller. -/
theorem finite_abel_s2_simple
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (N M : ℕ) (hN : 2 ≤ N) (hM : N + 1 ≤ M) :
    |S₂_at M - S₂_at N| ≤
    C_m * ((M : ℝ) ^ (-(1:ℝ)/4) * Real.log (M : ℝ) +
            (N : ℝ) ^ ((3:ℝ)/4) * Real.log (M : ℝ) / (M : ℝ)) +
    C_m * 10 * Real.log (M : ℝ) * (N : ℝ) ^ (-(1:ℝ)/4) := by
  -- Interior uses: for k ∈ [N, M]:
  --   |Δ(log(k)/k)| ≤ (log(k)+1)/k² ≤ (log(M)+1)/k²  [since log increasing]
  --   ≤ 2·log(M)/k²  [for M ≥ 3, log(M) ≥ 1]
  -- Then Σ |A(k)|·|Δf₂(k)| ≤ Σ C_m·(k^{3/4}+N^{3/4})·2·log(M)/k²
  --   = 2·C_m·log(M)·[Σ k^{-5/4} + N^{3/4}·Σ 1/k²]
  --   ≤ 2·C_m·log(M)·[4·N^{-1/4} + N^{3/4}·1/N]
  --   = 2·C_m·log(M)·5·N^{-1/4}
  --   = 10·C_m·log(M)·N^{-1/4}
  sorry

-- ════════════════════════════════════════════════
-- §3. S₂ DECAY VIA LIMIT + CONTROLLED M
-- ════════════════════════════════════════════════

/-- **S₂ decay via limit argument with controlled M selection.**
    |S₂(N)+1| ≤ C₂·N^{-1/4}·log(N) for all N ≥ 2.

    KEY: Choose M = max(N², M₀(ε)) so:
    - |S₂(M)+1| < ε = N^{-1/4}·log(N)  [from PNT₂]
    - log(M) ≤ 2·log(N)  [since M ≤ N² + M₀, and for large N]
    - Interior ≤ 20·C_m·log(N)·N^{-1/4}  [from controlled log(M)]
    - Boundary → 0 as M → ∞ for fixed N -/
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
  -- Uses finite_abel_s2_simple with M = max(N², M₀)
  -- so that log(M) ≤ 2·log(N) + C, making the bound uniform.
  sorry

end
