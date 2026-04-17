/-
  Cathedral/MellinBridge/BDWeights.lean

  ## The Optimal BD Weights

  Extracted definition of bdMoebiusWeight (the Möbius log-taper)
  into a standalone file to break the import cycle between
  AbelSiegeProof and PlancherelBypass.
-/

import Cathedral.MellinBridge.MertensIntegral
import Mathlib.NumberTheory.ArithmeticFunction.Moebius

noncomputable section
open Real

/-- The explicit BD weights from Möbius log-taper.
    v(i) = -μ(i+1) · (1 - log(i+1)/log N)
    for i : Fin(N-1), so the basis index k = i+1 ranges over {1,...,N-1}.

    NOTE (The True BD Weights): Unlike the High Frequency basis {k/x}
    which requires weights μ(k)/k, the True BD basis {1/(kx)} requires
    weights proportional to μ(k). This exactly triggers Möbius inversion! -/
def bdMoebiusWeight (N : ℕ) (i : Fin (N - 1)) : ℝ :=
  -(ArithmeticFunction.moebius (i.val + 1) : ℝ) *
  logWeight N (i.val + 1)

end
