#!/usr/bin/env python3
"""
Universal Wavefunction Optimizer v3.

Three analyses:
1. Unconstrained: a* = G^{-1} b → d²_std (the Möbius answer)
2. Polynomial envelope: fit F*(x) to a*(x) and evaluate d²
3. Direct projection: optimize c to minimize d² = 1 - 2β·c + c^T Γ c
   where Γ = P^T G P (using regularized solve)

Usage: python3 wavefunction_optimizer.py <cache_path> [K=10]
"""

import struct
import sys
import numpy as np
from pathlib import Path

DD_MAGIC = 0x5F5F444448544143

def load_dd_gram_hi(path):
    with open(path, 'rb') as f:
        magic = struct.unpack('<Q', f.read(8))[0]
        assert magic == DD_MAGIC, f"Bad magic: {magic:#x}"
        version = struct.unpack('<I', f.read(4))[0]
        max_n = struct.unpack('<I', f.read(4))[0]
        precision = struct.unpack('<I', f.read(4))[0]
        dim = struct.unpack('<I', f.read(4))[0]
        _ = f.read(8)  # checksum
        print(f"  Loading DD Gram: dim={dim}, max_n={max_n}, {dim*dim*8/(1024**3):.1f} GB")
        hi = np.fromfile(f, dtype=np.float64, count=dim*dim).reshape(dim, dim)
        return hi, dim, max_n

def analyze_coefficients(a_star, max_n, dim):
    """Analyze the structure of optimal coefficients."""
    x = np.array([(j + 2) / max_n for j in range(dim)])
    
    print(f"\n  ═══════════════════════════════════════════════")
    print(f"  ║  OPTIMAL COEFFICIENT ANATOMY")
    print(f"  ═══════════════════════════════════════════════")
    
    # Statistics
    print(f"  ||a*||_∞  = {np.max(np.abs(a_star)):.6e}")
    print(f"  ||a*||_2  = {np.linalg.norm(a_star):.6e}")
    print(f"  mean(a*)  = {np.mean(a_star):.6e}")
    print(f"  std(a*)   = {np.std(a_star):.6e}")
    
    # Positive/negative breakdown
    pos = np.sum(a_star > 0)
    neg = np.sum(a_star < 0)
    print(f"  Positive: {pos}/{dim}  Negative: {neg}/{dim}")
    
    # Correlation with 1/j, μ(j), etc.
    j_vals = np.arange(2, max_n + 1, dtype=np.float64)[:dim]
    
    # Check correlation with simple functions
    inv_j = 1.0 / j_vals
    corr_invj = np.corrcoef(a_star, inv_j)[0, 1]
    print(f"  Corr(a*, 1/j) = {corr_invj:.6f}")
    
    # Compute Möbius function for small values
    mobius = np.zeros(dim)
    sieve = np.ones(max_n + 1, dtype=np.int32)
    for p in range(2, max_n + 1):
        if sieve[p] == 1:  # prime
            for multiple in range(p, max_n + 1, p):
                sieve[multiple] *= -1
            for multiple in range(p*p, max_n + 1, p*p):
                sieve[multiple] = 0
    for j in range(dim):
        mobius[j] = sieve[j + 2]
    
    mu_j = mobius / j_vals
    nonzero = mobius != 0
    if np.sum(nonzero) > 0:
        corr_mu = np.corrcoef(a_star[nonzero], mu_j[nonzero])[0, 1]
        print(f"  Corr(a*, μ(j)/j) = {corr_mu:.6f}")
    
    # Sample the wavefunction at key points
    print(f"\n  Wavefunction profile a*(j):")
    checkpoints = [0, 1, 2, 3, 4, 8, 28, 48, 98, 498, 998,
                   min(dim-1, 4998), min(dim-1, 9998), min(dim-1, 19998)]
    for idx in checkpoints:
        if idx < dim:
            j = idx + 2
            mu_val = int(mobius[idx]) if idx < len(mobius) else '?'
            print(f"    a*[{j:6d}] = {a_star[idx]:+.10e}  μ({j})={mu_val:+2d}")

def direct_projection(G, b, max_n, dim, K_values=[1,2,3,5,8,10,15,20,30,50]):
    """
    Direct optimization: minimize d² = 1 - 2β·c + c^T Γ c
    over K-dimensional polynomial subspace.
    
    Uses SVD-regularized solve to handle ill-conditioning.
    """
    print(f"\n  ═══════════════════════════════════════════════")
    print(f"  ║  DIRECT PROJECTION ANALYSIS")
    print(f"  ║  d² = 1 - 2β·c + c^T Γ c,  Γ = P^T G P")
    print(f"  ═══════════════════════════════════════════════")
    
    N = max_n
    
    # Standard d² for reference
    try:
        L = np.linalg.cholesky(G)
        y = np.linalg.solve(L, b)
        d2_std = 1.0 - np.dot(y, y)
        a_star = np.linalg.solve(L.T, y)
    except:
        print("  Cholesky failed!")
        return None
    
    print(f"  Standard d²_{N} = {d2_std:.15e}")
    print()
    print(f"  {'K':>4} │ {'d²_projected':>20} │ {'Ratio vs std':>12} │ {'Cond(Γ)':>12}")
    print(f"  {'─'*4}─┼─{'─'*20}─┼─{'─'*12}─┼─{'─'*12}")
    
    best_K = 0
    best_d2 = float('inf')
    best_coeffs = None
    
    for K in K_values:
        if K > dim:
            continue
        
        # Build basis P: (dim × K)
        P = np.zeros((dim, K))
        for j in range(dim):
            x = (j + 2.0) / N
            for i in range(K):
                P[j, i] = (1.0 - x) ** (i + 1)
        
        # Projected quantities
        beta = P.T @ b
        GP = G @ P
        Gamma = P.T @ GP
        
        # SVD-regularized solve
        U, S, Vt = np.linalg.svd(Gamma)
        
        # Regularization: truncate singular values below machine epsilon
        threshold = S[0] * 1e-14
        S_inv = np.where(S > threshold, 1.0 / S, 0.0)
        effective_rank = np.sum(S > threshold)
        
        c = Vt.T @ (S_inv * (U.T @ beta))
        d2_proj = 1.0 - 2.0 * np.dot(beta, c) + np.dot(c, Gamma @ c)
        
        cond = S[0] / max(S[-1], 1e-300)
        ratio = d2_proj / d2_std if d2_std > 0 else float('inf')
        
        marker = ""
        if d2_proj < best_d2 and d2_proj > 0:
            best_d2 = d2_proj
            best_K = K
            best_coeffs = c.copy()
            marker = " ←"
        
        print(f"  {K:4d} │ {d2_proj:+.15e} │ {ratio:10.6f}× │ {cond:.4e} (r={effective_rank}){marker}")
    
    print(f"  {'─'*4}─┼─{'─'*20}─┼─{'─'*12}─┼─{'─'*12}")
    print(f"  {'std':>4} │ {d2_std:+.15e} │ {'1.000000×':>12} │")
    
    # Report best
    if best_coeffs is not None:
        print(f"\n  ═══════════════════════════════════════════════")
        print(f"  ║  OPTIMAL POLYNOMIAL: K={best_K}")
        print(f"  ║  F*(x) = Σ c_i (1-x)^i, i = 1..{best_K}")
        print(f"  ╠═══════════════════════════════════════════════")
        for i, c in enumerate(best_coeffs):
            print(f"  ║  c_{i+1:2d} = {c:+.15e}")
        print(f"  ╠═══════════════════════════════════════════════")
        print(f"  ║  d²_poly = {best_d2:.15e}")
        print(f"  ║  d²_std  = {d2_std:.15e}")
        print(f"  ║  Ratio   = {best_d2/d2_std:.6f}×")
        print(f"  ║  Gap     = {best_d2 - d2_std:.6e}")
        print(f"  ═══════════════════════════════════════════════")
        
        # Verify via explicit reconstruction
        P_best = np.zeros((dim, best_K))
        for j in range(dim):
            x = (j + 2.0) / N
            for i in range(best_K):
                P_best[j, i] = (1.0 - x) ** (i + 1)
        
        a_poly = P_best @ best_coeffs
        d2_check = 1.0 - 2.0 * np.dot(a_poly, b) + np.dot(a_poly, G @ a_poly)
        print(f"  Cross-check: d² = {d2_check:.15e}")
        
        # Lean 4 output
        print(f"\n  /-- Universal Wavefunction F*(x) = Σ c_i (1-x)^i")
        print(f"  def cathedral_wavefunction : Fin {best_K} → ℝ := ![")
        for i in range(best_K):
            comma = "," if i < best_K - 1 else ""
            print(f"    {best_coeffs[i]:+.15e}{comma}  -- c_{i+1}")
        print(f"  ]")
    
    return best_coeffs, best_d2, d2_std, a_star

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 wavefunction_optimizer.py <cache_path> [K=10]")
        sys.exit(1)
    
    cache_path = sys.argv[1]
    K = int(sys.argv[2]) if len(sys.argv) > 2 else 10
    
    print(f"\n  ╔═══════════════════════════════════════════════════════╗")
    print(f"  ║  CATHEDRAL WAVEFUNCTION OPTIMIZER v3")
    print(f"  ║  Direct Projection + Coefficient Anatomy")
    print(f"  ║  Cache: {Path(cache_path).name}")
    print(f"  ╚═══════════════════════════════════════════════════════╝")
    
    G, dim, max_n = load_dd_gram_hi(cache_path)
    b = np.array([1.0 / (j + 2) for j in range(dim)])
    
    # Phase 1: Direct projection with K-sweep
    coeffs, d2_poly, d2_std, a_star = direct_projection(G, b, max_n, dim)
    
    # Phase 2: Anatomy of optimal coefficients
    analyze_coefficients(a_star, max_n, dim)

if __name__ == "__main__":
    main()
