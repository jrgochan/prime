import Lake
open Lake DSL

package "hyperzeta_proofs" where
  -- Build constraints securely limiting memory limits

-- PrimeNumberTheoremAnd: Was temporarily removed (axiom-ified, May 10 2026).
-- Re-enabled May 31, 2026 at v4.29.0 to graduate 6 PNT axioms.
-- See Cathedral.PNT.PNTAndBridge for the bridge.

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.29.0"

-- PrimeNumberTheoremAnd: RE-ENABLED (May 31, 2026) at v4.29.0.
-- Graduates PNT axioms: mu_pnt_alt, R_isLittleO, frac_error_isLittleO.
require PrimeNumberTheoremAnd from git
  "https://github.com/AlexKontorovich/PrimeNumberTheoremAnd.git" @ "v4.29.0"

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
    `Cathedral.NymanBeurling.Antitone,
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
    -- L² Bridge: Mertens L² rate → Gram bound → RH (Exploration 36)
    `Cathedral.Vasyunin.Proof.GramL2Bridge,
    `Cathedral.Vasyunin.Proof.Chain,
    -- E_ratio Vanishing + Cotangent Reduction (Exploration 37: Crown → cotangent axiom)
    `Cathedral.Vasyunin.Proof.RatioVanishing,
    -- Selberg-Möbius stratification of cotangent sum (Exploration 37)
    `Cathedral.Vasyunin.Proof.CotangentStratification,
    -- Step Monotonicity: d²(N+1) ≤ d²(N) via variational bound (PROVED, zero axiom)
    `Cathedral.Vasyunin.Proof.StepMonotone,
    -- Asymptotic freedom: d² → 0 via telescoping Schur complements
    `Cathedral.Vasyunin.Proof.AsymptoticFreedom,
    -- Gram integral analysis
    `Cathedral.Gram.FractIntegral,
    `Cathedral.Gram.Bounds,
    `Cathedral.Gram.Diagonal,
    `Cathedral.Gram.OffDiagonal,
    `Cathedral.Gram.NbLinComb,
    `Cathedral.Gram.L2Bridge,
    -- Prime/composite Gram entry bounds (Exploration 36, zero sorry modulo Mertens axiom)
    `Cathedral.Gram.PrimeDecoupling,
    -- Spectral theory
    `Cathedral.Spectral.RayleighBridge,
    `Cathedral.Spectral.PTSymmetry,
    `Cathedral.Spectral.OctonionicPartition,
    `Cathedral.Spectral.ClassRestriction,
    `Cathedral.Spectral.FiniteDimReduction,
    -- Fourier–Gram Bridge (Exploration 31, ZERO SORRY)
    `Cathedral.Spectral.FourierGram,
    -- Prime Harmonics: oscillators on the unit circle
    `Cathedral.Spectral.PrimeHarmonics,
    -- Mirror Duality: zeros reconstruct primes (explicit formula)
    `Cathedral.Spectral.MirrorDuality,
    -- Ramanujan B₁ Inner Product (∫B₁({jt})·B₁({kt}) = gcd²/(12jk), ZERO SORRY)
    `Cathedral.Spectral.RamanujanInnerProduct,
    `Cathedral.Spectral.BilinearSieve,
    -- Spectral exploration (Exploration 19, NOT on crown path)
    `Cathedral.Spectral.ResidueDecomposition,
    `Cathedral.Spectral.ParticipationRatio,
    `Cathedral.Spectral.HeisenbergBypass,
    -- Davis-Kahan bridge (Prime Core → Covariance Decay, Exploration 36)
    `Cathedral.Spectral.DavisKahan,
    -- Witness concentration (Prime sector ℓ² mass bound, Exploration 36)
    `Cathedral.Spectral.WitnessConcentration,
    -- Structural layer
    `Cathedral.Structural.BDFloorArithmetic,
    `Cathedral.Structural.Independence,
    `Cathedral.Structural.BorderedSpectral,
    `Cathedral.Structural.Eigenvalue,
    `Cathedral.Structural.DivisorDropBound,
    `Cathedral.Structural.TailSumBound,
    `Cathedral.Structural.PrimeFractal,
    `Cathedral.Structural.Structural,
    -- Cholesky Decrement (d²(N+1) = d²(N) - y²_new, Approach A, May 31 2026)
    `Cathedral.Structural.CholeskyDecrement,
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
    `Cathedral.Assembly.SpectralObservatory,
    `Cathedral.NymanBeurling.QuadFormBridge,
    -- GramWitness archived to Cathedral/Archive/Universe1/ (April 25, 2026)
    -- witness_l2_error_decay_gram axiom ELIMINATED
    `Cathedral.NymanBeurling.BDBridge,
    `Cathedral.NymanBeurling.WitnessDecayProved,
    `Cathedral.NymanBeurling.BDBridgeProved,
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
    -- Gram Crown: discrete 2-axiom proof of RH (Exploration 37)
    `Cathedral.Assembly.GramCrown,
    -- Overcancellation: Crown-free path to RH (Exploration 39)
    `Cathedral.Assembly.OvercancellationChain,
    `Cathedral.Assembly.FejerMellinBound,
    `Cathedral.Assembly.Assembly,
    -- PNT bridge (re-enabled via local PNTAnd clone with v4.29 fix)
    `Cathedral.PNT.Bridge,
    -- PNTAnd Bridge (graduates mu_pnt_alt, R_isLittleO from PrimeNumberTheoremAnd)
    `Cathedral.PNT.PNTAndBridge,
    -- Mertens graduation (axiom → theorem via Perron)
    `Cathedral.Perron.MertensFromPerron,
    -- Perron Crown (axiom elimination + covariance graduation)
    `Cathedral.Assembly.PerronCrown,
    -- Path E: Mellin-Spectral Fusion (discrete_riemann_hypothesis graduation path)
    `Cathedral.Assembly.CovarianceFromPerron,
    -- Mellin Crown (frequency-domain forward direction, exploration10)
    `Cathedral.Assembly.MellinPerronBridge,
    `Cathedral.Assembly.MellinVarianceProof,
    `Cathedral.Assembly.MellinCrown,
    -- Mellin residual expansion (Crown graduation path, Exploration 13)
    `Cathedral.Assembly.MellinResidualExpansion,
    -- Gram form graduation (axiom → theorem via split-region L²)
    `Cathedral.Covariance.CovarianceAbel,
    `Cathedral.Covariance.CovarianceBound,
    `Cathedral.Covariance.GramFormProof,
    -- Euler product decomposition (Robin Resonance, Exploration 29)
    `Cathedral.Covariance.EulerProduct,
    `Cathedral.Covariance.Direct,
    `Cathedral.Covariance.DotProductBound,
    -- Taper decomposition (vᵀGv = U - 2L/lnN + Q/ln²N, Exploration 33)
    `Cathedral.Covariance.TaperDecomposition,
    -- GCD partition of the taper (Möbius Stratum Conjecture, Exploration 35)
    `Cathedral.Covariance.GCDPartition,
    -- Per-stratum growth bounds (Layer 4, Exploration 35)
    `Cathedral.Covariance.GCDStratumBound,
    -- GCD sign law (Layer 5, Möbius Stratum Conjecture, Exploration 35)
    `Cathedral.Covariance.GCDSignLaw,
    -- Ramanujan GCD Strata (Path B: v^T R v by arithmetic locality, Exploration 37)
    `Cathedral.Covariance.RamanujanGCDStrata,
    -- Coprime Inner Sum (Path B Phase 2: universal kernel Φ(M) analysis, Exploration 37)
    `Cathedral.Covariance.CoprimeInnerSum,
    -- Twelve Bridge (Trinity of 1/12: ζ(-1) ↔ R(k,k) ↔ kernel, Higgs anomaly, Exploration 37)
    `Cathedral.Covariance.TwelveBridge,
    -- Anomaly Strata (Final Reduction: Crown ↔ anomaly decay, Exploration 37)
    `Cathedral.Covariance.AnomalyStrata,
    -- Crown Reduction (3 Legs → Crown: PNT + Ramanujan + Anomaly, Exploration 37)
    `Cathedral.Covariance.CrownReduction,
    -- HC number formalization (unbounded HC subsequence, Exploration 36)
    `Cathedral.Covariance.HighlyComposite,
    -- HC-Gram bridge (HC bound → subseq bound → RH, Exploration 36)
    `Cathedral.Covariance.HCGramBridge,
    -- HC-Euler product (recipProduct/gcdWeighted Euler evaluation, Exploration 36)
    `Cathedral.Covariance.HCEulerProduct,
    -- HC prime structure (graduated Mertens HC axiom, Exploration 36)
    `Cathedral.Covariance.HCPrimeStructure,
    -- Mertens bridge (PNTA → Cathedral, Exploration 35)
    `Cathedral.Covariance.MertensBridge,
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
    `Cathedral.IntegralBasis.IntegralQuadForm,
    -- Winding Energy: Fourier B₁ decomposition of interference energy
    `Cathedral.IntegralBasis.WindingEnergy,
    `Cathedral.Analysis.IntervalCalc,
    -- PNT LogBridge (Dirichlet convolution identity, 1 sorry)
    `Cathedral.PNT.LogBridge,
    -- Number theory (Dirichlet convolution identities, Exploration 13)
    `Cathedral.NumberTheory.DirichletConvolution,
    -- Covariance Abel engine (Exploration 13)
    `Cathedral.Covariance.QuadFormIdentity,
    `Cathedral.Covariance.BilinearAbel,
    -- Abel covariance bound scaffold (closes witness_covariance_decay path)
    `Cathedral.Covariance.AbelCovarianceBound,
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
    `Cathedral.Physics.GaugeTheory.Dirac,
    -- Physics: Arithmetic Pauli Exclusion (Möbius = fermionic statistics, Exploration 36)
    `Cathedral.Physics.GaugeTheory.ArithmeticPauli,
    -- Physics: Arithmetic U(1) gauge (Liouville = charge conservation, Exploration 36)
    `Cathedral.Physics.GaugeTheory.ArithmeticU1,
    -- Physics: Arithmetic SU(2) gauge (parity breaking at p=2 = Higgs, Exploration 36)
    `Cathedral.Physics.GaugeTheory.ArithmeticSU2,
    -- Physics: Arithmetic SU(3) gauge (color confinement at p=3, Exploration 36)
    `Cathedral.Physics.GaugeTheory.ArithmeticSU3,
    -- Physics: Arithmetic Standard Model crown (U(1)×SU(2)×SU(3) assembly, Exploration 36)
    `Cathedral.Physics.GaugeTheory.ArithmeticStandardModel,
    -- Physics: Gauge Decomposition (bosonic/fermionic sector split, Exploration 36)
    `Cathedral.Physics.GaugeTheory.ArithmeticGaugeDecomposition,
    -- Physics: Confinement (strong coupling ρ>1, non-perturbative v*, Mirror RH Closure)
    `Cathedral.Physics.GaugeTheory.Confinement,
    -- Physics: Gauge Cancellation (vᵀGv SUSY decomposition, Exploration 36)
    `Cathedral.Physics.Cancellation.GaugeCancellation,
    -- Physics: Diagonal Bound (D(N) = O(ln N) unconditional, Exploration 36)
    `Cathedral.Physics.GramWiring.DiagonalBound,
    -- Physics: SUSY Reduction (Crown ⟺ Off-Diagonal Cancellation, Exploration 36)
    `Cathedral.Physics.Cancellation.SUSYReduction,
    -- Physics: SUSY Vacuum (topological SUSY algebra, Exploration 36)
    `Cathedral.Physics.Cancellation.SUSYVacuum,
    -- Physics: Ward Identity (arithmetic Noether theorem, Exploration 36)
    `Cathedral.Physics.Cancellation.WardIdentity,
    -- Physics: Spectral Gap Bridge (Ward → eigenvalue bounds, Exploration 36)
    `Cathedral.Physics.Strategy.SpectralGap,
    -- Physics: Phase Transition (B+F sign flip, cosmological ratio, Exploration 36)
    `Cathedral.Physics.Bridges.PhaseTransition,
    -- Physics: Cancellation Efficacy (algebraic engine of 99.96% cancellation, Exploration 36)
    `Cathedral.Physics.Cancellation.CancellationEfficacy,
    -- Physics: Inhomogeneous Ward Bound (GU-reframed crown axiom, Exploration 36)
    `Cathedral.Physics.Cancellation.InhomogeneousWard,
    -- Physics: Liouville Marginal (equidistribution against Gram, v4 sweep, Exploration 36)
    `Cathedral.Physics.Bridges.LiouvilleMarginal,
    -- Physics: Row Cancellation (per-row → global Ward bridge, Exploration 36)
    `Cathedral.Physics.Cancellation.RowCancellation,
    -- Physics: Bilinear Mertens Bridge (PNT → excess bound → Ward, Exploration 36)
    `Cathedral.Physics.Mertens.BilinearMertens,
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
    -- Zero-axiom forward direction (Exploration 36: The Road to Zero)
    `Cathedral.ZeroAxiom.AbelEngine,
    `Cathedral.ZeroAxiom.TaperedAbel,
    -- Compute: Interval arithmetic verifier (Oracle bridge, Exploration 32)
    `Cathedral.Compute.IntervalVerifier,
    -- Compute: Trusted oracle certificates (GPU → Lean, Exploration 32)
    `Cathedral.Compute.OracleCertificates,
    -- Oracle Cascade: RH from oracle → all conditional theorems (Exploration 32)
    `Cathedral.Assembly.OracleCascade,
    -- Qualitative forward direction (off-path, PNT convergence scaffold)
    `Cathedral.Assembly.QualitativeForward,
    -- Unconditional Mertens scaffold (off-path, PNT → M(x) = O(x^{3/4}))
    `Cathedral.PNT.UnconditionalMertens,
    -- Moment Method + Large Sieve (Exploration 36: clean forward path)
    `Cathedral.Assembly.ParsevalFactored,
    `Cathedral.Assembly.ZetaEnvelope,
    `Cathedral.Assembly.MomentMethodCrown,
    -- Direct Mellin Bound (Exploration 36: bypasses false covariance axiom)
    `Cathedral.Assembly.DirectMellinBound,
    -- Coprime Diagonal (Bilinear Probe v2: (6/π²)·logN + Chowla connection)
    `Cathedral.Physics.GramWiring.CoprimeDiagonal,
    -- Basel-Möbius (Squarefree graduation: Σ μ(d)/d² = 6/π²)
    `Cathedral.NumberTheory.BaselMoebius,
    -- Squarefree Reciprocal (graduation target: Σ_{sqfree} 1/k ≥ ½logN)
    `Cathedral.NumberTheory.SquarefreeReciprocal,
    -- Dark Gram Matrix (Bernoulli basis: the mirror universe, Exploration 36)
    `Cathedral.Gram.DarkGramMatrix,
    -- HC-Dark Spectral Anchor (connects dark PSD to HC optimality)
    `Cathedral.Physics.Bridges.HCDarkAnchor,
    -- S-Duality Glass (the mirror's conversion factor: ζ(2)↔ζ(4))
    `Cathedral.Physics.Glass.SDualityGlass,
    -- Hopf Glass Cycle (Cayley-Dickson tower ζ(2)↔ζ(16), Exploration 36)
    `Cathedral.Physics.Glass.HopfGlassCycle,
    -- Trigintaduonion Glass (32D/64D Prime Democracy, tower convergence, Exploration 36)
    `Cathedral.Physics.Glass.TrigintaduonionGlass,
    -- Möbius Shadow Crown (glass-layered factorization → crown bound)
    `Cathedral.Physics.Glass.MoebiusShadowCrown,
    -- Mertens Third (∏(1-1/p) ~ e^{-γ}/ln(N), shadow rate)
    `Cathedral.NumberTheory.MertensThird,
    -- Glass-Fiber CotRes decomposition (sym/anti splitting, dissolution lemma)
    `Cathedral.Physics.Glass.GlassFiberCotRes,
    -- Glass Euler Convergence (Glass₁ product → 0 via Mertens)
    `Cathedral.Physics.Glass.GlassEulerConvergence,
    -- Zeta2 Product Bound (graduation of zeta2Product_lower_bound axiom)
    `Cathedral.Zeta.Zeta2ProductBound,
    -- Mirror Geometry: the three realities of the zeta function
    `Cathedral.Zeta.MirrorGeometry,
    -- Zeta Tower Limit: ζ(2ⁿs) → 1 as n → ∞ (GRADUATED, zero sorry)
    `Cathedral.Zeta.ZetaTowerLimit,
    -- Glass Telescope: ζ(s) = ζ(2ⁿs) · ∏ ζ(2^k·s)/ζ(2^{k+1}·s) (GRADUATED, zero sorry)
    `Cathedral.Zeta.GlassTelescope,
    -- Glass Critical Line: the 4-step chain Glass → RH (1 axiom: THE WALL)
    `Cathedral.Physics.Glass.GlassCriticalLine,
    -- CotRes ↔ vᵀGv Bridge (diagonal/off-diagonal decomposition)
    `Cathedral.Physics.Glass.CotResQuadBridge,
    -- Bose-Einstein Primes (File #444: ζ(s) as partition function, Fermi-Dirac = squarefree)
    `Cathedral.Physics.Glass.BoseEinsteinPrimes,
    -- Möbius-Smith Bridge (connects SOS decomposition to Möbius weights)
    `Cathedral.Physics.GramWiring.MoebiusSmithBridge,
    `Cathedral.Physics.Cancellation.WoodburyCondensate,
    -- Critical Line Phase (1D Collapse: ξ(½+it) ∈ ℝ, Schwarz reflection, Exploration 38)
    `Cathedral.Physics.Bridges.CriticalLinePhase,
    -- Geometric Mertens Bridge (scan ↔ sign oscillation, Exploration 38)
    `Cathedral.Physics.Mertens.GeometricMertens,
    -- Morphology Bridge (shape ↔ Gram eigenstructure, Exploration 38)
    `Cathedral.Physics.Bridges.MorphologyBridge,
    -- Zeta-Mertens Bridge (Z-function ↔ truncated Mertens, NB integration)
    `Cathedral.Physics.Mertens.ZetaMertensBridge,
    -- Comparison Operator — ARCHIVED to Physics/Archive/ (superseded by SmithSpectralGap)
    -- Ramanujan Bridge (gcd²/(12jk) matrix, Jordan J₂, PSD, Exploration 39)
    `Cathedral.Physics.Mertens.RamanujanBridge,
    -- Glass Comparison (π⁴/3 bound, Ramanujan↔Dark transport, Exploration 39)
    `Cathedral.Physics.Glass.GlassComparison,
    -- Smith Spectral Gap (Dark PD via Smith decomposition, triangular injectivity)
    `Cathedral.Physics.GramWiring.SmithSpectralGap,
    -- Glass Distance (d² = 4/(4+σ) via Sherman-Morrison, Exploration 39)
    `Cathedral.Physics.Glass.GlassDistance,
    -- Sum of Squares (σ = 12·Σ d²·M₁²/J₂, manifestly non-negative)
    `Cathedral.Physics.Cancellation.SumOfSquares,
    -- Smith Witness (R·w = 𝟏 → d² ≤ 4/(4+6N) → 0)
    `Cathedral.Physics.GramWiring.SmithWitness,
    -- Von Mangoldt Bridge (c_d = Λ(d) in Smith basis, Exploration 38)
    `Cathedral.NumberTheory.VonMangoldtBridge,
    -- Spectral Divergence (Σ Λ(d)² → ∞ via Euclid, Exploration 39)
    `Cathedral.Physics.Bridges.SpectralDivergence,
    -- Gram Bridge ({t}² ≤ {t} → G_{kk} ≤ b_k, Exploration 39)
    `Cathedral.Gram.GramBridge,
    -- Ramanujan Form Bound (Smith decomposition → crown reduction, Strategy C Phase 2)
    `Cathedral.Physics.Mertens.RamanujanFormBound,
    -- Strategy C Audit (infrastructure compilation check, Phase 1)
    `Cathedral.Physics.Strategy.StrategyCAudit,
    -- Mertens-Ramanujan Bridge (divisor coefficient bound, Strategy C Phase 3)
    `Cathedral.Physics.Mertens.MertensRamanujan,
    -- Strategy C Crown (assembly + overcancellation framework, Phase 4)
    `Cathedral.Physics.Strategy.StrategyCCrown,
    -- Smith-Franel Bridge (d²_{kt} → 0 unconditionally, East Wing)
    `Cathedral.Physics.GramWiring.SmithFranelBridge,
    -- Entanglement Brake (S² brake, σ·S factorization, Thulium Session)
    `Cathedral.Physics.Cancellation.EntanglementBrake,
    -- Diagonal Decomposition (G_diag = C·Σv²/k − Σv²/k², Thulium Session)
    `Cathedral.Physics.GramWiring.DiagonalDecomposition,
    -- Cotangent Symmetry (Σcot(πm/a) = 0, Thulium Session)
    `Cathedral.Vasyunin.Cotangent.CotSymmetry,
    -- Vasyunin Reflection (V(a,a−b) = −V(a,b) algebraic core, Thulium Session)
    `Cathedral.Vasyunin.Cotangent.VasyuninReflection,
    -- Fract Reflection (graduated: {m(a−b)/a} = 1 − {mb/a}, Thulium Session)
    `Cathedral.Vasyunin.Cotangent.FractReflection,
    -- Reflection Wiring (V(a,a−b) = −V(a,b) COMPLETE, zero axiom, Thulium Session)
    `Cathedral.Vasyunin.Cotangent.VasyuninReflectionWiring,
    -- Vasyunin Bound (|V(a,b)| ≤ Σ|cot|, zero sorry, Thulium Session)
    `Cathedral.Vasyunin.Cotangent.VasyuninBound,
    -- Gershgorin Bound (eigenvalue localization, zero sorry, Thulium Session)
    `Cathedral.Vasyunin.Cotangent.GershgorinBound,
    -- Spectral Bound (Gershgorin → Gram wiring, 1 axiom, Thulium Session)
    `Cathedral.Vasyunin.Cotangent.SpectralBound,
    -- Diagonal Shift (C < 4/3, Δ(k) < 0 for k≥3, 12 theorems, Thulium Plumbing)
    `Cathedral.Physics.GramWiring.DiagonalShift,
    -- Abel Hammer (perfect square completion CσS-S²=-(S-Cσ/2)²+C²σ²/4, 13 theorems, Thulium Plumbing)
    `Cathedral.AbelTail.AbelHammer,
    -- Cotangent Dedekind Dissolution (closed-form V+V reciprocity, Thulium Session)
    `Cathedral.Physics.Bridges.CotDedekindDissolution,
    -- Overcancellation Assembly (master bound + convergence, 5 theorems, Thulium Plumbing)
    `Cathedral.Physics.Cancellation.OvercancellationAssembly,
    -- Log Correction Form (Master Decomposition: vᵀGv = AbelHammer + LogCorr − CotRes, Thulium Plumbing)
    `Cathedral.Physics.Mertens.LogCorrectionForm,
    -- Mertens Harmony (Three-Part Harmony: ratio identity + CotRes sign, Osmium Core)
    `Cathedral.Physics.Mertens.MertensHarmony,
    -- Mertens Bridge (Physics ↔ PNT connection: σ,S decomposition, Path 4.5 Step 1)
    `Cathedral.Physics.Mertens.MertensBridge,
    -- Abel Asymptotics (Abel→−S² via PNT, Crown chain, Path 4.5 Step 2)
    `Cathedral.AbelTail.AbelAsymptotics,
    -- LogCorr Asymptotics (Abel+LogCorr→−S(S+T₂), Iridium Crown, Path 4.5 Step 3)
    `Cathedral.Physics.Mertens.LogCorrAsymptotics,
    -- Iridium Crown (THE CAPSTONE: RH axiom + Crown theorem, Path 4.5 Step 4)
    `Cathedral.Physics.Bridges.IridiumCrown,
    -- B₁ Arithmetic Skeleton (Path 6: Spectral Gap Attack — gcd²/12jk decomposition)
    `Cathedral.Physics.Bridges.BernoulliSkeleton,
    -- Annihilation Bridge (σ→∞ ⟹ d²→0, conditional on moebius_annihilation)
    `Cathedral.Physics.Bridges.AnnihilationBridge,
    -- Bridge Gap (G_Vasyunin = R_Ramanujan + Δ decomposition, Bridge Gap Session)
    `Cathedral.Physics.Bridges.BridgeGap,
    -- Time-Domain Bridge (G = 2M - 1/(3jk) + 2∫E/t³, IBP maneuver, Bridge Session)
    `Cathedral.Physics.Bridges.TimeDomainBridge,
    -- Silence and Echo (trivial zero duality: ζ(-1)=-1/12, Σ_reg(-2n)=1/6, Basel)
    `Cathedral.Zeta.SilenceAndEcho,
    -- Kummer Tower (p-adic extension beyond Cayley-Dickson: ζ(-13)=ζ(-1), echo theorem)
    `Cathedral.Zeta.KummerTower,
    -- Tower Fusion (Rigidity Axiom: arithmetic structure forces zeros to Re(s)=1/2)
    `Cathedral.Zeta.TowerFusion,
    -- Spectral Tower (Fourier harmonics in the imaginary direction, Three Towers vision)
    `Cathedral.Zeta.SpectralTower,
    -- Four-Fold Symmetry (quadruplet structure, degeneration on Re=½, May 24, 2026)
    `Cathedral.Zeta.FourFoldSymmetry,
    -- Strip Geometry (circle-strip intersection, teardrop direction, May 25, 2026)
    `Cathedral.Zeta.StripGeometry,
    -- Hardy Z-Function (Z-function theory, ring contraction, May 25, 2026)
    `Cathedral.Zeta.HardyZFunction,
    -- Circle-Quadruplet Wiring (Klein V₄ on circles, degeneration at equator, May 25, 2026)
    `Cathedral.Zeta.CircleQuadruplet,
    -- Riemann Sphere (critical line = great circle, Λ₀ even, hemisphere bisection, May 25, 2026)
    `Cathedral.Zeta.RiemannSphere,
    -- Stereographic Projection (great circle = S² ∩ {X=0}, round-trip identities, May 27, 2026)
    `Cathedral.Zeta.StereographicProjection,
    -- Sphere Resonance (zeros = equatorial cancellation, prime winding → RH, May 27, 2026)
    `Cathedral.Zeta.SphereResonance,
    -- Arakelov Bridge (intersection theory road to RH, May 25, 2026)
    `Cathedral.Zeta.ArakelovBridge,
    -- Arakelov Layer 1: Weil Divisors on Spec(ℤ) (May 25, 2026)
    `Cathedral.Arakelov.WeilDivisor,
    -- Arakelov Layer 2: Arithmetic Divisors (May 25, 2026)
    `Cathedral.Arakelov.ArithmeticDivisor,
    -- Arakelov Layer 3: Gram-Arakelov Bridge (May 25, 2026)
    `Cathedral.Arakelov.GramBridge,
    -- Arakelov Layer 4: Fusion — connecting Arakelov to Cathedral (May 25, 2026)
    `Cathedral.Arakelov.ArakelovFusion,
    -- 𝔽₁ Layer 1: Λ-Rings (Borger's algebraic skeleton, May 26, 2026)
    `Cathedral.F1.LambdaRing,
    -- 𝔽₁ Layer 2: 𝔽₁-Zeta = Riemann ζ(s) (Euler product bridge, May 26, 2026)
    `Cathedral.F1.F1Zeta,
    -- 𝔽₁ Layer 3: Castelnuovo (Hodge Index → RH, The Wall, May 26, 2026)
    `Cathedral.F1.Castelnuovo,
    -- 𝔽₁ Layer 3.1: Hodge Quadratic Form (degree-0 subspace, May 26, 2026)
    `Cathedral.F1.HodgeQuadForm,
    -- 𝔽₁ Layer 3.2: Hodge Spectrum (eigenvalue growth, spectral gap, May 26, 2026)
    `Cathedral.F1.HodgeSpectrum,
    -- Euler Product Limit (lim vᵀB₁v = 1/(2π²), Option A, May 26, 2026)
    `Cathedral.NumberTheory.EulerProductLimit,
    -- Coprime-Restricted Möbius Sum (CR(d) = (6/π²)/Π(1-1/p²), May 27, 2026)
    `Cathedral.NumberTheory.CoprimeRestricted,
    -- Euler Product Graduation (Option A, FULLY GRADUATED, May 26, 2026)
    `Cathedral.NumberTheory.EulerProductGraduation,
    -- Squarefree J₂ Sum (graduation: Σ_{sqfree} 1/J₂ = π²/6, May 26, 2026)
    `Cathedral.NumberTheory.SquarefreeJ2Sum,
    -- Basis Perturbation (Bridge 2: Δ = G - R, three-term decomposition, May 29, 2026)
    `Cathedral.Physics.GramWiring.BasisPerturbation,
    -- Möbius Orthogonality (Bridge 2 closure: v^T Δ v bounded via PNT, May 29, 2026)
    `Cathedral.Physics.GramWiring.MoebiusOrthogonality,
    -- Dyson Equation (The Nuclear Option: d²_opt = d²_free + scattering, May 29, 2026)
    `Cathedral.Physics.GramWiring.DysonEquation,
    -- Inversion Bridge (The Boat: sawtooth → BD via x ↦ 1/x, 1 axiom ≡ RH, May 31, 2026)
    `Cathedral.Assembly.InversionBridge,
  ]
