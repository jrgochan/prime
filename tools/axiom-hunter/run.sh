#!/bin/bash
# run.sh — Launch the Axiom Hunter for overnight execution
#
# Usage:
#   ./prover/run.sh              # Full 8-hour hunt
#   ./prover/run.sh --quick      # 10-minute quick test
#   ./prover/run.sh --axiom NAME # Target specific axiom

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROVER_DIR="$SCRIPT_DIR"

echo "🏹 Cathedral Axiom Hunter"
echo "   Project: $PROJECT_DIR"
echo "   Time: $(date)"
echo ""

# Ensure we're in the right directory
cd "$PROJECT_DIR"

# Check lake is available
if ! command -v lake &> /dev/null; then
    echo "❌ 'lake' not found. Ensure elan/lake is on PATH."
    echo "   Try: export PATH=\$HOME/.elan/bin:\$PATH"
    exit 1
fi

# Ensure .olean cache is fresh
echo "🔨 Verifying build cache..."
cd proofs
if [ ! -d ".lake/build" ]; then
    echo "   No build cache found. Running lake build first..."
    lake build
fi
cd "$PROJECT_DIR"

# Create results directory
mkdir -p "$PROVER_DIR/results"

# Run the hunter
echo ""
echo "🚀 Launching Axiom Hunter..."
echo "   Logs: $PROVER_DIR/results/"
echo ""

# Use nohup for overnight runs (unless --quick is passed)
if [[ "$*" == *"--quick"* ]]; then
    python3 "$PROVER_DIR/axiom_hunter.py" "$@"
else
    # Run with nohup so it survives terminal close
    nohup python3 "$PROVER_DIR/axiom_hunter.py" "$@" \
        > "$PROVER_DIR/results/hunter_$(date +%Y%m%d_%H%M%S).log" 2>&1 &
    
    HUNTER_PID=$!
    echo "   PID: $HUNTER_PID"
    echo "   Log: $PROVER_DIR/results/hunter_$(date +%Y%m%d_%H%M%S).log"
    echo ""
    echo "   The hunt is running in the background."
    echo "   Check progress: tail -f $PROVER_DIR/results/hunter_*.log"
    echo "   Stop:           kill $HUNTER_PID"
    echo ""
    echo "   Sleep well. The forge works through the night. 🏛️"
fi
