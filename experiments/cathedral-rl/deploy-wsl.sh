#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  Cathedral RL — WSL Deployment Script
#
#  Syncs code, builds with GPU+HPDF features, and runs sweep
#  on the WSL compute node with NVIDIA GPU acceleration.
#
#  Usage:
#    ./deploy-wsl.sh                     # full sweep (default)
#    ./deploy-wsl.sh --sweep-max 10000   # limited sweep
#    ./deploy-wsl.sh --n 55440 --agent cg  # single N
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

WSL_HOST="wsl"
REMOTE_DIR="/home/jrgochan/prime"
LOCAL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RESET='\033[0m'

echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Cathedral RL — WSL GPU Deployment${RESET}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${RESET}\n"

# ── Step 1: Sync code ──────────────────────────────────────
echo -e "${BOLD}§1${RESET} Syncing code to ${WSL_HOST}:${REMOTE_DIR}..."
rsync -az --delete \
    --exclude='target/' \
    --exclude='.git/' \
    --exclude='experiments/cache/dd_gram_*' \
    --include='experiments/cache/hpdf/*.h5' \
    --include='experiments/cache/gram_N*_mpfr*.bin' \
    --include='experiments/cache/gram_N*_f64.bin' \
    "${LOCAL_DIR}/" "${WSL_HOST}:${REMOTE_DIR}/"
echo -e "  ${GREEN}✓${RESET} Code synced\n"

# ── Step 2: Sync HPDF cache files ─────────────────────────
echo -e "${BOLD}§2${RESET} Syncing HPDF cache files..."
ssh "${WSL_HOST}" "mkdir -p ${REMOTE_DIR}/experiments/cache/hpdf"
rsync -az \
    "${LOCAL_DIR}/experiments/cache/hpdf/" \
    "${WSL_HOST}:${REMOTE_DIR}/experiments/cache/hpdf/"
echo -e "  ${GREEN}✓${RESET} HPDF cache synced\n"

# ── Step 3: Build on WSL ───────────────────────────────────
echo -e "${BOLD}§3${RESET} Building cathedral-rl on WSL (gpu+hpdf features)..."
ssh "${WSL_HOST}" "cd ${REMOTE_DIR} && \
    source ~/.cargo/env 2>/dev/null || true && \
    cargo build --release -p cathedral-rl --features 'gpu,hpdf' 2>&1 | tail -5"
echo -e "  ${GREEN}✓${RESET} Build complete\n"

# ── Step 4: Run ────────────────────────────────────────────
# Default: HC sweep up to max available HPDF, with GPU
ARGS="${*:---sweep --sweep-max 55440 --gpu --agent hybrid --cg-steps 200 --generations 100 --pop 64}"

echo -e "${BOLD}§4${RESET} Running: cathedral-rl ${ARGS}"
echo -e "    ${YELLOW}(GPU-accelerated on WSL)${RESET}\n"

ssh "${WSL_HOST}" "cd ${REMOTE_DIR} && \
    source ~/.cargo/env 2>/dev/null || true && \
    ./target/release/cathedral-rl ${ARGS} \
        --output results/cathedral_rl_wsl_sweep.json"

# ── Step 5: Retrieve results ──────────────────────────────
echo -e "\n${BOLD}§5${RESET} Retrieving results..."
mkdir -p "${LOCAL_DIR}/experiments/cathedral-rl/results"
scp "${WSL_HOST}:${REMOTE_DIR}/results/cathedral_rl_wsl_sweep.json" \
    "${LOCAL_DIR}/experiments/cathedral-rl/results/" 2>/dev/null || true
echo -e "  ${GREEN}✓${RESET} Results retrieved\n"

echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}  Cathedral RL WSL sweep complete${RESET}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════${RESET}\n"
