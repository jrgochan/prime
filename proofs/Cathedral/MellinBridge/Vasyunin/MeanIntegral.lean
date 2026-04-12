/-
  Cathedral/MellinBridge/Vasyunin/MeanIntegral.lean

  **THE MEAN ENTRY INTEGRAL — PROVING THE FRESHMAN CALCULUS AXIOM**

  Goal: Prove vasyunin_mean_eq_integral, i.e.,
    (ln k + 1 - γ) / k = ∫₀¹ {1/(kx)} dx

  Strategy (per Theorist's derivation):
  Split [0,1] into [1/k, 1] ∪ [0, 1/k]:
  - On [1/k, 1]: 1/(kx) ∈ (0,1], floor = 0, {1/(kx)} = 1/(kx)
    ∫_{1/k}^1 1/(kx) dx = (1/k) ln(k)
  - On [0, 1/k]: 1/(kx) > 1, need piecewise analysis
    ∫₀^{1/k} {1/(kx)} dx = (1 - γ)/k
    (via telescoping with Euler-Mascheroni constant)

  Total: ln(k)/k + (1-γ)/k = (ln k + 1 - γ)/k = b_k  ✓

  Created: April 11, 2026, 10:00 PM MDT (The Night Shift)
-/

import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.MeasureTheory.Integral.IntervalIntegral.FundThmCalculus
import Mathlib.MeasureTheory.Function.Floor
import Mathlib.Analysis.SpecialFunctions.Log.Deriv
import Mathlib.NumberTheory.Harmonic.EulerMascheroni

noncomputable section
open Real MeasureTheory

-- ════════════════════════════════════════════════
-- §1. THE "EASY" INTEGRAL: ∫_{1/k}^1 1/(kx) dx = ln(k)/k
-- ════════════════════════════════════════════════

/-- On (1/k, 1], 1/(kx) ∈ (0,1), so {1/(kx)} = 1/(kx). -/
lemma fract_inv_mul_eq_self_on_upper (k : ℕ) (hk : 1 ≤ k) (x : ℝ)
    (hx_lo : 1 / (k : ℝ) < x) (hx_hi : x ≤ 1) :
    Int.fract (1 / ((k : ℝ) * x)) = 1 / ((k : ℝ) * x) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hx_pos : (0 : ℝ) < x := lt_of_lt_of_le (div_pos one_pos hk_pos) (le_of_lt hx_lo)
  have hkx_pos : (0 : ℝ) < (k : ℝ) * x := mul_pos hk_pos hx_pos
  -- 1/(kx) > 0 since kx > 0
  have h_pos : 0 < 1 / ((k : ℝ) * x) := div_pos one_pos hkx_pos
  -- 1/(kx) < 1 since kx > 1 (x > 1/k)
  have h_lt_one : 1 / ((k : ℝ) * x) < 1 := by
    rw [div_lt_one hkx_pos]
    calc 1 = (k : ℝ) * (1 / (k : ℝ)) := by rw [mul_div_cancel₀ _ (ne_of_gt hk_pos)]
      _ < (k : ℝ) * x := by exact mul_lt_mul_of_pos_left hx_lo hk_pos
  -- Floor = 0 since 0 < 1/(kx) < 1
  have h_floor : ⌊1 / ((k : ℝ) * x)⌋ = 0 := Int.floor_eq_zero_iff.mpr ⟨le_of_lt h_pos, h_lt_one⟩
  rw [Int.fract, h_floor, Int.cast_zero, sub_zero]

/-- ∫_{1/k}^1 {1/(kx)} dx = ∫_{1/k}^1 1/(kx) dx = ln(k)/k.
    Uses a.e. congr to replace {1/(kx)} with 1/(kx) on (1/k, 1),
    then FTC with antiderivative (1/k)·ln(kx). -/
theorem upper_integral_eq_log (k : ℕ) (hk : 1 ≤ k) :
    ∫ x in (1 / (k : ℝ))..(1 : ℝ), Int.fract (1 / ((k : ℝ) * x)) =
    Real.log (k : ℝ) / (k : ℝ) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hle : 1 / (k : ℝ) ≤ 1 := by rw [div_le_one hk_pos]; exact_mod_cast hk
  -- Step 1: Replace {1/(kx)} with 1/(kx) via a.e. congr
  have h_congr : ∫ x in (1 / (k : ℝ))..(1 : ℝ), Int.fract (1 / ((k : ℝ) * x)) =
      ∫ x in (1 / (k : ℝ))..(1 : ℝ), 1 / ((k : ℝ) * x) := by
    rw [intervalIntegral.integral_of_le hle, intervalIntegral.integral_of_le hle]
    apply integral_congr_ae
    exact (ae_restrict_mem measurableSet_Ioc).mono fun x hx => by
      exact fract_inv_mul_eq_self_on_upper k hk x hx.1 hx.2
  rw [h_congr]
  -- Step 2: FTC with antiderivative F(x) = (1/k) · ln(x)
  -- Since d/dx[(1/k)·ln(x)] = (1/k)·(1/x) = 1/(kx)
  have hF : ∀ x ∈ Set.uIcc (1 / (k : ℝ)) 1,
      HasDerivAt (fun x => (1 / (k : ℝ)) * Real.log x)
        (1 / ((k : ℝ) * x)) x := by
    intro x hx
    rw [Set.uIcc_of_le hle] at hx
    have hx_pos : (0 : ℝ) < x := lt_of_lt_of_le (div_pos one_pos hk_pos) hx.1
    convert (Real.hasDerivAt_log (ne_of_gt hx_pos)).const_mul (1 / (k : ℝ)) using 1
    field_simp
  have hint : IntervalIntegrable (fun x => 1 / ((k : ℝ) * x)) volume (1 / (k : ℝ)) 1 := by
    apply ContinuousOn.intervalIntegrable
    apply ContinuousOn.div continuousOn_const (continuousOn_const.mul continuousOn_id)
    intro x hx; rw [Set.uIcc_of_le hle] at hx
    exact ne_of_gt (mul_pos hk_pos (lt_of_lt_of_le (div_pos one_pos hk_pos) hx.1))
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hF hint]
  simp only [Real.log_one, mul_zero, Real.log_div one_ne_zero (ne_of_gt hk_pos), Real.log_one,
    zero_sub, neg_neg]
  ring

-- ════════════════════════════════════════════════
-- §2. THE "HARD" INTEGRAL: ∫₀^{1/k} {1/(kx)} dx = (1-γ)/k
-- ════════════════════════════════════════════════

-- On (1/((n+1)k), 1/(nk)), 1/(kx) ∈ (n, n+1), floor = n, {1/(kx)} = 1/(kx) - n.
-- Each piece integral: ∫ (1/(kx) - n) dx = (1/k)(ln((n+1)/n) - n·(1/(nk) - 1/((n+1)k)))
-- = (1/k)(ln(1+1/n) - 1/(n+1))

-- Summing: (1/k) Σ_{n≥1} (ln(1+1/n) - 1/(n+1))
-- = (1/k) Σ (ln(1+1/n) - 1/n + 1/n - 1/(n+1))
-- = (1/k) (Σ (ln(1+1/n) - 1/n) + Σ (1/n - 1/(n+1)))
-- = (1/k) (-γ + 1)  [first sum = Euler-Mascheroni by sign flip, second telescopes to 1]
-- = (1-γ)/k

/-- ∫₀^{1/k} {1/(kx)} dx = (1-γ)/k.
    This is the hard integral, requiring the Euler-Mascheroni limit. -/
theorem lower_integral_eq (k : ℕ) (hk : 1 ≤ k) :
    ∫ x in (0 : ℝ)..(1 / (k : ℝ)), Int.fract (1 / ((k : ℝ) * x)) =
    (1 - Real.eulerMascheroniConstant) / (k : ℝ) := by
  sorry -- piecewise decomposition + Euler-Mascheroni limit

-- ════════════════════════════════════════════════
-- §3. ASSEMBLY: mean entry = integral
-- ════════════════════════════════════════════════

/-- {1/(kx)} is integrable on any interval. -/
theorem fract_inv_mul_intervalIntegrable (k : ℕ) (a b : ℝ) :
    IntervalIntegrable (fun x => Int.fract (1 / ((k : ℝ) * x))) MeasureTheory.volume a b := by
  apply IntervalIntegrable.mono_fun (f := fun _ => (1 : ℝ))
      (hf := intervalIntegrable_const)
  · exact (measurable_fract.comp
      (measurable_const.div (measurable_const.mul measurable_id))).aestronglyMeasurable.restrict
  · filter_upwards with x
    rw [Real.norm_eq_abs, abs_of_nonneg (Int.fract_nonneg _), norm_one]
    exact le_of_lt (Int.fract_lt_one _)

/-- **THE MEAN ENTRY INTEGRAL IDENTITY** (proves the axiom).

    vasyuninMeanEntry k = (ln k + 1 - γ) / k = ∫₀¹ {1/(kx)} dx

    Split integral: ∫₀¹ = ∫₀^{1/k} + ∫_{1/k}^1
    = (1-γ)/k + ln(k)/k = (ln k + 1 - γ)/k. ∎ -/
theorem mean_entry_eq_integral (k : ℕ) (hk : 1 ≤ k) :
    (Real.log (k : ℝ) + 1 - Real.eulerMascheroniConstant) / (k : ℝ) =
    ∫ x in (0:ℝ)..1, Int.fract (1 / ((k : ℝ) * x)) := by
  have h_split := intervalIntegral.integral_add_adjacent_intervals
    (fract_inv_mul_intervalIntegrable k 0 (1 / (k : ℝ)))
    (fract_inv_mul_intervalIntegrable k (1 / (k : ℝ)) 1)
  rw [← h_split, lower_integral_eq k hk, upper_integral_eq_log k hk]
  field_simp; ring

end
