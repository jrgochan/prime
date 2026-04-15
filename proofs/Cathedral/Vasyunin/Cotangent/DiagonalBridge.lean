/-
  Cathedral/MellinBridge/Vasyunin/DiagonalBridge.lean

  ## The Diagonal Integral Bridge

  Proves the diagonal case of the Vasyunin integral bridge:
    vasyuninGramEntry k k = ∫₀¹ {1/(kx)}² dx

  This connects the discrete Vasyunin cotangent formula to the
  L²(0,1) inner product for the diagonal case j = k.

  Mathematical pipeline:
    LHS = (ln(2π) - γ)/k - 1/k²              [vasyuninGramEntry_diag]
    RHS = (1/k) · ∫₀ᵏ {1/u}² du               [change of variables u = kx]
        = (1/k) · (∫₀¹ {1/u}² du + ∫₁ᵏ 1/u² du) [split + fract identity]
        = (1/k) · ((ln(2π) - γ - 1) + (1 - 1/k))  [StirlingBridge + FTC]
        = (ln(2π) - γ)/k - 1/k²               [algebra]

  Created: April 12, 2026 (The Diagonal Assault)
  Status: 7 theorems + 1 axiom (fract_sq_integral_value)
-/

import Cathedral.Vasyunin.Defs
import Cathedral.Vasyunin.Cotangent.StirlingBridge
import Cathedral.Vasyunin.Cotangent.SqueezeElimination
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.MeasureTheory.Integral.IntervalIntegral.FundThmCalculus
import Mathlib.Analysis.SpecialFunctions.Integrals.Basic
import Mathlib.MeasureTheory.Function.Floor

noncomputable section
open Real MeasureTheory

namespace Cathedral.Vasyunin.DiagonalBridge

-- ════════════════════════════════════════════════
-- §1. FRACT IDENTITIES ON (1, ∞)
-- ════════════════════════════════════════════════

/-- For u > 1, {1/u} = 1/u (since 0 < 1/u < 1 and ⌊1/u⌋ = 0). -/
theorem fract_inv_of_gt_one {u : ℝ} (hu : 1 < u) :
    Int.fract (1 / u) = 1 / u := by
  apply Int.fract_eq_self.mpr
  constructor
  · positivity
  · rw [div_lt_one (by linarith)]; exact hu

/-- For u ≥ 1 with u ≠ 1, {1/u} = 1/u. -/
theorem fract_inv_of_ge_one_ae {u : ℝ} (hu : 1 ≤ u) (hu_ne : u ≠ 1) :
    Int.fract (1 / u) = 1 / u :=
  fract_inv_of_gt_one (lt_of_le_of_ne hu (Ne.symm hu_ne))

/-- For u > 1, {1/u}² = (1/u)². -/
theorem fract_sq_inv_of_gt_one {u : ℝ} (hu : 1 < u) :
    Int.fract (1 / u) * Int.fract (1 / u) = (1 / u) ^ 2 := by
  rw [fract_inv_of_gt_one hu, sq]

-- ════════════════════════════════════════════════
-- §2. THE TAIL INTEGRAL ∫₁ᵏ 1/u² du = 1 - 1/k
-- ════════════════════════════════════════════════

/-- ∫₁ᵏ 1/u² du = 1 - 1/k for k ≥ 1.
    Antiderivative: F(u) = -u⁻¹. FTC: F(k) - F(1) = -1/k + 1 = 1 - 1/k. -/
theorem integral_inv_sq (k : ℕ) (hk : 1 ≤ k) :
    ∫ u in (1:ℝ)..(k:ℝ), (1 / u ^ 2 : ℝ) = 1 - 1 / (k : ℝ) := by
  have hk_pos : (0:ℝ) < (k:ℝ) := Nat.cast_pos.mpr (by omega)
  have h1k : (1:ℝ) ≤ (k:ℝ) := by exact_mod_cast hk
  set F : ℝ → ℝ := fun u => -(u⁻¹)
  have hF : ∀ x ∈ Set.uIcc (1:ℝ) (k:ℝ),
      HasDerivAt F (1 / x ^ 2) x := by
    intro x hx
    rw [Set.uIcc_of_le h1k] at hx
    have hx_pos : (0:ℝ) < x := by linarith [hx.1]
    have hx_ne : x ≠ 0 := ne_of_gt hx_pos
    simp only [F]
    convert (hasDerivAt_inv hx_ne).neg using 1
    rw [neg_neg]; field_simp
  have hint : IntervalIntegrable (fun u => 1 / u ^ 2) volume (1:ℝ) (k:ℝ) := by
    apply ContinuousOn.intervalIntegrable
    apply ContinuousOn.div continuousOn_const (continuousOn_pow 2)
    intro x hx
    rw [Set.uIcc_of_le h1k] at hx
    exact pow_ne_zero 2 (ne_of_gt (by linarith [hx.1] : (0:ℝ) < x))
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hF hint]
  simp only [F]; rw [inv_one]; ring

-- ════════════════════════════════════════════════
-- §3. CHANGE OF VARIABLES
-- ════════════════════════════════════════════════

/-- ∫₀¹ f(kx) dx = (1/k) · ∫₀ᵏ f(u) du for k ≥ 1. -/
theorem integral_comp_mul_nat (f : ℝ → ℝ) (k : ℕ) (hk : 1 ≤ k) :
    ∫ x in (0:ℝ)..(1:ℝ), f ((k:ℝ) * x) =
    (1 / (k:ℝ)) * ∫ u in (0:ℝ)..(k:ℝ), f u := by
  have hk_ne : (k:ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  simp_rw [show ∀ x : ℝ, (k:ℝ) * x = x * (k:ℝ) from fun x => mul_comm _ _]
  have h := intervalIntegral.integral_comp_mul_right (f := f) hk_ne (a := (0:ℝ)) (b := (1:ℝ))
  rw [h]
  simp only [smul_eq_mul, inv_eq_one_div]
  congr 1 <;> ring

-- ════════════════════════════════════════════════
-- §4. SPLITTING AND ALGEBRA
-- ════════════════════════════════════════════════

/-- Split ∫₀ᵏ = ∫₀¹ + ∫₁ᵏ. -/
theorem integral_split_at_one (f : ℝ → ℝ) (k : ℕ) (_hk : 1 ≤ k)
    (hf_int_01 : IntervalIntegrable f MeasureTheory.volume 0 1)
    (hf_int_1k : IntervalIntegrable f MeasureTheory.volume 1 (k:ℝ)) :
    ∫ u in (0:ℝ)..(k:ℝ), f u =
    (∫ u in (0:ℝ)..(1:ℝ), f u) + (∫ u in (1:ℝ)..(k:ℝ), f u) := by
  rw [← intervalIntegral.integral_add_adjacent_intervals hf_int_01 hf_int_1k]

/-- The algebraic identity:
    (ln(2π) - γ)/k - 1/k² = (1/k) · ((ln(2π) - γ - 1) + (1 - 1/k)) -/
theorem diagonal_algebra (k : ℕ) (hk : 1 ≤ k) :
    (Real.log (2 * Real.pi) - eulerMascheroniConstant) / (k : ℝ) -
      1 / (k : ℝ) ^ 2 =
    1 / (k : ℝ) * ((Real.log (2 * Real.pi) - eulerMascheroniConstant - 1) +
      (1 - 1 / (k : ℝ))) := by
  have hk_ne : (k:ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  field_simp; ring

-- ════════════════════════════════════════════════
-- §5. THE BODY INTEGRAL (axiom from StirlingBridge)
-- ════════════════════════════════════════════════

/-- ∫₀¹ {1/u}² du = ln(2π) - γ - 1.
    AXIOM ELIMINATED: Now proved by SqueezeElimination via
    piecewise FTC + Squeeze Theorem.
    See: SqueezeElimination.fract_sq_integral_value -/
private theorem fract_sq_integral_value :
    ∫ u in (0:ℝ)..(1:ℝ),
      (Int.fract (1 / u) * Int.fract (1 / u) : ℝ) =
    Real.log (2 * Real.pi) - eulerMascheroniConstant - 1 :=
  Cathedral.Vasyunin.SqueezeElimination.fract_sq_integral_value

-- ════════════════════════════════════════════════
-- §6. THE DIAGONAL THEOREM
-- ════════════════════════════════════════════════

/-- **THE DIAGONAL BRIDGE**: The Vasyunin discrete formula equals
    the Lebesgue integral for the diagonal case j = k.

    vasyuninGramEntry k k = ∫₀¹ {1/(kx)}² dx

    This eliminates the vasyunin_eq_integral axiom for j = k,
    using only fract_sq_integral_value as the remaining axiom. -/
theorem vasyunin_eq_integral_diag (k : ℕ) (hk : k ≥ 1) :
    vasyuninGramEntry k k =
    ∫ x in (0:ℝ)..1,
      Int.fract (1 / ((k:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)) := by
  rw [vasyuninGramEntry_diag, diagonal_algebra k hk,
      ← fract_sq_integral_value, ← integral_inv_sq k hk]
  symm
  -- Explicitly rewrite integrand as (g ∘ (k * ·)) where g u = {1/u}²
  set g : ℝ → ℝ := fun u => Int.fract (1 / u) * Int.fract (1 / u) with hg_def
  -- LHS is ∫₀¹ g(k·x) dx
  change ∫ x in (0:ℝ)..1, g ((k:ℝ) * x) =
    1 / (k:ℝ) * ((∫ u in (0:ℝ)..1, g u) +
      ∫ u in (1:ℝ)..(k:ℝ), 1 / u ^ 2)
  rw [integral_comp_mul_nat g k hk]
  congr 1
  -- Goal: ∫₀ᵏ g = ∫₀¹ g + ∫₁ᵏ 1/u²
  -- Step A: Split ∫₀ᵏ g at 1 → ∫₀¹ g + ∫₁ᵏ g
  -- Step B: Show ∫₁ᵏ g = ∫₁ᵏ 1/u² (ae equal on (1,k])

  -- Integrability: g is bounded by 1 (since 0 ≤ fract < 1, so g ∈ [0,1))
  -- Measurability
  have hg_meas : Measurable g := by
    simp only [g]
    exact (measurable_const.div measurable_id).fract.mul
      (measurable_const.div measurable_id).fract
  -- Bound: |g(x)| ≤ 1
  have hg_norm : ∀ x : ℝ, ‖g x‖ ≤ 1 := by
    intro x; simp only [g, Real.norm_eq_abs]
    have h1 := Int.fract_nonneg (1 / x)
    have h2 := Int.fract_lt_one (1 / x)
    have hge : 0 ≤ Int.fract (1 / x) * Int.fract (1 / x) := mul_nonneg h1 h1
    have hlt : Int.fract (1 / x) * Int.fract (1 / x) < 1 :=
      calc Int.fract (1/x) * Int.fract (1/x)
          ≤ Int.fract (1/x) * 1 := by nlinarith
        _ < 1 := by linarith
    rw [abs_of_nonneg hge]; linarith
  -- Constant 1 is interval integrable
  have hg_int_01 : IntervalIntegrable g volume (0:ℝ) 1 :=
    IntervalIntegrable.mono_fun (intervalIntegrable_const (c := (1:ℝ)))
      hg_meas.aestronglyMeasurable.restrict
      (ae_of_all _ (fun x => by
        simp only [Real.norm_eq_abs, abs_one]; exact hg_norm x))
  have hg_int_1k : IntervalIntegrable g volume (1:ℝ) (k:ℝ) :=
    IntervalIntegrable.mono_fun (intervalIntegrable_const (c := (1:ℝ)))
      hg_meas.aestronglyMeasurable.restrict
      (ae_of_all _ (fun x => by
        simp only [Real.norm_eq_abs, abs_one]; exact hg_norm x))

  -- Step A: Split ∫₀ᵏ g at 1
  rw [integral_split_at_one g k hk hg_int_01 hg_int_1k]
  -- Goal: ∫₀¹ g + ∫₁ᵏ g = ∫₀¹ g + ∫₁ᵏ 1/u²
  congr 1

  -- Step B: ∫₁ᵏ g = ∫₁ᵏ 1/u² by ae equality on (1,k]
  apply intervalIntegral.integral_congr_ae
  -- Need: ∀ᵐ x ∂volume, x ∈ Ι 1 k → g(x) = 1/x²
  -- Ι 1 k = Set.uIoc 1 k. For x ∈ uIoc 1 k with 1 ≤ k, x > 1.
  filter_upwards with x
  intro hx
  simp only [Set.mem_uIoc] at hx
  have hx_gt : 1 < x := by
    rcases hx with ⟨h1, _⟩ | ⟨h1, h2⟩
    · exact h1
    · have : (k:ℝ) ≥ 1 := by exact_mod_cast hk
      linarith
  simp only [g]
  rw [fract_inv_of_gt_one hx_gt]
  -- Goal: x⁻¹ * x⁻¹ = 1 / x ^ 2
  have hx_ne : x ≠ 0 := ne_of_gt (by linarith)
  field_simp

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- PROVED (ZERO sorry, ZERO sorry placeholders):
--   ✅ fract_inv_of_gt_one      — {1/u} = 1/u for u > 1
--   ✅ fract_inv_of_ge_one_ae   — same for u ≥ 1, u ≠ 1
--   ✅ fract_sq_inv_of_gt_one   — {1/u}² = (1/u)² for u > 1
--   ✅ integral_inv_sq           — ∫₁ᵏ 1/u² du = 1 - 1/k (FTC)
--   ✅ integral_comp_mul_nat     — ∫₀¹ f(kx) = (1/k)∫₀ᵏ f
--   ✅ integral_split_at_one     — ∫₀ᵏ = ∫₀¹ + ∫₁ᵏ
--   ✅ diagonal_algebra          — key algebraic identity
--   ✅ vasyunin_eq_integral_diag — THE DIAGONAL BRIDGE (complete!)
--
-- AXIOM (1):
--   ⚠️ fract_sq_integral_value — ∫₀¹ {1/u}² du = ln(2π) - γ - 1
--      (StirlingBridge proves the limit; connecting to integral
--       requires monotone convergence on piecewise decomposition)

end Cathedral.Vasyunin.DiagonalBridge
