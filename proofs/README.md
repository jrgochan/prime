# Cathedral — Lean 4 Proof Architecture

The formal verification core of the Cathedral project. A machine-checked
reduction of the Riemann Hypothesis to a discrete variational witness.

## Build

```bash
lake build    # 79 active files, 96 archived
```

## Architecture (Post-Audit — April 19, 2026)

Following the Great Audit, the active codebase was reduced from 178 to
**79 files** (−56%). Every remaining file is on the critical path to the
crown theorem `nyman_beurling_equivalence`.

```
Cathedral/
├── Axioms.lean                            — Axiom registry
├── Defs.lean                              — Core definitions (gramEntry, nbLinComb, bdLinComb)
│
├── Assembly/              (12 files)      — CROWN: Main proof chain
│   ├── MainChain.lean                     — nyman_beurling_equivalence (THE CROWN)
│   ├── FinalDragon.lean                   — Abel-Parseval bridge (active development)
│   ├── OneCrown.lean                      — Single-axiom forward direction
│   ├── BDBypass.lean                      — RH → BD witness decay
│   ├── BDBridge.lean                      — Integral bridge connector
│   ├── DirectL2Crown.lean                 — Direct L² convergence
│   ├── GramWitness.lean                   — Gram matrix witness construction
│   ├── QuadFormBridge.lean                — l2_error_eq_quad_error, variational
│   ├── VasyuninBypass.lean                — Vasyunin covariance bypass
│   ├── AbelEngine.lean                    — Abel summation engine
│   ├── AbelL2Bridge.lean                  — Abel → L² bridge
│   └── Assembly.lean                      — Assembly hub
│
├── MellinBridge/          (18 files)      — Mellin transform infrastructure
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
│   ├── OrthogonalWitness.lean             — Báez-Duarte inner products
│   ├── PlancherelDefs.lean                — Plancherel definitions
│   └── Separation.lean                    — MellinBridge separation
│
├── NymanBeurling/         (4 files)       — Nyman-Beurling criterion
│   ├── BDMellin.lean                      — BD basis + Mellin connection
│   ├── NymanBeurling.lean                 — Re-export hub
│   ├── Separation.lean                    — Converse: d²→0 ⟹ RH (Pillar I)
│   └── ThetaBound.lean                    — Completed zeta bound
│
├── Vasyunin/              (18 files)      — Matrix + witness proofs
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
│   │   ├── IntegralBridge.lean            — vasyunin_eq_integral axiom
│   │   ├── LinIndep.lean                  — Augmented linear independence
│   │   ├── MeanIntegral.lean              — ∫₀¹ {1/(kx)} dx = (ln k + 1 - γ)/k
│   │   └── Rayleigh.lean                  — Rayleigh quotient theorems
│   └── Proof/                             — Witness decay chain
│       ├── Chain.lean                     — witness → d² → 0 → RH
│       ├── LambdaTrick.lean               — Lambda trick
│       ├── WitnessAsymptotics.lean        — Axiom decomposition (PNT + RH)
│       └── WitnessConditional.lean        — decay ↔ RH
│
├── White/                 (3 files)       — Axiom elimination
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
│   ├── Sylvester.lean                     — Sylvester's criterion for PD matrices
│   └── Variational.lean                   — Rayleigh quotient lower bound
│
├── Structural/            (3 files)       — Eigenvalue theory
│   ├── Eigenvalue.lean                    — Interlacing, drop formula
│   ├── Independence.lean                  — Linear independence
│   └── Structural.lean                    — Structural re-export
│
├── Scratch/               (1 file)        — Active development
│   └── AbelTailProof.lean                 — Abel tail bound (S₂/S₃ decay)
│
└── Archive/               (96 files)      — Preserved explorations
    ├── Scratch/                           — 9 dead experiments
    ├── NymanBeurling/                     — ThetaBoundMellin, MellinReduction
    ├── IntegralBasis/                     — BaezDuarte, Quantitative
    ├── Robin/                             — Robin's inequality (6 files)
    ├── Vasyunin/Cotangent/                — Piecewise FTC (10 files)
    ├── White/Infrastructure/              — Perron, Hilbert, Selberg (6 files)
    ├── Spectral/                          — ConstantVectorBound
    ├── Sieve/                             — AlignmentDecay, ParityBridge
    ├── MellinBridge/                      — ContourShift, DirichletCollapse
    └── Assembly/                          — IntervalCalc
```

## Stats

| Metric | Count |
|---|---|
| Active Lean files | **79** |
| Archived Lean files | **96** |
| Active modules | **11** |
| Active axioms | **45** |
| Crown critical-path axioms | **5** (verified by `#print axioms`) |
| Active sorries | **38** (0 on crown path) |

## The Axiom Structure

### Crown Critical Path: 5 Axioms

Verified by `#print axioms nyman_beurling_equivalence`:

| # | Axiom | Role |
|---|-------|------|
| 1 | `rh_implies_mertens_bound` | **Titchmarsh** — RH → Mertens bound |
| 2 | `autocorr_eval_zero` | **Calculus II** — Change of variables x=e^{-u} |
| 3 | `fourier_inv_autocorr` | **Mathlib** — L¹ Fourier inversion |
| 4 | `mellin_fourier_scale` | **Convention** — 2π scaling alignment |
| 5 | `critical_line_mellin_bound` | **Montgomery-Vaughan** — Mellin estimate |

### Key Theorem: Parseval Bridge (PROVED)

`parseval_bridge` chains axioms 2–4 to prove:
```
∫₀¹ |r_N(x)|² dx = (1/2π) ∫ |M̂_{r_N}(1/2+it)|² dt
```
This replaces the old opaque `l2_from_pointwise_bound` axiom.

### Zero-Axiom Theorems (Pure Mathlib)

- `gramMatrix_posSemidef` — G ≥ 0
- `gram_pos_def` — xᵀGx > 0 for x ≠ 0
- `gramMatrix_isUnit_det` — det(G) ≠ 0
- `nbDistSq_lt_one` — d² < 1
- `l2_error_eq_quad_error` — ∫(1-f)² = 1-2bᵀw+wᵀGw
- `nbDistSq_le_test_vector` — d² ≤ 1-2bᵀv+vᵀGv
- `eigenvalue_interlacing` — λ_min(G_{N+1}) ≤ λ_min(G_N)
- `lambdaEff_linear_growth_proved` — λ_eff grows linearly

## The Great Audit (April 18, 2026)

A deep audit of the codebase identified:
- **31 duplicated declaration names** across different files
- **9 ghost axioms** — axioms proved as theorems elsewhere
- **3 near-complete file duplications**
- **26 orphan files** not imported by anything on the critical path

The cleanup reduced the active codebase from 178 to 79 files (−56%),
with every remaining file on the critical path. Nothing was deleted —
all files are preserved in `Archive/`.
