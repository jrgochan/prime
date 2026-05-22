# MONOTONICITY PATH — Is vᵀG_V v / vᵀG^(1)v Monotonically Decreasing?

## Status: NUMERICAL EVIDENCE STRONG — No Formal Infrastructure Yet

---

## 1. The Observation

From the [bernoulli_vs_vasyunin probe](file:///Users/jrgochan/code/github.com/jrgochan/prime/experiments/overcancellation-scan/src/bin/bernoulli_vs_vasyunin.rs), the ratio of the two quadratic forms at the BD Möbius witness vector is **monotonically decreasing**:

| N | vᵀG_V v | vᵀG^(1)v | ratio = G_V / G^(1) |
|---|---------|----------|---------------------|
| 10 | 0.136 | 0.116 | **1.172** |
| 20 | 0.247 | 0.229 | **1.079** |
| 50 | 0.373 | 0.395 | **0.943** |
| 100 | 0.444 | 0.500 | **0.887** |
| 200 | 0.505 | 0.678 | **0.745** |
| 500 | 0.567 | 0.940 | **0.603** |

The ratio crosses 1 around N ≈ 40 and then decreases monotonically.

If the ratio → 0, then vᵀG_V v = o(vᵀG^(1)v) = o(log N), which would give overcancellation.

---

## 2. What Would a Monotonicity Proof Look Like?

### The Ratio

Define:
```
ρ(N) = vᵀG_V v / vᵀG^(1)v
```

where v = v_N is the BD Möbius witness at truncation N.

A monotonicity proof would show: **ρ(N+1) ≤ ρ(N)** for all N ≥ N₀.

### The Obstacle

The BD witness vector v_N changes with N (both dimension and entries change), so this is NOT a simple matrix monotonicity statement. We'd need:

1. **Rank-1 update analysis**: Going from N to N+1 adds one row/column to the Gram matrix and extends the witness vector. The change in vᵀGv involves the new entry G(N+1, ·) and the new witness entry v(N+1).

2. **Interlacing**: If G^(1) is the Bernoulli-1 Gram and G_V is Vasyunin, do their eigenvalues interlace in a way that makes the ratio decreasing?

### Simpler Sub-Questions

Before attacking the full ratio monotonicity, we could ask:

1. **Is vᵀG_V v bounded?** (Equivalent to RH.)
2. **Is vᵀG_V v increasing?** (If yes and bounded, convergence follows.)
3. **Is the correction vᵀΔv monotonically decreasing?** (Where Δ = G_V - G^(1).)

---

## 3. Existing Infrastructure

### What We Have

| Resource | Where | Relevance |
|----------|-------|-----------|
| Diagonal monotonicity: D(N) increasing | [DiagonalBound.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/DiagonalBound.lean#L305) | D(N) ≥ G(1,1) PROVED |
| D(N) = O(log N) | [DiagonalBound.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/DiagonalBound.lean#L271) | PROVED |
| Phase transition data | [PhaseTransition.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/PhaseTransition.lean) | Excess decomposition |
| Inhomogeneous Ward | [InhomogeneousWard.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/InhomogeneousWard.lean#L36) | Empirical ε/logN table |

### What We Don't Have

- No formal theory of rank-1 updates for the Vasyunin Gram matrix
- No interlacing results for G_V eigenvalues as N increases
- No proof that vᵀG_V v is even monotone (let alone the ratio)

---

## 4. Numerical Experiments Needed

### Experiment A: Fine-grained ratio at consecutive N

```
For N = 10, 11, 12, ..., 500:
  Compute ρ(N) = vᵀG_V v / vᵀG^(1)v
  Check: is ρ(N+1) < ρ(N) for all N ≥ 40?
```

If YES: strong evidence for monotonicity.
If NO: the ratio oscillates, and we need a different approach.

### Experiment B: Component-wise analysis

```
For each N, decompose:
  ρ(N) = 1 + vᵀΔv / vᵀG^(1)v

Track: vᵀΔv and vᵀG^(1)v separately.
Question: Does vᵀΔv / vᵀG^(1)v decrease monotonically?
```

### Experiment C: Eigenvalue tracking

```
For N = 10, 20, ..., 200:
  Compute eigenvalues of G_V(N) and G^(1)(N)
  Track: λ_max(G_V) / λ_max(G^(1))
  Question: Do the spectral ratios decrease?
```

---

## 5. Theoretical Approaches

### Approach A: Direct Computation via Abel Summation

The quadratic form vᵀG_V v = Σ_{j,k} G_V(j,k) · μ(j)w(j) · μ(k)w(k) / (jk) can be analyzed via double Abel summation on the Möbius function. This is the technique used in the PNT-related graduation proofs.

The key: can the **difference** vᵀΔv be expressed as a single Abel transform?

### Approach B: Spectral Monotonicity

If G_V has eigenvalues that decrease faster than G^(1) as N grows, the ratio would be decreasing. This connects to the GOE universality results from the [spectral certification](file:///Users/jrgochan/.gemini/antigravity-ide/knowledge/cathedral_spectral_certification/artifacts/spectral_universality_goe.md).

### Approach C: Subadditivity

If vᵀG_V v has a subadditivity property (the form at N+M ≤ form at N + form at M for appropriate witness vectors), then monotonicity of the ratio might follow from the superadditivity of vᵀG^(1)v.

---

## 6. Assessment

| Aspect | Rating |
|--------|--------|
| Numerical evidence | ⭐⭐⭐⭐⭐ (clean monotone decrease) |
| Theoretical basis | ⭐⭐ (no framework yet) |
| Implementation difficulty | ⭐⭐⭐⭐ (rank-1 updates for Vasyunin are hard) |
| Connection to existing proofs | ⭐⭐⭐ (DiagonalBound, PhaseTransition) |
| Potential payoff | ⭐⭐⭐ (would give vᵀG_V v = o(logN), but not ≤ 1) |

> **Verdict**: Monotonicity is a beautiful structural observation but proving it formally seems harder than proving the bound directly. The ratio decreasing to 0 would give overcancellation, but the intermediate step of proving monotonicity may not be easier than the end goal. Best used as a **guiding principle** for other approaches.

> **Recommendation**: Run Experiment A (fine-grained ratio) to confirm monotonicity, then use the structural insight to guide the Vasyunin reciprocity or diagonal shift approaches.
