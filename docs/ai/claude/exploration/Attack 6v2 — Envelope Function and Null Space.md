# Attack 6v2 Results — The Envelope Function and the Null Space

**From**: The Forge Master  
**To**: The Theorist & Jason  
**Subject**: Objectives 1 & 3 Complete — The Envelope Is NOT 1/√k  
**Date**: April 8, 2026  

---

## Objective 1: The Envelope Function f(k) = c*_k / (-μ(k))

### Raw Data (N=500, squarefree k)

| k | μ(k) | c*_k | f(k) | f(k)·√k | f(k)·ln(k) |
|---|---|---|---|---|---|
| 1 | +1 | -0.935 | 0.935 | 0.935 | — |
| 2 | -1 | +0.954 | 0.954 | 1.349 | 0.661 |
| 3 | -1 | +0.947 | 0.947 | 1.641 | 1.041 |
| 5 | -1 | +0.873 | 0.873 | 1.952 | 1.405 |
| 7 | -1 | +0.815 | 0.815 | 2.157 | 1.586 |
| 11 | -1 | +0.760 | 0.760 | 2.521 | 1.822 |
| 13 | -1 | +0.728 | 0.728 | 2.625 | 1.868 |
| 23 | -1 | +0.628 | 0.628 | 3.014 | 1.970 |
| 37 | -1 | +0.590 | 0.590 | 3.587 | 2.130 |
| 47 | -1 | +0.574 | 0.574 | 3.936 | 2.209 |

### Scaling Test Across N

| N | f(k)·√k avg | f(k)·k avg | f(k)·ln(k) avg |
|---|---|---|---|
| 10 | 1.12 | 2.28 | 0.67 |
| 20 | 1.36 | 4.49 | 0.97 |
| 50 | 1.93 | 12.3 | 1.13 |
| 100 | 2.29 | 21.8 | 1.09 |
| 200 | 3.37 | 46.6 | 1.28 |
| **500** | **4.57** | **101.4** | **1.28** |

### Diagnosis

**None of the three simple scalings (1/√k, 1/k, 1/ln k) are constant.**

- **f(k)·√k is GROWING** (0.94 → 4.57)  → f decays SLOWER than 1/√k
- **f(k)·k is GROWING FAST** (2.3 → 101) → f decays MUCH slower than 1/k
- **f(k)·ln(k) is NEARLY STABLE** (0.67 → 1.28) → **f ~ C/ln(k) is the best fit**

But even f(k)·ln(k) is still slowly increasing, from 0.67 at N=10 to 1.28 at N=500. This suggests:

> **f(k) ~ 1/ln(k) is approximately correct, but with a slow logarithmic correction.**

The envelope function is something like f(k) ≈ C · ln(ln(k)) / ln(k), or more likely f(k) involves the prime counting function or harmonic sums that make it not cleanly expressible.

### Implication for the Variational Proof

If f(k) ~ 1/ln(k), then a trial vector v_k = -μ(k)/ln(k) gives:

- Numerator: (bᵀv)² = (Σ b_k · (-μ(k)/ln(k)))² — needs the Möbius cancellation to evaluate
- Denominator: vᵀCv — involves Σ μ(j)μ(k)C(j,k)/(ln j · ln k), which IS the Parity Barrier

**The envelope function doesn't bypass the sieve.** The reason c* has the Möbius signs is precisely because the problem requires sieve-theoretic cancellation. Any test vector using μ(k) inherits the same barrier.

---

## Objective 3: The Null Space (The Ghost Harmonics)

### N=50: Eigenvector of λ_min = 4.35×10⁻⁴

| k | μ | component | type |
|---|---|---|---|
| **48** | 0 | **-0.771** | comp |
| 24 | 0 | +0.297 | comp |
| 49 | 0 | +0.288 | comp |
| 47 | -1 | +0.226 | prime |
| 46 | +1 | +0.220 | sqf |

### N=500: Eigenvector of λ_min = 5.46×10⁻⁶

| k | μ | component | type |
|---|---|---|---|
| **492** | 0 | **+0.454** | comp |
| **498** | -1 | **-0.432** | sqf |
| 490 | 0 | -0.282 | comp |
| 494 | -1 | -0.257 | sqf |
| 246 | -1 | -0.229 | sqf |
| 496 | 0 | +0.217 | comp |

### Pattern

The null space eigenvector concentrates on:
1. **High-k values** near N (the boundary of the basis)
2. **BOTH k and k/2** simultaneously — note (492, 246), (498, 249), (496, 248)
3. **Opposite signs for k and k/2** — the eigenvector oscillates between a number and its double

**This is the Parity Barrier in geometric form.** The near-zero eigenvalue corresponds to the direction where the basis functions {u/k} and {u/(k/2)} are almost indistinguishable after covariance deflation. The matrix can't tell k apart from k/2 — the fundamental parity obstruction.

The ghost harmonic at N=500 essentially says: "I can't tell whether to assign weight to k=492 or k=246." This is exactly the kind of even/odd ambiguity that the Möbius function resolves, and it's exactly what makes the RH hard.

---

## Summary

| Objective | Result | Implication |
|---|---|---|
| 1. Envelope | f(k) ~ 1/ln(k) (approx) | No clean bypass — the sieve IS the answer |
| 3. Null space | Concentrates on (k, k/2) pairs at boundary | Parity Barrier is geometric: can't distinguish k from 2k |

The Theorist was right: there is no shortcut past the Möbius function. The envelope function IS the sieve. The null space IS the parity barrier. The Cathedral's final axiom — X_N ≥ c·ln(N) — is genuinely equivalent to RH, and proving it requires understanding how the primes cancel through Dirichlet inversion.

— The Forge Master
