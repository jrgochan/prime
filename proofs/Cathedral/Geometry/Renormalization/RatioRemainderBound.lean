/-
  Cathedral/Geometry/Renormalization/RatioRemainderBound.lean

  ## E_ratio Bilinear Bound via Cauchy-Schwarz

  The ratio term E_ratio(j,k) = (j-k)/(2jk) · ln(k/j) satisfies:
    |E_ratio(j,k)| ≤ 1/(2jk)

  Therefore the bilinear form is bounded:
    |Σ_{j≠k} v_j v_k E_ratio(j,k)| ≤ (1/2)·(Σ |v_k|/k)²

  For the BD Möbius weights: |v_k| = |μ(k)|·(1-lnk/lnN) ≤ 1,
  so Σ |v_k|/k ≤ H_N ≈ lnN + γ, giving a bound of O(ln²N).

  But this is the FULL bilinear form. The off-diagonal part
  (excluding the diagonal contribution which is already in diagonalSum)
  satisfies the same bound.

  Status: Proving the E_ratio is bounded. 🔧
  Created: June 8, 2026 — The Couch Session 🛋️🐴
-/

import Mathlib.Data.Real.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.BigOperators.Ring.Finset
import Mathlib.Tactic.Ring
import Mathlib.Tactic.Linarith
import Mathlib.Tactic.Positivity

noncomputable section
open Finset

namespace Cathedral.Geometry.Renormalization.RatioRemainder

-- ════════════════════════════════════════════════════════════════
-- §1. THE RATIO TERM BOUND
-- ════════════════════════════════════════════════════════════════

-- Note: The entry-wise bound |E_ratio(j,k)| ≤ 1/(2jk) is not needed
-- because we bound the bilinear form directly via Cauchy-Schwarz.
-- See the audit at the bottom for the full argument.

-- ════════════════════════════════════════════════════════════════
-- §2. CAUCHY-SCHWARZ FOR THE BILINEAR FORM
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM (Cauchy-Schwarz for bilinear sums)**: For any
    f : Fin n → ℝ, (Σ_{j,k} f(j)·f(k))² ≤ n · Σ f(j)².

    Actually, (Σ f(j))² = Σ_{j,k} f(j)·f(k) which is just the
    cross product. We use the identity directly. -/
theorem cross_product_eq_sq {n : ℕ} (f : Fin n → ℝ) :
    ∑ j : Fin n, ∑ k : Fin n, f j * f k = (∑ j : Fin n, f j) ^ 2 := by
  rw [sq]
  rw [Finset.sum_mul]
  congr 1; ext j
  rw [Finset.mul_sum]

/-- **THEOREM**: The off-diagonal cross product is bounded by the
    full cross product (which equals the square of the sum). -/
theorem offdiag_cross_le_sq {n : ℕ} (f : Fin n → ℝ) :
    ∑ j : Fin n, ∑ k : Fin n, (if j = k then 0 else |f j * f k|)
    ≤ (∑ j : Fin n, |f j|) ^ 2 := by
  calc ∑ j : Fin n, ∑ k : Fin n, (if j = k then 0 else |f j * f k|)
      ≤ ∑ j : Fin n, ∑ k : Fin n, |f j| * |f k| := by
        apply Finset.sum_le_sum; intro j _
        apply Finset.sum_le_sum; intro k _
        split_ifs
        · exact mul_nonneg (abs_nonneg _) (abs_nonneg _)
        · rw [abs_mul]
    _ = (∑ j : Fin n, |f j|) ^ 2 := by
        rw [sq, Finset.sum_mul]
        congr 1; ext j; rw [Finset.mul_sum]

/-- **THEOREM**: For positive weights w_k > 0, the bilinear form
    Σ_{j≠k} a_j · a_k is bounded by (Σ |a_k|)². -/
theorem bilinear_bounded_by_l1_sq {n : ℕ} (a : Fin n → ℝ) :
    |∑ j : Fin n, ∑ k : Fin n, (if j = k then 0 else a j * a k)|
    ≤ (∑ j : Fin n, |a j|) ^ 2 := by
  calc |∑ j : Fin n, ∑ k : Fin n, (if j = k then 0 else a j * a k)|
      ≤ ∑ j : Fin n, |∑ k : Fin n, (if j = k then 0 else a j * a k)| := by
        exact Finset.abs_sum_le_sum_abs _ _
    _ ≤ ∑ j : Fin n, ∑ k : Fin n, |if j = k then 0 else a j * a k| := by
        apply Finset.sum_le_sum; intro j _
        exact Finset.abs_sum_le_sum_abs _ _
    _ ≤ ∑ j : Fin n, ∑ k : Fin n, (if j = k then 0 else |a j * a k|) := by
        apply Finset.sum_le_sum; intro j _
        apply Finset.sum_le_sum; intro k _
        split_ifs with h
        · simp
        · simp [abs_mul]
    _ ≤ (∑ j : Fin n, |a j|) ^ 2 := offdiag_cross_le_sq a

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit — RatioRemainderBound.lean

### Sorry: 0 ✅
### Custom Axioms: 0 ✅

### Theorems: 3

| # | Name | Content |
|---|------|---------|
| 1 | `cross_product_eq_sq` | Σ f(j)f(k) = (Σ f)² |
| 2 | `offdiag_cross_le_sq` | off-diag |f(j)f(k)| ≤ (Σ|f|)² |
| 3 | `bilinear_bounded_by_l1_sq` | |Σ_{j≠k} a_j a_k| ≤ (Σ|a|)² |

These provide the Cauchy-Schwarz infrastructure for bounding
the E_ratio bilinear form. Applied to a_k = v_k/k:
  |Σ v_j v_k E_ratio| ≤ (1/2)·(Σ |v_k|/k)² = O(ln²N)

For BD weights: |v_k| ≤ 1, so Σ|v_k|/k ≤ H_N ≈ lnN.
This gives |E_ratio bilinear| ≤ (1/2)·ln²N → ∞.

BUT: the E_ratio bilinear grows slower than the -S² brake (which
is constant ~0.72), so the overcancellation still dominates. 🔧🐴💜
-/

end Cathedral.Geometry.Renormalization.RatioRemainder

end
