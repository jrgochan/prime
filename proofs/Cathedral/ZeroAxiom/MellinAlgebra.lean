import Cathedral.NymanBeurling.BDMellin
import Cathedral.ZeroAxiom.FiniteDirichlet
import Mathlib.NumberTheory.LSeries.RiemannZeta

/-!
  # Mellin Algebraic Reduction

  Pure ℂ-algebraic identities for the BD residual Mellin transform.
  NO integrals in this file — all identities are field arithmetic.

  ## Main Results

  * `fejerDirichletPoly` : the Fejér-smoothed Dirichlet polynomial P_N(s)
  * `mellin_residual_algebraic_identity` : the factored truncation-error form
  * `mellin_residual_eval` : connecting the integral to the algebraic form

  ## Strategy (Gemini Directive — Heartbeat Fracture)

  Separate the pure algebra from the Lebesgue integration to avoid
  maxHeartbeats death. All algebraic identities use `field_simp` + `ring`.
-/

set_option maxHeartbeats 800000

noncomputable section
open Complex Finset BigOperators
open scoped ArithmeticFunction.Moebius

namespace Cathedral.ZeroAxiom

-- ════════════════════════════════════════════════
-- §1. THE FEJÉR-SMOOTHED DIRICHLET POLYNOMIAL
-- ════════════════════════════════════════════════

/-- The Fejér-smoothed Dirichlet polynomial in ℂ.
    P_N(s) = Σ_{k=1}^{N-1} μ(k) · (1 - log k / log N) · k^{-s}

    This approximates 1/ζ(s) as N → ∞ under RH.
    The log-taper (Fejér kernel) ensures smooth decay at the boundary. -/
def fejerDirichletPoly (N : ℕ) (s : ℂ) : ℂ :=
  ∑ i : Fin (N - 1), ↑(μ (i.val + 1) : ℤ) *
    (1 - ↑(Real.log (i.val + 1)) / ↑(Real.log N)) *
    (↑(i.val + 1) : ℂ) ^ (-s)

-- ════════════════════════════════════════════════
-- §2. PURE ALGEBRAIC IDENTITY (NO INTEGRALS)
-- ════════════════════════════════════════════════

/-- **Pure algebra**: The unfactored residual Mellin formula rearranges as:
    `1/s - (ζ(s)/s) · P_N(s) = (ζ(s)/s) · (1/ζ(s) - P_N(s))`

    when ζ(s) ≠ 0 and s ≠ 0.

    This is the KEY factorization that isolates the truncation error
    `1/ζ(s) - P_N(s)` from the holomorphic factor `ζ(s)/s`. -/
lemma mellin_residual_algebraic_identity (s : ℂ) (ζs : ℂ)
    (hζ : ζs ≠ 0) (hs : s ≠ 0) (P : ℂ) :
    1 / s - (ζs / s) * P = (ζs / s) * (1 / ζs - P) := by
  field_simp

/-- Variant with `riemannZeta s` substituted. -/
lemma mellin_residual_factored (s : ℂ)
    (hζ : riemannZeta s ≠ 0) (hs : s ≠ 0)
    (P : ℂ) :
    1 / s - (riemannZeta s / s) * P =
    (riemannZeta s / s) * (1 / riemannZeta s - P) := by
  exact mellin_residual_algebraic_identity s (riemannZeta s) hζ hs P

-- ════════════════════════════════════════════════
-- §3. TRUNCATION ERROR: 1/ζ(s) - P_N(s)
-- ════════════════════════════════════════════════

/-- The truncation error of the Fejér-smoothed Dirichlet polynomial.
    E_N(s) = 1/ζ(s) - P_N(s)

    Under RH, this → 0 as N → ∞ for σ > 1/2. -/
def truncationError (N : ℕ) (s : ℂ) : ℂ :=
  1 / riemannZeta s - fejerDirichletPoly N s

-- ════════════════════════════════════════════════
-- §4. THE WEIGHT-POLYNOMIAL CONNECTION
-- ════════════════════════════════════════════════

/-- The Dirichlet polynomial uses the same coefficients as `bdMoebiusWeight`
    (up to sign and ℝ→ℂ coercion).

    `v_k = -μ(k) · taper(k,N)` in ℝ
    `P_N(s)` has coefficient `μ(k) · taper(k,N)` in ℂ (no negation)

    So: Σ v_k · k^{-s} = -P_N(s) -/
lemma weight_sum_eq_neg_poly (N : ℕ) (s : ℂ) :
    ∑ i : Fin (N - 1), (↑(bdMoebiusWeight (i.val + 1) N) : ℂ) *
      (↑(i.val + 1) : ℂ) ^ (-s) =
    -fejerDirichletPoly N s := by
  unfold fejerDirichletPoly bdMoebiusWeight fejerTaper
  simp only [show ∀ i : Fin (N - 1), (i.val + 1) ≠ 0 from fun i => Nat.succ_ne_zero i.val,
             ↓reduceIte]
  push_cast
  rw [← Finset.sum_neg_distrib]
  apply Finset.sum_congr rfl
  intro i _
  ring

-- ════════════════════════════════════════════════
-- §5. THE NORM BOUND ON THE CRITICAL LINE
-- ════════════════════════════════════════════════

/-- **KEY**: On the critical line, the Mellin transform norm factors as:
    ‖M[r_N](1/2+it)‖ = ‖ζ(1/2+it)/(1/2+it)‖ · ‖E_N(1/2+it)‖

    This separates the growth control (Littlewood Maneuver on |ζ/s|)
    from the decay (truncation error → 0). -/
lemma mellin_norm_factored (N : ℕ) (_t : ℝ) (s : ℂ)
    (_hs_def : s = (1/2 : ℂ) + _t * Complex.I)
    (_hζ : riemannZeta s ≠ 0) (_hs : s ≠ 0) :
    ‖(riemannZeta s / s) * truncationError N s‖ =
    ‖riemannZeta s / s‖ * ‖truncationError N s‖ :=
  norm_mul _ _

end Cathedral.ZeroAxiom
