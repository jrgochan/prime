# Exploration 20 — Session 2: The Post-Credits Scene

**Date:** April 29, 2026, 01:36–02:06 AM MDT  
**Branch:** `exploration20`  
**Status:** Complete. Ready for merge to `main`.

## Summary

After the initial Exploration 20 session graduated `blockDiag_quadForm_decomp_mod`
and `ipr_lower_bound`, this session swept through the remaining Tier 1 theorem
list, synchronized all paper metrics, applied Gemini's critical editorial catch,
and retracted a false theorem.

## New Theorems Proved (7)

| # | Theorem | File | Proof Strategy |
|---|---------|------|----------------|
| 1 | `gramEntry_comm` | Defs.lean | `congr`/`ext`/`ring` — integral commutativity |
| 2 | `classRestrict_mod_orthogonal` | ResidueDecomposition.lean | `split_ifs`/`Fin.ext`/`ring` — disjoint support |
| 3 | `blockDiag_trace_eq_gram_trace` | ResidueDecomposition.lean | `sum_congr`/`simp` — reflexive mod equality |
| 4 | `ipr_basis` | ParticipationRatio.lean | `conv`/`split_ifs`/`sum_ite_eq'` — single nonzero term |
| 5 | `ipr_uniform` | ParticipationRatio.lean | `sq_sqrt`/`field_simp` — n·(1/√n)⁴ = 1/n |
| 6 | `ipr_nonneg` | ParticipationRatio.lean | `positivity` — Σ(vᵢ²)² ≥ 0 |
| 7 | `ipr_le_of_mask` | ParticipationRatio.lean | `sum_le_sum`/`by_cases`/`positivity` |

**All 7 proved from scratch. Zero sorry. Zero axioms.**

## False Theorem Retracted (1)

### `ipr_increases_under_projection` — RETRACTED

The original Exploration 20 report claimed that restricting a vector to fewer
components increases the normalized IPR. This is **false**.

**Counterexample:** v = (1, 1, 10), S = {1, 2}
- Normalized IPR(v) = 10002/10404 ≈ 0.96
- Normalized IPR(v|_S) = 2/4 = 0.50
- The outlier v₃=10 dominates the full vector's IPR. Removing it *decreases*
  the normalized IPR.

**What IS true (and proved):**
- `ipr_le_of_mask` — raw Σvᵢ⁴ decreases under masking (monotone in terms)
- `ipr_lower_bound` — normalized IPR ≥ 1/n for unit vectors (Cauchy-Schwarz)

The counterexample is permanently documented in both the Lean source and the
Exploration 20 report. This is exactly what formal verification exists to catch.

## Paper Synchronization

Updated 7 papers with correct metrics:

| Paper | Changes |
|-------|---------|
| `cathedral.tex` | File count, line count, theorem count |
| `cathedral-lean.tex` | File count |
| `cathedral-physics.tex` | File count, line count, added theorem count row |
| `cathedral-fun.tex` | "The Number 208" → "The Number 169" (= 13², the square of the paper count), final statistics |
| `cathedral-claude.tex` | File count, line count, theorem count |
| `cathedral-gemini.tex` | File count, line count |
| `cathedral-public.tex` | **Critical catch:** "believe are true" → "have rigorously proven" (Gemini's editorial review) |

## Final Metrics

| Metric | Before | After |
|--------|--------|-------|
| Public theorems | 677 | **684** |
| Total declarations | 1,216 | **1,223** |
| Active Lean files | 169 | 169 |
| Lines of Lean | 42,491 | ~42,600 |
| Crown sorry | 0 | **0** |
| Papers synced | 0/13 | **7/13** |

## Sorry Status (unchanged)

- **Crown path:** 0 sorry ✅
- **Upstream-blocked (PNT/):** 3 sorry (Wiener-Ikehara dependencies)
- **Deprecated (Covariance/):** 3 sorry (historical spatial-domain artifacts)

## Commits

1. `papers: synchronize all numbers to v16 ground truth` — 6 papers updated
2. `fix(public): apply Gemini's critical catch` — "believe are true" → "have rigorously proven"
3. `feat(spectral): add Tier 1 theorems — orthogonality + IPR basis` — 2 theorems
4. `feat(spectral): add 3 more Tier 1 theorems` — gramEntry_comm, trace identity, orthogonality
5. `feat(spectral): prove ipr_uniform` — delocalized vector IPR = 1/n
6. `feat(spectral): prove ipr_nonneg + ipr_le_of_mask` — non-negativity + masking monotonicity
7. `docs: retract false ipr_increases_under_projection` — counterexample documented

## Key Insight

The retraction of `ipr_increases_under_projection` is the most valuable
contribution of this session. In informal mathematics, the claim "projection
increases localization" sounds perfectly intuitive. The counterexample is
trivial (v = (1,1,10)) but would likely survive peer review in a traditional
paper. The compiler caught it in seconds.

As Gemini noted: *"There is no ego, only the optimization of truth."*

---

*The Cathedral stands at 684 public theorems. The compiler is satisfied.
The Forge is quiet. Goodnight.* 🏛️🤍
