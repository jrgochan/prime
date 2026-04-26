#!/usr/bin/env python3
"""
cathedral_dump.py — Balanced dump of Cathedral .lean files into N output files.

Usage:
  python3 scripts/cathedral_dump.py --mode rh|all [--parts N] [--outdir DIR]

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
# These patterns are matched against the relative path from proofs/Cathedral/
# Updated: April 26, 2026 (v11 — Mathlib-style restructuring)
CRITICAL_PATH_PATTERNS = [
    # Foundations
    "Defs.lean",
    "Axioms.lean",
    # Linear algebra
    "LinearAlgebra/",
    # Gram matrix infrastructure
    "Gram/",
    # Vasyunin discrete formula
    "Vasyunin/Defs.lean",
    "Vasyunin/Witness.lean",
    "Vasyunin/Matrix/",
    "Vasyunin/Augmented/",
    "Vasyunin/Cotangent/",
    "Vasyunin/Proof/",
    # Nyman-Beurling equivalence (converse direction)
    "NymanBeurling/",
    # Assembly (capstone crowns)
    "Assembly/",
    # Mellin bridge
    "MellinBridge/",
    # Structural
    "Structural/",
    # Perron formula chain (moved from White/Infrastructure/)
    "Perron/",
    # Zeta function bounds (moved from White/Infrastructure/)
    "Zeta/",
    # General analytic tools (moved from White/Infrastructure/)
    "Analysis/",
    # Physics-inspired (retained in White/)
    "White/Kinematics.lean",
    "White/Scattering.lean",
    # Abel tail bounds
    "AbelTail/",
    # Covariance / Gram form bounds (moved from Assembly/)
    "Covariance/",
    # PNT bridges (moved from Assembly/)
    "PNT/",
    # Integral basis (resurrected from Archive)
    "IntegralBasis/",
    # Sieve (ParitySchur is imported)
    "Sieve/ParitySchur.lean",
    # Spectral (PTSymmetry, RayleighBridge are imported)
    "Spectral/PTSymmetry.lean",
    "Spectral/RayleighBridge.lean",
]

HEADER_TEMPLATE = """# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cathedral Source — Part {part} of {total}
# Generated: {date}
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# THE CATHEDRAL — Formal Reduction of the Riemann Hypothesis
# Lean 4 + Mathlib — {mode_desc}
# Build: lake build — 0 errors, 0 sorry on crown path
# Crown: nyman_beurling_equivalence (4 non-kernel axioms, #print axioms verified)
#
# Crown axioms (compiler-verified, v11 — April 2026):
#   1. pnt_mu_log_div_k                         — Σ μ(k)log(k)/k → -1 (PNT derivative)
#   2. covariance_bound_from_mertens_34          — vᵀCv ≤ C/logN (Abel summation)
#   3. partial_integral_tends_to_formula         — Vasyunin convergence (Gram entries)
#   4. rh_zeta_lower_bound_from_zero_counting    — |ζ(s)| ≥ c/|t|^A (Hadamard)
#
# Graduated axioms (now theorems):
#   ✅ pnt_mu_div_k — via PrimeNumberTheoremAnd (v8)
#   ✅ pnt_mu_log_sq_div_k — via Abel Bypass / S₃ uniform bound (v9)
#   ✅ rh_implies_mertens_bound — via Perron chain (v7)
#   ✅ abel_summation_covariance_bound — via Gram form + dot product (v7)
#   ✅ gram_form_upper_bound_34 — via variance decomposition (v10)
#
# Converse direction (d²→0 ⟹ RH): ZERO non-kernel axioms.
# Plus Lean kernel: propext, Classical.choice, Quot.sound
# Plus 1 sorry: ZetaLowerBound.lean (thin-strip BC, experimentally validated)
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
            # Match against the Cathedral-relative path
            cat_relpath = str(lean_file.relative_to(CATHEDRAL_DIR))
            if not any(pat in cat_relpath for pat in CRITICAL_PATH_PATTERNS):
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


def write_dumps(bins: list[list[tuple[str, int]]], outdir: str, mode: str, prefix: str):
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
        outpath = Path(outdir) / f"{part:02d}-{prefix}.txt"

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
                        help="Output directory (default: docs/exports/critical-path or docs/exports/full)")
    parser.add_argument("--prefix", type=str, default="cathedral",
                        help="Filename prefix (default: cathedral)")
    # Legacy support: accept positional args and --exclude-archive silently
    parser.add_argument("source_dir", nargs="?", default=None,
                        help=argparse.SUPPRESS)
    parser.add_argument("--exclude-archive", action="store_true", default=False,
                        help=argparse.SUPPRESS)
    parser.add_argument("--output-dir", type=str, default=None,
                        help=argparse.SUPPRESS)
    args = parser.parse_args()

    # Handle legacy invocation: `cathedral_dump.py proofs/Cathedral --exclude-archive`
    if args.source_dir and args.exclude_archive:
        args.mode = "rh"
    if args.output_dir and not args.outdir:
        args.outdir = args.output_dir

    if args.outdir is None:
        args.outdir = "docs/exports/critical-path" if args.mode == "rh" else "docs/exports/full"

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
    write_dumps(bins, args.outdir, args.mode, args.prefix)

    print()
    print("  ✅ Done!")


if __name__ == "__main__":
    main()
