# Cathedral — Lean 4 Proof Architecture

The formal verification core of the Cathedral project. A machine-checked
reduction of the Riemann Hypothesis to a discrete variational witness.

## Build

```bash
lake build    # 3,543 jobs, zero errors, zero sorry
```

## Architecture

```
Cathedral/
├── Defs.lean                              — Core definitions (gramEntry, nbLinComb, nbDistSq)
├── Axioms.lean                            — Axiom registry (zeta_zero_separates)
│
├── LinearAlgebra/                         — LAYER 0: Pure algebra (0 axioms)
│   ├── SchurComplement.lean               — Schur complement + bordered matrix
│   ├── ShermanMorrison.lean               — d² = 1/(1+X)
│   ├── Sylvester.lean                     — Sylvester's criterion for PD matrices
│   └── Variational.lean                   — Rayleigh quotient lower bound
│
├── Gram/                                  — LAYER 1: L² integral bridge (0 axioms)
│   ├── L2Bridge.lean                      — l2_error_eq_quad_error
│   ├── FractIntegral.lean                 — Fractional-part integrability
│   ├── OffDiagBound.lean                  — Off-diagonal Gram bounds
│   └── GramConvention.lean                — gramEntry symmetry, positivity
│
├── Vasyunin/                              — LAYERS 2–5: The main proof
│   ├── Defs.lean                          — Gram, covariance, mean definitions
│   ├── Witness.lean                       — Log cutoff witness construction
│   │
│   ├── Matrix/                            — LAYER 2: Matrix properties
│   │   ├── Structural.lean                — Hermitian, PSD, invertibility
│   │   ├── GramEntries.lean               — Gram entry formulas
│   │   ├── GramEvaluations.lean           — G(1,1), G(1,2), G(2,2), G(3,3)
│   │   ├── GramPSD.lean                   — det(G₂) > 0, det(G₃) > 0
│   │   ├── CovEntries.lean                — Covariance closed-form entries
│   │   ├── CovDet2.lean                   — det(C₂) > 0
│   │   └── CovDet3.lean                   — det(C₃) > 0 (quadratic interpolation)
│   │
│   ├── Augmented/                         — LAYER 3: Factorial Nuke + Rayleigh
│   │   ├── LinIndep.lean                  — Augmented linear independence
│   │   ├── AugmentedGram.lean             — H_N PD (Factorial Nuke)
│   │   ├── IntegralBridge.lean            — vasyunin_eq_integral axiom
│   │   ├── MeanIntegral.lean              — ∫₀¹ {1/(kx)} dx = (ln k + 1 - γ)/k
│   │   ├── NbDistPos2.lean                — NB distance positivity (N=2)
│   │   ├── NbDistPos3.lean                — NB distance positivity (N=3)
│   │   └── Rayleigh.lean                  — Rayleigh quotient theorems
│   │
│   ├── Cotangent/                         — LAYER 4: Vasyunin formula evaluation
│   │   ├── DigammaReflection.lean         — ψ(1-s)-ψ(s) = πcot(πs) (PROVED)
│   │   ├── TelescopeSum.lean              — Cotangent telescope sums
│   │   ├── VasyuninAssembly.lean          — Assembly of telescope chain
│   │   ├── LogDigammaBridge.lean          — Digamma → Vasyunin link
│   │   ├── CrossTermFTC.lean              — Off-diagonal piecewise FTC
│   │   ├── OffDiagPartition.lean          — Tile partition + Beatty bound
│   │   ├── DiagonalBridge.lean            — Diagonal Vasyunin bridge
│   │   ├── PiecewiseFTC.lean              — Diagonal case FTC
│   │   ├── StirlingBridge.lean            — Stirling infrastructure
│   │   └── SqueezeElimination.lean        — Squeeze theorem
│   │
│   └── Proof/                             — LAYER 5: The proof chain
│       ├── BartlettWindow.lean            — Selberg sieve = Bartlett window
│       ├── WitnessAsymptotics.lean        — Axiom decomposition (PNT + RH)
│       ├── Chain.lean                     — witness → d² → 0 → RH
│       └── WitnessConditional.lean        — decay ↔ RH (THE CROWN JEWEL)
│
├── NymanBeurling/                         — LAYER 6: NB biconditional
│   ├── NymanBeurling.lean                 — nyman_beurling_iff_rh (5 axioms)
│   └── Separation.lean                    — NB converse direction
│
├── Assembly/                              — Bridge layer
│   ├── QuadFormBridge.lean                — l2_error_eq_quad_error, variational
│   ├── MainChain.lean                     — Assembly hub
│   └── MatrixConnection.lean              — gramMatrix ↔ vasyuninGramMatrix
│
├── Structural/                            — Eigenvalue theory
│   ├── Eigenvalue.lean                    — Interlacing, drop formula
│   ├── TelescopingSum.lean                — Determinant telescoping
│   └── DeterminantBounds.lean             — Determinant lower bounds
│
├── Spectral/                              — Spectral class theory (9 axioms)
│   ├── ClassRestriction.lean              — Arithmetic class restriction
│   ├── OctonionicPartition.lean           — 8-way octonionic partition
│   ├── FiniteDimReduction.lean            — Finite-dim spectral bounds
│   ├── PTSymmetry.lean                    — Liouville delocalization
│   └── ConstantVectorBound.lean           — λ_eff linear growth (PROVED)
│
├── Sieve/                                 — Sieve engine (11 axioms)
│   ├── BilinearSieve.lean                 — type_II_sieve_bound axiom
│   ├── ParityBridge.lean                  — gram_eigenvalue_asymptotic_derived
│   ├── ParitySchur.lean                   — Parity Schur complement
│   ├── VasyuninExpansion.lean             — Large-GCD expansion
│   ├── AlignmentDecay.lean                — Liouville cancellation
│   └── MoebiusUncoupling.lean             — Vaughan decomposition
│
├── MellinBridge/                          — Mellin route (8 axioms)
│   ├── MellinSieve.lean                   — phase_3_chain (2 axioms)
│   ├── MertensWeightBypass.lean           — mertens_bound_from_rh
│   ├── AutocorrelationBypass.lean         — Fourier inversion
│   ├── OrthogonalWitness.lean             — Báez-Duarte inner products
│   ├── MertensBound.lean                  — mertensFunction + rh_implies_mertens
│   ├── BDWeights.lean                     — bdMoebiusWeight extraction
│   ├── AbelSummation.lean                 — Abel's lemma (0 axioms!)
│   ├── AbelSiegeProof.lean                — Abel + Parseval composition
│   ├── MertensIntegral.lean               — logWeight derivative bounds
│   ├── PlancherelBypass.lean              — ⚡ PARSEVAL BRIDGE (PROVED!)
│   ├── DomainConnected.lean               — Slit half-plane (0 axioms!)
│   ├── IdentityBypass.lean                — Identity theorem
│   └── DirichletCollapse.lean             — Dirichlet series
│
├── IntegralBasis/                         — Integral basis (5 axioms)
│   ├── BaezDuarte.lean                    — nyman_beurling_equivalence
│   └── Quantitative.lean                  — Schur complement bounds
│
├── Robin/                                 — LAYER 7: Arithmetic equivalences
│   ├── Defs.lean                          — Robin/Lagarias definitions (1 axiom)
│   ├── BaseCases.lean                     — σ(p) ≤ bound for p ∈ {2,3,5,7}
│   ├── Equivalence.lean                   — 4 cross-path equivalence theorems
│   ├── HarmonicBounds.lean                — Harmonic number properties
│   ├── PrimeBounds.lean                   — lagarias_for_primes (0 axioms)
│   └── SigmaProps.lean                    — Divisor sum properties
│
└── Archive/                               — Historical explorations
```

## Stats

| Metric | Count |
|---|---|
| Active Lean files | **98** |
| Compiled modules | **3,543** |
| `sorry` | **0** |
| Warnings | **2** (deprecation only) |
| Total axioms | **57** |
| Critical-path axioms | **5** (verified by `#print axioms`) |

## The Axiom Structure

### Critical Path: 5 Axioms

Verified by `#print axioms nyman_beurling_equivalence`:

| # | Axiom | Role |
|---|-------|------|
| 1 | `rh_implies_mertens_bound` | **Titchmarsh** — RH → Mertens bound |
| 2 | `autocorr_eval_zero` | **Calculus II** — Change of variables x=e^{-u} |
| 3 | `fourier_inv_autocorr` | **Mathlib** — L¹ Fourier inversion |
| 4 | `mellin_fourier_scale` | **Scaling** — 2π alignment |
| 5 | `critical_line_mellin_bound` | **Montgomery-Vaughan** — Mellin estimate |

### Key Theorem: Parseval Bridge (PROVED)

`parseval_bridge` chains axioms 2–4 to prove:
```
∫₀¹ |r_N(x)|² dx = (1/2π) ∫ |M̂_{r_N}(1/2+it)|² dt
```
This replaces the old opaque `l2_from_pointwise_bound` axiom.

### Spectral Engine: 2 Axioms

`#print axioms gram_eigenvalue_asymptotic_derived`:
- `type_II_sieve_bound` — Asymptotic parity sieve (MPFR-verified)
- `block_eigenvalue_log_scaling` — Block-diagonal eigenvalue scaling

### Zero-Axiom Theorems (Pure Mathlib)

- `gramMatrix_posSemidef` — G ≥ 0
- `gram_pos_def` — xᵀGx > 0 for x ≠ 0
- `gramMatrix_isUnit_det` — det(G) ≠ 0
- `nbDistSq_lt_one` — d² < 1
- `l2_error_eq_quad_error` — ∫(1-f)² = 1-2bᵀw+wᵀGw
- `nbDistSq_le_test_vector` — d² ≤ 1-2bᵀv+vᵀGv
- `eigenvalue_interlacing` — λ_min(G_{N+1}) ≤ λ_min(G_N)
- `lambdaEff_linear_growth_proved` — λ_eff grows linearly
