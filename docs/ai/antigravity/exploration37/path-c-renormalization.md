# Path C: Renormalization — The Selberg-Delange α-Decay

## Status: ANALYZED (Not yet implemented in Lean)

## Overview

Path C approaches the Crown Axiom through the **Selberg-Delange method**:
a renormalization group technique that controls Dirichlet series coefficients
through their generating function behavior near s=1.

The core idea: instead of bounding v^T G v directly, show that the
Dirichlet series associated with the Gram quadratic form has a
**tauberian decay** controlled by the order of the pole of ζ(s) at s=1.

## The Mathematical Framework

### The Selberg-Delange Method

For a Dirichlet series F(s) = Σ a(n)/n^s with the property that
F(s) = ζ(s)^α · H(s) where H is holomorphic and nonvanishing near s=1:

```
Σ_{n≤x} a(n) = x · P(log x) / Γ(α) + O(x^{1-δ})
```

where P is a polynomial of degree α-1 (or α-1 < 0 gives decay).

### Application to the Gram Form

The Gram quadratic form v^T G v involves sums of the form:

```
Σ_{j,k ≤ N} μ(j)μ(k) · f(j,k) · G(j,k)
```

where f encodes the taper. The key: the generating Dirichlet series of
this double sum factors through ζ(s)^{-2} (from the two Möbius functions).

Since 1/ζ(s)² is entire (has no pole at s=1), the Selberg-Delange method
gives **power-saving decay** of the partial sums.

### The α Parameter

| Object | Dirichlet Series | α | Decay Rate |
|--------|-----------------|---|------------|
| Möbius sum Σ μ(n)/n^s | 1/ζ(s) | α = -1 | O(1/log N) by PNT |
| Double Möbius Σ μ(j)μ(k)/... | 1/ζ(s)² | α = -2 | O(1/log² N) potential |
| Tapered double sum | 1/ζ(s)² · (log factor) | α = -1 | O(1/log N) confirmed |

The taper (1 - log k/log N) introduces a log factor that shifts α from -2
to -1, exactly matching the Crown Axiom requirement of O(1/log N) decay.

## Connection to Path B (GCD Strata)

The Selberg-Delange approach and the GCD strata approach attack the same
quantity from different angles:

```
Path B: v^T G v = Σ_d R_d + Σ_d Δ_d
                  (arithmetic)  (analytic)

Path C: v^T G v ← controlled by 1/ζ(s)² near s=1
                  (complex analysis)
```

**The bridge**: The GCD strata decomposition of R(j,k) = gcd²/(12jk)
corresponds to the **Euler product factorization** of 1/ζ(s)²:

```
1/ζ(s)² = Π_p (1 - p^{-s})² = Σ_n μ²(n) · (d(n)/n^s) correction
```

The d-independence of the Ramanujan kernel (Path B's key result) is the
**arithmetic shadow** of the holomorphy of 1/ζ(s)² at s=1 (Path C's
starting point).

## What's Needed from the Cathedral

### Existing Infrastructure

1. **EulerProductLimit.lean**: Euler product convergence for ζ(s)
2. **Zeta2ProductBound.lean**: Bounds on 1/ζ(2) = 6/π²
3. **MertensThird.lean**: ln(N)·Π(1-1/p) → e^{-γ} (Mertens' third theorem)
4. **BDMellin.lean**: Mellin transform connection to L²(0,1)
5. **MertensBound.lean**: Quantitative Mertens bounds

### Missing Pieces

1. **Selberg-Delange tauberian theorem**: Not in Mathlib or PNTAnd yet.
   This is a significant formalization effort (comparable to PNT itself).

2. **Connection to the Gram form**: Need to express v^T G v as a
   double Dirichlet series and identify the generating function.

3. **The α-shift from taper**: Need to show that the log-cutoff taper
   shifts α from -2 to -1, matching the Crown bound.

## Difficulty Assessment

| Component | Difficulty | Notes |
|-----------|-----------|-------|
| Selberg-Delange in Lean | ⭐⭐⭐⭐⭐ | Major formalization project |
| Euler product → GCD strata | ⭐⭐⭐ | Partially done (EulerProduct.lean) |
| Taper α-shift | ⭐⭐ | Algebraic, uses Abel summation |
| Connection to Crown | ⭐⭐⭐ | Requires Mellin bridge |

## Verdict

Path C is **mathematically elegant** but **formalization-heavy**. The
Selberg-Delange theorem is not yet in any Lean library, making this a
multi-month project.

However, Path C has a key **theoretical advantage**: it would give
**power-saving** bounds (O(1/log² N) rather than O(1/log N)) if the
α = -2 could be maintained without the taper correction. This is
related to the **Vinogradov-Korobov** zero-free region, which gives
better-than-PNT decay.

### Synergy with Path B

The GCD strata results from tonight provide **unconditional arithmetic
infrastructure** that Path C can use:

- The universal kernel 1/(12ab) factorizes the Dirichlet series
- The non-squarefree vanishing eliminates non-multiplicative terms
- The anomaly localization isolates the "hard" analytic part

**If Path C could be formalized, combined with Path B's arithmetic,
the Crown Axiom would reduce to a known analytic number theory result.**

## Key References

- Selberg, A. "Note on a paper by L. G. Sathe" (1954)
- Delange, H. "Sur des formules de Atle Selberg" (1971)
- Tenenbaum, G. "Introduction to Analytic and Probabilistic Number Theory" Ch. II.5
- Iwaniec & Kowalski, "Analytic Number Theory" Ch. 5.5
