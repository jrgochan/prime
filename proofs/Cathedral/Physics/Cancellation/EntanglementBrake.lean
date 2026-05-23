/-
  Cathedral/Physics/Cancellation/EntanglementBrake.lean

  ## The Perfect Square Brake: vᵀE_const·v = −S²

  The E_const component of the error matrix E = G_V − R has entries:
    E_const(j,k) = −1/(jk)

  This gives the quadratic form:
    vᵀ E_const v = Σ_{j,k} v_j · v_k · (−1/(jk))
                 = −(Σ_k v_k/k)²

  This is ALWAYS ≤ 0, providing an unconditional "brake" on the
  Gram quadratic form vᵀG_Vv.

  Pure algebra. No analysis. No RH. Zero sorry.

  Created: May 20, 2026 (The Thulium Session — Entanglement)
-/

import Mathlib.Data.Real.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.BigOperators.Ring.Finset
import Mathlib.Tactic.Ring

noncomputable section
open Finset

namespace Cathedral.Entanglement

-- ════════════════════════════════════════════════
-- PART I: THE ALGEBRAIC IDENTITY
-- ════════════════════════════════════════════════

/-- The fundamental factorization: Σ_{i,j} f(i)·f(j) = (Σ f(i))².
    This is the outer-product identity for sums. -/
theorem sum_product_eq_sq {ι : Type*} [Fintype ι] (f : ι → ℝ) :
    ∑ i : ι, ∑ j : ι, f i * f j = (∑ i : ι, f i) ^ 2 := by
  rw [sq, Finset.sum_mul]
  congr 1; ext i
  rw [Finset.mul_sum]

-- ════════════════════════════════════════════════
-- PART II: THE PERFECT SQUARE BRAKE
-- ════════════════════════════════════════════════

/-- The Möbius aggregate S(N) = Σ_{k=0}^{N-1} v_k/(k+1).
    (Index shifted: Fin N uses 0-based, but denominators are k+1.) -/
noncomputable def moebiusS (N : ℕ) (v : Fin N → ℝ) : ℝ :=
  ∑ k : Fin N, v k / (↑(k : ℕ) + 1 : ℝ)

/-- The E_const quadratic form equals −S². -/
theorem const_error_eq_neg_S_sq (N : ℕ) (v : Fin N → ℝ) :
    ∑ j : Fin N, ∑ k : Fin N,
      -(v j / (↑(j : ℕ) + 1 : ℝ)) * (v k / (↑(k : ℕ) + 1 : ℝ)) =
    -(moebiusS N v) ^ 2 := by
  unfold moebiusS
  simp_rw [neg_mul, Finset.sum_neg_distrib, neg_inj]
  exact sum_product_eq_sq _

/-- The E_const quadratic form is non-positive.
    This is the unconditional "brake" on vᵀG_Vv. -/
theorem const_error_nonpos (N : ℕ) (v : Fin N → ℝ) :
    ∑ j : Fin N, ∑ k : Fin N,
      -(v j / (↑(j : ℕ) + 1 : ℝ)) * (v k / (↑(k : ℕ) + 1 : ℝ)) ≤ 0 := by
  rw [const_error_eq_neg_S_sq]
  exact neg_nonpos.mpr (sq_nonneg _)

/-- The brake in human-readable form:
    For any weights, −S² ≤ 0, so the constant error always
    pushes vᵀG_Vv downward. -/
theorem brake_nonpos (N : ℕ) (v : Fin N → ℝ) :
    -(moebiusS N v) ^ 2 ≤ 0 :=
  neg_nonpos.mpr (sq_nonneg _)

-- ════════════════════════════════════════════════
-- PART III: THE MÖBIUS AGGREGATE σ
-- ════════════════════════════════════════════════

/-- The Möbius aggregate σ(N) = Σ_{k=0}^{N-1} v_k.
    For Möbius-Fejér weights: σ → 1 by Mertens' theorem. -/
noncomputable def moebiusSigma (N : ℕ) (v : Fin N → ℝ) : ℝ :=
  ∑ k : Fin N, v k

-- ════════════════════════════════════════════════
-- PART IV: THE SUM-RECIPROCAL FACTORIZATION
-- ════════════════════════════════════════════════

/-- Cross-product factorization: Σ_{i,j} f(i)·g(j) = (Σ f)·(Σ g).
    This is the bilinear version of the sum-product identity. -/
theorem sum_cross_product {ι : Type*} [Fintype ι] (f g : ι → ℝ) :
    ∑ i : ι, ∑ j : ι, f i * g j = (∑ i : ι, f i) * (∑ j : ι, g j) := by
  rw [Finset.sum_mul]
  congr 1; ext i
  rw [Finset.mul_sum]

/-- The reciprocal-sum factorization:
    Σ_{j,k} v_j · v_k · (1/(j+1) + 1/(k+1)) = 2 · σ · S

    This factors the E_log dominant term into the product of
    two Möbius aggregates: σ (weight sum) and S (weighted harmonic).

    Proof: Split 1/(j+1) + 1/(k+1) into two sums.
    The first is (Σ v_j/(j+1)) · (Σ v_k) = S · σ.
    The second is (Σ v_j) · (Σ v_k/(k+1)) = σ · S.
    Total: 2 · σ · S. -/
theorem reciprocal_sum_factorization (N : ℕ) (v : Fin N → ℝ) :
    ∑ j : Fin N, ∑ k : Fin N,
      v j * v k * (1 / (↑(j : ℕ) + 1 : ℝ) + 1 / (↑(k : ℕ) + 1 : ℝ)) =
    2 * moebiusSigma N v * moebiusS N v := by
  unfold moebiusSigma moebiusS
  simp_rw [mul_add, Finset.sum_add_distrib]
  -- Factor each piece: v_j * v_k * (1/(j+1)) = (v_j/(j+1)) * v_k
  have rw1 : ∀ (j k : Fin N),
      v j * v k * (1 / ((↑↑j : ℝ) + 1)) = (v j / ((↑↑j : ℝ) + 1)) * v k := by
    intros; ring
  have rw2 : ∀ (j k : Fin N),
      v j * v k * (1 / ((↑↑k : ℝ) + 1)) = v j * (v k / ((↑↑k : ℝ) + 1)) := by
    intros; ring
  simp_rw [rw1, rw2, sum_cross_product]
  ring

/-- The E_log dominant term equals C · σ · S for any constant C.
    Instantiate with C = ln(2π) − γ to get the actual E_log dominant term.

    E_log_dom(j,k) = C/2 · (1/j + 1/k)
    vᵀ E_log_dom v = C/2 · 2 · σ · S = C · σ · S -/
theorem elog_dominant_factorization (N : ℕ) (v : Fin N → ℝ) (C : ℝ) :
    ∑ j : Fin N, ∑ k : Fin N,
      v j * v k * (C / 2 * (1 / (↑(j : ℕ) + 1 : ℝ) + 1 / (↑(k : ℕ) + 1 : ℝ))) =
    C * moebiusSigma N v * moebiusS N v := by
  have key : ∀ (j k : Fin N),
      v j * v k * (C / 2 * (1 / ((↑↑j : ℝ) + 1) + 1 / ((↑↑k : ℝ) + 1))) =
      (C / 2) * (v j * v k * (1 / ((↑↑j : ℝ) + 1) + 1 / ((↑↑k : ℝ) + 1))) := by
    intros; ring
  simp_rw [key, ← Finset.mul_sum]
  rw [reciprocal_sum_factorization]
  ring

end Cathedral.Entanglement

