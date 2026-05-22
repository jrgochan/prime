#!/usr/bin/env python3
"""
Entanglement Probe: Zooming into the N≈800 crossover point.

Questions:
1. At what exact N does vᵀEv cross zero?
2. What is vᵀGv = vᵀRv at that resonance?
3. Which (j,k) pairs dominate the error?
4. Is there a functional relationship between vᵀEv and vᵀRv?
5. Does the ratio vᵀEv/vᵀRv stabilize?

The Thulium X-Ray showed:
  N=750:  vᵀEv = +0.046
  N=1000: vᵀEv = -0.061

Somewhere around N≈800, the error vanishes exactly.
"""

import math
from functools import lru_cache

EULER_GAMMA = 0.5772156649015329
PI = math.pi
LN2PI = math.log(2 * PI)

# ─── Arithmetic ───

def mobius_sieve(n):
    mu = [0] * (n + 1)
    mu[1] = 1
    is_prime = [True] * (n + 1)
    primes = []
    for p in range(2, n + 1):
        if is_prime[p]:
            primes.append(p)
            mu[p] = -1
        for p2 in primes:
            if p * p2 > n: break
            is_prime[p * p2] = False
            if p % p2 == 0:
                mu[p * p2] = 0
                break
            mu[p * p2] = -mu[p]
    return mu

@lru_cache(maxsize=None)
def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

# ─── Matrix entries ───

def vasyunin_sum(a, b):
    if a <= 1: return 0.0
    total = 0.0
    for m in range(1, a):
        frac = (m * b % a) / a
        angle = PI * m / a
        s, c = math.sin(angle), math.cos(angle)
        if abs(s) < 1e-15: continue
        total += frac * c / s
    return total

def gram_entry(j, k):
    jf, kf = float(j), float(k)
    if j == k:
        return (LN2PI - EULER_GAMMA) / kf - 1.0 / (kf * kf)
    d = gcd(j, k)
    jp, kp = j // d, k // d
    t1 = (LN2PI - EULER_GAMMA) / 2.0 * (1.0/jf + 1.0/kf)
    t2 = (jf - kf) / (2.0 * jf * kf) * math.log(kf / jf)
    t3 = PI * d / (2.0 * jf * kf) * (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp))
    t4 = 1.0 / (jf * kf)
    return t1 + t2 - t3 - t4

def ram_entry(j, k):
    d = gcd(j, k)
    return d * d / (12.0 * j * k)

# ─── Quadratic form ───

def compute_forms(mu, n):
    log_n = math.log(n)
    # Möbius-Fejér weights
    v = {}
    for k in range(1, n + 1):
        if mu[k] == 0: continue
        v[k] = -mu[k] * (1.0 - math.log(k) / log_n)
    
    vt_gv = 0.0
    vt_rv = 0.0
    for j in v:
        for k in v:
            vjvk = v[j] * v[k]
            vt_gv += vjvk * gram_entry(j, k)
            vt_rv += vjvk * ram_entry(j, k)
    
    vt_ev = vt_gv - vt_rv
    return vt_gv, vt_rv, vt_ev

# ─── Main ───

max_n = 1000
mu = mobius_sieve(max_n)

print("=" * 72)
print("  ENTANGLEMENT PROBE: The N≈800 Crossover")
print("=" * 72)
print()

# ═══════════════════════════════════════════════
# §1. Fine-grained zoom around the crossover
# ═══════════════════════════════════════════════

print("§1. CROSSOVER ZOOM: Finding exact N where vᵀEv = 0")
print()
print(f"{'N':>6} {'vᵀGv':>12} {'vᵀRv':>12} {'vᵀEv':>12} {'vᵀEv·lnN':>12} {'(Gv-1)·lnN':>12}")
print("─" * 72)

prev_ev = None
crossover_n = None

for n in list(range(600, 950, 10)) + list(range(950, 1001, 50)):
    vt_gv, vt_rv, vt_ev = compute_forms(mu, n)
    log_n = math.log(n)
    
    if prev_ev is not None and prev_ev > 0 and vt_ev <= 0 and crossover_n is None:
        # Linear interpolation to find the zero
        crossover_n = n - 10 + 10 * prev_ev / (prev_ev - vt_ev)
        marker = "  ← CROSSOVER"
    else:
        marker = ""
    
    print(f"{n:>6} {vt_gv:>12.8f} {vt_rv:>12.8f} {vt_ev:>12.8f} {vt_ev*log_n:>12.6f} {(vt_gv-1)*log_n:>12.6f}{marker}")
    prev_ev = vt_ev

if crossover_n:
    print(f"\n  ★ Estimated crossover at N ≈ {crossover_n:.1f}")
    print(f"    At crossover: vᵀGv = vᵀRv (exact resonance)")

# ═══════════════════════════════════════════════
# §2. Ratio analysis: Is there a functional relationship?
# ═══════════════════════════════════════════════

print()
print("=" * 72)
print("§2. FUNCTIONAL RELATIONSHIP: vᵀEv vs vᵀRv")
print("=" * 72)
print()

print(f"{'N':>6} {'vᵀRv':>12} {'vᵀEv':>12} {'E/R':>12} {'E+R=Gv':>12} {'1-Gv':>12} {'(1-Gv)·lnN':>12}")
print("─" * 80)

for n in [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]:
    vt_gv, vt_rv, vt_ev = compute_forms(mu, n)
    log_n = math.log(n)
    ratio = vt_ev / vt_rv if abs(vt_rv) > 1e-15 else float('nan')
    deficit = 1.0 - vt_gv
    
    print(f"{n:>6} {vt_rv:>12.8f} {vt_ev:>12.8f} {ratio:>12.6f} {vt_gv:>12.8f} {deficit:>12.8f} {deficit*log_n:>12.6f}")

# ═══════════════════════════════════════════════
# §3. Which (j,k) pairs dominate the error?
# ═══════════════════════════════════════════════

print()
print("=" * 72)
print("§3. ENTANGLEMENT ANATOMY: Which pairs drive the cancellation?")
print("=" * 72)
print()

for target_n in [500, 800]:
    n = target_n
    log_n = math.log(n)
    v = {}
    for k in range(1, n + 1):
        if mu[k] == 0: continue
        v[k] = -mu[k] * (1.0 - math.log(k) / log_n)
    
    # Compute per-pair contributions
    diag_g, diag_r, diag_e = 0.0, 0.0, 0.0
    off_g, off_r, off_e = 0.0, 0.0, 0.0
    
    # Track top contributors to vᵀEv
    pair_contribs = []
    
    for j in v:
        for k in v:
            vjvk = v[j] * v[k]
            g = gram_entry(j, k)
            r = ram_entry(j, k)
            e = g - r
            
            contrib = vjvk * e
            if j == k:
                diag_e += contrib
                diag_g += vjvk * g
                diag_r += vjvk * r
            else:
                off_e += contrib
                off_g += vjvk * g
                off_r += vjvk * r
            
            if j <= k:  # avoid double counting for display
                pair_contribs.append((j, k, vjvk * e * (1 if j == k else 2)))
    
    # Sort by absolute contribution
    pair_contribs.sort(key=lambda x: abs(x[2]), reverse=True)
    
    total_ev = diag_e + off_e
    
    print(f"  N = {n}:")
    print(f"    Diagonal:     E_diag = {diag_e:>12.8f} ({100*diag_e/total_ev if total_ev != 0 else 0:.1f}%)")
    print(f"    Off-diagonal: E_off  = {off_e:>12.8f} ({100*off_e/total_ev if total_ev != 0 else 0:.1f}%)")
    print(f"    Total:        E_tot  = {total_ev:>12.8f}")
    print()
    
    print(f"    Top 15 (j,k) pairs by |contribution to vᵀEv|:")
    print(f"    {'j':>5} {'k':>5} {'gcd':>4} {'contrib':>14} {'cumul%':>8}")
    print(f"    {'─'*40}")
    
    cumul = 0.0
    for j, k, c in pair_contribs[:15]:
        cumul += c
        d = gcd(j, k)
        pct = 100 * cumul / total_ev if total_ev != 0 else 0
        print(f"    {j:>5} {k:>5} {d:>4} {c:>14.8f} {pct:>7.1f}%")
    print()

# ═══════════════════════════════════════════════
# §4. The entanglement structure
# ═══════════════════════════════════════════════

print("=" * 72)
print("§4. THE ENTANGLEMENT EQUATION")
print("=" * 72)
print()

# Key insight: G_V(j,k) = E_log(j,k) + E_cot(j,k) + E_const(j,k)
# R(j,k) = G_V(j,k) - E_log - E_cot - E_const
# So vᵀGv = vᵀ(E_log)v + vᵀ(E_cot)v + vᵀ(E_const)v
# The question is: is vᵀGv < 1 provable from the structure of these terms?

# For the Möbius weights, compute:
# Σ v_j v_k / (jk) = (Σ v_k/k)² — this is a perfect square!

print("  Key structural observation:")
print()
print("  E_const(j,k) = -1/(jk)")
print("  ⟹ vᵀ E_const v = -Σ_{j,k} v_j v_k/(jk) = -(Σ v_k/k)²")
print("  This is ALWAYS NEGATIVE (a perfect square, negated).")
print()

for n in [100, 500, 800, 1000]:
    log_n = math.log(n)
    sum_vk_over_k = 0.0
    for k in range(1, n + 1):
        if mu[k] == 0: continue
        vk = -mu[k] * (1.0 - math.log(k) / log_n)
        sum_vk_over_k += vk / k
    
    e_const_qf = -sum_vk_over_k**2
    
    # Also compute via direct sum
    v = {}
    for k in range(1, n + 1):
        if mu[k] == 0: continue
        v[k] = -mu[k] * (1.0 - math.log(k) / log_n)
    
    e_const_direct = 0.0
    for j in v:
        for k in v:
            e_const_direct += v[j] * v[k] * (-1.0 / (j * k))
    
    print(f"  N={n:>5}: Σ v_k/k = {sum_vk_over_k:>12.8f}, "
          f"-(Σv/k)² = {e_const_qf:>12.8f}, "
          f"direct = {e_const_direct:>12.8f}, "
          f"match: {'✅' if abs(e_const_qf - e_const_direct) < 1e-10 else '❌'}")

print()
print("  The sum Σ μ(k)·(1-logk/logN)/k is related to M(N)/N (Mertens).")
print("  Under RH: M(N) = O(N^{1/2+ε}), so Σ μ(k)/k → 0 slowly.")
print()

# Also check: Σ v_j * v_k * (1/j + 1/k) = 2 * (Σ v_k) * (Σ v_k/k)
print("  E_log dominant term: (ln2π-γ)/2 · Σ v_j v_k (1/j+1/k)")
print("  = (ln2π-γ) · (Σ v_k) · (Σ v_k/k)")
print()

for n in [100, 500, 800, 1000]:
    log_n = math.log(n)
    sum_vk = 0.0
    sum_vk_over_k = 0.0
    for k in range(1, n + 1):
        if mu[k] == 0: continue
        vk = -mu[k] * (1.0 - math.log(k) / log_n)
        sum_vk += vk
        sum_vk_over_k += vk / k
    
    e_log_est = (LN2PI - EULER_GAMMA) * sum_vk * sum_vk_over_k
    
    # Direct computation
    v = {}
    for k in range(1, n + 1):
        if mu[k] == 0: continue
        v[k] = -mu[k] * (1.0 - math.log(k) / log_n)
    
    e_log_direct = 0.0
    for j in v:
        for k in v:
            jf, kf = float(j), float(k)
            if j == k:
                e_log_direct += v[j]**2 * (LN2PI - EULER_GAMMA) / kf
            else:
                t1 = (LN2PI - EULER_GAMMA) / 2.0 * (1.0/jf + 1.0/kf)
                t2 = (jf - kf) / (2.0*jf*kf) * math.log(kf/jf)
                e_log_direct += v[j] * v[k] * (t1 + t2)
    
    sigma = sum_vk  # σ = Σ v_k
    
    print(f"  N={n:>5}: σ = {sigma:>10.6f}, Σv/k = {sum_vk_over_k:>10.8f}, "
          f"E_log_est = {e_log_est:>10.6f}, E_log_direct = {e_log_direct:>10.6f}")

print()
print("=" * 72)
print("SUMMARY")  
print("=" * 72)
print()
print("The entanglement structure:")
print()
print("  vᵀGv = (ln2π-γ)·σ·S + [log correction] - π·[cot Dedekind] - S²")
print()
print("  where σ = Σv_k (→ 1 by Mertens), S = Σv_k/k (→ 0 by PNT)")
print()
print("  The -S² term (from E_const) is ALWAYS negative and provably")
print("  controls the approach to 1. The question is whether the")
print("  cotangent term cooperates.")
print()
print("★ The entanglement is in the COUPLING between σ and S.")
print("  Both are Möbius-weighted sums. Their product (ln2π-γ)·σ·S")
print("  must balance against the cotangent Dedekind correction")
print("  and the Ramanujan divergence.")
print("★")
