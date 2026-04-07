import Lake
open Lake DSL

package "hyperzeta_proofs" where
  -- Build constraints securely limiting memory limits

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git"

@[default_target]
lean_lib «HyperzetaProofs» where
  roots := #[`LiCriterion, `SpectralRH.Defs, `SpectralRH.Structural, `SpectralRH.GramBounds, `SpectralRH.ParitySchur, `SpectralRH.BilinearSieve, `SpectralRH.ParityBridge, `SpectralRH.Quantitative, `SpectralRH.PTSymmetry, `SpectralRH.AlignmentDecay, `SpectralRH.Assembly, `SpectralRH.OctonionicPartition, `SpectralRH.ClassRestriction, `SpectralRH.FiniteDimReduction, `SpectralRH.SpectralFlow, `SpectralRH.RayleighBridge, `SpectralRH.MellinBridge, `HyperzetaRH]

lean_lib «Cathedral» where
  roots := #[
    -- Core definitions & infrastructure
    `Cathedral.Defs,
    `Cathedral.Structural.Eigenvalue, `Cathedral.Structural.NbLinComb,
    `Cathedral.Structural.Independence, `Cathedral.Structural.L2Tools,
    `Cathedral.Structural, `Cathedral.GramBounds,
    `Cathedral.GramDiag, `Cathedral.GramOffDiag,
    `Cathedral.FractIntegral,
    -- Mellin Bridge (THE critical path)
    `Cathedral.MellinBridge.Basic,
    `Cathedral.MellinBridge.FloorMellin, `Cathedral.MellinBridge.FloorDivMellin,
    `Cathedral.MellinBridge.Separation,
    `Cathedral.MellinBridge.HilbertSetup,
    `Cathedral.MellinBridge.OrthogonalWitness,
    `Cathedral.MellinBridge.MellinSieve,
    `Cathedral.MellinBridge.AutocorrelationBypass,
    `Cathedral.MellinBridge.MertensWeightBypass,
    `Cathedral.MellinBridge.AbelSummation,
    `Cathedral.MellinBridge.MertensIntegral,
    `Cathedral.MellinBridge,
    -- Assembly (crown)
    `Cathedral.Assembly.QuadFormBridge,
    `Cathedral.Assembly.MainChain, `Cathedral.Assembly,
    -- Spectral path (unconditional results, parallel exploration)
    `Cathedral.Spectral.PTSymmetry, `Cathedral.Spectral.RayleighBridge,
    `Cathedral.Spectral.OctonionicPartition, `Cathedral.Spectral.ClassRestriction,
    `Cathedral.Spectral.FiniteDimReduction,
    `Cathedral.Spectral.ConstantVectorBound,
    -- Sieve infrastructure (for forward direction)
    `Cathedral.ParitySchur, `Cathedral.VasyuninExpansion,
    `Cathedral.BilinearSieve, `Cathedral.MoebiusUncoupling,
    `Cathedral.ParityBridge,
    `Cathedral.Quantitative, `Cathedral.AlignmentDecay,
    -- Robin's Inequality (discrete arithmetic front)
    `Cathedral.Robin.Defs,
    `Cathedral.Robin.SigmaProps,
    `Cathedral.Robin.HarmonicBounds,
    `Cathedral.Robin.BaseCases,
    `Cathedral.Robin.PrimeBounds,
    `Cathedral.Robin.Equivalence
  ]
