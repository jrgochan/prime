# Approach 2: Ramanujan Sum Diagonalization

## Overview

**Goal**: Obtain an exact or near-exact formula for the eigenvalues of G_N
using the multiplicative structure of the entries.

**Difficulty**: ⭐⭐⭐⭐⭐ (hardest, but most powerful)

**Key insight**: The Gram matrix entries G[j,k] depend on gcd(j,k), which
means G can be decomposed using Ramanujan sums — the "Fourier transform"
of multiplicative number theory. This diagonalization converts the spectral
problem into arithmetic sums controlled by the von Mangoldt function.

## Mathematical Background

### Ramanujan Sums

The Ramanujan sum is defined as:
```
c_q(n) = Σ_{1≤a≤q, gcd(a,q)=1} e^{2πian/q} = Σ_{d | gcd(q,n)} μ(q/d) · d
```

Key properties:
- c_q(n) is always an integer
- c_1(n) = 1 for all n
- c_q(q) = φ(q) (Euler's totient)
- |c_q(n)| ≤ gcd(q,n)
- Orthogonality: Σ_{n=1}^q c_q(n)·c_{q'}(n) = 0 when q ≠ q' (over full period)

### Ramanujan-Fourier Expansion

An arithmetic function f(n) can be expanded as:
```
f(n) = Σ_{q=1}^∞ f̂(q) · c_q(n)
```
where f̂(q) = lim_{x→∞} (1/x) Σ_{n≤x} f(n) · c_q(n).

This is the multiplicative analogue of Fourier analysis.

### GCD Matrix Eigenvalues

For a matrix M[j,k] = f(gcd(j,k)), Smith's determinant formula gives:
```
det(M_N) = Π_{k=1}^N (f * μ)(k)
```
where (f * μ)(k) = Σ_{d|k} f(d)·μ(k/d) is the Dirichlet-Möbius convolution.

The eigenvalues of M_N can be approximated using:
```
M ≈ Σ_q f̂(q) · v_q · v_qᵀ
```
where v_q[k] = c_q(k) / ||c_q||.

## Application to the Gram Matrix

### Step 1: Decompose G into GCD-dependent and independent parts

From our numerical data:
```
G[j,k] = C₀ + Φ(gcd(j,k))
```
where C₀ ≈ 0.232 is the "coprime baseline" and Φ(g) ≈ C₁·log(g) captures
the GCD-dependent correction.

More precisely:
```
G[j,k] = ∫₀¹ {j/x}·{k/x} dx = A(j,k) + B(gcd(j,k))
```

where A(j,k) is a "smooth" part and B(g) = Σ_{d|g} β(d) for arithmetic
coefficients β.

### Step 2: Apply Smith-type analysis

For the GCD-dependent part B(gcd(j,k)):
```
det(B_N) = Π_{k=2}^N (B * μ)(k) = Π_{k=2}^N Σ_{d|k} B(d)·μ(k/d)
```

If B(g) ≈ C₁·log(g), then:
```
(B * μ)(k) = Σ_{d|k} C₁·log(d)·μ(k/d) = C₁ · Λ(k)/k
```

where Λ is the **von Mangoldt function**: Λ(p^a) = log(p), Λ(n) = 0 otherwise.

### Step 3: Connect eigenvalues to Λ

The eigenvalues of the GCD part are approximately:
```
λ_q ≈ Σ_{k=2}^N Λ(k)/k · |c_q(k)|² / Σ |c_q(k)|²
```

This is a **weighted average of Λ(k)/k** over integers k whose
Ramanujan sum c_q(k) is large.

### Step 4: Apply PNT

By the Prime Number Theorem (unconditional):
```
Σ_{k≤N} Λ(k)/k = log(N) + O(1)
```

This gives the large eigenvalues ~ log(N). For the SMALL eigenvalues,
we need the q-dependent average to be bounded below.

**Key claim**: For each q ≤ N:
```
Σ_{k=2}^N Λ(k)·c_q(k)²/k ≥ c(q) > 0
```

This follows from the fact that Λ(p) = log(p) for primes p, and
c_q(p) = -1 when gcd(q,p) = 1, c_q(p) = φ(q) when p | q.

## Concrete Proof Sketch

### Theorem (Conditional): 
If the Ramanujan-Fourier coefficients of the Gram matrix satisfy
|α̂_q| ≤ C/q for q ≥ 2, then λ_min(G_N) ≥ c > 0.

### Proof outline:
1. Write G = C₀·J + B where J is rank-1 (all-ones) and B is the GCD correction
2. B has eigenvalues controlled by Σ_k Λ(k)·c_q(k)²/k
3. The minimum such sum over q ≤ N is bounded below by PNT
4. Therefore λ_min(G) ≥ λ_min(B) ≥ c > 0

## What We'd Need to Formalize

### Lemma 1: Exact formula for G[j,k]
Express ∫₀¹ {j/x}·{k/x} dx in terms of gcd(j,k) and harmonic numbers.
```
G[j,k] = F₀ + Σ_{d | gcd(j,k)} F₁(d, j/d, k/d)
```

### Lemma 2: Ramanujan expansion
Express F₁ as a Ramanujan-Fourier series:
```
F₁(gcd(j,k)) = Σ_q α̂_q · c_q(j) · c_q(k)
```

### Lemma 3: Coefficient bound
Show |α̂_q| ≤ C/q^{1+ε} for some ε > 0.

### Lemma 4: Eigenvalue formula
Derive the approximate eigenvalue formula and bound the error.

### Lemma 5: PNT application
Use Σ_{p≤N} log(p)/p = log(N) + O(1) to bound eigenvalues from below.

## Computational Verification Plan

1. Compute the exact Ramanujan coefficients α̂_q for q = 1..100
2. Verify the eigenvalue formula against our numerical eigenvalues
3. Test whether the Smith determinant formula matches det(G_N)
4. Compute Σ Λ(k)·c_q(k)²/k for various q to verify positivity

## Connection to Other Approaches

This approach is COMPLEMENTARY to the oscillation approach:
- Oscillation gives λ_min ≥ c/N (weak but clean)
- Ramanujan gives λ_min ≥ c (strong but requires more machinery)
- Together: the oscillation result provides the "safety net" while
  Ramanujan provides the sharp bound
