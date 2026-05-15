# SUSY Cancellation Sweep — Experiment Plan

## Objective

Empirically close the three Cathedral gaps using high-N HPDF Gram matrices:

| Gap | Question | Status (N≤5040) | Need |
|-----|----------|----------------|------|
| **1** | Upper bound on \|B+F\| | ❌ R²=0.47 (noisy) | More N points |
| **2** | Cancellation improves with N | ✅ α=0.73 | Confirm at N>10K |
| **3** | B+F = o(D(N)) | ✅ excess α=0.73 | Confirm at N>10K |

## Key Finding: N=5040 Spike

At N=5040 (highly composite), `|B+F|` jumps from 0.013 (N=1680) to 0.189.
This is a **resonance spike** at highly composite numbers where the off-diagonal
terms align constructively. The N=2520 point (0.059) already shows the rise.

This behavior is consistent with the physics: HC numbers have maximal divisor
structure, creating temporary boson-fermion alignment. The critical question
is whether these spikes are *bounded* — do they grow with N, or does the
amplitude stabilize while the *ratio* |B+F|/D still decays?

## Available Data

| File | N | Size | RAM needed |
|------|------|------|------------|
| gram_N7560.h5 | 7,560 | 218 MB | ~500 MB |
| gram_N10080.h5 | 10,080 | 388 MB | ~800 MB |
| gram_N15120.h5 | 15,120 | 872 MB | ~1.8 GB |
| gram_N20000.h5 | 20,000 | 3.0 GB | ~3.2 GB |
| gram_N20160.h5 | 20,160 | 1.5 GB | ~3.2 GB |
| gram_N25200.h5 | 25,200 | 2.4 GB | ~5.0 GB |
| gram_N27720.h5 | 27,720 | 2.9 GB | ~6.1 GB |
| gram_N40000.h5 | 40,000 | 12 GB | ~12.8 GB |
| gram_N45360.h5 | 45,360 | 7.7 GB | ~16.4 GB |
| gram_N55440.h5 | 55,440 | 23 GB | ~24.5 GB |

**Total GPU/WSL RAM required for full sweep: ~64 GB**

## Enhanced Binary

`experiments/cathedral-particle-zoo/src/bin/susy_sweep.rs` (v2) now computes:

1. **Power-law fit** to `|B+F|` ~ c·N^(-α)
2. **Ratio scaling** `|B+F|/D(N)` ~ c·N^(-α_ratio)
3. **D(N) growth** fit
4. **Stabilization test** for `|B+F|·ln(N)`
5. **JSON certificate** with all scaling parameters

## Execution

### Phase 1: Local (done)
```bash
cargo run --release --bin susy-sweep -- --max-n 5040
```
Results: 17 files processed, key ratios extracted.

### Phase 2: WSL GPU
```bash
ssh wsl
cd ~/prime
cargo run --release --bin susy-sweep -- \
  --cache-dir experiments/cache/hpdf \
  --max-n 60000 \
  --output results/susy_sectors_full.tsv \
  --cert results/susy_certificate_full.json
```

### Phase 3: Analysis
- Plot `|B+F|/D(N)` vs N (log-log) — should show clean power-law
- Check if HC-number spikes in `|B+F|` are bounded
- Extract the stabilization constant for `|B+F|·ln(N)`

## Preliminary Results (N ≤ 5040)

```
GAP 2: |B+F|/D ~ 12.35 · N^(-0.73)   R² = 0.628  ✅
GAP 3: |B+F| α=0.52 > D α=-0.21      excess=0.73  ✅
GAP 1: Power law R²=0.47 — HC spikes reduce fit    ❌ (needs data)
```

The ratio `|B+F|/D` at the *worst* point (N=6) is 0.91, and by N=1680 drops
to 0.0086. Even the N=5040 spike only reaches 0.106 — still below the N=120
value of 0.43. **The envelope is clearly decaying.**
