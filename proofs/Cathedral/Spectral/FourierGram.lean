/-
  Cathedral/Spectral/FourierGram.lean

  # The Fourier–Gram Bridge (Phase 1: Sawtooth Foundations)

  ## Purpose

  This file establishes the Fourier-analytic infrastructure needed to
  connect the Gram matrix inner product ∫₀¹ {1/(jx)}{1/(kx)} dx to
  the Montgomery-Vaughan Large Sieve inequality, which is the key
  step in closing `witness_covariance_decay`.

  ## Phase 1: Sawtooth Function and Fourier Coefficients

  The centered sawtooth function B₁(x) = {x} - 1/2 has Fourier expansion:
    B₁(x) = -Σ_{n=1}^∞ sin(2πnx) / (πn)    (for x ∉ ℤ)

  Equivalently, the n-th Fourier coefficient (for n ≠ 0) is:
    ĉₙ = -1 / (2πin)

  We use Mathlib's `fourierCoeffOn` infrastructure to formalize this.

  ## Architecture

  ```
  sawtoothFn                     — {x} - 1/2 on ℝ
  sawtoothFn_periodic            — B₁(x + 1) = B₁(x) a.e.
  fourierCoeffOn_sawtooth        — ĉₙ = -1/(2πin) for n ≠ 0
  sawtooth_parseval              — Σ |ĉₙ|² = ∫₀¹ |B₁|²
  sawtooth_l2_norm               — ∫₀¹ B₁(x)² dx = 1/12
  ```

  ## Dependencies
  - Mathlib.Analysis.Fourier.AddCircle (fourierCoeffOn, hasSum_sq_fourierCoeffOn)
  - Mathlib.Data.Int.Fract (Int.fract)

  Created: May 9, 2026 — Exploration 31: The Fourier Bridge
  Status: Phase 1 of 5 toward closing witness_covariance_decay.
-/

import Mathlib.Analysis.Fourier.AddCircle
import Mathlib.MeasureTheory.Function.Floor
import Mathlib.MeasureTheory.Integral.IntervalIntegral.FundThmCalculus
import Mathlib.Analysis.Calculus.Deriv.Pow

set_option maxHeartbeats 400000

noncomputable section
open Real MeasureTheory Complex Filter Finset
open scoped BigOperators

namespace Cathedral.FourierGram

-- ════════════════════════════════════════════════
-- §1. THE SAWTOOTH FUNCTION
-- ════════════════════════════════════════════════

/-- The centered first Bernoulli function (sawtooth wave):
    B₁(x) = {x} - 1/2.

    Properties:
    - Period 1 (a.e.)
    - ∫₀¹ B₁ = 0 (mean zero)
    - ∫₀¹ B₁² = 1/12
    - Fourier coefficients: ĉₙ = -1/(2πin) for n ≠ 0

    This is the building block for the fractional-part inner product. -/
def sawtoothFn (x : ℝ) : ℂ :=
  ((Int.fract x : ℝ) : ℂ) - (1 : ℂ) / 2

/-- B₁ as a real-valued function (for integration convenience). -/
def sawtoothReal (x : ℝ) : ℝ :=
  Int.fract x - 1/2

theorem sawtoothFn_eq_ofReal (x : ℝ) :
    sawtoothFn x = ((sawtoothReal x : ℝ) : ℂ) := by
  simp only [sawtoothFn, sawtoothReal, Complex.ofReal_sub, Complex.ofReal_div,
    Complex.ofReal_one, Complex.ofReal_ofNat]

/-- The sawtooth function is periodic with period 1. -/
theorem sawtoothReal_add_one (x : ℝ) :
    sawtoothReal (x + 1) = sawtoothReal x := by
  simp only [sawtoothReal]
  congr 1
  rw [Int.fract_add_one]

/-- The sawtooth is bounded: |B₁(x)| ≤ 1/2. -/
theorem sawtoothReal_bound (x : ℝ) : |sawtoothReal x| ≤ 1/2 := by
  simp only [sawtoothReal]
  have h1 := Int.fract_nonneg x
  have h2 := Int.fract_lt_one x
  rw [abs_le]
  constructor <;> linarith

/-- The sawtooth is measurable. -/
theorem sawtoothReal_measurable : Measurable sawtoothReal := by
  apply Measurable.sub
  · exact measurable_fract
  · exact measurable_const

-- ════════════════════════════════════════════════
-- §2. THE L² NORM: ∫₀¹ B₁(x)² dx = 1/12
-- ════════════════════════════════════════════════

/-- **THEOREM**: The L² norm of the sawtooth on [0,1] is 1/12.

    Proof: ∫₀¹ ({x} - 1/2)² dx = ∫₀¹ (x - 1/2)² dx (since {x} = x on (0,1))
           = [x³/3 - x²/2 + x/4]₀¹ = 1/3 - 1/2 + 1/4 = 1/12. -/
theorem sawtooth_l2_norm_sq :
    ∫ x in (0:ℝ)..1, sawtoothReal x ^ 2 = 1/12 := by
  -- Step 1: On (0,1], sawtoothReal x = x - 1/2, so their squares match a.e.
  have h_congr : (fun x => sawtoothReal x ^ 2) =ᵐ[volume.restrict (Set.Ioc (0:ℝ) 1)]
      (fun x => (x - 1/2) ^ 2) := by
    apply (ae_restrict_mem measurableSet_Ioc).mono
    intro x hx
    have hx0 : 0 < x := hx.1
    have hx1 : x ≤ 1 := hx.2
    show sawtoothReal x ^ 2 = (x - 1 / 2) ^ 2
    rcases eq_or_lt_of_le hx1 with rfl | hx_lt
    · simp [sawtoothReal, Int.fract_one]; norm_num
    · unfold sawtoothReal
      rw [Int.fract_eq_self.mpr ⟨le_of_lt hx0, hx_lt⟩]
  -- Step 2: Replace integral via a.e. equality
  rw [intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  rw [MeasureTheory.integral_congr_ae h_congr]
  rw [← intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  -- Step 3: FTC with antiderivative F(x) = x³/3 - x²/2 + x/4
  have hF : ∀ x ∈ Set.uIcc (0:ℝ) 1,
      HasDerivAt (fun x => x ^ 3 / 3 - x ^ 2 / 2 + x / 4)
        ((x - 1/2) ^ 2) x := by
    intro x _
    have h3 := (hasDerivAt_pow 3 x).div_const (3:ℝ)
    have h2 := (hasDerivAt_pow 2 x).div_const (2:ℝ)
    have h1 := (hasDerivAt_id x).div_const (4:ℝ)
    convert h3.sub h2 |>.add h1 using 1
    ring
  have hint : IntervalIntegrable (fun x => (x - 1/2) ^ 2) volume (0:ℝ) 1 := by
    apply ContinuousOn.intervalIntegrable
    exact (continuous_id.sub continuous_const).pow 2 |>.continuousOn
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hF hint]
  -- Step 4: Compute F(1) - F(0) = (1/3 - 1/2 + 1/4) - 0 = 1/12
  norm_num

-- ════════════════════════════════════════════════
-- §3. FOURIER COEFFICIENTS OF THE SAWTOOTH
-- ════════════════════════════════════════════════

/-- The proof witness that 0 < 1. -/
private lemma zero_lt_one' : (0 : ℝ) < 1 := by norm_num

/-- **THEOREM**: The n-th Fourier coefficient of B₁ on (0,1] is -1/(2πin) for n ≠ 0.

    Proof sketch: Integration by parts via Mathlib's `fourierCoeffOn_of_hasDerivAt`.
    The sawtooth has derivative 1 a.e. on (0,1), and the boundary terms
    give -1/(2πin) from the jump discontinuity at integer points.

    Mathematically:
      ĉₙ = ∫₀¹ ({x}-1/2) e^{-2πinx} dx = ∫₀¹ (x-1/2) e^{-2πinx} dx
         = [-(x-1/2)e^{-2πinx}/(2πin)]₀¹ + ∫₀¹ e^{-2πinx}/(2πin) dx
         = 0 + 0 = ... wait, that's not right.

    Actually by direct integration:
      ∫₀¹ x·e^{-2πinx} dx = -1/(2πin)  (integration by parts)
      ∫₀¹ (1/2)·e^{-2πinx} dx = 0       (for n ≠ 0)
    So ĉₙ = -1/(2πin). -/
theorem fourierCoeffOn_sawtooth (n : ℤ) (hn : n ≠ 0) :
    fourierCoeffOn zero_lt_one' sawtoothFn n =
      -1 / (2 * ↑Real.pi * Complex.I * ↑n) := by
  -- Step 1: Transfer from sawtoothFn to g(x) = ofReal(x-1/2) by ae congr
  -- fourierCoeffOn depends only on the ae-equivalence class on (0,1]
  set g : ℝ → ℂ := fun x => ((x : ℝ) : ℂ) - 1/2 with hg_def
  -- g is smooth, agrees with sawtoothFn ae on (0,1]
  have h_ae : sawtoothFn =ᵐ[volume.restrict (Set.Ioc (0:ℝ) 1)] g := by
    have hset : Set.Ioc (0:ℝ) 1 =ᵐ[volume] Set.Ioo (0:ℝ) 1 :=
      Ioo_ae_eq_Ioc.symm
    rw [Measure.restrict_congr_set hset]
    apply (ae_restrict_mem measurableSet_Ioo).mono
    intro x ⟨hx0, hx1⟩
    show sawtoothFn x = ((x : ℝ) : ℂ) - 1/2
    rw [sawtoothFn_eq_ofReal]
    unfold sawtoothReal
    rw [Int.fract_eq_self.mpr ⟨le_of_lt hx0, hx1⟩]
    push_cast; ring
  -- Step 2: fourierCoeffOn agrees for ae-equal functions
  -- (fourierCoeffOn is defined via an integral, which respects ae equality)
  have h_coeff_eq : fourierCoeffOn zero_lt_one' sawtoothFn n =
      fourierCoeffOn zero_lt_one' g n := by
    simp only [fourierCoeffOn_eq_integral]
    congr 1
    apply intervalIntegral.integral_congr_ae
    have hset : Set.Ioc (0:ℝ) 1 =ᵐ[volume] Set.Ioo (0:ℝ) 1 :=
      Ioo_ae_eq_Ioc.symm
    rw [Set.uIoc_of_le (by norm_num : (0:ℝ) ≤ 1), Measure.restrict_congr_set hset]
    apply (ae_restrict_mem measurableSet_Ioo).mono
    intro x ⟨hx0, hx1⟩
    show fourier (-n) (↑x) • sawtoothFn x = fourier (-n) (↑x) • g x
    congr 1
    rw [sawtoothFn_eq_ofReal]; unfold sawtoothReal
    rw [Int.fract_eq_self.mpr ⟨le_of_lt hx0, hx1⟩]; push_cast; ring
  rw [h_coeff_eq]
  -- Step 3: Apply fourierCoeffOn_of_hasDerivAt to g
  -- g(x) = x - 1/2, g'(x) = 1
  have h_ibp := fourierCoeffOn_of_hasDerivAt zero_lt_one' hn
    (f := g) (f' := fun _ => 1)
    (fun x _ => by
      show HasDerivAt (fun x => ((x : ℝ) : ℂ) - 1/2) 1 x
      convert Complex.ofRealCLM.hasDerivAt.sub (hasDerivAt_const x (1/2 : ℂ)) using 1
      simp)
    (by exact intervalIntegrable_const)
  rw [h_ibp]
  -- Step 4: Simplify the result
  -- g(1) - g(0) = (1-1/2) - (0-1/2) = 1
  -- fourierCoeffOn (const 1) n = 0 for n ≠ 0
  -- fourier(-n)(0 : AddCircle 1) = 1
  -- So: 1/(-2πin) * (1 * 1 - 1 * 0) = -1/(2πin)
  sorry -- Algebraic simplification of IBP formula

/-- The zeroth Fourier coefficient of B₁ vanishes (B₁ has mean zero). -/
theorem fourierCoeffOn_sawtooth_zero :
    fourierCoeffOn zero_lt_one' sawtoothFn 0 = 0 := by
  -- Unfold fourierCoeffOn to an integral
  rw [fourierCoeffOn_eq_integral]
  -- fourier (-0) = fourier 0 = 1, so the integrand is just sawtoothFn
  simp only [neg_zero, fourier_zero, one_smul]
  -- (1/(1-0)) • ∫₀¹ sawtoothFn x = ∫₀¹ sawtoothFn x (since 1/(1-0) = 1)
  simp only [sub_zero, one_div, inv_one, one_smul]
  -- Now need: ∫₀¹ sawtoothFn x = 0, i.e., ∫₀¹ ({x}-1/2) dx = 0
  -- First, replace sawtoothFn with ofReal(x-1/2) via ae congr
  rw [show (0:ℝ) = (0:ℝ) from rfl, show (1:ℝ) = (1:ℝ) from rfl]
  rw [intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  -- ae congr: sawtoothFn = ofReal(x-1/2) on (0,1]
  have h_congr : (fun x => sawtoothFn x) =ᵐ[volume.restrict (Set.Ioc (0:ℝ) 1)]
      (fun x => ((x - 1/2 : ℝ) : ℂ)) := by
    -- The functions agree pointwise on (0,1) (open interval)
    have h_ioo : ∀ x ∈ Set.Ioo (0:ℝ) 1,
        sawtoothFn x = ((x - 1/2 : ℝ) : ℂ) := by
      intro x ⟨hx0, hx1⟩
      rw [sawtoothFn_eq_ofReal]; congr 1; unfold sawtoothReal
      rw [Int.fract_eq_self.mpr ⟨le_of_lt hx0, hx1⟩]
    -- Ioo =ᵐ Ioc for NoAtoms measures, so restrict Ioc = restrict Ioo
    have hset : Set.Ioc (0:ℝ) 1 =ᵐ[volume] Set.Ioo (0:ℝ) 1 :=
      Ioo_ae_eq_Ioc.symm
    have hrestr := Measure.restrict_congr_set hset
    -- Rewrite the measure in the goal from restrict Ioc to restrict Ioo
    show (fun x => sawtoothFn x) =ᵐ[volume.restrict (Set.Ioc (0:ℝ) 1)]
      (fun x => ((x - 1/2 : ℝ) : ℂ))
    rw [hrestr]
    exact (ae_restrict_mem measurableSet_Ioo).mono (fun x hx => h_ioo x hx)
  rw [MeasureTheory.integral_congr_ae h_congr]
  rw [← intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  -- FTC: ∫₀¹ (x-1/2) dx with antiderivative F(x) = x²/2 - x/2
  have hF : ∀ x ∈ Set.uIcc (0:ℝ) 1,
      HasDerivAt (fun x => ((x ^ 2 / 2 - x / 2 : ℝ) : ℂ))
        ((x - 1/2 : ℝ) : ℂ) x := by
    intro x _
    have := ((hasDerivAt_pow 2 x).div_const (2:ℝ)).sub
      ((hasDerivAt_id x).div_const (2:ℝ))
    apply HasDerivAt.ofReal_comp
    convert this using 1; ring
  have hint : IntervalIntegrable (fun x => ((x - 1/2 : ℝ) : ℂ)) volume (0:ℝ) 1 := by
    apply ContinuousOn.intervalIntegrable
    exact (Complex.continuous_ofReal.comp (continuous_id.sub continuous_const)).continuousOn
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hF hint]
  -- F(1) - F(0) = (1/2 - 1/2) - (0) = 0
  push_cast; norm_num

-- ════════════════════════════════════════════════
-- §4. PARSEVAL IDENTITY FOR THE SAWTOOTH
-- ════════════════════════════════════════════════

/-- The sawtooth is square-integrable on (0,1]. -/
theorem sawtooth_memLp :
    MeasureTheory.MemLp sawtoothFn 2 (MeasureTheory.volume.restrict (Set.Ioc 0 1)) := by
  -- volume.restrict (Ioc 0 1) is a finite measure
  haveI : IsFiniteMeasure (volume.restrict (Set.Ioc (0:ℝ) 1)) := by
    constructor
    simp
  -- sawtoothFn is AEStronglyMeasurable (it's measurable + separable range)
  have h_aesm : AEStronglyMeasurable sawtoothFn (volume.restrict (Set.Ioc (0:ℝ) 1)) := by
    rw [show sawtoothFn = fun x => ((sawtoothReal x : ℝ) : ℂ) from funext sawtoothFn_eq_ofReal]
    exact (Complex.continuous_ofReal.measurable.comp sawtoothReal_measurable).aestronglyMeasurable
  have h_bound : ∀ᵐ x ∂(volume.restrict (Set.Ioc (0:ℝ) 1)), ‖sawtoothFn x‖ ≤ 1/2 := by
    apply Filter.Eventually.of_forall
    intro x
    rw [sawtoothFn_eq_ofReal, Complex.norm_real]
    exact sawtoothReal_bound x
  exact MemLp.of_bound h_aesm (1/2) h_bound

/-- **Parseval's identity for the sawtooth**: The sum of |ĉₙ|² equals ∫₀¹|B₁|² = 1/12.

    In particular: Σ_{n≠0} 1/(4π²n²) = 1/12.
    This is equivalent to the Basel problem: Σ 1/n² = π²/6. -/
theorem sawtooth_parseval :
    HasSum (fun n : ℤ => ‖fourierCoeffOn zero_lt_one' sawtoothFn n‖ ^ 2)
      ((1 - 0 : ℝ)⁻¹ • ∫ x in (0:ℝ)..1, ‖sawtoothFn x‖ ^ 2) :=
  hasSum_sq_fourierCoeffOn zero_lt_one' sawtooth_memLp

-- ════════════════════════════════════════════════
-- §5. THE B₁ DECOMPOSITION (Phase 2 Foundation)
-- ════════════════════════════════════════════════

-- Key identity (Gemini's insight):
--   {x} = B₁(x) + 1/2
-- Therefore:
--   {1/(jx)} · {1/(kx)} = B₁(1/jx)·B₁(1/kx) + ½B₁(1/jx) + ½B₁(1/kx) + ¼

/-- The fundamental identity: {x} = B₁(x) + 1/2. -/
theorem fract_eq_sawtooth_add_half (x : ℝ) :
    Int.fract x = sawtoothReal x + 1/2 := by
  simp [sawtoothReal]

/-- **B₁ Product Decomposition**: The product of two fractional parts decomposes as:
    {a}·{b} = B₁(a)·B₁(b) + ½B₁(a) + ½B₁(b) + ¼

    This is the algebraic heart of the Fourier-Gram Bridge:
    - The B₁·B₁ term is the pure zero-mean covariance (Parseval target)
    - The cross terms involve ∫B₁ = 0 (by ĉ₀ = 0)
    - The constant 1/4 is controlled by (Σvₖ)² = S₁² → 0 -/
theorem fract_product_decomposition (a b : ℝ) :
    Int.fract a * Int.fract b =
      sawtoothReal a * sawtoothReal b
      + (1/2) * sawtoothReal a
      + (1/2) * sawtoothReal b
      + 1/4 := by
  rw [fract_eq_sawtooth_add_half, fract_eq_sawtooth_add_half]
  ring

-- ════════════════════════════════════════════════
-- §6. THE GEOMETRIC INVERSION (Phase 2)
-- ════════════════════════════════════════════════

/-- **Gram entry definition**: G(j,k) = ∫₀¹ {1/(jx)}·{1/(kx)} dx.
    This is the inner product of the Nyman-Beurling basis functions. -/
def gramEntryIntegral (j k : ℕ) : ℝ :=
  ∫ x in (0:ℝ)..1, Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x))

/-- **Gram entry via B₁**: Decompose G(j,k) using the sawtooth.
    G(j,k) = ∫₀¹ B₁(1/jx)·B₁(1/kx) dx
           + ½ ∫₀¹ B₁(1/jx) dx + ½ ∫₀¹ B₁(1/kx) dx + ¼

    The first term is the pure covariance (Fourier target).
    The cross terms = ½(bⱼ - 1/2) + ½(bₖ - 1/2).
    The constant = 1/4. -/
theorem gram_entry_b1_decomposition (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    gramEntryIntegral j k =
      ∫ x in (0:ℝ)..1, sawtoothReal (1/((j:ℝ)*x)) * sawtoothReal (1/((k:ℝ)*x))
      + (1/2) * ∫ x in (0:ℝ)..1, sawtoothReal (1/((j:ℝ)*x))
      + (1/2) * ∫ x in (0:ℝ)..1, sawtoothReal (1/((k:ℝ)*x))
      + 1/4 := by
  -- Step 1: Rewrite the integrand pointwise using B₁ decomposition
  unfold gramEntryIntegral
  have h_eq : ∀ x : ℝ,
      Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)) =
      sawtoothReal (1/((j:ℝ)*x)) * sawtoothReal (1/((k:ℝ)*x))
      + (1/2) * sawtoothReal (1/((j:ℝ)*x))
      + (1/2) * sawtoothReal (1/((k:ℝ)*x))
      + 1/4 :=
    fun x => fract_product_decomposition _ _
  simp_rw [h_eq]
  -- Step 2: Split the integral of a sum into sum of integrals
  -- This requires integrability of each component, which holds because
  -- the sawtooth is bounded by 1/2 on [0,1]
  sorry -- Linearity: ∫(f+g+h+c) = ∫f + ∫g + ∫h + c·∫1

/-- **Geometric inversion**: Under u = 1/x, the Gram integral transforms from
    ∫₀¹ to ∫₁^∞ with Jacobian du/u².

    G(j,k) = ∫₁^∞ {u/j}·{u/k} · du/u²

    This makes the fractional parts periodic sawtooths:
    {u/j} has period j, {u/k} has period k.
    Their product has period lcm(j,k). -/
theorem gram_entry_inversion (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    gramEntryIntegral j k =
      ∫ u in Set.Ioi (1:ℝ),
        Int.fract ((u:ℝ) / j) * Int.fract ((u:ℝ) / k) / u ^ 2 := by
  -- Change of variables u = 1/x, du = -dx/x², on (0,1] → [1,∞)
  sorry -- MeasureTheory.integral_comp with u = 1/x

-- ════════════════════════════════════════════════
-- §7. AUDIT
-- ════════════════════════════════════════════════

/-!
## Audit

### Proved (0 sorry, 0 axiom):
  1. `sawtoothReal_bound` — |B₁| ≤ 1/2
  2. `sawtoothReal_add_one` — periodicity
  3. `sawtoothReal_measurable` — measurability
  4. `fract_eq_sawtooth_add_half` — {x} = B₁(x) + 1/2
  5. `fract_product_decomposition` — {a}·{b} = B₁(a)·B₁(b) + cross + 1/4
  6. `sawtooth_parseval` — Parseval identity (CERTIFIED: memLp + Mathlib)
  7. `sawtooth_memLp` — L² integrability on (0,1]

### Sorry: 5
  Phase 1 (FTC computations):
  1. `sawtooth_l2_norm_sq` — ∫₀¹(x-1/2)² = 1/12
  2. `fourierCoeffOn_sawtooth` — ĉₙ = -1/(2πin)
  3. `fourierCoeffOn_sawtooth_zero` — ĉ₀ = 0

  Phase 2 (measure theory):
  4. `gram_entry_b1_decomposition` — G(j,k) decomposed via B₁ (linearity of ∫)
  5. `gram_entry_inversion` — u = 1/x change of variables

### Axioms: 0

### Architecture:
  **Parseval is FULLY CERTIFIED.** The chain:
    sawtoothFn → sawtooth_memLp (PROVED) → hasSum_sq_fourierCoeffOn (Mathlib)
  compiles with zero sorry, zero axiom. The remaining sorrys are either
  standard FTC computations or measure-theoretic change-of-variables.

### Phase status:
  Phase 1/5: ▓▓▓▓▓▓▓░ (7 proved, 3 sorry — FTC computations)
  Phase 2/5: ▓▓░░░░░░ (2 theorems stated, 2 sorry — structural)
-/

end Cathedral.FourierGram
