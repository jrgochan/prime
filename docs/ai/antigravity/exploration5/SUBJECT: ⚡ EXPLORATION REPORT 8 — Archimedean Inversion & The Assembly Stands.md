**FROM:** Antigravity  
**TO:** The Theorist  
**SUBJECT:** ⚡ EXPLORATION REPORT 8 — Archimedean Inversion & The Assembly Stands

---

## Status: 1 Sorry Remaining — The Integral Connection

The truncated Perron formula assembly (`truncated_perron_half_integer`) is architecturally complete. Every component of the proof is verified except for one precisely isolated step: the **integral connection** linking the finite Perron sum to the contour integral.

---

## What Was Proved This Session

### §4½. `perron_zeta_integrable` ✅ PROVED
**Integrability of X^s/(sζ(s)) on [-T,T] for c > 1.**

This was the first key missing tool. Pattern lifted from `PerronMoebius.lean:130-153`, but **dramatically simplified** because c > 1 means we use `riemannZeta_ne_zero_of_one_lt_re` instead of `rh_zeta_ne_zero`. No RH needed!

```lean
lemma perron_zeta_integrable (X c T : ℝ) (hX : 0 < X) (hc : 1 < c) :
    IntervalIntegrable (fun t : ℝ =>
      (X : ℂ) ^ (↑c + ↑t * I) /
        ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I)))
      MeasureTheory.volume (-T) T
```

### `rpow_eq_pred_mul` ✅ PROVED
**X^c = X^{c-1} · X for X > 0.** Tiny helper, but essential for the rpow algebra in the tail crush.

### Archimedean N Choice ✅ PROVED
**Dynamic N via `exists_nat_gt` with rpow inversion.**

The key insight: choose N₀ > (C_tail · T² · X)^{1/(c-1)}, then set N = max(m, N₀+1). The rpow inversion uses:
1. `rpow_mul` to compose `(val^{1/(c-1)})^{c-1} = val`
2. `one_div_mul_cancel` for the exponent identity `1/(c-1) · (c-1) = 1`
3. `Real.rpow_lt_rpow` for monotonicity

This gives `h_N_rpow : C_tail * T^2 * X < N^{c-1}`.

### `h_tail_crushed` ✅ PROVED
**C_tail · N^{1-c} · X^c · T ≤ X^{c+1}/T.**

Full calc chain:
```
C_tail · N^{1-c} · X^c · T
  = C_tail/N^{c-1} · X^c · T          [rpow_neg]
  ≤ 1/(T²·X) · X^c · T               [div_le_div_iff₀ + h_N_rpow]
  = X^{c-1}/T                          [rpow_eq_pred_mul + field_simp]
  ≤ X^{c+1}/T                          [rpow_le_rpow_of_exponent_le, X > 1]
```

### Triangle Inequality Assembly ✅ PROVED
**‖M - B‖ ≤ K · X^{c+1} / T** (modulo the integral connection).

Architecture:
- `h_M_AN`: ‖M - A_N‖ ≤ C_sum/(πT) · X^{c+1} — via `norm_sub_rev` + §2+§3
- `h_AN_B`: ‖A_N - B‖ ≤ X^{c+1}/T — **[sorry: integral connection]**
- `h_tri`: ‖M - B‖ ≤ ‖M-A_N‖ + ‖A_N-B‖ — via `norm_add_le`
- `h_final`: sum ≤ K · X^{c+1}/T — via `field_simp` + C_tail > 0

---

## The Final Sorry: `h_AN_B`

The one remaining sorry is at line ~613 in `HalfIntegerPerron.lean`:

```lean
have h_AN_B : ‖A_N - B‖ ≤ X ^ (c + 1) / T := by
  sorry
```

Where:
- `A_N = ∑_{n=1}^N μ(n) · perronIntegral(X/n, c, T)` — finite Perron sum
- `B = (1/(2π)) · ∫_{-T}^T X^s/(sζ(s)) dt` — contour integral

### What's Needed

The proof requires three sub-steps:

1. **Sum-to-integral conversion** (have `finite_sum_integral_swap`):
   ```
   A_N = (1/(2π)) · ∫ ∑ μ(n)(X/n)^s/s dt
   ```

2. **Algebraic factoring**:
   ```
   ∑ μ(n)(X/n)^s/s = (∑ μ(n)/n^s) · X^s/s
   ```
   This is just `Finset.sum_div` + `cpow_div` algebra.

3. **Integral difference** (use `intervalIntegral.integral_sub` + `perron_zeta_integrable`):
   ```
   A_N - B = (1/(2π)) · ∫ [(∑μ(n)/n^s) - 1/ζ(s)] · X^s/s dt
   ```
   This is exactly the expression bounded by §4 (`h_tail_bound`).

4. **Apply `h_tail_bound` + `h_tail_crushed`**:
   ```
   ‖A_N - B‖ ≤ C_tail · N^{1-c} · X^c · T ≤ X^{c+1}/T
   ```

### Tools Available
- `finite_sum_integral_swap` in DirichletPoly.lean (proved)
- `perron_zeta_integrable` (just proved)
- `intervalIntegral.integral_sub` (Mathlib)
- Pattern from PerronMoebius.lean:159-166 (exact blueprint)

### Technical Challenge
The main difficulty is **type-matching**: showing that the algebraically-factored integral matches the expression in `h_tail_bound`. This requires careful `simp_rw` / `congr` work to align:
- `(X/n)^s/s` with `(μ(n)/n^s) · X^s/s`
- The integrand of `B` with `X^s/(s·ζ(s)) = (1/ζ(s)) · X^s/s`

---

## Architecture Summary

```
§0. half_integer_log_bound          ✅ (log bounds at half-integers)
§1. perron_kernel_bound             ✅ (unified y > 1 / y < 1 kernel)
§2. perron_formula_error_bound_full ✅ (kernel error ≤ C_sum/(πT)·X^{c+1})
§3. perron_log_sum_bound            ✅ (∑ log sum ≤ C_sum·X^{c+1})
§4. dirichlet_tail_integral_bound   ✅ (tail ≤ C_tail·N^{1-c}·X^c·T)
§4½ perron_zeta_integrable          ✅ (integrability, no RH)
    rpow_eq_pred_mul                ✅ (X^c = X^{c-1}·X)
§5. truncated_perron_half_integer   1 sorry (integral connection h_AN_B)
    ├── Dynamic N (Archimedean)     ✅
    ├── h_N_rpow                    ✅ (N^{c-1} > C_tail·T²·X)
    ├── h_tail_crushed              ✅ (tail ≤ X^{c+1}/T)
    ├── h_M_AN (kernel bound)       ✅
    ├── h_AN_B (integral conn.)     ❌ sorry
    ├── h_tri (triangle)            ✅
    └── h_final (K absorption)      ✅
§6. summatoryMoebius_eq_half_integer ✅ (transfer to general x)
```

## Recommendation

The integral connection is a **plumbing** problem, not a mathematical one. All the hard analysis is done. The remaining work is:
1. Apply `finite_sum_integral_swap` to rewrite A_N as an integral
2. Factor `∑ μ(n)(X/n)^s/s = D_N(s)·X^s/s` algebraically  
3. Use `integral_sub` to form A_N - B
4. Apply `h_tail_bound` + `h_tail_crushed`

This is entirely analogous to what `PerronMoebius.lean:159-166` does (lines I highlighted in the deep scan). The pattern is: `← mul_sub, intervalIntegral.integral_sub h_int_f h_int_g`.

The Cathedral is one sorry from zero. The integral connection is the final bridge. 🏗️
