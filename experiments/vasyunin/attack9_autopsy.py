#!/usr/bin/env python3
"""
Attack 9: The Dimensional Autopsy (Optimized)

Decomposes v^T C_N v into its 5 component dimensions.
Uses rank-1 shortcuts for Terms 1 & 4, and precomputes V sums.
"""

import math
import json
import sys
import time

GAMMA = 0.5772156649015329
A = math.log(2 * math.pi) - GAMMA

def mobius_sieve(N):
    mu = [0] * (N + 1)
    mu[1] = 1
    is_prime = [True] * (N + 1)
    primes = []
    for i in range(2, N + 1):
        if is_prime[i]:
            primes.append(i)
            mu[i] = -1
        for p in primes:
            if i * p > N:
                break
            is_prime[i * p] = False
            if i % p == 0:
                mu[i * p] = 0
                break
            else:
                mu[i * p] = -mu[i]
    return mu

def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

def vasyunin_sum_cached(max_a):
    """Precompute all V(a,b) for a,b up to max_a."""
    cache = {}
    for a in range(1, max_a + 1):
        if a <= 1:
            continue
        # Precompute cot values for this a
        cots = [0.0] * a
        for m in range(1, a):
            cots[m] = 1.0 / math.tan(math.pi * m / a)
        for b in range(1, max_a + 1):
            if gcd(a, b) != 1:
                # V only defined for coprime; in the formula we use j'=j/d, k'=k/d
                # which are always coprime. We still compute for non-coprime for convenience.
                pass
            total = 0.0
            for m in range(1, a):
                frac_part = (m * b % a) / a
                total += frac_part * cots[m]
            cache[(a, b)] = total
    return cache

def dimensional_autopsy(N, mu, vcache=None):
    lnN = math.log(N)

    # Witness vector
    v = [0.0] * (N + 1)
    for k in range(1, N + 1):
        v[k] = -mu[k] * (1.0 - math.log(max(k, 1)) / lnN)

    # Mean vector
    b = [0.0] * (N + 1)
    for k in range(1, N + 1):
        b[k] = (math.log(k) + 1.0 - GAMMA) / k

    # Rank-1 sums
    sum_v = sum(v[k] for k in range(1, N + 1))
    sum_v_over_k = sum(v[k] / k for k in range(1, N + 1))
    bTv = sum(b[k] * v[k] for k in range(1, N + 1))

    # Term 1 (Rational): A * (Σv) * (Σv/k)  [rank-2, separable]
    vt_G1_v = A * sum_v * sum_v_over_k

    # Term 4 (Base): -(Σv/k)^2  [rank-1, separable]
    vt_G4_v = -sum_v_over_k ** 2

    # Mean deflation
    mean_defl = -(bTv ** 2)

    # Terms 2 (Log) and 3 (Cotangent): need double sum over off-diagonal
    # Only iterate over pairs where both v[j] and v[k] are nonzero
    # (i.e., both μ(j) and μ(k) are nonzero — squarefree indices)
    nonzero = [k for k in range(1, N + 1) if mu[k] != 0]

    vt_G2_v = 0.0
    vt_G3_v = 0.0

    for i_idx, j in enumerate(nonzero):
        # Diagonal of G2 and G3 is zero
        for k in nonzero[i_idx + 1:]:
            # Term 2: Log
            g2 = (j - k) / (2.0 * j * k) * math.log(k / j)

            # Term 3: Cotangent
            d = gcd(j, k)
            jp, kp = j // d, k // d
            if vcache and (jp, kp) in vcache:
                V1 = vcache[(jp, kp)]
            else:
                V1 = _vasyunin_sum(jp, kp)
            if vcache and (kp, jp) in vcache:
                V2 = vcache[(kp, jp)]
            else:
                V2 = _vasyunin_sum(kp, jp)
            g3 = -math.pi * d / (2.0 * j * k) * (V1 + V2)

            vt_G2_v += 2.0 * v[j] * v[k] * g2
            vt_G3_v += 2.0 * v[j] * v[k] * g3

    vt_C_v = vt_G1_v + vt_G2_v + vt_G3_v + vt_G4_v + mean_defl
    Q = (bTv ** 2) / vt_C_v if vt_C_v > 0 else float('inf')

    total_abs = abs(vt_G1_v) + abs(vt_G2_v) + abs(vt_G3_v) + abs(vt_G4_v) + abs(mean_defl)

    return {
        'N': N, 'ln_N': lnN,
        'bTv': bTv, 'bTv_sq': bTv**2,
        'vt_G1_rational': vt_G1_v,
        'vt_G2_log': vt_G2_v,
        'vt_G3_cot': vt_G3_v,
        'vt_G4_base': vt_G4_v,
        'mean_deflation': mean_defl,
        'vt_C_v': vt_C_v,
        'Q_over_ln': Q / lnN,
        'sum_v': sum_v,
        'sum_v_over_k': sum_v_over_k,
        'pct_rational': abs(vt_G1_v)/total_abs*100,
        'pct_log': abs(vt_G2_v)/total_abs*100,
        'pct_cot': abs(vt_G3_v)/total_abs*100,
        'pct_base': abs(vt_G4_v)/total_abs*100,
        'pct_mean': abs(mean_defl)/total_abs*100,
    }

def _vasyunin_sum(a, b):
    if a <= 1:
        return 0.0
    total = 0.0
    for m in range(1, a):
        frac_part = (m * b % a) / a
        total += frac_part / math.tan(math.pi * m / a)
    return total


if __name__ == '__main__':
    print("═══ Attack 9: The Dimensional Autopsy ═══")
    print()

    Ns = [50, 100, 200, 500, 1000, 2000]
    results = []

    # Sieve μ for the largest N
    max_N = max(Ns)
    print(f"  Sieving μ(k) for k ≤ {max_N}...", flush=True)
    mu = mobius_sieve(max_N)
    sq_free = sum(1 for k in range(1, max_N+1) if mu[k] != 0)
    print(f"  {sq_free} squarefree integers (out of {max_N})")

    # PNT diagnostic
    for N in Ns:
        sum_mu_k = sum(mu[k] / k for k in range(1, N + 1))
        print(f"    Σμ(k)/k for k≤{N}: {sum_mu_k:.8f}")
    print()

    for N in Ns:
        t0 = time.time()
        print(f"  N={N:>5}...", end="", flush=True)
        r = dimensional_autopsy(N, mu)
        dt = time.time() - t0
        results.append(r)
        print(f" {dt:.1f}s  Q/ln={r['Q_over_ln']:.4f}")

    # ─── Tables ───
    print()
    print("═══ Dimensional Decomposition: v^T [component] v ═══")
    print(f"{'N':>6} {'Rational':>12} {'Log':>12} {'Cotangent':>12} {'Base':>12} {'Mean':>12} {'TOTAL':>12}")
    print("-" * 84)
    for r in results:
        print(f"{r['N']:>6} {r['vt_G1_rational']:>12.4e} {r['vt_G2_log']:>12.4e} "
              f"{r['vt_G3_cot']:>12.4e} {r['vt_G4_base']:>12.4e} "
              f"{r['mean_deflation']:>12.4e} {r['vt_C_v']:>12.4e}")

    print()
    print("═══ Percentage Contribution ═══")
    print(f"{'N':>6} {'%Rational':>10} {'%Log':>10} {'%Cot':>10} {'%Base':>10} {'%Mean':>10}")
    print("-" * 60)
    for r in results:
        print(f"{r['N']:>6} {r['pct_rational']:>9.2f}% {r['pct_log']:>9.2f}% "
              f"{r['pct_cot']:>9.2f}% {r['pct_base']:>9.2f}% {r['pct_mean']:>9.2f}%")

    print()
    print("═══ Rank-1 Kill Diagnostic ═══")
    print(f"{'N':>6} {'Σv_k':>12} {'Σv_k/k':>12} {'|G1|/|G3|':>12}")
    print("-" * 50)
    for r in results:
        ratio = abs(r['vt_G1_rational']) / abs(r['vt_G3_cot']) if r['vt_G3_cot'] != 0 else float('inf')
        print(f"{r['N']:>6} {r['sum_v']:>12.4f} {r['sum_v_over_k']:>12.8f} {ratio:>12.6f}")

    print()
    print("═══ Rayleigh Quotient ═══")
    print(f"{'N':>6} {'Q/ln(N)':>10} {'(b^Tv)^2':>12} {'v^TCv':>12}")
    print("-" * 40)
    for r in results:
        print(f"{r['N']:>6} {r['Q_over_ln']:>10.4f} {r['bTv_sq']:>12.4e} {r['vt_C_v']:>12.4e}")

    output = {
        'experiment': 'attack9_dimensional_autopsy',
        'hypothesis': 'Rational and Base dimensions flatline; RH lives in Log x Cot x Mean',
        'results': results
    }
    with open('/Users/jrgochan/code/github.com/jrgochan/prime/experiments/vasyunin/results_attack9.json', 'w') as f:
        json.dump(output, f, indent=2)
    print()
    print("  📄 Saved to experiments/vasyunin/results_attack9.json")
    print("  ✅ Attack 9 complete.")
