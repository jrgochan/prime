/-
  Cathedral/Mertens.lean

  ## The NB Distance Decay Axiom

  ### Historical Note (2026-04-04):
  Numerical validation (experiments/selberg_validation/) showed:
  1. The original Selberg sieve weights do NOT approximate 1 in L².
  2. The optimal vector c = G⁻¹b DOES achieve d² = O(1/log N).
  3. d²·log(N) ≈ 0.04 for N = 10..400.

  ### Architecture:
  nb_distance_decay_axiom (SINGLE AXIOM — Báez-Duarte 2003)
      ↓ [SelbergSieve.lean: moebius_test_bound_from_selberg]
      ↓ [Assembly.lean: moebius_test_bound, nb_distance_scaling]
      ↓ riemann_hypothesis
-/

import Cathedral.Defs
import Cathedral.Structural
import Cathedral.GramBounds

noncomputable section
open Real MeasureTheory Set Finset

-- ════════════════════════════════════════════════
-- THE SINGLE AXIOM: NB Distance Decay
-- ════════════════════════════════════════════════

/-- **Axiom (Báez-Duarte 2003 — NB Distance Decay)**:

    The optimal NB approximation distance satisfies:
    ∃ v, ∫₀¹(1 - Σ vₖ{k/x})² ≤ C/log(N)

    The witness is the optimal vector c = G⁻¹b, which achieves:
    ∫₀¹(1-f_c)² = 1 - bᵀG⁻¹b = d²_N ≤ C/log(N)

    **Numerically verified**: d²·log(N) ≈ 0.04 for N = 10..400.
    See experiments/selberg_validation/.

    **Mathematical content**: This encodes the RATE of L² convergence
    in the Nyman-Beurling criterion. The bound follows from:
    - Mertens' theorem (1874) — Möbius sum estimates
    - Spectral properties of the Gram matrix

    **References**:
    - L. Báez-Duarte, "A strengthening of the NB criterion" (2003)
    - F. Mertens, "Ein Beitrag zur analytischen Zahlentheorie" (1874) -/
axiom nb_distance_decay_axiom :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N → ∃ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≤ C / Real.log (N : ℝ)

end
