#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
#  Cathedral Particle Zoo — GPU Batch Runner
#
#  Runs full eigendecomposition + prime core test on all available
#  gram_N*.h5 files using GPU acceleration (cuSOLVER dsyevd).
#
#  Usage:
#    # From the repo root on the GPU machine:
#    bash experiments/cathedral-particle-zoo/scripts/gpu_batch_run.sh
#
#    # Or via SSH from Mac:
#    ssh wsl 'cd /path/to/prime && bash experiments/cathedral-particle-zoo/scripts/gpu_batch_run.sh'
#
#  Prerequisites:
#    - CUDA toolkit (nvcc, cuSOLVER)
#    - Rust toolchain
#    - HDF5 development libraries
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CACHE_DIR="$REPO_ROOT/experiments/cache/hpdf"
RESULTS_DIR="$REPO_ROOT/experiments/cathedral-particle-zoo/results"

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  Cathedral Particle Zoo — GPU Batch Runner                         ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Detect GPU
if command -v nvidia-smi &>/dev/null; then
    echo "GPU detected:"
    nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader
    echo ""
else
    echo "WARNING: No GPU detected. Will fall back to CPU (f64)."
    echo ""
fi

# Build with GPU feature
echo "Building cathedral-particle-zoo with GPU support..."
cd "$REPO_ROOT"
cargo build --release -p cathedral-particle-zoo --features gpu 2>&1 | tail -3
echo ""

# Find all H5 files sorted by N
H5_FILES=$(ls "$CACHE_DIR"/gram_N*.h5 2>/dev/null | sort -t'N' -k2 -n)
N_FILES=$(echo "$H5_FILES" | wc -l | tr -d ' ')

if [ -z "$H5_FILES" ]; then
    echo "ERROR: No gram_N*.h5 files found in $CACHE_DIR"
    exit 1
fi

echo "Found $N_FILES H5 files in $CACHE_DIR"
echo ""

# Create results directory
mkdir -p "$RESULTS_DIR"

# Maximum dimension for full eigendecomposition on GPU
# RTX 4090: 24 GB VRAM → max dim ≈ 40,000 (2 × N² × 8 bytes)
# RTX 3090: 24 GB VRAM → same
# A100 80GB: max dim ≈ 100,000
MAX_DIM_GPU=40000
MAX_DIM_F64=15000  # CPU f64 via nalgebra (memory-bound)

SUCCESSES=0
FAILURES=0
SKIPPED=0

for H5 in $H5_FILES; do
    BASENAME=$(basename "$H5")
    N=$(echo "$BASENAME" | sed 's/gram_N\([0-9]*\)\.h5/\1/')
    DIM=$((N - 1))

    echo "═══════════════════════════════════════════════════════════════════════"
    echo "  Processing $BASENAME (N=$N, dim=$DIM)"
    echo "═══════════════════════════════════════════════════════════════════════"

    if [ "$DIM" -gt "$MAX_DIM_GPU" ]; then
        echo "  SKIPPING: dim=$DIM exceeds GPU VRAM limit (max=$MAX_DIM_GPU)"
        echo "  Use --lanczos-k 1000 for partial eigendecomposition"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Determine mode
    if [ "$DIM" -le "$MAX_DIM_F64" ] && ! command -v nvidia-smi &>/dev/null; then
        MODE="--precision 64"
        MODE_NAME="CPU f64"
    else
        MODE="--gpu"
        MODE_NAME="GPU cuSOLVER"
    fi

    echo "  Mode: $MODE_NAME"
    echo "  Started: $(date '+%Y-%m-%d %H:%M:%S')"
    START_TIME=$(date +%s)

    if cargo run --release -p cathedral-particle-zoo --features gpu -- \
        --hpdf "$H5" \
        --eigendecompose \
        $MODE \
        --output "$RESULTS_DIR" \
        2>&1 | tee "$RESULTS_DIR/log_N${N}.txt" | tail -20; then
        END_TIME=$(date +%s)
        ELAPSED=$((END_TIME - START_TIME))
        echo "  ✓ Completed in ${ELAPSED}s"
        SUCCESSES=$((SUCCESSES + 1))
    else
        echo "  ✗ FAILED"
        FAILURES=$((FAILURES + 1))
    fi
    echo ""
done

echo "═══════════════════════════════════════════════════════════════════════"
echo "  BATCH COMPLETE"
echo "  Successes: $SUCCESSES / $N_FILES"
echo "  Failures:  $FAILURES"
echo "  Skipped:   $SKIPPED"
echo "  Results:   $RESULTS_DIR"
echo "═══════════════════════════════════════════════════════════════════════"
