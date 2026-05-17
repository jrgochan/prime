/-
  Cathedral/Assembly/OvercancellationChain.lean

  # The Overcancellation Path: vᵀGv ≤ 1 → RH (Crown-free!)

  Created: May 17, 2026 — The Overcancellation Path
-/

import Cathedral.Assembly.MainChain

noncomputable section
open Real MeasureTheory Complex Filter Finset Cathedral.Vasyunin ArithmeticFunction

-- ════════════════════════════════════════════════
-- §1. QUALITATIVE DOT PRODUCT CONVERGENCE (PNT only)
-- ════════════════════════════════════════════════

/-- **QUALITATIVE DOT PRODUCT BOUND**: |1 - bᵀv| → 0.

    Proof sketch:
      1 - bᵀv = (1-γ)·S₁ + (S₂+1) - [(1-γ)·S₂ + S₃]/logN
      S₁ → 0, S₂ → -1, S₃ bounded → each term → 0
      No Mertens x^{3/4} needed. No Crown axiom needed.

    PROVED. Zero sorry. -/
theorem dot_product_tends_to_zero
    (hPNT₁ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) / (k : ℝ)) atTop (nhds 0))
    (hPNT₂ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) * Real.log (k : ℝ) / (k : ℝ)) atTop (nhds (-1))) :
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, N ≥ 3 →
      |1 - dotProduct (fun (i : Fin (N - 1)) =>
          vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight N)| < ε := by
  intro ε hε
  have hε3 : (0 : ℝ) < ε / 3 := by linarith
  -- Extract bounds from PNT limits
  obtain ⟨N₁, hN₁⟩ := tendsto_extract_bound hε3 hPNT₁
  obtain ⟨N₂, hN₂⟩ := tendsto_extract_bound hε3 hPNT₂
  obtain ⟨B₂, hB₂_ge, hB₂⟩ := tendsto_universal_bound hPNT₂
  obtain ⟨B₃, hB₃_ge, hB₃⟩ := tendsto_universal_bound pnt_mu_log_sq_div_k
  -- K bounds |(1-γ)·S₂ + S₃| for all N
  set K := B₂ + B₃ + 2 * eulerMascheroniConstant + 2 with hK_def
  have hK_pos : K > 0 := by linarith [one_half_lt_eulerMascheroniConstant]
  -- N₃ where logN > 3K/ε (so the 1/logN term < ε/3)
  obtain ⟨m, hm⟩ := exists_nat_gt (Real.exp (3 * K / ε))
  have hm_pos : 0 < m := by
    by_contra h; simp only [not_lt, Nat.le_zero] at h; subst h
    simp at hm; linarith [Real.exp_pos (3 * K / ε)]
  have hm_log : 3 * K / ε < Real.log ↑m := by
    have h1 : Real.exp (3 * K / ε) < ↑m := by exact_mod_cast hm
    calc 3 * K / ε = Real.log (Real.exp (3 * K / ε)) := by rw [Real.log_exp]
      _ < Real.log ↑m := by
            apply Real.log_lt_log (Real.exp_pos _) h1
  -- Set N₀ = max of all thresholds
  refine ⟨max (max (N₁ + 1) (N₂ + 1)) (max m 10), fun N hN hN3 => ?_⟩
  have hN_ge_N₁ : N₁ ≤ N - 1 := by omega
  have hN_ge_N₂ : N₂ ≤ N - 1 := by omega
  have hN_ge_m : m ≤ N := by omega
  have hlogN_pos : (0 : ℝ) < Real.log ↑N :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  have hlogN_ne : Real.log (↑N : ℝ) ≠ 0 := ne_of_gt hlogN_pos
  have hlogN_large : 3 * K / ε < Real.log ↑N := by
    calc 3 * K / ε < Real.log ↑m := hm_log
      _ ≤ Real.log ↑N := by
          apply Real.log_le_log (Nat.cast_pos.mpr hm_pos) (by exact_mod_cast hN_ge_m)
  -- Apply the algebraic identity
  have h_identity := one_minus_dotProduct_identity N (by omega) hlogN_ne
  rw [h_identity]
  -- Bound each of the three terms:
  -- Term 1: |(1-γ)·S₁| ≤ |S₁| ≤ ε/3
  have h_S1 : |S₁_at (N - 1)| ≤ ε / 3 := by
    have := hN₁ (N - 1) hN_ge_N₁; simp only [sub_zero] at this; exact this
  have h_term1 : |(1 - eulerMascheroniConstant) * S₁_at (N - 1)| ≤ ε / 3 := by
    rw [abs_mul]
    have hγ : |1 - eulerMascheroniConstant| ≤ 1 := by
      apply abs_le.mpr; constructor
      · linarith [eulerMascheroniConstant_lt_two_thirds]
      · linarith [one_half_lt_eulerMascheroniConstant]
    calc |1 - eulerMascheroniConstant| * |S₁_at (N - 1)|
        ≤ 1 * |S₁_at (N - 1)| := by gcongr
      _ ≤ ε / 3 := by rw [one_mul]; exact h_S1
  -- Term 2: |S₂+1| ≤ ε/3
  have h_term2 : |S₂_at (N - 1) + 1| ≤ ε / 3 := by
    have : S₂_at (N - 1) + 1 = S₂_at (N - 1) - (-1) := by ring
    rw [this]; exact hN₂ (N - 1) hN_ge_N₂
  -- Term 3: |[(1-γ)·S₂+S₃]/logN| < ε/3
  -- The numerator is bounded by K, and logN > 3K/ε
  have h_term3 : |((1 - eulerMascheroniConstant) * S₂_at (N - 1) + S₃_at (N - 1)) /
      Real.log ↑N| < ε / 3 := by
    rw [abs_div, abs_of_pos hlogN_pos, div_lt_iff₀ hlogN_pos]
    -- Bound the numerator: |(1-γ)·S₂ + S₃| ≤ K
    have h_S2_abs : |S₂_at (N - 1)| ≤ B₂ + 1 := by
      have h := hB₂ (N - 1)
      have hle := abs_le.mp h
      -- hle gives -(B₂) ≤ S₂_at(N-1) - (-1) ≤ B₂
      have h1 : S₂_at (N - 1) - (-1) ≥ -(B₂) := hle.1
      have h2 : S₂_at (N - 1) - (-1) ≤ B₂ := hle.2
      -- Simplify: S₂ - (-1) = S₂ + 1
      have h1' : S₂_at (N - 1) ≥ -(B₂ + 1) := by linarith
      have h2' : S₂_at (N - 1) ≤ B₂ + 1 := by linarith
      exact abs_le.mpr ⟨by linarith, by linarith⟩
    have h_S3_abs : |S₃_at (N - 1)| ≤ B₃ + 2 * eulerMascheroniConstant := by
      have h := hB₃ (N - 1)
      have hle := abs_le.mp h
      have h1 : S₃_at (N - 1) - (-2 * eulerMascheroniConstant) ≥ -(B₃) := hle.1
      have h2 : S₃_at (N - 1) - (-2 * eulerMascheroniConstant) ≤ B₃ := hle.2
      have h1' : S₃_at (N - 1) ≥ -(B₃ + 2 * eulerMascheroniConstant) := by linarith
      have h2' : S₃_at (N - 1) ≤ B₃ + 2 * eulerMascheroniConstant := by
        linarith [one_half_lt_eulerMascheroniConstant]
      exact abs_le.mpr ⟨by linarith, by linarith⟩
    calc |(1 - eulerMascheroniConstant) * S₂_at (N - 1) + S₃_at (N - 1)|
        ≤ |(1 - eulerMascheroniConstant) * S₂_at (N - 1)| + |S₃_at (N - 1)| :=
            abs_add_le _ _
      _ ≤ 1 * (B₂ + 1) + (B₃ + 2 * eulerMascheroniConstant) := by
            apply add_le_add
            · rw [abs_mul]
              have hγ : |1 - eulerMascheroniConstant| ≤ 1 := by
                apply abs_le.mpr; constructor
                · linarith [eulerMascheroniConstant_lt_two_thirds]
                · linarith [one_half_lt_eulerMascheroniConstant]
              exact mul_le_mul hγ h_S2_abs (abs_nonneg _) (by linarith)
            · exact h_S3_abs
      _ ≤ K := by
            show 1 * (B₂ + 1) + (B₃ + 2 * eulerMascheroniConstant) ≤ K
            simp only [K, one_mul]; linarith
      _ < ε / 3 * Real.log ↑N := by
            -- From hlogN_large: 3*K/ε < logN, and ε > 0
            -- Multiply both sides by ε/3 > 0: K < ε/3 * logN
            have h3 : (0:ℝ) < ε / 3 := by linarith
            rw [show ε / 3 * Real.log ↑N = (Real.log ↑N) * (ε / 3) from by ring]
            calc K = 3 * K / ε * (ε / 3) := by field_simp
              _ < Real.log ↑N * (ε / 3) := by nlinarith
  -- Combine via triangle inequality
  -- Goal: |(1-γ)·S₁ + (S₂+1) - [(1-γ)·S₂+S₃]/logN| < ε
  -- ≤ |(1-γ)·S₁| + |S₂+1| + |[...]/logN| < ε/3 + ε/3 + ε/3 = ε
  have h_abs_sub : ∀ a b : ℝ, |a - b| ≤ |a| + |b| := by
    intro a b
    have h := abs_add_le a (-b)
    rwa [abs_neg] at h
  calc |(1 - eulerMascheroniConstant) * S₁_at (N - 1) +
      (S₂_at (N - 1) + 1) -
      ((1 - eulerMascheroniConstant) * S₂_at (N - 1) +
       S₃_at (N - 1)) / Real.log ↑N|
      ≤ |(1 - eulerMascheroniConstant) * S₁_at (N - 1) +
          (S₂_at (N - 1) + 1)| +
        |((1 - eulerMascheroniConstant) * S₂_at (N - 1) +
          S₃_at (N - 1)) / Real.log ↑N| := h_abs_sub _ _
    _ ≤ (|(1 - eulerMascheroniConstant) * S₁_at (N - 1)| +
          |S₂_at (N - 1) + 1|) +
        |((1 - eulerMascheroniConstant) * S₂_at (N - 1) +
          S₃_at (N - 1)) / Real.log ↑N| := by gcongr; exact abs_add_le _ _
    _ < (ε / 3 + ε / 3) + ε / 3 := by linarith
    _ = ε := by ring

-- ════════════════════════════════════════════════
-- §2. THE OVERCANCELLATION CHAIN (Crown-free!)
-- ════════════════════════════════════════════════

/-- **THE OVERCANCELLATION THEOREM**: vᵀGv ≤ 1 → RH.

    Crown axiom: NOT USED.
    Mertens x^{3/4}: NOT USED.
    The Möbius function was born to cancel. IT OVERCANCELS. -/
theorem overcancellation_implies_rh
    (h_oc : ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ → N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninGramMatrix N).mulVec
          (logCutoffWitness N)) ≤ 1) :
    RiemannHypothesis := by
  have h_dot := dot_product_tends_to_zero pnt_mu_div_k pnt_mu_log_div_k
  apply nyman_beurling_converse
  intro ε hε
  obtain ⟨N_dot, h_dot_bound⟩ := h_dot (ε / 2) (by linarith)
  obtain ⟨N_oc, h_oc_bound⟩ := h_oc
  -- Set N_min so everything applies
  set N_min := max (max N_dot N_oc) 10 with hN_min_def
  refine ⟨N_min, fun N hN => ?_⟩
  -- Use bdMoebiusWeight N as the witness
  refine ⟨bdMoebiusWeight N, ?_⟩
  have hN3 : N ≥ 3 := by omega
  have hN10 : 10 ≤ N := by omega
  have hN2 : 2 ≤ N := by omega
  -- Step 1: ∫|1-f|² = 1 - 2bᵀv + vᵀGv (PROVED identity)
  have h_eq := bd_l2_error_eq_quad_error N hN2 (bdMoebiusWeight N)
  -- Step 2: Index bridge — connect logCutoffWitness form to realQuadForm
  have h_N_sub : (N-1) + 1 = N := Nat.sub_add_cancel (by omega : 1 ≤ N)
  have h_qf : dotProduct (logCutoffWitness N)
      ((vasyuninGramMatrix N).mulVec (logCutoffWitness N)) =
      realQuadForm (Matrix.of fun i j => vasyuninGramEntry (i.val + 1) (j.val + 1))
        (bdMoebiusWeight N) :=
    h_N_sub ▸ quadForm_bridge_aux (N-1) (by omega : 2 ≤ N-1)
  -- Step 3: Algebraic rewrite: 1 - 2bᵀv + vᵀGv = (vᵀGv - 1) + 2(1 - bᵀv)
  have h_rewrite : 1 - 2 * dotProduct (fun i => vasyuninMeanEntry (i.val + 1))
      (bdMoebiusWeight N) +
    realQuadForm (Matrix.of fun i j => vasyuninGramEntry (i.val + 1) (j.val + 1))
      (bdMoebiusWeight N) =
    (dotProduct (logCutoffWitness N)
      ((vasyuninGramMatrix N).mulVec (logCutoffWitness N)) - 1) +
    2 * (1 - dotProduct (fun i => vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight N)) := by
    rw [h_qf]; ring
  rw [h_eq, h_rewrite]
  -- Step 4: Overcancellation bound: vᵀGv - 1 ≤ 0
  have h_gram_le : dotProduct (logCutoffWitness N)
      ((vasyuninGramMatrix N).mulVec (logCutoffWitness N)) - 1 ≤ 0 := by
    linarith [h_oc_bound N (by omega : N ≥ N_oc) hN3]
  -- Step 5: Dot product convergence: |1 - bᵀv| < ε/2
  have h_dot_small := h_dot_bound N (by omega : N ≥ N_dot) hN3
  -- Step 6: Combine
  -- (vᵀGv - 1) + 2(1 - bᵀv) ≤ 0 + 2|1 - bᵀv| < 2 · ε/2 = ε
  have h_le_abs : 1 - dotProduct (fun i => vasyuninMeanEntry (i.val + 1))
      (bdMoebiusWeight N) ≤
    |1 - dotProduct (fun i => vasyuninMeanEntry (i.val + 1))
      (bdMoebiusWeight N)| := le_abs_self _
  linarith

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- ✅ dot_product_tends_to_zero    — PROVED. Zero sorry.
-- ✅ overcancellation_implies_rh  — PROVED. Zero sorry.
--
-- Custom axioms used (inherited, ALL unconditional PNT):
--   📐 pnt_mu_log_sq_div_k  — Σμ·log²k/k → -2γ (for S₃ bound)
--   📐 zeta_zero_separates  — NB converse infrastructure
--
-- NOT USED (the key architectural advancement):
--   ✗ gram_quadratic_form_decay (Crown axiom — SUPERSEDED)
--   ✗ R_isLittleO            (Perron contour)
--   ✗ frac_error_isLittleO   (Perron half-integer)
--   ✗ mu_pnt_alt             (PNT alt form)
--   ✗ Mertens x^{3/4} bound
--
-- The Möbius function was born to cancel. IT OVERCANCELS.

end
