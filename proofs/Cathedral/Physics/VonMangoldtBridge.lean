/-
  Cathedral/Physics/VonMangoldtBridge.lean

  ## The von Mangoldt Bridge: c_d = Λ(d)

  ════════════════════════════════════════════════════════════════

  The Vasyunin mean vector b(k) = (ln(k) + 1 - γ)/k, when rotated
  into the Smith basis via Φ⁻¹·D, becomes:

    c_d = Σ_{k|d} μ(d/k) · (ln(k) + 1 - γ) = Λ(d) + (1 - γ)·[d = 1]

  where Λ(d) is the von Mangoldt function.

  This is proved using Mathlib's `vonMangoldt_sum`:
    Σ_{k|d} Λ(k) = ln(d)

  inverted via Möbius: μ * log = Λ.

  ════════════════════════════════════════════════════════════════

  Significance: The von Mangoldt function is the Dirichlet series
  coefficient of -ζ'/ζ(s). Its appearance in the Smith basis rotation
  of the NB mean vector connects the Ramanujan arithmetic (gcd², J₂)
  to the continuous L²(0,1) geometry (Vasyunin Gram matrix).

  The Mellin lift — bridging σ → ∞ to d² → 0 — passes through Λ(d).

  Created: May 16, 2026 (Spectral Archaeology, Exploration 38)
-/

import Mathlib.NumberTheory.ArithmeticFunction.Moebius
import Mathlib.NumberTheory.ArithmeticFunction.VonMangoldt
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.NumberTheory.Harmonic.EulerMascheroni

noncomputable section
open Real Finset
open scoped ArithmeticFunction

namespace Cathedral.Physics.VonMangoldtBridge

-- ════════════════════════════════════════════════════════════════
-- PART I: The key Dirichlet convolution identity
-- ════════════════════════════════════════════════════════════════

-- The Möbius inversion of log gives von Mangoldt:
-- Σ_{d|n} μ(n/d) · ln(d) = Λ(n)
-- From vonMangoldt_sum: Σ_{d|n} Λ(d) = ln(n) and μ * ζ = ε.
-- Stated pointwise as vonMangoldt_eq_moebius_log_sum below.

-- ════════════════════════════════════════════════════════════════
-- PART II: The divisor sum form
-- ════════════════════════════════════════════════════════════════

/-- **Von Mangoldt as a Möbius sum over divisors.**

    Σ_{k|d} μ(d/k) · ln(k) = Λ(d)

    This is the pointwise form of moebius_conv_log_eq_vonMangoldt. -/
theorem vonMangoldt_eq_moebius_log_sum (d : ℕ) (hd : d ≠ 0) :
    (∑ k ∈ d.divisors,
      (ArithmeticFunction.moebius (d / k) : ℝ) * Real.log (k : ℝ)) =
    ArithmeticFunction.vonMangoldt d := by
  -- μ * log = Λ, proven via:
  --   calc μ * log = μ * (Λ * ζ) = Λ * (μ * ζ) = Λ * 1 = Λ
  -- Evaluating (μ * log)(d) gives a sum over divisorsAntidiagonal.
  -- Our sum is over divisors with μ(d/k)·log(k), which is the same
  -- sum reindexed. Need Nat.sum_divisorsAntidiagonal' to convert.
  sorry

-- ════════════════════════════════════════════════════════════════
-- PART III: The full Smith basis rotation identity
-- ════════════════════════════════════════════════════════════════

/-- **Möbius cancellation**: Σ_{k|d} μ(d/k) = [d = 1].

    When d ≥ 2, the sum vanishes.
    When d = 1, the sum is μ(1) = 1.

    This follows from μ * ζ = ε evaluated at d. -/
theorem moebius_sum_indicator (d : ℕ) (hd : d ≠ 0) :
    (∑ k ∈ d.divisors, (ArithmeticFunction.moebius (d / k) : ℝ)) =
    if d = 1 then 1 else 0 := by
  -- From coe_moebius_mul_coe_zeta: (μ * ζ)(d) = [d=1].
  -- (μ * ζ)(d) = Σ_{(a,b) ∈ antidiag(d)} μ(a)·ζ(b)
  --            = Σ_{k|d} μ(d/k)·ζ(k)
  --            = Σ_{k|d} μ(d/k)·1
  -- Need: antidiagonal ↔ divisors conversion for this Mathlib version.
  sorry

/-- **The Full Bridge Identity: c_d = Λ(d) + (1-γ)·[d=1]**

    For the Vasyunin mean vector b(k) = (ln(k) + 1 - γ)/k,
    the Smith basis rotation gives:

      c_d := Σ_{k|d} μ(d/k) · (ln(k) + 1 - γ)
           = [Σ_{k|d} μ(d/k) · ln(k)] + (1-γ) · [Σ_{k|d} μ(d/k)]
           = Λ(d) + (1 - γ) · [d = 1]

    The splitting uses linearity of the divisor sum and the
    identities from Parts I-II. -/
theorem smith_basis_rotation (d : ℕ) (hd : d ≠ 0) :
    (∑ k ∈ d.divisors,
      (ArithmeticFunction.moebius (d / k) : ℝ) *
      (Real.log (k : ℝ) + 1 - eulerMascheroniConstant)) =
    ArithmeticFunction.vonMangoldt d +
    if d = 1 then (1 - eulerMascheroniConstant) else 0 := by
  -- Step 1: Split the sum by linearity
  have hsplit : ∀ k ∈ d.divisors,
      (ArithmeticFunction.moebius (d / k) : ℝ) *
      (Real.log (k : ℝ) + 1 - eulerMascheroniConstant) =
      (ArithmeticFunction.moebius (d / k) : ℝ) * Real.log (k : ℝ) +
      (ArithmeticFunction.moebius (d / k) : ℝ) *
      (1 - eulerMascheroniConstant) := by
    intro k _; ring
  rw [Finset.sum_congr rfl hsplit, Finset.sum_add_distrib]
  -- Step 2: The log sum is Λ(d)
  rw [vonMangoldt_eq_moebius_log_sum d hd]
  -- Step 3: Factor out (1 - γ) from the second sum
  have hfactor : ∑ k ∈ d.divisors,
      (ArithmeticFunction.moebius (d / k) : ℝ) *
      (1 - eulerMascheroniConstant) =
      (1 - eulerMascheroniConstant) *
      ∑ k ∈ d.divisors, (ArithmeticFunction.moebius (d / k) : ℝ) := by
    rw [Finset.mul_sum]; congr 1; ext k; ring
  rw [hfactor, moebius_sum_indicator d hd]
  -- Step 4: Case split on d = 1
  split_ifs with h
  · -- d = 1: (1-γ) * 1 = 1 - γ
    ring
  · -- d ≥ 2: (1-γ) * 0 = 0
    ring

-- ════════════════════════════════════════════════════════════════
-- PART IV: Concrete values (verified by native_decide / norm_num)
-- ════════════════════════════════════════════════════════════════

/-- Λ(1) = 0. -/
theorem vonMangoldt_one : ArithmeticFunction.vonMangoldt 1 = 0 :=
  ArithmeticFunction.vonMangoldt_apply_one

/-- Λ(2) = ln(2). -/
theorem vonMangoldt_two :
    ArithmeticFunction.vonMangoldt 2 = Real.log 2 := by
  exact ArithmeticFunction.vonMangoldt_apply_prime (by decide)

/-- Λ(3) = ln(3). -/
theorem vonMangoldt_three :
    ArithmeticFunction.vonMangoldt 3 = Real.log 3 := by
  exact ArithmeticFunction.vonMangoldt_apply_prime (by decide)

/-- Λ(4) = ln(2) (since 4 = 2²). -/
theorem vonMangoldt_four :
    ArithmeticFunction.vonMangoldt 4 = Real.log 2 := by
  have h : (4 : ℕ) = 2 ^ 2 := by norm_num
  rw [h, ArithmeticFunction.vonMangoldt_apply_pow (by omega)]
  exact ArithmeticFunction.vonMangoldt_apply_prime (by decide)

/-- Λ(6) = 0 (6 is not a prime power). -/
theorem vonMangoldt_six :
    ArithmeticFunction.vonMangoldt 6 = 0 := by
  rw [ArithmeticFunction.vonMangoldt_eq_zero_iff]
  decide

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════
-- 2 sorry remaining:
--   1. vonMangoldt_eq_moebius_log_sum (Möbius inversion of log)
--   2. moebius_sum_indicator (μ * ζ = ε pointwise)
--
-- smith_basis_rotation: PROVEN modulo the 2 lemmas above.
-- Concrete values (Λ(1)=0, Λ(2)=ln2, Λ(3)=ln3, Λ(4)=ln2, Λ(6)=0): ALL PROVEN.
--
-- The 2 sorry are clean combinatorial identities from Mathlib's
-- Dirichlet convolution algebra. No deep analysis needed.

end Cathedral.Physics.VonMangoldtBridge
