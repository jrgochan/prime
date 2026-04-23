/-
  Cathedral/White/Infrastructure/ZetaConvexityBound.lean

  ## Convexity Bound for |ζ(s)| in the Critical Strip

  Target: ‖ζ(s)‖ ≤ (2 + |s.im|)² for 1/2 < Re(s) ≤ 2, |Im(s)| ≥ 1/2.

  ### Strategy (based on FloorMellin.lean)

  From `floor_mellin_eq_zeta` (PROVED in FloorMellin.lean, zero sorry):
    ∫₀¹ ⌊1/t⌋ · t^{s-1} dt = ζ(s)/s   for Re(s) > 1

  Decomposing ⌊1/t⌋ = 1/t - {1/t}:
    ζ(s) = s/(s-1) - s · ∫₀¹ {1/t} · t^{s-1} dt

  Bounding (for σ > 1, |t| ≥ 1/2):
    |ζ(s)| ≤ |s|/|s-1| + |s|/σ ≤ (1+1/|t|) + (1+|t|) ≤ 4+|t| ≤ (2+|t|)²

  ### Dependencies: Mathlib (ζ, L-series), FloorMellin, ThetaBound
-/

import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.LSeries.Dirichlet
import Mathlib.NumberTheory.LSeries.Nonvanishing
import Cathedral.MellinBridge.FloorMellin
import Cathedral.NymanBeurling.ThetaBound

noncomputable section
open Complex Real Filter MeasureTheory
open scoped Topology

namespace Cathedral.White.Infrastructure.ZetaConvexityBound

-- ════════════════════════════════════════════════════
-- §1. Arithmetic lemma
-- ════════════════════════════════════════════════════

/-- 5 + |t| ≤ (2 + |t|)² for |t| ≥ 1/2.
    Proof: (2+|t|)² = 4 + 4|t| + t² ≥ 5 + |t| since 3|t| + t² ≥ 1 for |t| ≥ 1/2. -/
lemma five_add_abs_le_sq (t : ℝ) (ht : 1/2 ≤ |t|) : 5 + |t| ≤ (2 + |t|) ^ 2 := by
  nlinarith [abs_nonneg t, sq_abs t]

-- ════════════════════════════════════════════════════
-- §2. Sub-lemmas for the FloorMellin decomposition
-- ════════════════════════════════════════════════════

/-- ∫₀¹ t^{s-2} dt = 1/(s-1) for Re(s) > 1.
    Uses Mathlib's `integral_cpow` with r = s-2, which has Re(r) > -1. -/
private lemma integral_cpow_eq_inv_sub_one {s : ℂ} (hs : 1 < s.re) :
    ∫ t in Set.Ioc (0:ℝ) 1, (↑t : ℂ) ^ (s - 2) = 1 / (s - 1) := by
  -- Convert set integral to interval integral
  rw [← intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  -- Apply integral_cpow with r = s - 2
  have hre : -1 < (s - 2).re := by simp [sub_re]; linarith
  rw [integral_cpow (Or.inl hre)]
  -- Simplify: (1)^{s-1} = 1, (0)^{s-1} = 0 (since Re(s-1) > 0)
  simp only [Complex.ofReal_one, Complex.ofReal_zero]
  have hs1 : s - 2 + 1 = s - 1 := by ring
  rw [hs1]
  have hs1_ne : s - 1 ≠ 0 := by
    intro h; have := congr_arg Complex.re h; simp at this; linarith
  rw [one_cpow, zero_cpow hs1_ne]
  simp

/-- The FloorMellin integral decomposes via ⌊1/t⌋ = 1/t - {1/t}:
    ∫₀¹ ⌊1/t⌋·t^{s-1} dt = 1/(s-1) - ∫₀¹ {1/t}·t^{s-1} dt -/
private lemma floor_mellin_decomp {s : ℂ} (hs : 1 < s.re) :
    ∫ t in Set.Ioc (0:ℝ) 1,
      (↑t : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / t⌋) : ℂ) =
    1 / (s - 1) -
    ∫ t in Set.Ioc (0:ℝ) 1,
      (↑t : ℂ) ^ (s - 1) * (↑(Int.fract ((1:ℝ)/t)) : ℂ) := by
  sorry

/-- The fractional part integral is bounded: |∫₀¹ {1/t}·t^{s-1} dt| ≤ 1/σ.
    Since 0 ≤ {x} < 1, the integrand norm ≤ t^{σ-1}, so integral ≤ 1/σ. -/
private lemma norm_fract_integral_le {s : ℂ} (hs : 0 < s.re) :
    ‖∫ t in Set.Ioc (0:ℝ) 1,
      (↑t : ℂ) ^ (s - 1) * (↑(Int.fract ((1:ℝ)/t)) : ℂ)‖ ≤ 1 / s.re := by
  sorry

/-- |s/(s-1)| ≤ 1 + 1/|s.im| for s with s.im ≠ 0.
    Proof: s/(s-1) = 1 + 1/(s-1), and |1/(s-1)| ≤ 1/|Im(s)|. -/
private lemma norm_div_sub_one_le {s : ℂ} (him : s.im ≠ 0) :
    ‖s / (s - 1)‖ ≤ 1 + 1 / |s.im| := by
  have hs1 : s - 1 ≠ 0 := by
    intro h
    have : s.im = 0 := by
      have := congr_arg Complex.im h; simp at this; exact this
    exact him this
  -- s/(s-1) = 1 + 1/(s-1)
  have hkey : s / (s - 1) = 1 + (s - 1)⁻¹ := by
    rw [inv_eq_one_div]
    field_simp
    ring
  rw [hkey]
  calc ‖1 + (s - 1)⁻¹‖
      ≤ ‖(1 : ℂ)‖ + ‖(s - 1)⁻¹‖ := norm_add_le _ _
    _ = 1 + 1 / ‖s - 1‖ := by rw [norm_one, norm_inv, one_div]
    _ ≤ 1 + 1 / |s.im| := by
        gcongr
        calc |s.im| = |(s - 1).im| := by simp
          _ ≤ ‖s - 1‖ := Complex.abs_im_le_norm _

/-- From `floor_mellin_eq_zeta`, we derive the bound ‖ζ(s)‖ ≤ 5 + |s.im| for Re(s) > 1.
    The proof decomposes the integral using ⌊1/t⌋ = 1/t - {1/t}. -/
private lemma norm_zeta_le_of_re_gt_one {s : ℂ}
    (hs : 1 < s.re) (hs2 : s.re ≤ 2) (him : 1/2 ≤ |s.im|) :
    ‖riemannZeta s‖ ≤ 5 + |s.im| := by
  -- s ≠ 0+1 since |Im(s)| ≥ 1/2
  have him0 : s.im ≠ 0 := by
    intro h; rw [h, abs_zero] at him; linarith
  have hs1 : s ≠ 1 := by
    intro h; simp [h] at him0
  have hs0 : s ≠ 0 := by
    intro h; rw [h, zero_re] at hs; linarith
  -- From FloorMellin: ζ(s)/s = 1/(s-1) - ∫ {1/t}·t^{s-1} dt
  have hfm := floor_mellin_eq_zeta s hs
  have hdecomp := floor_mellin_decomp hs
  -- So ζ(s)/s = 1/(s-1) - fract_integral
  have hzeta_div : riemannZeta s / s = 1 / (s - 1) -
      ∫ t in Set.Ioc (0:ℝ) 1,
        (↑t : ℂ) ^ (s - 1) * (↑(Int.fract ((1:ℝ)/t)) : ℂ) := by
    rw [← hfm, hdecomp]
  -- Multiply both sides by s: ζ(s) = s/(s-1) - s·∫
  have hzeta_eq : riemannZeta s = s / (s - 1) -
      s * ∫ t in Set.Ioc (0:ℝ) 1,
        (↑t : ℂ) ^ (s - 1) * (↑(Int.fract ((1:ℝ)/t)) : ℂ) := by
    have := congr_arg (· * s) hzeta_div
    simp only [div_mul_cancel₀ _ hs0] at this
    rw [this]; ring
  -- Triangle inequality
  rw [hzeta_eq]
  calc ‖s / (s - 1) - s * ∫ t in Set.Ioc (0:ℝ) 1,
        (↑t : ℂ) ^ (s - 1) * (↑(Int.fract ((1:ℝ)/t)) : ℂ)‖
      ≤ ‖s / (s - 1)‖ + ‖s * ∫ t in Set.Ioc (0:ℝ) 1,
          (↑t : ℂ) ^ (s - 1) * (↑(Int.fract ((1:ℝ)/t)) : ℂ)‖ :=
        norm_sub_le _ _
    _ ≤ (1 + 1/|s.im|) + ‖s‖ * (1/s.re) := by
        gcongr
        · exact norm_div_sub_one_le him0
        · rw [norm_mul]; gcongr
          exact norm_fract_integral_le (by linarith)
    _ ≤ 3 + (s.re + |s.im|) := by
        -- 1/|s.im| ≤ 2 since |s.im| ≥ 1/2
        have h_inv_im : 1/|s.im| ≤ 2 := by
          rw [div_le_iff₀ (by linarith : (0:ℝ) < |s.im|)]
          linarith
        -- ‖s‖/σ ≤ (|σ|+|t|)/σ ≤ (σ+|t|)/σ = 1+|t|/σ ≤ 1+|t| ≤ σ+|t|
        -- More directly: ‖s‖ ≤ |s.re| + |s.im| and 1/s.re ≤ 1
        have h_norm_s : ‖s‖ ≤ |s.re| + |s.im| :=
          Complex.norm_le_abs_re_add_abs_im s
        have h_inv_re : 1/s.re ≤ 1 := by
          rw [div_le_one (by linarith : (0:ℝ) < s.re)]; linarith
        have h_re_pos : 0 < s.re := by linarith
        have h_im_pos : 0 ≤ |s.im| := abs_nonneg _
        -- ‖s‖ * (1/σ) ≤ (|σ|+|t|) * 1 = |σ| + |t| = σ + |t|
        have h_prod : ‖s‖ * (1/s.re) ≤ s.re + |s.im| :=
          calc ‖s‖ * (1/s.re) ≤ (|s.re| + |s.im|) * 1 := by
                gcongr
            _ = |s.re| + |s.im| := mul_one _
            _ = s.re + |s.im| := by rw [abs_of_pos h_re_pos]
        linarith
    _ ≤ 5 + |s.im| := by linarith

-- ════════════════════════════════════════════════════
-- §3. Main convexity bound
-- ════════════════════════════════════════════════════

/-- **Convexity bound**: ‖ζ(s)‖ ≤ (2 + |s.im|)² for 1/2 < Re(s) ≤ 2, |Im(s)| ≥ 1/2.

    For Re(s) > 1: Uses FloorMellin decomposition ζ(s) = s/(s-1) - s·∫.
    For 1/2 < Re(s) ≤ 1: Uses analytic continuation of the integral formula
    (via the identity theorem: `AnalyticOnNhd.eqOn_of_preconnected_of_eventuallyEq`).

    Downstream dependency chain:
    zeta_norm_convexity_bound → zeta_norm_bound_on_disk → BC theorem →
    zeta_polynomial_lower_bound_rh → Perron formula → MainChain. -/
theorem zeta_norm_convexity_bound {s : ℂ}
    (hrs : 1/2 < s.re) (hrs2 : s.re ≤ 2) (him : 1/2 ≤ |s.im|) :
    ‖riemannZeta s‖ ≤ (2 + |s.im|) ^ (2 : ℝ) := by
  by_cases hre : 1 < s.re
  · -- Case 1: Re(s) > 1 — direct from FloorMellin decomposition
    have h1 := norm_zeta_le_of_re_gt_one hre hrs2 him
    have h2 := five_add_abs_le_sq s.im him
    calc ‖riemannZeta s‖
        ≤ 5 + |s.im| := h1
      _ ≤ (2 + |s.im|) ^ 2 := h2
      _ = (2 + |s.im|) ^ (2 : ℝ) := by
          rw [show (2 : ℝ) = ((2 : ℕ) : ℝ) from by norm_num, rpow_natCast]
  · -- Case 2: 1/2 < Re(s) ≤ 1 — needs analytic continuation
    -- The integral ∫₀¹ {1/t}·t^{s-1} dt converges for Re(s) > 0 and defines
    -- an analytic function. By the identity theorem
    -- (AnalyticOnNhd.eqOn_of_preconnected_of_eventuallyEq), the formula
    -- ζ(s) = s/(s-1) - s·∫₀¹ {1/t}·t^{s-1} dt extends from Re(s) > 1 to Re(s) > 0.
    -- The same bound |ζ(s)| ≤ 4+|t| then applies.
    sorry

end Cathedral.White.Infrastructure.ZetaConvexityBound
