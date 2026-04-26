# ARCHIVE — Cathedral Proof Archive Audit

> *A comprehensive inventory of archived Lean 4 files across three archive
> locations, documenting what was proved, what was superseded, and what
> remains valuable for future work.*
>
> **Last updated**: April 26, 2026 (v11 — The Mellin Crown)

---

## Archive Overview

The Cathedral maintains three archive locations containing **127 files**
and **29,698 lines** of Lean 4 code:

| Location | Files | Lines | Purpose |
|----------|-------|-------|---------|
| `archive/proved/` | 17 | 1,017 | Early "Lemma Ladder" explorations |
| `archive/SpectralRH/` | 17 | 6,423 | Pre-Cathedral spectral proof attempt |
| `Cathedral/Archive/` | 93 | 22,258 | Superseded Cathedral modules |
| **Total** | **127** | **29,698** | |

For comparison, the active codebase is **161 files / 39,375 lines**.

### Architecture Context (v11)

The Cathedral's crown path now uses the **Mellin Crown** (2 axioms, 0 sorry).
This means the entire real-variable forward chain (Perron → Mertens → Gram → L²)
is **off the crown path**. The following archived components are therefore doubly
superseded — first by the Perron Crown (v7), then by the Mellin Crown (v11):

- `DirectL2Crown.lean` — superseded by MellinCrown
- `OneCrown.lean` — superseded by MellinCrown
- `PerronCrown.lean` — still live (alternative path) but not on crown

---

## 1. `archive/proved/` — The Lemma Ladder

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

### Axiom-Ladder Results (30–41 axioms each)

These prove RH conditional on 41 axioms via the Li coefficient ladder.

> [!WARNING]
> The "Proved_riemann_hypothesis" files do **not** constitute a proof of RH.
> They prove RH conditional on 41 axioms. The Cathedral's current approach
> via the Mellin Crown has only **2 axioms**.

---

## 2. `archive/SpectralRH/` — The Pre-Cathedral Spectral Proof

**Origin**: April 1–7, 2026 — The original `rh-spectral` project.

The Cathedral absorbed ~80% of this code:
- `Defs.lean` → `Cathedral/Defs.lean`
- `Structural.lean` → `Cathedral/Structural/*.lean`
- `RayleighBridge.lean` → `Cathedral/Spectral/RayleighBridge.lean`
- `BilinearSieve.lean` → `Cathedral/Sieve/BilinearSieve.lean`
- `ParitySchur.lean` → `Cathedral/Sieve/ParitySchur.lean`

---

## 3. `Cathedral/Archive/` — Superseded Cathedral Modules

**93 files** remaining after the April 26 resurrection.

### 3a. `HighFrequencyTrap/` — "Universe 2" Snapshot (~46 files)

Complete frozen snapshot before the Perron chain and Vasyunin Bypass refactors.
Uses the old NB basis {k/x} instead of the BD basis {1/(kx)}.

### 3b. `DiscreteMirage/` — Cotangent Formula Dead End (10 files)

Early piecewise-FTC approach to the off-diagonal Vasyunin identity.

> [!TIP]
> `CrossTermFTC.lean` and `OffDiagPartition.lean` contain proved infrastructure
> useful for graduating the `partial_integral_tends_to_formula` axiom (which is
> now off-crown but still valuable for the Spectral Engine).

### 3c. `Robin/` — The Arithmetic Path (6 files, all sorry)

Alternative RH equivalence via Robin's inequality. Skeleton only.

### 3d. `NymanBeurling/` — Superseded Separation Proofs (3 files)

Superseded by the Rank-1 Mellin Miracle in `BDMellin.lean`.

### 3e. `MellinBridge/` — Contour Shift Exploration (3 files)

Early contour integration, later rebuilt as the 13-file Perron chain.

### 3f. `Vasyunin/` — Superseded Components (4 files remaining)

After resurrection of GramPSD and BartlettWindow:
- `Vasyunin.lean` (18L) — Old import hub
- `Augmented/NbDistPos2.lean` (121L) — d² < 1 for N=2 (**Proved**)
- `Augmented/NbDistPos3.lean` (174L) — d² < 1 for N=3 (**Proved**)
- `Cotangent/*` (10 files) — Duplicate of DiscreteMirage/

> [!NOTE]
> `NbDistPos2` and `NbDistPos3` are fully proved (0 axiom, 0 sorry) base cases.

### 3g. `White/` — Early Perron Infrastructure (6 files)

Old versions of now-live `Perron/` and `Zeta/` files. `PerronKernel.lean`
(928 lines) is the most substantial.

### 3h. `FinalDragon.lean` — Dead Re-export Facade

Archived April 26. The monolith was decomposed into MertensConversion,
AbelMean, MillenniumWall, and L2Convergence. Nothing imports it.

### 3i. Other Items

| File | Content | Status |
|------|---------|--------|
| `Universe1/GramWitness.lean` | NB basis {k/x} forward path | 1 axiom |
| `Spectral/ConstantVectorBound.lean` | Constant vector spectral bound | **Proved** |
| `Sieve/AlignmentDecay.lean` | Cross-term decay | 1 axiom |
| `Sieve/ParityBridge.lean` | Parity sieve bridge | 1 axiom |
| `Scratch/*` (8 files) | Exploratory scratch work | Mixed |

---

## Superseded Live Files (Not Yet Archived)

The following files are still in the active tree but no longer on the crown path
since v11. They remain as alternative proof routes and supporting infrastructure:

| File | Role in v10 | Status in v11 |
|------|-------------|---------------|
| `Assembly/PerronCrown.lean` | Primary forward path | Off-crown (alternative) |
| `Assembly/DirectL2Crown.lean` | Direct L² path | Off-crown (alternative) |
| `Assembly/OneCrown.lean` | One-axiom crown | Off-crown (alternative) |
| `PNT/AbelMean.lean` | Crown axiom (PNT) | Off-crown |
| `Covariance/GramFormProof.lean` | Crown axiom (covariance) | Off-crown |
| `Vasyunin/Cotangent/ConvergenceAxioms.lean` | Crown axiom (Vasyunin) | Off-crown |

> [!NOTE]
> These files are candidates for archival once the Mellin Crown is considered
> the permanent architecture. They're kept live for now because they provide
> alternative proof routes and contain substantial proved infrastructure.

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
| `ConstantVectorBound.lean` (747L) | Alternative spectral bound (fully proved) |
| `Robin/` (6 files) | Independent RH equivalence (skeleton) |
| `Vasyunin/Augmented/NbDistPos{2,3}.lean` | Certified base cases |

---

## Statistics

```
Total archive files:          127
Total archive lines:       29,698
Fully proved (0 axiom, 0 sorry): ~33 files
With sorry:                   ~18 files
With axioms only (no sorry):  ~50 files
Pure duplicates/stubs:        ~26 files
```

### Archive vs Active Codebase

| Metric | Active | Archive | Ratio |
|--------|--------|---------|-------|
| Files | 161 | 127 | 1.27× |
| Lines | 39,375 | 29,698 | 1.33× |
| Theorems | ~800 | ~400 | 2.0× |
| Crown axioms | **2** | — | — |

---

## Relationship to Proof History

```mermaid
graph LR
    A["archive/proved/<br/>Lemma Ladder<br/>(Mar 28)"] --> B["archive/SpectralRH/<br/>Spectral Proof v1<br/>(Apr 1-7)"]
    B --> C["Cathedral v1-v6<br/>HighFrequencyTrap era<br/>(Apr 7-20)"]
    C --> D["Cathedral v7-v9<br/>Perron Crown<br/>(Apr 20-24)"]
    D --> E["Cathedral v10<br/>Gram Form grad<br/>(Apr 25)"]
    E --> F["Cathedral v11<br/>THE MELLIN CROWN<br/>(Apr 26)"]

    C -.--->|"archived"| G["Cathedral/Archive/<br/>HighFrequencyTrap/"]
    B -.--->|"archived"| H["archive/SpectralRH/"]

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
