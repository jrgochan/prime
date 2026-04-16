/-
  Cathedral/Assembly/BDBridge.lean

  ## The BD L² Bridge

  Connects the Báez-Duarte basis {1/(kx)} to the Vasyunin discrete
  matrices, enabling the forward direction (RH ⟹ d²_BD → 0).

  Uses: vasyunin_eq_integral (1 axiom), vasyunin_mean_eq_integral (PROVED)
-/

import Cathedral.NymanBeurling.BDMellin
import Cathedral.Vasyunin.Augmented.IntegralBridge
import Cathedral.Assembly.QuadFormBridge
import Cathedral.Structural.Structural

noncomputable section
open Real Matrix Finset MeasureTheory Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- PART I: BD INTEGRAL = VASYUNIN MEAN DOT PRODUCT
-- ════════════════════════════════════════════════

/-- ∫₀¹ bdLinComb N v x dx = bᵀv (Vasyunin mean). -/
theorem bd_integral_bdLinComb_eq_dotProduct (N : ℕ) (v : Fin (N - 1) → ℝ) :
    ∫ x in (0:ℝ)..1, bdLinComb N v x =
    dotProduct (fun i => vasyuninMeanEntry (i.val + 1)) v := by
  unfold bdLinComb
  simp_rw [show (fun x : ℝ => ∑ i : Fin (N - 1),
    v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x))) =
    (fun x => ∑ i ∈ Finset.univ, (fun i (x : ℝ) =>
      v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x))) i x) from by
    ext x; simp]
  rw [intervalIntegral.integral_finset_sum
    (fun i _ => bd_single_fract_integrable (i.val + 1) (v i))]
  unfold dotProduct
  congr 1; ext i
  rw [intervalIntegral.integral_const_mul, mul_comm]
  congr 1
  exact (vasyunin_mean_eq_integral (i.val + 1) (by omega)).symm

-- ════════════════════════════════════════════════
-- PART II: BD GRAM L² IDENTITY
-- ════════════════════════════════════════════════

/-- Product of two BD basis functions is integrable on [0,1]. -/
private lemma bd_product_integrable (j k : ℕ) :
    IntervalIntegrable (fun x : ℝ =>
      Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)))
      MeasureTheory.volume 0 1 := by
  apply IntervalIntegrable.mono_fun (intervalIntegrable_const (c := (1:ℝ)))
  · exact ((measurable_fract_real.comp
      (measurable_const.div (measurable_const.mul measurable_id))).mul
      (measurable_fract_real.comp
      (measurable_const.div (measurable_const.mul measurable_id)))).aestronglyMeasurable.restrict
  · filter_upwards with x
    simp only [Real.norm_eq_abs, abs_one, abs_mul]
    calc ‖Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x))‖
        = |Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x))| := Real.norm_eq_abs _
      _ = |Int.fract (1 / ((j:ℝ) * x))| * |Int.fract (1 / ((k:ℝ) * x))| := rfl
      _ ≤ 1 * 1 := mul_le_mul
          ((abs_of_nonneg (Int.fract_nonneg _)).le.trans (Int.fract_lt_one _).le)
          ((abs_of_nonneg (Int.fract_nonneg _)).le.trans (Int.fract_lt_one _).le)
          (abs_nonneg _) zero_le_one
      _ = 1 := mul_one _

/-- ∫₀¹ (bdLinComb)² = vᵀ · vasyuninGramMatrix · v. -/
theorem bd_gram_l2_identity (N : ℕ) (_ : 2 ≤ N) (v : Fin (N - 1) → ℝ) :
    ∫ x in (0:ℝ)..1, (bdLinComb N v x) ^ 2 =
    realQuadForm (Matrix.of fun i j => vasyuninGramEntry (i.val + 1) (j.val + 1)) v := by
  -- Integrability of each product term
  have h_iint : ∀ i j : Fin (N-1),
      IntervalIntegrable (fun x : ℝ =>
        (v i * v j) * (Int.fract (1/((↑(i.val+1):ℝ)*x)) *
          Int.fract (1/((↑(j.val+1):ℝ)*x))))
        MeasureTheory.volume 0 1 :=
    fun i j => (bd_product_integrable (i.val+1) (j.val+1)).const_mul _
  -- Step 1: Expand (bdLinComb)² pointwise
  have h_sq : ∀ x : ℝ, (bdLinComb N v x) ^ 2 =
      ∑ i : Fin (N-1), ∑ j : Fin (N-1),
        (v i * v j) * (Int.fract (1/((↑(i.val+1):ℝ)*x)) *
          Int.fract (1/((↑(j.val+1):ℝ)*x))) := by
    intro x; unfold bdLinComb
    rw [sq, Finset.sum_mul]
    congr 1; ext i
    rw [Finset.mul_sum]
    congr 1; ext j; ring
  -- Step 2: Compute ∫ for each (i,j) pair
  have h_entry : ∀ i j : Fin (N-1),
      ∫ x in (0:ℝ)..1,
        (v i * v j) * (Int.fract (1/((↑(i.val+1):ℝ)*x)) *
          Int.fract (1/((↑(j.val+1):ℝ)*x))) =
      v i * v j * vasyuninGramEntry (i.val+1) (j.val+1) := by
    intro i j
    rw [intervalIntegral.integral_const_mul,
        ← vasyunin_eq_integral (i.val+1) (j.val+1) (by omega) (by omega)]
  -- Step 3: Swap integral and double sum using linearity
  have h_integral : ∫ x in (0:ℝ)..1, (bdLinComb N v x) ^ 2 =
      ∑ i : Fin (N-1), ∑ j : Fin (N-1),
        v i * v j * vasyuninGramEntry (i.val+1) (j.val+1) := by
    -- Rewrite integrand
    simp_rw [h_sq]
    -- Swap outer sum
    rw [show (fun x : ℝ => ∑ i : Fin (N-1), ∑ j : Fin (N-1),
          v i * v j * (Int.fract (1/((↑(i.val+1):ℝ)*x)) *
            Int.fract (1/((↑(j.val+1):ℝ)*x)))) =
        (fun x => ∑ i ∈ Finset.univ, (fun i x => ∑ j : Fin (N-1),
          v i * v j * (Int.fract (1/((↑(i.val+1):ℝ)*x)) *
            Int.fract (1/((↑(j.val+1):ℝ)*x)))) i x) from by ext x; simp]
    rw [intervalIntegral.integral_finset_sum (fun i _ => by
      show IntervalIntegrable (fun x => ∑ j : Fin (N-1),
        v i * v j * (Int.fract (1/((↑(i.val+1):ℝ)*x)) *
          Int.fract (1/((↑(j.val+1):ℝ)*x)))) _ 0 1
      have := IntervalIntegrable.sum Finset.univ (fun j (_ : j ∈ Finset.univ) => h_iint i j)
      convert this using 1
      ext x; simp only [Finset.sum_apply])]
    congr 1; ext i
    -- Swap inner sum
    rw [show (fun x : ℝ => ∑ j : Fin (N-1),
          v i * v j * (Int.fract (1/((↑(i.val+1):ℝ)*x)) *
            Int.fract (1/((↑(j.val+1):ℝ)*x)))) =
        (fun x => ∑ j ∈ Finset.univ, (fun j x =>
          v i * v j * (Int.fract (1/((↑(i.val+1):ℝ)*x)) *
            Int.fract (1/((↑(j.val+1):ℝ)*x)))) j x) from by ext x; simp]
    rw [intervalIntegral.integral_finset_sum (fun j _ => h_iint i j)]
    congr 1; ext j
    exact h_entry i j
  rw [h_integral]
  -- Step 4: Match the quadratic form
  unfold realQuadForm
  congr 1; ext i
  simp only [dotProduct, Matrix.mulVec, Matrix.of_apply]
  rw [Finset.mul_sum]
  congr 1; ext j; ring

-- ════════════════════════════════════════════════
-- PART III: THE BD L² ↔ MATRIX BRIDGE
-- ════════════════════════════════════════════════

/-- **THE BD L² ↔ MATRIX BRIDGE**:
    ∫₀¹ (1 - bdLinComb N v x)² = 1 - 2·bᵀv + vᵀGv -/
theorem bd_l2_error_eq_quad_error (N : ℕ) (hN : 2 ≤ N) (v : Fin (N - 1) → ℝ) :
    ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 =
    1 - 2 * dotProduct (fun i => vasyuninMeanEntry (i.val + 1)) v +
    realQuadForm (Matrix.of fun i j => vasyuninGramEntry (i.val + 1) (j.val + 1)) v := by
  rw [show (fun x : ℝ => (1 - bdLinComb N v x) ^ 2) =
      (fun x : ℝ => 1 - 2 * bdLinComb N v x + (bdLinComb N v x) ^ 2) from by ext x; ring]
  rw [show (fun x : ℝ => 1 - 2 * bdLinComb N v x + (bdLinComb N v x) ^ 2) =
      (fun x => (1 - 2 * bdLinComb N v x) + (bdLinComb N v x) ^ 2) from by ext x; ring]
  rw [intervalIntegral.integral_add
    ((intervalIntegrable_const (c := (1:ℝ))).sub ((bdLinComb_integrable N v).const_mul 2))
    (bdLinComb_sq_integrable N v)]
  rw [intervalIntegral.integral_sub
    (intervalIntegrable_const (c := (1:ℝ))) ((bdLinComb_integrable N v).const_mul 2)]
  rw [intervalIntegral.integral_const, sub_zero, smul_eq_mul, mul_one]
  rw [show (fun x : ℝ => 2 * bdLinComb N v x) = (fun x => (2:ℝ) * bdLinComb N v x) from rfl,
      intervalIntegral.integral_const_mul, bd_integral_bdLinComb_eq_dotProduct]
  rw [bd_gram_l2_identity N hN v]

end
