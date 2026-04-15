# Möbius Basis Experiment — Data Analysis

**From**: The Forge Master  
**Date**: 2026-04-07  
**Experiment**: `experiments/mobius-basis/` (Rust, 128-bit MPFR, rayon parallel)

---

## Experiment Design

We tested the Theorist's **Attack 2** (Möbius Basis Transformation): whether the transformed Gram matrix G̃ = M G Mᵀ is diagonally dominant, where:

- **G(j,k)** = ∫₀¹ {j/x}{k/x} dx — the Nyman-Beurling Gram matrix
- **M(i,j)** = μ(i/j) if j|i, else 0 — the Möbius change-of-basis (unit lower-triangular, det = 1)

If the **Gershgorin ratio** (off-diagonal row sum / diagonal) < 1.0 for every row, the Gershgorin Circle Theorem would give an unconditional lower bound λ_min(G̃) > 0, potentially eliminating the `block_eigenvalue_log_scaling` axiom.

### Technical Details
- **Precision**: 128-bit MPFR via `rug` crate (38 decimal digits)
- **Integration**: Change of variable t = 1/x, splitting into blocks [n, n+1) with exact sub-breakpoint enumeration. Tail t > 5000 bounded by 1/t_max = 2×10⁻⁴.
- **Parallelism**: rayon across 12 cores
- **Matrix sizes**: N = 10, 20, 50, 100

---

## Raw Results

### Eigenvalue Data

| N | dim | λ_min(G) | λ_max(G) | κ(G) | λ_min(G̃) | λ_max(G̃) | κ(G̃) | κ improvement |
|---|---|---|---|---|---|---|---|---|
| 10 | 9 | 3.20×10⁻² | 2.28 | 71 | 2.22×10⁻² | 1.56 | 70 | 1.02× |
| 20 | 19 | 2.28×10⁻² | 4.75 | 209 | 1.14×10⁻² | 3.00 | 263 | **0.79×** |
| 50 | 49 | 1.80×10⁻² | 12.2 | 678 | 4.76×10⁻³ | 7.48 | 1,571 | **0.43×** |

**Key observation**: The Möbius transform makes the condition number **worse** for N ≥ 20 (improvement factor < 1.0). The minimum eigenvalue of G̃ drops faster than that of G.

### Gershgorin Ratios

| N | Max ratio | Mean ratio | Fraction < 1.0 | Gershgorin min bound |
|---|---|---|---|---|
| 10 | 4.46 | 3.02 | 22.2% (2/9 rows) | -1.02 |
| 20 | 9.60 | 6.09 | 0% | -2.54 |
| 50 | 25.4 | 14.4 | 0% | -7.32 |

**Trend**: Max ratio ≈ 0.5 × N (linear growth). Diagonal dominance **never holds** and **diverges**.

### Gershgorin Ratios by Number Type

| N | Primes (worst) | Squarefree composites | Squareful |
|---|---|---|---|
| 10 | 4.46 (k=2) | 3.92 (k=6) | 0.93 (k=8) ✅ |
| 20 | 9.60 (k=2) | 8.43 (k=6) | 1.13 (k=16) |
| 50 | 25.4 (k=2) | 22.4 (k=6) | 1.77 (k=32) |

**The pattern is unambiguous**: primes are worst, squareful numbers are best.

---

## Root Cause Analysis

### Why Primes Are Immune to the Möbius Transform

For a prime p, the only divisor ≥ 2 is p itself. Therefore:
- M(p, p) = μ(p/p) = μ(1) = 1
- M(p, j) = 0 for all j ≠ p (since j ≥ 2 and j|p requires j = p)

**The prime rows of G̃ are identical to the prime rows of G.** The Möbius change-of-basis is the identity on the prime subspace. It cannot reduce cross-correlations between primes.

### Why Off-Diagonal Sums Grow

For the prime row p in G̃:

off_sum(p) = Σ_{k≠p} |G̃(p,k)| ≈ Σ_{k≠p} |G(p,k)| + corrections

The corrections from the Möbius mixing of composite columns actually **add** to the off-diagonal sum rather than reducing it, because the composite columns combine multiple correlated basis functions.

Meanwhile, the diagonal G̃(p,p) = G(p,p) ≈ 0.30 (roughly constant for all primes). So:

**ratio(p) ≈ (0.3 × N) / 0.3 = N** (linear growth)

### Why Squareful Numbers Are Good

For squareful k (μ(k) = 0), the Möbius transform creates the "difference sawtooth" W_k(x) = {k/x} - Σ μ(k/d){d/x}. This removes most of the low-frequency content, leaving a high-frequency residual with small L² inner products against other basis functions. The off-diagonal sums grow much slower for these rows.

---

## Validated Conclusions

1. **G is positive definite** — confirmed at all tested sizes with λ_min > 0
2. **G(2,2) ≈ 0.2939** — stable across all N (correct computation verified)
3. **The Möbius transform helps squareful rows** — ratios near or below 1.0
4. **The Möbius transform is identity on primes** — cannot help the dominant bottleneck
5. **Gershgorin on G̃ diverges** — ratios grow as ~O(N), ruling out Attack 2 as stated
6. **Condition number worsens** — κ(G̃) > κ(G) for N ≥ 20

---

## Implications for the Cathedral

### Attacks Falsified
- **Attack 2** (Möbius + Gershgorin) — **DEAD** as stated

### Attacks Validated / Unaffected
- **Attack 1** (Square-free projection) — supported by the squareful vs. squarefree ratio difference
- **Attack 3** (Explicit inverse "guess and check") — unaffected; this approach doesn't rely on diagonal dominance
- **Attack 4** (Gram-Schmidt sieve) — the prime correlation data (G(p,q) ≈ 0.25, G(p,p) ≈ 0.30) confirms the ~75% inter-prime correlation that makes this approach challenging

### New Directions Suggested by the Data
- **Block Gershgorin**: partition the matrix into a prime block and composite block; the composite block may be diagonally dominant
- **Weighted Gershgorin**: use weights w_k = 1/k to normalize the growing row sums
- **Hybrid**: project to squarefree (Attack 1), then apply block Gershgorin on the parity-split squarefree matrix

— The Forge Master
