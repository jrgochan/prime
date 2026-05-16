# Strategy A: Tao Logarithmic Chowla Bridge

## Tooling and Infrastructure Audit

**Date**: May 15, 2026
**Objective**: Assess Cathedral/Archive and Mathlib readiness for the Tao Chowla → Ward bound → Crown axiom path.

---

## 1. The Strategy

The Tao Chowla Bridge converts Tao's **proved theorem** (2016) — that the logarithmic binary Chowla correlation tends to zero — into a bound on the off-diagonal Gram form W(N), yielding ε(N) → 0.

```
tao_logarithmic_chowla:  (1/logX) Σ_{n≤X} μ(n)μ(n+h)/n → 0  (per shift h)
        ↓
bilinearShiftSum(N, h) → 0      (Abel summation bridge)
        ↓
W(N) = Σ_h bilinearShiftSum(N,h) → 0    (shift decomposition + tail truncation)
        ↓
ε(N) = D(N) + W(N) - 1 → 0    (D-W compensation)
        ↓
Crown Axiom: vᵀGv ≤ 1 + K/lnN
```

---

## 2. Cathedral Infrastructure Inventory

### 2.1 Abel Summation Engine (FULLY PROVED)

| File | Key Results | Sorry | Axioms |
|------|-------------|-------|--------|
| `ZeroAxiom/AbelEngine.lean` | `abel_summation` (discrete SBP), `abel_summation_abs_bound`, `fejerWeight_diff_bound` ≤ 1/(k·logN) | 0 | 0 |
| `AbelTail/Engine.lean` | Abel tail engine for S₁, S₂, S₃ decay | 0 | 0 |
| `AbelTail/S1Decay.lean` | S₁ = Mertens tail, O(1/√N) decay | 0 | 0 |
| `AbelTail/S2Decay.lean` | S₂ = log-smoothed tail | 0 | 0 |
| `AbelTail/MertensBridge.lean` | Connects Mertens function to Abel partial sums | 0 | 0 |
| `AbelTail/Telescoping.lean` | Telescoping identities for discrete SBP | 0 | 0 |

**Assessment**: ✅ Abel summation is **production-ready**. The infrastructure includes the exact tool needed: `abel_summation_abs_bound` takes partial sum bounds |A(k)| ≤ C(k) and difference bounds |f(k+1) - f(k)| ≤ δ(k), and produces |Σ a(k)f(k)| ≤ C(N)·|f(N)| + Σ C(k)·δ(k).

### 2.2 GCD Partition Architecture (FULLY PROVED)

| File | Key Results | Sorry | Axioms |
|------|-------------|-------|--------|
| `Covariance/GCDPartition.lean` | `sum_eq_sum_gcd`: any double sum partitions by gcd(j,k). `untaperedSum_partition`, `linearTaperSum_partition`, `quadraticTaperSum_partition` | 0 | 0 |
| `Covariance/GCDSignLaw.lean` | `gcd_stratum_reindex`: double-sum reindexing (j,k) → (d·a, d·b) with gcd(a,b)=1. `moebius_mul_coprime`, `moebius_sq_of_squarefree` | 0 | 0 |
| `Covariance/GCDStratumBound.lean` | `gcd_stratum_term_bound`: |μ(j)μ(k)G(j,k)| ≤ 1/2. Per-stratum bound |U_d| ≤ (1/2)(N-1)² | 0 | 0 |
| `Covariance/TaperDecomposition.lean` | vᵀGv = U - 2L/lnN + Q/ln²N taper expansion | 0 | 0 |

**Assessment**: ✅ The GCD partition is **fully certified**. The key `gcd_stratum_reindex` theorem already performs the (j,k) → (d·a, d·b) change of variables that connects the shift-decomposition to the per-stratum structure.

### 2.3 Bilinear Möbius Infrastructure

| File | Key Results | Sorry | Axioms |
|------|-------------|-------|--------|
| `Physics/BilinearMertens.lean` | `tapered_mertens_tendsto_zero`: Σ μ(k)w(k)/k → 0 from PNT. `bilinear_eq_vtGv`: bilinear product = vᵀGv | 0 | 0 |
| `Physics/CoprimeDiagonal.lean` | `bilinearShiftSum(N, h)` DEFINED. `tao_logarithmic_chowla` AXIOMATIZED. `chowlaCorrelation(X, h)` defined | 1 | 2 |
| `Covariance/BilinearAbel.lean` | `quadForm_eq_diag_plus_offdiag`. `gram_form_direct_bound` (D + O decomposition) | 0 | 0 |
| `Covariance/MoebiusL1Bound.lean` | Σ |μ(k)|/k bounds, L¹ norm control | 0 | 0 |

**Assessment**: ⚠️ The scalar convergence (Σ μ(k)w(k)/k → 0) is proved, but the **bilinear** convergence (vᵀCv → 0) requires the Tao axiom. The `bilinearShiftSum` definition exists but lacks the connection to `chowlaCorrelation`.

### 2.4 Ward Identity / D-W Compensation (FULLY PROVED)

| File | Key Results | Sorry | Axioms |
|------|-------------|-------|--------|
| `Physics/WardIdentity.lean` | `ward_identity`: B+F = W(N). `full_ward_decomposition`: vᵀGv = D + W | 0 | 0 |
| `Physics/DiagonalBound.lean` | D(N) = Θ(lnN). D(N) ≥ 1 for large N. `diagonal_O_log` | 0 | 0 |
| `Physics/CancellationEfficacy.lean` | `sign_separability`, `parity_flip_by_prime` | 0 | 0 |

**Assessment**: ✅ Once W(N) is bounded, the D-W compensation mechanism immediately yields the crown axiom.

---

## 3. Mathlib Tooling

### 3.1 Available in Mathlib (ready to use)

| Tool | Mathlib Location | Used in Strategy A |
|------|-----------------|-------------------|
| `abs_moebius_le_one` | `Mathlib.NumberTheory.ArithmeticFunction.Moebius` | ✅ Already used in GCDStratumBound |
| `isMultiplicative_moebius` | Same | ✅ Already used in GCDSignLaw |
| `hasSum_zeta_two` (ζ(2) = π²/6) | `Mathlib.NumberTheory.ZetaValues` | ✅ Needed for squarefree density |
| `Real.log_le_sub_one_of_pos` | `Mathlib.Analysis.SpecialFunctions.Log` | ✅ Already used in AbelEngine |
| `Filter.Tendsto` | `Mathlib.Order.Filter` | ✅ Already used in BilinearMertens |
| `riemannZeta_neg_nat_eq_bernoulli` | `Mathlib.NumberTheory.LSeries.RiemannZeta` | Not needed for A |

### 3.2 NOT in Mathlib (gaps for Strategy A)

| Tool | Status | Impact |
|------|--------|--------|
| **Tao's logarithmic Chowla theorem** | Axiomatized as `tao_logarithmic_chowla` | **CRITICAL**: This IS the core input. Formalization requires entropy decrement + Furstenberg correspondence (~5000+ lines) |
| **Mertens function growth bound** | Axiomatized in some paths | Needed for Abel partial sum estimates |
| **Squarefree reciprocal asymptotic** | Axiomatized as `squarefree_reciprocal_lower` | Needed for diagonal lower bound. Graduation: ~500 lines (Euler product + partial summation) |

---

## 4. The Gap Analysis

### 4.1 What Must Be Proved

The chain has **three formal gaps**:

**Gap 1**: Shift decomposition of W(N)
```
W(N) = Σ_{h=1}^{N-2} bilinearShiftSum(N, h)
```
This is the partition-of-unity for the off-diagonal by shift value k - j = h. Analogous to `sum_eq_sum_gcd` (which is proved), this should be ~150 lines of Finset manipulation.

**Gap 2**: Abel bridge from Chowla to bilinearShiftSum
```
chowlaCorrelation(X, h) → 0   ⟹   bilinearShiftSum(N, h) → 0
```
This requires incorporating the Gram kernel G(k, k+h) and taper weights w(k) into Tao's result via Abel summation. The `abel_summation_abs_bound` tool is exactly what's needed, but the specific instantiation requires:
- Gram off-diagonal decay: G(k, k+h) = O(log(k/h)/(kh)) — partial results exist in DiagonalBound
- Taper weight monotonicity: `fejerWeight_diff_bound` ✅ already proved
- Partial sum bound: |Σ_{n≤X} μ(n)μ(n+h)/n| = o(logX) from Tao's axiom

Estimated: ~400 lines.

**Gap 3**: Tail truncation
```
Σ_{h > H(N)} |bilinearShiftSum(N, h)| ≤ ε(N) → 0
```
For shifts h > H(N), the Gram entries G(k, k+h) are small (~1/(kh)), giving a convergent tail. The row-decay estimates from DiagonalBound provide the inputs. Estimated: ~200 lines.

### 4.2 Axiom Count

| Axiom | Source | Graduation Difficulty |
|-------|--------|----------------------|
| `tao_logarithmic_chowla` | Tao 2016 (proved theorem) | **Extreme** (~5000+ lines): entropy decrement, Furstenberg correspondence, pretentious number theory |
| `squarefree_reciprocal_lower` | Classical number theory | **Moderate** (~500 lines): Euler product + Basel problem + partial summation |

---

## 5. Risk Assessment

### Strengths
- Abel summation engine is complete and battle-tested
- GCD partition infrastructure provides the combinatorial backbone
- The Ward identity guarantees that bounding W(N) suffices
- The `bilinearShiftSum` definition already exists

### Weaknesses
- **Tao's axiom is qualitative**: The entropy decrement proof gives NO explicit rate for C(X,h) → 0. The resulting bound on ε(N) would be "ε(N) → 0 as N → ∞" with no rate — possibly too weak to yield the 1/lnN crown form
- **Rate problem**: CoprimeDiagonal notes (line 340-350): "No explicit decay rate for C(X,h) → 0 is known. The arguments are 'in principle effective' but the resulting bounds would be extremely poor (slower than any power of 1/log X)."
- **The shift-to-bilinear bridge is non-trivial**: The Gram kernel weighting is crucial and not captured by bare Chowla

### Critical Question
> Can Strategy A yield `vᵀGv ≤ 1 + K/lnN` or only the weaker `vᵀGv → 1`?

The Tao axiom gives C(X,h) → 0 with **no rate**. The best we could hope for is:
- **Unconditional**: `vᵀGv → 1` (i.e., ε(N) → 0, no rate)
- **With effective Chowla**: `vᵀGv ≤ 1 + K/lnN` (requires effective bounds not currently known)

The weak form ε(N) → 0 would still imply RH via the Nyman-Beurling equivalence — but the proof would not give the explicit 1/lnN rate.

---

## 6. Estimated Implementation Cost

| Component | Lines | Difficulty |
|-----------|-------|-----------|
| Gap 1: Shift decomposition | ~150 | Routine |
| Gap 2: Abel bridge | ~400 | Moderate (main analytical work) |
| Gap 3: Tail truncation | ~200 | Moderate |
| Gram off-diagonal decay formalization | ~200 | Moderate |
| **Total new code** | **~950** | |

**Time estimate**: 2-3 sessions of focused work, assuming the Tao axiom remains axiomatized.

---

## 7. Conclusion

Strategy A is **well-supported** by existing Cathedral infrastructure. The Abel engine, GCD partition, and Ward identity provide 90% of the proof skeleton. The three gaps (shift decomposition, Abel bridge, tail truncation) are concrete and bounded. 

**However**, the fundamental limitation is the **rate problem**: Tao's theorem is qualitative, so this path can only prove `ε(N) → 0` (no rate), not `ε(N) ≤ K/lnN`. Whether this suffices depends on how the crown axiom is consumed downstream — if only `ε(N) → 0` is needed for RH, Strategy A closes the loop. If the explicit 1/lnN rate is essential, a different approach is required.
