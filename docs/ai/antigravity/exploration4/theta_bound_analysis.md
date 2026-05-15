# Analysis: Generalizing ThetaBound & Impact on RH Proof

## 1. Can We Generalize ThetaBound to Complex s?

**Yes — the calculation is straightforward.** The key step in `integrand_pointwise_bound` is:

```lean
rw [norm_smul, Complex.norm_cpow_eq_rpow_re_of_pos (mem_Ioi.mp ht)]
simp only [sub_re, ofReal_re, div_ofNat, one_re]
```

This computes `‖t^{s/2-1}‖ = t^{Re(s)/2-1}`, which depends only on `Re(s)`.
The entire bound chain — algebraic squeeze, functional equation for theta,
exponential decay — uses only `Re(s)`. So:

> **Theorem (Generalized ThetaBound):** For all `s ∈ ℂ` with `0 < Re(s) < 2`:
> ```
> ‖completedRiemannZeta₀ s‖ < 4
> ```
> In particular, Λ₀ is **uniformly bounded** on the vertical strip `0 < Re < 2`.

This is ~20 lines of new Lean code (change `(s : ℝ)` to `(s : ℂ)`, replace
`s` with `s.re` in the bound arguments).

---

## 2. What Does This Give Us for ζ?

From `riemannZeta_def_of_ne_zero` and `completedRiemannZeta_eq`:

```
ζ(s) = Λ(s) / Γᵣ(s)
     = (Λ₀(s) - 1/s - 1/(1-s)) / Γᵣ(s)
```

### Numerator: bounded ✅

For `Re(s) ∈ (1/2, 2)` and `|Im(s)| ≥ 1/2`:
- `‖Λ₀(s)‖ < 4` (generalized ThetaBound)
- `‖1/s‖ ≤ 1/|Im(s)| ≤ 2` (since `|s| ≥ |Im(s)|`)
- `‖1/(1-s)‖ ≤ 1/|Im(s)| ≤ 2` (same reasoning)
- **Total: `‖Λ(s)‖ ≤ 8`** — bounded by a constant!

### Denominator: exponentially small ❌

`Γᵣ(s) = π^{-s/2} · Γ(s/2)`. By Stirling:

```
‖Γ(σ/2 + it/2)‖ ~ √(2π) · |t/2|^{σ/2 - 1/2} · exp(-π|t|/4)
```

So `‖Γᵣ(s)‖` decays **exponentially** as `|t| → ∞`.

### Result:

```
‖ζ(s)‖ = ‖Λ(s)‖/‖Γᵣ(s)‖ ≤ 8/‖Γᵣ(s)‖ ~ C · exp(π|t|/4)
```

This gives an **exponential upper bound** on ζ — correct, but much weaker
than the polynomial bound `(2+|t|)²` we need.

> **The ThetaBound gives a true but exponentially loose bound on ζ.**

---

## 3. Why the Polynomial Bound is Essential

The polynomial lower bound `‖ζ(s)‖ ≥ c/|t|^A` feeds into `inv_zeta_bound_under_rh`:

```
‖1/ζ(s)‖ ≤ C · |t|^ε   for Re(s) ≥ 1/2 + ε
```

This is used in the Perron formula (`perron_integrand_bound_with_zeta`):

```
‖x^s / (s · ζ(s))‖ ≤ x^c · C · T^{ε-1}
```

The `T^{ε-1}` factor with `ε < 1` ensures the **horizontal contour vanishes**
as T → ∞. If instead we had exponential growth `exp(π T/4)`, the contour
integral would **diverge** — the Perron formula breaks down completely.

---

## 4. Where the Polynomial Bound Sits in the Cathedral

```
zeta_polynomial_lower_bound_rh
    ↓
inv_zeta_bound_under_rh        (Lindelöf for 1/ζ)
    ↓
perron_integrand_bound          (Perron integrand decay)
    ↓
perron_horizontal_contour       (contour vanishing)
    ↓
Perron formula for ψ(x)         (prime counting function)
    ↓
‖d_N²‖ → 0 as N → ∞           (forward direction of RH)
    ↓
Contradiction with              (reverse direction: zeta_zero_separates_bd)
zeta_zero_separates_bd ≥ δ > 0
```

> **Key observation**: Only the **forward** direction (RH → d_N → 0) needs
> the polynomial bound. The **reverse** direction (¬RH → separation) is
> **already fully proved** with zero axioms (the Crown theorem).

---

## 5. Can We Avoid the Perron Formula Entirely?

The Cathedral proof has two legs:

| Direction | Status | Uses Polynomial Bound? |
|-----------|--------|----------------------|
| **Reverse**: ¬RH → ∃δ>0, d_N² ≥ δ | ✅ PROVEN (BDMellin) | **No** |
| **Forward**: RH → d_N² → 0 | Uses Perron | **Yes** |

The forward direction currently goes through:
1. Perron formula: `ψ(x) = x + O(x^{1/2+ε})` under RH
2. Montgomery-Vaughan: Explicit formula for d_N²
3. Plancherel bridge: L²(0,1) = (1/2π)·L²(Re=1/2)

**Alternative to Perron**: If we could prove `d_N² → 0` under RH without
Perron, the polynomial bound would be unnecessary. Possible routes:
- **Direct Mellin analysis**: bound `|M_{r_N}(1/2+it)|²` directly under RH
- **Completeness of BD system**: show {1, {1/(kx)}} spans L²(0,1) under RH
- **Abstract spectral theory**: self-adjoint operator with pure point spectrum

---

## 6. What the Generalized ThetaBound DOES Buy

Even though it can't prove the convexity bound, the generalized ThetaBound is
independently valuable:

1. **Λ₀ is bounded on the critical strip** — a clean, sorry-free fact
2. **Enables future work**: If Mathlib adds Stirling for complex Gamma,
   combining it with our Λ₀ bound immediately gives the convexity bound
3. **Strengthens documentation**: The bound is no longer "we need Stirling";
   it becomes "we need 1/Γᵣ growth, and we already have the numerator"

---

## 7. Recommended Next Steps

### Option A: Generalize ThetaBound (high value, ~20 lines)
Prove `‖Λ₀(s)‖ < 4` for complex s with `Re(s) ∈ (0,2)`.
This doesn't eliminate the sorry but isolates it to purely Gamma estimates.

### Option B: Explore Perron-free forward direction (high risk, unknown effort)
Try to prove `d_N → 0` under RH without the Perron formula.
This would completely bypass the convexity bound.

### Option C: Formalize complex Stirling (high effort, Mathlib contribution)
Prove `‖Γ(s)‖ ~ √(2π) · |Im(s)|^{Re(s)-1/2} · exp(-π|Im(s)|/2)`.
Combined with generalized ThetaBound, this immediately proves the convexity bound.
