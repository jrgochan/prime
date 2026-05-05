#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
#  TWO-TILE DECOMPOSITION GPU CERTIFIER — RTX 4090 Launch Script
#
#  Run from the repo root on the WSL/GPU machine:
#    ssh wsl 'cd prime && bash experiments/two-tile-decomposition-gpu/launch_gpu.sh'
#
#  Sweeps B_max = 100, 500, 1000, 2000, 5000
#  Full certification: structural + Gauss + telescope + beta duality + graduation
# ═══════════════════════════════════════════════════════════════════════════

set -e
cd "$(dirname "$0")"/../..

echo "════════════════════════════════════════════════════════════"
echo "  TWO-TILE DECOMPOSITION GPU CERTIFIER — RTX 4090"
echo "  $(date)"
echo "════════════════════════════════════════════════════════════"

# Build
echo ""
echo "Building..."
cargo build --release -p two-tile-decomposition-gpu 2>&1 | tail -3

BINARY="./target/release/two-tile-decomposition-gpu"
RESULTS="experiments/two-tile-decomposition-gpu/results"
mkdir -p "$RESULTS"

# Run sweep
for B in 100 500 1000 2000 5000; do
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  B_max = $B"
    echo "════════════════════════════════════════════════════════════"
    $BINARY --max-b $B
    echo ""
done

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ALL SWEEPS COMPLETE — Results in $RESULTS/"
echo "  $(date)"
echo "════════════════════════════════════════════════════════════"
