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
├── Defs.lean                         — Core definitions (RH, Nyman-Beurling distance)
├── LinearAlgebra/
│   ├── SchurComplement.lean          — Schur complement + bordered matrix theorem
│   ├── ShermanMorrison.lean          — d² = 1/(1+X), zero axioms
│   ├── Sylvester.lean                — Sylvester's criterion for PD matrices
│   └── Variational.lean              — Rayleigh quotient lower bound
├── MellinBridge/
│   ├── NymanBeurling.lean            — d²_N → 0 ⟺ RH
│   ├── Vasyunin.lean                 — Module root
│   └── Vasyunin/
│       ├── AugmentedGram.lean        — H_N PD, G_N PD, bᵀG⁻¹b < 1 (Factorial Nuke)
│       ├── Chain.lean                — Full proof chain: axiom → RH
│       ├── CovDet2.lean              — det(C₂) > 0
│       ├── CovDet3.lean              — det(C₃) > 0 (polynomial certificates)
│       ├── CovEntries.lean           — Covariance matrix closed-form entries
│       ├── Defs.lean                 — Vasyunin formula definitions
│       ├── GramEntries.lean          — Gram matrix entry properties
│       ├── GramEvaluations.lean      — G(1,1), G(1,2), G(2,2), G(3,3) closed form
│       ├── GramPSD.lean              — det(G₂) > 0, det(G₃) > 0
│       ├── IntegralBridge.lean       — Vasyunin integral axiom + mean entry bridge
│       ├── LinIndep.lean             — Augmented linear independence
│       ├── MeanIntegral.lean         — ∫₀¹ {1/(kx)} dx = (ln k + 1 - γ)/k
│       ├── CrossTermFTC.lean         — Off-diagonal piecewise FTC + Beatty bound
│       ├── PiecewiseFTC.lean         — Diagonal case FTC template
│       ├── DiagonalBridge.lean       — Diagonal Vasyunin bridge
│       ├── StirlingBridge.lean       — Stirling approximation infrastructure
│       ├── SqueezeElimination.lean   — Squeeze theorem for axiom elimination
│       ├── NbDistPos2.lean           — NB distance positivity (N=2)
│       ├── NbDistPos3.lean           — NB distance positivity (N=3)
│       ├── Rayleigh.lean             — Rayleigh quotient theorems
│       ├── Structural.lean           — Hermitian, PSD, invertibility theorems
│       └── Witness.lean              — Log cutoff witness construction
└── Robin/
    ├── BaseCases.lean                — σ(p) ≤ bound for p ∈ {2,3,5,7}
    ├── Defs.lean                     — Robin/Lagarias definitions + 1 axiom
    ├── Equivalence.lean              — 4 cross-path equivalence theorems
    ├── HarmonicBounds.lean           — Harmonic number properties
    ├── PrimeBounds.lean              — lagarias_for_primes (0 axioms)
    └── SigmaProps.lean               — Divisor sum properties
```

## Stats

| Metric | Count |
|---|---|
| Active Lean files | 36 |
| Theorems + Lemmas | 217 |
| Definitions | 42 |
| Axioms | 3 |
| `sorry` | **0** |
| Warnings | **0** |

## The 3 Axioms

1. **`log_cutoff_witness_bound`** (Chain.lean) — The RH itself: Q(v) ≥ c·ln(N)
2. **`vasyunin_eq_integral`** (IntegralBridge.lean) — Vasyunin formula = L² integral (CrossTermFTC attacks this)
3. **`arithmetic_rh_equivalences`** (Robin/Defs.lean) — Lagarias (2002) + Robin (1984) equivalences
