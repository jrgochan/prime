/-
  Cathedral/Robin/Defs.lean

  ## The Discrete Front: Robin's and Lagarias's Inequalities

  This file establishes the purely arithmetic path to the Riemann Hypothesis
  via two classical equivalences:

  - **Lagarias (2002)**: σ(n) ≤ Hₙ + exp(Hₙ) · log(Hₙ) for all n ≥ 1
  - **Robin (1984)**: σ(n) < e^γ · n · log(log(n)) for all n ≥ 5041

  Both are equivalent to RH. Unlike the Nyman-Beurling path (which requires
  L² functional analysis and Mellin transforms), these formulations are
  purely arithmetic: they involve only divisors, exponentials, and logarithms.

  ### Architecture

  ```
  Cathedral.Defs (RiemannHypothesis)
    ├── Cathedral.Vasyunin (Continuous / L² / Spectral Path)
    └── Cathedral.Robin        (Discrete / Arithmetic Path)  ← THIS FILE
  ```

  ### Axiom Philosophy

  The equivalences `lagarias_iff_rh` and `robin_iff_rh` are axiomatized
  as literature-standard results. The deep analytic content (Gronwall's
  theorem, colossally abundant numbers, Mertens' product formula) is
  isolated behind these interfaces, exactly as `mertens_bound_from_rh`
  isolates the Perron formula on the Nyman-Beurling path.

  ### References

  - Robin, G. (1984). "Grandes valeurs de la fonction somme des diviseurs
    et hypothèse de Riemann." J. Math. Pures Appl. 63, 187–213.
  - Lagarias, J.C. (2002). "An elementary problem equivalent to the
    Riemann hypothesis." Amer. Math. Monthly 109, 534–543.
-/

import Cathedral.Defs
import Mathlib.NumberTheory.ArithmeticFunction.Misc
import Mathlib.NumberTheory.Harmonic.Defs
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Analysis.SpecialFunctions.ExpDeriv
import Mathlib.NumberTheory.Harmonic.EulerMascheroni

noncomputable section
open ArithmeticFunction Real

-- ════════════════════════════════════════════════
-- PART I: DEFINITIONS
-- ════════════════════════════════════════════════

/-- The sum-of-divisors function σ₁(n) = Σ_{d | n} d.
    Uses Mathlib's `ArithmeticFunction.sigma` with k = 1. -/
def sumOfDivisors (n : ℕ) : ℕ :=
  (sigma 1) n

/-- The n-th harmonic number cast to ℝ.
    Hₙ = Σ_{k=1}^n 1/k.
    Uses Mathlib's `harmonic : ℕ → ℚ` with a cast to ℝ. -/
noncomputable def harmonicR (n : ℕ) : ℝ :=
  (harmonic n : ℝ)

-- ════════════════════════════════════════════════
-- PART II: LAGARIAS'S INEQUALITY (Primary Spearhead)
-- ════════════════════════════════════════════════

/-- **Lagarias's Inequality (2002)**:
    σ(n) ≤ Hₙ + exp(Hₙ) · log(Hₙ) for all n ≥ 1.

    This is the formalizer's preferred formulation because:
    1. It holds for ALL n ≥ 1 (no boundary at n = 5041)
    2. It uses harmonic numbers (well-supported in Mathlib)
    3. It avoids log(log(n)) domain issues for small n

    For n = 1: H₁ = 1, so σ(1) = 1 ≤ 1 + e¹·log(1) = 1 + 0 = 1. ✓ -/
def LagariasInequality : Prop :=
  ∀ n : ℕ, 1 ≤ n →
    (sumOfDivisors n : ℝ) ≤
      harmonicR n + Real.exp (harmonicR n) * Real.log (harmonicR n)

-- ════════════════════════════════════════════════
-- PART III: ROBIN'S INEQUALITY
-- ════════════════════════════════════════════════

/-- **Robin's Inequality (1984)**:
    σ(n) < e^γ · n · log(log(n)) for all n ≥ 5041.

    The last counterexample is n = 5040 = 2⁴ · 3² · 5 · 7
    (a highly composite number, σ(5040) = 19344).

    NOTE: For n ≥ 5041, log(log(n)) > 0 since log(5041) > e.
    The strict inequality makes this slightly harder to formalize
    than Lagarias, but it is the classical formulation. -/
def RobinInequality : Prop :=
  ∀ n : ℕ, 5041 ≤ n →
    (sumOfDivisors n : ℝ) <
      Real.exp eulerMascheroniConstant * (n : ℝ) * Real.log (Real.log (n : ℝ))

-- ════════════════════════════════════════════════
-- PART III-A: THE SINGLE ARITHMETIC AXIOM
-- ════════════════════════════════════════════════

/-- **AXIOM: Arithmetic Equivalences to RH (Lagarias 2002, Robin 1984)**

    Both Lagarias's inequality and Robin's inequality are equivalent
    to the Riemann Hypothesis.

    These are bundled into a single axiom because they derive from the
    same mathematical framework:
    - Gronwall's theorem: limsup σ(n)/(n·log(log(n))) = e^γ
    - Colossally abundant numbers (Alaoglu-Erdős 1944)
    - Euler product bounds from zero-free regions of ζ(s)

    MATHEMATICAL SOURCES:
    - Lagarias, J.C. (2002). "An elementary problem equivalent to the
      Riemann hypothesis." Amer. Math. Monthly 109, 534–543.
    - Robin, G. (1984). "Grandes valeurs de la fonction somme des
      diviseurs et hypothèse de Riemann." J. Math. Pures Appl. 63.

    PREVIOUSLY: 2 separate axioms (lagarias_iff_rh, robin_iff_rh).
    MERGED: April 12, 2026 — reduces Cathedral from 4 to 3 axioms. -/
axiom arithmetic_rh_equivalences :
    (LagariasInequality ↔ RiemannHypothesis) ∧
    (RobinInequality ↔ RiemannHypothesis)

-- ════════════════════════════════════════════════
-- PART IV: DERIVED THEOREMS (from the single axiom)
-- ════════════════════════════════════════════════

/-- Lagarias ↔ RH (derived from the bundled axiom). -/
theorem lagarias_iff_rh : LagariasInequality ↔ RiemannHypothesis :=
  arithmetic_rh_equivalences.1

/-- Robin ↔ RH (derived from the bundled axiom). -/
theorem robin_iff_rh : RobinInequality ↔ RiemannHypothesis :=
  arithmetic_rh_equivalences.2

/-- The two discrete paths are equivalent to each other. -/
theorem lagarias_iff_robin : LagariasInequality ↔ RobinInequality := by
  constructor
  · intro hL; exact robin_iff_rh.mpr (lagarias_iff_rh.mp hL)
  · intro hR; exact lagarias_iff_rh.mpr (robin_iff_rh.mp hR)

/-- RH implies Lagarias's Inequality. -/
theorem rh_implies_lagarias : RiemannHypothesis → LagariasInequality :=
  lagarias_iff_rh.mpr

/-- RH implies Robin's Inequality. -/
theorem rh_implies_robin : RiemannHypothesis → RobinInequality :=
  robin_iff_rh.mpr

/-- Lagarias's Inequality implies RH. -/
theorem lagarias_implies_rh : LagariasInequality → RiemannHypothesis :=
  lagarias_iff_rh.mp

/-- Robin's Inequality implies RH. -/
theorem robin_implies_rh : RobinInequality → RiemannHypothesis :=
  robin_iff_rh.mp

-- ════════════════════════════════════════════════
-- PART V: COMPUTATIONAL DEMONSTRATION
-- ════════════════════════════════════════════════

-- Lean can natively compute the sum of divisors:
#eval (sigma 1) 5040   -- 19344 (Highly composite, fails Robin)
#eval (sigma 1) 5041   -- 5113  (= 71², σ = 1 + 71 + 5041)
#eval (sigma 1) 12     -- 28    (perfect number: σ(12) = 28)
#eval (sigma 1) 6      -- 12    (perfect number: σ(6) = 12)

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- This file has:
--   ZERO sorry
--   1 axiom (arithmetic_rh_equivalences) — bundles Lagarias + Robin
--   7 proved theorems:
--     ✅ lagarias_iff_rh             — Lagarias ↔ RH (from bundled axiom)
--     ✅ robin_iff_rh                — Robin ↔ RH (from bundled axiom)
--     ✅ lagarias_iff_robin          — Lagarias ↔ Robin
--     ✅ rh_implies_lagarias         — RH → Lagarias
--     ✅ rh_implies_robin            — RH → Robin
--     ✅ lagarias_implies_rh         — Lagarias → RH
--     ✅ robin_implies_rh            — Robin → RH
--
-- Architecture:
--   Cathedral.Defs (RiemannHypothesis)
--     ├── Cathedral.Vasyunin  — axioms (vasyunin_eq_integral, log_cutoff_witness_bound)
--     └── Cathedral.Robin         — 1 axiom (arithmetic_rh_equivalences) ← THIS

end
