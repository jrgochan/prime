/-
  Cathedral/White/Infrastructure/ZetaConvexityBound.lean

  ## Convexity Bound for |ζ(s)| in the Critical Strip

  Target: ‖ζ(s)‖ ≤ (2 + |s.im|)² for 1/2 < Re(s) ≤ 2, |Im(s)| ≥ 1/2.

  ### Strategy (based on FloorMellin.lean)

  From `floor_mellin_eq_zeta` (PROVED in FloorMellin.lean, zero sorry):
    ∫₀¹ ⌊1/t⌋ · t^{s-1} dt = ζ(s)/s   for Re(s) > 1

  Decomposing ⌊1/t⌋ = 1/t - {1/t}:
    ζ(s) = s/(s-1) - s · ∫₀¹ {1/t} · t^{s-1} dt

  Bounding (for σ > 1, |t| ≥ 1/2):
    |ζ(s)| ≤ |s|/|s-1| + |s|/σ ≤ (1+1/|t|) + (1+|t|) ≤ 4+|t| ≤ (2+|t|)²

  ### Dependencies: Mathlib (ζ, L-series), FloorMellin, ThetaBound
-/

import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.LSeries.Dirichlet
import Mathlib.NumberTheory.LSeries.Nonvanishing
import Cathedral.MellinBridge.FloorMellin
import Cathedral.NymanBeurling.ThetaBound

noncomputable section
open Complex Real Filter MeasureTheory
open scoped Topology

namespace Cathedral.White.Infrastructure.ZetaConvexityBound

-- ════════════════════════════════════════════════════
-- §1. Arithmetic lemma
-- ════════════════════════════════════════════════════

/-- 4 + |t| ≤ (2 + |t|)² for all t : ℝ.
    Proof: (2+|t|)² = 4 + 4|t| + t² ≥ 4 + |t| since 3|t| + t² ≥ 0. -/
lemma four_add_abs_le_sq (t : ℝ) : 4 + |t| ≤ (2 + |t|) ^ 2 := by
  nlinarith [abs_nonneg t, sq_abs t]

-- ════════════════════════════════════════════════════
-- §2. Decomposition from FloorMellin
-- ════════════════════════════════════════════════════

/-- From `floor_mellin_eq_zeta`, we derive the bound ‖ζ(s)‖ ≤ 4 + |s.im| for Re(s) > 1.

    Proof sketch:
    1. floor_mellin_eq_zeta: ∫₀¹ ⌊1/t⌋·t^{s-1} dt = ζ(s)/s
    2. Split ⌊1/t⌋ = 1/t - {1/t}
    3. ∫₀¹ t^{s-2} dt = 1/(s-1)
    4. So ζ(s) = s/(s-1) - s·∫₀¹ {1/t}·t^{s-1} dt
    5. |∫ {1/t}·t^{s-1} dt| ≤ ∫ t^{σ-1} dt = 1/σ
    6. |ζ(s)| ≤ |s/(s-1)| + |s|/σ
    7. |s/(s-1)| = |1 + 1/(s-1)| ≤ 1 + 1/|s-1| ≤ 1 + 1/|t|
    8. |s|/σ ≤ (σ+|t|)/σ = 1 + |t|/σ ≤ 1 + |t|
    9. Total ≤ (1+1/|t|) + (1+|t|) ≤ 1+2+1+|t| = 4+|t| -/
private lemma norm_zeta_le_of_re_gt_one {s : ℂ}
    (hs : 1 < s.re) (hs2 : s.re ≤ 2) (him : 1/2 ≤ |s.im|) :
    ‖riemannZeta s‖ ≤ 4 + |s.im| := by
  sorry

-- ════════════════════════════════════════════════════
-- §3. Main convexity bound
-- ════════════════════════════════════════════════════

/-- **Convexity bound**: ‖ζ(s)‖ ≤ (2 + |s.im|)² for 1/2 < Re(s) ≤ 2, |Im(s)| ≥ 1/2.

    For Re(s) > 1: Uses FloorMellin decomposition ζ(s) = s/(s-1) - s·∫.
    For 1/2 < Re(s) ≤ 1: Uses analytic continuation of the integral formula
    (via the identity theorem: `AnalyticOnNhd.eqOn_of_preconnected_of_eventuallyEq`).

    Downstream dependency chain:
    zeta_norm_convexity_bound → zeta_norm_bound_on_disk → BC theorem →
    zeta_polynomial_lower_bound_rh → Perron formula → MainChain. -/
theorem zeta_norm_convexity_bound {s : ℂ}
    (hrs : 1/2 < s.re) (hrs2 : s.re ≤ 2) (him : 1/2 ≤ |s.im|) :
    ‖riemannZeta s‖ ≤ (2 + |s.im|) ^ (2 : ℝ) := by
  by_cases hre : 1 < s.re
  · -- Case 1: Re(s) > 1 — direct from FloorMellin decomposition
    have h1 := norm_zeta_le_of_re_gt_one hre hrs2 him
    have h2 := four_add_abs_le_sq s.im
    -- (2+|t|)^2 ≤ (2+|t|)^(2:ℝ) since they're equal via rpow_natCast
    calc ‖riemannZeta s‖
        ≤ 4 + |s.im| := h1
      _ ≤ (2 + |s.im|) ^ 2 := h2
      _ = (2 + |s.im|) ^ (2 : ℝ) := by
          rw [show (2 : ℝ) = ((2 : ℕ) : ℝ) from by norm_num, rpow_natCast]
  · -- Case 2: 1/2 < Re(s) ≤ 1 — needs analytic continuation
    -- The integral ∫₀¹ {1/t}·t^{s-1} dt converges for Re(s) > 0 and defines
    -- an analytic function. By the identity theorem
    -- (AnalyticOnNhd.eqOn_of_preconnected_of_eventuallyEq), the formula
    -- ζ(s) = s/(s-1) - s·∫₀¹ {1/t}·t^{s-1} dt extends from Re(s) > 1 to Re(s) > 0.
    -- The same bound |ζ(s)| ≤ 4+|t| then applies.
    sorry

end Cathedral.White.Infrastructure.ZetaConvexityBound
