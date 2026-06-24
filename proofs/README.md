# Cathedral — Lean 4 Proof Architecture

The formal verification core of the Cathedral project. A machine-checked
proof that the Riemann Hypothesis follows from a single axiom: the
Vasyunin Gram quadratic form bound vᵀGv ≤ 1.

## Quick Start

```bash
lake build    # Full Cathedral (8,849 theorems)
```

Requires Lean **v4.29.0** (pinned in `lean-toolchain`).

## The Claim

**`overcancellation_axiom → RiemannHypothesis`**

If the Vasyunin Gram quadratic form vᵀGv ≤ 1 for all sufficiently large N,
then the Riemann Hypothesis holds. This is proved with **0 sorry**.

### Verification (leanprover/comparator)

Two files for independent verification:

| File | Imports | Purpose |
|------|---------|---------|
| [`Challenge.lean`](Challenge.lean) | Mathlib only | States the theorem with `sorry` |
| [`Solution.lean`](Solution.lean) | Cathedral | Fills in the proof |

```bash
# Verify Challenge compiles (Mathlib only, expect 1 sorry warning):
lake env lean Challenge.lean

# Verify Solution compiles (0 sorry, 0 warnings):
lake env lean Solution.lean
```

### The Three Axioms

| # | Axiom | Content | Status |
|---|-------|---------|--------|
| 1 | `overcancellation_axiom` | vᵀGv ≤ 1 (The Wall) | **THE RH CONTENT** |
| 2 | `pnt_mu_log_sq_div_k` | Σ μ(k)·log²(k)/k → -2γ | PNT (unconditionally true) |
| 3 | `frac_error_isLittleO` | Fractional error = o(N) | PNT (unconditionally true) |

Axioms 2 and 3 are classical PNT consequences — they carry no RH content.
They are axioms in Lean only because their formalization is blocked on
upstream `PrimeNumberTheoremAnd` features.

The numerical certificate for Axiom 1: HPDF-validated for all N ≤ 55,440,
with margin vᵀGv ≤ 0.74 (26% below the threshold of 1).

## Architecture

```
Cathedral/
├── Defs.lean                              — Core definitions
├── Wall.lean                              — THE WALL: overcancellation_axiom
│
├── Assembly/              (20+ files)     — CROWN: Main proof chain
│   ├── OvercancellationChain.lean         — overcancellation_implies_rh (THE PROOF)
│   ├── MainChain.lean                     — nyman_beurling_equivalence
│   ├── OracleCascade.lean                 — Oracle Crown assembly
│   └── ...                                — Forward path assembly
│
├── NymanBeurling/         (10 files)      — Nyman-Beurling criterion
│   ├── BDMellin.lean                      — Rank-1 Mellin identity (680 lines)
│   ├── Separation.lean                    — Converse: d²→0 ⟹ RH (0 axioms!)
│   └── ...                                — BD basis, bridges, witnesses
│
├── Vasyunin/              (52 files)      — Matrix, witness, Cotangent tower
│   ├── Defs.lean                          — Gram entry, mean vector (Vasyunin formula)
│   ├── Witness.lean                       — Log-cutoff Möbius witness
│   ├── Proof/                             — Witness decay chain
│   ├── Cotangent/                         — Piecewise FTC engine (0 sorry)
│   └── Matrix/                            — Gram matrix properties
│
├── PNT/                   (4 files)       — PNT bridge (PrimeNumberTheoremAnd)
│   ├── LogBridge.lean                     — Σ μ(k)·log(k)/k → -1 (PROVED)
│   ├── AbelMean.lean                      — Abel tail + PNT theorems
│   └── ...                                — PNTAnd bridge
│
├── Geometry/              (30+ files)     — Overcancellation geometry
├── Physics/               (30+ files)     — SUSY decomposition, gauge theory
├── Covariance/            (20+ files)     — Möbius stratum analysis
├── MellinBridge/          (18 files)      — Mellin transform infrastructure
├── Perron/                (16 files)      — Perron formula (0 sorry!)
├── Analysis/              (16 files)      — Real/complex analysis
├── AbelTail/              (14 files)      — Abel summation infrastructure
├── Zeta/                  (10+ files)     — Zeta function properties
├── Spectral/              (11 files)      — Eigenvalue analysis
├── LinearAlgebra/         (4 files)       — SM, Schur, Sylvester (0 axioms)
├── Sieve/                 (4 files)       — Bilinear sieve + Möbius
│
└── Archive/               (113+ files)    — Preserved explorations
```

## The Proof Chain

```
overcancellation_axiom (Wall.lean)
  │  vᵀGv ≤ 1 for sufficiently large N
  │
  ▼
d² = (vᵀGv - 1) + 2(1 - bᵀv)    (algebraic identity)
  │  overcancellation: first term ≤ 0
  │  PNT: second term → 0
  │
  ▼
d² → 0    (Nyman-Beurling distance)
  │
  ▼
RiemannHypothesis    (Mathlib definition, via nyman_beurling_converse)
```

## Key Zero-Sorry Achievements

- **Converse direction** (d²→0 ⟹ RH) — zero axioms, zero sorry
- **Overcancellation chain** (vᵀGv ≤ 1 → RH) — zero sorry
- **Perron summation formula** — 16 files, zero sorry
- **Linear algebra** (Sherman-Morrison, Schur, Sylvester) — zero axioms
- **GCD stratum** (sign law, partition, bounds) — zero sorry
- **Vasyunin cotangent tower** — zero sorry
- **PNT graduation** (6 axioms → theorems via PrimeNumberTheoremAnd)

## Dependencies

- **Lean 4** v4.29.0
- **Mathlib** (measure theory, complex analysis, number theory, linear algebra)
- **PrimeNumberTheoremAnd** v4.29.0 (PNT, Mertens, von Mangoldt)

## Stats

| Metric | Count |
|---|---|
| Active Lean files | **505** |
| Archived Lean files | **117** |
| Theorem/lemma declarations | **~5,000** |
| Compilation errors | **0** |
| Crown path sorry | **0** |
| Custom axioms (crown) | **3** (1 Wall + 2 PNT) |
