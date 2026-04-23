/-
  Cathedral/White/Infrastructure/ZetaConvexityBound.lean

  ## Convexity Bound for |ζ(s)| in the Critical Strip

  Target: ‖ζ(s)‖ ≤ (2 + |s.im|)² for 1/2 < Re(s) ≤ 2, |Im(s)| ≥ 1/2.

  ### Strategy

  From `bd_mellin_base_case_proved` (PROVED in IdentityBypass.lean, zero sorry):
    ∫₀¹ {1/x} · x^{s-1} dx = 1/(s-1) - ζ(s)/s   for Re(s) > 0, s ≠ 1

  Rearranging:
    ζ(s) = s/(s-1) - s · ∫₀¹ {1/t} · t^{s-1} dt

  Bounding (for σ > 1/2, |t| ≥ 1/2):
    |ζ(s)| ≤ |s/(s-1)| + |s| · |∫|
           ≤ (1 + 1/|t|) + (σ + |t|) · (1/σ)
           ≤ 3 + (σ + |t|) ≤ 5 + |t| ≤ (2 + |t|)²

  ### Key dependencies (all zero sorry):
  - IdentityBypass.lean: bd_mellin_base_case_proved (analytic continuation via identity theorem)
  - FloorMellin.lean: floor_mellin_eq_zeta (integral representation, Re > 1)
  - FloorDivMellin.lean: mellin_fractBasis (fract decomposition)
  - DomainConnected.lean: domain connectivity
-/

import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.LSeries.Dirichlet
import Mathlib.NumberTheory.LSeries.Nonvanishing
import Cathedral.MellinBridge.IdentityBypass
import Cathedral.NymanBeurling.ThetaBound

noncomputable section
open Complex Real Filter MeasureTheory Set
open scoped Topology

namespace Cathedral.White.Infrastructure.ZetaConvexityBound

-- ════════════════════════════════════════════════════
-- §1. Arithmetic lemma
-- ════════════════════════════════════════════════════

/-- 4 + 2*|t| ≤ (2 + |t|)² for all t : ℝ.
    Proof: (2+|t|)² = 4 + 4|t| + t² ≥ 4 + 2|t| since 2|t| + t² ≥ 0. -/
private lemma four_add_two_abs_le_sq (t : ℝ) : 4 + 2 * |t| ≤ (2 + |t|) ^ 2 := by
  nlinarith [abs_nonneg t, sq_abs t]

-- ════════════════════════════════════════════════════
-- §2. The zeta decomposition from IdentityBypass
-- ════════════════════════════════════════════════════

/-- ζ(s) = s/(s-1) - s·∫₀¹ {1/t}·t^{s-1} dt for Re(s) > 0, s ≠ 1.
    Follows directly from `bd_mellin_base_case_proved`:
      ∫₀¹ {1/t}·t^{s-1} dt = 1/(s-1) - ζ(s)/s
    Rearranging: ζ(s)/s = 1/(s-1) - ∫, so ζ(s) = s/(s-1) - s·∫. -/
private lemma zeta_eq_pole_minus_fract {s : ℂ} (hs : 0 < s.re) (hs1 : s ≠ 1) :
    riemannZeta s = s / (s - 1) -
      s * ∫ x in Ioo (0:ℝ) 1,
        ((Int.fract (1 / x) : ℝ) : ℂ) * (↑x : ℂ) ^ (s - 1) := by
  have hs0 : s ≠ 0 := by intro h; rw [h, zero_re] at hs; linarith
  have hs1' : s - 1 ≠ 0 := sub_ne_zero.mpr hs1
  -- From IdentityBypass: ∫ {1/x}·x^{s-1} = 1/(s-1) - ζ(s)/s
  have hIB := bd_mellin_base_case_proved s hs hs1
  -- hIB: ∫ = 1/(s-1) - ζ(s)/s, so ζ(s)/s = 1/(s-1) - ∫
  set I := ∫ x in Ioo (0:ℝ) 1,
      ((Int.fract (1 / x) : ℝ) : ℂ) * (↑x : ℂ) ^ (s - 1) with hI_def
  -- From hIB: I = 1/(s-1) - ζ/s, rearrange to ζ/s = 1/(s-1) - I
  have hzeta_div : riemannZeta s / s = 1 / (s - 1) - I := by
    -- hIB: I = 1/(s-1) - ζ(s)/s, so ζ(s)/s = 1/(s-1) - I
    have h1 : I + riemannZeta s / s = 1 / (s - 1) := by
      rw [hIB]; ring
    linear_combination h1
  -- Multiply both sides by s: ζ(s) = s * (1/(s-1) - I)
  have hmul := congr_arg (· * s) hzeta_div
  simp only [div_mul_cancel₀ _ hs0] at hmul
  -- hmul: ζ(s) = (1/(s-1) - I) * s
  rw [hmul]
  -- Goal: (1/(s-1) - I) * s = s/(s-1) - s * I
  ring

-- ════════════════════════════════════════════════════
-- §3. Norm bounds
-- ════════════════════════════════════════════════════

/-- |s/(s-1)| ≤ 1 + 1/|s.im| for s with s.im ≠ 0.
    Proof: s/(s-1) = 1 + 1/(s-1), and |1/(s-1)| ≤ 1/|Im(s)|. -/
private lemma norm_div_sub_one_le {s : ℂ} (him : s.im ≠ 0) :
    ‖s / (s - 1)‖ ≤ 1 + 1 / |s.im| := by
  have hs1 : s - 1 ≠ 0 := by
    intro h
    have : s.im = 0 := by
      have := congr_arg Complex.im h; simp at this; exact this
    exact him this
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

/-- The fractional part integral is bounded: |∫₀¹ {1/t}·t^{s-1} dt| ≤ 1/σ.
    Since 0 ≤ {x} < 1, the integrand norm ≤ t^{σ-1}, so integral ≤ 1/σ.
    Uses norm_ofReal_cpow from FloorMellin.lean. -/
private lemma norm_fract_integral_le {s : ℂ} (hs : 0 < s.re) :
    ‖∫ x in Ioo (0:ℝ) 1,
      ((Int.fract (1 / x) : ℝ) : ℂ) * (↑x : ℂ) ^ (s - 1)‖ ≤ 1 / s.re := by
  -- Step 1: Convert Ioo to Ioc (measure-zero difference)
  rw [← integral_Ioc_eq_integral_Ioo]
  -- x^{σ-1} is integrable on Ioc(0,1) for σ > 0 (hence σ-1 > -1)
  have hrpow : IntegrableOn (fun x : ℝ => x ^ (s.re - 1)) (Ioc 0 1) := by
    have := intervalIntegral.intervalIntegrable_rpow'
      (show -1 < s.re - 1 from by linarith) (a := 0) (b := 1)
    rwa [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)] at this
  -- Pointwise norm bound: ‖{1/x}·x^{s-1}‖ ≤ x^{σ-1}
  have hpw : ∀ᵐ x ∂(volume.restrict (Ioc (0:ℝ) 1)),
      ‖((Int.fract (1 / x) : ℝ) : ℂ) * (↑x : ℂ) ^ (s - 1)‖ ≤ x ^ (s.re - 1) := by
    filter_upwards [ae_restrict_mem measurableSet_Ioc] with x hx
    obtain ⟨hx_pos, _⟩ := hx
    rw [norm_mul, Complex.norm_real, norm_ofReal_cpow x hx_pos]
    calc |Int.fract (1 / x)| * x ^ (s - 1).re
        ≤ 1 * x ^ (s - 1).re := by
          gcongr
          rw [abs_le]
          exact ⟨by linarith [Int.fract_nonneg (1/x)],
                 le_of_lt (Int.fract_lt_one _)⟩
      _ = x ^ (s.re - 1) := by simp [sub_re]
  -- Chain: ‖∫f‖ ≤ ∫ x^{σ-1} = 1/σ
  calc ‖∫ x in Ioc (0:ℝ) 1,
        ((Int.fract (1 / x) : ℝ) : ℂ) * (↑x : ℂ) ^ (s - 1)‖
      ≤ ∫ x in Ioc (0:ℝ) 1, x ^ (s.re - 1) :=
        norm_integral_le_of_norm_le hrpow hpw
    _ = 1 / s.re := by
        rw [← intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
        rw [integral_rpow (Or.inl (by linarith : (-1:ℝ) < s.re - 1))]
        have hσ : s.re - 1 + 1 = s.re := by ring
        rw [hσ, one_rpow, zero_rpow (ne_of_gt hs), sub_zero]

-- ════════════════════════════════════════════════════
-- §4. The main bound (unified: works for ALL Re(s) > 1/2)
-- ════════════════════════════════════════════════════

/-- ‖ζ(s)‖ ≤ (2 + |s.im|)² for 1/2 < Re(s) ≤ 2, |Im(s)| ≥ 1/2.
    Uses the decomposition from IdentityBypass which is valid for ALL Re(s) > 0.
    No case-splitting needed — the formula works everywhere. -/
private lemma norm_zeta_le {s : ℂ}
    (hrs : 1/2 < s.re) (_ : s.re ≤ 2) (him : 1/2 ≤ |s.im|) :
    ‖riemannZeta s‖ ≤ (2 + |s.im|) ^ 2 := by
  -- s ≠ 1 since |Im(s)| ≥ 1/2 but Im(1) = 0
  have him0 : s.im ≠ 0 := by
    intro h; rw [h, abs_zero] at him; linarith
  have hs1 : s ≠ 1 := by
    intro h; simp [h] at him0
  have hs0 : s ≠ 0 := by
    intro h; rw [h, zero_re] at hrs; linarith
  have hre_pos : 0 < s.re := by linarith
  -- Apply the decomposition: ζ(s) = s/(s-1) - s·∫
  rw [zeta_eq_pole_minus_fract hre_pos hs1]
  -- Triangle inequality
  calc ‖s / (s - 1) - s * ∫ x in Ioo (0:ℝ) 1,
        ((Int.fract (1 / x) : ℝ) : ℂ) * (↑x : ℂ) ^ (s - 1)‖
      ≤ ‖s / (s - 1)‖ + ‖s * ∫ x in Ioo (0:ℝ) 1,
          ((Int.fract (1 / x) : ℝ) : ℂ) * (↑x : ℂ) ^ (s - 1)‖ :=
        norm_sub_le _ _
    _ ≤ (1 + 1/|s.im|) + ‖s‖ * (1/s.re) := by
        gcongr
        · exact norm_div_sub_one_le him0
        · rw [norm_mul]; gcongr
          exact norm_fract_integral_le hre_pos
    _ ≤ 3 + (1 + 2 * |s.im|) := by
        -- 1/|s.im| ≤ 2 since |s.im| ≥ 1/2
        have h_inv_im : 1/|s.im| ≤ 2 := by
          rw [div_le_iff₀ (by linarith : (0:ℝ) < |s.im|)]
          linarith
        -- ‖s‖ ≤ |s.re| + |s.im|
        have h_norm_s : ‖s‖ ≤ |s.re| + |s.im| :=
          Complex.norm_le_abs_re_add_abs_im s
        -- ‖s‖ * (1/σ) ≤ (σ+|t|)/σ = 1 + |t|/σ ≤ 1 + 2|t| (since σ > 1/2)
        have h_prod : ‖s‖ * (1 / s.re) ≤ 1 + 2 * |s.im| := by
          have h_abs_re : |s.re| = s.re := abs_of_pos hre_pos
          have h_bound : ‖s‖ ≤ s.re + |s.im| := by linarith [h_norm_s]
          -- ‖s‖/σ ≤ (σ+|t|)/σ = 1 + |t|/σ
          have h_div : ‖s‖ * (1 / s.re) ≤ (s.re + |s.im|) / s.re := by
            rw [one_div, div_eq_mul_inv]
            exact mul_le_mul_of_nonneg_right h_bound (inv_nonneg.mpr hre_pos.le)
          rw [add_div, div_self (ne_of_gt hre_pos)] at h_div
          -- |t|/σ ≤ 2|t| since σ > 1/2
          have h_im_div : |s.im| / s.re ≤ 2 * |s.im| := by
            rw [div_le_iff₀ hre_pos]; nlinarith [abs_nonneg s.im]
          linarith
        linarith
    _ = 4 + 2 * |s.im| := by ring
    _ ≤ (2 + |s.im|) ^ 2 := four_add_two_abs_le_sq s.im

-- ════════════════════════════════════════════════════
-- §5. Main convexity bound
-- ════════════════════════════════════════════════════

/-- **Convexity bound**: ‖ζ(s)‖ ≤ (2 + |s.im|)² for 1/2 < Re(s) ≤ 2, |Im(s)| ≥ 1/2.

    Uses `bd_mellin_base_case_proved` from IdentityBypass.lean (zero sorry)
    to decompose ζ(s) = s/(s-1) - s·∫₀¹ {1/t}·t^{s-1} dt.
    The formula is valid for ALL Re(s) > 0 (not just Re(s) > 1).

    Downstream dependency chain:
    zeta_norm_convexity_bound → zeta_norm_bound_on_disk → BC theorem →
    zeta_polynomial_lower_bound_rh → Perron formula → MainChain. -/
theorem zeta_norm_convexity_bound {s : ℂ}
    (hrs : 1/2 < s.re) (hrs2 : s.re ≤ 2) (him : 1/2 ≤ |s.im|) :
    ‖riemannZeta s‖ ≤ (2 + |s.im|) ^ (2 : ℝ) := by
  calc ‖riemannZeta s‖
      ≤ (2 + |s.im|) ^ 2 := norm_zeta_le hrs hrs2 him
    _ = (2 + |s.im|) ^ (2 : ℝ) := by
        rw [show (2 : ℝ) = ((2 : ℕ) : ℝ) from by norm_num, rpow_natCast]

end Cathedral.White.Infrastructure.ZetaConvexityBound
