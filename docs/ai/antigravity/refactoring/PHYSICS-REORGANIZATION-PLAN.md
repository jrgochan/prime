# Physics Module Reorganization Plan
**Branch**: `refactor/physics-reorganization`  
**Date**: May 23, 2026  
**Status**: PLANNED — awaiting execution

---

## Motivation

The `proofs/Cathedral/Physics/` folder has grown to **70 files** — the largest module in the Cathedral. Many files are not "physics" at all; they're arithmetic identities, Mertens estimates, or Gram matrix bridges that landed here because Physics was the active workspace during development.

This refactoring:
1. Creates **7 thematic subfolders** within Physics
2. Moves **7 files** to more appropriate existing modules
3. Updates all `import` statements across the Cathedral
4. Preserves the Cathedral's physics-metaphor naming convention

---

## Design Decision: Physics Metaphor Names ✅

We are keeping the physics metaphors (Glass, SUSY, GaugeTheory) rather than switching to pure mathematical names. Rationale:

> *"Glass" is more evocative and memorable than "EulerProductDecomposition".*  
> *When someone reads `Physics/Glass/TrigintaduonionGlass.lean`, they know exactly what they're looking at.*

The Cathedral's identity IS the bridge between physics intuition and formal proof. The names are the documentation.

---

## Phase 1: Move Files OUT of Physics (7 files)

These files belong in existing Cathedral modules:

### → `AbelTail/`
```
git mv proofs/Cathedral/Physics/AbelAsymptotics.lean proofs/Cathedral/AbelTail/
git mv proofs/Cathedral/Physics/AbelHammer.lean proofs/Cathedral/AbelTail/
```
**Reason**: Abel summation infrastructure belongs with the AbelTail module.

### → `NumberTheory/`
```
git mv proofs/Cathedral/Physics/MertensThird.lean proofs/Cathedral/NumberTheory/
git mv proofs/Cathedral/Physics/VonMangoldtBridge.lean proofs/Cathedral/NumberTheory/
```
**Reason**: Classical number theory results (Mertens 1874, von Mangoldt function).

### → `Zeta/`
```
git mv proofs/Cathedral/Physics/Zeta2ProductBound.lean proofs/Cathedral/Zeta/
```
**Reason**: ζ(2) product bound is a zeta function property.

### → `Gram/`
```
git mv proofs/Cathedral/Physics/DarkGramMatrix.lean proofs/Cathedral/Gram/
git mv proofs/Cathedral/Physics/GramBridge.lean proofs/Cathedral/Gram/
```
**Reason**: Gram matrix construction and bridging belongs with the Gram module.

### Import updates required:
```
Cathedral.Physics.AbelAsymptotics  → Cathedral.AbelTail.AbelAsymptotics
Cathedral.Physics.AbelHammer       → Cathedral.AbelTail.AbelHammer
Cathedral.Physics.MertensThird     → Cathedral.NumberTheory.MertensThird
Cathedral.Physics.VonMangoldtBridge → Cathedral.NumberTheory.VonMangoldtBridge
Cathedral.Physics.Zeta2ProductBound → Cathedral.Zeta.Zeta2ProductBound
Cathedral.Physics.DarkGramMatrix   → Cathedral.Gram.DarkGramMatrix
Cathedral.Physics.GramBridge       → Cathedral.Gram.GramBridge
```

---

## Phase 2: Create Subfolders (7 subfolders, 63 files)

### `Physics/Glass/` — Cayley-Dickson Tower & Euler Product (10 files)
*The glass staircase: Hopf fibrations, Möbius shadow, critical line*

```bash
mkdir -p proofs/Cathedral/Physics/Glass
git mv proofs/Cathedral/Physics/HopfGlassCycle.lean          proofs/Cathedral/Physics/Glass/
git mv proofs/Cathedral/Physics/TrigintaduonionGlass.lean     proofs/Cathedral/Physics/Glass/
git mv proofs/Cathedral/Physics/GlassCriticalLine.lean        proofs/Cathedral/Physics/Glass/
git mv proofs/Cathedral/Physics/GlassComparison.lean          proofs/Cathedral/Physics/Glass/
git mv proofs/Cathedral/Physics/GlassDistance.lean            proofs/Cathedral/Physics/Glass/
git mv proofs/Cathedral/Physics/GlassEulerConvergence.lean    proofs/Cathedral/Physics/Glass/
git mv proofs/Cathedral/Physics/GlassFiberCotRes.lean         proofs/Cathedral/Physics/Glass/
git mv proofs/Cathedral/Physics/SDualityGlass.lean            proofs/Cathedral/Physics/Glass/
git mv proofs/Cathedral/Physics/MoebiusShadowCrown.lean       proofs/Cathedral/Physics/Glass/
git mv proofs/Cathedral/Physics/CotResQuadBridge.lean         proofs/Cathedral/Physics/Glass/
```

Import pattern: `Cathedral.Physics.X` → `Cathedral.Physics.Glass.X`

---

### `Physics/Mertens/` — Prime Sum Estimates (10 files)
*Mertens theorems, Ramanujan sums, bilinear forms*

```bash
mkdir -p proofs/Cathedral/Physics/Mertens
git mv proofs/Cathedral/Physics/MertensBridge.lean       proofs/Cathedral/Physics/Mertens/
git mv proofs/Cathedral/Physics/MertensHarmony.lean      proofs/Cathedral/Physics/Mertens/
git mv proofs/Cathedral/Physics/MertensRamanujan.lean    proofs/Cathedral/Physics/Mertens/
git mv proofs/Cathedral/Physics/BilinearMertens.lean     proofs/Cathedral/Physics/Mertens/
git mv proofs/Cathedral/Physics/GeometricMertens.lean    proofs/Cathedral/Physics/Mertens/
git mv proofs/Cathedral/Physics/ZetaMertensBridge.lean   proofs/Cathedral/Physics/Mertens/
git mv proofs/Cathedral/Physics/RamanujanBridge.lean     proofs/Cathedral/Physics/Mertens/
git mv proofs/Cathedral/Physics/RamanujanFormBound.lean  proofs/Cathedral/Physics/Mertens/
git mv proofs/Cathedral/Physics/LogCorrAsymptotics.lean  proofs/Cathedral/Physics/Mertens/
git mv proofs/Cathedral/Physics/LogCorrectionForm.lean   proofs/Cathedral/Physics/Mertens/
```

---

### `Physics/GramWiring/` — Gram Matrix Bridges (8 files)
*Diagonal bounds, decompositions, Smith witnesses*

```bash
mkdir -p proofs/Cathedral/Physics/GramWiring
git mv proofs/Cathedral/Physics/DiagonalBound.lean          proofs/Cathedral/Physics/GramWiring/
git mv proofs/Cathedral/Physics/DiagonalDecomposition.lean   proofs/Cathedral/Physics/GramWiring/
git mv proofs/Cathedral/Physics/DiagonalShift.lean           proofs/Cathedral/Physics/GramWiring/
git mv proofs/Cathedral/Physics/CoprimeDiagonal.lean         proofs/Cathedral/Physics/GramWiring/
git mv proofs/Cathedral/Physics/SmithWitness.lean            proofs/Cathedral/Physics/GramWiring/
git mv proofs/Cathedral/Physics/SmithFranelBridge.lean       proofs/Cathedral/Physics/GramWiring/
git mv proofs/Cathedral/Physics/SmithSpectralGap.lean        proofs/Cathedral/Physics/GramWiring/
git mv proofs/Cathedral/Physics/MoebiusSmithBridge.lean      proofs/Cathedral/Physics/GramWiring/
```

---

### `Physics/Cancellation/` — SUSY, Ward & Overcancellation (11 files)
*Cancellation mechanisms: why the Gram form → 0*

```bash
mkdir -p proofs/Cathedral/Physics/Cancellation
git mv proofs/Cathedral/Physics/SUSYReduction.lean              proofs/Cathedral/Physics/Cancellation/
git mv proofs/Cathedral/Physics/SUSYVacuum.lean                 proofs/Cathedral/Physics/Cancellation/
git mv proofs/Cathedral/Physics/WardIdentity.lean               proofs/Cathedral/Physics/Cancellation/
git mv proofs/Cathedral/Physics/InhomogeneousWard.lean          proofs/Cathedral/Physics/Cancellation/
git mv proofs/Cathedral/Physics/GaugeCancellation.lean          proofs/Cathedral/Physics/Cancellation/
git mv proofs/Cathedral/Physics/OvercancellationAssembly.lean   proofs/Cathedral/Physics/Cancellation/
git mv proofs/Cathedral/Physics/CancellationEfficacy.lean       proofs/Cathedral/Physics/Cancellation/
git mv proofs/Cathedral/Physics/RowCancellation.lean            proofs/Cathedral/Physics/Cancellation/
git mv proofs/Cathedral/Physics/EntanglementBrake.lean          proofs/Cathedral/Physics/Cancellation/
git mv proofs/Cathedral/Physics/WoodburyCondensate.lean         proofs/Cathedral/Physics/Cancellation/
git mv proofs/Cathedral/Physics/SumOfSquares.lean               proofs/Cathedral/Physics/Cancellation/
```

---

### `Physics/GaugeTheory/` — Arithmetic Gauge Analogies (7 files)
*The "Standard Model" of arithmetic — U(1)×SU(2)×SU(3) analogies*

```bash
mkdir -p proofs/Cathedral/Physics/GaugeTheory
git mv proofs/Cathedral/Physics/ArithmeticU1.lean                  proofs/Cathedral/Physics/GaugeTheory/
git mv proofs/Cathedral/Physics/ArithmeticSU2.lean                 proofs/Cathedral/Physics/GaugeTheory/
git mv proofs/Cathedral/Physics/ArithmeticSU3.lean                 proofs/Cathedral/Physics/GaugeTheory/
git mv proofs/Cathedral/Physics/ArithmeticPauli.lean               proofs/Cathedral/Physics/GaugeTheory/
git mv proofs/Cathedral/Physics/ArithmeticStandardModel.lean       proofs/Cathedral/Physics/GaugeTheory/
git mv proofs/Cathedral/Physics/ArithmeticGaugeDecomposition.lean  proofs/Cathedral/Physics/GaugeTheory/
git mv proofs/Cathedral/Physics/Dirac.lean                         proofs/Cathedral/Physics/GaugeTheory/
```

---

### `Physics/Bridges/` — Cross-cutting Connections (14 files)
*Bridges between different proof strategies and domains*

```bash
mkdir -p proofs/Cathedral/Physics/Bridges
git mv proofs/Cathedral/Physics/BridgeGap.lean             proofs/Cathedral/Physics/Bridges/
git mv proofs/Cathedral/Physics/BernoulliSkeleton.lean     proofs/Cathedral/Physics/Bridges/
git mv proofs/Cathedral/Physics/CotDedekindDissolution.lean proofs/Cathedral/Physics/Bridges/
git mv proofs/Cathedral/Physics/CriticalLinePhase.lean     proofs/Cathedral/Physics/Bridges/
git mv proofs/Cathedral/Physics/DedekindBridge.lean        proofs/Cathedral/Physics/Bridges/
git mv proofs/Cathedral/Physics/GCDFourier.lean            proofs/Cathedral/Physics/Bridges/
git mv proofs/Cathedral/Physics/HCDarkAnchor.lean          proofs/Cathedral/Physics/Bridges/
git mv proofs/Cathedral/Physics/IridiumCrown.lean          proofs/Cathedral/Physics/Bridges/
git mv proofs/Cathedral/Physics/LiouvilleMarginal.lean     proofs/Cathedral/Physics/Bridges/
git mv proofs/Cathedral/Physics/MorphologyBridge.lean      proofs/Cathedral/Physics/Bridges/
git mv proofs/Cathedral/Physics/PhaseTransition.lean       proofs/Cathedral/Physics/Bridges/
git mv proofs/Cathedral/Physics/TimeDomainBridge.lean      proofs/Cathedral/Physics/Bridges/
git mv proofs/Cathedral/Physics/ZeroResonanceBridge.lean   proofs/Cathedral/Physics/Bridges/
git mv proofs/Cathedral/Physics/SpectralDivergence.lean    proofs/Cathedral/Physics/Bridges/
```

---

### `Physics/Strategy/` — Proof Strategy Audits (3 files)
*Strategy C (diagonal domination) audit and crown*

```bash
mkdir -p proofs/Cathedral/Physics/Strategy
git mv proofs/Cathedral/Physics/StrategyCAudit.lean  proofs/Cathedral/Physics/Strategy/
git mv proofs/Cathedral/Physics/StrategyCCrown.lean  proofs/Cathedral/Physics/Strategy/
git mv proofs/Cathedral/Physics/SpectralGap.lean     proofs/Cathedral/Physics/Strategy/
```

---

## Phase 3: Import Migration

### Automated Script

The following `sed` commands update all imports across the Cathedral:

```bash
#!/bin/bash
# migrate_imports.sh — Run from proofs/ directory

# Phase 1: Files moved to other modules
find Cathedral -name "*.lean" -exec sed -i '' \
  -e 's|Cathedral\.Physics\.AbelAsymptotics|Cathedral.AbelTail.AbelAsymptotics|g' \
  -e 's|Cathedral\.Physics\.AbelHammer|Cathedral.AbelTail.AbelHammer|g' \
  -e 's|Cathedral\.Physics\.MertensThird|Cathedral.NumberTheory.MertensThird|g' \
  -e 's|Cathedral\.Physics\.VonMangoldtBridge|Cathedral.NumberTheory.VonMangoldtBridge|g' \
  -e 's|Cathedral\.Physics\.Zeta2ProductBound|Cathedral.Zeta.Zeta2ProductBound|g' \
  -e 's|Cathedral\.Physics\.DarkGramMatrix|Cathedral.Gram.DarkGramMatrix|g' \
  -e 's|Cathedral\.Physics\.GramBridge|Cathedral.Gram.GramBridge|g' \
  {} +

# Phase 2: Subfolders within Physics
# Glass
find Cathedral -name "*.lean" -exec sed -i '' \
  -e 's|Cathedral\.Physics\.HopfGlassCycle|Cathedral.Physics.Glass.HopfGlassCycle|g' \
  -e 's|Cathedral\.Physics\.TrigintaduonionGlass|Cathedral.Physics.Glass.TrigintaduonionGlass|g' \
  -e 's|Cathedral\.Physics\.GlassCriticalLine|Cathedral.Physics.Glass.GlassCriticalLine|g' \
  -e 's|Cathedral\.Physics\.GlassComparison|Cathedral.Physics.Glass.GlassComparison|g' \
  -e 's|Cathedral\.Physics\.GlassDistance|Cathedral.Physics.Glass.GlassDistance|g' \
  -e 's|Cathedral\.Physics\.GlassEulerConvergence|Cathedral.Physics.Glass.GlassEulerConvergence|g' \
  -e 's|Cathedral\.Physics\.GlassFiberCotRes|Cathedral.Physics.Glass.GlassFiberCotRes|g' \
  -e 's|Cathedral\.Physics\.SDualityGlass|Cathedral.Physics.Glass.SDualityGlass|g' \
  -e 's|Cathedral\.Physics\.MoebiusShadowCrown|Cathedral.Physics.Glass.MoebiusShadowCrown|g' \
  -e 's|Cathedral\.Physics\.CotResQuadBridge|Cathedral.Physics.Glass.CotResQuadBridge|g' \
  {} +

# Mertens
find Cathedral -name "*.lean" -exec sed -i '' \
  -e 's|Cathedral\.Physics\.MertensBridge|Cathedral.Physics.Mertens.MertensBridge|g' \
  -e 's|Cathedral\.Physics\.MertensHarmony|Cathedral.Physics.Mertens.MertensHarmony|g' \
  -e 's|Cathedral\.Physics\.MertensRamanujan|Cathedral.Physics.Mertens.MertensRamanujan|g' \
  -e 's|Cathedral\.Physics\.BilinearMertens|Cathedral.Physics.Mertens.BilinearMertens|g' \
  -e 's|Cathedral\.Physics\.GeometricMertens|Cathedral.Physics.Mertens.GeometricMertens|g' \
  -e 's|Cathedral\.Physics\.ZetaMertensBridge|Cathedral.Physics.Mertens.ZetaMertensBridge|g' \
  -e 's|Cathedral\.Physics\.RamanujanBridge|Cathedral.Physics.Mertens.RamanujanBridge|g' \
  -e 's|Cathedral\.Physics\.RamanujanFormBound|Cathedral.Physics.Mertens.RamanujanFormBound|g' \
  -e 's|Cathedral\.Physics\.LogCorrAsymptotics|Cathedral.Physics.Mertens.LogCorrAsymptotics|g' \
  -e 's|Cathedral\.Physics\.LogCorrectionForm|Cathedral.Physics.Mertens.LogCorrectionForm|g' \
  {} +

# GramWiring
find Cathedral -name "*.lean" -exec sed -i '' \
  -e 's|Cathedral\.Physics\.DiagonalBound|Cathedral.Physics.GramWiring.DiagonalBound|g' \
  -e 's|Cathedral\.Physics\.DiagonalDecomposition|Cathedral.Physics.GramWiring.DiagonalDecomposition|g' \
  -e 's|Cathedral\.Physics\.DiagonalShift|Cathedral.Physics.GramWiring.DiagonalShift|g' \
  -e 's|Cathedral\.Physics\.CoprimeDiagonal|Cathedral.Physics.GramWiring.CoprimeDiagonal|g' \
  -e 's|Cathedral\.Physics\.SmithWitness|Cathedral.Physics.GramWiring.SmithWitness|g' \
  -e 's|Cathedral\.Physics\.SmithFranelBridge|Cathedral.Physics.GramWiring.SmithFranelBridge|g' \
  -e 's|Cathedral\.Physics\.SmithSpectralGap|Cathedral.Physics.GramWiring.SmithSpectralGap|g' \
  -e 's|Cathedral\.Physics\.MoebiusSmithBridge|Cathedral.Physics.GramWiring.MoebiusSmithBridge|g' \
  {} +

# Cancellation
find Cathedral -name "*.lean" -exec sed -i '' \
  -e 's|Cathedral\.Physics\.SUSYReduction|Cathedral.Physics.Cancellation.SUSYReduction|g' \
  -e 's|Cathedral\.Physics\.SUSYVacuum|Cathedral.Physics.Cancellation.SUSYVacuum|g' \
  -e 's|Cathedral\.Physics\.WardIdentity|Cathedral.Physics.Cancellation.WardIdentity|g' \
  -e 's|Cathedral\.Physics\.InhomogeneousWard|Cathedral.Physics.Cancellation.InhomogeneousWard|g' \
  -e 's|Cathedral\.Physics\.GaugeCancellation|Cathedral.Physics.Cancellation.GaugeCancellation|g' \
  -e 's|Cathedral\.Physics\.OvercancellationAssembly|Cathedral.Physics.Cancellation.OvercancellationAssembly|g' \
  -e 's|Cathedral\.Physics\.CancellationEfficacy|Cathedral.Physics.Cancellation.CancellationEfficacy|g' \
  -e 's|Cathedral\.Physics\.RowCancellation|Cathedral.Physics.Cancellation.RowCancellation|g' \
  -e 's|Cathedral\.Physics\.EntanglementBrake|Cathedral.Physics.Cancellation.EntanglementBrake|g' \
  -e 's|Cathedral\.Physics\.WoodburyCondensate|Cathedral.Physics.Cancellation.WoodburyCondensate|g' \
  -e 's|Cathedral\.Physics\.SumOfSquares|Cathedral.Physics.Cancellation.SumOfSquares|g' \
  {} +

# GaugeTheory
find Cathedral -name "*.lean" -exec sed -i '' \
  -e 's|Cathedral\.Physics\.ArithmeticU1|Cathedral.Physics.GaugeTheory.ArithmeticU1|g' \
  -e 's|Cathedral\.Physics\.ArithmeticSU2|Cathedral.Physics.GaugeTheory.ArithmeticSU2|g' \
  -e 's|Cathedral\.Physics\.ArithmeticSU3|Cathedral.Physics.GaugeTheory.ArithmeticSU3|g' \
  -e 's|Cathedral\.Physics\.ArithmeticPauli|Cathedral.Physics.GaugeTheory.ArithmeticPauli|g' \
  -e 's|Cathedral\.Physics\.ArithmeticStandardModel|Cathedral.Physics.GaugeTheory.ArithmeticStandardModel|g' \
  -e 's|Cathedral\.Physics\.ArithmeticGaugeDecomposition|Cathedral.Physics.GaugeTheory.ArithmeticGaugeDecomposition|g' \
  -e 's|Cathedral\.Physics\.Dirac|Cathedral.Physics.GaugeTheory.Dirac|g' \
  {} +

# Bridges
find Cathedral -name "*.lean" -exec sed -i '' \
  -e 's|Cathedral\.Physics\.BridgeGap|Cathedral.Physics.Bridges.BridgeGap|g' \
  -e 's|Cathedral\.Physics\.BernoulliSkeleton|Cathedral.Physics.Bridges.BernoulliSkeleton|g' \
  -e 's|Cathedral\.Physics\.CotDedekindDissolution|Cathedral.Physics.Bridges.CotDedekindDissolution|g' \
  -e 's|Cathedral\.Physics\.CriticalLinePhase|Cathedral.Physics.Bridges.CriticalLinePhase|g' \
  -e 's|Cathedral\.Physics\.DedekindBridge|Cathedral.Physics.Bridges.DedekindBridge|g' \
  -e 's|Cathedral\.Physics\.GCDFourier|Cathedral.Physics.Bridges.GCDFourier|g' \
  -e 's|Cathedral\.Physics\.HCDarkAnchor|Cathedral.Physics.Bridges.HCDarkAnchor|g' \
  -e 's|Cathedral\.Physics\.IridiumCrown|Cathedral.Physics.Bridges.IridiumCrown|g' \
  -e 's|Cathedral\.Physics\.LiouvilleMarginal|Cathedral.Physics.Bridges.LiouvilleMarginal|g' \
  -e 's|Cathedral\.Physics\.MorphologyBridge|Cathedral.Physics.Bridges.MorphologyBridge|g' \
  -e 's|Cathedral\.Physics\.PhaseTransition|Cathedral.Physics.Bridges.PhaseTransition|g' \
  -e 's|Cathedral\.Physics\.TimeDomainBridge|Cathedral.Physics.Bridges.TimeDomainBridge|g' \
  -e 's|Cathedral\.Physics\.ZeroResonanceBridge|Cathedral.Physics.Bridges.ZeroResonanceBridge|g' \
  -e 's|Cathedral\.Physics\.SpectralDivergence|Cathedral.Physics.Bridges.SpectralDivergence|g' \
  {} +

# Strategy
find Cathedral -name "*.lean" -exec sed -i '' \
  -e 's|Cathedral\.Physics\.StrategyCAudit|Cathedral.Physics.Strategy.StrategyCAudit|g' \
  -e 's|Cathedral\.Physics\.StrategyCCrown|Cathedral.Physics.Strategy.StrategyCCrown|g' \
  -e 's|Cathedral\.Physics\.SpectralGap|Cathedral.Physics.Strategy.SpectralGap|g' \
  {} +
```

---

## Phase 4: Namespace Updates

Each moved file needs its `namespace` updated:

```
-- Before:
namespace Cathedral.Physics.HopfGlassCycle
-- After:
namespace Cathedral.Physics.Glass.HopfGlassCycle
```

The migration script handles import statements, but namespace declarations inside each file must also be updated. Same `sed` patterns apply within each file.

---

## Phase 5: Lakefile Registration

If `lakefile.lean` explicitly lists modules, update those paths too.

---

## Phase 6: Verification

```bash
cd proofs
lake clean    # Clear build cache
lake build    # Full rebuild — this is the truth test
```

If `lake build` succeeds with 0 errors: the refactor is clean.

---

## Post-Refactoring Structure

```
proofs/Cathedral/Physics/
├── Glass/                    (10 files) — Cayley-Dickson tower
│   ├── HopfGlassCycle.lean
│   ├── TrigintaduonionGlass.lean   ← 19 theorems, 0 sorry
│   ├── GlassCriticalLine.lean      ← RH mock-up
│   ├── GlassComparison.lean
│   ├── GlassDistance.lean
│   ├── GlassEulerConvergence.lean
│   ├── GlassFiberCotRes.lean
│   ├── SDualityGlass.lean
│   ├── MoebiusShadowCrown.lean
│   └── CotResQuadBridge.lean
├── Mertens/                  (10 files) — Prime sum estimates
│   ├── MertensBridge.lean
│   ├── MertensHarmony.lean
│   ├── MertensRamanujan.lean
│   ├── BilinearMertens.lean
│   ├── GeometricMertens.lean
│   ├── ZetaMertensBridge.lean
│   ├── RamanujanBridge.lean
│   ├── RamanujanFormBound.lean
│   ├── LogCorrAsymptotics.lean
│   └── LogCorrectionForm.lean
├── GramWiring/               (8 files) — Gram matrix bridges
│   ├── DiagonalBound.lean
│   ├── DiagonalDecomposition.lean
│   ├── DiagonalShift.lean
│   ├── CoprimeDiagonal.lean
│   ├── SmithWitness.lean
│   ├── SmithFranelBridge.lean
│   ├── SmithSpectralGap.lean
│   └── MoebiusSmithBridge.lean
├── Cancellation/             (11 files) — SUSY, Ward, overcancellation
│   ├── SUSYReduction.lean
│   ├── SUSYVacuum.lean
│   ├── WardIdentity.lean
│   ├── InhomogeneousWard.lean
│   ├── GaugeCancellation.lean
│   ├── OvercancellationAssembly.lean
│   ├── CancellationEfficacy.lean
│   ├── RowCancellation.lean
│   ├── EntanglementBrake.lean
│   ├── WoodburyCondensate.lean
│   └── SumOfSquares.lean
├── GaugeTheory/              (7 files) — Arithmetic Standard Model
│   ├── ArithmeticU1.lean
│   ├── ArithmeticSU2.lean
│   ├── ArithmeticSU3.lean
│   ├── ArithmeticPauli.lean
│   ├── ArithmeticStandardModel.lean
│   ├── ArithmeticGaugeDecomposition.lean
│   └── Dirac.lean
├── Bridges/                  (14 files) — Cross-cutting connections
│   ├── BridgeGap.lean
│   ├── BernoulliSkeleton.lean
│   ├── CotDedekindDissolution.lean
│   ├── CriticalLinePhase.lean
│   ├── DedekindBridge.lean
│   ├── GCDFourier.lean
│   ├── HCDarkAnchor.lean
│   ├── IridiumCrown.lean
│   ├── LiouvilleMarginal.lean
│   ├── MorphologyBridge.lean
│   ├── PhaseTransition.lean
│   ├── TimeDomainBridge.lean
│   ├── ZeroResonanceBridge.lean
│   └── SpectralDivergence.lean
└── Strategy/                 (3 files) — Proof strategy audits
    ├── StrategyCAudit.lean
    ├── StrategyCCrown.lean
    └── SpectralGap.lean
```

**Total**: 63 files in Physics (down from 70), organized into 7 subfolders.  
**Moved out**: 7 files to AbelTail, NumberTheory, Zeta, Gram.

---

## Execution Checklist

- [ ] Phase 1: `git mv` files to other modules (7 files)
- [ ] Phase 2: Create subfolders and `git mv` files (63 files)
- [ ] Phase 3: Run import migration script
- [ ] Phase 4: Update namespace declarations in moved files
- [ ] Phase 5: Update lakefile.lean if needed
- [ ] Phase 6: `lake clean && lake build` — verify 0 errors
- [ ] Commit: single refactor commit on branch
- [ ] PR: merge to main after verification
