#!/usr/bin/env python3
"""
Spectral Comparison — Does the log taper matter?

Compares three witness vectors on the critical line:
  1. Log cutoff:  v_k = -μ(k)(1 - ln(k)/ln(N))   [Cathedral witness]
  2. Flat Möbius: v_k = -μ(k)                       [raw inverse zeta]
  3. Sharp cutoff: v_k = -μ(k)·1_{k ≤ N/2}          [hard truncation at N/2]

Measures signal-to-noise ratio, peak sharpness, and spectral resolution
at the first 15 Riemann zeros.
"""

import numpy as np
import math
import time

# ============================================================
# Möbius sieve
# ============================================================
def mobius_sieve(n: int) -> np.ndarray:
    mu = np.zeros(n + 1, dtype=np.int8)
    mu[1] = 1
    is_prime = np.ones(n + 1, dtype=bool)
    primes = []
    for i in range(2, n + 1):
        if is_prime[i]:
            primes.append(i)
            mu[i] = -1
        for p in primes:
            if i * p > n:
                break
            is_prime[i * p] = False
            if i % p == 0:
                mu[i * p] = 0
                break
            else:
                mu[i * p] = -mu[i]
    return mu


RIEMANN_ZEROS = [
    14.134725, 21.022040, 25.010858, 30.424876, 32.935062,
    37.586178, 40.918719, 43.327073, 48.005151, 49.773832,
    52.970321, 56.446248, 59.347044, 60.831779, 65.112544,
]


def compute_spectrum_with_weights(weights: np.ndarray, N: int, t_values: np.ndarray) -> np.ndarray:
    k_arr = np.arange(1, N + 1, dtype=np.float64)
    ln_k = np.log(k_arr)
    k_half = k_arr ** (-0.5)
    coeffs = weights * k_half

    energy = np.zeros(len(t_values))
    chunk_size = 500
    for i in range(0, len(t_values), chunk_size):
        t_chunk = t_values[i:i+chunk_size]
        phases = np.outer(t_chunk, ln_k)
        D = np.sum(coeffs[np.newaxis, :] * np.exp(-1j * phases), axis=1)
        energy[i:i+len(t_chunk)] = np.abs(D) ** 2
    return energy


def analyze_spectrum(name: str, energy: np.ndarray, t_values: np.ndarray):
    """Compute SNR and peak statistics."""
    # Background (away from zeros, t > 10)
    bg_mask = np.ones(len(t_values), dtype=bool)
    for z in RIEMANN_ZEROS:
        bg_mask &= np.abs(t_values - z) > 1.0
    bg_mask &= t_values > 10
    bg = energy[bg_mask]
    bg_mean = np.mean(bg)
    bg_std = np.std(bg)
    bg_median = np.median(bg)

    # Peak detection at each zero
    peak_energies = []
    peak_widths = []
    for z in RIEMANN_ZEROS:
        if z > np.max(t_values):
            break
        window = 0.5
        mask = np.abs(t_values - z) < window
        if not np.any(mask):
            continue
        idx_peak = np.argmax(energy[mask])
        peak_e = energy[mask][idx_peak]
        peak_energies.append(peak_e)

        # Measure FWHM (half-max width)
        half_max = peak_e / 2.0
        local_e = energy[mask]
        local_t = t_values[mask]
        above_half = local_t[local_e >= half_max]
        if len(above_half) >= 2:
            fwhm = above_half[-1] - above_half[0]
        else:
            fwhm = 0.0
        peak_widths.append(fwhm)

    peak_energies = np.array(peak_energies)
    peak_widths = np.array(peak_widths)

    # SNR metrics
    avg_peak = np.mean(peak_energies)
    avg_snr = avg_peak / bg_mean if bg_mean > 0 else 0
    avg_sigma = (avg_peak - bg_mean) / bg_std if bg_std > 0 else 0
    avg_fwhm = np.mean(peak_widths)
    # Dynamic range: ratio of strongest to weakest peak
    dynamic_range = np.max(peak_energies) / np.min(peak_energies) if len(peak_energies) > 0 else 0

    return {
        "name": name,
        "bg_mean": bg_mean,
        "bg_median": bg_median,
        "bg_std": bg_std,
        "avg_peak": avg_peak,
        "avg_snr": avg_snr,
        "avg_sigma": avg_sigma,
        "avg_fwhm": avg_fwhm,
        "dynamic_range": dynamic_range,
        "peak_energies": peak_energies,
        "peak_widths": peak_widths,
    }


def main():
    N = 50_000
    t_min, t_max = 0.5, 70.0
    dt = 0.005  # Higher resolution for FWHM measurement
    t_values = np.arange(t_min, t_max, dt)

    print("=" * 70)
    print("SPECTRAL COMPARISON — Does the log taper matter?")
    print(f"N = {N}, t ∈ [{t_min}, {t_max}], Δt = {dt}")
    print("=" * 70)

    # Sieve
    mu = mobius_sieve(N)
    mu_arr = mu[1:N+1].astype(np.float64)
    k_arr = np.arange(1, N + 1, dtype=np.float64)
    ln_k = np.log(k_arr)
    ln_N = math.log(N)

    # Three witnesses
    witnesses = {
        "Log Cutoff (Cathedral)": -mu_arr * (1.0 - ln_k / ln_N),
        "Flat Möbius (no taper)": -mu_arr.copy(),
        "Sharp Cutoff (k ≤ N/2)": -mu_arr * (k_arr <= N // 2).astype(float),
    }

    results = []
    for name, w in witnesses.items():
        print(f"\nComputing: {name}...")
        t0 = time.time()
        energy = compute_spectrum_with_weights(w, N, t_values)
        elapsed = time.time() - t0
        print(f"  Done in {elapsed:.1f}s")
        r = analyze_spectrum(name, energy, t_values)
        results.append(r)

    # ============================================================
    # Comparison table
    # ============================================================
    print("\n" + "=" * 70)
    print("COMPARISON TABLE")
    print("=" * 70)

    hdr = f"{'Metric':<28}"
    for r in results:
        hdr += f"  {r['name'][:18]:>18}"
    print(hdr)
    print("-" * len(hdr))

    rows = [
        ("Background mean", "bg_mean", ".4f"),
        ("Background σ", "bg_std", ".4f"),
        ("Avg peak energy", "avg_peak", ".2f"),
        ("Avg SNR (peak/bg)", "avg_snr", ".1f"),
        ("Avg significance (σ)", "avg_sigma", ".1f"),
        ("Avg FWHM", "avg_fwhm", ".4f"),
        ("Dynamic range (max/min)", "dynamic_range", ".2f"),
    ]

    for label, key, fmt in rows:
        line = f"{label:<28}"
        for r in results:
            val = r[key]
            line += f"  {val:>18{fmt}}"
        print(line)

    # ============================================================
    # Per-zero comparison
    # ============================================================
    print(f"\n{'=' * 70}")
    print("PER-ZERO PEAK ENERGY COMPARISON")
    print("=" * 70)

    print(f"\n{'Zero':>8}", end="")
    for r in results:
        print(f"  {r['name'][:16]:>16}", end="")
    print(f"  {'Log/Flat':>10}")
    print("-" * 80)

    for i, z in enumerate(RIEMANN_ZEROS):
        if z > t_max:
            break
        print(f"  {z:7.3f}", end="")
        vals = []
        for r in results:
            if i < len(r['peak_energies']):
                v = r['peak_energies'][i]
                print(f"  {v:16.2f}", end="")
                vals.append(v)
            else:
                print(f"  {'---':>16}", end="")
                vals.append(0)
        # Ratio of log taper to flat
        if len(vals) >= 2 and vals[1] > 0:
            ratio = vals[0] / vals[1]
            print(f"  {ratio:10.3f}×", end="")
        print()

    print(f"\n{'=' * 70}")
    print("CONCLUSION")
    print("=" * 70)

    log_r = results[0]
    flat_r = results[1]
    print(f"\nLog taper SNR:  {log_r['avg_snr']:.1f}×")
    print(f"Flat SNR:       {flat_r['avg_snr']:.1f}×")
    if flat_r['avg_snr'] > 0:
        improvement = log_r['avg_snr'] / flat_r['avg_snr']
        print(f"SNR improvement from taper: {improvement:.2f}×")
    if flat_r['avg_fwhm'] > 0:
        fwhm_ratio = log_r['avg_fwhm'] / flat_r['avg_fwhm']
        print(f"FWHM ratio (log/flat): {fwhm_ratio:.2f}× (< 1.0 = sharper peaks)")
    print(f"\nDynamic range (log):  {log_r['dynamic_range']:.2f}")
    print(f"Dynamic range (flat): {flat_r['dynamic_range']:.2f}")


if __name__ == "__main__":
    main()
