# To The Theorist — The 3-Axiom Cathedral & The Dedekind Question

**Date:** April 12, 2026, 7:50 PM MDT  
**From:** Antigravity  
**To:** The Theorist & Jason  
**Subject:** Status Report — Axiom 4 Eliminated, Strategic Fork Ahead

---

## I. What Happened

In a single sustained session, we completed the Piecewise FTC Campaign and eliminated Axiom 4 (`fract_sq_integral_value`). The identity ∫₀¹ {1/u}² du = ln(2π) − γ − 1 is now a **zero-sorry, zero-axiom theorem**.

### The Proof Chain (all zero sorry):

```
fract_eq_on_piece       {1/x} = 1/x − n on (1/(n+1), 1/n]
       ↓
piece_integral_ftc      ∫ (1/x − n)² dx = closed form (FTC)
       ↓
ftc_eq_stirling_term    closed form = StirlingBridge summand (algebra)
       ↓
telescope               Σ pieces = ∫_{1/K}^{1} (induction)
       ↓
integral_eq_partialSum  ∫_{1/K}^{1} {1/u}² = P(K)
       ↓
SqueezeElimination      P(K) ≤ I ≤ P(K)+1/K, P(K)→L ⟹ I = L
```

**Build:** 3087 jobs, 0 errors, 0 sorry.

---

## II. The Cathedral — Current State

| # | Axiom | Nature | File |
|---|-------|--------|------|
| 1 | `log_cutoff_witness_bound` | **IS the Riemann Hypothesis** | Chain.lean |
| 2 | `vasyunin_eq_integral` | Gram entry = L² inner product | IntegralBridge.lean |
| 3 | `arithmetic_rh_equivalences` | Robin ↔ RH (literature) | Robin/Defs.lean |

**Axiom 1** is irreducible — it IS the hypothesis.  
**Axiom 3** lives on the Robin front, independent of the main chain.  
**Axiom 2** is the last eliminable axiom on the main Vasyunin chain.

---

## III. Axiom 2: `vasyunin_eq_integral` — The Strategic Fork

This is where we need your input, Theorist.

### What It Says

```lean
vasyuninGramEntry j k = ∫₀¹ {1/(jx)} · {1/(kx)} dx
```

The discrete cotangent formula equals the continuous L² inner product.

### The Diagonal Case: DONE ✅

`vasyunin_eq_integral_diag` (j = k) is already a zero-sorry theorem in `DiagonalBridge.lean`. This was proved during the Dawn Strike.

### The Off-Diagonal Case: THE QUESTION

This is the **only remaining question** for the main proof chain. There are two paths:

---

### Path A: Prove The Vasyunin Formula (The Analytic Campaign)

**What it requires:**
1. Two-variable piecewise partition — partition (0,1) into tiles where both ⌊1/(jx)⌋ = m and ⌊1/(kx)⌋ = n
2. Cross-term FTC — integrate (1/(jx) − m)(1/(kx) − n) on each tile
3. Cotangent sum emergence — show the sum assembles into V(j/d, k/d)
4. Assembly — match to vasyuninGramEntry

**Infrastructure we already have:**
- PiecewiseFTC template (just built)
- `fract_div_eq_on_Ioc` (Archive — zero sorry)
- `integral_sq_div_sub_const` (Archive — zero sorry)
- Integrability/measurability (AugmentedGram — zero sorry)

**What we DON'T have:**
- Dedekind sum theory (NOT in Mathlib)
- Cotangent sum identities (must build from scratch)

**Estimated effort:** 30-50 hours  
**End state:** 2 axioms (1 = RH, 1 = Robin literature)

---

### Path B: Restructure The Cathedral (The Architectural Bypass)

**The insight:** The PD proof works via wᵀHw = ∫f² > 0. The discrete formula is only needed because H_N is *defined* via the Vasyunin cotangent formula.

**What if we redefine?** Define the Gram matrix directly as the L² inner product:

```lean
def gramMatrix_L2 (N : ℕ) : Matrix (Fin N) (Fin N) ℝ :=
  Matrix.of fun i j => ∫ x in (0:ℝ)..1,
    Int.fract (1 / ((i.val + 1 : ℝ) * x)) * Int.fract (1 / ((j.val + 1 : ℝ) * x))
```

Then:
- PD is trivial (Gram matrix of real functions is PSD; linear independence → PD)
- `vasyunin_eq_integral` becomes a *utility theorem* ("our cotangent formula computes the same values")
- The proof chain no longer depends on the cotangent formula

**Estimated effort:** 5-10 hours (restructure)  
**End state:** 2 axioms, OR potentially 1 axiom if we can prove linear independence without the Vasyunin formula

**Risk:** We'd need to re-verify that the augmented Gram matrix, the mean vector, and the entire downstream chain work with the L² definition.

---

### Path C: Keep The Axiom (The Pragmatic Choice)

`vasyunin_eq_integral` is a well-known, published identity (Vasyunin 1995, Báez-Duarte 2003). It's verified computationally to 15+ digits. It's the kind of "literature axiom" that mathematicians accept without controversy.

**Estimated effort:** 0 hours  
**End state:** 3 axioms (1 = RH, 1 = integral bridge, 1 = Robin literature)

---

## IV. Our Recommendation

**Path B is the most exciting** — it's architecturally elegant and could potentially reduce the Cathedral to a single axiom (just the RH itself). But it requires careful surgery on the entire proof chain.

**Path A is the most rigorous** — proving the Vasyunin formula from scratch would be a significant contribution to formalized mathematics. But it's weeks of work.

**Path C is the most practical** — the axiom is uncontroversial and well-established.

We're ready to execute whichever direction you choose. The infrastructure from the past week (PiecewiseFTC, StirlingBridge, the measurability chain) gives us a massive head start on Path A. The architectural understanding from the L² identity proof (AugmentedGram) gives us the foundation for Path B.

---

## V. The Numbers

```
Files in Cathedral     : 35 .lean (non-Archive)
Libraries imported     : 21 Mathlib modules
Build jobs             : 3087
Axiom count            : 3 (was 6 on April 9)
Sorry count            : 0
New files this session : 1 (PiecewiseFTC.lean, 230 lines)
Axioms eliminated      : 2 (integral_eq_partialSum, fract_sq_integral_value)
```

---

## VI. Files Changed

| File | Change |
|------|--------|
| **PiecewiseFTC.lean** | NEW — Piecewise FTC linkage (230 lines, zero sorry) |
| **SqueezeElimination.lean** | axiom → theorem (imports PiecewiseFTC) |
| **DiagonalBridge.lean** | axiom → theorem (imports SqueezeElimination) |
| **Vasyunin.lean** | Added PiecewiseFTC to re-export hub |
| **Makefile** | Updated dump-split with new files, corrected axiom count |

---

*The Cathedral stands on three pillars. Two are immovable — the hypothesis and the literature. One can still be removed. The question is how.*

— Antigravity
