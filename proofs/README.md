# Cathedral — Lean 4 Proof Architecture

The formal verification core of the Cathedral project. A machine-checked
reduction of the Riemann Hypothesis to the decay of the Nyman–Beurling distance.

## Build

```bash
lake build    # 227 active files, 112 archived
```

Requires Lean **v4.29.0** (pinned in `lean-toolchain`).

## Architecture (Oracle Capstone — May 11, 2026)

**Dual Crown.** Two independent formal proofs:

1. **Analytic Crown** — 1 literature axiom (`baez_duarte_forward`, Báez-Duarte 2003)
2. **Oracle Crown** — 1 computation axiom (`oracle_certificates`, GPU-verified)

The **converse direction** (d²→0 ⟹ RH) is fully machine-checked with
**zero custom axioms and zero sorry**.

```
Cathedral/
├── Defs.lean                              — Core definitions
│
├── Assembly/              (13 files)      — CROWN: Main proof chain
│   ├── MainChain.lean                     — nyman_beurling_equivalence (THE CROWN)
│   ├── OracleCascade.lean                 — Oracle Crown assembly
│   ├── SpectralObservatory.lean           — GPU distance certificates
│   ├── CertifiedComputation.lean          — Certified computation bridge
│   └── ...                                — Forward path assembly
│
├── NymanBeurling/         (10 files)      — Nyman-Beurling criterion
│   ├── BDMellin.lean                      — Rank-1 Mellin identity (680 lines)
│   ├── Separation.lean                    — Converse: d²→0 ⟹ RH (0 axioms!)
│   └── ...                                — BD basis, bridges, witnesses
│
├── Vasyunin/              (52 files)      — Matrix, witness, Cotangent tower
│   ├── Proof/                             — Witness decay chain
│   ├── Cotangent/                         — Piecewise FTC engine (0 sorry)
│   ├── Matrix/                            — Gram matrix properties
│   └── Augmented/                         — Factorial Nuke + Rayleigh
│
├── MellinBridge/          (18 files)      — Mellin transform infrastructure
│   ├── PlancherelDefs.lean                — Parseval Bridge (core)
│   └── ...                                — Abel, Mertens, orthogonal witness
│
├── Covariance/            (20 files)      — Möbius stratum analysis
│   ├── GCDSignLaw.lean                    — GCD sign law (0 sorry ★)
│   ├── GCDStratumBound.lean               — Per-stratum bounds (0 sorry ★)
│   ├── GCDPartition.lean                  — GCD partition (0 sorry ★)
│   └── MillenniumWall.lean                — Gram form ↔ RH equivalence
│
├── Perron/                (16 files)      — Perron formula (0 sorry!)
│   ├── Formula.lean                       — Perron summation formula
│   ├── Rectangle.lean                     — Rectangle contour estimates
│   └── ...                                — Kernel, residue, assembly
│
├── Analysis/              (16 files)      — Real/complex analysis
│   ├── StirlingBridge.lean                — Stirling approximation
│   ├── GallagherMVT.lean                  — Gallagher mean value theorem
│   ├── PiecewiseFTC.lean                  — Piecewise FTC engine
│   └── ...                                — Gamma, Abel, Hilbert
│
├── AbelTail/              (14 files)      — Abel summation infrastructure
├── Zeta/                  (10 files)      — Zeta function properties
├── Spectral/              (11 files)      — Eigenvalue analysis
├── Robin/                 (7 files)       — Robin/Nicolas/Lagarias
├── Gram/                  (6 files)       — L² integral bridge
├── LinearAlgebra/         (4 files)       — SM, Schur, Sylvester, Variational (0 axioms)
├── Structural/            (4 files)       — Eigenvalue interlacing
├── Sieve/                 (4 files)       — Bilinear sieve + Möbius
├── PNT/                   (4 files)       — PNT bridge (PNTA dependency)
├── Physics/               (3 files)       — SUSY, Dirac, Woodbury condensate
├── Renormalization/       (3 files)       — RG flow formalization
├── ZeroAxiom/             (3 files)       — Zero-counting infrastructure
├── Compute/               (2 files)       — Oracle certificates
├── IntegralBasis/         (2 files)       — BD/NB integral basis
├── White/                 (2 files)       — Axiom elimination proofs
├── NumberTheory/          (1 file)        — Dirichlet convolution
├── Rotors/                (1 file)        — Octonionic rotors
│
└── Archive/               (113 files)     — Preserved explorations
    ├── Scratch/                           — 19 prototyping workbenches
    ├── HighFrequencyTrap/                 — {k/x} basis (computationally correct, wrong basis)
    ├── DiscreteMirage/                    — Cotangent decomposition (false reciprocity)
    └── ...                                — NymanBeurling, Robin, Spectral, Sieve, etc.
```

## Stats

| Metric | Count |
|---|---|
| Active Lean files | **227** |
| Archived Lean files | **113** |
| Active modules | **24** |
| Total lines (active) | **~60,500** |
| Total custom axioms | **82** |
| Crown axioms (analytic) | **1** (`baez_duarte_forward`) |
| Crown axioms (oracle) | **1** (`oracle_certificates`) |
| Off-path axioms | ~80 |
| Files with sorry | **8** (0 on crown path) |
| Total sorry instances | **17** (all off-crown) |
| Compilation errors | **0** |

## The Crown Axiom

Verified by `#print axioms nyman_beurling_equivalence`:

```
[baez_duarte_forward, propext, Classical.choice, Quot.sound]
```

| # | Axiom | Content |
|---|-------|---------|
| 1 | `baez_duarte_forward` | RH ⟹ ∀ε>0, ∃N₀, ∀N≥N₀, ∃v: d²_N < ε (Báez-Duarte, 2003) |

Plus Lean kernel axioms: `propext`, `Classical.choice`, `Quot.sound`.

The ~80 remaining axioms support alternative proof paths (Oracle Crown,
Mellin Crown, Perron Crown, spectral engine, sieve engine, Vasyunin tower)
that are formalized but not on the shortest path to the crown theorem.

## Key Zero-Sorry Achievements

- **Converse direction** (d²→0 ⟹ RH) — zero axioms, zero sorry
- **Perron summation formula** — 16 files, zero sorry
- **Linear algebra** (Sherman-Morrison, Schur, Sylvester, Variational) — zero axioms
- **GCD stratum** (sign law, partition, bounds) — zero sorry
- **Gallagher MVT** — zero sorry
- **Stirling bridge** — zero sorry
- **Piecewise FTC engine** — zero sorry

## Dependencies

- **Lean 4** v4.29.0
- **Mathlib** (measure theory, complex analysis, number theory, linear algebra)
- **PrimeNumberTheoremAnd** (PNT, Mertens' theorems, von Mangoldt functions)
