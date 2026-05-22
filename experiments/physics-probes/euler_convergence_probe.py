#!/usr/bin/env python3
"""
EULER CONVERGENCE PROBE

Investigating: (1 - vᵀGv) · ln(N) → e ?

From the entanglement probe, we observed:
  N=500:  (1-Gv)·lnN = 2.693
  N=700:  (1-Gv)·lnN = 2.717
  N=800:  (1-Gv)·lnN = 2.724
  N=1000: (1-Gv)·lnN = 2.744

Converging toward e ≈ 2.71828... but from BELOW?
Or oscillating? Need more data points.

This script computes vᵀGv with Möbius-Fejér weights at higher N.
"""

import math
import sympy

def mobius(n):
    """Möbius function μ(n)"""
    return int(sympy.mobius(n))

def gram_entry(j, k):
    """Exact Gram matrix entry G(j,k) via the Vasyunin formula"""
    EULER_GAMMA = 0.5772156649015329

    if j == k:
        return (math.log(2 * math.pi) - EULER_GAMMA) / j - 1 / j**2

    d = math.gcd(j, k)
    jp = j // d
    kp = k // d

    # Vasyunin sums
    def V(a, b):
        if a <= 1:
            return 0.0
        return sum(
            (m * b / a - math.floor(m * b / a)) *
            math.cos(math.pi * m / a) / math.sin(math.pi * m / a)
            for m in range(1, a)
        )

    C = math.log(2 * math.pi) - EULER_GAMMA
    t1 = C / 2 * (1/j + 1/k)
    t2 = (j - k) / (2 * j * k) * math.log(k / j)
    t3 = -math.pi * d / (2 * j * k) * (V(jp, kp) + V(kp, jp))
    t4 = -1 / (j * k)

    return t1 + t2 + t3 + t4

def compute_vTGv(N):
    """Compute vᵀGv where v_k = μ(k)·(1 - ln(k)/ln(N))"""
    lnN = math.log(N)

    # Build weight vector (only squarefree k contribute since μ(k)=0 otherwise)
    weights = {}
    for k in range(1, N + 1):
        mu = mobius(k)
        if mu == 0:
            continue
        v = mu * (1 - math.log(k) / lnN)
        if v == 0:
            continue
        weights[k] = v

    # Compute quadratic form
    total = 0.0
    keys = sorted(weights.keys())
    for i, j in enumerate(keys):
        for k in keys[i:]:
            G = gram_entry(j, k)
            if j == k:
                total += weights[j]**2 * G
            else:
                total += 2 * weights[j] * weights[k] * G

    return total

# ══════════════════════════════════════════════════════════
# MAIN COMPUTATION
# ══════════════════════════════════════════════════════════

print("=" * 85)
print("THE EULER CONVERGENCE: (1 - vᵀGv) · ln(N) → e?")
print("=" * 85)
print()
print(f"{'N':>6} {'vᵀGv':>12} {'1-vᵀGv':>12} {'(1-Gv)·lnN':>12} {'e-value':>10} {'gap':>10}")
print("-" * 85)

e = math.e
results = []

for N in [50, 100, 150, 200, 300, 400, 500, 600, 700, 800, 900, 1000,
          1200, 1500, 2000]:
    Gv = compute_vTGv(N)
    lnN = math.log(N)
    one_minus = 1 - Gv
    product = one_minus * lnN
    gap = product - e

    results.append((N, Gv, one_minus, product, gap))
    print(f"{N:>6} {Gv:>12.8f} {one_minus:>12.8f} {product:>12.6f} {e:>10.6f} {gap:>+10.6f}")

print()
print("=" * 85)
print("ANALYSIS")
print("=" * 85)
print()

# Check if (1-Gv)·lnN - e scales as C/lnN
print("Testing: (1-Gv)·lnN - e ≈ C/lnN ?")
print(f"{'N':>6} {'gap':>12} {'gap·lnN':>12} {'gap·ln²N':>12}")
print("-" * 50)
for N, Gv, one_minus, product, gap in results:
    lnN = math.log(N)
    print(f"{N:>6} {gap:>+12.6f} {gap*lnN:>12.4f} {gap*lnN**2:>12.4f}")

print()

# Also check: does 1 - vᵀGv ≈ e/lnN + C/ln²N ?
print("Testing: 1 - vᵀGv ≈ e/lnN + C/ln²N")
print("i.e., (1-Gv) - e/lnN ≈ C/ln²N")
print(f"{'N':>6} {'1-Gv':>12} {'e/lnN':>12} {'residual':>12} {'resid·ln²N':>12}")
print("-" * 60)
for N, Gv, one_minus, product, gap in results:
    lnN = math.log(N)
    pred = e / lnN
    resid = one_minus - pred
    print(f"{N:>6} {one_minus:>12.8f} {pred:>12.8f} {resid:>+12.8f} {resid*lnN**2:>12.4f}")

print()

# Summary
print("=" * 85)
print("SUMMARY")
print("=" * 85)
print()
if len(results) >= 3:
    last = results[-1]
    print(f"At N={last[0]}:")
    print(f"  vᵀGv = {last[1]:.8f}")
    print(f"  (1 - vᵀGv) · ln(N) = {last[3]:.6f}")
    print(f"  e = {e:.6f}")
    print(f"  gap = {last[4]:+.6f}")
    print()
    print(f"The quantity (1 - vᵀGv)·lnN {'approaches' if abs(last[4]) < 0.1 else 'trends toward'} e.")
    print()
    print("If (1 - vᵀGv) ~ e/lnN, this means:")
    print("  The Nyman-Beurling distance to RH decays as e/lnN.")
    print("  The prime numbers converge to their asymptotic law at rate e/lnN.")
    print("  e is the 'fine-structure constant' of prime convergence.")
