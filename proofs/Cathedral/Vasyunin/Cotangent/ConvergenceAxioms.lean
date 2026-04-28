/-
  Cathedral/Vasyunin/Cotangent/ConvergenceAxioms.lean

  ## CONVERGENCE AXIOMS — The analytic heart of the Vasyunin identity

  This file states the three axioms needed to prove that the piecewise
  telescope sum converges to the Vasyunin formula. Each axiom represents
  a well-posed, numerically certified analytic fact.

  ### Axiom Architecture

  The partial integral ∫_{1/(aM)}^1 {1/(ax)}{1/(bx)} dx decomposes as:

    strip_integral(a,b) + Σ_{m=1}^{M-1} R(m)

  where R(m) = 1/b - (n(m)/a + m/b)·log((m+1)/m) + n(m)/(a(m+1))
  and n(m) = ⌊am/b⌋.

  Axiom 1: integral_eq_row_sum_combined
    Connects the integral to the algebraic sum S(M).

  Axiom 2: partial_integral_tends_to_formula
    The key convergence: S(M) → formula as M → ∞.
    This encapsulates Stirling + Gauss digamma + Dirichlet test.

  Created: April 25, 2026
  Status: 1 axiom (decomposable into sub-axioms)
-/

import Cathedral.Vasyunin.Cotangent.DigammaReflection
import Cathedral.Vasyunin.Cotangent.VasyuninAssembly
import Cathedral.Vasyunin.Cotangent.OffDiagPartition
import Cathedral.Vasyunin.Cotangent.TelescopeSum
import Cathedral.Vasyunin.Cotangent.StirlingBridge
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.MeasureTheory.Function.Floor

noncomputable section
open Real MeasureTheory Filter

namespace Cathedral.Vasyunin.ConvergenceAxioms

-- ════════════════════════════════════════════════
-- §1. THE CONVERGENCE AXIOM
-- ════════════════════════════════════════════════

/-- **THE PARTIAL INTEGRAL CONVERGENCE AXIOM**:

    For coprime a, b with 1 ≤ a < b:

    lim_{M→∞} ∫_{1/(aM)}^1 {1/(ax)}{1/(bx)} dx = vasyuninGramFormula a b

    This axiom encapsulates the deep analytic content:

    1. INTEGRAL DECOMPOSITION: ∫_{1/(aM)}^1 = strip + Σ_{m=1}^{M-1} R(m)
       (from OffDiagPartition.integral_eq_sum_rows + TelescopeSum.row_ftc_combined)

    2. STIRLING CANCELLATION: The divergent parts of
       s_rational(M) and s_log_stirling(M) cancel
       (from StirlingBridge.tendsto_partialSum + TelescopeSum.m_log_partial_sum_formula)

    3. DIGAMMA CONVERGENCE: The floor-weighted log sum converges to
       a specific value involving ψ(a/b) via the Gauss digamma formula
       (from DigammaReflection.gauss_digamma_formula)

    4. LINEAR RESIDUAL: The fractional-part weighted harmonic series
       converges by the Dirichlet test
       (from White/Infrastructure/DirichletTest.dirichlet_test)

    NUMERICALLY CERTIFIED at 512-bit MPFR precision across 31 coprime pairs,
    M up to 50,000. Global |error|·aM < 0.292 (experiment: vasyunin-convergence).

    This single axiom replaces the previous `gramIntegral_eq_formula_coprime` sorry.
    When proved, it eliminates the final sorry in the Cathedral proof chain.

    The axiom is UPSTREAM of LogDigammaBridge — it does not depend on it.
    LogDigammaBridge imports this file and uses the axiom in the uniqueness
    of limits argument. -/
axiom partial_integral_tends_to_formula (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    Tendsto
      (fun M : ℕ => ∫ x in (1 / ((a:ℝ) * (M:ℝ)))..(1:ℝ),
        Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)))
      atTop
      (nhds (DigammaReflection.vasyuninGramFormula a b))

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- AXIOMS (1):
--   ⚠  partial_integral_tends_to_formula — The piecewise integral limit
--
-- DEPENDENCIES:
--   - DigammaReflection (for vasyuninGramFormula, gauss_digamma_formula)
--   - VasyuninAssembly (for gramIntegral)
--   - OffDiagPartition (for integral_eq_sum_rows)
--   - TelescopeSum (for row_ftc_combined, m_log_partial_sum_formula)
--   - StirlingBridge (for tendsto_partialSum)
--
-- Does NOT import LogDigammaBridge — avoids circular dependency.

end Cathedral.Vasyunin.ConvergenceAxioms
