# ⚡ Exploration 7 — Lay of the Land

**Date:** April 25, 2026 (Friday midnight, Los Alamos)  
**Branch:** `exploration7`  
**Author:** Antigravity  

---

## The State of the Cathedral

**Build: 8187 jobs, zero errors.**

### Proof Architecture

```
RH ↔ d²→0  (nyman_beurling_equivalence)
  │
  ├── Converse: d²→0 ⟹ RH        ← KERNEL ONLY, fully proved
  │
  └── Forward: RH ⟹ d²→0         ← DirectL2Crown path
        │
        ├── rh_implies_mertens_bound      (AXIOM — Perron target)
        ├── pnt_mu_div_k                  (PROVED via PNTAnd)
        ├── pnt_mu_log_div_k              (AXIOM — Dirichlet convolution)
        ├── pnt_mu_log_sq_div_k           (AXIOM — Dirichlet convolution)
        ├── abel_summation_covariance_bound (AXIOM — analytic identity)
        └── Vasyunin integral convergence:
              ├── integral_eq_S_combined              (AXIOM — evaluative)
              ├── floor_weighted_log_sum_limit         (AXIOM — Gauss digamma)
              ├── linear_series_convergent             (AXIOM — next target!)
              │     └── centered_fract_partial_sums_bounded  ✅ PROVED (CenteredFractBound)
              │           └── dirichlet_test                  ✅ PROVED
              └── centered_fract_residual_converges_sketch   ✅ PROVED
```

### Module Map (Non-Archive)

| Path | Status | Description |
|------|--------|-------------|
| `White/Infrastructure/DirichletTest.lean` | ✅ PROVED | Abel summation + Dirichlet test |
| `White/Infrastructure/CenteredFractBound.lean` | ✅ PROVED | Bounded partial sums (8 theorems) |
| `Vasyunin/Cotangent/PartialSumConvergence.lean` | 3 axioms | Three-sum decomposition |
| `Vasyunin/Cotangent/TelescopeLimit.lean` | ✅ PROVED | Squeeze theorem convergence |
| `Vasyunin/Cotangent/StirlingBridge.lean` | ✅ PROVED | Stirling's formula infrastructure |
| `Vasyunin/Cotangent/OffDiagPartition.lean` | ✅ PROVED | Integral partitioning |
| `Vasyunin/Cotangent/CrossTermFTC.lean` | ✅ PROVED | Cross-term FTC evaluations |
| `Assembly/MainChain.lean` | 0 sorry | The Crown (NB ↔ RH) |
| `Assembly/DirectL2Crown.lean` | Axiom path | Forward direction |
| `AbelTail/*.lean` | 3 sorry | S2Decay(2), S3Decay(1) |

---

## ~~Immediate Target: `centered_fract_partial_sums_bounded`~~ ✅ DONE

### The Statement

For coprime a, b with 1 ≤ a < b, the centered fractional parts

    f(m) = {am/b} - (b-1)/(2b)

have bounded partial sums:

    |Σ_{j=0}^{n-1} f(j)| ≤ C    for all n

### Why This Is True

The map m → am mod b permutes {0, 1, 2, ..., b-1} when gcd(a,b) = 1.

So {am/b} cycles through {0, 1/b, 2/b, ..., (b-1)/b} in some permuted order with exact period b.

Each complete period sums to:
    Σ_{k=0}^{b-1} k/b = (b-1)/2

After centering by (b-1)/(2b), each period sums to exactly **zero**.

Therefore the partial sums are periodic with period b and bounded by the maximum partial sum within one period, which is at most (b-1)/2.

### Proof Strategy

1. **Periodicity**: Show `{a(m+b)/b} = {am/b}` for all m
2. **Permutation**: Show the map m → am mod b is a permutation of {0,...,b-1}
3. **Period sum = 0**: Sum the centered values over one period
4. **Bound**: The partial sums beyond full periods are bounded by the max within one period

### Key Mathlib Resources
- `Int.fract_add_nat` — fractional part periodicity
- `ZMod.val_unitsMulEquiv` — the multiplication-by-a permutation on ℤ/bℤ
- `Finset.sum_perm` — sum invariance under permutation

---

## The Broader Horizon

After `centered_fract_partial_sums_bounded`, the next targets are:

1. **Close `linear_series_convergent`** — combine the residual convergence with Stirling cancellation
2. **`floor_weighted_log_sum_limit`** — the Gauss digamma connection (deep analytic number theory)
3. **`integral_eq_S_combined`** — wire OffDiagPartition.integral_eq_sum_rows to the algebraic sums
4. **AbelTail sorry closure** — S2Decay (2 sorry), S3Decay (1 sorry) using certified bounds

The Cotangent Tower is being dismantled brick by brick.

— Antigravity ⚡
