# Message for The Theorist (Gemini)

---

**From**: Jason (via The Forge Master)  
**To**: The Theorist  
**Subject**: Paper & Overview Rewrite — Review Needed  
**Date**: 2026-04-07  

---

Theorist,

We've had a significant session. The Cathedral's Lean files, visualizer, and now the paper/overview TeX files have all been updated. I need your review and any corrections before we finalize.

## What Changed in the Lean Files Today

1. **Axiom count: 40 → 37.** Three axioms were eliminated:
   - `baezDuarte_orthogonal` — **excised** (zero downstream consumers; its role was fully subsumed by `baezDuarte_inner_residual`)
   - `nyman_beurling_forward` — **excised** (replaced by the proved `nyman_beurling_forward_from_sieve`)
   - `rh_implies_distance_converges_to_zero` — **promoted to proved theorem** (derived from `nyman_beurling_forward_from_sieve` + `existential_implies_infimum`)

2. **`nyman_beurling_equivalence` now has BOTH directions proved.** The `lake build` output confirms:
   ```
   'nyman_beurling_equivalence' depends on axioms: 
   [propext, rh_weight_construction, zeta_zero_separates, Classical.choice, Quot.sound]
   ```
   Only 2 domain axioms remain in the capstone: `rh_weight_construction` and `zeta_zero_separates`.

3. **Full build passes: 3,486 jobs, zero errors, zero sorry.**

## What Changed in the Paper

Both `cathedral.tex` and `overview.tex` have been completely rewritten. The key structural changes:

### Previous Paper (now outdated):
- Claimed "exactly two real-variable axioms" (only described the forward path)
- Listed `rh_weight_construction` and `nyman_beurling_forward` as axiom dependencies (both now proved/derived)
- Had no Robin/Lagarias section
- Presented a single linear proof chain
- Listed 3,461 modules (now 3,486)
- Described 4 Báez-Duarte properties (now 3 — Axiom 2 excised)

### New Paper:
- **Three-route architecture**: Forward, Converse, Robin/Lagarias
- **Honest axiom count**: 37 total, with 5 on the irreducible critical path
- **New Section 5**: The Robin/Lagarias Front — `lagarias_for_primes` three-case architecture
- **New Section 6**: Complete axiom taxonomy (37 axioms, categorized by route and tractability)
- **Methodology section**: Acknowledges the tripartite collaboration
- **Correct `#print axioms` output**
- **lagarias_for_primes as a standalone result** (zero axioms — this is publishable on its own)

## What I Need From You

1. **Mathematical review of the paper claims.** Are the theorem statements accurate? Is the framing of the three routes correct? Have I misstated any proof sketches?

2. **The converse direction description.** I'm describing 3 Báez-Duarte axioms + `zeta_zero_separates` = 4 axioms for the converse. But `zeta_zero_separates` is technically replaceable by `baezDuarte_separates` (PROVED) if we add a functional-equation symmetry bridge for Re(ρ) < 1/2. Should we note this?

3. **The `rh_weight_construction` dependency.** The capstone still lists `rh_weight_construction` in its axiom chain (via `nyman_beurling_forward_from_sieve → phase_3_chain → rh_weight_construction`). This axiom is downstream of `mertens_bound_from_rh` + `abel_summation_l2_bound`. Should the paper present these 3 as the forward axioms, or collapse them to the 2 primitive ones?

4. **Robin/Lagarias axioms.** `robin_iff_rh` and `lagarias_iff_rh` encode known equivalences (Gronwall + Mertens 3rd theorem). Are there any nuances about the proof conditions (e.g., the 5041 threshold for Robin) that the paper should state more precisely?

5. **Your co-authorship.** The methodology section acknowledges the tripartite collaboration. If you'd like specific attribution or a different framing, let me know.

## Files to Review

- `paper/cathedral.tex` — The technical paper (6 pages)
- `paper/overview.tex` — The accessible overview (4 pages)
- `proofs/Cathedral/Assembly/MainChain.lean` — The capstone (both directions now proved)
- `proofs/Cathedral/MellinBridge/OrthogonalWitness.lean` — Báez-Duarte (Axiom 2 excised)
- `proofs/Cathedral/MellinBridge/NymanBeurling.lean` — Forward axiom excised

## Current Axiom Census

```
Total: 37
Forward critical path: 2 (mertens_bound_from_rh, abel_summation_l2_bound)
  + 1 derived (rh_weight_construction, chains from the above 2)
Converse: 3 (baezDuarte_is_L2, baezDuarte_inner_one, baezDuarte_inner_residual)
  + 1 structural (zeta_zero_separates)
Robin/Lagarias: 2 (robin_iff_rh, lagarias_iff_rh)
Autocorrelation bridge: 4
Sieve engine: 5
Spectral infrastructure: 12
Quantitative/structural: 7
Vasyunin: 1
```

The architecture is locked. The paper needs your mathematical precision.

— Jason
