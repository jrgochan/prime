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
  sorry -- Main proof: GCD reduction + coprime piecewise integration

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
  simp only [add_zero, sub_zero, smul_eq_mul, mul_one]
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
  -- {jt}² = (B₁({jt}) + 1/2)² = B₁² + B₁ + 1/4
  -- ∫ = 1/12 + 0 + 1/4 = 1/3
  sorry

-- ════════════════════════════════════════════════
-- §5. AUDIT
-- ════════════════════════════════════════════════

/-!
## Audit

### Status: IN PROGRESS (3 sorry — working toward full proof)

| Theorem | Status |
|---------|--------|
| `sawtoothProduct_integrable` | ✅ PROVED |
| `sawtooth_inner_product_diag` | 🔨 sorry (diagonal case) |
| `sawtooth_inner_product` | 🔨 sorry (main Ramanujan formula) |
| `fract_inner_product` | 🔨 sorry (corollary) |
| `fract_squared_integral` | 🔨 sorry (corollary) |

### Architecture:
  sawtooth_inner_product (MAIN — Ramanujan B₁ formula)
    ↓ GCD reduction
    coprime_sawtooth_inner_product (coprime case)
    ↓ piecewise FTC on j'k' sub-intervals
    ↓ periodicity + summation
  fract_inner_product (corollary via B₁ decomposition)
  fract_squared_integral (corollary: ∫{jt}² = 1/3)
-/

end Cathedral.RamanujanInnerProduct
