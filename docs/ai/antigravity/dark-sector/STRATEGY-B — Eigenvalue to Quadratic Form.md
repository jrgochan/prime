# Strategy B — Eigenvalue → Quadratic Form

## Goal

Prove `vᵀGv ≤ 1` by showing the Möbius vector `v = bdMoebiusWeight N` has its energy concentrated in directions where the Gram matrix eigenvalues are small (≤ 1), using the spectral self-similarity and eigenvalue convergence results.

## The Idea

The Gram matrix G_N has eigenvalues λ₁ ≥ λ₂ ≥ ... ≥ λ_{N-1} > 0, and the quadratic form expands as:

$$v^T G v = \sum_i \lambda_i \langle v, e_i \rangle^2$$

where {e_i} are orthonormal eigenvectors. If we can show:
1. Most eigenvalues are ≤ 1 (or close to 1)
2. The Möbius vector has negligible projection onto the few eigenvalues > 1

then vᵀGv ≤ 1 follows.

## Cathedral Arsenal

### Spectral Results (0 sorry)

| Theorem | File | Statement |
|---------|------|-----------|
| `eigenvalue_limit_exists` | MainChain.lean | ∃ L ≥ 0, λ_min(N) → L (unconditional) |
| `lambdaMin_shifted_antitone` | Antitone.lean | λ_min is monotone decreasing |
| `lambdaMin_pos` | Separation.lean | λ_min(N) > 0 for all N ≥ 2 |
| `eigenvalue_interlacing` | Eigenvalue.lean | Cauchy interlacing: λ_min(N+1) ≤ λ_min(N) |
| `eigenDrop_nonneg` | Eigenvalue.lean | δ_N = λ_min(N-1) - λ_min(N) ≥ 0 |
| `spectral_selfsimilarity_upper` | PrimeFractal.lean | λ_min(G^(p)) ≤ (1/p)·λ_min(G) + (p-1)/p |
| `min_eigenvalue_le_quadForm` | PrimeFractal.lean | λ_min ≤ vᵀGv/\|v\|² (Rayleigh) |

### Gram Matrix Results (0 sorry)

| Theorem | File | Statement |
|---------|------|-----------|
| `gram_entry_le_one` | GramBridge.lean | G_{jk} ≤ 1 |
| `gram_diag_le_mean` | GramBridge.lean | G_{kk} ≤ b_k (diagonal ≤ mean) |
| `hf_gram_diag_upper'` | Diagonal.lean | G_{kk} ≤ 1/(2k) + C/k² |
| `gram_diag_lower_bound` | PrimeDecoupling.lean | G(k,k) ≥ 1/(4k) for k ≥ 2 |
| `gram_offdiag_abs_bound` | PrimeDecoupling.lean | \|G(j,k)\| ≤ (3/4)(1/j + 1/k) |

### Gershgorin Tools (0 sorry)

| Theorem | File | Statement |
|---------|------|-----------|
| `eigenvalue_le` | GershgorinBound.lean | λ ≤ max_i(G_{ii} + R_i) |
| `eigenvalue_ge` | GershgorinBound.lean | λ ≥ min_i(G_{ii} - R_i) |
| `eigenvalue_pos_of_diag_dominates` | GershgorinBound.lean | G_{ii} > R_i ⟹ λ > 0 |
| `gram_eigenvalue_le` | SpectralBound.lean | Wiring to Gram matrix |

### Möbius Vector Properties

| Theorem | File | Statement |
|---------|------|-----------|
| `mu_sq_nonneg` | BartlettWindow.lean | μ(k)² ≥ 0 |
| `mu_sq_le_one` | BartlettWindow.lean | μ(k)² ≤ 1 |
| `bartlett_window_ratio` | BartlettWindow.lean | Window function ≤ 1 |
| `dot_product_tends_to_zero` | OvercancellationChain.lean | \|1 - bᵀv\| → 0 |

## Proof Architecture

### Path B1: Trace Bound

**Key identity**: tr(G) = Σ λ_i = Σ G_{kk}.

From `hf_gram_diag_upper'`: G_{kk} ≤ 1/(2k) + C/k² for all k ≥ 1.

Therefore: tr(G_N) = Σ_{k=1}^{N-1} G_{kk} ≤ (1/2)H_{N-1} + C·π²/6

where H_n is the harmonic number. Since H_n ~ ln(n), the trace grows logarithmically.

**The trace tells us**: On average, eigenvalues are ~ ln(N)/(N-1) → 0. Most eigenvalues are small!

But the **maximum eigenvalue** λ_max ~ ln(N)/2 (from Gershgorin), so a few eigenvalues dominate the trace.

**What we need**: Show the Möbius vector v has small projection onto the top eigenspaces.

### Path B2: Spectral Decomposition + Mertens

Write vᵀGv = Σ λ_i ⟨v, eᵢ⟩². Split into:
- **Small eigenvalues** (λ_i ≤ 1): Contribution ≤ 1 · Σ ⟨v, eᵢ⟩² ≤ ‖v‖²
- **Large eigenvalues** (λ_i > 1): Need ⟨v, eᵢ⟩ ≈ 0

For the Möbius vector v_k = -μ(k)·(1 - log(k)/log(N)) / (k·log(N)):

$$\|v\|^2 = \sum_k v_k^2 \leq \sum_k \frac{1}{k^2 \log^2 N} = \frac{\pi^2/6}{\log^2 N} \to 0$$

So the "small eigenvalue" contribution → 0. The issue is entirely about the large eigenvalues.

**The top eigenvector** of G_N is approximately proportional to (1/√k), because G_{jk} ~ 1/(2·max(j,k)) and the dominant structure is a harmonic-like kernel.

**Möbius cancellation kills the top eigenvector**: ⟨v, e_top⟩ ~ Σ μ(k)/(k√k · logN) → 0 by PNT.

### Path B3: Rayleigh Quotient Bound (Already Partially Done!)

From `WitnessAsymptotics.lean`:
```
theorem rayleigh_witness_growth (N : ℕ) (hN : 10 ≤ N) :
    ∃ c : ℝ, c > 0 ∧ c * Real.log N ≤ rayleighQuotient N (logCutoffWitness N)
```

This shows the **Rayleigh quotient** R(v) = (bᵀv)² / vᵀCv grows like log(N), where C is the covariance matrix. Since vᵀGv = 1 - 2bᵀv + vᵀGv and vᵀCv = vᵀGv - (bᵀv)², the Rayleigh quotient constrains vᵀGv.

Specifically: R = (bᵀv)² / (vᵀGv - (bᵀv)²). If R ~ log(N) and bᵀv → 1:

$$v^T G v = (b^T v)^2 + \frac{(b^T v)^2}{R} \approx 1 + \frac{1}{\log N} \to 1$$

This is **exactly** the gram_form_upper_bound_direct statement!

## The Critical Insight

> [!IMPORTANT]
> **The Rayleigh quotient growth** (`rayleigh_witness_growth`) combined with **bᵀv → 1** (`dot_product_tends_to_zero`) gives vᵀGv = 1 + O(1/log N) — which is stronger than vᵀGv ≤ 1 but requires understanding the constant.

The issue: `rayleigh_witness_growth` uses the **covariance** matrix C = G - bbᵀ, and the bound requires knowing that the covariance is small. This is circular — it assumes what we're trying to prove.

## What's Actually Missing

The gap is precisely at:
```
gram_form_upper_bound_direct : ∃ K, ∀ N large, vᵀGv ≤ 1 + K/log(N)
```

This is currently an **axiom** in `GramBoundDirect.lean`. Proving it requires either:
1. An independent bound on vᵀCv (covariance), or
2. A direct computation of vᵀGv using the Vasyunin formula + Möbius cancellation

## Difficulty Assessment

> [!NOTE]
> **MEDIUM DIFFICULTY.** The spectral decomposition approach has the right structure, but connecting the eigenvalue bounds to the specific Möbius vector requires either:
> - A uniform Mertens-type bound (which enters RH territory), or
> - A direct diagonal-domination argument (→ Strategy C)

The Rayleigh quotient path (B3) is the most promising but currently circular.

## Estimated Effort

- **Path B1 (Trace)**: 1-2 days research, but likely insufficient alone
- **Path B2 (Spectral + Mertens)**: 3-5 days, requires PNT-level sums
- **Path B3 (Rayleigh)**: Already partially done, but breaking the circularity is the core RH difficulty

## Recommendation

The Rayleigh quotient growth theorem is the **closest existing tool** to proving vᵀGv ≤ 1. The gap is understanding the covariance matrix independently. Strategy C (direct diagonal domination) might be a better path to close this, since it avoids eigenvalue arguments entirely.

**Best next step**: Investigate whether `gram_offdiag_abs_bound` (|G(j,k)| ≤ (3/4)(1/j + 1/k)) can directly bound the off-diagonal part of vᵀGv, which combined with `gram_diag_le_mean` (G_{kk} ≤ b_k) gives a direct bound. This leads to Strategy C.
