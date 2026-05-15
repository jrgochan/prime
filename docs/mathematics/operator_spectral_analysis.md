# Operator-Theoretic Spectral Gap Analysis

## Summary

We investigated whether the Nyman-Beurling Gram matrix spectral gap can be
established via operator-theoretic decomposition, bypassing the need for
infinite computation.

**Result: The simple mean-field decomposition fails, but yields important
structural insights about WHY the spectral gap exists.**

## The Decomposition

The Gram matrix G_N has entries G[j,k] = ∫₀¹ {j/x}{k/x} dx.

Since E[{k/x}] = ∫₀¹ {k/x} dx = 1/2, the "mean-field" product is
(1/2)(1/2) = 1/4. So we decompose:

```
G = (1/4)·𝟙𝟙ᵀ + E
```

where E[j,k] = G[j,k] - 1/4 captures arithmetic correlations.

## Numerical Results (N = 2..500)

### Entry Structure

| k | G[k,k] | E[k,k] | Asymptotic |
|---|--------|--------|------------|
| 2 | 0.2939 | 0.0439 | → 1/3 |
| 10 | 0.3250 | 0.0750 | → 1/3 |
| 100 | 0.3324 | 0.0824 | → 1/3 |
| 500 | 0.3330 | 0.0830 | → 1/3 |

Note: G[k,k] → 1/3 (not 1/2), because ∫₀¹ {k/x}² dx → 1/3 for large k
(the variance of a uniform random variable on [0,1] is 1/12, so
E[X²] = Var + (EX)² = 1/12 + 1/4 = 1/3).

### Gershgorin Analysis of E

**Result: 0/499 rows satisfy diagonal dominance.**

| k | E[k,k] | Σ\|E[k,j]\| | Ratio |
|---|--------|-------------|-------|
| 2 | 0.044 | 9.82 | 224× |
| 50 | 0.081 | 0.84 | 10× |
| 500 | 0.083 | 0.42 | 5× |

The ratio decreases with k but never drops below 1.

### Spectrum Comparison: G vs E

| N | λ_min(G_N) | λ_min(E_N) | E positive? |
|---|-----------|-----------|:-----------:|
| 10 | +0.032 | +0.003 | ✅ |
| 20 | +0.023 | **-0.043** | ❌ |
| 100 | +0.016 | -0.241 | ❌ |
| 500 | +0.012 | **-0.706** | ❌ |

**E has exactly 1 negative eigenvalue** for N ≥ 20 — along the "all-ones"
direction. All other eigenvalues of E are positive.

### E₅₀₀ Eigenvalue Structure

```
λ₁(E) = -0.706    ← the all-ones direction (NEGATIVE)
λ₂(E) = +0.013    ← matches λ_min(G) ≈ 0.012!
λ₃(E) = +0.015
...
λ₄₉₉(E) = +0.653
```

## Key Insight: Two Protection Mechanisms

The spectral gap of G comes from TWO different mechanisms:

1. **All-ones direction** (eigenvalue ≈ N/4):
   Protected by the large mean-field contribution (1/4)·𝟙𝟙ᵀ.
   The rank-1 term lifts E's single negative eigenvalue to strongly positive.

2. **Liouville direction** (eigenvalue ≈ 0.012):
   Protected by arithmetic cancellation in the Liouville function.
   This eigenvalue is the same whether computed from G or from E.

## Why This Approach Fails

The decomposition G = (1/4)·𝟙𝟙ᵀ + E fails because:

- Weyl's inequality gives λ_min(G) ≥ λ_min(E) + λ_min((1/4)·𝟙𝟙ᵀ)
  = λ_min(E) + 0 = λ_min(E) < 0. Useless!

- The rank-1 term has λ_min = 0 (it's rank 1), so it can't lift E's
  negative eigenvalue through Weyl.

- The correct bound is: the all-ones direction in G has eigenvalue
  ≈ N/4 + (-0.7) > 0, which works — but only because N is large.
  For the Liouville direction, no rank-1 help is available.

## Conclusion

The spectral gap on the Liouville subspace (the subspace ⊥ to 𝟙) is
controlled by arithmetic correlations of the Liouville function λ(k).
Proving this gap is positive is equivalent to bounding L(x) = Σ_{k≤x} λ(k),
which is equivalent to the Riemann Hypothesis.

**No simple operator inequality can bypass this arithmetic content.**

## Experimental Setup

- Computation: `experiments/weil_explicit/src/operator_spectral.rs`
- Integration: 500,000-point midpoint rule
- Matrix sizes: up to 499×499 (N=500)
- Runtime: 7 seconds
