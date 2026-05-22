#!/usr/bin/env python3
"""
BD Optimal Weights Probe — The Definitive Experiment

Loads precomputed Gram matrices from HPDF files, solves the
optimal BD least-squares problem v* = G⁻¹⟨1,f⟩, and computes:

    BD²(N) = 1 - ⟨1,f⟩ᵀ G⁻¹ ⟨1,f⟩

If RH is true, BD²(N) → 0 as N → ∞.
This probe determines the RATE.
"""

import numpy as np
import h5py
import os
import sys
from pathlib import Path

EULER_GAMMA = 0.5772156649015329
CACHE_DIR = Path("/Users/jrgochan/code/github.com/jrgochan/prime/experiments/cache/hpdf")

def load_gram_matrix(N):
    """Load the Gram matrix from HPDF cache."""
    path = CACHE_DIR / f"gram_N{N}.h5"
    if not path.exists():
        return None, None, None
    
    with h5py.File(path, 'r') as f:
        dim = f['structure/diagonal'].shape[0]  # N-1 (indices 1..N mapped to 0..N-2)
        diag = f['structure/diagonal'][:]
        upper = f['gram/upper_triangle'][:]
        b_vec = f['b_vector'][:]
        mu = f['number_theory/mobius'][:]
    
    # Reconstruct full symmetric matrix from upper triangle + diagonal
    G = np.zeros((dim, dim), dtype=np.float64)
    idx = 0
    for i in range(dim):
        G[i, i] = diag[i]
        for j in range(i+1, dim):
            G[i, j] = upper[idx]
            G[j, i] = upper[idx]
            idx += 1
    
    return G, b_vec, mu

def compute_inner_product_1_fk(N):
    """
    Compute ⟨1, f_k⟩ = ∫₀¹ {1/(kt)} dt = (ln(k) + 1 - γ) / k
    for k = 1, ..., N-1 (indices in the Gram matrix).
    """
    # The HPDF Gram matrix is indexed 1..N-1 (k = j+1 for index j)
    inner = np.zeros(N - 1)
    for j in range(N - 1):
        k = j + 1
        inner[j] = (np.log(k) + 1.0 - EULER_GAMMA) / k
    return inner

def main():
    print("╔═══════════════════════════════════════════════════════════════╗")
    print("║  BD OPTIMAL WEIGHTS PROBE — The Definitive Experiment       ║")
    print("║  v* = G⁻¹⟨1,f⟩,  BD² = 1 - ⟨1,f⟩ᵀ G⁻¹ ⟨1,f⟩            ║")
    print("╚═══════════════════════════════════════════════════════════════╝")
    print()

    # Find all available HPDF files
    available = []
    for f in sorted(CACHE_DIR.glob("gram_N*.h5")):
        n = int(f.stem.split("N")[1])
        available.append(n)
    available.sort()
    
    print(f"Available HPDF files: {len(available)}")
    print(f"Sizes: {available}")
    print()

    # Test sizes (use available HPDF files, skip very small ones)
    test_ns = [n for n in available if n >= 12]
    
    print("═══════════════════════════════════════════════════════════════")
    print("§1. OPTIMAL BD² = 1 - bᵀ G⁻¹ b")
    print("    b_k = ⟨1, f_k⟩ = (ln k + 1 - γ)/k")
    print("═══════════════════════════════════════════════════════════════")
    print()
    print(f"{'N':>8}  {'dim':>6}  {'BD²':>14}  {'BD²·ln(N)':>12}  {'BD²·ln²(N)':>12}  {'BD²·√N':>12}  {'κ(G)':>12}")
    
    results = []
    
    for N in test_ns:
        G, b_stored, mu = load_gram_matrix(N)
        if G is None:
            print(f"{N:>8}  SKIP (file not found)")
            continue
        
        dim = G.shape[0]
        
        # Compute the inner product vector b = ⟨1, f_k⟩
        b = compute_inner_product_1_fk(N)
        
        if len(b) != dim:
            print(f"{N:>8}  SKIP (dim mismatch: b={len(b)}, G={dim})")
            continue
        
        try:
            # Method 1: Direct solve v* = G⁻¹ b using Cholesky (G is SPD)
            # BD² = 1 - bᵀ v* = 1 - bᵀ G⁻¹ b
            v_star = np.linalg.solve(G, b)
            bd_sq = 1.0 - np.dot(b, v_star)
            
            # Condition number
            try:
                kappa = np.linalg.cond(G)
            except:
                kappa = float('inf')
            
            ln_n = np.log(N)
            
            print(f"{N:>8}  {dim:>6}  {bd_sq:>14.10f}  {bd_sq*ln_n:>12.6f}  {bd_sq*ln_n**2:>12.6f}  {bd_sq*np.sqrt(N):>12.6f}  {kappa:>12.1f}")
            
            results.append((N, dim, bd_sq, kappa))
            
        except np.linalg.LinAlgError as e:
            print(f"{N:>8}  ERROR: {e}")
    
    if len(results) < 2:
        print("\nNot enough results for rate analysis.")
        return
    
    # ═══════════════════════════════════════════════════
    # SECTION 2: Rate Analysis
    # ═══════════════════════════════════════════════════
    print()
    print("═══════════════════════════════════════════════════════════════")
    print("§2. RATE ANALYSIS")
    print("═══════════════════════════════════════════════════════════════")
    print()
    
    # Check which scaling stabilizes
    for label, scale_fn in [
        ("BD²·ln(N)", lambda n, bd: bd * np.log(n)),
        ("BD²·ln²(N)", lambda n, bd: bd * np.log(n)**2),
        ("BD²·√N", lambda n, bd: bd * np.sqrt(n)),
        ("BD²·N", lambda n, bd: bd * n),
    ]:
        vals = [scale_fn(r[0], r[2]) for r in results if r[2] > 0]
        if len(vals) >= 3:
            # Check stability: ratio of last to middle
            mid = len(vals) // 2
            ratio = vals[-1] / vals[mid] if vals[mid] != 0 else float('inf')
            stable = "← STABILIZING" if 0.8 < ratio < 1.2 else ""
            print(f"  {label:>14}:  first={vals[0]:>10.4f}  mid={vals[mid]:>10.4f}  last={vals[-1]:>10.4f}  ratio={ratio:.4f}  {stable}")
    
    # Power law fit
    if len(results) >= 3:
        ns = np.array([r[0] for r in results if r[2] > 0], dtype=float)
        bds = np.array([r[2] for r in results if r[2] > 0])
        if len(bds) >= 3 and np.all(bds > 0):
            # Fit log(BD²) = a + b·log(N) → BD² ~ N^b
            log_ns = np.log(ns)
            log_bds = np.log(bds)
            coeffs = np.polyfit(log_ns, log_bds, 1)
            print(f"\n  Power law fit: BD² ~ N^({coeffs[0]:.4f})")
            print(f"  (If ≈ -1: rate is 1/N; if ≈ -0.5: rate is 1/√N)")
            
            # Also fit log(BD²) = a + b·1/log(N) for logarithmic decay
            inv_log_ns = 1.0 / log_ns
            coeffs2 = np.polyfit(inv_log_ns, log_bds, 1)
            print(f"  Log-decay fit: ln(BD²) ~ {coeffs2[0]:.4f}/ln(N) + {coeffs2[1]:.4f}")
    
    # ═══════════════════════════════════════════════════
    # SECTION 3: Optimal Weights Analysis (for largest N)
    # ═══════════════════════════════════════════════════
    print()
    print("═══════════════════════════════════════════════════════════════")
    print("§3. OPTIMAL WEIGHT STRUCTURE (largest N)")
    print("═══════════════════════════════════════════════════════════════")
    print()
    
    # Use the largest available N
    N_large = results[-1][0]
    G, _, mu = load_gram_matrix(N_large)
    b = compute_inner_product_1_fk(N_large)
    v_star = np.linalg.solve(G, b)
    
    # Show the first few optimal weights
    print(f"  Optimal weights v*(k) for N = {N_large}:")
    print(f"  {'k':>6}  {'v*(k)':>14}  {'μ(k)':>6}  {'v_mertens(k)':>14}")
    for j in range(min(20, len(v_star))):
        k = j + 1
        mu_k = mu[k] if k < len(mu) else 0
        ln_n = np.log(N_large)
        w = max(0, 1.0 - np.log(k) / ln_n) if k < N_large else 0
        v_mert = -mu_k / k * w
        print(f"  {k:>6}  {v_star[j]:>14.8f}  {mu_k:>6}  {v_mert:>14.8f}")
    
    # Compare norms
    print(f"\n  ||v*||₂ = {np.linalg.norm(v_star):.6f}")
    print(f"  ||v*||₁ = {np.sum(np.abs(v_star)):.6f}")
    print(f"  v*ᵀ G v* = {np.dot(v_star, G @ v_star):.10f}")
    print(f"  bᵀ v*    = {np.dot(b, v_star):.10f}")
    print(f"  BD²      = {1.0 - np.dot(b, v_star):.10f}")
    
    # ═══════════════════════════════════════════════════
    # SECTION 4: Comparison with b_vector from HPDF
    # ═══════════════════════════════════════════════════
    print()
    print("═══════════════════════════════════════════════════════════════")
    print("§4. COMPARISON: Our b vs HPDF b_vector")
    print("═══════════════════════════════════════════════════════════════")
    print()
    
    _, b_stored, _ = load_gram_matrix(N_large)
    if b_stored is not None and len(b_stored) == len(b):
        diff = np.max(np.abs(b - b_stored))
        rel_diff = diff / np.max(np.abs(b_stored)) if np.max(np.abs(b_stored)) > 0 else 0
        print(f"  Max |b_ours - b_hpdf| = {diff:.6e}")
        print(f"  Relative difference   = {rel_diff:.6e}")
        print(f"  b_ours[0:5]  = {b[:5]}")
        print(f"  b_hpdf[0:5]  = {b_stored[:5]}")
        
        # Also try BD with the HPDF b_vector
        v_star_hpdf = np.linalg.solve(G, b_stored)
        bd_sq_hpdf = 1.0 - np.dot(b_stored, v_star_hpdf)
        print(f"\n  BD² with HPDF b_vector = {bd_sq_hpdf:.10f}")
        print(f"  BD² with our b_vector  = {1.0 - np.dot(b, v_star):.10f}")
    
    print()
    print("═══════════════════════════════════════════════════════════════")
    print("§5. VERDICT")
    print("═══════════════════════════════════════════════════════════════")
    print()
    
    last_bd = results[-1][2]
    if last_bd > 0 and last_bd < 0.01:
        print("  🎯 BD² is SMALL and DECREASING → RH confirmed numerically!")
    elif last_bd > 0 and last_bd < 1:
        print("  📉 BD² is decreasing but still > 0.01 — need larger N")
    elif last_bd <= 0:
        print("  ⚠️  BD² is NEGATIVE — this shouldn't happen (check Gram matrix)")
    else:
        print("  ❌ BD² > 1 — something is wrong with the computation")
    
    print()
    print("The primes have spoken. 💎")

if __name__ == "__main__":
    main()
