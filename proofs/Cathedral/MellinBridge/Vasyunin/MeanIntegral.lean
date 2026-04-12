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
import Cathedral.Archive.HighFrequencyTrap.FractIntegral

noncomputable section
open Real MeasureTheory

-- ════════════════════════════════════════════════
-- §1. THE "EASY" INTEGRAL: ∫_{1/k}^1 1/(kx) dx = ln(k)/k
-- ════════════════════════════════════════════════

/-- On (1/k, 1], 1/(kx) ∈ (0,1), so {1/(kx)} = 1/(kx). -/
lemma fract_inv_mul_eq_self_on_upper (k : ℕ) (hk : 1 ≤ k) (x : ℝ)
    (hx_lo : 1 / (k : ℝ) < x) (_hx_hi : x ≤ 1) :
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
  simp only [Real.log_one, mul_zero, Real.log_div one_ne_zero (ne_of_gt hk_pos),
    zero_sub]
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

/-- **Euler-Mascheroni series identity**: Σ(1/(m+1) - log(1+1/(m+1))) = γ.
    Proof: partial sums = H_N - log(N+1) → γ via tendsto_harmonic_sub_log. -/
private lemma hasSum_inv_sub_log_euler :
    HasSum (fun m : ℕ => 1 / ((m + 1 : ℕ) : ℝ) - Real.log (1 + 1 / ((m + 1 : ℕ) : ℝ)))
      Real.eulerMascheroniConstant := by
  rw [hasSum_iff_tendsto_nat_of_nonneg]
  · -- partial sum = H_N - log(N+1)
    have hpart : ∀ N, ∑ m ∈ Finset.range N,
        (1 / ((m + 1 : ℕ) : ℝ) - Real.log (1 + 1 / ((m + 1 : ℕ) : ℝ))) =
        (harmonic N : ℝ) - Real.log ((N : ℝ) + 1) := by
      intro N
      rw [Finset.sum_sub_distrib]
      congr 1
      -- Harmonic part: Σ 1/(m+1) = H_N
      · simp only [harmonic, Rat.cast_sum, Rat.cast_inv, Rat.cast_natCast]
        congr 1; ext i; rw [one_div]
      -- Log telescope: Σ log(1+1/(m+1)) = log(N+1)
      · induction N with
        | zero => simp
        | succ n ih =>
          rw [Finset.sum_range_succ, ih]
          have hn1 : (0 : ℝ) < (n : ℝ) + 1 := by positivity
          have hn2 : (0 : ℝ) < (n : ℝ) + 2 := by linarith
          rw [show 1 + 1 / ((n + 1 : ℕ) : ℝ) = ((n : ℝ) + 2) / ((n : ℝ) + 1) from by
            push_cast; field_simp; ring]
          rw [Real.log_div (ne_of_gt hn2) (ne_of_gt hn1)]
          push_cast; ring
    simp_rw [hpart]
    -- H_N - log(N+1) → γ
    have h1 := Real.tendsto_harmonic_sub_log
    have h2 : Filter.Tendsto (fun N : ℕ => Real.log ((N : ℝ) + 1) - Real.log (N : ℝ))
        Filter.atTop (nhds 0) := by
      have : Filter.Tendsto (fun N : ℕ => Real.log (1 + 1 / (N : ℝ)))
          Filter.atTop (nhds (Real.log (1 + 0))) := by
        have hlog_cont : ContinuousAt (fun x : ℝ => Real.log (1 + x)) 0 :=
          (continuousAt_const.add continuousAt_id).log (by norm_num)
        have h1N : Filter.Tendsto (fun N : ℕ => (1 : ℝ) / (N : ℝ))
            Filter.atTop (nhds 0) := by
          simp_rw [one_div]; exact tendsto_inv_atTop_nhds_zero_nat (𝕜 := ℝ)
        exact hlog_cont.tendsto.comp h1N
      simp only [add_zero, Real.log_one] at this
      refine this.congr' ?_
      filter_upwards [Filter.eventually_gt_atTop 0] with n hn
      rw [show 1 + 1 / (n : ℝ) = ((n : ℝ) + 1) / (n : ℝ) from by field_simp]
      rw [Real.log_div (by positivity) (by positivity)]
    have h3 := h1.sub h2
    simp only [sub_zero] at h3
    convert h3 using 1; ext N; ring
  · intro m
    have : Real.log (1 + 1 / ((m + 1 : ℕ) : ℝ)) ≤ 1 / ((m + 1 : ℕ) : ℝ) := by
      rw [Real.log_le_iff_le_exp (by positivity)]
      linarith [Real.add_one_le_exp (1 / ((m + 1 : ℕ) : ℝ))]
    linarith

/-- ∫₀¹ {1/x} dx = 1 - γ -/
private lemma fract_inv_integral_eq :
    ∫ x in (0:ℝ)..1, Int.fract (1 / x) = 1 - Real.eulerMascheroniConstant := by
  have h := fract_integral_identity 1 (by omega)
  simp only [Nat.cast_one, one_mul] at h
  rw [h, hasSum_inv_sub_log_euler.tsum_eq]

/-- ∫₀^{1/k} {1/(kx)} dx = (1-γ)/k.
    This is the hard integral, requiring the Euler-Mascheroni limit.
    Proof: substitute u = kx to get (1/k)∫₀¹{1/u}du = (1/k)(1-γ). -/
theorem lower_integral_eq (k : ℕ) (hk : 1 ≤ k) :
    ∫ x in (0 : ℝ)..(1 / (k : ℝ)), Int.fract (1 / ((k : ℝ) * x)) =
    (1 - Real.eulerMascheroniConstant) / (k : ℝ) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hk_ne : (k : ℝ) ≠ 0 := ne_of_gt hk_pos
  have hsub : ∫ x in (0 : ℝ)..(1 / (k : ℝ)), Int.fract (1 / ((k : ℝ) * x)) =
      (k : ℝ)⁻¹ * ∫ x in (0 : ℝ)..1, Int.fract (1 / x) := by
    have hcomm : (fun x => Int.fract (1 / ((k : ℝ) * x))) =
        (fun x => Int.fract (1 / (x * (k : ℝ)))) := by ext x; rw [mul_comm]
    rw [hcomm]
    have h := intervalIntegral.integral_comp_mul_right (a := (0 : ℝ)) (b := 1 / (k : ℝ))
      (fun u => Int.fract (1 / u)) hk_ne
    simp only [zero_mul, smul_eq_mul] at h
    rw [show 1 / (k : ℝ) * (k : ℝ) = 1 from by field_simp] at h
    exact h
  rw [hsub, fract_inv_integral_eq, inv_mul_eq_div]

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
