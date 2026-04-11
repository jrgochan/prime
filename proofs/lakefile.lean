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
    -- Linear algebra (abstract, zero sorry)
    `Cathedral.LinearAlgebra.ShermanMorrison,
    `Cathedral.LinearAlgebra.Variational,
    `Cathedral.LinearAlgebra.SchurComplement,
    `Cathedral.LinearAlgebra.Sylvester,
    -- Mellin Bridge: Nyman-Beurling + Vasyunin (the active proof chain)
    `Cathedral.MellinBridge.NymanBeurling,
    `Cathedral.MellinBridge.Vasyunin,
    -- Robin's Inequality (discrete arithmetic front)
    `Cathedral.Robin.Defs,
    `Cathedral.Robin.SigmaProps,
    `Cathedral.Robin.HarmonicBounds,
    `Cathedral.Robin.BaseCases,
    `Cathedral.Robin.PrimeBounds,
    `Cathedral.Robin.Equivalence
  ]
