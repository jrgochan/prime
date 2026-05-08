import Lake
open Lake DSL

package "hyperzeta_proofs" where
  -- Build constraints securely limiting memory limits

-- PrimeNumberTheoremAnd: local clone with v4.29 fixes (Fourier.lean simp fix)
-- Cloned from github.com/AlexKontorovich/PrimeNumberTheoremAnd, patched in-tree
require PrimeNumberTheoremAnd from "./deps/PrimeNumberTheoremAnd"

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.29.0"

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
    -- Analysis (moved from Cotangent, Phase 1 refactoring)
    `Cathedral.Analysis.StirlingBridge,
    `Cathedral.Analysis.PiecewiseFTC,
    `Cathedral.Analysis.SqueezeElimination,
    `Cathedral.Analysis.CrossTermFTC,
    `Cathedral.Analysis.FractIntegrable,
    -- Cotangent tower (off-diagonal infrastructure)
    `Cathedral.Vasyunin.Cotangent.OffDiagPartition,
    `Cathedral.Vasyunin.Cotangent.TelescopeSum,
    `Cathedral.Vasyunin.Cotangent.VasyuninAssembly,
    `Cathedral.Vasyunin.Cotangent.DigammaReflection,
    `Cathedral.Vasyunin.Cotangent.ConvergenceAxioms,
    -- ConvergenceProof: REMOVED (dead leaf — graduation site superseded by AlgebraicLimit)
    `Cathedral.Vasyunin.Cotangent.LogDigammaBridge,
    `Cathedral.Vasyunin.Cotangent.FormulaBridge,
    `Cathedral.Vasyunin.Cotangent.GCDReduction,
    `Cathedral.Vasyunin.Cotangent.IntegralSubstitution,
    -- TelescopeLimit: REMOVED (dead leaf — squeeze limit superseded by direct evaluation)
    `Cathedral.Vasyunin.Augmented.VasyuninIntegralProof,
    `Cathedral.Vasyunin.Augmented.IntegralBridge,
    `Cathedral.Vasyunin.Augmented.DiagBound,
    `Cathedral.Vasyunin.Augmented.CovarianceAbel,
    `Cathedral.Vasyunin.Proof.LambdaTrick,
    -- Witness numerator graduation (axiom → theorem via PNT, May 2026)
    `Cathedral.Vasyunin.Proof.WitnessNumeratorProved,
    -- Witness numerator RATE graduation (Axiom B → theorem, Exploration 29)
    `Cathedral.Vasyunin.Proof.WitnessNumeratorRate,
    `Cathedral.Vasyunin.Proof.WitnessAsymptotics,
    `Cathedral.Vasyunin.Proof.WitnessConditional,
    `Cathedral.Vasyunin.Proof.GramBoundReduction,
    `Cathedral.Vasyunin.Proof.GramBoundDirect,
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
    -- Spectral exploration (Exploration 19, NOT on crown path)
    `Cathedral.Spectral.ResidueDecomposition,
    `Cathedral.Spectral.ParticipationRatio,
    `Cathedral.Spectral.HeisenbergBypass,
    -- Structural layer
    `Cathedral.Structural.BDFloorArithmetic,
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
    `Cathedral.NymanBeurling.WitnessDecayProved,
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
    -- PNT bridge (re-enabled via local PNTAnd clone with v4.29 fix)
    `Cathedral.PNT.Bridge,
    -- Mertens graduation (axiom → theorem via Perron)
    `Cathedral.Perron.MertensFromPerron,
    -- Perron Crown (axiom elimination + covariance graduation)
    `Cathedral.Assembly.PerronCrown,
    -- Mellin Crown (frequency-domain forward direction, exploration10)
    `Cathedral.Assembly.MellinPerronBridge,
    `Cathedral.Assembly.MellinVarianceProof,
    `Cathedral.Assembly.MellinCrown,
    -- Mellin residual expansion (Crown graduation path, Exploration 13)
    `Cathedral.Assembly.MellinResidualExpansion,
    -- Gram form graduation (axiom → theorem via split-region L²)
    `Cathedral.Covariance.CovarianceBound,
    `Cathedral.Covariance.GramFormProof,
    -- Euler product decomposition (Robin Resonance, Exploration 29)
    `Cathedral.Covariance.EulerProduct,
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
    -- Gamma multiplication formula (Gauss, via Stirling)
    `Cathedral.Analysis.GammaProductEval,
    `Cathedral.Analysis.GammaMultiplication,
    -- Floor-fract infrastructure (ℕ division ↔ ℝ fractional parts, ZERO SORRY)
    `Cathedral.Analysis.FloorFract,
    -- Zeta convexity bound (WIP)
    `Cathedral.Zeta.ConvexityBound,
    -- Zeta disk geometry & upper bounds (zero sorry)
    `Cathedral.Zeta.DiskBounds,
    -- Zeta tail bound: ‖ζ(s)-1‖ < 1 for Re(s) ≥ 2 (PROVED, zero sorry)
    `Cathedral.Zeta.TailBound,
    -- Hadamard three-circles + zero-counting axiom (thin-strip infrastructure)
    `Cathedral.Zeta.Hadamard,
    -- Littlewood Maneuver: Three-Circles + Right Half-Plane Trap
    -- (graduates rh_zeta_lower_bound_from_zero_counting, zero sorry)
    `Cathedral.Zeta.LittlewoodManeuver,
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
    -- PNT LogBridge (Dirichlet convolution identity, 1 sorry)
    `Cathedral.PNT.LogBridge,
    -- Number theory (Dirichlet convolution identities, Exploration 13)
    `Cathedral.NumberTheory.DirichletConvolution,
    -- Covariance Abel engine (Exploration 13)
    `Cathedral.Covariance.QuadFormIdentity,
    `Cathedral.Covariance.BilinearAbel,
    -- Gallagher MVT and frequency separation (Exploration 13-14, ZERO SORRY)
    `Cathedral.Analysis.GallagherMVT,
    `Cathedral.Analysis.FrequencySeparation,
    -- Rotors: Gallagher energy partition (Exploration 14)
    `Cathedral.Rotors.GallagherPartition,
    -- Renormalization: Arithmetic α-decay (Exploration 23, April 30, 2026)
    `Cathedral.Renormalization.Defs,
    `Cathedral.Renormalization.Axiom,
    `Cathedral.Renormalization.Bridge,
    -- Algebraic limit identification (axiom graduation infrastructure)
    `Cathedral.Vasyunin.Cotangent.AlgebraicLimit,
    -- Gram integral proof (axiom graduation: gramIntegral = vasyuninGramFormula)
    `Cathedral.Vasyunin.Cotangent.GramIntegralProof,
    -- Diagonal strike (a=1 case: gramIntegral(1,b) = vasyuninGramFormula(1,b))
    `Cathedral.Vasyunin.Cotangent.DiagonalStrike,
    -- Fract series evaluation (axiom graduation: fract correction closed form)
    `Cathedral.Vasyunin.Cotangent.FractSeriesEval,
    -- General fract series evaluation (Phase 1: coprime (a,b) decomposition)
    `Cathedral.Vasyunin.Cotangent.GeneralFractSeriesEval,
    -- Two-tile correction (Phase 2: Δ(m) = actualRowIntegral - rowTerm)
    `Cathedral.Vasyunin.Cotangent.TwoTileCorrection,
    -- Generalized residue-class evaluation (Phase 3: {ar/b} weights)
    `Cathedral.Vasyunin.Cotangent.GeneralResidueEval,
    -- Weighted digamma general (Phase 4: tsum = fractTarget)
    `Cathedral.Vasyunin.Cotangent.WeightedDigammaGeneral,
    -- Two-tile evaluation (Phase 5-6: assembly → axiom graduation)
    `Cathedral.Vasyunin.Cotangent.FractTargetEval,
    `Cathedral.Vasyunin.Cotangent.ColumnSumEval,
    `Cathedral.Vasyunin.Cotangent.DeltaDirectEval,
    `Cathedral.Vasyunin.Cotangent.DeltaResidueEval,
    `Cathedral.Vasyunin.Cotangent.TsumDirectEval,
    `Cathedral.Vasyunin.Cotangent.TwoTileEval,
    -- Physics: 1+1D Dirac equation (conceptual beacon, NOT on proof chain)
    `Cathedral.Physics.Dirac,
    -- Robin's inequality (discrete arithmetic path, un-archived May 2, 2026)
    `Cathedral.Robin.Defs,
    `Cathedral.Robin.SigmaProps,
    `Cathedral.Robin.BaseCases,
    `Cathedral.Robin.HarmonicBounds,
    `Cathedral.Robin.PrimeBounds,
    `Cathedral.Robin.Equivalence,
    `Cathedral.Robin.GramDiagonalBound,
    -- Zero-axiom forward direction (Exploration 27: The Millennium Strike)
    `Cathedral.ZeroAxiom.FiniteDirichlet,
    `Cathedral.ZeroAxiom.MellinAlgebra,
  ]
