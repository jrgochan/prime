#!/usr/bin/env python3
"""Test connections between Robin's inequality sigma(n)/n and a*(n)."""
import numpy as np
import math

data = np.loadtxt('experiments/cache/unconstrained_coeffs_N20000.tsv', comments='#')
j_vals = data[:, 0].astype(int)
a_star = data[:, 1]

def sigma(n):
    s = 0
    for d in range(1, int(n**0.5)+1):
        if n % d == 0:
            s += d + n//d
            if d == n//d:
                s -= d
    return s

def omega(n):
    count = 0
    d = 2
    while d * d <= n:
        if n % d == 0:
            count += 1
            while n % d == 0:
                n //= d
        d += 1
    if n > 1:
        count += 1
    return count

gamma = 0.5772156649015329

N = 2000
sig_over_n = np.zeros(N)
robin_ratio = np.zeros(N)
for i in range(N):
    n = int(j_vals[i])
    s = sigma(n)
    sig_over_n[i] = s / n
    lln = math.log(math.log(n)) if n > 2 else 1.0
    robin_ratio[i] = (s / n) / (math.exp(gamma) * lln)

print("=" * 70)
print("ROBIN'S INEQUALITY vs OPTIMAL COEFFICIENTS")
print("=" * 70)

# Correlations
print("\n1. Correlations:")
print(f"   Corr(a*(n), sigma(n)/n)     = {np.corrcoef(a_star[:N], sig_over_n)[0,1]:+.6f}")
print(f"   Corr(a*(n), Robin ratio)    = {np.corrcoef(a_star[:N], robin_ratio)[0,1]:+.6f}")
print(f"   Corr(|a*(n)|, sigma(n)/n)   = {np.corrcoef(np.abs(a_star[:N]), sig_over_n)[0,1]:+.6f}")
print(f"   Corr(|a*(n)|, Robin ratio)  = {np.corrcoef(np.abs(a_star[:N]), robin_ratio)[0,1]:+.6f}")

# Key numbers
print("\n2. Robin's critical numbers (highest sigma/n):")
for n in [2, 4, 6, 12, 24, 30, 60, 120, 180, 240, 360, 720, 840, 1260, 1680, 2520, 5040]:
    if n > 20000:
        break
    idx = n - 2
    s = sigma(n)
    lln = math.log(math.log(n)) if n > 2 else 1.0
    robin = (s / n) / (math.exp(gamma) * lln)
    w = omega(n)
    print(f"   n={n:5d}: sig/n={s/n:.4f}  Robin={robin:.4f}  a*={a_star[idx]:+.8f}  omega={w}")

# Does sigma/n predict |a*|?
print("\n3. Binned analysis: mean|a*| by sigma(n)/n quartiles:")
quartiles = np.percentile(sig_over_n, [25, 50, 75])
bins = [0] + list(quartiles) + [100]
for i in range(4):
    mask = (sig_over_n >= bins[i]) & (sig_over_n < bins[i+1])
    if np.sum(mask) > 0:
        mean_abs = np.mean(np.abs(a_star[:N][mask]))
        mean_signed = np.mean(a_star[:N][mask])
        print(f"   sigma/n in [{bins[i]:.2f}, {bins[i+1]:.2f}): count={np.sum(mask):4d}, mean|a*|={mean_abs:.6f}, mean(a*)={mean_signed:+.6f}")

# The Gram diagonal connection
print("\n4. Gram diagonal G(j,j) = 1/j:")
print("   G(j,j) = integral_0^inf {j/x}^2 dx/x^2 = sum_{n=1}^inf 1/(n(n+1)) * (2n+1)/j = 1/j")
print("   So the diagonal is trivially 1/j, not related to sigma")

# Key test: does the PRODUCT n*a*(n) relate to sigma?
print("\n5. n*a*(n) vs sigma(n) at superabundant numbers:")
for n in [6, 12, 24, 36, 48, 60, 120, 180, 240, 360, 720, 840, 1260, 1680, 2520, 5040]:
    if n > 20000:
        break
    idx = n - 2
    s = sigma(n)
    na = n * a_star[idx]
    print(f"   n={n:5d}: n*a*={na:+10.4f}  sigma={s:6d}  n*a*/sigma={na/s:+.6f}")

# Critical: Gram row sums and sigma
print("\n6. Connection: Gram row sum = sum_k G(j,k) relates to sigma?")
print("   G(j,k) = 1/2(1/j + 1/k - gcd(j,k)^2/(jk))")
print("   sum_k G(j,k) = (N-1)/(2j) + H_N/2 - 1/(2j) sum_k gcd(j,k)^2/k")
print("   The gcd sum: sum_{k=2}^N gcd(j,k)^2/k = sum_{d|j} d^2 sum_{m: dm<=N, gcd(m,j/d)=1} 1/(dm)")
print("   This involves the Jordan totient function and connects to sigma!")
print("   Specifically, sum_{d|n} phi(d) = n, and sum_{d|n} d*phi(n/d) = sigma(n)*phi(n)/n")

# Direct test: sum_k gcd(j,k)^2/k for small j
print("\n7. Direct gcd sums (N=2000):")
for j in [2, 3, 4, 5, 6, 10, 12, 30, 60, 120]:
    gcd_sum = 0
    for k in range(2, N+2):
        g = math.gcd(j, k)
        gcd_sum += g*g / k
    s = sigma(j)
    print(f"   j={j:4d}: sum_k gcd(j,k)^2/k = {gcd_sum:.4f}  sigma(j)={s:5d}  ratio={gcd_sum/s:.6f}")
