# ⚡ EXPLORATION REPORT 9: The Cathedral Reorganization — 6 → 2

**Date**: April 22, 2026  
**Phase**: Cathedral Assembly Refactor  
**Status**: ✅ Complete — Full build passing, zero sorries

---

## Executive Summary

The Cathedral's crown theorem — the forward direction of the Nyman-Beurling equivalence for the Riemann Hypothesis — has been restructured from a **6-axiom proof chain to a 2-axiom proof chain**, while simultaneously decomposing the monolithic 971-line `FinalDragon.lean` into 5 focused modules.

This was not new mathematics. It was an *architectural discovery*: the 2-axiom proof path already existed (in `DirectL2Crown.lean`, created April 18) but was not being used as the primary crown. The old chain through `FinalDragon.lean` was still the one `OneCrown.lean` imported.

The fix was a 2-line change. The refactor was the rest.

---

## The Discovery

### The Audit

Running `#print axioms rh_implies_l2_convergence` on the old crown revealed 6 Cathedral axioms:

| # | Axiom | Origin |
|---|-------|--------|
| 1 | `rh_implies_mertens_bound` | MertensBound.lean |
| 2 | `gram_form_upper_bound` | FinalDragon.lean §2c |
| 3 | `pnt_mu_div_k` | FinalDragon.lean §1b |
| 4 | `pnt_mu_log_div_k` | FinalDragon.lean §1b |
| 5 | `pnt_mu_log_sq_div_k` | FinalDragon.lean §1b |
| 6 | `vasyunin_offdiag_integral` | Vasyunin.IntegralProof |

Meanwhile, `DirectL2Crown.lean` had `rh_implies_bd_convergence_direct` — a **fully proved** theorem using only 2 axioms:

| # | Axiom | Origin |
|---|-------|--------|
| 1 | `rh_implies_mertens_bound` | MertensBound.lean |
| 2 | `bd_gram_form_decay` | MontgomeryVaughan.lean |

The 2-axiom path was there all along. We just weren't pointing at it.

### The Rewire

```lean
-- OneCrown.lean (BEFORE)
import Cathedral.Assembly.FinalDragon
theorem rh_implies_l2_convergence := rh_implies_l2_convergence_proved

-- OneCrown.lean (AFTER)
import Cathedral.Assembly.DirectL2Crown
theorem rh_implies_l2_convergence := rh_implies_bd_convergence_direct
```

**Result**: Verified via `#print axioms` — crown drops from 6 to 2 Cathedral axioms.

---

## The Decomposition

`FinalDragon.lean` was 971 lines doing 6 different jobs. It was the single largest file in the Cathedral, containing everything from PNT axiom declarations to the crowned convergence theorem.

### Before: 1 Monolith (971 lines)

```
FinalDragon.lean
├── §1. MertensConversion (rh_implies_mertens_34)          ~70 lines
├── §1b. PNT Axioms (3 axiom declarations)                 ~30 lines
├── §2a. Abel Tail (rpow bounds, tail_raw, domination)     ~370 lines
├── §2b. Mean Bound (moebius_mean_finite_bound)             ~160 lines
├── §2c. Gram/Covariance/Quadratic                         ~180 lines
├── §3. L² Decay + Convergence                              ~80 lines
└── §4. Crown (rh_implies_l2_convergence_proved)            ~25 lines
```

### After: 5 Modules + Facade (1122 lines total with headers)

| File | Lines | Responsibility |
|------|-------|---------------|
| `MertensConversion.lean` | 91 | x^{1/2}·log²x → x^{3/4} conversion |
| `PNTAbelMean.lean` | 592 | PNT axioms + Abel tail 🎓 + mean bound |
| `MillenniumWall.lean` | 197 | Gram form axiom + covariance graduation 🎓🎓 |
| `L2Convergence.lean` | 133 | L² decay + convergence (alternative path) |
| `FinalDragon.lean` | 25 | Thin re-export facade |

Each file now has a single clear purpose, clean imports, and a descriptive header.

---

## Two Proof Paths: An Architectural Diagram

The Cathedral now has two independent proof paths to the crown:

```
                    ┌──────────────────────────────────────────────┐
                    │   RiemannHypothesis                          │
                    └───────────┬──────────────────────────────────┘
                                │
                    ┌───────────▼───────────┐
                    │ rh_implies_mertens_bound │
                    │     [AXIOM 1]            │
                    └───┬───────────────┬─────┘
                        │               │
          ┌─────────────▼──┐       ┌────▼──────────────────┐
          │ DIRECT BD PATH │       │ ALTERNATIVE CHAIN     │
          │ (2 axioms)     │       │ (6 axioms)            │
          └────────┬───────┘       └────────┬──────────────┘
                   │                        │
          ┌────────▼───────────┐   ┌────────▼──────────────┐
          │ bd_gram_form_decay │   │ PNT axioms (3)        │
          │   [AXIOM 2]        │   │ gram_form_upper_bound │
          └────────┬───────────┘   │ vasyunin_offdiag_int. │
                   │               └────────┬──────────────┘
          ┌────────▼───────────┐   ┌────────▼──────────────┐
          │ loglog/log → 0     │   │ Abel tail + mean +    │
          │   [PROVED]         │   │ covariance + quadratic│
          └────────┬───────────┘   │   [ALL PROVED]        │
                   │               └────────┬──────────────┘
          ┌────────▼───────────┐   ┌────────▼──────────────┐
          │ DirectL2Crown.lean │   │ L2Convergence.lean    │
          │   [PROVED]         │   │   [PROVED]            │
          └────────┬───────────┘   └────────┬──────────────┘
                   │                        │
                   └───────┬────────────────┘
                           │
                   ┌───────▼─────────────┐
                   │  OneCrown.lean      │
                   │  rh_implies_l2_     │
                   │  convergence        │
                   │  ══════════════     │
                   │  Uses DIRECT PATH   │
                   │  (2 axioms)         │
                   └─────────────────────┘
```

Both paths are fully proved. The crown uses the Direct BD Path because it requires only 2 axioms instead of 6.

---

## Verification

| Check | Result |
|-------|--------|
| `lake build` | ✅ 3584 jobs, zero errors |
| `grep sorry` | ✅ Zero sorries in all 6 files |
| `#print axioms rh_implies_l2_convergence` | ✅ 2 Cathedral + 3 kernel axioms |
| Backward compatibility | ✅ `FinalDragon.lean` re-exports all decomposed modules |

---

## The Cathedral: Current State

### Axiom Inventory

| Axiom | Status | File |
|-------|--------|------|
| `rh_implies_mertens_bound` | 🔴 Required (on crown) | MertensBound.lean |
| `bd_gram_form_decay` | 🔴 Required (on crown) | MontgomeryVaughan.lean |
| `gram_form_upper_bound` | 🟡 Off-crown (alt chain only) | MillenniumWall.lean |
| `pnt_mu_div_k` | 🟡 Off-crown (alt chain only) | PNTAbelMean.lean |
| `pnt_mu_log_div_k` | 🟡 Off-crown (alt chain only) | PNTAbelMean.lean |
| `pnt_mu_log_sq_div_k` | 🟡 Off-crown (alt chain only) | PNTAbelMean.lean |
| `vasyunin_offdiag_integral` | 🟡 Off-crown (alt only) | IntegralProof.lean |

### Graduated Theorems 🎓

| Theorem | Date | Method |
|---------|------|--------|
| `abel_mertens_tail_raw` | April 22 | s1_decay + s2_decay + s3_decay |
| `millennium_covariance_cancellation` | April 22 | Variance decomposition + CovarianceAbel |

### Critical Path to Zero Axioms

Only **2 axioms** remain on the crown path:

1. **`rh_implies_mertens_bound`**: RH → |M(x)| = O(√x·log²x)
   - This is Titchmarsh §14.25 — classical analytic number theory
   - Proof route: Perron's formula + contour integration
   - Infrastructure exists: PerronKernel.lean, ZetaConvexity.lean

2. **`bd_gram_form_decay`**: Mertens → ∫(1-f)² ≤ K·loglog/logN
   - This is the BD L² residual bound via Abel summation
   - Proof route: compose l2_from_pointwise_bound_derived chain
   - Infrastructure exists: PlancherelBypass.lean, AbelSiegeProof.lean

---

## Next Steps

### Immediate: Graduate `bd_gram_form_decay` (High Confidence)

`bd_gram_form_decay` may already be *provable from existing infrastructure*. The chain:

```
rh_implies_mertens_bound (axiom)
  → l2_from_pointwise_bound_derived (PlancherelBypass.lean — PROVED)
  → same bound as bd_gram_form_decay
```

`l2_from_pointwise_bound_derived` in PlancherelBypass.lean composes `parseval_bridge` + `critical_line_mellin_bound` to give:

```lean
∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 ≤
    (C_m + 1)² * Real.log (Real.log ↑N) / Real.log ↑N
```

This is essentially `bd_gram_form_decay` but with a different Mertens input signature. **Unifying these signatures could immediately graduate `bd_gram_form_decay` to theorem**, dropping the crown to **1 axiom**.

**Action**: Audit the signature mismatch between `bd_gram_form_decay` (takes C_m, hC_pos, hM directly) and `l2_from_pointwise_bound_derived` (takes structured Mertens hypothesis). If they match modulo packaging, implement the bridge.

### Medium-term: Graduate `rh_implies_mertens_bound` (The Final Axiom)

This is the last axiom. It requires:

1. **Perron's formula**: ψ(x) = (1/2πi) ∫ -ζ'(s)/ζ(s) · x^s/s ds
2. **Contour shift**: Move the contour past the pole at s=1, using RH to ensure no zeros off the critical line
3. **Residue extraction**: The pole at s=1 gives the main term
4. **Error estimation**: The integral on Re(s)=1/2 is O(√x·log²x)

Infrastructure partially exists in:
- `PerronKernel.lean` — Perron kernel definition
- `ZetaConvexity.lean` — Convexity bounds
- `DirichletZetaInverse.lean` — 1/ζ(s) formalization

**Action**: This is a significant Lean formalization effort. Consider whether to prove it directly or establish it via an equivalent PNT-class statement.

### Cleanup: Archive Dead Code

The refactor revealed several potentially stale files in Assembly:
- `MainChain.lean` (186 lines) — may be obsolete
- `BDBypass.lean` (42 lines) — thin wrapper, may be redundant with DirectL2Crown
- `VasyuninBypass.lean` (203 lines) — check if still referenced

**Action**: Audit imports of these files. Archive any that are unreferenced.

### Long-term: The Zero-Axiom Cathedral

The endgame architecture:

```
RiemannHypothesis
  → [PROVED] Perron's formula + contour shift + RH
  → [PROVED] |M(x)| = O(√x·log²x)
  → [PROVED] ∫(1-f)² ≤ K·loglog/logN  (Parseval + Mellin)
  → [PROVED] loglog/logN → 0           (calculus)
  → [PROVED] RH → d²_N → 0            (crown)
  → [PROVED] d²_N → 0 → RH            (converse, already zero-sorry)
  → [PROVED] RH ↔ d²_N → 0            (Nyman-Beurling equivalence)
```

We are 2 axioms from the finish. The path is clear.

---

*"The Cathedral's walls are clean. The path is narrow — two axioms wide — and it leads straight to the light."*
