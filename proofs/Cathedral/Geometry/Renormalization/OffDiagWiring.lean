/-
  Cathedral/Geometry/Renormalization/OffDiagWiring.lean

  ## Step 4: Full Sum → Off-Diagonal Conversion

  AbelHammer proves factorizations for FULL double sums Σ_{j,k}.
  BilinearAbel defines offDiagonalSum as Σ_{j≠k}.
  This file bridges the two.

  Status: THE WIRING 🔧
  Created: June 7, 2026 — Mountain Session Night 🏔️
-/

import Mathlib.Data.Real.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.BigOperators.Ring.Finset
import Mathlib.Tactic.Ring
import Mathlib.Tactic.Linarith

noncomputable section
open Finset

namespace Cathedral.Geometry.Renormalization.OffDiagWiring

-- ════════════════════════════════════════════════════════════════
-- §1. SPLITTING A DOUBLE SUM INTO DIAGONAL + OFF-DIAGONAL
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: Any double sum splits into diagonal + off-diagonal.
    Σ_{j,k} f(j,k) = Σ_k f(k,k) + Σ_{j≠k} f(j,k) -/
theorem double_sum_split {n : ℕ} (f : Fin n → Fin n → ℝ) :
    ∑ j : Fin n, ∑ k : Fin n, f j k =
    (∑ k : Fin n, f k k) +
    (∑ j : Fin n, ∑ k : Fin n, if j = k then 0 else f j k) := by
  have key : ∀ j : Fin n, ∑ k : Fin n, f j k =
      f j j + ∑ k : Fin n, (if j = k then 0 else f j k) := by
    intro j
    conv_lhs => rw [show ∑ k : Fin n, f j k =
      ∑ k : Fin n, ((if j = k then f j k else 0) + (if j = k then 0 else f j k)) from by
        congr 1; ext k; split_ifs <;> simp]
    rw [Finset.sum_add_distrib]
    congr 1
    simp []
  simp_rw [key]
  rw [Finset.sum_add_distrib]

/-- **COROLLARY**: Off-diagonal = full - diagonal. -/
theorem offdiag_eq_full_minus_diag {n : ℕ} (f : Fin n → Fin n → ℝ) :
    ∑ j : Fin n, ∑ k : Fin n, (if j = k then 0 else f j k) =
    (∑ j : Fin n, ∑ k : Fin n, f j k) -
    (∑ k : Fin n, f k k) := by
  have := double_sum_split f
  linarith

-- ════════════════════════════════════════════════════════════════
-- §2. THE CONSTANT ERROR COMPONENT
-- ════════════════════════════════════════════════════════════════

/-- S = Σ v_k/(k+1): the harmonic Möbius aggregate. -/
def moebiusS {n : ℕ} (v : Fin n → ℝ) : ℝ :=
  ∑ k : Fin n, v k / (↑(k : ℕ) + 1)

/-- **THEOREM**: Full constant sum = -S².
    Σ_{j,k} -(v_j/(j+1))·(v_k/(k+1)) = -S² -/
theorem full_const_eq_neg_S_sq {n : ℕ} (v : Fin n → ℝ) :
    ∑ j : Fin n, ∑ k : Fin n,
      -(v j / (↑(j : ℕ) + 1)) * (v k / (↑(k : ℕ) + 1)) =
    -(moebiusS v) ^ 2 := by
  unfold moebiusS
  simp_rw [neg_mul, Finset.sum_neg_distrib, neg_inj, sq]
  rw [Finset.sum_mul]
  congr 1; ext j; rw [Finset.mul_sum]

/-- **THEOREM**: Off-diagonal constant = -S² + Σ (v_k/(k+1))².

    Σ_{j≠k} -(v_j/(j+1))(v_k/(k+1)) = -S² + Σ_k (v_k/(k+1))²

    This bridges AbelHammer's full-sum result to the off-diagonal. -/
theorem offdiag_const_eq {n : ℕ} (v : Fin n → ℝ) :
    ∑ j : Fin n, ∑ k : Fin n,
      (if j = k then 0 else -(v j / (↑(j : ℕ) + 1)) * (v k / (↑(k : ℕ) + 1))) =
    -(moebiusS v) ^ 2 + ∑ k : Fin n, (v k / (↑(k : ℕ) + 1)) ^ 2 := by
  have h_full := full_const_eq_neg_S_sq v
  have h_offdiag := offdiag_eq_full_minus_diag
    (fun j k => -(v j / (↑(j : ℕ) + 1)) * (v k / (↑(k : ℕ) + 1)))
  have h_diag : ∑ k : Fin n, -(v k / (↑(k : ℕ) + 1)) * (v k / (↑(k : ℕ) + 1)) =
      -(∑ k : Fin n, (v k / (↑(k : ℕ) + 1)) ^ 2) := by
    simp only [neg_mul, sq, Finset.sum_neg_distrib]
  linarith

-- ════════════════════════════════════════════════════════════════
-- §3. THE LOG DOMINANT COMPONENT
-- ════════════════════════════════════════════════════════════════

/-- σ = Σ v_k: the total weight. -/
def moebiusSigma {n : ℕ} (v : Fin n → ℝ) : ℝ :=
  ∑ k : Fin n, v k

/-- **THEOREM**: Full log-dominant sum = C·σ·S.
    Σ_{j,k} v_j·v_k·(C/2)·(1/(j+1) + 1/(k+1)) = C·σ·S -/
theorem full_log_eq_C_sigma_S {n : ℕ} (v : Fin n → ℝ) (C : ℝ) :
    ∑ j : Fin n, ∑ k : Fin n,
      v j * v k * (C / 2 * (1 / (↑(j : ℕ) + 1 : ℝ) + 1 / (↑(k : ℕ) + 1 : ℝ))) =
    C * moebiusSigma v * moebiusS v := by
  unfold moebiusSigma moebiusS
  simp_rw [mul_add, Finset.sum_add_distrib]
  have rw1 : ∀ (j k : Fin n),
      v j * v k * (C / 2 * (1 / ((↑↑j : ℝ) + 1))) = (C / 2) * ((v j / ((↑↑j : ℝ) + 1)) * v k) := by
    intros; ring
  have rw2 : ∀ (j k : Fin n),
      v j * v k * (C / 2 * (1 / ((↑↑k : ℝ) + 1))) = (C / 2) * (v j * (v k / ((↑↑k : ℝ) + 1))) := by
    intros; ring
  simp_rw [rw1, rw2, ← Finset.mul_sum]
  have h1 : ∀ (f g : Fin n → ℝ),
      ∑ i : Fin n, f i * ∑ _j : Fin n, g _j = (∑ i, f i) * (∑ j, g j) :=
    fun f g => by rw [Finset.sum_mul]
  simp_rw [h1]
  ring

-- ════════════════════════════════════════════════════════════════
-- §4. COMBINED: PERFECT SQUARE IN OFF-DIAGONAL
-- ════════════════════════════════════════════════════════════════

/-- **THE PERFECT SQUARE**: C·σ·S - S² = -(S-Cσ/2)² + C²σ²/4.
    Pure algebra — the heart of overcancellation. -/
theorem perfect_square (S σ C : ℝ) :
    C * σ * S - S ^ 2 = -(S - C * σ / 2) ^ 2 + C ^ 2 * σ ^ 2 / 4 := by
  ring

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit — OffDiagWiring.lean (June 7, 2026)

### Sorry: 0 ✅
### Custom Axioms: 0 ✅

### Theorems: 6

| # | Name | Content |
|---|------|---------|
| 1 | `double_sum_split` | Σ f = Σ_diag + Σ_offdiag |
| 2 | `offdiag_eq_full_minus_diag` | offDiag = full - diag |
| 3 | `full_const_eq_neg_S_sq` | Σ -h(j)h(k) = -S² |
| 4 | `offdiag_const_eq` | off-diag const = -S² + Σ h² |
| 5 | `full_log_eq_C_sigma_S` | Σ log terms = C·σ·S |
| 6 | `perfect_square` | C·σ·S-S² = -(S-Cσ/2)²+C²σ²/4 |

Step 4 of the GramFormProof wiring map.
The water flows through the pipe. 🔧🐴💜
-/

end Cathedral.Geometry.Renormalization.OffDiagWiring

end
