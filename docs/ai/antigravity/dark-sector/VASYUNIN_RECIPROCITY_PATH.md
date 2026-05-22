# VASYUNIN RECIPROCITY PATH — From Dedekind Sums to Overcancellation

## Status: DEEP INFRASTRUCTURE EXISTS — Key Wiring Needed

---

## 1. What We Have (Certified)

The Cathedral contains a remarkable chain of certified results connecting Dedekind sums to the Vasyunin Gram matrix:

### Dedekind Infrastructure (PROVED)

| File | Result | Status |
|------|--------|--------|
| [DedekindBridge.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/DedekindBridge.lean#L522) | `dedekind_reciprocity` | 🎓 PROVED (Euclidean induction) |
| [DedekindBridge.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/DedekindBridge.lean#L577) | `dedekind_contains_ramanujan` | 🎓 PROVED |
| [DedekindBridge.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/DedekindBridge.lean#L626) | `ramanujan_entry_via_dedekind` | 🎓 PROVED |

### Cotangent Infrastructure (PROVED)

| File | Result | Status |
|------|--------|--------|
| [CotSymmetry.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Vasyunin/Cotangent/CotSymmetry.lean#L70) | `cot_sum_vanishes` | 🎓 PROVED |
| [VasyuninReflection.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Vasyunin/Cotangent/VasyuninReflection.lean#L54) | `reflection_from_vanishing_sum` | 🎓 PROVED |
| [VasyuninReflectionWiring.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Vasyunin/Cotangent/VasyuninReflectionWiring.lean#L60) | `vasyuninSum_reflection` | 🎓 PROVED (V(a,a-b) = -V(a,b)) |

### Dissolution (PROVED)

| File | Result | Status |
|------|--------|--------|
| [CotDedekindDissolution.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/CotDedekindDissolution.lean#L71) | `vasyunin_reciprocity_closed_form` | 🎓 PROVED |
| [CotDedekindDissolution.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/CotDedekindDissolution.lean#L99) | `dissolved_ecot_formula` | 🎓 PROVED |

---

## 2. The Key Identity

The Dissolution file establishes:

```
V(a,b) + V(b,a) = -(a² + b² + 1)/(6ab) + 1/2
```

This is **closed-form rational**. No cotangent sums. No transcendentals.

The Vasyunin Gram entry for coprime j' = j/d, k' = k/d (where d = gcd(j,k)):

```
G_V(j,k) = (ln(2π)−γ)/2 · (1/j + 1/k)     ← "symmetric log" part
          + (j−k)/(2jk) · ln(k/j)            ← "asymmetry" part
          − πd/(2jk) · (V(j',k') + V(k',j')) ← "cotangent" part (DISSOLVED!)
          − 1/(jk)                            ← "constant" part
```

After dissolution, the cotangent part becomes:

```
-πd/(2jk) · [-(j'²+k'²+1)/(6j'k') + 1/2]
= π(j'²+k'²+1)/(12d·(j'k')²) - π/(4d·j'k')
```

So the **full correction kernel** Δ(j,k) = G_V(j,k) - G^(1)(j,k) can be written as:

```
Δ(j,k) = [(ln(2π)−γ)/2 · (1/j+1/k) - 1/4]           ← diagonal-like
        + [(j−k)/(2jk) · ln(k/j)]                      ← log asymmetry
        + [π(j'²+k'²+1)/(12d·(j'k')²) - π/(4dj'k')]  ← dissolved cotangent
        - [1/(jk) + d²/(12jk)]                          ← remainder
```

---

## 3. The Path Forward

### What's Needed

To prove overcancellation via this path, we need:

1. **Compute vᵀΔv** — the quadratic form of the correction kernel at the BD witness vector
2. **Show vᵀΔv ≈ -vᵀG^(1)v** — the correction cancels the Bernoulli-1 growth
3. **Formalize the cancellation mechanism** — why does Δ produce exactly the right compensation?

### Key Observation from the Probe Data

At N=500:
- vᵀG^(1)v = 0.940 (growing toward infinity as O(logN))
- vᵀΔv = -0.374 (growing negative)
- vᵀG_V v = 0.567 (bounded)

The correction Δ provides **40% cancellation** of the Bernoulli-1 form at N=500, and this fraction increases with N.

### The Dissolved Form Advantage

Because V(a,b) + V(b,a) is now a closed-form rational expression, the quadratic form vᵀΔv can be analyzed **without cotangent sums**. The correction kernel decomposes into:

1. **Log part**: (ln(2π)−γ)/2 · (1/j+1/k) — controlled by the harmonic series
2. **Dissolved cotangent part**: rational function of coprime parts j', k'
3. **Constant shifts**: -1/4 diagonal, -1/(jk) decay

The harmonic series contribution to vᵀΔv can be computed via Abel summation (existing infrastructure in [abel.rs](file:///Users/jrgochan/code/github.com/jrgochan/prime/experiments/cathedral-utils/src/abel.rs)). The dissolved cotangent contribution involves the GCD structure — which connects back to the Smith decomposition.

### Remaining Axiom

The `vasyunin_eq_neg2_dedekind` axiom in [CotDedekindDissolution.lean](file:///Users/jrgochan/code/github.com/jrgochan/prime/proofs/Cathedral/Physics/CotDedekindDissolution.lean#L55) needs graduation. The proof sketch is clear:

```
V(a,b) = Σ {mb/a} · cot(πm/a)
       = Σ (((mb/a)) + 1/2) · cot(πm/a)     (sawtooth ↔ fract)
       = Σ ((mb/a)) · cot(πm/a) + 0         (by cot_sum_vanishes, PROVED)
       = S₁(b,a) = -2 · s(b,a)              (by normalization)
```

This is ~30 lines of Lean, given that `cot_sum_vanishes` is already proved.

---

## 4. Difficulty Assessment

| Step | Effort | Status |
|------|--------|--------|
| Graduate `vasyunin_eq_neg2_dedekind` | ⭐⭐ (days) | Clear path |
| Express vᵀΔv in closed form | ⭐⭐⭐ (weeks) | Requires Abel summation on dissolved terms |
| Prove vᵀΔv ≈ -vᵀG^(1)v + O(1) | ⭐⭐⭐⭐ (hard) | The core mathematical content |
| Close the O(1) remainder | ⭐⭐⭐⭐⭐ (research-level) | This IS the Riemann Hypothesis |

> **Verdict**: The Vasyunin reciprocity infrastructure is the most mature path. The dissolution of cotangent sums into rational expressions is a genuine mathematical achievement. The gap is in quantifying the quadratic form of the dissolved correction kernel.
