#!/usr/bin/env python3
"""
Spectral Decomposition of the Cotangent Residual (v2)
=====================================================

Uses Möbius-weighted coefficients v_k = μ(k) and 
uniform coefficients v_k = 1 to see the decomposition
in action (the optimal v trivializes the decomposition).
"""

import numpy as np
from math import gcd, log
from functools import lru_cache

def gram_matrix(N):
    """G(j,k) = gcd(j+1,k+1)² / ((j+1)(k+1))."""
    G = np.zeros((N, N))
    for j in range(N):
        for k in range(N):
            g = gcd(j + 1, k + 1)
            G[j, k] = g * g / ((j + 1) * (k + 1))
    return G

@lru_cache(maxsize=None)
def mobius(n):
    """Möbius function μ(n)."""
    if n == 1:
        return 1
    # Factor n
    factors = []
    m = n
    for p in range(2, int(m**0.5) + 1):
        if m % p == 0:
            count = 0
            while m % p == 0:
                m //= p
                count += 1
            if count > 1:
                return 0
            factors.append(p)
    if m > 1:
        factors.append(m)
    return (-1) ** len(factors)

def abel_hammer(v, N):
    """AbelHammer = -(S - Cσ/2)² + C²σ²/4."""
    sigma = np.sum(v)
    S = np.sum(v[k] / (k + 1) for k in range(N))
    C = 1.0
    return -(S - C * sigma / 2)**2 + C**2 * sigma**2 / 4

def log_correction(v, N):
    """LogCorr = σ·T₁ - S·T₂."""
    sigma = np.sum(v)
    S = np.sum(v[k] / (k + 1) for k in range(N))
    f = np.array([log(k + 1) for k in range(N)])
    T1 = np.sum(v * f / np.arange(1, N + 1, dtype=float))
    T2 = np.sum(v * f)
    return sigma * T1 - S * T2

def analyze(N, v, label):
    """Full analysis for given N and coefficient vector v."""
    G = gram_matrix(N)
    
    vtGv = v @ G @ v
    abel = abel_hammer(v, N)
    logcorr = log_correction(v, N)
    cotres = abel + logcorr - vtGv
    
    # Eigendecomposition
    eigenvalues, eigenvectors = np.linalg.eigh(G)
    idx = np.argsort(eigenvalues)
    eigenvalues = eigenvalues[idx]
    eigenvectors = eigenvectors[:, idx]
    
    # Project v
    coeffs = eigenvectors.T @ v
    mode_contribs = eigenvalues * coeffs**2
    
    # Spectral bands for vᵀGv
    edge_contrib = mode_contribs[0]
    bulk_contrib = np.sum(mode_contribs[1:])
    
    print(f"\n  [{label}] N = {N}")
    print(f"  v = [{v[0]:.3f}, {v[1]:.3f}, {v[2]:.3f}, ..., {v[-1]:.3f}]")
    print(f"  σ = Σv = {np.sum(v):.6f}")
    print(f"  S = Σv/(k+1) = {np.sum(v[k]/(k+1) for k in range(N)):.6f}")
    print(f"")
    print(f"  ┌─────────────────────────────────────────────┐")
    print(f"  │  vᵀGv       = {vtGv:+14.8f}                │")
    print(f"  │  AbelHammer = {abel:+14.8f}                │")
    print(f"  │  LogCorr    = {logcorr:+14.8f}                │")
    print(f"  │  CotRes     = {cotres:+14.8f}                │")
    print(f"  │  ─────────────────────────────               │")
    print(f"  │  1 - vᵀGv   = {1 - vtGv:+14.8f}  (Crown)   │")
    print(f"  └─────────────────────────────────────────────┘")
    print(f"")
    print(f"  Spectral decomposition of vᵀGv:")
    print(f"    λ_min mode:  {edge_contrib:+12.8f}  ({100*edge_contrib/vtGv if vtGv != 0 else 0:6.2f}%)")
    print(f"    Bulk modes:  {bulk_contrib:+12.8f}  ({100*bulk_contrib/vtGv if vtGv != 0 else 0:6.2f}%)")
    print(f"")
    print(f"  Decomposition fractions:")
    print(f"    Abel/vᵀGv = {abel/vtGv*100 if vtGv != 0 else 0:+8.3f}%")
    print(f"    LogC/vᵀGv = {logcorr/vtGv*100 if vtGv != 0 else 0:+8.3f}%")
    print(f"    CotR/vᵀGv = {cotres/vtGv*100 if vtGv != 0 else 0:+8.3f}%")
    
    return {
        'vtGv': vtGv, 'abel': abel, 'logcorr': logcorr,
        'cotres': cotres, 'crown': 1 - vtGv,
        'edge': edge_contrib, 'bulk': bulk_contrib,
        'evals': eigenvalues,
    }

if __name__ == '__main__':
    print("╔══════════════════════════════════════════════════════════╗")
    print("║  COTANGENT RESIDUAL: SPECTRAL ANATOMY                  ║")
    print("║  Non-optimal v to see the decomposition structure      ║")
    print("╚══════════════════════════════════════════════════════════╝")
    
    test_Ns = [30, 60, 120, 180, 360]
    
    for N in test_Ns:
        print(f"\n{'='*60}")
        print(f"  N = {N}")
        print(f"{'='*60}")
        
        # v1: Uniform weights (simplest)
        v_uniform = np.ones(N)
        r1 = analyze(N, v_uniform, "UNIFORM v=1")
        
        # v2: Möbius weights (arithmetic)
        v_mobius = np.array([float(mobius(k + 1)) for k in range(N)])
        r2 = analyze(N, v_mobius, "MÖBIUS v=μ(k)")
        
        # v3: Harmonic weights (v_k = 1/k)
        v_harm = np.array([1.0 / (k + 1) for k in range(N)])
        r3 = analyze(N, v_harm, "HARMONIC v=1/k")
        
        # v4: Mertens-like (v_k = μ(k)/k)
        v_mertens = np.array([float(mobius(k+1)) / (k+1) for k in range(N)])
        r4 = analyze(N, v_mertens, "MERTENS v=μ/k")
    
    # Cross-N summary for Möbius weights  
    print(f"\n\n{'='*70}")
    print(f"  SUMMARY: Möbius weights v = μ(k)")
    print(f"{'='*70}")
    print(f"  {'N':>6}  {'vᵀGv':>12}  {'Abel':>12}  {'LogCorr':>12}  {'CotRes':>12}  {'Crown':>12}")
    
    for N in test_Ns:
        v_mobius = np.array([float(mobius(k + 1)) for k in range(N)])
        G = gram_matrix(N)
        vtGv = v_mobius @ G @ v_mobius
        abel = abel_hammer(v_mobius, N)
        logcorr = log_correction(v_mobius, N)
        cotres = abel + logcorr - vtGv
        crown = 1 - vtGv
        print(f"  {N:6d}  {vtGv:12.6f}  {abel:+12.6f}  {logcorr:+12.6f}  {cotres:+12.6f}  {crown:+12.6e}")
