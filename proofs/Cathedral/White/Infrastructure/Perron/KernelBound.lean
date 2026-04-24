import Cathedral.White.Infrastructure.Perron.ResidueGtOne
import Cathedral.White.Infrastructure.Perron.ResidueLtOne

/-!
# The Unified Perron Kernel Bound

This file combines the `y > 1` (residue = 1) and `y < 1` (residue = 0) cases
into the unified Perron kernel theorem: for `y > 0`, `y ≠ 1`,
`‖P(y,c,T) - 𝟙(y > 1)‖ ≤ y^c / (π·T·|log y|)`.

## Main results

* `perron_kernel_bound` : the unified Perron kernel approximation bound
-/

noncomputable section
open Complex Real MeasureTheory Set BigOperators ComplexConjugate

namespace Cathedral.White.Infrastructure

-- ═══════════════════════════════════════════
-- §8. The Unified Perron Kernel Bound
-- ═══════════════════════════════════════════

/-- **UNIFIED PERRON KERNEL**: The Perron integral approximates the step function.

    For any y > 0, y ≠ 1:
    |(1/2πi) ∫_{c-iT}^{c+iT} y^s/s ds - 𝟙(y > 1)| ≤ y^c / (π·T·|log y|) -/
theorem perron_kernel_bound (y c T : ℝ) (hy : 0 < y) (hy_ne : y ≠ 1)
    (hc : 0 < c) (hT : 0 < T) :
    ‖perronIntegral y c T - (if 1 < y then 1 else 0)‖ ≤
    y ^ c / (Real.pi * T * |Real.log y|) := by
  by_cases h : 1 < y
  · simp only [h, ↑ite_true]
    exact perron_kernel_gt_one y c T h hc hT
  · push Not at h
    have hlt : y < 1 := lt_of_le_of_ne h hy_ne
    simp only [show ¬(1 < y) from not_lt.mpr (le_of_lt hlt), ↑ite_false]
    simp only [sub_zero]
    exact perron_kernel_lt_one y c T hy hlt hc hT

end Cathedral.White.Infrastructure
