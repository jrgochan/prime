/-
  Cathedral/Structural/Independence.lean

  ## NB linear independence and positive definiteness.

  Proves that the Gram matrix is positive definite (and hence invertible).

  Core results:
  - fract_eq_sub (floor computation on intervals — general, basis-agnostic)
  - bd_nyman_beurling_lin_indep (PROVEN: ∫ f² > 0 for BD basis)
  - gram_pos_def (wᵀGw > 0)
  - gram_positive_definite (λ_min > 0)
  - gramMatrix_det_ne_zero

  HISTORY: Migrated to BD basis {1/(kx)} on 2026-05-07.
  Linear independence graduated from axiom to theorem on 2026-05-07
  using the floor constancy theorem: on (1/(n+1), 1/n),
  ⌊1/(mx)⌋ = ⌊n/m⌋ for all positive m (see BDFloorArithmetic.lean).
-/

import Cathedral.Defs
import Cathedral.Spectral.RayleighBridge
import Cathedral.Gram.NbLinComb
import Cathedral.Structural.BDFloorArithmetic

noncomputable section
open Complex Real

-- ════════════════════════════════════════════════
-- FLOOR COMPUTATIONS ON INTERVALS
-- ════════════════════════════════════════════════

/-- On (n/(n+1), 1) with m ≤ n ≥ 1, {m/x} = m/x - m. -/
theorem fract_eq_sub {n m : ℕ} (hm : m ≤ n) (hn : 1 ≤ n)
    {x : ℝ} (hx_lo : (n : ℝ) / (↑n + 1) < x) (hx_hi : x < 1) :
    Int.fract ((m : ℝ) / x) = (m : ℝ) / x - (m : ℝ) := by
  have hx_pos : 0 < x := by linarith [show (0:ℝ) < ↑n / (↑n + 1) by positivity]
  have h1 : (m : ℝ) * x ≤ ↑m := by nlinarith
  have hn_ineq : (↑n : ℝ) < x * (↑n + 1) :=
    (div_lt_iff₀ (by positivity : (0:ℝ) < ↑n + 1)).mp hx_lo
  have hm_cross : (m : ℝ) * (↑n + 1) ≤ ↑n * (↑m + 1) := by
    have : (m : ℝ) ≤ ↑n := by exact_mod_cast hm
    nlinarith
  have h2 : ↑m < (↑m + 1) * x := by nlinarith
  have h_floor : ⌊(m : ℝ) / x⌋ = (m : ℤ) := by
    rw [Int.floor_eq_iff]
    constructor
    · push_cast; rw [le_div_iff₀ hx_pos]; linarith
    · push_cast; rw [div_lt_iff₀ hx_pos]; linarith
  simp only [Int.fract, h_floor]; push_cast; ring

-- ════════════════════════════════════════════════
-- INTEGRABILITY AND POSITIVE DEFINITENESS
-- ════════════════════════════════════════════════

/-- nbLinComb² is integrable on [0,1]. -/
theorem nbLinComb_sq_integrable (N : ℕ) (w : Fin (N - 1) → ℝ) :
    IntervalIntegrable (fun x => (nbLinComb N w x) ^ 2) MeasureTheory.volume 0 1 := by
  have h_sq : (fun x => (nbLinComb N w x) ^ 2) =
      (fun x => ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
        (w i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x))) *
        (w j * Int.fract (1 / ((↑(j.val + 1) : ℝ) * x)))) := by
    ext x; unfold nbLinComb; rw [sq, Finset.sum_mul_sum]
  rw [h_sq]
  have : (fun x : ℝ => ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
      (w i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x))) *
      (w j * Int.fract (1 / ((↑(j.val + 1) : ℝ) * x)))) =
    (∑ i : Fin (N - 1), ∑ j : Fin (N - 1), fun x =>
      (w i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x))) *
      (w j * Int.fract (1 / ((↑(j.val + 1) : ℝ) * x)))) := by
    ext x; simp [Finset.sum_apply]
  rw [this]
  apply IntervalIntegrable.sum; intro i _
  apply IntervalIntegrable.sum; intro j _
  have : (fun x : ℝ => (w i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x))) *
      (w j * Int.fract (1 / ((↑(j.val + 1) : ℝ) * x)))) =
    (fun x : ℝ => (w i * w j) * (Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) *
      Int.fract (1 / ((↑(j.val + 1) : ℝ) * x)))) := by ext x; ring
  rw [this]
  exact (fract_prod_intervalIntegrable (i.val + 1) (j.val + 1)).const_mul _

/-- **BD linear independence** (PROVEN): ∫₀¹ (Σ wᵢ{1/((i+1)x)})² dx > 0 for w ≠ 0.
    Graduated from axiom using floor constancy on (1/(n+1), 1/n). -/
theorem bd_nyman_beurling_lin_indep (N : ℕ) (hN : 2 ≤ N)
    (w : Fin (N - 1) → ℝ) (hw : w ≠ 0) :
    0 < ∫ x in (0:ℝ)..1, (nbLinComb N w x) ^ 2 := by
  obtain ⟨c, d, hc0, hcd, hd1, hne⟩ := bd_nbLinComb_nonzero_somewhere N hN w hw
  have hpos_sub : ∀ x, x ∈ Set.Ioo c d → 0 < (nbLinComb N w x) ^ 2 :=
    fun x hx => sq_pos_of_ne_zero (hne x hx)
  have hisub : IntervalIntegrable (fun x => (nbLinComb N w x) ^ 2) MeasureTheory.volume c d :=
    (nbLinComb_sq_integrable N w).mono_set (by
      simp only [Set.uIcc_of_le (le_of_lt hcd), Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc hc0 hd1)
  have hint_sub : 0 < ∫ x in c..d, (nbLinComb N w x) ^ 2 :=
    intervalIntegral.intervalIntegral_pos_of_pos_on hisub hpos_sub hcd
  have hi0c : IntervalIntegrable (fun x => (nbLinComb N w x) ^ 2) MeasureTheory.volume 0 c :=
    (nbLinComb_sq_integrable N w).mono_set (by
      simp only [Set.uIcc_of_le hc0, Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc le_rfl (hcd.le.trans hd1))
  have hid1 : IntervalIntegrable (fun x => (nbLinComb N w x) ^ 2) MeasureTheory.volume d 1 :=
    (nbLinComb_sq_integrable N w).mono_set (by
      simp only [Set.uIcc_of_le hd1, Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc (hc0.trans hcd.le) le_rfl)
  have h_01 : (∫ x in (0:ℝ)..1, (nbLinComb N w x) ^ 2) =
    (∫ x in (0:ℝ)..c, (nbLinComb N w x) ^ 2) +
    (∫ x in c..d, (nbLinComb N w x) ^ 2) +
    (∫ x in d..1, (nbLinComb N w x) ^ 2) := by
    have h1 := intervalIntegral.integral_add_adjacent_intervals hi0c hisub
    have h2 := intervalIntegral.integral_add_adjacent_intervals (hi0c.trans hisub) hid1
    linarith
  rw [h_01]
  have h1 : 0 ≤ ∫ x in (0:ℝ)..c, (nbLinComb N w x) ^ 2 :=
    intervalIntegral.integral_nonneg hc0 (fun x _ => sq_nonneg _)
  have h2 : 0 ≤ ∫ x in d..1, (nbLinComb N w x) ^ 2 :=
    intervalIntegral.integral_nonneg hd1 (fun x _ => sq_nonneg _)
  linarith

/-- **gram_pos_def**: wᵀGw > 0 for w ≠ 0. -/
theorem gram_pos_def (N : ℕ) (hN : 2 ≤ N)
    (w : Fin (N - 1) → ℝ) (hw : w ≠ 0) :
    0 < realQuadForm (gramMatrix N) w := by
  rw [gram_l2_identity N hN w]
  exact bd_nyman_beurling_lin_indep N hN w hw

/-- **The Gram matrix is positive definite** for N ≥ 2: λ_min > 0. -/
theorem gram_positive_definite (N : ℕ) (hN : 2 ≤ N) : 0 < lambdaMin N := by
  unfold lambdaMin
  simp only [show N ≥ 2 from hN, dite_true]
  exact pos_def_implies_min_eigenvalue_pos
    (gramMatrix_hermitian N)
    (by omega)
    (fun v hv => gram_pos_def N hN v hv)

theorem lambdaMin_pos (N : ℕ) (hN : 2 ≤ N) : 0 < lambdaMin N :=
  gram_positive_definite N hN

/-- det(G) ≠ 0 for N ≥ 2. -/
theorem gramMatrix_det_ne_zero (N : ℕ) (hN : 2 ≤ N) :
    (gramMatrix N).det ≠ 0 := by
  intro h_zero
  rw [Matrix.exists_mulVec_eq_zero_iff.symm] at h_zero
  obtain ⟨v, hv_ne, hv_ker⟩ := h_zero
  have h_pos := gram_pos_def N hN v hv_ne
  rw [realQuadForm, hv_ker, dotProduct_zero] at h_pos
  exact lt_irrefl 0 h_pos

/-- Global IsUnit seal for the Gram matrix determinant. -/
lemma gramMatrix_isUnit_det (N : ℕ) (hN : 2 ≤ N) :
    IsUnit (gramMatrix N).det :=
  isUnit_iff_ne_zero.mpr (gramMatrix_det_ne_zero N hN)

end
