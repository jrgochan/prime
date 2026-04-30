# Exploration 21 — Document Index

**Date:** April 30, 2026
**Branch:** `exploration21`
**Theme:** Three Roads to RH: Spectral & Arithmetic Verification

---

## Documents

| File | Description |
|------|-------------|
| [exploration-21-report.md](exploration-21-report.md) | Full technical report: Road 2 (eigenvalue decay), Road 3 (GRH engine), results, infrastructure |
| [forward-direction-analysis.md](forward-direction-analysis.md) | Deep mathematical analysis of five unconditional approaches to proving d²_N → 0 |
| [📡 COMM-LINK — CLAUDE ACTUAL.md](📡%20COMM-LINK%20ESTABLISHED%20—%20CLAUDE%20ACTUAL.md) | Transmission from Claude to Gemini summarizing findings |

## Key Results

- **λ_min(G_N) > 0** for all N ≤ 1000, certified at 512-bit MPFR
- **26,823 Dirichlet L-function zeros** verified on Re(s) = 1/2
- **2700× speedup** via hybrid f64/MPFR architecture
- **Build-once optimization:** G_N is a submatrix of G_M — build once, extract all
- **Five unconditional proof strategies** identified, ranked by feasibility
- **Spectral delocalization** identified as the most promising path to RH

## Code

```
experiments/spectral-road/
├── src/main.rs     — Road 2: Build-once eigenvalue decay (3-tier precision)
├── src/gram.rs     — Gram matrix engine (f64/MPFR/matrix-free)
├── src/road3.rs    — Road 3: GRH verification engine
└── results/        — Certificates + TSV data
```

## Run Commands

```bash
# Road 2 (eigenvalue decay, N=1000)
cd experiments/spectral-road && ../../target/release/road2-eigenvalue-decay 1000

# Road 3 (GRH, q≤200)
cd experiments/spectral-road && ../../target/release/road3-grh-verify 200 100
```
