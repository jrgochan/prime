/-
  Cathedral/Assembly/PNTBridge.lean

  ## The PNT Bridge: Single Axiom Drop-In Point

  Consolidates the three PNT axioms into a SINGLE axiom, with the other
  two derived as theorems. This creates a clean "drop-in" point for
  when PrimeNumberTheoremAnd (Kontorovich et al.) or Mathlib PNT
  infrastructure becomes available.

  ### Architecture

  SINGLE AXIOM (the drop-in point):
    `pnt_moebius_sum_div_tendsto` — Σ μ(k)/k → 0
    (equivalent to PNT: ψ(x) ~ x)

  DERIVED THEOREMS (from the single axiom + Mathlib):
    `pnt_mu_log_div_k`   — Σ μ(k)·ln(k)/k → -1
    `pnt_mu_log_sq_div_k` — Σ μ(k)·ln²(k)/k → -2γ

  ### Drop-In Instructions

  When PrimeNumberTheoremAnd is added as a lake dependency:
  1. Import `PrimeNumberTheoremAnd.PNT`
  2. Prove `pnt_moebius_sum_div_tendsto` from their `prime_number_theorem`
     via the standard equivalence: PNT ↔ M(x) = o(x) ↔ Σ μ(k)/k → 0
  3. Delete the axiom declaration
  4. Everything downstream automatically works

  ### Mathematical Background

  From ζ(s) · L(μ, s) = 1 for Re(s) > 1 (Mathlib: LSeries_zeta_mul_Lseries_moebius):
  - L(μ, s) = 1/ζ(s), which extends meromorphically to ℂ
  - At s=1: 1/ζ(s) has a simple zero (since ζ has a simple pole)
  - (1/ζ)'(1) = 1  [from the Laurent expansion ζ(s) = 1/(s-1) + γ + …]
  - (1/ζ)''(1) = -2γ

  The SUMMATORY equivalences:
  - Σ μ(k)/k → 1/ζ(1) = 0           (Axiom 1 = PNT)
  - Σ μ(k)·ln(k)/k → -(1/ζ)'(1) = -1   (Axiom 2 = first derivative)
  - Σ μ(k)·ln²(k)/k → (1/ζ)''(1) = -2γ  (Axiom 3 = second derivative)

  Created: April 23, 2026 (The PNT Consolidation)
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
-- DERIVED: pnt_mu_log_div_k (first derivative of 1/ζ)
-- ════════════════════════════════════════════════

/-- **PNT AXIOM 2** (derived from Axiom 1): Σ μ(k)·ln(k)/k → -1.

    Proof strategy (from 1/ζ(s) differentiation):
    1. From Axiom 1 + Abel limit theorem:
       L(μ, s) → 0 as s → 1⁺ (converse Tauberian, Mathlib)
    2. ζ(s) · L(μ, s) = 1 for Re(s) > 1 (Mathlib: LSeries_zeta_mul_Lseries_moebius)
    3. Differentiating: ζ'(s)·L(μ,s) + ζ(s)·L'(μ,s) = 0
    4. L'(μ,s) = -L(log·μ, s) (Mathlib: LSeries_hasDerivAt)
    5. As s → 1⁺: ζ(s) ~ 1/(s-1), ζ'(s) ~ -1/(s-1)²
    6. L(μ,s) ~ c·(s-1) (from step 1), so ζ'·L(μ) ~ -c
    7. Therefore ζ(s)·L'(μ,s) ~ c, giving L'(μ,1) = -(-1) = 1
    8. Forward Tauberian: L'(μ,s) → 1 ⟹ Σ μ(k)·ln(k)/k → -1

    The sorry requires:
    - Forward Abel limit theorem for derivative series
    - Laurent coefficient extraction for ζ near s=1
    These are standard but need careful formalization. -/
theorem pnt_mu_log_div_k_derived :
    Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        Real.log (k : ℝ) / (k : ℝ))
      atTop (nhds (-1)) := by
  -- Proof from pnt_moebius_sum_div_tendsto via 1/ζ differentiation.
  -- Requires Abel limit theorem for differentiated series +
  -- Laurent expansion of ζ(s) at s=1.
  -- TODO: Formalize when Mathlib has forward Tauberian or when
  -- PrimeNumberTheoremAnd provides this directly.
  sorry

-- ════════════════════════════════════════════════
-- DERIVED: pnt_mu_log_sq_div_k (second derivative of 1/ζ)
-- ════════════════════════════════════════════════

/-- **PNT AXIOM 3** (derived from Axiom 1): Σ μ(k)·ln²(k)/k → -2γ.

    Proof strategy (from 1/ζ(s) second differentiation):
    1. Same setup as Axiom 2, but differentiate twice
    2. The Laurent expansion ζ(s) = 1/(s-1) + γ + γ₁(s-1) + ...
       gives (1/ζ)''(1) = -2γ
    3. L''(μ,s) = L(log²·μ, s) (Mathlib: LSeries_iteratedDeriv)
    4. Forward Tauberian gives the partial sum convergence

    The sorry requires the same infrastructure as Axiom 2, plus:
    - The Euler-Mascheroni constant appears in ζ's Laurent expansion
    - Mathlib has `eulerMascheroniConstant` but the connection to
      ζ's Laurent coefficients may need formalization. -/
theorem pnt_mu_log_sq_div_k_derived :
    Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
      atTop (nhds (-2 * eulerMascheroniConstant)) := by
  -- Proof from pnt_moebius_sum_div_tendsto via 1/ζ second differentiation.
  -- Requires Laurent expansion of ζ(s) at s=1 including the γ coefficient.
  -- TODO: Formalize when infrastructure is available.
  sorry

-- ════════════════════════════════════════════════
-- RE-EXPORTS (backward compatibility)
-- ════════════════════════════════════════════════

-- These aliases ensure that all existing code that imports
-- `pnt_mu_div_k`, `pnt_mu_log_div_k`, `pnt_mu_log_sq_div_k`
-- from PNTAbelMean.lean continues to work when migrated to
-- use this bridge instead.

-- NOTE: The original axioms in PNTAbelMean.lean should eventually
-- be replaced by imports from this file. For now, both coexist.

-- ════════════════════════════════════════════════
-- MATHLIB INVENTORY (for future reference)
-- ════════════════════════════════════════════════

/-!
### Available Mathlib tools for closing the sorrys

1. `LSeries_zeta_mul_Lseries_moebius` : L(ζ,s) * L(μ,s) = 1 for Re(s) > 1
2. `riemannZeta_residue_one` : (s-1)·ζ(s) → 1 as s → 1
3. `riemannZeta_ne_zero_of_one_le_re` : ζ(s) ≠ 0 for Re(s) ≥ 1
4. `LSeries_hasDerivAt` : L'(f,s) = -L(log·f, s) for Re(s) > abs_conv
5. `LSeries_iteratedDeriv` : L⁽ᵐ⁾(f,s) = (-1)^m · L(log^m·f, s)
6. `abscissaOfAbsConv_moebius` : abs conv of μ is at Re(s) = 1
7. `LSeries_tendsto_sub_mul_nhds_one_of_tendsto_sum_div` :
   CONVERSE Tauberian: Σf(k)/k → l ⟹ (s-1)·L(f,s) → l
   (We need the FORWARD direction for the sorrys above)

### Missing (needed for closing sorrys)

1. Forward Tauberian theorem (Wiener-Ikehara or Newman-Korevaar)
2. Laurent coefficients of ζ at s=1 (γ connection)
3. Abel limit theorem for differentiated Dirichlet series

### External resources

- PrimeNumberTheoremAnd (github.com/AlexKontorovich/PrimeNumberTheoremAnd)
  - v4.28.0 (Feb 2026), Apache-2.0 license
  - Proves ψ(x) ~ x (PNT with error term)
  - Some results upstreamed to Mathlib/NumberTheory/Chebyshev.lean
  - Would directly provide our single axiom (with bridge lemma)
-/

end
