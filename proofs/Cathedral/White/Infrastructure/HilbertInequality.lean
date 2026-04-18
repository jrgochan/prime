/-
  Cathedral/White/Infrastructure/HilbertInequality.lean

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
import Mathlib.MeasureTheory.Integral.Bochner.Basic
import Mathlib.MeasureTheory.Measure.Lebesgue.Basic

noncomputable section
open Complex Real Finset BigOperators

namespace Cathedral.White.Infrastructure

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
-- §5. Selberg Majorant Axioms
-- ═══════════════════════════════════════════

/-!
### The Beurling-Selberg Extremal Function

The Selberg majorant S : ℝ → ℝ is the optimal band-limited
majorant of the signum function. Its explicit formula uses
`sinc²` and the cotangent partial fraction expansion
(`Mathlib.Analysis.SpecialFunctions.Trigonometric.Cotangent:cot_series_rep`).

Reference: Vaaler, "Some extremal functions in Fourier analysis",
Bull. AMS 12 (1985), 183-216.

**PROOF PATH**: The axioms below will be replaced by constructive
proofs using:
- `sinc` (§4 above)
- `cot_series_rep` from Mathlib (π·cot(πx) = 1/x + Σ(1/(x-n)+1/(x+n)))
- `euler_sineTerm_tprod` from Mathlib (Euler sine product)
- `digamma_reflection_complex` from Cathedral/Vasyunin/Cotangent/
-/

/-- The Selberg majorant of sgn(x). -/
axiom selbergMajorant : ℝ → ℝ

/-- **BS1**: S(x) ≥ 1 for x > 0 (majorizes sgn). -/
axiom selbergMajorant_ge_one_of_pos (x : ℝ) (hx : 0 < x) :
    1 ≤ selbergMajorant x

/-- **BS2**: S(x) ≤ -1 for x < 0 (majorizes sgn). -/
axiom selbergMajorant_le_neg_one_of_neg (x : ℝ) (hx : x < 0) :
    selbergMajorant x ≤ -1

/-- **BS3**: S is Lebesgue integrable. -/
axiom selbergMajorant_integrable :
    MeasureTheory.Integrable selbergMajorant (MeasureTheory.volume : MeasureTheory.Measure ℝ)

/-- **BS4**: ∫ S(x) dx = 2 (optimal for band-limited sgn majorant). -/
axiom selbergMajorant_integral :
    ∫ x : ℝ, selbergMajorant x ∂(MeasureTheory.volume : MeasureTheory.Measure ℝ) = 2

/-- **BS5**: Fourier transform of S vanishes outside [-1,1]. -/
axiom selbergMajorant_fourier_support (ξ : ℝ) (hξ : 1 < |ξ|) :
    ∫ x : ℝ, selbergMajorant x * Real.cos (2 * π * ξ * x)
      ∂(MeasureTheory.volume : MeasureTheory.Measure ℝ) = 0

-- ═══════════════════════════════════════════
-- §6. Montgomery-Vaughan Hilbert Inequality
-- ═══════════════════════════════════════════

/-- **Montgomery-Vaughan Hilbert Inequality** (1974).
    For δ-separated real numbers, the discrete Hilbert transform is bounded
    with the sharp constant π/δ.

    Reference: Montgomery & Vaughan, J. London Math. Soc. (2) 8 (1974), 73-81.

    **PROOF PATH**: Follows from the Selberg majorant axioms (§5) via:
    1. Construct smoothed kernel K_Δ(x) = S(x/δ)/(2δ)
    2. Show the quadratic form Σ x_r ȳ_s K_Δ(λ_r-λ_s) is positive-definite
       (from band-limitation BS5)
    3. Separate diagonal (using BS4: ∫S = 2) and off-diagonal (using BS1/BS2)
    4. Conclude: off-diagonal ≤ (π/δ) · diagonal

    **CURRENT STATUS**: Blocked on the derivation from BS axioms.
    When the axioms are replaced by constructive proofs, this
    becomes fully sorry-free. -/
theorem montgomery_vaughan_inequality
    (N : ℕ) (x : Fin N → ℂ) (lam : Fin N → ℝ) (δ : ℝ) (hδ : 0 < δ)
    (h_sep : IsDeltaSeparated lam δ) :
    let S := ∑ i : Fin N, ∑ j : Fin N,
        (if i = j then (0 : ℂ)
         else (x i * starRingEnd ℂ (x j)) / ((lam i - lam j : ℝ) : ℂ))
    ‖S‖ ≤ (π / δ) * ∑ i : Fin N, ‖x i‖ ^ 2 := by
  -- Derivation from Selberg axioms BS1-BS5 (TODO)
  sorry

end Cathedral.White.Infrastructure
