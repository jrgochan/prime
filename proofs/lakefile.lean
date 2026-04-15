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
    -- Archive (reference proofs for the active chain)
    `Cathedral.Archive.HighFrequencyTrap.FractIntegral
  ]
