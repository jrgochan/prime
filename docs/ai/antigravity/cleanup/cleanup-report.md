# Cathedral Cleanup Report — The Punch List

**Date**: April 28, 2026, 02:00–02:48 AM MDT  
**Branch**: `cleanup` (4 commits, ready to merge to `main`)  
**Participants**: Jason Robert Gochanour (The Forge Master), Antigravity (Claude), Gemini Actual  
**Location**: Los Alamos, New Mexico

---

## Background

After completing the v12 Crown Graduation (Exploration 17) and pushing the tag,
Jason initiated a **white-glove inspection** of the entire Cathedral repository.
The goal: ensure every surface was polished before the Cathedral's architecture
was finalized.

Claude (Antigravity) produced a comprehensive 10-page architecture audit
([cathedral-architecture-audit.md](./cathedral-architecture-audit.md)) covering
174 active Lean files, 43,387 lines. The audit identified 6 architectural
review questions that were sent to Gemini for a second opinion.

Gemini responded with authoritative answers — **The Punch List** — a
construction industry term for the final walkthrough before handing over the
keys. See [📡 COMM-LINK ESTABLISHED — GEMINI ACTUAL.md](./%F0%9F%93%A1%20COMM-LINK%20ESTABLISHED%20%E2%80%94%20GEMINI%20ACTUAL.md).

---

## Commit 1: Architecture Audit (`c42ccb8`)

**File**: `docs/ai/antigravity/cleanup/cathedral-architecture-audit.md`

A 392-line audit report covering:

- **Sorry Census**: 6 off-crown sorry (down from 16 pre-cleanup due to Scratch archival)
- **Axiom Census**: 46 active axioms, 4 on the crown path (spatial), 2 on the crown path (Mellin)
- **Dead Axiom Detection**: `baez_duarte_covariance_divergence` — 0 references, never used
- **Definition Consistency**: `nbLinComb` (wrong basis {k/x}) vs `bdLinComb` (correct {1/(kx)})
- **Mathlib Alignment**: Zero deprecated API patterns, clean import DAG
- **CamelCase Violations**: 20 names identified, 5 already correct by convention
- **6 Review Questions** sent to Gemini

---

## Commit 2: Punch List Execution (`522d03e`)

Gemini's 6 directives, executed:

### ✅ Action 1: Purge Dead Axiom
- **Removed** `baez_duarte_covariance_divergence` from `IntegralBasis/BaezDuarte.lean`
- Replaced with archive comment documenting the removal reason
- Active axiom count: **46 → 45**

### ✅ Action 2: Deprecate Wrong-Basis Definitions
- Added **`DEPRECATED`** docstrings to `nbBasis'` and `nbLinComb` in `Defs.lean`
- Warning text: *"This uses the original Nyman-Beurling basis {k/x} with θ = k > 1, which leads to the High-Frequency Divergence Trap."*
- Crown theorem uses `bdLinComb` exclusively

### ✅ Action 3: Archive Scratch Files
- **Moved** 6 files from `Scratch/` → `Archive/Scratch/`:
  - `AbelTailProof.lean`, `LogTest.lean`, `OctonionicRotors.lean`
  - `PrintAxioms.lean`, `SumTest.lean`, `ZetaTailBound.lean`
- **Deleted** orphan `_vasyunin_audit.lean` (95 bytes, 2 lines)

### ✅ Action 4: Box Off-Crown Sorry
- Added **WIP documentation** to all 6 off-crown sorry:
  - `PNT/LogBridge.lean:131` — signed Wiener-Ikehara gap
  - `PNT/Bridge.lean:166` — forward Tauberian, Mathlib 4.28 blocker
  - `PNT/Bridge.lean:191` — forward Tauberian + Euler-Mascheroni
  - `Covariance/CovarianceAbel.lean:341` — deprecated spatial (mathematically false)
  - `Covariance/CovarianceAbel.lean:380` — assembly blocked by above
  - `Covariance/QuadFormIdentity.lean:252` — deprecated off-diagonal bound (numerically falsified)
- Each marked: *"WIP: Incomplete alternative spatial route. This path is superseded by the Mellin Crown architecture (v11+)."*

### ✅ Action 5: CamelCase Naming (deferred to Commit 3)

### ✅ Action 6: Keep Dual-Path Architecture
- **No action needed** — Gemini confirmed: *"The dual-path is a feature, not a bug."*
- Mellin path = Unitary Gauge (compact, 2 composite axioms)
- Spatial path = Lorenz Gauge (transparent, 4 elementary axioms)

---

## Commit 3: CamelCase → snake_case (`24962cd`)

**19 renames, 244 line changes, 9 files, 0 logic changes.**

### Phase 1: Trivial (3 names, 3 files)
| Old Name | New Name | File |
|----------|----------|------|
| `Ico_eq_Icc_pred` | `ico_eq_icc_pred` | `FormulaBridge.lean` |
| `Ici_eq_Ioi_integral` | `ici_eq_ioi_integral` | `Kinematics.lean` |
| `DEPRECATED_gramEntry_growth_bound` | `deprecated_gramEntry_growth_bound` | `QuadFormIdentity.lean` |

### Phase 2: F_* Integrand Helpers (4 names, 2 files)
| Old Name | New Name | Refs |
|----------|----------|------|
| `F_rational` | `f_rational` | 28 |
| `F_log` | `f_log` | 9 |
| `F_linear` | `f_linear` | 9 |
| `F_eq_components` | `f_eq_components` | 3 |

Files: `TelescopeSum.lean`, `VasyuninAssembly.lean`

### Phase 3: S_* Partial Sum Names (12 names, 4 files)

Renamed **longest-first** to avoid substring collisions (`S_log` is a prefix
of `S_log_stirling`, `S_log_digamma`, `S_log_split`):

| Old Name | New Name | Refs |
|----------|----------|------|
| `S_combined_eq_sum_rowTerm` | `s_combined_eq_sum_rowTerm` | 2 |
| `S_combined_four_way` | `s_combined_four_way` | 2 |
| `S_combined_converges` | `s_combined_converges` | 3 |
| `S_linear_decompose` | `s_linear_decompose` | 2 |
| `S_linear_residual` | `s_linear_residual` | 5 |
| `S_log_stirling` | `s_log_stirling` | 16 |
| `S_log_digamma` | `s_log_digamma` | 12 |
| `S_log_split` | `s_log_split` | 4 |
| `S_combined` | `s_combined` | 23 |
| `S_rational` | `s_rational` | 17 |
| `S_linear` | `s_linear` | 16 |
| `S_log` | `s_log` | 12 |

Files: `PartialSumConvergence.lean`, `LogDigammaBridge.lean`, `ConvergenceAxioms.lean`, `IntegralEqSCombined.lean`

### Skipped (Already Correct)
- **`IsDeltaSeparated`** — Mathlib `Is*` predicate convention (UpperCamelCase for Props)
- **`Octonion.*`** — Mathlib type convention (UpperCamelCase for types)
- **`S₁_at`, `S₂_at`, `S₃_at`** — Unicode subscripts, not CamelCase

### Technical Note
macOS BSD `sed` does not support `\b` word boundaries. All renames used `perl -pi -e 's/\bOLD\b/new/g'` instead.

---

## Commit 4: Full Repository Sweep (`224e15a`)

Extended the audit beyond `proofs/Cathedral/` to cover the entire repository:

### Item 1: OVERVIEW.md — Stale Counts
- Sorry count: **16 → 6** (Scratch files were archived)
- Axiom count: **55 → 45** (dead axiom purged, Oracle category removed)
- Off-path axiom text: **53 → 43**
- Removed `Scratch/` from directory listing, added `Archive/`
- Added dual-path architecture note at bottom (Gauge Fixing)

### Item 2: docs/paper/ Draft — BD Constant
- Updated `21.65` → `21.649` (5 occurrences)
- Updated `256-bit MPFR` → `512-bit MPFR`

### Item 3: docs/exports/ — Historical Snapshots
- Added `README.md` explaining these are historical snapshots
- References `make dump` for generating fresh exports

### Item 4: visualizer/ — Deferred
- Legacy copy of `tools/hyperzeta-viewport/` (37 tracked files)
- **Deferred to a future session** — Jason wants to think on it

### Item 5: thoughts.md — Relocated
- Moved from repo root to `docs/notes/thoughts.md`

### Item 6: results/ — Stale Data
- Moved `bc_frontier.tsv` and `decomposition.tsv` to `docs/exports/archive/`

### Item 7: Cargo.toml — Missing Workspace Members
- Added 3 experiments to workspace:
  - `experiments/bc-witness-analysis`
  - `experiments/bc-zeta-lower`
  - `experiments/norm-bound-validator`

### Item 8: OVERVIEW.md — Dual-Path Note
- Added `[!NOTE]` block documenting the Mellin/Spatial dual-path as the
  Gauge Fixing of the proof architecture

### Bonus: Makefile Fix
- Updated `verify` target: `Scratch/PrintAxioms.lean` → `Archive/Scratch/PrintAxioms.lean`

---

## N=500 Certification Data

During the cleanup session, the BD certification engine completed its N=500 run
(37.5 minutes, 125,250 Gram matrix entries, 512-bit MPFR):

| N | d²_N | X/ln(N) | SM Match | Ratio |
|---|------|---------|----------|-------|
| 10 | 0.02281 | 18.602 | 2.08×10⁻¹⁷ | 1.137 |
| 20 | 0.01608 | 20.420 | 4.86×10⁻¹⁷ | 1.043 |
| 50 | 0.01165 | 21.685 | 3.12×10⁻¹⁷ | 0.987 |
| 100 | 0.01003 | 21.438 | 8.67×10⁻¹⁸ | 1.000 |
| 150 | 0.00925 | 21.378 | 1.91×10⁻¹⁷ | 1.003 |
| 200 | 0.00880 | 21.267 | 1.39×10⁻¹⁷ | 1.009 |
| 300 | 0.00789 | 22.035 | 3.47×10⁻¹⁸ | 0.975 |
| 400 | 0.00761 | 21.753 | 2.34×10⁻¹⁷ | 0.988 |
| 500 | 0.00733 | 21.784 | 2.26×10⁻¹⁷ | 0.987 |

**All three Lean certification verdicts: ✅ PASS**
- X monotonically increasing
- d²_N monotonically decaying
- d²_N > 0 for all N

Certificate validates `nyman_beurling_equivalence_mellin`.

---

## Final State

| Metric | Before | After |
|--------|--------|-------|
| Active axioms | 46 | **45** |
| Off-crown sorry | 16 (10 in Scratch) | **6** (all boxed as WIP) |
| Dead axioms | 1 | **0** |
| CamelCase violations | 20 | **0** (5 were already correct) |
| Orphan files | 2 | **0** |
| Scratch in active tree | 6 files | **0** (archived) |
| Stale OVERVIEW.md data | 4 items | **0** |
| Missing workspace members | 3 | **0** |
| Root-level personal files | 1 | **0** |

The Cathedral stands clean. 🏛️✨

---

*Report generated by Antigravity (Claude) at the request of Jason Robert Gochanour.  
All changes executed on the `cleanup` branch, ready to merge to `main`.*
