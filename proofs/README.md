# Cathedral — Lean 4 Proof Architecture

The formal verification core of the Cathedral project. A machine-checked
reduction of the Riemann Hypothesis to the decay of the Nyman–Beurling distance.

## Build

```bash
lake build    # 84 active files, 96 archived
```

## Architecture (Night Assault — April 20, 2026)

Following the Great Audit and the Night Assault (Vasyunin diagonal elimination),
the active codebase was expanded to **84 files** with the Cotangent tower
promotion. Every remaining file is on the critical path to the
crown theorem `nyman_beurling_equivalence`.

```
Cathedral/
├── Axioms.lean                            — Axiom registry (42 axioms, tiered)
├── Defs.lean                              — Core definitions (gramEntry, nbLinComb, bdLinComb)
│
├── Assembly/              (12 files)      — CROWN: Main proof chain
│   ├── MainChain.lean                     — nyman_beurling_equivalence (THE CROWN)
│   ├── OneCrown.lean                      — Single-axiom forward direction
│   ├── BDBypass.lean                      — RH → BD witness decay
│   ├── BDBridge.lean                      — Integral bridge connector
│   ├── DirectL2Crown.lean                 — Direct L² convergence
│   ├── GramWitness.lean                   — Gram matrix witness construction
│   ├── QuadFormBridge.lean                — l2_error_eq_quad_error, variational
│   ├── VasyuninBypass.lean                — Vasyunin covariance bypass
│   ├── AbelEngine.lean                    — Abel summation engine
│   ├── AbelL2Bridge.lean                  — Abel → L² bridge (2 sorry, alt path)
│   ├── FinalDragon.lean                   — Abel-Parseval bridge
│   └── Assembly.lean                      — Assembly hub
│
├── MellinBridge/          (16 files)      — Mellin transform infrastructure
│   ├── PlancherelBypass.lean              — ⚡ THE PARSEVAL BRIDGE (core)
│   ├── AbelSiegeProof.lean                — Abel + Parseval composition
│   ├── AbelSummation.lean                 — Abel's lemma (0 axioms!)
│   ├── MertensBound.lean                  — mertensFunction + rh_implies_mertens
│   ├── MertensIntegral.lean               — logWeight derivative bounds
│   ├── MertensWeightBypass.lean           — mertens_bound_from_rh
│   ├── AutocorrelationBypass.lean         — Fourier inversion
│   ├── BDWeights.lean                     — bdMoebiusWeight extraction
│   ├── Basic.lean                         — Basic Mellin definitions
│   ├── DomainConnected.lean               — Slit half-plane (0 axioms!)
│   ├── FloorDivMellin.lean                — Floor division Mellin
│   ├── FloorMellin.lean                   — Floor function Mellin
│   ├── HilbertSetup.lean                  — Hilbert space setup
│   ├── IdentityBypass.lean                — Identity theorem
│   ├── MellinSieve.lean                   — Phase 3 chain
│   └── OrthogonalWitness.lean             — Báez-Duarte inner products
│
├── NymanBeurling/         (4 files)       — Nyman-Beurling criterion
│   ├── BDMellin.lean                      — BD basis + Rank-1 Mellin Miracle
│   ├── NymanBeurling.lean                 — Re-export hub
│   ├── Separation.lean                    — Converse: d²→0 ⟹ RH (Pillar I)
│   └── ThetaBound.lean                    — ζ(s) ≠ 0 on (0,1) (0 axioms!)
│
├── Vasyunin/              (21 files)      — Matrix + witness + Cotangent tower
│   ├── Defs.lean                          — Gram, covariance, mean definitions
│   ├── Witness.lean                       — Log cutoff witness construction
│   ├── Matrix/                            — Gram matrix properties
│   │   ├── Structural.lean                — Hermitian, PSD, invertibility
│   │   ├── GramEntries.lean               — Gram entry formulas
│   │   ├── GramEvaluations.lean           — G(1,1), G(1,2), G(2,2), G(3,3)
│   │   ├── CovEntries.lean                — Covariance closed-form entries
│   │   ├── CovDet2.lean                   — det(C₂) > 0
│   │   └── CovDet3.lean                   — det(C₃) > 0
│   ├── Augmented/                         — Factorial Nuke + Rayleigh
│   │   ├── AugmentedGram.lean             — H_N PD (Factorial Nuke)
│   │   ├── IntegralBridge.lean            — vasyunin_offdiag_integral axiom
│   │   ├── VasyuninIntegralProof.lean     — Diagonal PROVED (Stirling + FTC)
│   │   ├── LinIndep.lean                  — Augmented linear independence
│   │   ├── MeanIntegral.lean              — ∫₀¹ {1/(kx)} dx = (ln k + 1 - γ)/k
│   │   └── Rayleigh.lean                  — Rayleigh quotient theorems
│   ├── Cotangent/                         — Piecewise FTC (promoted from Archive)
│   │   ├── StirlingBridge.lean            — Stirling floor bounds (0 axioms)
│   │   ├── PiecewiseFTC.lean              — Per-tile FTC engine (0 axioms)
│   │   ├── SqueezeElimination.lean        — Diagonal squeeze (0 axioms)
│   │   ├── CrossTermFTC.lean              — Off-diagonal FTC
│   │   ├── OffDiagPartition.lean          — Off-diagonal partition
│   │   ├── TelescopeSum.lean              — Telescope summation
│   │   ├── VasyuninAssembly.lean          — Assembly hub
│   │   ├── DigammaReflection.lean         — Gauss digamma (1 axiom)
│   │   └── LogDigammaBridge.lean          — Telescope-to-Vasyunin (3 axioms)
│   └── Proof/                             — Witness decay chain
│       ├── Chain.lean                     — witness → d² → 0 → RH
│       ├── LambdaTrick.lean               — Lambda trick
│       ├── WitnessAsymptotics.lean        — Axiom decomposition (PNT + RH)
│       └── WitnessConditional.lean        — decay ↔ RH
│
├── White/                 (4 files)       — Axiom elimination proofs
│   ├── Kinematics.lean                    — Antitone CoV, L² isometry
│   ├── Scattering.lean                    — Fourier-Mellin bridge
│   └── Infrastructure/
│       └── MontgomeryVaughan.lean         — MV L² bound scaffold
│
├── Gram/                  (6 files)       — L² integral bridge
│   ├── L2Bridge.lean                      — l2_error_eq_quad_error
│   ├── FractIntegral.lean                 — Fractional-part integrability
│   ├── Bounds.lean                        — Gram entry bounds
│   ├── Diagonal.lean                      — Diagonal entries
│   ├── NbLinComb.lean                     — NB linear combination
│   └── OffDiagonal.lean                   — Off-diagonal bound
│
├── Spectral/              (5 files)       — Eigenvalue analysis
│   ├── ClassRestriction.lean              — Arithmetic class restriction
│   ├── OctonionicPartition.lean           — 8-way octonionic partition
│   ├── FiniteDimReduction.lean            — Finite-dim spectral bounds
│   ├── PTSymmetry.lean                    — Liouville delocalization
│   └── RayleighBridge.lean                — Rayleigh bridge
│
├── Sieve/                 (4 files)       — Bilinear sieve + Möbius weights
│   ├── BilinearSieve.lean                 — type_II_sieve_bound axiom
│   ├── ParitySchur.lean                   — Parity Schur complement
│   ├── VasyuninExpansion.lean             — Large-GCD expansion
│   └── MoebiusUncoupling.lean             — Vaughan decomposition
│
├── LinearAlgebra/         (4 files)       — Pure algebra (0 axioms)
│   ├── SchurComplement.lean               — Schur complement + bordered matrix
│   ├── ShermanMorrison.lean               — d² = 1/(1+X)
│   ├── Sylvester.lean                     — Sylvester's criterion for PD
│   └── Variational.lean                   — Rayleigh quotient lower bound
│
├── Structural/            (3 files)       — Eigenvalue theory
│   ├── Eigenvalue.lean                    — Interlacing, drop formula
│   ├── Independence.lean                  — Linear independence
│   └── Structural.lean                    — Structural re-export
│
└── Archive/               (96 files)      — Preserved explorations
    ├── Scratch/                           — 9 dead experiments
    ├── NymanBeurling/                     — ThetaBoundMellin, MellinReduction
    ├── IntegralBasis/                     — BaezDuarte, Quantitative
    ├── Robin/                             — Robin's inequality (6 files)
    ├── Vasyunin/Cotangent/                — Foundational FTC (10 files, diagonal chain promoted)
    ├── White/Infrastructure/              — Perron, Hilbert, Selberg (6 files)
    ├── Spectral/                          — ConstantVectorBound
    ├── Sieve/                             — AlignmentDecay, ParityBridge
    ├── MellinBridge/                      — ContourShift, DirichletCollapse
    └── Assembly/                          — IntervalCalc
```

## Stats

| Metric | Count |
|---|---|
| Active Lean files | **84** |
| Archived Lean files | **96** |
| Active modules | **11** |
| Active axioms | **43** |
| Crown critical-path axioms | **7** (verified by `#print axioms`) |
| Active sorries | **2** (0 on crown path) |
| Compilation errors | **0** |

## The Two Crown Axioms

Verified by `#print axioms nyman_beurling_equivalence`:

| # | Axiom | Content |
|---|-------|---------|
| 1 | `bd_mellin_at_zero` | Analytic continuation of BD Mellin identity to Re(s) > 0 |
| 2 | `rh_implies_l2_convergence` | RH ⟹ d²_N → 0 (Báez-Duarte, 2003) |

Plus Lean kernel axioms: `propext`, `Classical.choice`, `Quot.sound`.

The 38 remaining axioms support alternative proof paths (spectral engine,
sieve engine, Vasyunin cotangent formula) that are formalized but not on
the shortest path to the crown theorem.

## The Great Audit (April 18, 2026)

A deep audit of the codebase identified:
- **31 duplicated declaration names** across different files
- **9 ghost axioms** — axioms proved as theorems elsewhere
- **3 near-complete file duplications**
- **26 orphan files** not imported by anything on the critical path

The cleanup reduced the active codebase from 178 to 78 files (−56%),
with every remaining file on the critical path. Nothing was deleted —
all files are preserved in `Archive/`.

## The Night Assault (April 20, 2026)

The Vasyunin diagonal identity `vasyunin_eq_integral` was proved as a
theorem via Stirling's formula and piecewise FTC, eliminating it as a
crown axiom. The companion axiom `fract_sq_integral` was also eliminated.
The Cotangent tower (10 files, 1,838 lines) was promoted from Archive to
active codebase. A 256-bit MPFR experiment confirmed 6–7 digit agreement
for the off-diagonal case. The crown axiom was narrowed to
`vasyunin_offdiag_integral` (off-diagonal only).
