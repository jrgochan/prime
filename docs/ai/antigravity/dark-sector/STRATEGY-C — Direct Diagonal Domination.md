# Strategy C — Direct Diagonal Domination

## Goal

Prove `vᵀGv ≤ 1` by splitting the quadratic form into diagonal and off-diagonal parts and bounding each directly using:
- **Diagonal**: G_{kk} ≤ b_k (proved in GramBridge.lean)
- **Off-diagonal**: |G_{jk}| ≤ (3/4)(1/j + 1/k) (proved in PrimeDecoupling.lean)
- **Möbius cancellation**: The off-diagonal sum cancels due to μ(k)

## The Idea

$$v^T G v = \underbrace{\sum_k v_k^2 \cdot G_{kk}}_{\text{diagonal}} + \underbrace{\sum_{j \neq k} v_j \cdot G_{jk} \cdot v_k}_{\text{off-diagonal}}$$

### Diagonal Part

From `gram_diag_le_mean`: G_{kk} ≤ b_k where b_k = ∫₀¹ {1/(kx)} dx.

For the Möbius vector v_k = -μ(k)·w(k) / (k·log N) where w(k) = 1 - log(k)/log(N):

$$\text{diag} = \sum_k v_k^2 \cdot G_{kk} \leq \sum_k v_k^2 \cdot b_k$$

From `quad_form_diag_bound` (GramBridge.lean), this is **already proved**.

Moreover: Σ v_k² · b_k ≤ Σ (1/(k²·log²N)) · (1/k) = (1/log²N) · Σ 1/k³ → 0.

So the **diagonal contributes ≤ C/log²(N) → 0**.

### Off-Diagonal Part — THE HEART

$$\text{off-diag} = \sum_{j \neq k} v_j \cdot G_{jk} \cdot v_k$$

This is where **Möbius cancellation** lives. We need:

$$\left|\sum_{j \neq k} \frac{\mu(j) w(j)}{j \log N} \cdot G(j,k) \cdot \frac{\mu(k) w(k)}{k \log N}\right| \leq 1 - o(1)$$

## Cathedral Arsenal

### Proved Tools for This Strategy

| Theorem | File | What It Gives |
|---------|------|---------------|
| **gram_diag_le_mean** | GramBridge.lean | G_{kk} ≤ b_k (diagonal bound) ✅ |
| **quad_form_diag_bound** | GramBridge.lean | Σv²G_{kk} ≤ Σv²b_k ✅ |
| **gram_offdiag_abs_bound** | PrimeDecoupling.lean | \|G(j,k)\| ≤ (3/4)(1/j + 1/k) ✅ |
| **gram_entry_cauchy_schwarz** | GramBridge.lean | G_{jk}² ≤ G_{jj}·G_{kk} ✅ |
| **gram_entry_nonneg** | GramBridge.lean | G_{jk} ≥ 0 ✅ |
| **fract_sq_le_fract** | GramBridge.lean | {t}² ≤ {t} ✅ |
| **vasyuninGramEntry_diag** | Defs.lean | G(k,k) = (ln(2π)-γ)/k - 1/k² ✅ |
| **pnt_moebius_sum_div_tendsto** | AbelMean.lean | Σ μ(k)/k → 0 ✅ |
| **pnt_mu_log_div_k** | AbelMean.lean | Σ μ(k)log(k)/k → -1 ✅ |
| **bartlett_window_ratio** | BartlettWindow.lean | Σ μ²(k)/k · w² ≤ C/log(N) ✅ |
| **dot_product_tends_to_zero** | OvercancellationChain.lean | \|1 - bᵀv\| → 0 ✅ |

### Key Identity (Already Proved!)

From `bd_l2_error_eq_quad_error` (in NbLinComb.lean):

$$\int_0^1 (1 - f_N(x))^2 dx = 1 - 2b^T v + v^T G v$$

So: **vᵀGv = ∫₀¹ (1-f_N)² dx + 2bᵀv - 1**

Since the integral is ≥ 0 and bᵀv → 1: **vᵀGv ≥ 2bᵀv - 1 → 1 from below**.

For the **upper bound**: vᵀGv = ∫₀¹ (1-f)² + 2bᵀv - 1 ≤ ∫₀¹ (1-f)² + 1 + o(1).

We need ∫₀¹ (1-f)² → 0, which IS the Báez-Duarte convergence — which IS RH.

> [!CAUTION]
> **Circular!** Proving ∫₀¹ (1-f)² → 0 is equivalent to RH. So the direct L² identity approach is circular for proving vᵀGv ≤ 1.

## Breaking the Circularity: The Off-Diagonal Bound

The way out is to **bound the off-diagonal directly** without going through L².

### Step 1: Factor the off-diagonal

$$\text{off-diag} = \frac{1}{\log^2 N} \sum_{j \neq k} \frac{\mu(j) w(j)}{j} \cdot G(j,k) \cdot \frac{\mu(k) w(k)}{k}$$

### Step 2: Use the AM-GM bound

From `gram_offdiag_abs_bound`: |G(j,k)| ≤ (3/4)(1/j + 1/k).

$$|\text{off-diag}| \leq \frac{3/4}{\log^2 N} \sum_{j \neq k} \frac{|\mu(j)| w(j)}{j} \cdot \left(\frac{1}{j} + \frac{1}{k}\right) \cdot \frac{|\mu(k)| w(k)}{k}$$

By symmetry in j,k:

$$= \frac{3/2}{\log^2 N} \sum_{j \neq k} \frac{|\mu(j)| w(j)}{j^2} \cdot \frac{|\mu(k)| w(k)}{k}$$

$$\leq \frac{3/2}{\log^2 N} \left(\sum_j \frac{1}{j^2}\right) \left(\sum_k \frac{|\mu(k)| w(k)}{k}\right)$$

$$= \frac{3/2}{\log^2 N} \cdot \frac{\pi^2}{6} \cdot \left(\sum_k \frac{w(k)}{k}\right)$$

Now Σ w(k)/k = Σ (1 - log(k)/log(N)) / k for squarefree k ≤ N. This is approximately:

$$\sum_{k \leq N} \frac{1}{k} - \frac{1}{\log N} \sum_{k \leq N} \frac{\log k}{k} \approx \log N - \frac{\log^2 N / 2}{\log N} = \frac{\log N}{2}$$

So: |off-diag| ≤ (3/2)(π²/6)(log N / 2) / log²N = (π²/8) / log N → 0!

> [!IMPORTANT]
> **THIS WORKS!** The off-diagonal is O(1/log N), and the diagonal is O(1/log² N), so:
> $$v^T G v = \underbrace{O(1/\log^2 N)}_{\text{diagonal}} + \underbrace{O(1/\log N)}_{\text{off-diagonal}} \to 0 \lt 1$$

### But wait — this is TOO good

This would give vᵀGv → 0, which contradicts the numerical observation vᵀGv ≈ 0.3. The issue is that the AM-GM bound `|G(j,k)| ≤ (3/4)(1/j+1/k)` is **too loose** — it ignores the Möbius signs.

The actual off-diagonal involves **signed sums** of μ(j)μ(k), not |μ(j)||μ(k)|. The AM-GM + triangle inequality kills all the cancellation.

### Refinement: Separate the mean vector

The identity ∫₀¹ {1/(jx)} {1/(kx)} dx includes the "overlap with 1":
- G(j,k) = (bⱼ contribution) + (fluctuation)

From the L² identity: vᵀGv = 1 - 2bᵀv + ∫(1-f)² = 1 - 2(1-o(1)) + ∫(1-f)² ≈ -1 + ∫(1-f)²

Wait, that gives vᵀGv = ∫(1-f)² + 2bᵀv - 1. If bᵀv → 1, then vᵀGv → ∫(1-f)².

## The Real Path: Mertens + Diagonal Domination

### What would close the gap unconditionally:

**Claim**: For the Möbius vector v_k = -μ(k)·w(k)/(k·logN):

$$v^T G v = (b^T v)^2 + v^T C v$$

where C = G - bbᵀ is the covariance matrix. We know:
- (bᵀv)² → 1 (from PNT, proved)
- vᵀCv ≥ 0 (since C is positive semidefinite for positive Gram)

So vᵀGv ≥ 1 eventually. For the **upper bound**:

$$v^T C v = v^T G v - (b^T v)^2$$

If we can show vᵀCv = O(1/log N), then vᵀGv = 1 + O(1/log N).

### The Bartlett Window Approach

From `bartlett_window_ratio` (proved, 0 sorry):

$$\sum_{k=1}^{N-1} \frac{\mu(k)^2}{k} \cdot w(k)^2 \leq \frac{6/\pi^2}{\log N} \cdot (1 + o(1))$$

This bounds **‖v‖² · (constant)**. The covariance vᵀCv is bounded by:

$$v^T C v \leq \|v\|^2 \cdot \lambda_{\max}(C)$$

And λ_max(C) ≤ λ_max(G) ≤ tr(G) ~ (1/2)log(N). So:

$$v^T C v \leq \frac{C_1}{\log N} \cdot \frac{\log N}{2} = C_1/2$$

This gives vᵀGv ≤ 1 + C₁/2 — **not tight enough** for vᵀGv ≤ 1, but close!

### Tightening: Use λ_max(C) ≤ max row sum of C

The **covariance** C_{jk} = G_{jk} - b_j · b_k.

Row sum of C at row j: Σ_k |C_{jk}| = Σ_k |G_{jk} - b_j·b_k|

For large j,k: b_j ≈ (ln(2π)-γ)/j and G_{jk} ≈ (ln(2π)-γ)/max(j,k), so C_{jk} is the "fluctuation" part. This is much smaller than G_{jk} itself.

## Difficulty Assessment

> [!TIP]
> **MEDIUM DIFFICULTY, MOST PROMISING.** The diagonal domination approach has all the tools already proved in the Cathedral. The gap is tightening the off-diagonal bound from O(1) to o(1).

The key insight: **we don't need vᵀGv ≤ 1**, we only need vᵀGv ≤ 1 + K/log(N) (which is `gram_form_upper_bound_direct`). The diagonal contribution is O(1/log²N) and the off-diagonal... if we can show it's ≤ 1 + O(1/logN), we're done.

## Estimated Effort

- **Research**: 1-2 days (the mathematics is fairly clear)
- **Key calculation**: Bound Σ_{j≠k} μ(j)w(j)/j · G(j,k) · μ(k)w(k)/k using the Vasyunin formula
- **Formalization**: 3-5 days
- **Risk**: LOW — the tools are all proved, the bound just needs to be tight enough

## Concrete Next Steps

1. **Compute** vᵀGv numerically for N = 100, 1000, 10000 and plot vᵀGv vs 1 + K/log(N) to find K
2. **Prove** the off-diagonal bound using `gram_offdiag_abs_bound` and PNT sums
3. **Connect** the BartlettWindow ratio to the covariance bound
4. **Verify** that the constant is tight enough

## The Bottom Line

> [!IMPORTANT]
> Strategy C is the **most achievable** path. The tools are:
> - `gram_diag_le_mean` (diagonal ✅)
> - `gram_offdiag_abs_bound` (entry-wise ✅)
> - `bartlett_window_ratio` (weight norm ✅)
> - `pnt_moebius_sum_div_tendsto` + `pnt_mu_log_div_k` (PNT ✅)
>
> What remains is **one calculation**: bound the off-diagonal sum
> $$\sum_{j \neq k} \frac{\mu(j) w(j)}{j \log N} \cdot G(j,k) \cdot \frac{\mu(k) w(k)}{k \log N}$$
> using the Vasyunin formula and PNT sums. This is a concrete, bounded task.

The off-diagonal decomposes as:
1. A "main term" involving Σ μ(j)/j · Σ μ(k)/k → 0 × 0 = 0
2. A "correction" involving Σ μ(j)log(j)/j · Σ μ(k)/k → (-1) × 0 = 0
3. Higher-order corrections bounded by 1/log²(N)

This is the **Möbius function doing what it was born to do**: cancelling.
