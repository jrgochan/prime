/-
  Cathedral/Spectral/BilinearSieve.lean

  # Phase 3: Bilinear Form → Large Sieve

  ## Purpose

  Given the Fourier decomposition of the Gram matrix (Phase 2),
  this file connects the bilinear form vᵀGv to the Montgomery-Vaughan
  Large Sieve inequality, establishing the bound:

    vᵀGv ≤ C · Σ |vₖ|² · (k + 1)

  ## Architecture

  1. The Gram bilinear form vᵀGv = Σ_{j,k} vⱼ vₖ G(j,k)
  2. Via B₁ decomposition: vᵀGv = ∫₀¹ |Σ vₖ B₁(1/kx)|² dx + cross terms
  3. Via Parseval: ∫|Σ vₖ B₁|² = Σ_n |Σ_k vₖ ĉₙ(k)|²
  4. Via Large Sieve: Σ_n |exponential sum|² ≤ (N + Q²) · Σ|aₖ|²

  The Möbius weights with log-taper then give Σ|aₖ|² = O(1/ln N).

  ## Dependencies
  - Cathedral.Spectral.FourierGram (Phase 1-2)
  - Cathedral.Analysis.MontgomeryVaughan (Large Sieve)

  Created: May 9, 2026 — Exploration 31
  Status: Phase 3 of 5
-/

import Cathedral.Spectral.FourierGram

set_option maxHeartbeats 400000

noncomputable section
open Real MeasureTheory Complex Filter Finset
open scoped BigOperators

namespace Cathedral.BilinearSieve

-- ════════════════════════════════════════════════
-- §1. THE BILINEAR FORM
-- ════════════════════════════════════════════════

/-- The finite bilinear form: vᵀGv = Σ_{j,k=1}^{N-1} vⱼ vₖ G(j,k).
    This is the quadratic form in the Nyman-Beurling distance formula:
      d²_N = 1 - 2bᵀv + vᵀGv -/
def bilinearForm (N : ℕ) (v : Fin (N - 1) → ℝ)
    (G : Fin (N - 1) → Fin (N - 1) → ℝ) : ℝ :=
  ∑ j : Fin (N - 1), ∑ k : Fin (N - 1), v j * v k * G j k

-- ════════════════════════════════════════════════
-- §2. THE B₁ BILINEAR DECOMPOSITION
-- ════════════════════════════════════════════════

/-- **The B₁ bilinear form**: After the B₁ decomposition of each G(j,k),
    the bilinear form vᵀGv splits as:

      vᵀGv = ∫₀¹ |Σ vₖ B₁(1/kx)|² dx
           + (Σ vₖ) · Σ vₖ (bₖ - 1/2)
           + ¼ · (Σ vₖ)²

    The first term is the pure Fourier-analyzable covariance.
    The second involves bₖ (known from Vasyunin).
    The third involves S₁ = Σ μ(k)wₖ/k → 0 (from PNT). -/
theorem bilinear_b1_decomposition (N : ℕ) (v : Fin (N - 1) → ℝ) :
    ∫ x in (0:ℝ)..1,
      (∑ j : Fin (N - 1),
        v j * Int.fract (1 / ((↑(j.val + 1) : ℝ) * x))) ^ 2 =
    ∫ x in (0:ℝ)..1,
      (∑ j : Fin (N - 1),
        v j * FourierGram.sawtoothReal (1 / ((↑(j.val + 1) : ℝ) * x))) ^ 2
    + 2 * (∑ j : Fin (N - 1), v j) *
      (∫ x in (0:ℝ)..1,
        ∑ j : Fin (N - 1),
          v j * FourierGram.sawtoothReal (1 / ((↑(j.val + 1) : ℝ) * x)))
    + (1/4) * (∑ j : Fin (N - 1), v j) ^ 2 := by
  -- Follows from pointwise {x} = B₁(x) + 1/2 substitution
  sorry -- Algebraic expansion using fract_eq_sawtooth_add_half

-- ════════════════════════════════════════════════
-- §3. THE FOURIER SPECTRAL BOUND
-- ════════════════════════════════════════════════

/-- **Fourier Spectral Bound (Phase 3 target)**:

    The pure B₁ covariance integral, after Parseval, becomes:

      ∫₀¹ |Σ vₖ B₁(1/kx)|² dx = Σ_{n≠0} |Σ_k vₖ · ĉₙ(k)|²

    where ĉₙ(k) = -1/(2πin) · e^{2πin·phase(k)} are the Fourier
    coefficients of B₁(u/k) on the periodic domain.

    The inner sums are exponential sums over rational phases n/k,
    which is EXACTLY the Farey spectrum that the Montgomery-Vaughan
    Large Sieve was designed to bound.

    Target theorem:
      ∫₀¹ |Σ vₖ B₁(1/kx)|² ≤ C · Σ (k+1) · |vₖ|² -/

-- ════════════════════════════════════════════════
-- §4. THE WITNESS COVARIANCE BOUND
-- ════════════════════════════════════════════════

/-- **The master bound**: Combining the B₁ decomposition with the
    Large Sieve bound gives:

      vᵀCv ≤ K/ln(N)

    where C = G - bbᵀ is the covariance matrix and v are the
    Möbius log-taper weights.

    This closes `witness_covariance_decay` when combined with
    the PNT weight norm bound (Phase 4). -/
theorem witness_covariance_bound_from_sieve
    (N : ℕ) (hN : 3 ≤ N)
    (v : Fin (N - 1) → ℝ)
    -- Hypothesis: v are the Möbius log-taper weights
    (hv : ∀ k : Fin (N - 1), |v k| ≤ 1 / Real.log N)
    -- Hypothesis: PNT gives Σ|vₖ|²·(k+1) = O(1/ln N)
    (hweight : ∑ k : Fin (N - 1), (v k) ^ 2 * (↑(k.val + 1) + 1) ≤ 1 / Real.log N) :
    -- Conclusion: the covariance is bounded
    ∃ K > 0,
    ∫ x in (0:ℝ)..1,
      (∑ j : Fin (N - 1),
        v j * FourierGram.sawtoothReal (1 / ((↑(j.val + 1) : ℝ) * x))) ^ 2
    ≤ K / Real.log N := by
  sorry -- Assembly: B₁ decomposition + Parseval + Large Sieve + weight bound

-- ════════════════════════════════════════════════
-- §5. AUDIT
-- ════════════════════════════════════════════════

/-!
## Audit

### Sorry: 2
  1. `bilinear_b1_decomposition` — algebraic expansion
  2. `witness_covariance_bound_from_sieve` — full assembly (Phase 3+4+5)

### Axioms: 0

### Architecture:
  This file sketches the complete chain from Gram matrix to covariance decay.
  The key ingredients are:
  - Phase 1-2 (FourierGram.lean): B₁ decomposition + Parseval
  - Phase 3 (this file): Bilinear form → Fourier spectral bound → Large Sieve
  - Phase 4 (TBD): Möbius weight norm = O(1/ln N)
  - Phase 5 (TBD): Assembly → graduate witness_covariance_decay

### Phase status:
  Phase 3/5: ▓▓░░░░░░ (structure mapped, 2 sorry)
-/

end Cathedral.BilinearSieve
