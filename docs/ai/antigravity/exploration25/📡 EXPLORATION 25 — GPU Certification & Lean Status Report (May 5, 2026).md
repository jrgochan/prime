# 📡 EXPLORATION 25 — GPU Certification & Lean Status Report

**Date:** May 5, 2026 (00:55 MDT)  
**Author:** Claude Actual (Antigravity)  
**Branch:** `exploration25`

---

## Part I — Two-Tile Decomposition GPU Certifier v2

### 🏛️ Executive Summary

The complete CPU experiment certification suite has been ported to a GPU-accelerated Rust/CUDA hybrid tool. All 10 certification sections pass across **30,387,486 coprime pairs** (B=10,000) on the RTX 4090.

### Modules Ported (7 new source files)

| Module | Section | Purpose | Status |
|--------|---------|---------|--------|
| `compute.rs` | — | f64 row integrals, strip, delta, Vasyunin formula | ✅ |
| `delta_formula.rs` | §1 | Δ(m) closed-form vs FTC verification | ✅ |
| `class_eval.rs` | §2 | Per-class delta sum aggregation | ✅ |
| `honest_algebra.rs` | §3 | 3-piece decomposition (P1/P2/P3) | ✅ |
| `gram_crossref.rs` | §4 | FTC vs cathedral-utils gram series | ✅ |
| `rosetta_stone.rs` | §5 | gramEntry ↔ gramIntegral bridge + Phantom Axiom | ✅ |
| `graduation.rs` | §6-§10 | Full axiom graduation (ex cpu.rs) | ✅ |

**Coverage assessment:** Only `actual_eval.rs` (subsumed by §2) and `analysis.rs` (just a struct + print) were not ported — both are redundant with existing modules.

### GPU Results (RTX 4090, NVIDIA GeForce RTX 4090)

| B_max | Coprime Pairs | GPU Time | Rate | Status |
|-------|--------------|----------|------|--------|
| 20 | 108 | 0.42s | — | ✅ ALL CERTIFIED |
| 100 | 2,944 | 0.8s | — | ✅ ALL CERTIFIED |
| 1,000 | 303,192 | **1.1s** | 267K pairs/sec | ✅ ALL CERTIFIED |
| 5,000 | 7,595,458 | **100s** | 76K pairs/sec | ✅ ALL CERTIFIED |
| **10,000** | **30,387,486** | **13 min** | 38K pairs/sec | ✅ **ALL CERTIFIED** |

### Error Stability Across Scale

The graduation identity error remains rock-solid even at B=10,000:

| B_max | §7 Gauss logΓ | §7 Gauss ψ | §8 Telescope logΓ | §8 Telescope ψ | §9 Beta Duality | §10 Graduation |
|-------|---------------|------------|-------------------|---------------|-----------------|----------------|
| 20 | 3.55e-15 | 2.13e-13 | 3.55e-15 | 2.13e-14 | 5.55e-17 | 2.61e-15 |
| 1,000 | 2.27e-13 | 1.09e-11 | 2.27e-13 | 2.73e-12 | 6.05e-17 | 4.64e-14 |
| 5,000 | 1.82e-12 | 6.55e-11 | 1.82e-12 | 2.18e-11 | 6.05e-17 | 2.19e-13 |
| **10,000** | **3.64e-12** | **1.31e-10** | **5.46e-12** | **4.37e-11** | **6.05e-17** | **4.43e-13** |

**Key observation:** Beta duality is exact to machine epsilon (6e-17) because it's a pure integer identity. The graduation identity stays at ~1e-13, well within tolerance. The slow growth in Gauss/telescope errors is expected accumulation at f64 precision — this is exactly where DD arithmetic (31 digits) would help.

### DD Precision Extension

Extended `cathedral-utils::dd` with full transcendental library:
- `ln()` via argument reduction + 2·atanh series
- `lgamma()` via Stirling + recurrence (shift to x≥20)
- `digamma()` via asymptotic + recurrence (7 Bernoulli terms)
- `sin/cos/cot()` via Taylor with 2π reduction
- `floor/frac()` exact DD arithmetic
- `PartialEq/PartialOrd` for comparisons

**Precision ladder:** f64 (15 digits) → DD (31 digits) → MPFR (300 digits)

DD uses only pairs of f64s + FMA, so it works on CUDA natively. Next step: wire `--dd` CLI flag into the graduation engine.

### Architecture

```
two-tile-decomposition-gpu/
├── src/
│   ├── main.rs              # v2 driver: 10-section suite + CLI
│   ├── gpu.rs                # CUDA FFI + PairResult (22 fields)
│   ├── compute.rs            # f64 math building blocks
│   ├── delta_formula.rs      # §1: Δ(m) closed-form
│   ├── class_eval.rs         # §2: per-class evaluation
│   ├── honest_algebra.rs     # §3: 3-piece decomposition
│   ├── gram_crossref.rs      # §4: FTC vs series cross-ref
│   ├── rosetta_stone.rs      # §5: gramEntry ↔ gramIntegral bridge
│   └── graduation.rs         # §6-§10: axiom graduation
├── cuda/skeleton_keys.cu     # RTX 4090 kernel (block-per-pair)
└── results/
    ├── full_cert_B{N}.json   # Machine-readable certificates
    └── full_cert_B{N}.tsv    # Per-pair data
```

---

## Part II — Lean 4 Cathedral Status

### Current Architecture (v17, May 5, 2026)

**203 active Lean files, 53,764 lines** (excluding Archive/)

### Crown Path Axioms

The Nyman-Beurling equivalence `nyman_beurling_equivalence` depends on:

| # | Axiom | Role | Graduation Status |
|---|-------|------|-------------------|
| 1 | `covariance_bound_from_mertens_34` | Abel summation bound | Perron path (standard ANT) |
| 2 | `pnt_mu_div_k` | PNT: Σ μ(k)/k → 0 | Standard PNT result |
| 3 | `pnt_mu_log_div_k` | PNT: Σ μ(k)ln(k)/k → -1 | Standard PNT result |
| 4 | `sorryAx` | Hardy-Littlewood Mellin variance | **THE WALL** (beyond Mathlib v4.29) |
| 5-7 | `propext`, `Classical.choice`, `Quot.sound` | Lean kernel | Standard |

### The Converse Direction: PURE ✅

`nyman_beurling_converse` — **zero custom axioms**. Proved via the Rank-1 Mellin Miracle.

### Recent Graduations (Exploration 25)

| Axiom | Date | Method |
|-------|------|--------|
| `rh_zeta_lower_bound_from_zero_counting` | May 5 | Littlewood Maneuver (1,094 lines, 0 sorry) |

### Active sorry Count

| Location | sorry | Status |
|----------|-------|--------|
| `DeltaDirectEval.lean:798` | `staircase_telescope` | Gemini Key 1 — needs proof |
| `DeltaDirectEval.lean:838` | `beta_modulo_duality` | Gemini Key 2 — needs proof |
| `DeltaDirectEval.lean:898` | `sum_perClass_eq_deltaTarget_algebraic` | Assembly — depends on Keys 1 & 2 |
| `ColumnSumEval.lean:107` | `four_way_eq_formula` | **SUPERSEDED** by DeltaDirectEval |
| `AlgebraicLimit.lean:57` | `gramIntegral_eq_formula_ge2` | Cycle-breaking axiom (proved downstream) |

**The critical path:** The 3 sorry values in `DeltaDirectEval.lean` are the frontier. Once `staircase_telescope` and `beta_modulo_duality` are proved as Lean theorems, the `sum_perClass_eq_deltaTarget_algebraic` assembly follows, which graduates `four_way_eq_formula`, which graduates `gramIntegral_eq_formula_ge2`, completing the Vasyunin identity proof chain.

### Total Non-Archive Axioms: 55

Most are in:
- Spectral path (ClassRestriction, PTSymmetry, etc.) — separate proof tower
- SpectralObservatory oracle axioms — numerical certificates
- Sieve machinery (Vaughan, BilinearSieve) — standard ANT
- MellinBridge (Autocorrelation, MertensWeight) — Perron formalization

---

## Part III — Branch Decision

### Recommendation: **Finish the DeltaDirectEval sorry values, then branch.**

Rationale:
1. **We're 2 lemmas away** from completing the Vasyunin identity proof chain (`staircase_telescope` and `beta_modulo_duality`). These are the Gemini Keys, now verified to 30.4M pairs on GPU.

2. **Natural branch boundary:** Once `gramIntegral_eq_formula_ge2` graduates from axiom → theorem, that's a clean architectural milestone. The exploration25 branch would then contain:
   - Complete GPU certification suite (10 sections, 30M pairs)
   - Littlewood Maneuver graduation
   - Vasyunin identity graduation (if we close the sorry values)
   - DD precision infrastructure

3. **Scope risk:** Adding more features to exploration25 risks merge conflicts. The branch already has substantial changes across experiments + proofs.

### Concrete Next Steps (before branching)

1. **Prove `staircase_telescope`** in DeltaDirectEval.lean — this is a finite sum identity over Finsets, should be tractable with `Finset.sum_bij` and telescoping.

2. **Prove `beta_modulo_duality`** — an integer congruence identity, provable via `Int.emod` arithmetic.

3. **Assemble `sum_perClass_eq_deltaTarget_algebraic`** — wiring the pieces together with `linarith`/`ring`.

4. **Graduate `gramIntegral_eq_formula_ge2`** from axiom → theorem.

5. **Branch to exploration26** with the Vasyunin identity fully certified in both Lean and GPU.

---

*Filed by Claude Actual, Antigravity Division*  
*For the Cathedral. For the proof. For all of us. 🏛️*
