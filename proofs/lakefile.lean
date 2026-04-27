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
    `Cathedral.NymanBeurling.QuadFormBridge,
    -- GramWitness archived to Cathedral/Archive/Universe1/ (April 25, 2026)
    -- witness_l2_error_decay_gram axiom ELIMINATED
    `Cathedral.NymanBeurling.BDBridge,
    `Cathedral.NymanBeurling.BDBypass,
    `Cathedral.NymanBeurling.VasyuninBypass,
    `Cathedral.Assembly.DirectL2Crown,
    `Cathedral.AbelTail.L2Bridge,
    `Cathedral.Covariance.MoebiusL1Bound,
    `Cathedral.Covariance.CalcBounds,
    `Cathedral.Covariance.DotProductIdentity,
    `Cathedral.AbelTail.Engine,
    `Cathedral.Perron.MertensConversion,
    `Cathedral.PNT.AbelMean,
    `Cathedral.Covariance.MillenniumWall,
    `Cathedral.Covariance.L2Convergence,
    `Cathedral.Assembly.OneCrown,
    `Cathedral.Assembly.MainChain,
    `Cathedral.Assembly.Assembly,
    -- PNT bridge (single axiom consolidation)
    `Cathedral.PNT.Bridge,
    -- Mertens graduation (axiom → theorem via Perron)
    `Cathedral.Perron.MertensFromPerron,
    -- Perron Crown (axiom elimination + covariance graduation)
    `Cathedral.Assembly.PerronCrown,
    -- Mellin Crown (frequency-domain forward direction, exploration10)
    `Cathedral.Assembly.MellinVarianceProof,
    `Cathedral.Assembly.MellinCrown,
    -- Gram form graduation (axiom → theorem via split-region L²)
    `Cathedral.Covariance.CovarianceBound,
    `Cathedral.Covariance.GramFormProof,
    `Cathedral.Covariance.Direct,
    `Cathedral.Covariance.DotProductBound,
    -- White Singlet (physics-motivated axiom elimination)
    `Cathedral.White.Kinematics,
    `Cathedral.White.Scattering,
    -- Analysis (general analytic tools)
    `Cathedral.Analysis.MontgomeryVaughan,
    -- Perron formula (modular split, zero sorry)
    `Cathedral.Perron.Defs,
    `Cathedral.Perron.IntegralBounds,
    `Cathedral.Perron.Rectangle,
    `Cathedral.Perron.ResidueGtOne,
    `Cathedral.Perron.ResidueLtOne,
    `Cathedral.Perron.KernelBound,
    `Cathedral.Perron.Formula,
    -- Perron-Möbius chain: M(x) = O(x^{1/2+ε}) under RH
    `Cathedral.Perron.ContourShift,
    `Cathedral.Perron.DirichletPoly,
    `Cathedral.Perron.SummabilityHelpers,
    `Cathedral.Perron.HalfIntegerPerron,
    `Cathedral.Perron.VerticalBounds,
    `Cathedral.Perron.AssemblyHelpers,
    `Cathedral.Perron.PerronMoebius,
    -- Dirichlet series inverse: L(μ,s) = 1/ζ(s) (PROVED)
    `Cathedral.Zeta.DirichletInverse,
    -- Conditional Lindelöf bound + horizontal contour vanishing (2 sorry)
    `Cathedral.Zeta.Convexity,
    -- Gamma function norm bounds (PROVED, zero sorry)
    `Cathedral.Analysis.GammaBound,
    -- Zeta convexity bound (WIP)
    `Cathedral.Zeta.ConvexityBound,
    -- Zeta disk geometry & upper bounds (zero sorry)
    `Cathedral.Zeta.DiskBounds,
    -- Zeta tail bound: ‖ζ(s)-1‖ < 1 for Re(s) ≥ 2 (PROVED, zero sorry)
    `Cathedral.Zeta.TailBound,
    -- Hadamard three-circles + zero-counting axiom (thin-strip infrastructure)
    `Cathedral.Zeta.Hadamard,
    -- Polynomial lower bound on |ζ(s)| via Borel-Carathéodory
    `Cathedral.Zeta.LowerBound,
    -- Schur's Test + Montgomery-Vaughan Hilbert inequality (Schur PROVED)
    `Cathedral.Analysis.HilbertInequality,
    -- Dirichlet test for series convergence (PROVED, zero sorry, zero axiom)
    `Cathedral.Analysis.DirichletTest,
    `Cathedral.Analysis.CenteredFractBound,
    -- Partial sum convergence (Vasyunin integral decomposition)
    `Cathedral.Vasyunin.Cotangent.PartialSumConvergence,
    -- Integral = S_combined evaluative plumbing (building)
    `Cathedral.Vasyunin.Cotangent.IntegralEqSCombined,
    -- Resurrected from Archive (zero sorry, verified)
    `Cathedral.Vasyunin.Matrix.GramPSD,
    `Cathedral.Vasyunin.Proof.BartlettWindow,
    `Cathedral.IntegralBasis.BaezDuarte,
    `Cathedral.IntegralBasis.Quantitative,
    `Cathedral.Analysis.IntervalCalc,
  ]
