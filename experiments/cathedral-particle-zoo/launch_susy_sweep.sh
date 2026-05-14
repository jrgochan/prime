#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# SUSY Sector Cancellation Sweep — WSL GPU Launch Script
#
# Runs the enhanced susy-sweep against all cached HPDF Gram matrices
# to test the three Cathedral gaps:
#
#   Gap 1: Does |B+F| have an unconditional upper bound?
#   Gap 2: Does off-diagonal cancellation improve with N?
#   Gap 3: Is B+F = o(D(N))?
#
# Usage:
#   LOCAL (small N ≤ 5040):
#     ./launch_susy_sweep.sh local
#
#   WSL GPU (full sweep N ≤ 55440):
#     ./launch_susy_sweep.sh wsl
#
#   WSL GPU with specific N:
#     ./launch_susy_sweep.sh wsl --n-values 5040,10080,20160,45360,55440
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

MODE="${1:-local}"
shift || true

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="results/susy_sweep_${TIMESTAMP}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  SUSY Cancellation Sweep — Launch Controller               ║"
echo "║  Mode: ${MODE}                                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"

if [ "$MODE" = "local" ]; then
    echo ""
    echo "  Running LOCAL sweep (N ≤ 5040, fits in ~8 GB RAM)..."
    echo ""
    
    mkdir -p "$RESULTS_DIR"
    
    cargo run --release --bin susy-sweep -- \
        --cache-dir experiments/cache/hpdf \
        --max-n 5040 \
        --min-n-fit 60 \
        --output "${RESULTS_DIR}/susy_sectors.tsv" \
        --cert "${RESULTS_DIR}/susy_certificate.json" \
        "$@" \
        2>&1 | tee "${RESULTS_DIR}/sweep.log"
    
    echo ""
    echo "  Results in: ${RESULTS_DIR}/"
    
elif [ "$MODE" = "wsl" ]; then
    echo ""
    echo "  Building release binary for WSL deployment..."
    echo ""
    
    # Build release binary
    cargo build --release --bin susy-sweep
    
    echo ""
    echo "  Deploying to WSL GPU via SSH..."
    echo "  NOTE: Ensure H5 files are accessible on the WSL filesystem."
    echo "  The sweep processes files sequentially; large N files need ~24+ GB RAM."
    echo ""
    echo "  Recommended: run on WSL with 64 GB RAM for N ≤ 55440"
    echo ""
    
    # Create results dir on WSL and run
    ssh wsl "mkdir -p ~/prime/results/susy_sweep_${TIMESTAMP}"
    
    ssh wsl "cd ~/prime && cargo run --release --bin susy-sweep -- \
        --cache-dir experiments/cache/hpdf \
        --max-n 60000 \
        --min-n-fit 60 \
        --output results/susy_sweep_${TIMESTAMP}/susy_sectors.tsv \
        --cert results/susy_sweep_${TIMESTAMP}/susy_certificate.json \
        $*" \
        2>&1 | tee "${RESULTS_DIR:-/dev/null}/wsl_sweep.log" || true
    
    echo ""
    echo "  Pulling results from WSL..."
    mkdir -p "$RESULTS_DIR"
    scp "wsl:~/prime/results/susy_sweep_${TIMESTAMP}/*" "$RESULTS_DIR/" 2>/dev/null || \
        echo "  (Results may need manual retrieval from WSL)"
    
    echo "  Results in: ${RESULTS_DIR}/"
    
else
    echo "  Usage: $0 [local|wsl] [extra args...]"
    echo ""
    echo "  Examples:"
    echo "    $0 local                    # N ≤ 5040 on this machine"
    echo "    $0 wsl                      # Full sweep on WSL GPU"
    echo "    $0 local --max-n 1000       # Quick test"
    exit 1
fi
