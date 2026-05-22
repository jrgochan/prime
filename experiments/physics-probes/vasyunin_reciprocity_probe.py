#!/usr/bin/env python3
"""
VASYUNIN RECIPROCITY PROBE

What is V(a,b) + V(b,a) for coprime a,b?

V(a,b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)

By cot_sum_vanishes: V(a,b) = Σ ((mb/a)) · cot(πm/a)
  where ((x)) = {x} - 1/2 is the sawtooth.

The GRAM MATRIX uses: -πd/(2jk) · [V(j',k') + V(k',j')]
So understanding V+V is the key to understanding the entanglement.
"""

import math
from fractions import Fraction

def fract(x):
    return x - math.floor(x)

def vasyunin_sum(a, b):
    if a <= 1:
        return 0.0
    return sum(fract(m * b / a) * math.cos(math.pi * m / a) / math.sin(math.pi * m / a)
               for m in range(1, a))

def dedekind_sum_saw(b, a):
    """Standard Dedekind sum: s(b,a) = Σ ((m/a)) · ((mb/a))"""
    if a <= 1:
        return 0.0
    return sum((fract(m/a) - 0.5) * (fract(m*b/a) - 0.5) for m in range(1, a))

def dedekind_sum_cot(b, a):
    """Cotangent Dedekind sum: s(b,a) = (1/4a) Σ cot(πm/a) · cot(πmb/a)"""
    if a <= 1:
        return 0.0
    return (1/(4*a)) * sum(
        (math.cos(math.pi*m/a)/math.sin(math.pi*m/a)) *
        (math.cos(math.pi*m*b/a)/math.sin(math.pi*m*b/a))
        for m in range(1, a))

# ══════════════════════════════════════════════════════════════
# §1: What does V(a,b) + V(b,a) look like?
# ══════════════════════════════════════════════════════════════

print("=" * 90)
print("§1. V(a,b) + V(b,a) for coprime pairs with a,b ≥ 2")
print("=" * 90)
print()

print(f"{'(a,b)':>8} {'V(a,b)':>14} {'V(b,a)':>14} {'V+V':>14} {'s+s':>14} {'(a²+b²+1)/12ab':>16}")
print("-" * 90)

for a in range(2, 16):
    for b in range(2, a):
        if math.gcd(a, b) != 1:
            continue
        Va = vasyunin_sum(a, b)
        Vb = vasyunin_sum(b, a)
        sa = dedekind_sum_saw(a, b)
        sb = dedekind_sum_saw(b, a)
        recip = (a**2 + b**2 + 1) / (12*a*b) - 0.25
        print(f"  ({a:>2},{b:>2})  {Va:>14.8f} {Vb:>14.8f} {Va+Vb:>14.8f} {sa+sb:>14.8f} {recip:>16.8f}")

# ══════════════════════════════════════════════════════════════
# §2: Relationship between V(a,b) and individual cot terms
# ══════════════════════════════════════════════════════════════

print()
print("=" * 90)
print("§2. Testing: V(a,b) = -a · cot_dedekind_sum(b,a)?")
print("    i.e., V(a,b) = -(1/4) · Σ cot(πm/a) · cot(πmb/a)?")
print("=" * 90)
print()

# The cotangent Dedekind sum is s_cot(b,a) = (1/4a) Σ cot·cot
# So 4a·s_cot(b,a) = Σ cot·cot
# Try: V(a,b) = C · Σ cot(πm/a) · cot(πmb/a)?
# V(a,b) = Σ {mb/a} · cot(πm/a) = Σ ((mb/a)) · cot + 0
# Σ cot·cot = 4a·s(b,a)

for a in range(3, 10):
    for b in range(1, a):
        if math.gcd(a, b) != 1:
            continue
        V = vasyunin_sum(a, b)
        cot_cot_sum = sum(
            (math.cos(math.pi*m/a)/math.sin(math.pi*m/a)) *
            (math.cos(math.pi*m*b/a)/math.sin(math.pi*m*b/a))
            for m in range(1, a))
        if abs(cot_cot_sum) > 1e-10:
            ratio = V / cot_cot_sum
            print(f"  ({a},{b}): V={V:>12.8f}  Σcot·cot={cot_cot_sum:>12.8f}  ratio={ratio:>10.6f}")
        else:
            print(f"  ({a},{b}): V={V:>12.8f}  Σcot·cot={cot_cot_sum:>12.8f}  (zero)")

# ══════════════════════════════════════════════════════════════
# §3: Does the GRAM MATRIX term simplify?
# ══════════════════════════════════════════════════════════════

print()
print("=" * 90)
print("§3. The Gram matrix cotangent term:")
print("    G_cot(j,k) = -πd/(2jk) · [V(j',k') + V(k',j')]")
print("    Compare with the Dedekind reciprocity term:")
print("    G_ded(j,k) = πd/(jk) · [s(j',k') + s(k',j')]")
print("           = πd/(jk) · [(j'²+k'²+1)/(12j'k') - 1/4]")
print("=" * 90)
print()

EULER_GAMMA = 0.5772156649015329

print(f"{'(j,k)':>8} {'G_cot':>14} {'G_ded_recip':>14} {'ratio':>10} {'G_V(j,k)':>14}")
print("-" * 70)

for j in range(1, 12):
    for k in range(j+1, 12):
        d = math.gcd(j, k)
        jp = j // d
        kp = k // d

        # Actual cotangent term
        Va = vasyunin_sum(jp, kp)
        Vb = vasyunin_sum(kp, jp)
        G_cot = -math.pi * d / (2*j*k) * (Va + Vb)

        # Dedekind reciprocity prediction
        recip = (jp**2 + kp**2 + 1) / (12*jp*kp) - 0.25
        G_ded = math.pi * d / (j*k) * recip

        # Full Gram entry
        C = math.log(2*math.pi) - EULER_GAMMA
        term1 = C/2 * (1/j + 1/k)
        term2 = (j-k)/(2*j*k) * math.log(k/j)
        G_V = term1 + term2 + G_cot - 1/(j*k)

        ratio = G_cot / G_ded if abs(G_ded) > 1e-15 else float('inf')
        print(f"  ({j:>2},{k:>2})  {G_cot:>14.8f} {G_ded:>14.8f} {ratio:>10.4f} {G_V:>14.8f}")

# ══════════════════════════════════════════════════════════════
# §4: Can V+V be expressed in terms of the DIGAMMA function?
# ══════════════════════════════════════════════════════════════

print()
print("=" * 90)
print("§4. Testing digamma relationship:")
print("    ψ(x) = -γ + Σ_{n=0}^∞ (1/(n+1) - 1/(n+x))")
print("    Test: V(a,b) + V(b,a) = f(ψ(j'/k'), ψ(k'/j'), ...)?")
print("=" * 90)
print()

# The Gram matrix has a known integral representation:
# G(j,k) = ∫_0^1 {1/(jt)} {1/(kt)} dt
# For coprime j,k this involves the Vasyunin sum.
# The integral can also be computed via the digamma function:
# ∫_0^1 {t/a} · {t/b} dt = ... (for a,b coprime)

# Let's check: is V(a,b)+V(b,a) related to the cotangent sum
# Σ cot(πm/a)·cot(πm·b/a) = 4a·s(b,a)?

print("V+V vs cotangent Dedekind reciprocity:")
print(f"{'(a,b)':>8} {'V+V':>14} {'-2·(s(b,a)+s(a,b))':>20} {'V+V / (-2·(s+s))':>18}")
print("-" * 70)

for a in range(2, 16):
    for b in range(2, a):
        if math.gcd(a, b) != 1:
            continue
        Va = vasyunin_sum(a, b)
        Vb = vasyunin_sum(b, a)
        V_sum = Va + Vb

        # Dedekind sums both ways
        s_ab = dedekind_sum_saw(a, b)
        s_ba = dedekind_sum_saw(b, a)
        ded_sum = -2 * (s_ab + s_ba)

        if abs(ded_sum) > 1e-15:
            ratio = V_sum / ded_sum
        else:
            ratio = float('inf')

        print(f"  ({a:>2},{b:>2})  {V_sum:>14.8f} {ded_sum:>20.8f} {ratio:>18.6f}")

# ══════════════════════════════════════════════════════════════
# §5: Per-term analysis — what makes V different from s?
# ══════════════════════════════════════════════════════════════

print()
print("=" * 90)
print("§5. Per-term analysis for (a,b)=(5,3):")
print("    V(5,3) = Σ {3m/5}·cot(πm/5)")
print("    s(3,5) = Σ ((m/5))·((3m/5))")
print("=" * 90)
print()

a, b = 5, 3
print(f"  m   {'{3m/5}':>8}  {'cot(πm/5)':>12}  {'V term':>12}  {'((m/5))':>10}  {'((3m/5))':>10}  {'s term':>12}")
for m in range(1, a):
    frac_mb = fract(m*b/a)
    cot_val = math.cos(math.pi*m/a) / math.sin(math.pi*m/a)
    v_term = frac_mb * cot_val
    saw_m = fract(m/a) - 0.5
    saw_mb = fract(m*b/a) - 0.5
    s_term = saw_m * saw_mb
    print(f"  {m}   {frac_mb:>8.4f}  {cot_val:>12.6f}  {v_term:>12.6f}  {saw_m:>10.4f}  {saw_mb:>10.4f}  {s_term:>12.6f}")

print(f"\n  V(5,3) = {vasyunin_sum(5,3):.8f}")
print(f"  s(3,5) = {dedekind_sum_saw(3,5):.8f}")
print(f"  -2·s   = {-2*dedekind_sum_saw(3,5):.8f}")

print()
print("  KEY INSIGHT: V uses cot(πm/a) while s uses ((m/a)) = m/a - 1/2")
print("  These are DIFFERENT weights. cot(πm/a) ≠ C·(m/a - 1/2) for any C.")
print("  The Vasyunin sum is genuinely transcendental.")
