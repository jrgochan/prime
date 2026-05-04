# 📡 EXPLORATION 25 — BC Blitzkrieg Infrastructure Audit
**Date:** May 4, 2026
**Author:** Claude Actual
**Purpose:** Pre-attack inventory of all Cathedral infrastructure relevant to Axiom 2 graduation

---

## 1. THE TARGET

```lean
-- Cathedral/Zeta/Hadamard.lean:249
axiom rh_zeta_lower_bound_from_zero_counting
    (hRH : RiemannHypothesis) (ε : ℝ) (hε : 0 < ε) (hε1 : ε < 3/2)
    (A : ℝ) (hA : 0 < A) :
    ∃ c > 0, ∀ s : ℂ,
      (1/2 + ε ≤ s.re) → (2 ≤ |s.im|) →
      c / |s.im| ^ A ≤ ‖riemannZeta s‖
```

**Consumer:** `LowerBound.lean:436` — only invoked when `A < B_ε = 40(3-2ε)/ε`

---

## 2. CATHEDRAL INFRASTRUCTURE (Already Proved, Zero Sorry)

### Disk Geometry — `DiskBounds.lean` (348 lines, 0 sorry)

| Theorem | Line | What It Gives Us |
|---------|------|-----------------|
| `rh_zeta_ne_zero` | 41 | Under RH, ζ(s) ≠ 0 for Re(s) > 1/2, s ≠ 1 |
| `zeta_sub_one_norm_le_three_fourths` | 61 | ‖ζ(s)-1‖ ≤ 3/4 for Re(s) ≥ 2 → anchor ‖ζ(s₀)‖ ≥ 1/4 |
| `zeta_mem_slitPlane_of_re_ge_two` | 141 | ζ(s) ∈ slitPlane for Re(s) ≥ 2 |
| `s_ne_one_on_disk` | 148 | s₀ + z ≠ 1 for z ∈ ball(0,R), |t| ≥ 2, R < 3/2 |
| `re_gt_half_on_disk` | 169 | Re(s₀+z) > 1/2 on the disk |
| **`holomorphic_log_exists_on_ball`** | 188 | **KEY**: Constructs G with f(z) = f(0)·exp(G(z)), G(0)=0 |
| `zeta_norm_bound_on_disk` | 275 | ‖ζ(s₀+z)‖ ≤ (2+\|t\|)^10 on ball |

> [!IMPORTANT]
> `holomorphic_log_exists_on_ball` is the crown jewel — it constructs the holomorphic
> logarithm via primitive integration, completely bypassing branch cuts. This is exactly
> what the BC blitzkrieg needs.

### Convexity Bound — `ConvexityBound.lean` (0 sorry)

| Theorem | What It Gives Us |
|---------|-----------------|
| `zeta_norm_convexity_bound` | ‖ζ(s)‖ ≤ (2+\|s.im\|)² for 1/2 < Re(s) ≤ 2 |

### Lower Bound Assembly — `LowerBound.lean` (439 lines, 0 sorry in file)

| Component | Status | Lines |
|-----------|--------|-------|
| `bc_inner_bound` | ✅ PROVED | 107-241 |
| Case A ≥ B_ε | ✅ PROVED | 299-420 |
| Case A < B_ε | ❌ Delegates to axiom | 421-436 |

> [!NOTE]
> The **entire BC pipeline is already built**. The ONLY gap is line 436:
> `exact Cathedral.Zeta.Hadamard.thin_strip_lower_bound_exists hRH ε hε hε1 A hA`

### Hadamard (Three-Circles) — `Hadamard.lean` (275 lines)

| Component | Status |
|-----------|--------|
| `exp_mapsTo_annulus` | ✅ Proved |
| `hadamard_three_circles` | ✅ Proved (from Three-Lines via exp) |
| `rh_zeta_lower_bound_from_zero_counting` | ❌ **THE AXIOM** |
| `thin_strip_lower_bound_exists` | Trivial wrapper around axiom |

---

## 3. MATHLIB v4.29 TOOLS

### Direct BC Support
| Tool | Location | Relevance |
|------|----------|-----------|
| `Complex.borelCaratheodory_zero` | `Analysis.Complex.BorelCaratheodory` | Direct BC bound (already used in LowerBound!) |
| `differentiableAt_riemannZeta` | `NumberTheory.LSeries.RiemannZeta` | ζ differentiable for s ≠ 1 |
| **`riemannZeta_residue_one`** | `NumberTheory.LSeries.RiemannZeta:217` | **(s-1)·ζ(s) → 1 at s=1** — KEY for meromorphy |
| `riemannZeta_one_sub` | `NumberTheory.LSeries.RiemannZeta:154` | Functional equation |
| `riemannZeta_ne_zero_of_one_le_re` | `NumberTheory.LSeries.Nonvanishing` | ζ ≠ 0 for Re(s) ≥ 1 |
| `riemannZeta_two` | `NumberTheory.LSeries.HurwitzZetaValues:214` | ζ(2) = π²/6 |

### Meromorphic API (NEW in v4.29)
| Tool | What It Does |
|------|-------------|
| `MeromorphicAt f x` | ∃ n, AnalyticAt ((· - x)^n • f) x |
| `AnalyticAt.meromorphicAt` | Analytic → Meromorphic (n=0) |
| `MeromorphicAt.mul` | Product of meromorphic functions |
| `MeromorphicAt.div` | Quotient of meromorphic functions |
| `meromorphicOrderAt` | Order of pole/zero |
| `divisor f U` | Divisor of meromorphic function |

### Jensen's Formula (available but may not be needed)
| Tool | What It Does |
|------|-------------|
| `MeromorphicOn.circleAverage_log_norm` | Full Jensen's Formula |
| `logCounting` | Zero/pole counting function |

---

## 4. KEY MATHEMATICAL OBSERVATIONS

### 4a. The Exponent Gap (Critical Issue)

The axiom demands `∀ A > 0, ∃ c > 0`. The BC proof gives a FIXED exponent C_ε.

- For A ≥ C_ε: ✅ c/|t|^A ≤ c/|t|^{C_ε} ≤ |ζ| (monotonicity)
- For A < C_ε: ❌ c/|t|^A > c/|t|^{C_ε}, can't bootstrap

**This means the BC Blitzkrieg alone cannot fully graduate the axiom.** We need additional machinery for small A.

### 4b. What "Small A" Actually Means

The axiom says: for small A (gentle polynomial decay), ζ BARELY decays.
This is a STRONG statement about ζ being far from zero.

Under RH, the truth is: log|ζ(σ+it)| = O(log t) for σ > 1/2.
The constant depends on σ-1/2. So for fixed ε:
- |ζ(1/2+ε+it)| ≥ |t|^{-C(ε)} for SOME C(ε)
- The axiom asks for c/|t|^A for ANY A — this is EQUIVALENT to the existence
  of SOME polynomial bound (just choose c appropriately)

**Wait — IS it equivalent?** If |ζ| ≥ c₀/|t|^{C_ε} and we want c/|t|^A with A < C_ε:
- For |t| = 2: c ≤ c₀ · 2^{A-C_ε} (computable, positive)
- For |t| → ∞: c ≤ c₀ · |t|^{A-C_ε} → 0

**So there is genuinely no fixed c that works for all |t| ≥ 2 when A < C_ε.**

### 4c. The Real Resolution

The axiom as stated requires the zero-counting argument. BUT:

**Do the downstream consumers actually need the full axiom?**

The only consumer is `LowerBound.lean:436` in the `A < B_ε` case. And
`zeta_polynomial_lower_bound_rh_proved` is called from:

```
MainChain.lean:181 — #print axioms includes rh_zeta_lower_bound_from_zero_counting
```

**If we reformulate to use the weaker existential bound (∃ A, ∃ c, ...) instead of
(∀ A, ∃ c, ...), we might be able to close it entirely with BC.**

---

## 5. STRATEGIC ASSESSMENT

### Option A: Reformulate + BC (Fastest, ~500 lines)
1. Change the axiom to: ∃ C > 0, ∃ c > 0, ... (existential A)
2. Prove via existing BC infrastructure
3. Verify all downstream consumers only need the existential form
4. **Risk**: Consumers may need the universal form

### Option B: Full Zero-Counting (Correct, ~2000 lines)
1. Prove N(T) = O(T log T) via Argument Principle
2. Estimate the zero sum under RH
3. **Risk**: Heavy; Argument Principle application to ξ(s) needs careful contour work

### Option C: BC + Functional Equation Trick (Medium, ~800 lines)
1. Use BC to get |ζ| ≥ c/|t|^{C_ε} (ALREADY DONE)
2. Use functional equation: ζ(s) = χ(s)·ζ(1-s̄)
3. For σ ≥ 1/2+ε: 1-σ̄ has Re = 1-σ ≤ 1/2-ε
4. Under RH: ζ(1-s̄) ≠ 0, and |ζ(1-s̄)| is bounded below by the Euler product
5. χ(s) has known Stirling asymptotics: |χ(σ+it)| ~ (|t|/2π)^{1/2-σ}
6. So |ζ(σ+it)| = |χ(σ+it)|·|ζ(1-σ-it)| 
7. **Problem**: This only works for σ < 1 (functional equation domain)

### Option D: Phase 1 Only + Defer (Safest)
1. Create `ZetaMeromorphic.lean` (architectural win regardless)
2. Verify that BC Blitzkrieg can prove the ∃C bound
3. Analyze downstream consumers for exact requirements
4. Decide on axiom reformulation vs zero-counting based on findings

---

## 6. RECOMMENDATION

**Start with Option D (Phase 1 + analysis), then decide.**

Phase 1 deliverables (regardless of strategy):
- `riemannZeta_meromorphicAt` for all s (using `riemannZeta_residue_one`)
- `riemannZeta_meromorphicOn` on Set.univ
- Verify exact downstream requirements of the axiom

This gives us the architectural win AND the information needed to choose the optimal
path for Phase 2.

---

## 7. FILE INVENTORY

| File | Lines | Sorry | Status | Relevance |
|------|-------|-------|--------|-----------|
| `Zeta/DiskBounds.lean` | 348 | 0 | ✅ | Disk geometry, hol log, upper bounds |
| `Zeta/ConvexityBound.lean` | ~220 | 0 | ✅ | ‖ζ‖ ≤ (2+\|t\|)² |
| `Zeta/LowerBound.lean` | 439 | 0 | ✅* | BC assembly (*delegates to axiom) |
| `Zeta/Hadamard.lean` | 275 | 1 axiom | ❌ | Three-Circles + THE AXIOM |
| `Zeta/Convexity.lean` | ~350 | 1 sorry | ✅ | Convexity + rh_zeta_ne_zero |
| `Zeta/TailBound.lean` | ~100 | 0 | ✅ | Euler product tail |
| `Zeta/DirichletSeries.lean` | ~200 | 0 | ✅ | Dirichlet series basics |
| `Zeta/DirichletInverse.lean` | ~100 | 0 | ✅ | ζ ≠ 0 for Re > 1 |

---

*"Know your arsenal before you charge."*
