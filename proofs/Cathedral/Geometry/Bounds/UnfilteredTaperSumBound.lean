/-
  Cathedral/Geometry/UnfilteredTaperSumBound.lean

  ## GRADUATING unfilteredTaperSum_lower: Σ(1-lnk/lnN)² ≥ N/ln²N

  ════════════════════════════════════════════════════════════════

  THE PROOF STRATEGY (Sum-Integral Comparison):

  The taper function f(x) = (1 - ln x / ln N)² is antitone on [1, N].
  By Mathlib's AntitoneOn.integral_le_sum_Ico:

    ∫₁ᴺ f(x) dx ≤ Σ_{k=1}^{N-1} f(k)

  The integral evaluates to:
    ∫₁ᴺ (1 - ln x/ln N)² dx = 2N/ln²N - 1 - 2/lnN - 2/ln²N

  For N ≥ 100: integral ≥ N/ln²N.

  STATUS: Graduates unfilteredTaperSum_lower axiom.
  Created: June 5, 2026 — Sub-Axiom Graduation Campaign 🛡️
-/

import Cathedral.Geometry.Bounds.NormLowerBound
import Mathlib.Analysis.SumIntegralComparisons
import Mathlib.Analysis.SpecialFunctions.Integrals.Basic

set_option maxHeartbeats 1600000

noncomputable section
open Real Finset MeasureTheory Set

namespace Cathedral.Geometry.Bounds.UnfilteredTaperSumBound

open Cathedral.Geometry.Bounds.NormLowerBound

-- ════════════════════════════════════════════════════════════════
-- §1. THE TAPER FUNCTION IS ANTITONE
-- ════════════════════════════════════════════════════════════════

/-- **ANTITONE**: The taper function (1 - ln x / ln N)² is antitone on [1, N]. -/
theorem taperFn_antitone {N : ℝ} (hN : 1 < N) :
    AntitoneOn (fun x => (1 - Real.log x / Real.log N) ^ 2) (Icc 1 N) := by
  intro x hx y hy hxy
  have hlogN : 0 < Real.log N := Real.log_pos hN
  have hx_pos : 0 < x := lt_of_lt_of_le one_pos hx.1
  have hlog_le : Real.log x ≤ Real.log y := Real.log_le_log hx_pos hxy
  have hgy : 1 - Real.log y / Real.log N ≤ 1 - Real.log x / Real.log N := by
    have := div_le_div_of_nonneg_right hlog_le hlogN.le
    linarith
  have hgy_nn : 0 ≤ 1 - Real.log y / Real.log N := by
    rw [sub_nonneg, div_le_one hlogN]
    exact Real.log_le_log (lt_of_lt_of_le one_pos hy.1) hy.2
  exact pow_le_pow_left₀ hgy_nn hgy 2

-- ════════════════════════════════════════════════════════════════
-- §2. SUB-AXIOMS (elementary analysis facts)
-- ════════════════════════════════════════════════════════════════

/-- **INTEGRAL EVALUATION**: ∫₁ᴺ (1 - ln x / ln N)² dx = 2N/ln²N - 1 - 2/lnN - 2/ln²N.

    Verified by the antiderivative F(x) = x(1-lnx/c)² + 2x(1-lnx/c)/c + 2x/c²
    where c = ln N. F'(x) = (1-lnx/c)² by the product rule. -/
axiom integral_taper_sq (N : ℝ) (hN : 1 < N) :
    ∫ x in (1:ℝ)..N, (1 - Real.log x / Real.log N) ^ 2 =
      2 * N / (Real.log N) ^ 2 - 1 - 2 / Real.log N - 2 / (Real.log N) ^ 2

/-- **ELEMENTARY BOUND**: ln²N + 2·lnN + 2 ≤ N for N ≥ 100.

    Equivalent to e^x ≥ x² + 2x + 2 for x ≥ ln 100 > 4.6.
    Holds since e^5 ≈ 148 > 37 = 5²+10+2, and the gap widens. -/
axiom log_sq_add_linear_le_self (N : ℝ) (hN : 100 ≤ N) :
    (Real.log N) ^ 2 + 2 * Real.log N + 2 ≤ N

-- ════════════════════════════════════════════════════════════════
-- §3. THE INTEGRAL LOWER BOUND
-- ════════════════════════════════════════════════════════════════

/-- **INTEGRAL ≥ N/ln²N**: For N ≥ 100, the integral exceeds N/ln²N. -/
theorem integral_ge_N_div_log_sq (N : ℝ) (hN : 100 ≤ N) :
    N / (Real.log N) ^ 2 ≤
    ∫ x in (1:ℝ)..N, (1 - Real.log x / Real.log N) ^ 2 := by
  have hN1 : 1 < N := by linarith
  rw [integral_taper_sq N hN1]
  have hlogN_pos : 0 < Real.log N := Real.log_pos hN1
  have hlogN_ne : Real.log N ≠ 0 := ne_of_gt hlogN_pos
  have hlog2_pos : 0 < (Real.log N) ^ 2 := sq_pos_of_pos hlogN_pos
  have hlog2_ne : (Real.log N) ^ 2 ≠ 0 := ne_of_gt hlog2_pos
  -- Clear denominators: multiply by ln²N > 0
  -- N/ln²N ≤ 2N/ln²N - 1 - 2/lnN - 2/ln²N
  -- ⟺ N ≤ 2N - ln²N - 2lnN - 2  (multiply by ln²N)
  -- ⟺ ln²N + 2lnN + 2 ≤ N
  rw [div_le_iff₀ hlog2_pos]
  have h_clear : (2 * N / (Real.log N) ^ 2 - 1 - 2 / Real.log N -
      2 / (Real.log N) ^ 2) * (Real.log N) ^ 2 =
      2 * N - (Real.log N) ^ 2 - 2 * Real.log N - 2 := by
    field_simp
  rw [h_clear]
  -- Need: N ≤ 2N - ln²N - 2lnN - 2, i.e., ln²N + 2lnN + 2 ≤ N
  linarith [log_sq_add_linear_le_self N hN]

-- ════════════════════════════════════════════════════════════════
-- §4. THE GRADUATION
-- ════════════════════════════════════════════════════════════════

/-- **GRADUATED THEOREM**: unfilteredTaperSum N ≥ N/ln²N for large N.

    Chain:
    - taperFn_antitone: taper² is antitone on [1, N]
    - AntitoneOn.integral_le_sum_Ico: sum ≥ integral (Mathlib)
    - integral_ge_N_div_log_sq: integral ≥ N/ln²N

    This replaces the axiom unfilteredTaperSum_lower. -/
theorem unfilteredTaperSum_lower_proved :
    ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ → N ≥ 3 →
      ↑N / (Real.log ↑N) ^ 2 ≤ unfilteredTaperSum N := by
  use 100
  intro N hN _hN3
  unfold unfilteredTaperSum
  have hN1 : (1:ℝ) < (↑N : ℝ) := by exact_mod_cast show 1 < N by omega
  -- Step 1: integral ≥ N/ln²N
  have h_int := integral_ge_N_div_log_sq (↑N) (by exact_mod_cast hN)
  -- Step 2: the taper function is antitone on [1, N]
  -- Step 2: sum ≥ integral by Mathlib's comparison theorem
  -- AntitoneOn.integral_le_sum_Ico needs AntitoneOn on Icc (↑1 : ℝ) (↑N : ℝ)
  have h_anti : AntitoneOn (fun x => (1 - Real.log x / Real.log ↑N) ^ 2)
      (Icc (↑(1:ℕ) : ℝ) (↑N : ℝ)) := by
    simp only [Nat.cast_one]
    exact taperFn_antitone hN1
  have h1N : (1 : ℕ) ≤ N := by omega
  have h_sum_ge := h_anti.integral_le_sum_Ico h1N
  -- Step 3: Convert Ico 1 N to Icc 1 (N-1)
  have h_Ico_eq : Finset.Ico 1 N = Finset.Icc 1 (N - 1) := by
    ext k; simp [Finset.mem_Ico, Finset.mem_Icc]; omega
  -- Chain: N/ln²N ≤ integral ≤ sum(Ico) = sum(Icc)
  calc (↑N : ℝ) / (Real.log ↑N) ^ 2
      ≤ ∫ x in (1:ℝ)..(↑N:ℝ), (1 - Real.log x / Real.log ↑N) ^ 2 := h_int
    _ ≤ ∑ k ∈ Finset.Ico 1 N, (1 - Real.log ↑k / Real.log ↑N) ^ 2 := by
          -- Bridge: (1:ℝ) = ↑(1:ℕ) in the integral bound only
          convert h_sum_ge using 2
          simp
    _ = ∑ k ∈ Finset.Icc 1 (N - 1), (1 - Real.log ↑k / Real.log ↑N) ^ 2 := by
          rw [h_Ico_eq]

-- ════════════════════════════════════════════════════════════════
-- §5. AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit (June 5, 2026 — Sub-Axiom Graduation)

### Sorry: 0 ✅
### Custom Axioms: 2
  - `integral_taper_sq`: ∫₁ᴺ (1-lnx/lnN)² dx = 2N/ln²N - 1 - 2/lnN - 2/ln²N
    (calculus identity, verifiable by differentiating the antiderivative)
  - `log_sq_add_linear_le_self`: ln²N + 2lnN + 2 ≤ N for N ≥ 100
    (elementary, follows from e^x ≥ x² + 2x + 2 for x ≥ 5)

### Theorems PROVED:
| # | Result | Status | Content |
|---|--------|--------|---------|
| 1 | `taperFn_antitone` | ✅ | (1-lnx/lnN)² antitone on [1,N] |
| 2 | `integral_ge_N_div_log_sq` | ✅ | integral ≥ N/ln²N for N ≥ 100 |
| 3 | `unfilteredTaperSum_lower_proved` | ✅ | The graduation target |

### The Chain:
```
taperFn_antitone: f antitone on [1,N]                [PROVED]
    ↓ AntitoneOn.integral_le_sum_Ico (Mathlib)
sum ≥ integral                                        [MATHLIB]
    ↓ integral_taper_sq (AXIOM: calculus identity)
    + log_sq_add_linear_le_self (AXIOM: elementary bound)
integral ≥ N/ln²N                                     [PROVED]
    ↓
unfilteredTaperSum_lower_proved: Σf ≥ N/ln²N          [PROVED ✅]
```
-/

end Cathedral.Geometry.Bounds.UnfilteredTaperSumBound

end
