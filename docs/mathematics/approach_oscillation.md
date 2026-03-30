# Approach 1: Oscillation Orthogonality

## Overview

**Goal**: Prove λ_min(G_N) ≥ 1/(C·N^α) for some constants C, α.

**Difficulty**: ⭐⭐⭐ (moderate — concrete Fourier-analytic argument)

**Key insight**: On short intervals near x = 0, the functions {k/x} oscillate
rapidly with "frequency" proportional to k. Different k yield nearly
orthogonal oscillations, giving a guaranteed energy lower bound.

## The Argument

### Step 1: Localize to (0, 1/N)

For any unit vector v ∈ ℝ^{N-1}, define f(x) = Σ_{k=2}^N v_k · {k/x}.

Since the integral over (0,1) is ≥ the integral over any sub-interval:

```
vᵀ G_N v = ∫₀¹ f(x)² dx ≥ ∫₀^{1/N} f(x)² dx
```

### Step 2: Periodicity structure on (0, 1/N)

For x ∈ (0, 1/N) and k ≤ N, we have k/x > N, so {k/x} completes
many oscillation periods. On each interval (k/(m+1), k/m):

```
{k/x} = k/x - m     (linear in 1/x, slope = k)
```

The number of complete periods of {k/x} on (0, 1/N) is approximately k·N.

### Step 3: Approximate orthogonality

**Claim**: For j ≠ k with j,k ≤ N:

```
∫₀^{1/N} {j/x}·{k/x} dx ≈ (1/12N) · δ_{jk} + O(1/N²)
```

**Why**: On a single period of {k/x}, the average of {k/x} is 1/2 and the
average of {k/x}² is 1/3 (variance = 1/12). When j ≠ k, the oscillations
of {j/x} and {k/x} are "incommensurate" and the cross-correlation averages
to approximately 1/4 (product of means), not 1/3.

More precisely, the Fourier expansion of {y} is:
```
{y} = 1/2 - (1/π) Σ_{n=1}^∞ sin(2πny) / n
```

So {k/x} has Fourier-like oscillations with "frequencies" 2πk/x, and
cross-correlations between different k cancel by Riemann-Lebesgue.

### Step 4: Lower bound

Combining Steps 1-3:

```
∫₀^{1/N} f(x)² dx ≥ (1/12N) · Σ v_k² - O(N/N²)
                    = 1/(12N) - O(1/N)
                    ≥ c/N for large N
```

This gives: **λ_min(G_N) ≥ c/N** for some c > 0.

## What We'd Need to Formalize

### Lemma 1: Energy in one period
For k ≥ 2 and integer m ≥ k:
```
∫_{k/(m+1)}^{k/m} {k/x}² dx = 1/(6m(m+1)) + O(1/m³)
```

### Lemma 2: Cross-correlation cancellation
For distinct j, k ≥ 2:
```
|∫₀^{1/N} ({j/x} - 1/2)·({k/x} - 1/2) dx| ≤ C · log(N) / (N · |j-k|)
```

### Lemma 3: Summed cross-correlation bound
```
Σ_{j≠k} |∫₀^{1/N} ({j/x}-1/2)({k/x}-1/2) dx| ≤ C · log²(N) / N
```

### Theorem: λ_min ≥ c/N
Combining the self-energy 1/(12N) with the cross-correlation bound
C·log²(N)/N, for N large enough:
```
λ_min(G_N) ≥ 1/(12N) - C·log²(N)/N ≥ c/N
```

## Computational Verification Plan

1. Compute the cross-correlations ∫₀^{1/N} ({j/x}-1/2)({k/x}-1/2) dx
   for small N and verify they're O(log N / (N·|j-k|))
2. Verify that the self-energy terms ∫₀^{1/N} {k/x}² dx ≈ 1/(12N)
3. Check that the c/N bound is consistent with our observed λ_min ~ N^{-0.12}

## Limitations

This approach gives λ_min ≥ c/N, which is WEAKER than the observed
λ_min ~ N^{-0.12}. But it's a **provable starting point**. Improving the
bound from c/N to c/N^{0.12} requires the Ramanujan approach (Approach 2).

Also note: c/N is sufficient for d_N → 0 (and hence RH), because
d_N² ≤ C/N · (something from the RHS vector). The full connection
needs the convergence proof in `gram_bound_implies_convergence`.
