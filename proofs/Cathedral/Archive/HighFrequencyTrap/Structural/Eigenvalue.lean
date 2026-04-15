/-
  Cathedral/Structural/Eigenvalue.lean

  ## Eigenvalue monotonicity and interlacing.

  Core results:
  - eigenvalue_interlacing (Cauchy interlacing)
  - lambdaMin_shifted_antitone
  - eigenDrop_nonneg
  - telescoping identity
  - drop_formula_bound (axiom)
-/

import Cathedral.Defs
import Cathedral.Archive.HighFrequencyTrap.Spectral.RayleighBridge

noncomputable section
open Complex Real

/-- **Cauchy Interlacing** (PROVEN): λ_min(G_{N+1}) ≤ λ_min(G_N). -/
theorem eigenvalue_interlacing (N : ℕ) (hN : 2 ≤ N) :
    lambdaMin (N + 1) ≤ lambdaMin N := by
  obtain ⟨n, rfl⟩ : ∃ n, N = n + 1 := ⟨N - 1, by omega⟩
  have hn : 0 < n := by omega
  unfold lambdaMin
  simp only [show n + 1 ≥ 2 from by omega, show n + 2 ≥ 2 from by omega, dite_true]
  set H_n := gramMatrix_hermitian (n + 1)
  set H_n1 := gramMatrix_hermitian (n + 2)
  apply Finset.le_inf'
  intro j _
  have h_in_range : H_n.eigenvalues₀ j ∈ Set.range H_n.eigenvalues := by
    unfold Matrix.IsHermitian.eigenvalues
    exact ⟨(Fintype.equivOfCardEq (Fintype.card_fin _)) j,
           congr_arg _ (Equiv.symm_apply_apply _ j)⟩
  obtain ⟨i, hi⟩ := h_in_range
  rw [← hi]
  rw [← quadForm_eigenvector H_n i, ← quadForm_padVector]
  exact min_eigenvalue_le_quadForm H_n1 _
    (padVector_norm _ (H_n.eigenvectorBasis.orthonormal.1 i))
    (by omega)

theorem eigenvalue_antitone (N : ℕ) (hN : 2 ≤ N) :
    lambdaMin (N + 1) ≤ lambdaMin N := eigenvalue_interlacing N hN

/-- lambdaMin shifted to start at 0 is antitone on all of ℕ. -/
lemma lambdaMin_shifted_antitone : Antitone (fun n => lambdaMin (n + 2)) := by
  intro a b hab
  induction hab with
  | refl => exact le_refl _
  | step h ih => exact le_trans (eigenvalue_antitone _ (by omega)) ih

/-- lambdaMin is antitone for indices ≥ 2. -/
lemma lambdaMin_antitone_ge2 (M N : ℕ) (hM : 2 ≤ M) (hN : M ≤ N) :
    lambdaMin N ≤ lambdaMin M := by
  have := lambdaMin_shifted_antitone (show M - 2 ≤ N - 2 by omega)
  simp only at this
  have hM2 : M - 2 + 2 = M := by omega
  have hN2 : N - 2 + 2 = N := by omega
  rwa [hM2, hN2] at this

/-- The eigenvalue drop is non-negative (from Cauchy interlacing) -/
theorem eigenDrop_nonneg (N : ℕ) (hN : 3 ≤ N) : 0 ≤ eigenDrop N := by
  unfold eigenDrop
  have h2 : 2 ≤ N - 1 := by omega
  have := eigenvalue_antitone (N - 1) h2
  have hsimp : N - 1 + 1 = N := by omega
  rw [hsimp] at this
  linarith

/-- Telescoping: λ_min(G_N) = λ_min(G_{N₀}) - Σ_{k=N₀}^{N-1} δ_{k+1}. -/
theorem telescoping (N₀ N : ℕ) (h₀ : 2 ≤ N₀) (hN : N₀ ≤ N) :
    lambdaMin N = lambdaMin N₀ -
    ∑ k ∈ Finset.Ico N₀ N, eigenDrop (k + 1) := by
  simp_rw [eigenDrop_succ]
  induction N with
  | zero => simp [Nat.le_zero.mp hN]
  | succ n ih =>
    by_cases h : N₀ ≤ n
    · rw [Finset.sum_Ico_succ_top h]
      have := ih h
      linarith
    · push Not at h
      have : N₀ = n + 1 := by omega
      subst this
      simp

/-- **Drop formula** (Schur complement perturbation) — AXIOM. -/
axiom drop_formula_bound (N : ℕ) (hN : 3 ≤ N) :
    eigenDrop N ≤ (cosAlignment (N - 1))^2 *
      dotProduct (crossCorrVec (N - 1)) (crossCorrVec (N - 1)) /
      schurComplement (N - 1)

theorem drop_formula (N : ℕ) (hN : 3 ≤ N) :
    eigenDrop N ≤ (cosAlignment (N - 1))^2 *
      dotProduct (crossCorrVec (N - 1)) (crossCorrVec (N - 1)) /
      schurComplement (N - 1) := drop_formula_bound N hN

end
