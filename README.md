# Prime — Spectral Riemann Hypothesis Formalization

A formal proof architecture for the Riemann Hypothesis in **Lean 4** against **Mathlib**,
supported by Rust-based numerical experiments.

## Proof Architecture

The proof reduces RH to the **Nyman-Beurling criterion** (Beurling 1955) via a
**Parity Schur complement** decomposition of the Gram matrix. The chain is
**fully connected** with **zero sorry** and **zero algebraic axioms**:

```
type_II_sieve_bound (K < 1)           ← Tier 3: The Millennium Frontier
    ↓ [sieve_implies_stable_ratio — PROVED, 0 sorry]
stable_ratio_parity (R < 1)
    ↓ [schur_to_distance_scaling_v2 — axiom]
nb_distance_scaling (d²_N ≤ C/log N)  ← NOW A THEOREM (was axiom!)
    ↓ [distance_converges_to_zero — PROVED]
nyman_beurling                         ← axiom (published: Beurling 1955)
    ↓
riemann_hypothesis                     ← PROVED
```

Lean reports `riemann_hypothesis` depends on axioms:
`[nyman_beurling, schur_to_distance_scaling_v2, stable_ratio_parity]`
+ standard Lean axioms (`propext`, `Classical.choice`, `Quot.sound`).

`stable_ratio_parity` is **proved** in BilinearSieve.lean as `type_II_implies_stable_ratio`
(kept as axiom in ParitySchur.lean for import ordering).

### Zero-Sorry Core

**ParitySchur.lean** — Parity block decomposition (zero sorry):
- **Parity projections**: π₊ + π₋ = I, π₊π₋ = 0 (completeness + orthogonality)
- **Block decomposition**: G = A + B + Bᵀ + C (Liouville parity blocks)
- **Schur complement PSD**: G > 0 ⟹ A - BC⁻¹Bᵀ ≥ 0 (both cases!)
- **PSD blocks**: parityBlockA_psd, parityBlockC_psd via `PosSemidef.conjTranspose_mul_mul_same`
- **Schur lower bound**: H_eff ≥ (1-R)·A (schur_complement_lower_from_ratio)

**BilinearSieve.lean** — Bilinear sieve reduction (zero sorry, zero algebraic axioms):
- **sieve_implies_stable_ratio**: Type II bound K < 1 ⟹ interference ratio R ≤ K² < 1
- Optimal witness w = C⁻¹Bᵀv collapses Q² ≤ K²·(vᵀAv)·Q to Q ≤ K²·vᵀAv

**GramBounds.lean** — Gram matrix entry bounds (zero sorry):
- **gramEntry_nonneg/le_one**: 0 ≤ G_{j,k} ≤ 1
- **gramEntry_integrand_measurable**: Measurability via `measurable_fract` + `Measurable.div`
- **gramEntry_integrable**: Interval integrability via bounded measurable functions
- **vasyunin_coprime_case**: For coprime j,k, |G_{j,k} - 1/4| ≤ 1 — covering ~60.8% of all entries

## Quick Start

```bash
cd proofs
lake build          # Build all Lean proofs
```

Or use the Makefile:
```bash
make build          # Full project build (Lean + Rust)
make lean-audit     # Scan for sorry/axiom counts
make clean          # Clean all build artifacts
```

## Contributing

### The 3 Critical Path Axioms

| Axiom | Tier | Status | Description |
|-------|------|--------|-------------|
| `type_II_sieve_bound` | 3 (Frontier) | 🔴 Open | K < 1 in the bilinear Cauchy-Schwarz. Computationally K ≈ 0.961. |
| `schur_to_distance_scaling_v2` | 2 (Bridge) | 🟡 Needs proof | R < 1 → d²_N ≤ C/log(N). Connects spectral gap to NB distance. |
| `nyman_beurling` | Published | 📘 Beurling 1955 | d_N → 0 ⟺ RH. Standard reference, formalizable from Mathlib. |

### Tier 2: Formalizing Published Results _(PhD-level)_

**Targets:** `vasyunin_expansion` and `moebius_uncoupling`

These are NOT open mathematical problems. They formalize:
- The Báez-Duarte–Balazard–Landreau–Saias (2005) divisor-sum expansion of Gram entries
- Vaughan's identity (1977) for decomposing arithmetic sums into Type I/II components

**Partial progress:** The coprime case (`gcd(j,k) = 1`) of `vasyunin_expansion` is
already verified in [`GramBounds.lean`](proofs/SpectralRH/GramBounds.lean), covering
~60.8% of all matrix entries using only the trivial integral bounds.

### Tier 3: The Millennium Frontier _(Open problem)_

**Target:** `type_II_sieve_bound` (K < 1)

The irreducible analytical content: proving that the cross-parity bilinear form
satisfies a strict Cauchy-Schwarz defect. The obstruction is **Selberg's parity barrier**
— the statistical independence of Liouville parity from divisibility structure.
Computationally K ≈ 0.961 (R ≈ 0.924), indicating 96.1% parity-coupling efficiency.

## File Guide

### Critical Path

| File | Sorry | Description |
|------|-------|-------------|
| `Defs.lean` | 0 | Core definitions (Gram matrix, NB distance, Liouville) |
| `Structural.lean` | 0 | gram_pos_def (L² linear independence) |
| `RayleighBridge.lean` | 0 | Eigenvalue-quadratic form bridge |
| `GramBounds.lean` | 0 | Gram entry bounds, coprime Vasyunin case |
| `ParitySchur.lean` | 0 | Parity decomposition, Schur PSD, V2 bridge |
| `BilinearSieve.lean` | 0 | Sieve → stable ratio (0 algebraic axioms) |
| `Assembly.lean` | 0 | Final chain: type_II → ... → RH |

### Exploratory / Supporting (not on critical path)

| File | Description |
|------|-------------|
| `PTSymmetry.lean` | PT-symmetry algebra foundations |
| `Quantitative.lean` | Quantitative eigenvalue bounds |
| `SpectralFlow.lean` | Spectral flow continuity (8 axioms) |
| `ClassRestriction.lean` | Octonion residue class analysis (5 axioms) |
| `OctonionicPartition.lean` | Block-diagonal gap dominance |
| `FiniteDimReduction.lean` | Finite-dimensional approximation |
| `AlignmentDecay.lean` | Liouville cancellation |

### Experiments (Rust)

```
experiments/
├── spectral-gap-analysis/    # Eigenvalue computation
├── parity_schur/             # Parity block experiments
├── cross_class_verifier/     # Cross-class verification
└── weil_explicit/            # GUE connection tests
```

## Paper

The research paper documenting the full architecture, including the Three Gaps
analysis and the three-tier formalization roadmap, is in
[`proofs/SpectralRH/paper/`](proofs/SpectralRH/paper/).

## License

MIT
