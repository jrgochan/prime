/-
  Cathedral/PNT/Bridge.lean

  ## The PNT Bridge: From PrimeNumberTheoremAnd to Cathedral

  Bridges the PrimeNumberTheoremAnd (Kontorovich et al.) library's
  `mu_pnt_alt` theorem into the Cathedral's PNT axiom infrastructure.

  ### Status (April 25, 2026)

  THEOREM (proved from PrimeNumberTheoremAnd.mu_pnt_alt):
    `pnt_moebius_sum_div_tendsto` — Σ μ(k)/k → 0  ✅ ZERO SORRY

  KNOWN SORRYS (2):
    `pnt_mu_log_div_k_derived`   — Σ μ(k)·ln(k)/k → -1    (sorry)
    `pnt_mu_log_sq_div_k_derived` — Σ μ(k)·ln²(k)/k → -2γ  (sorry)

  ### Blocking Analysis

  These 2 sorrys do NOT block the MainChain (MainChain.lean):n
    - MainChain.lean builds with ZERO sorrys
    - The log-weighted sums flow through PNTAbelMean → MillenniumWall → FinalDragon
      which is an ALTERNATIVE chain, not the primary MainChain path
    - The OneCrown/DirectL2Crown path uses PNT axioms from PNT/AbelMean.lean
      (not PNTBridge), so PNTBridge sorrys are completely isolated

  ### Why the 2 sorrys cannot be closed now

  Both require a **forward Tauberian theorem**: if L(f,s) → ℓ as s → 1⁺,
  then Σ f(k)/k → ℓ. Mathlib 4.28 has only the CONVERSE direction
  (`LSeries_tendsto_sub_mul_nhds_one_of_tendsto_sum_div`).
  PNTAnd's Wiener-Ikehara implementation has its own 2 sorrys.
  Elementary approaches fail because the log-weight introduces
  O(x·log x) error terms that cannot be controlled by M(x) = o(x).

  These will resolve automatically when Mathlib gains:
    - A forward Abel/Tauberian theorem for Dirichlet series, OR
    - PNTAnd closes its Wiener-Ikehara sorrys

  ### Mathematical Background

  From ζ(s) · L(μ, s) = 1 for Re(s) > 1:
  - L(μ, s) = 1/ζ(s)
  - Σ μ(k)/k → 1/ζ(1) = 0           (PROVED via mu_pnt_alt)
  - Σ μ(k)·ln(k)/k → -(1/ζ)'(1) = -1   (sorry — needs forward Tauberian)
  - Σ μ(k)·ln²(k)/k → (1/ζ)''(1) = -2γ  (sorry — needs forward Tauberian)
-/

import Cathedral.Defs
import Mathlib.NumberTheory.ArithmeticFunction.Moebius
import Mathlib.NumberTheory.LSeries.Dirichlet
import Mathlib.NumberTheory.LSeries.Deriv
import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.Harmonic.EulerMascheroni
import Mathlib.NumberTheory.LSeries.SumCoeff
import PrimeNumberTheoremAnd.Consequences

noncomputable section
open Real Finset Filter ArithmeticFunction ArithmeticFunction.Moebius

-- ════════════════════════════════════════════════
-- THE PNT (now a THEOREM via PrimeNumberTheoremAnd)
-- ════════════════════════════════════════════════

/-- **THE PRIME NUMBER THEOREM** (summatory Möbius form).

    The partial sums of μ(k)/k converge to 0:
      Σ_{k=1}^{N} μ(k)/k → 0 as N → ∞

    This is equivalent to the Prime Number Theorem:
      ψ(x) ~ x, or equivalently π(x) ~ x/ln(x)

    **PROVED** from `PrimeNumberTheoremAnd.mu_pnt_alt`:
      `(fun x : ℝ ↦ Σ n ∈ range ⌊x⌋₊, (μ n : ℝ) / n) =o[atTop] (fun _ ↦ 1)`

    The bridge:
    1. `mu_pnt_alt` gives o(1) over real-indexed partial sums (range ⌊x⌋₊)
    2. o(1) implies Tendsto ... 0 (by isLittleO_one_iff)
    3. Compose with (· : ℕ → ℝ) to get discrete version (range N)
    4. Convert range N → Icc 1 N (μ(0) = 0, so the n=0 term vanishes)

    Reference: Kontorovich et al., PrimeNumberTheoremAnd (2024-2026). -/
theorem pnt_moebius_sum_div_tendsto :
    Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(μ k) : ℝ) / (k : ℝ))
      atTop (nhds 0) := by
  -- mu_pnt_alt gives o(1) for the ℝ-indexed version over range ⌊x⌋₊
  have h_o1 := mu_pnt_alt
  rw [Asymptotics.isLittleO_one_iff] at h_o1
  -- Compose with ℕ → ℝ to get discrete version
  have h_range : Tendsto (fun N : ℕ =>
      ∑ n ∈ Finset.range N, (↑(μ n) : ℝ) / (n : ℝ))
      atTop (nhds 0) := by
    have := h_o1.comp tendsto_natCast_atTop_atTop
    simp only [Function.comp_def, Nat.floor_natCast] at this
    exact this
  -- The Icc 1 N sum equals the range (N+1) sum minus the n=0 term (which is 0)
  -- Equivalently: Σ_{Icc 1 N} = Σ_{range N} + μ(N)/N - μ(0)/0
  -- Since μ(0) = 0: Σ_{Icc 1 N} = Σ_{range N} + μ(N)/N
  have h_eq : ∀ N : ℕ,
      ∑ k ∈ Finset.Icc 1 N, (↑(μ k) : ℝ) / (k : ℝ) =
      ∑ n ∈ Finset.range N, (↑(μ n) : ℝ) / (n : ℝ) + (↑(μ N) : ℝ) / (N : ℝ) := by
    intro N
    -- Icc 1 N ∪ {0} = range (N+1), and μ(0)/0 = 0
    have h_union : Finset.Icc 1 N = (Finset.range (N + 1)).erase 0 := by
      ext n; simp [Finset.mem_Icc, Finset.mem_range]; omega
    rw [h_union]
    rw [Finset.sum_erase_eq_sub (Finset.mem_range.mpr (Nat.zero_lt_succ N))]
    simp only [ArithmeticFunction.map_zero, Int.cast_zero, zero_div, sub_zero]
    rw [Finset.sum_range_succ]
  -- The N-th term μ(N)/N → 0
  have h_Nth : Tendsto (fun N : ℕ => (↑(μ N) : ℝ) / (N : ℝ)) atTop (nhds 0) := by
    rw [Metric.tendsto_atTop]
    intro ε hε
    refine ⟨⌈1/ε⌉₊ + 1, fun N hN => ?_⟩
    simp only [dist_zero_right]
    have hN_pos : (0 : ℝ) < N := Nat.cast_pos.mpr (by omega)
    calc ‖(↑(μ N) : ℝ) / (N : ℝ)‖
        = |(↑(μ N) : ℝ)| / N := by
          rw [norm_div, Real.norm_eq_abs, Real.norm_natCast]
      _ ≤ 1 / N := by
          apply div_le_div_of_nonneg_right _ hN_pos.le
          exact_mod_cast abs_moebius_le_one
      _ < ε := by
          have h1ε : 1 / ε < N := calc
            1 / ε ≤ ⌈1/ε⌉₊ := Nat.le_ceil (1/ε)
            _ < ⌈1/ε⌉₊ + 1 := by linarith
            _ ≤ N := by exact_mod_cast hN
          exact (div_lt_iff₀ hN_pos).mpr (mul_comm ε ↑N ▸ (div_lt_iff₀ hε).mp h1ε)
  -- Combine: Σ_{Icc 1 N} = Σ_{range N} + μ(N)/N → 0 + 0 = 0
  have h_sum : Tendsto
      ((fun N => ∑ n ∈ Finset.range N, (↑(μ n) : ℝ) / (n : ℝ)) +
       (fun N => (↑(μ N) : ℝ) / (N : ℝ))) atTop (nhds 0) := by
    rw [show (0:ℝ) = 0 + 0 from (add_zero 0).symm]
    exact h_range.add h_Nth
  exact h_sum.congr (fun N => (h_eq N).symm)

-- ════════════════════════════════════════════════
-- DERIVED: pnt_mu_div_k (identical to the theorem)
-- ════════════════════════════════════════════════

/-- **PNT AXIOM 1** (now a theorem): Σ μ(k)/k → 0.
    Trivially equal to `pnt_moebius_sum_div_tendsto`. -/
theorem pnt_mu_div_k_derived :
  Tendsto (fun N =>
    ∑ k ∈ Finset.Icc 1 N, (↑(μ k) : ℝ) / (k : ℝ))
    atTop (nhds 0) :=
  pnt_moebius_sum_div_tendsto

-- ════════════════════════════════════════════════
-- SORRY 1/2: pnt_mu_log_div_k (first derivative of 1/ζ)
-- ════════════════════════════════════════════════

/-- **SORRY** (blocked by upstream): Σ μ(k)·ln(k)/k → -1.

    This is a standard PNT consequence, equivalent to -(1/ζ)'(1) = -1.

    BLOCKING: Requires a forward Tauberian theorem not in Mathlib 4.28.
    ISOLATION: Does NOT block MainChain.lean (which has zero sorrys).
    RESOLUTION: Will close when Mathlib gains forward Abel/Tauberian. -/
theorem pnt_mu_log_div_k_derived :
    Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        Real.log (k : ℝ) / (k : ℝ))
      atTop (nhds (-1)) := by
  -- WIP: Incomplete alternative spatial route. This path is superseded by
  -- the Mellin Crown architecture (v11+). Requires forward Tauberian theorem
  -- not available in Mathlib 4.28. Left for future exploration.
  sorry

-- ════════════════════════════════════════════════
-- SORRY 2/2: pnt_mu_log_sq_div_k (second derivative of 1/ζ)
-- NOTE: This axiom was ELIMINATED from the crown path in v9 (Abel Bypass).
-- The S₃ uniform bound suffices for L² decay. This sorry is OFF-PATH.
-- ════════════════════════════════════════════════

/-- **SORRY** (blocked by upstream, OFF CROWN PATH): Σ μ(k)·ln²(k)/k → -2γ.

    This is a standard PNT consequence, equivalent to (1/ζ)''(1) = -2γ.

    NOTE: ELIMINATED from the crown path in v9 via the Abel Bypass.
    The S₃ uniform bound (S3UniformBound.lean) suffices for the L² decay
    without needing this exact limit.

    BLOCKING: Same as sorry 1/2 — needs forward Tauberian + γ from
              ζ's Laurent expansion at s=1.
    ISOLATION: Does NOT block MainChain.lean (which has zero sorrys).
    RESOLUTION: Will close when Mathlib gains forward Abel/Tauberian. -/
theorem pnt_mu_log_sq_div_k_derived :
    Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
      atTop (nhds (-2 * eulerMascheroniConstant)) := by
  -- WIP: Incomplete alternative spatial route, OFF CROWN PATH since v9.
  -- Superseded by Abel Bypass + S₃ uniform bound. Requires forward Tauberian
  -- theorem + Euler-Mascheroni from ζ Laurent expansion. Left for future.
  sorry

-- ════════════════════════════════════════════════
-- SORRY SUMMARY
-- ════════════════════════════════════════════════

/-!
### Sorry Status (2 sorrys, both isolated)

| # | Theorem | Limit | Blocker |
|---|---------|-------|-------|
| 1 | `pnt_mu_log_div_k_derived` | -1 | Forward Tauberian |
| 2 | `pnt_mu_log_sq_div_k_derived` | -2γ | Forward Tauberian + γ |

**Isolation**: Neither sorry propagates to MainChain.lean.
MainChain.lean builds with ZERO sorrys, ZERO sorry warnings.

**Upstream requirement**: Mathlib `LSeries_tendsto_sub_mul_nhds_one_of_tendsto_sum_div`
provides the CONVERSE Tauberian (Σ → L-series). The FORWARD direction
(L-series → Σ) is needed but missing from Mathlib 4.28.

**PNTAnd**: Wiener.lean has 2 sorrys on Fourier BV bounds.
When those close, forward Tauberian becomes available.
-/

end
