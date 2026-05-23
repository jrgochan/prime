import Lake
open Lake DSL

package "hyperzeta_proofs" where
  -- Build constraints securely limiting memory limits

-- PrimeNumberTheoremAnd: REMOVED (axiom-ified, May 10 2026).
-- All PNTAnd results used by the Cathedral are now stated as axioms
-- in the individual files that previously imported PNTAnd.
-- This makes the repo self-contained: only Lean 4 + Mathlib required.

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
    `Cathedral.Assembly.Assembly,
    -- PNT bridge (re-enabled via local PNTAnd clone with v4.29 fix)
    `Cathedral.PNT.Bridge,
    -- Mertens graduation (axiom → theorem via Perron)
    `Cathedral.Perron.MertensFromPerron,
    -- Perron Crown (axiom elimination + covariance graduation)
    `Cathedral.Assembly.PerronCrown,
    -- Path E: Mellin-Spectral Fusion (witness_covariance_decay graduation)
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
    `Cathedral.Physics.Dirac,
    -- Physics: Arithmetic Pauli Exclusion (Möbius = fermionic statistics, Exploration 36)
    `Cathedral.Physics.ArithmeticPauli,
    -- Physics: Arithmetic U(1) gauge (Liouville = charge conservation, Exploration 36)
    `Cathedral.Physics.ArithmeticU1,
    -- Physics: Arithmetic SU(2) gauge (parity breaking at p=2 = Higgs, Exploration 36)
    `Cathedral.Physics.ArithmeticSU2,
    -- Physics: Arithmetic SU(3) gauge (color confinement at p=3, Exploration 36)
    `Cathedral.Physics.ArithmeticSU3,
    -- Physics: Arithmetic Standard Model crown (U(1)×SU(2)×SU(3) assembly, Exploration 36)
    `Cathedral.Physics.ArithmeticStandardModel,
    -- Physics: Gauge Decomposition (bosonic/fermionic sector split, Exploration 36)
    `Cathedral.Physics.ArithmeticGaugeDecomposition,
    -- Physics: Gauge Cancellation (vᵀGv SUSY decomposition, Exploration 36)
    `Cathedral.Physics.GaugeCancellation,
    -- Physics: Diagonal Bound (D(N) = O(ln N) unconditional, Exploration 36)
    `Cathedral.Physics.DiagonalBound,
    -- Physics: SUSY Reduction (Crown ⟺ Off-Diagonal Cancellation, Exploration 36)
    `Cathedral.Physics.SUSYReduction,
    -- Physics: SUSY Vacuum (topological SUSY algebra, Exploration 36)
    `Cathedral.Physics.SUSYVacuum,
    -- Physics: Ward Identity (arithmetic Noether theorem, Exploration 36)
    `Cathedral.Physics.WardIdentity,
    -- Physics: Spectral Gap Bridge (Ward → eigenvalue bounds, Exploration 36)
    `Cathedral.Physics.SpectralGap,
    -- Physics: Phase Transition (B+F sign flip, cosmological ratio, Exploration 36)
    `Cathedral.Physics.PhaseTransition,
    -- Physics: Cancellation Efficacy (algebraic engine of 99.96% cancellation, Exploration 36)
    `Cathedral.Physics.CancellationEfficacy,
    -- Physics: Inhomogeneous Ward Bound (GU-reframed crown axiom, Exploration 36)
    `Cathedral.Physics.InhomogeneousWard,
    -- Physics: Liouville Marginal (equidistribution against Gram, v4 sweep, Exploration 36)
    `Cathedral.Physics.LiouvilleMarginal,
    -- Physics: Row Cancellation (per-row → global Ward bridge, Exploration 36)
    `Cathedral.Physics.RowCancellation,
    -- Physics: Bilinear Mertens Bridge (PNT → excess bound → Ward, Exploration 36)
    `Cathedral.Physics.BilinearMertens,
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
    `Cathedral.Physics.CoprimeDiagonal,
    -- Basel-Möbius (Squarefree graduation: Σ μ(d)/d² = 6/π²)
    `Cathedral.NumberTheory.BaselMoebius,
    -- Squarefree Reciprocal (graduation target: Σ_{sqfree} 1/k ≥ ½logN)
    `Cathedral.NumberTheory.SquarefreeReciprocal,
    -- Dark Gram Matrix (Bernoulli basis: the mirror universe, Exploration 36)
    `Cathedral.Physics.DarkGramMatrix,
    -- HC-Dark Spectral Anchor (connects dark PSD to HC optimality)
    `Cathedral.Physics.HCDarkAnchor,
    -- S-Duality Glass (the mirror's conversion factor: ζ(2)↔ζ(4))
    `Cathedral.Physics.SDualityGlass,
    -- Hopf Glass Cycle (Cayley-Dickson tower ζ(2)↔ζ(16), Exploration 36)
    `Cathedral.Physics.HopfGlassCycle,
    -- Trigintaduonion Glass (32D/64D Prime Democracy, tower convergence, Exploration 36)
    `Cathedral.Physics.TrigintaduonionGlass,
    -- Möbius Shadow Crown (glass-layered factorization → crown bound)
    `Cathedral.Physics.MoebiusShadowCrown,
    -- Mertens Third (∏(1-1/p) ~ e^{-γ}/ln(N), shadow rate)
    `Cathedral.Physics.MertensThird,
    -- Glass-Fiber CotRes decomposition (sym/anti splitting, dissolution lemma)
    `Cathedral.Physics.GlassFiberCotRes,
    -- Glass Euler Convergence (Glass₁ product → 0 via Mertens)
    `Cathedral.Physics.GlassEulerConvergence,
    -- Zeta2 Product Bound (graduation of zeta2Product_lower_bound axiom)
    `Cathedral.Physics.Zeta2ProductBound,
    -- CotRes ↔ vᵀGv Bridge (diagonal/off-diagonal decomposition)
    `Cathedral.Physics.CotResQuadBridge,
    -- Möbius-Smith Bridge (connects SOS decomposition to Möbius weights)
    `Cathedral.Physics.MoebiusSmithBridge,
    `Cathedral.Physics.WoodburyCondensate,
    -- Critical Line Phase (1D Collapse: ξ(½+it) ∈ ℝ, Schwarz reflection, Exploration 38)
    `Cathedral.Physics.CriticalLinePhase,
    -- Geometric Mertens Bridge (scan ↔ sign oscillation, Exploration 38)
    `Cathedral.Physics.GeometricMertens,
    -- Morphology Bridge (shape ↔ Gram eigenstructure, Exploration 38)
    `Cathedral.Physics.MorphologyBridge,
    -- Zeta-Mertens Bridge (Z-function ↔ truncated Mertens, NB integration)
    `Cathedral.Physics.ZetaMertensBridge,
    -- Comparison Operator — ARCHIVED to Physics/Archive/ (superseded by SmithSpectralGap)
    -- Ramanujan Bridge (gcd²/(12jk) matrix, Jordan J₂, PSD, Exploration 39)
    `Cathedral.Physics.RamanujanBridge,
    -- Glass Comparison (π⁴/3 bound, Ramanujan↔Dark transport, Exploration 39)
    `Cathedral.Physics.GlassComparison,
    -- Smith Spectral Gap (Dark PD via Smith decomposition, triangular injectivity)
    `Cathedral.Physics.SmithSpectralGap,
    -- Glass Distance (d² = 4/(4+σ) via Sherman-Morrison, Exploration 39)
    `Cathedral.Physics.GlassDistance,
    -- Sum of Squares (σ = 12·Σ d²·M₁²/J₂, manifestly non-negative)
    `Cathedral.Physics.SumOfSquares,
    -- Smith Witness (R·w = 𝟏 → d² ≤ 4/(4+6N) → 0)
    `Cathedral.Physics.SmithWitness,
    -- Von Mangoldt Bridge (c_d = Λ(d) in Smith basis, Exploration 38)
    `Cathedral.Physics.VonMangoldtBridge,
    -- Spectral Divergence (Σ Λ(d)² → ∞ via Euclid, Exploration 39)
    `Cathedral.Physics.SpectralDivergence,
    -- Gram Bridge ({t}² ≤ {t} → G_{kk} ≤ b_k, Exploration 39)
    `Cathedral.Physics.GramBridge,
    -- Ramanujan Form Bound (Smith decomposition → crown reduction, Strategy C Phase 2)
    `Cathedral.Physics.RamanujanFormBound,
    -- Strategy C Audit (infrastructure compilation check, Phase 1)
    `Cathedral.Physics.StrategyCAudit,
    -- Mertens-Ramanujan Bridge (divisor coefficient bound, Strategy C Phase 3)
    `Cathedral.Physics.MertensRamanujan,
    -- Strategy C Crown (assembly + overcancellation framework, Phase 4)
    `Cathedral.Physics.StrategyCCrown,
    -- Smith-Franel Bridge (d²_{kt} → 0 unconditionally, East Wing)
    `Cathedral.Physics.SmithFranelBridge,
    -- Entanglement Brake (S² brake, σ·S factorization, Thulium Session)
    `Cathedral.Physics.EntanglementBrake,
    -- Diagonal Decomposition (G_diag = C·Σv²/k − Σv²/k², Thulium Session)
    `Cathedral.Physics.DiagonalDecomposition,
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
    `Cathedral.Physics.DiagonalShift,
    -- Abel Hammer (perfect square completion CσS-S²=-(S-Cσ/2)²+C²σ²/4, 13 theorems, Thulium Plumbing)
    `Cathedral.Physics.AbelHammer,
    -- Cotangent Dedekind Dissolution (closed-form V+V reciprocity, Thulium Session)
    `Cathedral.Physics.CotDedekindDissolution,
    -- Overcancellation Assembly (master bound + convergence, 5 theorems, Thulium Plumbing)
    `Cathedral.Physics.OvercancellationAssembly,
    -- Log Correction Form (Master Decomposition: vᵀGv = AbelHammer + LogCorr − CotRes, Thulium Plumbing)
    `Cathedral.Physics.LogCorrectionForm,
    -- Mertens Harmony (Three-Part Harmony: ratio identity + CotRes sign, Osmium Core)
    `Cathedral.Physics.MertensHarmony,
    -- Mertens Bridge (Physics ↔ PNT connection: σ,S decomposition, Path 4.5 Step 1)
    `Cathedral.Physics.MertensBridge,
    -- Abel Asymptotics (Abel→−S² via PNT, Crown chain, Path 4.5 Step 2)
    `Cathedral.Physics.AbelAsymptotics,
    -- LogCorr Asymptotics (Abel+LogCorr→−S(S+T₂), Iridium Crown, Path 4.5 Step 3)
    `Cathedral.Physics.LogCorrAsymptotics,
    -- Iridium Crown (THE CAPSTONE: RH axiom + Crown theorem, Path 4.5 Step 4)
    `Cathedral.Physics.IridiumCrown,
    -- B₁ Arithmetic Skeleton (Path 6: Spectral Gap Attack — gcd²/12jk decomposition)
    `Cathedral.Physics.BernoulliSkeleton,
    -- Bridge Gap (G_Vasyunin = R_Ramanujan + Δ decomposition, Bridge Gap Session)
    `Cathedral.Physics.BridgeGap,
    -- Time-Domain Bridge (G = 2M - 1/(3jk) + 2∫E/t³, IBP maneuver, Bridge Session)
    `Cathedral.Physics.TimeDomainBridge,
  ]
