/-
  Scratch file: bordered_matrix_posDef proof.
-/
import Mathlib.LinearAlgebra.Matrix.DotProduct
import Mathlib.LinearAlgebra.Matrix.NonsingularInverse
import Mathlib.LinearAlgebra.Matrix.PosDef
import Mathlib.Data.Matrix.Basic

noncomputable section
open Matrix Finset Fin

-- Split dotProduct over Fin (n+1) into Fin n part + last
private lemma dotProduct_fin_succ {n : ℕ} (x y : Fin (n+1) → ℝ) :
    dotProduct x y =
    dotProduct (x ∘ Fin.castSucc) (y ∘ Fin.castSucc) +
    x (Fin.last n) * y (Fin.last n) := by
  simp only [dotProduct, Fin.sum_univ_castSucc, Function.comp]

-- Split mulVec at any index
private lemma mulVec_split {n : ℕ} (M : Matrix (Fin (n+1)) (Fin (n+1)) ℝ)
    (x : Fin (n+1) → ℝ) (i : Fin (n+1)) :
    (M.mulVec x) i =
    ∑ j : Fin n, M i (Fin.castSucc j) * x (Fin.castSucc j) +
    M i (Fin.last n) * x (Fin.last n) := by
  simp only [mulVec, dotProduct, Fin.sum_univ_castSucc]

-- The main theorem (castSucc formulation)
theorem bordered_matrix_posDef' {n : ℕ}
    (M : Matrix (Fin (n+1)) (Fin (n+1)) ℝ)
    (hH : M.IsHermitian)
    (A : Matrix (Fin n) (Fin n) ℝ)
    (hA_eq : ∀ i j : Fin n, M (Fin.castSucc i) (Fin.castSucc j) = A i j)
    (hA_pd : A.PosDef)
    (g : Fin n → ℝ)
    (hg_eq : ∀ i : Fin n, M (Fin.castSucc i) (Fin.last n) = g i)
    (hs : M (Fin.last n) (Fin.last n) -
          dotProduct g (A⁻¹.mulVec g) > 0) :
    M.PosDef := by
  have hg_sym : ∀ i : Fin n, M (Fin.last n) (Fin.castSucc i) = g i := by
    intro i
    have := congr_fun (congr_fun hH (Fin.last n)) (Fin.castSucc i)
    simp [conjTranspose_apply, star_trivial] at this
    rw [← this]; exact hg_eq i
  set α := M (Fin.last n) (Fin.last n)
  refine PosDef.of_dotProduct_mulVec_pos hH fun {x} hx => ?_
  simp only [star_trivial]
  set y : Fin n → ℝ := x ∘ Fin.castSucc
  set z : ℝ := x (Fin.last n)
  -- Express (Mx) at each index
  have hMx_cast : ∀ i : Fin n, (M.mulVec x) (Fin.castSucc i) =
      (A.mulVec y) i + g i * z := by
    intro i; rw [mulVec_split]
    simp only [hA_eq, hg_eq]
    show ∑ j, A i j * y j + g i * z = (A.mulVec y) i + g i * z
    simp [mulVec, dotProduct]
  have hMx_last : (M.mulVec x) (Fin.last n) =
      dotProduct g y + α * z := by
    rw [mulVec_split]; simp only [hg_sym]
    show ∑ j, g j * y j + α * z = dotProduct g y + α * z
    simp [dotProduct]
  -- Key identity: xᵀMx = yᵀAy + 2z(gᵀy) + αz²
  have h_quad : dotProduct x (M.mulVec x) =
      dotProduct y (A.mulVec y) + 2 * z * dotProduct g y + α * z ^ 2 := by
    rw [dotProduct_fin_succ]
    have h_top : dotProduct (x ∘ Fin.castSucc) ((M.mulVec x) ∘ Fin.castSucc) =
        dotProduct y (A.mulVec y) + z * dotProduct g y := by
      show ∑ i, y i * (M.mulVec x) (Fin.castSucc i) = _
      simp_rw [hMx_cast, mul_add, Finset.sum_add_distrib]
      simp only [dotProduct]
      congr 1
      · -- ∑ y_i * (g_i * z) = z * ∑ g_i * y_i
        have : ∀ i, y i * (g i * z) = z * (g i * y i) := fun i => by ring
        simp_rw [this, ← Finset.mul_sum]
    have h_bot : x (Fin.last n) * (M.mulVec x) (Fin.last n) =
        z * dotProduct g y + α * z ^ 2 := by
      rw [hMx_last]; ring
    rw [h_top, h_bot]; ring
  rw [h_quad]
  -- Case split on z
  by_cases hz : z = 0
  · simp only [hz, zero_mul, mul_zero, add_zero]
    have hy_ne : y ≠ 0 := by
      intro hy_eq; apply hx; ext i
      refine Fin.lastCases ?_ ?_ i
      · exact hz
      · intro j; exact congr_fun hy_eq j
    have := hA_pd.dotProduct_mulVec_pos hy_ne
    simpa [star_trivial] using this
  · have h_sz_pos : (α - dotProduct g (A⁻¹.mulVec g)) * z ^ 2 > 0 :=
      mul_pos hs (sq_pos_of_ne_zero hz)
    set w := y + z • A⁻¹.mulVec g
    have h_wAw := hA_pd.posSemidef.dotProduct_mulVec_nonneg w
    simp only [star_trivial] at h_wAw
    have hA_unit : IsUnit A.det := A.isUnit_iff_isUnit_det.mp hA_pd.isUnit
    have hA_inv_g : A.mulVec (A⁻¹.mulVec g) = g := by
      rw [mulVec_mulVec, mul_nonsing_inv A hA_unit, one_mulVec]
    have h_expand : dotProduct w (A.mulVec w) =
        dotProduct y (A.mulVec y) +
        z * dotProduct y g +
        z * dotProduct (A⁻¹.mulVec g) (A.mulVec y) +
        z ^ 2 * dotProduct g (A⁻¹.mulVec g) := by
      simp only [w, mulVec_add, mulVec_smul, add_dotProduct, dotProduct_add,
        smul_dotProduct, dotProduct_smul, hA_inv_g,
        dotProduct_comm (A⁻¹.mulVec g) g]; ring
    have h1 : dotProduct (A⁻¹.mulVec g) (A.mulVec y) = dotProduct g y := by
      -- Strategy: unfold everything to sums, use A symmetry and A·A⁻¹g = g
      unfold dotProduct; simp only [mulVec, dotProduct]
      simp_rw [Finset.mul_sum]
      rw [Finset.sum_comm]
      -- Goal: ∑_i ∑_j (∑_k A⁻¹ j k * g k) * (A j i * y i) = ∑_i g i * y i
      apply Finset.sum_congr rfl; intro i _
      -- Need: ∑_j (A⁻¹g)_j * (A j i * y i) = g i * y i
      -- = ∑_j (A⁻¹g)_j * A_ji * y_i = y_i * ∑_j (A⁻¹g)_j * A_ji
      -- Transform each term so we can factor y_i out
      have h_factor : ∀ j, (∑ k, A⁻¹ j k * g k) * (A j i * y i) =
          ((∑ k, A⁻¹ j k * g k) * A j i) * y i := fun j => by ring
      simp_rw [h_factor, ← Finset.sum_mul]
      -- Goal: (∑_j (A⁻¹g)_j * A_ji) * y_i = g_i * y_i
      congr 1
      -- Goal: ∑_j (A⁻¹g)_j * A_ji = g_i
      -- Use: A_ji = A_ij (symmetric), then ∑_j A_ij * (A⁻¹g)_j = (A·A⁻¹g)_i = g_i
      have hA_sym_ij : ∀ j, A j i = A i j := by
        intro j; have := congr_fun (congr_fun hA_pd.isHermitian j) i
        simp [conjTranspose_apply, star_trivial] at this; exact this.symm
      simp_rw [hA_sym_ij]
      rw [show ∑ j, (∑ k, A⁻¹ j k * g k) * A i j =
          ∑ j, A i j * ∑ k, A⁻¹ j k * g k from by
        congr 1; ext j; ring]
      exact congr_fun hA_inv_g i
    rw [h1, dotProduct_comm y g] at h_expand
    linarith
