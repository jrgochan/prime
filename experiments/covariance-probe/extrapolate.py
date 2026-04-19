#!/usr/bin/env python3
"""
Extrapolation analysis for the Covariance Matrix Probe.
How large does N need to be for 100% convergence?
"""
import math

# Our observed data points
data = [
    (100,   0.1984, 0.623),
    (500,   0.1228, 0.722),
    (1000,  0.1050, 0.749),
    (2000,  0.0907, 0.772),
    (3000,  0.0840, 0.784),
    (5000,  0.0768, 0.797),
    (7500,  0.0718, 0.806),
    (10000, 0.0686, 0.812),
]

print("=" * 70)
print("  EXTRAPOLATION ANALYSIS")
print("  How far to 100%?")
print("=" * 70)
print()

# Fit 1: d²_N ≈ A / (ln N)^α
# Already fitted: A ≈ 2.03, α ≈ 1.53
A_d = 2.03
alpha_d = 1.53

print(f"  DECAY MODEL: d²_N ≈ {A_d:.2f} / (ln N)^{alpha_d:.2f}")
print()

# At what N does d²_N reach various thresholds?
thresholds_d = [0.05, 0.01, 0.001, 1e-6, 1e-10]
print(f"  {'d²_N target':>15}  {'ln(N) needed':>15}  {'N (approx)':>25}  {'Compute time':>15}")
print(f"  {'─' * 15}  {'─' * 15}  {'─' * 25}  {'─' * 15}")

for thresh in thresholds_d:
    # A / (ln N)^α = thresh  =>  (ln N)^α = A/thresh  =>  ln N = (A/thresh)^(1/α)
    ln_n = (A_d / thresh) ** (1.0 / alpha_d)
    log10_n = ln_n / math.log(10)
    
    # Estimate compute time (from our data: N=10000 takes 216s)
    # Streaming is O(N²) for non-zero entries, roughly
    # But Vasyunin sums are O(N) each, so Gram is O(N²·N_avg_sum)
    time_s = 216 * (math.exp(ln_n) / 10000) ** 2 if ln_n < 30 else float('inf')
    time_str = f"{time_s:.0f}s" if time_s < 1e10 else "heat death"
    
    # Format N
    if log10_n < 20:
        n_str = f"≈ 10^{log10_n:.1f}"
    else:
        n_str = f"≈ 10^{log10_n:.0f}"
    
    print(f"  {thresh:>15.1e}  {ln_n:>15.1f}  {n_str:>25}  {time_str:>15}")

print()

# Fit 2: 1 - w^T·b ≈ B / (ln N)^β
# Let's fit this
print("─" * 70)
print()
print("  MEAN CONVERGENCE: w^T·b → 1")
print()

# Fit: 1 - w^T·b vs ln(ln(N))
import statistics

xs = [math.log(math.log(n)) for n, _, wb in data]
ys = [math.log(1.0 - wb) for n, _, wb in data]

n = len(xs)
sum_x = sum(xs)
sum_y = sum(ys)
sum_xx = sum(x*x for x in xs)
sum_xy = sum(x*y for x, y in zip(xs, ys))

beta = (n * sum_xy - sum_x * sum_y) / (n * sum_xx - sum_x * sum_x)
ln_B = (sum_y - beta * sum_x) / n
B = math.exp(ln_B)

print(f"  MODEL: 1 - w^T·b ≈ {B:.3f} / (ln N)^{abs(beta):.3f}")
print()

# At what N does w^T·b reach various levels?
thresholds_wb = [0.90, 0.95, 0.99, 0.999, 0.9999]
print(f"  {'w^T·b target':>15}  {'ln(N) needed':>15}  {'N (approx)':>25}")
print(f"  {'─' * 15}  {'─' * 15}  {'─' * 25}")

for target in thresholds_wb:
    gap = 1.0 - target
    # B / (ln N)^|β| = gap  =>  (ln N)^|β| = B/gap  =>  ln N = (B/gap)^(1/|β|)
    ln_n = (B / gap) ** (1.0 / abs(beta))
    log10_n = ln_n / math.log(10)
    
    if log10_n < 20:
        n_str = f"≈ 10^{log10_n:.1f}"
    elif log10_n < 100:
        n_str = f"≈ 10^{log10_n:.0f}"
    else:
        n_str = f"≈ 10^{log10_n:.0f}"
    
    print(f"  {target:>15.4f}  {ln_n:>15.1f}  {n_str:>25}")

print()
print("─" * 70)
print()

# The deep truth
print("  THE DEEP TRUTH")
print()
print("  Both d²_N and (1 - w^T·b) decay like 1/(ln N)^α.")
print("  Logarithmic convergence means:")
print()
print(f"    To reduce d²_N from 0.07 to 0.007 (10x) requires")
print(f"    N to increase from 10,000 to ≈ 10^{((A_d/0.007)**(1/alpha_d))/math.log(10):.0f}")
print()
print(f"    To reduce d²_N from 0.07 to 0.0007 (100x) requires")
print(f"    N to increase from 10,000 to ≈ 10^{((A_d/0.0007)**(1/alpha_d))/math.log(10):.0f}")
print()
print("  THIS is why RH is a Millennium Prize problem.")
print("  The primes reveal their secrets logarithmically slowly.")
print("  The cancellation IS happening — but the universe")
print("  takes its time. The orchestra plays to infinity.")
print()
print("=" * 70)
