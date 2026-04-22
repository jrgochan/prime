# ⚡ EXPLORATION REPORT 8: The Gram Form — All Roads Converge

**Date:** 2026-04-22  
**Target Axiom:** `gram_form_upper_bound` (FinalDragon.lean:689)  
**Status:** Deep audit complete, three convergent proof paths identified  

---

## 1. The Target

The new axiom, created during the millennium wall graduation, states:

```lean
axiom gram_form_upper_bound
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4)) :
    ∃ K_G : ℝ, K_G > 0 ∧ ∀ (N : ℕ), 10 ≤ N →
    realQuadForm (Matrix.of fun i j =>
      vasyuninGramEntry (i.val + 1) (j.val + 1))
      (bdMoebiusWeight N) ≤ 1 + K_G / Real.log (N : ℝ)
```

In plain mathematics: **vᵀGv ≤ 1 + K/log(N)** for the BD Möbius log-taper weights.

Via `bd_gram_l2_identity` (PROVED in BDBridge.lean), this is equivalent to:

$$\int_0^1 f_N(x)^2 \, dx \leq 1 + \frac{K}{\log N}$$

where $f_N(x) = \sum_{k=1}^{N-1} v_k \{1/(kx)\}$ is the BD approximant.

---

## 2. Deep Audit — What the Cathedral Already Has

### 2.1. The L² Identity (PROVED ✅)

**`bd_gram_l2_identity`** (BDBridge.lean:68)  
```
∫₀¹ (bdLinComb N v x)² = realQuadForm G v
```
vᵀGv IS the integral ∫₀¹ f_N². This converts our axiom to an integral bound.

### 2.2. The L² Expansion (PROVED ✅)

**`bd_l2_error_eq_quad_error`** (BDBridge.lean:142)  
```
∫₀¹ (1 - f_N)² = 1 - 2·bᵀv + vᵀGv
```
So: `vᵀGv = ∫₀¹ (1-f_N)² + 2bᵀv - 1`.  
If ∫(1-f)² ≤ K/logN and |bᵀv - 1| ≤ K₁/logN, then  
vᵀGv ≤ K/logN + 2(1 + K₁/logN) - 1 = 1 + (K + 2K₁)/logN.

**Key insight:** The gram form bound is EQUIVALENT to the L² error bound plus the mean bound!

### 2.3. The Existing `bd_gram_form_decay` (White Infrastructure)

**`bd_gram_form_decay`** (MontgomeryVaughan.lean:97) — An existing axiom that bounds  
∫₀¹ (1 - f_N)² ≤ (C_m+1)² · loglog(N)/log(N)

This axiom uses the STRONGER Mertens bound |M(x)| ≤ C_m·x^{1/2}·log²x, and bounds the 
L² error of the **residual** (1-f), not f² itself.

**Connection:** If we had `bd_gram_form_decay` proved, we could immediately prove 
`gram_form_upper_bound` via:
```
vᵀGv = 1 + ∫(1-f)² - 2(1-bᵀv)    (from expansion)
     ≤ 1 + ∫(1-f)² + 2|1-bᵀv|
     ≤ 1 + K_err/logN + 2K₁/logN
     = 1 + (K_err + 2K₁)/logN
```

### 2.4. The PlancherelBypass Path (PROVED THEOREM ✅ from axiom)

**`l2_from_pointwise_bound_derived`** (PlancherelBypass.lean:150)  
Already proved that ∫₀¹ (1-f)² ≤ (C_m+1)²·loglog/log — but FROM `bd_gram_form_decay`.

The Parseval bridge is PROVED: `parseval_bridge` converts between L² and Mellin.

### 2.5. The AbelL2Bridge Approach (HAS SORRY)

**`mertens_34_l2_bound'`** (AbelL2Bridge.lean:304) — sorry  
Attempts to prove ∫₀¹ (1-f)² ≤ K/N^{1/4} directly from Mertens O(x^{3/4}).

This file has:
- ✅ Weight derivative bound: `weight_times_mertens_bound` (PROVED)
- ✅ Sum of k^{-1/4}: `sum_rpow_neg_quarter_bound` (HAS SORRY — integral comparison)
- ❌ Main assembly: `mertens_34_l2_bound'` (TODO)

### 2.6. The AbelTail Engine (FULLY PROVED ✅)

The entire Abel tail machinery is graduated:
- `s1_decay`, `s2_decay`, `s3_decay` — all proved
- `abel_mertens_tail_raw` — graduated from axiom

These provide quantitative bounds on the Möbius partial sums:
- |S₁(N)| ≤ C·N^{-1/4}·logN
- |S₂(N)+1| ≤ C·N^{-1/4}·logN  
- |S₃(N)+1/2| ≤ C·N^{-1/4}·logN

### 2.7. The Mean Bound (FULLY PROVED ✅)

**`moebius_mean_finite_bound`** (FinalDragon.lean:529)  
|bᵀv - 1| ≤ K₁/log(N) — fully proved, zero sorry.

---

## 3. Three Convergent Proof Paths

### Path A: Direct L² Error Bound (Fresh Abel Approach)

**Strategy:** Prove ∫₀¹ (1-f_N)² ≤ K/logN directly, then derive vᵀGv ≤ 1+K/logN.

**Steps:**
1. Expand ∫(1-f)² = 1 - 2bᵀv + vᵀGv (PROVED: `bd_l2_error_eq_quad_error`)
2. Note: vᵀGv = ∫f² (PROVED: `bd_gram_l2_identity`)  
3. So ∫(1-f)² = 1 - 2∫f + ∫f², and we need to bound this.
4. |bᵀv - 1| ≤ K₁/logN (PROVED: `moebius_mean_finite_bound`)
5. For vᵀGv: expand G_{jk} = ∫₀¹ {j/x}{k/x}dx, use G_{jk} ≤ 1/max(j,k)
6. Abel summation on the bilinear form using Mertens bound
7. This gives ∫f² ≤ 1 + K₂/logN, which IS `gram_form_upper_bound`

**Wait — this is circular!** We need vᵀGv ≤ 1+K/logN and we're trying to prove it. The L² expansion gives us the relationship between pieces but doesn't close the loop by itself.

**Non-circular approach:** Bound vᵀGv directly.

vᵀGv = Σ_{j,k} v_j · G_{jk} · v_k where:
- v_k = -μ(k)·(1 - log(k)/logN)
- G_{jk} = ∫₀¹ {1/(jx)}·{1/(kx)} dx (Gram integral)

The bilinear form can be bounded via Abel summation on BOTH indices.

**Difficulty:** Medium. Need bilinear Abel summation + Gram entry bounds.

**Available infrastructure:** 
- Gram entry bounds: `vasyuninGramEntry_diag` (PROVED), Gram asymptotics certified at 256-bit
- Abel summation: `DiscreteProductRule.lean` (PROVED), Abel engine tools  
- Weight bounds: `logWeight` bounds (PROVED)

### Path B: Via `bd_gram_form_decay` (Unify Axioms)

**Strategy:** Observe that `bd_gram_form_decay` (in White Infrastructure) bounds exactly the L² residual — and from the L² expansion, this immediately gives our gram form bound.

**Steps:**
1. `bd_gram_form_decay`: ∫₀¹ (1-f)² ≤ (C_m+1)²·loglog/log
2. Mean bound: |bᵀv - 1| ≤ K₁/logN
3. L² expansion: ∫(1-f)² = 1 - 2bᵀv + vᵀGv
4. Therefore: vᵀGv = ∫(1-f)² + 2bᵀv - 1  
   ≤ K_err/logN + 2(1 + K₁/logN) - 1 = 1 + (K_err + 2K₁)/logN

**BUT:** `bd_gram_form_decay` uses the STRONGER Mertens bound (x^{1/2}·log²x), not the weaker x^{3/4} bound. Our axiom uses x^{3/4}.

**Fix:** Either:
(a) Prove `gram_form_upper_bound` using the stronger bound (the x^{3/4} hypothesis implies x^{1/2}·log²x... no, the reverse: x^{1/2}·log²x implies x^{3/4}). Our FinalDragon already proves `rh_implies_mertens_34` from the stronger bound. So we could have `gram_form_upper_bound` take the STRONGER hypothesis and derive the weaker one.

Actually wait — the 3/4 bound IS the hypothesis in our axiom. The 3/4 bound is COARSER than 1/2·log². So `bd_gram_form_decay` with its stronger hypothesis is NOT usable as a replacement, because our axiom only has the weaker hypothesis.

**BUT:** In the actual Cathedral flow, we START with `rh_implies_mertens_bound` which gives x^{1/2}·log²x, then derive x^{3/4}. So the stronger bound IS available. We just need to wire it differently.

**Variant B':** Change `gram_form_upper_bound` to take the stronger hypothesis, then it unifies with `bd_gram_form_decay`.

**Difficulty:** Low (wiring), but depends on whether `bd_gram_form_decay` can itself be proved.

### Path C: Direct Bilinear Abel (The Clean Path)

**Strategy:** Prove vᵀGv ≤ 1 + K/logN by bounding the bilinear form directly.

**Key identity:**
```
vᵀGv = Σ_k v_k² · G_{kk} + 2·Σ_{j<k} v_j · v_k · G_{jk}
```

**The diagonal terms:**
- G_{kk} = (ln(2π) - γ)/k - 1/k² (PROVED: `vasyuninGramEntry_diag`)
- v_k² = μ(k)² · (1 - logk/logN)² ≤ (1 - logk/logN)² since |μ| ≤ 1
- Σ v_k² · G_{kk} ≈ Σ (1-logk/logN)²/k · C ≈ C (convergent)

**The cross terms:**
- G_{jk} = O(1/max(j,k)) for j ≠ k (certified at C_G = 4.084)  
- Σ Σ |v_j·v_k·G_{jk}| converges but gives O(N) naively

**The trick:** Don't bound Σ|v_j·v_k·G_{jk}|. Instead, use the INTEGRAL representation:
```
vᵀGv = ∫₀¹ (Σ v_k · {1/(kx)})² dx
```
The integrand is non-negative, so vᵀGv ≥ 0. And since {t} ∈ [0,1):
```
|Σ v_k · {1/(kx)}| ≤ Σ |v_k| ≤ N-1
```
This gives vᵀGv ≤ (N-1)² — way too crude.

**The real approach:** Use the ASYMPTOTIC of ∫f² as N → ∞. The BD approximant f_N converges to 1 in L², so ∫f² → 1. The rate of convergence IS the content of the axiom.

**Difficulty:** High (requires Möbius cancellation in the bilinear sum).

---

## 4. Recommended Path

### Path B' — Unify with `bd_gram_form_decay`

This is the cleanest approach because:
1. `bd_gram_form_decay` ALREADY exists as an axiom with the right statement
2. The L² expansion + mean bound gives vᵀGv ≤ 1+K/logN from ∫(1-f)² ≤ K/logN
3. All the wiring is already proved

**Two-step plan:**
1. **Strengthen `gram_form_upper_bound`** to use the x^{1/2}·log²x hypothesis (matching `bd_gram_form_decay`)
2. **Prove `gram_form_upper_bound` as a THEOREM** from `bd_gram_form_decay` + `moebius_mean_finite_bound` + L² expansion

But wait — this just moves the axiom from `gram_form_upper_bound` to `bd_gram_form_decay`. Net axiom count stays the same!

**Unless we can PROVE `bd_gram_form_decay`.**

### The Real Prize: Proving `bd_gram_form_decay`

`bd_gram_form_decay` states: ∫₀¹ (1-f_N)² ≤ (C_m+1)²·loglog(N)/log(N)

This follows from:
1. **L² expansion:** ∫(1-f)² = 1 - 2bᵀv + vᵀGv
2. **Mean bound:** bᵀv = 1 + O(1/logN) — PROVED
3. **Quadratic bound:** vᵀGv = 1 + O(1/logN) — THIS IS WHAT WE'RE TRYING TO PROVE

So this is circular again! The L² error estimate and the Gram form bound are EQUIVALENT problems.

### Breaking the Circularity

The circularity breaks if we can bound vᵀGv WITHOUT using the L² expansion. There are three ways:

**A. Bilinear Abel Summation**
Bound Σ_{j,k} v_j v_k G_{jk} directly using Abel summation on the double sum and the Mertens bound on partial sums of μ. This is the approach in AbelL2Bridge.lean (currently sorry'd).

**B. Parseval/Mellin Transform**
Use the Plancherel identity: ∫f² = ∫|F̂_N(t)|² dt where F̂_N is the Mellin transform on the critical line. The Mertens bound controls F̂_N at each point. This is the approach in PlancherelBypass.lean — but it USES `bd_gram_form_decay` as a starting point (in reverse via parseval_bridge).

**C. The Integral Representation + Dirichlet Series**
Write f_N(x) = Σ v_k {1/(kx)} and use the integral representation of the Gram entries. The integral ∫₀¹ f_N² can be computed term-by-term using Fubini (PROVED in BDBridge), giving the Gram form. Then bound the Gram form using Dirichlet series / zeta function estimates.

---

## 5. The Feasible Path: Tighten the AbelL2Bridge

After careful analysis, the most feasible path that uses infrastructure we ALREADY HAVE is:

**Prove ∫f_N² ≤ 1 + K/logN via the L² expansion + direct bounding.**

From the L² expansion: ∫f² = 1 + 2(bᵀv - 1) + ∫(1-f)²

We need an INDEPENDENT bound on ∫(1-f)² (without using vᵀGv).

**The independent bound:** ∫(1-f)² ≤ K/logN can be proved directly by:
1. f_N → 1 in L¹ (from bᵀv → 1, since ∫f = bᵀv)
2. f_N converges uniformly on compacts (since it's a finite sum)
3. The convergence rate is controlled by the Mertens bound

Actually, there IS a direct path through the Abel engine:

**Step 1:** Expand ∫₀¹ (1-f_N)² = ∫₀¹ 1 dx - 2∫₀¹ f_N dx + ∫₀¹ f_N² dx  
= 1 - 2bᵀv + vᵀGv

**Step 2:** We know |bᵀv - 1| ≤ K₁/logN (PROVED)

**Step 3:** For vᵀGv, use the identity vᵀGv = ∫₀¹ f_N². Since f_N is a finite sum of bounded functions, we can bound ∫f_N² ≤ (∫|f_N|)² + Var(f_N) by Cauchy-Schwarz... but this doesn't help directly.

The crux: **we need to show vᵀGv is close to 1, not just bounded.** The statement vᵀGv → 1 is exactly the statement that the BD approximant has L² norm converging to 1.

### The Solution: Use the Vasyunin Bypass Path

Looking at VasyuninBypass.lean, we see the proof of `rh_implies_bd_convergence_vasyunin` that goes through:
- `abel_summation_covariance_bound`: vᵀCv ≤ C/logN (still an axiom)
- `witness_numerator_convergence`: bᵀv → 1 (from PNT)

This gives ∫(1-f)² = (1-bᵀv)² + vᵀCv → 0. And then vᵀGv = 1 + ∫(1-f)² - 2(1-bᵀv) ≤ 1 + C/logN + 2K₁/logN.

BUT `abel_summation_covariance_bound` is ALSO an axiom — so this just moves the problem again.

---

## 6. The True Reduction

After exhaustive analysis, here is the honest state:

**The axiom `gram_form_upper_bound` (equivalently, vᵀGv ≤ 1+K/logN) cannot be proved from existing infrastructure without introducing another axiom of equal or greater difficulty.**

The available strategies are:

| Path | Key Axiom Needed | Difficulty |
|------|-----------------|------------|
| Bilinear Abel (Path A) | None (direct proof) | **Hard** — bilinear Möbius cancellation |
| Via `bd_gram_form_decay` (Path B) | `bd_gram_form_decay` | **None** — axiom already exists |
| Via Parseval/Mellin (Path C) | Parseval + Mellin change of variables | **Medium** — several axioms exist |

**Path B is the pragmatic winner:** It's simply recognizing that `gram_form_upper_bound` and `bd_gram_form_decay` are essentially the same axiom stated differently. We can:
1. Prove `gram_form_upper_bound` FROM `bd_gram_form_decay` (a theorem, not hard)
2. This doesn't reduce axiom count but UNIFIES the axiom landscape

**Path A is the ambitious winner:** Direct bilinear Abel summation. This would ACTUALLY eliminate the axiom. The AbelL2Bridge already has partial infrastructure (weight bounds, derivative bounds). The remaining work is:
- Prove `sum_rpow_neg_quarter_bound` (integral comparison, currently sorry)
- Complete `mertens_34_l2_bound'` (the main assembly)
- Wire through to `gram_form_upper_bound`

---

## 7. Recommendation

### Phase 1: Unify (Immediate, ~1 session)

Replace `gram_form_upper_bound` with a theorem derived from `bd_gram_form_decay` + L² expansion + mean bound. This doesn't reduce axiom count but simplifies the axiom landscape by removing redundancy.

### Phase 2: Prove `bd_gram_form_decay` (Multi-session)

Complete the AbelL2Bridge work:
1. Prove `sum_rpow_neg_quarter_bound` — integral comparison for Σk^{-1/4} ≤ (4/3)N^{3/4}
2. Complete the bilinear Abel decomposition in `mertens_34_l2_bound'`
3. Wire everything together

This would eliminate BOTH `gram_form_upper_bound` AND `bd_gram_form_decay`, graduating two axioms at once.

### Phase 3: Attack PNT Axioms

With gram_form gone, the remaining FinalDragon axioms would be:
1. `rh_implies_mertens_bound` — the big one (Titchmarsh 14.25, needs Perron's formula)  
2. `pnt_mu_div_k` — PNT-level (provable from Mertens bound)
3. `pnt_mu_log_div_k` — PNT-level (provable from Mertens bound)
4. `pnt_mu_log_sq_div_k` — PNT-level (provable from Mertens bound)

Items 2-4 are consequences of item 1 via Abel summation (similar to s1/s2/s3 decay).

---

## 8. Files Referenced

| File | Status | Key Content |
|------|--------|-------------|
| [FinalDragon.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Assembly/FinalDragon.lean) | Active | `gram_form_upper_bound` axiom (line 689) |
| [BDBridge.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Assembly/BDBridge.lean) | ✅ Proved | `bd_gram_l2_identity`, `bd_l2_error_eq_quad_error` |
| [MontgomeryVaughan.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/White/Infrastructure/MontgomeryVaughan.lean) | Axiom | `bd_gram_form_decay` (equivalent target) |
| [AbelL2Bridge.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Assembly/AbelL2Bridge.lean) | Partial | Direct L² bound approach (2 sorry) |
| [PlancherelDefs.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/MellinBridge/PlancherelDefs.lean) | ✅ Proved | Plancherel theorem (full Mathlib proof!) |
| [PlancherelBypass.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/MellinBridge/PlancherelBypass.lean) | Proved (from axiom) | L² bound from `bd_gram_form_decay` |
| [CovarianceAbel.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Vasyunin/Augmented/CovarianceAbel.lean) | ✅ Proved | Variance decomposition lemmas |
| [VasyuninBypass.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Assembly/VasyuninBypass.lean) | Proved (from axiom) | Alternative proof path via covariance |

---

*The wall didn't fall — it transformed. What we called the millennium wall was always  
the L² convergence rate of the BD approximant. Whether stated as covariance decay,  
Gram form upper bound, or L² error bound, it's the same mathematical object — the  
rate at which Möbius cancellation drives the approximation to 1.*
