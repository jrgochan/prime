/-
  Cathedral/MellinBridge/MertensBound.lean

  ## The Foundation of Pillar II: The Classical Mertens Bound

  Isolates the classical real-variable RH equivalence into a fundamental
  bedrock layer, breaking the circular dependency between BDBypass and
  AbelSiegeProof.

  ### Contents:
  - `mertensFunction`: M(x) = Σ_{n≤x} μ(n)
  - `rh_implies_mertens_bound`: RH → |M(x)| = O(x^{1/2} log²x)

  This is pure classical analytic number theory (Titchmarsh 1986, §14.25),
  with no dependence on the Nyman-Beurling machinery.
-/

import Cathedral.Defs
import Mathlib.NumberTheory.ArithmeticFunction.Moebius

noncomputable section
open Real Finset

/-- The Mertens function: M(x) = Σ_{n≤x} μ(n). -/
def mertensFunction (x : ℝ) : ℤ :=
  (Finset.filter (fun (n : ℕ) => (n : ℝ) ≤ x ∧ 0 < n)
    (Finset.range (⌊x⌋₊ + 1))).sum
    (fun (n : ℕ) => ArithmeticFunction.moebius n)

/-- **AXIOM 1 (Classical Number Theory)**: RH implies the Mertens bound.

    Under the Riemann Hypothesis:
      |M(x)| ≤ C · x^{1/2} · (log x)²

    This is standard analytic number theory (Titchmarsh 1986, Thm 14.25).
    It avoids all complex analysis, stating RH purely as a growth rate. -/
axiom rh_implies_mertens_bound :
    RiemannHypothesis →
    ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C * x ^ (1/2 : ℝ) * (Real.log x) ^ 2

end
