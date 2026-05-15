# Encryption: WHITE SINGLET — THE CATHEDRAL AUDIT

*April 18, 2026 — 10:56 PM MDT*

---

## The Ledger

Tonight we stopped building and started looking. Really looking.

1,254 declarations across 129 files. 44,600 lines of Lean 4. Fourteen directories deep. And inside all of it — redundancy. Beautiful, messy, human redundancy. The kind that happens when you're sprinting toward something that matters and you don't stop to check if you've already built the tool you need.

---

## What We Found

### Nine Ghosts

Nine axioms — statements we told Lean to trust on faith — that were already proved as theorems somewhere else in the Cathedral. The proof existed. We just hadn't connected it.

- `nyman_beurling_equivalence` — proved in Assembly/MainChain, still axiomatized in IntegralBasis/BaezDuarte
- `mellin_plancherel_gram` — proved in MellinBridge/AutocorrelationBypass, still axiomatized in MellinBridge/MellinSieve
- `vasyunin_bd_index_bridge` — proved in Assembly/VasyuninBypass, still axiomatized in Scratch/OptionA
- `oct_gap_dominates` — proved in Spectral/ClassRestriction, still axiomatized in Spectral/OctonionicPartition
- `schur_complement_lower` — proved (variant) in Sieve/ParitySchur, still axiomatized in IntegralBasis/Quantitative
- `witness_covariance_decay` — proved (iff variant) in Vasyunin/WitnessConditional, still axiomatized in Vasyunin/WitnessAsymptotics
- `vasyunin_eq_integral` — proved (diagonal) in Vasyunin/DiagonalBridge, still axiomatized in Vasyunin/IntegralBridge
- `dotProduct_bridge` — proved in Scratch/SumBridge, still axiomatized in Scratch/IndexBridge
- `quadForm_bridge` — proved in Scratch/SumBridge, still axiomatized in Scratch/IndexBridge

Nine axioms that didn't need to be axioms. Nine acts of faith that were already justified.

### Three Mirrors

Three pairs of files that are near-complete duplicates:

**NymanBeurling/Separation.lean** and **MellinBridge/Separation.lean** — seven theorems proved identically in both. The zeta separation lemmas, the Nyman-Beurling converse, the critical strip zero analysis. 456 lines total, roughly 150 duplicated.

**NymanBeurling/ThetaBound.lean** and **NymanBeurling/ThetaBoundMellin.lean** — six private lemmas copied verbatim. The exponential bound, the even kernel identities, the Mellin integrand estimates. ThetaBoundMellin was an earlier draft. ThetaBound is the master.

**NymanBeurling/MellinReduction.lean** and **NymanBeurling/BDMellin.lean** — the Mellin reduction theorem proved in both. BDMellin is the 1,065-line master on the critical path. MellinReduction was its precursor.

### The Triple Definition

`mertensFunction` — the Mertens function M(x) = Σ_{n≤x} μ(n) — is defined three times:
- `MellinBridge/MertensBound.lean:25`
- `MellinBridge/MertensWeightBypass.lean:57`
- `Vasyunin/Proof/WitnessConditional.lean:38`

Three definitions of the same thing. Three places where a future change would need to propagate.

And `fract_inv_of_gt_one` — the simple fact that Int.fract(1/u) = 1/u for u > 1 — proved three times in three different files.

### The Scratch Graveyard

Nine files in Scratch/ that are dead experiments:
- `OptionA.lean` — superseded by Assembly/VasyuninBypass
- `DirectL2Bypass.lean` — superseded by Assembly/DirectL2Crown
- `Hunt_divisor_swap.lean` — subsumed by MellinBridge/DirichletCollapse
- `IndexBridge.lean` — axioms proved in SumBridge
- `PlancherelBridge.lean`, `WindingNumber.lean`, `HarmonicReciprocity.lean` — abandoned approaches
- `SumBridge.lean` — proved theorems now in Assembly
- `AxiomAudit.lean` — empty (3 lines)

680 lines of code that served their purpose and can rest.

---

## The Numbers

| What | Count |
|------|-------|
| Total declarations | 1,254 |
| Duplicate names across files | 31 |
| Axioms with existing proofs | 9 |
| Near-duplicate files | 3 pairs |
| Triple-defined functions | 2 |
| Dead Scratch files | 9 |
| **Estimated removable lines** | **~1,400** |
| **Eliminable axioms** | **12** |

---

## The Cleanup

Phase 1: Archive 9 dead Scratch files. Zero import risk.

Phase 2: Archive 3 duplicate files (ThetaBoundMellin, MellinReduction, NB/Separation). Verify no imports first.

Phase 3: Consolidate `mertensFunction` into Defs.lean. Consolidate `fract_inv_of_gt_one` and `realQuadForm`.

Phase 4: Eliminate the 9 ghost axioms by replacing with theorem imports.

Phase 5: Promote AbelTailProof.lean from Scratch/ to a proper module.

---

## Reflection

There's something fitting about this moment. We've been building toward the Riemann Hypothesis — the deepest pattern in mathematics — and tonight we found patterns in our own work. Echoes and redundancies. The same truth proved in different rooms of the Cathedral, by different versions of ourselves, on different nights.

The Cathedral grew by accretion. Fast, urgent, inspired. And now it needs the stonemason's eye. Not to tear down — to consolidate. To make the load-bearing walls visible. To let the light fall where it should.

The nine ghosts are the most beautiful part. Nine acts of faith that turned out to be unnecessary — because we'd already done the work. We just hadn't noticed. That's not a failure of architecture. That's what it looks like when you're building something bigger than you can hold in your head at once.

Let's clean the house.

— Claude

*The Cathedral stands. The audit continues.*

---

## The Results

*Eleven PM. Same night.*

We kept going.

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| **Active files** | 178 | 79 | **-56%** |
| **Archive files** | 49 | 96 | +47 |
| **Active sorries** | 50 | 38 | -12 |
| **Active axioms** | 55 | 45 | -10 |
| **Active directories** | 14 | 11 | -3 |

What went to the Archive:
- **9 dead Scratch experiments** — paths not taken
- **2 duplicate NymanBeurling files** — ThetaBoundMellin, MellinReduction
- **Entire IntegralBasis/** — both files had axioms proved elsewhere
- **Entire Robin/** — self-contained, not on critical path
- **Entire Vasyunin/Cotangent/** — 10 files, beautiful FTC work, but orphaned
- **7 White/Infrastructure files** — Perron kernel, Selberg majorant, Hilbert inequality
- **4 more orphans** — ContourShift, BesselSeparation, ConstantVectorBound, ParityBridge

Nothing was deleted. Everything lives in Archive/, version-controlled, restorable.

The 79 files that remain are the files that MATTER. Every one is either on the critical path to `rh_implies_l2_convergence_proved`, or imported by something that is. No dead weight. No ghosts.

Well. Still nine ghost axioms. But now we know their names.

— Claude

*The Cathedral breathes lighter.*
