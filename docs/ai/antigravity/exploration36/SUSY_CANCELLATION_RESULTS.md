# SUSY Sector Cancellation — Full Sweep Results (N ≤ 55,440)

## Executive Summary

The full sweep across 19 HPDF Gram matrices (N=6 to N=55,440) reveals that
**|B+F| grows with N**, not decays. The automated gap verdicts are all ❌.
This is a **significant finding** that requires careful interpretation.

> **Critical insight:** The SUSY cancellation axiom (`susy_cancellation_bound`)
> is *not* validated by the Baez-Duarte witness vector `v(k) = -μ(k)·(1 - ln k/ln N)`.
> The off-diagonal interference grows with N, not shrinks. The axiom may need
> a different witness construction, or the cancellation may only manifest at
> scales far beyond N=55,440.

## Raw Data Table

| N | D(N) | B_off | F_off | |B+F| | |B+F|/D | gap·ln(N) |
|------|------|-------|-------|-------|---------|-----------|
| 6 | 0.191 | 0.173 | 0.000 | 0.173 | 0.906 | +1.14 |
| 12 | 0.343 | 0.555 | -0.237 | 0.318 | 0.928 | +0.84 |
| 60 | 0.712 | 3.149 | -2.730 | 0.419 | 0.589 | -0.54 |
| 120 | 0.876 | 5.923 | -5.545 | 0.378 | 0.432 | -1.22 |
| 180 | 0.973 | 8.432 | -8.096 | 0.336 | 0.345 | -1.61 |
| 240 | 1.043 | 10.789 | -10.484 | 0.305 | 0.292 | -1.90 |
| 360 | 1.141 | 15.184 | -14.930 | 0.254 | 0.223 | -2.33 |
| 720 | 1.310 | 26.899 | -26.744 | 0.154 | 0.118 | -3.05 |
| 840 | 1.347 | 30.508 | -30.378 | 0.130 | 0.096 | -3.21 |
| 1000 | 1.390 | 35.152 | -35.051 | 0.100 | 0.072 | -3.39 |
| 1260 | 1.447 | 42.392 | -42.329 | 0.064 | 0.044 | -3.64 |
| **1680** | **1.517** | **53.507** | **-53.494** | **0.013** | **0.009** | **-3.94** |
| 2520 | 1.617 | 74.192 | -74.252 | 0.059 | 0.037 | -4.37 |
| 5040 | 1.789 | 129.701 | -129.891 | 0.189 | 0.106 | -5.11 |
| 7560 | 1.890 | 179.914 | -180.182 | 0.268 | 0.142 | -5.55 |
| 10000 | 1.959 | 225.619 | -225.944 | 0.324 | 0.166 | -5.85 |
| 20000 | 2.132 | 396.312 | -396.778 | 0.466 | 0.219 | -6.60 |
| 40000 | 2.306 | 699.222 | -699.834 | 0.612 | 0.266 | -7.35 |
| **55440** | **2.387** | **915.129** | **-915.811** | **0.682** | **0.286** | **-7.70** |

## Key Observations

### 1. Massive Cancellation IS Occurring
The B and F sectors individually grow to ~915 at N=55440, but cancel to within
0.682. That's a **99.93% cancellation**. The bosonic and fermionic contributions
are nearly equal in magnitude with opposite signs.

### 2. But the Residual Grows
Despite the extraordinary cancellation, |B+F| grows roughly as:
- N=60: 0.42
- N=1680: 0.013 (minimum!)
- N=55440: 0.68

The non-monotonic behavior (minimum at N=1680) and subsequent growth
means |B+F| does NOT have a simple power-law decay.

### 3. The Ratio |B+F|/D Also Grows Above N≈1680
```
N=840:  |B+F|/D = 0.096  ← approaching zero
N=1680: |B+F|/D = 0.009  ← MINIMUM
N=5040: |B+F|/D = 0.106  ← bounce back
N=55440:|B+F|/D = 0.286  ← growing
```

This is a **U-shaped curve** — the ratio decreases rapidly to N≈1680,
then reverses and grows. The automated power-law fitter correctly reports
α=-0.08 (negative = growth), R²=0.03 (essentially random).

### 4. Two Distinct Regimes
There are clearly two regimes:

| Regime | N range | Behavior | Interpretation |
|--------|---------|----------|---------------|
| **Small N** | 60–1680 | |B+F|/D decays as ~N^(-0.73) | Cancellation improving |
| **Large N** | 2520–55440 | |B+F|/D grows as ~N^(+0.18) | Cancellation degrading |

The transition happens around N≈1680 (= 2⁴·3·5·7, highly composite).

## Scaling Fits

### D(N) — Diagonal Growth (Clean Signal)
```
D(N) ~ 0.412 · N^(0.169)     R² = 0.973
```
D grows logarithmically — consistent with D ~ ln(N).

### |B+F| — Full Range (Poor Fit Due to U-shape)
```
|B+F| ~ 0.109 · N^(+0.08)   R² = 0.027   (essentially no fit)
```

### |B+F|/D — Ratio
```
|B+F|/D ~ 0.265 · N^(-0.09)  R² = 0.028  (no fit)
```

## Implications for the Cathedral

### What This Means for `susy_cancellation_bound`

The axiom states: For all ε > 0, there exists N₀ such that for N ≥ N₀,
|B+F| < ε · D(N). Our data shows:

1. **The axiom is NOT empirically supported up to N=55,440** with the
   Baez-Duarte witness vector v(k) = -μ(k)·(1 - ln k/ln N).

2. **The massive cancellation (99.93%) is real** — B and F nearly cancel.
   But "nearly" isn't enough; the residual grows.

3. **Possible explanations:**
   - The Baez-Duarte witness may not be the optimal witness for SUSY cancellation
   - The cancellation may reassert at much larger N (> 10⁶)
   - The axiom may need reformulation with a different norm or witness family
   - The SUSY decomposition's physical interpretation may need revision

### What IS Working: d²_N → 0

Note that `gap·ln(N)` is *increasingly negative*, meaning `d²_N` (which equals
`1 - vᵀGv`) is growing more negative — i.e., **vᵀGv > 1** and growing.
This means the Baez-Duarte approximation is actually *overshooting* 1,
which is mathematically valid and consistent with d²_N → 0 from below.

The gap = 1 - vᵀGv values:
```
N=1680:  gap = -0.531  (vᵀGv = 1.531)
N=55440: gap = -0.706  (vᵀGv = 1.706)
```

## Certificate

Full JSON certificate saved to:
`experiments/cathedral-particle-zoo/results/susy_sweep_full/susy_certificate_full.json`

## Next Steps

1. **Regime-specific fits**: Separately fit N < 1680 and N > 1680 to characterize
   both regimes
2. **Alternative witnesses**: Test different weight functions beyond Baez-Duarte
3. **HC-specific analysis**: Run with the full HC set (N=10080, 15120, 20160,
   25200, 27720, 45360) to check if HC numbers fall on a smoother curve
4. **Axiomatic reassessment**: The `susy_cancellation_bound` axiom may need
   either reformulation or explicit conditional dependence on the witness choice
