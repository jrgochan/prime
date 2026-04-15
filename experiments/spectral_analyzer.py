#!/usr/bin/env python3
"""
Spectral Analyzer — Cathedral Log Cutoff Witness on the Critical Line

Computes the Dirichlet polynomial D_N(1/2 + it) = Σ v_k · k^{-1/2-it}
where v_k = -μ(k)(1 - ln(k)/ln(N)) is the Cathedral's log cutoff witness.

Sweeps t along the critical line and plots |D_N(1/2+it)|^2, overlaying
the known Riemann zeta zeros to test for spectral resonance.
"""

import numpy as np
import math
import time

# ============================================================
# Möbius sieve
# ============================================================
def mobius_sieve(n: int) -> np.ndarray:
    """Compute μ(k) for k = 0, 1, ..., n using a sieve."""
    mu = np.zeros(n + 1, dtype=np.int8)
    mu[1] = 1
    is_prime = np.ones(n + 1, dtype=bool)
    primes = []

    for i in range(2, n + 1):
        if is_prime[i]:
            primes.append(i)
            mu[i] = -1  # prime => μ = -1
        for p in primes:
            if i * p > n:
                break
            is_prime[i * p] = False
            if i % p == 0:
                mu[i * p] = 0  # p^2 | ip => μ = 0
                break
            else:
                mu[i * p] = -mu[i]

    return mu


# ============================================================
# Known Riemann zeta zeros (imaginary parts, first 30)
# From Odlyzko's tables
# ============================================================
RIEMANN_ZEROS = [
    14.134725, 21.022040, 25.010858, 30.424876, 32.935062,
    37.586178, 40.918719, 43.327073, 48.005151, 49.773832,
    52.970321, 56.446248, 59.347044, 60.831779, 65.112544,
    67.079811, 69.546402, 72.067158, 75.704691, 77.144840,
    79.337375, 82.910381, 84.735493, 87.425275, 88.809111,
    92.491899, 94.651344, 95.870634, 98.831194, 101.317851,
]


# ============================================================
# Spectral energy computation
# ============================================================
def compute_spectrum(N: int, t_values: np.ndarray) -> np.ndarray:
    """
    Compute |D_N(1/2 + it)|^2 for each t in t_values.

    D_N(s) = Σ_{k=1}^{N} v_k · k^{-s}
    where v_k = -μ(k) · (1 - ln(k)/ln(N))
    and s = 1/2 + it.
    """
    print(f"Computing Möbius sieve up to N={N}...")
    t0 = time.time()
    mu = mobius_sieve(N)
    print(f"  Sieve complete in {time.time()-t0:.2f}s")

    # Precompute witness weights and k^{-1/2}
    ln_N = math.log(N)
    k_arr = np.arange(1, N + 1, dtype=np.float64)
    ln_k = np.log(k_arr)
    envelope = 1.0 - ln_k / ln_N       # (1 - ln(k)/ln(N))
    mu_arr = mu[1:N+1].astype(np.float64)
    v = -mu_arr * envelope               # v_k = -μ(k)(1 - ln(k)/ln(N))
    k_half = k_arr ** (-0.5)             # k^{-1/2}
    coeffs = v * k_half                  # v_k · k^{-1/2}

    # For each t, compute D_N = Σ coeffs[k] · exp(-i·t·ln(k))
    print(f"Computing spectral energy for {len(t_values)} values of t...")
    t0 = time.time()

    energy = np.zeros(len(t_values))
    # Process in chunks to manage memory
    chunk_size = 500
    for i in range(0, len(t_values), chunk_size):
        t_chunk = t_values[i:i+chunk_size]
        # Phase matrix: rows = t values, cols = k values
        phases = np.outer(t_chunk, ln_k)  # shape (chunk, N)
        # D_N(t) = Σ coeffs[k] · exp(-i·t·ln(k))
        D = np.sum(coeffs[np.newaxis, :] * np.exp(-1j * phases), axis=1)
        energy[i:i+len(t_chunk)] = np.abs(D) ** 2
        if (i + chunk_size) % 5000 == 0:
            print(f"  Progress: {min(i+chunk_size, len(t_values))}/{len(t_values)}")

    print(f"  Spectrum complete in {time.time()-t0:.2f}s")
    return energy


def main():
    N = 50_000
    t_min, t_max = 0.5, 100.0
    dt = 0.01
    t_values = np.arange(t_min, t_max, dt)

    print("=" * 60)
    print(f"SPECTRAL ANALYZER — Cathedral Log Cutoff Witness")
    print(f"N = {N}, t ∈ [{t_min}, {t_max}], Δt = {dt}")
    print("=" * 60)

    energy = compute_spectrum(N, t_values)

    # ============================================================
    # Results: energy near Riemann zeros
    # ============================================================
    print("\n" + "=" * 60)
    print("RESULTS: Spectral energy near Riemann zeros")
    print("=" * 60)

    # Background stats (avoid the low-t region which has edge effects)
    bg_mask = np.ones(len(t_values), dtype=bool)
    for z in RIEMANN_ZEROS:
        bg_mask &= np.abs(t_values - z) > 1.0
    bg_energy = energy[bg_mask & (t_values > 10)]
    bg_mean = np.mean(bg_energy)
    bg_std = np.std(bg_energy)
    bg_median = np.median(bg_energy)

    print(f"\nBackground (|t - zeros| > 1.0, t > 10):")
    print(f"  Mean:   {bg_mean:.4f}")
    print(f"  Median: {bg_median:.4f}")
    print(f"  StdDev: {bg_std:.4f}")

    print(f"\n{'Zero':>8}  {'t_peak':>8}  {'Energy':>10}  {'Ratio':>8}  {'σ above':>8}")
    print("-" * 52)

    for z in RIEMANN_ZEROS:
        if z > t_max:
            break
        # Find peak in a window around the zero
        window = 0.5
        mask = np.abs(t_values - z) < window
        if not np.any(mask):
            continue
        idx = np.argmax(energy[mask])
        local_t = t_values[mask][idx]
        local_e = energy[mask][idx]
        ratio = local_e / bg_mean if bg_mean > 0 else 0
        sigma = (local_e - bg_mean) / bg_std if bg_std > 0 else 0
        print(f"  {z:7.3f}  {local_t:8.3f}  {local_e:10.4f}  {ratio:7.2f}×  {sigma:7.1f}σ")

    # ============================================================
    # Also check: are the TOP peaks near zeros?
    # ============================================================
    print(f"\n{'=' * 60}")
    print("TOP 15 PEAKS (t > 5):")
    print("=" * 60)

    valid = t_values > 5.0
    valid_t = t_values[valid]
    valid_e = energy[valid]

    # Find local maxima
    peaks = []
    for i in range(1, len(valid_e) - 1):
        if valid_e[i] > valid_e[i-1] and valid_e[i] > valid_e[i+1]:
            peaks.append((valid_t[i], valid_e[i]))

    peaks.sort(key=lambda x: -x[1])

    print(f"\n{'Rank':>4}  {'t':>8}  {'Energy':>10}  {'Nearest zero':>13}  {'Δt':>8}")
    print("-" * 50)
    for rank, (t, e) in enumerate(peaks[:15], 1):
        # Find nearest Riemann zero
        dists = [abs(t - z) for z in RIEMANN_ZEROS]
        nearest_idx = np.argmin(dists)
        nearest_z = RIEMANN_ZEROS[nearest_idx]
        delta = t - nearest_z
        print(f"  {rank:3d}  {t:8.3f}  {e:10.4f}  {nearest_z:12.3f}  {delta:+8.3f}")

    # ============================================================
    # Save data for plotting
    # ============================================================
    outfile = "spectral_analyzer_output.tsv"
    print(f"\nSaving data to {outfile}...")
    with open(outfile, "w") as f:
        f.write("t\tenergy\n")
        for t, e in zip(t_values, energy):
            f.write(f"{t:.4f}\t{e:.6f}\n")
    print(f"Done. {len(t_values)} data points saved.")
    print(f"\nRiemann zeros used: {RIEMANN_ZEROS[:10]}...")


if __name__ == "__main__":
    main()
