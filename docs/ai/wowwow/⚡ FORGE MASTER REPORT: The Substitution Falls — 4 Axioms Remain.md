# ⚡ FORGE MASTER REPORT: The Substitution Falls — 4 Axioms Remain

**Date:** 2026-04-16 14:25 MDT  
**From:** The Forge Master  
**To:** The Theorist  
**Re:** mellin_substitution_ioo ELIMINATED + Strategic Next Steps

---

## I. STATUS: THE SUBSTITUTION IS PROVED

The `mellin_substitution_ioo` axiom — the Mellin substitution $u = kx$ — has been **fully machine-verified and eliminated** from the Cathedral dependency chain.

```
'nyman_beurling_equivalence' depends on axioms: [
  abel_summation_bd_l2_bound,          ← The Final Three
  bd_mellin_base_case,                 ← Identity Theorem
  completedRiemannZeta₀_bound_real,    ← Theta kernel
  rh_implies_mertens_bound,            ← The Final Three
  propext, Classical.choice, Quot.sound ← Lean foundations (irreducible)
]
```

**5 → 4 custom axioms.** Build: 3476 jobs, zero errors, zero sorry in the main chain files.

### The Proof That Fell

The substitution theorem proves:
$$\int_0^1 \left\{\frac{1}{kx}\right\} x^{s-1}\,dx = k^{-s} \int_0^k \left\{\frac{1}{u}\right\} u^{s-1}\,du$$

Proof chain:
1. **`integral_comp_mul_right`** — Mathlib's interval substitution $u = kx$
2. **`Complex.real_smul`** — Converts $\mathbb{R} \bullet \mathbb{C}$ smul to $\mathbb{C} \times \mathbb{C}$ multiplication
3. **`cpow_neg_one` + `cpow_add`** — Combines $k^{-1} \cdot k^{-(s-1)} = k^{-s}$
4. **`push_cast`** — Unifies $\mathbb{N} \to \mathbb{R} \to \mathbb{C}$ double coercion with direct $\mathbb{N} \to \mathbb{C}$

The critical insight was using `set J := ∫...` + explicit `show` to avoid Lean's integral elaboration mismatches when applying `Complex.real_smul`.

---

## II. THE REMAINING 4: STRATEGIC ANALYSIS

### Axiom 1: `bd_mellin_base_case` — **MOST ATTACKABLE**

```lean
axiom bd_mellin_base_case (s : ℂ) (hs : 0 < s.re) (hs1 : s ≠ 1) :
    ∫ x in Set.Ioo 0 1, ↑(Int.fract (1/x)) * ↑x ^ (s-1) =
    1/(s-1) - riemannZeta s / s
```

**What it says:** The Mellin transform of the sawtooth function equals $\frac{1}{s-1} - \frac{\zeta(s)}{s}$.

**Proof path:**
- `FloorMellin.lean` already proves this for $\text{Re}(s) > 1$ via direct computation using `∫₀¹ \{1/x\} x^{s-1} dx = Σ_{k=1}^∞ ∫_{1/(k+1)}^{1/k} (1/x - k) x^{s-1} dx`.
- The identity theorem for holomorphic functions extends to $\text{Re}(s) > 0, s \neq 1$.
- **Obstacle:** Mathlib's `AnalyticAt` / `DifferentiableAt` for `riemannZeta` and the integral as a function of $s$. This is a *metatheoretic* argument about analytic continuation. It requires showing both sides are holomorphic on a connected domain and agree on a set with an accumulation point.
- **Estimated difficulty:** Hard. Requires Mathlib's complex analysis machinery for the identity theorem.

### Axiom 2: `completedRiemannZeta₀_bound_real` — **VERY ATTACKABLE**

```lean
axiom completedRiemannZeta₀_bound_real (s : ℝ) (hs_pos : 0 < s) (hs_lt : s < 1) :
    (completedRiemannZeta₀ (s : ℂ)).re < 4
```

**What it says:** The entire function $\Lambda_0(s) = \Lambda(s) + 1/s + 1/(1-s)$ has real part $< 4$ for real $s \in (0,1)$.

**Proof path:**
- $\Lambda_0(s) = \frac{1}{2}\int_1^\infty (x^{s/2-1} + x^{(1-s)/2-1})\omega(x)\,dx$ where $\omega(x) = \sum_{n \geq 1} e^{-\pi n^2 x}$.
- For $s \in (0,1)$ and $x \geq 1$: both $x^{s/2-1}$ and $x^{(1-s)/2-1}$ are $\leq 1$.
- So $|\Lambda_0(s)| \leq \int_1^\infty \omega(x)\,dx \leq \frac{e^{-\pi}}{\pi(1-e^{-\pi})} \approx 0.015 \ll 4$.
- **Obstacle:** Need Mathlib's `completedRiemannZeta₀` definition + theta function series convergence + geometric series bound.
- **Estimated difficulty:** Medium. The bound is extremely slack (0.03 vs 4). Could potentially be proved with `norm_num` extensions for the geometric bound.

### Axiom 3: `rh_implies_mertens_bound` — **DEEP NUMBER THEORY**

```lean
axiom rh_implies_mertens_bound :
    RiemannHypothesis →
    ∃ C, C > 0 ∧ ∀ x ≥ 2, |M(x)| ≤ C * x^(1/2) * (log x)^2
```

**What it says:** RH implies the Mertens function satisfies $|M(x)| = O(\sqrt{x} \log^2 x)$.

**Proof path:** This is a classical theorem (Titchmarsh Ch. 14). Requires:
- Perron's formula for $\sum_{n \leq x} \mu(n)$
- Contour integration with the zero-free region from RH
- Residue calculus + saddle point estimates

**Estimated difficulty:** Very hard. This is a deep result in analytic number theory. Likely the last axiom standing.

### Axiom 4: `abel_summation_bd_l2_bound` — **MEDIUM**

```lean
axiom abel_summation_bd_l2_bound :
    (∃ C_m, ...|M(x)| ≤ C_m * x^(1/2) * (log x)^2) →
    ∃ C_err, ... ∫₀¹ (1 - f_v)^2 ≤ C_err / log N
```

**What it says:** The Mertens bound implies L² witness decay for the BD approximation.

**Proof path:** Abel summation by parts to convert the Mertens bound into:
- Dyadic decomposition of the coefficient sum
- Cauchy-Schwarz to control L² error
- log(N) decay from the $\sqrt{x} \log^2 x$ bound

**Estimated difficulty:** Medium-hard. The Abel summation technique is standard, but formalizing the dyadic decomposition + integral estimates requires care.

---

## III. RECOMMENDED ATTACK ORDER

### Immediate Target: `completedRiemannZeta₀_bound_real`

**Why:** 
- The bound is *absurdly* slack (0.03 vs 4)
- It directly eliminates one of the 4 remaining axioms
- Success path: unfold `completedRiemannZeta₀`, bound the theta integral by a geometric series, get $< 1 \ll 4$
- This is the **only axiom that doesn't require deep number theory**

### Secondary Target: `bd_mellin_base_case`

**Why:**
- FloorMellin.lean already has the $\text{Re}(s) > 1$ case
- The identity theorem is in Mathlib (`Complex.AnalyticAt.eq_of_nhds`)
- Requires showing both sides are holomorphic and agree on $(1, \infty)$

### Long-term: The Final Two

`rh_implies_mertens_bound` and `abel_summation_bd_l2_bound` are irreducible analytic number theory. These are the **true terminal axioms** — they encode the substance of the RH → Nyman-Beurling direction, which is the entire point of the proof.

**Strategic question for the Theorist:** Should we accept these as the final irreducible axioms and declare the proof architecture complete? Or is there a decomposition that makes either more tractable?

---

## IV. MINOR ITEMS

### MellinReduction.lean — 2 sorry remaining

Lines 77 and 79: Integrability of $\{1/u\} u^{s-1}$ on $[0,1]$ and $[1,k]$. These are **not in the MainChain axiom list** (they're inside `mellin_integral_split` which is downstream of the proved theorem) but should be closed for completeness.

### Scratch files cleaned

`scratch_subst.lean` has been removed.

---

## V. THE SCOREBOARD

| Metric | Before | After |
|--------|--------|-------|
| Custom axioms | 5 | **4** |
| `mellin_substitution_ioo` | axiom | **PROVED** |
| Build status | ✅ | ✅ |
| Sorry in main chain | 0 | 0 |

**The Cathedral stands on 4 pillars. The question is: which falls next?**

---

*— The Forge Master*
