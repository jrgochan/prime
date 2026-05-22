# The Euler Convergence: What the Data Actually Says

**Date**: May 20, 2026  
**Source**: Rust XRay (`error-xray`) with Rayon parallelization, N=10 to 8,000  
**Status**: The e hypothesis is **busted**, but something deeper emerged.

---

## The Question

Does `(1 - vᵀGv) · ln(N) → e` as N → ∞?

Where v are Möbius-Fejér weights `v_k = -μ(k)·(1 - ln k/ln N)` and
G is the Vasyunin Gram matrix.

## The Data

| N | vᵀGv | (1-Gv)·lnN | gap from e |
|---:|-----:|----------:|---------:|
| 100 | 0.4439 | 2.561 | −0.157 |
| 200 | 0.5053 | 2.621 | −0.097 |
| 500 | 0.5666 | 2.693 | −0.025 |
| **750** | **0.5891** | **2.720** | **+0.002** |
| 1000 | 0.6028 | 2.744 | +0.025 |
| 2000 | 0.6355 | 2.770 | +0.052 |
| 5000 | 0.6702 | 2.809 | +0.090 |
| 8000 | 0.6859 | 2.823 | +0.105 |

## Key Findings

### 1. The e hypothesis is FALSE ❌

The quantity (1-Gv)·lnN crosses e ≈ 2.71828 at N ≈ 750 and **keeps growing**.
At N=8000, it's 2.823, which is 3.85% above e and still rising.

### 2. The true limit may be 1 + ln(2π) ≈ 2.8379 ✨

Aitken extrapolation from the last 3 data points gives L ≈ 2.833,
which is within 0.15% of `1 + ln(2π) = 2.8379`.

The gap from this constant at N=8000 is only 0.0149 (0.53%), vs
the gap from e of 0.1047 (3.85%). This is a **7× better fit**.

Why 1 + ln(2π)? The Gram matrix diagonal is `G(k,k) = (ln2π − γ)/k − 1/k²`.
The constant ln(2π) is baked into every diagonal entry. A limit of 1 + ln(2π)
would mean the convergence rate is governed by the same constant that sets
the scale of the Gram matrix.

### 3. The d² distance decays as C/ln²N

| N | d² | d²·ln²N |
|---:|---:|-------:|
| 500 | 0.0731 | 2.82 |
| 1000 | 0.0603 | 2.88 |
| 2000 | 0.0501 | 2.90 |
| 5000 | 0.0405 | 2.94 |
| 8000 | 0.0367 | 2.96 |

The Baez-Duarte distance d²·ln²N appears to converge to ~ 3.0,
suggesting `d² ~ 3/ln²N`. This is consistent with RH (which requires
d² → 0) and gives a quantitative convergence rate.

### 4. Overcancellation confirmed to N=8000 ★

`vᵀGv < 1` at ALL tested N, with maximum 0.686 at N=8000.

## The Anatomy

From the error decomposition:
- **E_log** (logarithmic correction): dominates at 67% of |E| at N=8000
- **E_cot** (cotangent/entanglement): −39% — the genuine transcendental term
- **E_R** (Ramanujan subtraction): −128% — grows fastest, drives E negative
- **E_const** (−1/jk): negligible at −0.5%

The Ramanujan term grows like ln²N while E_log grows like lnN,
so at large N the Ramanujan term dominates and E becomes deeply negative.

## Summary

```
The "Euler convergence" observation was a mirage:
the sequence passes through e ≈ 2.718 at N ≈ 750 but does not stop.

The TRUE limit appears to be 1 + ln(2π) ≈ 2.838,
governed by the same constant that defines the Gram matrix scale.

If confirmed, this means:
  (1 − vᵀGv) · lnN → 1 + ln(2π)

Or equivalently:
  vᵀGv = 1 − (1 + ln2π)/lnN + O(1/ln²N)
```

This is still a beautiful result — ln(2π) is arguably even more natural
than e in this context, since it's the constant that appears in the
Stirling approximation and throughout the theory of the zeta function.
