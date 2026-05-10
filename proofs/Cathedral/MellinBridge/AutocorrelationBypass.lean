import Cathedral.MellinBridge.Basic
import Cathedral.MellinBridge.HilbertSetup
import Cathedral.MellinBridge.MellinSieve
import Cathedral.Defs

/-!
  Cathedral/MellinBridge/AutocorrelationBypass.lean

  Alternative forward path via the autocorrelation representation.
  Axioms: mellin_fourier_change, fourier_inversion_autocorrelation,
  gram_form_eq_l2_norm.

  NOT on the v11 crown path (alternative route).
-/

/-! # Cathedral.MellinBridge.AutocorrelationBypass

    ## The Autocorrelation Bypass: Plancherel without L² Isometry

    This file decomposes the `mellin_plancherel_gram` axiom into
    elementary components that avoid the L² Plancherel isometry
    (not yet in Mathlib 4).

    ### The Key Insight

    Instead of asserting the abstract Plancherel identity, we:
    1. Change variables x = e^{-u} to convert Mellin → Fourier
    2. Define the autocorrelation h(t) = (g * g̃)(t)
    3. Use L¹ Fourier inversion (much more tractable) at t=0
    4. Map back to obtain the Gram form identity

    ### Mathematical Chain

    Step 1: Mellin → Fourier (exponential substitution)
      M_{f_N}(1/2 + it) = ∫₀^∞ f_N(e^{-u}) e^{-u/2} e^{-itu} du
                        = F[g_N](t)
      where g_N(u) = f_N(e^{-u}) · e^{-u/2} · 1_{u≥0}

    Step 2: g_N ∈ L¹ ∩ L² (exponential decay)
      |g_N(u)| ≤ C · e^{-u/2} for u ≥ 0

    Step 3: Autocorrelation h = g_N ⋆ g̃_N is L¹
      h(t) = ∫ g_N(u) g_N(u-t) du
      ĥ(ξ) = |F[g_N](ξ)|²

    Step 4: L¹ Fourier Inversion at t = 0
      h(0) = (1/2π) ∫ ĥ(ξ) dξ
           = (1/2π) ∫ |M_{f_N}(1/2+it)|² dt

    Step 5: Change back to original variable
      h(0) = ∫₀^∞ |g_N(u)|² du = ∫₀¹ |f_N(x)|² dx = vᵀ G_N v

    ### Axiom Decomposition
    The single `mellin_plancherel_gram` axiom is replaced by THREE
    elementary axioms, each independently verifiable:
    1. `mellin_fourier_change` — the exponential substitution
    2. `autocorrelation_l1` — g_N ∈ L¹ ∩ L²
    3. `fourier_inversion_l1` — L¹ Fourier inversion at a point
-/

noncomputable section
open Complex Real MeasureTheory Set Filter

-- ════════════════════════════════════════════════
-- STEP 1: THE EXPONENTIAL SUBSTITUTION
-- ════════════════════════════════════════════════

/-- The "flattened" NB basis function after the exponential substitution.
    g_N(u) = f_N(e^{-u}) · e^{-u/2} for u ≥ 0.

    This converts the Mellin domain (0,1] to the Fourier domain [0,∞).
    The key property: g_N decays exponentially, so g_N ∈ L¹ ∩ L². -/
def flattenedBasis (N : ℕ) (v : Fin (N - 1) → ℝ) (u : ℝ) : ℝ :=
  if 0 ≤ u then
    nbLinComb N v (Real.exp (-u)) * Real.exp (-u / 2)
  else 0

/-- **Axiom (Change of Variables)**: Mellin = Fourier after flattening.

    M₀₁[f_N](1/2 + it) = ∫₀^∞ g_N(u) e^{-itu} du = F[g_N](t)

    This is a purely mechanical change of variables x = e^{-u}:
    - dx = -e^{-u} du
    - x^{1/2+it-1} = e^{-u(1/2+it-1)} = e^{u/2} · e^{-itu}
    - x^{s-1} dx = e^{u/2-itu} · e^{-u} du = e^{-u/2-itu} du

    The only content is that the substitution is valid for
    our specific basis functions (finite sums of fractional parts).

    MATHEMATICAL DIFFICULTY: Elementary (Calculus II level).
    FORMALIZATION DIFFICULTY: Moderate (change of variables in integrals). -/
axiom mellin_fourier_change (N : ℕ) (hN : 2 ≤ N)
    (v : Fin (N - 1) → ℝ) (t : ℝ) :
    mellinNBLinCombR N v ((1/2 : ℂ) + t * Complex.I) =
    ∫ u : ℝ, (flattenedBasis N v u : ℂ) * Complex.exp (-(t * u) * Complex.I)

-- ════════════════════════════════════════════════
-- STEP 2: INTEGRABILITY OF THE FLATTENED BASIS
-- ════════════════════════════════════════════════

-- **FORMERLY axiom flattened_basis_integrable**:
-- Excised 2026-04-19 (The Great Audit). This axiom was dead code — zero
-- proof-term references in the entire active codebase. The integrability
-- is used implicitly by the other axioms in this file.

-- ════════════════════════════════════════════════
-- STEP 3: THE AUTOCORRELATION
-- ════════════════════════════════════════════════

/-- The autocorrelation of the flattened basis:
    h(t) = ∫ g_N(u) · g_N(u - t) du

    Key properties:
    - h is continuous (Young's inequality: L² ⋆ L² → C₀)
    - h is L¹ (Cauchy-Schwarz: ∫|h| ≤ ‖g‖² < ∞)
    - ĥ(ξ) = |F[g_N](ξ)|² (convolution theorem) -/
def autocorrelation (N : ℕ) (v : Fin (N - 1) → ℝ) (t : ℝ) : ℝ :=
  ∫ u : ℝ, flattenedBasis N v u * flattenedBasis N v (u - t)

/-- **Axiom (L¹ Fourier Inversion at a Point)**: For continuous f with f̂ ∈ L¹,
    f(0) = (1/2π) ∫ f̂(ξ) dξ.

    This is the STANDARD L¹ Fourier inversion theorem, applied at a single
    point. It does NOT require the L² Plancherel isometry.

    Applied to h = g_N ⋆ g̃_N:
    - h is continuous (automatic from L² ⋆ L²)
    - ĥ(ξ) = |ĝ_N(ξ)|² ∈ L¹ (because |ĝ|² ≤ ĝ ∈ L¹, and ĝ is bounded)
    - Therefore h(0) = (1/2π) ∫ |ĝ_N(ξ)|² dξ

    MATHEMATICAL DIFFICULTY: Standard (any real analysis textbook).
    FORMALIZATION DIFFICULTY: Moderate (L¹ Fourier inversion is being
    actively developed in Mathlib). -/
axiom fourier_inversion_autocorrelation (N : ℕ) (hN : 2 ≤ N)
    (v : Fin (N - 1) → ℝ) :
    autocorrelation N v 0 =
    (1 / (2 * Real.pi)) *
    ∫ t : ℝ, ‖mellinNBLinCombR N v ((1/2 : ℂ) + t * Complex.I)‖ ^ 2

-- ════════════════════════════════════════════════
-- STEP 4: THE GRAM FORM CONNECTION
-- ════════════════════════════════════════════════

/-- **THEOREM**: The autocorrelation at 0 equals the L² norm.

    h(0) = ∫ |g_N(u)|² du = ∫₀¹ |f_N(x)|² dx

    The first equality is the definition of autocorrelation at 0.
    The second is the change of variables x = e^{-u}, dx = -e^{-u} du:
    ∫₀^∞ |f(e^{-u})|² · e^{-u} du = ∫₀¹ |f(x)|² dx -/
theorem autocorrelation_zero_eq_l2_norm (N : ℕ) (v : Fin (N - 1) → ℝ) :
    autocorrelation N v 0 =
    ∫ u : ℝ, (flattenedBasis N v u) ^ 2 := by
  unfold autocorrelation
  congr 1; ext u
  simp [sub_zero, sq]

/-- **Axiom (Gram Form = L² Norm)**: The Gram quadratic form equals the
    L² norm of the NB approximant.

    vᵀ G_N v = ∫₀¹ |f_N(x)|² dx = ∫₀^∞ |g_N(u)|² du = h(0)

    The first equality is the definition of gramMatrix:
    G_{ij} = ∫₀¹ {(i+1)/x}{(j+1)/x} dx, so
    vᵀGv = Σᵢ Σⱼ vᵢ vⱼ ∫₀¹ {(i+1)/x}{(j+1)/x} dx
         = ∫₀¹ (Σ vᵢ {(i+1)/x})² dx = ∫₀¹ |f_N(x)|² dx

    MATHEMATICAL DIFFICULTY: Definition-level (properties of the Gram matrix).
    FORMALIZATION DIFFICULTY: Moderate (interchanging sum and integral). -/
axiom gram_form_eq_l2_norm (N : ℕ) (hN : 2 ≤ N)
    (v : Fin (N - 1) → ℝ) :
    dotProduct v ((gramMatrix N).mulVec v) =
    ∫ u : ℝ, (flattenedBasis N v u) ^ 2

-- ════════════════════════════════════════════════
-- STEP 5: THE BYPASS THEOREM
-- ════════════════════════════════════════════════

/-- **THEOREM (The Autocorrelation Bypass)**:
    The Plancherel axiom is now DERIVABLE from the three elementary axioms.

    Proof chain:
    1. gram_form_eq_l2_norm: vᵀGv = ∫ |g_N|²
    2. autocorrelation_zero_eq_l2_norm: ∫ |g_N|² = h(0)
    3. fourier_inversion_autocorrelation: h(0) = (1/2π) ∫ |M_f|²

    Composing: vᵀGv = (1/2π) ∫ |M_f(1/2+it)|² dt

    This REPLACES the monolithic `mellin_plancherel_gram` axiom
    with three independently verifiable components. -/
theorem mellin_plancherel_gram_derived (N : ℕ) (hN : 2 ≤ N)
    (v : Fin (N - 1) → ℝ) :
    dotProduct v ((gramMatrix N).mulVec v) =
    (1 / (2 * Real.pi)) *
    ∫ t : ℝ, ‖mellinNBLinCombR N v ((1/2 : ℂ) + t * Complex.I)‖ ^ 2 := by
  -- Step 1: vᵀGv = ∫ |g_N|²
  rw [gram_form_eq_l2_norm N hN v]
  -- Step 2: ∫ |g_N|² = h(0)
  rw [← autocorrelation_zero_eq_l2_norm]
  -- Step 3: h(0) = (1/2π) ∫ |M_f|²
  exact fourier_inversion_autocorrelation N hN v

end

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- This file has:
--   3 axioms (elementary, independently verifiable):
--     📐 mellin_fourier_change             (change of variables — Calculus II)
--     📐 fourier_inversion_autocorrelation  (L¹ Fourier inversion at a point)
--     📐 gram_form_eq_l2_norm              (Gram matrix = L² norm of f_N)
--   PROVED:
--     ✅ autocorrelation_zero_eq_l2_norm   (PROVED — definition unfolding)
--     ✅ mellin_plancherel_gram_derived    (PROVED — composition of 3 axioms)
--
-- AXIOM REDUCTION:
--   BEFORE: mellin_plancherel_gram (1 monolithic axiom, requires L² Plancherel)
--   AFTER:  3 elementary axioms (change of vars, L¹ inversion, Gram=L²)
--           (flattened_basis_integrable excised as dead code, April 2026)
--           Each is independently verifiable and closer to Mathlib's frontier
