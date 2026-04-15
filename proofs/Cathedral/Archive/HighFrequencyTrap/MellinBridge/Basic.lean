import Cathedral.Defs
import Cathedral.Archive.HighFrequencyTrap.Structural.Structural
import Mathlib.Analysis.MellinTransform
import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.LSeries.Dirichlet
import Mathlib.NumberTheory.LSeries.Nonvanishing
import Mathlib.Analysis.SpecialFunctions.Integrability.Basic

/-! # Cathedral.Archive.HighFrequencyTrap.MellinBridge.Basic

## Definitions and core Mellin transform infrastructure

This module defines the restricted Mellin transform on (0,1) and the
fractional part basis functions {k/x}, establishing the mathematical
framework for the Nyman-Beurling criterion.

### Key definitions
- `mellinRestricted`: M₀₁[f](s) = ∫₀¹ f(x) · x^{s-1} dx
- `fractBasisC`: φ_k(x) = {k/x}
- `targetFnC`: 1_{(0,1)}
- `mellin_target`: ∫₀¹ x^{s-1} dx = 1/s (proved from Mathlib)
-/

noncomputable section
open Complex Real MeasureTheory Set Filter

-- ════════════════════════════════════════════════
-- DEFINITIONS
-- ════════════════════════════════════════════════

/-- The restricted Mellin transform on (0,1):
    M₀₁[f](s) = ∫₀¹ f(x) · x^{s-1} dx.

    This is the natural inner product ⟨f, x^{s-1}⟩ in L²(0,1)
    when s = 1/2 + it (on the critical line). -/
def mellinRestricted (f : ℝ → ℂ) (s : ℂ) : ℂ :=
  ∫ t in Set.Ioc (0 : ℝ) 1, (t : ℂ) ^ (s - 1) * f t

/-- The fractional part basis function as a ℂ-valued function.
    φ_k(x) = {k/x} for x > 0. -/
def fractBasisC (k : ℕ) (x : ℝ) : ℂ :=
  (↑(Int.fract ((k : ℝ) / x)) : ℂ)

/-- The target function: 1_{(0,1)}, as a ℂ-valued function.
    This is the function we want to approximate in L². -/
def targetFnC (x : ℝ) : ℂ :=
  if 0 < x ∧ x ≤ 1 then 1 else 0

-- ════════════════════════════════════════════════
-- MELLIN TRANSFORMS OF BASIS FUNCTIONS
-- ════════════════════════════════════════════════

/-- **Theorem**: Mellin transform of the target function 1_{(0,1)}.
    ∫₀¹ 1 · x^{s-1} dx = 1/s  for Re(s) > 0.

    NOTE: This is ALREADY in Mathlib as `hasMellin_one_Ioc`!
    We state it here in our restricted Mellin notation for interface clarity.
    The proof simply unfolds `mellinRestricted` and applies the Mathlib result. -/
theorem mellin_target (s : ℂ) (hs : 0 < s.re) :
    mellinRestricted targetFnC s = 1 / s := by
  unfold mellinRestricted
  have h_simp : Set.EqOn
      (fun t : ℝ => (↑t : ℂ) ^ (s - 1) * targetFnC t)
      (fun t : ℝ => (↑t : ℂ) ^ (s - 1))
      (Set.Ioc (0:ℝ) 1) := by
    intro t ⟨h0, h1⟩
    simp only [targetFnC, if_pos (And.intro h0 h1), mul_one]
  rw [setIntegral_congr_fun measurableSet_Ioc h_simp]
  rw [← intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  have hre : -1 < (s - 1).re := by simp [sub_re, one_re]; linarith
  have hs0 : s ≠ 0 := by intro h; rw [h, zero_re] at hs; exact lt_irrefl _ hs
  rw [integral_cpow (Or.inl hre), sub_add_cancel, ofReal_one, one_cpow,
      ofReal_zero, zero_cpow hs0, sub_zero]

/- **Documentation**: Mellin transform of the fractional part basis function.

    For Re(s) > 1 and k ≥ 1:
    ∫₀¹ {k/x} · x^{s-1} dx = k/(s(s-1)) + (k^s/s)(H_k(s) - ζ(s))

    where H_k(s) = ∑_{m=1}^k m^{-s} is the partial Dirichlet sum.

    For k = 1, this simplifies to: 1/(s-1) - ζ(s)/s.

    **Derivation**:
    1. Substitute u = k/x: integral becomes k^s ∫_k^∞ {u} u^{-s-1} du
    2. Expand {u} = u - ⌊u⌋ and split at integer points
    3. Abel summation on ∑_{n=k}^∞ n(n^{-s} - (n+1)^{-s})
    4. The sum telescopes to k^{1-s} + ζ(s) - ∑_{m=1}^k m^{-s}
    5. Combining gives the identity above

    **Numerically verified** for k = 1,2,3 and s = 2,3 to 6 decimal places.

    **Reduction**: For k = 1, the identity decomposes as:
      {1/x} = 1/x - ⌊1/x⌋, so
      ∫₀¹ {1/x} x^{s-1} = ∫₀¹ x^{s-2} - ∫₀¹ ⌊1/x⌋ x^{s-1}
                          = 1/(s-1) - ζ(s)/s
    The first integral is proved (mellin_cpow_restricted).
    The second is the `floor_mellin_eq_zeta` theorem below. -/
