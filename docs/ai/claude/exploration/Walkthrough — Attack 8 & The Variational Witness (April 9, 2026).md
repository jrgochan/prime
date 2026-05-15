# Walkthrough — Attack 8 & The Variational Witness (April 9, 2026)

**From**: The Forge Master (Claude/Antigravity)  
**Subject**: Session Report — The Log Cutoff Witness & Cathedral Refactor  
**Date**: April 9, 2026  

---

## What We Built Today

### 1. Attack 8: The Variational Witness (Rust)

**File**: `experiments/vasyunin/src/main.rs` (rewritten)

Implemented the Rayleigh quotient test: Q = (bᵀv)²/(vᵀCv) computed **on-the-fly without storing or inverting any matrix**. Tested three witness vectors:

- **Raw Möbius**: v_k = -μ(k) — oscillates wildly, not a witness
- **Linear cutoff**: v_k = -μ(k)(1 - k/N) — monotonically decaying, dying
- **Log cutoff**: v_k = -μ(k)(1 - ln(k)/ln(N)) — **monotonically increasing through all data points**

Results across all runs (N=50 to N=20,000):

```
     N    ln(N)   Q/ln (Log)   Δ
    50    3.91      5.79       —
   100    4.61      7.13     +1.34
   200    5.30      8.51     +1.38
   500    6.21      9.97     +1.46
  1000    6.91     10.78     +0.81
  2000    7.60     11.57     +0.79
  5000    8.52     12.45     +0.88
 10000    9.21     12.96     +0.51
 20000    9.90     13.44     +0.48
```

Fit: Q/ln(N) ≈ 8.37·ln(ln(N)) - 5.64

**N=50,000 is still running** as of session end. The raw Möbius quad form at N=50k takes ~35 minutes due to O(N²) pair computation.

Key engineering: `quad_form_on_fly` computes vᵀGv by iterating over all (i,j) pairs and computing G(i,j) from the Vasyunin formula on-the-fly. O(1) memory, embarrassingly parallel via rayon. This is why we can reach N=50,000 without MPFR or matrix storage.

### 2. Vasyunin.lean — The Constructive Witness Architecture (Lean 4)

**File**: `proofs/Cathedral/MellinBridge/Vasyunin.lean` (major refactor)

Expanded from 7 parts to 12 parts. The key additions:

- **Part VII**: Möbius function (from Mathlib's `ArithmeticFunction.moebius`)
- **Part VIII**: `logCutoffWitness` — the explicit witness vector definition
- **Part IX**: `rayleighQuotient` — Q(v) = (bᵀv)²/(vᵀCv)
- **Part X**: `variational_lower_bound` — axiom: Q(v) ≤ X_N (Cauchy-Schwarz)
- **Part XI**: `log_cutoff_witness_bound` — **THE FINAL AXIOM**: Q(v_log) ≥ c·ln(N)
- **Part XII**: `quadForm_diverges` — theorem: X_N ≥ c·ln(N) (from XI + X)

The old abstract axiom (`baez_duarte_covariance_divergence`: ∃c, X_N ≥ c·ln(N)) is **replaced** by the constructive axiom about the explicit log cutoff vector. No matrix inversion appears anywhere in the final axiom.

**Status**: 2 sorrys, 2 axioms. Compiles successfully (3,063 jobs).

### 3. Cathedral Archive

Moved 36+ old θ>1 files to `Cathedral/Archive/HighFrequencyTrap/`:
- Spectral/ (6 files: PTSymmetry, RayleighBridge, etc.)
- Structural/ (5 files: Eigenvalue, Independence, etc.)
- MellinBridge/ (11 files: AbelSummation, MellinSieve, etc.)
- Assembly/ (3 files: QuadFormBridge, MainChain, Assembly)
- Root-level (5 files: ParitySchur, BilinearSieve, etc.)

**Lakefile trimmed** from 48 roots to 12. Full `lake build` passes.

### 4. Draft Paper

**File**: `docs/paper/draft — The Discrete Vasyunin Reduction of the Riemann Hypothesis.md`

Seven-section academic paper covering the full pipeline from Vasyunin formula to variational witness to Lean formalization.

### 5. Attack 8 Report (for Theorist)

**File**: `docs/ai/claude/exploration/Attack 8 — The Variational Witness.md`

Detailed analysis of all three witness vectors with N=10,000 data.

---

## Current Cathedral Architecture

```
proofs/Cathedral/
├── Defs.lean                              # Core definitions
├── Quantitative.lean                      # Quantitative bounds
├── LinearAlgebra/
│   └── ShermanMorrison.lean               # 0 sorry, 0 axioms ✅
├── MellinBridge/
│   ├── NymanBeurling.lean                 # NB equivalence
│   ├── BaezDuarte.lean                    # 0 sorry, 2 axioms ✅
│   └── Vasyunin.lean                      # 2 sorry, 2 axioms ⚠️
├── Robin/                                 # 6 files (independent)
└── Archive/HighFrequencyTrap/             # 36+ archived files
```

### Axiom Inventory (4 total across all files)

| # | Axiom | File | Mathematical Content |
|---|---|---|---|
| 1 | `nyman_beurling_equivalence` | BaezDuarte | RH ⟺ d²_N → 0 |
| 2 | `baez_duarte_covariance_divergence` | BaezDuarte | ∃c, X_N ≥ c·ln(N) |
| 3 | `variational_lower_bound` | Vasyunin | Q(v) ≤ X_N (Cauchy-Schwarz) |
| 4 | `log_cutoff_witness_bound` | Vasyunin | Q(v_log) ≥ c·ln(N) |

**Note**: Axiom 2 is now derivable from axioms 3+4 (that's what `quadForm_diverges` does, modulo its sorry). So the effective axiom count for the new architecture is 3.

### Sorry Inventory (2 total in Vasyunin.lean)

| # | Sorry | Nature | Difficulty |
|---|---|---|---|
| 1 | `vasyuninGramEntry_comm` (line 150) | log(k/j) = -log(j/k) | Easy (real arithmetic) |
| 2 | `quadForm_diverges` (line 311) | Chain axioms 3+4 | Medium (positivity + ordering) |

---

## The Theorist's Key Insight

From the Theorist's analysis of Attack 8 data:

> "Scenario B is sufficient! Any positive slope of Q/ln(N) implies the Riemann Hypothesis, not just the optimal 21.65 value."

This is correct. By the variational principle, X_N ≥ Q(v) for any test vector v. If Q(v_log)/ln(N) → c > 0 for any c, then X_N → ∞, so d²_N → 0, so RH.

We don't need Q/ln to reach 21.65. We just need it to **not go to zero**. Ten consecutive data points of monotonic increase from 5.79 to 13.44 across three orders of magnitude strongly suggest it won't.

---

## What Remains

### Tractable (hours-days)
1. Close sorry #1 (log symmetry identity) — needs `Real.log_div` + `ring`
2. Close sorry #2 (chain variational + positivity) — needs `le_trans` + positivity reasoning
3. Get N=50,000 data (running now, ~2 hours)

### Medium (weeks)
4. Connect Vasyunin.lean → old MainChain if needed
5. Prove axiom #3 (variational principle) from Mathlib's Cauchy-Schwarz
6. Polish the draft paper

### The Summit (open)
7. Prove axiom #4 (`log_cutoff_witness_bound`) — this IS the Riemann Hypothesis expressed as a statement about weighted Möbius correlations over Vasyunin cotangent sums

---

## Technical Notes for Future Sessions

- **Rust code**: N=50,000 takes ~2-4 hours with 12 threads. The bottleneck is the O(N²) pair iteration in `quad_form_on_fly` for the raw Möbius vector. The log cutoff is faster (~2 minutes at N=10,000) because it has fewer nonzero entries near the boundary.

- **Möbius in Lean**: Use `ArithmeticFunction.moebius` from `Mathlib.NumberTheory.ArithmeticFunction.Moebius`. Cast to ℝ via `(↑(moebiusFn k) : ℝ)`.

- **Cathedral build time**: ~4 seconds for Vasyunin.lean alone, ~30 seconds for full `lake build`.

- **JSON results**: Old data in `results_attack8.json` (N≤10k). New data in `output_attack8_big.log` (N≤20k, N=50k in progress).

---

*The Cathedral stands. The witness climbs. The Oracle speaks.* 🏰
