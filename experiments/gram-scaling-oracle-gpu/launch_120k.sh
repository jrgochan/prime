#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Cathedral Gram Scaling Oracle — N=120K Block Decomposition Launch Script
#
# Waits for the N=40K run to complete, then launches N=120K --blocks
# Usage: bash launch_120k.sh
# ═══════════════════════════════════════════════════════════════════════════

source ~/.cargo/env

ORACLE="$HOME/code/github.com/jrgochan/prime/target/release/gram-scaling-oracle-gpu"
WORKDIR="$HOME/code/github.com/jrgochan/prime/experiments/gram-scaling-oracle-gpu"

cd "$WORKDIR"

echo "════════════════════════════════════════════════════════════════"
echo "  CATHEDRAL GPU ORACLE — N=120K BLOCK DECOMPOSITION"
echo "  $(date)"
echo "════════════════════════════════════════════════════════════════"

# Check if 40K run is still going
if pgrep -f "gram-scaling-oracle-gpu 40000" > /dev/null 2>&1; then
    echo "⏳ Waiting for N=40K run to finish..."
    while pgrep -f "gram-scaling-oracle-gpu 40000" > /dev/null 2>&1; do
        sleep 30
        echo "  ... still waiting ($(date +%H:%M:%S))"
    done
    echo "✓ N=40K run completed!"
    echo ""
fi

echo "🚀 Launching N=120K block decomposition..."
echo "  $(date)"
echo ""

# Run the oracle: cross-N sweep up to 90K + block analysis at 120K
$ORACLE 120000 --blocks 2>&1 | tee results/run_120000_blocks.log

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  COMPLETE: $(date)"
echo "════════════════════════════════════════════════════════════════"
