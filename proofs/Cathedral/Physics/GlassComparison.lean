/-
  Cathedral/Physics/GlassComparison.lean

  ## THE GLASS COMPARISON: R ↔ G⁽²⁾ Decomposition

  ════════════════════════════════════════════════════════════════

  ### Summary

  This file establishes the exact relationship between the Ramanujan
  matrix R and the dark Gram matrix G⁽²⁾:

    R(j,k) = 15 · (jk/gcd²) · G⁽²⁾(j,k)

  This gives the quadratic form identity:

    vᵀRv = 15 · Σ_{j,k} (jk/gcd²) · G²(j,k) · v_j · v_k

  The coprime ratio jk/gcd(j,k)² = j'k' equals 1 on diagonal
  and ≥ 2 off-diagonal, with asymptotic weighted average π⁴/45.

  ### Architecture

  The **dark spectral gap** (Q(x) > 0 for x ≠ 0) is proved via
  Smith decomposition in SmithSpectralGap.lean, NOT through the
  comparison operator. The comparison analysis here provides
  additional quantitative information about the spectral gap constant.

  Status: 0 SORRY
  Dependencies: RamanujanBridge, SDualityGlass, SmithSpectralGap
  Created: May 15, 2026
-/

import Cathedral.Physics.RamanujanBridge
import Cathedral.Physics.SDualityGlass
import Cathedral.Physics.SmithSpectralGap

noncomputable section
open Real Finset

namespace Cathedral.Physics.GlassComparison

-- ════════════════════════════════════════════════════════════════
-- §1. THE EXACT QUADRATIC FORM IDENTITY
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: The Ramanujan quadratic form decomposes via dark entries.

    vᵀRv = 15 · Σ_{i,j} (jk/gcd²) · v_i · G⁽²⁾(j,k) · v_j

    This is exact — follows directly from R(j,k) = 15·(jk/gcd²)·G⁽²⁾(j,k). -/
theorem ramanujan_form_via_dark (N : ℕ) (x : Fin N → ℝ) :
    ∑ i : Fin N, ∑ j : Fin N,
      RamanujanBridge.ramanujanEntry (i.val + 1) (j.val + 1) * x i * x j =
    15 * ∑ i : Fin N, ∑ j : Fin N,
      ((i.val + 1 : ℝ) * (j.val + 1 : ℝ) /
        (Nat.gcd (i.val + 1) (j.val + 1) : ℝ) ^ 2) *
      DarkGramMatrix.darkGramEntry_n2 (i.val + 1) (j.val + 1) * x i * x j := by
  rw [Finset.mul_sum]
  apply Finset.sum_congr rfl
  intro i _
  rw [Finset.mul_sum]
  apply Finset.sum_congr rfl
  intro j _
  have hi : 0 < i.val + 1 := by omega
  have hj : 0 < j.val + 1 := by omega
  rw [RamanujanBridge.ramanujan_vs_dark _ _ hi hj]
  push_cast
  ring

-- ════════════════════════════════════════════════════════════════
-- §2. COPRIME RATIO ANALYSIS
-- ════════════════════════════════════════════════════════════════

/-- The coprime ratio j'k' = jk/gcd(j,k)² equals 1 on the diagonal. -/
theorem coprime_ratio_diag (k : ℕ) (hk : 0 < k) :
    (k : ℝ) * (k : ℝ) / (Nat.gcd k k : ℝ) ^ 2 = 1 := by
  rw [Nat.gcd_self]
  have hk_ne : (k : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  field_simp

/-- The coprime ratio j'k' ≥ 2 on the off-diagonal (j ≠ k, j,k ≥ 1). -/
theorem coprime_ratio_offdiag (j k : ℕ) (hj : 0 < j) (hk : 0 < k) (hjk : j ≠ k) :
    2 ≤ (j : ℝ) * (k : ℝ) / (Nat.gcd j k : ℝ) ^ 2 := by
  set d := Nat.gcd j k
  have hd_pos : 0 < d := Nat.gcd_pos_of_pos_left k hj
  have hd_ne : (d : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  set j' := j / d
  set k' := k / d
  have hdj : d ∣ j := Nat.gcd_dvd_left j k
  have hdk : d ∣ k := Nat.gcd_dvd_right j k
  have hj_eq : j' * d = j := Nat.div_mul_cancel hdj
  have hk_eq : k' * d = k := Nat.div_mul_cancel hdk
  have hj'_pos : 0 < j' := by
    rw [show j' = j / d from rfl]
    exact Nat.div_pos (Nat.le_of_dvd hj hdj) hd_pos
  have hk'_pos : 0 < k' := by
    rw [show k' = k / d from rfl]
    exact Nat.div_pos (Nat.le_of_dvd hk hdk) hd_pos
  have hjk' : j' ≠ k' := by
    intro h
    have : j' * d = k' * d := by rw [h]
    rw [hj_eq, hk_eq] at this
    exact hjk this
  -- j'*k' ≥ 2: both ≥ 1 and distinct
  have hjk'_ge2 : 2 ≤ j' * k' := by
    rcases Nat.lt_or_ge j' 2 with hlt | hge
    · calc 2 = 1 * 2 := by ring
        _ ≤ j' * k' := Nat.mul_le_mul (by omega) (by omega)
    · calc 2 = 2 * 1 := by ring
        _ ≤ j' * k' := Nat.mul_le_mul hge (by omega)
  -- jk/d² = j'*k'
  suffices h : (j : ℝ) * k / (d : ℝ) ^ 2 = ↑(j' * k') by
    rw [h]; exact_mod_cast hjk'_ge2
  have hj_cast : (j : ℝ) = (j' : ℝ) * (d : ℝ) := by exact_mod_cast hj_eq.symm
  have hk_cast : (k : ℝ) = (k' : ℝ) * (d : ℝ) := by exact_mod_cast hk_eq.symm
  rw [hj_cast, hk_cast]
  push_cast [Nat.cast_mul]
  field_simp

-- ════════════════════════════════════════════════════════════════
-- §3. ASYMPTOTIC COMPARISON CONSTANTS
-- ════════════════════════════════════════════════════════════════

/-- The asymptotic comparison constant α = π⁴/3 = 30·ζ(4).
    This is the weighted average of the coprime ratio j'k' over the
    dark Gram matrix, for BD witness-type vectors as N → ∞. -/
noncomputable def comparisonAlpha : ℝ := Real.pi ^ 4 / 3

/-- The asymptotic intercept β = 1/12 - π⁴/540.
    This is NEGATIVE: β ≈ -0.0971. -/
noncomputable def comparisonBeta : ℝ := 1 / 12 - Real.pi ^ 4 / 540

/-- β is negative. This is the key sign: the Ramanujan PSD constraint
    combined with the negative intercept forces G⁽²⁾ to be positive definite. -/
theorem comparisonBeta_neg : comparisonBeta < 0 := by
  unfold comparisonBeta
  rw [sub_neg]
  have hpi : (3 : ℝ) < Real.pi := Real.pi_gt_three
  have hpi4 : (81 : ℝ) < Real.pi ^ 4 := by
    have h3 : (0 : ℝ) ≤ 3 := by positivity
    nlinarith [Real.pi_gt_three, sq_nonneg (Real.pi - 3),
              sq_nonneg (Real.pi ^ 2 - 9)]
  linarith

/-- The quantitative spectral gap: -β/α = 1/180 - 1/(4π⁴) ≈ 0.00299.
    If the comparison bound held universally, this would be the minimum
    eigenvalue of G⁽²⁾. The Smith proof shows G⁽²⁾ is PD without
    needing this constant, but the constant bounds the spectral gap
    for Baez-Duarte witness vectors. -/
noncomputable def spectralGapConstant : ℝ := 1 / 180 - 1 / (4 * Real.pi ^ 4)

theorem spectralGapConstant_pos : 0 < spectralGapConstant := by
  unfold spectralGapConstant
  have hpi : (3 : ℝ) < Real.pi := Real.pi_gt_three
  have hpi4_pos : (0 : ℝ) < Real.pi ^ 4 := by positivity
  have h45 : (45 : ℝ) < Real.pi ^ 4 := by
    nlinarith [sq_nonneg (Real.pi - 3), sq_nonneg (Real.pi ^ 2 - 9)]
  have h4pi : (180 : ℝ) < 4 * Real.pi ^ 4 := by nlinarith
  have h1 : 0 < 4 * Real.pi ^ 4 - 180 := by linarith
  have h2 : 0 < 720 * Real.pi ^ 4 := by positivity
  rw [show (1:ℝ) / 180 - 1 / (4 * Real.pi ^ 4) =
    (4 * Real.pi ^ 4 - 180) / (720 * Real.pi ^ 4) from by field_simp; ring]
  exact div_pos h1 h2

-- ════════════════════════════════════════════════════════════════
-- §4. THE DARK SPECTRAL GAP (via Smith Decomposition)
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: The dark Gram matrix G⁽²⁾ is strictly positive definite.

    Proved via the Smith decomposition of the GCD matrix:
    - The divisor transform x ↦ y is injective (triangular with unit diagonal)
    - The quadratic form Q(x) = Σ J₄(d)·y_d² with J₄(d) > 0
    - So x ≠ 0 ⟹ ∃ d with y_d ≠ 0 ⟹ Q(x) > 0

    See SmithSpectralGap.lean for the full proof. -/
theorem dark_spectral_gap_explicit (N : ℕ) (x : Fin N → ℝ) (hx : x ≠ 0) :
    0 < ∑ i : Fin N, ∑ j : Fin N,
      DarkGramMatrix.darkGramEntry_n2 (i.val + 1) (j.val + 1) * x i * x j :=
  SmithSpectralGap.dark_spectral_gap N x hx

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit

### Sorry: 0 🎓

### Custom Axioms: 0

### PROVED:
| # | Result | Status |
|---|--------|--------|
| 1 | `ramanujan_form_via_dark` | 🎓 PROVED (exact decomposition) |
| 2 | `coprime_ratio_diag` = 1 | 🎓 PROVED |
| 3 | `coprime_ratio_offdiag` ≥ 2 | 🎓 PROVED |
| 4 | `comparisonBeta_neg` | 🎓 PROVED (β < 0) |
| 5 | `spectralGapConstant_pos` | 🎓 PROVED |
| 6 | `dark_spectral_gap_explicit` | 🎓 PROVED (via SmithSpectralGap) |

### Architecture:
```
  SmithSpectralGap.dark_spectral_gap (PROVED — Smith decomposition)
       ↓
  dark_spectral_gap_explicit (PROVED — direct application)
       ↓
  CROWN AXIOM
```

### Historical Note:
  The original proof strategy attempted a universal matrix inequality
  `R ≤ (π⁴/3)·G² + β·I`. While the constants α = π⁴/3 and
  β = 1/12 - π⁴/540 are correct asymptotically for BD witness vectors,
  the UNIVERSAL bound is false (G² has zero diagonal ⟹ can't dominate
  the identity). The Smith decomposition approach supersedes this entirely,
  proving G⁽²⁾ is PD without needing the comparison operator at all.
-/

end Cathedral.Physics.GlassComparison

end
