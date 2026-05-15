"""
═══════════════════════════════════════════════════════════════
Li's CRITERION — FAST Rust-powered computation
═══════════════════════════════════════════════════════════════

RH ⟺ λₙ ≥ 0 for all n ≥ 1

Key insight we discovered in the math:
  For zeros ON the critical line (ρ = 1/2 + iγ):
    |1 - 1/ρ| = 1  (unit magnitude!)
    each term contributes 2(1 - cos(n·αₖ)) ≥ 0

  So RH → each individual term ≥ 0 → λₙ ≥ 0.
  An off-line zero would have |1 - 1/ρ| ≠ 1, causing
  exponential growth/decay that eventually makes λₙ < 0.
"""

import numpy as np
import core_engine
import time

print("=" * 72)
print("Li's CRITERION: Rust-powered computation")
print("=" * 72)

# ═══════════════════════════════════════════
# STEP 1: Validate zero finding
# ═══════════════════════════════════════════
print("\n▓▓▓ STEP 1: Validate Hardy Z-function zeros ▓▓▓\n")

known_zeros = [14.134725, 21.022040, 25.010858, 30.424876, 32.935062,
               37.586178, 40.918719, 43.327073, 48.005151, 49.773832]

# Find zeros up to t = 100
t0 = time.time()
n_zeros, lambdas, zeros = core_engine.li_coeffs(1, 100.0)
dt = time.time() - t0
print(f"  Found {n_zeros} zeros up to t = 100 in {dt:.3f}s")
print(f"  First 10 zeros found vs known:")
for i in range(min(10, len(zeros))):
    known = known_zeros[i] if i < len(known_zeros) else 0
    err = abs(zeros[i] - known) if i < len(known_zeros) else 0
    print(f"    γ_{i+1:2d} = {zeros[i]:12.6f}  (known: {known:12.6f}, err: {err:.2e})")

# ═══════════════════════════════════════════
# STEP 2: Compute λ₁ through λ₅₀₀
# ═══════════════════════════════════════════
print(f"\n\n▓▓▓ STEP 2: Li coefficients λ₁ through λ₅₀₀ ▓▓▓\n")

# Use zeros up to t = 1000 for better accuracy
t0 = time.time()
n_zeros, lambdas, zeros = core_engine.li_coeffs(500, 1000.0)
dt = time.time() - t0
print(f"  Found {n_zeros} zeros up to t = 1000 in {dt:.3f}s")
print(f"  Computed 500 Li coefficients\n")

# Known asymptotic: λₙ ~ (n/2)·ln(n/(2πe)) + c·n/2
gamma_euler = 0.5772156649015329
c_asymp = 1 + gamma_euler/2 - np.log(2*np.pi)/2

print(f"  {'n':>6s} {'λₙ':>15s} {'λₙ/n':>10s} {'asymp/n':>10s} {'ratio':>8s} {'≥0?':>5s}")
print("  " + "-" * 60)

all_positive = True
for n in list(range(1, 21)) + list(range(25, 101, 5)) + list(range(100, 501, 50)):
    if n > len(lambdas): break
    lam = lambdas[n-1]
    per_n = lam / n
    asymp = n/2 * np.log(n / (2*np.pi*np.e)) + c_asymp * n / 2
    asymp_per_n = asymp / n
    ratio = lam / asymp if abs(asymp) > 1e-15 else float('inf')
    pos = "✓" if lam >= 0 else "✗ FAIL!"
    if lam < 0: all_positive = False
    print(f"  {n:6d} {lam:15.6f} {per_n:10.6f} {asymp_per_n:10.6f} "
          f"{ratio:8.4f} {pos}")

# ═══════════════════════════════════════════
# STEP 3: Structure analysis
# ═══════════════════════════════════════════
print(f"\n\n▓▓▓ STEP 3: Structural analysis ▓▓▓\n")

# Decompose λₙ = A(n) + B(n)
# A(n) = main asymptotic term (ALWAYS positive for n ≥ some N₀)
# B(n) = correction
print("  Decomposition: λₙ = A(n) + B(n)")
print(f"  {'n':>6s} {'A(n)':>12s} {'B(n)':>12s} {'|B|/A':>10s} {'B bounded?':>10s}")
print("  " + "-" * 52)

max_B_over_A = 0
for n in list(range(1, 21)) + [30, 50, 100, 200, 500]:
    if n > len(lambdas): break
    lam = lambdas[n-1]
    A = n/2 * (np.log(n/(2*np.pi)) - 1 + gamma_euler/2)
    B = lam - A
    ratio_ba = abs(B) / abs(A) if abs(A) > 1e-15 else float('inf')
    max_B_over_A = max(max_B_over_A, ratio_ba) if ratio_ba < 100 else max_B_over_A
    print(f"  {n:6d} {A:12.6f} {B:+12.6f} {ratio_ba:10.4f}")

print(f"\n  Max |B|/A ratio: {max_B_over_A:.4f}")

# ═══════════════════════════════════════════
# STEP 4: The KEY insight — individual contributions
# ═══════════════════════════════════════════
print(f"\n\n▓▓▓ STEP 4: Individual zero contributions to λₙ ▓▓▓\n")
print("  Each zero ρₖ = 1/2 + iγₖ contributes 2(1 - cos(n·αₖ))")
print("  where αₖ = π - 2·arctan(2γₖ)\n")

# Show the angles
print(f"  {'k':>4s} {'γₖ':>12s} {'αₖ':>12s} {'αₖ/π':>10s} {'contrib(n=1)':>12s}")
print("  " + "-" * 55)

for k in range(min(20, len(zeros))):
    gamma = zeros[k]
    alpha = np.pi - 2 * np.arctan(2 * gamma)
    contrib = 2 * (1 - np.cos(alpha))
    print(f"  {k+1:4d} {gamma:12.6f} {alpha:12.8f} {alpha/np.pi:10.6f} {contrib:12.8f}")

# ═══════════════════════════════════════════
# STEP 5: Convergence of λₙ with more zeros
# ═══════════════════════════════════════════
print(f"\n\n▓▓▓ STEP 5: Convergence with number of zeros ▓▓▓\n")
print("  How many zeros do we need for accurate λₙ?")
print(f"  {'T_max':>8s} {'n_zeros':>8s} {'λ₁':>12s} {'λ₁₀':>12s} "
      f"{'λ₅₀':>12s} {'λ₁₀₀':>12s} {'time':>8s}")
print("  " + "-" * 72)

for t_max in [100, 500, 1000, 5000, 10000]:
    t0 = time.time()
    nz, lams, _ = core_engine.li_coeffs(100, t_max)
    dt = time.time() - t0
    print(f"  {t_max:8.0f} {nz:8d} {lams[0]:12.8f} {lams[9]:12.8f} "
          f"{lams[49]:12.6f} {lams[99]:12.6f} {dt:8.3f}s")

# ═══════════════════════════════════════════
# STEP 6: GO BIG — λₙ up to n = 10000
# ═══════════════════════════════════════════
print(f"\n\n▓▓▓ STEP 6: Large-scale — λₙ up to n = 10000 ▓▓▓\n")

t0 = time.time()
n_zeros, big_lambdas, _ = core_engine.li_coeffs(10000, 10000.0)
dt = time.time() - t0
print(f"  Found {n_zeros} zeros, computed 10000 Li coefficients in {dt:.1f}s\n")

# Check all positive
min_lambda = min(big_lambdas)
min_idx = big_lambdas.index(min_lambda)
all_pos = all(l >= 0 for l in big_lambdas)
print(f"  All λ₁...λ₁₀₀₀₀ positive: {'YES ✓' if all_pos else 'NO ✗'}")
print(f"  Minimum λₙ: λ_{min_idx+1} = {min_lambda:.10f}")
print(f"  λ₁ = {big_lambdas[0]:.10f}")
print(f"  λ₁₀₀₀₀ = {big_lambdas[-1]:.6f}")

# Sample values
print(f"\n  {'n':>8s} {'λₙ':>18s} {'λₙ/n':>12s} {'≥0?':>5s}")
print("  " + "-" * 48)
for n in [1, 2, 5, 10, 50, 100, 500, 1000, 2000, 5000, 10000]:
    lam = big_lambdas[n-1]
    print(f"  {n:8d} {lam:18.8f} {lam/n:12.6f} {'✓' if lam >= 0 else '✗'}")

print(f"\n\n▓▓▓ SUMMARY ▓▓▓\n")
print(f"  Li's criterion: RH ⟺ λₙ ≥ 0 for all n")
print(f"  Verified: λ₁ through λ₁₀₀₀₀ ALL POSITIVE ✓" if all_pos else
      f"  FOUND NEGATIVE λₙ — would disprove RH!")
print(f"\n  Key structural insight:")
print(f"  Each on-line zero contributes 2(1-cos(n·αₖ)) ≥ 0")
print(f"  An off-line zero would contribute terms growing as |1-1/ρ|ⁿ")
print(f"  → eventually overwhelms the bounded on-line contributions")
print(f"  → λₙ < 0 for large enough n")
print(f"\n  The positivity of λₙ is EQUIVALENT to all zeros being on-line.")
