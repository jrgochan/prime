#!/usr/bin/env python3
"""
PRACTICAL APPROACH: Measure ||E_N|| / ||G_N|| at various N.

Instead of finding the exact Gram formula, we directly measure how
close G_N is to the Smith structure by computing the anti-multiplicative
ratio and the von Mangoldt correlation as functions of N.

Key insight: if the Gram matrix G_N asymptotically approaches a Smith
matrix, then G_N^{-1} b should approach the pure Möbius-von Mangoldt
vector. We can measure this convergence directly.
"""
import numpy as np
import math

def gram_matrix(N, T=10000):
    dim = N - 1
    G = np.zeros((dim, dim))
    for i in range(dim):
        for j in range(i, dim):
            ji, jj = i+2, j+2
            s = 0.0
            for n in range(1, T+1):
                fi = (n % ji) / ji
                fj = (n % jj) / jj
                s += fi * fj / (n * (n + 1))
            G[i, j] = s
            G[j, i] = s
    return G

def mobius(n):
    if n == 1: return 1
    factors = 0; temp = n
    for d in range(2, n+1):
        if d*d > temp: break
        if temp % d == 0:
            factors += 1; temp //= d
            if temp % d == 0: return 0
    if temp > 1: factors += 1
    return (-1) ** factors

def von_mangoldt(n):
    if n < 2: return 0
    temp = n
    for p in range(2, n+1):
        if p*p > temp:
            if temp == n: return math.log(n)
            break
        if temp % p == 0:
            t2 = temp
            while t2 % p == 0: t2 //= p
            if t2 == 1: return math.log(p)
            break
    return 0

gamma = 0.5772156649015329

print("=" * 70)
print("E_N DECAY MEASUREMENT")
print("=" * 70)

# Measure at various N
for N in [50, 100, 200, 500]:
    dim = N - 1
    print(f"\n--- N = {N}, dim = {dim} ---")
    
    # Build G
    T = max(5000, N * 10)
    G = gram_matrix(N, T=T)
    
    # Build b (correct formula!)
    b = np.array([(math.log(k+2) + 1 - gamma) / (k+2) for k in range(dim)])
    
    # Solve for a*
    a_star = np.linalg.solve(G, b)
    d2 = 1.0 - np.dot(b, a_star)
    
    # Anti-multiplicative ratios
    ratios = []
    for p, q in [(2,3), (2,5), (3,5), (2,7), (3,7)]:
        pq = p * q
        if pq <= N:
            r = a_star[pq-2] / (a_star[p-2] * a_star[q-2])
            ratios.append(r)
    mean_ratio = np.mean(ratios) if ratios else float('nan')
    
    # Von Mangoldt correlation at prime powers
    lam = np.array([von_mangoldt(k+2) / (k+2) for k in range(dim)])
    mask = lam > 0  # prime powers only
    if np.sum(mask) > 5:
        corr_pp = np.corrcoef(a_star[mask], lam[mask])[0, 1]
    else:
        corr_pp = float('nan')
    
    # Overall von Mangoldt correlation
    corr_all = np.corrcoef(a_star, lam)[0, 1]
    
    # Measure "Smith-ness": build L^{-1} and test G vs Smith
    L_inv = np.zeros((dim, dim))
    for i in range(dim):
        for j in range(dim):
            ni, nj = i+2, j+2
            if nj <= ni and ni % nj == 0:
                L_inv[i, j] = mobius(ni // nj)
    
    # Test: L^{-1} G L^{-T} should be diagonal if G is Smith
    D_test = L_inv @ G @ L_inv.T
    off_diag = np.sqrt(np.sum(D_test**2) - np.sum(np.diag(D_test)**2))
    diag_norm = np.sqrt(np.sum(np.diag(D_test)**2))
    smith_ratio = off_diag / diag_norm
    
    print(f"  d^2_N = {d2:.8e}")
    print(f"  mean anti-mult ratio = {mean_ratio:.4f}")
    print(f"  Corr(a*, Lambda/n) all = {corr_all:.4f}")
    print(f"  Corr(a*, Lambda/n) primes = {corr_pp:.4f}")
    print(f"  Smith ratio ||off||/||diag|| = {smith_ratio:.6f}")

print("\n\n" + "=" * 70)
print("SCALING ANALYSIS")
print("=" * 70)

# Collect the key scaling data
Ns = [50, 100, 200, 500]
smith_ratios = []
anti_mult = []
d2s = []

for N in Ns:
    dim = N - 1
    T = max(5000, N * 10)
    G = gram_matrix(N, T=T)
    b = np.array([(math.log(k+2) + 1 - gamma) / (k+2) for k in range(dim)])
    a_star = np.linalg.solve(G, b)
    d2 = 1.0 - np.dot(b, a_star)
    d2s.append(d2)
    
    ratios = []
    for p, q in [(2,3), (2,5), (3,5), (2,7), (3,7)]:
        pq = p * q
        if pq <= N:
            r = a_star[pq-2] / (a_star[p-2] * a_star[q-2])
            ratios.append(r)
    anti_mult.append(np.mean(ratios))
    
    L_inv = np.zeros((dim, dim))
    for i in range(dim):
        for j in range(dim):
            ni, nj = i+2, j+2
            if nj <= ni and ni % nj == 0:
                L_inv[i, j] = mobius(ni // nj)
    D_test = L_inv @ G @ L_inv.T
    off = np.sqrt(np.sum(D_test**2) - np.sum(np.diag(D_test)**2))
    diag = np.sqrt(np.sum(np.diag(D_test)**2))
    smith_ratios.append(off / diag)

print(f"\n{'N':>6} | {'d^2_N':>12} | {'anti-mult':>10} | {'|1+ratio|':>10} | {'Smith ratio':>12}")
print("-" * 65)
for i, N in enumerate(Ns):
    dev = abs(1 + anti_mult[i])
    print(f"{N:6d} | {d2s[i]:12.6e} | {anti_mult[i]:10.4f} | {dev:10.4f} | {smith_ratios[i]:12.6f}")

# Power law fits
import numpy as np
lnN = np.log(Ns)
# Fit |1 + ratio| ~ N^alpha
deviations = [abs(1 + r) for r in anti_mult]
if all(d > 0 for d in deviations):
    ln_dev = np.log(deviations)
    slope, intercept = np.polyfit(lnN, ln_dev, 1)
    print(f"\n|1 + ratio| ~ N^{slope:.3f}  (R^2={np.corrcoef(lnN, ln_dev)[0,1]**2:.4f})")

# Fit Smith ratio ~ N^beta
ln_smith = np.log(smith_ratios)
slope2, intercept2 = np.polyfit(lnN, ln_smith, 1)
print(f"Smith ratio ~ N^{slope2:.3f}  (R^2={np.corrcoef(lnN, ln_smith)[0,1]**2:.4f})")
