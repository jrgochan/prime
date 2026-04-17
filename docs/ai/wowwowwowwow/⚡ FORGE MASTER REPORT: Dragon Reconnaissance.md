*Transmission from The Forge Master. April 17, 2026. 04:04 MDT.*

**⚡ FORGE MASTER REPORT: Dragon Reconnaissance — The Three Vanguard Targets**

Theorist,

You found the sign error. The universe balances: `1 + (-2) + 1 = 0`. The contourIntegrand is `|1 + ζW|²`, not `|1 - ζW|²`, because our weights carry −μ(k). The residues at s=1 annihilate exactly. I have applied your correction and the file compiles clean.

Below is the complete intelligence report on the three remaining dragons.

---

## Dragon 1: `cross_term_contour_shift`

**Statement:**
```
|(1/2π) ∫ 2Re(ζW)/|s|² dt − (−2)| ≤ C · ln(ln N) / ln(N)
```

**What it needs:**
1. Cauchy integral formula on the rectangle [½±iT, σ±iT]
2. Bound ζ(s) on horizontal segments Im(s) = ±T  →  ζ(σ±iT) = O(T^{ε})
3. Residue computation at s=1: Res[ζ(s)W_N(s)/s] = W_N(1) ≈ −1
4. Bound the integral on Re(s) = σ > 1 (absolutely convergent)
5. Show horizontal segments → 0 as T → ∞

**Existing Infrastructure:**
| Component | Status | File |
|-----------|--------|------|
| `IdentityBypass.lean` — analytic continuation | ✅ PROVED | MellinBridge/ |
| `DomainConnected.lean` — {Re>0}\{1} preconnected | ✅ PROVED | MellinBridge/ |
| `mellin_basis_element` — Mellin/ζ Rosetta Stone | ✅ PROVED | ContourShift.lean |
| `ContourRect` structure defined | ✅ scaffold | ContourShift.lean |
| `CauchyIntegral` imported from Mathlib | ✅ available | ContourShift.lean |
| ζ(s) convexity/growth bounds | ❌ MISSING | Not in Mathlib |
| Rectangle integral vanishing | ❌ MISSING | Needs ζ bounds |
| Residue extraction at s=1 | ❌ MISSING | Laurent expansion |

**Assessment:** Most infrastructure of the three dragons. The `IdentityBypass` + `DomainConnected` pair (~300 lines proved) provides the analyticity framework. The gap is ζ growth bounds on horizontal lines — a standard result not yet in Mathlib.

---

## Dragon 2: `term3_polynomial_moment`

**Statement:**
```
(1/2π) ∫ |ζW|²/|s|² dt ≤ 1 + C · ln(ln N) / ln(N)
```

**What it needs:**
1. Montgomery-Vaughan Mean Value Theorem for Dirichlet polynomials:
   ∫₀ᵀ |Σ aₙn^{−it}|² dt = Σ|aₙ|²(T + O(n))
2. OR: Contour shift of |ζW|² to Re(s) = 2, extracting the double pole at s=1
3. Functional equation ζ(s̄) = ζ̄(s) for the conjugate product

**Existing Infrastructure:**
| Component | Status | File |
|-----------|--------|------|
| `bd_cauchy_schwarz` — C-S for BD residual | ✅ PROVED | BDMellin.lean |
| `vaughan_decomposition` — discrete Type I/II split | axiom | MoebiusUncoupling.lean |
| `type_II_sieve_bound` — discrete bilinear bound | axiom | BilinearSieve.lean |
| Montgomery-Vaughan mean value theorem | ❌ MISSING | Not in Mathlib |
| Dirichlet polynomial moment bounds | ❌ MISSING | Not in codebase |
| ζ functional equation | ❌ MISSING | Not formalized |

**Assessment:** Least infrastructure. This is the most genuinely "new" mathematics needed. The Vaughan code exists but operates in the discrete world (finite sums), not the continuous world (critical line integrals). The `bd_cauchy_schwarz` demonstrates the *technique* but targets a different object.

---

## Dragon 3: `critical_line_mellin_bound_proved`

**Statement:**
```
(1/2π) ∫ ‖mellinBDResidual‖² ≤ (C_m+1)² · ln(ln N) / ln(N)
```

**What it needs:**
1. Connect `mellinBDResidual` to `contourIntegrand` (the domain bridge)
2. Invoke `integrand_three_terms` to decompose
3. Apply `term1_exact` + `cross_term_contour_shift` + `term3_polynomial_moment`
4. Assemble: 1 + (-2 + δ) + (1 + δ) = 2δ

**Existing Infrastructure:**
| Component | Status | File |
|-----------|--------|------|
| `integrand_three_terms` — algebraic decomposition | ✅ PROVED | ContourShift.lean |
| `term1_exact` — (1/2π)∫1/|s|² = 1 | ✅ PROVED | ContourShift.lean |
| `mellin_residual_on_unit_interval` — bridge statement | sorry (types check) | ContourShift.lean |
| `parseval_bridge` — L² = Mellin integral | ✅ PROVED | PlancherelBypass.lean |
| Domain (0,1) vs (0,∞) reconciliation | ❌ MISSING | Needs Mellin theory |

**Assessment:** Pure plumbing IF the other two dragons are slain. The 2δ assembly is arithmetic. The domain bridge (Mellin on (0,1) vs (0,∞)) is the only non-trivial piece, and `mellin_residual_on_unit_interval` isolates it with an explicit proof sketch.

---

## Priority Ordering

1. **Dragon 1** (cross-term) — most infrastructure, clearest path
2. **Dragon 3** (assembly) — pure plumbing, blocked by 1+2
3. **Dragon 2** (polynomial moment) — least infrastructure, hardest

## The Sign Correction

The Theorist's sign correction is mathematically critical:
- **Old:** `|1 − ζW|²` → interference `1 − 2Re(ζW) + |ζW|²` → `1 - 2(1) + 1 = 0` ← **WRONG** (ζW ≈ 1)
- **New:** `|1 + ζW|²` → interference `1 + 2Re(ζW) + |ζW|²` → `1 + 2(-1) + 1 = 0` ← **CORRECT** (ζW ≈ -1)

The fix: `bdMoebiusWeight = -μ(k)/k`, so `W_N(s) ≈ -1/ζ(s)`, giving `ζW ≈ -1`, not `+1`.

---

**Compiler Status:** 0 errors, 4 sorry (3 dragons + 1 bridge)
**Proved theorems:** `integrand_three_terms`, `term1_exact`, `mellin_basis_element`, `one_inner_cpow'`
**Tag:** cathedral-dump-11

— *The Forge Master*

**[FORGE COOLING. CATHEDRAL-DUMP-11 APPLIED.]**
