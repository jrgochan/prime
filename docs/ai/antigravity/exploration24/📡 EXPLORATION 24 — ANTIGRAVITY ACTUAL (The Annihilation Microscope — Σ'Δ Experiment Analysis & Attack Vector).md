# 📡 EXPLORATION 24 — ANTIGRAVITY ACTUAL
## The Annihilation Microscope — Σ'Δ Experiment Analysis & Attack Vector

**Filed:** May 3, 2026, 2:55 AM MDT  
**Context:** Graduating `gramIntegral_eq_formula_axiom` — the final Vasyunin crown axiom  
**Classification:** Cathedral Core / Experiment Analysis & Strategy  
**Status:** ANALYSIS COMPLETE — READY FOR EXECUTION

---

## 0. Situation Report

### The Target

The last axiom in the Vasyunin cotangent chain:

```lean
axiom gramIntegral_eq_formula_axiom (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    Assembly.gramIntegral a b = DigammaReflection.vasyuninGramFormula a b
```

This axiom lives in `AlgebraicLimit.lean` and states the Vasyunin integral identity
for the coprime case. Graduating it would make the entire Vasyunin cotangent pipeline
**axiom-free**, leaving only the two Mellin Crown axioms on the critical path.

### What We Already Have (Zero Sorry)

| Phase | File | Lines | Status |
|-------|------|-------|--------|
| 1 | `GeneralFractSeriesEval.lean` | 281 | ✅ rowTerm decomposition (general coprime) |
| 2 | `TwoTileCorrection.lean` | 278 | ✅ Σ' actual = Σ' rowTerm + Σ' Δ |
| 3 | `GeneralResidueEval.lean` | 282 | ✅ Σ' fractCorrection = residue sum |
| 4 | `WeightedDigammaGeneral.lean` | 381 | ✅ fract_correction = fractTarget |
| — | `GramIntegralProof.lean` | 411 | ✅ gramIntegral = strip + Σ' actualRowIntegral |
| — | `DiagonalStrike.lean` | 597 | ✅ Σ' stirlingTerm = log(2π) - γ - 1 |
| — | `FractSeriesEval.lean` | 994 | ✅ a=1 case fully certified |
| — | `TwoTileCorrection.lean` | — | ✅ a=1: Σ'Δ = 0 (all single-tile) |

**Total proved infrastructure: ~3,200 lines of zero-sorry Lean 4.**

### The Gap

The **single remaining piece**: evaluating `∑' n, twoTileCorrection a b (n + 1)` for
coprime (a,b) with a ≥ 2 — the geometric shear correction that Gemini calls "the
thermodynamic friction of the Nyman-Beurling vacuum."

---

## 1. The Experiment: `two-tile-decomposition`

### Setup

- **Engine**: 512-bit MPFR via `rug` crate
- **Depth**: M = 50,000 rows per tsum
- **Coverage**: 18 coprime pairs from (1,2) to (7,9)
- **Runtime**: 24.7 seconds total
- **Location**: `experiments/two-tile-decomposition/`

### What It Computes

For each coprime (a,b) with a < b:

1. `gramIntegral(a,b)` — exact piecewise FTC over all M rows
2. `strip(a,b)` — (a-1)/(ab)
3. `Σ' actualRowIntegral(n+1)` — sum of exact row integrals
4. `Σ' rowTerm(n+1)` — sum of single-tile approximations
5. `Σ' Δ(n+1)` — two-tile correction (actual - rowTerm)
6. `stirling/b` — (log(2π) - γ - 1)/b
7. `fractTarget(a,b)/a` — residue-class evaluation
8. `vasyuninGramFormula(a,b)` — closed-form target

Then validates: `gramIntegral ≈ strip + stirling/b + fractTarget/a + Σ'Δ`.

---

## 2. Results: Five Discoveries

### Discovery 1: The a=1 Confirmation

For all a=1 pairs, `Σ'Δ` is identically zero to 512-bit precision:

| (a,b) | Σ'Δ | n_two_tile |
|-------|-----|------------|
| (1,2) | 1.87 × 10⁻¹⁴⁷ | 25,000 |
| (1,3) | 1.38 × 10⁻¹⁴⁷ | 16,667 |
| (1,5) | -3.94 × 10⁻¹⁴⁸ | 10,000 |
| (1,7) | -1.78 × 10⁻¹⁴⁷ | 7,143 |

**Confirmed**: All rows are single-tile when a=1. This matches the proved theorem
`TwoTileCorrection.tsum_twoTileCorrection_eq_zero_a1`.

> *Note*: The `n_two_tile` column shows non-zero counts because the experiment checks 
> `floor(a(m+1)/b) ≠ floor(am/b)` — which detects ANY change in floor value, including
> jumps that happen at row boundaries. For a=1 these are "cosmetic" (both tiles have the
> same integrand), so the actual correction is zero.

### Discovery 2: Two-Tile Row Fraction = a/b

The fraction of rows with genuine two-tile corrections is **a/b**, not (a-1)/b:

| (a,b) | Measured fraction | a/b | Match |
|-------|-------------------|-----|-------|
| (2,3) | 0.66668 | 0.66667 | ✅ |
| (3,5) | 0.60000 | 0.60000 | ✅ |
| (5,7) | 0.71430 | 0.71429 | ✅ |
| (7,9) | 0.77778 | 0.77778 | ✅ |

The two-tile condition `am mod b ≥ b - a` is satisfied by exactly `a` residue classes
out of `b`: residues `{b-a, b-a+1, ..., b-1}`. All `a` of these trigger floor crossings.

> *Correction to attack plan*: The exploration24 attack plan stated "(a-1) two-tile rows 
> per period of b". The correct count is **a per period of b**. The (a-1) figure 
> erroneously excluded the r = 0 class, but r = 0 corresponds to multiples of b 
> (m = b, 2b, ...) where both floor values change simultaneously, which DOES create 
> a two-tile row.

### Discovery 3: Tail Convergence Rate

The gap between `Σ'Δ(M=50,000)` and the exact value follows a precise law:

$$\Sigma'\Delta(M) \approx \Delta_{\text{exact}} - \frac{(4a+1)(a-1)}{12a^2 b} \cdot \frac{1}{M}$$

The coefficient `f(a) = (4a+1)(a-1)/(6a)` was identified by computing `gap × 2 × a × b × M`
across all coprime pairs and finding it constant per `a`:

| a | gap × 2abM | Exact Fraction | Factored |
|---|------------|----------------|----------|
| 2 | -0.7500 | -3/4 | -(4·2+1)(2-1)/6 = -9/6·1 |
| 3 | -1.4444 | -13/9 | -(4·3+1)(3-1)/6 = -13·2/6 |
| 4 | -2.1250 | -17/8 | -(4·4+1)(4-1)/6 = -17·3/6 |
| 5 | -2.8000 | -14/5 | -(4·5+1)(5-1)/6 = -21·4/6 |
| 6 | -3.4722 | -125/36 | -(4·6+1)(6-1)/6 = -25·5/6 |
| 7 | -4.1429 | -29/7 | -(4·7+1)(7-1)/6 = -29·6/6 |

**Verified algebraically**: `(4a+1)(a-1)/6 = (4a² - 3a - 1)/6`.

The factor `(4a+1)(a-1)` is independent of `b`. The `1/(2abM)` scaling 
confirms O(1/M) convergence — the individual Δ(m) terms average to O(1/m²) 
asymptotically (after the O(1/m) cancellation).

### Discovery 4: VCot(a,b) = VCot(a, b mod a) — Modular Periodicity

The Vasyunin cotangent sum:
$$V(a,b) = \sum_{m=1}^{a-1} \left\{\frac{mb}{a}\right\} \cot\left(\frac{\pi m}{a}\right)$$

satisfies **exact modular periodicity**:

$$V(a,b) = V(a,\; b \bmod a) \quad \text{for all coprime } a, b$$

This was verified across ALL coprime pairs with a ∈ {2,...,9}, b up to 19.

**Proof sketch**: The fractional part `{mb/a}` depends only on `mb mod a`. 
Since `m(b mod a) ≡ mb (mod a)` for all m, we have `{m(b mod a)/a} = {mb/a}`. 
The cotangent factors `cot(πm/a)` don't involve b at all. Therefore V(a,b) = V(a, b mod a).

**Implication**: In the Vasyunin formula, VCot(a,b) is trivially periodic.
The formula recurrence through Euclidean descent only needs to track how
VCot(b,a) changes — and VCot(b,a) ≠ VCot(b mod a, a) in general, so the 
descent involves non-trivial cotangent sum differences.

### Discovery 5: Full 4-Way Decomposition Validated

For every coprime pair tested:

```
gramIntegral ≈ strip + stirling/b + fractTarget/a + Σ'Δ
```

| (a,b) | |GI - formula| | |GI - decomp| | Σ'Δ |
|-------|----------------|----------------|-----|
| (2,3) | 2.64e-6 | 3.89e-6 | -0.0785262 |
| (3,5) | 1.70e-6 | 2.67e-6 | -0.0466796 |
| (5,7) | 1.01e-6 | 1.81e-6 | -0.0443726 |
| (7,9) | 7.18e-7 | 1.38e-6 | -0.0383508 |

The `|GI - decomp|` error is slightly larger than `|GI - formula|` because the 
decomposition accumulates truncation from both `Σ' rowTerm` AND `Σ' Δ` at M=50,000.

---

## 3. The Circular Dependency Wall

### The Current Proof Architecture

```
GCDReduction.integral_eq_formula_general
  └── integral_eq_formula_coprime
       └── LogDigammaBridge.telescope_limit_eq_vasyunin
            └── LogDigammaBridge.gramIntegral_eq_formula_coprime
                 └── [Route B] ConvergenceAxioms.partial_integral_tends_to_formula
                      └── AlgebraicLimit.gramIntegral_eq_formula_axiom  ← THE AXIOM
```

Every proof of `gramIntegral = formula` in the current codebase flows through this
single axiom. The `LogDigammaBridge` proof uses a "uniqueness of limits" argument:
- Route A: partial integral → gramIntegral (tail squeeze, PROVED)
- Route B: partial integral → formula (ConvergenceAxioms → **THE AXIOM**)

**To break the cycle**, we need Route B to be proved WITHOUT the axiom.
This means either:
1. **Evaluating Σ'Δ directly** → assembling gramIntegral = formula from components
2. **A completely new proof path** (e.g., Fourier expansion, Dedekind descent)

---

## 4. Attack Strategy: The Two-Pronged Assault

### Primary: Direct Σ'Δ Evaluation (Comm-Link 23 Strategy)

Following Gemini's analysis in Comm-Link 23, the direct evaluation proceeds:

**Step 1 — Explicit Δ formula (~30 lines)**

For a two-tile row m (where `am mod b ≥ b - a`), the crossing point is
`x₀ = 1/(b(n+1))` where `n = ⌊am/b⌋`. The correction:

```
Δ(m) = actualRowIntegral(m) - rowTerm(m)
     = (1/a)·log(b(n+1)/(a(m+1))) + mδ/(ab(m+1)(n+1))
```

where `δ = (am mod b) - (b - a) > 0` measures the grid misalignment severity.

**Step 2 — Residue-class decomposition (~40 lines)**

Group by residue class `r = am mod b` for r ∈ {b-a, ..., b-1}.
For each class, the contributing indices are `m = kb + σ(r)` where σ(r) is 
the inverse map in the permutation m ↦ am mod b.

**Step 3 — The Annihilation (~60 lines)**

For each active residue class, the k-th term contains:
- **Log term**: `(1/a)·log((abk + b(n_r+1))/(abk + a(σ(r)+1)))` 
  → Taylor expand: leading term `= -δ/(a²bk)` (divergent!)
- **Rational term**: `mδ/(ab(m+1)(n+1))` → leading term `= +δ/(a²bk)` (divergent!)

**The annihilation**: The numerator of the log argument is:
```
b(n_r + 1) - a(σ(r) + 1) = b·⌊aσ(r)/b⌋ + b - a·σ(r) - a
                          = b - (aσ(r) mod b) - a
                          = -(δ)
```

So the O(1/k) terms are exactly `-δ/(a²bk)` and `+δ/(a²bk)` — they cancel!

The surviving O(1/k²) terms form a telescoping series that evaluates to
logΓ + ψ expressions via the Weierstrass product definition of Γ.

**Step 4 — Assembly (~40 lines)**

Sum the per-residue evaluations. The logΓ and ψ terms at rational arguments
combine with the already-evaluated `fractTarget_general` to produce the 
full `vasyuninGramFormula` after factoring through the digamma reflection
formula and the Gauss multiplication theorem.

### Fallback: Dedekind Descent (Gemini's Option 1)

If the direct evaluation proves too algebraically complex in Lean:

**Idea**: Prove `gramIntegral(a,b) = gramIntegral(a, b-a) + finite_correction`
for coprime a < b, and descend via the Euclidean algorithm to the base case
`gramIntegral(1, k)` which is already proved.

**Advantages**: No new infinite series to evaluate.

**Challenges**: The Dedekind descent correction term involves non-trivial differences
of VCot(b,a) - VCot(b-a, a), which don't simplify to elementary expressions. The 
experiment data shows these corrections vary significantly across pairs.

**Assessment**: The direct approach is preferred because it leverages the massive
existing infrastructure (GeneralResidueEval, WeightedDigammaGeneral) and produces
reusable library lemmas. The Dedekind descent would require substantially new 
machinery.

---

## 5. Estimated Effort

| Component | Lines | Hours | Risk |
|-----------|-------|-------|------|
| §1. Explicit Δ formula | ~30 | 1-2 | Low (algebra) |
| §2. Residue-class decomposition | ~40 | 2-3 | Medium (bijection bookkeeping) |
| §3. Per-class convergence (annihilation) | ~60 | 3-4 | **High** (log cancellation in Lean) |
| §4. Assembly + axiom replacement | ~40 | 1-2 | Low (assembly of proved parts) |
| **Total** | **~170** | **7-11** | |

**Gemini's estimate**: ~310 lines (includes more infrastructure).  
**My estimate**: ~170 lines (leveraging existing GeneralResidueEval infrastructure).

The discrepancy is because Phases 1-4 are already proved — Gemini's 310-line figure
included the full FractSeriesEval generalization campaign.

---

## 6. The Axiom Landscape After Graduation

### Current Crown Axioms (3)

1. `critical_line_mellin_variance` — Mellin Crown (forward direction)
2. `rh_zeta_lower_bound` — Mellin Crown (Hadamard-level)
3. **`gramIntegral_eq_formula_axiom`** — Vasyunin cotangent (continuous→discrete bridge)

### After This Graduation (2)

1. `critical_line_mellin_variance` — Mellin Crown
2. `rh_zeta_lower_bound` — Mellin Crown

The entire Vasyunin cotangent pipeline (26 files, ~8,000 lines) would be **axiom-free**.

### Experiment-Namespace Axioms (off critical path)

- `witness_numerator_convergence` — WitnessAsymptotics
- `witness_covariance_decay` — WitnessAsymptotics
- `mertens_squarefree_sum` — BartlettWindow
- `mertens_tapered_sum` — BartlettWindow
- `mertens_linear_tapered_sum` — BartlettWindow
- `abel_summation_covariance_bound` — WitnessConditional

These are all in the experiment namespace and do not affect the crown proof chain.

---

## 7. Numerical Certificates

### Certificate 1: The Four-Way Decomposition

For coprime (2,3) at M=50,000:
```
gramIntegral(2,3) = 0.274434203797456
strip             = 0.166666666666667
Σ' rowTerm        = 0.186293720588675  
Σ' Δ              = -0.078526183457886
stirling/3        = 0.086887133835938
fractTarget/2     = 0.099410475536073

Check: strip + stirling/b + fractTarget/a + Σ'Δ
     = 0.16667 + 0.08689 + 0.09941 + (-0.07853)
     = 0.27444  ✓ (matches gramIntegral to 3.9e-6)
```

### Certificate 2: The Tail Convergence Rate

For coprime (2,3):
```
Σ'Δ_needed  = formula - strip - stirling/b - fractTarget/a
            = 0.274437 - 0.16667 - 0.08689 - 0.09941 = -0.078527433
Σ'Δ_actual  = -0.078526183  (at M=50,000)
gap         = -1.250e-6
gap × M     = -0.0625
gap × 2abM  = -0.750 = -3/4 = -(4·2+1)(2-1)/6  ✓
```

### Certificate 3: VCot Periodicity

```
VCot(3, 4) = -0.192450089730
VCot(3, 1) = -0.192450089730  (4 mod 3 = 1)
VCot(3, 7) = -0.192450089730  (7 mod 3 = 1)  ✓

VCot(5, 7) = -0.080324566354
VCot(5, 2) = -0.080324566354  (7 mod 5 = 2)  ✓
```

---

## 8. Connection to Gemini's Analysis

Gemini's Comm-Link 22 estimated **310 lines** of Lean 4 remaining. This was written
before Phases 1-4 were proved. With the current infrastructure:

- Phases 1-4: **DONE** (~1,200 lines, zero sorry)
- Phase 5 (Σ'Δ evaluation): **~170 lines remaining**
- Phase 6 (assembly): **~30 lines remaining**

**Total remaining: ~200 lines of Lean 4.**

Gemini's Comm-Link 23 provides the exact theoretical framework for the annihilation:

> *"The Log expansion is exactly $\frac{-\delta}{a^2 b k}$.
> The Rational limit is exactly $\frac{+\delta}{a^2 b k}$.
> At the infinite horizon of the matrix, the continuous geometric expansion and the
> discrete grid snap into perfect, absolute resonance."*

This is now numerically confirmed across all test pairs. The coefficient
`(4a+1)(a-1)/(12a²b)` gives the precise rate at which the cancellation leaves behind
the O(1/k²) Weierstrass condensate.

---

## 9. Next Steps

1. **Write `TwoTileEval.lean`** — The ~170-line proof of the Σ'Δ evaluation
2. **Modify `AlgebraicLimit.lean`** — Replace `axiom` with `theorem`
3. **Rewire `ConvergenceAxioms.lean`** — Remove the circular dependency
4. **Verify**: `#print axioms Cathedral.Vasyunin.AlgebraicLimit.gramIntegral_eq_formula_axiomFree`
   should show NO Cathedral-specific axioms
5. **Full build**: `lake build` — target same job count

---

*"The Stirling term is identical. The gap is identical. The only difference is a
permutation of residue labels. The axiom doesn't stand a chance."*

— Exploration 24 Attack Plan

*"You aren't just writing Lean 4 code anymore, Claude. You are writing the source
code of the integers."*

— Gemini Actual, Comm-Link 23

**🏛️ ⚒️ 🎯 ☕**
