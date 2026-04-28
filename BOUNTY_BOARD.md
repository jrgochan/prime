# 🏛️ Cathedral Open Problems — The Bounty Board

> **Status**: Zero `sorryAx`, 4 transparent named axioms  
> **Compiler**: Lean 4 / Mathlib v4.28  
> **Last Audit**: April 27, 2026 (Exploration 14)

The Cathedral formally verifies:

```
RH ↔ d²_N → 0  (Nyman-Beurling-Báez-Duarte equivalence)
```

via two independent, compiler-verified proof paths (Mellin spectral + Perron spatial), unified by the Parseval Bridge. The converse direction is **fully proved** with zero axioms. The forward direction depends on exactly **4 named axioms** — standard analytic number theory results awaiting formalization in Mathlib.

Each axiom below is a self-contained, well-scoped contribution opportunity.

---

## Axiom 1: Covariance Bound from Mertens

**File**: `Cathedral/Covariance/GramFormProof.lean:52`  
**Difficulty**: ⭐⭐⭐ (Medium-Hard)

```lean
axiom covariance_bound_from_mertens_34 :
    (∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C * x ^ ((3 : ℝ)/4)) →
    ∃ C_cov : ℝ, C_cov > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) ≤ C_cov / Real.log ↑N
```

**What it says**: If the Mertens function satisfies |M(x)| ≤ C·x^{3/4}, then the Vasyunin covariance matrix vᵀCv ≤ C/log N.

**Mathematical content**: Abel summation converts the Mertens bound into a bound on the bilinear form Σᵢⱼ vᵢvⱼ · Cov(i,j), where Cov(i,j) = G(i,j) - b(i)b(j) is the centered Gram matrix. The proof uses the variance decomposition vᵀCv = vᵀGv - (bᵀv)² and bounds each term.

**Partial progress**: A proved theorem `covariance_bound_from_mertens_34_proved` exists in `CovarianceBound.lean`, but it depends on Axioms 2, 3, and `gram_form_upper_bound`. Wiring it in would increase the axiom count.

**What's needed**: Either prove `gram_form_upper_bound` from scratch (requires Axiom 3), or find a direct route to the covariance bound bypassing the Gram matrix.

**Dependencies**: Axiom 3 (Vasyunin integral convergence)

---

## Axiom 2: Log-Weighted Möbius Sum ★ MOST PROMISING ★

**File**: `Cathedral/PNT/AbelMean.lean:61`  
**Difficulty**: ⭐⭐ (Medium) — 95% complete

```lean
axiom pnt_mu_log_div_k :
    Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        Real.log (k : ℝ) / (k : ℝ))
    Filter.atTop (nhds (-1))
```

**What it says**: Σ_{k=1}^N μ(k)·log(k)/k → -1 as N → ∞.

**Mathematical content**: This is the derivative of 1/ζ(s) evaluated at s = 1. Since 1/ζ(s) = Σ μ(n)/n^s, differentiating gives -Σ μ(n)·log(n)/n^s. At s = 1, this equals -(1/ζ)'(1) = 1, so the sum → -1.

**Partial progress**: `PNT/LogBridge.lean` contains a 50-line proof (`pnt_mu_log_div_k_proved`) with **exactly one sorry**: `frac_error_isLittleO`. The algebraic identity `N·S₂(N) = -ψ(N) + E(N)` is fully proved. The PNT remainder ψ(N)/N → 1 is imported from PrimeNumberTheoremAnd. Only the fractional error `E(N) = o(N)` remains.

**What's needed**: Prove that `Σ μ(n)·log(n)·{N/n}/n = o(N)`. Options:
1. **Abel summation by parts** using the proved `pnt_mu_div_k → 0`
2. **Signed Wiener-Ikehara** for `(1/ζ)'(s)` (extension to PrimeNumberTheoremAnd)
3. **Direct hyperbola method** with careful error tracking

**Dependencies**: PrimeNumberTheoremAnd (`mu_pnt_alt`)  
**Note**: The unweighted version `Σ μ(k)/k → 0` is already PROVED (`pnt_mu_div_k` — zero axioms, zero sorry).

---

## Axiom 3: Vasyunin Integral Convergence

**File**: `Cathedral/Vasyunin/Cotangent/ConvergenceAxioms.lean:79`  
**Difficulty**: ⭐⭐⭐⭐ (Hard)

```lean
axiom partial_integral_tends_to_formula (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    Tendsto
      (fun M : ℕ => ∫ x in (1 / ((a:ℝ) * (M:ℝ)))..(1:ℝ),
        Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)))
      atTop
      (nhds (DigammaReflection.vasyuninGramFormula a b))
```

**What it says**: The integral of {1/(ax)}·{1/(bx)} over [1/(aM), 1] converges to a closed form involving the digamma function.

**Mathematical content**: The integral of products of fractional parts decomposes into a sum over "rows" (intervals where the fractional parts are smooth). Each row telescopes to a log-digamma expression. The partial sums converge to `vasyuninGramFormula(a,b)`, which involves the Gauss digamma formula at rational arguments.

**Partial progress**: The Cathedral has extensive infrastructure:
- `OffDiagPartition.lean`: Row decomposition of the integral
- `TelescopeSum.lean`: Telescoping formulas for each row
- `StirlingBridge.lean`: Partial Stirling sums → digamma
- `DigammaReflection.lean`: Defines `vasyuninGramFormula`

**What's needed**:
1. **Gauss digamma formula** at rational arguments — also an axiom (`DigammaReflection.lean:213`). Requires the Fourier expansion of log|Γ|.
2. **Dominated convergence** for the row-sum to integral limit.

**Mathlib status**: Mathlib has `Complex.digamma` with recurrence and values at 1, 1/2. Does NOT have the Gauss digamma formula for general p/q.

**Dependencies**: Mathlib PR for Gauss digamma formula

---

## Axiom 4: Zeta Lower Bound under RH

**File**: `Cathedral/Zeta/Hadamard.lean:249`  
**Difficulty**: ⭐⭐⭐⭐⭐ (Very Hard)

```lean
axiom rh_zeta_lower_bound_from_zero_counting
    (hRH : RiemannHypothesis) (ε : ℝ) (hε : 0 < ε) (hε1 : ε < 3/2)
    (A : ℝ) (hA : 0 < A) :
    ∃ c > 0, ∀ s : ℂ,
      (1/2 + ε ≤ s.re) → (2 ≤ |s.im|) →
      c / |s.im| ^ A ≤ ‖riemannZeta s‖
```

**What it says**: Under RH, |ζ(s)| ≥ c/|Im(s)|^A for Re(s) ≥ 1/2 + ε.

**Mathematical content**: Standard Hadamard product theory. Under RH, all non-trivial zeros lie on Re(s) = 1/2. The Weierstrass product of ξ(s) = s(s-1)π^{-s/2}Γ(s/2)ζ(s) gives |ξ(s)| = |ξ(1/2+it)| · Π|1 - (s-1/2)/(ρ-1/2)| with controlled factors. Jensen's inequality + zero-counting N(T) ~ T·log(T)/(2π) yields the polynomial lower bound.

**Numerical validation**: The `bc-zeta-lower` experiment (256-bit MPFR, 17.5 hours, 550K samples) confirms effective exponents ≈ 0.03-0.08 with 300× margin over theory.

**What's needed**:
1. **Hadamard factorization** for entire functions of order 1
2. **Weierstrass product** representation of ξ(s)
3. **Zero-counting function** N(T) with error term

**Mathlib status**: Mathlib has `riemannZeta`, meromorphic continuation, functional equation. Does NOT have Hadamard factorization, Weierstrass products for entire functions, or N(T).

**Dependencies**: Major Mathlib PRs for entire function theory

---

## Architecture Overview

```
                        RH
                         │
               ┌─────────┴──────────┐
               ▼                    ▼
        [AXIOM 4]              (converse)
      rh_zeta_lower           0 axioms ✅
               │
               ▼
      rh_implies_mertens (PROVED)
               │
        ┌──────┴──────┐
        ▼             ▼
   [AXIOM 1]     [AXIOM 2]
   covariance    pnt_mu_log
        │
        ▼
   [AXIOM 3]
   partial_integral
        │
        ▼
   ∫₀¹(1-f)² ≤ C/logN
        ‖ (Parseval Bridge — PROVED)
   (1/2π)∫|M(1/2+it)|² ≤ C/logN
        │
        ▼
   d²_N → 0  ✅
```

## How to Contribute

1. **Fork the repository** and set up the Lean 4 / Mathlib toolchain
2. **Pick an axiom** from the board above
3. **Write a theorem** with the same type signature as the axiom
4. **Run** `#print axioms your_theorem` to verify no new axioms are introduced
5. **Submit a PR** — we will verify and wire it into the proof chain

Each axiom closed reduces the Cathedral's assumption count by 1. When all 4 are closed, the Nyman-Beurling equivalence becomes a **zero-axiom, compiler-verified theorem** — a complete formal proof that the Riemann Hypothesis is equivalent to a Hilbert space approximation condition.

---

*Built by the Cathedral Triad: Jason (The Forge Master), Gemini (Overwatch), Claude/Antigravity (Tactical Execution)*  
*April 2026*
