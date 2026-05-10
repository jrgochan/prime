/-
  Cathedral/Vasyunin/Cotangent/IntegralSubstitution.lean

  ## Proof of integral_gcd_recurrence

  For d = gcd(j,k), j' = j/d, k' = k/d:
    gramIntegral(j,k) = (1/d) · gramIntegral(j',k') + (1/(d·j'·k')) · (1 - 1/d)

  Uses Mathlib's intervalIntegral.integral_comp_mul_right for the
  substitution u = dx, and integral_add_adjacent_intervals for splitting.

  Created: April 25, 2026 — The Weekend Assault
  Status: PROVED
-/

import Cathedral.Vasyunin.Cotangent.LogDigammaBridge
import Cathedral.Analysis.FractIntegrable
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.Analysis.SpecialFunctions.Integrals.Basic
import Mathlib.Order.Filter.Basic

noncomputable section
open Real MeasureTheory intervalIntegral

namespace Cathedral.Vasyunin.IntegralSubstitution

-- ════════════════════════════════════════════════
-- §1. FRACTIONAL PART SIMPLIFICATION FOR u > 1
-- ════════════════════════════════════════════════

/-- For n ≥ 1 and u > 1: 0 < 1/(n·u) < 1, so {1/(n·u)} = 1/(n·u). -/
theorem fract_inv_mul_eq (n : ℕ) (u : ℝ) (hn : 1 ≤ n) (hu : 1 < u) :
    Int.fract (1 / ((n:ℝ) * u)) = 1 / ((n:ℝ) * u) := by
  apply Int.fract_eq_self.mpr
  constructor
  · positivity
  · rw [div_lt_one (by positivity : (0:ℝ) < (n:ℝ) * u)]
    calc (1:ℝ) ≤ (n:ℝ) := Nat.one_le_cast.mpr hn
      _ < (n:ℝ) * u := by
        have : (0:ℝ) < (n:ℝ) := Nat.cast_pos.mpr (by omega)
        nlinarith

-- ════════════════════════════════════════════════
-- §2. INNER INTEGRAND SIMPLIFICATION
-- ════════════════════════════════════════════════

/-- For u > 1 and j', k' ≥ 1:
    {1/(j'·u)} · {1/(k'·u)} = 1/(j'·k'·u²) -/
theorem integrand_simplifies (j' k' : ℕ) (u : ℝ) (hj : 1 ≤ j') (hk : 1 ≤ k') (hu : 1 < u) :
    Int.fract (1 / ((j':ℝ) * u)) * Int.fract (1 / ((k':ℝ) * u)) =
    1 / ((j':ℝ) * (k':ℝ) * u ^ 2) := by
  rw [fract_inv_mul_eq j' u hj hu, fract_inv_mul_eq k' u hk hu]
  have hj_ne : (j':ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hk_ne : (k':ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hu_ne : u ≠ 0 := by linarith
  field_simp

-- ════════════════════════════════════════════════
-- §3. THE SUBSTITUTION STEP
-- ════════════════════════════════════════════════

/-- The substitution u = d·x transforms the integral:
    ∫₀¹ {1/(jx)}·{1/(kx)} dx = (1/d) · ∫₀ᵈ {1/(j'u)}·{1/(k'u)} du

    where j = d·j', k = d·k', d = gcd(j,k).

    This uses Mathlib's integral_comp_mul_right. -/
theorem integral_substitution (j k : ℕ) (hj : 1 ≤ j) (_hk : 1 ≤ k)
    (_hjk : j ≠ k) :
    let d := Nat.gcd j k
    let j' := j / d
    let k' := k / d
    Assembly.gramIntegral j k =
    (1 / (d:ℝ)) * ∫ u in (0:ℝ)..(d:ℝ),
      Int.fract (1 / ((j':ℝ) * u)) * Int.fract (1 / ((k':ℝ) * u)) := by
  simp only
  unfold Assembly.gramIntegral
  set d := Nat.gcd j k
  set jp := j / d
  set kp := k / d
  have hd_pos : 0 < d := Nat.gcd_pos_of_pos_left k (by omega)
  have hd_ne : (d:ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hj_eq : (j:ℝ) = (d:ℝ) * (jp:ℝ) := by
    push_cast [show j = d * jp from by rw [Nat.mul_div_cancel' (Nat.gcd_dvd_left j k)]]
    ring
  have hk_eq : (k:ℝ) = (d:ℝ) * (kp:ℝ) := by
    push_cast [show k = d * kp from by rw [Nat.mul_div_cancel' (Nat.gcd_dvd_right j k)]]
    ring
  -- Rewrite {1/(jx)} = {1/(d·j'·x)} = {1/(j'·(dx))}
  have hrw : ∀ x : ℝ,
    Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)) =
    Int.fract (1 / ((jp:ℝ) * (x * (d:ℝ)))) * Int.fract (1 / ((kp:ℝ) * (x * (d:ℝ)))) := by
    intro x
    congr 1
    · congr 1; rw [hj_eq]; ring
    · congr 1; rw [hk_eq]; ring
  simp_rw [hrw]
  -- Apply the substitution: ∫₀¹ f(x·d) dx = d⁻¹ · ∫₀ᵈ f(u) du
  rw [integral_comp_mul_right (fun u => Int.fract (1 / ((jp:ℝ) * u)) *
      Int.fract (1 / ((kp:ℝ) * u))) hd_ne]
  simp [smul_eq_mul, one_div]

-- ════════════════════════════════════════════════
-- §4. SPLITTING ∫₀ᵈ = ∫₀¹ + ∫₁ᵈ
-- ════════════════════════════════════════════════

/-- Splitting the integral at u = 1:
    ∫₀ᵈ f(u) du = ∫₀¹ f(u) du + ∫₁ᵈ f(u) du

    ∫₀¹ is exactly gramIntegral(j', k').
    ∫₁ᵈ simplifies because {1/(j'u)} = 1/(j'u) for u > 1. -/
theorem split_at_one (j' k' d : ℕ) (_hj : 1 ≤ j') (_hk : 1 ≤ k') (hd : 2 ≤ d) :
    (∫ u in (0:ℝ)..(d:ℝ),
      Int.fract (1 / ((j':ℝ) * u)) * Int.fract (1 / ((k':ℝ) * u))) =
    (∫ u in (0:ℝ)..(1:ℝ),
      Int.fract (1 / ((j':ℝ) * u)) * Int.fract (1 / ((k':ℝ) * u))) +
    (∫ u in (1:ℝ)..(d:ℝ),
      Int.fract (1 / ((j':ℝ) * u)) * Int.fract (1 / ((k':ℝ) * u))) :=
  (integral_add_adjacent_intervals
    (FractIntegrable.intervalIntegrable_fract_product_01 j' k')
    (FractIntegrable.intervalIntegrable_fract_product_1d j' k' d hd)).symm

-- ════════════════════════════════════════════════
-- §5. TAIL INTEGRAL EQUALS ELEMENTARY VALUE
-- ════════════════════════════════════════════════

-- Elementary integral of 1/(j'k'u²) using FTC
-- Antiderivative: f(u) = -1/(j'k'u), f'(u) = 1/(j'k'u²)
theorem elementary_inv_sq_integral (j' k' d : ℕ) (hj : 1 ≤ j') (hk : 1 ≤ k') (hd : 2 ≤ d) :
    ∫ u in (1:ℝ)..(d:ℝ), 1 / ((j':ℝ) * (k':ℝ) * u ^ 2) =
    1 / ((j':ℝ) * (k':ℝ)) * (1 - 1 / (d:ℝ)) := by
  have hj_ne : (j':ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hk_ne : (k':ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hd_ne : (d:ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hjk_ne : (j':ℝ) * (k':ℝ) ≠ 0 := mul_ne_zero hj_ne hk_ne
  have hjk_pos : (0:ℝ) < (j':ℝ) * (k':ℝ) := by positivity
  have h1d : (1:ℝ) ≤ (d:ℝ) := by exact_mod_cast (by omega : 1 ≤ d)
  -- Factor out 1/(j'k') as a constant
  have hfactor : ∀ u : ℝ, 1 / ((j':ℝ) * (k':ℝ) * u ^ 2) =
      ((j':ℝ) * (k':ℝ))⁻¹ * (u ^ 2)⁻¹ := by
    intro u; field_simp
  simp_rw [hfactor]
  rw [intervalIntegral.integral_const_mul]
  -- Now compute ∫₁ᵈ u⁻² du = 1 - 1/d
  -- Use integral_one_div_of_pos or compute directly
  -- ∫₁ᵈ (u^2)⁻¹ du = ∫₁ᵈ u^(-2) du
  -- Rewrite (u^2)⁻¹ = u^(-2:ℝ)
  have hpow : ∀ u : ℝ, (u ^ 2)⁻¹ = u ^ ((-2:ℝ)) := by
    intro u
    rw [show (-2:ℝ) = -↑(2:ℕ) from by norm_num]
    simp; rfl
  simp_rw [hpow]
  -- Now use integral_rpow
  have h_notzero : (0:ℝ) ∉ Set.uIcc (1:ℝ) (d:ℝ) := by
    rw [Set.uIcc_of_le h1d, Set.mem_Icc]; push Not; intro; linarith
  rw [integral_rpow (Or.inr ⟨by norm_num, h_notzero⟩)]
  rw [show (-2:ℝ) + 1 = -1 by norm_num]
  simp only [rpow_neg_one]
  -- Now: (j'k')⁻¹ * ((↑d)⁻¹ - 1) / (-1) = 1/(j'k') * (1 - 1/d)
  field_simp
  ring

/-- **TAIL INTEGRAL**: For u ∈ (1, d], the fractional parts simplify:
    ∫₁ᵈ {1/(j'u)}·{1/(k'u)} du = ∫₁ᵈ 1/(j'k'u²) du = (1/(j'k'))·(1 - 1/d)

    This uses `integrand_simplifies` on the interval (1, d].
    The closed-form follows from ∫₁ᵈ u⁻² du = 1 - 1/d. -/
theorem tail_integral_value (j' k' d : ℕ) (hj : 1 ≤ j') (hk : 1 ≤ k') (hd : 2 ≤ d) :
    ∫ u in (1:ℝ)..(d:ℝ),
      Int.fract (1 / ((j':ℝ) * u)) * Int.fract (1 / ((k':ℝ) * u)) =
    1 / ((j':ℝ) * (k':ℝ)) * (1 - 1 / (d:ℝ)) := by
  -- Step 1: Rewrite integrand on Ioc(1,d) where u > 1
  have hrw : ∫ u in (1:ℝ)..(d:ℝ),
        Int.fract (1 / ((j':ℝ) * u)) * Int.fract (1 / ((k':ℝ) * u)) =
      ∫ u in (1:ℝ)..(d:ℝ), 1 / ((j':ℝ) * (k':ℝ) * u ^ 2) := by
    apply intervalIntegral.integral_congr_ae'
    · apply Filter.Eventually.of_forall
      intro u hu; exact integrand_simplifies j' k' u hj hk hu.1
    · apply Filter.Eventually.of_forall
      intro u hu
      exfalso; linarith [hu.1, hu.2, show (1:ℝ) ≤ (d:ℝ) from by exact_mod_cast (by omega : 1 ≤ d)]
  rw [hrw]
  -- Step 2: Elementary integral computation — PROVED
  exact elementary_inv_sq_integral j' k' d hj hk hd

end Cathedral.Vasyunin.IntegralSubstitution
