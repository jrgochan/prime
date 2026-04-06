# gram_entry_offdiag_upper: IBP Chain Proof Plan
## Date: 2026-04-06

## Current Status
- RH depends on 3 mathematical axioms: gram_entry_offdiag_upper, gcd_sq_sum_le, zeta_zero_separates
- gcd_sq_sum_le: stamped as axiom (requires Möbius machinery, 12× margin, verified N≤100k)
- gram_entry_offdiag_upper: TARGET for elimination via IBP chain

## Architecture

```
gram_entry_offdiag_upper (AXIOM in GramEntry.lean)
  └── gram_entry_offdiag_upper' (OffDiagBound.lean, PROVED modulo cov_le_gcd_div)
        ├── gramEntry_le_quarter_plus_cov  ✅ PROVED (GramOffDiag.lean)
        └── cov_le_gcd_div                 ❌ sorry
              ├── cov_eq_weighted_cross     ✅ PROVED (CovDecomp.lean)
              └── running_avg_bound         ❌ sorry
                    └── running_avg_coprime_bound  ❌ sorry (RunningAvg.lean)
                          ├── running_at_breakpoint      ❌ sorry
                          ├── inter_breakpoint_bound      ❌ sorry (measurability)
                          ├── partial_correction_le_full  ❌ sorry
                          └── partial_correction_nonneg   ✅ PROVED
```

## Sorry Inventory (7 total)

### RunningAvg.lean (5 sorrys)
1. `inter_breakpoint_bound` (L74) — EASY: measurability fix, calc chain done
2. `running_at_breakpoint` (L93) — MEDIUM: connect integral → piece sum via cross_telescope
3. `partial_correction_le_full` (L130) — MEDIUM: partial ≤ full sum (terms ≥ 0)
4. `running_avg_coprime_bound` (L150) — HARD: main theorem, assembles 1-3
5. `running_avg_coprime_bound_symm` (L159) — EASY: symmetry swap once #4 done

### OffDiagBound.lean (2 sorrys)
6. `running_avg_bound` (L143) — MEDIUM: reduce to coprime pair via gcd factoring
7. `cov_le_gcd_div` (L162) — HARD: IBP + weight telescoping + running average

## Key Mathematical Facts (PROVED in Mertens/)
- weight_piece: ∫₀¹ 1/(n+1+t)² dt = 1/(n+1) - 1/(n+2)           ✅
- weight_total_one: Σ weights = 1 (telescoping)                     ✅
- cross_pointwise_bound: |({αu}-½)({βu}-½)| ≤ 1/4                 ✅
- partial_correction_nonneg: correction terms ≥ 0                   ✅
- cross_telescope: piece integrals sum correctly                    ✅ (CoprimeCross)
- correction_sum: full correction = (α²-1)/(12αβ)                  ✅ (CoprimeCross)

## OPEN QUESTION: Bound Mismatch
OffDiagBound.lean currently targets: cov ≤ gcd/(jk)
The corrected axiom uses: gramEntry ≤ 1/4 + gcd²/(12jk) + 1/(4·max)
These are DIFFERENT. Need to verify relationship before proceeding.

Specifically: does gcd/(jk) ≤ gcd²/(12jk) + 1/(4·max(j,k)) always hold?
Or should we re-target the IBP chain to prove cov ≤ gcd²/(12jk) + 1/(4·max) directly?

## Proposed Attack Order
Phase A (quick wins): #1 inter_breakpoint_bound, #3 partial_correction_le_full
Phase B (structural): #2 running_at_breakpoint, #4 running_avg_coprime_bound
Phase C (bridge):     #5 symmetry, #6 running_avg_bound, #7 cov_le_gcd_div
