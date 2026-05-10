/-
  Cathedral/MellinBridge/IdentityBypass.lean

  ## The Identity Theorem Bypass

  Proves `bd_mellin_base_case`: for Re(s) > 0, s ≠ 1,
    ∫₀¹ {1/x} · x^{s-1} dx = 1/(s-1) - ζ(s)/s

  Strategy: Both sides are analytic on {Re(s) > 0} \ {1}.
  They agree for Re(s) > 1 (FloorDivMellin.lean).
  The Identity Theorem propagates equality to all of {Re(s) > 0} \ {1}.

  Status: PROVED.
-/
import Cathedral.MellinBridge.FloorMellin
import Cathedral.MellinBridge.FloorDivMellin
import Cathedral.MellinBridge.DomainConnected
import Mathlib.Analysis.Analytic.IsolatedZeros
import Mathlib.Analysis.MellinTransform
import Mathlib.NumberTheory.LSeries.RiemannZeta

noncomputable section
open Complex Real MeasureTheory Set Filter Asymptotics TopologicalSpace

-- ════════════════════════════════════════════════════
-- Section 1: The LHS function and its properties
-- ════════════════════════════════════════════════════

/-- The function {1/x} · 1_{(0,1]}(x), extended by zero to all of ℝ.
    This is the integrand's "coefficient" for the Mellin transform. -/
private def fractInvIoc (x : ℝ) : ℂ :=
  indicator (Ioc 0 1) (fun t => ((Int.fract (1 / t) : ℝ) : ℂ)) x

/-- fractInvIoc is bounded by 1 everywhere. -/
private lemma fractInvIoc_norm_le (x : ℝ) : ‖fractInvIoc x‖ ≤ 1 := by
  unfold fractInvIoc
  by_cases hx : x ∈ Ioc 0 1
  · simp [indicator_of_mem hx, Complex.norm_real]
    exact (abs_of_nonneg (Int.fract_nonneg _)).le.trans (Int.fract_lt_one _).le
  · simp [indicator_of_notMem hx]

/-- fractInvIoc vanishes on (1, ∞). -/
private lemma fractInvIoc_eq_zero_of_gt_one {x : ℝ} (hx : 1 < x) : fractInvIoc x = 0 := by
  unfold fractInvIoc
  exact indicator_of_notMem (fun h => not_le.mpr hx h.2) _

/-- fractInvIoc is O(x^(-0)) = O(1) near 0. -/
private lemma fractInvIoc_isBigO_zero :
    fractInvIoc =O[nhdsWithin 0 (Ioi 0)] (fun x : ℝ => x ^ (-(0 : ℝ))) := by
  simp only [neg_zero, rpow_zero]
  exact isBigO_of_le _ (fun x => by simp [fractInvIoc_norm_le x])

/-- fractInvIoc is O(x^(-a)) at ∞ for any a (it vanishes for x > 1). -/
private lemma fractInvIoc_isBigO_top (a : ℝ) :
    fractInvIoc =O[atTop] (fun x : ℝ => x ^ (-a)) := by
  apply IsBigO.of_bound 1
  filter_upwards [eventually_ge_atTop (2 : ℝ)] with x hx
  rw [one_mul, fractInvIoc_eq_zero_of_gt_one (by linarith), norm_zero]
  exact norm_nonneg _

/-- fractInvIoc is measurable. -/
private lemma fractInvIoc_aestronglyMeasurable :
    AEStronglyMeasurable fractInvIoc (volume : Measure ℝ) := by
  unfold fractInvIoc
  exact (Measurable.indicator
    (Complex.continuous_ofReal.measurable.comp
      ((measurable_const.div measurable_id).fract))
    measurableSet_Ioc).aestronglyMeasurable

/-- fractInvIoc is globally integrable (bounded on finite-measure support). -/
private lemma fractInvIoc_integrable : Integrable fractInvIoc (volume : Measure ℝ) := by
  apply IntegrableOn.integrable_of_forall_notMem_eq_zero (s := Ioc (0:ℝ) 1)
  · apply Measure.integrableOn_of_bounded (show volume (Ioc (0:ℝ) 1) ≠ ⊤ from measure_Ioc_lt_top.ne)
    · exact fractInvIoc_aestronglyMeasurable
    · filter_upwards with x
      unfold fractInvIoc
      by_cases hx : x ∈ Ioc (0:ℝ) 1
      · simp [indicator_of_mem hx, Complex.norm_real]
        exact (abs_of_nonneg (Int.fract_nonneg _)).le.trans (Int.fract_lt_one _).le
      · simp [indicator_of_notMem hx]
  · intro x hx; unfold fractInvIoc; exact indicator_of_notMem hx _

/-- fractInvIoc is locally integrable on (0, ∞). -/
private lemma fractInvIoc_locallyIntegrableOn :
    LocallyIntegrableOn fractInvIoc (Ioi 0) :=
  fractInvIoc_integrable.locallyIntegrable.locallyIntegrableOn (Ioi 0)

/-- The LHS integral over Ioo equals the integral over Ioc (measure-zero difference). -/
private lemma integral_Ioo_eq_Ioc (s : ℂ) :
    ∫ x in Ioo (0:ℝ) 1, ((Int.fract (1 / x) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1)  =
    ∫ x in Ioc (0:ℝ) 1, ((Int.fract (1 / x) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1)  :=
  (integral_Ioc_eq_integral_Ioo).symm

/-- The LHS integral equals the Mellin transform of fractInvIoc. -/
private lemma lhs_eq_mellin (s : ℂ) :
    ∫ x in Ioo (0:ℝ) 1, ((Int.fract (1 / x) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1) =
    mellin fractInvIoc s := by
  rw [integral_Ioo_eq_Ioc]
  have h_comm : ∀ x : ℝ, ((Int.fract (1 / x) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1) =
      (x : ℂ) ^ (s - 1) * ((Int.fract (1 / x) : ℝ) : ℂ) := fun x => mul_comm _ _
  simp_rw [h_comm]
  unfold mellin
  simp only [smul_eq_mul]
  let g : ℝ → ℂ := fun t => (t : ℂ) ^ (s - 1) * ((Int.fract (1 / t) : ℝ) : ℂ)
  show ∫ x in Ioc (0:ℝ) 1, g x = ∫ x in Ioi (0:ℝ), (x:ℂ)^(s-1) * fractInvIoc x
  have h_key : (fun x : ℝ => (x:ℂ)^(s-1) * fractInvIoc x) = indicator (Ioc (0:ℝ) 1) g := by
    ext x; unfold fractInvIoc g
    by_cases hx : x ∈ Ioc (0:ℝ) 1
    · simp [indicator_of_mem hx]
    · simp [indicator_of_notMem hx, mul_zero]
  rw [h_key, setIntegral_indicator measurableSet_Ioc]
  show ∫ x in Ioc (0:ℝ) 1, g x = ∫ x in Ioi (0:ℝ) ∩ Ioc (0:ℝ) 1, g x
  rw [inter_eq_right.mpr Ioc_subset_Ioi_self]

/-- The LHS is differentiable at every s with Re(s) > 0. -/
private lemma lhs_differentiableAt {s : ℂ} (hs : 0 < s.re) :
    DifferentiableAt ℂ (mellin fractInvIoc) s :=
  mellin_differentiableAt_of_isBigO_rpow fractInvIoc_locallyIntegrableOn
    (fractInvIoc_isBigO_top (s.re + 1)) (by linarith)
    fractInvIoc_isBigO_zero (by linarith : (0 : ℝ) < s.re)

/-- The domain {Re > 0} \ {1} is open. -/
private lemma domain_isOpen :
    IsOpen {s : ℂ | 0 < s.re ∧ s ≠ 1} :=
  (isOpen_lt continuous_const Complex.continuous_re).inter isOpen_ne

/-- The LHS is analytic on {Re(s) > 0} \ {1}. -/
private lemma lhs_analyticOnNhd :
    AnalyticOnNhd ℂ (mellin fractInvIoc) {s : ℂ | 0 < s.re ∧ s ≠ 1} :=
  (DifferentiableOn.analyticOnNhd
    (fun _s hs => (lhs_differentiableAt hs.1).differentiableWithinAt) domain_isOpen)

-- ════════════════════════════════════════════════════
-- Section 2: The RHS analyticity
-- ════════════════════════════════════════════════════

/-- The RHS function: s ↦ 1/(s-1) - ζ(s)/s. -/
private def rhs (s : ℂ) : ℂ := 1 / (s - 1) - riemannZeta s / s

/-- The RHS is differentiable on {Re(s) > 0} \ {1}. -/
private lemma rhs_differentiableOn :
    DifferentiableOn ℂ rhs {s : ℂ | 0 < s.re ∧ s ≠ 1} := by
  intro s ⟨hs_pos, hs_ne⟩
  have hs_ne_zero : s ≠ 0 := by intro h; rw [h, zero_re] at hs_pos; linarith
  have h_sub_ne : s - 1 ≠ 0 := sub_ne_zero.mpr hs_ne
  unfold rhs
  apply DifferentiableAt.differentiableWithinAt
  apply DifferentiableAt.sub
  · exact (differentiableAt_const (1 : ℂ)).div
      (differentiableAt_id.sub (differentiableAt_const (1 : ℂ))) h_sub_ne
  · exact (differentiableAt_riemannZeta hs_ne).div differentiableAt_id hs_ne_zero

/-- The RHS is analytic on {Re(s) > 0} \ {1}. -/
private lemma rhs_analyticOnNhd :
    AnalyticOnNhd ℂ rhs {s : ℂ | 0 < s.re ∧ s ≠ 1} :=
  rhs_differentiableOn.analyticOnNhd domain_isOpen

-- ════════════════════════════════════════════════════
-- Section 3: Agreement for Re(s) > 1
-- ════════════════════════════════════════════════════

/-- For Re(s) > 1, the fract integral equals 1/(s-1) - ζ(s)/s.
    Uses FloorDivMellin.lean: mellin_fractBasis with k=1. -/
private lemma lhs_eq_rhs_of_re_gt_one {s : ℂ} (hs : 1 < s.re) :
    mellin fractInvIoc s = rhs s := by
  -- Step 1: Unfold mellin fractInvIoc to ∫ Ioc, matching mellinRestricted
  rw [← lhs_eq_mellin s, integral_Ioo_eq_Ioc]
  -- Step 2: Commute factors to match mellinRestricted form
  simp_rw [show ∀ x : ℝ, ((Int.fract (1 / x) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1) =
      (x : ℂ) ^ (s - 1) * ((Int.fract (1 / x) : ℝ) : ℂ) from fun x => mul_comm _ _]
  -- Step 3: This IS mellinRestricted (fractBasisC 1) s
  have h_mellin := mellin_fractBasis 1 (by omega) s hs
  unfold mellinRestricted fractBasisC at h_mellin
  -- Step 4: Cast alignment: Nat.cast 1 / x = 1 / x
  have h_cast : ∀ x : ℝ, Int.fract ((1 : ℕ) / x) = Int.fract (1 / x) := by
    intro x; norm_num
  simp_rw [h_cast] at h_mellin
  rw [h_mellin]
  -- Step 5: Algebraic simplification
  unfold rhs
  have hs_ne : s ≠ 0 := by intro h; rw [h, zero_re] at hs; linarith
  have hs1_ne : s - 1 ≠ 0 := by intro h; have := congr_arg re h; simp [sub_re, one_re] at this; linarith
  have h_sum : (Finset.range 1).sum (fun m => ((↑(m + 1 : ℕ) : ℂ) ^ (-s))) = 1 := by
    simp [one_cpow]
  rw [h_sum]; simp only [Nat.cast_one, one_cpow]
  field_simp; ring

-- ════════════════════════════════════════════════════
-- Section 4: The Identity Theorem
-- ════════════════════════════════════════════════════

/-- {Re(s) > 0} \ {1} is preconnected.
    Proved in DomainConnected.lean via explicit path construction. -/
private lemma domain_isPreconnected :
    IsPreconnected {s : ℂ | 0 < s.re ∧ s ≠ 1} :=
  domain_preconnected

/-- 2 belongs to the domain. -/
private lemma two_mem_domain : (2 : ℂ) ∈ {s : ℂ | 0 < s.re ∧ s ≠ 1} := by
  refine ⟨?_, ?_⟩
  · show 0 < (2 : ℂ).re; norm_num
  · intro h; have := congr_arg Complex.re h; norm_num at this

/-- The main technical lemma: LHS agrees with RHS on all of {Re > 0} \ {1}. -/
private lemma mellin_fractInvIoc_eq_rhs :
    EqOn (mellin fractInvIoc) rhs {s : ℂ | 0 < s.re ∧ s ≠ 1} := by
  apply AnalyticOnNhd.eqOn_of_preconnected_of_eventuallyEq
    lhs_analyticOnNhd rhs_analyticOnNhd domain_isPreconnected two_mem_domain
  apply Filter.eventually_of_mem
    (isOpen_lt continuous_const Complex.continuous_re |>.mem_nhds
      (show (1 : ℝ) < (2 : ℂ).re from by norm_num))
  exact fun s hs => lhs_eq_rhs_of_re_gt_one hs

-- ════════════════════════════════════════════════════
-- Section 5: The theorem that replaces the axiom
-- ════════════════════════════════════════════════════

/-- **THEOREM** (replaces axiom bd_mellin_base_case):
    ∫₀¹ {1/x} · x^{s-1} dx = 1/(s-1) - ζ(s)/s for Re(s) > 0, s ≠ 1. -/
theorem bd_mellin_base_case_proved (s : ℂ) (hs : 0 < s.re) (hs1 : s ≠ 1) :
    ∫ x in Ioo (0:ℝ) 1, ((Int.fract (1 / x) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1) =
    1 / (s - 1) - riemannZeta s / s := by
  rw [lhs_eq_mellin]
  exact mellin_fractInvIoc_eq_rhs ⟨hs, hs1⟩
