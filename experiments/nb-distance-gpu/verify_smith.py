#!/usr/bin/env python3
"""
Verify the Smith-Woodbury theory with the CORRECT b-vector.

KEY CORRECTION: b_k = (ln k + 1 - gamma) / k, NOT 1/k!
Gemini's claim: L^{-1} D^{-1} b = Lambda(k) exactly.
"""
import numpy as np
import math

N = 200
dim = N - 1
gamma = 0.5772156649015329

print("=" * 70)
print("SMITH-WOODBURY VERIFICATION (CORRECT b-vector)")
print(f"N = {N}, dim = {dim}")
print("=" * 70)

# Correct b-vector: (ln k + 1 - gamma) / k
b_correct = np.array([(math.log(k+2) + 1 - gamma) / (k+2) for k in range(dim)])
# Wrong b-vector I used before
b_wrong = np.array([1.0 / (k+2) for k in range(dim)])

print(f"\nb_correct[0] (k=2) = {b_correct[0]:.8f}  vs  b_wrong[0] = {b_wrong[0]:.8f}")
print(f"b_correct[1] (k=3) = {b_correct[1]:.8f}  vs  b_wrong[1] = {b_wrong[1]:.8f}")

# Mobius function
def mobius(n):
    if n == 1: return 1
    factors = 0
    temp = n
    d = 2
    while d * d <= temp:
        if temp % d == 0:
            factors += 1
            temp //= d
            if temp % d == 0: return 0
        d += 1
    if temp > 1: factors += 1
    return (-1) ** factors

# Divisibility matrix L and its inverse
L = np.zeros((dim, dim))
Linv = np.zeros((dim, dim))
for i in range(dim):
    for j in range(dim):
        ni, nj = i+2, j+2
        if nj <= ni and ni % nj == 0:
            L[i, j] = 1.0
            Linv[i, j] = mobius(ni // nj)

# Verify L * Linv = I
err = np.max(np.abs(L @ Linv - np.eye(dim)))
print(f"\n||L * L^-1 - I|| = {err:.2e}")

# D_diag = diagonal scaling: D[k] = 1/k (maps b to ln k + 1 - gamma)
# Actually D^{-1} = diag(k), so D^{-1} b = k * b_k = ln k + 1 - gamma
D_inv = np.diag(np.array([k+2 for k in range(dim)], dtype=float))
D = np.diag(np.array([1.0/(k+2) for k in range(dim)]))

# Step 1: D^{-1} b = k * b_k = ln(k) + 1 - gamma
Dinv_b = D_inv @ b_correct
print("\n--- Step 1: D^{-1} b = ln(k) + 1 - gamma ---")
for k in [2, 3, 5, 7, 10, 30]:
    idx = k - 2
    expected = math.log(k) + 1 - gamma
    print(f"  k={k:3d}: D^-1 b = {Dinv_b[idx]:.8f}  expected = {expected:.8f}  err = {abs(Dinv_b[idx]-expected):.2e}")

# Step 2: L^{-1} (D^{-1} b) = mu * (ln + 1 - gamma)
Linv_Dinv_b = Linv @ Dinv_b
print("\n--- Step 2: L^{-1} D^{-1} b = mu * (ln + 1 - gamma) ---")
print("  If Gemini is right, this should equal Lambda(k) exactly")

# Von Mangoldt function
def von_mangoldt(n):
    if n < 2: return 0
    temp = n
    for p in range(2, n+1):
        if p * p > temp and temp > 1:
            if temp == n:
                return math.log(n)
            break
        if temp % p == 0:
            temp2 = temp
            while temp2 % p == 0:
                temp2 //= p
            if temp2 == 1:
                return math.log(p)
            break
    return 0

print("\n  k  | L^{-1} D^{-1} b | Lambda(k) | Difference")
print("  " + "-" * 55)
max_err = 0
for k in range(2, min(N+1, 51)):
    idx = k - 2
    lam_k = von_mangoldt(k)
    val = Linv_Dinv_b[idx]
    err = abs(val - lam_k)
    max_err = max(max_err, err)
    if k <= 20 or k in [30, 50] or lam_k > 0:
        marker = " <-- prime power" if lam_k > 0 else ""
        print(f"  {k:3d} | {val:+.10f} | {lam_k:.10f} | {err:.2e}{marker}")

print(f"\n  Max error over k=2..{min(N,50)}: {max_err:.2e}")

# Correlation
lam_vals = np.array([von_mangoldt(k+2) for k in range(dim)])
corr = np.corrcoef(Linv_Dinv_b, lam_vals)[0, 1]
print(f"  Corr(L^-1 D^-1 b, Lambda) = {corr:.10f}")

# Now test the full Woodbury structure
print("\n" + "=" * 70)
print("WOODBURY STRUCTURE TEST")
print("=" * 70)

# Build the pure Smith matrix M(j,k) = gcd(j,k)^2 / (2*j*k)
M = np.zeros((dim, dim))
for i in range(dim):
    for j in range(dim):
        g = math.gcd(i+2, j+2)
        M[i, j] = g * g / (2.0 * (i+2) * (j+2))

# Build the rank-2 perturbation: R = (1/2)(u 1^T + 1 u^T) where u_j = 1/(2j)
u = np.array([1.0 / (2*(k+2)) for k in range(dim)])
ones = np.ones(dim)
R = 0.5 * (np.outer(u, ones) + np.outer(ones, u))

# Predicted Gram: G_pred = R - M
G_pred = R - M

# Build actual Gram
def gram_entry(j, k, T=5000):
    s = 0.0
    for n in range(1, T+1):
        fj = (n % j) / j
        fk = (n % k) / k
        s += fj * fk / (n * (n + 1))
    return s

print("\nBuilding actual Gram matrix (T=5000)...")
G = np.zeros((dim, dim))
for i in range(dim):
    for j in range(i, dim):
        v = gram_entry(i+2, j+2)
        G[i, j] = v
        G[j, i] = v

# Compare G vs G_pred
err_matrix = G - G_pred
rel_err = np.max(np.abs(err_matrix)) / np.max(np.abs(G))
print(f"\n||G - (R - M)||_max = {np.max(np.abs(err_matrix)):.6e}")
print(f"||G||_max = {np.max(np.abs(G)):.6e}")
print(f"Relative error = {rel_err:.6e}")

# Sample entries
print("\n  (j,k) |  G_actual   |  G_pred=R-M |  Error")
for j, k in [(2,2), (2,3), (2,5), (3,5), (6,10), (10,15)]:
    i1, i2 = j-2, k-2
    print(f"  ({j},{k:2d}) | {G[i1,i2]:.8f} | {G_pred[i1,i2]:.8f} | {abs(G[i1,i2]-G_pred[i1,i2]):.2e}")

# Test Smith factorization on M alone
print("\n--- Smith factorization of M = gcd^2/(2jk) ---")
D_m = Linv @ M @ Linv.T
off_m = np.sqrt(np.sum(D_m**2) - np.sum(np.diag(D_m)**2))
diag_m = np.sqrt(np.sum(np.diag(D_m)**2))
print(f"||D_off||_F / ||D_diag||_F = {off_m/diag_m:.6e}")
print(f"First 5 diagonal of L^-1 M L^-T: {np.diag(D_m)[:5]}")
