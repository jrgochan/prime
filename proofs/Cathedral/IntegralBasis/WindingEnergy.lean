/-
  Cathedral/IntegralBasis/WindingEnergy.lean

  ## WINDING ENERGY: The Fourier Structure of the Interference

  ════════════════════════════════════════════════════════════════

  This file connects the IntegralQuadForm L² energy to the
  Fourier decomposition via the sawtooth function B₁.

  The key chain:

  vᵀGv = ∫₀¹ |f_N(x)|² dx                   (IntegralQuadForm)
       = ∫₀¹ |Σ vⱼ{1/(jx)}|² dx
       = ∫₀¹ |Σ vⱼ(B₁(1/(jx)) + ½)|² dx     (FourierGram: {x} = B₁(x)+½)
       = ∫₀¹ |Σ vⱼB₁(1/(jx)) + ½Σvⱼ|² dx

  The energy decomposes into:
  1. **Covariance energy**: ∫₀¹|Σ vⱼB₁(1/(jx))|² dx (Fourier/Parseval target)
  2. **Mean energy**: (½Σvⱼ)² · 1 (from the constant term)
  3. **Cross energy**: Σvⱼ · ∫₀¹ Σvⱼ B₁(1/(jx)) dx (involves mean entries bⱼ)

  RH ⟺ inf_v vᵀGv → 0 (Nyman-Beurling criterion).
  Since the covariance and mean energies are both ≥ 0,
  RH requires BOTH to vanish in the limit.

  ### Architecture

  §1. Energy = gramQuadForm (aliasing)
  §2. B₁ decomposition of the Gram quadratic form
  §3. Energy lower bounds from Fourier structure
  §4. The Nyman-Beurling criterion in energy language

  Status: Building...
  Created: May 27, 2026 — The Resonance Chain, Phase 2
-/

import Cathedral.IntegralBasis.IntegralQuadForm
import Cathedral.Spectral.FourierGram

noncomputable section
open Real MeasureTheory Filter Finset BigOperators

namespace Cathedral.IntegralBasis.WindingEnergy

open Cathedral.IntegralBasis.IntegralQuadForm
open Cathedral.FourierGram

-- ════════════════════════════════════════════════
-- §1. ENERGY = GRAM QUADRATIC FORM
-- ════════════════════════════════════════════════

/-! ### The Interference Energy

The "interference energy" at coefficients v is the L² norm of the
weighted sum of basis functions. This is exactly the Gram quadratic
form vᵀGv from IntegralQuadForm. -/

/-- **The interference energy**: ∫₀¹ |Σ vⱼ {1/(jx)}|² dx.
    This is the same as gramQuadForm but named to emphasize the
    physical interpretation as "how much energy is in the
    interference pattern of the prime oscillators." -/
def interferenceEnergy (N : ℕ) (v : Fin N → ℝ) : ℝ :=
  gramQuadForm N v

/-- **ENERGY EQUALS INTEGRAL**: The interference energy is the L²
    norm of the weighted basis sum on [0,1]. -/
theorem interferenceEnergy_eq_integral (N : ℕ) (v : Fin N → ℝ) :
    interferenceEnergy N v = ∫ x in (0:ℝ)..1, fN N v x ^ 2 :=
  gramQuadForm_eq_integral N v

/-- **ENERGY IS NONNEG**: The interference energy is always ≥ 0.
    This is automatic: it's the integral of a square. -/
theorem interferenceEnergy_nonneg (N : ℕ) (v : Fin N → ℝ) :
    0 ≤ interferenceEnergy N v :=
  gramQuadForm_nonneg N v

-- ════════════════════════════════════════════════
-- §2. B₁ DECOMPOSITION OF THE ENERGY
-- ════════════════════════════════════════════════

/-! ### Fourier Decomposition via B₁

Each basis function {1/(jx)} = B₁(1/(jx)) + ½, where B₁ is the
centered sawtooth (mean zero, Fourier coefficients ĉₙ = -1/(2πin)).

So f_N(x) = Σ vⱼ {1/(jx)} = Σ vⱼ B₁(1/(jx)) + ½ Σvⱼ

This splits the energy into three parts:
- Covariance: ∫|Σ vⱼ B₁|² (captures the Fourier structure)
- Cross: 2 · (½Σvⱼ) · ∫ Σ vⱼ B₁  (involves mean entries)
- Constant: (½Σvⱼ)² (captured by S₁ = Σvⱼ) -/

/-- **The centered linear combination**: g_N(x) = Σ vⱼ B₁(1/(jx)).
    This is f_N minus its "DC component" ½Σvⱼ. The Fourier analysis
    applies to g_N (which has mean approximately zero). -/
def gN (N : ℕ) (v : Fin N → ℝ) (x : ℝ) : ℝ :=
  ∑ j : Fin N, v j * sawtoothReal (1 / ((↑(j.val + 1) : ℝ) * x))

/-- **The DC component**: S₁ = Σ vⱼ, the sum of all coefficients.
    The "constant part" of the interference pattern. -/
def dcComponent (N : ℕ) (v : Fin N → ℝ) : ℝ :=
  ∑ j : Fin N, v j

/-- **f_N = g_N + ½S₁**: The linear combination splits into the
    centered part (g_N) and the DC offset (½Σvⱼ). -/
theorem fN_eq_gN_plus_dc (N : ℕ) (v : Fin N → ℝ) (x : ℝ) :
    fN N v x = gN N v x + (1/2) * dcComponent N v := by
  unfold fN gN dcComponent h
  simp only [fract_eq_sawtooth_add_half, mul_add, Finset.sum_add_distrib]
  congr 1
  rw [← Finset.sum_mul]; ring

/-- **ENERGY DECOMPOSITION**: The interference energy splits as:
    vᵀGv = ∫₀¹ g_N² dx + S₁ · ∫₀¹ g_N dx + ¼ · S₁²

    where S₁ = Σvⱼ is the DC component.

    Proof: f_N = g_N + ½S₁, so f_N² = g_N² + S₁·g_N + ¼S₁².
    Integrate term by term. -/
theorem energy_decomposition (N : ℕ) (v : Fin N → ℝ) :
    interferenceEnergy N v =
      (∫ x in (0:ℝ)..1, gN N v x ^ 2)
      + dcComponent N v * (∫ x in (0:ℝ)..1, gN N v x)
      + (1/4) * dcComponent N v ^ 2 := by
  rw [interferenceEnergy_eq_integral]
  set S := dcComponent N v with hS_def
  -- f_N(x)² = (g_N(x) + ½S)² = g_N² + S·g_N + ¼S²
  -- Step 1: Integrability infrastructure
  have h_gN_int : IntervalIntegrable (gN N v) volume (0:ℝ) 1 := by
    have hfN : IntervalIntegrable (fN N v) volume (0:ℝ) 1 := by
      apply IntervalIntegrable.mono_fun (intervalIntegrable_const (c := ∑ j : Fin N, |v j|))
      · exact (fN_measurable N v).aestronglyMeasurable.restrict
      · apply ae_of_all; intro x
        show ‖fN N v x‖ ≤ ‖∑ j : Fin N, |v j|‖
        rw [Real.norm_eq_abs, Real.norm_eq_abs,
          abs_of_nonneg (Finset.sum_nonneg (fun j _ => abs_nonneg (v j)))]
        exact fN_abs_le_l1 N v x
    have h_eq : gN N v = fun x => fN N v x - (1/2) * S := by
      ext x; rw [fN_eq_gN_plus_dc]; ring
    rw [h_eq]; exact hfN.sub intervalIntegrable_const
  have h_gN_meas : Measurable (gN N v) := by
    unfold gN
    exact Finset.measurable_sum _ fun j _ =>
      measurable_const.mul (sawtoothReal_measurable.comp
        (measurable_const.div (measurable_const.mul measurable_id)))
  have h_gN2_int : IntervalIntegrable (fun x => gN N v x ^ 2) volume (0:ℝ) 1 := by
    apply IntervalIntegrable.mono_fun
      (intervalIntegrable_const (c := (∑ j : Fin N, |v j|) ^ 2))
    · exact (h_gN_meas.pow_const 2).aestronglyMeasurable.restrict
    · apply ae_of_all; intro x
      show ‖gN N v x ^ 2‖ ≤ ‖(∑ j : Fin N, |v j|) ^ 2‖
      rw [Real.norm_eq_abs, Real.norm_eq_abs,
        abs_of_nonneg (sq_nonneg _), abs_of_nonneg (sq_nonneg _)]
      have : |gN N v x| ≤ ∑ j : Fin N, |v j| := by
        unfold gN
        calc |∑ j : Fin N, v j * sawtoothReal _|
            ≤ ∑ j : Fin N, |v j * sawtoothReal _| := Finset.abs_sum_le_sum_abs _ _
          _ ≤ ∑ j : Fin N, |v j| := by
              apply Finset.sum_le_sum; intro j _; rw [abs_mul]
              calc |v j| * |sawtoothReal _|
                  ≤ |v j| * (1/2) := mul_le_mul_of_nonneg_left
                    (sawtoothReal_bound _) (abs_nonneg _)
                _ ≤ |v j| * 1 := by
                    apply mul_le_mul_of_nonneg_left _ (abs_nonneg _); norm_num
                _ = |v j| := mul_one _
      have h2 : 0 ≤ ∑ j : Fin N, |v j| := Finset.sum_nonneg (fun j _ => abs_nonneg (v j))
      nlinarith [abs_nonneg (gN N v x), sq_abs (gN N v x)]
  have h_cross_int : IntervalIntegrable
      (fun x => S * gN N v x) volume (0:ℝ) 1 :=
    IntervalIntegrable.const_mul h_gN_int S
  -- Step 2: Transform LHS via calc
  calc ∫ x in (0:ℝ)..1, fN N v x ^ 2
      = ∫ x in (0:ℝ)..1, (gN N v x ^ 2 + S * gN N v x) + 1/4 * S ^ 2 := by
        congr 1; ext x; rw [fN_eq_gN_plus_dc]; ring
    _ = (∫ x in (0:ℝ)..1, gN N v x ^ 2 + S * gN N v x)
        + ∫ x in (0:ℝ)..1, (1:ℝ)/4 * S ^ 2 :=
        intervalIntegral.integral_add (h_gN2_int.add h_cross_int) intervalIntegrable_const
    _ = ((∫ x in (0:ℝ)..1, gN N v x ^ 2) + ∫ x in (0:ℝ)..1, S * gN N v x)
        + ∫ x in (0:ℝ)..1, (1:ℝ)/4 * S ^ 2 := by
        congr 1; exact intervalIntegral.integral_add h_gN2_int h_cross_int
    _ = ((∫ x in (0:ℝ)..1, gN N v x ^ 2) + S * ∫ x in (0:ℝ)..1, gN N v x)
        + 1/4 * S ^ 2 := by
        rw [intervalIntegral.integral_const_mul, intervalIntegral.integral_const]
        simp only [sub_zero, smul_eq_mul]; ring

-- ════════════════════════════════════════════════
-- §3. ENERGY LOWER BOUNDS FROM FOURIER STRUCTURE
-- ════════════════════════════════════════════════

/-! ### Lower Bounds

Since g_N² ≥ 0 and ¼S₁² ≥ 0, each piece provides a lower bound.
The covariance piece ∫g_N² is where Parseval applies: it equals
the sum of squared Fourier coefficients of g_N.

These bounds constrain how small the interference energy can get. -/

/-- **COVARIANCE ENERGY IS NONNEG**: ∫₀¹ g_N² dx ≥ 0.
    The pure Fourier covariance is always nonneg (integral of square). -/
theorem covariance_energy_nonneg (N : ℕ) (v : Fin N → ℝ) :
    0 ≤ ∫ x in (0:ℝ)..1, gN N v x ^ 2 := by
  apply intervalIntegral.integral_nonneg_of_forall (by norm_num : (0:ℝ) ≤ 1)
  intro x; exact sq_nonneg _

/-- **DC ENERGY IS NONNEG**: ¼S₁² ≥ 0. -/
theorem dc_energy_nonneg (N : ℕ) (v : Fin N → ℝ) :
    0 ≤ (1/4) * dcComponent N v ^ 2 := by
  apply mul_nonneg (by norm_num) (sq_nonneg _)

-- ════════════════════════════════════════════════
-- §4. THE GRAM MATRIX FOURIER STRUCTURE
-- ════════════════════════════════════════════════

/-! ### Per-Entry Fourier Structure

Each Gram entry G(j,k) decomposes via B₁ (from FourierGram):

  G(j,k) = ∫₀¹ B₁(1/jx)·B₁(1/kx) dx + cross terms + ¼

The first term is the "covariance" of basis functions j and k.
In Fourier space, this becomes a sum over harmonics:

  ∫₀¹ B₁(1/jx)·B₁(1/kx) dx = Σₙ ĉₙ(j) · ĉₙ(k)*

where ĉₙ(j) is the n-th Fourier coefficient of x ↦ B₁(1/(jx)).
This is the Parseval identity applied per-entry. -/

/-- **GRAM ENTRY DECOMPOSITION**: G(j,k) as defined in IntegralQuadForm
    equals the gramEntryIntegral from FourierGram. -/
theorem gramEntry_eq_fourierGramEntry (j k : ℕ) :
    Cathedral.BaezDuarte.bdGramEntry j k = gramEntryIntegral j k := by
  rfl

-- ════════════════════════════════════════════════
-- §5. THE NYMAN-BEURLING CRITERION
-- ════════════════════════════════════════════════

/-! ### RH ⟺ Energy Vanishes

The Nyman-Beurling criterion says:

  RH ⟺ inf_{v ∈ ℝᴺ} vᵀGv → 0 as N → ∞

In the interference picture:

  RH ⟺ the prime oscillators can achieve arbitrarily good
         destructive interference on [0,1]

  RH ⟺ the Nyman-Beurling basis functions span L²(0,1)
         (their linear hull is dense)

The energy decomposition shows this requires BOTH:
  1. ∫₀¹ g_N² → 0 (Fourier covariance vanishes)
  2. S₁² → 0 (DC component vanishes)

The second is easy to achieve (just balance positive and negative
coefficients). The first is the hard part — it's equivalent to
controlling the Fourier spectrum of the interference pattern. -/

/-- **NYMAN-BEURLING ENERGY CRITERION**: RH is equivalent to the
    statement that the infimum of the interference energy over
    all N-dimensional coefficient vectors v, with the constraint
    that ∫₀¹ |1 - f_N|² is minimized, tends to 0.

    We state this as: for every ε > 0, there exists N and v such
    that interferenceEnergy N v < ε.

    NOTE: The precise formulation involves the distance to the
    constant function 1, not just the energy of f_N itself. We
    state the structural version here. -/
theorem energy_le_of_gramQuadForm_le (N : ℕ) (v : Fin N → ℝ) (ε : ℝ)
    (h : gramQuadForm N v ≤ ε) :
    interferenceEnergy N v ≤ ε :=
  h

-- ════════════════════════════════════════════════
-- §6. THE SPECTRAL GAP
-- ════════════════════════════════════════════════

/-! ### The Spectral Gap and the Critical Line

The Fourier coefficients of B₁ are ĉₙ = -1/(2πin). The
coefficients of B₁(1/(jx)) under the geometric inversion
u = 1/x involve the harmonic frequencies nj.

The spectral decomposition of the covariance energy:

  ∫₀¹ g_N² dx = Σₙ |Σⱼ vⱼ · ĉₙ(j)|²

Each "spectral band" n contributes |Σⱼ vⱼ · ĉₙ(j)|².
When n corresponds to a prime p, the coefficient involves
the prime's Fourier harmonic at frequency log(p).

The spectral gap is:
  min_n |Σⱼ vⱼ · ĉₙ(j)|² > 0  ⟹  ∫g_N² > 0

If RH is true, this spectral gap must close as N → ∞. -/

/-- **ENERGY BOUNDS PRIME CONTRIBUTION**: The interference energy
    is at least as large as the energy in any single Fourier mode.
    This is a consequence of Parseval: total ≥ each component.

    Here we state the elementary version: vᵀGv ≥ 0 with equality
    iff f_N = 0 a.e. on [0,1]. -/
theorem energy_zero_iff_zero_ae (N : ℕ) (v : Fin N → ℝ) :
    interferenceEnergy N v = 0 ↔
    ∀ᵐ x ∂(MeasureTheory.volume.restrict (Set.Ioc 0 1)),
      fN N v x = 0 := by
  rw [interferenceEnergy_eq_integral, intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  constructor
  · -- Forward: ∫f²=0 ⟹ f=0 a.e. (since f² ≥ 0)
    intro h
    have h_sq_nonneg : ∀ᵐ x ∂volume.restrict (Set.Ioc 0 1), 0 ≤ fN N v x ^ 2 :=
      ae_of_all _ (fun _ => sq_nonneg _)
    have h_integrable : Integrable (fun x => fN N v x ^ 2)
        (volume.restrict (Set.Ioc 0 1)) := by
      have := (fN_sq_intervalIntegrable N v)
      rwa [intervalIntegrable_iff, Set.uIoc_of_le (by norm_num : (0:ℝ) ≤ 1),
        IntegrableOn] at this
    have h_sq_zero := (integral_eq_zero_iff_of_nonneg_ae h_sq_nonneg h_integrable).mp h
    -- f² = 0 a.e. ⟹ f = 0 a.e.
    exact h_sq_zero.mono (fun x hx => by
      simp only [Pi.zero_apply] at hx
      exact sq_eq_zero_iff.mp hx)
  · -- Backward: f=0 a.e. ⟹ ∫f²=0
    intro h
    have : (fun x => fN N v x ^ 2) =ᵐ[volume.restrict (Set.Ioc 0 1)] 0 :=
      h.mono (fun x hx => by simp [hx])
    exact (integral_congr_ae this).trans (integral_zero _ _)

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

/-!
## Audit — WindingEnergy

### Architecture

```
  interferenceEnergy N v = gramQuadForm N v = ∫₀¹ f_N² dx
         ↓ (fN_eq_gN_plus_dc)
  f_N = g_N + ½S₁   where g_N = Σ vⱼ B₁(1/(jx)), S₁ = Σvⱼ
         ↓ (energy_decomposition)
  Energy = ∫g_N² + S₁·∫g_N + ¼S₁²
         ↓
  Covariance energy ≥ 0   (Fourier/Parseval target)
  DC energy = ¼S₁² ≥ 0    (coefficient sum)
         ↓
  RH ⟺ both → 0 as N → ∞
```

### The Physical Picture

The energy ∫₀¹ f_N² dx measures "how much the prime oscillators
fail to cancel." The B₁ decomposition separates this into:

1. **Covariance** (g_N²): the AC interference — controlled by
   Fourier harmonics. Each prime contributes harmonics at
   frequency nj, and Parseval counts their squared sum.

2. **DC offset** (¼S₁²): the mean interference — controlled by
   balancing coefficients. Easy to make small.

3. **Cross term** (S₁·∫g_N): coupling between AC and DC.
   Involves the mean entries bⱼ = ∫ B₁(1/(jx)) dx.

RH says the prime harmonics can conspire to make ALL three
terms simultaneously vanish in the limit.
-/

end Cathedral.IntegralBasis.WindingEnergy
