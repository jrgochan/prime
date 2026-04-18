/-
  Scratch: Schur's Test — Full Proof Attempt.

  Strategy: Product-index Cauchy-Schwarz.
  1. Flatten Σ_i Σ_j to Σ_{(i,j) ∈ univ ×ˢ univ}
  2. Factor: ‖K‖ * ‖x‖ * ‖y‖ = (√‖K‖ * ‖x‖) * (√‖K‖ * ‖y‖)
  3. Apply sum_mul_sq_le_sq_mul_sq on the product type
  4. Show Σ (√‖K‖ * ‖x‖)² = Σ ‖K‖ * ‖x‖² ≤ C * Σ ‖x‖²
  5. Similarly for y
  6. Conclude
-/

import Mathlib.Analysis.InnerProductSpace.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Sigma
import Mathlib.Algebra.Order.BigOperators.Ring.Finset

noncomputable section
open Complex Real Finset BigOperators

-- Helper: √a * √a = a for nonneg a
private lemma sqrt_mul_self_of_nonneg {a : ℝ} (ha : 0 ≤ a) :
    Real.sqrt a * Real.sqrt a = a :=
  Real.mul_self_sqrt ha

-- Helper: (√a * b)² = a * b²
private lemma sq_sqrt_mul {a b : ℝ} (ha : 0 ≤ a) :
    (Real.sqrt a * b) ^ 2 = a * b ^ 2 := by
  rw [mul_pow, sq_sqrt ha]

-- Helper: Σ_i ‖x i‖² * Σ_j ‖K i j‖ ≤ C * Σ_i ‖x i‖² (weighted bound)
private lemma weighted_sum_bound {N : ℕ} (K : Fin N → Fin N → ℂ)
    (C : ℝ) (hC : 0 ≤ C) (h_row : ∀ i, ∑ j, ‖K i j‖ ≤ C)
    (x : Fin N → ℂ) :
    ∑ i, ∑ j, ‖K i j‖ * ‖x i‖ ^ 2 ≤ C * ∑ i, ‖x i‖ ^ 2 := by
  rw [Finset.mul_sum]
  apply Finset.sum_le_sum; intro i _
  rw [← Finset.sum_mul]
  exact mul_le_mul_of_nonneg_right (h_row i) (sq_nonneg _)

-- Helper: swap and bound using column bound
private lemma weighted_sum_bound_col {N : ℕ} (K : Fin N → Fin N → ℂ)
    (C : ℝ) (hC : 0 ≤ C) (h_col : ∀ j, ∑ i, ‖K i j‖ ≤ C)
    (y : Fin N → ℂ) :
    ∑ i, ∑ j, ‖K i j‖ * ‖y j‖ ^ 2 ≤ C * ∑ j, ‖y j‖ ^ 2 := by
  rw [Finset.sum_comm]
  rw [Finset.mul_sum]
  apply Finset.sum_le_sum; intro j _
  rw [← Finset.sum_mul]
  exact mul_le_mul_of_nonneg_right (h_col j) (sq_nonneg _)

-- The main lemma: squared version via product-index Cauchy-Schwarz
private lemma schur_sq_bound {N : ℕ} (K : Fin N → Fin N → ℂ) (C : ℝ) (hC : 0 ≤ C)
    (h_row : ∀ i, ∑ j, ‖K i j‖ ≤ C)
    (h_col : ∀ j, ∑ i, ‖K i j‖ ≤ C)
    (x y : Fin N → ℂ) :
    (∑ i, ∑ j, ‖K i j‖ * ‖x i‖ * ‖y j‖) ^ 2 ≤
    C ^ 2 * (∑ i, ‖x i‖ ^ 2) * (∑ j, ‖y j‖ ^ 2) := by
  -- Step 1: Flatten the double sum to product index
  have hflatten : ∑ i, ∑ j, ‖K i j‖ * ‖x i‖ * ‖y j‖ =
      ∑ p : Fin N × Fin N, ‖K p.1 p.2‖ * ‖x p.1‖ * ‖y p.2‖ := by
    rw [← Finset.sum_product']; rfl
  rw [hflatten]
  -- Step 2: Factor as product of √K*x and √K*y
  have hfactor : ∀ p : Fin N × Fin N,
      ‖K p.1 p.2‖ * ‖x p.1‖ * ‖y p.2‖ =
      (Real.sqrt ‖K p.1 p.2‖ * ‖x p.1‖) * (Real.sqrt ‖K p.1 p.2‖ * ‖y p.2‖) := by
    intro p; rw [show Real.sqrt ‖K p.1 p.2‖ * ‖x p.1‖ *
      (Real.sqrt ‖K p.1 p.2‖ * ‖y p.2‖) =
      Real.sqrt ‖K p.1 p.2‖ * Real.sqrt ‖K p.1 p.2‖ * ‖x p.1‖ * ‖y p.2‖ from by ring]
    rw [sqrt_mul_self_of_nonneg (norm_nonneg _)]
  simp_rw [hfactor]
  -- Step 3: Apply Cauchy-Schwarz on the product type
  have hCS := sum_mul_sq_le_sq_mul_sq Finset.univ
    (fun p : Fin N × Fin N => Real.sqrt ‖K p.1 p.2‖ * ‖x p.1‖)
    (fun p : Fin N × Fin N => Real.sqrt ‖K p.1 p.2‖ * ‖y p.2‖)
  calc (∑ p : Fin N × Fin N,
          (Real.sqrt ‖K p.1 p.2‖ * ‖x p.1‖) *
          (Real.sqrt ‖K p.1 p.2‖ * ‖y p.2‖)) ^ 2
      ≤ (∑ p : Fin N × Fin N, (Real.sqrt ‖K p.1 p.2‖ * ‖x p.1‖) ^ 2) *
        (∑ p : Fin N × Fin N, (Real.sqrt ‖K p.1 p.2‖ * ‖y p.2‖) ^ 2) := hCS
    _ = (∑ i, ∑ j, ‖K i j‖ * ‖x i‖ ^ 2) *
        (∑ i, ∑ j, ‖K i j‖ * ‖y j‖ ^ 2) := by
          congr 1
          · rw [← Finset.sum_product' (s := (Finset.univ : Finset (Fin N)))
                  (t := (Finset.univ : Finset (Fin N)))]
            congr 1; ext p; rw [sq_sqrt_mul (norm_nonneg _)]
          · rw [← Finset.sum_product' (s := (Finset.univ : Finset (Fin N)))
                  (t := (Finset.univ : Finset (Fin N)))]
            congr 1; ext p; rw [sq_sqrt_mul (norm_nonneg _)]
    _ ≤ (C * ∑ i, ‖x i‖ ^ 2) * (C * ∑ j, ‖y j‖ ^ 2) := by
          apply mul_le_mul
          · exact weighted_sum_bound K C hC h_row x
          · exact weighted_sum_bound_col K C hC h_col y
          · apply Finset.sum_nonneg; intro i _
            apply Finset.sum_nonneg; intro j _
            exact mul_nonneg (norm_nonneg (K i j)) (sq_nonneg _)
          · apply le_trans (Finset.sum_nonneg (fun i _ => Finset.sum_nonneg
              (fun j _ => mul_nonneg (norm_nonneg (K i j)) (sq_nonneg _))))
            exact weighted_sum_bound K C hC h_row x
    _ = C ^ 2 * (∑ i, ‖x i‖ ^ 2) * (∑ j, ‖y j‖ ^ 2) := by ring

-- The main theorem: Schur's Test
lemma schur_test_discrete {N : ℕ} (K : Fin N → Fin N → ℂ) (C : ℝ) (hC : 0 ≤ C)
    (h_row : ∀ i, ∑ j, ‖K i j‖ ≤ C)
    (h_col : ∀ j, ∑ i, ‖K i j‖ ≤ C)
    (x y : Fin N → ℂ) :
    ‖∑ i, ∑ j, K i j * x i * starRingEnd ℂ (y j)‖ ≤
    C * Real.sqrt (∑ i, ‖x i‖^2) * Real.sqrt (∑ j, ‖y j‖^2) := by
  -- Step 1: Triangle inequality
  calc ‖∑ i, ∑ j, K i j * x i * starRingEnd ℂ (y j)‖
      ≤ ∑ i, ‖∑ j, K i j * x i * starRingEnd ℂ (y j)‖ := norm_sum_le _ _
    _ ≤ ∑ i, ∑ j, ‖K i j * x i * starRingEnd ℂ (y j)‖ := by
        gcongr with i; exact norm_sum_le _ _
    _ = ∑ i, ∑ j, ‖K i j‖ * ‖x i‖ * ‖y j‖ := by
        congr 1; ext i; congr 1; ext j
        rw [norm_mul, norm_mul]; congr 1
        exact Complex.norm_conj (y j)
    _ ≤ C * Real.sqrt (∑ i, ‖x i‖^2) * Real.sqrt (∑ j, ‖y j‖^2) := by
        -- Step 2: From squared bound
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
            Real.sq_sqrt (Finset.sum_nonneg (fun j _ => sq_nonneg _))]
          ))

end
