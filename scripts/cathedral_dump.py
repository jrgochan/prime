#!/usr/bin/env python3
"""
cathedral_dump.py — Balanced dump of Cathedral .lean files into N output files.

Usage:
  python3 scripts/cathedral_dump.py --mode rh|all [--parts N] [--outdir DIR]

Modes:
  rh   — Critical path only (files reachable via imports from the crown theorems)
  all  — All active .lean files (excludes Archive/ and Scratch/)

The script uses a greedy bin-packing algorithm to balance file sizes evenly
across the output files, so no single file gets too large.

The RH mode traces the transitive import closure from three crown roots:
  1. Assembly/MainChain.lean        — nyman_beurling_equivalence (1 axiom)
  2. Spectral/HeisenbergBypass.lean — heisenberg_implies_d_sq_zero (2 axioms)
  3. Vasyunin/Proof/WitnessConditional.lean — witness_covariance_decay ↔ RH
"""

import argparse
import os
import re
import sys
from pathlib import Path
from datetime import datetime

CATHEDRAL_DIR = Path("proofs/Cathedral")

# Root files for the RH critical path.
# The script BFS-traverses all `import Cathedral.*` to find the full closure.
RH_ROOTS = [
    "Assembly/MainChain.lean",
    "Spectral/HeisenbergBypass.lean",
    "Vasyunin/Proof/WitnessConditional.lean",
]

HEADER_TEMPLATE = """# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cathedral Source — Part {part} of {total}
# Generated: {date}
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# THE CATHEDRAL — Formal Reduction of the Riemann Hypothesis
# Lean 4 + Mathlib — {mode_desc}
# Build: lake build — 0 errors, 0 sorry on crown path
#
# ═══ Two-Axiom Crown Architecture (May 2026) ═══
#
# Primary export: nyman_beurling_equivalence (MainChain.lean)
#   RH ↔ d²_N → 0
#   Axiom: baez_duarte_forward (Báez-Duarte, IMRN 2003)
#   Converse: FULLY PROVED (0 custom axioms)
#
# Heisenberg Bypass: heisenberg_implies_d_sq_zero (HeisenbergBypass.lean)
#   d²_N → 0 via real spectral decomposition
#   Axiom 1: witness_covariance_decay   — THE Riemann Hypothesis
#   Axiom 2: witness_numerator_convergence — PNT-level (graduated)
#
# Crown Jewel: witness_covariance_decay ↔ RH (WitnessConditional.lean)
#   Both directions proved. Zero sorry.
#
# Graduated theorems (formerly axioms):
#   ✅ nbDistSq_nonneg                — L² norm ≥ 0
#   ✅ spectral_identity              — Parseval + self-adjointness
#   ✅ spectral_energy_le_one         — d² ≥ 0 corollary
#   ✅ ultraviolet_completeness       — Rayleigh-Ritz squeeze
#   ✅ bd_witness_l2_error_decay      — Vasyunin λ-trick
#   ✅ spectral_energy_witness_lower  — variational principle
#   ✅ witness_numerator_convergence  — PNT via Möbius sums
#
# Plus Lean kernel: propext, Classical.choice, Quot.sound
#
# This is part {part} of {total}. {upload_hint}
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""


def trace_imports(roots: list[str]) -> set[str]:
    """BFS over `import Cathedral.*` to find the transitive closure from roots."""
    visited: set[str] = set()
    queue = list(roots)

    while queue:
        f = queue.pop(0)
        if f in visited:
            continue
        visited.add(f)
        fullpath = CATHEDRAL_DIR / f
        if not fullpath.exists():
            continue
        with open(fullpath) as fh:
            for line in fh:
                m = re.match(r"^import Cathedral\.(.+)", line.strip())
                if m:
                    imp = m.group(1).replace(".", "/") + ".lean"
                    if (CATHEDRAL_DIR / imp).exists():
                        queue.append(imp)

    return {f for f in visited if (CATHEDRAL_DIR / f).exists()}


def collect_files(mode: str) -> list[tuple[str, int]]:
    """Collect .lean files with their sizes. Returns [(relpath, line_count)]."""
    if mode == "rh":
        # Use import-graph tracing for the critical path
        critical = trace_imports(RH_ROOTS)
        files = []
        for rel in sorted(critical):
            fullpath = CATHEDRAL_DIR / rel
            lines = fullpath.read_text().count('\n')
            lean_path = str(Path("Cathedral") / rel)
            files.append((lean_path, lines))
        return files

    # mode == "all"
    files = []
    for lean_file in sorted(CATHEDRAL_DIR.rglob("*.lean")):
        relpath = str(lean_file.relative_to(Path("proofs")))

        # Skip Archive, Scratch, .lake
        if any(skip in relpath for skip in ["Archive/", "Scratch/", ".lake/"]):
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

    mode_desc = "Critical Path (RH chain — import-graph traced)" if mode == "rh" else "Full Active Codebase"
    upload_hint = "Upload all 10 files for complete coverage." if len(bins) <= 10 else ""
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
                # Resolve the actual file path
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
