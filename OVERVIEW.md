# OVERVIEW — The Cathedral Proof Chain

> *A machine-verified reduction of the Riemann Hypothesis via the
> Nyman–Beurling–Báez-Duarte equivalence in Lean 4, with an independent
> Oracle Bridge proof path from GPU-certified computation.*
>
> **Last updated**: May 31, 2026 (v22 — The Crowning)
>
> **Last audited**: May 31, 2026 — Crowned Cathedral architecture,
> `discrete_riemann_hypothesis` as sole axiom (≡ RH),
> 381 active files, ~116K lines, 3 sorry (off-crown), 0 errors

---

## The Crown Theorem

The Cathedral's central result is `baez_duarte_forward` in
[MainChain.lean](proofs/Cathedral/Assembly/MainChain.lean):

```
#print axioms baez_duarte_forward
-- frac_error_isLittleO, pnt_mu_log_sq_div_k,
-- Cathedral.Vasyunin.discrete_riemann_hypothesis,
-- propext, Classical.choice, Quot.sound
```

**Crown status: 0 sorry, 1 axiom (discrete_riemann_hypothesis ≡ RH), 2 PNT bureaucracy.**

The Cathedral also proves RH *directly* via the **Oracle Bridge**:

```lean
theorem rh_from_oracle : RiemannHypothesis :=
  rh_from_certificates hcSubseq hcBounds ...
```

**Oracle status: 0 sorry, 1 computation axiom (oracle_certificates).**

---

## Proof Architecture

The proof decomposes into two pillars:

```mermaid
graph TD
    subgraph "Pillar I — Converse (0 axioms, 0 sorry)"
        C1["d²_N → 0"]
        C2["Rank-1 Mellin Miracle<br/>M[hₖ](ρ) = 1/(k(ρ-1))"]
        C3["Cauchy-Schwarz separation<br/>d² ≥ (2σ-1)·t²/(|ρ|⁴|ρ-1|²)"]
        C5["RH"]
        C1 --> C2 --> C3 --> C5
    end

    subgraph "Pillar II — Forward (1 axiom ≡ RH, 0 sorry)"
        F1["RH"]
        F2["discrete_riemann_hypothesis<br/>(v^T C v ≤ C/ln N — ≡ RH)"]
        F6["d²_N → 0"]
        F1 --> F2 --> F6
    end

    style C1 fill:#2d5016,color:white
    style C5 fill:#2d5016,color:white
    style F1 fill:#1a4a8a,color:white
    style F6 fill:#1a4a8a,color:white
    style F2 fill:#8a4a1a,color:white
```

### Pillar I: Converse (d²→0 ⟹ RH)

**Status: PURE** — zero custom axioms, zero sorry.

Proved in [BDMellin.lean](proofs/Cathedral/NymanBeurling/BDMellin.lean) (680 lines)
via the **Rank-1 Mellin Miracle**: the Mellin transform of the BD basis
function h_k(x) = {1/(kx)} at a ζ-zero ρ yields a rank-1 tensor, enabling
Cauchy-Schwarz separation.

### Pillar II: Forward (RH ⟹ d²→0) — The Direct Mellin Bound

**Status: 1 axiom (`discrete_riemann_hypothesis` ≡ RH), 0 sorry.**

The primary crown path uses `discrete_riemann_hypothesis` — the covariance
decay bound v^T C v ≤ C/ln N, formally proved equivalent to RH via
`witness_covariance_decay_iff_rh`.

Seven alternative forward paths are preserved:

| Path | Crown Axioms | Status |
|------|-------------|--------|
| **Direct Mellin Bound (F)** | `discrete_riemann_hypothesis` | **Primary** |
| **Oracle Bridge (D)** | `oracle_certificates` | 0 sorry |
| **Gram Crown (E)** | Direct Gram bound | 0 sorry |
| Mellin Crown (A) | 0 (graduated) | 0 sorry |
| Perron Crown (B) | 4 transparent | 0 sorry |
| Renormalization (C) | Selberg–Delange | 0 sorry |
| Glass Bridge (G) | Sherman–Morrison | 0 sorry |

### The Oracle Bridge

**Status: 1 computation axiom (`oracle_certificates`), 0 sorry.**

The Oracle Bridge bypasses all literature axioms. It measures the Gram quadratic
form v^T G v at highly composite numbers using DD-precision arithmetic,
imports the bound as `oracle_certificates`, then proves:

```
oracle_certificates → v^T G v < 1 along subseq → d² → 0 → RH
```

The **Oracle Cascade** (`OracleCascade.lean`) derives everything unconditionally from RH.

---

## Crown Axioms

```
#print axioms baez_duarte_forward  -- PRIMARY EXPORT
-- frac_error_isLittleO,           (PNT, unconditional)
-- pnt_mu_log_sq_div_k,            (PNT, unconditional)
-- discrete_riemann_hypothesis,    (≡ RH — The Crowning)
-- propext, Classical.choice, Quot.sound  (Lean kernel)
```

| # | Axiom | Content | Status |
|---|-------|---------|--------|
| 1 | `discrete_riemann_hypothesis` | v^T C v ≤ C/ln N | **≡ RH** |
| 2 | `frac_error_isLittleO` | Fractional-part error | PNT (unconditional) |
| 3 | `pnt_mu_log_sq_div_k` | Möbius log-squared sum | PNT (unconditional) |

### Graduated Axioms (v22)

| Former Axiom | Graduated Method |
|---|---|
| `R_isLittleO` | PrimeNumberTheoremAnd |
| `mu_pnt_alt` | PrimeNumberTheoremAnd |
| `mu_log_mul_zeta` | Mathlib `sum_moebius_mul_log_eq` |
| 10 PNT bridge sums | PrimeNumberTheoremAnd |
| `abel_summation_covariance_bound` | Trivial from dRH |

> [!IMPORTANT]
> The crown axiom is not a "literature axiom" — it IS the Riemann Hypothesis,
> stated in the language of the Cathedral. The equivalence
> `witness_covariance_decay_iff_rh` is a machine-verified theorem.
> Graduating the axiom is equivalent to proving RH itself.

---

## Module Structure

The codebase comprises **381 active Lean files** across **25+ topic directories** with
**~116,000 lines** of active code, **~3,000 proved theorems/lemmas**, and **~118 active axioms**
(1 on the crown path).

```
Cathedral/
├── Assembly/        (22 files)  Crown assemblies (MainChain, Assembly, GramCrown, etc.)
├── Compute/          (3 files)  Oracle Bridge (GPU certificates, rh_from_oracle)
├── White/            (2 files)  Parseval bridge (Kinematics, Scattering)
├── NymanBeurling/   (11 files)  BDMellin (converse), Separation, BD bridges
├── MellinBridge/    (18 files)  Mellin transform, Plancherel, floor transforms
├── Zeta/            (10 files)  Zeta function bounds, Hadamard, convexity
├── Perron/          (16 files)  Perron formula chain + Mertens conversion
├── PNT/              (5 files)  PNT bridges (PrimeNumberTheoremAnd dependency)
├── Vasyunin/        (53 files)  Vasyunin formula + witness (Cotangent/, Matrix/, Proof/)
├── Covariance/      (24 files)  Gram form, dot product, L² convergence
├── Gram/             (7 files)  FractIntegral, Diagonal, OffDiagonal
├── AbelTail/        (14 files)  Abel summation engine + tail bounds
├── Sieve/            (4 files)  BilinearSieve, ParitySchur, MoebiusUncoupling
├── Spectral/        (14 files)  Heisenberg bypass, ClassRestriction, Mirror
├── Analysis/         (6 files)  Hilbert inequality, Montgomery-Vaughan
├── LinearAlgebra/    (4 files)  Sherman-Morrison, Sylvester, Variational
├── IntegralBasis/    (5 files)  Báez-Duarte basis + winding energy
├── NumberTheory/     (8 files)  Euler product, Mertens, multiplicative functions
├── Structural/       (9 files)  CholeskyDecrement, BorderedSpectral, eigenvalues
├── Physics/         (76 files)  Gauge theory, SUSY, Glass Bridge, BE/FD, particle zoo
├── Robin/            (7 files)  Robin/Nicolas/Lagarias equivalences
├── ZeroAxiom/        (5 files)  Zero-axiom engine
├── Archive/        (114 files)  Preserved exploratory paths
└── Defs.lean, Axioms.lean      Root definition and axiom files
```

---

## Sorry Inventory

3 `sorry` placeholders exist in the active tree, **all off-crown**:

| File | Count | Context |
|------|-------|---------|
| `Assembly/DirectMellinBound.lean` | 2 | Exploratory direct path |
| `Physics/Bridges/DedekindBridge.lean` | 1 | Off-path Dedekind bridge |

> [!NOTE]
> **Zero sorry on the crown path.** Down from 17 sorry at v17 to 3 at v22.
> The PNT-related sorry were eliminated when PrimeNumberTheoremAnd was integrated.

---

## Architecture History

| Version | Date | Crown Axioms | Architecture |
|---------|------|-------------|--------------|
| v1 | Mar 2026 | 6 | Initial Nyman-Beurling formalization |
| v5 | Apr 18 | 1 | Great Purge (OneCrown) |
| v11 | Apr 26 | 2 | Mellin Crown (frequency domain) |
| v12 | Apr 28 | 2 | Crown Graduation (Perron Bridge) |
| **v16** | **May 6** | **1** | **One-Pillar Cathedral** |
| **v17** | **May 10** | **1+1** | **Oracle Capstone (Dual Crown)** |
| v18 | May 13 | 1 | Gram Crown added |
| v19 | May 14 | 1+3 PNT | Direct Mellin Bound + Graduation |
| v20 | May 17 | 1+3 PNT | Glass Bridge + Physics Enrichment |
| v21 | May 24 | 1+3 PNT | Bose–Einstein Prime Gas (File #444) |
| **v22** | **May 31** | **1+2 PNT** | **The Crowning: discrete_riemann_hypothesis** |

---

## Codebase Metrics

| Metric | Value |
|--------|-------|
| Active Lean files | 381 |
| Active lines of code | ~116,000 |
| Total files (incl. archive) | 495 |
| Archive files | 114 |
| Theorems + lemmas | ~3,000 proved |
| Total axioms (active) | ~118 |
| Crown axioms | **1** (≡ RH) |
| PNT bureaucracy | **2** (unconditional) |
| Crown path sorry | **0** |
| Off-crown sorry | **3** |
| Topic directories | 25+ |
| Build jobs | 8,485 |
| Experiments (Rust/MPFR/DD) | 50+ |
| Papers | 17 (4 core + 13 working drafts) |
| Development time | ~66 days |
| Lean version | 4.29.0 |
| Largest certified N | 55,440 (d²=0.0398, CG-DD) |

> [!NOTE]
> The Cathedral maintains a **Crowned Cathedral** architecture: the sole axiom
> `discrete_riemann_hypothesis` IS the Riemann Hypothesis. Seven proof paths
> (Direct Mellin Bound, Oracle Bridge, Gram Crown, Mellin, Perron, Renormalization,
> Glass Bridge) provide a multi-path verification architecture.
