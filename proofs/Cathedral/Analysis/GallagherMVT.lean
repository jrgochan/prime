/-
  Cathedral/Analysis/GallagherMVT.lean

  ## The Gallagher Bypass: MVT via Fejér Kernel

  ### Architecture (April 27, 2026 — GEMINI TACTICAL DIRECTIVE)

  Gemini's CRITICAL OVERRIDE: DO NOT attempt Vaaler's lemma.
  Instead, prove the MVT directly using the Fejér kernel.

  The key identity: for δ-separated frequencies λₙ,
    ∫ₐ |Σ aₙ e^{iλₙt}|² · δ · K(δt) dt = Σ |aₙ|²
  where K = sinc² (Fejér kernel).

  Proof:
  1. Expand |f|² = Σₘ Σₙ aₘ āₙ e^{i(λₘ-λₙ)t}
  2. Swap ∫ and Σ (integral_finset_sum, finite sums)
  3. Each term: aₘāₙ · δ · ∫ e^{iωt} K(δt) dt = aₘāₙ · K̂(ω/δ)
  4. FK4: K̂(ξ) = Λ(ξ) = 0 for |ξ| ≥ 1
  5. For m ≠ n: |λₘ-λₙ| ≥ δ, so |ω/δ| ≥ 1, so K̂ = 0
  6. For m = n: K̂(0) = Λ(0) = 1
  7. Therefore: I = Σ |aₙ|²

  This BYPASSES the Montgomery-Vaughan Hilbert inequality entirely.
  The constant is not π/δ but just 1 (exact identity, not inequality).

  ### Dependencies
  - HilbertInequality.lean (FK1-FK4, all PROVED)
  - PlancherelDefs.lean (Plancherel, PROVED)

  ### Sorry Status
  - fejer_weighted_identity: 1 sorry (Fubini + FK4 assembly)
  - gallagher_mvt: 1 sorry (connects identity to MVT bound)
-/

import Cathedral.Analysis.HilbertInequality
import Cathedral.MellinBridge.PlancherelDefs

noncomputable section
open Complex Real Finset BigOperators MeasureTheory
open scoped FourierTransform

namespace Cathedral.Analysis

-- ═══════════════════════════════════════════════
-- §1. TRIGONOMETRIC POLYNOMIAL DEFINITIONS
-- ═══════════════════════════════════════════════

/-- A trigonometric polynomial: f(t) = Σ aₙ e^{2πiλₙt} -/
def trigPoly {N : ℕ} (a : Fin N → ℂ) (lam : Fin N → ℝ) (t : ℝ) : ℂ :=
  ∑ n : Fin N, a n * Complex.exp (2 * π * lam n * t * I)

/-- The Fejér-weighted L² integral:
    I = ∫ₐ |f(t)|² · δ · K(δt) dt
    where K = sinc² is the Fejér kernel. -/
def fejerWeightedL2 {N : ℕ} (a : Fin N → ℂ) (lam : Fin N → ℝ) (δ : ℝ) : ℝ :=
  ∫ t : ℝ, ‖trigPoly a lam t‖ ^ 2 * (δ * fejerKernel (δ * t))

-- ═══════════════════════════════════════════════
-- §2. THE CROSS-TERM IDENTITY
-- ═══════════════════════════════════════════════

/-- Each cross-term integral equals K̂ evaluated at the frequency difference.

    ∫ e^{2πi(λₘ-λₙ)t} · δ · K(δt) dt = Λ((λₘ-λₙ)/δ)

    where Λ(ξ) = max(1-|ξ|, 0) is the triangle function (= K̂).

    Proof: Change of variables u = δt, then apply FK4 (Bridge theorem). -/
theorem cross_term_integral (ω δ : ℝ) (hδ : 0 < δ) :
    ∫ t : ℝ, (Complex.exp (2 * π * ω * t * I)).re * (δ * fejerKernel (δ * t)) =
    triangleFunction (ω / δ) := by
  sorry  -- Change of variables u = δt + FK Bridge theorem
         -- The key step: ∫ cos(2πωt) · δ · sinc²(δt) dt
         -- = ∫ cos(2π(ω/δ)u) · sinc²(u) du
         -- = triangleFunction(ω/δ)  (by FK Bridge, PROVED)

-- ═══════════════════════════════════════════════
-- §3. THE FEJÉR ORTHOGONALITY IDENTITY
-- ═══════════════════════════════════════════════

/-- **FEJÉR ORTHOGONALITY**: For δ-separated frequencies, the
    Fejér-weighted L² integral equals the sum of squared amplitudes.

    ∫ₐ |Σ aₙ e^{2πiλₙt}|² · δ · K(δt) dt = Σ |aₙ|²

    This is the Gallagher bypass: instead of bounding the bilinear form
    Σ aₘāₙ/(λₘ-λₙ) via Montgomery-Vaughan, we DIRECTLY prove that
    the Fejér-weighted integral collapses to the diagonal.

    Dependencies:
    - integral_finset_sum (Mathlib, for swapping ∫ and Σ)
    - cross_term_integral (above)
    - FK4: triangleFunction(ξ) = 0 for |ξ| ≥ 1 (HilbertInequality.lean, PROVED)
    - FK3: triangleFunction(0) = 1 (HilbertInequality.lean, PROVED) -/
theorem fejer_orthogonality
    {N : ℕ} (a : Fin N → ℂ) (lam : Fin N → ℝ) (δ : ℝ) (hδ : 0 < δ)
    (h_sep : IsDeltaSeparated lam δ) :
    fejerWeightedL2 a lam δ = ∑ n : Fin N, ‖a n‖ ^ 2 := by
  -- The proof assembles these PROVED facts:
  -- 1. Expand |f|² = Σ_m Σ_n a_m * conj(a_n) * e^{2πi(λ_m-λ_n)t}
  -- 2. Swap ∫ and Σ (integral_finset_sum, trivial for finite sums)
  -- 3. Each cross-term: ∫ cos(2π(λ_m-λ_n)t) · δ·K(δt) dt
  --    = Λ((λ_m-λ_n)/δ) by cross_term_integral
  -- 4. Off-diagonal (m≠n): |λ_m-λ_n| ≥ δ, so |(λ_m-λ_n)/δ| ≥ 1
  --    → Λ = 0 by triangleFunction_support (PROVED)
  -- 5. Diagonal (m=n): Λ(0) = 1 by triangleFunction_zero (PROVED)
  -- 6. Total = Σ |a_n|² · 1 = Σ |a_n|²
  sorry

-- ═══════════════════════════════════════════════
-- §4. THE FEJÉR-WEIGHTED MVT
-- ═══════════════════════════════════════════════

/-- **NON-NEGATIVITY**: The Fejér-weighted L² integral is non-negative.
    Follows immediately from FK1 (fejerKernel_nonneg). -/
theorem fejerWeightedL2_nonneg
    {N : ℕ} (a : Fin N → ℂ) (lam : Fin N → ℝ) (δ : ℝ) (hδ : 0 < δ) :
    0 ≤ fejerWeightedL2 a lam δ := by
  unfold fejerWeightedL2
  apply integral_nonneg
  intro t
  apply mul_nonneg
  · exact sq_nonneg _
  · apply mul_nonneg (le_of_lt hδ)
    exact fejerKernel_nonneg _

/-- **KEY BOUND**: The Fejér kernel provides an upper bound on the
    interval integral via the identity K(x) ≤ K(0) = 1 for all x.

    Since 0 ≤ K(δt) ≤ 1 for all t:
      δ · ∫_{-T}^{T} |f|² dt ≤ ∫_ℝ |f|² · δ · K(δt) dt · (some correction)

    More precisely, for |t| ≤ T with δT ≤ 1:
      K(δt) = sinc²(δt) ≥ sinc²(δT) ≥ c > 0

    So: ∫_{-T}^{T} |f|² ≤ (1/c) · ∫_ℝ |f|² · δ·K(δt) dt
                          = (1/c) · Σ|aₙ|²  by fejer_orthogonality

    With c = sinc²(1) = (sin π/π)² = 0 — wait, sinc(1) = 0!
    We need δT < 1, i.e., T < 1/δ. -/

-- For the Cathedral, we need a different formulation.
-- The Crown Axiom needs ∫_ℝ |M|² (over ALL of ℝ), not over [-T,T].
-- The Fejér orthogonality gives us the exact tool.

/-- **GALLAGHER MVT (Fejér-weighted version)**:
    For δ-separated frequencies and the Fejér weight δ·K(δt):

      ∫_ℝ |Σ aₙ e^{2πiλₙt}|² · δ · K(δt) dt = Σ |aₙ|²

    This is an EXACT IDENTITY, not an inequality.
    It bypasses Montgomery-Vaughan entirely.

    For the MVT application with λₙ = logn/(2π), δ = 1/(2πN),
    this gives the weighted L² norm exactly. -/
theorem gallagher_mvt
    {N : ℕ} (a : Fin N → ℂ) (lam : Fin N → ℝ) (δ : ℝ) (hδ : 0 < δ)
    (h_sep : IsDeltaSeparated lam δ) :
    ∫ t : ℝ, ‖trigPoly a lam t‖ ^ 2 * (δ * fejerKernel (δ * t)) =
    ∑ n : Fin N, ‖a n‖ ^ 2 :=
  fejer_orthogonality a lam δ hδ h_sep

-- ═══════════════════════════════════════════════
-- §5. APPLICATION TO DIRICHLET POLYNOMIALS
-- ═══════════════════════════════════════════════

/-- For Dirichlet polynomials D(t) = Σ aₙ n^{-1/2-it}, the frequencies
    are λₙ = -log(n)/(2π), and the minimum separation for n ∈ [1,N] is:
      δ = min_{m≠n} |logm - logn|/(2π) = log(N/(N-1))/(2π) ≥ 1/(2πN)

    The Fejér orthogonality gives:
      ∫_ℝ |D(t)|² · (1/(2πN)) · K(t/(2πN)) dt = Σ |aₙ|²/n

    This provides the exact L² norm of the Dirichlet polynomial
    in the Fejér-weighted space. -/

-- The connection to the Crown Axiom:
-- M(1/2+it) = R(1/2+it) + (ζ(1/2+it)/(1/2+it)) · D(1/2+it)
-- ∫|M|² ≤ 2∫|R|² + 2∫|ζ/s|²·|D|²
-- The R term is rational and bounded.
-- The ζ/s · D term: |ζ(1/2+it)/(1/2+it)|² ≤ C (under RH)
-- ∫|ζ/s|²·|D|² ≤ C · ∫|D|² · w(t) for appropriate w
-- And the Fejér identity controls ∫|D|² · w.

-- ═══════════════════════════════════════════════
-- §6. AUDIT
-- ═══════════════════════════════════════════════

-- PROVED (zero sorry):
--   ✅ trigPoly — definition
--   ✅ fejerWeightedL2 — definition
--   ✅ fejerWeightedL2_nonneg — K ≥ 0 (from FK1)
--
-- SORRY (2):
--   🟡 cross_term_integral — change of variables + FK Bridge
--   🟡 fejer_orthogonality — sum expansion + FK4 kill + FK3 diagonal
--
-- These 2 sorrys use ONLY proved infrastructure:
--   - triangleFunction_inverseFT_eq_fejerKernel (PROVED, 970 lines)
--   - triangleFunction_support (PROVED)
--   - triangleFunction_zero (PROVED)
--   - integral_finset_sum (Mathlib)

end Cathedral.Analysis
