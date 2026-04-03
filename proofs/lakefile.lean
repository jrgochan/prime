import Lake
open Lake DSL

package "hyperzeta_proofs" where
  -- Build constraints securely limiting memory limits

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git"

@[default_target]
lean_lib «HyperzetaProofs» where
  -- Expose SedenionAxioms boundaries formally inside the array
  roots := #[`SedenionAxioms, `LiCriterion, `SpectralRH.Defs, `SpectralRH.Structural, `SpectralRH.Quantitative, `SpectralRH.PTSymmetry, `SpectralRH.AlignmentDecay, `SpectralRH.Assembly, `SpectralRH.OctonionicPartition, `SpectralRH.ClassRestriction, `SpectralRH.FiniteDimReduction, `SpectralRH.SpectralFlow, `SpectralRH.RayleighBridge, `HyperzetaRH]
