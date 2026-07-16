#!/usr/bin/env python3
"""
Preprocess HPDF Gram matrix .h5 files into JSON for the HyperZeta Gram viewer.

Outputs two resolutions:
  - lo: every `stride_lo`th point (fast loading, overview)
  - hi: every `stride_hi`th point (detailed view)

Usage:
  python preprocess_gram.py --N 2520
  python preprocess_gram.py --N 2520 --stride-lo 10 --stride-hi 3
  python preprocess_gram.py --all  # preprocess all available files
"""

import argparse
import json
import math
import sys
from pathlib import Path

import h5py
import numpy as np

CACHE_DIR = Path(__file__).resolve().parents[3] / "experiments" / "cache" / "hpdf"
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "public" / "data"


def is_prime(n: int) -> bool:
    if n < 2:
        return False
    if n < 4:
        return True
    if n % 2 == 0 or n % 3 == 0:
        return False
    i = 5
    while i * i <= n:
        if n % i == 0 or n % (i + 2) == 0:
            return False
        i += 6
    return True


def load_gram(N: int):
    """Load the Gram matrix from HPDF cache. Returns (G, b_vec, dim)."""
    path = CACHE_DIR / f"gram_N{N}.h5"
    if not path.exists():
        print(f"  ✗ File not found: {path}")
        return None, None, 0

    with h5py.File(path, "r") as f:
        dim = f["structure/diagonal"].shape[0]
        diag = f["structure/diagonal"][:]
        upper = f["gram/upper_triangle"][:]
        b_vec = f["b_vector"][:]

    return diag, upper, b_vec, dim


def preprocess(N: int, stride_lo: int = 10, stride_hi: int = 3):
    """Preprocess a single Gram matrix into lo/hi JSON files."""
    print(f"Processing N={N}...")
    result = load_gram(N)
    if result is None or result[0] is None:
        return False

    diag, upper, b_vec, dim = result
    print(f"  Dimension: {dim}×{dim}")
    print(f"  Upper triangle entries: {len(upper)}")

    # Compute global stats from diagonal (fast)
    diag_min = float(np.min(diag))
    diag_max = float(np.max(diag))
    diag_mean = float(np.mean(diag))

    # We need to scan upper triangle for global min/max too
    if len(upper) > 0:
        upper_min = float(np.min(upper))
        upper_max = float(np.max(upper))
        global_min = min(diag_min, upper_min)
        global_max = max(diag_max, upper_max)
    else:
        global_min = diag_min
        global_max = diag_max

    metadata = {
        "N": N,
        "dim": dim,
        "globalMin": global_min,
        "globalMax": global_max,
        "diagMin": diag_min,
        "diagMax": diag_max,
        "diagMean": diag_mean,
    }

    # Generate samples at each resolution
    for label, stride in [("lo", stride_lo), ("hi", stride_hi)]:
        points = []
        # Sample indices
        indices = list(range(0, dim, stride))
        if dim - 1 not in indices:
            indices.append(dim - 1)  # always include last

        print(f"  {label}: sampling {len(indices)} indices (stride={stride})")

        # Reconstruct needed entries
        # For the sampled (i, j) pairs, we need to pull from diag + upper
        # Upper triangle is stored as: for i in range(dim): for j in range(i+1, dim): upper[idx++]
        # We build an index map for fast lookup
        # For large dim, this is expensive — so we subsample

        # Approach: iterate over sampled (i, j) pairs
        for si, i in enumerate(indices):
            # Diagonal entry
            j_real = i + 1  # 1-indexed
            k_real = i + 1
            gcd_val = j_real  # gcd(x,x) = x
            points.append({
                "j": j_real,
                "k": k_real,
                "v": float(diag[i]),
                "g": gcd_val,
                "p": 1 if is_prime(j_real) and is_prime(k_real) else 0,
            })

            # Off-diagonal entries (upper triangle only, matrix is symmetric)
            for sj_idx in range(si + 1, len(indices)):
                j_idx = indices[sj_idx]
                # Compute upper triangle index for (i, j_idx)
                # Position = sum_{r=0}^{i-1} (dim - r - 1) + (j_idx - i - 1)
                upper_pos = i * (2 * dim - i - 1) // 2 + (j_idx - i - 1)
                if upper_pos >= len(upper):
                    continue
                val = float(upper[upper_pos])

                j_real = i + 1
                k_real = j_idx + 1
                gcd_val = math.gcd(j_real, k_real)
                p_flag = 0
                if is_prime(j_real) and is_prime(k_real):
                    p_flag = 2  # both prime
                elif is_prime(j_real) or is_prime(k_real):
                    p_flag = 1  # one prime

                points.append({
                    "j": j_real,
                    "k": k_real,
                    "v": val,
                    "g": gcd_val,
                    "p": p_flag,
                })

        print(f"  {label}: {len(points)} points generated")

        # Compute per-resolution stats
        values = [p["v"] for p in points]
        res_data = {
            "metadata": {
                **metadata,
                "resolution": label,
                "stride": stride,
                "numPoints": len(points),
                "sampledMin": float(min(values)) if values else 0,
                "sampledMax": float(max(values)) if values else 0,
            },
            "points": points,
        }

        # Write JSON
        out_path = OUTPUT_DIR / f"gram_N{N}_{label}.json"
        with open(out_path, "w") as f:
            json.dump(res_data, f, separators=(",", ":"))
        size_mb = out_path.stat().st_size / (1024 * 1024)
        print(f"  {label}: wrote {out_path.name} ({size_mb:.1f} MB)")

    return True


def main():
    parser = argparse.ArgumentParser(description="Preprocess HPDF Gram matrices for visualization")
    parser.add_argument("--N", type=int, help="Matrix size to preprocess")
    parser.add_argument("--all", action="store_true", help="Preprocess all available files")
    parser.add_argument("--stride-lo", type=int, default=10, help="Stride for lo-res (default: 10)")
    parser.add_argument("--stride-hi", type=int, default=3, help="Stride for hi-res (default: 3)")
    parser.add_argument("--list", action="store_true", help="List available HPDF files")
    args = parser.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # List available files
    available = sorted([
        int(p.stem.replace("gram_N", ""))
        for p in CACHE_DIR.glob("gram_N*.h5")
    ])

    if args.list or (not args.N and not args.all):
        print(f"Available HPDF files ({len(available)}):")
        for n in available:
            path = CACHE_DIR / f"gram_N{n}.h5"
            size_mb = path.stat().st_size / (1024 * 1024)
            print(f"  N={n:>6d}  ({size_mb:>8.1f} MB)")
        if not args.list:
            print("\nUsage: python preprocess_gram.py --N 2520")
        return

    if args.all:
        for n in available:
            preprocess(n, args.stride_lo, args.stride_hi)
    elif args.N:
        if args.N not in available:
            print(f"N={args.N} not found. Available: {available}")
            sys.exit(1)
        preprocess(args.N, args.stride_lo, args.stride_hi)


if __name__ == "__main__":
    main()
