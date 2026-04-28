#!/bin/bash
# ═══════════════════════════════════════════════════════════
# copy-certificates.sh — copies Rust experiment certificates
# into the HyperZeta Viewport public directory for Tier 2
# precomputed visualization modes.
# ═══════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIEWPORT_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(cd "$VIEWPORT_DIR/../.." && pwd)"

DEST="$VIEWPORT_DIR/public/data/certificates"
mkdir -p "$DEST"

echo "╔═══════════════════════════════════════════════╗"
echo "║  HyperZeta Certificate Loader                 ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""
echo "Source: $REPO_ROOT/experiments/*/results/"
echo "Dest:   $DEST/"
echo ""

EXPERIMENTS=(
  "hilbert-spectral"
  "l2-decay-certificate"
  "gram-oracle"
  "mellin-certificate"
  "abel-bridge"
  "mvt-decomposition"
  "vasyunin-convergence"
  "rotor-spectroscopy"
  "crown-cancellation"
  "gram-matrix"
  "gram-bilinear-abel"
  "gram-form-identity"
  "gram-pointwise"
  "gram-quadform"
  "bc-exponent-frontier"
  "pnt-mobius-sums"
  "perron-contour"
)

copied=0
missing=0

for exp in "${EXPERIMENTS[@]}"; do
  SRC="$REPO_ROOT/experiments/$exp/results/certificate.json"
  if [ -f "$SRC" ]; then
    cp "$SRC" "$DEST/$exp.json"
    echo "  ✓ $exp"
    ((copied++))
  else
    echo "  ⚠ $exp — no certificate found"
    ((missing++))
  fi
done

echo ""
echo "Done: $copied copied, $missing missing"
