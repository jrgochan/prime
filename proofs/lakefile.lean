import Lake
open Lake DSL

package "hyperzeta_proofs" where
  -- Build constraints securely limiting memory limits

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git"

@[default_target]
lean_lib «HyperzetaProofs» where
  roots := #[`LiCriterion, `SpectralRH.Defs, `SpectralRH.Structural, `SpectralRH.GramBounds, `SpectralRH.ParitySchur, `SpectralRH.BilinearSieve, `SpectralRH.ParityBridge, `SpectralRH.Quantitative, `SpectralRH.PTSymmetry, `SpectralRH.AlignmentDecay, `SpectralRH.Assembly, `SpectralRH.OctonionicPartition, `SpectralRH.ClassRestriction, `SpectralRH.FiniteDimReduction, `SpectralRH.SpectralFlow, `SpectralRH.RayleighBridge, `SpectralRH.MellinBridge, `SpectralRH.SelbergSieve, `HyperzetaRH]

lean_lib «Cathedral» where
  roots := #[
    -- Core (critical path)
    `Cathedral.Defs,
    `Cathedral.Structural.Eigenvalue, `Cathedral.Structural.NbLinComb,
    `Cathedral.Structural.Independence, `Cathedral.Structural.L2Tools,
    `Cathedral.Structural, `Cathedral.GramBounds,
    `Cathedral.GramDiag, `Cathedral.GramOffDiag,
    `Cathedral.FractIntegral,
    `Cathedral.Mertens.Defs, `Cathedral.Mertens.Algebraic,
    `Cathedral.Mertens.Harmonic, `Cathedral.Mertens.GramEntry,
    `Cathedral.Mertens.GramSum, `Cathedral.Mertens.NbDecay,
    `Cathedral.SelbergSieve,
    `Cathedral.MellinBridge,
    `Cathedral.Assembly.DropAssembly, `Cathedral.Assembly.QuadFormBridge,
    `Cathedral.Assembly.MainChain, `Cathedral.Assembly,
    -- Spectral path (non-critical, parallel exploration)
    `Cathedral.Spectral.PTSymmetry, `Cathedral.Spectral.RayleighBridge,
    `Cathedral.Spectral.OctonionicPartition, `Cathedral.Spectral.ClassRestriction,
    `Cathedral.Spectral.FiniteDimReduction,
    -- Bridge files (used by Assembly for alternative proofs)
    `Cathedral.ParitySchur, `Cathedral.BilinearSieve, `Cathedral.ParityBridge,
    `Cathedral.Quantitative, `Cathedral.AlignmentDecay,
    -- Mertens infrastructure (sorry-free, promoted from Scratch)
    `Cathedral.Mertens.PeriodicFormula,
    `Cathedral.Mertens.BernoulliCross, `Cathedral.Mertens.CoprimeCross,
    `Cathedral.Mertens.SubstProbe, `Cathedral.Mertens.CovDecomp,
    -- Scratch/development files (active work, has sorrys)
    `Cathedral.Scratch.OffDiagBound, `Cathedral.Scratch.RunningAvg
  ]

