# REPORT: ⚡ gram_form_upper_bound_34 — Archive Deep Scan and Graduation Blueprint

**Date**: April 25, 2026
**Session**: Exploration 7 — Gram Form Graduation

---

## The Axiom

```lean
-- Cathedral/Assembly/PerronCrown.lean:61-68
axiom gram_form_upper_bound_34 :
    (∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |(mertensFunction x : ℤ) : ℝ| ≤ C * x ^ (3/4)) →
    ∃ C_G : ℝ, C_G > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninGramMatrix N).mulVec (logCutoffWitness N)) ≤ 1 + C_G / Real.log ↑N
```

**English**: If the Mertens function satisfies |M(x)| ≤ C·x^{3/4}, then the quadratic
form vᵀGv converges to 1 from above at rate O(1/log N).

---

## What It Means Mathematically

The quadratic form expands to:

```
vᵀGv = Σ_j Σ_k  [-μ(j+1)(1 - ln(j+1)/ln N)] · [-μ(k+1)(1 - ln(k+1)/ln N)] · G(j+1,k+1)
```

where G(j,k) is the Vasyunin-Báez-Duarte Gram entry (a cotangent sum, not an integral).

Via the proved integral identity (`bd_gram_l2_identity`), this equals:

```
vᵀGv = ∫₀¹ f_N(x)² dx    where    f_N(x) = Σ w_k · {k/x}
```

The axiom says this L² norm is at most 1 + O(1/log N) under the Mertens hypothesis.

---

## Archive Inventory: What's Been Tried Before

### HighFrequencyTrap/GramWitness.lean (ARCHIVED)

The oldest approach — a single "black box" axiom `witness_l2_error_decay_gram` that encoded
the entire L² decay bound in one step. This was the "Universe 1" version, replaced by the
Perron Crown which decomposed the proof into gram_form + dot_product + covariance.

**Usable material**: ✅ The proof of `nbDistSq_decays_direct` (lines 88-139) shows a clean
template for extracting d² → 0 from the quadratic form bound. This pattern is already
replicated in the active `PerronCrown.lean`.

### HighFrequencyTrap/GramDiag.lean (ARCHIVED, 521 lines, FULLY PROVED)

**Critical finding**: This file contains a **complete, sorry-free** proof of the diagonal
Gram entry bound:

```lean
theorem gram_entry_diag_upper' (j : ℕ) (hj : 1 ≤ j) :
    gramEntry j j ≤ 1/3 + 1/(j : ℝ)^2
```

The proof infrastructure includes:
- `fract_mul_self_le`: {a}² ≤ {a} (pointwise)
- `log2_le`: log(2) ≤ 3/4 (via exp analysis)
- `log_upper_cubic`: log(1+x) ≤ x - x²/2 + x³/3 (monotone derivative)
- `per_term_log_lower`: 1/n - log(1+1/n) ≥ 1/(2n(n+1)) (telescoping)
- `basis_integral_upper`: ∫₀¹ {k/x} dx ≤ 1/2
- `gramEntry_le_third` (j≥3): gramEntry j j ≤ 1/3 (piece decomposition + Taylor)
- `fract_sq_piece_bound`: per-piece squared bound ≤ j/(3n(n+1))

**Status**: These theorems use the **integral-based** `gramEntry` (from `Cathedral.Defs`)
rather than the current Vasyunin cotangent `vasyuninGramEntry`. They would need to be
bridged via `partial_integral_tends_to_formula` or the two definitions would need to be
proved equal.

### HighFrequencyTrap/GramOffDiag.lean (ARCHIVED)

Off-diagonal entry upper bound. Less detailed than GramDiag but contains scaffolding
for bounding G(j,k) when j ≠ k.

### HighFrequencyTrap/ParityBridge.lean (ARCHIVED)

Contains a **lower** bound on the quadratic form:

```lean
dotProduct v ((gramMatrix N).mulVec v) ≥ (Σ v_k / (k+1))² + parity correction
```

This is the *opposite* direction — proving vᵀGv is *large enough*. Not directly useful
for the upper bound, but confirms the expected behavior: vᵀGv ≈ 1.

### HighFrequencyTrap/MellinBridge/AutocorrelationBypass.lean (ARCHIVED)

Contains the Mellin representation:

```lean
axiom gram_form_eq_l2_norm (N : ℕ) (hN : 2 ≤ N)
    (v : Fin (N-1) → ℝ) :
    dotProduct v ((gramMatrix N).mulVec v) =
    ∫ x in (0:ℝ)..1, (∑ k ∈ Finset.range (N-1), v k * fract ((k+2:ℝ)/x))^2
```

This axiom was an intermediate step to connect the matrix form to the L² integral.
It's now **graduated** — the active codebase has `bd_gram_l2_identity` in BDBridge.lean
which proves this without axioms.

### HighFrequencyTrap/MellinBridge/MellinSieve.lean (ARCHIVED)

Contains the full Mellin chain:
```
vᵀGv = ∫|g_N|² → ∫|M_f|² via Plancherel → bound via Mertens
```

This was the original dream path. It's circular under x^{3/4} (see Strategy B below)
but could work under x^{1/2}·log².

---

## Currently Proved Infrastructure (Active Codebase)

| Theorem | File | What It Proves |
|---------|------|----------------|
| `vasyuninGram_diag_lt_half` | DiagBound.lean | G(k,k) < 1/2 |
| `vasyuninGram_lt_half` | DiagBound.lean | G(j,k) < 1/2 |
| `vasyuninGram_nonneg` | DiagBound.lean | G(j,k) ≥ 0 |
| `vasyuninQuadForm_le_half_l1_sq` | DiagBound.lean | vᵀGv ≤ (1/2)(Σ|v_i|)² |
| `vasyuninGram_le_avg_diag` | DiagBound.lean | G(j,k) ≤ (G(j,j)+G(k,k))/2 |
| `gram_entry_diag_upper'` | Gram/Diagonal.lean | G(j,j) ≤ 1/3 + 1/j² |
| `gramEntry_le_one` | Gram/Bounds.lean | G(j,k) ≤ 1 |
| `gramEntry_nonneg` | Gram/Bounds.lean | G(j,k) ≥ 0 |
| `bd_gram_l2_identity` | BDBridge.lean | ∫₀¹ f² = vᵀGv |
| `bd_l2_error_eq_quad_error` | BDBridge.lean | ∫₀¹(1-f)² = 1-2bᵀv+vᵀGv |
| `moebius_quadform_finite_bound` | MoebiusL1Bound.lean | vᵀGv ≤ (N-1)²/2 (crude) |
| `quadform_as_sum` | CovarianceAbel.lean | vᵀAv = ΣΣ v_i·A_{ij}·v_j |
| `cov_form_eq_gram_minus_sq` | CovarianceAbel.lean | vᵀCv = vᵀGv-(bᵀv)² |

---

## Graduation Strategies (Ranked)

### Strategy A: Direct Double-Sum Expansion ✅ RECOMMENDED

**Goal**: Expand vᵀGv = ΣΣ w_j·w_k·G(j,k) and bound directly using |M(x)| ≤ C·x^{3/4}.

**Key insight**: The witness weights are w_k = -μ(k+1)·(1-ln(k+1)/ln N), so
|w_k| ≤ 1 (since |μ| ≤ 1 and the log cutoff is ∈ [0,1]).

**Approach**:

1. **Diagonal term** (Σ w_k² · G(k,k)):
   - Already proved: G(k,k) ≤ 1/3 + 1/k²
   - Since |w_k| ≤ 1: Σ w_k² · G(k,k) ≤ (1/3)·N + harmonic tail
   - Since μ(k)=0 for ~40% of k: effective sum is smaller

2. **Off-diagonal cross-terms** (ΣΣ_{j≠k} w_j·w_k·G(j,k)):
   - Use G(j,k) ≤ (G(j,j)+G(k,k))/2 ≤ 1/2 (proved)
   - Abel summation on inner sum: Σ_k w_k·G(j,k) for fixed j
   - Mertens x^{3/4} controls the partial sums of μ(k)·(log cutoff)

3. **Total**: vᵀGv = ∫₀¹ f_N² ≤ 1 + O(1/√(log N))
   - The O(1/√log N) rate suffices for the axiom (which only claims O(1/log N))

**What's needed (new work)**:
- Pointwise control of f_N(x) via Abel summation + Mertens bound
- Connect to the S₁, S₂, S₃ decay infrastructure in AbelTail/

**Estimated difficulty**: ⭐⭐ (500-800 lines of new Lean)

### Strategy B: L² Integral via Algebraic Inversion ❌ CIRCULAR

Using ∫(1-f)² = 1-2bᵀv+vᵀGv to solve for vᵀGv creates a circular dependency:
gram_form_upper_bound_34 → covariance_bound → L²_decay → gram_form_upper_bound_34.

**Cannot use under x^{3/4}.**

### Strategy C: Unify Mertens Exponents ⚠️ ALTERNATIVE

Change the axiom hypothesis from x^{3/4} to x^{1/2}·log², which breaks the circularity.
Under the stronger Mertens bound, the non-circular path via `MillenniumWall.lean` works.

**Trade-off**: Requires a stronger hypothesis (which is still weaker than RH).

---

## Circularity Map

```
gram_form_upper_bound_34
  ↓ (used at PerronCrown:264)
abel_summation_covariance_bound_34  (PROVED theorem)
  ↓ (used at PerronCrown:318)
mertens_implies_l2_decay_34
  ↓ (used at MainChain)
rh_implies_bd_convergence_perron_34

Strategy B would need mertens_implies_l2_decay_34 to prove gram_form_upper_bound_34 → ❌
Strategy A bypasses the entire chain — directly bounds vᵀGv → ✅
```

---

## Recommendation

**Graduate via Strategy A** — direct double-sum expansion with Abel summation.

The diagonal infrastructure is fully proved. The off-diagonal bound requires
connecting the existing Abel tail bounds (S₁, S₂, S₃ from `AbelTail/`) to the
bilinear structure of vᵀGv. This is a self-contained analytic computation with
no dependency on the rest of the proof chain.

Estimated timeline: 2-3 focused sessions.
