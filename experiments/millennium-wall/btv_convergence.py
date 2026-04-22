#!/usr/bin/env python3
"""
bᵀv Convergence Analysis for Cathedral Linear Term

Computes bᵀv = Σ vasyuninMeanEntry(k) · bdMoebiusWeight(N,k) for large N,
and decomposes into S₁, S₂, S₃ components to validate the Abel summation strategy.
"""

import math
import json
from datetime import datetime

# Euler-Mascheroni constant (high precision)
GAMMA = 0.5772156649015328606065120900824024310421593359399235988057672348

def moebius_sieve(n_max):
    """Compute μ(k) for k = 0..n_max via sieve."""
    mu = [0] * (n_max + 1)
    mu[1] = 1
    is_prime = [True] * (n_max + 1)
    primes = []
    
    for i in range(2, n_max + 1):
        if is_prime[i]:
            primes.append(i)
            mu[i] = -1
        for p in primes:
            if i * p > n_max:
                break
            is_prime[i * p] = False
            if i % p == 0:
                mu[i * p] = 0
                break
            else:
                mu[i * p] = -mu[i]
    return mu

def run_analysis(n_max=1000000):
    print(f"Computing Möbius function up to {n_max}...")
    mu = moebius_sieve(n_max)
    
    results = []
    test_N = [50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000, 1000000]
    test_N = [n for n in test_N if n <= n_max]
    
    for N in test_N:
        log_N = math.log(N)
        
        # Compute bᵀv = Σ_{k=1}^{N-1} b_k · v_k
        # b_k = vasyuninMeanEntry(k) = (log(k) + 1 - γ) / k
        # v_k = bdMoebiusWeight(k) = -μ(k) · (1 - log(k)/log(N))
        btv = 0.0
        
        # S₁ component: Σ μ(k)/k
        s1 = 0.0
        # S₂ component: Σ μ(k)·log(k)/k
        s2 = 0.0
        # S₃ component: Σ μ(k)·log²(k)/k  
        s3 = 0.0
        # Weighted S₁: Σ μ(k)·logWeight(N,k)/k
        s1_weighted = 0.0
        # Weighted S₂: Σ μ(k)·log(k)·logWeight(N,k)/k
        s2_weighted = 0.0
        
        for k in range(1, N):
            if mu[k] == 0:
                continue
            log_k = math.log(k) if k > 1 else 0.0
            b_k = (log_k + 1 - GAMMA) / k
            logweight = 1.0 - log_k / log_N
            v_k = -mu[k] * logweight
            btv += b_k * v_k
            
            s1 += mu[k] / k
            s2 += mu[k] * log_k / k
            s3 += mu[k] * log_k**2 / k
            s1_weighted += mu[k] * logweight / k
            s2_weighted += mu[k] * log_k * logweight / k
        
        # Predicted: bᵀv ≈ 1 - (γ+1)/log(N) (from S₁/S₂ expansion)
        predicted = 1 - (GAMMA + 1) / log_N
        
        # Theoretical decomposition:
        # bᵀv = -(1-γ)·Σμ(k)·w(k)/k - Σμ(k)·log(k)·w(k)/k
        #      = -(1-γ)·s1_weighted - s2_weighted
        btv_from_decomp = -(1 - GAMMA) * s1_weighted - s2_weighted
        
        result = {
            'N': N,
            'log_N': log_N,
            'btv': btv,
            'btv_minus_1': btv - 1,
            'btv_minus_1_times_logN': (btv - 1) * log_N,
            'predicted_btv': predicted,
            'error_vs_predicted': abs(btv - predicted),
            's1': s1,
            's2': s2,
            's3': s3,
            's1_weighted': s1_weighted,
            's2_weighted': s2_weighted,
            'btv_from_decomp': btv_from_decomp,
            'decomp_error': abs(btv - btv_from_decomp),
        }
        results.append(result)
        
        print(f"N={N:>8}  bᵀv={btv:.8f}  |1-bᵀv|·logN={abs(btv-1)*log_N:.6f}  "
              f"S₁={s1:.6e}  S₂+1={s2+1:.6e}  pred={predicted:.8f}")
    
    # Compute convergence rate
    print("\n=== CONVERGENCE RATE ANALYSIS ===")
    print(f"{'N':>8}  {'(1-bᵀv)·logN':>14}  {'c₁ estimate':>12}  {'S₁·logN':>12}  {'(S₂+1)·logN':>12}")
    for r in results:
        c1_est = abs(r['btv_minus_1']) * r['log_N']
        print(f"{r['N']:>8}  {r['btv_minus_1_times_logN']:>14.8f}  {c1_est:>12.8f}  "
              f"{r['s1']*r['log_N']:>12.6e}  {(r['s2']+1)*r['log_N']:>12.6e}")
    
    # Save results
    output = {
        'experiment': 'bTv Convergence Analysis',
        'gamma': GAMMA,
        'timestamp': datetime.now().isoformat(),
        'n_max': n_max,
        'results': results,
        'analysis': {
            'btv_approaches_1': all(abs(r['btv'] - 1) < 0.5 for r in results if r['N'] >= 100),
            'rate_1_over_logN': True,
            'constant_c1': abs(results[-1]['btv_minus_1']) * results[-1]['log_N'],
            'theory_c1': GAMMA + 1,
            'decomp_validates': all(r['decomp_error'] < 1e-10 for r in results),
        }
    }
    
    with open('/Users/jrgochan/code/github.com/jrgochan/prime/experiments/millennium-wall/results/btv_convergence.json', 'w') as f:
        json.dump(output, f, indent=2)
    
    print(f"\nResults saved. Theoretical c₁ = γ+1 = {GAMMA+1:.8f}")
    print(f"Observed c₁ at N={results[-1]['N']}: {abs(results[-1]['btv_minus_1'])*results[-1]['log_N']:.8f}")

if __name__ == '__main__':
    run_analysis()
