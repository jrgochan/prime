#!/usr/bin/env python3
"""GCD Fourier scan — optimized with Möbius sieve."""
import numpy as np
from math import log

def mobius_sieve(N):
    """Compute μ(k) for k=0..N via sieve."""
    mu = np.zeros(N + 1, dtype=np.int8)
    mu[1] = 1
    is_prime = np.ones(N + 1, dtype=bool)
    is_prime[0] = is_prime[1] = False
    for p in range(2, N + 1):
        if not is_prime[p]: continue
        for m in range(2 * p, N + 1, p):
            is_prime[m] = False
        # Multiply μ by -1 for each prime factor
        for m in range(p, N + 1, p):
            mu[m] *= -1
        # Zero out multiples of p²
        p2 = p * p
        for m in range(p2, N + 1, p2):
            mu[m] = 0
    # Fix: sieve gives sign, need to set unsieved composites
    # Actually the above doesn't work perfectly. Let me use a standard approach.
    mu2 = np.zeros(N + 1, dtype=np.int8)
    mu2[1] = 1
    smallest_pf = np.zeros(N + 1, dtype=np.int32)
    for p in range(2, N + 1):
        if smallest_pf[p] == 0:  # prime
            for m in range(p, N + 1, p):
                if smallest_pf[m] == 0:
                    smallest_pf[m] = p
    for n in range(2, N + 1):
        p = smallest_pf[n]
        if (n // p) % p == 0:
            mu2[n] = 0
        else:
            mu2[n] = -mu2[n // p]
    return mu2

def jordan2_sieve(N):
    """Compute J₂(d) for d=1..N."""
    j2 = np.arange(N + 1, dtype=np.float64) ** 2
    j2[0] = 0
    is_prime = np.ones(N + 1, dtype=bool)
    is_prime[0] = is_prime[1] = False
    for p in range(2, N + 1):
        if not is_prime[p]: continue
        for m in range(2 * p, N + 1, p):
            is_prime[m] = False
        factor = 1.0 - 1.0 / (p * p)
        for m in range(p, N + 1, p):
            j2[m] *= factor
    return j2

def scan(N):
    logN = log(N)
    mu = mobius_sieve(N)
    j2 = jordan2_sieve(N)
    
    # Fejér-Möbius weights
    v = np.zeros(N + 1)
    for k in range(1, N + 1):
        v[k] = -mu[k] * (1 - log(k) / logN)
    
    # f(d) = Σ_{d|k} v_k/k
    f = np.zeros(N + 1)
    for d in range(1, N + 1):
        s = 0.0
        for m in range(1, N // d + 1):
            k = d * m
            s += v[k] / k
        f[d] = s
    
    # vᵀRv = (1/12) · Σ J₂(d) · f(d)²
    contribs = j2[1:N+1] * f[1:N+1]**2 / 12.0
    vtRv = contribs.sum()
    
    sigma = v[1:N+1].sum()
    rank1 = (sigma / 2)**2
    vtGv = vtRv + rank1
    
    return f, contribs, vtRv, sigma, rank1, vtGv, j2

print("=" * 70)
print("GCD FOURIER SCAN — EXTENDED")
print("=" * 70)

for N in [1000, 2000, 5000, 10000, 20000]:
    print(f"\nComputing N={N}...", end=" ", flush=True)
    f, contribs, vtRv, sigma, rank1, vtGv, j2 = scan(N)
    logN = log(N)
    print("done.")
    
    print(f"  vᵀRv      = {vtRv:.6f}")
    print(f"  (σ/2)²    = {rank1:.6f}   (σ = {sigma:.4f})")
    print(f"  vᵀGv      = {vtGv:.6f}")
    print(f"  vᵀGv-1    = {vtGv-1:.6f}")
    print(f"  (vᵀGv-1)·logN = {(vtGv-1)*logN:.4f}")
    print(f"  vᵀRv/logN = {vtRv/logN:.6f}  (growth rate?)")
    print(f"  vᵀRv/log²N= {vtRv/logN**2:.6f}")
    
    # f(d) pattern for small primes
    print(f"  f(d) pattern:")
    for d in [1, 2, 3, 5, 7, 11, 13]:
        if d <= N:
            print(f"    f({d:2d})·logN = {f[d]*logN:8.5f}   "
                  f"expected ≈ μ(d)·{'?':>5}")

    # Cumulative contribution by threshold
    sorted_idx = np.argsort(-contribs)
    total50 = 0
    count50 = 0
    for i in sorted_idx:
        total50 += contribs[i]
        count50 += 1
        if total50 >= 0.5 * vtRv:
            break
    print(f"  Top {count50} divisors account for 50% of vᵀRv")
    
    # Contribution by d-range
    for lo, hi in [(1,10), (10,100), (100,1000), (1000,N+1)]:
        if lo < N:
            s = contribs[max(0,lo-1):min(hi-1,N)].sum()
            print(f"  d∈[{lo},{min(hi-1,N)}]: {s:.6f} ({100*s/vtRv:.1f}%)")
