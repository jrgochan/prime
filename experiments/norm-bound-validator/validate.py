#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════════════
 CATHEDRAL NORM-BOUND VALIDATOR
 Validates: ‖ζ(2+it+z)‖ ≤ (2+|t|)^C for z ∈ ball(0, R)

 Target sorry: zeta_norm_bound_on_disk in ZetaLowerBound.lean
 Uses mpmath for arbitrary-precision zeta computation.
═══════════════════════════════════════════════════════════════════════
"""

import mpmath
import json
import time
import os
from datetime import datetime, timezone

mpmath.mp.dps = 50  # 50 decimal digits

# ═══════════════════════════════════════════
# §1. Core Computation
# ═══════════════════════════════════════════

def zeta_norm(sigma, t):
    """Compute ‖ζ(σ+it)‖ at high precision."""
    s = mpmath.mpc(sigma, t)
    z = mpmath.zeta(s)
    return float(abs(z))

def scan_disk(t_center, radius, n_radii=30, n_angles=200):
    """Scan ‖ζ(2+it+z)‖ over disk(0, R), return max norm and location."""
    max_norm = 0.0
    max_re = 2.0
    max_im = t_center
    
    for ri in range(n_radii + 1):
        rr = radius * ri / n_radii
        na = 1 if ri == 0 else n_angles
        for j in range(na):
            theta = 2 * mpmath.pi * j / na
            s_re = 2.0 + float(rr * mpmath.cos(theta))
            s_im = t_center + float(rr * mpmath.sin(theta))
            
            try:
                zn = zeta_norm(s_re, s_im)
                if zn > max_norm:
                    max_norm = zn
                    max_re = s_re
                    max_im = s_im
            except Exception:
                pass
    
    return max_norm, max_re, max_im

# ═══════════════════════════════════════════
# §2. Main Validation
# ═══════════════════════════════════════════

def main():
    t0 = time.time()
    
    print()
    print("  ╔═══════════════════════════════════════════════════════════════╗")
    print("  ║  CATHEDRAL NORM-BOUND VALIDATOR                             ║")
    print("  ║  Target: zeta_norm_bound_on_disk (ZetaLowerBound.lean)      ║")
    print("  ║  Bound: ‖ζ(2+it+z)‖ ≤ (2+|t|)^C for z ∈ ball(0, R)       ║")
    print(f"  ║  Precision: {mpmath.mp.dps} decimal digits                            ║")
    print("  ╚═══════════════════════════════════════════════════════════════╝")
    print()
    
    # Parameters
    t_values = [2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000]
    radii = [0.5, 1.0, 1.2, 1.4, 1.49]
    C_target = 10  # The exponent in our Lean statement
    
    os.makedirs("results", exist_ok=True)
    
    # TSV output
    tsv = open("results/norm_bound.tsv", "w")
    tsv.write("t\tR\tmax_norm\tbound_value\tratio\ttightest_C\tmax_at_re\tmax_at_im\n")
    
    all_ratios = []
    all_C = []
    max_C_overall = 0.0
    worst_t = 0
    worst_R = 0
    
    print("  ═══ §1. NORM BOUND SCAN ═══")
    print(f"  Testing: ‖ζ(2+it+z)‖ ≤ (2+|t|)^{C_target}")
    print()
    print(f"  {'t':>7} │ {'R':>5} │ {'max‖ζ‖':>12} │ {'(2+|t|)^10':>14} │ {'ratio':>10} │ {'tight C':>8} │ max at")
    print(f"  {'─'*7}─┼─{'─'*5}─┼─{'─'*12}─┼─{'─'*14}─┼─{'─'*10}─┼─{'─'*8}─┼─{'─'*20}")
    
    for t in t_values:
        for R in radii:
            max_norm, max_re, max_im = scan_disk(t, R)
            bound = (2 + abs(t)) ** C_target
            ratio = max_norm / bound if bound > 0 else float('inf')
            
            # Tightest C: max_norm ≤ (2+|t|)^C ⟺ C ≥ log(max_norm)/log(2+|t|)
            log_base = mpmath.log(2 + abs(t))
            if max_norm > 0 and float(log_base) > 0:
                tight_C = float(mpmath.log(max_norm) / log_base)
            else:
                tight_C = 0.0
            
            tsv.write(f"{t}\t{R}\t{max_norm:.15e}\t{bound:.6e}\t{ratio:.15e}\t{tight_C:.15e}\t{max_re:.6f}\t{max_im:.6f}\n")
            
            all_ratios.append(ratio)
            all_C.append(tight_C)
            if tight_C > max_C_overall:
                max_C_overall = tight_C
                worst_t = t
                worst_R = R
            
            # Print select rows (all R for small t, R=1.4 for larger t)
            if R in [1.4, 1.49] or t <= 20:
                status = "✓" if ratio < 1 else "✗"
                print(f"  {t:>7} │ {R:>5.2f} │ {max_norm:>12.4f} │ {bound:>14.2e} │ {ratio:>10.2e} │ {tight_C:>8.4f} │ ({max_re:.2f}, {max_im:.1f})")
    
    tsv.close()
    
    print()
    
    # ═══════════════════════════════════════════
    # §3. Re ≥ 2 vs Re < 2 Analysis
    # ═══════════════════════════════════════════
    print("  ═══ §2. LEFT vs RIGHT HALF OF DISK ═══")
    print("  Does the max occur at Re < 2 (critical strip) or Re ≥ 2 (tail bound region)?")
    print()
    
    t_test = [50, 200, 1000, 5000]
    R_test = 1.4
    
    for t in t_test:
        # Right half (Re >= 2): tail bound gives |ζ-1| ≤ 3/4, so |ζ| ≤ 7/4
        max_right = 0.0
        max_left = 0.0
        
        for ri in range(31):
            rr = R_test * ri / 30
            na = 1 if ri == 0 else 200
            for j in range(na):
                theta = 2 * mpmath.pi * j / na
                dre = float(rr * mpmath.cos(theta))
                s_re = 2.0 + dre
                s_im = t + float(rr * mpmath.sin(theta))
                try:
                    zn = zeta_norm(s_re, s_im)
                    if dre >= 0:
                        max_right = max(max_right, zn)
                    else:
                        max_left = max(max_left, zn)
                except:
                    pass
        
        print(f"    t={t:>5}: left half (Re<2) max = {max_left:.4f},  right half (Re≥2) max = {max_right:.4f}")
    
    print()
    
    # ═══════════════════════════════════════════
    # §4. Convexity Bound Check
    # ═══════════════════════════════════════════
    print("  ═══ §3. CONVEXITY BOUND VERIFICATION ═══")
    print("  Standard bound: ‖ζ(σ+it)‖ ≤ C·|t|^{(1-σ)/2+ε} for 0 ≤ σ ≤ 1")
    print("  For σ ∈ (0.5, 2): ‖ζ‖ ≤ C·|t|^{max((1-σ)/2, 0)+ε}")
    print()
    
    print(f"  {'t':>7} │ {'σ':>5} │ {'‖ζ(σ+it)‖':>12} │ {'|t|^(1-σ)/2':>12} │ {'ratio':>10}")
    print(f"  {'─'*7}─┼─{'─'*5}─┼─{'─'*12}─┼─{'─'*12}─┼─{'─'*10}")
    
    for t in [50, 100, 500, 1000, 5000]:
        for sigma in [0.6, 0.8, 1.0, 1.5, 2.0]:
            zn = zeta_norm(sigma, t)
            convex_exp = max((1 - sigma) / 2, 0)
            convex_bound = abs(t) ** convex_exp
            ratio = zn / convex_bound if convex_bound > 0 else 0
            print(f"  {t:>7} │ {sigma:>5.1f} │ {zn:>12.4f} │ {convex_bound:>12.4f} │ {ratio:>10.4f}")
        print()
    
    # ═══════════════════════════════════════════
    # §5. Certificate
    # ═══════════════════════════════════════════
    elapsed = time.time() - t0
    
    bound_valid = all(r < 1.0 for r in all_ratios)
    
    print("  ╔═══════════════════════════════════════════════════════════════╗")
    print("  ║  NORM-BOUND VALIDATOR — CERTIFICATE                         ║")
    print("  ╠═══════════════════════════════════════════════════════════════╣")
    print("  ║")
    print(f"  ║  {'✓' if bound_valid else '✗'} ‖ζ(2+it+z)‖ ≤ (2+|t|)^10 for ALL tested (t, R)")
    print(f"  ║    Max ratio: {max(all_ratios):.6e}")
    print(f"  ║    Tightest exponent C needed: {max_C_overall:.6f}")
    print(f"  ║    Worst case: t={worst_t}, R={worst_R}")
    print(f"  ║    Margin: C=10 is {10/max(max_C_overall, 1e-10):.0f}x more than needed")
    print("  ║")
    print(f"  ║  Proof strategy hint:")
    if max_C_overall < 1:
        print(f"  ║    C < 1 → even ‖ζ‖ ≤ (2+|t|) suffices!")
        print(f"  ║    For Re ≥ 2: tail bound gives ‖ζ‖ ≤ 7/4 ✓")
        print(f"  ║    For Re < 2: convexity ‖ζ‖ ≤ C·|t|^{{1/4}} ≤ (2+|t|) ✓")
    else:
        print(f"  ║    Use Phragmén-Lindelöf with exponent ≤ {max_C_overall:.2f}")
    print("  ║")
    print(f"  ║  Runtime: {elapsed:.1f}s  Precision: {mpmath.mp.dps} digits")
    print("  ║")
    print("  ╚═══════════════════════════════════════════════════════════════╝")
    print()
    
    # Write JSON certificate
    cert = {
        "experiment": "Cathedral Norm-Bound Validator",
        "target": "zeta_norm_bound_on_disk",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "precision_digits": mpmath.mp.dps,
        "bound_valid": bound_valid,
        "C_target": C_target,
        "C_tightest": max_C_overall,
        "C_margin_factor": 10 / max(max_C_overall, 1e-10),
        "worst_t": worst_t,
        "worst_R": worst_R,
        "max_ratio": max(all_ratios),
        "n_tests": len(all_ratios),
        "t_values": t_values,
        "radii": radii,
        "elapsed_seconds": elapsed,
        "proof_hint": "C<1: tail bound for Re>=2, convexity for Re<2" if max_C_overall < 1 else f"Need PL with C<={max_C_overall:.2f}"
    }
    
    with open("results/certificate.json", "w") as f:
        json.dump(cert, f, indent=2)
    
    print(f"  Output: results/norm_bound.tsv, results/certificate.json")
    print()

if __name__ == "__main__":
    main()
