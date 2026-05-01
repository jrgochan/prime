#!/usr/bin/env python3
"""Compute the Selberg-Delange parameter alpha from microscopic prime data."""
import numpy as np
import math

gamma = 0.5772156649015329

# Load N=40000 coefficients
data = np.loadtxt("experiments/cache/unconstrained_coeffs_N40000.tsv", comments="#")
coeffs = {int(row[0]): row[1] for row in data}
N = 40001

# Sieve primes
sieve = [True] * (N + 1)
sieve[0] = sieve[1] = False
primes = []
for p in range(2, N + 1):
    if sieve[p]:
        primes.append(p)
        for m in range(p * p, N + 1, p):
            sieve[m] = False

def b(k):
    return (math.log(k) + 1 - gamma) / k

print("=" * 70)
print("SELBERG-DELANGE PARAMETER: MICROSCOPIC → MACROSCOPIC")
print("=" * 70)

# ── Local Euler factors ──
print("\nLocal factors L_p = (1-1/p) · [1 + Sigma_k a*(p^k)b(p^k)/p^k]:")
print("   p   |    a*(p)    |   sum_k      |     L_p      |   ln(L_p)  ")
print("-" * 70)

log_product = 0.0
log_product_prime_only = 0.0

for p in primes:
    local_sum = 0.0
    pk = p
    while pk <= N:
        if pk in coeffs:
            local_sum += coeffs[pk] * b(pk) / pk
        pk *= p

    L_p = (1 - 1.0/p) * (1 + local_sum)
    a_p = coeffs.get(p, 0)
    L_p_prime_only = (1 - 1.0/p) * (1 + a_p * b(p) / p)

    if p <= 43 or p in [97, 101, 997, 1009]:
        lnL = math.log(L_p) if L_p > 0 else float('nan')
        print(f"  {p:5d} | {a_p:+10.6f} | {local_sum:+12.8f} | {L_p:12.8f} | {lnL:10.6f}")

    if L_p > 0:
        log_product += math.log(L_p)
    if L_p_prime_only > 0:
        log_product_prime_only += math.log(L_p_prime_only)

alpha_full = math.exp(log_product)
alpha_prime = math.exp(log_product_prime_only)

print(f"\n  Gemini formula (all prime powers): alpha = {alpha_full:.8f}")
print(f"  Prime-only terms:                  alpha = {alpha_prime:.8f}")
print(f"  Empirical alpha (d^2 fit):         alpha = 0.1707")

# ── Approach 2: z-parameter ──
z_sum = sum(coeffs.get(p, 0) * b(p) / p for p in primes)
print(f"\n  SD z = Sigma_p a*(p)b(p)/p = {z_sum:.8f}")
print(f"  (If z ~ alpha, match? {abs(z_sum - 0.17) < 0.05})")

# ── Approach 3: Running prime sum S(x) ──
print(f"\n  Running sum S(x) = Sigma_{{p<=x}} a*(p)·b(p):")
print(f"       x |      S(x) |    ln S |   ln ln x |   S/ln(x)  |  S/ln(x)^2")
print("-" * 75)

running = 0.0
checkpoints = [100, 500, 1000, 2000, 5000, 10000, 20000, 40000]
cp_idx = 0
xs_fit, ss_fit = [], []
for p in primes:
    running += coeffs.get(p, 0) * b(p)
    while cp_idx < len(checkpoints) and p >= checkpoints[cp_idx]:
        x = checkpoints[cp_idx]
        lnx = math.log(x)
        print(f"  {x:7d} | {running:9.4f} | {math.log(running):7.4f} | {math.log(lnx):9.4f} | {running/lnx:10.4f} | {running/lnx**2:10.4f}")
        xs_fit.append(x)
        ss_fit.append(running)
        cp_idx += 1

# Fit S(x) ~ C · ln(x)^beta
if len(xs_fit) >= 3:
    ln_s = [math.log(s) for s in ss_fit]
    ln_lnx = [math.log(math.log(x)) for x in xs_fit]
    n = len(xs_fit)
    mx = sum(ln_lnx) / n
    my = sum(ln_s) / n
    cov = sum((a-mx)*(b-my) for a,b in zip(ln_lnx, ln_s))
    vx = sum((a-mx)**2 for a in ln_lnx)
    beta = cov / vx
    ln_C = my - beta * mx
    C_fit = math.exp(ln_C)
    print(f"\n  Fit: S(x) = {C_fit:.4f} · ln(x)^{beta:.4f}")

# ── Approach 4: Single-prime Euler product ──
print(f"\n  Single-prime Euler product:")
log_ep = 0.0
for p in primes:
    local = 1.0
    pk = p
    while pk <= N:
        if pk in coeffs:
            local += coeffs[pk] * b(pk)
        pk *= p
    if local > 0:
        log_ep += math.log(local)

ep = math.exp(log_ep)
print(f"  Pi_p (1 + Sigma_k a*(p^k)b(p^k)) = {ep:.6f}")
print(f"  ln(product) = {log_ep:.6f}")

# ── Approach 5: What value of z makes F(s) = zeta(s)^z * nice? ──
# F(1) ~ E_N = 0.6627
# zeta(s)^z ~ (1/(s-1))^z as s->1
# This doesn't directly give z since F(1) is finite and zeta(1) = inf
# Instead: look at the partial Euler product and compare to (ln N)^z

print(f"\n  What z satisfies Pi_p^N (factor) ~ (ln N)^z?")
print(f"  ln(EP) = {log_ep:.6f}")
print(f"  ln(ln(40000)) = {math.log(math.log(40000)):.6f}")
z_est = log_ep / math.log(math.log(40000))
print(f"  z_estimate = ln(EP) / ln(ln N) = {z_est:.6f}")

# Same for N=20000
data20 = np.loadtxt("experiments/cache/unconstrained_coeffs_N20000.tsv", comments="#")
coeffs20 = {int(row[0]): row[1] for row in data20}
log_ep20 = 0.0
for p in primes:
    if p > 20001: break
    local = 1.0
    pk = p
    while pk <= 20001:
        if pk in coeffs20:
            local += coeffs20[pk] * b(pk)
        pk *= p
    if local > 0:
        log_ep20 += math.log(local)

z_est20 = log_ep20 / math.log(math.log(20000))
print(f"  z_estimate (N=20K) = {log_ep20:.6f} / {math.log(math.log(20000)):.6f} = {z_est20:.6f}")

# ── Summary ──
print(f"\n{'='*70}")
print(f"SUMMARY: CANDIDATE ALPHA VALUES")
print(f"{'='*70}")
print(f"  Empirical alpha (d^2 ~ C/ln(N)^a):  0.1707")
print(f"  Gemini Euler product:                 {alpha_full:.6f}")
print(f"  Prime-only Euler product:             {alpha_prime:.6f}")
print(f"  SD z-parameter Sigma f(p)/p:          {z_sum:.6f}")
print(f"  z from ln(EP)/ln(ln N) at N=40K:      {z_est:.6f}")
print(f"  z from ln(EP)/ln(ln N) at N=20K:      {z_est20:.6f}")
