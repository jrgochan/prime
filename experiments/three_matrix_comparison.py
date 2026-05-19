#!/usr/bin/env python3
"""Three-matrix comparison: G⁽¹⁾, R, G⁽²⁾ quadratic forms.

G⁽¹⁾(j,k) = R(j,k) + 1/4              (Glass Bridge)
R(j,k) = gcd(j,k)²/(12·j·k)           (Ramanujan)
G⁽²⁾(j,k) = gcd(j,k)⁴/(180·j²·k²)    (Dark Gram)

SOS decompositions:
  vᵀRv   = (1/12)  · Σ_d J₂(d) · [Σ_{d|k} v_k/k]²
  vᵀG⁽²⁾v = (1/180) · Σ_d J₄(d) · [Σ_{d|k} v_k/k²]²
  vᵀG⁽¹⁾v = vᵀRv + (σ/2)²
"""
import numpy as np
from math import log

def mobius_sieve(N):
    mu = np.zeros(N + 1, dtype=np.int8)
    mu[1] = 1
    spf = np.zeros(N + 1, dtype=np.int32)
    for p in range(2, N + 1):
        if spf[p] == 0:
            for m in range(p, N + 1, p):
                if spf[m] == 0: spf[m] = p
    for n in range(2, N + 1):
        p = spf[n]
        if (n // p) % p == 0: mu[n] = 0
        else: mu[n] = -mu[n // p]
    return mu

def jordan_sieve(N, order):
    """J_order(d) = d^order · Π_{p|d}(1 - 1/p^order)"""
    j = np.arange(N + 1, dtype=np.float64) ** order
    j[0] = 0.0
    is_prime = np.ones(N + 1, dtype=bool)
    is_prime[0] = is_prime[1] = False
    for p in range(2, N + 1):
        if not is_prime[p]: continue
        for m in range(2*p, N+1, p): is_prime[m] = False
        factor = 1.0 - 1.0 / (p ** order)
        for m in range(p, N+1, p): j[m] *= factor
    return j

def compute(N):
    logN = log(N)
    mu = mobius_sieve(N)
    j2 = jordan_sieve(N, 2)
    j4 = jordan_sieve(N, 4)

    # Fejér weights: v_k = -μ(k)(1 - logk/logN)
    v = np.zeros(N + 1)
    for k in range(1, N + 1):
        v[k] = -mu[k] * (1 - log(k) / logN)

    # GCD Fourier coefficients
    # f(d) = Σ_{d|k} v_k/k     (for R)
    # g(d) = Σ_{d|k} v_k/k²    (for G⁽²⁾)
    f = np.zeros(N + 1)
    g = np.zeros(N + 1)
    for d in range(1, N + 1):
        sf, sg = 0.0, 0.0
        m = 1
        while d * m <= N:
            k = d * m
            sf += v[k] / k
            sg += v[k] / (k * k)
            m += 1
        f[d] = sf
        g[d] = sg

    # Quadratic forms via SOS
    vtRv = sum(j2[d] * f[d]**2 / 12.0 for d in range(1, N+1))
    vtG2v = sum(j4[d] * g[d]**2 / 180.0 for d in range(1, N+1))
    sigma = sum(v[1:N+1])
    rank1 = (sigma / 2)**2
    vtG1v = vtRv + rank1

    # bᵀv
    btv = sum(v[k] * (0.5 - 0.5/k) for k in range(1, N+1) if mu[k] != 0)
    d_sq = 1 - 2*btv + vtG1v

    # Contribution by d-range for each matrix
    def by_range(contribs, total):
        ranges = [(1,10), (10,100), (100,1000), (1000, min(10000,N+1)), (10000, N+1)]
        out = []
        for lo, hi in ranges:
            if lo <= N:
                s = sum(contribs[d] for d in range(lo, min(hi, N+1)))
                out.append((lo, min(hi-1,N), s, 100*s/total if total > 0 else 0))
        return out

    r_contribs = {d: j2[d]*f[d]**2/12.0 for d in range(1, N+1)}
    g2_contribs = {d: j4[d]*g[d]**2/180.0 for d in range(1, N+1)}

    return {
        'vtRv': vtRv, 'vtG2v': vtG2v, 'vtG1v': vtG1v,
        'rank1': rank1, 'sigma': sigma, 'btv': btv, 'd_sq': d_sq,
        'f': f, 'g': g, 'j2': j2, 'j4': j4,
        'r_ranges': by_range(r_contribs, vtRv),
        'g2_ranges': by_range(g2_contribs, vtG2v),
    }

print("=" * 72)
print("THREE-MATRIX COMPARISON: G⁽¹⁾ vs R vs G⁽²⁾")
print("  G⁽¹⁾ = positive Gram (Vasyunin)  = R + ¼·𝟏𝟏ᵀ")
print("  R    = Ramanujan                  = gcd²/(12jk)")
print("  G⁽²⁾ = dark Gram                  = gcd⁴/(180j²k²)")
print("=" * 72)

print(f"\n{'N':>8} | {'vᵀG⁽¹⁾v':>10} | {'vᵀRv':>10} | {'vᵀG⁽²⁾v':>10} | "
      f"{'(σ/2)²':>8} | {'d²':>10} | {'R/logN':>8} | {'G²/logN':>8}")
print("─" * 95)

results = {}
for N in [100, 500, 1000, 2000, 5000, 10000, 20000, 50000]:
    r = compute(N)
    results[N] = r
    logN = log(N)
    print(f"{N:>8} | {r['vtG1v']:>10.4f} | {r['vtRv']:>10.4f} | {r['vtG2v']:>10.6f} | "
          f"{r['rank1']:>8.4f} | {r['d_sq']:>10.6f} | {r['vtRv']/logN:>8.4f} | {r['vtG2v']/logN:>8.6f}")

# Growth rate analysis
print(f"\n{'─'*72}")
print("GROWTH RATE ANALYSIS")
print(f"{'─'*72}")
print(f"\n{'N':>8} | {'vᵀRv/logN':>10} | {'vᵀRv/log²N':>11} | "
      f"{'vᵀG²v/logN':>11} | {'vᵀG²v/log²N':>12} | {'R/G²':>8}")
print("─" * 72)
for N in [100, 500, 1000, 5000, 10000, 20000, 50000]:
    r = results[N]
    logN = log(N)
    ratio = r['vtRv'] / r['vtG2v'] if r['vtG2v'] > 0 else 0
    print(f"{N:>8} | {r['vtRv']/logN:>10.6f} | {r['vtRv']/logN**2:>11.6f} | "
          f"{r['vtG2v']/logN:>11.8f} | {r['vtG2v']/logN**2:>12.8f} | {ratio:>8.2f}")

# GCD Fourier comparison: f(d) vs g(d)
N = 50000
r = results[N]
logN = log(N)
print(f"\n{'─'*72}")
print(f"FOURIER COEFFICIENTS at N={N}")
print(f"{'─'*72}")
print(f"{'d':>5} | {'f(d)·logN':>10} | {'g(d)·logN':>10} | {'f(d)/g(d)':>10} | "
      f"{'1/φ(d)':>8} | {'J₂(d)':>8} | {'J₄(d)':>10}")
print("─" * 72)
for d in [1, 2, 3, 5, 7, 11, 13, 30, 210]:
    if d <= N:
        fd = r['f'][d] * logN
        gd = r['g'][d] * logN
        ratio = fd / gd if abs(gd) > 1e-15 else 0
        from math import gcd as mgcd
        phi_d = sum(1 for k in range(1, d+1) if mgcd(k, d) == 1)
        print(f"{d:>5} | {fd:>10.6f} | {gd:>10.6f} | {ratio:>10.2f} | "
              f"{1/phi_d:>8.5f} | {r['j2'][d]:>8.1f} | {r['j4'][d]:>10.1f}")

# Contribution by d-range
print(f"\n{'─'*72}")
print("CONTRIBUTION BY d-RANGE (N=50000)")
print(f"{'─'*72}")
print(f"{'range':>15} | {'R contrib':>10} | {'R %':>6} | {'G² contrib':>10} | {'G² %':>6}")
print("─" * 60)
r = results[50000]
for (lo, hi, s, pct), (_, _, s2, pct2) in zip(r['r_ranges'], r['g2_ranges']):
    print(f"  d∈[{lo:>5},{hi:>5}] | {s:>10.4f} | {pct:>5.1f}% | {s2:>10.6f} | {pct2:>5.1f}%")
