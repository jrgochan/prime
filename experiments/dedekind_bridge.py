"""
Dedekind Bridge: Exploring G_V(j,k) - R(j,k)

The Vasyunin Gram entry G_V(j,k) and the Ramanujan entry R(j,k) differ
by cotangent sums related to Dedekind sums. This script computes the
exact difference and connects it to the Dedekind reciprocity law.

Key identity (Dedekind reciprocity):
  s(a,b) + s(b,a) = (a² + b² + 1)/(12ab) - 1/4

where s(b,a) = (1/4a) Σ_{m=1}^{a-1} cot(πm/a)·cot(πmb/a)
"""

import numpy as np
from math import gcd, log, pi, cos, sin, floor
from fractions import Fraction

# Euler-Mascheroni constant
GAMMA = 0.5772156649015329

def frac(x):
    """Fractional part {x}"""
    return x - floor(x)

def cot(x):
    """Cotangent"""
    return cos(x) / sin(x)

def dedekind_sum(b, a):
    """Classical Dedekind sum s(b,a) = (1/4a) Σ cot(πm/a)·cot(πmb/a)"""
    if a <= 1:
        return 0.0
    return sum(cot(pi*m/a) * cot(pi*m*b/a) for m in range(1, a)) / (4*a)

def vasyunin_sum(a, b):
    """V(a,b) = Σ_{m=1}^{a-1} {mb/a}·cot(πm/a)"""
    if a <= 1:
        return 0.0
    return sum(frac(m*b/a) * cot(pi*m/a) for m in range(1, a))

def ramanujan_entry(j, k):
    """R(j,k) = gcd(j,k)² / (12jk)"""
    d = gcd(j, k)
    return d**2 / (12 * j * k)

def vasyunin_gram_entry(j, k):
    """Exact Vasyunin formula for G_V(j,k)"""
    d = gcd(j, k)
    jp, kp = j // d, k // d
    
    if j == k:
        return (log(2*pi) - GAMMA) / j - 1 / j**2
    
    term1 = (log(2*pi) - GAMMA) / 2 * (1/j + 1/k)
    term2 = (j - k) / (2*j*k) * log(k/j)
    term3 = pi * d / (2*j*k) * (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp))
    term4 = 1 / (j*k)
    
    return term1 + term2 - term3 - term4

# ═══════════════════════════════════════════════
# §1. NUMERICAL COMPARISON: G_V vs R
# ═══════════════════════════════════════════════

print("=" * 70)
print("§1. G_V(j,k) vs R(j,k) for small j,k")
print("=" * 70)
print(f"{'(j,k)':>8}  {'G_V':>12}  {'R':>12}  {'G_V-R':>12}  {'R+1/4':>12}  {'G_V-(R+1/4)':>12}")
print("-" * 70)

for j in range(1, 7):
    for k in range(j, 7):
        gv = vasyunin_gram_entry(j, k)
        r = ramanujan_entry(j, k)
        rp = r + 0.25
        print(f"({j},{k}){'':<3}  {gv:12.8f}  {r:12.8f}  {gv-r:12.8f}  {rp:12.8f}  {gv-rp:12.8f}")

# ═══════════════════════════════════════════════
# §2. DEDEKIND SUM VERIFICATION
# ═══════════════════════════════════════════════

print("\n" + "=" * 70)
print("§2. Dedekind Reciprocity: s(a,b) + s(b,a) = (a²+b²+1)/(12ab) - 1/4")
print("=" * 70)

for a in range(2, 10):
    for b in range(1, a):
        if gcd(a, b) != 1:
            continue
        s_ab = dedekind_sum(a, b)
        s_ba = dedekind_sum(b, a)
        lhs = s_ab + s_ba
        rhs = (a**2 + b**2 + 1) / (12*a*b) - 0.25
        print(f"  s({a},{b})+s({b},{a}) = {lhs:10.8f},  "
              f"(a²+b²+1)/(12ab)-1/4 = {rhs:10.8f},  "
              f"error = {abs(lhs-rhs):.2e}")

# ═══════════════════════════════════════════════
# §3. THE KEY CONNECTION: G_V - R in Dedekind terms
# ═══════════════════════════════════════════════

print("\n" + "=" * 70)
print("§3. Decomposing G_V - R")
print("=" * 70)
print()
print("G_V(j,k) = (ln2π-γ)/2·(1/j+1/k) + (j-k)/(2jk)·ln(k/j)")
print("         - πd/(2jk)·(V(j',k')+V(k',j')) - 1/(jk)")
print()
print("R(j,k) = gcd²/(12jk) = 1/(12j'k')")
print()
print("So G_V - R = [log terms] - [πd/(2jk)]·[V+V] - [1/jk] - [1/(12j'k')]")
print()

# For coprime j',k', check if V(j',k')+V(k',j') relates to Dedekind
print(f"{'(j,k)':>8}  {'V+V':>12}  {'πd/(2jk)·(V+V)':>16}  {'s+s':>12}  {'(a²+b²+1)/(12ab)':>18}")
print("-" * 70)

for j in range(1, 8):
    for k in range(j+1, 8):
        d = gcd(j, k)
        jp, kp = j // d, k // d
        
        vpv = vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp)
        sps = dedekind_sum(jp, kp) + dedekind_sum(kp, jp)
        recip = (jp**2 + kp**2 + 1) / (12*jp*kp)
        coeff = pi * d / (2*j*k)
        
        print(f"({j},{k}){'':<3}  {vpv:12.8f}  {coeff*vpv:16.8f}  "
              f"{sps:12.8f}  {recip:18.8f}")

# ═══════════════════════════════════════════════
# §4. THE CORRECTION MATRIX: G_V - R - 1/4
# ═══════════════════════════════════════════════

print("\n" + "=" * 70)
print("§4. What is G_V(j,k) - R(j,k) - 1/4 exactly?")
print("=" * 70)
print()
print("If G_V ≈ R + 1/4 + correction, what is the correction?")
print()
print(f"{'(j,k)':>8}  {'correction':>12}  {'-1/(2j)-1/(2k)':>16}  {'remaining':>12}")
print("-" * 70)

for j in range(1, 8):
    for k in range(j, 8):
        gv = vasyunin_gram_entry(j, k)
        r = ramanujan_entry(j, k)
        corr = gv - r - 0.25
        mean_corr = -1/(2*j) - 1/(2*k)
        remaining = corr - mean_corr
        print(f"({j},{k}){'':<3}  {corr:12.8f}  {mean_corr:16.8f}  {remaining:12.8f}")

# ═══════════════════════════════════════════════
# §5. HYPOTHESIS: G_V = R + 1/4 - 1/(2j) - 1/(2k) + ?
# ═══════════════════════════════════════════════

print("\n" + "=" * 70)
print("§5. Testing: G_V = R + 1/4 - 1/(2j) - 1/(2k) + log_correction?")
print("=" * 70)
print()

print(f"{'(j,k)':>8}  {'remaining':>12}  {'(ln2π-γ-1)/2·(1/j+1/k)':>24}  {'diff':>12}")
print("-" * 70)

C = (log(2*pi) - GAMMA - 1) / 2  # This constant might work

for j in range(1, 8):
    for k in range(j, 8):
        gv = vasyunin_gram_entry(j, k)
        r = ramanujan_entry(j, k)
        corr = gv - r - 0.25
        mean_corr = -1/(2*j) - 1/(2*k)
        remaining = corr - mean_corr
        
        # Try log correction
        log_term = C * (1/j + 1/k)
        diff = remaining - log_term
        
        if j == k:
            # Diagonal: different formula
            log_term_diag = (log(2*pi) - GAMMA)/j - 1/j**2 - 1/(12*j**2) - 0.25 + 1/j
            diff_diag = gv - (r + 0.25 - 1/j + log_term)
        
        print(f"({j},{k}){'':<3}  {remaining:12.8f}  {log_term:24.8f}  {diff:12.8f}")

# ═══════════════════════════════════════════════
# §6. EXACT FORMULA CHECK
# ═══════════════════════════════════════════════

print("\n" + "=" * 70)
print("§6. Exact decomposition of G_V(j,k)")
print("=" * 70)
print()
print("Hypothesis: G_V(j,k) = R(j,k) + b(j)·b(k) - b(j)/k - b(k)/j + correction")
print("where b(k) = vasyuninMeanEntry(k) = (ln(k)+1-γ)/k")
print()

def mean_entry(k):
    return (log(k) + 1 - GAMMA) / k

print(f"{'(j,k)':>8}  {'G_V':>12}  {'R+b·b-b/k-b/j':>16}  {'diff':>12}")
print("-" * 70)

for j in range(1, 8):
    for k in range(j, 8):
        gv = vasyunin_gram_entry(j, k)
        r = ramanujan_entry(j, k)
        bj = mean_entry(j)
        bk = mean_entry(k)
        
        # Try: G_V = R + bj*bk (rank-1 from mean)
        approx = r + bj * bk
        diff = gv - approx
        print(f"({j},{k}){'':<3}  {gv:12.8f}  {approx:16.8f}  {diff:12.8f}")
