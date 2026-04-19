import Mathlib.Analysis.Complex.CauchyIntegral
import Mathlib.Analysis.SpecialFunctions.Complex.LogDeriv
import Mathlib.Analysis.SpecialFunctions.Pow.Deriv
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.Analysis.Complex.RemovableSingularity
import Mathlib.Analysis.Calculus.DSlope

noncomputable section
open Complex Real MeasureTheory Set

-- Step 1: y^z is differentiable everywhere
lemma cpow_const_differentiable (y : ℝ) (hy : 0 < y) (z : ℂ) :
    DifferentiableAt ℂ (fun z => (y : ℂ) ^ z) z :=
  DifferentiableAt.const_cpow differentiableAt_id
    (Or.inl (Complex.ofReal_ne_zero.mpr (ne_of_gt hy)))

-- Step 2: dslope of y^z is differentiable everywhere
lemma dslope_cpow_differentiable (y : ℝ) (hy : 0 < y) (z : ℂ) :
    DifferentiableAt ℂ (dslope (fun z => (y : ℂ) ^ z) 0) z := by
  rcases eq_or_ne z 0 with rfl | hz
  · -- At z = 0: use continuousAt_dslope_same + differentiability of y^z
    -- Actually we need the removable singularity result
    rw [show (0 : ℂ) = (0 : ℂ) from rfl]
    have hDiff : DifferentiableOn ℂ (fun z => (y : ℂ) ^ z) (Set.univ : Set ℂ) :=
      fun z _ => (cpow_const_differentiable y hy z).differentiableWithinAt
    have key := (differentiableOn_dslope (show (Set.univ : Set ℂ) ∈ nhds (0 : ℂ) from Filter.univ_mem)).mpr hDiff
    exact (key 0 (Set.mem_univ _)).differentiableAt Filter.univ_mem
  · -- At z ≠ 0: straightforward
    exact (differentiableAt_dslope_of_ne hz).mpr (cpow_const_differentiable y hy z)

-- Step 3: CG for dslope on a rectangle
lemma dslope_rect_vanishes (y : ℝ) (hy : 0 < y) (R c T : ℝ) :
    (∫ x in (-R)..c, dslope (fun z => (y : ℂ) ^ z) 0 (↑x + -↑T * I)) -
    (∫ x in (-R)..c, dslope (fun z => (y : ℂ) ^ z) 0 (↑x + ↑T * I)) +
    I * (∫ t in (-T)..T, dslope (fun z => (y : ℂ) ^ z) 0 (↑c + ↑t * I)) -
    I * (∫ t in (-T)..T, dslope (fun z => (y : ℂ) ^ z) 0 (-↑R + ↑t * I)) = 0 := by
  have hDiff : DifferentiableOn ℂ (dslope (fun z => (y : ℂ) ^ z) 0)
      (Set.uIcc (-R) c ×ℂ Set.uIcc (-T) T) :=
    fun z _ => (dslope_cpow_differentiable y hy z).differentiableWithinAt
  have key := Complex.integral_boundary_rect_eq_zero_of_differentiableOn
    (dslope (fun z => (y : ℂ) ^ z) 0) ⟨-R, -T⟩ ⟨c, T⟩ hDiff
  simp only [smul_eq_mul] at key
  convert key using 2 <;> push_cast <;> ring

end
