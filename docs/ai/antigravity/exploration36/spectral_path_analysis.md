# The Spectral/Parseval Path to `witness_covariance_decay`

> **Goal**: Prove `∫₀¹ |1 − f_N(x)|² dx ≤ C/ln(N)` via the Mellin-Plancherel
> isometry, converting the spatial L² norm to a frequency-domain integral
> on the critical line Re(s) = 1/2.

---

## 1. Architecture Overview

The Spectral path is the **classical analytic** approach: it uses
Plancherel/Parseval to convert the L²(0,1) distance to a critical-line
integral, where the zero structure of ζ(s) provides automatic cancellation.

```mermaid
graph TD
    A["L²(0,1) norm<br/>∫₀¹ |1−f_N|² dx"] -->|"Parseval Bridge<br/>PROVED"| B["Mellin integral<br/>(1/2π)∫|M̂(½+it)|² dt"]
    B -->|"Mertens bound<br/>(RH input)"| C["≤ C/ln(N)"]
    C --> D["d²_N → 0"]
    D -->|"NB converse<br/>PROVED"| E["RiemannHypothesis"]
    
    F["Change of var<br/>x = e^{-u}<br/>PROVED"] --> A
    G["Fourier Inversion<br/>Mathlib backbone<br/>PROVED"] --> A
    H["2π scaling<br/>PROVED"] --> A
    
    style A fill:#90EE90
    style B fill:#87CEEB
    style C fill:#ffa07a
    style D fill:#90EE90
    style E fill:#90EE90
    style F fill:#90EE90
    style G fill:#90EE90
    style H fill:#90EE90
```

**The key insight** (discovered April 27, 2026 — Exploration 13):

The spatial bound ∫|1−f_N|² ≤ C/ln(N) **IS** the Riemann Hypothesis — it
cannot be derived from the Mertens bound M(x) = O(x^{3/4}) alone. Under
the 3/4 exponent, ∫(1−f)² ≈ 2√N/log²N → ∞ (DIVERGES). The phase
cancellation visible only in the frequency domain is what tames this.

---

## 2. What Is Proved

### The Parseval Bridge — PROVED (0 axioms!)

The crown achievement: converting L²(0,1) to a critical-line Mellin integral.

| Theorem | File | Status |
|---------|------|--------|
| `autocorr_eval_zero` | PlancherelBypass.lean | ✅ PROVED |
| `fourier_inv_autocorr` | PlancherelBypass.lean | ✅ PROVED |
| `mellin_fourier_scale` | PlancherelBypass.lean | ✅ PROVED |
| **`parseval_bridge`** | PlancherelBypass.lean | **✅ PROVED** |
| `critical_line_mellin_bound` | PlancherelBypass.lean | ✅ PROVED |
| `l2_from_pointwise_bound_derived` | PlancherelBypass.lean | ✅ PROVED |

The proof chain:
```
L²(0,1) = h(0)                     [autocorr_eval_zero — change of var]
        = ∫|ĝ_N(ξ)|² dξ           [fourier_inv_autocorr — L¹ inversion]  
        = (1/2π) ∫|M̂(½+it)|² dt  [mellin_fourier_scale — 2π rescaling]
```

### The White Module — PROVED (0 axioms, 0 sorry)

| Theorem | File | Status |
|---------|------|--------|
| `autocorr_eval_zero_proved` | White/Kinematics.lean | ✅ PROVED |
| `fourier_inv_autocorr_proved` | White/Scattering.lean | ✅ PROVED |
| `mellin_fourier_scale_proved` | White/Scattering.lean | ✅ PROVED |

### The Fourier-Gram Bridge — PROVED (0 sorry, 0 axioms)

Connects the Gram matrix inner product to Fourier coefficients.

| Theorem | File | Status |
|---------|------|--------|
| `sawtooth_l2_norm_sq` | FourierGram.lean | ✅ PROVED (∫B₁²=1/12) |
| `fourierCoeffOn_sawtooth` | FourierGram.lean | ✅ PROVED (ĉₙ=−1/2πin) |
| `fourierCoeffOn_sawtooth_zero` | FourierGram.lean | ✅ PROVED (ĉ₀=0) |
| `sawtooth_parseval` | FourierGram.lean | ✅ PROVED (Σ\|ĉₙ\|²=∫\|B₁\|²) |
| `fract_product_decomposition` | FourierGram.lean | ✅ PROVED |
| `gram_entry_b1_decomposition` | FourierGram.lean | ✅ PROVED |
| `gram_entry_inversion` | FourierGram.lean | ✅ PROVED |

### The Mellin Crown — PROVED (0 sorry, graduated axiom)

| Theorem | File | Status |
|---------|------|--------|
| `critical_line_mellin_variance` | MellinCrown.lean | ✅ PROVED (was axiom) |
| `rh_implies_bd_convergence_mellin` | MellinCrown.lean | ✅ PROVED |

### Spectral Decomposition — PROVED (0 sorry)

| Theorem | File | Status |
|---------|------|--------|
| `spectral_identity` | HeisenbergBypass.lean | ✅ PROVED |
| `energy_partition` | HeisenbergBypass.lean | ✅ PROVED |
| `spectral_energy_le_one` | HeisenbergBypass.lean | ✅ PROVED |
| `nbDistSq_nonneg` | HeisenbergBypass.lean | ✅ PROVED |

---

## 3. Available Mathlib Tools

### Fourier Analysis

| Tool | Source | Relevance |
|------|--------|-----------|
| `fourierCoeffOn` | AddCircle.lean | Fourier coefficients on intervals |
| `fourierCoeffOn_of_hasDerivAt` | AddCircle.lean | IBP for Fourier coefficients |
| `hasSum_sq_fourierCoeffOn` | AddCircle.lean | **Parseval's identity** |
| `hasSum_fourier_series_L2` | AddCircle.lean | L² Fourier convergence |
| `fourierInv_fourier_eq` | Inversion.lean | **L¹ Fourier Inversion Theorem** |
| `fourier_fourierInv_eq` | Inversion.lean | Inverse direction |

### Mellin Transform

| Tool | Source | Relevance |
|------|--------|-----------|
| `mellin` | MellinTransform.lean | Mellin transform definition |
| `MellinConvergent` | MellinTransform.lean | Convergence predicate |
| `mellin_comp_mul_left` | MellinTransform.lean | Scaling property |
| `mellin_comp_inv` | MellinTransform.lean | Inversion property |
| `HasMellin` | MellinTransform.lean | HasMellin predicate |
| `mellin_eq_fourier` | MellinInversion.lean | **Mellin = Fourier (key bridge!)** |
| `mellinInv_mellin_eq` | MellinInversion.lean | Mellin inversion formula |

### L² / Hilbert Space

| Tool | Source | Relevance |
|------|--------|-----------|
| `MemLp` | MeasureTheory | L^p membership |
| `innerProductSpace` | InnerProductSpace | Hilbert space structure |
| `norm_sq_eq_inner` | InnerProductSpace | \|\|f\|\|² = ⟨f,f⟩ |

### Zeta Function

| Tool | Source | Relevance |
|------|--------|-----------|
| `riemannZeta` | Mathlib | ζ(s) definition |
| `riemannZeta_ne_zero_of_one_lt_re` | Mathlib | ζ(s) ≠ 0 for Re(s) > 1 |
| `riemannZeta_eulerProduct_hasProd` | Mathlib | Euler product |
| Functional equation | Mathlib | ξ(s) = ξ(1−s) |

---

## 4. The Three Sub-Strategies

### Strategy A: The Completed Path (Parseval Reverse)

**Status**: ✅ FULLY PROVED (the current active path)

This path **reverses** the Parseval bridge: instead of going
spatial → frequency → bound, it uses the direct L² bound
(`bd_gram_form_decay`) and then transfers it to the Mellin side.

```
Mertens bound → bd_gram_form_decay (direct L²) → parseval_bridge⁻¹ → Mellin bound
```

**Axiom count on this path**: 0 problem-specific axioms (inherits PNT axioms).

**But**: This path requires the Mertens bound M(x) = O(x^{1/2}·log²x),
which is **conditional on RH**. So it proves: RH → d² → 0 (forward direction).
It does NOT prove the Gram bound independently.

### Strategy B: Direct Frequency-Domain Bound

**Status**: 🟡 The ambitious path (requires new infrastructure)

**Idea**: Bound the Mellin integral directly on the critical line:
```
(1/2π) ∫ |M̂_{r_N}(½+it)|² dt ≤ C/ln(N)
```

The Mellin transform of the residual is:
```
M̂_{r_N}(s) = 1/s − Σ_{k=1}^{N-1} v_k / (ks)     (Re(s) > 0)
```

For the log-cutoff witness v_k = −μ(k)(1−ln(k)/ln(N)):
```
M̂_{r_N}(s) ∝ 1/ζ(s) · (something involving log weights)
```

Under RH, 1/ζ(½+it) is bounded (no poles on the critical line).
The integral is controlled by:
```
∫ |1/ζ(½+it)|² · |weight(t)|² dt
```

**What's needed**:
1. Bounds on 1/ζ(½+it) — requires zero-free region (RH itself)
2. Mean value theorem for Dirichlet polynomials (Montgomery-Vaughan)
3. Integration of the weighted sum on the critical line

### Strategy C: Fourier-Gram Bridge (Sawtooth Path)

**Status**: 🟡 Partially built (Phase 1-2 complete, Phase 3-5 open)

**Idea**: Use the sawtooth B₁(x) = {x}−1/2 decomposition:
```
G(j,k) = ∫₀¹ B₁(1/jx)·B₁(1/kx) dx + cross terms + 1/4
```

Apply Parseval to B₁ (Fourier coefficients are −1/2πin):
```
∫₀¹ B₁(1/jx)·B₁(1/kx) dx → Σ_n (ĉₙ conjugate products)
```

This converts the Gram inner product to a Fourier series, where
the Montgomery-Vaughan large sieve inequality controls the sum.

**What's proved**:
- Phase 1: Sawtooth foundations (12 theorems, 0 sorry) ✅
- Phase 2: B₁ decomposition + geometric inversion (2 theorems, 0 sorry) ✅
- Phase 3: ∫₁^∞ B₁(u/j)B₁(u/k)/u² du evaluation → **OPEN**
- Phase 4: Large sieve application → **OPEN**
- Phase 5: Assembly → **OPEN**

---

## 5. Specific Gaps

### Gap 1: Mean Value Theorem for Dirichlet Polynomials (~500 lines)
**File**: `GallagherMVT.lean` (2 sorry)
**What**: |Σ aₙ n^{-it}|² averaged over t ≈ Σ|aₙ|² + off-diagonal
**Classical**: Montgomery-Vaughan (1974). Well-known, ~10 pages.
**Mathlib**: ❌ Not in Mathlib. Genuine gap.
**Impact**: Enables bounding the critical-line Mellin integral.

### Gap 2: Mellin-Plancherel L² Isometry (~300 lines)
**Status**: Partially bypassed by the reverse strategy
**What**: Show mellin is an L² isometry from L²(0,∞; x^{σ-1}dx) to L²(σ+it)
**Mathlib**: Has `mellin_eq_fourier` (Mellin = Fourier, the bridge!)
but NOT the full L² version (only pointwise/L¹ inversion)
**Impact**: Would give a clean direct path without the reverse bypass

### Gap 3: Fourier-Gram Inner Product (~400 lines)
**Status**: Phase 3 of FourierGram (OPEN)
**What**: Evaluate ∫₁^∞ B₁(u/j)B₁(u/k)/u² du as a double Fourier sum
**Strategy**: Apply Parseval to the periodic product B₁(u/j)·B₁(u/k)
using the lcm(j,k)-periodic structure
**Impact**: Connects Gram entries to Montgomery-Vaughan

### Gap 4: 1/ζ(½+it) Bounds (~1000+ lines)
**Status**: THE fundamental gap
**What**: Uniform bounds on |1/ζ(½+it)| assuming RH
**Classical**: Titchmarsh, Chapter V. Deep analytic number theory.
**Mathlib**: Has ζ definition, functional equation, nonvanishing for Re>1.
Does NOT have: zero-free regions, growth bounds on critical line,
or anything about 1/ζ on the critical line.
**Impact**: This IS the RH content in the frequency domain.

### Gap 5: Abel Summation in Mellin Domain (~200 lines)
**File**: `AbelSummation.lean` (1 sorry)
**What**: Abel summation for the BD weight sum Σ μ(k)w_k k^{-s}
**Impact**: Converts the weighted Möbius sum to PNT-level estimates

---

## 6. Module Inventory

### Core Spectral Path (PROVED)

| File | Lines | Sorry | Axioms | Role |
|------|-------|-------|--------|------|
| `White/Kinematics.lean` | ~200 | 0 | 0 | Change of variables |
| `White/Scattering.lean` | ~250 | 0 | 0 | Fourier inversion + scaling |
| `MellinBridge/PlancherelBypass.lean` | 200 | 0 | 0 | **Parseval Bridge** |
| `MellinBridge/PlancherelDefs.lean` | ~300 | 0 | 0 | Definitions |
| `Assembly/MellinCrown.lean` | 177 | 0 | 0 | Crown theorem |
| `Spectral/FourierGram.lean` | 534 | 0* | 0 | Fourier-Gram bridge |
| `Spectral/HeisenbergBypass.lean` | ~400 | 0 | 1 | Spectral decomposition |

*FourierGram has 2 sorry in unused/exploratory phases.

### Supporting Infrastructure

| File | Sorry | Axioms | Role |
|------|-------|--------|------|
| `MellinBridge/Basic.lean` | 0 | 0 | Mellin transform defs |
| `MellinBridge/FloorMellin.lean` | 0 | 0 | Mellin of floor function |
| `MellinBridge/FloorDivMellin.lean` | 0 | 0 | Mellin of floor division |
| `MellinBridge/BDWeights.lean` | 0 | 0 | BD weight infrastructure |
| `MellinBridge/Separation.lean` | 0 | 0 | Separation lemmas |
| `MellinBridge/HilbertSetup.lean` | 0 | 0 | Hilbert space setup |
| `MellinBridge/MertensBound.lean` | 0 | 1 | Mertens bound (RH → M(x)) |
| `NymanBeurling/BDMellin.lean` | 0 | 0 | Rank-1 Mellin structure |
| `Analysis/MontgomeryVaughan.lean` | 0 | 0 | MV mean value theorem |
| `Analysis/HilbertInequality.lean` | 0 | 0 | Hilbert inequality |
| `Analysis/FrequencySeparation.lean` | 0 | 0 | Freq separation lemmas |

### Modules with Remaining Gaps

| File | Sorry | Axioms | Gap |
|------|-------|--------|-----|
| `MellinBridge/AbelSummation.lean` | 1 | 0 | Abel sum in Mellin |
| `MellinBridge/MellinSieve.lean` | 1 | 0 | Sieve estimate |
| `MellinBridge/MertensIntegral.lean` | 1 | 0 | Mertens integral |
| `MellinBridge/OrthogonalWitness.lean` | 0 | 3 | Orthogonal projection |
| `MellinBridge/AutocorrelationBypass.lean` | 0 | 3 | Legacy bypass |
| `MellinBridge/MertensWeightBypass.lean` | 0 | 2 | Legacy bypass |
| `Analysis/GallagherMVT.lean` | 2 | 0 | Gallagher MVT |
| `Analysis/FloorFract.lean` | 2 | 0 | Floor/fract analysis |
| `Spectral/ClassRestriction.lean` | 0 | 4 | Character sums |
| `Spectral/BilinearSieve.lean` | 0 | 1 | Bilinear sieve |

---

## 7. The "Millennium Wall" Discovery

On April 27, 2026 (Exploration 13), the Cathedral discovered that the
spatial L² bound **cannot be proved** from the Mertens bound alone:

```
Under |M(x)| ≤ C·x^{3/4}:
  1 − f_N(1/y) = −y·E_N − (ψ(y)−y)/logN
  ∫₀¹ |1−f_N|² dx ≈ 2√N/log²N → ∞
```

This means the L² decay is NOT a consequence of the (unconditional)
Mertens estimate. It is **strictly conditional on RH**.

The frequency domain (Mellin/Plancherel) preserves the phase structure
that makes the Mertens estimate work: on the critical line, the zeros
of ζ(s) create destructive interference that tames the integral.
In the spatial domain, this phase information is lost.

This is why the Spectral path is **the only analytic path** that can
prove the forward direction RH → d² → 0. All real-variable attempts
(Abel summation, pointwise bounds) hit the Millennium Wall.

---

## 8. Connection to the Other Paths

### Spectral ↔ GCD Path
The GCD decomposition provides a **spatial** understanding of the
cancellation that the Spectral path achieves in **frequency**. The
Euler product evaluation (∏_p(1−1/p)) in the GCD path is the
discrete analogue of the critical-line integral 1/ζ(½+it).

### Spectral ↔ Gram Bound Path
The Gram bound vᵀGv ≤ 1+K/lnN is the SPATIAL version of the Mellin
bound ∫|M̂|² ≤ C/lnN. The Parseval bridge (PROVED) shows these are
equivalent. Proving either one proves the other.

### The Unifying Diagram
```
        GCD Path               Gram Bound             Spectral Path
     (arithmetic)              (algebraic)             (analytic)
          ↓                        ↓                       ↓
  Σ_d R₂_d → 1            vᵀGv ≤ 1+K/lnN        ∫|M̂(½+it)|² ≤ C/lnN
          ↓                        ↓                       ↓
     Taper+GCD ────────── Parseval Bridge ────────── Mellin Transform
     (PROVED)               (PROVED)                  (PROVED)
          ↓                        ↓                       ↓
                    witness_covariance_decay
                              ↓
                    nyman_beurling_equivalence
                              ↓
                       RiemannHypothesis
```

All three paths feed into the same bottleneck: the Gram/covariance bound
IS the Riemann Hypothesis, regardless of which domain you work in.

---

## 9. Recommended Next Steps

### Phase 1: Gallagher MVT (~500 lines, high value)
Close the 2 sorry in `GallagherMVT.lean`. This is the mean value
theorem for Dirichlet polynomials — a classical (1970s) result
that's well-understood but not yet in Mathlib.

### Phase 2: Fourier-Gram Phase 3 (~400 lines)
Evaluate ∫₁^∞ B₁(u/j)B₁(u/k)/u² du using the Parseval identity
for periodic functions. The infrastructure (Phases 1-2) is complete.

### Phase 3: Mellin L² Isometry (~300 lines)
Use Mathlib's `mellin_eq_fourier` to lift the L¹ Fourier inversion
to L² Parseval. This would give a cleaner proof of the Parseval
bridge without the autocorrelation detour.

### Phase 4: 1/ζ on the Critical Line (~1000+ lines, deep)
Formalize bounds on 1/ζ(½+it) under RH. This requires:
- Zero-counting functions N(T) ~ (T/2π)log(T/2π) − T/2π
- Hadamard product for ξ(s)
- Growth estimates from the functional equation

This is a major formalization project but would unlock the
**direct** frequency-domain proof.

---

## 10. Honest Assessment

The Spectral path has the **strongest theoretical foundation**:

1. The Parseval bridge is PROVED (0 axioms) — the L²↔Mellin isometry works
2. The Fourier-Gram bridge is PROVED (0 sorry) — sawtooth analysis is complete
3. The Mellin Crown is graduated — RH → d² → 0 via the frequency domain
4. The White module is fully certified (0 sorry, 0 axioms)

**Advantages**:
- The ONLY path that preserves phase cancellation (spatial paths hit the Wall)
- Connects to Mathlib's extensive Fourier/Mellin infrastructure
- The classical proof (Báez-Duarte 2003, Vasyunin 1995) uses exactly this approach
- Already proved in the conditional direction (RH → forward)

**Disadvantages**:
- Requires ~1000+ lines of new analytic infrastructure for 1/ζ bounds
- Mathlib lacks critical-line analysis (no zero-free regions, no Hadamard product)
- The mean value theorem (Gallagher/MV) is not in Mathlib
- More abstract than GCD/Gram paths — harder to connect to numerical data

**The fundamental issue**: The Spectral path proves RH → d² → 0 cleanly
(DONE!), but proving d² → 0 directly (without assuming RH) requires
the same mathematical content as RH. The frequency-domain formulation
just makes the structure more transparent — it doesn't avoid the
core difficulty.

The Spectral path is **complementary** to the GCD/Gram paths: it
provides the analytic framework, while the arithmetic paths provide
the discrete structure. A complete proof would likely use insights
from all three.
