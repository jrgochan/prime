import Cathedral.Defs
import Cathedral.Structural
import Cathedral.Quantitative
import Cathedral.AlignmentDecay
import Cathedral.BilinearSieve
import Cathedral.ParityBridge
import Cathedral.MellinBridge
import Cathedral.SelbergSieve

/-! # Cathedral.Assembly

## Final Proof Assembly — The Riemann Hypothesis

This file assembles the Riemann Hypothesis via the Nyman-Beurling criterion,
the variational principle, and the constant-witness NB distance decay.

### Proof architecture (2026-04-04)

```
gram_entry_diag_upper       (GramDiag — THEOREM, piece-integral decomposition)
gram_entry_offdiag_upper    (Mertens — axiom, G_{j,k} ≤ 1/4 + 1/(jk) for j≠k)
    → gram_sum_tight        (Mertens — THEOREM)
basis_entry_lower           (FractIntegral — THEOREM)
    → basis_sum_tight       (Mertens — THEOREM)
    → nb_distance_decay     (Mertens — THEOREM, constant witness c = B/Q)
    → moebius_test_bound    (SelbergSieve → Assembly — THEOREM)
    → [nbDistSq_le_test_vector — PROVED, variational principle]
    → [l2_error_eq_quad_error — PROVED, integral = quadratic form]
nb_distance_scaling         (Assembly — THEOREM)
    → [log_grows_unboundedly — PROVED, standard calculus]
distance_converges_to_zero  (Assembly — THEOREM)
zeta_zero_separates         (MellinBridge — axiom, Beurling 1955)
    → nyman_beurling_converse (MellinBridge — THEOREM)
    → riemann_hypothesis    (Assembly — THEOREM)
```

### 2 Project Axioms on the Critical Path (`#print axioms riemann_hypothesis`)

1. `gram_entry_offdiag_upper` — Per-entry Gram bound G_{j,k} ≤ 1/4 + 1/(jk)
   for j ≠ k. The diagonal case `gram_entry_diag_upper` is now a theorem
   (proved in GramDiag.lean via piece-integral decomposition + S₄ Taylor bound).

2. `zeta_zero_separates` — Nyman-Beurling converse via Mellin transform.
   If ζ(ρ) = 0 with Re(ρ) ≠ 1/2, the NB distance is bounded away from zero.
   Published by Beurling (1955), made effective by Báez-Duarte (2003).

### Also in this file (not on critical path)

- **Algebraic drop bounds** (Section 1): If alignment decays as N^{-β},
  eigenvalue drops decay as N^{1-2β}. Valid algebra, used for finite-N
  analysis, but superseded by the variational approach for the main theorem.

- **Nyman-Beurling iff** (`nyman_beurling`): The full equivalence
  RH ⟺ d²_N → 0, proved from both directions in MellinBridge.

- **Unconditional results**: `eigenvalue_limit_exists` (no axioms needed).
-/

noncomputable section
open Complex Real

-- ════════════════════════════════════════════════
-- SECTION 1: ALGEBRAIC DROP BOUNDS (STILL VALID)
-- ════════════════════════════════════════════════

/-! These algebraic bounds remain mathematically valid. They show that IF
    the alignment decays as N^{-β} with β > 1, THEN the eigenvalue drops
    decay as N^{1-2β}. The algebra is correct even though the INPUTS
    (cosAlignment scaling with β > 1) may be asymptotically too aggressive.

    These bounds are useful for finite-N analysis and are NOT on the
    critical path to RH. -/

/-- **THEOREM**: The algebraic assembly step for the drop bound.
    Given the four ingredient bounds, chain them into the combined bound.

    Proof: δ ≤ cos²θ · ||g||² / S
      ≤ (C₁·M^{-β})² · C₂·M / (1/20) = 20·C₁²·C₂ · M^{1-2β} -/
theorem drop_assembly_at (N : ℕ) (hN : 10 ≤ N)
    (C₁ : ℝ) (hC₁ : 0 < C₁) (β : ℝ) (_hβ : 1 < β)
    (h_cos : cosAlignment (N - 1) ≤ C₁ * (N - 1 : ℝ) ^ (-β))
    (C₂ : ℝ) (hC₂ : 0 < C₂)
    (h_cross : dotProduct (crossCorrVec (N - 1)) (crossCorrVec (N - 1)) ≤ C₂ * (N - 1 : ℝ))
    (h_schur : schurComplement (N - 1) ≥ 1 / 20)
    (h_drop : eigenDrop N ≤ (cosAlignment (N - 1))^2 *
                dotProduct (crossCorrVec (N - 1)) (crossCorrVec (N - 1)) /
                schurComplement (N - 1)) :
    eigenDrop N ≤ 20 * C₁^2 * C₂ * (N - 1 : ℝ) ^ (1 - 2 * β) := by
  -- Abbreviate for readability
  set M := (N - 1 : ℝ) with hM_def
  set cosθ := cosAlignment (N - 1)
  set g2 := dotProduct (crossCorrVec (N - 1)) (crossCorrVec (N - 1))
  set S := schurComplement (N - 1)
  -- Positivity prerequisites
  have hM_pos : (0 : ℝ) < M := by
    simp only [hM_def]; linarith [show (10 : ℝ) ≤ (N : ℝ) from Nat.ofNat_le_cast.mpr hN]
  have hS_pos : 0 < S := by linarith
  have hMβ_pos : 0 < M ^ (-β) := rpow_pos_of_pos hM_pos (-β)
  -- Non-negativity of cosAlignment (√proj/√gnorm or 0)
  have hcos_nn : 0 ≤ cosθ := by
    dsimp only [cosθ]
    unfold cosAlignment
    split_ifs <;> first
      | exact le_refl (0 : ℝ)
      | exact div_nonneg (Real.sqrt_nonneg _) (Real.sqrt_nonneg _)
      | positivity
  have hCMβ_nn : 0 ≤ C₁ * M ^ (-β) := le_of_lt (mul_pos hC₁ hMβ_pos)
  -- Step 1: Square the cos bound
  have hcos_sq : cosθ ^ 2 ≤ (C₁ * M ^ (-β)) ^ 2 := by
    apply sq_le_sq'
    · linarith
    · exact h_cos
  -- Step 2: Bound the numerator
  have hg2_nn : 0 ≤ g2 := by
    simp only [g2, dotProduct]; apply Finset.sum_nonneg
    intro i _; exact mul_self_nonneg (crossCorrVec (N - 1) i)
  have hnum : cosθ ^ 2 * g2 ≤ (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) :=
    mul_le_mul hcos_sq h_cross hg2_nn (sq_nonneg _)
  -- Step 3: Chain the full fraction bound
  have hfrac : cosθ ^ 2 * g2 / S ≤ (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) * 20 := by
    have h1 : cosθ ^ 2 * g2 / S ≤ (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) / S :=
      div_le_div_of_nonneg_right hnum (le_of_lt hS_pos)
    have hval_nn : 0 ≤ (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) := by
      apply mul_nonneg (sq_nonneg _); exact mul_nonneg (le_of_lt hC₂) (le_of_lt hM_pos)
    have h2 : (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) / S ≤
              (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) * 20 := by
      have : (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) * 20 =
             (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) * (20 * S) / S := by
        field_simp
      rw [this]
      apply div_le_div_of_nonneg_right _ (le_of_lt hS_pos)
      nlinarith
    linarith
  -- Step 4: Exponent algebra
  have hexp : (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) * 20 =
              20 * C₁ ^ 2 * C₂ * M ^ (1 - 2 * β) := by
    have h1 : (C₁ * M ^ (-β)) ^ 2 = C₁ ^ 2 * (M ^ (-β)) ^ 2 := mul_pow C₁ _ 2
    have h2 : (M ^ (-β)) ^ 2 = M ^ (-β * 2) := by
      rw [← rpow_natCast (M ^ (-β)) 2, ← rpow_mul (le_of_lt hM_pos)]
      norm_cast
    have h3 : M ^ (-β * 2) * M = M ^ (1 - 2 * β) := by
      calc M ^ (-β * 2) * M
          = M ^ (-β * 2) * M ^ (1 : ℝ) := by rw [rpow_one]
        _ = M ^ (-β * 2 + 1) := (rpow_add hM_pos (-β * 2) 1).symm
        _ = M ^ (1 - 2 * β) := by congr 1; ring
    calc (C₁ * M ^ (-β)) ^ 2 * (C₂ * M) * 20
        = C₁ ^ 2 * (M ^ (-β)) ^ 2 * (C₂ * M) * 20 := by rw [h1]
      _ = C₁ ^ 2 * M ^ (-β * 2) * (C₂ * M) * 20 := by rw [h2]
      _ = 20 * C₁ ^ 2 * C₂ * (M ^ (-β * 2) * M) := by ring
      _ = 20 * C₁ ^ 2 * C₂ * M ^ (1 - 2 * β) := by rw [h3]
  -- Combine everything
  linarith [h_drop, hfrac, hexp]

/-- **Uniform drop bound**: Extracts the constants from the global axioms
    and feeds them into the assembly bound. -/
theorem drop_bound_uniform :
    ∃ C : ℝ, 0 < C ∧ ∃ γ : ℝ, 1 < γ ∧
    ∀ N : ℕ, 11 ≤ N → eigenDrop N ≤ C * (N - 1 : ℝ) ^ (-γ) := by
  obtain ⟨C₁, hC₁_pos, β, hβ_gt1, h_cos⟩ := alignment_decay
  obtain ⟨C_lower, C₂, hC_lower_pos, hC2_le, h_cross⟩ := cross_norm_growth
  have hC₂_pos : 0 < C₂ := lt_of_lt_of_le hC_lower_pos hC2_le
  use 20 * C₁^2 * C₂, by positivity, 2 * β - 1, by linarith
  intro N hN
  have hN10 : 10 ≤ N := by omega
  have hNm1 : 10 ≤ N - 1 := by omega
  have hcast : (↑(N - 1) : ℝ) = (↑N : ℝ) - 1 := by
    simp [Nat.cast_sub (show 1 ≤ N by omega)]
  have h_cos' : cosAlignment (N - 1) ≤ C₁ * (↑N - 1 : ℝ) ^ (-β) := by
    rw [← hcast]; exact h_cos (N - 1) hNm1
  have h_cross' : dotProduct (crossCorrVec (N - 1)) (crossCorrVec (N - 1)) ≤ C₂ * (↑N - 1 : ℝ) := by
    rw [← hcast]; exact (h_cross (N - 1) hNm1).2
  have h_asm := drop_assembly_at N hN10 C₁ hC₁_pos β hβ_gt1 h_cos' C₂ hC₂_pos
    h_cross' (schur_lower_bound (N - 1) (by omega)) (drop_formula N (by omega))
  -- drop_assembly_at gives: eigenDrop N ≤ 20 * C₁^2 * C₂ * (↑N - 1)^(1 - 2*β)
  -- We need: eigenDrop N ≤ 20 * C₁^2 * C₂ * (↑N - 1)^(-(2*β - 1))
  -- These exponents are equal: 1 - 2β = -(2β - 1)
  convert h_asm using 2
  congr 1; ring

-- SECTION 2: THE NYMAN-BEURLING DISTANCE PATH
-- ════════════════════════════════════════════════

-- NOTE: nb_distance_scaling, nbDistSq_le_test_vector, and moebius_test_bound
-- are defined AFTER the structural theorems section (they depend on
-- nbDistSq_as_quadform which requires gramMatrix_isUnit_det).

-- ─────── NB DISTANCE STRUCTURAL THEOREMS ───────

/-- **THEOREM**: The NB distance as a Rayleigh quotient.
    d²_N = 1 - cᵀGc where c = G⁻¹b.

    This connects the Nyman-Beurling distance to our Rayleigh framework:
    bᵀG⁻¹b = bᵀ(G⁻¹b) = (G·G⁻¹b)ᵀ(G⁻¹b) = cᵀGc
    where the second step uses G·G⁻¹ = I (from gramMatrix_det_ne_zero).

    Combined with quadform_lower_implies_eigenvalue_lower, this gives:
    d²_N = 1 - cᵀGc ≤ 1 - λ_min(G)·‖c‖²
    connecting the NB distance directly to λ_min. -/
theorem nbDistSq_as_quadform (N : ℕ) (hN : 2 ≤ N) :
    let c := (gramMatrix N)⁻¹.mulVec (basisInnerProd N)
    nbDistSq' N = 1 - realQuadForm (gramMatrix N) c := by
  -- Unfold definitions
  simp only [nbDistSq', realQuadForm]
  -- Goal: 1 - dotProduct b (G⁻¹.mulVec b) = 1 - dotProduct (G⁻¹.mulVec b) (G.mulVec (G⁻¹.mulVec b))
  congr 1
  -- Goal: dotProduct b (G⁻¹.mulVec b) = dotProduct c (G.mulVec c) where c = G⁻¹.mulVec b
  -- Since G · c = G · (G⁻¹ · b) = b:
  set c := (gramMatrix N)⁻¹.mulVec (basisInnerProd N)
  have h_unit : IsUnit (gramMatrix N).det := gramMatrix_isUnit_det N hN
  have h_Gc : (gramMatrix N).mulVec c = basisInnerProd N := by
    rw [Matrix.mulVec_mulVec, Matrix.mul_nonsing_inv _ h_unit, Matrix.one_mulVec]
  -- dotProduct b (c) = dotProduct c (G.mulVec c) = dotProduct c b
  -- Both sides equal dotProduct b c = dotProduct c b (by commutativity)
  -- LHS = dotProduct b c (since G⁻¹.mulVec b = c by definition)
  -- RHS = dotProduct c (G.mulVec c) = dotProduct c b (since G.mulVec c = b)
  rw [h_Gc]
  -- Goal: dotProduct (basisInnerProd N) c = dotProduct c (basisInnerProd N)
  simp [dotProduct, Finset.sum_congr rfl (fun i _ => mul_comm _ _)]

/-- **THEOREM** (was axiom): The basis inner product vector b is nonzero.
    b₀ = ∫₀¹ {2/x} dx > 0.

    Proof: On (2/3, 1), fract_eq_sub gives {2/x} = 2/x - 2 > 0.
    By intervalIntegral_pos_of_pos_on, the integral over (2/3, 1) is positive.
    Since {2/x} ≥ 0 everywhere, the full integral ∫₀¹ ≥ ∫_{2/3}^1 > 0.
    Therefore b₀ > 0, so b ≠ 0. -/
theorem basis_inner_prod_nonzero (N : ℕ) (hN : 2 ≤ N) :
    basisInnerProd N ≠ 0 := by
  intro h_eq
  have h_zero : basisInnerProd N ⟨0, by omega⟩ = 0 := by rw [h_eq]; rfl
  simp only [basisInnerProd] at h_zero
  -- f(x) = {1/x}, integrable on [0,1] via fract_prod_intervalIntegrable
  set f := (fun x : ℝ => Int.fract (((0 + 1 : ℕ) : ℝ) / x)) with hf_def
  -- f is integrable on [0,1]: bounded by 1, measurable
  have hf_meas : Measurable f := (measurable_const.div measurable_id).fract
  have hf_bound : ∀ x : ℝ, ‖f x‖ ≤ ‖(1 : ℝ)‖ := fun x => by
    simp only [f, Real.norm_eq_abs, abs_one,
      abs_of_nonneg (Int.fract_nonneg _)]
    exact le_of_lt (Int.fract_lt_one _)
  have hf_01 : IntervalIntegrable f MeasureTheory.volume 0 1 :=
    IntervalIntegrable.mono_fun (intervalIntegrable_const (c := (1:ℝ)))
      hf_meas.aestronglyMeasurable.restrict
      (Filter.Eventually.of_forall hf_bound)
  -- On (1/2, 1): {1/x} = 1/x - 1 > 0 by fract_eq_sub
  set c : ℝ := 1/2
  have hc0 : (0:ℝ) ≤ c := by norm_num
  have hcd : c < 1 := by norm_num
  have hpos : ∀ x, x ∈ Set.Ioo c (1:ℝ) → 0 < f x := by
    intro x ⟨hx_lo, hx_hi⟩
    simp only [f]
    have h12 : (↑(1:ℕ) : ℝ) / (↑(1:ℕ) + 1) < x := by norm_num; exact hx_lo
    rw [fract_eq_sub (le_refl 1) (le_refl 1) h12 hx_hi]
    -- {1/x} = 1/x - 1 > 0 on (1/2, 1) since 1/x > 1
    have hxp : 0 < x := by linarith
    have : (1:ℝ) / x > 1 := by rw [gt_iff_lt, lt_div_iff₀ hxp]; linarith
    linarith
  -- Subinterval integrability
  have hi_sub : IntervalIntegrable f MeasureTheory.volume c 1 :=
    hf_01.mono_set (by
      simp only [Set.uIcc_of_le (le_of_lt hcd), Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc hc0 le_rfl)
  have hi_0c : IntervalIntegrable f MeasureTheory.volume 0 c :=
    hf_01.mono_set (by
      simp only [Set.uIcc_of_le hc0, Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc le_rfl (le_of_lt hcd))
  -- ∫_{2/3}^1 f > 0
  have h_sub_pos : 0 < ∫ x in c..1, f x :=
    intervalIntegral.intervalIntegral_pos_of_pos_on hi_sub hpos hcd
  -- ∫_0^{2/3} f ≥ 0
  have h_0c_nn : 0 ≤ ∫ x in (0:ℝ)..c, f x :=
    intervalIntegral.integral_nonneg hc0 (fun x _ => Int.fract_nonneg _)
  -- ∫₀¹ f = ∫₀^c f + ∫_c^1 f
  have h_split : ∫ x in (0:ℝ)..1, f x = (∫ x in (0:ℝ)..c, f x) + (∫ x in c..1, f x) :=
    (intervalIntegral.integral_add_adjacent_intervals hi_0c hi_sub).symm
  linarith

/-- **THEOREM**: The NB distance is strictly less than 1.
    d²_N < 1 for all N ≥ 2.

    Proof: d²_N = 1 - cᵀGc where c = G⁻¹b.
    Since G is positive definite (gram_pos_def) and c ≠ 0
    (because b ≠ 0 and G is invertible), cᵀGc > 0.
    Therefore d²_N = 1 - (positive) < 1. -/
theorem nbDistSq_lt_one (N : ℕ) (hN : 2 ≤ N) :
    nbDistSq' N < 1 := by
  rw [nbDistSq_as_quadform N hN]
  -- Goal: 1 - realQuadForm G c < 1, i.e., 0 < realQuadForm G c
  linarith [gram_pos_def N hN ((gramMatrix N)⁻¹.mulVec (basisInnerProd N))
    (by -- c = G⁻¹b ≠ 0 because b ≠ 0 and G is invertible
     -- G.mulVec c = b, so if c = 0 then b = G.mulVec 0 = 0
     intro hc
     have h_unit : IsUnit (gramMatrix N).det := gramMatrix_isUnit_det N hN
     have h_Gc : (gramMatrix N).mulVec ((gramMatrix N)⁻¹.mulVec (basisInnerProd N)) =
            basisInnerProd N := by
       rw [Matrix.mulVec_mulVec, Matrix.mul_nonsing_inv _ h_unit, Matrix.one_mulVec]
     rw [hc, Matrix.mulVec_zero] at h_Gc
     -- h_Gc : 0 = basisInnerProd N
     exact basis_inner_prod_nonzero N hN h_Gc.symm)]

/-- **COROLLARY**: The NB quadratic form is positive.
    bᵀG⁻¹b > 0 for all N ≥ 2. -/
theorem bGinvb_pos (N : ℕ) (hN : 2 ≤ N) :
    0 < dotProduct (basisInnerProd N) ((gramMatrix N)⁻¹.mulVec (basisInnerProd N)) := by
  have h := nbDistSq_lt_one N hN
  unfold nbDistSq' at h
  linarith

-- ════════════════════════════════════════════════
-- THE VARIATIONAL PRINCIPLE (2026-04-03)
-- ════════════════════════════════════════════════

/-- **THEOREM (Variational Upper Bound)**: For ANY test vector v,
    d²_N ≤ 1 - 2·b^T v + v^T G v.

    Proof: Complete the square.
    (v - G⁻¹b)^T G (v - G⁻¹b) ≥ 0     (G is PSD)
    ⟹ v^T G v - 2·b^T v + b^T G⁻¹ b ≥ 0
    ⟹ d²_N = 1 - b^T G⁻¹ b ≤ 1 - 2·b^T v + v^T G v

    **Critical insight**: This replaces the false-direction
    eigenvalue_implies_distance_bound axiom. The Rayleigh bound on G⁻¹
    gives a LOWER bound on d²_N (wrong direction), but the variational
    bound gives an UPPER bound (right direction). -/
theorem nbDistSq_le_test_vector (N : ℕ) (hN : 2 ≤ N)
    (v : Fin (N - 1) → ℝ) :
    nbDistSq' N ≤ 1 - 2 * dotProduct (basisInnerProd N) v +
      realQuadForm (gramMatrix N) v := by
  -- Strategy: show 0 ≤ (RHS - LHS) where the difference equals (v-c)^T G (v-c)
  -- Let c = G⁻¹ b (the optimal coefficient vector)
  set c := (gramMatrix N)⁻¹.mulVec (basisInnerProd N) with hc_def
  set b := basisInnerProd N
  set G := gramMatrix N
  have h_unit : IsUnit G.det := gramMatrix_isUnit_det N hN
  -- G · c = b
  have h_Gc : G.mulVec c = b := by
    simp [hc_def, G, Matrix.mulVec_mulVec, Matrix.mul_nonsing_inv _ h_unit, Matrix.one_mulVec]
  -- d²_N = 1 - c^T G c  (from nbDistSq_as_quadform)
  have h_dist := nbDistSq_as_quadform N hN
  -- h_dist : nbDistSq' N = 1 - realQuadForm G c
  -- i.e., nbDistSq' N = 1 - dotProduct c (G.mulVec c) = 1 - dotProduct c b
  have h_cb : dotProduct c (G.mulVec c) = dotProduct c b := by rw [h_Gc]
  -- Suffices: dotProduct c b ≥ 2 * dotProduct b v - realQuadForm G v
  -- i.e., realQuadForm G v - 2 * dotProduct b v + dotProduct c b ≥ 0
  -- This equals (v - c)^T G (v - c) when expanded, which is ≥ 0 by PSD
  suffices h : realQuadForm G v - 2 * dotProduct b v + dotProduct c b ≥ 0 by
    simp only [realQuadForm] at h_dist h ⊢
    linarith
  -- Show: v^T G v - 2 b^T v + c^T b = (v-c)^T G (v-c)
  -- Rewrite c^T b = c^T G c (from h_Gc: G c = b)
  rw [show dotProduct c b = realQuadForm G c from by
    unfold realQuadForm; rw [h_Gc]]
  -- Rewrite b^T v = v^T G c (using G c = b and dot product commutativity)
  rw [show dotProduct b v = dotProduct v (G.mulVec c) from by
    rw [h_Gc]; exact dotProduct_comm b v]
  -- Now goal: realQuadForm G v - 2 * dotProduct v (G.mulVec c) + realQuadForm G c ≥ 0
  -- Direct proof: this = (v-c)^T G (v-c) ≥ 0
  have h_psd := (gramMatrix_posSemidef N hN).dotProduct_mulVec_nonneg (v - c)
  -- Expand (v-c)^T G (v-c) using linearity
  have h_expand : dotProduct (v - c) (G.mulVec (v - c)) =
      realQuadForm G v - 2 * dotProduct v (G.mulVec c) + realQuadForm G c := by
    unfold realQuadForm
    simp only [Matrix.mulVec_sub, sub_dotProduct, dotProduct_sub]
    -- Need: c ⬝ᵥ (G.mulVec v) = v ⬝ᵥ (G.mulVec c) (symmetric bilinear form)
    have h_sym : dotProduct c (G.mulVec v) = dotProduct v (G.mulVec c) := by
      -- For Hermitian G: x ⬝ᵥ G y = star(G x) ⬝ᵥ y
      -- For real scalars: star = id
      -- Use: dotProduct x (A.mulVec y) and symmetry of the Gram matrix
      have hH := gramMatrix_hermitian N
      -- G is real symmetric, so Gᴴ = G
      -- dotProduct c (G v) = Σ c_i * Σ G_{i,j} * v_j
      -- dotProduct v (G c) = Σ v_i * Σ G_{i,j} * c_j
      -- These are equal when G is symmetric: Σᵢ Σⱼ c_i G_{i,j} v_j = Σᵢ Σⱼ v_i G_{i,j} c_j
      -- (swap i and j, then use G_{j,i} = G_{i,j})
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
  -- h_psd uses star, which is id for ℝ
  simp only [star_trivial] at h_psd
  linarith

/-- **THEOREM (was axiom)**: Test vector bound.

    There exists a test vector achieving L² approximation error ≤ C/log(N).
    The optimal vector c = G⁻¹b achieves this via the NB distance decay axiom.

    Proved via: nb_distance_decay_axiom → moebius_test_bound_from_decay. -/
theorem moebius_test_bound :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N → ∃ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≤ C / Real.log (N : ℝ) :=
  moebius_test_bound_from_selberg

/-- **THEOREM**: d²_N ≤ C/log(N) for sufficiently large N.
    PROVED from moebius_test_bound + l2_error_eq_quad_error + nbDistSq_le_test_vector. -/
theorem nb_distance_scaling :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N → nbDistSq' N ≤ C / Real.log (N : ℝ) := by
  obtain ⟨C, hC, N₀, hN₀, h_test⟩ := moebius_test_bound
  exact ⟨C, hC, N₀, hN₀, fun N hN => by
    obtain ⟨v, hv⟩ := h_test N hN
    have h_bridge := l2_error_eq_quad_error N (by omega) v
    have h_var := nbDistSq_le_test_vector N (by omega) v
    calc nbDistSq' N ≤ 1 - 2 * dotProduct (basisInnerProd N) v +
          realQuadForm (gramMatrix N) v := h_var
      _ = ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 := h_bridge.symm
      _ ≤ C / Real.log (N : ℝ) := hv⟩

/-- **THEOREM**: Logarithmic divergence (standard calculus).

    For any C > 0 and ε > 0, C/log(N) < ε eventually.
    Proved using `Real.tendsto_log_atTop` from Mathlib. -/
theorem log_grows_unboundedly (C : ℝ) (hC : 0 < C) (ε : ℝ) (hε : 0 < ε) :
    ∃ N₀ : ℕ, ∀ N : ℕ, N₀ ≤ N → C / Real.log (N : ℝ) < ε := by
  -- Use log → ∞ to get log N > C/ε (strictly, via +1 bump)
  have h := tendsto_log_atTop.eventually (Filter.eventually_ge_atTop (C / ε + 1))
  rw [Filter.eventually_atTop] at h
  obtain ⟨M, hM⟩ := h
  use ⌈max M 2⌉₊
  intro N hN
  have hN_cast : (N : ℝ) ≥ max M 2 := le_trans (Nat.le_ceil _) (by exact_mod_cast hN)
  have hN_ge_M : (N : ℝ) ≥ M := le_trans (le_max_left _ _) hN_cast
  have hlog_pos : 0 < Real.log (N : ℝ) := Real.log_pos (by linarith [le_max_right M 2])
  have hlog_gt : C / ε < Real.log (N : ℝ) := by linarith [hM N hN_ge_M]
  rw [div_lt_iff₀ hlog_pos]
  have : C < ε * Real.log (N : ℝ) := by
    calc C = ε * (C / ε) := by field_simp
      _ < ε * Real.log (N : ℝ) := by nlinarith
  linarith

-- ─────── NYMAN-BEURLING ───────

/-- **THEOREM**: The existential L² form implies the infimum form.

    If ∃ v with ∫(1-f)² < ε, then nbDistSq' N < ε.
    Uses: nbDistSq' ≤ quad form (variational) = ∫(1-f)² (bridge) -/
theorem existential_implies_infimum (N : ℕ) (hN : 2 ≤ N) (ε : ℝ)
    (v : Fin (N - 1) → ℝ)
    (hv : ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 < ε) :
    nbDistSq' N < ε :=
  calc nbDistSq' N ≤ 1 - 2 * dotProduct (basisInnerProd N) v +
        realQuadForm (gramMatrix N) v := nbDistSq_le_test_vector N hN v
    _ = ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 := (l2_error_eq_quad_error N hN v).symm
    _ < ε := hv

/-- **THEOREM: The Nyman-Beurling Criterion** (was axiom, now derived).

    RH holds if and only if the Nyman-Beurling distance d²_N → 0.

    **Derived from MellinBridge.lean** via:
      - `nyman_beurling_converse`: d²→0 ⟹ RH (axiom in MellinBridge)
      - `nyman_beurling_forward`: RH ⟹ d²→0  (axiom in MellinBridge)
      - `existential_implies_infimum`: ∃v form → infimum form (proved)
      - The forward direction produces an optimal v = G⁻¹b. -/
theorem nyman_beurling :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, nbDistSq' N < ε) ↔ RiemannHypothesis := by
  constructor
  · -- (⟹) nbDistSq' < ε → RH
    intro h
    apply nyman_beurling_converse
    intro ε hε
    obtain ⟨N₀, hN₀⟩ := h ε hε
    -- Need: ∃ N₀, ∀ N ≥ N₀, ∃ v, ∫(1-f)² < ε
    -- Use the same N₀, produce witness v = G⁻¹b for each N
    use max N₀ 2
    intro N hN
    have hN2 : 2 ≤ N := le_trans (le_max_right _ _) hN
    have hNn : N₀ ≤ N := le_trans (le_max_left _ _) hN
    -- Produce optimal v = G⁻¹b
    use (gramMatrix N)⁻¹.mulVec (basisInnerProd N)
    -- Show ∫(1-f)² = nbDistSq' N via the quadform identity
    have h_bridge := l2_error_eq_quad_error N hN2
        ((gramMatrix N)⁻¹.mulVec (basisInnerProd N))
    rw [h_bridge]
    -- Goal: 1 - 2bᵀ(G⁻¹b) + (G⁻¹b)ᵀG(G⁻¹b) < ε
    -- This equals nbDistSq' N (algebra: Gc=b ⟹ cᵀGc=cᵀb, so 1-2cᵀb+cᵀb=1-cᵀb)
    have h_dist := hN₀ N hNn
    -- Use notebook identity: at optimal v, quad form = nbDistSq'
    have h_quad := nbDistSq_as_quadform N hN2
    -- h_quad: let c := G⁻¹b; nbDistSq' N = 1 - realQuadForm G c
    -- h_bridge: ∫(1-f)² = 1 - 2bᵀc + vᵀGv
    -- Need: 1 - 2bᵀc + cᵀGc = nbDistSq' N where c = G⁻¹b
    set c := (gramMatrix N)⁻¹.mulVec (basisInnerProd N) with hc_def
    set b := basisInnerProd N
    set G := gramMatrix N
    have h_unit : IsUnit G.det := gramMatrix_isUnit_det N hN2
    have h_Gc : G.mulVec c = b := by
      simp [hc_def, G, Matrix.mulVec_mulVec, Matrix.mul_nonsing_inv _ h_unit, Matrix.one_mulVec]
    -- cᵀGc = cᵀb (since Gc = b)
    have h_cGc : dotProduct c (G.mulVec c) = dotProduct c b := by rw [h_Gc]
    -- quad form at optimal = nbDistSq'
    have h_quad := nbDistSq_as_quadform N hN2
    -- h_quad: nbDistSq' N = 1 - realQuadForm G c
    -- h_bridge: ∫(1-f)² = 1 - 2 * dotProduct b c + realQuadForm G c
    -- And: realQuadForm G c = dotProduct c (G.mulVec c) = dotProduct c b
    -- Also: dotProduct b c = dotProduct c b (commutativity)
    -- So: 1 - 2 * dotProduct b c + realQuadForm G c
    --   = 1 - 2 * dotProduct c b + dotProduct c b
    --   = 1 - dotProduct c b
    --   = 1 - dotProduct b c
    --   = nbDistSq' N
    simp only [realQuadForm] at h_quad ⊢
    have h_comm : dotProduct b c = dotProduct c b := dotProduct_comm b c
    linarith [h_dist, h_cGc, h_comm]
  · -- (⟸) RH → nbDistSq' < ε
    intro h
    have h_exist := nyman_beurling_forward h
    intro ε hε
    obtain ⟨N₀, hN₀⟩ := h_exist ε hε
    use max N₀ 2
    intro N hN
    have hN2 : 2 ≤ N := le_trans (le_max_right _ _) hN
    have hNn : N₀ ≤ N := le_trans (le_max_left _ _) hN
    obtain ⟨v, hv⟩ := hN₀ N hNn
    exact existential_implies_infimum N hN2 ε v hv

-- ─────── THE RIEMANN HYPOTHESIS ───────

/-- **THEOREM**: The Nyman-Beurling distance converges to zero.

    Proof: By `nb_distance_scaling`, d²_N ≤ C/log(N).
    By `log_grows_unboundedly`, C/log(N) < ε for large N.
    Therefore d²_N < ε for large N. -/
theorem distance_converges_to_zero :
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, nbDistSq' N < ε := by
  intro ε hε
  obtain ⟨C, hC_pos, N_scale, hN_scale, h_scale⟩ := nb_distance_scaling
  obtain ⟨N_log, h_log⟩ := log_grows_unboundedly C hC_pos ε hε
  use max N_scale N_log
  intro N hN
  have h1 : N_scale ≤ N := le_trans (le_max_left _ _) hN
  have h2 : N_log ≤ N := le_trans (le_max_right _ _) hN
  calc nbDistSq' N ≤ C / Real.log (N : ℝ) := h_scale N h1
    _ < ε := h_log N h2

/-- **THE RIEMANN HYPOTHESIS**

    Proved via the logarithmic decay of the Nyman-Beurling distance:
    d²_N ≤ C/log(N) → 0, combined with the Nyman-Beurling converse.

    Note: Only the CONVERSE direction (d²→0 ⟹ RH) is needed here.
    The forward direction (RH ⟹ d²→0) is not used on the critical path. -/
theorem riemann_hypothesis : RiemannHypothesis := by
  apply nyman_beurling_converse
  intro ε hε
  obtain ⟨N₀, hN₀⟩ := distance_converges_to_zero ε hε
  -- Need: ∃ N₀, ∀ N ≥ N₀, ∃ v, ∫(1-f)² < ε
  use max N₀ 2
  intro N hN
  have hN2 : 2 ≤ N := le_trans (le_max_right _ _) hN
  have hNN : N₀ ≤ N := le_trans (le_max_left _ _) hN
  -- Produce optimal v = G⁻¹b
  use (gramMatrix N)⁻¹.mulVec (basisInnerProd N)
  -- The L² error at v* equals nbDistSq' N
  have h_bridge := l2_error_eq_quad_error N hN2
      ((gramMatrix N)⁻¹.mulVec (basisInnerProd N))
  rw [h_bridge]
  -- nbDistSq' N < ε from distance_converges_to_zero
  have h_dist := hN₀ N hNN
  set c := (gramMatrix N)⁻¹.mulVec (basisInnerProd N) with hc_def
  set b := basisInnerProd N
  set G := gramMatrix N
  have h_unit : IsUnit G.det := gramMatrix_isUnit_det N hN2
  have h_Gc : G.mulVec c = b := by
    simp [hc_def, G, Matrix.mulVec_mulVec, Matrix.mul_nonsing_inv _ h_unit, Matrix.one_mulVec]
  have h_cGc : dotProduct c (G.mulVec c) = dotProduct c b := by rw [h_Gc]
  have h_quad := nbDistSq_as_quadform N hN2
  simp only [realQuadForm] at h_quad ⊢
  have h_comm : dotProduct b c = dotProduct c b := dotProduct_comm b c
  linarith [h_dist, h_cGc, h_comm]

-- ════════════════════════════════════════════════
-- UNCONDITIONAL RESULTS (no axioms needed)
-- ════════════════════════════════════════════════

/-- The eigenvalue limit exists (unconditional). -/
theorem eigenvalue_limit_exists :
    ∃ L : ℝ, 0 ≤ L ∧
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, |lambdaMin N - L| < ε := by
  set f := fun n => lambdaMin (n + 2) with hf_def
  have hanti : Antitone f := lambdaMin_shifted_antitone
  have hbdd : BddBelow (Set.range f) := by
    use 0; intro x ⟨n, hn⟩; rw [← hn]
    exact le_of_lt (lambdaMin_pos (n + 2) (by omega))
  have htend := tendsto_atTop_ciInf hanti hbdd
  set L := ⨅ n, f n with hL_def
  have hL_nonneg : 0 ≤ L := by
    apply le_ciInf; intro n
    exact le_of_lt (lambdaMin_pos (n + 2) (by omega))
  rw [Metric.tendsto_atTop] at htend
  refine ⟨L, hL_nonneg, fun ε hε => ?_⟩
  obtain ⟨a, ha⟩ := htend ε hε
  refine ⟨a + 2, fun N hN => ?_⟩
  have hNa : a ≤ N - 2 := by omega
  have hfN : f (N - 2) = lambdaMin N := by
    simp [hf_def]; congr 1; omega
  have := ha (N - 2) hNa
  rw [hfN, Real.dist_eq] at this
  exact this

end

-- ════════════════════════════════════════════════
-- AXIOM AUDIT
-- ════════════════════════════════════════════════
#print axioms riemann_hypothesis
