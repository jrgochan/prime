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
    `Cathedral.Quantitative,
    -- Linear algebra (basis-independent, zero sorry)
    `Cathedral.LinearAlgebra.ShermanMorrison,
    -- Mellin Bridge: Báez-Duarte + Vasyunin (the true Cathedral)
    `Cathedral.MellinBridge.NymanBeurling,
    `Cathedral.MellinBridge.BaezDuarte,
    `Cathedral.MellinBridge.Vasyunin,
    -- Robin's Inequality (discrete arithmetic front)
    `Cathedral.Robin.Defs,
    `Cathedral.Robin.SigmaProps,
    `Cathedral.Robin.HarmonicBounds,
    `Cathedral.Robin.BaseCases,
    `Cathedral.Robin.PrimeBounds,
    `Cathedral.Robin.Equivalence
  ]
