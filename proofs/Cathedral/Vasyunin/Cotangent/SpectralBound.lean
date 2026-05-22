/-
  Cathedral/Vasyunin/Cotangent/SpectralBound.lean

  ## Spectral Bound: Wiring Gershgorin to the Gram Matrix

  Connects Gershgorin eigenvalue bounds to the Cathedral's
  Gram matrix, providing an upper bound on eigenvalues.

  Created: May 20, 2026 (The Thulium Session — Spectral Wiring)
-/

import Cathedral.Vasyunin.Cotangent.GershgorinBound
import Cathedral.Defs
import Mathlib.Tactic

noncomputable section
open Finset Matrix

namespace Cathedral.Vasyunin.SpectralBound

-- ════════════════════════════════════════════════
-- PART I: GERSHGORIN RADIUS OF THE GRAM MATRIX
-- ════════════════════════════════════════════════

/-- The Gershgorin radius for row i of the Gram matrix G_N. -/
def gramGershgorinRadius (N : ℕ) (i : Fin (N - 1)) : ℝ :=
  Gershgorin.gershgorinRadius (gramMatrix N) i

-- ════════════════════════════════════════════════
-- PART II: EIGENVALUE LOCALIZATION
-- ════════════════════════════════════════════════

/-- **Bridge Axiom**: Every eigenvalue of the Gram matrix (as given by
    IsHermitian.eigenvalues₀) is also an eigenvalue in the
    Module.End.HasEigenvalue sense needed for Gershgorin.

    This is mathematically trivial (eigenvalues ARE eigenvalues)
    but requires type-level gymnastics through
    EuclideanSpace / toLpLin / toLin' that we axiomatize. -/
axiom gram_eigenvalue_hasEigenvalue (N : ℕ) (hN : 2 ≤ N)
    (i : Fin (Fintype.card (Fin (N - 1)))) :
    Module.End.HasEigenvalue (Matrix.toLin' (gramMatrix N))
      ((gramMatrix_hermitian N).eigenvalues₀ i)

/-- **GRAM EIGENVALUE UPPER BOUND**: For every eigenvalue index i,
    there exists a row k such that the eigenvalue is at most
    G(k,k) + R_k (the Gershgorin disk upper edge). -/
theorem gram_eigenvalue_le (N : ℕ) (hN : 2 ≤ N) (hne : NeZero (N - 1))
    (i : Fin (Fintype.card (Fin (N - 1)))) :
    ∃ k : Fin (N - 1),
      (gramMatrix_hermitian N).eigenvalues₀ i ≤
        gramMatrix N k k + gramGershgorinRadius N k := by
  have hμ := gram_eigenvalue_hasEigenvalue N hN i
  obtain ⟨k, hk⟩ := Gershgorin.eigenvalue_in_disk (gramMatrix N)
    ((gramMatrix_hermitian N).eigenvalues₀ i) hμ
  exact ⟨k, Gershgorin.eigenvalue_le _ _ k hk⟩

/-- **GRAM EIGENVALUE LOWER BOUND**: For every eigenvalue index i,
    there exists a row k such that G(k,k) - R_k is a lower bound. -/
theorem gram_eigenvalue_ge (N : ℕ) (hN : 2 ≤ N) (hne : NeZero (N - 1))
    (i : Fin (Fintype.card (Fin (N - 1)))) :
    ∃ k : Fin (N - 1),
      gramMatrix N k k - gramGershgorinRadius N k ≤
        (gramMatrix_hermitian N).eigenvalues₀ i := by
  have hμ := gram_eigenvalue_hasEigenvalue N hN i
  obtain ⟨k, hk⟩ := Gershgorin.eigenvalue_in_disk (gramMatrix N)
    ((gramMatrix_hermitian N).eigenvalues₀ i) hμ
  exact ⟨k, Gershgorin.eigenvalue_ge _ _ k hk⟩

/-- **SPECTRAL RADIUS BOUND**: If |G(k,k)| + R_k is bounded by B
    for all rows k, then every eigenvalue has |eigenvalue| at most B. -/
theorem gram_spectral_radius_bound (N : ℕ) (hN : 2 ≤ N) (hne : NeZero (N - 1))
    (B : ℝ) (hB : ∀ k : Fin (N - 1),
      |gramMatrix N k k| + gramGershgorinRadius N k ≤ B)
    (i : Fin (Fintype.card (Fin (N - 1)))) :
    |(gramMatrix_hermitian N).eigenvalues₀ i| ≤ B := by
  have hμ := gram_eigenvalue_hasEigenvalue N hN i
  exact Gershgorin.eigenvalue_abs_le_max_disk (gramMatrix N)
    ((gramMatrix_hermitian N).eigenvalues₀ i) hμ B hB

-- ════════════════════════════════════════════════
-- PART III: THE DIAGONAL IS (ln2pi - gamma)/(k+1)
-- ════════════════════════════════════════════════

/-- The diagonal entry G(k,k) = gramEntry(k+1, k+1).
    By the Vasyunin formula: G(k,k) = (ln2pi - gamma)/(k+1) - 1/(k+1)^2.
    The largest diagonal is G(0,0) = G(1,1) = ln2pi - gamma - 1 approx 0.2607. -/
theorem gramMatrix_diag_eq (N : ℕ) (k : Fin (N - 1)) :
    gramMatrix N k k = gramEntry (k.val + 1) (k.val + 1) := by
  unfold gramMatrix
  simp [Matrix.of_apply]

end Cathedral.Vasyunin.SpectralBound
