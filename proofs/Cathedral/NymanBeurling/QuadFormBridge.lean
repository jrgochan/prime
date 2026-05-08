/-
  Cathedral/NymanBeurling/QuadFormBridge.lean

  ## NB Distance Structural Theorems.

  The variational principle and quadratic form bridge:
  - nbDistSq_as_quadform (d² = 1 - cᵀGc)
  - basis_inner_prod_nonzero (b ≠ 0)
  - nbDistSq_lt_one (d² < 1)
  - nbDistSq_le_test_vector (variational upper bound)
-/

import Cathedral.Defs
import Cathedral.Structural.Structural
import Cathedral.Sieve.ParitySchur

noncomputable section
open Complex Real

/-- **THEOREM**: NB distance as Rayleigh quotient: d² = 1 - cᵀGc. -/
theorem nbDistSq_as_quadform (N : ℕ) (hN : 2 ≤ N) :
    let c := (gramMatrix N)⁻¹.mulVec (basisInnerProd N)
    nbDistSq' N = 1 - realQuadForm (gramMatrix N) c := by
  simp only [nbDistSq', realQuadForm]
  congr 1
  set c := (gramMatrix N)⁻¹.mulVec (basisInnerProd N)
  have h_unit : IsUnit (gramMatrix N).det := gramMatrix_isUnit_det N hN
  have h_Gc : (gramMatrix N).mulVec c = basisInnerProd N := by
    rw [Matrix.mulVec_mulVec, Matrix.mul_nonsing_inv _ h_unit, Matrix.one_mulVec]
  rw [h_Gc]
  simp [dotProduct, Finset.sum_congr rfl (fun i _ => mul_comm _ _)]

/-- **THEOREM**: The basis inner product vector b is nonzero. -/
theorem basis_inner_prod_nonzero (N : ℕ) (hN : 2 ≤ N) :
    basisInnerProd N ≠ 0 := by
  intro h_eq
  have h_zero : basisInnerProd N ⟨0, by omega⟩ = 0 := by rw [h_eq]; rfl
  simp only [basisInnerProd] at h_zero
  set f := (fun x : ℝ => Int.fract (1 / (((0 + 1 : ℕ) : ℝ) * x))) with hf_def
  have hf_meas : Measurable f :=
    (measurable_const.div (measurable_const.mul measurable_id)).fract
  have hf_bound : ∀ x : ℝ, ‖f x‖ ≤ ‖(1 : ℝ)‖ := fun x => by
    simp only [f, Real.norm_eq_abs, abs_one,
      abs_of_nonneg (Int.fract_nonneg _)]
    exact le_of_lt (Int.fract_lt_one _)
  have hf_01 : IntervalIntegrable f MeasureTheory.volume 0 1 :=
    IntervalIntegrable.mono_fun (intervalIntegrable_const (c := (1:ℝ)))
      hf_meas.aestronglyMeasurable.restrict
      (Filter.Eventually.of_forall hf_bound)
  set c : ℝ := 1/2
  have hc0 : (0:ℝ) ≤ c := by norm_num
  have hcd : c < 1 := by norm_num
  have hpos : ∀ x, x ∈ Set.Ioo c (1:ℝ) → 0 < f x := by
    intro x ⟨hx_lo, hx_hi⟩
    simp only [f]
    -- {1/(1*x)} = {1/x} and for x ∈ (1/2, 1), 1/x ∈ (1, 2)
    -- so fract(1/x) = 1/x - 1 > 0
    have hxp : 0 < x := by linarith
    -- Simplify: 1/((0+1:ℕ)*x) = 1/x  (since (0+1:ℕ) = 1)
    have h_simp : (1 : ℝ) / (((0 + 1 : ℕ) : ℝ) * x) = 1 / x := by simp
    rw [h_simp]
    have h1x_gt1 : (1:ℝ) < 1 / x := by rw [one_div]; exact one_lt_inv_iff₀.mpr ⟨hxp, hx_hi⟩
    have h1x_lt2 : 1 / x < 2 := by
      rw [div_lt_iff₀ hxp]
      have : (1:ℝ)/2 < x := hx_lo
      linarith
    have h_floor : ⌊(1:ℝ) / x⌋ = 1 := by
      rw [Int.floor_eq_iff]
      constructor <;> push_cast <;> linarith
    rw [Int.fract, h_floor]; push_cast
    linarith
  have hi_sub : IntervalIntegrable f MeasureTheory.volume c 1 :=
    hf_01.mono_set (by
      simp only [Set.uIcc_of_le (le_of_lt hcd), Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc hc0 le_rfl)
  have hi_0c : IntervalIntegrable f MeasureTheory.volume 0 c :=
    hf_01.mono_set (by
      simp only [Set.uIcc_of_le hc0, Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc le_rfl (le_of_lt hcd))
  have h_sub_pos : 0 < ∫ x in c..1, f x :=
    intervalIntegral.intervalIntegral_pos_of_pos_on hi_sub hpos hcd
  have h_0c_nn : 0 ≤ ∫ x in (0:ℝ)..c, f x :=
    intervalIntegral.integral_nonneg hc0 (fun x _ => Int.fract_nonneg _)
  have h_split : ∫ x in (0:ℝ)..1, f x = (∫ x in (0:ℝ)..c, f x) + (∫ x in c..1, f x) :=
    (intervalIntegral.integral_add_adjacent_intervals hi_0c hi_sub).symm
  linarith

/-- **THEOREM**: d² < 1 for all N ≥ 2. -/
theorem nbDistSq_lt_one (N : ℕ) (hN : 2 ≤ N) :
    nbDistSq' N < 1 := by
  rw [nbDistSq_as_quadform N hN]
  linarith [gram_pos_def N hN ((gramMatrix N)⁻¹.mulVec (basisInnerProd N))
    (by
     intro hc
     have h_unit : IsUnit (gramMatrix N).det := gramMatrix_isUnit_det N hN
     have h_Gc : (gramMatrix N).mulVec ((gramMatrix N)⁻¹.mulVec (basisInnerProd N)) =
            basisInnerProd N := by
       rw [Matrix.mulVec_mulVec, Matrix.mul_nonsing_inv _ h_unit, Matrix.one_mulVec]
     rw [hc, Matrix.mulVec_zero] at h_Gc
     exact basis_inner_prod_nonzero N hN h_Gc.symm)]

/-- **COROLLARY**: bᵀG⁻¹b > 0. -/
theorem bGinvb_pos (N : ℕ) (hN : 2 ≤ N) :
    0 < dotProduct (basisInnerProd N) ((gramMatrix N)⁻¹.mulVec (basisInnerProd N)) := by
  have h := nbDistSq_lt_one N hN
  unfold nbDistSq' at h
  linarith

-- ════════════════════════════════════════════════
-- THE VARIATIONAL PRINCIPLE
-- ════════════════════════════════════════════════

/-- **THEOREM (Variational Upper Bound)**: For ANY test vector v,
    d²_N ≤ 1 - 2·bᵀv + vᵀGv. -/
theorem nbDistSq_le_test_vector (N : ℕ) (hN : 2 ≤ N)
    (v : Fin (N - 1) → ℝ) :
    nbDistSq' N ≤ 1 - 2 * dotProduct (basisInnerProd N) v +
      realQuadForm (gramMatrix N) v := by
  set c := (gramMatrix N)⁻¹.mulVec (basisInnerProd N) with hc_def
  set b := basisInnerProd N
  set G := gramMatrix N
  have h_unit : IsUnit G.det := gramMatrix_isUnit_det N hN
  have h_Gc : G.mulVec c = b := by
    simp [hc_def, G, Matrix.mulVec_mulVec, Matrix.mul_nonsing_inv _ h_unit, Matrix.one_mulVec]
  have h_dist := nbDistSq_as_quadform N hN
  have h_cb : dotProduct c (G.mulVec c) = dotProduct c b := by rw [h_Gc]
  suffices h : realQuadForm G v - 2 * dotProduct b v + dotProduct c b ≥ 0 by
    simp only [realQuadForm] at h_dist h ⊢
    linarith
  rw [show dotProduct c b = realQuadForm G c from by
    unfold realQuadForm; rw [h_Gc]]
  rw [show dotProduct b v = dotProduct v (G.mulVec c) from by
    rw [h_Gc]; exact dotProduct_comm b v]
  have h_psd := (gramMatrix_posSemidef N hN).dotProduct_mulVec_nonneg (v - c)
  have h_expand : dotProduct (v - c) (G.mulVec (v - c)) =
      realQuadForm G v - 2 * dotProduct v (G.mulVec c) + realQuadForm G c := by
    unfold realQuadForm
    simp only [Matrix.mulVec_sub, sub_dotProduct, dotProduct_sub]
    have h_sym : dotProduct c (G.mulVec v) = dotProduct v (G.mulVec c) := by
      have hH := gramMatrix_hermitian N
      simp only [dotProduct, Matrix.mulVec, Matrix.IsHermitian] at hH ⊢
      simp_rw [Finset.mul_sum]
      rw [Finset.sum_comm]
      congr 1; ext j
      congr 1; ext i
      have : G i j = G j i := by
        have := congr_fun (congr_fun hH i) j
        simp [Matrix.conjTranspose_apply, star_trivial] at this
        exact this.symm
      ring_nf; rw [this]; ring
    linarith
  simp only [star_trivial] at h_psd
  linarith

end
