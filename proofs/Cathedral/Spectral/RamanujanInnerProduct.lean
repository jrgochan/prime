/-
  Cathedral/Spectral/RamanujanInnerProduct.lean

  ## The Ramanujan B₁ Inner Product Formula

  **Main theorem** (`sawtooth_inner_product`):

    ∫₀¹ B₁({jt}) · B₁({kt}) dt = gcd(j,k)² / (12·j·k)

  where B₁(x) = {x} - 1/2 is the centered first Bernoulli function.

  ## Strategy

  We prove this via reduction to the coprime case:

  1. **GCD reduction**: Substitute u = d·t where d = gcd(j,k),
     showing the integral equals ∫₀¹ B₁({j't})·B₁({k't}) dt
     with j' = j/d, k' = k/d coprime.

  2. **Coprime formula**: For coprime j', k', prove
     ∫₀¹ B₁({j't})·B₁({k't}) dt = 1/(12·j'·k')
     by piecewise integration over the j'·k' sub-intervals
     of [0,1] where both sawtooths are linear.

  3. **Combine**: 1/(12·j'·k') = d²/(12·j·k).

  ## Dependencies
  - `Cathedral.Spectral.FourierGram` (sawtoothReal, sawtooth_l2_norm_sq)

  Created: May 16, 2026
  Status: Strategy C Phase 1 completion
-/

import Cathedral.Spectral.FourierGram

set_option maxHeartbeats 800000

open Real MeasureTheory Finset
open scoped BigOperators

noncomputable section

namespace Cathedral.RamanujanInnerProduct

open Cathedral.FourierGram

-- ════════════════════════════════════════════════
-- §1. THE BILINEAR SAWTOOTH INTEGRAL
-- ════════════════════════════════════════════════

/-- The bilinear sawtooth integral: ∫₀¹ B₁({jt})·B₁({kt}) dt.
    This is the pure covariance term from the B₁ decomposition. -/
def sawtoothInnerProduct (j k : ℕ) : ℝ :=
  ∫ t in (0:ℝ)..1, sawtoothReal (j * t) * sawtoothReal (k * t)

-- ════════════════════════════════════════════════
-- §2. DIAGONAL CASE: j = k
-- ════════════════════════════════════════════════

/-- **Integrability**: The sawtooth product is integrable on [0,1]. -/
theorem sawtoothProduct_integrable (j k : ℕ) :
    IntervalIntegrable
      (fun t => sawtoothReal (j * t) * sawtoothReal (k * t))
      volume (0:ℝ) 1 := by
  apply (IntegrableOn.of_bound (by simp)
    ((sawtoothReal_measurable.comp (measurable_const.mul measurable_id)).mul
     (sawtoothReal_measurable.comp (measurable_const.mul measurable_id))).aestronglyMeasurable.restrict
    1 (ae_of_all _ (fun t => by
      rw [Real.norm_eq_abs, abs_mul]
      calc |sawtoothReal _| * |sawtoothReal _|
          ≤ (1/2) * (1/2) := mul_le_mul (sawtoothReal_bound _)
            (sawtoothReal_bound _) (abs_nonneg _) (by norm_num)
        _ ≤ 1 := by norm_num))).intervalIntegrable

/-- **Diagonal case**: ∫₀¹ B₁({jt})² dt = 1/12 for any j ≥ 1.

    This follows from the periodicity of B₁: the function
    t ↦ B₁({jt})² has j identical periods on [0,1]. -/
theorem sawtooth_inner_product_diag (j : ℕ) (hj : 0 < j) :
    sawtoothInnerProduct j j = 1 / 12 := by
  unfold sawtoothInnerProduct
  have hj_ne : (j : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  -- Rewrite f*f as f² with explicit function form for substitution
  conv_lhs => arg 1; ext t; rw [(sq (sawtoothReal (↑j * t))).symm]
  -- Substitution u = j*t: ∫₀¹ f(jt)² dt = j⁻¹ • ∫₀ʲ f(u)² du
  rw [intervalIntegral.integral_comp_mul_left (fun u => sawtoothReal u ^ 2) hj_ne,
      mul_zero, mul_one]
  -- Periodicity of B₁²
  have hper : Function.Periodic (fun u => sawtoothReal u ^ 2) 1 := fun u => by
    show sawtoothReal (u + 1) ^ 2 = sawtoothReal u ^ 2
    rw [sawtoothReal_add_one]
  -- Integrability on [0,1] from boundedness (|B₁²| ≤ 1/4)
  have hint : IntervalIntegrable (fun u => sawtoothReal u ^ 2) volume 0 1 := by
    rw [show (fun u => sawtoothReal u ^ 2) = fun u => sawtoothReal u * sawtoothReal u
        from funext (fun u => sq _)]
    exact (IntegrableOn.of_bound (by simp)
      (sawtoothReal_measurable.mul sawtoothReal_measurable).aestronglyMeasurable.restrict
      (1/4) (ae_of_all _ (fun u => by
        rw [Real.norm_eq_abs, abs_mul]
        calc |sawtoothReal u| * |sawtoothReal u|
            ≤ (1/2) * (1/2) := mul_le_mul (sawtoothReal_bound _)
              (sawtoothReal_bound _) (abs_nonneg _) (by norm_num)
          _ ≤ 1/4 := by norm_num))).intervalIntegrable
  -- ∫₀ʲ B₁(u)² du = j • ∫₀¹ B₁(u)² du (periodicity over j periods)
  have hint_all : ∀ t₁ t₂, IntervalIntegrable (fun u => sawtoothReal u ^ 2) volume t₁ t₂ :=
    hper.intervalIntegrable₀ one_ne_zero hint
  rw [show (↑j : ℝ) = 0 + (↑j : ℤ) • (1 : ℝ) from by simp]
  rw [hper.intervalIntegral_add_zsmul_eq _ 0 hint_all]
  -- Evaluate: j⁻¹ • (j • ∫₀^{0+1} B₁² du) = 1/12
  simp only [zero_add, sawtooth_l2_norm_sq, smul_eq_mul, zsmul_eq_mul, Int.cast_natCast]
  field_simp

-- ════════════════════════════════════════════════
-- ════════════════════════════════════════════════
-- §3. MEAN-ZERO PROPERTY
-- ════════════════════════════════════════════════

/-- **Base case**: ∫₀¹ B₁(u) du = 0 (the sawtooth has mean zero). -/
private theorem sawtooth_mean_zero_base :
    ∫ u in (0:ℝ)..1, sawtoothReal u = 0 := by
  -- On (0,1), sawtoothReal u = u - 1/2. They may differ at u=1 but that's measure 0.
  rw [intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  have h_congr : (fun u => sawtoothReal u) =ᵐ[volume.restrict (Set.Ioc (0:ℝ) 1)]
      (fun u => u - 1/2) := by
    rw [Measure.restrict_congr_set Ioo_ae_eq_Ioc.symm]
    exact (ae_restrict_mem measurableSet_Ioo).mono fun u ⟨hu0, hu1⟩ => by
      simp [sawtoothReal, Int.fract_eq_self.mpr ⟨le_of_lt hu0, hu1⟩]
  rw [MeasureTheory.integral_congr_ae h_congr,
      ← intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  -- FTC: ∫₀¹ (u - 1/2) du = [u²/2 - u/2]₀¹ = 0
  have hF : ∀ u ∈ Set.uIcc (0:ℝ) 1,
      HasDerivAt (fun u => u ^ 2 / 2 - u / 2) (u - 1/2) u := by
    intro u _
    convert (hasDerivAt_pow 2 u).div_const 2 |>.sub ((hasDerivAt_id u).div_const 2) using 1; ring
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hF
    ((continuous_id.sub continuous_const).intervalIntegrable 0 1)]
  norm_num

/-- **Scaled mean zero**: ∫₀¹ B₁(m·t) dt = 0 for m ≥ 1.
    By substitution u = m·t + periodicity + base mean zero. -/
theorem sawtooth_mean_zero (m : ℕ) (hm : 0 < m) :
    ∫ t in (0:ℝ)..1, sawtoothReal (↑m * t) = 0 := by
  have hm_ne : (m : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  -- Substitution u = m*t: ∫₀¹ B₁(mt) dt = m⁻¹ • ∫₀ᵐ B₁(u) du
  rw [intervalIntegral.integral_comp_mul_left sawtoothReal hm_ne, mul_zero, mul_one]
  -- Periodicity: ∫₀ᵐ B₁(u) du = m • ∫₀¹ B₁(u) du
  have hper : Function.Periodic sawtoothReal 1 := fun u => sawtoothReal_add_one u
  have hint : IntervalIntegrable sawtoothReal volume 0 1 :=
    (IntegrableOn.of_bound (by simp)
      sawtoothReal_measurable.aestronglyMeasurable.restrict
      (1/2) (ae_of_all _ (fun u => sawtoothReal_bound u))).intervalIntegrable
  have hint_all : ∀ t₁ t₂, IntervalIntegrable sawtoothReal volume t₁ t₂ :=
    hper.intervalIntegrable₀ one_ne_zero hint
  rw [show (↑m : ℝ) = 0 + (↑m : ℤ) • (1 : ℝ) from by simp]
  rw [hper.intervalIntegral_add_zsmul_eq _ 0 hint_all]
  -- m⁻¹ • (m • 0) = 0
  simp only [zero_add, sawtooth_mean_zero_base, smul_zero]

-- Integrability helpers for the decomposition
private theorem sawtooth_scaled_integrable (m : ℕ) :
    IntervalIntegrable (fun t => sawtoothReal (↑m * t)) volume (0:ℝ) 1 :=
  (IntegrableOn.of_bound (by simp)
    (sawtoothReal_measurable.comp (measurable_const.mul measurable_id)).aestronglyMeasurable.restrict
    (1/2) (ae_of_all _ (fun t => sawtoothReal_bound _))).intervalIntegrable

-- ════════════════════════════════════════════════
-- §4. THE RAMANUJAN FORMULA (Main Theorem)
-- ════════════════════════════════════════════════

-- Coprime Ramanujan inner product: ∫₀¹ B₁(jt)·B₁(kt) dt = 1/(12jk) for coprime j,k.
-- Proof: Bernoulli distribution formula Σ B₁(x+r/j) = B₁(jx)
--   + CRT permutation + j=1 base case via ∫₀¹ t·B₁(kt) = 1/(12k).

/-- Helper: ∫₀¹ t·B₁(t) dt = 1/12 (k=1 base case).
    On (0,1), B₁(t) = t - 1/2, so t·B₁(t) = t²-t/2.
    FTC: ∫₀¹ (t²-t/2) = 1/3 - 1/4 = 1/12. -/
private theorem id_sawtooth_base :
    ∫ t in (0:ℝ)..1, t * sawtoothReal t = 1 / 12 := by
  rw [intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  have h_congr : (fun t => t * sawtoothReal t) =ᵐ[volume.restrict (Set.Ioc (0:ℝ) 1)]
      (fun t => t ^ 2 - t / 2) := by
    rw [Measure.restrict_congr_set Ioo_ae_eq_Ioc.symm]
    exact (ae_restrict_mem measurableSet_Ioo).mono fun t ⟨ht0, ht1⟩ => by
      simp [sawtoothReal, Int.fract_eq_self.mpr ⟨le_of_lt ht0, ht1⟩]; ring
  rw [MeasureTheory.integral_congr_ae h_congr,
      ← intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  -- FTC with antiderivative F(t) = t³/3 - t²/4
  have hF : ∀ t ∈ Set.uIcc (0:ℝ) 1,
      HasDerivAt (fun t => t ^ 3 / 3 - t ^ 2 / 4) (t ^ 2 - t / 2) t := by
    intro t _
    have h3 := (hasDerivAt_pow 3 t).div_const (3:ℝ)
    have h2 := (hasDerivAt_pow 2 t).div_const (4:ℝ)
    convert h3.sub h2 using 1; ring
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hF
    ((continuous_pow 2 |>.sub (continuous_id.div_const 2)).intervalIntegrable 0 1)]
  norm_num

/-- Helper: ∫₀¹ u·B₁(ku) du = 1/(12k).
    Substitute u = kt, then decompose u·B₁(u) = B₁²(u) + B₁(u)/2 + ⌊u⌋·B₁(u).
    B₁² and B₁/2 are periodic (integrals: k·1/12 and k·0).
    ⌊u⌋·B₁(u) vanishes by mean-zero on each period.
    Result: (1/k²)·(k/12) = 1/(12k). -/
private theorem id_sawtooth_integral (k : ℕ) (hk : 0 < k) :
    ∫ t in (0:ℝ)..1, t * sawtoothReal (↑k * t) = 1 / (12 * (k : ℝ)) := by
  by_cases hk1 : k = 1
  · subst hk1; simp only [Nat.cast_one, one_mul, mul_one]; exact id_sawtooth_base
  -- General k ≥ 2: rewrite t·B₁(kt) = (1/k)·(kt)·B₁(kt) = (1/k)·h(kt)
  have hk_ne : (k : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hk_pos : (0 : ℝ) < k := Nat.cast_pos.mpr hk
  -- t * B₁(kt) = (1/k) * (kt * B₁(kt))
  have h_rw : ∀ t : ℝ, t * sawtoothReal (↑k * t) =
      (1 / ↑k) * ((fun u => u * sawtoothReal u) (↑k * t)) := fun t => by
    simp only; rw [show ↑k * t * sawtoothReal (↑k * t) = ↑k * (t * sawtoothReal (↑k * t))
      from by ring]; field_simp
  simp_rw [h_rw]
  rw [intervalIntegral.integral_const_mul]
  -- Substitution u = kt
  have hsub := intervalIntegral.integral_comp_mul_left
    (fun u => u * sawtoothReal u) hk_ne (a := 0) (b := 1)
  simp only [mul_zero, mul_one] at hsub
  rw [hsub]
  -- Key: show ∫₀ᵏ u·B₁(u) = k · (1/12) = k/12
  -- Each shifted period ∫_m^{m+1} u·B₁(u) du = 1/12
  have hper : Function.Periodic sawtoothReal 1 := sawtoothReal_add_one
  -- ∫_m^{m+1} u·B₁(u) du = 1/12 for any m : ℤ
  have hpiece : ∀ m : ℤ, ∫ u in (m:ℝ)..(↑m + 1),
      u * sawtoothReal u = 1 / 12 := by
    intro m
    -- Substitution v = u - m: ∫_m^{m+1} (u·B₁(u)) du = ∫₀¹ (v+m)·B₁(v+m) dv
    have hsub := intervalIntegral.integral_comp_add_right
      (fun u => u * sawtoothReal u) (↑m) (a := (0:ℝ)) (b := 1)
    simp only [zero_add] at hsub
    rw [show (1 : ℝ) + ↑m = ↑m + 1 from by ring] at hsub
    rw [← hsub]
    -- B₁(v+m) = B₁(v) by periodicity (period 1, integer shift m)
    have hshift : ∀ v : ℝ, sawtoothReal (v + ↑m) = sawtoothReal v := fun v => by
      have h := (hper.zsmul m) v; simp [zsmul_eq_mul, mul_one] at h; exact h
    simp_rw [hshift]
    -- ∫₀¹ (v+m)·B₁(v) dv = ∫₀¹ v·B₁(v) dv + m·∫₀¹ B₁(v) dv
    simp_rw [show ∀ v : ℝ, (v + ↑m) * sawtoothReal v = v * sawtoothReal v + ↑m * sawtoothReal v
      from fun v => by ring]
    -- Integrability of each summand
    have h_B_ii : IntervalIntegrable sawtoothReal volume (0:ℝ) 1 :=
      (IntegrableOn.of_bound (by simp) sawtoothReal_measurable.aestronglyMeasurable.restrict
        (1/2) (ae_of_all _ (fun v => sawtoothReal_bound v))).intervalIntegrable
    have h_ii1 : IntervalIntegrable (fun v => v * sawtoothReal v) volume (0:ℝ) 1 := by
      refine ⟨?_, ?_⟩ <;>
        exact IntegrableOn.of_bound measure_Ioc_lt_top
          (measurable_id.mul sawtoothReal_measurable).aestronglyMeasurable.restrict
          (1/2) ((ae_restrict_mem measurableSet_Ioc).mono fun v hv => by
            rw [Real.norm_eq_abs, abs_mul]
            calc |v| * |sawtoothReal v|
                ≤ 1 * (1/2) := mul_le_mul
                  (by rw [abs_le]; constructor <;> linarith [hv.1, hv.2])
                  (sawtoothReal_bound v) (abs_nonneg _) (by norm_num)
              _ = 1/2 := by ring)
    have h_ii2 : IntervalIntegrable (fun v => ↑m * sawtoothReal v) volume (0:ℝ) 1 :=
      h_B_ii.const_mul ↑m
    rw [intervalIntegral.integral_add h_ii1 h_ii2]
    rw [intervalIntegral.integral_const_mul, sawtooth_mean_zero_base, mul_zero, add_zero]
    exact id_sawtooth_base
  -- Now assemble: (1/k) * (k⁻¹ * ∫₀ᵏ u·B₁(u)) = 1/(12k)
  -- First show ∫₀ⁿ u·B₁(u) = n/12 by induction
  have hint : ∀ n : ℕ, ∫ u in (0:ℝ)..(↑n), u * sawtoothReal u = ↑n / 12 := by
    intro n; induction n with
    | zero => simp [intervalIntegral.integral_same]
    | succ m ih =>
      rw [show (↑(m + 1) : ℝ) = ↑m + 1 from by push_cast; ring]
      -- Integrability on any bounded interval
      have h_ii : ∀ a b : ℝ, IntervalIntegrable (fun u => u * sawtoothReal u) volume a b := by
        intro a b; constructor <;> {
          apply IntegrableOn.of_bound measure_Ioc_lt_top
            (measurable_id.mul sawtoothReal_measurable).aestronglyMeasurable.restrict
            (|a| + |b| + 1)
          exact (ae_restrict_mem measurableSet_Ioc).mono fun v hv => by
            rw [Real.norm_eq_abs, abs_mul]
            have hb := sawtoothReal_bound v
            have habs := abs_nonneg v
            have habs_a := abs_nonneg a
            have habs_b := abs_nonneg b
            have h1 := hv.1  -- min a b < v
            have h2 := hv.2  -- v ≤ max a b
            have : |v| ≤ |a| + |b| := by
              rw [abs_le]; constructor
              · -- -v ≤ |a| + |b|: since v > min a b ≥ -(|a|+|b|)
                have := neg_abs_le a; have := neg_abs_le b
                nlinarith [min_le_left a b, min_le_right a b]
              · -- v ≤ |a| + |b|: since v ≤ max a b ≤ |a| + |b|
                nlinarith [le_abs_self a, le_abs_self b,
                           le_max_left a b, le_max_right a b]
            calc |v| * |sawtoothReal v|
                ≤ |v| * (1/2) := mul_le_mul_of_nonneg_left hb habs
              _ ≤ (|a| + |b|) * (1/2) := by nlinarith
              _ ≤ |a| + |b| + 1 := by nlinarith }
      rw [← intervalIntegral.integral_add_adjacent_intervals (h_ii 0 ↑m) (h_ii ↑m (↑m + 1))]
      rw [ih]
      have := hpiece (m : ℤ)
      simp only [Int.cast_natCast] at this
      rw [this]; ring
  simp only [smul_eq_mul] at *
  rw [hint k]; field_simp

/-- Base case j=1: ∫₀¹ B₁(t)·B₁(kt) dt = 1/(12k).
    Since B₁(t) = t - 1/2 a.e. on [0,1], this equals
    ∫₀¹ t·B₁(kt) - (1/2)·∫₀¹ B₁(kt) = 1/(12k) - 0. -/
private theorem sawtooth_base_inner_product (k : ℕ) (hk : 0 < k) :
    ∫ t in (0:ℝ)..1, sawtoothReal (1 * t) * sawtoothReal (↑k * t) =
    1 / (12 * (k : ℝ)) := by
  -- On (0,1), sawtoothReal(1·t) = t - 1/2, so B₁(t)·B₁(kt) = (t-1/2)·B₁(kt)
  simp only [one_mul]
  -- ae-congr: replace sawtoothReal t with (t - 1/2) on (0,1)
  have h_ae : (fun t => sawtoothReal t * sawtoothReal (↑k * t)) =ᵐ[volume.restrict (Set.uIoc (0:ℝ) 1)]
      (fun t => (t - 1/2) * sawtoothReal (↑k * t)) := by
    rw [show Set.uIoc (0:ℝ) 1 = Set.Ioc 0 1 from by
      simp [Set.uIoc]]
    rw [Measure.restrict_congr_set Ioo_ae_eq_Ioc.symm]
    exact (ae_restrict_mem measurableSet_Ioo).mono fun t ⟨ht0, ht1⟩ => by
      simp [sawtoothReal, Int.fract_eq_self.mpr ⟨le_of_lt ht0, ht1⟩]
  rw [intervalIntegral.integral_congr_ae_restrict h_ae]
  -- (t - 1/2) * B₁(kt) = t * B₁(kt) - (1/2) * B₁(kt)
  simp_rw [show ∀ t : ℝ, (t - 1/2) * sawtoothReal (↑k * t) =
    t * sawtoothReal (↑k * t) - (1/2) * sawtoothReal (↑k * t) from fun t => by ring]
  -- Split integral
  have h_ii1 : IntervalIntegrable (fun t => t * sawtoothReal (↑k * t)) volume (0:ℝ) 1 := by
    -- t * B₁(kt) = (B₁(t) + 1/2) * B₁(kt) = B₁(t)*B₁(kt) + (1/2)*B₁(kt) ae on (0,1)
    have h1 := sawtoothProduct_integrable 1 k  -- B₁(1·t) * B₁(kt) integrable
    have h2 := (sawtooth_scaled_integrable k).const_mul (1/2 : ℝ)  -- (1/2)*B₁(kt) integrable
    -- Rewrite: t*B₁(kt) =ae B₁(t)*B₁(kt) + (1/2)*B₁(kt)
    apply (h1.add h2).congr_ae
    rw [show Set.uIoc (0:ℝ) 1 = Set.Ioc 0 1 from by
      simp [Set.uIoc]]
    rw [Measure.restrict_congr_set Ioo_ae_eq_Ioc.symm]
    exact (ae_restrict_mem measurableSet_Ioo).mono fun t ⟨ht0, ht1⟩ => by
      simp only [Nat.cast_one, one_mul]
      simp [sawtoothReal, Int.fract_eq_self.mpr ⟨le_of_lt ht0, ht1⟩]; ring
  have h_ii2 : IntervalIntegrable (fun t => (1/2) * sawtoothReal (↑k * t)) volume (0:ℝ) 1 :=
    (sawtooth_scaled_integrable k).const_mul (1/2)
  rw [intervalIntegral.integral_sub h_ii1 h_ii2]
  rw [intervalIntegral.integral_const_mul, sawtooth_mean_zero k hk, mul_zero, sub_zero]
  exact id_sawtooth_integral k hk

/-- Bernoulli distribution formula: Σ_{r=0}^{n-1} B₁(x + r/n) = B₁(nx).
    This is the multiplicative formula for Bernoulli polynomials at degree 1. -/
private theorem bernoulli_distribution (n : ℕ) (hn : 0 < n) (x : ℝ) :
    ∑ r ∈ Finset.range n, sawtoothReal (x + ↑r / ↑n) = sawtoothReal (↑n * x) := by
  simp only [sawtoothReal]
  have hn_pos : (0 : ℝ) < ↑n := Nat.cast_pos.mpr hn
  have hn_ne : (n : ℝ) ≠ 0 := ne_of_gt hn_pos
  rw [Finset.sum_sub_distrib, Finset.sum_const, Finset.card_range, nsmul_eq_mul]
  suffices h : ∑ r ∈ Finset.range n, Int.fract (x + ↑r / ↑n) =
      Int.fract (↑n * x) + (↑n - 1) / 2 by linarith
  have h_expand : ∀ r ∈ Finset.range n,
      Int.fract (x + ↑r / ↑n) = (x + ↑r / ↑n) - ↑⌊x + ↑r / ↑n⌋ :=
    fun r _ => (Int.self_sub_floor _).symm
  rw [Finset.sum_congr rfl h_expand]
  rw [Finset.sum_sub_distrib]
  have h_arith : ∑ r ∈ Finset.range n, (x + ↑r / (↑n : ℝ)) =
      ↑n * x + (↑n - 1) / 2 := by
    rw [Finset.sum_add_distrib, Finset.sum_const, Finset.card_range, nsmul_eq_mul]
    congr 1
    obtain ⟨m, rfl⟩ := Nat.exists_eq_succ_of_ne_zero (by omega : n ≠ 0)
    simp_rw [← Finset.sum_div]
    have h2 := Finset.sum_range_id_mul_two (m + 1)
    simp only [Nat.succ_sub_one] at h2
    have h2r : (∑ r ∈ Finset.range (m + 1), (↑r : ℝ)) * 2 = (↑m + 1) * ↑m := by
      have h : (↑((∑ r ∈ Finset.range (m + 1), r) * 2) : ℝ) = (↑((m + 1) * m) : ℝ) := by
        exact_mod_cast h2
      push_cast at h; linarith
    have hsucc : (↑(Nat.succ m) : ℝ) = ↑m + 1 := by push_cast; ring
    rw [hsucc]
    have hne : (↑m + 1 : ℝ) ≠ 0 := by positivity
    rw [div_eq_div_iff hne two_ne_zero]
    linarith
  -- Step 5: Hermite's identity: ∑⌊x+r/n⌋ = ⌊nx⌋
  have h_hermite : (∑ r ∈ Finset.range n, (⌊x + ↑r / (↑n : ℝ)⌋ : ℝ)) =
      ↑⌊↑n * x⌋ := by
    have floor_zero : ∀ {y : ℝ}, 0 ≤ y → y < 1 → ⌊y⌋ = 0 := by
      intro y hy0 hy1
      have : ⌊y⌋ < 1 := Int.floor_lt.mpr (by exact_mod_cast hy1)
      have : 0 ≤ ⌊y⌋ := Int.floor_nonneg.mpr hy0
      omega
    have sum_ediv : ∀ k : ℤ, ∑ r ∈ Finset.range n, ((k + ↑r) / (↑n : ℤ)) = k := by
      intro k
      have hn_ne : (↑n : ℤ) ≠ 0 := by omega
      suffices h : ↑n * (∑ r ∈ Finset.range n, ((k + ↑r) / ↑n)) = ↑n * k by
        exact mul_left_cancel₀ hn_ne h
      rw [Finset.mul_sum]
      have h_mul : ∀ r : ℕ, ↑n * ((k + ↑r) / (↑n : ℤ)) = (k + ↑r) - (k + ↑r) % ↑n := by
        intro r; have := Int.mul_ediv_add_emod (k + ↑r) ↑n; linarith
      simp_rw [h_mul, Finset.sum_sub_distrib]
      rw [show ∑ r ∈ Finset.range n, (k + (↑r : ℤ)) =
        ↑n * k + ∑ r ∈ Finset.range n, (↑r : ℤ) from by
          rw [Finset.sum_add_distrib, Finset.sum_const, Finset.card_range, nsmul_eq_mul]]
      suffices h_perm : ∑ r ∈ Finset.range n, ((k + ↑r) % (↑n : ℤ)) =
          ∑ r ∈ Finset.range n, (↑r : ℤ) by rw [h_perm]; ring
      conv_lhs =>
        arg 2; ext r
        rw [← Int.toNat_of_nonneg (Int.emod_nonneg (k + ↑r) hn_ne)]

      apply Finset.sum_nbij (fun (r : ℕ) => ((k + (↑r : ℤ)) % ↑n).toNat)
      · intro r hr
        simp only [Finset.mem_range] at hr ⊢
        have h1 := Int.emod_nonneg (k + ↑r) hn_ne
        have h2 := Int.emod_lt_of_pos (k + ↑r) (by omega : (0 : ℤ) < ↑n)
        omega
      · intro r₁ hr₁ r₂ hr₂ heq
        simp only [Finset.mem_coe, Finset.mem_range] at hr₁ hr₂
        have h₁ := Int.emod_nonneg (k + ↑r₁) hn_ne
        have h₂ := Int.emod_nonneg (k + ↑r₂) hn_ne
        have hmod : (k + ↑r₁) % ↑n = (k + ↑r₂) % ↑n := by
          have h := congr_arg (fun m : ℕ => (m : ℤ)) heq
          simp only [Int.toNat_of_nonneg h₁, Int.toNat_of_nonneg h₂] at h; exact h
        have h_dvd : (↑n : ℤ) ∣ (↑r₁ - ↑r₂) := by
          have hsub : ((k + ↑r₁) - (k + ↑r₂)) % ↑n = 0 := by
            rw [Int.sub_emod, hmod, sub_self]; simp
          rw [show (k + ↑r₁ : ℤ) - (k + ↑r₂) = ↑r₁ - ↑r₂ from by ring] at hsub
          exact (Int.dvd_iff_emod_eq_zero).mpr hsub
        have : (↑r₁ : ℤ) = ↑r₂ := by
          rcases h_dvd with ⟨c, hc⟩
          have hbound1 : -(↑n : ℤ) < ↑r₁ - ↑r₂ := by omega
          have hbound2 : (↑r₁ : ℤ) - ↑r₂ < ↑n := by omega
          rcases Int.lt_trichotomy c 0 with hc_neg | rfl | hc_pos
          · have : ↑n * c ≤ -(↑n : ℤ) := by nlinarith
            omega
          · omega
          · have : ↑n ≤ ↑n * c := le_mul_of_one_le_right (by omega) hc_pos
            omega
        exact_mod_cast this
      · intro b hb
        simp only [Finset.mem_coe, Finset.mem_range] at hb
        refine ⟨((↑b - k) % ↑n).toNat, ?_, ?_⟩
        · simp only [Finset.mem_coe, Finset.mem_range]
          have := Int.emod_nonneg (↑b - k) hn_ne
          have := Int.emod_lt_of_pos (↑b - k) (by omega : (0 : ℤ) < ↑n)
          omega
        · have h1 := Int.emod_nonneg (↑b - k) hn_ne
          have h2 := Int.emod_lt_of_pos (↑b - k) (by omega : (0 : ℤ) < ↑n)
          have hb_mod : (↑b : ℤ) % ↑n = ↑b := Int.emod_eq_of_lt (by omega) (by omega)
          have h4 : (↑((↑b - k) % (↑n : ℤ)).toNat : ℤ) = (↑b - k) % ↑n :=
            Int.toNat_of_nonneg h1
          have h5 : (k + (↑b - k) % ↑n) % (↑n : ℤ) = ↑b % ↑n := by
            have : (k + (↑b - k)) % (↑n : ℤ) = ↑b % ↑n := by ring_nf
            rw [← this, Int.add_emod, Int.emod_emod_of_dvd]
            · rw [← Int.add_emod]
            · exact dvd_refl _
          have h6 : ((k + ↑((↑b - k) % (↑n : ℤ)).toNat) % ↑n).toNat = b := by
            rw [h4, h5, hb_mod]; omega
          exact h6
      · intro r hr
        simp [Int.toNat_of_nonneg (Int.emod_nonneg (k + ↑r) hn_ne)]

    set κ := ⌊↑n * x⌋
    set η := Int.fract (↑n * x) / ↑n
    have hn_ne : (↑n : ℝ) ≠ 0 := ne_of_gt hn_pos
    have hη0 : 0 ≤ η := div_nonneg (Int.fract_nonneg _) (le_of_lt hn_pos)
    have hη1 : η < 1 / ↑n := by
      show Int.fract (↑n * x) / ↑n < 1 / ↑n
      exact div_lt_div_of_pos_right (Int.fract_lt_one _) hn_pos
    have hx_eq : x = ↑κ / ↑n + η := by
      show x = ↑⌊↑n * x⌋ / ↑n + Int.fract (↑n * x) / ↑n
      rw [← add_div, Int.floor_add_fract]; exact (mul_div_cancel_left₀ x hn_ne).symm
    have h_rw : ∀ r, x + ↑r / (↑n : ℝ) = η + ((↑κ : ℝ) + (↑r : ℝ)) / ↑n := by
      intro r; rw [hx_eq]; field_simp; ring
    simp_rw [h_rw]
    have h_floor : ∀ r ∈ Finset.range n,
        ⌊η + ((↑κ : ℝ) + (↑r : ℝ)) / (↑n : ℝ)⌋ = (κ + ↑r) / ↑n := by
      intro r hr
      rw [Finset.mem_range] at hr
      set q := (κ + ↑r) / (↑n : ℤ)
      set s := (κ + ↑r) % (↑n : ℤ)
      have hs0 : 0 ≤ s := Int.emod_nonneg _ (by omega)
      have hs1 : s < ↑n := Int.emod_lt_of_pos _ (by omega)
      have h_kr : (κ : ℤ) + ↑r = ↑n * q + s := by
        have := Int.mul_ediv_add_emod (κ + ↑r) ↑n; linarith
      have h_split : ((↑κ : ℝ) + (↑r : ℝ)) / (↑n : ℝ) = ↑q + ↑s / ↑n := by
        have : ((↑κ : ℝ) + (↑r : ℝ)) = ↑n * ↑q + ↑s := by
          have : (↑(κ + (↑r : ℤ)) : ℝ) = (↑(↑n * q + s) : ℝ) := by exact_mod_cast h_kr
          push_cast at this ⊢; linarith
        rw [this]; field_simp
      rw [h_split, show η + (↑q + ↑s / (↑n : ℝ)) = ↑q + (η + ↑s / ↑n) from by ring,
        Int.floor_intCast_add]
      suffices h : ⌊η + ↑s / (↑n : ℝ)⌋ = 0 by simp [h]
      have hs_r : (0 : ℝ) ≤ ↑s := by exact_mod_cast hs0
      have hs_bound : (↑s : ℝ) + 1 ≤ ↑n := by exact_mod_cast hs1
      apply floor_zero (by positivity)
      calc η + ↑s / ↑n < 1 / ↑n + ↑s / ↑n := by linarith
        _ = (↑s + 1) / ↑n := by rw [add_div]; ring
        _ ≤ ↑n / ↑n := by apply div_le_div_of_nonneg_right (by linarith) (le_of_lt hn_pos)
        _ = 1 := div_self (ne_of_gt hn_pos)
    have h_floor_cast : ∀ r ∈ Finset.range n,
        (⌊η + ((↑κ : ℝ) + (↑r : ℝ)) / (↑n : ℝ)⌋ : ℝ) = ↑((κ + ↑r) / (↑n : ℤ)) := by
      intro r hr; exact_mod_cast h_floor r hr
    rw [Finset.sum_congr rfl h_floor_cast]
    exact_mod_cast sum_ediv κ
  rw [h_arith, h_hermite, ← Int.self_sub_floor (↑n * x)]
  ring

theorem sawtooth_coprime_inner_product (j k : ℕ) (hj : 0 < j) (hk : 0 < k)
    (hcop : Nat.Coprime j k) :
    ∫ t in (0:ℝ)..1, sawtoothReal (↑j * t) * sawtoothReal (↑k * t) =
    1 / (12 * (j : ℝ) * (k : ℝ)) := by
  have hj_ne : (j : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hk_ne : (k : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hj_pos : (0 : ℝ) < ↑j := Nat.cast_pos.mpr hj
  have hk_pos : (0 : ℝ) < ↑k := Nat.cast_pos.mpr hk
  -- Step 1: Substitution u = jt
  -- ∫₀¹ B₁(jt)·B₁(kt) dt = j⁻¹ · ∫₀ʲ B₁(u)·B₁(ku/j) du
  -- Step 2: Split ∫₀ʲ = ∑_{m=0}^{j-1} ∫_m^{m+1}, shift v = u - m
  -- ∫_m^{m+1} B₁(u)·B₁(ku/j) du = ∫₀¹ B₁(v)·B₁(k(v+m)/j) dv
  -- (using B₁(v+m) = B₁(v) by integer periodicity)
  -- Step 3: CRT permutation (coprimality)
  -- Since gcd(j,k)=1, m ↦ km mod j is a bijection on {0,...,j-1}
  -- So ∑_m B₁(kv/j + km/j) = ∑_r B₁(kv/j + r/j)
  -- Step 4: Bernoulli distribution
  -- ∑_{r=0}^{j-1} B₁(kv/j + r/j) = B₁(j · kv/j) = B₁(kv)
  -- Therefore: ∫₀ʲ B₁(u)·B₁(ku/j) du = ∫₀¹ B₁(v)·B₁(kv) dv
  have h_fold : ∫ u in (0:ℝ)..(↑j),
      sawtoothReal u * sawtoothReal (↑k * u / ↑j) =
      ∫ v in (0:ℝ)..1, sawtoothReal v * sawtoothReal (↑k * v) := by
    -- Integrability of the product on any bounded interval
    have h_ii : ∀ a b : ℝ, IntervalIntegrable
        (fun u => sawtoothReal u * sawtoothReal (↑k * u / ↑j)) volume a b := by
      intro a b; constructor <;> {
        apply IntegrableOn.of_bound measure_Ioc_lt_top
          ((sawtoothReal_measurable.comp measurable_id).mul
           (sawtoothReal_measurable.comp ((measurable_const.mul measurable_id).div_const _))).aestronglyMeasurable.restrict
          (1/4)
        exact (ae_restrict_mem measurableSet_Ioc).mono fun v _ => by
          rw [Real.norm_eq_abs, abs_mul]
          calc |sawtoothReal v| * |sawtoothReal _|
              ≤ (1/2) * (1/2) := mul_le_mul (sawtoothReal_bound _)
                (sawtoothReal_bound _) (abs_nonneg _) (by norm_num)
            _ ≤ 1/4 := by norm_num }
    -- Split: ∫₀ʲ = ∑_{m=0}^{j-1} ∫_m^{m+1}
    have h_split : ∀ (n : ℕ),
        ∫ u in (0:ℝ)..(↑n), sawtoothReal u * sawtoothReal (↑k * u / ↑j) =
        ∑ m ∈ Finset.range n, ∫ u in (↑m:ℝ)..(↑m + 1),
          sawtoothReal u * sawtoothReal (↑k * u / ↑j) := by
      intro n; induction n with
      | zero => simp [intervalIntegral.integral_same]
      | succ n ih =>
        rw [Finset.sum_range_succ, show (↑(n + 1) : ℝ) = ↑n + 1 from by push_cast; ring]
        rw [← intervalIntegral.integral_add_adjacent_intervals
          (h_ii 0 ↑n) (h_ii ↑n (↑n + 1))]
        rw [ih]
    rw [h_split j]
    -- Shift each piece: v = u - m, using B₁(v+m) = B₁(v)
    have hper : Function.Periodic sawtoothReal 1 := sawtoothReal_add_one
    have h_shift : ∀ m : ℕ, m < j →
        ∫ u in (↑m:ℝ)..(↑m + 1),
          sawtoothReal u * sawtoothReal (↑k * u / ↑j) =
        ∫ v in (0:ℝ)..1,
          sawtoothReal v * sawtoothReal (↑k * v / ↑j + ↑k * ↑m / ↑j) := by
      intro m hm
      have hsub := intervalIntegral.integral_comp_add_right
        (fun u => sawtoothReal u * sawtoothReal (↑k * u / ↑j)) (↑m) (a := (0:ℝ)) (b := 1)
      simp only [zero_add] at hsub
      rw [show (1 : ℝ) + ↑m = ↑m + 1 from by ring] at hsub
      rw [← hsub]
      congr 1
      ext v
      have hper_v : sawtoothReal (v + ↑↑m) = sawtoothReal v := by
        have h := (hper.zsmul m) v; simp [zsmul_eq_mul, mul_one] at h; exact h
      rw [hper_v]
      congr 1; ring_nf
    have h_rewrite : ∑ m ∈ Finset.range j,
        ∫ u in (↑m:ℝ)..(↑m + 1), sawtoothReal u * sawtoothReal (↑k * u / ↑j) =
        ∑ m ∈ Finset.range j,
          ∫ v in (0:ℝ)..1, sawtoothReal v * sawtoothReal (↑k * v / ↑j + ↑k * ↑m / ↑j) := by
      apply Finset.sum_congr rfl
      intro m hm
      exact h_shift m (Finset.mem_range.mp hm)
    rw [h_rewrite]
    -- Step A: Swap sum and integral (finite sum, bounded integrands)
    have h_intble : ∀ m : ℕ, IntervalIntegrable
        (fun v => sawtoothReal v * sawtoothReal (↑k * v / ↑j + ↑k * ↑m / ↑j)) volume 0 1 := by
      intro m; constructor <;> {
        apply IntegrableOn.of_bound measure_Ioc_lt_top
          ((sawtoothReal_measurable.comp measurable_id).mul
           (sawtoothReal_measurable.comp
            (((measurable_const.mul measurable_id).div_const _).add_const _))).aestronglyMeasurable.restrict
          (1/4)
        exact (ae_restrict_mem measurableSet_Ioc).mono fun v _ => by
          rw [Real.norm_eq_abs, abs_mul]
          calc |sawtoothReal v| * |sawtoothReal _|
              ≤ (1/2) * (1/2) := mul_le_mul (sawtoothReal_bound _)
                (sawtoothReal_bound _) (abs_nonneg _) (by norm_num)
            _ ≤ 1/4 := by norm_num }
    rw [← intervalIntegral.integral_finset_sum (fun m _ => h_intble m)]
    -- Factor out B₁(v) and reduce to: ∑_m B₁(kv/j + km/j) = B₁(kv)
    congr 1; ext v; rw [← Finset.mul_sum]; congr 1
    -- Absorb integer part of km/j by periodicity of B₁
    have h_per_term : ∀ (m : ℕ), sawtoothReal (↑k * v / ↑j + ↑k * ↑m / ↑j) =
        sawtoothReal (↑k * v / ↑j + ↑(k * m % j) / ↑j) := by
      intro m
      -- km/j = floor_part + (km%j)/j, floor_part is integer → absorbed by periodicity
      set q := k * m / j
      set r := k * m % j
      have h_div : k * m = j * q + r := (Nat.div_add_mod (k * m) j).symm
      -- ↑k * ↑m / ↑j = q + ↑r / ↑j in ℝ
      have h_real : ↑k * (↑m : ℝ) / ↑j = ↑q + ↑r / ↑j := by
        have h1 : (↑(k * m) : ℝ) = ↑j * ↑q + ↑r := by push_cast [h_div]; ring
        have h2 : (↑(k * m) : ℝ) = ↑k * ↑m := by push_cast; ring
        have hj_ne' : (↑j : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
        rw [← h2]; field_simp [hj_ne'] at h1 ⊢; linarith
      rw [h_real]
      rw [show ↑k * v / ↑j + (↑q + ↑r / (↑j : ℝ)) = (↑k * v / ↑j + ↑r / ↑j) + ↑q from by ring]
      have hq := (hper.zsmul q) (↑k * v / ↑j + ↑r / ↑j)
      simp [zsmul_eq_mul, mul_one] at hq; exact hq
    simp_rw [h_per_term]
    -- CRT bijection + bernoulli_distribution
    -- m ↦ km%j permutes {0,...,j-1}, then ∑_r B₁(kv/j + r/j) = B₁(kv)
    rw [show ∑ m ∈ Finset.range j, sawtoothReal (↑k * v / ↑j + ↑(k * m % j) / ↑j) =
        ∑ r ∈ Finset.range j, sawtoothReal (↑k * v / ↑j + ↑r / ↑j) from by
      apply Finset.sum_nbij (fun m => k * m % j)
      · intro m _; exact Finset.mem_range.mpr (Nat.mod_lt _ hj)
      · -- Injective: km₁ ≡ km₂ (mod j) with m₁,m₂ < j implies m₁ = m₂ (via ZMod)
        intro m₁ hm₁ m₂ hm₂ heq
        simp only [Finset.mem_coe, Finset.mem_range] at hm₁ hm₂
        have h_zmod : (↑(k * m₁) : ZMod j) = ↑(k * m₂) := by
          rwa [ZMod.natCast_eq_natCast_iff]
        push_cast at h_zmod
        have hk_unit : IsUnit (k : ZMod j) :=
          ⟨ZMod.unitOfCoprime k hcop.symm, (ZMod.coe_unitOfCoprime k hcop.symm).symm⟩
        have h_eq := hk_unit.mul_left_cancel h_zmod
        rwa [ZMod.natCast_eq_natCast_iff, Nat.ModEq, Nat.mod_eq_of_lt hm₁,
          Nat.mod_eq_of_lt hm₂] at h_eq
      · -- Surjective: follows from injectivity + same cardinality (finite pigeonhole)
        intro r hr
        simp only [Finset.mem_coe, Finset.mem_range] at hr
        -- The image = range j by injection + same card
        have h_image : (Finset.range j).image (fun m => k * m % j) ⊆ Finset.range j :=
          fun x hx => by simp at hx ⊢; obtain ⟨m, _, rfl⟩ := hx; exact Nat.mod_lt _ hj
        have h_card : (Finset.range j).image (fun m => k * m % j) = Finset.range j := by
          apply Finset.eq_of_subset_of_card_le h_image
          rw [Finset.card_image_of_injOn (fun m₁ hm₁ m₂ hm₂ heq => by
            simp only [Finset.mem_coe, Finset.mem_range] at hm₁ hm₂
            have h_zmod : (↑(k * m₁) : ZMod j) = ↑(k * m₂) := by
              rwa [ZMod.natCast_eq_natCast_iff]
            push_cast at h_zmod
            have hk_unit : IsUnit (k : ZMod j) :=
              ⟨ZMod.unitOfCoprime k hcop.symm, (ZMod.coe_unitOfCoprime k hcop.symm).symm⟩
            have h_eq := hk_unit.mul_left_cancel h_zmod
            rwa [ZMod.natCast_eq_natCast_iff, Nat.ModEq, Nat.mod_eq_of_lt hm₁,
              Nat.mod_eq_of_lt hm₂] at h_eq)]
        have : r ∈ (Finset.range j).image (fun m => k * m % j) := by
          rw [h_card]; exact Finset.mem_range.mpr hr
        simp at this; obtain ⟨m, hm, hmod⟩ := this
        exact ⟨m, Finset.mem_range.mpr hm, hmod⟩
      · intro m _; rfl]
    -- bernoulli_distribution: ∑_r B₁(x + r/j) = B₁(j·x)
    -- with x = kv/j: ∑_r B₁(kv/j + r/j) = B₁(j · kv/j) = B₁(kv)
    conv_rhs => rw [show ↑k * v = ↑j * (↑k * v / ↑j) from by field_simp]
    exact bernoulli_distribution j hj (↑k * v / ↑j)
  -- Step 5: Assembly
  -- ∫₀¹ B₁(jt)·B₁(kt) dt = j⁻¹ · ∫₀ʲ B₁(u)·B₁(ku/j) du
  --                        = j⁻¹ · ∫₀¹ B₁(v)·B₁(kv) dv    [h_fold]
  --                        = j⁻¹ · 1/(12k)                  [sawtooth_base_inner_product]
  --                        = 1/(12jk)
  -- Substitution step: rewrite integrand
  have h_sub : ∫ t in (0:ℝ)..1, sawtoothReal (↑j * t) * sawtoothReal (↑k * t) =
      (↑j)⁻¹ * ∫ u in (0:ℝ)..(↑j), sawtoothReal u * sawtoothReal (↑k * u / ↑j) := by
    have hsub := intervalIntegral.integral_comp_mul_left
      (fun u => sawtoothReal u * sawtoothReal (↑k * u / ↑j)) hj_ne (a := 0) (b := 1)
    simp only [mul_zero, mul_one, smul_eq_mul] at hsub
    rw [← hsub]; congr 1; ext t
    show sawtoothReal (↑j * t) * sawtoothReal (↑k * t) =
      sawtoothReal (↑j * t) * sawtoothReal (↑k * (↑j * t) / ↑j)
    congr 1; field_simp
  rw [h_sub, h_fold]
  -- Now: j⁻¹ * ∫₀¹ B₁(v)·B₁(kv) dv = 1/(12jk)
  have h1 : ∫ v in (0:ℝ)..1, sawtoothReal v * sawtoothReal (↑k * v) =
      1 / (12 * ↑k) := by
    rw [show (fun v => sawtoothReal v * sawtoothReal (↑k * v)) =
      (fun v => sawtoothReal (1 * v) * sawtoothReal (↑k * v)) from by simp]
    exact sawtooth_base_inner_product k hk
  rw [h1]; field_simp

/-- **THEOREM (Ramanujan B₁ Inner Product Formula)**:

    For j, k ≥ 1:
      ∫₀¹ B₁({jt}) · B₁({kt}) dt = gcd(j,k)² / (12·j·k)

    This connects the positive-sector Gram matrix to GCD arithmetic,
    bridging into the dark crystal's gcd⁴ structure.

    **Proof outline**:
    1. Reduce to coprime case via d = gcd(j,k) substitution
    2. For coprime j', k': piecewise integrate over lcm(j',k') = j'k' intervals
    3. Each interval contributes 1/(12·(j'k')²), and there are j'k' intervals
    4. Total = 1/(12·j'k') = d²/(12·j·k)
-/
theorem sawtooth_inner_product (j k : ℕ) (hj : 0 < j) (hk : 0 < k) :
    sawtoothInnerProduct j k =
    (Nat.gcd j k : ℝ) ^ 2 / (12 * (j : ℝ) * (k : ℝ)) := by
  -- Let d = gcd(j,k), j' = j/d, k' = k/d
  set d := Nat.gcd j k with hd_def
  have hd_pos : 0 < d := Nat.gcd_pos_of_pos_left k hj
  have hj_div : d ∣ j := Nat.gcd_dvd_left j k
  have hk_div : d ∣ k := Nat.gcd_dvd_right j k
  set j' := j / d with hj'_def
  set k' := k / d with hk'_def
  have hj_eq : j = d * j' := by
    rw [mul_comm]; exact (Nat.div_mul_cancel hj_div).symm
  have hk_eq : k = d * k' := by
    rw [mul_comm]; exact (Nat.div_mul_cancel hk_div).symm
  have hj'_pos : 0 < j' := Nat.div_pos (Nat.le_of_dvd hj hj_div) hd_pos
  have hk'_pos : 0 < k' := Nat.div_pos (Nat.le_of_dvd hk hk_div) hd_pos
  have hcop : Nat.Coprime j' k' := Nat.coprime_div_gcd_div_gcd hd_pos
  -- Step 1: GCD reduction
  -- sawtoothInnerProduct (d*j') (d*k') = sawtoothInnerProduct j' k'
  -- by substitution u = d*t and periodicity
  unfold sawtoothInnerProduct
  -- Rewrite j, k in terms of d, j', k' and reorganize for substitution
  simp_rw [show (↑j : ℝ) = ↑d * ↑j' by push_cast [hj_eq]; ring,
           show (↑k : ℝ) = ↑d * ↑k' by push_cast [hk_eq]; ring,
           show ∀ t : ℝ, ↑d * ↑j' * t = ↑j' * (↑d * t) from fun t => by ring,
           show ∀ t : ℝ, ↑d * ↑k' * t = ↑k' * (↑d * t) from fun t => by ring]
  -- Now integrand is B₁(j'·(d·t)) · B₁(k'·(d·t))
  -- Substitution u = d*t: ∫₀¹ g(d·t) dt = d⁻¹ · ∫₀^d g(u) du
  have hd_ne : (d : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  -- Define g to prevent beta reduction
  have hsub := intervalIntegral.integral_comp_mul_left
    (fun u => sawtoothReal (↑j' * u) * sawtoothReal (↑k' * u)) hd_ne (a := 0) (b := 1)
  simp only [mul_zero, mul_one] at hsub
  rw [hsub]
  -- Periodicity: ∫₀^d = d · ∫₀¹ (product has period 1)
  have hper : Function.Periodic
      (fun u => sawtoothReal (↑j' * u) * sawtoothReal (↑k' * u)) 1 := fun u => by
    show sawtoothReal (↑j' * (u + 1)) * sawtoothReal (↑k' * (u + 1)) =
         sawtoothReal (↑j' * u) * sawtoothReal (↑k' * u)
    simp only [mul_add, mul_one]
    have hsaw_per : Function.Periodic sawtoothReal 1 := sawtoothReal_add_one
    congr 1
    · -- sawtoothReal(j'*u + j') = sawtoothReal(j'*u)
      -- = sawtoothReal(j'*u + j'*1) by nat_mul
      have h := (hsaw_per.nat_mul j') (↑j' * u)
      simp only [mul_one] at h; exact h
    · have h := (hsaw_per.nat_mul k') (↑k' * u)
      simp only [mul_one] at h; exact h
  have hint := sawtoothProduct_integrable j' k'
  have hint_all : ∀ t₁ t₂, IntervalIntegrable
      (fun u => sawtoothReal (↑j' * u) * sawtoothReal (↑k' * u)) volume t₁ t₂ :=
    hper.intervalIntegrable₀ one_ne_zero hint
  rw [show (↑d : ℝ) = 0 + (↑d : ℤ) • (1 : ℝ) from by simp]
  rw [hper.intervalIntegral_add_zsmul_eq _ 0 hint_all]
  simp only [zero_add, smul_eq_mul, zsmul_eq_mul, Int.cast_natCast]
  -- Now: d⁻¹ • (d * ∫₀¹ B₁(j'u)·B₁(k'u) du) = gcd²/(12jk)
  -- = ∫₀¹ B₁(j'u)·B₁(k'u) du (d cancels)
  -- Step 2: Coprime formula (the core identity)
  -- For coprime j', k': ∫₀¹ B₁(j't)·B₁(k't) dt = 1/(12·j'·k')
  suffices h_cop : ∫ t in (0:ℝ)..1, sawtoothReal (↑j' * t) * sawtoothReal (↑k' * t) =
      1 / (12 * ↑j' * ↑k') by
    rw [h_cop]
    -- Goal is now: (↑d*1)⁻¹ * (↑d * (1/(12*↑j'*↑k'))) = (↑d*1)²/(12*(↑d*1*↑j')*(↑d*1*↑k'))
    have hj'_ne : (j' : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
    have hk'_ne : (k' : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
    field_simp
  exact sawtooth_coprime_inner_product j' k' hj'_pos hk'_pos hcop

-- ════════════════════════════════════════════════
-- §5. COROLLARIES FOR STRATEGY C
-- ════════════════════════════════════════════════

/-- **Corollary**: The fractional-part inner product has GCD structure.

    ∫₀¹ {jt}·{kt} dt = gcd(j,k)²/(12jk) + 1/4

    This follows from the B₁ decomposition {a}{b} = B₁·B₁ + cross + 1/4
    and the mean-zero property of B₁ (which kills the cross terms). -/
theorem fract_inner_product (j k : ℕ) (hj : 0 < j) (hk : 0 < k) :
    ∫ t in (0:ℝ)..1, Int.fract (j * t) * Int.fract (k * t) =
    (Nat.gcd j k : ℝ) ^ 2 / (12 * (j : ℝ) * (k : ℝ)) + 1/4 := by
  -- Step 1: Rewrite {jt}·{kt} using B₁ decomposition
  simp_rw [show ∀ t, Int.fract (↑j * t) * Int.fract (↑k * t) =
    sawtoothReal (↑j * t) * sawtoothReal (↑k * t)
    + (1/2) * sawtoothReal (↑j * t)
    + (1/2) * sawtoothReal (↑k * t) + 1/4
    from fun t => fract_product_decomposition _ _]
  -- Step 2: Split integral by linearity
  have h_prod := sawtoothProduct_integrable j k
  have h_j := sawtooth_scaled_integrable j
  have h_k := sawtooth_scaled_integrable k
  rw [intervalIntegral.integral_add
    ((h_prod.add (h_j.const_mul _)).add (h_k.const_mul _))
    intervalIntegrable_const,
    intervalIntegral.integral_add
    (h_prod.add (h_j.const_mul _)) (h_k.const_mul _),
    intervalIntegral.integral_add h_prod (h_j.const_mul _)]
  -- Step 3: Evaluate each piece
  -- ∫ (1/2)·B₁(jt) = (1/2) · 0 = 0
  rw [intervalIntegral.integral_const_mul, sawtooth_mean_zero j hj, mul_zero]
  -- ∫ (1/2)·B₁(kt) = (1/2) · 0 = 0
  rw [intervalIntegral.integral_const_mul, sawtooth_mean_zero k hk, mul_zero]
  -- ∫ 1/4 dt = 1/4
  rw [intervalIntegral.integral_const]
  -- Now: ∫ B₁·B₁ + 0 + 0 + 1/4 · (1-0) = gcd²/(12jk) + 1/4
  simp only [add_zero, sub_zero, smul_eq_mul]
  -- Fold the integral back as sawtoothInnerProduct and apply the main formula
  change sawtoothInnerProduct j k + 1 * (1 / 4) = _
  rw [sawtooth_inner_product j k hj hk]
  ring

/-- **Strategy C Bridge**: Ratio of positive to dark Gram diagonal entries.

    For j = k: G^(1)_{j,j} / G^(2)_{j,j} is explicitly computable.
    The positive diagonal ∫₀¹ {jt}² dt = 1/3 (from sawtooth_inner_product_diag).
    The dark diagonal G^(2)_{j,j} = 1/180.
    Ratio = 60 — a universal constant independent of j.

    This is the "comparison operator" at the diagonal level. -/
theorem fract_squared_integral (j : ℕ) (hj : 0 < j) :
    ∫ t in (0:ℝ)..1, Int.fract (j * t) ^ 2 = 1 / 3 := by
  -- {jt}² = B₁²+B₁+1/4, use fract_product_decomposition
  simp_rw [show ∀ t : ℝ, Int.fract (↑j * t) ^ 2 =
    sawtoothReal (↑j * t) * sawtoothReal (↑j * t)
    + (1/2) * sawtoothReal (↑j * t) + (1/2) * sawtoothReal (↑j * t) + 1/4
    from fun t => by rw [sq]; exact fract_product_decomposition _ _]
  -- Split integral by linearity
  have h_sq := sawtoothProduct_integrable j j
  have h_j := sawtooth_scaled_integrable j
  rw [intervalIntegral.integral_add
    ((h_sq.add (h_j.const_mul _)).add (h_j.const_mul _))
    intervalIntegrable_const,
    intervalIntegral.integral_add
    (h_sq.add (h_j.const_mul _)) (h_j.const_mul _),
    intervalIntegral.integral_add h_sq (h_j.const_mul _)]
  -- ∫ (1/2)·B₁(jt) = 0 (both cross terms)
  rw [intervalIntegral.integral_const_mul, sawtooth_mean_zero j hj, mul_zero]
  -- ∫ B₁(jt)² = 1/12, ∫ 1/4 = 1/4
  have h1 : ∫ (x : ℝ) in (0:ℝ)..1, sawtoothReal (↑j * x) * sawtoothReal (↑j * x) = 1 / 12 :=
    sawtooth_inner_product_diag j hj
  simp only [h1, add_zero, intervalIntegral.integral_const, sub_zero, smul_eq_mul]
  norm_num

-- ════════════════════════════════════════════════
-- §5. AUDIT
-- ════════════════════════════════════════════════

/-!
## Audit

### Status: ZERO SORRY — Fully Certified ✅

| Theorem | Status |
|---------|--------|
| `sawtoothProduct_integrable` | ✅ PROVED |
| `sawtooth_inner_product_diag` | ✅ PROVED (substitution + periodicity + L² norm) |
| `sawtooth_mean_zero_base` | ✅ PROVED (ae-congr + FTC) |
| `sawtooth_mean_zero` | ✅ PROVED (substitution + periodicity + base case) |
| `sawtooth_coprime_inner_product` | ✅ PROVED (CRT permutation + bernoulli_distribution) |
| `sawtooth_inner_product` | ✅ PROVED (GCD reduction + coprime case) |
| `fract_inner_product` | ✅ PROVED (B₁ decomposition + mean-zero) |
| `fract_squared_integral` | ✅ PROVED (corollary: ∫{jt}² = 1/3) |

### Architecture:
  sawtooth_inner_product (MAIN — Ramanujan B₁ formula)
    ↓ GCD reduction (d = gcd(j,k), substitution u=dt, periodicity)
    sawtooth_coprime_inner_product (coprime kernel)
      ↓ Integral splitting + periodicity shift
      ↓ CRT bijection (m ↦ km%j via ZMod coprimality)
      ↓ Bernoulli distribution identity (∑ B₁(x+r/n) = B₁(nx))
  fract_inner_product (corollary via B₁ decomposition + mean-zero)
  fract_squared_integral (corollary: ∫{jt}² = 1/3)
-/

end Cathedral.RamanujanInnerProduct
