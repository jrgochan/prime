# Dense Scaling Law Analysis — d²_opt from N=2 to 55,440

**Date**: May 30, 2026  
**Session**: Mirror-RH Closure — The Scaling Law Hunt

## Executive Summary

We computed d²_opt for **every integer** N from 2 to 5,000 using the new `--scaling` mode in prime-harmonics (Rust, parallelized with rayon), plus H5 oracle data for N up to 55,440. The results reveal:

1. **τ(N) is irrelevant**: Divisor count has zero correlation with d²_opt residuals (ρ = -0.000125)
2. **All number classes follow the same curve**: Primes, HCNs, and composites are indistinguishable
3. **The "0.04 floor" keeps sinking**: It's 0.040 at 2 terms, 0.038 at 3 terms, 0.034 at 4 terms
4. **The critical question remains open**: d²→0 (RH true) vs d²→0.034 (RH false)

## Method

### The Key Insight

The Gram entry G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx depends only on j and k, not on N. Therefore, the Gram matrix for any N' ≤ N is the **leading principal submatrix** of the Gram matrix for N. A single HPDF file at N=55,440 gives us d²_opt for all integers from 2 to 55,440.

### Implementation

New `--scaling` mode in `prime-harmonics` (Rust):
- Reads the HPDF `.h5` file (DD-precision Gram upper triangle + b_vector)
- For each target N: extracts (N-1)×(N-1) leading submatrix
- Cholesky solve: d² = 1 - bᵀG⁻¹b
- Parallelized with rayon (all cores)
- Annotates each N with: is_prime, is_hcn, τ(N), class

### Compute

| Sweep | Range | Source | Wall Time | CPU |
|-------|-------|--------|-----------|-----|
| Dense | N=2..5000 | gram_N5040.h5 | 44 min | 1100% (11 cores) |
| Oracle | N=5040..55440 | individual H5 files | 23 min (overnight) | single-core |

## Results

### Model Fits (N=100 to 55,440)

| Model | Formula | Offset | RMS | Tail Error |
|-------|---------|--------|-----|------------|
| **B** (best) | 0.0338 + 0.112/ln − 0.592/ln² + 1.268/ln³ | 0.0338 | 3.53×10⁻⁵ | 4.5×10⁻⁵ |
| A | 0.0384 + 0.021/ln + 0.001/ln² | 0.0384 | 3.90×10⁻⁵ | 1.75×10⁻⁴ |
| D (no offset) | 0.540/ln − 1.701/ln² | 0 | 8.20×10⁻⁴ | 3.80×10⁻³ |
| C (pure 1/ln) | 0.304/ln | 0 | 4.99×10⁻³ | — |

Models with a nonzero offset fit **21× better** than models forcing d²→0.

### The Offset Puzzle

The fitted offset depends on the number of terms:

| Terms | Formula | Offset |
|-------|---------|--------|
| 2 | a + b/ln | 0.0400 |
| 3 | a + b/ln + c/ln² | 0.0384 |
| 4 | a + b/ln + c/ln² + d/ln³ | 0.0338 |

The offset is **monotonically decreasing** as we add terms. If d² is truly a convergent series Σ cₖ/lnᵏ(N), the offset should eventually reach 0. But with only N ≤ 55,440 data, we cannot yet distinguish between:

- **d² → 0**: RH is true (the series converges to zero)
- **d² → 0.034**: RH is false (a nonzero limit exists)

### τ(N) Analysis

Pearson correlation between τ(N) and d² residual: **ρ = -0.000125**

| τ(N) | Count | Mean Residual | Std |
|------|-------|---------------|-----|
| 2 (primes) | 278 | +2.3×10⁻⁷ | 3.4×10⁻⁵ |
| 4 | 536 | −3.0×10⁻⁷ | 3.2×10⁻⁵ |
| 8 | 373 | −3.0×10⁻⁸ | 3.1×10⁻⁵ |
| 12 | 201 | +9.7×10⁻⁷ | 3.1×10⁻⁵ |
| 24 | 56 | +4.9×10⁻⁷ | 2.2×10⁻⁵ |

**No signal.** Divisor count does not predict d²_opt.

### Class-Stratified Analysis

| Class | Mean Residual | Std | Count |
|-------|--------------|-----|-------|
| Prime | +2.3×10⁻⁷ | 3.4×10⁻⁵ | 278 |
| HCN | −1.8×10⁻⁵ | 5.3×10⁻⁵ | 8 |
| Composite | +5.0×10⁻⁸ | 3.1×10⁻⁵ | 1615 |

HCNs sit slightly *below* the trend (better d²), but only 1.8×10⁻⁵ lower — within noise for 8 data points.

## Predictions

If Model B is correct (d² → 0.034):

| N | d²_predicted |
|---|-------------|
| 10⁶ | 0.0399 |
| 10⁹ | 0.0389 |
| 10¹² | 0.0378 |
| 10¹⁸ | 0.0365 |
| ∞ | 0.0338 |

If d² is a pure logarithmic series (d² → 0):

| N | d²_predicted |
|---|-------------|
| 10⁶ | 0.030 |
| 10⁹ | 0.022 |
| 10¹² | 0.017 |
| 10¹⁸ | 0.013 |

## Next Steps: Pushing to Higher N

### The Bottleneck

For N = M, the Cholesky factorization costs O(M³/6) flops and requires O(M²) memory:

| N | Matrix Size | Memory | Cholesky Time |
|---|------------|--------|---------------|
| 5,000 | 5000×5000 | 200 MB | ~10s |
| 10,000 | 10000×10000 | 800 MB | ~80s |
| 20,000 | 20000×20000 | 3.2 GB | ~10 min |
| 55,440 | 55440×55440 | 24.6 GB | ~25 min |

### Strategies for Higher N

1. **Incremental Cholesky**: Reuse L from N-1 to compute L for N (rank-1 update). Cost: O(N²) per step instead of O(N³).

2. **Woodbury/Sherman-Morrison**: d²(N) = 1 - bᵀG⁻¹b. When going from N-1 to N, G grows by one row+column. Use the Woodbury identity to update G⁻¹ without full refactorization.

3. **Sparse sampling**: Compute d²_opt only at selected N values (e.g., every 100th integer for N > 5000) since the curve is smooth.

4. **GPU acceleration**: The existing cuSOLVER pipeline can handle Cholesky up to N ≈ 55,000.

### Recommended: Incremental Cholesky + Sparse Tail

For a complete sweep to N=55,440:
- Dense N=2..5000 (already done, 44 min)
- Every 10th N for N=5000..10000 (~50 solves at ~80s each ≈ 1 hr)
- Every 100th N for N=10000..55440 (~450 solves at 1-25 min each ≈ days)

OR: implement the incremental Cholesky update for O(N²) per step, making the entire dense sweep to N=55440 feasible in hours.

## Connection to the Proof

The chain:
```
d²_opt → 0  ⟹  scaling_implies_convergence  ⟹  nyman_beurling_converse  ⟹  RH
             ✅ PROVED (0 sorry)              ✅ PROVED (0 sorry)
```

The only missing piece: proving d²_opt → 0 analytically. The numerical evidence is:
- d² is definitely decreasing (monotonically after N ≈ 100)
- The rate is approximately 1/ln(N)
- Whether the limit is 0 or ~0.034 cannot be distinguished from N ≤ 55,440 data alone
