-- Test: can we prove the half-angle trig identity algebraically?
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic

open Real

-- 1 - cos(2θ) = 2sin²(θ)
-- Equivalent: cos(2θ) = 1 - 2sin²(θ), i.e., cos(2θ) = cos²(θ) - sin²(θ)

-- We need: 2(1-cos(2πx))/(2πx)² = (sin(πx)/(πx))²
-- i.e., 2(1-cos(2πx))/(4π²x²) = sin²(πx)/(π²x²)
-- i.e., (1-cos(2πx))/(2π²x²) = sin²(πx)/(π²x²)
-- i.e., (1-cos(2πx))/2 = sin²(πx)

example (x : ℝ) (hx : x ≠ 0) :
    (1 - cos (2 * π * x)) / (2 * π * x) ^ 2 +
    (1 - cos (2 * π * x)) / (2 * π * x) ^ 2 =
    (sin (π * x) / (π * x)) ^ 2 := by
  have hpx : π * x ≠ 0 := mul_ne_zero pi_ne_zero hx
  -- Use cos_two_mul : cos(2θ) = 2cos²θ - 1
  -- So 1 - cos(2θ) = 2 - 2cos²θ = 2(1 - cos²θ) = 2sin²θ
  have h_half : 1 - cos (2 * (π * x)) = 2 * sin (π * x) ^ 2 := by
    have := cos_sq (π * x)  -- cos²(πx) = 1 - sin²(πx)
    nlinarith [sin_sq_add_cos_sq (π * x)]
  rw [show 2 * π * x = 2 * (π * x) from by ring] at *
  rw [h_half]
  field_simp
  ring
