#!/usr/bin/env python3
"""Analyze the arithmetic structure of the optimal coefficients a* = G^{-1} b."""
import numpy as np
from collections import defaultdict

data = np.loadtxt('experiments/cache/unconstrained_coeffs_N20000.tsv', comments='#')
j_vals = data[:, 0].astype(int)
a_star = data[:, 1]

def factorize(n):
    factors = {}
    d = 2
    while d * d <= n:
        while n % d == 0:
            factors[d] = factors.get(d, 0) + 1
            n //= d
        d += 1
    if n > 1:
        factors[n] = factors.get(n, 0) + 1
    return factors

def omega(n):
    """Number of distinct prime factors."""
    return len(factorize(n))

def Omega(n):
    """Total number of prime factors with multiplicity."""
    return sum(factorize(n).values())

def is_squarefree(n):
    return all(e == 1 for e in factorize(n).values())

# Mobius function
sieve = np.ones(20001, dtype=int)
for p in range(2, 142):
    if abs(sieve[p]) == 1:
        for m in range(p, 20001, p):
            sieve[m] *= -1
        for m in range(p*p, 20001, p*p):
            sieve[m] = 0

print("=" * 70)
print("ARITHMETIC STRUCTURE OF a* = G^{-1} b  (N=20000)")
print("=" * 70)

# 1. Mean |a*| by number of prime factors
print("\n1. Mean |a*| by number of distinct prime factors omega(j):")
omega_groups = defaultdict(list)
for i in range(len(j_vals)):
    w = omega(j_vals[i])
    omega_groups[w].append(abs(a_star[i]))

for w in sorted(omega_groups.keys()):
    vals = omega_groups[w]
    print(f"   omega={w}: count={len(vals):5d}, mean|a*|={np.mean(vals):.6f}, max={np.max(vals):.6f}")

# 2. Squarefree vs non-squarefree
print("\n2. Squarefree vs non-squarefree:")
sf_vals = [abs(a_star[i]) for i in range(len(j_vals)) if is_squarefree(j_vals[i])]
nsf_vals = [abs(a_star[i]) for i in range(len(j_vals)) if not is_squarefree(j_vals[i])]
print(f"   Squarefree:     count={len(sf_vals):5d}, mean|a*|={np.mean(sf_vals):.6f}")
print(f"   Non-squarefree: count={len(nsf_vals):5d}, mean|a*|={np.mean(nsf_vals):.6f}")
print(f"   Ratio: {np.mean(sf_vals)/np.mean(nsf_vals):.3f}")

# 3. Multiplicative structure test
print("\n3. Multiplicative structure: a*(pq) vs a*(p)*a*(q) for coprime p,q:")
test_pairs = [(2,3), (2,5), (3,5), (2,7), (3,7), (5,7), (2,11), (3,11), (2,13), (5,11)]
for p, q in test_pairs:
    jk = p * q
    ap = a_star[p-2]
    aq = a_star[q-2]
    ajk = a_star[jk-2]
    prod = ap * aq
    print(f"   a*({p})*a*({q})={prod:+.4f}  a*({jk})={ajk:+.4f}  ratio={ajk/prod:.4f}" if prod != 0 else f"   a*({p})*a*({q})=0")

# 4. Dirichlet convolution: (mu * a*)(n)
print("\n4. Dirichlet convolution (mu * a*)(n):")
print("   If a* is multiplicative, (mu*a*)(n) should be simple")
for n in [2, 3, 4, 5, 6, 10, 12, 15, 30, 60, 100, 210]:
    idx = n - 2
    if idx >= len(a_star):
        continue
    conv = 0.0
    for d in range(1, n+1):
        if n % d == 0 and d < 20001:
            mu_d = sieve[d]
            nd = n // d
            if nd >= 2 and nd-2 < len(a_star):
                conv += mu_d * a_star[nd-2]
    print(f"   n={n:4d}: a*(n)={a_star[idx]:+.6f}, (mu*a*)(n)={conv:+.6f}, n*a*(n)={n*a_star[idx]:+.6f}")

# 5. Check if n*a*(n) has nicer structure
print("\n5. n*a*(n) values at small n:")
for n in range(2, 31):
    idx = n - 2
    na = n * a_star[idx]
    mu = sieve[n]
    print(f"   n={n:3d}: n*a*(n)={na:+.6f}  mu(n)={mu:+d}  n*a*(n)/mu(n)={'N/A' if mu==0 else f'{na/mu:+.6f}'}")

# 6. Energy progression  
print("\n6. Energy E_N = 1 - d^2_N:")
for N, d2 in [(5000, 0.0531), (10000, 0.0506), (20000, 0.0502)]:
    E = 1 - d2
    print(f"   E_{N:>5} = {E:.6f}  d^2 = {d2:.4f}  rate ~ {d2*np.log(N):.4f}/ln(N)")

# 7. Correlation of a*(n) with arithmetic functions
print("\n7. Correlations of a*(n) with arithmetic functions:")
n_arr = j_vals.astype(float)
corrs = {
    "1/n": 1.0/n_arr,
    "mu(n)/n": np.array([sieve[int(j)]/j for j in j_vals]),
    "(-1)^n/n": np.array([(-1)**int(j)/j for j in j_vals]),
    "log(n)/n": np.log(n_arr)/n_arr,
    "Lambda(n)/n": np.zeros(len(j_vals)),  # von Mangoldt (approximate)
}
# Compute von Mangoldt
for i, j in enumerate(j_vals):
    f = factorize(int(j))
    if len(f) == 1:
        p, k = list(f.items())[0]
        corrs["Lambda(n)/n"][i] = np.log(p) / j

for name, arr in corrs.items():
    nz = arr != 0
    if np.sum(nz) > 100:
        c = np.corrcoef(a_star[nz], arr[nz])[0, 1]
        print(f"   Corr(a*, {name:15s}) = {c:+.6f}")
