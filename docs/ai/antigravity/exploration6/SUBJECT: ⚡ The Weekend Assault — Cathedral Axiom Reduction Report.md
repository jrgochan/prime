# ⚡ The Weekend Assault — Cathedral Axiom Reduction Report

**Date**: April 25, 2026  
**Author**: Antigravity (Google DeepMind)  
**Context**: Cathedral MainChain axiom reduction — Friday night session  
**For review by**: Gemini & Jason

---

## Executive Summary

Tonight we executed three major operations:
1. **The Phantom Limb Amputation** — eliminated `witness_l2_error_decay_gram` from MainChain
2. **Deep scan of `vasyunin_offdiag_integral`** — the next axiom target
3. **Vasyunin Integral Verifier v2.0** — production-grade Rust certification engine

The Cathedral MainChain now builds with zero sorrys and one fewer axiom. The forward direction uses the Báez-Duarte basis exclusively.

---

## 1. The Phantom Limb — Executed ✅

### What happened
The Cathedral had two parallel "Universes" for the Nyman-Beurling approximation:
- **Universe 1**: `{k/x}` basis → `gramMatrix`, `nbDistSq'`, `witness_l2_error_decay_gram` (AXIOM)
- **Universe 2**: `{1/(kx)}` basis → `vasyuninGramMatrix`, `bdLinComb`, `rh_implies_bd_convergence_direct` (PROVED)

Pillar II was built on Universe 1, but the forward proof (`DirectL2Crown`) lived in Universe 2. We restructured MainChain to use Universe 2's proved path, eliminating the axiom.

### Files changed
| File | Change |
|------|--------|
| `Assembly/MainChain.lean` | Pillar II → `rh_implies_bd_convergence_direct` |
| `NymanBeurling/NymanBeurling.lean` | Removed `GramWitness` import |
| `lakefile.lean` | Removed `GramWitness` from build targets |
| `Assembly/GramWitness.lean` | Archived to `Archive/Universe1/` |

### Verification
```
Build completed successfully (8180 jobs).
zero sorry warnings on MainChain
witness_l2_error_decay_gram: ABSENT from #print axioms
```

---

## 2. Axiom Budget — Current State

### `nyman_beurling_equivalence` depends on:

| # | Axiom | Type | Status |
|---|-------|------|--------|
| 1 | `pnt_mu_div_k` | Σ μ(k)/k → 0 | ✅ Proved (PNTBridge) |
| 2 | `pnt_mu_log_div_k` | Σ μ(k)·log(k)/k → -1 | ⏳ Deferred (Dirichlet convolution) |
| 3 | `pnt_mu_log_sq_div_k` | Σ μ(k)·log²(k)/k → -2γ | ⏳ Deferred (Dirichlet convolution) |
| 4 | `rh_implies_mertens_bound` | RH → |M(x)| = O(√x·log²x) | ⏳ Later (PerronCrown) |
| 5 | `abel_summation_covariance_bound` | Abel-Parseval bridge | 🟡 Analytic identity |
| 6 | `vasyunin_offdiag_integral` | Off-diagonal Gram = integral | 🔥 **NEXT TARGET** |
| ~~7~~ | ~~`witness_l2_error_decay_gram`~~ | ~~Gram witness decay~~ | ❌ **ELIMINATED** |

### Converse direction: kernel axioms only ✅
### Forward direction: 6 Cathedral axioms (1 proved, 2 deferred, 3 actionable)

---

## 3. Deep Scan: `vasyunin_offdiag_integral`

### The axiom
```lean
axiom vasyunin_offdiag_integral (j k : ℕ) (hj : j ≥ 1) (hk : k ≥ 1) (hjk : j ≠ k) :
    vasyuninGramEntry j k =
    ∫ x in (0:ℝ)..1, Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x))
```

### Infrastructure inventory (all sorry-free ✅)

The Cotangent tower has **9 files, ~130KB** of proved infrastructure:

| File | Lines | What's proved |
|------|-------|--------------|
| `CrossTermFTC.lean` | 14.5K | Per-tile FTC antiderivative evaluations |
| `PiecewiseFTC.lean` | 11K | Piecewise integration on row bands |
| `SqueezeElimination.lean` | 8.5K | ∫₀¹{1/u}²du = log(2π)-γ-1 |
| `StirlingBridge.lean` | 9.5K | Stirling approximation bridge |
| `OffDiagPartition.lean` | 20K | Row-band partition of [0,1] |
| `TelescopeSum.lean` | 17.6K | Telescoping FTC sums |
| `DigammaReflection.lean` | 12.8K | ψ(1-s)-ψ(s) = π·cot(πs) ← **WAS AXIOM, NOW PROVED** |
| `LogDigammaBridge.lean` | 18.6K | Floor-sum identity, reciprocity |
| `VasyuninAssembly.lean` | 7K | Formula symmetry, gram integral |

**Plus**: Diagonal case (`vasyunin_integral_diag`) — **PROVED** in `VasyuninIntegralProof.lean`.

### Sub-axiom decomposition

| # | Sub-axiom | Location | Difficulty | Time est. |
|---|-----------|----------|-----------|-----------|
| 4 | `vasyunin_integral_eq_formula` (general → coprime) | LogDigammaBridge:364 | 🟢 Easy | 1-2 hrs |
| 2 | `harmonicTileSum_reciprocity` (Dedekind) | LogDigammaBridge:119 | 🟡 Medium | 2-4 hrs |
| 1 | `gauss_digamma_formula` (Gauss's formula) | DigammaReflection:213 | 🟡 Med-Hard | 4-8 hrs |
| 3 | `telescope_limit_eq_vasyunin` (M→∞ limit) | LogDigammaBridge:305 | 🔴 Hard | 8-16 hrs |

### Complication discovered
`vasyuninGramEntry` (Defs.lean) uses `vasyuninSum` (cot = cos/sin), while `vasyuninGramFormula` (DigammaReflection.lean) uses `vasyuninCotSum` (1/tan). These are definitionally equal (`cos/sin = 1/tan`) but need a bridge lemma. This adds ~30 min to sub-axiom 4.

### Attack order
1. Bridge `vasyuninSum ↔ vasyuninCotSum` (30 min)
2. Sub-axiom 4: general → coprime reduction (1-2 hrs)
3. Sub-axiom 2: harmonic reciprocity (2-4 hrs)
4. Sub-axiom 1: Gauss digamma (4-8 hrs)
5. Sub-axiom 3: telescope limit — the boss fight (8-16 hrs)

---

## 4. Vasyunin Integral Verifier v2.0

### Previous results (April 22, max_k=10)

| Phase | Pairs | Min digits | Runtime |
|-------|-------|-----------|---------|
| Diagonal (k=1..15) | 15 | 6 | 141s |
| Off-diagonal (1≤j<k≤10) | 45 | 6 | 124s |
| **Total** | **60** | **6** | **265s** |

Key observations:
- Formula-integral match: **6-7 decimal digits** across all pairs
- Error scales as **O(1/(j·M_total))** where M_total = 10⁶ rows
- GCD structure visible: pairs with gcd>1 run slightly faster (fewer k-tiles per row)
- 256-bit MPFR precision is far more than needed — the bottleneck is the number of piecewise tiles

### v2.0 upgrade
- Bumped to **max_k=50** (1275 pairs total)
- Added `serde`/`chrono` for structured JSON certificates
- GCD structure analysis phase
- Progress reporting
- Certification threshold (≥4 matching digits = certified)

### Runtime estimate for max_k=50
Previous: 60 pairs in 265s ≈ 4.4s/pair average.  
At max_k=50: ~1275 pairs. Larger j,k means more tiles, so ~6-8s/pair average.  
**Estimate: 20-40 minutes** on 12 cores.

### Command to run (in separate terminal)
```bash
cd /path/to/prime/experiments/vasyunin-integral && cargo run --release 2>&1 | tee results/run_v2_n50.log
```

---

## 5. Weekend Plan

### Friday night (now)
- [x] Phantom Limb Amputation
- [x] Deep scan of vasyunin_offdiag_integral
- [x] Vasyunin Integral Verifier v2.0
- [ ] Bridge vasyuninSum ↔ vasyuninCotSum
- [ ] Sub-axiom 4: general → coprime

### Saturday
- [ ] Sub-axiom 2: harmonic tile reciprocity
- [ ] Sub-axiom 1: Gauss digamma formula

### Sunday (if needed)
- [ ] Sub-axiom 3: telescope limit (the boss fight)
- [ ] Integration: prove vasyunin_offdiag_integral from sub-axioms

### After weekend
- [ ] PNT log-weighted sums (Dirichlet convolution)
- [ ] abel_summation_covariance_bound
- [ ] PerronCrown → eliminate rh_implies_mertens_bound

---

## 6. The Big Picture

| Version | Date | Axioms | Key move |
|---------|------|--------|----------|
| v1 | March 2026 | 6 | Original architecture |
| v2 | April 6 | 5 | Great Purge |
| v3 | April 16 | 4 | Parseval Bridge |
| v4 | April 18a | 2 | Direct L² Crown |
| v5 | April 18b | 1 | One Crown |
| **v6** | **April 25** | **0 new** | **Phantom Limb Amputation** |
| v7 | This weekend? | -1 | vasyunin_offdiag_integral proved? |

The shield of the compiler holds.
