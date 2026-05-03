#!/bin/bash
# Run octonion-probe at representative N values
# Now captures structured output to results/ via Rust code
# Terminal output is also captured to a log file

cd "$(dirname "$0")"

LOG="results/sweep_$(date +%Y%m%d_%H%M%S).log"
mkdir -p results

echo "═══ OCTONION PROBE — SWEEP ═══" | tee "$LOG"
echo "Log: $LOG" | tee -a "$LOG"
echo "" | tee -a "$LOG"

for n in 100 500 1000 2000 5000; do
    echo "━━━━━ N=$n ━━━━━" | tee -a "$LOG"
    cargo run --release --bin octonion-probe -- $n 50000 2>&1 | tee -a "$LOG"
    echo "" | tee -a "$LOG"
done

echo "═══ SWEEP COMPLETE ═══" | tee -a "$LOG"
echo "Results in: results/" | tee -a "$LOG"
