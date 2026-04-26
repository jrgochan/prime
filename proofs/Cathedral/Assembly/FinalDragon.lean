/-
  Cathedral/Assembly/FinalDragon.lean

  ## The Final Dragon v7: Thin Re-Export Facade

  This file was the monolithic proof chain (971 lines).
  As of April 22, 2026, it has been decomposed into:

  - MertensConversion.lean: rh_implies_mertens_34 (x^{1/2}·log²x → x^{3/4})
  - PNTAbelMean.lean: PNT axioms + Abel tail + mean bound (566 lines)
  - MillenniumWall.lean: Gram form axiom + covariance graduation 🎓🎓
  - L2Convergence.lean: L² decay + convergence theorem

  The CROWN theorem (RH → d²→0) now uses the Direct BD Path
  via DirectL2Crown.lean with only 2 Cathedral axioms, bypassing
  this entire chain.

  This file re-exports all the decomposed modules for backward
  compatibility.
-/

import Cathedral.Perron.MertensConversion
import Cathedral.PNT.AbelMean
import Cathedral.Covariance.MillenniumWall
import Cathedral.Covariance.L2Convergence
