/-
  Cathedral/PNT/UnconditionalMertens.lean

  ## Axiom B Graduation: Honest Assessment

  ### What We Need
  `witness_numerator_rate`: |bᵀv - 1| ≤ K₁/ln(N)

  ### What PNTAnd Provides (unconditionally)
  1. `mu_pnt_alt`: Σ μ(k)/k → 0  (qualitative, NO rate)
  2. `MediumPNT`: ψ(x) - x = O(x · exp(-c · (log x)^{1/10}))

  ### The Gap (CORRECTED)
  The MediumPNT bound does NOT give |M(x)| ≤ C·x^{3/4}.
  In fact, x·exp(-c·(log x)^{1/10}) GROWS FASTER than x^{3/4}!
  The ratio x^{1/4}·exp(-c·(log x)^{1/10}) → ∞.

  The unconditional Mertens bound is:
    |M(x)| = O(x · exp(-c · (log x)^{1/10}))
  which is o(x) but NOT O(x^{3/4}).

  ### What This Means for Axiom B
  The existing proof chain (`witness_numerator_rate_proved`) requires
  |M(x)| ≤ C·x^{3/4}. This bound requires RH (or quasi-RH).

  To close Axiom B unconditionally, we need EITHER:
  A. Rewrite the Abel tail engine to use the weaker exponential bound
  B. Extract quantitative partial sum bounds from PNTAnd directly
  C. Prove Σ μ(k)/k = O(exp(-c'·(log N)^{1/10})) from MediumPNT
     (which IS stronger than O(1/log N))

  ### Status
  The `witness_numerator_rate` axiom CANNOT be closed with the current
  code without either RH or significant new infrastructure.
  The unconditional PNT gives rates, but in a form the current Abel
  tail engine doesn't accept.
-/

-- This file is an analysis document, not compilable code.
-- See AXIOM_B_GRADUATION_REPORT.md for the detailed write-up.
