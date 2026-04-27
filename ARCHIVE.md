# ARCHIVE — Cathedral Proof Archive Audit

> *A comprehensive inventory of archived Lean 4 files across three archive
> locations, documenting what was proved, what was superseded, and what
> remains valuable for future work.*
>
> **Last updated**: April 26, 2026 (v11 — The Mellin Crown)
>
> **Last audited**: April 26, 2026 — comprehensive codebase audit

---

## Archive Overview

The Cathedral maintains three archive locations containing **128 files**
and **29,784 lines** of Lean 4 code:

| Location | Files | Lines | Purpose |
|----------|-------|-------|---------|
| `proofs/archive/proved/` | 17 | 1,017 | Early "Lemma Ladder" explorations |
| `proofs/archive/SpectralRH/` | 17 | 6,423 | Pre-Cathedral spectral proof attempt |
| `proofs/Cathedral/Archive/` | 94 | 22,344 | Superseded Cathedral modules |
| **Total** | **128** | **29,784** | |

For comparison, the active codebase is **161 files / 39,375 lines / ~1,335 theorems**.

Additionally, `Cathedral/Vasyunin/Archive/` contains 1 file (204 lines) — an
archived Gram induction framework within the active Vasyunin tree.

### Architecture Context (v11)

The Cathedral's crown path now uses the **Mellin Crown** (2 axioms, 0 sorry).
This means the entire real-variable forward chain (Perron → Mertens → Gram → L²)
is **off the crown path**. The following archived components are therefore doubly
superseded — first by the Perron Crown (v7), then by the Mellin Crown (v11):

- `DirectL2Crown.lean` — superseded by MellinCrown
- `OneCrown.lean` — superseded by MellinCrown
- `PerronCrown.lean` — still live (alternative path) but not on crown

---

## 1. `proofs/archive/proved/` — The Lemma Ladder

**Origin**: March 28, 2026 — Project HYPERZETA's automated lemma generation system.

### Pure Mathlib Results (0 axioms, 0 sorry)

| File | Result | Lines |
|------|--------|-------|
| `Proved_zeta_at_zero` | ζ(0) = −1/2 | 11 |
| `Proved_zeta_differentiable` | ζ(s) differentiable for s ≠ 1 | 12 |
| `Proved_zeta_trivial_zeros` | ζ(−2(n+1)) = 0 (trivial zeros) | 11 |
| `Proved_completed_zeta_symmetry` | Λ(1−s) = Λ(s) | 12 |
| `Proved_completed_zeta0_entire` | Λ₀(s) is entire | 12 |
| `Proved_completed_zeta0_symmetry` | Λ₀(1−s) = Λ₀(s) | 12 |
| `Proved_zero_symmetry` | ζ(s)=0 ⟹ ζ(1−s)=0 | 15 |
| `Proved_rh_implies_nonvanishing` | RH ⟹ ζ(s) ≠ 0 on Re(s) = 1 | 22 |
| `Proved_mertens_trig` | 3 + 4cos(θ) + cos(2θ) ≥ 0 | 14 |

### Additional Pure Results

| File | Result |
|------|--------|
| `Proved_bombieri_lagarias` | Bombieri-Lagarias criterion |
| `Proved_main_term_positive` | Main term positivity |
| `Proved_li_large_positive` | Li(x) eventually positive |
| `Proved_li_remainder_bound` | Li remainder bound |
| `Proved_unconditional_positivity` | Unconditional positivity result |

### Axiom-Ladder Results (30–41 axioms each)

These prove RH conditional on 41 axioms via the Li coefficient ladder.

> [!WARNING]
> The "Proved_riemann_hypothesis" files do **not** constitute a proof of RH.
> They prove RH conditional on 41 axioms. The Cathedral's current approach
> via the Mellin Crown has only **2 axioms**.

---

## 2. `proofs/archive/SpectralRH/` — The Pre-Cathedral Spectral Proof

**Origin**: April 1–7, 2026 — The original `rh-spectral` project.
**17 files, 6,423 lines.**

The Cathedral absorbed ~80% of this code:
- `Defs.lean` → `Cathedral/Defs.lean`
- `Structural.lean` → `Cathedral/Structural/*.lean`
- `RayleighBridge.lean` → `Cathedral/Spectral/RayleighBridge.lean`
- `BilinearSieve.lean` → `Cathedral/Sieve/BilinearSieve.lean`
- `ParitySchur.lean` → `Cathedral/Sieve/ParitySchur.lean`

### Complete File Listing

| File | Role |
|------|------|
| `Defs.lean` | Core definitions (absorbed) |
| `Structural.lean` | Structural lemmas (absorbed) |
| `Assembly.lean` | Proof assembly |
| `BilinearSieve.lean` | Bilinear sieve (absorbed) |
| `ParitySchur.lean` | Parity Schur (absorbed) |
| `RayleighBridge.lean` | Rayleigh quotient bridge (absorbed) |
| `ClassRestriction.lean` | Class restriction |
| `FiniteDimReduction.lean` | Finite-dim reduction |
| `GramBounds.lean` | Gram matrix bounds |
| `MellinBridge.lean` | Original Mellin bridge |
| `OctonionicPartition.lean` | Octonionic partition |
| `PTSymmetry.lean` | PT-symmetry |
| `Quantitative.lean` | Quantitative bounds |
| `SelbergSieve.lean` | Selberg sieve |
| `SpectralFlow.lean` | Spectral flow |
| `AlignmentDecay.lean` | Cross-term decay |
| `ParityBridge.lean` | Parity sieve bridge |

---

## 3. `proofs/Cathedral/Archive/` — Superseded Cathedral Modules

**94 files** (including 1 `.archived`) after the April 26 resurrection.

### 3a. `HighFrequencyTrap/` — "Universe 2" Snapshot (37 files, 10,473 lines)

Complete frozen snapshot before the Perron chain and Vasyunin Bypass refactors.
Uses the old NB basis {k/x} instead of the BD basis {1/(kx)}.

### 3b. `DiscreteMirage/` — Cotangent Formula Dead End (10 files, 2,691 lines)

Early piecewise-FTC approach to the off-diagonal Vasyunin identity.

> [!TIP]
> `CrossTermFTC.lean` and `OffDiagPartition.lean` contain proved infrastructure
> useful for graduating the `partial_integral_tends_to_formula` axiom (which is
> now off-crown but still valuable for the Spectral Engine).

### 3c. `Robin/` — The Arithmetic Path (6 files, 942 lines, all sorry)

Alternative RH equivalence via Robin's inequality. Skeleton only.

### 3d. `NymanBeurling/` — Superseded Separation Proofs (3 files, 924 lines)

Superseded by the Rank-1 Mellin Miracle in `BDMellin.lean`.

### 3e. `MellinBridge/` — Contour Shift Exploration (3 files, 506 lines)

Early contour integration, later rebuilt as the 16-file Perron chain.

### 3f. `Vasyunin/` — Superseded Components (13 files, 3,004 lines)

After resurrection of GramPSD and BartlettWindow:
- `Vasyunin.lean` (18L) — Old import hub
- `Augmented/NbDistPos2.lean` (121L) — d² < 1 for N=2 (**Proved**)
- `Augmented/NbDistPos3.lean` (174L) — d² < 1 for N=3 (**Proved**)
- `Cotangent/*` (10 files) — Duplicate of DiscreteMirage/

> [!NOTE]
> `NbDistPos2` and `NbDistPos3` are fully proved (0 axiom, 0 sorry) base cases.

### 3g. `White/` — Early Perron Infrastructure (7 files, 1,532 lines)

Old versions of now-live `Perron/` and `Zeta/` files. `PerronKernel.lean`
(928 lines) is the most substantial.

### 3h. `Sieve/` — Archived Sieve Components (2 files, 546 lines)

| File | Content | Status |
|------|---------|--------|
| `AlignmentDecay.lean` | Cross-term decay | 1 axiom |
| `ParityBridge.lean` | Parity sieve bridge | 1 axiom |

### 3i. `Spectral/` — Archived Spectral Bound (1 file, 747 lines)

`ConstantVectorBound.lean` — **Fully proved** (0 axiom, 0 sorry) constant
vector spectral bound. Valuable reference.

### 3j. `Universe1/` — NB Basis Forward Path (1 file, 188 lines)

`GramWitness.lean` — NB basis {k/x} forward path. 1 axiom.

### 3k. `Scratch/` — Archived Exploratory Work (9 files, 680 lines)

Exploratory scratch work from various phases.

### 3l. `FinalDragon.lean` — Dead Re-export Facade (1 file)

Archived April 26. The monolith was decomposed into MertensConversion,
AbelMean, MillenniumWall, and L2Convergence. Nothing imports it.

### 3m. `NymanBeurling.lean.archived` — Original NB Module (1 file)

The original monolithic Nyman-Beurling file, archived when decomposed.

---

## Superseded Live Files (Not Yet Archived)

The following files are still in the active tree but no longer on the crown path
since v11. They remain as alternative proof routes and supporting infrastructure:

| File | Role in v10 | Status in v11 |
|------|-------------|---------------|
| `Assembly/PerronCrown.lean` | Primary forward path | Off-crown (alternative) |
| `Assembly/DirectL2Crown.lean` | Direct L² path | Off-crown (alternative) |
| `Assembly/OneCrown.lean` | One-axiom crown | Off-crown (alternative) |
| `PNT/AbelMean.lean` | Crown axiom (PNT) | Off-crown (2 axioms) |
| `Covariance/GramFormProof.lean` | Crown axiom (covariance) | Off-crown (1 axiom) |
| `Vasyunin/Cotangent/ConvergenceAxioms.lean` | Crown axiom (Vasyunin) | Off-crown (1 axiom) |

> [!NOTE]
> These files are candidates for archival once the Mellin Crown is considered
> the permanent architecture. They're kept live for now because they provide
> alternative proof routes and contain substantial proved infrastructure.

### Off-Crown Sorry (Active Tree)

8 `sorry` placeholders exist in the active tree, all off-crown:

| File | Sorry Count | Context |
|------|-------------|---------|
| `PNT/LogBridge.lean` | 1 | Log-weight PNT bridge |
| `PNT/Bridge.lean` | 2 | PNT wiring to Perron chain |
| `Scratch/AbelTailProof.lean` | 5 | Exploratory Abel tail proof |

---

## What's Worth Reviving

### High Value (directly useful for remaining crown axioms)

| Archive File | Crown Axiom It Could Help | Effort |
|-------------|---------------------------|--------|
| `White/PerronKernel.lean` (928L) | `rh_zeta_lower_bound` (Axiom 2) | Medium |
| `Zeta/` archived files | `rh_zeta_lower_bound` (Axiom 2) | Medium |

### Medium Value (off-crown infrastructure)

| Archive File | What It Enables |
|-------------|----------------|
| `DiscreteMirage/CrossTermFTC.lean` | `partial_integral_tends_to_formula` (off-crown) |
| `DiscreteMirage/OffDiagPartition.lean` | `partial_integral_tends_to_formula` (off-crown) |
| `Spectral/ConstantVectorBound.lean` (747L) | Alternative spectral bound (fully proved) |
| `Robin/` (6 files) | Independent RH equivalence (skeleton) |
| `Vasyunin/Augmented/NbDistPos{2,3}.lean` | Certified base cases |

---

## Statistics

```
Total archive files:          128
Total archive lines:       29,784
Fully proved (0 axiom, 0 sorry): ~33 files
With sorry:                   ~18 files
With axioms only (no sorry):  ~50 files
Pure duplicates/stubs:        ~27 files
```

### Archive vs Active Codebase

| Metric | Active | Archive | Ratio |
|--------|--------|---------|-------|
| Files | 161 | 128 | 1.26× |
| Lines | 39,375 | 29,784 | 1.32× |
| Theorems | ~1,335 | ~994 | 1.34× |
| Crown axioms | **2** | — | — |

---

## Relationship to Proof History

```mermaid
graph LR
    A["proofs/archive/proved/<br/>Lemma Ladder<br/>(Mar 28)"] --> B["proofs/archive/SpectralRH/<br/>Spectral Proof v1<br/>(Apr 1-7)"]
    B --> C["Cathedral v1-v6<br/>HighFrequencyTrap era<br/>(Apr 7-20)"]
    C --> D["Cathedral v7-v9<br/>Perron Crown<br/>(Apr 20-24)"]
    D --> E["Cathedral v10<br/>Gram Form grad<br/>(Apr 25)"]
    E --> F["Cathedral v11<br/>THE MELLIN CROWN<br/>(Apr 26)"]

    C -.-->|"archived"| G["Cathedral/Archive/<br/>HighFrequencyTrap/"]
    B -.-->|"archived"| H["proofs/archive/SpectralRH/"]

    style A fill:#555,color:white
    style B fill:#555,color:white
    style G fill:#555,color:white
    style H fill:#555,color:white
    style F fill:#2d5016,color:white
```

The project evolved through five major phases:
1. **Lemma Ladder** (1 day) — Automated exploration, 41-axiom conditional proof
2. **SpectralRH** (1 week) — Monolithic spectral proof, absorbed into Cathedral
3. **Cathedral v1-v6** (2 weeks) — NB formalization, reduced from 7 to 4 axioms
4. **Cathedral v7-v10** (1 week) — Perron Crown, real-variable forward chain (4 axioms)
5. **Cathedral v11** (1 day) — **The Mellin Crown** — frequency-domain forward chain (2 axioms)

---

## Experiment Index

The repository contains **27 Rust/MPFR experiment directories** under `experiments/`:

| Experiment | Purpose |
|-----------|---------|
| `mellin-certificate` | **Crown validator** — 256-bit Parseval bridge verification |
| `baez-duarte` | BD basis function analysis |
| `gram-matrix` | Gram matrix eigenvalue computation |
| `gram-oracle` | Certified Gram matrix bounds |
| `gram-quadform` | Quadratic form analysis |
| `gram-pointwise` | Pointwise Gram entry bounds |
| `gram-bilinear-abel` | Bilinear Abel summation |
| `l2-decay-certificate` | L² decay rate certification |
| `vasyunin` | Vasyunin formula numerics |
| `vasyunin-convergence` | Vasyunin convergence rates |
| `vasyunin-integral` | Vasyunin integral computation |
| `perron-contour` | Perron contour integration |
| `contour-oracle` | Contour integration bounds |
| `abel-bridge` | Abel summation bridge |
| `abel-tail-validator` | Abel tail bound validation |
| `pnt-mobius-sums` | Möbius sum asymptotics |
| `mobius-basis` | Möbius basis analysis |
| `millennium-wall` | Millennium wall bounds |
| `norm-bound-validator` | Norm bound validation |
| `spectral` | Spectral gap analysis |
| `spectral-analyzer` | Extended spectral analysis |
| `bc-witness-analysis` | Borel-Carathéodory witness |
| `bc-zeta-lower` | Zeta lower bound via B-C |
| `covariance-probe` | Covariance structure probing |
| `two-tile-analyzer` | Two-tile decomposition |
| `algebraic` | Algebraic structure exploration |
| `numerical` | General numerical experiments |
