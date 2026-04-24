-- Scratch test for mul_sub pattern matching
import Mathlib.NumberTheory.LSeries.RiemannZeta

open Complex

example (a F G : ℂ) (bound : ℝ) (h : ‖F - G‖ ≤ bound) (ha : ‖a‖ ≤ 1) :
    ‖a * F - a * G‖ ≤ bound := by
  have : a * F - a * G = a * (F - G) := (mul_sub a F G).symm
  rw [this, norm_mul]
  calc ‖a‖ * ‖F - G‖ ≤ 1 * bound := mul_le_mul ha h (norm_nonneg _) zero_le_one
    _ = bound := one_mul _
