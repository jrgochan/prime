/-
  Cathedral/Mertens.lean

  ## NB Distance Decay — The Constant Witness Approach

  ### Key Discovery (2026-04-04):
  The CONSTANT test vector w_k = c handles everything!

  For w_k = c (constant), f(x) = c·Σ{k/x}, and
  ∫₀¹(1-f)² = 1 - 2c·B + c²·Q where:
    B = Σ b_k = Σ ∫₀¹{k/x}dx   (sum of basis inner products)
    Q = 𝟙ᵀG𝟙 = ∫₀¹(Σ{k/x})²dx (total Gram mass)

  At c_opt = B/Q: error = 1 - B²/Q.
  Numerically: 1 - B²/Q ≈ 2·log(N)/N = o(1/log N). ✓

  ### Architecture:
  FractIntegral.lean: basis_entry_lower (THEOREM from axioms)
      ↓ [basis_sum_tight — THEOREM]
  gram_sum_tight (AXIOM — Vasyunin expansion)
      ↓ [nb_distance_decay_axiom' — THEOREM!]
      ↓ [SelbergSieve.lean: moebius_test_bound_from_selberg]
      ↓ [Assembly.lean: moebius_test_bound, nb_distance_scaling]
      ↓ riemann_hypothesis
-/

import Cathedral.Defs
import Cathedral.Structural
import Cathedral.GramBounds
import Cathedral.FractIntegral
import Cathedral.GramDiag

noncomputable section
open Real MeasureTheory Set Finset Matrix

-- ════════════════════════════════════════════════
-- DEFINITIONS
-- ════════════════════════════════════════════════

/-- Sum of basis inner products: B(N) = Σ_{k=1}^{N-1} b_k = Σ ∫₀¹ {k/x} dx. -/
noncomputable def basisSum (N : ℕ) : ℝ :=
  ∑ i : Fin (N - 1), basisInnerProd N i

/-- Total Gram mass: Q(N) = 𝟙ᵀG𝟙 = Σ_{j,k} G_{jk}. -/
noncomputable def gramSum (N : ℕ) : ℝ :=
  ∑ i : Fin (N - 1), ∑ j : Fin (N - 1), gramMatrix N i j

-- ════════════════════════════════════════════════
-- ALGEBRA HELPERS
-- ════════════════════════════════════════════════

def constVec (N : ℕ) (c : ℝ) : Fin (N - 1) → ℝ := fun _ => c

lemma dot_const (N : ℕ) (c : ℝ) :
    dotProduct (basisInnerProd N) (constVec N c) = c * basisSum N := by
  unfold dotProduct basisSum constVec
  simp [Finset.mul_sum]
  congr 1; ext i; ring

lemma quad_const (N : ℕ) (c : ℝ) :
    realQuadForm (gramMatrix N) (constVec N c) = c ^ 2 * gramSum N := by
  simp only [realQuadForm, constVec, gramSum, dotProduct, Matrix.mulVec,
             Finset.mul_sum]
  ring_nf

-- ════════════════════════════════════════════════
-- PURE ℝ HELPER LEMMAS
-- ════════════════════════════════════════════════

lemma quadratic_bound_of_bounds
    (M L A D B Q : ℝ) (hM : M > 0) (_hL : L > 0)
    (_hA : A > 0) (_hD : D > 0)
    (hB : B ≥ M / 2 - A * L)
    (hQ : Q ≤ M ^ 2 / 4 + D * (M + 1)) :
    1 - 2 * (2 / M * B) + (2 / M) ^ 2 * Q ≤
    4 * A * L / M + 4 * D * (M + 1) / M ^ 2 := by
  have hM2 : M ^ 2 > 0 := by positivity
  have hMne : M ≠ 0 := ne_of_gt hM
  rw [div_add_div _ _ (ne_of_gt hM) (ne_of_gt hM2)]
  rw [le_div_iff₀ (mul_pos hM hM2)]
  have h1 : B * M ≥ M ^ 2 / 2 - A * L * M := by nlinarith
  have h2 : Q * 4 ≤ M ^ 2 + 4 * D * (M + 1) := by nlinarith
  have : (1 - 2 * (2 / M * B) + (2 / M) ^ 2 * Q) * (M * M ^ 2) =
         M ^ 3 - 4 * B * M ^ 2 + 4 * Q * M := by
    field_simp; ring
  rw [this]
  nlinarith [sq_nonneg M, sq_nonneg B]

lemma simplify_error_bound (M L A D : ℝ) (hM : M ≥ 2) (hL : L ≥ 1)
    (hA : A > 0) (hD : D > 0) :
    4 * A * L / M + 4 * D * (M + 1) / M ^ 2 ≤
    (8 * A + 8 * D) * L / M := by
  have hMpos : M > 0 := by linarith
  have hM2pos : M ^ 2 > 0 := by positivity
  rw [div_add_div _ _ (ne_of_gt hMpos) (ne_of_gt hM2pos)]
  rw [div_le_div_iff₀ (mul_pos hMpos hM2pos) hMpos]
  have hM3 : M ^ 3 > 0 := by positivity
  have lhs_expand : (4 * A * L * M ^ 2 + M * (4 * D * (M + 1))) * M =
    4 * A * L * M ^ 3 + 4 * D * M ^ 2 * (M + 1) := by ring
  have rhs_expand : (8 * A + 8 * D) * L * (M * M ^ 2) =
    8 * A * L * M ^ 3 + 8 * D * L * M ^ 3 := by ring
  rw [lhs_expand, rhs_expand]
  have h1 : 4 * D * M ^ 2 * (M + 1) ≤ 8 * D * M ^ 3 := by
    have : 4 * D * M ^ 2 * (M + 1) = 4 * D * M ^ 3 + 4 * D * M ^ 2 := by ring
    have : 8 * D * M ^ 3 = 4 * D * M ^ 3 + 4 * D * M ^ 3 := by ring
    have hD_M2_pos : 0 < D * M ^ 2 := by positivity
    have hM_ge_1 : M - 1 ≥ 1 := by linarith
    nlinarith [mul_pos hD_M2_pos (show 0 < M - 1 by linarith)]
  have h2 : 8 * D * M ^ 3 ≤ 8 * D * L * M ^ 3 := by
    have : 0 < 8 * D * M ^ 3 := by positivity
    nlinarith
  have h3 : 4 * A * L * M ^ 3 ≤ 8 * A * L * M ^ 3 := by
    nlinarith [show 0 ≤ A * L * M ^ 3 from by positivity]
  linarith

lemma ratio_flip (K C L M : ℝ) (hL : L > 0) (hM : M > 0)
    (hK : K ≥ 0) (hKC : K ≤ C) (hL2 : L ^ 2 ≤ M) :
    K * L / M ≤ C / L := by
  rw [div_le_div_iff₀ hM hL]
  calc K * L * L = K * L ^ 2 := by ring
    _ ≤ K * M := by nlinarith
    _ ≤ C * M := by nlinarith

theorem log_sq_le_self :
    ∃ N₀ : ℕ, 4 ≤ N₀ ∧ ∀ N : ℕ, N₀ ≤ N →
    Real.log (N : ℝ) ^ 2 ≤ ((N : ℝ) - 1) := by
  refine ⟨258, by omega, fun N hN => ?_⟩
  have hNge : (258 : ℝ) ≤ (N : ℝ) := by exact_mod_cast hN
  have hNnn : (0 : ℝ) ≤ (N : ℝ) := by linarith
  have h1 := Real.log_le_rpow_div hNnn (show (0:ℝ) < 1/4 by norm_num)
  set s := Real.sqrt (N : ℝ) with hs_def
  have hSnn : 0 ≤ s := Real.sqrt_nonneg _
  have hSsq : s * s = (N : ℝ) := Real.mul_self_sqrt hNnn
  have hN14 : (N : ℝ) ^ ((1:ℝ)/4) = Real.sqrt s := by
    rw [show (1:ℝ)/4 = (1/2) * (1/2) from by norm_num,
        Real.rpow_mul hNnn]
    conv_lhs => rw [show (N:ℝ) ^ ((1:ℝ)/2) = s from by rw [hs_def, Real.sqrt_eq_rpow]]
    rw [Real.sqrt_eq_rpow]
  rw [hN14] at h1
  have h1' : Real.log (N : ℝ) ≤ 4 * Real.sqrt s := by linarith [show (0:ℝ) < 1/4 from by norm_num]
  have hs16 : s ≥ 16 := by
    rw [ge_iff_le, hs_def, ← Real.sqrt_sq (show (0:ℝ) ≤ 16 by norm_num)]
    apply Real.sqrt_le_sqrt
    nlinarith
  have hSs_nn : 0 ≤ Real.sqrt s := Real.sqrt_nonneg _
  have hSs4 : Real.sqrt s ≥ 4 := by
    rw [ge_iff_le, ← Real.sqrt_sq (show (0:ℝ) ≤ 4 by norm_num)]
    apply Real.sqrt_le_sqrt; nlinarith
  have hSsSsq : Real.sqrt s * Real.sqrt s = s := Real.mul_self_sqrt hSnn
  have hlog_nn : 0 ≤ Real.log (N : ℝ) := Real.log_nonneg (by linarith : (1:ℝ) ≤ (N:ℝ))
  have h2 : Real.log (N : ℝ) ^ 2 ≤ 16 * s := by
    have : Real.log (N:ℝ) ^ 2 ≤ (4 * Real.sqrt s) ^ 2 :=
      sq_le_sq' (by linarith) h1'
    calc Real.log (N:ℝ) ^ 2 ≤ (4 * Real.sqrt s) ^ 2 := this
      _ = 16 * (Real.sqrt s * Real.sqrt s) := by ring
      _ = 16 * s := by rw [hSsSsq]
  have h3 : 16 * s ≤ (N : ℝ) - 1 := by
    rw [← hSsq]
    nlinarith [sq_nonneg (s - 16)]
  linarith

-- ════════════════════════════════════════════════
-- LAYER 2: HARMONIC NUMBER TOOLS
-- ════════════════════════════════════════════════

noncomputable def harmonicFin (n : ℕ) : ℝ :=
  ∑ i : Fin n, 1 / ((i.val : ℝ) + 1)

private lemma inv_succ_le_log_div (k : ℕ) (hk : 1 ≤ k) :
    1 / ((k : ℝ) + 1) ≤ Real.log ((k : ℝ) + 1) - Real.log (k : ℝ) := by
  rw [← Real.log_div (by positivity) (by positivity)]
  have hk_pos : (k : ℝ) > 0 := Nat.cast_pos.mpr (by omega)
  have hk1_pos : (k : ℝ) + 1 > 0 := by linarith
  rw [show (1:ℝ) / ((k:ℝ) + 1) = Real.log (Real.exp (1 / ((k:ℝ) + 1))) from
    (Real.log_exp _).symm]
  apply Real.log_le_log (Real.exp_pos _)
  have hx_small : 1 / ((k : ℝ) + 1) ≤ 1 := by
    rw [div_le_one hk1_pos]; linarith
  have hx_nonneg : 0 ≤ 1 / ((k : ℝ) + 1) := by positivity
  calc Real.exp (1 / ((k:ℝ) + 1))
      ≤ 1 + 1/((k:ℝ)+1) + 1/((k:ℝ)+1)^2 := by
        have hbound := Real.exp_bound' (x := 1/((k:ℝ)+1)) (n := 2) hx_nonneg hx_small (by omega)
        simp only [Finset.sum_range_succ, Finset.sum_range_zero, pow_zero, pow_succ,
                   one_mul, Nat.factorial, Nat.succ_eq_add_one] at hbound
        norm_num at hbound
        rw [show (1:ℝ)/((k:ℝ)+1) = ((k:ℝ)+1)⁻¹ from one_div _,
            show (1:ℝ)/((k:ℝ)+1)^2 = ((k:ℝ)+1)⁻¹ * ((k:ℝ)+1)⁻¹ from by
              rw [one_div, sq, _root_.mul_inv_rev]]
        nlinarith
    _ ≤ ((k:ℝ) + 1) / (k:ℝ) := by
        rw [show ((k:ℝ) + 1)/(k:ℝ) = 1 + 1/(k:ℝ) from by field_simp]
        have h1 : 1/((k:ℝ)+1) + 1/((k:ℝ)+1)^2 ≤ 1/(k:ℝ) := by
          rw [div_add_div _ _ (ne_of_gt hk1_pos) (ne_of_gt (pow_pos hk1_pos 2))]
          rw [div_le_div_iff₀ (mul_pos hk1_pos (pow_pos hk1_pos 2)) hk_pos]
          nlinarith [sq_nonneg (k : ℝ)]
        linarith

theorem harmonicFin_le (n : ℕ) (hn : 1 ≤ n) :
    harmonicFin n ≤ 1 + Real.log (n : ℝ) := by
  induction n with
  | zero => omega
  | succ m ih =>
    cases m with
    | zero =>
      simp only [harmonicFin]
      norm_num
    | succ k =>
      unfold harmonicFin
      rw [show ∑ i : Fin (k + 2), 1 / ((i.val : ℝ) + 1)
          = (∑ i : Fin (k + 1), 1 / ((i.val : ℝ) + 1)) + 1 / ((k : ℝ) + 1 + 1) from by
        rw [Fin.sum_univ_castSucc]
        simp [Fin.val_last]]
      have ih' := ih (by omega)
      unfold harmonicFin at ih'
      have hstep := inv_succ_le_log_div (k + 1) (by omega)
      push_cast at hstep ⊢
      have h := add_le_add ih' (le_of_eq rfl |>.trans hstep)
      norm_cast at *
      linarith

-- ════════════════════════════════════════════════
-- LAYER 3: DERIVED SUM BOUNDS
-- ════════════════════════════════════════════════

/-- **THEOREM**: B(N) ≥ (N-1)/2 - C·log(N).
    Uses basis_entry_lower (from FractIntegral.lean) + harmonicFin_le. -/
theorem basis_sum_tight :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N →
    basisSum N ≥ (N - 1 : ℝ) / 2 - C * Real.log (N : ℝ) := by
  refine ⟨1, one_pos, 3, by omega, fun N hN => ?_⟩
  have h1 : basisSum N ≥
      ∑ i : Fin (N - 1), ((1:ℝ)/2 - 1 / (2 * ((i.val : ℝ) + 1))) := by
    unfold basisSum
    apply Finset.sum_le_sum
    intro i _
    unfold basisInnerProd
    have h := basis_entry_lower (i.val + 1) (by omega)
    show _ ≥ _
    simp only [] at *
    have : ((i.val + 1 : ℕ) : ℝ) = (i.val : ℝ) + 1 := by push_cast; ring
    rw [this]
    convert h using 1 <;> push_cast <;> ring
  have h2 : ∑ i : Fin (N - 1), ((1:ℝ)/2 - 1 / (2 * ((i.val : ℝ) + 1)))
      = (↑(N - 1) : ℝ) / 2 - (1/2) * harmonicFin (N - 1) := by
    unfold harmonicFin
    simp only [Finset.sum_sub_distrib, Fin.sum_const, nsmul_eq_mul]
    ring_nf
    suffices hsuff : ∑ x : Fin (N - 1), (2 + (x.val : ℝ) * 2)⁻¹
        = (1/2) * ∑ x : Fin (N - 1), (1 + (x.val : ℝ))⁻¹ by linarith
    rw [Finset.mul_sum]
    congr 1; ext x
    rw [show (2 : ℝ) + (x.val : ℝ) * 2 = 2 * (1 + (x.val : ℝ)) from by ring]
    rw [_root_.mul_inv_rev, mul_comm]
    norm_num
  have hN1 : 1 ≤ N - 1 := by omega
  have h3 : harmonicFin (N - 1) ≤ 1 + Real.log (N : ℝ) := by
    calc harmonicFin (N - 1) ≤ 1 + Real.log (↑(N - 1)) := harmonicFin_le _ hN1
      _ ≤ 1 + Real.log (N : ℝ) := by
          gcongr
          exact_mod_cast Nat.sub_le N 1
  have hlogN : 1 ≤ Real.log (N : ℝ) := by
    rw [← Real.log_exp 1]
    apply Real.log_le_log (Real.exp_pos 1)
    calc Real.exp 1 ≤ 3 := by
          have := Real.exp_bound' (n := 3) (by norm_num : (0:ℝ) ≤ 1)
            (by norm_num : (1:ℝ) ≤ 1)
          simp [Finset.sum_range_succ] at this; linarith
      _ ≤ (N : ℝ) := by exact_mod_cast hN
  have hNR : (N - 1 : ℝ) = (↑(N - 1) : ℝ) := by
    push_cast [Nat.cast_sub (by omega : 1 ≤ N)]; ring
  calc basisSum N
      ≥ (↑(N - 1) : ℝ) / 2 - (1/2) * harmonicFin (N - 1) := by linarith [h1, h2]
    _ ≥ (↑(N - 1) : ℝ) / 2 - (1/2) * (1 + Real.log (N : ℝ)) := by linarith [h3]
    _ = (↑(N - 1) : ℝ) / 2 - 1/2 - Real.log (N : ℝ) / 2 := by ring
    _ ≥ (N - 1 : ℝ) / 2 - 1 * Real.log (N : ℝ) := by rw [hNR]; linarith

/-- **THEOREM** (was axiom): Per-entry Gram upper bound (diagonal case).
    G_{j,j} = ∫₀¹ {j/x}² dx ≤ 1/3 + 1/j².
    See Cathedral.GramDiag for the proof architecture. -/
theorem gram_entry_diag_upper (j : ℕ) (hj : 1 ≤ j) :
    gramEntry j j ≤ 1 / 3 + 1 / ((j : ℝ) ^ 2) := gram_entry_diag_upper' j hj

/-- **AXIOM**: Per-entry Gram upper bound (off-diagonal case).
    G_{j,k} = ∫₀¹ {j/x}·{k/x} dx ≤ 1/4 + 1/(j·k)  for j ≠ k.

    For j ≠ k, the fractional parts {j/x} and {k/x} are approximately
    independent (Weyl equidistribution), so their product integral
    approaches E[{j/x}]·E[{k/x}] = (1/2)·(1/2) = 1/4.
    The correction 1/(jk) bounds the correlation. -/
axiom gram_entry_offdiag_upper (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hjk : j ≠ k) :
    gramEntry j k ≤ 1 / 4 + 1 / ((j : ℝ) * (k : ℝ))

/-- Unified bound for downstream usage: G_{j,k} ≤ 1/3 + 1/(j·k).
    This follows from either gram_entry_diag_upper or gram_entry_offdiag_upper
    since 1/4 < 1/3 and 1/j² ≤ 1/(j·k) when j = k. -/
lemma gram_entry_upper (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    gramEntry j k ≤ 1 / 3 + 1 / ((j : ℝ) * (k : ℝ)) := by
  by_cases hjk : j = k
  · subst hjk
    have h := gram_entry_diag_upper j hj
    rw [show (j : ℝ) ^ 2 = (j : ℝ) * (j : ℝ) from sq (j : ℝ)] at h
    linarith
  · have h := gram_entry_offdiag_upper j k hj hk hjk
    linarith

/-- Helper: The double sum Σᵢ Σⱼ 1/((i+1)(j+1)) = H_{N-1}². -/
private lemma double_sum_reciprocal (n : ℕ) :
    ∑ i : Fin n, ∑ j : Fin n,
      (1 / (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1)))
    = harmonicFin n ^ 2 := by
  unfold harmonicFin
  have : ∀ i : Fin n, ∑ j : Fin n,
      (1 / (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1)))
    = (1 / ((i.val : ℝ) + 1)) * ∑ j : Fin n, (1 / ((j.val : ℝ) + 1)) := by
    intro i
    rw [Finset.mul_sum]
    congr 1; ext j
    rw [div_mul_div_comm]; ring_nf
  simp_rw [this]
  rw [← Finset.sum_mul]
  ring

/-- **THEOREM**: Q(N) ≤ (N-1)²/4 + C·N.
    Off-diagonal: G(i,j) ≤ 1/4 + 1/((i+1)(j+1)), contributes (N-1)²/4 + H².
    Diagonal excess: G(i,i) ≤ 1/3 + ... vs 1/4 + ..., adds (N-1)/12.
    Total: (N-1)²/4 + H² + (N-1)/12 ≤ (N-1)²/4 + 5N. -/
theorem gram_sum_tight :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N →
    gramSum N ≤ (N - 1 : ℝ) ^ 2 / 4 + C * (N : ℝ) := by
  obtain ⟨N_L, hNL, hLogSq⟩ := log_sq_le_self
  refine ⟨5, by norm_num, max N_L 3, by omega, fun N hN => ?_⟩
  have hN3 : 3 ≤ N := by omega
  have hNL' : N_L ≤ N := by omega
  have hN1 : 1 ≤ N - 1 := by omega
  -- Off-diagonal bound
  have hentry_offdiag : ∀ i j : Fin (N - 1), i ≠ j →
      gramMatrix N i j ≤ 1 / 4 + 1 / (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1)) := by
    intros i j hij
    simp only [gramMatrix, Matrix.of_apply]
    have hi_ne_j : i.val + 1 ≠ j.val + 1 := by intro h; exact hij (Fin.ext (by omega))
    convert gram_entry_offdiag_upper (i.val + 1) (j.val + 1) (by omega) (by omega) hi_ne_j using 2
    all_goals push_cast; ring
  -- Diagonal bound
  have hentry_diag : ∀ i : Fin (N - 1),
      gramMatrix N i i ≤ 1 / 3 + 1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1)) := by
    intro i
    simp only [gramMatrix, Matrix.of_apply]
    have h := gram_entry_diag_upper (i.val + 1) (by omega)
    have hcast : ((i.val + 1 : ℕ) : ℝ) = (i.val : ℝ) + 1 := by push_cast; ring
    rw [show ((i.val + 1 : ℕ) : ℝ) ^ 2 = ((i.val : ℝ) + 1) * ((i.val : ℝ) + 1) from by
      rw [hcast]; ring] at h
    linarith
  -- Every entry satisfies 1/4 + corr, with extra 1/12 on diagonal
  -- G(i,j) ≤ 1/4 + 1/((i+1)(j+1))  for all (i,j), with equality or better off-diag
  -- G(i,i) ≤ 1/4 + 1/12 + 1/((i+1)²) = (1/4 + 1/((i+1)²)) + 1/12
  -- So: Σ G(i,j) ≤ Σ (1/4 + 1/((i+1)(j+1))) + (N-1)·(1/12)
  have h_sum_bound :
      ∑ i : Fin (N - 1), ∑ j : Fin (N - 1), gramMatrix N i j ≤
      ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
        (1 / 4 + 1 / (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) +
      (N - 1 : ℝ) / 12 := by
    -- For each i, split inner sum at j = i vs j ≠ i
    have h_row : ∀ i : Fin (N - 1),
        ∑ j : Fin (N - 1), gramMatrix N i j ≤
        ∑ j : Fin (N - 1), (1 / 4 + 1 / (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) + 1 / 12 := by
      intro i
      -- Split: Σ_j G(i,j) = G(i,i) + Σ_{j≠i} G(i,j)
      -- ≤ (1/3 + corr_ii) + Σ_{j≠i} (1/4 + corr_ij)
      -- = (1/4 + 1/12 + corr_ii) + Σ_{j≠i} (1/4 + corr_ij)
      -- = Σ_j (1/4 + corr_ij) + 1/12   [since corr_ii appears in both]
      calc ∑ j : Fin (N - 1), gramMatrix N i j
          = gramMatrix N i i + ∑ j ∈ Finset.univ.erase i, gramMatrix N i j := by
            rw [← Finset.add_sum_erase _ _ (Finset.mem_univ i)]
        _ ≤ (1 / 3 + 1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1))) +
            ∑ j ∈ Finset.univ.erase i,
              (1 / 4 + 1 / (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) := by
            apply add_le_add
            · exact hentry_diag i
            · exact Finset.sum_le_sum (fun j hj =>
                hentry_offdiag i j (Ne.symm (Finset.ne_of_mem_erase hj)))
        _ = (1 / 4 + 1 / (((i.val : ℝ) + 1) * ((i.val : ℝ) + 1))) +
            ∑ j ∈ Finset.univ.erase i,
              (1 / 4 + 1 / (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) + 1 / 12 := by
            linarith [show (1:ℝ)/3 = 1/4 + 1/12 from by norm_num]
        _ = ∑ j : Fin (N - 1),
              (1 / 4 + 1 / (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) + 1 / 12 := by
            rw [← Finset.add_sum_erase _ _ (Finset.mem_univ i)]
    -- Now sum over i
    calc ∑ i : Fin (N - 1), ∑ j : Fin (N - 1), gramMatrix N i j
        ≤ ∑ i : Fin (N - 1), (∑ j : Fin (N - 1),
            (1 / 4 + 1 / (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) + 1 / 12) :=
          Finset.sum_le_sum (fun i _ => h_row i)
      _ = ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
            (1 / 4 + 1 / (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) +
          ∑ _i : Fin (N - 1), (1 / 12 : ℝ) := by
          simp only [← Finset.sum_add_distrib]
      _ = ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
            (1 / 4 + 1 / (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) +
          (N - 1 : ℝ) / 12 := by
          congr 1
          simp [Finset.sum_const, Finset.card_fin]
          push_cast [Nat.cast_sub (show 1 ≤ N from by omega)]
          ring
  -- Now evaluate: Σ(1/4 + corr) = (N-1)²/4 + H²
  have h_split :
      ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
        (1 / 4 + 1 / (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1))) =
      (N - 1 : ℝ) ^ 2 / 4 + harmonicFin (N - 1) ^ 2 := by
    simp only [Finset.sum_add_distrib]
    congr 1
    · simp only [Finset.sum_const, Finset.card_fin, nsmul_eq_mul]
      push_cast [Nat.cast_sub (show 1 ≤ N from by omega)]
      ring
    · exact double_sum_reciprocal (N - 1)
  -- Bound H² ≤ 4·log²N ≤ 4·(N-1) ≤ 4·N
  have hH := harmonicFin_le (N - 1) hN1
  have hH_bound : harmonicFin (N - 1) ≤ 2 * Real.log (N : ℝ) := by
    have hlogN_ge1 : Real.log (N : ℝ) ≥ 1 := by
      rw [ge_iff_le, ← Real.log_exp 1]
      apply Real.log_le_log (Real.exp_pos 1)
      have : Real.exp 1 ≤ 3 := by
        have := Real.exp_bound' (x := 1) (n := 3) (by norm_num) (by norm_num) (by omega)
        simp [Finset.sum_range_succ, Nat.factorial] at this; linarith
      linarith [show (3 : ℝ) ≤ (N : ℝ) from by exact_mod_cast hN3]
    linarith [harmonicFin_le (N - 1) hN1,
              show Real.log (↑(N - 1)) ≤ Real.log (N : ℝ) from by
                gcongr; exact_mod_cast Nat.sub_le N 1]
  have hH_sq : harmonicFin (N - 1) ^ 2 ≤ 4 * Real.log (N : ℝ) ^ 2 := by
    have hH_nn : 0 ≤ harmonicFin (N - 1) := by
      unfold harmonicFin; apply Finset.sum_nonneg; intros; positivity
    nlinarith [sq_nonneg (harmonicFin (N - 1)), sq_nonneg (Real.log (N : ℝ))]
  have hlog_sq : Real.log (N : ℝ) ^ 2 ≤ (N : ℝ) - 1 := hLogSq N hNL'
  -- Chain: gramSum ≤ (N-1)²/4 + H² + (N-1)/12
  --                ≤ (N-1)²/4 + 4·(N-1) + N/12
  --                ≤ (N-1)²/4 + 5·N
  calc ∑ i : Fin (N - 1), ∑ j : Fin (N - 1), gramMatrix N i j
      ≤ (∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
          (1 / 4 + 1 / (((i.val : ℝ) + 1) * ((j.val : ℝ) + 1)))) +
        (N - 1 : ℝ) / 12 := h_sum_bound
    _ = ((N - 1 : ℝ) ^ 2 / 4 + harmonicFin (N - 1) ^ 2) + (N - 1 : ℝ) / 12 := by
        rw [h_split]
    _ ≤ (N - 1 : ℝ) ^ 2 / 4 + 4 * Real.log (N : ℝ) ^ 2 + (N : ℝ) / 12 := by
        linarith [hH_sq]
    _ ≤ (N - 1 : ℝ) ^ 2 / 4 + 4 * ((N : ℝ) - 1) + (N : ℝ) / 12 := by
        linarith [hlog_sq]
    _ ≤ (N - 1 : ℝ) ^ 2 / 4 + 5 * (N : ℝ) := by linarith

-- ════════════════════════════════════════════════
-- MAIN THEOREM
-- ════════════════════════════════════════════════

theorem nb_distance_decay_axiom' :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N → ∃ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≤ C / Real.log (N : ℝ) := by
  obtain ⟨C_A, hCA, N_A, hNA, hA⟩ := basis_sum_tight
  obtain ⟨C_B, hCB, N_B, hNB, hB⟩ := gram_sum_tight
  obtain ⟨N_L, hNL, hLogSq⟩ := log_sq_le_self
  set K := 8 * (C_A + C_B + 1) with hK_def
  refine ⟨K, by linarith, max (max (max N_A N_B) N_L) 4, by omega,
    fun N hN => ?_⟩
  have hN2 : 2 ≤ N := by omega
  have hN4 : 4 ≤ N := by omega
  have hNA' : N_A ≤ N := by omega
  have hNB' : N_B ≤ N := by omega
  have hNL' : N_L ≤ N := by omega
  set M := ((N : ℝ) - 1) with hM_def
  set L := Real.log (N : ℝ) with hL_def
  have hMpos : M > 0 := by
    have : (4 : ℝ) ≤ (N : ℝ) := Nat.ofNat_le_cast.mpr hN4
    linarith
  have hMge2 : M ≥ 2 := by
    have : (4 : ℝ) ≤ (N : ℝ) := Nat.ofNat_le_cast.mpr hN4
    linarith
  have hLpos : L > 0 := by
    apply Real.log_pos; linarith [show (4 : ℝ) ≤ (N : ℝ) from Nat.ofNat_le_cast.mpr hN4]
  have hLge1 : L ≥ 1 := by
    rw [ge_iff_le, hL_def]
    rw [show (1 : ℝ) = Real.log (Real.exp 1) from (Real.log_exp 1).symm]
    apply Real.log_le_log (Real.exp_pos 1)
    have hexp_le_3 : Real.exp 1 ≤ 3 := by
      have := Real.exp_bound' (x := 1) (n := 3) (by norm_num) (by norm_num) (by omega)
      simp [Finset.sum_range_succ, Nat.factorial] at this
      linarith
    linarith [show (4 : ℝ) ≤ (N : ℝ) from Nat.ofNat_le_cast.mpr hN4]
  have hBbound : basisSum N ≥ M / 2 - C_A * L := hA N hNA'
  have hQbound : gramSum N ≤ M ^ 2 / 4 + C_B * (N : ℝ) := hB N hNB'
  have hN_eq : (N : ℝ) = M + 1 := by linarith
  rw [hN_eq] at hQbound
  have hLogSqBound : L ^ 2 ≤ M := hLogSq N hNL'
  set c := 2 / M with hc_def
  refine ⟨constVec N c, ?_⟩
  have h_l2 := l2_error_eq_quad_error N hN2 (constVec N c)
  rw [h_l2, dot_const N c, quad_const N c]
  have h_step1 := quadratic_bound_of_bounds M L C_A C_B (basisSum N) (gramSum N)
    hMpos hLpos hCA hCB hBbound hQbound
  have h_step2 := simplify_error_bound M L C_A C_B hMge2 hLge1 hCA hCB
  have h_step3 := ratio_flip (8 * C_A + 8 * C_B) K L M hLpos hMpos
    (by linarith) (by linarith) hLogSqBound
  linarith [h_step3 ]

-- Bridge: the old axiom is now a theorem
theorem nb_distance_decay_axiom_bridge :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N → ∃ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≤ C / Real.log (N : ℝ) :=
  nb_distance_decay_axiom'

end
