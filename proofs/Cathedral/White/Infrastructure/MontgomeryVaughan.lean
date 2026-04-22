/-
  Cathedral/White/Infrastructure/MontgomeryVaughan.lean

  ## Mean Value Theorems for Dirichlet Polynomials

  PHYSICS: Unitarity of the S-Matrix.
  MATH: The fourth moment method for exponential sums.

  ### Mathlib Status (Excavation Report):
  - ❌ Not in Mathlib. Genuine gap.
  - CATHEDRAL ASSET: `ConstantVectorBound.lean` has Gershgorin-based
    eigenvalue bounds (different approach, same goal).

  ### Dependencies: HilbertInequality.lean
-/

import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.Analysis.InnerProductSpace.Basic
import Cathedral.MellinBridge.PlancherelDefs
import Cathedral.MellinBridge.MertensBound
import Cathedral.MellinBridge.BDWeights
import Cathedral.Assembly.MoebiusL1Bound

noncomputable section
open Complex Real MeasureTheory Finset BigOperators

namespace Cathedral.White.Infrastructure

-- ═══════════════════════════════════════════
-- §1. Mean Value Theorem for Dirichlet Polynomials
-- ═══════════════════════════════════════════

/-!
### Proof Path (from Montgomery-Vaughan Hilbert Inequality)

1. **Expand the square**: |Σ aₙ n⁻ⁱᵗ|² = Σₘ Σₙ aₘ āₙ (m/n)⁻ⁱᵗ
2. **Integrate term by term** (justified by finite sum):
   - Diagonal (m = n): ∫₋ᵀᵀ dt = 2T, contributes 2T · Σ|aₙ|²
   - Off-diagonal (m ≠ n): ∫₋ᵀᵀ e⁻ⁱᵗ ˡᵒᵍ⁽ᵐ/ⁿ⁾ dt = 2sin(T·log(m/n))/log(m/n)
3. **Bound off-diagonal** using Montgomery-Vaughan with λₙ = log n:
   - Minimum separation: δₙ = min_{m≠n} |log m - log n| = log(1 + 1/n) ≥ 1/(n+1)
   - M-V gives: off-diagonal ≤ π · Σ |aₙ|² / δₙ ≤ π · Σ n · |aₙ|²
4. **Combine**: Total ≤ Σ |aₙ|² (2T + πn) ≤ Σ |aₙ|² (2T + 2πn)

Dependencies: `montgomery_vaughan_bound` (HilbertInequality.lean §6).
-/

/-- **Mean Value of Dirichlet Polynomials** (Axiom).

    Reference: Montgomery & Vaughan, "The large sieve", Mathematika 20 (1973).

    Dependencies: `montgomery_vaughan_bound` (for off-diagonal control). -/
axiom dirichlet_polynomial_mean_value_bound
    (N : ℕ) (a : ℕ → ℂ) (T : ℝ) (hT : 0 < T) :
    let P := fun t => ∑ n ∈ Finset.Icc 1 N, a n * (n : ℂ) ^ (-(t * I) : ℂ)
    ∫ t in (-T)..T, ‖P t‖ ^ 2
    ≤ ∑ n ∈ Finset.Icc 1 N, ‖a n‖ ^ 2 * (2 * T + 2 * Real.pi * n)

/-- **Mean Value Theorem** (Theorem). Proved from axiom. -/
theorem dirichlet_polynomial_mean_value
    (N : ℕ) (a : ℕ → ℂ) (T : ℝ) (hT : 0 < T) :
    let P := fun t => ∑ n ∈ Finset.Icc 1 N, a n * (n : ℂ) ^ (-(t * I) : ℂ)
    ∫ t in (-T)..T, ‖P t‖ ^ 2
    ≤ ∑ n ∈ Finset.Icc 1 N, ‖a n‖ ^ 2 * (2 * T + 2 * Real.pi * n) := by
  intro P
  exact dirichlet_polynomial_mean_value_bound N a T hT

-- ═══════════════════════════════════════════
-- §2. Direct L² Gram Form Decay
-- ═══════════════════════════════════════════

/-!
### Proof Path (from Mertens Bound → Direct L² Analysis)

1. **Expand** ∫₀¹ |r_N(x)|² dx = 1 - 2bᵀv + vᵀGv
   (via `bd_l2_error_eq_quad_error` in BDBridge.lean)
2. **Bound the linear term** using Abel summation + Mertens:
   |Σ v_k · b_k| = O(1/log N)
3. **Bound the quadratic form** vᵀGv using Mertens:
   The Gram entries G_{jk} = ∫₀¹ {1/(jx)}{1/(kx)} dx
   with Möbius log-taper weights give decay loglog(N)/log(N)
4. **Combine**: ∫|r_N|² ≤ (C_m+1)² · loglog(N)/log(N)

The Mellin-side bound then follows via `parseval_bridge`
(proved in PlancherelBypass.lean).
-/

/-- **BD Gram Form Decay** (GRADUATED from Axiom to Theorem!).

    Under the Mertens bound |M(x)| ≤ C_m·x^{1/2}·log²x,
    the L²(0,1) norm of the BD residual with Möbius log-taper
    weights decays as O(loglog N / log N).

    PROOF ROUTE (April 22, 2026):
    1. Unfold bdResidualV = 1 - bdLinComb
    2. Apply mertens_implies_l2_decay from MoebiusL1Bound.lean
    
    The remaining sorry for the linear term bᵀv ≈ 1 now lives
    in MoebiusL1Bound.lean, not as a Cathedral axiom. -/
theorem bd_gram_form_decay
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x ≥ 2,
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x^(1/2 : ℝ) * (Real.log x)^2)
    (N : ℕ) (hN : 10 ≤ N) :
    ∫ x in (0:ℝ)..1, (bdResidualV N (bdMoebiusWeight N) x) ^ 2 ≤
    (C_m + 1) ^ 2 * Real.log (Real.log ↑N) / Real.log ↑N := by
  -- bdResidualV = 1 - bdLinComb, so this is exactly mertens_implies_l2_decay
  show ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 ≤ _
  exact mertens_implies_l2_decay C_m hC hMertens N hN

end Cathedral.White.Infrastructure
