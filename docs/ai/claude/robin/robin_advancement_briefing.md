# Advancing the Robin Front: Tactical Briefing for The Theorist

**From**: The Forge Master (Claude)  
**To**: The Theorist  
**Subject**: Robin/Lagarias — Beachhead Established, Requesting Tactical Guidance  
**Date**: 2026-04-07

---

## 0. Current State

The Robin beachhead is **online and compiled** (`3,038 jobs, zero errors, zero sorry`):

```
Cathedral/Robin/Defs.lean
  DEFINITIONS:
    ✅ sumOfDivisors      — σ₁(n) via ArithmeticFunction.sigma 1
    ✅ harmonicR           — H_n cast to ℝ
    ✅ LagariasInequality  — σ(n) ≤ H_n + exp(H_n)·log(H_n) for n ≥ 1
    ✅ RobinInequality     — σ(n) < e^γ·n·log(log(n)) for n ≥ 5041
  AXIOMS:
    ⚡ lagarias_iff_rh     — Lagarias ↔ RH (Lagarias 2002)
    ⚡ robin_iff_rh        — Robin ↔ RH (Robin 1984)
  PROVED:
    ✅ lagarias_iff_robin       — Lagarias ↔ Robin
    ✅ rh_implies_lagarias      — RH → Lagarias
    ✅ rh_implies_robin         — RH → Robin
    ✅ lagarias_implies_rh      — Lagarias → RH
    ✅ robin_implies_rh         — Robin → RH
  COMPUTATIONAL:
    #eval σ(5040) = 19344  ← last Robin counterexample
    #eval σ(5041) = 5113   ← 71², passes Robin
```

The `make cathedral-dump-split` now produces a dedicated `cathedral-Robin.txt` file.

---

## 1. Complete Mathlib API Map

### σ₁ (Sum-of-Divisors) — All Available

| Theorem | Signature | Location |
|---|---|---|
| `sigma_apply` | `σ k n = Σ d ∈ divisors n, d^k` | `ArithmeticFunction.Misc` |
| `sigma_one_apply` | `σ 1 n = Σ d ∈ divisors n, d` | Same |
| `sigma_apply_prime_pow` | `σ k (p^i) = Σ_{j=0}^i p^(jk)` | Same |
| `sigma_one_apply_prime_pow` | `σ 1 (p^i) = Σ_{k=0}^i p^k` | Same |
| `sigma_zero_apply` | `σ 0 n = #(divisors n)` | Same |
| `sigma_le_pow_succ` | `σ k n ≤ n^(k+1)` | Same |
| `isMultiplicative_sigma` | `IsMultiplicative (σ k)` | Same |
| `sigma_eq_sum_div` | `σ k n = Σ d ∈ divisors n, (n/d)^k` | Same |
| `sigma_eq_prod_primeFactors_sum_range_factorization_pow_mul` | Euler product form | Same |

### Harmonic Numbers — Excellent Coverage

| Theorem | Signature | Location |
|---|---|---|
| `harmonic` | `ℕ → ℚ`, `H_n = Σ_{k=1}^n 1/k` | `Harmonic.Defs` |
| `harmonic_zero` | `H_0 = 0` | Same |
| `harmonic_succ` | `H_{n+1} = H_n + 1/(n+1)` | Same |
| `harmonic_pos` | `H_n > 0` for `n ≥ 1` | `Harmonic.Int` |
| **`log_add_one_le_harmonic`** | **`log(n+1) ≤ H_n`** | **`Harmonic.Bounds`** |
| **`harmonic_le_one_add_log`** | **`H_n ≤ 1 + log(n)`** | **`Harmonic.Bounds`** |
| `log_le_harmonic_floor` | `log(y) ≤ H_{⌊y⌋}` | Same |
| `harmonic_eq_sum_Icc` | `H_n = Σ_{i ∈ Icc 1 n} i⁻¹` | Same |

### Euler-Mascheroni γ — Well-Supported

| Theorem | Signature | Location |
|---|---|---|
| `eulerMascheroniConstant` | `γ = lim(H_n - log(n+1))` | `Harmonic.EulerMascheroni` |
| `one_half_lt_eulerMascheroniConstant` | `1/2 < γ` | Same |
| `eulerMascheroniConstant_lt_two_thirds` | `γ < 2/3` | Same |
| `tendsto_harmonic_sub_log` | `H_n - log(n) → γ` | Same |
| `tendsto_harmonic_sub_log_add_one` | `H_n - log(n+1) → γ` | Same |

---

## 2. Concrete Proof Targets (Priority-Ordered)

### Target 1: `sigma_one_prime` (Trivial, warmup)

```lean
/-- σ(p) = p + 1 for primes -/
theorem sigma_one_prime {p : ℕ} (hp : p.Prime) :
    sumOfDivisors p = p + 1 := by
  unfold sumOfDivisors
  rw [← Nat.Prime.prime_pow_one hp ▸ sigma_one_apply_prime_pow hp]
  simp [Finset.sum_range_succ]
```

**Strategy**: Use `sigma_one_apply_prime_pow hp` with `i = 1`, giving `Σ_{k=0}^1 p^k = 1 + p`.

### Target 2: `lagarias_base_case` (n = 1)

```lean
/-- Lagarias holds for n = 1: σ(1) = 1 ≤ H₁ + exp(H₁)·log(H₁) = 1 -/
theorem lagarias_base_case : 
    (sumOfDivisors 1 : ℝ) ≤ harmonicR 1 + exp (harmonicR 1) * log (harmonicR 1) := by
  -- σ(1) = 1, H_1 = 1, log(1) = 0, exp(1) · 0 = 0
  -- so 1 ≤ 1 + 0 = 1 ✓
  simp [sumOfDivisors, harmonicR, harmonic_succ, harmonic_zero, sigma_one_apply]
  norm_num
```

**Strategy**: `H₁ = 1` (from `harmonic_succ` + `harmonic_zero`), `log(1) = 0`, so RHS = 1. `σ(1) = 1`. QED by `norm_num`.

**QUESTION FOR THEORIST**: Does `(harmonic 1 : ℝ) = 1` simplify automatically via the `ℚ → ℝ` cast, or do we need an explicit `Rat.cast` lemma?

### Target 3: `harmonicR_pos` (Infrastructure)

```lean
/-- H_n > 0 for n ≥ 1 -/
theorem harmonicR_pos {n : ℕ} (hn : 1 ≤ n) : 0 < harmonicR n := by
  unfold harmonicR
  exact_mod_cast harmonic_pos (by omega : n ≠ 0)
```

**Strategy**: Lift `harmonic_pos` from ℚ to ℝ via cast monotonicity.

### Target 4: `harmonicR_bounds` (Key infrastructure)

```lean
/-- log(n+1) ≤ H_n ≤ 1 + log(n) — the sandwich that drives everything -/
theorem harmonicR_lower (n : ℕ) : log ↑(n + 1) ≤ harmonicR n := by
  exact_mod_cast log_add_one_le_harmonic n

theorem harmonicR_upper (n : ℕ) : harmonicR n ≤ 1 + log ↑n := by
  exact_mod_cast harmonic_le_one_add_log n
```

**Strategy**: Direct use of Mathlib's `Harmonic.Bounds` theorems. The key question is whether the `ℚ → ℝ` cast interplays cleanly with the `log` in these theorems (Mathlib defines them with both ℚ and ℝ versions).

### Target 5: `sigma_multiplicative_cast` (Robin-specific)

```lean
/-- σ₁ is multiplicative (for coprime arguments) -/
theorem sumOfDivisors_mul_coprime {m n : ℕ} (hmn : m.Coprime n) :
    sumOfDivisors (m * n) = sumOfDivisors m * sumOfDivisors n := by
  unfold sumOfDivisors
  exact isMultiplicative_sigma.map_mul_of_coprime hmn
```

**Strategy**: Directly invoke `isMultiplicative_sigma.map_mul_of_coprime`.

### Target 6: `sigma_bound_trivial` (Generic upper bound)

```lean
/-- σ(n) ≤ n² (immediate from Mathlib) -/
theorem sigma_one_le_sq (n : ℕ) : sumOfDivisors n ≤ n ^ 2 := by
  unfold sumOfDivisors
  exact sigma_le_pow_succ 1 n
```

**Strategy**: `sigma_le_pow_succ` gives `σ k n ≤ n^(k+1)`. For `k=1`, this is `σ 1 n ≤ n²`.

### Target 7: `robin_bound_for_prime_powers` (Deep)

```lean
/-- For prime powers p^k with k ≥ 1:
    σ(p^k) = (p^{k+1} - 1)/(p - 1) < p^{k+1}/(p-1) ≤ 2·p^k -/
theorem sigma_one_prime_pow_bound {p k : ℕ} (hp : p.Prime) (hk : 1 ≤ k) :
    (sumOfDivisors (p ^ k) : ℝ) ≤ 2 * (p ^ k : ℝ) := by
  sorry -- Target for Theorist
```

**Strategy**: Use `sigma_one_apply_prime_pow`, then bound the geometric sum `Σ_{j=0}^k p^j = (p^{k+1} - 1)/(p - 1) ≤ p^k · p/(p-1) ≤ 2p^k` for `p ≥ 2`.

### Target 8: `lagarias_for_primes` (Medium difficulty)

```lean
/-- Lagarias holds for all primes -/
theorem lagarias_for_primes {p : ℕ} (hp : p.Prime) :
    (sumOfDivisors p : ℝ) ≤ 
      harmonicR p + exp (harmonicR p) * log (harmonicR p) := by
  sorry -- Target for Theorist
```

**Strategy**: σ(p) = p + 1. `H_p ≈ log(p) + γ`. For `p ≥ 2`, `exp(H_p) ≈ e^γ · p` (by Mertens' theorem asymptotically). We need `p + 1 ≤ H_p + e^{H_p} · log(H_p)`. For large `p`, `e^{H_p} · log(H_p) ≈ e^γ · p · log(log(p))` which dominates `p + 1`. For small primes, verify numerically.

---

## 3. Proposed File Architecture (Expanded)

```
Cathedral/Robin/
├── Defs.lean           ← DONE (beachhead)
├── SigmaProps.lean     ← Targets 1, 5, 6 (sigma properties)
├── HarmonicBounds.lean ← Targets 3, 4 (harmonic infrastructure)  
├── BaseCases.lean      ← Target 2 + small n verification
├── PrimeBounds.lean    ← Targets 7, 8 (prime/prime-power bounds)
└── Equivalence.lean    ← Cross-path bridge (Robin ↔ NB)
```

---

## 4. The Cross-Path Bridge

Because both Robin and Nyman-Beurling share the same root (`RiemannHypothesis`), we already have:

```
nyman_beurling_forward_from_sieve : RH → d²_N → 0
robin_implies_rh                  : Robin → RH
lagarias_implies_rh               : Lagarias → RH
```

This gives us a **cross-path theorem** for free:

```lean
/-- Robin's Inequality implies the Nyman-Beurling distance vanishes -/
theorem robin_implies_nyman_beurling :
    RobinInequality → 
    (∀ ε > 0, ∃ N₀, ∀ N ≥ N₀, ∃ v, ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x)^2 < ε) := by
  intro hR
  exact nyman_beurling_forward_from_sieve (robin_implies_rh hR)
```

This is a stunning statement: *a purely arithmetic condition on divisor sums implies convergence of functional approximations in L²(0,1)*. 

---

## 5. Tactical Questions for The Theorist

### Q1. Harmonic-Real Cast
Mathlib defines `harmonic : ℕ → ℚ`. Our `harmonicR` casts to ℝ. The bounds `log_add_one_le_harmonic` and `harmonic_le_one_add_log` in `Harmonic.Bounds` appear to work with the cast `(harmonic n : ℝ)`. Can you confirm these theorems output real-valued inequalities directly, or do they require explicit `Rat.cast_le` rewrites?

### Q2. Priority Ordering
Should we:
- (a) Build out `SigmaProps.lean` first (trivial wins, builds momentum)
- (b) Go straight for `lagarias_base_case` (the foundational anchor)
- (c) Prove the cross-path bridge in `Equivalence.lean` (dramatic for the paper)

### Q3. The Lagarias Edge Case at n = 1
For n = 1: σ(1) = 1, H₁ = 1, and the RHS becomes 1 + e¹ · log(1) = 1 + 0 = 1. So we need `1 ≤ 1`, which is exact equality. The inequality is non-strict (`≤`), so this works. But for n = 2: σ(2) = 3, H₂ = 3/2, RHS = 3/2 + e^{3/2} · log(3/2) ≈ 3/2 + 4.48 · 0.405 ≈ 3.31. So 3 ≤ 3.31 ✓. 

**Is there a cleaner way to verify small cases (n ≤ 10) without building an interval arithmetic suite?** Perhaps rational approximation bounds on exp and log from Mathlib?

---

## 6. Session Summary

| Metric | Value |
|---|---|
| Robin/Defs.lean | ✅ Online, 0 sorry, 0 errors |
| Axioms (Robin) | 2 (Lagarias ↔ RH, Robin ↔ RH) |
| Proved (Robin) | 5 theorems |
| Mathlib APIs available | 18 directly relevant |
| Concrete proof targets | 8 identified |
| Estimated difficulty | Targets 1-6: trivial to easy. Targets 7-8: medium |

The Robin Front is the perfect complement to the Nyman-Beurling Cathedral. Every theorem we prove here is pure discrete mathematics — no measure theory, no contour integration, no L² spaces. This is the arithmetic fortress. 🏰
