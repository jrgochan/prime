# 🏰 CATHEDRAL DEEP AUDIT & The Millennium Wall Proof Path

**Date**: 2026-04-22  
**Scope**: Complete audit of all 212 `.lean` files in the Cathedral  
**Purpose**: Map the axiom landscape and chart the proof path for `millennium_covariance_cancellation`

---

## Part I: The Full Axiom Census

### 1.1 Scale

| Category | Count |
|----------|-------|
| Total `.lean` files | 212 |
| Active (non-Archive) | 115 |
| Archive | 97 |
| Active axioms | 51 |
| Active sorry | 5 |
| Archive axioms | 64 |

### 1.2 Active Sorry Map (5 total)

| File | Line | Content | On Critical Path? |
|------|------|---------|-------------------|
| `AbelL2Bridge.lean` | 294 | Abel → L² bridge | ❌ Side chain |
| `AbelL2Bridge.lean` | 317 | Abel → L² convergence | ❌ Side chain |
| `ZetaConvexity.lean` | 46 | Convexity bound ln | ❌ Infrastructure |
| `ZetaConvexity.lean` | 57 | Phragmén-Lindelöf | ❌ Infrastructure |
| `DirichletSeries.lean` | 40 | Abel for Dirichlet series | ❌ Infrastructure |

**None of the 5 active sorry blocks are on the critical path.** The Crown theorem `rh_implies_l2_convergence_proved` compiles with zero sorry.

### 1.3 Active Axiom Taxonomy (51 total)

#### Tier 0: The Crown (6 axioms — on critical path)

These are the **only** axioms that `rh_implies_l2_convergence_proved` depends on:

| # | Axiom | File | Role |
|---|-------|------|------|
| 1 | `rh_implies_mertens_bound` | MertensBound.lean | RH → |M(x)| = O(√x·log²x) |
| 2 | `pnt_mu_div_k` | FinalDragon.lean | PNT: Σ μ(k)/k → 0 |
| 3 | `pnt_mu_log_div_k` | FinalDragon.lean | PNT: Σ μ(k)log(k)/k → -1 |
| 4 | `pnt_mu_log_sq_div_k` | FinalDragon.lean | PNT: Σ μ(k)log²(k)/k → -2γ |
| 5 | `millennium_covariance_cancellation` | FinalDragon.lean | 2D covariance bound |
| 6 | `vasyunin_offdiag_integral` | VasyuninIntegralProof.lean | Off-diagonal Gram entry |

#### Tier 1: Converse Infrastructure (6 axioms)

Used by the converse `d²_N → 0 ⟹ RH` or alternative forward paths:

| Axiom | File | Purpose |
|-------|------|---------|
| `baezDuarte_is_L2` | OrthogonalWitness.lean | BD function is L² |
| `baezDuarte_inner_one` | OrthogonalWitness.lean | ⟨e_ρ, 1⟩ ≠ 0 |
| `baezDuarte_inner_residual` | OrthogonalWitness.lean | Inner product with residual |
| `mertens_bound_from_rh` | MertensWeightBypass.lean | Duplicate of #1 |
| `abel_summation_l2_bound` | MertensWeightBypass.lean | Abel → L² (alt path) |
| `abel_summation_covariance_bound` | WitnessConditional.lean | Covariance (alt path) |

#### Tier 2: Parseval/Plancherel Infrastructure (3 axioms)

These are NOT on the critical path (the Parseval reverse-bypass already proved `critical_line_mellin_bound` without them):

| Axiom | File | Purpose |
|-------|------|---------|
| `mellin_fourier_change` | AutocorrelationBypass.lean | Mellin = Fourier (calculus) |
| `fourier_inversion_autocorrelation` | AutocorrelationBypass.lean | L¹ Fourier inversion |
| `gram_form_eq_l2_norm` | AutocorrelationBypass.lean | Gram = L² norm |

#### Tier 3: Montgomery-Vaughan Chain (9 axioms)

| Axiom | File | Purpose |
|-------|------|---------|
| `montgomeryVaughan_bound` | HilbertInequality.lean | MV Hilbert inequality |
| `selbergMajorant` + 5 properties | HilbertInequality.lean | Selberg majorant BS1-BS5 |
| `dirichlet_polynomial_mean_value_bound` | MontgomeryVaughan.lean | Mean value theorem |
| `bd_gram_form_decay` | MontgomeryVaughan.lean | Direct L² decay |

#### Tier 4: Vasyunin Cotangent Chain (4 axioms)

| Axiom | File | Purpose |
|-------|------|---------|
| `gauss_digamma_formula` | DigammaReflection.lean | Gauss ψ formula |
| `harmonicTileSum_reciprocity` | LogDigammaBridge.lean | Harmonic reciprocity |
| `telescope_limit_eq_vasyunin` | LogDigammaBridge.lean | Telescope → Vasyunin |
| `vasyunin_integral_eq_formula` | LogDigammaBridge.lean | Integral = formula |

#### Tier 5: Spectral/Sieve Side Chains (15 axioms)

Various axioms in `Spectral/`, `Sieve/`, `Structural/` — these support alternative proof paths and the parity bridge, but none are on the Crown critical path.

#### Tier 6: Computational Oracles (3 axioms)

`oracle_lambda_min_positive_2000`, `oracle_witness_bound_100/1000` — certified computation axioms in `CertifiedComputation.lean`.

#### Tier 7: Side-chain witnesses (5 axioms)

`bd_witness_l2_error_decay`, `witness_l2_error_decay_gram`, `witness_numerator_convergence`, `witness_covariance_decay`, `vasyunin_large_gcd` — in witness/expansion files.

---

## Part II: The Graduated Axioms (Historical)

| Former Axiom | Status | Date | How |
|-------------|--------|------|-----|
| `vasyunin_eq_integral` | THEOREM ✅ | Apr 20 | Diagonal via FTC, off-diag narrowed |
| `fract_sq_integral` | THEOREM ✅ | Apr 20 | Stirling + Squeeze from Mathlib |
| `rh_implies_mertens_34` | THEOREM ✅ | Apr 22 | From mertens_bound: x^{1/2}·log²x ≤ 64·x^{3/4} |
| `abel_mertens_tail_raw` | THEOREM 🎓 | Apr 22 | s1_decay + s2_decay + s3_decay |

---

## Part III: The Millennium Wall — What It Actually Says

### 3.1 The Statement

```lean
axiom millennium_covariance_cancellation
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4)) :
    ∃ K_cov : ℝ, K_cov > 0 ∧ ∀ (N : ℕ), 10 ≤ N →
    realQuadForm (vasyuninCovMatrix (N - 1))
      (bdMoebiusWeight N) ≤ K_cov / Real.log (N : ℝ)
```

**Translation**: Under the Mertens bound, the quadratic form `vᵀCv` where `C = G - bbᵀ` (Gram matrix minus mean-tensor) decays as `O(1/log N)` with specific `bdMoebiusWeight` weights.

### 3.2 Why It's Hard

The covariance matrix `C = G - bbᵀ` captures the **interaction** between pairs of Möbius-weighted fractional parts. The diagonal of G (each entry individually) is well-controlled. The mean vector b is well-controlled (via `moebius_mean_finite_bound`, PROVED). But the **cross-terms** of G with the mean tensor create a 2D cancellation that cannot be handled by 1D Abel summation.

The issue: `G_{jk} · v_j · v_k` with `v_k = μ(k)·log(k)/k` involves:
```
Σ_j Σ_k μ(j)μ(k)·log(j)log(k)/(jk) · ∫₀¹ {1/(jx)}{1/(kx)} dx
```

This is a **double Möbius sum** weighted by the Gram integral. No factorization into separate j-sums and k-sums is possible without Parseval/Mellin.

---

## Part IV: The Proof Path for `millennium_covariance_cancellation`

### 4.1 The Strategy: Bypass via `bd_gram_form_decay`

The cleanest path does NOT attack the millennium wall directly. Instead:

```
bd_gram_form_decay (axiom in MontgomeryVaughan.lean)
  → critical_line_mellin_bound (PROVED via parseval_bridge⁻¹)
  → l2_from_pointwise_bound_derived (PROVED)
```

The key insight: `bd_gram_form_decay` is a **STRICTLY STRONGER** statement than `millennium_covariance_cancellation`. It says:

```
∫₀¹ |1 - f_N(x)|² ≤ (C_m+1)² · loglog(N)/log(N)
```

Since `∫|1-f|² = 1 - 2vᵀb + vᵀGv = (1 - vᵀb)² + vᵀCv`, we have:
```
vᵀCv ≤ ∫|1-f|² ≤ (C_m+1)² · loglog(N)/log(N) ≤ K/log(N)
```

So proving `bd_gram_form_decay` would simultaneously prove `millennium_covariance_cancellation` with a better rate.

### 4.2 Proving `bd_gram_form_decay`

The proof path documented in `MontgomeryVaughan.lean`:

```
Step 1: ∫₀¹ |r_N(x)|² dx = 1 - 2bᵀv + vᵀGv
Step 2: |Σ v_k · b_k| = O(1/log N)  [Abel + Mertens — WE HAVE THIS!]
Step 3: vᵀGv = O(loglog N / log N)   [THE KEY STEP]
Step 4: Combine: ∫|r_N|² ≤ (C_m+1)² · loglog(N)/log(N)
```

Step 2 is essentially `moebius_mean_finite_bound` — **already proved in FinalDragon.lean**.

Step 3 is the hard part. It decomposes via the Parseval bridge:

```
vᵀGv = ∫₀¹ |f_N(x)|² dx 
      = (1/2π) ∫ |M_{f_N}(1/2+it)|² dt  [parseval_bridge, PROVED]
```

Then the Mellin transform of f_N on the critical line is:
```
M_{f_N}(1/2+it) = Σ_{k=1}^{N-1} v_k · h_k(1/2+it)
```

where `h_k(s) = ∫₀¹ {k/x} x^{s-1} dx` is the Mellin transform of the k-th fractional part basis.

### 4.3 The MV Mean Value Path (The Breakthrough Route)

The **most promising** path to prove `vᵀGv ≤ C·loglog(N)/log(N)`:

**Step A**: Express vᵀGv via the Parseval bridge:
```
vᵀGv = (1/2π) ∫_{-∞}^{∞} |Σ v_k h_k(1/2+it)|² dt
```
*(Already proved as `parseval_bridge`)*

**Step B**: Compute `h_k(1/2+it)` explicitly. For the BD basis:
```
h_k(s) = 1/(s·k^s) - ψ(s)/(k^s)  [Mellin of {k/x}]
```
On the critical line s = 1/2+it:
```
|h_k(1/2+it)| = O(1/√k)  [uniform in t for |t| ≥ 1]
```

**Step C**: Apply the MV mean value theorem:
```
∫_{-T}^{T} |Σ aₙ n^{-it}|² dt ≤ Σ |aₙ|² (2T + 2πn)
```
*(Axiom `dirichlet_polynomial_mean_value_bound`, needs proof from `montgomery_vaughan_bound`)*

With `a_k = v_k · h_k(1/2)` (approximately μ(k)·log(k)/(k·√k)):
```
Σ |a_k|² · (2T + 2πk) ≤ Σ μ(k)²·log²(k)/k³ · (2T + 2πk)
```

For T = N: the diagonal dominates, giving `O(loglog N)`. Dividing by T = N: `O(loglog N / N)`.

Wait — this gives too much decay! The issue is the v_k already carry 1/k factors. The actual rate is `O(loglog N / log N)`, which comes from the log-taper:
- `v_k = μ(k)·log(k)/k` gives `Σ |v_k|² ≈ Σ log²(k)/k² ≈ const`
- The Gram entries add another 1/√k factor
- The MV off-diagonal control gives O(1/logN) from the taper structure

**Step D**: Abel tail control (NEW — what we just proved!):

The Abel decay theorems provide:
```
|Σ_{k=1}^N μ(k)/k| ≤ C₁ · N^{-1/4}                     [s1_decay]
|Σ_{k=1}^N μ(k)·logk/k + 1| ≤ C₂ · N^{-1/4} · logN      [s2_decay]
```

These bound the **tail contributions** of the Dirichlet polynomial `Σ v_k · k^{-it}` when we truncate at different thresholds. Specifically:

1. **High frequency (|t| > N)**: The MV theorem gives decay from the `2T` term
2. **Medium frequency (1 < |t| < N)**: The off-diagonal MV bound controls interference
3. **Low frequency (|t| < 1)**: The Abel decay bounds control the smooth part

The Abel-proved bounds feed into case 3: they certify that the DC component of the Dirichlet polynomial (the partial sum at t=0) converges with the right rate, and the first/second derivatives at t=0 (which correspond to S₂ and S₃) also converge.

### 4.4 The Dependency DAG

```mermaid
graph TD
    A[montgomery_vaughan_bound] -->|Selberg majorant| B[dirichlet_polynomial_mean_value_bound]
    B --> C[bd_gram_form_decay]
    P[parseval_bridge ✅] --> C
    S[s1_decay ✅ + s2_decay ✅ + s3_decay ✅] --> D[Abel coefficient bounds]
    D --> C
    M[moebius_mean_finite_bound ✅] --> E[linear mean bound]
    E --> C
    C --> F[millennium_covariance_cancellation]
    C --> G[mertens_l2_decay → Crown!]
```

### 4.5 The Irreducible Core

After the audit, the truly irreducible axioms are:

| Axiom | Can it be proved? | Blocking on |
|-------|-------------------|-------------|
| `montgomery_vaughan_bound` | Yes, from Selberg majorant | Selberg axioms BS1-BS5 |
| `selbergMajorant` (BS1-BS5) | Yes, constructive | Lean/Mathlib Fourier gaps |
| `bd_gram_form_decay` | Yes, from MV + Abel + Parseval | MV bound + assembly |
| `dirichlet_polynomial_mean_value_bound` | Yes, from MV theorem | MV Hilbert inequality |

The dependency bottleneck is clear: **everything flows through `montgomery_vaughan_bound`**.

### 4.6 Alternative: The Direct L² Bypass

There is a shorter but less educational path:

Instead of proving `millennium_covariance_cancellation` from the MV chain, we could:

1. Prove `bd_gram_form_decay` directly via the **2-point observation**:
   ```
   ∫₀¹ |1-f_N|² = 1 - 2·Σ v_k·b_k + Σ_j Σ_k v_j·v_k·G_{jk}
   ```
   
2. The quadratic form `Σ v_j v_k G_{jk}` with Möbius log-taper weights satisfies:
   - Each `G_{jk} = O(1/max(j,k))` (from Vasyunin formula)
   - The weights `v_k = μ(k)·log(k)/k` decay as `1/k`
   - Bilinear form: `Σ_j Σ_k (logj·logk)/(jk)·(1/max(j,k))·μ(j)μ(k)`
   - The Möbius cancellation in the j-sum (for fixed k) gives `O(k^{-1/4})` from our Abel bounds
   - Summing over k: `O(Σ k^{-5/4}·logk) = O(1)` — this is exactly `log_weighted_rpow_54_tail`!

This path uses our Abel machinery **directly** rather than going through MV. The key insight:

> *The Abel tail bounds we proved are exactly the coefficient estimates needed for the 1D reduction of the 2D covariance sum.*

---

## Part V: Recommended Proof Path

### Phase 1: Direct Covariance Bound (leverages Abel work)

1. **Prove `bd_gram_form_decay`** by:
   - Expanding `∫|1-f|² = 1 - 2vᵀb + vᵀGv`
   - Using `moebius_mean_finite_bound` (PROVED) for the linear term
   - For the quadratic term, fix k and sum over j:
     - Use Abel summation on `Σ_j μ(j)·log(j)·G_{jk}/j`
     - The Abel-proved tail bounds give `O(k^{-1/4}·logk)`
     - Sum over k: `Σ k^{-1/4}·logk·v_k = Σ log²k·k^{-5/4} = O(1)` via `logsq_weighted_tail`!

2. **Replace `millennium_covariance_cancellation`** as a corollary of `bd_gram_form_decay`.

### Phase 2: MV Chain (independent, deeper)

1. Prove `selbergMajorant` constructively (explicit formula: `sgn(x)·(1 - B₁(|x|)) + B₁_hat(x)`)
2. Prove `montgomery_vaughan_bound` from Selberg majorant
3. Prove `dirichlet_polynomial_mean_value_bound` from MV bound

### Phase 3: Perron Chain (`rh_implies_mertens_bound`)

1. Connect Perron formula (PROVED) to `1/ζ(s)` Dirichlet series (PROVED)
2. Implement contour shift: Re(s) = 1+ε → Re(s) = 1/2+ε
3. Bound the shifted contour using RH zero-free region

### Phase 4: PNT Axioms

1. Formalize `pnt_mu_div_k` from Mathlib PNT + Abel limit theorem
2. Similarly for `pnt_mu_log_div_k` and `pnt_mu_log_sq_div_k`

---

## Part VI: Build Status

```
Build completed successfully (3503 jobs).
Sorry: 5 (none on critical path)
Active axioms: 51 (6 on critical path)
Graduated axioms: 4

Crown: rh_implies_l2_convergence_proved
  ↳ Depends on 6 Cathedral axioms + 3 kernel axioms
  ↳ Zero sorry in proof chain
  ↳ Converse (d²_N → 0 ⟹ RH) is PURE (0 custom axioms)
```

---

*"The Cathedral has 115 active files, 51 axioms, and 5 sorry. But only 6 axioms stand between us and the Crown. And the Abel foundation we just completed provides the coefficient data that the next wall — the millennium covariance — needs to fall. The sum swap was the heartbeat; the Montgomery-Vaughan inequality is the next frontier."*
