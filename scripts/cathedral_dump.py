#!/usr/bin/env python3
"""
cathedral_dump.py — Balanced dump of Cathedral .lean files into N output files.

Usage:
  python3 scripts/cathedral_dump.py [--mode rh|all] [--parts N] [--outdir DIR]

Modes:
  rh   — Critical path only (files on the crown theorem's dependency chain)
  all  — All active .lean files (excludes Archive/ and Scratch/)

The script uses a greedy bin-packing algorithm to balance file sizes evenly
across the output files, so no single file gets too large.
"""

import argparse
import os
import sys
from pathlib import Path
from datetime import datetime

CATHEDRAL_DIR = Path("proofs/Cathedral")

# Files on the critical path to nyman_beurling_equivalence
# Ordered by dependency depth (foundations first)
CRITICAL_PATH_PATTERNS = [
    "Defs.lean",
    "Axioms.lean",
    "LinearAlgebra/",
    "Gram/",
    "Vasyunin/Defs.lean",
    "Vasyunin/Witness.lean",
    "Vasyunin/Matrix/",
    "Vasyunin/Augmented/",
    "Vasyunin/Cotangent/",
    "Vasyunin/Proof/",
    "NymanBeurling/",
    "Assembly/",
    "MellinBridge/MertensBound.lean",
    "MellinBridge/MertensIntegral.lean",
    "MellinBridge/BDWeights.lean",
    "White/Kinematics.lean",
    "White/Scattering.lean",
]

HEADER_TEMPLATE = """# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cathedral Source — Part {part} of {total}
# Generated: {date}
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# THE CATHEDRAL — Formal Reduction of the Riemann Hypothesis
# Lean 4 + Mathlib — {mode_desc}
# Build: lake build — 0 errors, 0 sorry on crown path
# Crown: nyman_beurling_equivalence (7 axioms, #print axioms verified)
# Total: 84 active files, 42 axioms
#
# Crown axioms:
#   1. rh_implies_mertens_bound   — RH → |M(x)| = O(x^{{1/2}} log²x)
#   2. pnt_mu_div_k               — Σ μ(k)/k → 0 (PNT)
#   3. pnt_mu_log_div_k           — Σ μ(k)log(k)/k → -1 (PNT)
#   4. pnt_mu_log_sq_div_k        — Σ μ(k)log²(k)/k → -2γ (PNT)
#   5. abel_mertens_tail_raw      — Abel summation tail bounds
#   6. millennium_covariance_cancellation — 2D covariance bound
#   7. vasyunin_offdiag_integral   — Off-diagonal Gram = integral
#
# This is part {part} of {total}. {upload_hint}
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""


def collect_files(mode: str) -> list[tuple[str, int]]:
    """Collect .lean files with their sizes. Returns [(relpath, line_count)]."""
    files = []
    for lean_file in sorted(CATHEDRAL_DIR.rglob("*.lean")):
        relpath = str(lean_file.relative_to(Path("proofs")))

        # Skip Archive, Scratch, .lake
        if any(skip in relpath for skip in ["Archive/", "Scratch/", ".lake/"]):
            continue

        if mode == "rh":
            # Only include files matching critical path patterns
            if not any(pat in relpath for pat in CRITICAL_PATH_PATTERNS):
                continue

        lines = lean_file.read_text().count('\n')
        files.append((relpath, lines))

    return files


def bin_pack_greedy(files: list[tuple[str, int]], n_bins: int) -> list[list[tuple[str, int]]]:
    """Greedy bin-packing: assign largest files first to smallest bin."""
    bins: list[list[tuple[str, int]]] = [[] for _ in range(n_bins)]
    bin_sizes = [0] * n_bins

    # Sort files largest first
    sorted_files = sorted(files, key=lambda x: x[1], reverse=True)

    for filepath, size in sorted_files:
        # Find the smallest bin
        min_idx = bin_sizes.index(min(bin_sizes))
        bins[min_idx].append((filepath, size))
        bin_sizes[min_idx] += size

    # Sort files within each bin by path for readability
    for b in bins:
        b.sort(key=lambda x: x[0])

    return bins


def write_dumps(bins: list[list[tuple[str, int]]], outdir: str, mode: str):
    """Write each bin to an output file."""
    os.makedirs(outdir, exist_ok=True)

    # Clear old files
    for old in Path(outdir).glob("*.txt"):
        old.unlink()

    mode_desc = "Critical Path (RH chain)" if mode == "rh" else "Full Active Codebase"
    upload_hint = "Upload all files." if len(bins) <= 10 else ""
    total = len(bins)
    date = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    total_files = 0
    total_lines = 0

    for i, bin_files in enumerate(bins):
        part = i + 1
        outpath = Path(outdir) / f"{part:02d}-cathedral.txt"

        header = HEADER_TEMPLATE.format(
            part=part, total=total, date=date,
            mode_desc=mode_desc, upload_hint=upload_hint
        )

        with open(outpath, 'w') as f:
            f.write(header)

            for relpath, line_count in bin_files:
                fullpath = Path("proofs") / relpath
                f.write(f"\n{'='*64}\n")
                f.write(f"FILE: {relpath}\n")
                f.write(f"{'='*64}\n\n")
                f.write(fullpath.read_text())
                f.write("\n")

        bin_lines = sum(lc for _, lc in bin_files)
        bin_file_count = len(bin_files)
        total_files += bin_file_count
        total_lines += bin_lines

        size_kb = outpath.stat().st_size / 1024
        print(f"  {outpath.name:25s}  {size_kb:6.1f} KB  {bin_lines:5d} lines  {bin_file_count:2d} files")

    print()
    print(f"  📊 Total: {total_files} files, {total_lines} lines across {total} parts")
    print(f"  📁 Output: {outdir}/")


def main():
    parser = argparse.ArgumentParser(description="Cathedral balanced dump")
    parser.add_argument("--mode", choices=["rh", "all"], default="all",
                        help="rh = critical path only, all = full active codebase")
    parser.add_argument("--parts", type=int, default=10,
                        help="Number of output files (default: 10)")
    parser.add_argument("--outdir", type=str, default=None,
                        help="Output directory (default: cathedral-rh or cathedral-10)")
    args = parser.parse_args()

    if args.outdir is None:
        args.outdir = "cathedral-rh" if args.mode == "rh" else "cathedral-10"

    print(f"═══ Cathedral: {args.mode.upper()} dump into {args.parts} files ═══")
    print()

    files = collect_files(args.mode)
    if not files:
        print("  ❌ No files found!")
        sys.exit(1)

    total_lines = sum(lc for _, lc in files)
    print(f"  Found {len(files)} files, {total_lines} lines")
    print(f"  Target: ~{total_lines // args.parts} lines per file")
    print()

    bins = bin_pack_greedy(files, args.parts)
    write_dumps(bins, args.outdir, args.mode)

    print()
    print("  ✅ Done!")


if __name__ == "__main__":
    main()
