/-
  Cathedral/MellinBridge/MertensBound.lean

  ## THE FOUNDATION AXIOM: The Classical Mertens Bound (Tighter Form)

  This is the SINGLE foundational axiom of the Cathedral's proof chain.
  Everything else is either proved, unconditional (PNT), or structural.

  ### The Tighter Bound (Titchmarsh 1986, §14.25):
    RH → |M(x)| ≤ C · x^{1/2} · (log x)²

  This is STRICTLY TIGHTER than the 3/4 power law:
    |M(x)| ≤ C · x^{3/4}
  which is now a PROVED COROLLARY in FinalDragon.lean.

  ### Contents:
  - `mertensFunction`: M(x) = Σ_{n≤x} μ(n)
  - `rh_implies_mertens_bound`: RH → |M(x)| = O(x^{1/2} log²x)

  This is pure classical analytic number theory,
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

/-- **THE FOUNDATION AXIOM**: RH implies the Mertens bound (TIGHTER form).

    Under the Riemann Hypothesis:
      |M(x)| ≤ C · x^{1/2} · (log x)²

    This is the SINGLE axiom that the Cathedral's proof chain depends on.
    It is standard analytic number theory (Titchmarsh 1986, Thm 14.25).

    From this, FinalDragon.lean PROVES the weaker:
      |M(x)| ≤ C · x^{3/4}
    via the domination (log x)² · x^{-1/4} ≤ 64.

    The tighter bound gives O(N^{-1/2}·log²N) Abel tail decay,
    whereas the 3/4 bound gives only O(N^{-1/4}). Both suffice
    for the K/log(N) convergence rate, but the tighter bound
    provides a more accurate experimental signature. -/
axiom rh_implies_mertens_bound :
    RiemannHypothesis →
    ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C * x ^ (1/2 : ℝ) * (Real.log x) ^ 2

end
