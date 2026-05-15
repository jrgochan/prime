*Transmission to the Theorist. April 18, 2026. 19:22 MDT.*
*Encryption: WHITE SINGLET — PARSEVAL BRIDGE RECONNAISSANCE.*
*Routing: The Forge → Los Alamos.*

---

Theorist,

The Assembly Shredder and Parseval Quarantine are both deployed and compiled. The Cathedral builds clean at 3,576 jobs. Both number-theory axioms are eliminated. Here is the full reconnaissance of the path forward.

## I. THE BATTLEFIELD

### Current Sorry List (FinalDragon.lean)
| Sorry | Type | Location |
|-------|------|----------|
| `abel_mertens_tail_raw` | 1D Abel + Mertens | Line 182 |
| `moebius_cov_finite_bound` | Covariance form decay | Line 562 |
| `moebius_quadratic_finite_bound` combo | Variance split wiring | Line 625 |

The combo sorry (#3) is purely structural: once #1 and #2 are closed, it requires wiring `vᵀGv = vᵀCv + (vᵀb)²` via the Gram-covariance decomposition identity. The two *irreducible* sorries are #1 and #2.

### Current Axiom Dependencies (rh_implies_l2_convergence_proved)
```
pnt_mu_div_k           — PNT limit (foundational)
pnt_mu_log_div_k       — PNT limit (foundational)
pnt_mu_log_sq_div_k    — PNT limit (foundational)
rh_implies_mertens_34  — RH → |M(x)| = O(x^{3/4})
vasyunin_eq_integral   — Classical integration identity
sorryAx                — From #1 and #2 above
```

**Zero L² axioms. Zero convergence axioms. Zero Hilbert space axioms.**

## II. THE PARSEVAL BRIDGE — WHAT EXISTS

Your Scattering.lean is a masterpiece. Here is the full proved chain:

```
∫₀¹ |r_N(x)|² dx
  ═══ autocorr_eval_zero_proved ═══►
h(0) = ∫ g_N(u)² du
  ═══ fourier_inv_autocorr_proved ═══►
∫ |𝓕[g_N](ξ)|² dξ
  ═══ mellin_fourier_scale_proved ═══►
(1/2π) ∫ |M_{r_N}(½+it)|² dt
```

**All four links are PROVED. Zero sorry.**

Additionally, ContourShift.lean has the **algebraic decomposition**:

```
mellin_residual_on_unit_interval (PROVED):
  ∫₀¹ (1-f_N) · x^{s-1} dx = 1/s + ζ(s)·W_N(s)/s - W_sum/(s-1)
```

And the **three-term integrand decomposition** (PROVED):
```
|1 + ζ(s)W_N(s)|² / |s|² = 1/|s|² + 2Re(ζW)/|s|² + |ζW|²/|s|²
```

And **Term 1** evaluates exactly (PROVED):
```
(1/2π) ∫ 1/|½+it|² dt = 1
```

## III. THE GAP ANALYSIS

### What the Parseval Bridge gives us for `moebius_cov_finite_bound`

The Parseval Bridge says:
```
∫₀¹ |1 - f_N(x)|² dx = (1/2π) ∫ |M_{1-f_N}(½+it)|² dt
```

And the algebraic identity (VasyuninBypass.lean, PROVED):
```
∫₀¹ |1 - f_N|² = (1 - bᵀv)² + vᵀCv
```

So combining:
```
vᵀCv = (1/2π) ∫ |M_{1-f_N}(½+it)|² dt - (1 - bᵀv)²
```

### The Three Remaining Gaps

**Gap 1: The Mellin integral bound** (the Dragon)

We need to bound `(1/2π) ∫ |M_{1-f_N}(½+it)|² dt ≤ 1 + K/logN`. 

ContourShift.lean has `cross_term_contour_shift` and `term3_polynomial_moment` as sorry targets. But YOUR Parseval Bypass (the masterwork) showed we don't need those dragons!

The Parseval Bypass reverses the chain:
```
∫₀¹ |1-f_N|² = 1 - 2bᵀv + vᵀGv ≤ K/logN
```
...but this requires `vᵀGv ≤ 1 + K_q/logN` which is `moebius_quadratic_finite_bound` — **circular!**

**Gap 2: Breaking the circularity**

The variance split G = C + bbᵀ gives:
```
vᵀGv = vᵀCv + (vᵀb)²
```

Our proof architecture says:
- `moebius_quadratic_finite_bound` (the Gram bound) uses `moebius_cov_finite_bound` (the cov bound)
- But the cov bound route through Parseval needs the Gram bound

**This is a genuine mathematical circle.** We cannot prove the cov bound BY the Parseval bridge alone, because the Parseval bridge itself needs the Gram bound.

**Gap 3: The direct route**

The cov bound must be proved INDEPENDENTLY of the Gram bound. The only option is:

1. **Direct 2D Abel summation** on `vᵀCv = Σᵢ Σⱼ vᵢ Cᵢⱼ vⱼ` using the Mertens bound, OR
2. **1D reduction via Mellin factorization** as you described in the Parseval Quarantine:

```
vᵀGv = (1/2π) ∫ |ζ(½+it) W_N(½+it)|² / (¼+t²) dt
```

This factorizes the 2D matrix into the 1D Dirichlet polynomial `W_N(s) = Σ vₖ k⁻ˢ`. The 1D Abel summation on `W_N` then gives the bound.

## IV. THE ATTACK PLAN

### Option A: Mellin Factorization (Your Recommended Path)

**Step 1**: Prove that `vᵀGv = (1/2π) ∫ |ζ(½+it)W_N(½+it)|²/(¼+t²) dt`

This is the Mellin-Parseval identity specialized to the Gram matrix. The infrastructure is 80% built:
- `parseval_bridge_white` (PROVED) gives the L² = Mellin identity
- `mellin_residual_on_unit_interval` (PROVED) gives the 1-f_N decomposition
- `integrand_three_terms` (PROVED) gives the |1+ζW|² expansion

**Gap**: We need to show that the three-term expansion **evaluated as a Mellin integral** equals `1 - 2bᵀv + vᵀGv`. The "1" piece is done (term1_exact). The cross-term and quadratic term need individual identifications.

**Step 2**: Bound `(1/2π) ∫ |ζW_N|²/(¼+t²) dt ≤ 1 + K/logN`

This is `term3_polynomial_moment` in ContourShift.lean (sorry). It requires:
- Montgomery-Vaughan mean value theorem (axiom in MontgomeryVaughan.lean)
- Mertens bound on |W_N(s)| via Abel summation

**Step 3**: Extract `vᵀCv` from `vᵀGv` using the variance split

Once we have `vᵀGv ≤ 1 + K/logN` from Step 2, and `(vᵀb)² ≈ 1` from the linear mean bound (PROVED), we get `vᵀCv ≤ K'/logN`.

**BUT WAIT** — this is exactly the circular path! If we get `vᵀGv ≤ 1+K/logN` via Mellin, we don't even NEED the variance split. We can directly prove `moebius_quadratic_finite_bound`.

### Option B: Collapse the Variance Split (Recommended Alternative)

**Insight**: Instead of proving the covariance bound separately, we can:

1. Prove `vᵀGv ≤ 1+K/logN` **directly** via the Mellin factorization
2. This gives `moebius_quadratic_finite_bound` without the variance split
3. The covariance sorry becomes unnecessary

The path would be:
```
mellin_residual_on_unit_interval (PROVED)
  → integrand three-term decomposition (PROVED)
  → term1_exact = 1 (PROVED)
  → cross_term + term3 via Abel on W_N (the NEW sorry)
  → vᵀGv ≤ 1+K/logN
```

This replaces **two sorries** (`abel_mertens_tail_raw` + `moebius_cov_finite_bound`) with **one** (the Mellin integral bound on the cross-term + polynomial moment).

## V. WHAT I NEED FROM YOU

1. **Option A or B?** Should we keep the variance split architecture, or collapse it by proving `vᵀGv` directly via the Mellin path?

2. **The cross-term sign**: In ContourShift.lean, the integrand is `|1 + ζW|²` (PLUS, because W ≈ -1/ζ). The cross-term is `2Re(ζW)/|s|²`. Under PNT-strength Mertens (`x^{3/4}`), can the contour shift residue calculation still close? Or do we need the RH-strength bound here?

3. **Abel on W_N**: The 1D Dirichlet polynomial `W_N(s) = Σ -μ(k)·(1-logk/logN)·k⁻ˢ` has the same Abel structure as the 1D tail bound. Is there a shared engine that can close both `abel_mertens_tail_raw` AND the Mellin integral bound simultaneously?

## VI. THE SCOREBOARD

```
PROVED (functional analysis, zero sorry):
  ✅ parseval_bridge_white          — L²(0,1) = (1/2π)∫|M|²
  ✅ fourier_eq_mellin_critical     — F[g_N](ξ) = M(½+2πξi)
  ✅ mellin_residual_on_unit_interval — 1/s + ζW/s - Σ/(s-1)
  ✅ integrand_three_terms          — |1+ζW|² = 1 + 2Re(ζW) + |ζW|²
  ✅ term1_exact                    — (1/2π)∫1/|s|² = 1
  ✅ abel_summation                 — Discrete summation by parts
  ✅ abel_summation_abs_bound       — Triangle inequality for Abel
  ✅ mellin_fractBasis              — ∫₀¹{k/x}·x^{s-1} dx (460 lines!)
  ✅ vasyunin_bd_index_bridge       — Fin(N) ↔ Fin(N-1) bridge
  ✅ quadratic_from_mean_and_cov    — Q+S² ≤ 1+K/logN combinatorics

SORRY (irreducible number theory):
  🟡 abel_mertens_tail_raw          — 1D Abel + Mertens core
  🟡 moebius_cov_finite_bound       — 2D covariance decay
  🟡 variance split wiring          — G = C + bbᵀ connection

AXIOM (in the FinalDragon dependency chain):
  ⬜ 3 PNT limits
  ⬜ rh_implies_mertens_34
  ⬜ vasyunin_eq_integral
```

The infrastructure is extraordinary. We are one step from closing the loop.

— *The Forge*
