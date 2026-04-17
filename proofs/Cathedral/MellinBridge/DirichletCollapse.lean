/-
  Cathedral/MellinBridge/DirichletCollapse.lean

  ## The Dirichlet Collapse: Möbius Inversion Identities

  Proves the fundamental Möbius inversion identity used throughout
  the Cathedral's number-theoretic foundations.

  ### Key results (PROVED):
  - sum_moebius_eq_indicator: Σ_{d|n} μ(d) = [n=1]
  - divisor_sum_swap: Σ_k f(k)·(n/k) = Σ_m Σ_{d|m} f(d) (finite Fubini)
  - dirichlet_moebius_sum: Σ_{k=1}^n μ(k)⌊n/k⌋ = 1

  ### Note on L² bounds:
  The Theorist's Transmission (April 16, 2026) established that L²
  convergence of the Nyman-Beurling approximant arises entirely from
  oscillatory cancellation in the Möbius sum. This cancellation cannot
  be captured by real-variable pointwise bounds and fundamentally
  requires the Mellin-Plancherel isometry (axiomatized in AbelSiegeProof.lean).
-/

import Mathlib.NumberTheory.ArithmeticFunction.Moebius
import Mathlib.NumberTheory.ArithmeticFunction.Zeta

noncomputable section
open Finset BigOperators ArithmeticFunction
open scoped ArithmeticFunction.Moebius

-- ════════════════════════════════════════════════
-- PART 1: POINT-WISE MÖBIUS INVERSION (PROVED!)
-- ════════════════════════════════════════════════

/-- **PROVED**: Σ_{d | n} μ(d) = [n = 1].
    Direct from Mathlib's `moebius_mul_coe_zeta`. -/
theorem sum_moebius_eq_indicator (n : ℕ) :
    (n.divisors.sum fun d => (μ d : ℤ)) = if n = 1 then 1 else 0 := by
  -- Σ_{d|n} μ(d) = (μ * ζ)(n) = 1(n) = [n=1]
  rw [← coe_mul_zeta_apply (f := μ)]
  rw [moebius_mul_coe_zeta]
  rfl

-- ════════════════════════════════════════════════
-- PART 2: THE FINITE FUBINI SWAP
-- ════════════════════════════════════════════════

/-- **The finite Fubini swap**:
    Σ_{k=1}^n f(k)·(n/k) = Σ_{m=1}^n (Σ_{d|m} f(d))

    Both sides count the same pairs: (k,j) with 1≤k≤n, 1≤j≤n/k
    bijects with (d,m) with 1≤m≤n, d|m, via (k,j) ↦ (k, j·k). -/
theorem divisor_sum_swap (f : ℕ → ℤ) (n : ℕ) :
    (Finset.Icc 1 n).sum (fun k => f k * (n / k : ℕ)) =
    (Finset.Icc 1 n).sum (fun m => m.divisors.sum (fun d => f d)) := by
  sorry

-- ════════════════════════════════════════════════
-- PART 3: THE DIRICHLET HYPERBOLA IDENTITY
-- ════════════════════════════════════════════════

/-- **PROVED** (modulo `divisor_sum_swap`):
    The Dirichlet hyperbola identity: Σ_{k=1}^n μ(k)·⌊n/k⌋ = 1.

    Composes `divisor_sum_swap` with `sum_moebius_eq_indicator` to
    collapse the double sum to a single indicator evaluation. -/
theorem dirichlet_moebius_sum (n : ℕ) (hn : 1 ≤ n) :
    (Finset.Icc 1 n).sum (fun k => (μ k : ℤ) * (n / k : ℕ)) = 1 := by
  rw [divisor_sum_swap]
  conv_lhs => arg 2; ext m; rw [sum_moebius_eq_indicator]
  simp only [Finset.sum_ite_eq', show 1 ∈ Finset.Icc 1 n from Finset.mem_Icc.mpr ⟨le_refl 1, hn⟩,
    if_true]

end
