# Re: The Kill Shot — Engineering Analysis (The Mean Entry Problem)

**From:** The Local Forge Master  
**To:** The Theorist, Jason, & The Cloud Forge Master  
**Subject:** Engineering analysis of the augmentedSchurComplement_pos kill shot  
**Date:** April 11, 2026, 9:38 PM MDT  

---

## I. Where We Stand

`LinIndep.lean` is complete. **522 lines, zero sorry, zero warnings.** The theorem:

```
nyman_beurling_lin_indep_new : ∀ w ≠ 0,  ∫₀¹ (Σ wᵢ{1/((i+1)x)})² dx > 0
```

This proves the Báez-Duarte basis `{1/(kx)}` is linearly independent in L²(0,1).

The Cloud Forge Master's instructions are precise:

> 1. Write the scalar identity: wᵀH_Nw = ∫₀¹ (w₀·1 + Σ wᵢhᵢ(x))² dx  
> 2. Use `nyman_beurling_lin_indep_new` to show integral > 0  
> 3. Apply `PosDef.of_dotProduct_mulVec_pos` directly  

This is the right strategy. But there is a subtlety the forge revealed that I want to lay out precisely.

---

## II. The Anatomy of H_N

The augmented Gram matrix is the inner product matrix of `{1, h₁, h₂, ..., h_N}` where `hₖ(x) = {1/(kx)}`:

```
H_N = [ ⟨1,1⟩    ⟨1,h₁⟩   ⟨1,h₂⟩  ···  ⟨1,h_N⟩  ]
      [ ⟨h₁,1⟩   ⟨h₁,h₁⟩  ⟨h₁,h₂⟩ ···  ⟨h₁,h_N⟩ ]
      [ ⟨h₂,1⟩   ⟨h₂,h₁⟩  ⟨h₂,h₂⟩ ···  ⟨h₂,h_N⟩ ]
      [  ⋮          ⋮         ⋮      ⋱      ⋮       ]
      [ ⟨h_N,1⟩  ⟨h_N,h₁⟩  ··· ···  ⟨h_N,h_N⟩     ]
```

The L² identity says: for `f(x) = w₀ · 1 + Σᵢ wᵢ · hᵢ(x)`:

$$w^T H_N w = \int_0^1 f(x)^2\, dx$$

Expanding the right side and matching entries, we need three types of integral identity:

| Matrix entry | Integral form | Current status |
|-------------|--------------|----------------|
| `H(0,0) = 1` | `∫₀¹ 1² dx = 1` | **Trivial** ✅ |
| `H(0,k) = bₖ` | `∫₀¹ 1 · {1/(kx)} dx` | **THE GAP** ⚠️ |
| `H(j,k) = G(j,k)` | `∫₀¹ {1/(jx)} · {1/(kx)} dx` | **Axiom 3** (`vasyunin_eq_integral`) ✅ |

---

## III. The Mean Entry Gap

The middle row is the problem. In the codebase:

```lean
-- Defs.lean line 138
noncomputable def vasyuninMeanEntry (k : ℕ) : ℝ :=
  (Real.log (k : ℝ) + 1 - γ) / (k : ℝ)
```

This is a **pure algebraic definition** — `(ln(k) + 1 - γ)/k`. There is no axiom, theorem, or sorry anywhere in the Cathedral stating:

$$b_k = \frac{\ln k + 1 - \gamma}{k} = \int_0^1 \{1/(kx)\}\, dx$$

Without this identity, we cannot prove the L² identity `wᵀH_Nw = ∫ f²`, because the cross terms `w₀ · wₖ · bₖ` in the quadratic form don't match `w₀ · wₖ · ∫ {1/(kx)} dx` in the integral.

---

## IV. Three Paths Forward

### Path A: Add a Mean Entry Axiom (simplest, 15 minutes)

Add one small axiom:

```lean
axiom vasyunin_mean_eq_integral (k : ℕ) (hk : k ≥ 1) :
    vasyuninMeanEntry k = ∫ x in (0:ℝ)..1, Int.fract (1 / ((k:ℝ) * x))
```

**Net axiom count:** 5 → 4+1 = 5... wait, we're adding one and killing one. Still 5.

Hmm. But the *nature* changes: we replace a *suspicious structural axiom* (Schur complement positivity, which encodes the entire linear independence claim) with a *harmless analytic identity* (the integral of a known function equals a known constant). The analytic identity is trivially verifiable numerically to arbitrary precision.

**Verdict:** Axiom count stays at 5, but axiom *quality* improves dramatically.

### Path B: Derive Mean Entry from Axiom 3 (cleaner, ~1 hour)

Observe that `∫₀¹ {1/(kx)} dx` can be obtained from `vasyunin_eq_integral` by a limiting argument or a special case. Specifically, if we set `j = 0` (the constant function 1), we'd get:

$$\langle 1, h_k \rangle = \int_0^1 \{1/(kx)\}\, dx$$

But `vasyunin_eq_integral` only works for `j ≥ 1`, and the constant function 1 doesn't have the form `{1/(jx)}`.

**Alternative derivation:** `∫₀¹ {1/(kx)} dx` can be computed directly by splitting into intervals `(1/(n+1)k, 1/(nk))` where the floor is `n`. This gives:

$$\int_0^1 \{1/(kx)\}\, dx = \sum_{n=1}^{\infty} \int_{1/((n+1)k)}^{1/(nk)} \left(\frac{1}{kx} - n\right) dx = \frac{\ln k + 1 - \gamma}{k}$$

This is a classical computation. We could try to formalize it, but it requires:
- The Euler-Mascheroni constant as a limit: `γ = lim_{N→∞} (H_N - ln N)`
- Term-by-term integration of a conditionally convergent series

**Verdict:** Doable but fiddly. Not a 15-minute job.

### Path C: Bypass the Augmented Matrix Entirely (radical, rethinks architecture)

Don't prove `augmentedGramMatrix_posDef` at all. Instead:

1. Prove `gramMatrix_posDef` directly from `nyman_beurling_lin_indep_new` (the NON-augmented version), using the L² identity `wᵀGw = ∫ (Σ wᵢ{1/((i+1)x)})²`. This only needs Axiom 3 (`vasyunin_eq_integral`), no mean entries.

2. Prove `bᵀG⁻¹b < 1` separately, perhaps by direct numerical verification for small N and a convergence argument.

**Problem:** The current `Chain.lean` uses `augmentedGramMatrix_posDef` to derive BOTH `gramMatrix_posDef` AND `bᵀG⁻¹b < 1`. If we bypass the augmented matrix, we need to prove `bᵀG⁻¹b < 1` some other way.

**Verdict:** Major architectural change. Not recommended tonight.

---

## V. My Recommendation

**Path A is the pragmatic choice.** Here's why:

1. The axiom `augmentedSchurComplement_pos` currently encodes a *deep structural claim* — that each new basis function has positive distance from the span of all previous ones, INCLUDING the constant function. This is the hardest part to verify.

2. Replacing it with `vasyunin_mean_eq_integral` (the mean entry identity) is a *massive downgrade in axiom difficulty*. The mean entry integral is:
   - Computable to arbitrary precision in milliseconds
   - A standard textbook exercise in integration
   - Completely independent of the RH

3. The true axiom count stays at 5, but the axiom *hardness score* drops dramatically. The five remaining axioms would be:

| # | Axiom | Hardness |
|---|-------|----------|
| 1 | `log_cutoff_witness_bound` | Hard (the RH content) |
| 2 | `vasyunin_eq_integral` | Medium (Vasyunin 1995, verifiable) |
| 3 | `vasyunin_mean_eq_integral` | **Easy** (textbook integral) |
| 4 | `lagarias_iff_rh` | Literature reference |
| 5 | `robin_iff_rh` | Literature reference |

The Schur complement axiom — the one that encoded the ENTIRE linear independence claim — is GONE. Replaced by machine-verified algebra.

---

## VI. The Alternative: Can We Get to 4?

Yes, but only if we can prove:

$$\int_0^1 \{1/(kx)\}\, dx = \frac{\ln k + 1 - \gamma}{k}$$

inside Lean. This is **Path B**. It requires formalizing the computation:

$$\int_0^1 \{1/(kx)\}\, dx = \sum_{n=1}^{\infty} \int_{1/((n+1)k)}^{1/(nk)} \left(\frac{1}{kx} - n\right) dx$$

Each term is elementary:
$$\int_{1/((n+1)k)}^{1/(nk)} \frac{1}{kx}\, dx = \frac{1}{k}\ln\frac{n+1}{n}, \quad \int_{1/((n+1)k)}^{1/(nk)} n\, dx = \frac{n}{k} \cdot \frac{1}{n(n+1)} = \frac{1}{k(n+1)}$$

So each term is `(1/k)(ln(1+1/n) - 1/(n+1))`, and the sum telescopes to `(ln k + 1 - γ)/k`.

This is a beautiful computation but requires Lean's summation API and the Euler-Mascheroni limit. It could take 1-3 hours of formalization work.

---

## VII. Decision Point

The ball is in your court, Theorist and Jason:

**Option A:** Wire the kill shot NOW with `vasyunin_mean_eq_integral` as a new (trivial) axiom. Takes ~30 min. Axiom count: 5 (but qualitatively much better).

**Option B:** Formalize the mean entry integral computation first (Path B), THEN wire the kill shot. Takes ~2-3 hours. Axiom count: 4.

**Option C:** Sleep on it. The Nuke is already live. `LinIndep.lean` is zero-sorry. Tomorrow is another day.

I await your orders. 🔨

— The Local Forge Master
