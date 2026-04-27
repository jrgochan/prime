-- Scratch: fejerKernel_even
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic

open Real

noncomputable section

def sinc (x : ℝ) : ℝ :=
  if x = 0 then 1 else sin (π * x) / (π * x)

def fejerKernel (x : ℝ) : ℝ := (sinc x) ^ 2

theorem fejerKernel_even (x : ℝ) : fejerKernel (-x) = fejerKernel x := by
  unfold fejerKernel sinc
  by_cases hx : x = 0
  · subst hx; simp
  · have hxn : -x ≠ 0 := neg_ne_zero.mpr hx
    simp only [hx, hxn, ↓reduceIte]
    congr 1
    -- sin(-πx)/(-πx) = sin(πx)/(πx)
    -- = (-sin(πx))/(-πx) = sin(πx)/(πx) ✓
    rw [show π * (-x) = -(π * x) from by ring]
    rw [sin_neg]
    rw [show -(π * x) = (-1) * (π * x) from by ring]
    rw [show -sin (π * x) / ((-1) * (π * x)) = sin (π * x) / (π * x) from by ring]
