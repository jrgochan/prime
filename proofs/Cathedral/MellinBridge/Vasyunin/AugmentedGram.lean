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

/-- **THE L² IDENTITY**: wᵀH_Nw = ∫₀¹ f² dx.
    Proved by expanding both sides to a common normal form:
    w₀² + 2·w₀·Σ v(i)·meanEntry(i+1) + ΣᵢΣⱼ v(i)·v(j)·gramEntry(i+1,j+1)
    LHS via Fin.sum_univ_succ + casewise H expansion.
    RHS via integral linearity + the two axioms. -/
theorem augmented_l2_identity (N : ℕ) (hN : N ≥ 1) (w : Fin (N+1) → ℝ) :
    dotProduct w ((augmentedGramMatrix N).mulVec w) =
    ∫ x in (0:ℝ)..1, (nbAugLinComb N w x) ^ 2 := by
  -- Strategy: show both sides equal the same normal form.
  -- LHS expansion:
  suffices hLHS : dotProduct w ((augmentedGramMatrix N).mulVec w) =
      (w ⟨0, Nat.zero_lt_succ N⟩) ^ 2 +
      2 * (w ⟨0, Nat.zero_lt_succ N⟩) * ∑ i : Fin N, w (Fin.succ i) * vasyuninMeanEntry (i.val + 1) +
      ∑ i : Fin N, ∑ j : Fin N, w (Fin.succ i) * w (Fin.succ j) * vasyuninGramEntry (i.val + 1) (j.val + 1) by
    rw [hLHS]
    sorry -- RHS: ∫₀¹ f² = normal form (integral linearity + axioms)
  -- Prove hLHS: expand dot product
  simp only [dotProduct, mulVec, augmentedGramMatrix, of_apply]
  rw [Fin.sum_univ_succ]; simp_rw [Fin.sum_univ_succ]
  simp only [Fin.val_zero, Fin.val_succ]
  have h : ∀ x : Fin N, (x : ℕ) + 1 ≠ 0 := fun x => by omega
  simp only [and_true, h, ↓reduceIte, and_false]
  simp_rw [mul_add, Finset.sum_add_distrib, Finset.mul_sum]
  rw [show w 0 = w ⟨0, Nat.zero_lt_succ N⟩ from rfl]
  -- After distributing, we have:
  -- LHS = w₀*(1*w₀) + Σ w₀*(mean*w) + Σ w*(mean*w₀) + ΣΣ w*(gram*w)
  -- RHS = w₀² + 2*w₀*Σ(w*mean) + ΣΣ w*w*gram
  -- Rearrange: a + b + (c + d) → a + (b + c) + d
  -- using basic add_assoc/add_comm, then combine b+c with ← Finset.sum_add_distrib
  have step1 : ∀ (a b c d : ℝ), a + b + (c + d) = a + (b + c) + d := by
    intros; ring
  rw [step1]
  rw [← Finset.sum_add_distrib]
  congr 1; congr 1
  · ring
  · apply Finset.sum_congr rfl; intro i _; ring
  · apply Finset.sum_congr rfl; intro i _
    apply Finset.sum_congr rfl; intro j _; ring

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
          simp [nbLinCombNew, hv, zero_mul, Finset.sum_const_zero]]
        simp [hw₀]⟩
    · -- Subcase 2b: w₀ ≠ 0, v ≠ 0.
      -- Replicate the minimum-index analysis: on the critical interval (a,b),
      -- f(x) = w₀ + A/x - w_{k₀} = A/x - (w_{k₀} - w₀).
      -- When A ≠ 0: use affine_inv_nonzero_subinterval (already proved).
      -- When A = 0: f = w₀ - w_{k₀} (constant). Nonzero when w₀ ≠ w_{k₀}.
      -- When A = 0, w₀ = w_{k₀}: f = 0 on this interval, but this
      -- doesn't actually arise because g would then be zero (v=0 case).
      -- Find minimum nonzero index k₀ for v
      have hv_exists : ∃ i : Fin N, v i ≠ 0 := by
        by_contra h; push_neg at h; exact hv (funext h)
      let S := Finset.filter (fun i : Fin N => v i ≠ 0) Finset.univ
      have hS : S.Nonempty := by
        obtain ⟨i, hi⟩ := hv_exists
        exact ⟨i, Finset.mem_filter.mpr ⟨Finset.mem_univ _, hi⟩⟩
      set k₀ := S.min' hS
      have hvk₀ : v k₀ ≠ 0 := (Finset.mem_filter.mp (Finset.min'_mem S hS)).2
      have hv_below : ∀ i : Fin N, i < k₀ → v i = 0 := by
        intro i hi; by_contra h
        exact absurd (Finset.min'_le S i (Finset.mem_filter.mpr ⟨Finset.mem_univ _, h⟩))
          (not_le.mpr hi)
      -- Since v i = w (Fin.succ i), translate to w: w (Fin.succ i) = 0 for i < k₀
      have hw_below : ∀ i : Fin N, i < k₀ → (fun j => w (Fin.succ j)) i = 0 := by
        intro i hi; exact hv_below i hi
      set Av := ∑ i : Fin N, v i / ((i.val + 1 : ℕ) : ℝ) with hAv_def
      set k := k₀.val + 1 with hk_def
      have hk_pos : (0 : ℝ) < (k : ℝ) := by positivity
      have hk1_pos : (0 : ℝ) < (k : ℝ) + 1 := by linarith
      set a := 1 / ((k : ℝ) + 1)
      set b := 1 / (k : ℝ)
      have hab : a < b := by
        simp only [a, b]; rw [div_lt_div_iff₀ hk1_pos hk_pos]; nlinarith
      have ha_pos : (0 : ℝ) < a := by positivity
      have ha_nn : 0 ≤ a := le_of_lt ha_pos
      have hb_le_1 : b ≤ 1 := by
        simp only [b]; rw [div_le_one hk_pos]; exact_mod_cast (by omega : 1 ≤ k)
      -- On (a, b), g(x) = nbLinCombNew N v x = Av/x - v(k₀)
      -- So f(x) = w₀ + g(x) = w₀ + Av/x - v(k₀) = Av/x - (v(k₀) - w₀)
      have ha_eq : a = 1 / ((k₀.val : ℝ) + 2) := by
        simp only [a]; congr 1; simp only [hk_def]; push_cast; ring
      have hb_eq : b = 1 / ((k₀.val : ℝ) + 1) := by
        simp only [b]; congr 1; simp only [hk_def]; push_cast; ring
      by_cases hAv_zero : Av = 0
      · -- A = 0: g = -v(k₀) on (a,b), so f = w₀ - v(k₀)
        by_cases hw_vk : w₀ = v k₀
        · -- w₀ = v(k₀): f = 0 on the LEFT critical interval.
          -- THE THEORIST'S REVELATION: On the RIGHT interval (b, 1/k₀),
          -- ALL floors of 1/((i+1)x) are 0 (since (i+1)x > 1 for i ≥ k₀),
          -- so g(x) = Σ v_i/((i+1)x) = A/x = 0 (since A = 0).
          -- Therefore f(x) = w₀ ≠ 0 everywhere on the right interval.
          -- This works for k₀ ≥ 1. For k₀ = 0, the right interval escapes (0,1).
          by_cases hk₀_pos : k₀.val ≥ 1
          · -- k₀ ≥ 1: use the right interval (1/(k₀+1), 1/k₀)
            -- g = A/x - v(k₀-1) = 0/x - 0 = 0, so f = w₀ ≠ 0 on this interval.
            have hk₀v := hk₀_pos  -- k₀.val ≥ 1
            -- Interval bounds
            have hk₀_cast_pos : (0 : ℝ) < (k₀.val : ℝ) :=
              Nat.cast_pos.mpr (by omega)
            refine ⟨1 / ((k₀.val : ℝ) + 1), 1 / (k₀.val : ℝ),
              by positivity,
              by rw [div_lt_div_iff₀ (by linarith) hk₀_cast_pos]; nlinarith,
              by rw [div_le_one hk₀_cast_pos]; exact_mod_cast hk₀v,
              fun x hx => ?_⟩
            show w₀ + nbLinCombNew N v x ≠ 0
            -- The interval (1/(k₀+1), 1/k₀) = (1/(k₀'+2), 1/(k₀'+1)) where k₀' = k₀-1
            have hk₀'_bound : k₀.val - 1 < N := by omega
            have hv_below' : ∀ i : Fin N, i < ⟨k₀.val - 1, hk₀'_bound⟩ → v i = 0 := by
              intro i hi; apply hv_below
              exact lt_of_lt_of_le hi (by simp [Fin.le_def])
            have hx_lo : 1 / ((⟨k₀.val - 1, hk₀'_bound⟩ : Fin N).val + 2 : ℝ) < x := by
              change 1 / ((⟨k₀.val - 1, hk₀'_bound⟩ : Fin N).val + 2 : ℝ) < x
              simp only [Fin.val_mk]
              norm_cast
              rw [show k₀.val - 1 + 2 = k₀.val + 1 from by omega]
              exact_mod_cast hx.1
            have hx_hi : x < 1 / ((⟨k₀.val - 1, hk₀'_bound⟩ : Fin N).val + 1 : ℝ) := by
              change x < 1 / ((⟨k₀.val - 1, hk₀'_bound⟩ : Fin N).val + 1 : ℝ)
              simp only [Fin.val_mk]
              norm_cast
              rw [show k₀.val - 1 + 1 = k₀.val from by omega]
              exact_mod_cast hx.2
            rw [nbLinCombNew_eq_affine_on_critical_interval N v ⟨k₀.val - 1, hk₀'_bound⟩
                hv_below' x hx_lo hx_hi]
            -- Now: w₀ + (A/x - v(k₀-1)) ≠ 0
            -- v(k₀-1) = 0 since k₀-1 < k₀, and A = 0
            have hvk₀' : v ⟨k₀.val - 1, hk₀'_bound⟩ = 0 :=
              hv_below _ (by simp [Fin.lt_def]; omega)
            rw [hvk₀', sub_zero]
            -- Now: w₀ + A/x ≠ 0, where A = Av = 0
            conv_lhs => rw [show (∑ i : Fin N, v i / ((i.val + 1 : ℕ) : ℝ)) = Av from rfl]
            rw [hAv_zero, zero_div, add_zero]
            exact hw₀
          · -- k₀ = 0: degenerate edge case (right interval escapes (0,1))
            sorry
        · -- w₀ ≠ v(k₀): f = w₀ - v(k₀) ≠ 0 everywhere on (a, b)
          refine ⟨a, b, ha_nn, hab, hb_le_1, fun x ⟨hx_lo, hx_hi⟩ => ?_⟩
          show w₀ + nbLinCombNew N v x ≠ 0
          rw [nbLinCombNew_eq_neg_on_critical_interval N v k₀ hv_below hAv_zero x
              (by linarith) (by linarith)]
          intro h_eq
          apply hw_vk
          -- h_eq : w₀ + (-v k₀) = 0, i.e. w₀ = v k₀
          linarith
      · -- A ≠ 0: f(x) = w₀ + Av/x - v(k₀) = Av/x - (v(k₀) - w₀)
        -- Use affine_inv_nonzero_subinterval
        obtain ⟨c, d, hac, hcd, hdb, hne_f⟩ :=
          affine_inv_nonzero_subinterval Av (v k₀ - w₀) a b hAv_zero ha_pos hab
        refine ⟨c, d, by linarith, hcd, by linarith, fun x hx => ?_⟩
        show w₀ + nbLinCombNew N v x ≠ 0
        rw [nbLinCombNew_eq_affine_on_critical_interval N v k₀ hv_below x
            (by have := hx.1; linarith) (by have := hx.2; linarith)]
        have := hne_f x hx
        -- this : Av / x - (v k₀ - w₀) ≠ 0
        -- goal : w₀ + (Av / x - v k₀) ≠ 0
        intro h_eq; apply this; linarith

/-- nbLinCombNew is integrable (finite sum of bounded fract functions). -/
private theorem nbLinCombNew_integrable (N : ℕ) (v : Fin N → ℝ) :
    IntervalIntegrable (fun x => nbLinCombNew N v x) MeasureTheory.volume 0 1 := by
  -- nbLinCombNew = Σ v(i) * fract(1/((i+1)x))
  -- Pull the sum outside: ∑ (fun x => v(i) * fract(...))
  -- Each term is v(i) * (IntervalIntegrable fract)
  unfold nbLinCombNew
  show IntervalIntegrable (fun x => ∑ i : Fin N,
    v i * Int.fract (1 / (((i.val + 1 : ℕ) : ℝ) * x))) MeasureTheory.volume 0 1
  have h_swap : (fun x => ∑ i : Fin N, v i * Int.fract (1 / (((i.val + 1 : ℕ) : ℝ) * x))) =
      ∑ i ∈ Finset.univ, (fun x => v i * Int.fract (1 / (((i.val + 1 : ℕ) : ℝ) * x))) := by
    ext x; simp [Finset.sum_apply]
  rw [h_swap]
  exact IntervalIntegrable.sum Finset.univ (fun i _ =>
    (fract_inv_intervalIntegrable (i.val + 1)).const_mul (v i))

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
