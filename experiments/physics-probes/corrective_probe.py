#!/usr/bin/env python3
"""
CORRECTIVE PROBE: What IS V(a,b) in terms of known quantities?

The identity V(a,b) = -2·s(b,a) is FALSE.
We need to find the CORRECT relationship.

V(a,b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)
s(b,a) = Σ_{m=1}^{a-1} ((m/a)) · ((mb/a))

Via cot_sum_vanishes:
  V(a,b) = Σ ((mb/a)) · cot(πm/a)     [since {x} = ((x)) + 1/2 and Σcot = 0]

This is a HYBRID sum: cotangent in first factor, sawtooth in second.
The standard Dedekind sum has sawtooth · sawtooth.
The cotangent Dedekind sum is (1/4a) · Σ cot · cot.

Key question: What is V(a,b) + V(b,a)?
Is it still a closed-form expression?
"""

import math

def fract(x):
    return x - math.floor(x)

def sawtooth(x):
    return fract(x) - 0.5

def vasyunin_sum(a, b):
    if a <= 1:
        return 0.0
    return sum(fract(m * b / a) * (math.cos(math.pi * m / a) / math.sin(math.pi * m / a))
               for m in range(1, a))

def dedekind_sum(b, a):
    if a <= 1:
        return 0.0
    return sum(sawtooth(m / a) * sawtooth(m * b / a) for m in range(1, a))

def dedekind_cot(b, a):
    """Cotangent form: s_cot(b,a) = (1/4a) Σ cot(πm/a) · cot(πmb/a)"""
    if a <= 1:
        return 0.0
    return (1 / (4 * a)) * sum(
        (math.cos(math.pi * m / a) / math.sin(math.pi * m / a)) *
        (math.cos(math.pi * m * b / a) / math.sin(math.pi * m * b / a))
        for m in range(1, a))

print("=" * 80)
print("CORRECTIVE PROBE: Finding the TRUE identity for V(a,b)")
print("=" * 80)
print()

# First verify: s(b,a) sawtooth = s(b,a) cotangent?
print("§1. Verify s_sawtooth = s_cotangent")
print("-" * 50)
for a in range(2, 12):
    for b in range(1, 12):
        if math.gcd(a, b) != 1:
            continue
        s_saw = dedekind_sum(b, a)
        s_cot = dedekind_cot(b, a)
        err = abs(s_saw - s_cot)
        if err > 1e-10:
            print(f"  ({a},{b}): s_saw={s_saw:.8f} s_cot={s_cot:.8f} err={err:.2e} ❌")
        elif a <= 6:
            print(f"  ({a},{b}): s_saw={s_saw:.8f} s_cot={s_cot:.8f} err={err:.2e} ✅")
print()

# Now: what IS V(a,b)?
# V(a,b) = Σ {mb/a} · cot(πm/a) = Σ ((mb/a)) · cot(πm/a) + 0
# Let's try: V(a,b) = C · s_cot(b,a) for some constant C?
print("§2. Test V(a,b) / s(b,a) ratio")
print("-" * 50)
print(f"{'(a,b)':>10} {'V(a,b)':>14} {'s(b,a)':>14} {'V/s':>10} {'4a·s_cot':>14}")
for a in range(3, 12):
    for b in range(1, a):
        if math.gcd(a, b) != 1:
            continue
        V = vasyunin_sum(a, b)
        s = dedekind_sum(b, a)
        s_c = dedekind_cot(b, a)
        ratio = V / s if abs(s) > 1e-15 else float('inf')
        four_a_s = 4 * a * s_c
        print(f"  ({a},{b})  {V:>14.8f} {s:>14.8f} {ratio:>10.4f} {four_a_s:>14.8f}")
print()

# Key question: V(a,b) + V(b,a) for coprime a,b ≥ 2
print("§3. V(a,b) + V(b,a) — is there a closed form?")
print("-" * 80)
print(f"{'(a,b)':>10} {'V(a,b)':>12} {'V(b,a)':>12} {'V+V':>12} {'a/b+b/a-2':>12} {'(a²+b²+1)/6ab-1/2':>18}")
for a in range(2, 15):
    for b in range(2, a):
        if math.gcd(a, b) != 1:
            continue
        Va = vasyunin_sum(a, b)
        Vb = vasyunin_sum(b, a)
        V_sum = Va + Vb
        # Guess 1: a/b + b/a - 2
        guess1 = a/b + b/a - 2
        # Guess 2: closed form from reciprocity (our old claim)
        guess2 = -(a**2 + b**2 + 1) / (6*a*b) + 0.5
        print(f"  ({a},{b})  {Va:>12.8f} {Vb:>12.8f} {V_sum:>12.8f} {guess1:>12.8f} {guess2:>18.8f}")
print()

# Let's try to find the pattern by looking at V(a,b) + V(b,a) more carefully
print("§4. Searching for the V+V identity")
print("-" * 80)
# Try: does V(a,b) + V(b,a) = f(a,b) for some rational f?
# Let's compute V+V for many pairs and see if we can spot a pattern
print(f"{'(a,b)':>10} {'V+V':>14} {'V+V * 6ab':>14} {'a²+b²+1':>12} {'3ab':>8}")
for a in range(2, 20):
    for b in range(2, a):
        if math.gcd(a, b) != 1:
            continue
        Va = vasyunin_sum(a, b)
        Vb = vasyunin_sum(b, a)
        V_sum = Va + Vb
        scaled = V_sum * 6 * a * b
        ab_sq = a**2 + b**2 + 1
        three_ab = 3 * a * b
        if a <= 10:
            print(f"  ({a:>2},{b:>2})  {V_sum:>14.8f} {scaled:>14.4f} {ab_sq:>12} {three_ab:>8}")
print()

# Another approach: try V(a,b) = -a · cot_dedekind · 2 ?
# i.e., V(a,b) = -2 * (4a * s_cot(b,a)) / (4) = -2a * s_cot(b,a)?
# V(a,b) = something involving cot form of s
print("§5. Testing V(a,b) = -2·(2a)·s_cot(b,a) = -4a·s_cot(b,a)?")
print("-" * 50)
for a in range(3, 12):
    for b in range(1, a):
        if math.gcd(a, b) != 1:
            continue
        V = vasyunin_sum(a, b)
        s_c = dedekind_cot(b, a)
        predicted = -4 * a * s_c
        err = abs(V - predicted)
        if a <= 8:
            status = "✅" if err < 1e-10 else f"❌ err={err:.4e}"
            print(f"  ({a},{b}): V={V:>12.8f}  -4a·s_cot={predicted:>12.8f}  {status}")
print()

# Since s_cot = s_saw, and V ≠ -2s, maybe V = -4a·s?
print("§6. Testing V(a,b) = -4a·s(b,a)?")
print("-" * 50)
for a in range(3, 12):
    for b in range(1, a):
        if math.gcd(a, b) != 1:
            continue
        V = vasyunin_sum(a, b)
        s = dedekind_sum(b, a)
        predicted = -4 * a * s
        err = abs(V - predicted)
        if a <= 8:
            status = "✅" if err < 1e-10 else f"❌ err={err:.4e}"
            print(f"  ({a},{b}): V={V:>12.8f}  -4a·s={predicted:>12.8f}  {status}")
