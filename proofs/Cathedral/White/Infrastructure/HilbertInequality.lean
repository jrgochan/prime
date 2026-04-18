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
private lemma schur_sq_bound {N : ℕ} (K : Fin N → Fin N → ℂ) (C : ℝ) (hC : 0 ≤ C)
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
-- §3. δ-Separation and Montgomery-Vaughan
-- ═══════════════════════════════════════════

/-- A finite sequence of reals is δ-separated if the distance between
    any two distinct elements is at least δ. -/
def IsDeltaSeparated {N : ℕ} (lam : Fin N → ℝ) (δ : ℝ) : Prop :=
  ∀ i j : Fin N, i ≠ j → δ ≤ |lam i - lam j|

/-- **TARGET**: Montgomery-Vaughan Hilbert Inequality (1973).
    For δ-separated real numbers, the discrete Hilbert transform is bounded
    with the sharp constant π/δ.

    Reference: Montgomery & Vaughan, "The large sieve", Mathematika 20 (1973).
    ROUTE: Apply schur_test_discrete with K_ij = 1/(λ_i - λ_j),
    then bound row sums using cotangent estimates. -/
theorem montgomery_vaughan_inequality
    (N : ℕ) (x : Fin N → ℂ) (lam : Fin N → ℝ) (δ : ℝ) (hδ : 0 < δ)
    (h_sep : IsDeltaSeparated lam δ) :
    let S := ∑ i : Fin N, ∑ j : Fin N,
        (if i = j then (0 : ℂ)
         else (x i * starRingEnd ℂ (x j)) / ((lam i - lam j : ℝ) : ℂ))
    ‖S‖ ≤ (π / δ) * ∑ i : Fin N, ‖x i‖ ^ 2 := by
  -- 🔨 PHASE 2 TARGET:
  -- 1. Apply schur_test_discrete with K_ij = 1/(λ_i - λ_j).
  -- 2. Construct Montgomery-Vaughan test weights.
  -- 3. Bound the row sums: Σ_{j≠i} 1/|λ_i - λ_j| ≤ π/δ.
  sorry

end Cathedral.White.Infrastructure
