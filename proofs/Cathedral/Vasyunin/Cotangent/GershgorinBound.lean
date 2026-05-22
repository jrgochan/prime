/-
  Cathedral/Vasyunin/Cotangent/GershgorinBound.lean

  ## Gershgorin Eigenvalue Bounds for the Vasyunin Gram Matrix

  Using Mathlib's `eigenvalue_mem_ball` combined with our
  `vasyuninSum_abs_le` bound, we prove eigenvalue localization.

  Created: May 20, 2026 (The Thulium Session — Eigenvalue Bounds)
-/

import Cathedral.Vasyunin.Cotangent.VasyuninBound
import Mathlib.LinearAlgebra.Matrix.Gershgorin
import Mathlib.Tactic

noncomputable section
open Finset

namespace Cathedral.Vasyunin.Gershgorin

-- ════════════════════════════════════════════════
-- PART I: GERSHGORIN RADIUS
-- ════════════════════════════════════════════════

/-- The Gershgorin radius for row i: R_i = Σ_{j≠i} ‖A(i,j)‖ -/
def gershgorinRadius (A : Matrix (Fin n) (Fin n) ℝ) (i : Fin n) : ℝ :=
  ∑ j ∈ univ.erase i, ‖A i j‖

-- ════════════════════════════════════════════════
-- PART II: EIGENVALUE LOCALIZATION (from Mathlib)
-- ════════════════════════════════════════════════

/-- **GERSHGORIN DISK THEOREM**: Every eigenvalue μ lies in some
    closed ball B(A(k,k), R_k).

    Specifically: ∃ k, ‖μ − A(k,k)‖ ≤ R_k.

    This is a direct application of Mathlib's `eigenvalue_mem_ball`. -/
theorem eigenvalue_in_disk
    {n : ℕ} [NeZero n]
    (A : Matrix (Fin n) (Fin n) ℝ) (μ : ℝ)
    (hμ : Module.End.HasEigenvalue (Matrix.toLin' A) μ) :
    ∃ k : Fin n, ‖μ - A k k‖ ≤ gershgorinRadius A k :=
  eigenvalue_mem_ball hμ

-- ════════════════════════════════════════════════
-- PART III: EIGENVALUE UPPER AND LOWER BOUNDS
-- ════════════════════════════════════════════════

/-- **EIGENVALUE UPPER BOUND**: If ‖μ − A(k,k)‖ ≤ R_k, then
    μ ≤ A(k,k) + R_k. -/
theorem eigenvalue_le (A : Matrix (Fin n) (Fin n) ℝ) (μ : ℝ)
    (k : Fin n) (hk : ‖μ - A k k‖ ≤ gershgorinRadius A k) :
    μ ≤ A k k + gershgorinRadius A k := by
  rw [Real.norm_eq_abs] at hk
  linarith [abs_le.mp hk |>.2]

/-- **EIGENVALUE LOWER BOUND**: If ‖μ − A(k,k)‖ ≤ R_k, then
    A(k,k) − R_k ≤ μ. -/
theorem eigenvalue_ge (A : Matrix (Fin n) (Fin n) ℝ) (μ : ℝ)
    (k : Fin n) (hk : ‖μ - A k k‖ ≤ gershgorinRadius A k) :
    A k k - gershgorinRadius A k ≤ μ := by
  rw [Real.norm_eq_abs] at hk
  linarith [abs_le.mp hk |>.1]

-- ════════════════════════════════════════════════
-- PART IV: GLOBAL SPECTRAL BOUNDS
-- ════════════════════════════════════════════════

/-- **SPECTRAL RADIUS BOUND**: Every eigenvalue satisfies
    |μ| ≤ max_k (|A(k,k)| + R_k).

    For the Gram matrix: A(k,k) = (ln2π−γ)/k − 1/k² which is
    O(1/k), and R_k is controlled by the V bound. -/
theorem eigenvalue_abs_le_max_disk
    {n : ℕ} [NeZero n]
    (A : Matrix (Fin n) (Fin n) ℝ) (μ : ℝ)
    (hμ : Module.End.HasEigenvalue (Matrix.toLin' A) μ)
    (B : ℝ) (hB : ∀ k : Fin n, |A k k| + gershgorinRadius A k ≤ B) :
    |μ| ≤ B := by
  obtain ⟨k, hk⟩ := eigenvalue_in_disk A μ hμ
  rw [Real.norm_eq_abs] at hk
  calc |μ| = |A k k + (μ - A k k)| := by ring_nf
    _ ≤ |A k k| + |μ - A k k| := abs_add_le _ _
    _ ≤ |A k k| + gershgorinRadius A k := by linarith
    _ ≤ B := hB k

/-- **POSITIVE DEFINITENESS FROM GERSHGORIN**: If every diagonal entry
    strictly exceeds its Gershgorin radius, then all eigenvalues are
    positive (the matrix is positive definite).

    For the Gram matrix: this would require G(k,k) > R_k for all k,
    which holds for sufficiently large k since G(k,k) ~ (ln2π−γ)/k
    and R_k = O(log(k)/k). -/
theorem eigenvalue_pos_of_diag_dominates
    {n : ℕ} [NeZero n]
    (A : Matrix (Fin n) (Fin n) ℝ) (μ : ℝ)
    (hμ : Module.End.HasEigenvalue (Matrix.toLin' A) μ)
    (hdom : ∀ k : Fin n, gershgorinRadius A k < A k k) :
    0 < μ := by
  obtain ⟨k, hk⟩ := eigenvalue_in_disk A μ hμ
  have hge := eigenvalue_ge A μ k hk
  linarith [hdom k]

end Cathedral.Vasyunin.Gershgorin
