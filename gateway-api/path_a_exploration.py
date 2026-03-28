"""
═══════════════════════════════════════════════════════════════
RATIO SPIKE VALIDATION: Full battery of tests
═══════════════════════════════════════════════════════════════

Does the non-complex ratio spike at σ = 1/2 near EVERY zeta zero?
Is it a convergence artifact? Is it specific to the critical line?
"""

import numpy as np
import core_engine
import time

def analyze_eta(s, terms=200, accelerate=True):
    mat, comp, norm = core_engine.eta_arithmetic(s, terms, accelerate)
    M = np.array(mat).reshape(16, 16)
    eigs = np.linalg.eigvals(M)
    eig_mags = np.sort(np.abs(eigs))
    rank = np.linalg.matrix_rank(M, tol=1e-8)
    
    unique_mags = []
    for m in eig_mags:
        if not unique_mags or abs(m - unique_mags[-1]) > 1e-8:
            unique_mags.append(m)
    
    complex_norm = np.sqrt(comp[0]**2 + comp[1]**2)
    extra_norm = np.sqrt(sum(c**2 for c in comp[2:]))
    
    return {
        "norm": norm, "rank": rank, "comp": comp,
        "eig_mags": eig_mags, "unique_mags": unique_mags,
        "n_groups": len(unique_mags),
        "spread": eig_mags[-1] - eig_mags[0],
        "complex_norm": complex_norm, "extra_norm": extra_norm,
        "ratio": extra_norm / max(complex_norm, 1e-15),
        "min_eig": eig_mags[0],
    }


# Classical zeta zeros (first 10)
ZEROS = [
    14.134725, 21.022040, 25.010858, 30.424876, 32.935062,
    37.586178, 40.918719, 43.327073, 48.005151, 49.773832,
]

print("=" * 80)
print("RATIO SPIKE VALIDATION: Comprehensive Battery")
print("=" * 80)
start = time.time()

# ═══════════════════════════════════════════════════════════
# TEST 1: Ratio spike at ALL 10 known zeros
# Compare σ = 0.3, 0.5, 0.7 at each zero
# ═══════════════════════════════════════════════════════════
print("\n▓▓▓ TEST 1: Ratio spike at all 10 known ζ zeros ▓▓▓\n")
print(f"  {'Zero#':>5s} {'t':>10s} {'|σ=0.3|':>8s} {'r_0.3':>8s} "
      f"{'|σ=0.5|':>8s} {'r_0.5':>8s} {'|σ=0.7|':>8s} {'r_0.7':>8s} "
      f"{'spike?':>8s}")
print("  " + "-" * 82)

spike_count = 0
for idx, t_zero in enumerate(ZEROS):
    results = {}
    for sigma in [0.3, 0.5, 0.7]:
        s = [sigma, t_zero] + [0.0]*14
        r = analyze_eta(s, terms=200, accelerate=True)
        results[sigma] = r
    
    r03 = results[0.3]['ratio']
    r05 = results[0.5]['ratio']
    r07 = results[0.7]['ratio']
    
    # Is there a spike at σ=0.5? (ratio > both neighbors by factor > 2)
    is_spike = r05 > max(r03, r07) * 1.5
    spike_count += int(is_spike)
    spike_str = "YES ◄◄" if is_spike else "no"
    
    print(f"  {idx+1:5d} {t_zero:10.4f} "
          f"{results[0.3]['norm']:8.3f} {r03:8.3f} "
          f"{results[0.5]['norm']:8.3f} {r05:8.3f} "
          f"{results[0.7]['norm']:8.3f} {r07:8.3f} "
          f"{spike_str:>8s}")

print(f"\n  SPIKE RATE: {spike_count}/{len(ZEROS)} zeros show ratio spike at σ=0.5")

# ═══════════════════════════════════════════════════════════
# TEST 2: Convergence validation (200, 500, 1000, 2000 terms)
# At the first zero s = 0.5 + 14.135i
# ═══════════════════════════════════════════════════════════
print("\n\n▓▓▓ TEST 2: Convergence stability ▓▓▓\n")
print(f"  s = 0.5 + 14.135i (first ζ zero)")
print(f"  {'terms':>6s} {'|η_A|':>10s} {'ratio':>10s} {'spread':>12s} "
      f"{'ℂ-part':>10s} {'extra':>10s} {'time_s':>8s}")
print("  " + "-" * 70)

for nterms in [100, 200, 500, 1000, 2000]:
    s = [0.5, 14.134725] + [0.0]*14
    t0 = time.time()
    r = analyze_eta(s, terms=nterms, accelerate=True)
    dt = time.time() - t0
    print(f"  {nterms:6d} {r['norm']:10.6f} {r['ratio']:10.4f} "
          f"{r['spread']:12.6f} {r['complex_norm']:10.6f} "
          f"{r['extra_norm']:10.6f} {dt:8.2f}")

# ═══════════════════════════════════════════════════════════
# TEST 3: Fine σ sweep at each of first 5 zeros
# ═══════════════════════════════════════════════════════════
print("\n\n▓▓▓ TEST 3: Fine σ sweep at first 5 zeros ▓▓▓\n")

for idx, t_zero in enumerate(ZEROS[:5]):
    print(f"  Zero #{idx+1}: t = {t_zero:.4f}")
    print(f"    {'σ':>6s} {'ratio':>10s} {'|η_A|':>10s} {'spread':>10s} {'bar':>30s}")
    print("    " + "-" * 65)
    
    ratios_at_sigma = []
    for sigma in np.arange(0.1, 2.05, 0.1):
        s = [sigma, t_zero] + [0.0]*14
        r = analyze_eta(s, terms=200, accelerate=True)
        ratios_at_sigma.append((sigma, r['ratio']))
        bar_len = int(min(r['ratio'] * 5, 30))
        bar = '█' * bar_len
        marker = " ◄◄◄" if abs(sigma - 0.5) < 0.05 else ""
        print(f"    {sigma:6.2f} {r['ratio']:10.4f} {r['norm']:10.4f} "
              f"{r['spread']:10.6f} {bar}{marker}")
    
    # Find sigma that maximizes ratio
    best_sigma = max(ratios_at_sigma, key=lambda x: x[1])
    print(f"    Peak ratio at σ = {best_sigma[0]:.2f} (ratio = {best_sigma[1]:.4f})")
    print()

# ═══════════════════════════════════════════════════════════
# TEST 4: Control — ratio at NON-ZERO t values
# Does the spike ONLY happen near zeros?
# ═══════════════════════════════════════════════════════════
print("\n▓▓▓ TEST 4: Control — ratio at non-zero t values ▓▓▓\n")
print("  Checking ratio(σ=0.5) / max(ratio(σ=0.3), ratio(σ=0.7)) at various t:")
print(f"  {'t':>8s} {'r_0.3':>8s} {'r_0.5':>8s} {'r_0.7':>8s} "
      f"{'spike_factor':>12s} {'near_zero':>12s}")
print("  " + "-" * 60)

for t in np.arange(10, 40, 1.0):
    results = {}
    for sigma in [0.3, 0.5, 0.7]:
        s = [sigma, t] + [0.0]*14
        r = analyze_eta(s, terms=200, accelerate=True)
        results[sigma] = r
    
    r03 = results[0.3]['ratio']
    r05 = results[0.5]['ratio']
    r07 = results[0.7]['ratio']
    spike_factor = r05 / max(r03, r07, 0.001)
    
    near = ""
    for zt in ZEROS[:5]:
        if abs(t - zt) < 0.5:
            near = f"◄ ζ={zt:.1f}"
    
    print(f"  {t:8.1f} {r03:8.3f} {r05:8.3f} {r07:8.3f} "
          f"{spike_factor:12.3f} {near:>12s}")

# ═══════════════════════════════════════════════════════════
# TEST 5: Ultra-fine resolution near first zero
# Track the ratio as a function of BOTH σ and t
# ═══════════════════════════════════════════════════════════
print("\n\n▓▓▓ TEST 5: 2D ratio map near first zero ▓▓▓\n")
print("  σ (rows) × t (cols) near s = 0.5 + 14.135i")
print("  Values shown: non-complex ratio\n")

t_vals = np.arange(13.5, 14.8, 0.1)
sigma_vals = np.arange(0.2, 0.9, 0.1)

# Header
header_label = "σ\\t"
print(f"  {header_label:>6s}", end="")
for t in t_vals:
    print(f" {t:6.2f}", end="")
print()
print("  " + "-" * (7 + 7*len(t_vals)))

for sigma in sigma_vals:
    print(f"  {sigma:6.2f}", end="")
    for t in t_vals:
        s = [sigma, t] + [0.0]*14
        r = analyze_eta(s, terms=200, accelerate=True)
        # Highlight large ratios
        val = r['ratio']
        if val > 3.0:
            print(f" {val:5.1f}*", end="")
        else:
            print(f" {val:6.2f}", end="")
    print()

elapsed = time.time() - start
print(f"\n\nTotal runtime: {elapsed:.1f}s")
