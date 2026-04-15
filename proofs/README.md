# Cathedral — Lean 4 Proof Architecture

The formal verification core of the Cathedral project. A machine-checked
reduction of the Riemann Hypothesis to a discrete variational witness.

## Build

```bash
lake build    # zero errors, zero sorry, zero warnings
```

## Architecture

```
Cathedral/
├── Defs.lean                              — Core definitions (RH, NB distance)
│
├── LinearAlgebra/                         — LAYER 0: Pure algebra (0 axioms)
│   ├── SchurComplement.lean               — Schur complement + bordered matrix
│   ├── ShermanMorrison.lean               — d² = 1/(1+X)
│   ├── Sylvester.lean                     — Sylvester's criterion for PD matrices
│   └── Variational.lean                   — Rayleigh quotient lower bound
│
├── Vasyunin/                              — LAYERS 1–5: The main proof
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
│   │   ├── IntegralBridge.lean            — Vasyunin integral axiom
│   │   ├── MeanIntegral.lean              — ∫₀¹ {1/(kx)} dx = (ln k + 1 - γ)/k
│   │   ├── NbDistPos2.lean                — NB distance positivity (N=2)
│   │   ├── NbDistPos3.lean                — NB distance positivity (N=3)
│   │   └── Rayleigh.lean                  — Rayleigh quotient theorems
│   │
│   ├── Cotangent/                         — LAYER 4: Vasyunin formula evaluation
│   │   ├── DigammaReflection.lean         — ψ(1-s)-ψ(s) = πcot(πs)
│   │   ├── TelescopeSum.lean              — Cotangent telescope sums
│   │   ├── VasyuninAssembly.lean          — Assembly of telescope chain
│   │   ├── LogDigammaBridge.lean          — Digamma → Vasyunin link (3 axioms)
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
├── NymanBeurling/                         — LAYER 6: NB criterion
│   └── NymanBeurling.lean                 — d²_N → 0 ⟺ RH
│
└── Robin/                                 — LAYER 7: Arithmetic equivalences
    ├── Defs.lean                          — Robin/Lagarias definitions (1 axiom)
    ├── BaseCases.lean                     — σ(p) ≤ bound for p ∈ {2,3,5,7}
    ├── Equivalence.lean                   — 4 cross-path equivalence theorems
    ├── HarmonicBounds.lean                — Harmonic number properties
    ├── PrimeBounds.lean                   — lagarias_for_primes (0 axioms)
    └── SigmaProps.lean                    — Divisor sum properties
```

## Stats

| Metric | Count |
|---|---|
| Active Lean files | 38 |
| Theorems + Lemmas | 230+ |
| Definitions | 48 |
| `sorry` | **0** |
| Warnings | **0** |

## The Axiom Structure

The Cathedral's axioms decompose into tiers:

### Tier 1: The RH Content (1 axiom)
- **`witness_covariance_decay`** — vᵀCv ≤ C/ln(N)
  - *Machine-verified equivalent to RH* (`witness_covariance_decay_iff_rh`)
  - Plain English: "The Selberg-weighted Möbius witness approximates 1 in L²(0,1) with error O(1/ln N)"

### Tier 2: PNT-Level (1 axiom)
- **`witness_numerator_convergence`** — bᵀv → 1 (from Mertens: Σ μ(k)·ln(k)/k → -1)

### Tier 3: Classical Number Theory (6 axioms)
- 3 Mertens partial-sum axioms (BartlettWindow)
- 3 Vasyunin integral / digamma evaluation axioms

### Tier 4: Structural (3 axioms)
- `arithmetic_rh_equivalences` — Robin ↔ Lagarias ↔ RH
- `rh_implies_mertens_bound` — RH → |M(x)| ≤ Cx^{1/2}(log x)²
- `abel_summation_l2_bound` — Mertens bound → L² decay
- `algebraic_nb_bridge` — Gram matrix = integrals (links algebraic/analytic)
