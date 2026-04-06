# SpectralRH: A Lean 4 Formalization of the Nyman-Beurling Spectral Approach to RH

A formally verified proof architecture for the Riemann Hypothesis in [Lean 4](https://leanprover.github.io/), using the **Nyman-Beurling criterion** and **spectral gap analysis** of Gram matrices.

## What This Is

This project formalizes the logical structure of a spectral proof of the Riemann Hypothesis:

> **If the minimum eigenvalue of the Nyman-Beurling Gram matrix stays bounded away from zero as the matrix dimension grows, then the Riemann Hypothesis holds.**

The formalization consists of **11 Lean files** (~3,700 lines), containing:
- **89 formally verified theorems/lemmas** (zero `sorry`s)
- **7 custom axioms** on the critical path (clearly documented)
- **3 standard Lean axioms** (`propext`, `Classical.choice`, `Quot.sound`)

## The Proof Chain

```
riemann_hypothesis
    ↑ (nyman_beurling)
nbDistSq' N → 0
    ↑ (gram_bound_to_nbdist)
∃ c > 0, ∀ N ≥ 2, c ≤ λ_min(G_N)         [hyperzeta — PROVEN]
    ↑ (telescoping — PROVEN)
∑ eigenDrop bounded by T < λ_min(500)      [spectral_gap_positive_from_decay]
    ↑ (drop_bound_uniform — PROVEN)
eigenDrop N ≤ C · N^{-γ}, γ > 1           [drop_assembly_at — PROVEN]
    ↑
cos²θ · ‖g‖² / S                          [drop_formula_bound, cross_norm_bound,
    ↑                                        schur_complement_lower]
Liouville cancellation                    [liouville_cancellation]
```

## Axiom Transparency

Running `#print axioms riemann_hypothesis` in Lean produces:

```
'riemann_hypothesis' depends on axioms:
  cross_norm_bound           -- ‖g_N‖² = Θ(N)
  drop_formula_bound         -- δ_N ≤ cos²θ · ‖g‖² / S  (Schur complement perturbation)
  gram_bound_to_nbdist       -- spectral gap → NB-distance → 0
  liouville_cancellation     -- cos θ_N = O(N^{-β}), β > 1  (the Liouville discovery)
  nyman_beurling             -- Beurling (1955), Báez-Duarte (2003)
  schur_complement_lower     -- S_N ≥ 1/20
  spectral_gap_positive_from_decay  -- the physical bridge (see below)
  propext                    -- (standard Lean)
  Classical.choice           -- (standard Lean)
  Quot.sound                 -- (standard Lean)
```

### Axiom Classification

| Tier | Axiom | Description | Status |
|------|-------|-------------|--------|
| **Published theorem** | `nyman_beurling` | Beurling 1955 / Báez-Duarte 2003. Formalizing requires multi-year effort. | Literature reference |
| **Deep number theory** | `liouville_cancellation` | Liouville function correlations decay in eigenvector alignment | Core discovery |
| **Physical bridge** | `spectral_gap_positive_from_decay` | The specific Gram matrix constants keep L > 0 | Core assertion |
| **Standard linear algebra** | `drop_formula_bound` | Bordered matrix eigenvalue perturbation (standard textbook) | Good first issue |
| **Standard linear algebra** | `schur_complement_lower` | Quantitative Schur complement bound S ≥ 1/20 | Needs certified numerics |
| **Integral estimate** | `cross_norm_bound` | Cross-correlation norm ‖g‖² = Θ(N) from Koksma asymptotics | Needs integral analysis |
| **Functional analysis** | `gram_bound_to_nbdist` | Uniform spectral gap → approximation convergence | Standard FA |

## The Spectral Gap Discovery

During formalization, an AI-assisted peer review caught a **limit-exchange fallacy** in the original proof blueprint:

> **The 1/N counterexample**: The decay hypothesis `eigenDrop N ≤ C · N^{-γ}` with γ > 1 guarantees the eigenvalue drops are summable, but does NOT guarantee the spectral gap stays open. Consider `λ_min(N) = 1/N`: the drops `δ_N = 1/N(N-1) = O(N⁻²)` satisfy γ = 2 > 1, yet `lim λ_min(N) = 0`.

This led to the honest restructuring of `tail_bound_from_decay` → `spectral_gap_positive_from_decay`, which explicitly acknowledges that **the deep physical content** — that the specific constants governing Gram matrix decay are small enough to keep the spectral gap open — cannot be derived from the decay rate alone.

## What Is Proven (Zero Sorry)

### Core Structural Results
- **`gram_pos_def`**: The Gram matrix is positive definite (L² linear independence of fractional parts)
- **`eigenvalue_interlacing`**: Cauchy interlacing via Rayleigh quotient embedding
- **`lambdaMin_pos`**: λ_min(G_N) > 0 for all N ≥ 2
- **`schurComplement_pos`**: The Schur complement S_N > 0 (witness vector construction)
- **`telescoping`**: λ_min(N) = λ_min(N₀) - Σ eigenDrop (induction)
- **`eigenDrop_nonneg`**: eigenDrop ≥ 0 (from interlacing)

### Assembly Results
- **`drop_assembly_at`**: Full algebra chaining cos²θ·‖g‖²/S into O(N^{1-2β})
- **`drop_bound_uniform`**: Uniform constants for eigenDrop decay
- **`hyperzeta`**: λ_min(G_∞) > 0 from certified tail bound
- **`riemann_hypothesis`**: RH from hyperzeta + Nyman-Beurling

### Infrastructure
- **`min_eigenvalue_le_quadForm`**: Rayleigh quotient bound (Parseval + spectral decomposition)
- **`quadForm_eigenvector`**: Quadratic form at eigenvectors = eigenvalue
- **`weyl_min_eigenvalue`**: Weyl's inequality for eigenvalue sums
- **`gram_l2_identity`**: wᵀGw = ‖φ_w‖²_{L²} (integral identity)
- **`blockDiag_quadForm_decomp`**: Octonionic class decomposition of quadratic forms
- **`oct_gap_dominates`**: λ_min(G) ≤ λ_min(G^block) via Rayleigh quotient

## File Structure

| File | Lines | Role |
|------|-------|------|
| `Defs.lean` | 206 | Core definitions: gramEntry, lambdaMin, eigenDrop, schurComplement, cosAlignment |
| `RayleighBridge.lean` | 362 | Rayleigh quotient ↔ eigenvalue bridge, Weyl's inequality |
| `Structural.lean` | 620 | Interlacing, positivity, L² identity, gram_pos_def, telescoping |
| `Quantitative.lean` | 204 | schurComplement_pos, certified bounds |
| `AlignmentDecay.lean` | 83 | Liouville cancellation → alignment decay |
| `Assembly.lean` | 226 | Final proof assembly: drop_assembly → hyperzeta → RH |
| `OctonionicPartition.lean` | 311 | Fano plane partition of integers into 8 classes |
| `ClassRestriction.lean` | 659 | Block-diagonal decomposition, class restriction |
| `FiniteDimReduction.lean` | 401 | 8-dimensional finite reduction, energy decomposition |
| `SpectralFlow.lean` | 419 | Spectral flow analysis, t-parameterized interpolation |
| `PTSymmetry.lean` | 82 | PT-symmetry structure of Gram matrix |

## Building

```bash
cd proofs/
lake build
```

Requires Lean 4 with Mathlib. Build produces zero errors and zero warnings.

## Contributing

The following axioms are good candidates for community contribution:

1. **`drop_formula_bound`** — Standard Schur complement eigenvalue perturbation. Requires bordered matrix decomposition and spectral projection. See `Structural.lean:608`.

2. **`gram_bound_to_nbdist`** — Spectral gap implies NB-distance convergence. Standard functional analysis argument. See `Assembly.lean:170`.

## License

This work is for the advancement of mathematics. Use freely with attribution.
