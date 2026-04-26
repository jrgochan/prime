import Lake
open Lake DSL

package "hyperzeta_proofs" where
  -- Build constraints securely limiting memory limits

require PrimeNumberTheoremAnd from git
  "https://github.com/AlexKontorovich/PrimeNumberTheoremAnd.git" @ "v4.28.0"

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.28.0"

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
    `Cathedral.NymanBeurling.ThetaBound,
    `Cathedral.NymanBeurling.BDMellin,
    `Cathedral.NymanBeurling.NymanBeurling,
    -- Vasyunin (the active proof chain)
    `Cathedral.Vasyunin.Defs,
    `Cathedral.Vasyunin.Witness,
    `Cathedral.Vasyunin.Matrix.GramEntries,
    `Cathedral.Vasyunin.Matrix.GramEvaluations,
    `Cathedral.Vasyunin.Matrix.CovEntries,
    `Cathedral.Vasyunin.Matrix.CovDet2,
    `Cathedral.Vasyunin.Matrix.CovDet3,
    `Cathedral.Vasyunin.Matrix.Structural,
    `Cathedral.Vasyunin.Augmented.AugmentedGram,
    `Cathedral.Vasyunin.Augmented.LinIndep,
    `Cathedral.Vasyunin.Augmented.Rayleigh,
    `Cathedral.Vasyunin.Augmented.MeanIntegral,
    -- Cotangent tower (diagonal proof chain, sorry-free)
    `Cathedral.Vasyunin.Cotangent.StirlingBridge,
    `Cathedral.Vasyunin.Cotangent.PiecewiseFTC,
    `Cathedral.Vasyunin.Cotangent.SqueezeElimination,
    -- Cotangent tower (off-diagonal infrastructure)
    `Cathedral.Vasyunin.Cotangent.CrossTermFTC,
    `Cathedral.Vasyunin.Cotangent.OffDiagPartition,
    `Cathedral.Vasyunin.Cotangent.TelescopeSum,
    `Cathedral.Vasyunin.Cotangent.VasyuninAssembly,
    `Cathedral.Vasyunin.Cotangent.DigammaReflection,
    `Cathedral.Vasyunin.Cotangent.ConvergenceAxioms,
    `Cathedral.Vasyunin.Cotangent.LogDigammaBridge,
    `Cathedral.Vasyunin.Cotangent.FormulaBridge,
    `Cathedral.Vasyunin.Cotangent.GCDReduction,
    `Cathedral.Vasyunin.Cotangent.FractIntegrable,
    `Cathedral.Vasyunin.Cotangent.IntegralSubstitution,
    `Cathedral.Vasyunin.Cotangent.TelescopeLimit,
    `Cathedral.Vasyunin.Augmented.VasyuninIntegralProof,
    `Cathedral.Vasyunin.Augmented.IntegralBridge,
    `Cathedral.Vasyunin.Augmented.DiagBound,
    `Cathedral.Vasyunin.Augmented.CovarianceAbel,
    `Cathedral.Vasyunin.Proof.LambdaTrick,
    `Cathedral.Vasyunin.Proof.WitnessAsymptotics,
    `Cathedral.Vasyunin.Proof.WitnessConditional,
    `Cathedral.Vasyunin.Proof.Chain,
    -- Gram integral analysis
    `Cathedral.Gram.FractIntegral,
    `Cathedral.Gram.Bounds,
    `Cathedral.Gram.Diagonal,
    `Cathedral.Gram.OffDiagonal,
    `Cathedral.Gram.NbLinComb,
    `Cathedral.Gram.L2Bridge,
    -- Spectral theory
    `Cathedral.Spectral.RayleighBridge,
    `Cathedral.Spectral.PTSymmetry,
    `Cathedral.Spectral.OctonionicPartition,
    `Cathedral.Spectral.ClassRestriction,
    `Cathedral.Spectral.FiniteDimReduction,
    -- Structural layer
    `Cathedral.Structural.Independence,
    `Cathedral.Structural.Eigenvalue,
    `Cathedral.Structural.Structural,
    -- Mellin bridge
    `Cathedral.MellinBridge.Basic,
    `Cathedral.MellinBridge.FloorMellin,
    `Cathedral.MellinBridge.FloorDivMellin,
    `Cathedral.MellinBridge.HilbertSetup,
    `Cathedral.MellinBridge.Separation,
    `Cathedral.MellinBridge.OrthogonalWitness,
    `Cathedral.MellinBridge.AbelSummation,
    `Cathedral.MellinBridge.MertensIntegral,
    `Cathedral.MellinBridge.MertensWeightBypass,
    `Cathedral.MellinBridge.AutocorrelationBypass,
    `Cathedral.MellinBridge.MellinSieve,
    `Cathedral.MellinBridge.DomainConnected,
    `Cathedral.MellinBridge.IdentityBypass,
    `Cathedral.MellinBridge.MertensBound,
    `Cathedral.MellinBridge.BDWeights,
    `Cathedral.MellinBridge.AbelSiegeProof,
    `Cathedral.MellinBridge.PlancherelDefs,
    `Cathedral.MellinBridge.PlancherelBypass,
    -- Sieve engine
    `Cathedral.Sieve.VasyuninExpansion,
    `Cathedral.Sieve.ParitySchur,
    `Cathedral.Sieve.BilinearSieve,
    `Cathedral.Sieve.MoebiusUncoupling,
    -- Abel tail engine (production split from Scratch)
    `Cathedral.AbelTail.Antiderivative,
    `Cathedral.AbelTail.RectangleBound,
    `Cathedral.AbelTail.Telescoping,
    `Cathedral.AbelTail.MertensBridge,
    `Cathedral.AbelTail.DiscreteProductRule,
    `Cathedral.AbelTail.LogTailBound,
    `Cathedral.AbelTail.AbelInterior,
    `Cathedral.AbelTail.S1Decay,
    `Cathedral.AbelTail.S2Decay,
    `Cathedral.AbelTail.S3Decay,
    `Cathedral.AbelTail.S3UniformBound,
    `Cathedral.AbelTail.Assembly,
    -- Assembly (the crown)
    `Cathedral.Assembly.CertifiedComputation,
    `Cathedral.Assembly.QuadFormBridge,
    -- GramWitness archived to Cathedral/Archive/Universe1/ (April 25, 2026)
    -- witness_l2_error_decay_gram axiom ELIMINATED
    `Cathedral.Assembly.BDBridge,
    `Cathedral.Assembly.BDBypass,
    `Cathedral.Assembly.VasyuninBypass,
    `Cathedral.Assembly.DirectL2Crown,
    `Cathedral.Assembly.AbelL2Bridge,
    `Cathedral.Assembly.MoebiusL1Bound,
    `Cathedral.Assembly.CalcBounds,
    `Cathedral.Assembly.DotProductIdentity,
    `Cathedral.Assembly.AbelEngine,
    `Cathedral.Assembly.MertensConversion,
    `Cathedral.Assembly.PNTAbelMean,
    `Cathedral.Assembly.MillenniumWall,
    `Cathedral.Assembly.L2Convergence,
    `Cathedral.Assembly.FinalDragon,
    `Cathedral.Assembly.OneCrown,
    `Cathedral.Assembly.MainChain,
    `Cathedral.Assembly.Assembly,
    -- PNT bridge (single axiom consolidation)
    `Cathedral.Assembly.PNTBridge,
    -- Mertens graduation (axiom → theorem via Perron)
    `Cathedral.Assembly.MertensFromPerron,
    -- Perron Crown (axiom elimination + covariance graduation)
    `Cathedral.Assembly.PerronCrown,
    -- White Singlet (Phase I: Axiom elimination)
    `Cathedral.White.Kinematics,
    `Cathedral.White.Scattering,
    -- White Singlet Infrastructure (Mathlib-ready scaffolds)
    `Cathedral.White.Infrastructure.MontgomeryVaughan,
    -- Perron formula (modular split, zero sorry)
    `Cathedral.White.Infrastructure.Perron.Defs,
    `Cathedral.White.Infrastructure.Perron.IntegralBounds,
    `Cathedral.White.Infrastructure.Perron.Rectangle,
    `Cathedral.White.Infrastructure.Perron.ResidueGtOne,
    `Cathedral.White.Infrastructure.Perron.ResidueLtOne,
    `Cathedral.White.Infrastructure.Perron.KernelBound,
    `Cathedral.White.Infrastructure.Perron.Formula,
    -- Perron-Möbius chain: M(x) = O(x^{1/2+ε}) under RH
    `Cathedral.White.Infrastructure.Perron.ContourShift,
    `Cathedral.White.Infrastructure.Perron.DirichletPoly,
    `Cathedral.White.Infrastructure.SummabilityHelpers,
    `Cathedral.White.Infrastructure.Perron.HalfIntegerPerron,
    `Cathedral.White.Infrastructure.Perron.VerticalBounds,
    `Cathedral.White.Infrastructure.Perron.AssemblyHelpers,
    `Cathedral.White.Infrastructure.Perron.PerronMoebius,
    -- Dirichlet series inverse: L(μ,s) = 1/ζ(s) (PROVED)
    `Cathedral.White.Infrastructure.DirichletZetaInverse,
    -- Conditional Lindelöf bound + horizontal contour vanishing (2 sorry)
    `Cathedral.White.Infrastructure.ZetaConvexity,
    -- Gamma function norm bounds (PROVED, zero sorry)
    `Cathedral.White.Infrastructure.GammaBound,
    -- Zeta convexity bound (WIP)
    `Cathedral.White.Infrastructure.ZetaConvexityBound,
    -- Zeta disk geometry & upper bounds (zero sorry)
    `Cathedral.White.Infrastructure.ZetaDiskBounds,
    -- Zeta tail bound: ‖ζ(s)-1‖ < 1 for Re(s) ≥ 2 (PROVED, zero sorry)
    `Cathedral.White.Infrastructure.ZetaTailBound,
    -- Hadamard three-circles + zero-counting axiom (thin-strip infrastructure)
    `Cathedral.White.Infrastructure.ZetaHadamard,
    -- Polynomial lower bound on |ζ(s)| via Borel-Carathéodory
    `Cathedral.White.Infrastructure.ZetaLowerBound,
    -- Schur's Test + Montgomery-Vaughan Hilbert inequality (Schur PROVED)
    `Cathedral.White.Infrastructure.HilbertInequality,
    -- Dirichlet test for series convergence (PROVED, zero sorry, zero axiom)
    `Cathedral.White.Infrastructure.DirichletTest,
    `Cathedral.White.Infrastructure.CenteredFractBound,
    -- Partial sum convergence (Vasyunin integral decomposition)
    `Cathedral.Vasyunin.Cotangent.PartialSumConvergence,
    -- Integral = S_combined evaluative plumbing (building)
    `Cathedral.Vasyunin.Cotangent.IntegralEqSCombined,
  ]
