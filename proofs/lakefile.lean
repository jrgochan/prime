import Lake
open Lake DSL

package "hyperzeta_proofs" where
  -- Build constraints securely limiting memory limits

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git"

@[default_target]
lean_lib «HyperzetaProofs» where
  roots := #[`LiCriterion, `SpectralRH.Defs, `SpectralRH.Structural, `SpectralRH.GramBounds, `SpectralRH.ParitySchur, `SpectralRH.BilinearSieve, `SpectralRH.ParityBridge, `SpectralRH.Quantitative, `SpectralRH.PTSymmetry, `SpectralRH.AlignmentDecay, `SpectralRH.Assembly, `SpectralRH.OctonionicPartition, `SpectralRH.ClassRestriction, `SpectralRH.FiniteDimReduction, `SpectralRH.SpectralFlow, `SpectralRH.RayleighBridge, `SpectralRH.MellinBridge, `SpectralRH.SelbergSieve, `HyperzetaRH]
