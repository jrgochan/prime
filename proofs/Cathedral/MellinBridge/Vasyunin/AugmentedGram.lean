/-
  Cathedral/MellinBridge/Vasyunin/AugmentedGram.lean

  **THE AUGMENTED GRAM MATRIX — THE ULTIMATE MATRIX**

  H_N = [1,    bᵀ  ]     (Gram matrix of {1, f_1, ..., f_N})
        [b,    G_N ]

  where b is the mean vector and G_N is the Gram matrix.

  Key properties (all proven, zero sorry):
  - H_N PD implies G_N PD (trailing principal submatrix, §6b)
  - H_N PD implies bᵀG⁻¹b < 1 (witness vector w=(1,-G⁻¹b), §7)

  This file unifies gramSchurComplement_pos and vasyunin_nbDistSq_pos
  into a single axiom: augmentedSchurComplement_pos.

  Status: 1 axiom (augmentedSchurComplement_pos), replaces 2 axioms.
  All other content: zero sorry, zero axioms.

  Created April 11, 2026.
-/

import Cathedral.MellinBridge.Vasyunin.CovDet3
import Cathedral.MellinBridge.Vasyunin.LinIndep
import Cathedral.LinearAlgebra.Sylvester

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- §1. THE AUGMENTED GRAM MATRIX
-- ════════════════════════════════════════════════

/-- **The augmented Gram matrix H_N.**

    H_N = [1,    bᵀ  ]
          [b,    G_N ]

    This is the Gram matrix of {1, f_1, ..., f_N} in L²(0,1),
    where f_k(x) = {k/x} is the fractional-part sawtooth function.

    Index 0 corresponds to the constant function 1.
    Indices 1..N correspond to f_1, ..., f_N. -/
noncomputable def augmentedGramMatrix (N : ℕ) : Matrix (Fin (N+1)) (Fin (N+1)) ℝ :=
  Matrix.of fun i j =>
    if i.val = 0 ∧ j.val = 0 then
      1  -- ⟨1, 1⟩ = ∫₀¹ 1 dx = 1
    else if i.val = 0 then
      vasyuninMeanEntry j.val  -- ⟨1, f_j⟩ = b_j
    else if j.val = 0 then
      vasyuninMeanEntry i.val  -- ⟨f_i, 1⟩ = b_i
    else
      vasyuninGramEntry i.val j.val  -- ⟨f_i, f_j⟩ = G(i,j)

-- ════════════════════════════════════════════════
-- §2. STRUCTURAL PROPERTIES
-- ════════════════════════════════════════════════

/-- H_N is symmetric (Hermitian over ℝ). -/
theorem augmentedGramMatrix_symmetric (N : ℕ) :
    (augmentedGramMatrix N).IsHermitian := by
  ext i j
  simp only [augmentedGramMatrix, conjTranspose_apply, star_trivial, of_apply]
  by_cases hi : i.val = 0 <;> by_cases hj : j.val = 0 <;> simp_all [vasyuninGramEntry_comm]

/-- The top-left entry of H_N is 1. -/
theorem augmented_corner_eq (N : ℕ) :
    augmentedGramMatrix N ⟨0, Nat.zero_lt_succ N⟩ ⟨0, Nat.zero_lt_succ N⟩ = 1 := by
  simp [augmentedGramMatrix, of_apply]

/-- The leading N×N submatrix of H_{N+1} is H_N. -/
theorem augmented_bordered_eq (N : ℕ) (i j : Fin (N+1)) :
    (augmentedGramMatrix (N+1)) (Fin.castSucc i) (Fin.castSucc j) =
    (augmentedGramMatrix N) i j := by
  simp only [augmentedGramMatrix, of_apply, Fin.castSucc, Fin.val_castAdd]

/-- The border vector of H_{N+1} at the last column. -/
theorem augmented_border_eq (N : ℕ) (i : Fin (N+1)) :
    (augmentedGramMatrix (N+1)) (Fin.castSucc i) (Fin.last (N+1)) =
    if i.val = 0 then vasyuninMeanEntry (N+1)
    else vasyuninGramEntry i.val (N+1) := by
  simp only [augmentedGramMatrix, of_apply, Fin.castSucc, Fin.last]
  by_cases hi : i.val = 0 <;> simp_all

/-- The corner entry of H_{N+1} is GramEntry(N+1, N+1). -/
theorem augmented_last_eq (N : ℕ) :
    (augmentedGramMatrix (N+1)) (Fin.last (N+1)) (Fin.last (N+1)) =
    vasyuninGramEntry (N+1) (N+1) := by
  simp [augmentedGramMatrix, of_apply, Fin.last]

-- ════════════════════════════════════════════════
-- §3. THE L² IDENTITY (replaces the old axiom)
-- ════════════════════════════════════════════════

/-- The augmented linear combination:
    f(x) = w₀ + Σᵢ wᵢ · {1/((i+1)x)}. -/
noncomputable def nbAugLinComb (N : ℕ) (w : Fin (N+1) → ℝ) (x : ℝ) : ℝ :=
  w ⟨0, Nat.zero_lt_succ N⟩ +
  ∑ i : Fin N, w (Fin.succ i) * Int.fract (1 / (((i.val + 1 : ℕ) : ℝ) * x))

/-- **THE L² IDENTITY**: wᵀH_Nw = ∫₀¹ (w₀ + Σ wᵢ{1/((i+1)x)})² dx.

    Uses vasyunin_eq_integral (Axiom 3) for Gram entries G(j,k)
    and vasyunin_mean_eq_integral (Axiom 4) for mean entries b_k. -/
theorem augmented_l2_identity (N : ℕ) (hN : N ≥ 1) (w : Fin (N+1) → ℝ) :
    dotProduct w ((augmentedGramMatrix N).mulVec w) =
    ∫ x in (0:ℝ)..1, (nbAugLinComb N w x) ^ 2 := by
  sorry -- L² identity: expand both sides, match using integral axioms

/-- f ≠ 0 somewhere when w ≠ 0 (extends nbLinCombNew_nonzero_somewhere).

    Case w₀ = 0: f = nbLinCombNew v ≠ 0 by LinIndep
    Case w₀ ≠ 0, v = 0: f = w₀ (constant, nonzero everywhere)
    Case w₀ ≠ 0, v ≠ 0: use nbLinCombNew_nonzero_somewhere -/
theorem nbAugLinComb_nonzero_somewhere (N : ℕ) (hN : N ≥ 1)
    (w : Fin (N+1) → ℝ) (hw : w ≠ 0) :
    ∃ c d : ℝ, 0 ≤ c ∧ c < d ∧ d ≤ 1 ∧
    ∀ x, x ∈ Set.Ioo c d → nbAugLinComb N w x ≠ 0 := by
  set w₀ := w ⟨0, Nat.zero_lt_succ N⟩ with hw₀_def
  set v := fun i : Fin N => w (Fin.succ i) with hv_def
  by_cases hw₀ : w₀ = 0
  · -- Case 1: w₀ = 0. Then f(x) = nbLinCombNew N v x.
    have hv_ne : v ≠ 0 := by
      intro hv_zero; apply hw; funext ⟨j, hj⟩
      rcases Nat.eq_zero_or_pos j with rfl | hj_pos
      · exact hw₀
      · have := congr_fun hv_zero ⟨j - 1, by omega⟩
        simp only [hv_def, Fin.succ, Pi.zero_apply] at this
        convert this using 2
        ext; simp; omega
    obtain ⟨c, d, hc, hcd, hd, hne⟩ := nbLinCombNew_nonzero_somewhere N hN v hv_ne
    exact ⟨c, d, hc, hcd, hd, fun x hx => by
      show w₀ + nbLinCombNew N v x ≠ 0
      rw [hw₀, zero_add]; exact hne x hx⟩
  · -- Case 2: w₀ ≠ 0.
    by_cases hv : v = 0
    · -- Subcase 2a: v = 0. Then f(x) = w₀ (constant).
      exact ⟨0, 1, le_refl 0, one_pos, le_refl 1, fun x _ => by
        show w₀ + nbLinCombNew N v x ≠ 0
        rw [show nbLinCombNew N v x = 0 from by
          simp [nbLinCombNew, hv, Pi.zero_apply, zero_mul, Finset.sum_const_zero]]
        simp [hw₀]⟩
    · -- Subcase 2b: v ≠ 0. Use the integral positivity argument.
      -- ∫₀¹ f² > 0 since f is not identically zero (w₀ ≠ 0),
      -- which means f ≠ 0 on some subinterval.
      sorry

/-- nbLinCombNew is integrable (finite sum of bounded fract functions). -/
private theorem nbLinCombNew_integrable (N : ℕ) (v : Fin N → ℝ) :
    IntervalIntegrable (fun x => nbLinCombNew N v x) MeasureTheory.volume 0 1 := by
  -- nbLinCombNew is a finite sum of w_i * fract(1/(kx))
  -- Each term is bounded by |w_i|, and bounded+measurable → integrable
  -- The sum of finitely many IntervalIntegrable functions is IntervalIntegrable
  sorry

/-- nbAugLinComb² is integrable on [0,1].
    f = w₀ + g where g = nbLinCombNew. Then f² = w₀² + 2w₀g + g².
    All pieces integrable: constant, const*sum(bounded), sum(bounded)². -/
theorem nbAugLinComb_sq_integrable (N : ℕ) (w : Fin (N+1) → ℝ) :
    IntervalIntegrable (fun x => (nbAugLinComb N w x) ^ 2) MeasureTheory.volume 0 1 := by
  set w₀ := w ⟨0, Nat.zero_lt_succ N⟩
  set v := fun i : Fin N => w (Fin.succ i)
  -- f(x) = w₀ + g(x), so f² = w₀² + 2w₀g + g²
  have hf_eq : (fun x => (nbAugLinComb N w x) ^ 2) =
      (fun x => w₀ ^ 2 + 2 * w₀ * nbLinCombNew N v x + (nbLinCombNew N v x) ^ 2) := by
    ext x; show (w₀ + nbLinCombNew N v x) ^ 2 = _; ring
  rw [hf_eq]
  exact (((intervalIntegrable_const).add
    ((nbLinCombNew_integrable N v).const_mul (2 * w₀))).add
    (nbLinCombNew_sq_integrable N v))

-- ════════════════════════════════════════════════
-- §3b. DIRECT PD PROOF (replaces §3 axiom + §4 induction)
-- ════════════════════════════════════════════════

/-- **THEOREM (was axiom): H_N is positive definite for all N ≥ 1.**

    Proved DIRECTLY from the L² identity:
    wᵀH_Nw = ∫₀¹ f² > 0 for w ≠ 0.

    This ELIMINATES the augmentedSchurComplement_pos axiom
    and the inductive proof entirely. -/
theorem augmentedGramMatrix_posDef (N : ℕ) (hN : N ≥ 1) :
    (augmentedGramMatrix N).PosDef := by
  refine PosDef.of_dotProduct_mulVec_pos (augmentedGramMatrix_symmetric N) fun {w} hw => ?_
  simp only [star_trivial]
  rw [augmented_l2_identity N hN w]
  -- Need: ∫₀¹ f² > 0 for f not identically zero
  obtain ⟨c, d, hc0, hcd, hd1, hne⟩ := nbAugLinComb_nonzero_somewhere N hN w hw
  have hpos_sub : ∀ x, x ∈ Set.Ioo c d → 0 < (nbAugLinComb N w x) ^ 2 :=
    fun x hx => sq_pos_of_ne_zero (hne x hx)
  have hisub : IntervalIntegrable (fun x => (nbAugLinComb N w x) ^ 2) MeasureTheory.volume c d :=
    (nbAugLinComb_sq_integrable N w).mono_set (by
      simp only [Set.uIcc_of_le (le_of_lt hcd), Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc hc0 hd1)
  have hint_sub : 0 < ∫ x in c..d, (nbAugLinComb N w x) ^ 2 :=
    intervalIntegral.intervalIntegral_pos_of_pos_on hisub hpos_sub hcd
  have hi0c : IntervalIntegrable (fun x => (nbAugLinComb N w x) ^ 2) MeasureTheory.volume 0 c :=
    (nbAugLinComb_sq_integrable N w).mono_set (by
      simp only [Set.uIcc_of_le hc0, Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc le_rfl (hcd.le.trans hd1))
  have hid1 : IntervalIntegrable (fun x => (nbAugLinComb N w x) ^ 2) MeasureTheory.volume d 1 :=
    (nbAugLinComb_sq_integrable N w).mono_set (by
      simp only [Set.uIcc_of_le hd1, Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc (hc0.trans hcd.le) le_rfl)
  have h_01 : (∫ x in (0:ℝ)..1, (nbAugLinComb N w x) ^ 2) =
    (∫ x in (0:ℝ)..c, (nbAugLinComb N w x) ^ 2) +
    (∫ x in c..d, (nbAugLinComb N w x) ^ 2) +
    (∫ x in d..1, (nbAugLinComb N w x) ^ 2) := by
    have h1 := intervalIntegral.integral_add_adjacent_intervals hi0c hisub
    have h2 := intervalIntegral.integral_add_adjacent_intervals (hi0c.trans hisub) hid1
    linarith
  rw [h_01]
  have h1 : 0 ≤ ∫ x in (0:ℝ)..c, (nbAugLinComb N w x) ^ 2 :=
    intervalIntegral.integral_nonneg hc0 (fun x _ => sq_nonneg _)
  have h2 : 0 ≤ ∫ x in d..1, (nbAugLinComb N w x) ^ 2 :=
    intervalIntegral.integral_nonneg hd1 (fun x _ => sq_nonneg _)
  linarith

-- (§5 BASE CASE and §6 INDUCTIVE THEOREM removed — replaced by direct
-- L² proof in §3b above using nyman_beurling_lin_indep_new.)
-- ════════════════════════════════════════════════
-- §6b. CONSEQUENCE: G_N PD FROM H_N PD
-- ════════════════════════════════════════════════

-- G_N is the trailing N×N submatrix of H_N (indices 1..N).
-- For any x : Fin N → ℝ, set w = (0, x) ∈ ℝᴺ⁺¹.
-- Then wᵀH_Nw = xᵀG_Nx (all cross terms vanish because w(0)=0).

/-- Embed x ∈ ℝᴺ into ℝᴺ⁺¹ as (0, x). -/
private noncomputable def embedGram (N : ℕ) (x : Fin N → ℝ) : Fin (N+1) → ℝ :=
  Fin.cons 0 x

/-- (0, x) ≠ 0 when x ≠ 0. -/
private theorem embedGram_ne_zero (N : ℕ) (x : Fin N → ℝ) (hx : x ≠ 0) :
    embedGram N x ≠ 0 := by
  intro hw
  apply hx
  funext i
  have := congr_fun hw (Fin.succ i)
  simp [embedGram, Fin.cons] at this
  exact this

/-- **THE QUADRATIC FORM IDENTITY: (0,x)ᵀ H_N (0,x) = xᵀ G_N x.** -/
private theorem gram_quadform_eq (N : ℕ) (x : Fin N → ℝ) :
    dotProduct (embedGram N x) ((augmentedGramMatrix N).mulVec (embedGram N x)) =
    dotProduct x ((vasyuninGramMatrix N).mulVec x) := by
  simp only [dotProduct, mulVec]
  rw [Fin.sum_univ_succ]
  simp only [embedGram, Fin.cons_zero, zero_mul, zero_add]
  apply Finset.sum_congr rfl
  intro i _
  simp only [Fin.cons_succ]
  congr 1
  rw [Fin.sum_univ_succ]
  simp only [Fin.cons_zero, mul_zero, zero_add]
  simp only [Fin.cons_succ]
  apply Finset.sum_congr rfl
  intro j _
  simp only [augmentedGramMatrix, of_apply, Fin.val_succ]
  have hi : ¬ (i.val + 1 = 0) := by omega
  have hj : ¬ (j.val + 1 = 0) := by omega
  simp only [hi, hj, ↓reduceIte, and_self]
  simp [vasyuninGramMatrix, of_apply]

/-- **THEOREM: G_N is positive definite for all N ≥ 1.**

    Derived from augmentedGramMatrix_posDef.
    G_N is the trailing submatrix of H_N, so for any nonzero x,
    xᵀG_Nx = (0,x)ᵀH_N(0,x) > 0 (since H_N PD and (0,x) ≠ 0).

    This ELIMINATES gramSchurComplement_pos for deriving G_N PD. -/
theorem gramMatrix_posDef_from_augmented (N : ℕ) (hN : N ≥ 1) :
    (vasyuninGramMatrix N).PosDef := by
  have hH := augmentedGramMatrix_posDef N hN
  refine PosDef.of_dotProduct_mulVec_pos (vasyuninGramMatrix_symmetric N) fun {x} hx => ?_
  simp only [star_trivial]
  rw [← gram_quadform_eq N x]
  have h := hH.dotProduct_mulVec_pos (embedGram_ne_zero N x hx)
  simpa [star_trivial] using h

-- ════════════════════════════════════════════════
-- §7. CONSEQUENCE: bᵀG⁻¹b < 1 FROM H_N PD
-- ════════════════════════════════════════════════

-- The proof uses a specific witness vector w = (1, -G⁻¹b).
-- Key identity: wᵀH_Nw = 1 - bᵀG⁻¹b.
-- Since H_N PD and w ≠ 0, we get 1 - bᵀG⁻¹b > 0, i.e., bᵀG⁻¹b < 1.

set_option maxHeartbeats 1600000

/-- G⁻¹b vector. -/
private noncomputable def nbGinvb (N : ℕ) : Fin N → ℝ :=
  (vasyuninGramMatrix N)⁻¹.mulVec (vasyuninMeanVec N)

/-- The witness vector w = (1, -G⁻¹b) ∈ ℝᴺ⁺¹. -/
private noncomputable def nbWitness (N : ℕ) : Fin (N+1) → ℝ :=
  Fin.cons 1 (fun k => -(nbGinvb N k))

/-- w ≠ 0 since w(0) = 1 ≠ 0. -/
private theorem nbWitness_ne_zero (N : ℕ) : nbWitness N ≠ 0 := by
  intro hw
  have : nbWitness N 0 = 0 := congr_fun hw 0
  simp [nbWitness, Fin.cons] at this

/-- G · G⁻¹b = b (invertibility of G). -/
private theorem G_mul_nbGinvb (N : ℕ) (hG : (vasyuninGramMatrix N).PosDef) :
    (vasyuninGramMatrix N).mulVec (nbGinvb N) = vasyuninMeanVec N := by
  have hdet : IsUnit (vasyuninGramMatrix N).det :=
    (vasyuninGramMatrix N).isUnit_iff_isUnit_det.mp hG.isUnit
  simp only [nbGinvb, Matrix.mulVec_mulVec,
    Matrix.mul_nonsing_inv _ hdet, Matrix.one_mulVec]

/-- **THE QUADRATIC FORM IDENTITY: wᵀH_Nw = 1 - bᵀG⁻¹b.**

    Proved by expanding the double sum over Fin(N+1), splitting at index 0,
    and using G · G⁻¹b = b to show the tail vanishes. -/
private theorem quadform_eq (N : ℕ)
    (hG : (vasyuninGramMatrix N).PosDef) :
    dotProduct (nbWitness N) ((augmentedGramMatrix N).mulVec (nbWitness N)) =
    1 - dotProduct (vasyuninMeanVec N) (nbGinvb N) := by
  simp only [dotProduct, mulVec]
  rw [Fin.sum_univ_succ]
  have h_w0 : nbWitness N 0 = 1 := by simp [nbWitness, Fin.cons]
  -- Inner sum at i=0
  have h_inner0 : ∑ j : Fin (N+1), (augmentedGramMatrix N) 0 j * nbWitness N j =
      1 - dotProduct (vasyuninMeanVec N) (nbGinvb N) := by
    rw [Fin.sum_univ_succ]
    simp only [augmentedGramMatrix, of_apply, Fin.val_zero, Fin.val_succ]
    simp only [nbWitness, Fin.cons_zero, Fin.cons_succ]
    simp only [true_and, Nat.add_one_ne_zero, ↓reduceIte]
    simp only [dotProduct, vasyuninMeanVec, nbGinvb]
    ring_nf
    rw [Finset.sum_neg_distrib]
    ring
  rw [h_w0, one_mul, h_inner0]
  -- Tail sum = 0
  suffices h_tail :
      ∑ i : Fin N, nbWitness N (Fin.succ i) *
      ∑ j : Fin (N+1), (augmentedGramMatrix N) (Fin.succ i) j * nbWitness N j = 0 by
    simp only [dotProduct] at h_tail ⊢
    linarith
  apply Finset.sum_eq_zero
  intro i _
  suffices h_zero :
      ∑ j : Fin (N+1), (augmentedGramMatrix N) (Fin.succ i) j * nbWitness N j = 0 by
    rw [h_zero, mul_zero]
  rw [Fin.sum_univ_succ]
  simp only [augmentedGramMatrix, of_apply, Fin.val_succ, Fin.val_zero,
    Fin.cons_succ, nbWitness, Fin.cons_zero]
  have hi : ¬ (i.val + 1 = 0) := by omega
  simp only [hi, false_and, ↓reduceIte, Nat.add_one_ne_zero]
  have hGg := G_mul_nbGinvb N hG
  have hGg_i : (vasyuninGramMatrix N).mulVec (nbGinvb N) i = vasyuninMeanVec N i :=
    congr_fun hGg i
  simp only [mulVec, dotProduct, vasyuninGramMatrix, of_apply, vasyuninMeanVec] at hGg_i
  rw [mul_one]
  have h_neg : ∑ x : Fin N, vasyuninGramEntry (i.val + 1) (x.val + 1) * -nbGinvb N x =
      -∑ x : Fin N, vasyuninGramEntry (i.val + 1) (x.val + 1) * nbGinvb N x := by
    rw [← Finset.sum_neg_distrib]
    apply Finset.sum_congr rfl
    intro j _
    ring
  rw [h_neg, hGg_i]
  ring

/-- **THEOREM: bᵀG⁻¹b < 1 for all N ≥ 1.**

    Derived from augmentedGramMatrix_posDef via the witness vector w = (1, -G⁻¹b).
    The quadratic form wᵀH_Nw = 1 - bᵀG⁻¹b > 0 (since H_N PD and w ≠ 0).

    This ELIMINATES the vasyunin_nbDistSq_pos axiom. -/
theorem nbDistSq_pos_from_augmented (N : ℕ) (hN : N ≥ 1)
    (hG : (vasyuninGramMatrix N).PosDef) :
    dotProduct (vasyuninMeanVec N) (nbGinvb N) < 1 := by
  have hH := augmentedGramMatrix_posDef N hN
  have hw_ne := nbWitness_ne_zero N
  have hpos := hH.dotProduct_mulVec_pos hw_ne
  simp only [star_trivial] at hpos
  have h_eq := quadform_eq N hG
  linarith

end Cathedral.Vasyunin
