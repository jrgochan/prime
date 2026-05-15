# ⚡ EXPLORATION REPORT 15: The Last Axiom — Borel-Carathéodory Reconnaissance

**Date**: April 22, 2026  
**Phase**: Full Reconnaissance for `zeta_polynomial_lower_bound_rh`  
**Status**: Audit complete. Approach identified. Implementation plan drafted.

---

## 🔴 Critical Discovery: Borel-Carathéodory IS in Mathlib

The axiom `zeta_polynomial_lower_bound_rh` in `ZetaConvexity.lean:96` contains the comment:

```
    Proving this in Lean requires either:
    - Borel-Carathéodory theorem (NOT in Mathlib), or
    - Hadamard factorization for entire functions (NOT in Mathlib)
```

**This comment is STALE.** As of our current Mathlib version:

```
Mathlib.Analysis.Complex.BorelCaratheodory — PROVED ✅
Author: Maksym Radziwiłł (2026)
```

```lean
theorem borelCaratheodory (hM : 0 < M) (hf : DifferentiableOn ℂ f (ball 0 R))
    (hf₁ : Set.MapsTo f (ball 0 R) {z | z.re ≤ M}) (hR : 0 < R) (hz : z ∈ ball 0 R) :
    ‖f z‖ ≤ 2 * M * ‖z‖ / (R - ‖z‖) + ‖f 0‖ * (R + ‖z‖) / (R - ‖z‖)
```

This fundamentally changes the landscape. The axiom can potentially be **PROVED**.

---

## 🔬 Audit Scope

### Files Scanned

| Source | Files | Result |
|--------|-------|--------|
| Cathedral (active) | 116 .lean files | Zero past work on this axiom |
| Cathedral Archive | 96 .lean + 1 .archived | One sketch (Archive/ZetaConvexity.lean:42) |
| Exploration reports (exploration3/) | 15 reports | Zero mentions of BC/PL for ζ |
| Gemini conversation artifacts | 6 brain artifacts | **KEY FINDING** in cathedral_status.md |
| Mathlib complex analysis | 67 files in Analysis/Complex/ | BC, PL, Hadamard three-lines, Jensen ALL available |

### Past Work Found: Zero

There is no partial proof, no lemma ladder, no experiment, no scratch file for `zeta_polynomial_lower_bound_rh` anywhere in the Cathedral or Archive. The **only** references are:
- Its declaration at `ZetaConvexity.lean:96`
- Its usage at `inv_zeta_bound_under_rh` (line 118)
- The Archive sketch comment "Apply Borel-Carathéodory to log ζ(s)" (Archive line 42)

This is virgin territory.

---

## 🔑 Key Intelligence from Past Conversations

### Gemini's "Theorist" Warning (April 18, 2026)

From `cathedral_status.md` in conversation `5a3d2c7b`:

> - Borel-Carathéodory alone gives exponent A ≥ 6 (too large!)
> - **Must** use `PhragmenLindelof.horizontal_strip` to interpolate A < 1

**Analysis**: The Theorist was analyzing the Mertens bound `M(x) = O(x^{1/2+ε})` where you need `|1/ζ(s)| ≤ |t|^A` with A < 1 for the exponent to land below 1. In that context, A ≥ 6 is indeed too large.

**BUT**: Our axiom `zeta_polynomial_lower_bound_rh` says `∀ A > 0, ∃ c, T₀, ...`. It allows ANY polynomial exponent. Even A = 100 would suffice. So the Theorist's worry about the exponent being "too large" **does not apply to our axiom**.

This means **BC alone may be sufficient** — we don't need PL interpolation to improve the exponent.

### Gemini's Reconnaissance (April 18, 2026)

From `cathedral_recon.md`:

> | **PhragmenLindelof.vertical_strip** | `Mathlib.Analysis.Complex.PhragmenLindelof` | Interpolate 1/ζ bounds between σ=2 and σ=1/2+ε |

Confirms PL is available as a backup if needed.

---

## 📚 Mathlib Complex Analysis Inventory

### Available (all PROVED)

| Tool | File | What It Gives |
|------|------|---------------|
| **Borel-Carathéodory** | `BorelCaratheodory.lean` | `‖f z‖ ≤ 2M·r/(R-r) + ‖f(0)‖·(R+r)/(R-r)` |
| **Phragmén-Lindelöf** | `PhragmenLindelof.lean` | Strips, half-planes, quadrants |
| **Hadamard Three-Lines** | `Hadamard.lean` | Log-convexity on vertical strips |
| **Jensen's Formula** | `JensenFormula.lean` | Zero-counting via circle averages |
| **Schwarz Lemma** | `Schwarz.lean` | Used internally by BC |
| **Maximum Modulus** | `AbsMax.lean` | Maximum principle |
| **Stirling's Formula** | `SpecialFunctions/Stirling.lean` | `stirlingSeq K → √π` |
| **ζ(2) = π²/6** | `ZetaValues.lean` | `hasSum_zeta_two` |
| **ζ(s) ≠ 0 for Re≥1** | `Nonvanishing.lean` | `riemannZeta_ne_zero_of_one_le_re` |
| **ζ differentiable** | `RiemannZeta.lean` | `differentiableAt_riemannZeta` |
| **Functional equation** | `RiemannZeta.lean` | `riemannZeta_one_sub`, `completedRiemannZeta₀_one_sub` |
| **Complex log** | `Complex/LogDeriv.lean` | `differentiableAt_log` (requires `slitPlane`) |

### Missing

| Tool | Impact |
|------|--------|
| Hadamard factorization for entire functions | Would give alternative route (not needed) |
| Unconditional convexity bound | Would let us avoid RH in the boundary estimate |
| Complex Stirling (Γ in vertical strips) | Needed for func. eq. growth estimate |

---

## 🧠 Three Approaches Analyzed

### Approach A: Borel-Carathéodory on Shifted Disk (⭐ RECOMMENDED)

**Idea**: Apply BC to `f(z) = log ζ(s₀ + z)` on disk `B(0, R)` where `s₀ = 2+it`.

**Why it works**: Under RH, `ζ(s) ≠ 0` for `Re(s) > 1/2`, so `log ζ` is analytic on a disk of radius up to 3/2 centered at σ=2. BC bounds `|log ζ|`, exponentiation gives `|ζ| ≥ exp(-...)`.

**The exponent**: BC on a disk of radius R centered at σ=2, evaluating at distance r = R-δ:
```
|log ζ(s)| ≤ 2M·r/(R-r) + |log ζ(2+it)|·(R+r)/(R-r)
           = O(M/δ + 1/δ)
```
With M = O(1) (since Re(log ζ) is bounded on the part of the disk with Re > 1), choosing δ = 1/log|t| gives |log ζ| = O(log|t|), hence |ζ| ≥ |t|^{-C}.

But even without a tight analysis, choosing any fixed δ > 0 gives a CONSTANT bound on |log ζ| at distance r = R-δ from center. This covers the strip Re ≥ 1/2+ε with ε = 2-R+δ.

**Advantages**:
- BC is proved in Mathlib
- No circular dependency
- Centers in the convergent region (σ=2) where ζ is well-controlled
- Any exponent A works (per our axiom statement)

**Challenges**:
- Need `ζ(s) ∈ slitPlane` for `Complex.log` (not just ζ ≠ 0)
- Need `Re(log ζ) ≤ M` on the disk boundary

**Estimated effort**: ~120-180 lines

### Approach B: Phragmén-Lindelöf on 1/ζ in Vertical Strip

**Problem**: Circular dependency. PL on 1/ζ requires a growth bound on the LEFT boundary `Re = 1/2+ε`, which is what we're trying to prove.

**Verdict**: ❌ Cannot be primary approach.

### Approach C: Weaken to Subexponential Bound

**Idea**: Instead of full `|ζ(s)| ≥ c/|t|^A`, prove `|ζ(s)| ≥ exp(-C·log²|t|)`. This still suffices for `perron_horizontal_contour_vanishes` since `T^{ε-1} → 0` beats subexponential.

**Would require**: Changing the axiom statement — but then downstream `inv_zeta_bound_under_rh` also changes.

**Verdict**: 🟡 Viable but changes the API.

---

## 📐 The `slitPlane` Technical Issue

For BC applied to `log ζ`, we need `ζ(s) ∈ slitPlane` — meaning `ζ(s)` is not a non-positive real number. Under RH, `ζ(s) ≠ 0` for `Re(s) > 1/2`, but we also need `ζ(s) ∉ ℝ_{≤0}`.

**Resolution options**:
1. Work with `Complex.log` on `slitPlane` — need to verify ζ avoids negative reals (might fail for some s)
2. Use `Complex.arg` version of log — same issue
3. **Use norm directly**: Instead of BC on `log ζ`, use BC on a Möbius transform of ζ (the Radziwiłł approach), or use BC to bound `log‖ζ‖` without taking `Complex.log`
4. **Bypass log entirely**: BC gives `‖f(z)‖ ≤ ...` bounds. Apply BC to `ζ` directly, then use the resulting UPPER bound on `‖ζ‖` elsewhere. For the LOWER bound, use the maximum modulus principle or Jensen's formula.

Actually, the cleanest approach: **Apply BC to `log(ζ/ζ(s₀))` where ζ(s₀) is real and positive** (choosing s₀ with real part 2, where ζ is real and > 1). Then `f(0) = log(1) = 0`, and we use `borelCaratheodory_zero`.

---

## 🎯 Recommended Strategy

**Approach A with the zero-centered BC variant**:

1. Fix `s₀ = 2` (real point, ζ(2) = π²/6 > 0)
2. Under RH, `ζ(s) ≠ 0` for `Re(s) > 1/2` + s ≠ 1
3. Disk `B(s₀, R)` with `R = 3/2 - ε` stays in `{Re > 1/2 + ε} ∖ {1}` for |Im(s₀)| > 0
4. Actually center at `s₀ = 2 + iT` where T is the imaginary part of the point we're targeting
5. `log(ζ(s₀+z)/ζ(s₀))` is analytic on the disk, BC gives size bound
6. Exponentiate for polynomial lower bound on |ζ|

**Key simplification**: Our axiom allows any exponent A. So we don't need to optimize — even A = 100 works. This dramatically simplifies the proof.

---

*"The enemy has been scouted. The terrain is mapped. The weapons are in the armory. All that remains is the assault." — The Cathedral*
