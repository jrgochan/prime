#!/usr/bin/env python3
"""Investigate d² discrepancies between Cholesky implementations."""
import numpy as np
from numpy.linalg import cholesky, solve

EULER_GAMMA = 0.5772156649015328606

def b_vector_nb(dim):
    """Nyman-Beurling b-vector: b_k = (ln(k) + 1 - gamma) / k for k=2..dim+1"""
    return np.array([(np.log(k) + 1.0 - EULER_GAMMA) / k for k in range(2, dim + 2)])

def b_vector_naive(dim):
    """Naive b-vector: b_k = 1/k for k=2..dim+1"""
    return np.array([1.0/k for k in range(2, dim + 2)])

def read_ooc(path, dim):
    with open(path, 'rb') as f:
        f.read(40)
        return np.frombuffer(f.read(dim*dim*8), dtype=np.float64).reshape(dim, dim)

SEP = '=' * 70

print(SEP)
print('d-squared CHOLESKY INVESTIGATION')
print('Which b-vector and which Cholesky gives the best answer?')
print(SEP)

for N in [100, 1000]:
    dim = N - 1
    path = f'/mnt/d/cathedral-cache/ooc_gram_N{N}_p256.bin'
    G = read_ooc(path, dim)
    
    print(f'\n{SEP}')
    print(f'N = {N}, dim = {dim}')
    print(SEP)
    
    b_nb = b_vector_nb(dim)
    b_naive = b_vector_naive(dim)
    
    print(f'  b_nb[0:3]    = {b_nb[:3]}')
    print(f'  b_naive[0:3] = {b_naive[:3]}')
    print(f'  Ratio b_nb/b_naive[0] = {b_nb[0]/b_naive[0]:.6f}')
    print()
    
    # ── Condition number ──
    eigvals = np.linalg.eigvalsh(G)
    cond = eigvals[-1] / eigvals[0]
    print(f'  Condition number: {cond:.2e}')
    print(f'  lambda_min = {eigvals[0]:.6e}')
    print(f'  lambda_max = {eigvals[-1]:.6e}')
    print(f'  Effective digits lost: {np.log10(cond):.1f}')
    print()
    
    d2_results = {}
    
    # Method 1: numpy Cholesky (LAPACK dpotrf)
    try:
        L = cholesky(G)
        y = solve(L, b_nb)
        d2 = 1 - np.dot(y, y)
        d2_results['numpy_chol_nb'] = d2
        print(f'  numpy Cholesky + NB b-vec:    d2 = {d2:.15e}')
        
        y_naive = solve(L, b_naive)
        d2_naive = 1 - np.dot(y_naive, y_naive)
        d2_results['numpy_chol_naive'] = d2_naive
        print(f'  numpy Cholesky + naive b-vec: d2 = {d2_naive:.15e}')
    except Exception as e:
        print(f'  numpy Cholesky FAILED: {e}')
    
    # Method 2: numpy solve (LU via LAPACK dgesv)
    try:
        x = np.linalg.solve(G, b_nb)
        d2 = 1 - np.dot(b_nb, x)
        d2_results['numpy_lu_nb'] = d2
        print(f'  numpy LU     + NB b-vec:     d2 = {d2:.15e}')
    except Exception as e:
        print(f'  numpy LU FAILED: {e}')
    
    # Method 3: scipy Cholesky (cho_factor + cho_solve)
    try:
        from scipy.linalg import cho_factor, cho_solve
        c, low = cho_factor(G)
        x = cho_solve((c, low), b_nb)
        d2 = 1 - np.dot(b_nb, x)
        d2_results['scipy_chol_nb'] = d2
        print(f'  scipy Chol   + NB b-vec:     d2 = {d2:.15e}')
    except ImportError:
        print(f'  scipy not available')
    except Exception as e:
        print(f'  scipy Cholesky FAILED: {e}')
    
    # Method 4: hand-rolled Cholesky (matches Rust OOC verify)
    sub = G.copy()
    n = len(sub)
    ok = True
    for j in range(n):
        s = sub[j,j] - np.dot(sub[j,:j], sub[j,:j])
        if s <= 0:
            print(f'  hand Chol FAILED at col {j}')
            ok = False
            break
        sub[j,j] = np.sqrt(s)
        for i in range(j+1, n):
            sub[i,j] = (sub[i,j] - np.dot(sub[i,:j], sub[j,:j])) / sub[j,j]
            sub[j,i] = 0  # zero upper triangle
    if ok:
        # Forward solve L y = b
        y_hand = np.zeros(n)
        for i in range(n):
            y_hand[i] = (b_nb[i] - np.dot(sub[i,:i], y_hand[:i])) / sub[i,i]
        d2 = 1 - np.dot(y_hand, y_hand)
        d2_results['hand_chol_nb'] = d2
        print(f'  hand Chol    + NB b-vec:     d2 = {d2:.15e}')
    
    # Method 5: Direct G^{-1} computation (expensive but maximally stable)
    try:
        Ginv = np.linalg.inv(G)
        d2 = 1 - b_nb @ Ginv @ b_nb
        d2_results['direct_inv_nb'] = d2
        print(f'  Direct inv   + NB b-vec:     d2 = {d2:.15e}')
    except Exception as e:
        print(f'  Direct inv FAILED: {e}')
    
    # Method 6: Eigendecomposition solve (most stable for ill-conditioned)
    try:
        eigvals_full, eigvecs = np.linalg.eigh(G)
        # G^{-1} b = V diag(1/λ) V^T b
        bt = eigvecs.T @ b_nb
        x_eig = eigvecs @ (bt / eigvals_full)
        d2 = 1 - np.dot(b_nb, x_eig)
        d2_results['eig_nb'] = d2
        print(f'  Eigendecomp  + NB b-vec:     d2 = {d2:.15e}')
    except Exception as e:
        print(f'  Eigendecomp FAILED: {e}')
    
    # ── Comparison with Rust values ──
    rust_gpu = {100: 4.309489557335522e-2, 1000: 4.145802262727005e-2}
    rust_ooc_verify = {100: 4.309489707940439e-2, 1000: 4.184314781492582e-2}
    
    print()
    print(f'  --- Reference (Rust) ---')
    print(f'  GPU nalgebra Chol + NB b:    d2 = {rust_gpu[N]:.15e}')
    print(f'  OOC hand Chol + NB b:        d2 = {rust_ooc_verify[N]:.15e}')
    
    print()
    print(f'  --- Deltas ---')
    for name, val in d2_results.items():
        delta_gpu = abs(val - rust_gpu[N])
        delta_ooc = abs(val - rust_ooc_verify[N])
        marker = '✓' if delta_gpu < 1e-10 else ('~' if delta_gpu < 1e-6 else '✗')
        print(f'  {marker} {name:30s}  Δ(vs GPU)={delta_gpu:.2e}  Δ(vs OOC)={delta_ooc:.2e}')
    
    # N=1000: OOC verify only uses sub-500, so show that separately
    if N == 1000:
        print()
        print(f'  NOTE: OOC verify uses sub-500 Cholesky (d2_501), not full d2_1000')
        print(f'  GPU nalgebra uses full 999x999 Cholesky')
        # Compute d2_501 via numpy for comparison
        sub500 = G[:500, :500]
        b500 = b_nb[:500]
        L500 = cholesky(sub500)
        y500 = solve(L500, b500)
        d2_500 = 1 - np.dot(y500, y500)
        print(f'  numpy Chol (500x500) + NB b: d2 = {d2_500:.15e}')
        print(f'  Rust OOC verify (500x500):   d2 = {rust_ooc_verify[N]:.15e}')
        print(f'  Delta: {abs(d2_500 - rust_ooc_verify[N]):.2e}')

print()
print(SEP)
print('CONCLUSION: All methods should agree to ~10-12 digits for well-conditioned matrices.')
print('Remaining disagreement is due to finite f64 arithmetic accumulation.')
print(SEP)
