import Lake
open Lake DSL

package "hyperzeta_proofs" where
  -- Build constraints securely limiting memory limits

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git"

-- Legacy roots (superseded by Cathedral architecture)
-- @[default_target]
-- lean_lib «HyperzetaProofs» where
--   roots := #[`LiCriterion, `SpectralRH.Defs, ...]

@[default_target]
lean_lib «Cathedral» where
  roots := #[
    -- Core definitions & infrastructure
    `Cathedral.Defs,
    -- Axiom registry
    `Cathedral.Axioms,
    -- Linear algebra (abstract, zero sorry)
    `Cathedral.LinearAlgebra.ShermanMorrison,
    `Cathedral.LinearAlgebra.Variational,
    `Cathedral.LinearAlgebra.SchurComplement,
    `Cathedral.LinearAlgebra.Sylvester,
    -- Nyman-Beurling criterion
    `Cathedral.NymanBeurling.Separation,
    `Cathedral.NymanBeurling.NymanBeurling,
    -- Vasyunin (the active proof chain)
    `Cathedral.Vasyunin,
    -- Robin's Inequality (discrete arithmetic front)
    `Cathedral.Robin.Defs,
    `Cathedral.Robin.SigmaProps,
    `Cathedral.Robin.HarmonicBounds,
    `Cathedral.Robin.BaseCases,
    `Cathedral.Robin.PrimeBounds,
    `Cathedral.Robin.Equivalence,
    -- Archive: Spectral theory (leaf nodes)
    `Cathedral.Archive.HighFrequencyTrap.Spectral.RayleighBridge,
    `Cathedral.Archive.HighFrequencyTrap.Spectral.PTSymmetry,
    `Cathedral.Archive.HighFrequencyTrap.Spectral.OctonionicPartition,
    `Cathedral.Archive.HighFrequencyTrap.Spectral.ClassRestriction,
    `Cathedral.Archive.HighFrequencyTrap.Spectral.FiniteDimReduction,
    `Cathedral.Archive.HighFrequencyTrap.Spectral.ConstantVectorBound,
    -- Archive: Structural layer
    `Cathedral.Archive.HighFrequencyTrap.Structural.NbLinComb,
    `Cathedral.Archive.HighFrequencyTrap.Structural.Independence,
    `Cathedral.Archive.HighFrequencyTrap.Structural.Eigenvalue,
    `Cathedral.Archive.HighFrequencyTrap.Structural.L2Tools,
    `Cathedral.Archive.HighFrequencyTrap.Structural.Structural,
    -- Archive: Gram integral analysis
    `Cathedral.Archive.HighFrequencyTrap.FractIntegral,
    `Cathedral.Archive.HighFrequencyTrap.GramDiag,
    `Cathedral.Archive.HighFrequencyTrap.GramBounds,
    `Cathedral.Archive.HighFrequencyTrap.GramOffDiag,
    -- Archive: Mellin bridge
    `Cathedral.Archive.HighFrequencyTrap.MellinBridge.Basic,
    `Cathedral.Archive.HighFrequencyTrap.MellinBridge.FloorMellin,
    `Cathedral.Archive.HighFrequencyTrap.MellinBridge.FloorDivMellin,
    `Cathedral.Archive.HighFrequencyTrap.MellinBridge.HilbertSetup,
    `Cathedral.Archive.HighFrequencyTrap.MellinBridge.Separation,
    `Cathedral.Archive.HighFrequencyTrap.MellinBridge.OrthogonalWitness,
    `Cathedral.Archive.HighFrequencyTrap.MellinBridge.AbelSummation,
    `Cathedral.Archive.HighFrequencyTrap.MellinBridge.MertensIntegral,
    `Cathedral.Archive.HighFrequencyTrap.MellinBridge.MertensWeightBypass,
    `Cathedral.Archive.HighFrequencyTrap.MellinBridge.AutocorrelationBypass,
    `Cathedral.Archive.HighFrequencyTrap.MellinBridge.MellinSieve,
    `Cathedral.Archive.HighFrequencyTrap.MellinBridge,
    -- Archive: Parity & sieve
    `Cathedral.Archive.HighFrequencyTrap.VasyuninExpansion,
    `Cathedral.Archive.HighFrequencyTrap.ParitySchur,
    `Cathedral.Archive.HighFrequencyTrap.ParityBridge,
    `Cathedral.Archive.HighFrequencyTrap.BilinearSieve,
    `Cathedral.Archive.HighFrequencyTrap.MoebiusUncoupling,
    `Cathedral.Archive.HighFrequencyTrap.AlignmentDecay,
    -- Archive: Assembly
    `Cathedral.Archive.HighFrequencyTrap.Assembly.QuadFormBridge,
    `Cathedral.Archive.HighFrequencyTrap.Assembly.MainChain,
    `Cathedral.Archive.HighFrequencyTrap.Assembly.Assembly,
    -- Archive: Integral basis
    `Cathedral.Archive.IntegralBasis.BaezDuarte,
    `Cathedral.Archive.IntegralBasis.Quantitative
  ]
