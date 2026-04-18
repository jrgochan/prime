/-
  Cathedral/White/Infrastructure/DirichletZetaInverse.lean

  ## The Dirichlet Series for 1/ζ(s)

  PHYSICS: The inverse propagator — Möbius inversion in the S-matrix.
  MATH: L(μ, s) = 1/ζ(s) for Re(s) > 1, pure algebra.

  ### Mathlib Status: FULLY COVERED ✅
  - `ArithmeticFunction.LSeries_zeta_mul_Lseries_moebius` (ζ·μ = 1)
  - `ArithmeticFunction.LSeries_zeta_eq_riemannZeta` (L(ζ,s) = ζ(s))
  - `ArithmeticFunction.LSeriesSummable_moebius_iff` (convergence)

  ### Dependencies: Mathlib only.
-/

import Mathlib.NumberTheory.LSeries.Dirichlet

noncomputable section
open Complex Real ArithmeticFunction BigOperators

-- access notation
open scoped LSeries.notation ArithmeticFunction.Moebius ArithmeticFunction.zeta

namespace Cathedral.White.Infrastructure

-- ═══════════════════════════════════════════
-- §1. L(μ, s) = 1/ζ(s) — PROVED ✅
-- ═══════════════════════════════════════════

/-- **PROVED**: The L-series of the Möbius function is the reciprocal of ζ(s).

    This is the fundamental identity: ∑ μ(n)/n^s = 1/ζ(s) for Re(s) > 1.
    Proof: Pure algebra from Mathlib's `LSeries_zeta_mul_Lseries_moebius`
    and `LSeries_zeta_eq_riemannZeta`. -/
theorem moebius_lseries_eq_inv_zeta {s : ℂ} (hs : 1 < s.re) :
    LSeries (↗μ) s = 1 / riemannZeta s := by
  have hζ_ne : riemannZeta s ≠ 0 := riemannZeta_ne_zero_of_one_lt_re hs
  have h_prod := LSeries_zeta_mul_Lseries_moebius hs
  rw [LSeries_zeta_eq_riemannZeta hs] at h_prod
  -- h_prod : ζ(s) * L(μ,s) = 1
  -- Therefore L(μ,s) = 1/ζ(s)
  rw [one_div]
  exact mul_left_cancel₀ hζ_ne (by rw [mul_inv_cancel₀ hζ_ne]; exact h_prod)

/-- **PROVED**: The Möbius L-series converges absolutely for Re(s) > 1. -/
theorem moebius_lseries_summable {s : ℂ} (hs : 1 < s.re) :
    LSeriesSummable (↗μ) s :=
  LSeriesSummable_moebius_iff.mpr hs

/-- **PROVED**: ζ(s) ≠ 0 for Re(s) > 1. -/
theorem zeta_ne_zero_of_re_gt_one {s : ℂ} (hs : 1 < s.re) :
    riemannZeta s ≠ 0 :=
  riemannZeta_ne_zero_of_one_lt_re hs

-- ═══════════════════════════════════════════
-- §2. The Summatory Möbius Function
-- ═══════════════════════════════════════════

/-- The summatory Möbius function M(x) = ∑_{n ≤ x} μ(n). -/
def summatoryMoebius (x : ℝ) : ℤ :=
  ∑ n ∈ Finset.Icc 1 ⌊x⌋₊, μ n

/-- M(x) is bounded by x (trivially). -/
lemma summatoryMoebius_le (x : ℝ) (hx : 0 < x) :
    |((summatoryMoebius x : ℤ) : ℝ)| ≤ x := by
  sorry -- Each μ(n) ∈ {-1, 0, 1}, summing at most ⌊x⌋ terms

/-  **COROLLARY**: By Perron's formula (once proved),
    M(x) = (1/2πi) ∫_{c-iT}^{c+iT} x^s / (s·ζ(s)) ds + O(x^c/T)

    This follows from:
    1. perron_formula_from_kernel with a(n) = μ(n)
    2. ∑ μ(n)/n^s = 1/ζ(s) (moebius_lseries_eq_inv_zeta above)
    3. Absolute convergence for c > 1 (moebius_lseries_summable above)

    The contour shift from Re(s) = c to Re(s) = 1/2 + ε then gives
    M(x) = O(x^{1/2+ε}) under RH. -/

end Cathedral.White.Infrastructure
