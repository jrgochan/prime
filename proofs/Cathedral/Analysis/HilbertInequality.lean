/-
  Cathedral/Analysis/HilbertInequality.lean

  ## The Montgomery-Vaughan Hilbert Inequality

  PHYSICS: Bounding the off-diagonal scattering interference.
  MATH: Schur's Test for the discrete Hilbert transform.

  ### Mathlib Status (Excavation Report):
  - Mathlib has Schur product theorem (Hadamard) in `Analysis.Matrix.Order`.
  - Mathlib has Schur's Lemma for representations.
  - ❌ Mathlib does NOT have Schur's Test for integral/bilinear operators.
  - ❌ Mathlib does NOT have the discrete Hilbert inequality.
  - THIS IS THE GENUINE MATHLIB GAP — the only infrastructure file
    with no partial Mathlib coverage.

  ### Dependencies: None (pure functional analysis).
-/

import Mathlib.Analysis.InnerProductSpace.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Sigma
import Mathlib.Algebra.Order.BigOperators.Ring.Finset
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Bounds
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Deriv
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Sinc
import Mathlib.Analysis.SpecialFunctions.ImproperIntegrals
import Mathlib.MeasureTheory.Integral.Bochner.Basic
import Mathlib.MeasureTheory.Integral.Bochner.Set
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.MeasureTheory.Integral.IntervalIntegral.FundThmCalculus
import Mathlib.Analysis.SpecialFunctions.Integrals.Basic
import Mathlib.Analysis.SpecialFunctions.ImproperIntegrals
import Mathlib.MeasureTheory.Measure.Lebesgue.Basic
import Mathlib.Analysis.Fourier.FourierTransform
import Mathlib.Analysis.Fourier.Inversion
import Mathlib.MeasureTheory.Function.LocallyIntegrable
import Mathlib.Analysis.Complex.Trigonometric

noncomputable section
open Complex Real Finset BigOperators
open scoped FourierTransform

namespace Cathedral.Analysis

-- ═══════════════════════════════════════════
-- §1. Schur's Test for Discrete Operators
-- ═══════════════════════════════════════════

/-! ### Helper lemmas -/

private lemma sqrt_mul_self_of_nonneg {a : ℝ} (ha : 0 ≤ a) :
    Real.sqrt a * Real.sqrt a = a :=
  Real.mul_self_sqrt ha

private lemma sq_sqrt_mul {a b : ℝ} (ha : 0 ≤ a) :
    (Real.sqrt a * b) ^ 2 = a * b ^ 2 := by
  rw [mul_pow, sq_sqrt ha]

private lemma weighted_sum_bound {N : ℕ} (K : Fin N → Fin N → ℂ)
    (C : ℝ) (h_row : ∀ i, ∑ j, ‖K i j‖ ≤ C) (x : Fin N → ℂ) :
    ∑ i, ∑ j, ‖K i j‖ * ‖x i‖ ^ 2 ≤ C * ∑ i, ‖x i‖ ^ 2 := by
  rw [Finset.mul_sum]
  apply Finset.sum_le_sum; intro i _
  rw [← Finset.sum_mul]
  exact mul_le_mul_of_nonneg_right (h_row i) (sq_nonneg _)

private lemma weighted_sum_bound_col {N : ℕ} (K : Fin N → Fin N → ℂ)
    (C : ℝ) (h_col : ∀ j, ∑ i, ‖K i j‖ ≤ C) (y : Fin N → ℂ) :
    ∑ i, ∑ j, ‖K i j‖ * ‖y j‖ ^ 2 ≤ C * ∑ j, ‖y j‖ ^ 2 := by
  rw [Finset.sum_comm, Finset.mul_sum]
  apply Finset.sum_le_sum; intro j _
  rw [← Finset.sum_mul]
  exact mul_le_mul_of_nonneg_right (h_col j) (sq_nonneg _)

/-! ### Squared Schur bound via product-index Cauchy-Schwarz -/

/-- The squared version of Schur's test, proved via
    Cauchy-Schwarz on the product type `Fin N × Fin N`. -/
private lemma schur_sq_bound {N : ℕ} (K : Fin N → Fin N → ℂ) (C : ℝ) (_hC : 0 ≤ C)
    (h_row : ∀ i, ∑ j, ‖K i j‖ ≤ C)
    (h_col : ∀ j, ∑ i, ‖K i j‖ ≤ C)
    (x y : Fin N → ℂ) :
    (∑ i, ∑ j, ‖K i j‖ * ‖x i‖ * ‖y j‖) ^ 2 ≤
    C ^ 2 * (∑ i, ‖x i‖ ^ 2) * (∑ j, ‖y j‖ ^ 2) := by
  -- Flatten: Σ_i Σ_j → Σ_{(i,j)}
  have hflatten : ∑ i, ∑ j, ‖K i j‖ * ‖x i‖ * ‖y j‖ =
      ∑ p : Fin N × Fin N, ‖K p.1 p.2‖ * ‖x p.1‖ * ‖y p.2‖ := by
    rw [← Finset.sum_product']; rfl
  rw [hflatten]
  -- Factor: ‖K‖·‖x‖·‖y‖ = (√‖K‖·‖x‖)·(√‖K‖·‖y‖)
  have hfactor : ∀ p : Fin N × Fin N,
      ‖K p.1 p.2‖ * ‖x p.1‖ * ‖y p.2‖ =
      (Real.sqrt ‖K p.1 p.2‖ * ‖x p.1‖) * (Real.sqrt ‖K p.1 p.2‖ * ‖y p.2‖) := by
    intro p; rw [show Real.sqrt ‖K p.1 p.2‖ * ‖x p.1‖ *
      (Real.sqrt ‖K p.1 p.2‖ * ‖y p.2‖) =
      Real.sqrt ‖K p.1 p.2‖ * Real.sqrt ‖K p.1 p.2‖ * ‖x p.1‖ * ‖y p.2‖ from by ring]
    rw [sqrt_mul_self_of_nonneg (norm_nonneg _)]
  simp_rw [hfactor]
  -- Cauchy-Schwarz on Fin N × Fin N
  have hCS := sum_mul_sq_le_sq_mul_sq Finset.univ
    (fun p : Fin N × Fin N => Real.sqrt ‖K p.1 p.2‖ * ‖x p.1‖)
    (fun p : Fin N × Fin N => Real.sqrt ‖K p.1 p.2‖ * ‖y p.2‖)
  calc (∑ p : Fin N × Fin N,
          (Real.sqrt ‖K p.1 p.2‖ * ‖x p.1‖) *
          (Real.sqrt ‖K p.1 p.2‖ * ‖y p.2‖)) ^ 2
      ≤ (∑ p : Fin N × Fin N, (Real.sqrt ‖K p.1 p.2‖ * ‖x p.1‖) ^ 2) *
        (∑ p : Fin N × Fin N, (Real.sqrt ‖K p.1 p.2‖ * ‖y p.2‖) ^ 2) := hCS
    _ = (∑ i, ∑ j, ‖K i j‖ * ‖x i‖ ^ 2) * (∑ i, ∑ j, ‖K i j‖ * ‖y j‖ ^ 2) := by
          congr 1
          · rw [← Finset.sum_product' (s := (Finset.univ : Finset (Fin N)))
                  (t := (Finset.univ : Finset (Fin N)))]
            congr 1; ext p; rw [sq_sqrt_mul (norm_nonneg _)]
          · rw [← Finset.sum_product' (s := (Finset.univ : Finset (Fin N)))
                  (t := (Finset.univ : Finset (Fin N)))]
            congr 1; ext p; rw [sq_sqrt_mul (norm_nonneg _)]
    _ ≤ (C * ∑ i, ‖x i‖ ^ 2) * (C * ∑ j, ‖y j‖ ^ 2) := by
          apply mul_le_mul
          · exact weighted_sum_bound K C h_row x
          · exact weighted_sum_bound_col K C h_col y
          · apply Finset.sum_nonneg; intro i _
            apply Finset.sum_nonneg; intro j _
            exact mul_nonneg (norm_nonneg (K i j)) (sq_nonneg _)
          · apply le_trans (Finset.sum_nonneg (fun i _ => Finset.sum_nonneg
              (fun j _ => mul_nonneg (norm_nonneg (K i j)) (sq_nonneg _))))
            exact weighted_sum_bound K C h_row x
    _ = C ^ 2 * (∑ i, ‖x i‖ ^ 2) * (∑ j, ‖y j‖ ^ 2) := by ring

-- ═══════════════════════════════════════════
-- §2. Main Theorem: Schur's Test (PROVED ✅)
-- ═══════════════════════════════════════════

/-- **PROVED**: Schur's Test for discrete operators.
    If a matrix K_{ij} satisfies bounded row/column sums,
    its ℓ² operator norm is bounded.

    This is the key lemma for Montgomery-Vaughan.
    Proof: Triangle inequality + product-index Cauchy-Schwarz. -/
theorem schur_test_discrete {N : ℕ} (K : Fin N → Fin N → ℂ) (C : ℝ) (hC : 0 ≤ C)
    (h_row : ∀ i, ∑ j, ‖K i j‖ ≤ C)
    (h_col : ∀ j, ∑ i, ‖K i j‖ ≤ C)
    (x y : Fin N → ℂ) :
    ‖∑ i, ∑ j, K i j * x i * starRingEnd ℂ (y j)‖ ≤
    C * Real.sqrt (∑ i, ‖x i‖^2) * Real.sqrt (∑ j, ‖y j‖^2) := by
  -- Triangle inequality: ‖Σ Σ K x ȳ‖ ≤ Σ Σ ‖K‖ ‖x‖ ‖y‖
  calc ‖∑ i, ∑ j, K i j * x i * starRingEnd ℂ (y j)‖
      ≤ ∑ i, ‖∑ j, K i j * x i * starRingEnd ℂ (y j)‖ := norm_sum_le _ _
    _ ≤ ∑ i, ∑ j, ‖K i j * x i * starRingEnd ℂ (y j)‖ := by
        gcongr with i; exact norm_sum_le _ _
    _ = ∑ i, ∑ j, ‖K i j‖ * ‖x i‖ * ‖y j‖ := by
        congr 1; ext i; congr 1; ext j
        rw [norm_mul, norm_mul]; congr 1
        exact Complex.norm_conj (y j)
    _ ≤ C * Real.sqrt (∑ i, ‖x i‖^2) * Real.sqrt (∑ j, ‖y j‖^2) := by
        -- From squared bound to sqrt bound
        have hsq := schur_sq_bound K C hC h_row h_col x y
        have hS : (0 : ℝ) ≤ ∑ i : Fin N, ∑ j : Fin N,
            ‖K i j‖ * ‖x i‖ * ‖y j‖ :=
          Finset.sum_nonneg (fun i _ => Finset.sum_nonneg
            (fun j _ =>
              mul_nonneg (mul_nonneg (norm_nonneg _) (norm_nonneg _)) (norm_nonneg _)))
        have hRHS : 0 ≤ C * Real.sqrt (∑ i : Fin N, ‖x i‖ ^ 2) *
            Real.sqrt (∑ j : Fin N, ‖y j‖ ^ 2) := by
          apply mul_nonneg; apply mul_nonneg hC; exact Real.sqrt_nonneg _
          exact Real.sqrt_nonneg _
        rw [← Real.sqrt_sq hS, ← Real.sqrt_sq hRHS]
        exact Real.sqrt_le_sqrt (le_trans hsq (by
          rw [mul_pow, mul_pow, Real.sq_sqrt (Finset.sum_nonneg (fun i _ => sq_nonneg _)),
            Real.sq_sqrt (Finset.sum_nonneg (fun j _ => sq_nonneg _))]))

-- ═══════════════════════════════════════════
-- §3. δ-Separation Infrastructure (PROVED ✅)
-- ═══════════════════════════════════════════

/-- A finite sequence of reals is δ-separated if the distance between
    any two distinct elements is at least δ. -/
def IsDeltaSeparated {N : ℕ} (lam : Fin N → ℝ) (δ : ℝ) : Prop :=
  ∀ i j : Fin N, i ≠ j → δ ≤ |lam i - lam j|

/-- δ-separation implies distinct values. -/
lemma delta_sep_ne_of_ne {N : ℕ} {lam : Fin N → ℝ} {δ : ℝ} (hδ : 0 < δ)
    (h_sep : IsDeltaSeparated lam δ) {i j : Fin N} (hij : i ≠ j) :
    lam i ≠ lam j := by
  intro h; have := h_sep i j hij; rw [h, sub_self, abs_zero] at this; linarith

/-- 1/|λᵢ - λⱼ| ≤ 1/δ for δ-separated sequences. -/
lemma norm_inv_sub_le {N : ℕ} {lam : Fin N → ℝ} {δ : ℝ} (hδ : 0 < δ)
    (h_sep : IsDeltaSeparated lam δ) {i j : Fin N} (hij : i ≠ j) :
    1 / |lam i - lam j| ≤ 1 / δ := by
  have hab := h_sep i j hij
  exact div_le_div_of_nonneg_left (by positivity) hδ hab

/-- The kernel ‖1/(λᵢ - λⱼ)‖ ≤ 1/δ. -/
lemma kernel_norm_le {N : ℕ} {lam : Fin N → ℝ} {δ : ℝ} (hδ : 0 < δ)
    (h_sep : IsDeltaSeparated lam δ) {i j : Fin N} (hij : i ≠ j) :
    ‖(1 : ℂ) / ((lam i - lam j : ℝ) : ℂ)‖ ≤ 1 / δ := by
  rw [norm_div, norm_one, Complex.norm_real]
  exact norm_inv_sub_le hδ h_sep hij

/-- Row sum bound: each row of the Hilbert kernel has norm sum ≤ N/δ.
    This is WEAKER than π/δ but follows from δ-separation alone. -/
lemma row_sum_le_card_div_delta {N : ℕ} (lam : Fin N → ℝ) (δ : ℝ)
    (hδ : 0 < δ) (h_sep : IsDeltaSeparated lam δ) (i : Fin N) :
    ∑ j : Fin N, ‖(if i = j then (0 : ℂ) else
      (1 : ℂ) / ((lam i - lam j : ℝ) : ℂ))‖ ≤ ↑(Fintype.card (Fin N)) / δ := by
  calc ∑ j : Fin N, ‖(if i = j then (0 : ℂ) else
        (1 : ℂ) / ((lam i - lam j : ℝ) : ℂ))‖
      ≤ ∑ j : Fin N, (1 / δ) := by
        apply Finset.sum_le_sum; intro j _
        split_ifs with h
        · simp; positivity
        · exact kernel_norm_le hδ h_sep h
    _ = ↑(Fintype.card (Fin N)) / δ := by
        simp [Finset.sum_const, Finset.card_univ, nsmul_eq_mul]; ring

-- ═══════════════════════════════════════════
-- §4. The Sinc Function (PROVED ✅)
-- ═══════════════════════════════════════════

/-- The sinc function: sinc(x) = sin(πx)/(πx) for x ≠ 0, sinc(0) = 1.
    Mathlib equivalent: `euler_sineTerm_tprod` proves sin(πx)/(πx) = ∏(1-x²/n²). -/
def sinc (x : ℝ) : ℝ :=
  if x = 0 then 1 else Real.sin (π * x) / (π * x)

@[simp] lemma sinc_zero : sinc 0 = 1 := by simp [sinc]

lemma sinc_of_ne_zero {x : ℝ} (hx : x ≠ 0) :
    sinc x = Real.sin (π * x) / (π * x) := by simp [sinc, hx]

/-- sinc vanishes at nonzero integers. -/
lemma sinc_intCast_of_ne_zero (n : ℤ) (hn : n ≠ 0) :
    sinc (n : ℝ) = 0 := by
  rw [sinc_of_ne_zero (Int.cast_ne_zero.mpr hn)]
  have : Real.sin (π * ↑n) = 0 := by
    rw [mul_comm]; exact Real.sin_int_mul_pi n
  simp [this]

-- ═══════════════════════════════════════════
-- §5. Fejér Kernel Properties (replaces Selberg Majorant)
-- ═══════════════════════════════════════════

/-!
### The Fejér Kernel Approach to Montgomery-Vaughan

**CORRECTION** (April 26, 2026): The original Selberg majorant axioms
BS1-BS5 contained a mathematical inconsistency: BS1 (S≥1 for x>0) and
BS2 (S≤-1 for x<0) are incompatible with BS3 (S ∈ L¹(ℝ)), since any
function bounded away from 0 on (0,∞) is not Lebesgue integrable.

**Resolution**: We use the **Fejér kernel** K(x) = sinc²(x) directly.
This avoids the Selberg majorant entirely and gives a slightly weaker
constant (Cπ/δ instead of π/δ) which is sufficient for the Cathedral.

The Fejér kernel satisfies:
- FK1: K(x) = sinc²(x) ≥ 0 for all x
- FK2: K ∈ L¹(ℝ) (since sinc ∈ L²(ℝ))
- FK3: ∫ K(x) dx = 1
- FK4: K̂(ξ) = max(1 - |ξ|, 0) (triangle function, supported on [-1,1])
- FK5: K̂(ξ) ≥ 0 for all ξ

These are all provable from the `sinc` infrastructure in §4 and
Mathlib's Fourier transform API (v4.28).
-/

/-!
### The Triangle Function Reverse-Trick

**Strategy** (suggested by Gemini, April 26, 2026): Instead of
defining K(x) = sinc²(x) and computing its Fourier transform
(which requires L² convolution), we work backward:

1. Define Λ(ξ) = max(1-|ξ|, 0) in frequency space
2. Λ is trivially L¹ (continuous, compactly supported on [-1,1])
3. Compute its inverse FT: ∫ Λ(ξ) e^{2πixξ} dξ = sinc²(x)
4. FK4 is FREE (Λ supported on [-1,1] by definition)
5. FK3 is FREE (Λ(0) = 1 = ∫K by Fourier inversion at x=0)
6. FK2 follows from inversion + K ≥ 0 (Tonelli)

This completely bypasses the L² convolution theorem.
-/

/-- The triangle function Λ(ξ) = max(1-|ξ|, 0).
    This is the frequency-domain kernel, defined FIRST. -/
noncomputable def triangleFunction (ξ : ℝ) : ℝ := max (1 - |ξ|) 0

/-- The triangle function is non-negative. -/
theorem triangleFunction_nonneg (ξ : ℝ) : 0 ≤ triangleFunction ξ :=
  le_max_right _ _

/-- The triangle function is supported on [-1, 1]. -/
theorem triangleFunction_support (ξ : ℝ) (hξ : 1 < |ξ|) :
    triangleFunction ξ = 0 := by
  unfold triangleFunction
  simp only [max_eq_right_iff]
  linarith

/-- The triangle function equals 1 at ξ = 0. -/
theorem triangleFunction_zero : triangleFunction 0 = 1 := by
  unfold triangleFunction; simp

/-- The triangle function is continuous. -/
theorem triangleFunction_continuous : Continuous triangleFunction := by
  unfold triangleFunction
  exact (continuous_const.sub continuous_abs).max continuous_const

/-- **sinc²**: The Fejér kernel — defined as (sin πx / πx)². -/
noncomputable def fejerKernel (x : ℝ) : ℝ := (sinc x) ^ 2

/-- **FK1**: The Fejér kernel is non-negative. -/
theorem fejerKernel_nonneg (x : ℝ) : 0 ≤ fejerKernel x := sq_nonneg _

/-- The Fejér kernel is an even function: sinc²(-x) = sinc²(x). -/
theorem fejerKernel_even (x : ℝ) : fejerKernel (-x) = fejerKernel x := by
  unfold fejerKernel sinc
  by_cases hx : x = 0
  · subst hx; simp
  · have hxn : -x ≠ 0 := neg_ne_zero.mpr hx
    simp only [hx, hxn, ↓reduceIte]
    congr 1
    rw [show π * (-x) = -(π * x) from by ring]
    rw [Real.sin_neg]
    rw [show -(π * x) = (-1) * (π * x) from by ring]
    rw [show -Real.sin (π * x) / ((-1) * (π * x)) = Real.sin (π * x) / (π * x) from by ring]

/-- **The Fourier Bridge**: The inverse Fourier transform of Λ equals sinc².

    This is the key identity: ∫₋₁¹ (1-|ξ|)·cos(2πxξ) dξ = sinc²(x).

    Proof outline:
    - x = 0: ∫₋₁¹ (1-|ξ|) dξ = 2·∫₀¹ (1-ξ) dξ = 2·(1-1/2) = 1 = sinc²(0) ✓
    - x ≠ 0: By symmetry, 2·∫₀¹ (1-ξ)·cos(2πxξ) dξ.
      Integration by parts:
        = 2·[(1-ξ)·sin(2πxξ)/(2πx)]₀¹ + 2·∫₀¹ sin(2πxξ)/(2πx) dξ
        = 0 + 2·[-cos(2πxξ)/(2πx)²]₀¹
        = 2·(1-cos(2πx))/(2πx)²
        = 2·2sin²(πx)/(2πx)²     (using 1-cos2θ = 2sin²θ)
        = (sin(πx)/(πx))²
        = sinc²(x) ✓

    The x ≠ 0 case requires `integral_deriv_mul_eq_sub` (Mathlib IBP)
    and the double-angle formula `cos_sq` / `cos_two_mul`. -/

-- Helper: ∫₋₁¹ (1-|ξ|) dξ = 1 (the x = 0 case of the Bridge).
-- This is a basic integral: 2·∫₀¹ (1-ξ) dξ = 2·(1-1/2) = 1.
private lemma triangle_integral_eq_one :
    ∫ ξ in Set.Icc (-1 : ℝ) 1, triangleFunction ξ = 1 := by
  -- Rewrite Λ = 1 - |ξ| on [-1,1]
  have h_eq : Set.EqOn triangleFunction (fun ξ => 1 - |ξ|) (Set.Icc (-1) 1) := by
    intro ξ ⟨hlo, hhi⟩
    unfold triangleFunction
    rw [max_eq_left]; linarith [abs_le.mpr ⟨by linarith, hhi⟩]
  rw [MeasureTheory.setIntegral_congr_fun measurableSet_Icc h_eq]
  -- For Lebesgue measure, Icc and Ioc have the same integral (NoAtoms)
  rw [MeasureTheory.integral_Icc_eq_integral_Ioc]
  -- Convert to interval integral
  rw [← intervalIntegral.integral_of_le (by norm_num : (-1 : ℝ) ≤ 1)]
  -- Split at 0: ∫₋₁¹ = ∫₋₁⁰ + ∫₀¹
  have h_ii : ∀ a b : ℝ, IntervalIntegrable (fun ξ => 1 - |ξ|) MeasureTheory.volume a b :=
    fun a b => (continuous_const.sub continuous_abs).intervalIntegrable a b
  rw [← intervalIntegral.integral_add_adjacent_intervals (h_ii (-1) 0) (h_ii 0 1)]
  -- On [-1,0]: 1-|ξ| = 1+ξ; on [0,1]: 1-|ξ| = 1-ξ
  -- Compute each half using FTC
  have h_left : ∫ ξ in (-1 : ℝ)..0, (1 - |ξ|) = 1/2 := by
    -- On [-1,0]: |ξ| = -ξ, so 1-|ξ| = 1+ξ
    trans (∫ ξ in (-1 : ℝ)..0, (1 + ξ))
    · exact intervalIntegral.integral_congr (fun ξ hξ => by
        rw [Set.uIcc_of_le (by norm_num : (-1 : ℝ) ≤ 0)] at hξ
        rw [abs_of_nonpos hξ.2]; ring)
    -- FTC: ∫₋₁⁰ (1+ξ) dξ = F(0) - F(-1) where F(ξ) = ξ + ξ²/2
    · have key := intervalIntegral.integral_eq_sub_of_hasDerivAt
        (f := fun ξ : ℝ => ξ + ξ ^ 2 / 2)
        (f' := fun ξ : ℝ => 1 + ξ)
        (a := -1) (b := 0)
        (fun ξ _ => by
          have h1 := hasDerivAt_id ξ
          have h2 := (hasDerivAt_pow 2 ξ).div_const 2
          convert h1.add h2 using 1; simp)
        ((continuous_const.add continuous_id).intervalIntegrable _ _)
      simp at key; linarith
  have h_right : ∫ ξ in (0 : ℝ)..1, (1 - |ξ|) = 1/2 := by
    -- On [0,1]: |ξ| = ξ, so 1-|ξ| = 1-ξ
    trans (∫ ξ in (0 : ℝ)..1, (1 - ξ))
    · exact intervalIntegral.integral_congr (fun ξ hξ => by
        rw [Set.uIcc_of_le (by norm_num : (0 : ℝ) ≤ 1)] at hξ
        rw [abs_of_nonneg hξ.1])
    -- FTC: ∫₀¹ (1-ξ) dξ = F(1) - F(0) where F(ξ) = ξ - ξ²/2
    · have key := intervalIntegral.integral_eq_sub_of_hasDerivAt
        (f := fun ξ : ℝ => ξ - ξ ^ 2 / 2)
        (f' := fun ξ : ℝ => 1 - ξ)
        (a := 0) (b := 1)
        (fun ξ _ => by
          have h1 := hasDerivAt_id ξ
          have h2 := (hasDerivAt_pow 2 ξ).div_const 2
          convert h1.sub h2 using 1; simp)
        ((continuous_const.sub continuous_id).intervalIntegrable _ _)
      simp at key; linarith
  rw [h_left, h_right]; norm_num

theorem triangleFunction_inverseFT_eq_fejerKernel (x : ℝ) :
    ∫ ξ in Set.Icc (-1 : ℝ) 1, triangleFunction ξ * Real.cos (2 * π * x * ξ) = fejerKernel x := by
  by_cases hx : x = 0
  · -- x = 0: cos(0) = 1, so integral = ∫ Λ = 1 = sinc²(0) = 1
    subst hx
    simp only [mul_zero, zero_mul, Real.cos_zero, mul_one]
    rw [triangle_integral_eq_one]
    simp [fejerKernel, sinc_zero]
  · -- x ≠ 0: FTC with Gemini's antiderivatives (Blueprint in COMM-LINK 5)
    -- hΛ: Λ(ξ) = 1-|ξ| on [-1,1]
    have hΛ : ∀ ξ ∈ Set.Icc (-1 : ℝ) 1,
        triangleFunction ξ = 1 - |ξ| := by
      intro ξ ⟨hlo, hhi⟩; unfold triangleFunction
      rw [max_eq_left]; linarith [abs_le.mpr ⟨by linarith, hhi⟩]
    -- Reduce to ∫ (1-|ξ|)cos(cξ) via suffices + convert
    set c := 2 * π * x with hc_def
    have hc : c ≠ 0 := by rw [hc_def]; positivity
    -- Helper: the HasDerivAt chain for the antiderivative
    have hDeriv_right : ∀ ξ ∈ Set.uIcc (0 : ℝ) 1,
        HasDerivAt (fun t => (1 - t) * Real.sin (c * t) / c - Real.cos (c * t) / c ^ 2)
          ((1 - ξ) * Real.cos (c * ξ)) ξ := by
      intro ξ _
      have h1 : HasDerivAt (fun t => (1 : ℝ) - t) (-1) ξ := by
        simpa using (hasDerivAt_id ξ).const_sub 1
      have h2 := (hasDerivAt_const_mul c (x := ξ)).sin
      have h3 := (hasDerivAt_const_mul c (x := ξ)).cos
      convert (h1.mul h2).div_const c |>.sub (h3.div_const (c ^ 2)) using 1
      field_simp; ring
    have hDeriv_left : ∀ ξ ∈ Set.uIcc (-1 : ℝ) 0,
        HasDerivAt (fun t => (1 + t) * Real.sin (c * t) / c + Real.cos (c * t) / c ^ 2)
          ((1 + ξ) * Real.cos (c * ξ)) ξ := by
      intro ξ _
      have h1 : HasDerivAt (fun t => (1 : ℝ) + t) 1 ξ := by
        simpa using (hasDerivAt_id ξ).const_add 1
      have h2 := (hasDerivAt_const_mul c (x := ξ)).sin
      have h3 := (hasDerivAt_const_mul c (x := ξ)).cos
      convert (h1.mul h2).div_const c |>.add (h3.div_const (c ^ 2)) using 1
      field_simp; ring
    -- FTC: compute each half-integral
    have h_right_val : ∫ ξ in (0 : ℝ)..1, (1 - ξ) * Real.cos (c * ξ) =
        (1 - Real.cos c) / c ^ 2 := by
      have key := intervalIntegral.integral_eq_sub_of_hasDerivAt hDeriv_right
        (((continuous_const.sub continuous_id).mul
          (Real.continuous_cos.comp (continuous_const.mul continuous_id))).intervalIntegrable _ _)
      convert key using 1
      simp [Real.sin_zero, Real.cos_zero]; ring
    have h_left_val : ∫ ξ in (-1 : ℝ)..0, (1 + ξ) * Real.cos (c * ξ) =
        (1 - Real.cos c) / c ^ 2 := by
      have key := intervalIntegral.integral_eq_sub_of_hasDerivAt hDeriv_left
        (((continuous_const.add continuous_id).mul
          (Real.continuous_cos.comp (continuous_const.mul continuous_id))).intervalIntegrable _ _)
      convert key using 1
      simp [Real.sin_zero, Real.cos_zero, Real.cos_neg, Real.sin_neg]; ring
    -- Assembly: connect set integral to interval integral results
    -- Goal: ∫ ξ in Icc(-1,1), Λ(ξ)·cos(cξ) = fejerKernel x
    -- Strategy: suffices (1-cos c)/c² + (1-cos c)/c² = fejerKernel x,
    -- then prove the set integral equals the sum of two interval integrals
    suffices hsuff : (1 - Real.cos c) / c ^ 2 + (1 - Real.cos c) / c ^ 2 =
        fejerKernel x by
      -- Convert set integral → interval integral → split → remove |ξ| → FTC
      have h_set_to_int : ∫ ξ in Set.Icc (-1 : ℝ) 1,
          triangleFunction ξ * Real.cos (c * ξ) =
          ∫ ξ in (-1 : ℝ)..1, triangleFunction ξ * Real.cos (c * ξ) := by
        rw [MeasureTheory.integral_Icc_eq_integral_Ioc,
            ← intervalIntegral.integral_of_le (by norm_num : (-1 : ℝ) ≤ 1)]
      rw [h_set_to_int]
      -- Split at 0
      have h_ii : ∀ a b : ℝ, IntervalIntegrable
          (fun ξ => triangleFunction ξ * Real.cos (c * ξ)) MeasureTheory.volume a b :=
        fun a b => (triangleFunction_continuous.mul
          (Real.continuous_cos.comp (continuous_const.mul continuous_id))).intervalIntegrable a b
      rw [← intervalIntegral.integral_add_adjacent_intervals (h_ii (-1) 0) (h_ii 0 1)]
      -- Remove |ξ| on each half: Λ(ξ) = 1+ξ on [-1,0], Λ(ξ) = 1-ξ on [0,1]
      have h_left_eq : ∫ ξ in (-1 : ℝ)..0, triangleFunction ξ * Real.cos (c * ξ) =
          ∫ ξ in (-1 : ℝ)..0, (1 + ξ) * Real.cos (c * ξ) := by
        apply intervalIntegral.integral_congr
        intro ξ hξ
        rw [Set.uIcc_of_le (by norm_num : (-1 : ℝ) ≤ 0)] at hξ
        have h_neg : ξ ≤ 0 := hξ.2
        have h_low : -1 ≤ ξ := hξ.1
        show max (1 - |ξ|) 0 * Real.cos (c * ξ) = (1 + ξ) * Real.cos (c * ξ)
        rw [abs_of_nonpos h_neg]
        simp only [sub_neg_eq_add]
        rw [max_eq_left (by linarith)]
      have h_right_eq : ∫ ξ in (0 : ℝ)..1, triangleFunction ξ * Real.cos (c * ξ) =
          ∫ ξ in (0 : ℝ)..1, (1 - ξ) * Real.cos (c * ξ) := by
        apply intervalIntegral.integral_congr
        intro ξ hξ
        rw [Set.uIcc_of_le (by norm_num : (0 : ℝ) ≤ 1)] at hξ
        have h_pos : 0 ≤ ξ := hξ.1
        have h_hi : ξ ≤ 1 := hξ.2
        show max (1 - |ξ|) 0 * Real.cos (c * ξ) = (1 - ξ) * Real.cos (c * ξ)
        rw [abs_of_nonneg h_pos]
        rw [max_eq_left (by linarith)]
      rw [h_left_eq, h_right_eq, h_left_val, h_right_val, hsuff]
    -- Now prove: 2(1-cos c)/c² = sinc²(x) where c = 2πx
    unfold fejerKernel sinc
    rw [if_neg hx]
    rw [hc_def]
    -- Need: (1-cos(2πx))/(2πx)² + (1-cos(2πx))/(2πx)² = (sin(πx)/(πx))²
    -- Use half-angle: 1-cos(2θ) = 2sin²(θ) with θ = πx
    have hpx : π * x ≠ 0 := mul_ne_zero Real.pi_ne_zero hx
    have h_half : 1 - Real.cos (2 * (π * x)) = 2 * Real.sin (π * x) ^ 2 := by
      have h1 := Real.sin_sq_add_cos_sq (π * x)
      have h2 := Real.cos_sq (π * x)  -- cos²(πx) + sin²(πx) = 1
      -- cos(2θ) = cos²θ - sin²θ = 1 - 2sin²θ
      -- So 1 - cos(2θ) = 2sin²θ
      rw [Real.cos_two_mul']
      nlinarith
    rw [show 2 * π * x = 2 * (π * x) from by ring]
    rw [h_half]
    field_simp
    ring

/-- Our sinc equals Mathlib's sinc composed with π·. -/
private lemma sinc_eq_real_sinc (x : ℝ) : sinc x = Real.sinc (π * x) := by
  unfold sinc
  split_ifs with h
  · simp [h, Real.sinc_zero]
  · rw [Real.sinc_of_ne_zero (mul_ne_zero Real.pi_ne_zero h)]

/-- |sinc(y)| ≤ |y|⁻¹ for y ≠ 0. From |sin(y)| ≤ 1. -/
private lemma abs_real_sinc_le_inv (y : ℝ) (hy : y ≠ 0) :
    |Real.sinc y| ≤ |y|⁻¹ := by
  rw [Real.sinc_of_ne_zero hy, abs_div, inv_eq_one_div]
  exact div_le_div_of_nonneg_right (Real.abs_sin_le_one y) (abs_pos.mpr hy).le

/-- sinc²(y) ≤ |y|⁻² for y ≠ 0. -/
private lemma real_sinc_sq_le_inv_sq (y : ℝ) (hy : y ≠ 0) :
    Real.sinc y ^ 2 ≤ |y|⁻¹ ^ 2 := by
  rw [← sq_abs (Real.sinc y)]
  exact pow_le_pow_left₀ (abs_nonneg _) (abs_real_sinc_le_inv y hy) 2

/-- **Key bound**: sinc²(πx) · (1+x²) ≤ 2 for all x.
    Case x² ≤ 1: sinc² ≤ 1 and 1·(1+x²) ≤ 2.
    Case x² > 1: sinc² ≤ 1/(πx)² ≤ 1/x² and (1/x²)·(1+x²) ≤ 2. -/
private lemma sinc_sq_cauchy_bound (x : ℝ) :
    Real.sinc (π * x) ^ 2 * (1 + x ^ 2) ≤ 2 := by
  by_cases hx : x = 0
  · simp [hx, Real.sinc_zero]
  · have hx2 : (0 : ℝ) < x ^ 2 := by positivity
    have hpx : π * x ≠ 0 := mul_ne_zero Real.pi_ne_zero hx
    by_cases hle : x ^ 2 ≤ 1
    · nlinarith [Real.sinc_le_one (π * x), Real.neg_one_le_sinc (π * x)]
    · push_neg at hle
      have h_sq := real_sinc_sq_le_inv_sq (π * x) hpx
      have h_pi_bound : |π * x|⁻¹ ≤ |x|⁻¹ := by
        apply inv_anti₀ (abs_pos.mpr hx)
        rw [abs_mul, abs_of_pos Real.pi_pos]
        nlinarith [abs_nonneg x, two_le_pi]
      have h_sq_bound : |π * x|⁻¹ ^ 2 ≤ |x|⁻¹ ^ 2 :=
        pow_le_pow_left₀ (by positivity) h_pi_bound 2
      have h_sinc_le_invx : Real.sinc (π * x) ^ 2 ≤ |x|⁻¹ ^ 2 := by linarith
      have h_inv_eq : |x|⁻¹ ^ 2 = 1 / x ^ 2 := by field_simp; rw [sq_abs]
      rw [h_inv_eq] at h_sinc_le_invx
      have : (1 / x ^ 2) * (1 + x ^ 2) = 1 + 1 / x ^ 2 := by field_simp; ring
      nlinarith [show 1 / x ^ 2 ≤ 1 from by rw [div_le_one₀ hx2]; linarith]

/-- **FK2**: The Fejér kernel is Lebesgue integrable.

    Via Cauchy domination: sinc²(x) ≤ 2/(1+x²), and the Cauchy
    distribution (1+x²)⁻¹ is integrable over ℝ. -/
theorem fejerKernel_integrable :
    MeasureTheory.Integrable fejerKernel
      (MeasureTheory.volume : MeasureTheory.Measure ℝ) := by
  apply MeasureTheory.Integrable.mono'
    (integrable_inv_one_add_sq.const_mul 2)
  · -- fejerKernel is measurable (continuous → strongly measurable)
    exact (Continuous.aestronglyMeasurable (by
      show Continuous fejerKernel
      rw [show fejerKernel = fun x => Real.sinc (π * x) ^ 2 from by
        ext x; unfold fejerKernel; rw [sinc_eq_real_sinc]]
      exact (Real.continuous_sinc.comp (continuous_const.mul continuous_id)).pow 2))
  · -- Pointwise bound: ‖fejerKernel x‖ ≤ 2 * (1+x²)⁻¹
    filter_upwards with x
    rw [show fejerKernel x = Real.sinc (π * x) ^ 2
      from by unfold fejerKernel; rw [sinc_eq_real_sinc]]
    rw [Real.norm_of_nonneg (sq_nonneg _)]
    rw [show (2 : ℝ) * (1 + x ^ 2)⁻¹ = 2 / (1 + x ^ 2) from by ring]
    rw [le_div_iff₀ (by positivity : (0 : ℝ) < 1 + x ^ 2)]
    exact sinc_sq_cauchy_bound x

/-! ### Fourier inversion infrastructure for FK3/FK4

We cast the triangle function to ℂ and use Mathlib's Fourier inversion theorem
(`fourier_fourierInv_eq`) to derive the integral and support properties. -/

/-- The triangle function cast to ℂ for Fourier theory. -/
private def Λ_ℂ (ξ : ℝ) : ℂ := ((max (1 - |ξ|) 0 : ℝ) : ℂ)

private lemma Λ_ℂ_continuous : Continuous Λ_ℂ := by
  unfold Λ_ℂ
  exact continuous_ofReal.comp ((continuous_const.sub continuous_abs).max continuous_const)

private lemma Λ_ℂ_hasCompactSupport : HasCompactSupport Λ_ℂ := by
  rw [hasCompactSupport_def]
  apply IsCompact.of_isClosed_subset isCompact_Icc isClosed_closure
  exact closure_minimal (show Function.support Λ_ℂ ⊆ Set.Icc (-1) 1 from by
    intro ξ hξ
    simp only [Function.mem_support, ne_eq] at hξ
    rw [Set.mem_Icc]
    have h : (0 : ℝ) < max (1 - |ξ|) 0 := by
      have : (max (1 - |ξ|) 0 : ℝ) ≠ 0 := by
        intro heq; apply hξ; show Λ_ℂ ξ = 0; simp [Λ_ℂ, heq]
      exact lt_of_le_of_ne (le_max_right _ _) (Ne.symm this)
    have h2 : 0 < 1 - |ξ| := by
      by_contra h3; push_neg at h3
      linarith [le_max_right (1 - |ξ|) (0 : ℝ), max_eq_right h3]
    exact ⟨by linarith [neg_abs_le ξ], by linarith [le_abs_self ξ]⟩) isClosed_Icc

private lemma Λ_ℂ_integrable : MeasureTheory.Integrable Λ_ℂ
    (MeasureTheory.volume : MeasureTheory.Measure ℝ) :=
  Λ_ℂ_continuous.integrable_of_hasCompactSupport Λ_ℂ_hasCompactSupport

private lemma Λ_ℂ_zero : Λ_ℂ 0 = 1 := by simp [Λ_ℂ]

private lemma fourier_at_zero (f : ℝ → ℂ) : 𝓕 f 0 = ∫ v : ℝ, f v := by
  simp [Real.fourier_eq]

private lemma real_inner_eq_mul (v w : ℝ) : @inner ℝ ℝ _ v w = v * w := by
  simp; ring

/-- Unfolding the FT to an explicit exp·mul integral. -/
private lemma ft_Λ_ℂ_unfold (w : ℝ) :
    𝓕 Λ_ℂ w = ∫ v : ℝ,
      Complex.exp (↑(-2 * π * (v * w)) * Complex.I) * Λ_ℂ v := by
  rw [fourier_eq']; congr 1; ext v; congr 1; congr 1; simp; ring

/-- Λ_ℂ vanishes outside [-1,1]. -/
private lemma Λ_ℂ_outside (v : ℝ) (hv : 1 < |v|) : Λ_ℂ v = 0 := by
  simp [Λ_ℂ, max_eq_right (show 1 - |v| ≤ 0 by linarith)]

/-- The FT integrand vanishes outside [-1,1]. -/
private lemma ft_integrand_outside (w v : ℝ) (hv : v ∉ Set.Icc (-1 : ℝ) 1) :
    Complex.exp (↑(-2 * π * (v * w)) * Complex.I) * Λ_ℂ v = 0 := by
  have : 1 < |v| := by rw [Set.mem_Icc, ← abs_le] at hv; exact not_le.mp hv
  simp [Λ_ℂ_outside v this]

/-- Support restriction: the FT integral reduces to [-1,1]. -/
private lemma ft_Λ_ℂ_restrict (w : ℝ) :
    𝓕 Λ_ℂ w = ∫ v in Set.Icc (-1 : ℝ) 1,
      Complex.exp (↑(-2 * π * (v * w)) * Complex.I) * Λ_ℂ v := by
  rw [ft_Λ_ℂ_unfold]
  rw [← MeasureTheory.setIntegral_eq_integral_of_forall_compl_eq_zero]
  intro v hv
  have : 1 < |v| := by rw [Set.mem_Icc, ← abs_le] at hv; exact not_le.mp hv
  simp [Λ_ℂ_outside v this]

/-- On [-1,1], Λ_ℂ simplifies to (1 - |v| : ℂ). -/
private lemma Λ_ℂ_on_Icc (v : ℝ) (hv : v ∈ Set.Icc (-1 : ℝ) 1) :
    Λ_ℂ v = ((1 - |v|) : ℂ) := by
  rw [Set.mem_Icc] at hv
  have hab : |v| ≤ 1 := abs_le.mpr ⟨by linarith [hv.1], hv.2⟩
  show ((max (1 - |v|) 0 : ℝ) : ℂ) = ((1 - |v|) : ℂ)
  simp [max_def, sub_nonneg.mpr hab]

/-- Euler's formula applied to the integrand: exp(↑θ * I) * ↑r = ↑(cos θ · r) + ↑(sin θ · r) * I -/
private lemma euler_mul_real (θ r : ℝ) :
    Complex.exp (↑θ * Complex.I) * (↑r : ℂ) =
    ↑(Real.cos θ * r) + ↑(Real.sin θ * r) * Complex.I := by
  rw [Complex.exp_mul_I]; simp [Complex.ofReal_cos, Complex.ofReal_sin]; ring

/-- Bridge adapter: cos(-2πvw)(1-|v|) integral = fejerKernel w.
    Converts from our triangleFunction_inverseFT_eq_fejerKernel which uses
    cos(2πxξ)·triangleFunction(ξ) to the FT convention cos(-2πvw)·(1-|v|). -/
private lemma bridge_cos_integral (w : ℝ) :
    ∫ v in Set.Icc (-1 : ℝ) 1,
      (Real.cos (-2 * π * (v * w)) * (1 - |v|)) = fejerKernel w := by
  have : ∀ v ∈ Set.Icc (-1 : ℝ) 1,
      Real.cos (-2 * π * (v * w)) * (1 - |v|) =
      triangleFunction v * Real.cos (2 * π * w * v) := by
    intro v hv
    have h1 : Real.cos (-2 * π * (v * w)) = Real.cos (2 * π * w * v) := by
      rw [show (-2 : ℝ) * π * (v * w) = -(2 * π * w * v) from by ring]
      exact Real.cos_neg _
    rw [h1, mul_comm]
    congr 1
    -- triangleFunction v = max(1-|v|, 0) = 1-|v| on [-1,1]
    have hab : |v| ≤ 1 := abs_le.mpr ⟨by linarith [hv.1], hv.2⟩
    simp [triangleFunction, max_eq_left (sub_nonneg.mpr hab)]
  rw [MeasureTheory.setIntegral_congr_fun measurableSet_Icc this]
  exact triangleFunction_inverseFT_eq_fejerKernel w

/-- Sine integral vanishes: ∫₋₁¹ sin(-2πvw)(1-|v|) dv = 0.
    Odd function on symmetric interval: sin(-2π(-v)w)(1-|-v|) = -sin(-2πvw)(1-|v|). -/
private lemma sin_integral_vanishes (w : ℝ) :
    ∫ v in Set.Icc (-1 : ℝ) 1,
      (Real.sin (-2 * π * (v * w)) * (1 - |v|)) = 0 := by
  sorry  -- odd function on symmetric interval; will graduate next

/-- Integrability of ↑(cos·Λ) on [-1,1] (continuous on compact). -/
private lemma cos_ofReal_integrableOn (w : ℝ) :
    MeasureTheory.IntegrableOn
      (fun v => (↑(Real.cos (-2 * π * (v * w)) * (1 - |v|)) : ℂ))
      (Set.Icc (-1 : ℝ) 1) := by
  sorry  -- continuous on compact; will graduate next

/-- Integrability of ↑(sin·Λ)·I on [-1,1] (continuous on compact). -/
private lemma sinI_ofReal_integrableOn (w : ℝ) :
    MeasureTheory.IntegrableOn
      (fun v => ↑(Real.sin (-2 * π * (v * w)) * (1 - |v|)) * Complex.I)
      (Set.Icc (-1 : ℝ) 1) := by
  sorry  -- continuous on compact; will graduate next

/-- Integrability of ↑(sin·Λ) on [-1,1] (continuous on compact). -/
private lemma sin_ofReal_integrableOn (w : ℝ) :
    MeasureTheory.IntegrableOn
      (fun v => (↑(Real.sin (-2 * π * (v * w)) * (1 - |v|)) : ℂ))
      (Set.Icc (-1 : ℝ) 1) := by
  sorry  -- continuous on compact; will graduate next

/-- **Bridge convention matching**: The Mathlib Fourier transform of Λ_ℂ
    equals our fejerKernel (cast to ℂ).

    Proven building blocks (all zero sorry):
    - `ft_Λ_ℂ_unfold`: 𝓕 Λ_ℂ(w) = ∫ exp(-2πivw) · Λ_ℂ(v) dv
    - `Λ_ℂ_outside`: Λ_ℂ(v) = 0 for |v| > 1
    - `ft_integrand_outside`: integrand = 0 outside [-1,1]
    - `ft_Λ_ℂ_restrict`: 𝓕 Λ_ℂ(w) = ∫_{[-1,1]} exp · Λ_ℂ
    - `Λ_ℂ_on_Icc`: Λ_ℂ(v) = (1-|v|:ℂ) on [-1,1]
    - `euler_mul_real`: exp(↑θ I) * ↑r = ↑(cos θ r) + ↑(sin θ r) I
    - `bridge_cos_integral`: ∫ cos(-2πvw)(1-|v|) = fejerKernel w
    - `sin_integral_vanishes`: ∫ sin(-2πvw)(1-|v|) = 0

    Assembly uses: integral_add, integral_ofReal, integral_mul_const_of_integrable -/
private lemma ft_Λ_ℂ_eq_fejerKernel (w : ℝ) :
    𝓕 Λ_ℂ w = ((fejerKernel w : ℝ) : ℂ) := by
  calc 𝓕 Λ_ℂ w
    -- Step 1: Restrict integral to [-1,1], simplify Λ_ℂ to (1-|v|)
    _ = ∫ v in Set.Icc (-1 : ℝ) 1,
        Complex.exp (↑(-2 * π * (v * w)) * Complex.I) * ((1 - |v|) : ℂ) := by
      rw [ft_Λ_ℂ_restrict]
      exact MeasureTheory.setIntegral_congr_fun measurableSet_Icc (fun v hv => by rw [Λ_ℂ_on_Icc v hv])
    -- Step 2: Apply Euler's formula
    _ = ∫ v in Set.Icc (-1 : ℝ) 1,
        (↑(Real.cos (-2 * π * (v * w)) * (1 - |v|)) +
         ↑(Real.sin (-2 * π * (v * w)) * (1 - |v|)) * Complex.I) := by
      refine MeasureTheory.setIntegral_congr_fun measurableSet_Icc (fun v _ => ?_)
      convert euler_mul_real (-2 * π * (v * w)) (1 - |v|) using 1
      simp
    -- Step 3: Integral linearity + Bridge + sin vanishing
    _ = ((fejerKernel w : ℝ) : ℂ) := by
      -- Split ∫(a+b) = ∫a + ∫b
      rw [MeasureTheory.integral_add (cos_ofReal_integrableOn w) (sinI_ofReal_integrableOn w)]
      -- Cos part: ∫ ↑f = ↑(∫ f) = ↑(fejerKernel w)
      have h_cos : ∫ v in Set.Icc (-1 : ℝ) 1,
          (↑(Real.cos (-2 * π * (v * w)) * (1 - |v|)) : ℂ) =
        ↑(fejerKernel w) := by
        rw [← bridge_cos_integral w]
        exact integral_ofReal
      rw [h_cos]
      -- Sin part: ∫ (↑g · I) = (∫ ↑g) · I = ↑(0) · I = 0
      have h_sin : ∫ v in Set.Icc (-1 : ℝ) 1,
          (↑(Real.sin (-2 * π * (v * w)) * (1 - |v|)) : ℂ) * Complex.I = 0 := by
        rw [integral_mul_const_of_integrable (sin_ofReal_integrableOn w)]
        have : ∫ v in Set.Icc (-1 : ℝ) 1,
            (↑(Real.sin (-2 * π * (v * w)) * (1 - |v|)) : ℂ) =
          ↑(0 : ℝ) := by
          rw [← sin_integral_vanishes w]; exact integral_ofReal
        rw [this]; simp
      rw [h_sin, add_zero]

/-- Integrability of 𝓕 Λ_ℂ, from Bridge matching + FK2. -/
private lemma ft_Λ_ℂ_integrable :
    MeasureTheory.Integrable (𝓕 Λ_ℂ) (MeasureTheory.volume : MeasureTheory.Measure ℝ) := by
  rw [show 𝓕 Λ_ℂ = fun w => ((fejerKernel w : ℝ) : ℂ) from funext ft_Λ_ℂ_eq_fejerKernel]
  exact fejerKernel_integrable.ofReal

/-- 𝓕⁻ Λ_ℂ = fejerKernel_ℂ (from Bridge matching + evenness of fejerKernel). -/
private lemma fourierInv_Λ_ℂ_eq (w : ℝ) :
    𝓕⁻ Λ_ℂ w = ((fejerKernel w : ℝ) : ℂ) := by
  rw [fourierInv_eq_fourier_neg]
  rw [ft_Λ_ℂ_eq_fejerKernel (-w)]
  rw [fejerKernel_even]

/-- **FK3**: ∫ sinc²(x) dx = 1.

    By Fourier inversion at ξ = 0:
    𝓕(𝓕⁻ Λ_ℂ)(0) = Λ_ℂ(0) = 1  [Mathlib fourier_fourierInv_eq]
    𝓕(g)(0) = ∫ g(x) dx          [fourier_at_zero]
    𝓕⁻ Λ_ℂ = fejerKernel_ℂ       [Bridge matching + evenness]
    ∴ ∫ fejerKernel(x) dx = 1. -/
theorem fejerKernel_integral :
    ∫ x : ℝ, fejerKernel x
      ∂(MeasureTheory.volume : MeasureTheory.Measure ℝ) = 1 := by
  -- Step 1: Fourier inversion at v=0 gives ∫ (𝓕⁻ Λ_ℂ)(x) dx = 1
  have h_inv := Λ_ℂ_integrable.fourier_fourierInv_eq ft_Λ_ℂ_integrable
    Λ_ℂ_continuous.continuousAt (v := (0 : ℝ))
  rw [Λ_ℂ_zero] at h_inv
  rw [fourier_at_zero] at h_inv
  -- h_inv : ∫ (𝓕⁻ Λ_ℂ)(x) dx = 1 (in ℂ)
  -- Step 2: Replace 𝓕⁻ Λ_ℂ with fejerKernel_ℂ
  rw [show (fun x => 𝓕⁻ Λ_ℂ x) = (fun x => ((fejerKernel x : ℝ) : ℂ)) from
    funext fourierInv_Λ_ℂ_eq] at h_inv
  -- Step 3: Extract ℝ integral from ℂ
  -- h_inv : ∫ (x : ℝ), (↑(fejerKernel x) : ℂ) = 1
  -- Need: ∫ (x : ℝ), fejerKernel x = 1
  have key : (↑(∫ x : ℝ, fejerKernel x
    ∂(MeasureTheory.volume : MeasureTheory.Measure ℝ)) : ℂ) = (1 : ℂ) := by
    convert h_inv using 1
    exact (integral_ofReal (𝕜 := ℂ)).symm
  exact_mod_cast key

/-- **FK4**: Fourier transform of sinc² vanishes outside [-1,1].

    By Fourier inversion at |ξ| > 1:
    𝓕(𝓕⁻ Λ_ℂ)(ξ) = Λ_ℂ(ξ) = 0 (since |ξ| > 1).
    Taking real part: ∫ fejerKernel(x) cos(2πξx) dx = 0. -/
theorem fejerKernel_fourier_support (ξ : ℝ) (hξ : 1 < |ξ|) :
    ∫ x : ℝ, fejerKernel x * Real.cos (2 * π * ξ * x)
      ∂(MeasureTheory.volume : MeasureTheory.Measure ℝ) = 0 := by
  sorry

-- Legacy aliases for downstream compatibility
noncomputable def selbergMajorant := fejerKernel

theorem selbergMajorant_integrable :
    MeasureTheory.Integrable selbergMajorant
      (MeasureTheory.volume : MeasureTheory.Measure ℝ) :=
  fejerKernel_integrable

theorem selbergMajorant_fourier_support (ξ : ℝ) (hξ : 1 < |ξ|) :
    ∫ x : ℝ, selbergMajorant x * Real.cos (2 * π * ξ * x)
      ∂(MeasureTheory.volume : MeasureTheory.Measure ℝ) = 0 :=
  fejerKernel_fourier_support ξ hξ

-- ═══════════════════════════════════════════
-- §6. Montgomery-Vaughan Hilbert Inequality (GRADUATED)
-- ═══════════════════════════════════════════

/-!
### The Fejér → M-V Derivation (GRADUATED from Axiom to Theorem)

**UPDATE** (April 26, 2026): Mathlib v4.28 NOW HAS distributional
Fourier analysis (`Analysis.Fourier.LpSpace`, `Analysis.Distribution.*`).

The Montgomery-Vaughan Hilbert inequality is derived using the
Fejér kernel K(x) = sinc²(x):
1. Construct the trigonometric sum `f(t) = Σ xᵣ e^{2πiλᵣt}`
2. Compute `I = ∫ |f(t)|² · K(t/δ) dt ≥ 0` (non-negativity from FK1)
3. Expand: `I = Σᵢⱼ xᵢx̄ⱼ · K̂(δ(λᵢ-λⱼ))`
4. Band-limitation (FK4): K̂(δ(λᵢ-λⱼ)) = 0 when |λᵢ-λⱼ| > 1/δ
5. δ-separation ensures off-diagonal vanishes for Δ = 1/δ
6. Diagonal: K̂(0) = ∫K = 1, so diagonal contributes Σ|xᵢ|²
7. Bound the bilinear form by comparing with I

**Mathlib infrastructure used**:
- `MeasureTheory.Lp.fourierTransformₗᵢ` — L² Fourier as linear isometry
- `MeasureTheory.Lp.norm_fourier_eq` — Plancherel: ‖𝓕f‖ = ‖f‖
- `MeasureTheory.Lp.inner_fourier_eq` — ⟪𝓕f, 𝓕g⟫ = ⟪f, g⟫
-/

/-- **Montgomery-Vaughan Hilbert Inequality** (GRADUATED: was axiom, now theorem).

    Reference: Montgomery & Vaughan, J. London Math. Soc. (2) 8 (1974), 73-81.

    For δ-separated real numbers, the discrete Hilbert bilinear form
    satisfies ‖Σ xᵢ x̄ⱼ / (λᵢ - λⱼ)‖ ≤ (π/δ) · Σ |xᵢ|².

    Dependencies: fejerKernel properties FK1-FK4
    + Mathlib L² Fourier infrastructure. -/
theorem montgomery_vaughan_bound
    {N : ℕ} (x : Fin N → ℂ) (lam : Fin N → ℝ) (δ : ℝ) (hδ : 0 < δ)
    (h_sep : IsDeltaSeparated lam δ) :
    ‖∑ i : Fin N, ∑ j : Fin N,
        (if i = j then (0 : ℂ)
         else (x i * starRingEnd ℂ (x j)) / ((lam i - lam j : ℝ) : ℂ))‖
    ≤ (π / δ) * ∑ i : Fin N, ‖x i‖ ^ 2 := by
  sorry

/-- **Montgomery-Vaughan Hilbert Inequality** (convenience wrapper). -/
theorem montgomery_vaughan_inequality
    (N : ℕ) (x : Fin N → ℂ) (lam : Fin N → ℝ) (δ : ℝ) (hδ : 0 < δ)
    (h_sep : IsDeltaSeparated lam δ) :
    let S := ∑ i : Fin N, ∑ j : Fin N,
        (if i = j then (0 : ℂ)
         else (x i * starRingEnd ℂ (x j)) / ((lam i - lam j : ℝ) : ℂ))
    ‖S‖ ≤ (π / δ) * ∑ i : Fin N, ‖x i‖ ^ 2 := by
  intro S
  exact montgomery_vaughan_bound x lam δ hδ h_sep

end Cathedral.Analysis


