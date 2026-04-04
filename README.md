# Prime — Spectral Riemann Hypothesis Formalization

A formal proof architecture for the Riemann Hypothesis in **Lean 4** against **Mathlib**,
reducing RH to **two domain axioms** in a compiler-verified chain.

## The Honest Assessment

> *This formalization doesn't simplify RH — it isolates the hard content*
> *into two irreducible mathematical claims, and makes everything else*
> *compiler-verified.*

This project has **reduced the Riemann Hypothesis to two domain axioms** in a
fully connected, compiler-verified Lean 4 chain (3,433 build jobs, 0 errors).
All algebraic infrastructure, the functional equation bridge, the NB
criterion decomposition, and the critical strip localization are
**proved with zero sorry**.

## Axiom Audit

```
'riemann_hypothesis' depends on axioms:
  [moebius_test_bound,
   zeta_zero_separates,
   propext, Classical.choice, Quot.sound]
```

Only **two domain axioms**. The remaining three (`propext`, `Classical.choice`,
`Quot.sound`) are Lean's foundational axioms — present in every Lean 4 program.

## Proof Architecture

```
riemann_hypothesis                       ← PROVED THEOREM
├── nyman_beurling                       ← PROVED (decomposed into forward + converse)
│   ├── nyman_beurling_forward           ← PROVED (existential witness extraction)
│   └── nyman_beurling_converse          ← PROVED (contrapositive via separating functional)
│       ├── rh_neg_gives_critical_strip_zero  ← PROVED THEOREM
│       │   ├── zeta_nontrivial_zero_re_pos   ← PROVED (functional equation!)
│       │   │   ├── zeta_neg_odd_ne_zero      ← PROVED (Selberg-style factor chain)
│       │   │   │   └── cos_pi_mul_succ       ← PROVED (trig induction)
│       │   │   ├── riemannZeta_zero          ← MATHLIB (ζ(0) = -1/2)
│       │   │   ├── riemannZeta_one_sub       ← MATHLIB (functional equation)
│       │   │   └── riemannZeta_ne_zero_of_one_le_re ← MATHLIB
│       │   └── riemannZeta_ne_zero_of_one_le_re ← MATHLIB
│       └── zeta_zero_separates          ← AXIOM ⭐ (Mellin separation)
├── nb_distance_scaling                  ← PROVED (d²_N ≤ C/log N)
│   ├── moebius_test_bound               ← AXIOM ⭐ (test vector existence)
│   ├── l2_error_eq_quad_error           ← PROVED (L² ↔ Matrix Bridge)
│   └── nbDistSq_le_test_vector          ← PROVED (variational bound, PSD)
└── distance_converges_to_zero           ← PROVED (log divergence)
```

## The Two Remaining Axioms

### 1. `moebius_test_bound` — Test Vector Existence

```lean
axiom moebius_test_bound :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N → ∃ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≤ C / Real.log (N : ℝ)
```

*"There exists a test vector achieving L² approximation error ≤ C/log(N)."*

This is equivalent to the Nyman-Beurling distance estimate d²_N = O(1/log N).
It is the quantitative content of RH. Proof strategies include:
- **Selberg sieve weights** with k≥1 basis (requires refactoring `nbLinComb`)
- **Báez-Duarte (2003)** coefficients using 1/ζ(s)
- **Optimal test vector** v* = G⁻¹b (requires PNT-level estimates)

### 2. `zeta_zero_separates` — Mellin Separation

```lean
axiom zeta_zero_separates :
    ∀ ρ : ℂ, riemannZeta ρ = 0 →
    0 < ρ.re → ρ.re < 1 → ρ.re ≠ 1/2 →
    ∃ δ : ℝ, 0 < δ ∧
    ∀ N : ℕ, 2 ≤ N → ∀ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≥ δ
```

*"If ζ has a zero off the critical line, approximation is blocked."*

This uses the Mellin transform identity: when ζ(ρ) = 0, the functional
x^{ρ-1} annihilates every {k/x} but not 1_{(0,1)}, creating an L²
obstruction with defect δ > 0. Proof ingredients:
- `mellin_fractBasis` (Mellin of {k/x}, in MellinBridge.lean)
- Continuity of ℓ_ρ on L²(0,1)
- Residue calculus / contour integration

## What's Proved (Theorems from Mathlib)

The following were **axioms** in earlier versions and are now **proved theorems**:

| Theorem | Method | Mathlib Ingredients |
|---------|--------|-------------------|
| `nyman_beurling` | Decomposition | Forward + converse |
| `nyman_beurling_converse` | Contrapositive | `zeta_zero_separates` |
| `rh_neg_gives_critical_strip_zero` | Case analysis + push_neg | `riemannZeta_ne_zero_of_one_le_re` |
| `zeta_nontrivial_zero_re_pos` | **Functional equation** | `riemannZeta_one_sub`, `riemannZeta_zero`, nonvanishing |
| `zeta_neg_odd_ne_zero` | **Factor chain** | Γ, cpow, cos, ζ nonvanishing |
| `cos_int_mul_pi_ne_zero` | Trig induction | `Complex.cos_pi`, `Complex.cos_add_pi` |
| `cos_pi_mul_succ` | Base + induction | cos(π) = -1 |

## Quick Start

```bash
cd proofs
lake build          # Build all Lean proofs (~3,433 jobs)
```

Verify the axiom set:
```bash
echo 'import SpectralRH.Assembly
#print axioms riemann_hypothesis' | lake env lean --stdin
```

Or use the Makefile:
```bash
make build          # Full project build (Lean + Rust)
make lean-audit     # Scan for sorry/axiom counts
make clean          # Clean all build artifacts
```

## File Guide

### Critical Path

| File | Sorry | Description |
|------|-------|-------------|
| `Defs.lean` | 0 | Core definitions (Gram matrix, NB distance, Liouville) |
| `Structural.lean` | 0 | Gram PSD, eigenvalue interlacing, fractional part lemmas |
| `RayleighBridge.lean` | 0 | Eigenvalue-quadratic form bridge (both directions) |
| `GramBounds.lean` | 0 | Gram entry bounds, coprime Vasyunin case |
| `ParitySchur.lean` | 0 | Parity decomposition, Schur PSD |
| `BilinearSieve.lean` | 0 | Sieve → stable ratio |
| `ParityBridge.lean` | 0 | Parity Bridge: sieve + block scaling → full scaling |
| `MellinBridge.lean` | 0 | Mellin infrastructure, functional equation proofs |
| `Assembly.lean` | 0 | Final chain: axioms → RH |

### Exploratory / Supporting

| File | Description |
|------|-------------|
| `SelbergSieve.lean` | Selberg sieve exploration (k=1 gap documented) |
| `Quantitative.lean` | Schur complement positivity proof |
| `SpectralFlow.lean` | Spectral flow analysis |
| `FiniteDimReduction.lean` | Finite-dimensional reduction |

## Two Pillars Architecture

**Pillar 1: Discrete Linear Algebra (PROVED — zero sorry)**
- Gram matrix theory: Hermitianness, PSD, eigenvalue bounds
- Parity decomposition: Liouville blocks A, B, C
- Schur complement: A - BC⁻¹Bᵀ ≥ 0
- Variational principle: d²_N ≤ any test vector
- L² ↔ Matrix bridge: ∫(1-f)² = 1 - 2bᵀv + vᵀGv

**Pillar 2: Analytic Number Theory (2 axioms remaining)**
- Test vector existence (`moebius_test_bound`): Möbius weights + PNT
- Mellin separation (`zeta_zero_separates`): separating functional

**Functional Equation Bridge (PROVED from Mathlib)**
- ζ functional equation: `riemannZeta_one_sub`
- Critical strip localization: `zeta_nontrivial_zero_re_pos`
- Negative odd nonvanishing: `zeta_neg_odd_ne_zero`
- Trig identity: cos(πn) = (-1)^n

## Roadmap

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | L²↔Matrix Bridge | ✅ PROVED |
| 2 | Mellin transform infrastructure | ✅ PROVED |
| 3 | Functional equation bridge | ✅ PROVED (from Mathlib) |
| 4 | Nyman-Beurling decomposition | ✅ PROVED |
| 5 | Critical strip localization | ✅ PROVED (from Mathlib) |
| 6 | Test vector existence | 🟡 `moebius_test_bound` axiom |
| 7 | Mellin separation | 🟡 `zeta_zero_separates` axiom |

### Next Steps

1. **Refactor basis to k≥1**: Include {1/x} in the NB basis, enabling
   the Selberg sieve to close `moebius_test_bound`.
2. **Formalize `zeta_zero_separates`**: Target for a community bounty.
   Requires complex analysis (Mellin transform + residue calculus).

## Paper

The research paper is in [`proofs/SpectralRH/paper/`](proofs/SpectralRH/paper/).

## License

MIT
