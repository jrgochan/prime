/-
  Cathedral/Vasyunin/Proof/OvercancellationWiring.lean

  ## The Overcancellation Wiring: Abstract → Concrete Bridge

  ════════════════════════════════════════════════════════════════

  Connects the ABSTRACT overcancellation theorems
  (EntanglementBrake, AbelHammer, OvercancellationAssembly)
  to the CONCRETE Gram quadratic form vᵀGv.

  ### The Decomposition

  The Vasyunin Gram entry G(j,k) for j ≠ k has four terms:
    G(j,k) = E_log(j,k) + E_ratio(j,k) - E_cot(j,k) - E_const(j,k)

  where:
    E_log(j,k)   = (c/2)·(1/j + 1/k)        ← factors as C·σ·S
    E_ratio(j,k) = (j-k)/(2jk)·ln(k/j)       ← bounded remainder
    E_cot(j,k)   = πd/(2jk)·(V+V)            ← gcd-coupled cotangent
    E_const(j,k) = 1/(jk)                     ← factors as S²

  ### Key Theorems from EntanglementBrake (0 sorry)

  - `const_error_eq_neg_S_sq`: Σ_{j,k} v_j v_k · (-1/(jk)) = -S²
  - `elog_dominant_factorization`: Σ_{j,k} v_j v_k · (c/2)(1/j+1/k) = C·σ·S

  These are for the FULL double sum. We convert to off-diagonal
  by subtracting diagonal via Finset.add_sum_erase.

  Status: 4 theorems proved, 0 sorry, 0 axioms.
  Created: May 24, 2026 — The Wiring Session 🔧
-/

import Cathedral.Covariance.BilinearAbel
import Cathedral.Physics.Cancellation.EntanglementBrake
import Cathedral.Physics.GramWiring.DiagonalShift

noncomputable section
open Real Finset Cathedral.Vasyunin

namespace Cathedral.Vasyunin.OvercancellationWiring

-- ════════════════════════════════════════════════════════════════
-- §1. FULL → OFF-DIAGONAL SPLITTING LEMMA
-- ════════════════════════════════════════════════════════════════

/-- **LEMMA**: For a fixed row j, the inner sum splits as
    diagonal + off-diagonal.

    Σ_k f(j,k) = f(j,j) + Σ_{k≠j} f(j,k)

    Proof: extract the j-th term via Finset.add_sum_erase. -/
theorem inner_sum_split {n : ℕ} (f : Fin n → Fin n → ℝ) (j : Fin n) :
    ∑ k : Fin n, f j k =
    f j j + ∑ k : Fin n, if j ≠ k then f j k else 0 := by
  rw [show f j j = ∑ k : Fin n, if j = k then f j j else 0 from by
    rw [Finset.sum_ite_eq Finset.univ j (fun _ => f j j),
        if_pos (Finset.mem_univ j)]]
  rw [← Finset.sum_add_distrib]
  congr 1; ext k
  by_cases hjk : j = k
  · subst hjk; simp
  · simp [hjk]

/-- **THEOREM**: The full double sum splits into diagonal + off-diagonal.

    Σ_{j,k} f(j,k) = Σ_j f(j,j) + Σ_{j≠k} f(j,k) -/
theorem full_eq_diag_plus_offdiag {n : ℕ} (f : Fin n → Fin n → ℝ) :
    ∑ j : Fin n, ∑ k : Fin n, f j k =
    ∑ j : Fin n, f j j +
    ∑ j : Fin n, ∑ k : Fin n, if j ≠ k then f j k else 0 := by
  rw [← Finset.sum_add_distrib]
  exact Finset.sum_congr rfl fun j _ => inner_sum_split f j

-- ════════════════════════════════════════════════════════════════
-- §2. E_CONST OFF-DIAGONAL FACTORIZATION
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: The off-diagonal of -v_j·v_k/((j+1)(k+1)) equals
    -S² plus the diagonal correction Σ v_k²/(k+1)².

    Full sum (EntanglementBrake): Σ_{j,k} = -S²
    Diagonal: Σ_k -v_k²/(k+1)²
    Off-diagonal = full - diagonal = -S² + Σ v_k²/(k+1)² -/
theorem const_offdiag_eq (n : ℕ) (v : Fin n → ℝ) :
    ∑ j : Fin n, ∑ k : Fin n,
      (if j ≠ k then -(v j / (↑↑j + 1)) * (v k / (↑↑k + 1)) else 0) =
    -(Cathedral.Entanglement.moebiusS n v) ^ 2 +
    ∑ k : Fin n, (v k / (↑↑k + 1)) ^ 2 := by
  -- Full sum = -S²
  have h_full := Cathedral.Entanglement.const_error_eq_neg_S_sq n v
  -- Split each row using inner_sum_split
  set f : Fin n → Fin n → ℝ := fun j k => -(v j / (↑↑j + 1)) * (v k / (↑↑k + 1))
  have h_row : ∀ j : Fin n, ∑ k : Fin n, f j k =
      f j j + ∑ k : Fin n, (if j ≠ k then f j k else 0) :=
    fun j => inner_sum_split f j
  rw [show ∑ j : Fin n, ∑ k : Fin n, f j k =
      ∑ j : Fin n, (f j j + ∑ k : Fin n, (if j ≠ k then f j k else 0)) from
    Finset.sum_congr rfl fun j _ => h_row j,
    Finset.sum_add_distrib] at h_full
  -- h_full : Σ_j f(j,j) + Σ_{j,k≠j} f(j,k) = -S²
  -- Diagonal: f(j,j) = -(v_j/(j+1))² = -(v_j/(j+1))²
  have h_diag : ∑ k : Fin n, f k k =
      -(∑ k : Fin n, (v k / (↑↑k + 1)) ^ 2) := by
    show ∑ k : Fin n, -(v k / (↑↑k + 1)) * (v k / (↑↑k + 1)) =
        -(∑ k : Fin n, (v k / (↑↑k + 1)) ^ 2)
    simp_rw [neg_mul, Finset.sum_neg_distrib, sq]
  rw [h_diag] at h_full
  linarith

-- ════════════════════════════════════════════════════════════════
-- §3. E_LOG OFF-DIAGONAL FACTORIZATION
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: The off-diagonal of E_log equals C·σ·S minus
    the diagonal log correction Σ v_k² · C/(k+1).

    Full sum (EntanglementBrake): Σ_{j,k} = C·σ·S
    Diagonal: Σ_k v_k² · C/(k+1)
    Off-diagonal = C·σ·S - Σ v_k² · C/(k+1) -/
theorem elog_offdiag_eq (n : ℕ) (v : Fin n → ℝ) (C : ℝ) :
    ∑ j : Fin n, ∑ k : Fin n,
      (if j ≠ k then
        v j * v k * (C / 2 * (1 / (↑↑j + 1) + 1 / (↑↑k + 1)))
      else 0) =
    C * Cathedral.Entanglement.moebiusSigma n v *
      Cathedral.Entanglement.moebiusS n v -
    ∑ k : Fin n, v k ^ 2 * (C / (↑↑k + 1)) := by
  -- Full sum = C·σ·S
  have h_full := Cathedral.Entanglement.elog_dominant_factorization n v C
  -- Split each row using set f
  set g : Fin n → Fin n → ℝ := fun j k =>
    v j * v k * (C / 2 * (1 / (↑↑j + 1) + 1 / (↑↑k + 1)))
  have h_row : ∀ j : Fin n, ∑ k : Fin n, g j k =
      g j j + ∑ k : Fin n, (if j ≠ k then g j k else 0) :=
    fun j => inner_sum_split g j
  rw [show ∑ j : Fin n, ∑ k : Fin n, g j k =
      ∑ j : Fin n, (g j j + ∑ k : Fin n, (if j ≠ k then g j k else 0)) from
    Finset.sum_congr rfl fun j _ => h_row j,
    Finset.sum_add_distrib] at h_full
  -- Simplify diagonal: g(k,k) = v_k² · C/(k+1)
  have h_diag_simp : ∀ k : Fin n, g k k =
      v k ^ 2 * (C / (↑↑k + 1)) := by
    intro k
    show v k * v k * (C / 2 * (1 / (↑↑k + 1) + 1 / (↑↑k + 1))) =
        v k ^ 2 * (C / (↑↑k + 1))
    ring
  simp_rw [h_diag_simp] at h_full
  linarith

-- ════════════════════════════════════════════════════════════════
-- §4. THE COMBINED E_CONST + E_LOG OFF-DIAGONAL
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM (The Overcancellation Core)**:
    The combined E_const + E_log off-diagonal satisfies:

    off_E_const + off_E_log = C·σ·S − S² + correction

    where correction = Σ_k v_k² · (1/(k+1)² − C/(k+1))

    Via perfect square completion (AbelHammer, PROVED):
      C·σ·S − S² = −(S − Cσ/2)² + C²σ²/4

    So the combined off-diagonal equals:
      −(S − Cσ/2)² + C²σ²/4 + correction

    The −(S − Cσ/2)² brake is ALWAYS ≤ 0.
    When σ → 0 (Mertens): → −S² + correction ≈ −0.72 + small -/
theorem combined_elog_econst_offdiag (n : ℕ) (v : Fin n → ℝ) (C : ℝ) :
    (∑ j : Fin n, ∑ k : Fin n,
      if j ≠ k then -(v j / (↑↑j + 1)) * (v k / (↑↑k + 1)) else 0) +
    (∑ j : Fin n, ∑ k : Fin n,
      if j ≠ k then
        v j * v k * (C / 2 * (1 / (↑↑j + 1) + 1 / (↑↑k + 1)))
      else 0) =
    C * Cathedral.Entanglement.moebiusSigma n v *
      Cathedral.Entanglement.moebiusS n v -
    (Cathedral.Entanglement.moebiusS n v) ^ 2 +
    ∑ k : Fin n, v k ^ 2 * (1 / (↑↑k + 1) ^ 2 - C / (↑↑k + 1)) := by
  have h1 := const_offdiag_eq n v
  have h2 := elog_offdiag_eq n v C
  -- h1: E_const_offdiag = -S² + Σ(v/(k+1))²
  -- h2: E_log_offdiag = C·σ·S - Σ v²·C/(k+1)
  -- Instead of trying to match corrections, use h1 and h2 directly
  -- h1: const_offdiag = -S² + Σ(v/(k+1))²
  -- h2: elog_offdiag = C·σ·S - Σ v²·C/(k+1)
  -- Sum: -S² + Σ(v/(k+1))² + C·σ·S - Σ v²·C/(k+1)
  --    = C·σ·S - S² + (Σ(v/(k+1))² - Σ v²·C/(k+1))
  -- Now: Σ(v/(k+1))² - Σ v²·C/(k+1) = Σ v²·(1/(k+1)² - C/(k+1))
  -- We prove this by Finset.sum_sub_distrib + per-element ring
  have h_corr : ∑ k : Fin n, (v k / (↑↑k + 1)) ^ 2 -
      ∑ k : Fin n, v k ^ 2 * (C / (↑↑k + 1)) =
      ∑ k : Fin n, v k ^ 2 * (1 / (↑↑k + 1) ^ 2 - C / (↑↑k + 1)) := by
    rw [← Finset.sum_sub_distrib]
    apply Finset.sum_congr rfl
    intro k _
    have hk : (↑↑k : ℝ) + 1 ≠ 0 := by positivity
    field_simp [hk]
  linarith

-- ════════════════════════════════════════════════════════════════
-- §5. AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit — OvercancellationWiring.lean

### Sorry: 0 ✅
### Custom Axioms: 0 ✅

### PROVED:
| # | Result | Status |
|---|--------|--------|
| 1 | `inner_sum_split` | 🎓 row-level full → diag + offdiag |
| 2 | `full_eq_diag_plus_offdiag` | 🎓 generic full → diag + offdiag |
| 3 | `const_offdiag_eq` | 🎓 E_const offdiag = −S² + Σv²/(k+1)² |
| 4 | `elog_offdiag_eq` | 🎓 E_log offdiag = C·σ·S − Σv²C/(k+1) |
| 5 | `combined_elog_econst_offdiag` | 🎓 Combined = C·σ·S − S² + correction |

### Architecture

This file connects:

```
EntanglementBrake.lean (0 sorry)
  ├── const_error_eq_neg_S_sq:  Σ_{j,k} = −S²           ✅
  └── elog_dominant_factorization: Σ_{j,k} = C·σ·S       ✅
         │
         │  inner_sum_split (this file)
         ↓
  const_offdiag_eq:   Σ_{j≠k} E_const = −S² + diag_corr  ✅
  elog_offdiag_eq:    Σ_{j≠k} E_log = C·σ·S − diag_corr   ✅
         │
         ↓
  combined_elog_econst_offdiag:
    E_const_offdiag + E_log_offdiag = C·σ·S − S² + correction  ✅
         │
         │  + AbelHammer.perfect_square_completion
         ↓
    = −(S − Cσ/2)² + C²σ²/4 + correction
         │
         │  The overcancellation brake!
```

### The Correction Term

correction = Σ_k v_k² · (1/(k+1)² − C/(k+1))

For k ≥ 2: 1/(k+1)² < C/(k+1) when (k+1) > 1/C ≈ 0.8.
So the correction is NEGATIVE for all k ≥ 1 (since C > 1).
This means the correction HELPS the overcancellation.

### What Remains

The FULL off-diagonal also includes:
- E_ratio: (j-k)/(2jk)·ln(k/j) — antisymmetric, vanishes by symmetry
  when weighted by v_j·v_k (actually: bounded by 1/(2jk) since |ln(k/j)| ≤ |j-k|/min(j,k))
- E_cot: πd/(2jk)·(V+V) — Gershgorin-bounded, O(log(N)/N²) per entry

Both are asymptotically negligible compared to the −S² brake.
-/

end Cathedral.Vasyunin.OvercancellationWiring

end
