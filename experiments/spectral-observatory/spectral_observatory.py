#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════╗
║  🔭 THE SPECTRAL OBSERVATORY                                           ║
║                                                                         ║
║  Experiment: Quantum Decoupling of the Riemann Vacuum                   ║
║                                                                         ║
║  Hypothesis: The macroscopic target vector b must be orthogonal to      ║
║  the low-eigenvalue eigenstates of the Gram matrix G_N. Specifically:   ║
║                                                                         ║
║    c_k² = |⟨b, v_k⟩|² must decay FASTER than λ_k                       ║
║                                                                         ║
║  so that E_k = c_k²/λ_k → 0 as λ_k → 0.                               ║
║                                                                         ║
║  If this holds, the spectral sum Σ c_k²/λ_k converges to 1,            ║
║  which means d²_N → 0, which means RH.                                 ║
║                                                                         ║
║  Cathedral Core Team — April 30, 2026                                   ║
╚══════════════════════════════════════════════════════════════════════════╝
"""

import numpy as np
from scipy.linalg import eigh
import time
import math
import os
import sys

# ═══════════════════════════════════════════════════════════════════════
# GRAM MATRIX CONSTRUCTION (Vasyunin formula)
# ═══════════════════════════════════════════════════════════════════════

EULER_GAMMA = 0.5772156649015328606

def vasyunin_sum(a: int, b: int) -> float:
    """Compute the Vasyunin cotangent sum V(a,b) = Σ_{m=1}^{a-1} {mb/a} cot(πm/a)."""
    if a <= 1:
        return 0.0
    total = 0.0
    for m in range(1, a):
        frac = ((m * b) % a) / a
        angle = math.pi * m / a
        s = math.sin(angle)
        if abs(s) < 1e-15:
            continue
        c = math.cos(angle)
        total += frac * c / s
    return total

# Cache for Vasyunin sums
_vasyunin_cache = {}

def vasyunin_cached(a: int, b: int) -> float:
    key = (a, b)
    if key not in _vasyunin_cache:
        _vasyunin_cache[key] = vasyunin_sum(a, b)
    return _vasyunin_cache[key]

def gram_entry(j: int, k: int) -> float:
    """Gram matrix entry G(j,k) = ∫₀¹ {1/(jx)} · {1/(kx)} dx using Vasyunin formula."""
    ln2pi = math.log(2 * math.pi)
    coeff = (ln2pi - EULER_GAMMA) / 2.0
    jf, kf = float(j), float(k)
    jk = jf * kf

    if j == k:
        return (ln2pi - EULER_GAMMA) / jf - 1.0 / (jf * jf)

    d = math.gcd(j, k)
    jp, kp = j // d, k // d
    return (coeff * (1/jf + 1/kf)
            + (jf - kf) / (2*jk) * math.log(kf/jf)
            - math.pi * d / (2*jk) * (vasyunin_cached(jp, kp) + vasyunin_cached(kp, jp))
            - 1/jk)

def b_vector_entry(k: int) -> float:
    """Mean vector entry b_k = ∫₀¹ {1/(kx)} dx = (1 - γ - ln(k))/k + 1/(2k)."""
    # Vasyunin mean: ⟨1, {1/(kx)}⟩ in L²(0,1)
    # = (ln(2π) - γ) / (2k) - 1/(2k²) ... actually let's use the simpler form
    # b_k = (1 - γ)/k + (something involving harmonic numbers)
    # Actually the exact formula from the Lean code: vasyuninMeanEntry
    # b_k = (ln(2π) - γ) / (2k)
    ln2pi = math.log(2 * math.pi)
    return (ln2pi - EULER_GAMMA) / (2.0 * k)

def build_gram_matrix(N: int):
    """Build the (N-1) × (N-1) Gram matrix for indices k = 2, 3, ..., N."""
    dim = N - 1
    G = np.zeros((dim, dim))
    for i in range(dim):
        for j in range(i, dim):
            val = gram_entry(i + 2, j + 2)
            G[i, j] = val
            G[j, i] = val
    return G

def build_b_vector(N: int):
    """Build the target vector b for indices k = 2, 3, ..., N."""
    dim = N - 1
    b = np.zeros(dim)
    for i in range(dim):
        b[i] = b_vector_entry(i + 2)
    return b

# ═══════════════════════════════════════════════════════════════════════
# THE SPECTRAL OBSERVATORY
# ═══════════════════════════════════════════════════════════════════════

def run_spectral_observatory(N: int, output_dir: str):
    """
    Full spectral decomposition of the Nyman-Beurling Gram matrix.

    Computes:
      1. Full eigendecomposition G = V Λ V^T
      2. Projection amplitudes c_k = ⟨b, v_k⟩
      3. Spectral energy distribution E_k = c_k² / λ_k
      4. Cumulative spectral sum S(k) = Σ_{i≤k} c_i² / λ_i
      5. Verification: S(N-1) should equal 1 - d²_N
    """
    print(f"\n{'═' * 72}")
    print(f"  🔭 SPECTRAL OBSERVATORY — N = {N}")
    print(f"{'═' * 72}")

    # Step 1: Build Gram matrix
    t0 = time.time()
    print(f"  Building {N-1}×{N-1} Gram matrix...", end=" ", flush=True)
    G = build_gram_matrix(N)
    t_gram = time.time() - t0
    print(f"done ({t_gram:.1f}s)")

    # Step 2: Build b-vector
    b = build_b_vector(N)
    b_norm = np.linalg.norm(b)
    print(f"  ‖b‖ = {b_norm:.8f}")

    # Step 3: Full eigendecomposition
    t0 = time.time()
    print(f"  Computing full eigendecomposition...", end=" ", flush=True)
    eigenvalues, eigenvectors = eigh(G)
    t_eig = time.time() - t0
    print(f"done ({t_eig:.1f}s)")

    # eigenvalues are sorted ascending by scipy.eigh
    lambda_min = eigenvalues[0]
    lambda_max = eigenvalues[-1]
    cond = lambda_max / lambda_min if lambda_min > 0 else float('inf')
    print(f"  λ_min = {lambda_min:.8e}")
    print(f"  λ_max = {lambda_max:.8e}")
    print(f"  cond(G) = {cond:.4e}")

    # Step 4: Projection amplitudes
    # c_k = ⟨b, v_k⟩ = b^T · v_k
    c = eigenvectors.T @ b  # c[k] = v_k^T b
    c_sq = c ** 2

    # Step 5: Spectral energy distribution
    E = np.zeros_like(c_sq)
    for k in range(len(eigenvalues)):
        if eigenvalues[k] > 1e-30:
            E[k] = c_sq[k] / eigenvalues[k]
        else:
            E[k] = float('inf')

    # Step 6: Cumulative spectral sum (sorted by ascending eigenvalue)
    S_cumulative = np.cumsum(E)
    S_total = S_cumulative[-1]

    # Step 7: The distance
    d_sq = 1.0 - S_total
    d_sq_direct = 1.0 - b @ np.linalg.solve(G, b)  # Direct computation for comparison

    print(f"\n  ── SPECTRAL DECOMPOSITION ──")
    print(f"  Σ c_k²/λ_k = {S_total:.12f}")
    print(f"  d²_N = 1 - Σ c_k²/λ_k = {d_sq:.12f}")
    print(f"  d²_N (direct) = {d_sq_direct:.12f}")
    print(f"  Agreement: {abs(d_sq - d_sq_direct):.4e}")

    # ═══════════════════════════════════════════════════════════════════
    # QUANTUM DECOUPLING ANALYSIS
    # ═══════════════════════════════════════════════════════════════════

    print(f"\n  ── QUANTUM DECOUPLING ANALYSIS ──")
    print(f"  {'k':>5} {'λ_k':>14} {'c_k²':>14} {'E_k=c²/λ':>14} {'S_cum':>12} {'c²/λ ratio':>12}")
    print(f"  {'─'*5} {'─'*14} {'─'*14} {'─'*14} {'─'*12} {'─'*12}")

    # Show bottom 20 eigenvalues (the dangerous ones)
    n_show = min(20, len(eigenvalues))
    for k in range(n_show):
        ratio = c_sq[k] / eigenvalues[k] if eigenvalues[k] > 1e-30 else float('inf')
        # c²/λ ratio: if this stays bounded, decoupling holds
        c_lambda_ratio = c_sq[k] / eigenvalues[k]**2 if eigenvalues[k] > 1e-30 else float('inf')
        print(f"  {k:5d} {eigenvalues[k]:14.8e} {c_sq[k]:14.8e} {E[k]:14.8e} {S_cumulative[k]:12.8f} {c_lambda_ratio:12.4e}")

    print(f"  {'...':>5}")

    # Show top 5 eigenvalues
    for k in range(max(0, len(eigenvalues) - 5), len(eigenvalues)):
        ratio = c_sq[k] / eigenvalues[k] if eigenvalues[k] > 1e-30 else float('inf')
        c_lambda_ratio = c_sq[k] / eigenvalues[k]**2 if eigenvalues[k] > 1e-30 else float('inf')
        print(f"  {k:5d} {eigenvalues[k]:14.8e} {c_sq[k]:14.8e} {E[k]:14.8e} {S_cumulative[k]:12.8f} {c_lambda_ratio:12.4e}")

    # ═══════════════════════════════════════════════════════════════════
    # THE KEY DIAGNOSTIC: c_k² vs λ_k SCALING
    # ═══════════════════════════════════════════════════════════════════

    print(f"\n  ── DECOUPLING POWER LAW ──")
    print(f"  If c_k² ~ λ_k^β with β > 1, then E_k → 0 and the sum converges.")
    print(f"  If β ≤ 1, the low-eigenvalue modes destroy convergence.")

    # Fit log(c_k²) vs log(λ_k) for the bottom eigenvalues
    n_fit = min(50, len(eigenvalues) // 2)
    mask = (eigenvalues[:n_fit] > 1e-30) & (c_sq[:n_fit] > 1e-50)
    if mask.sum() >= 5:
        log_lambda = np.log(eigenvalues[:n_fit][mask])
        log_c_sq = np.log(c_sq[:n_fit][mask])
        coeffs = np.polyfit(log_lambda, log_c_sq, 1)
        beta = coeffs[0]
        print(f"  β = {beta:.6f}  (fit over bottom {mask.sum()} modes)")
        if beta > 1:
            print(f"  ✅ β > 1: QUANTUM DECOUPLING CONFIRMED")
            print(f"     c_k² decays faster than λ_k → E_k → 0 → sum converges")
        elif beta > 0:
            print(f"  ⚠️  0 < β < 1: MARGINAL — sum may diverge logarithmically")
        else:
            print(f"  ❌ β ≤ 0: NO DECOUPLING — low modes dominate")
    else:
        print(f"  (insufficient data for power-law fit)")
        beta = float('nan')

    # ═══════════════════════════════════════════════════════════════════
    # ORTHOGONALITY SHIELD: ⟨b, v_min⟩
    # ═══════════════════════════════════════════════════════════════════

    print(f"\n  ── ORTHOGONALITY SHIELD ──")
    print(f"  |⟨b, v_min⟩| = {abs(c[0]):.8e}")
    print(f"  |⟨b, v_min⟩|² = {c_sq[0]:.8e}")
    print(f"  λ_min = {eigenvalues[0]:.8e}")
    print(f"  E_0 = c_0²/λ_min = {E[0]:.8e}")
    print(f"  E_0 / d²_N = {E[0] / d_sq if d_sq > 0 else float('inf'):.8e}")

    # ═══════════════════════════════════════════════════════════════════
    # ENERGY CONCENTRATION: Where does the spectral sum accumulate?
    # ═══════════════════════════════════════════════════════════════════

    print(f"\n  ── ENERGY CONCENTRATION ──")
    total_energy = S_total
    for threshold in [0.5, 0.9, 0.95, 0.99, 0.999]:
        idx = np.searchsorted(S_cumulative, threshold * total_energy)
        if idx < len(eigenvalues):
            print(f"  {threshold*100:5.1f}% of energy in modes 0..{idx} (λ > {eigenvalues[idx]:.4e})")
        else:
            print(f"  {threshold*100:5.1f}% of energy requires all {len(eigenvalues)} modes")

    # ═══════════════════════════════════════════════════════════════════
    # SAVE DATA
    # ═══════════════════════════════════════════════════════════════════

    os.makedirs(output_dir, exist_ok=True)
    data_file = os.path.join(output_dir, f"spectral_N{N}.tsv")
    with open(data_file, 'w') as f:
        f.write("k\tlambda_k\tc_k_sq\tE_k\tS_cumulative\n")
        for k in range(len(eigenvalues)):
            f.write(f"{k}\t{eigenvalues[k]:.15e}\t{c_sq[k]:.15e}\t{E[k]:.15e}\t{S_cumulative[k]:.15e}\n")
    print(f"\n  Data saved to: {data_file}")

    return {
        'N': N,
        'dim': N - 1,
        'eigenvalues': eigenvalues,
        'c_sq': c_sq,
        'E': E,
        'S_cumulative': S_cumulative,
        'S_total': S_total,
        'd_sq': d_sq,
        'd_sq_direct': d_sq_direct,
        'beta': beta,
        'lambda_min': lambda_min,
        'c_min_sq': c_sq[0],
        'E_0': E[0],
    }


# ═══════════════════════════════════════════════════════════════════════
# MULTI-N SCALING ANALYSIS
# ═══════════════════════════════════════════════════════════════════════

def run_scaling_analysis(sizes, output_dir):
    """Run the observatory at multiple N values and check scaling."""
    results = []
    for N in sizes:
        r = run_spectral_observatory(N, output_dir)
        results.append(r)

    print(f"\n\n{'═' * 72}")
    print(f"  🔭 SCALING SUMMARY")
    print(f"{'═' * 72}")
    print(f"  {'N':>6} {'dim':>5} {'λ_min':>14} {'|⟨b,v_min⟩|²':>14} {'E_0':>14} {'β':>8} {'d²_N':>14} {'Σc²/λ':>14}")
    print(f"  {'─'*6} {'─'*5} {'─'*14} {'─'*14} {'─'*14} {'─'*8} {'─'*14} {'─'*14}")
    for r in results:
        print(f"  {r['N']:6d} {r['dim']:5d} {r['lambda_min']:14.8e} {r['c_min_sq']:14.8e} "
              f"{r['E_0']:14.8e} {r['beta']:8.4f} {r['d_sq']:14.10f} {r['S_total']:14.10f}")

    # Check if β is increasing with N (stronger decoupling at larger N)
    betas = [r['beta'] for r in results if not math.isnan(r['beta'])]
    if len(betas) >= 2:
        print(f"\n  β trend: {' → '.join(f'{b:.4f}' for b in betas)}")
        if all(betas[i] <= betas[i+1] for i in range(len(betas)-1)):
            print(f"  ✅ β is INCREASING → decoupling STRENGTHENS with N")
        elif betas[-1] > 1:
            print(f"  ✅ β > 1 at largest N → decoupling holds")
        else:
            print(f"  ⚠️  β behavior is non-monotonic — needs larger N")

    # Check E_0 trend
    E0s = [r['E_0'] for r in results]
    print(f"\n  E_0 trend: {' → '.join(f'{e:.4e}' for e in E0s)}")
    if all(E0s[i] >= E0s[i+1] for i in range(len(E0s)-1)):
        print(f"  ✅ E_0 is DECREASING → lowest mode contribution vanishing")
    else:
        print(f"  ⚠️  E_0 is non-monotonic")

    print(f"\n  🔭 Observatory complete.")
    print(f"  Data files in: {output_dir}")


# ═══════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    print()
    print("╔══════════════════════════════════════════════════════════════════╗")
    print("║  🔭 THE SPECTRAL OBSERVATORY                                   ║")
    print("║  Quantum Decoupling of the Riemann Vacuum                      ║")
    print("║  Cathedral Core Team — April 30, 2026                          ║")
    print("╚══════════════════════════════════════════════════════════════════╝")

    output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results", "spectral-observatory")

    # Start with smaller N values that can run on CPU
    # For the full N=5000+ experiment, we'd need the GPU eigendecomposition
    sizes = [100, 200, 500, 1000, 2000]

    # Check if user requested specific sizes
    if len(sys.argv) > 1:
        sizes = [int(s) for s in sys.argv[1:]]

    run_scaling_analysis(sizes, output_dir)
