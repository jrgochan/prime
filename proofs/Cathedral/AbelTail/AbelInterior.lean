/-
  Cathedral/AbelTail/AbelInterior.lean

  ## Shared Interior Bound Machinery for Abel Decay Proofs

  Extracts the common core of finite_abel_s1_diff, finite_abel_s2_diff,
  and finite_abel_s3_diff into reusable lemmas.

  ### Key lemmas:
  - rpow_34_div_sq: k^{3/4}/k² = k^{-5/4}
  - rpow_34_div_eq: M^{3/4}/M = M^{-1/4}
  - rpow_cancel_34: N^{3/4}·N^{-3/4} = 1
  - interior_bound_weighted: generic interior bound with weight function

  These appear identically in S₁, S₂, S₃ proofs.
-/

import Cathedral.AbelTail.RectangleBound

noncomputable section
open Real Finset BigOperators

-- ════════════════════════════════════════════════
-- §1. RPOW CONVERSION LEMMAS
-- ════════════════════════════════════════════════

/-- **PROVED**: k^{3/4} / k² = k^{-5/4} for k > 0. -/
lemma rpow_34_div_sq (k : ℕ) (hk : 1 ≤ k) :
    (k : ℝ) ^ ((3:ℝ)/4) / (k : ℝ) ^ 2 = (k : ℝ) ^ (-(5:ℝ)/4) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  rw [show (k : ℝ) ^ 2 = (k : ℝ) ^ (2:ℝ) from by rw [← Real.rpow_natCast]; norm_num]
  rw [div_eq_mul_inv, ← Real.rpow_neg (le_of_lt hk_pos)]
  rw [← Real.rpow_add hk_pos]
  norm_num

/-- **PROVED**: M^{3/4} / M = M^{-1/4} for M > 0. -/
lemma rpow_34_div_eq (M : ℕ) (hM : 1 ≤ M) :
    (M : ℝ) ^ ((3:ℝ)/4) / (M : ℝ) = (M : ℝ) ^ (-(1:ℝ)/4) := by
  have hM_pos : (0 : ℝ) < (M : ℝ) := Nat.cast_pos.mpr (by omega)
  have : (M : ℝ) ^ ((3:ℝ)/4) / (M : ℝ) ^ (1:ℝ) = (M : ℝ) ^ ((3:ℝ)/4 - 1) :=
    (Real.rpow_sub hM_pos _ _).symm ▸ rfl
  rw [Real.rpow_one] at this; rw [this]; congr 1; ring

/-- **PROVED**: N^{3/4} · N^{-3/4} = 1 for N > 0. -/
lemma rpow_cancel_34 (N : ℕ) (hN : 1 ≤ N) :
    (N : ℝ) ^ ((3:ℝ)/4) * (N : ℝ) ^ (-(3:ℝ)/4) = 1 := by
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  rw [← Real.rpow_add hN_pos, show (3:ℝ)/4 + -(3:ℝ)/4 = 0 from by ring]
  exact Real.rpow_zero _

-- ════════════════════════════════════════════════
-- §2. GENERIC INTERIOR BOUND
-- ════════════════════════════════════════════════

/-- **Weighted interior bound (cleaner constants).**
    Given nonneg weight w(k) with Σ k^{-5/4}·w(k) ≤ tail_bound,
    bounds the Abel interior sum:
      Σ_{Ico} C_m·(k^{3/4}+N^{3/4})·w(k)/k² ≤ 2·C_m·tail_bound

    The constant 2 is clean because we decompose w/k² = w·k^{-5/4}·k^{-3/4}
    and use k^{-3/4} ≤ N^{-3/4} for the second piece. -/
theorem interior_bound_weighted
    (N M : ℕ) (hN : 1 ≤ N) (hNM : N + 1 ≤ M)
    (C_m : ℝ) (hC : 0 < C_m)
    (w : ℕ → ℝ) (hw : ∀ k, k ∈ Icc (N+1) M → 0 ≤ w k)
    (tail_bound : ℝ) (htail : 0 ≤ tail_bound)
    (h_tail : (Icc (N+1) M).sum (fun k => (k : ℝ) ^ (-(5:ℝ)/4) * w k) ≤ tail_bound) :
    (Ico (N+1) M).sum (fun k =>
      C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) *
      (w k / (k : ℝ) ^ 2)) ≤
    2 * C_m * tail_bound := by
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  -- Step 1: Ico ⊆ Icc (terms nonneg)
  have h_subset : (Ico (N+1) M).sum (fun k =>
      C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) *
      (w k / (k : ℝ) ^ 2)) ≤
    (Icc (N+1) M).sum (fun k =>
      C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) *
      (w k / (k : ℝ) ^ 2)) := by
    apply Finset.sum_le_sum_of_subset_of_nonneg Finset.Ico_subset_Icc_self
    intro k hk _
    apply mul_nonneg
    · apply mul_nonneg (by linarith)
      exact add_nonneg (by positivity) (by positivity)
    · exact div_nonneg (hw k hk) (by positivity)
  -- Step 2: Split into two sums
  have h_split : (Icc (N+1) M).sum (fun k =>
      C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) *
      (w k / (k : ℝ) ^ 2)) =
    (Icc (N+1) M).sum (fun k =>
      C_m * (k : ℝ) ^ ((3:ℝ)/4) * (w k / (k : ℝ) ^ 2)) +
    (Icc (N+1) M).sum (fun k =>
      C_m * (N : ℝ) ^ ((3:ℝ)/4) * (w k / (k : ℝ) ^ 2)) := by
    rw [← Finset.sum_add_distrib]
    apply Finset.sum_congr rfl; intro k _; ring
  -- Step 3: First sum — k^{3/4}·w/k² ≤ k^{-5/4}·w → ≤ C_m·tail_bound
  have h_first : (Icc (N+1) M).sum (fun k =>
      C_m * (k : ℝ) ^ ((3:ℝ)/4) * (w k / (k : ℝ) ^ 2)) ≤
    C_m * tail_bound := by
    calc (Icc (N+1) M).sum (fun k =>
            C_m * (k : ℝ) ^ ((3:ℝ)/4) * (w k / (k : ℝ) ^ 2))
        = (Icc (N+1) M).sum (fun k =>
            C_m * ((k : ℝ) ^ ((3:ℝ)/4) * (w k / (k : ℝ) ^ 2))) := by
          apply Finset.sum_congr rfl; intro k _; ring
      _ ≤ (Icc (N+1) M).sum (fun k =>
            C_m * ((k : ℝ) ^ (-(5:ℝ)/4) * w k)) := by
          apply Finset.sum_le_sum; intro k hk
          rw [Finset.mem_Icc] at hk
          have : (k : ℝ) ^ ((3:ℝ)/4) * (w k / (k : ℝ) ^ 2) =
              ((k : ℝ) ^ ((3:ℝ)/4) / (k : ℝ) ^ 2) * w k := by ring
          rw [show C_m * ((k : ℝ) ^ ((3:ℝ)/4) * (w k / (k : ℝ) ^ 2)) =
              C_m * (((k : ℝ) ^ ((3:ℝ)/4) / (k : ℝ) ^ 2) * w k) from by ring]
          rw [rpow_34_div_sq k (by omega)]
      _ = C_m * (Icc (N+1) M).sum (fun k =>
            (k : ℝ) ^ (-(5:ℝ)/4) * w k) := by
          rw [← Finset.mul_sum]
      _ ≤ C_m * tail_bound := by
          apply mul_le_mul_of_nonneg_left h_tail (by linarith)
  -- Step 4: Second sum — factor out, use k^{-3/4} ≤ N^{-3/4}
  have h_second : (Icc (N+1) M).sum (fun k =>
      C_m * (N : ℝ) ^ ((3:ℝ)/4) * (w k / (k : ℝ) ^ 2)) ≤
    C_m * tail_bound := by
    -- Rewrite as C_m * N^{3/4} * Σ w/k²
    have h_eq : (Icc (N+1) M).sum (fun k =>
        C_m * (N : ℝ) ^ ((3:ℝ)/4) * (w k / (k : ℝ) ^ 2)) =
      C_m * (N : ℝ) ^ ((3:ℝ)/4) * (Icc (N+1) M).sum (fun k =>
        w k / (k : ℝ) ^ 2) := by
      rw [← Finset.mul_sum]
    rw [h_eq]
    -- Bound: Σ w/k² ≤ N^{-3/4} · Σ k^{-5/4}·w ≤ N^{-3/4} · tail_bound
    have h_wk : (Icc (N+1) M).sum (fun k => w k / (k : ℝ) ^ 2) ≤
        (N : ℝ) ^ (-(3:ℝ)/4) * tail_bound := by
      calc (Icc (N+1) M).sum (fun k => w k / (k : ℝ) ^ 2)
          ≤ (N : ℝ) ^ (-(3:ℝ)/4) *
            (Icc (N+1) M).sum (fun k => (k : ℝ) ^ (-(5:ℝ)/4) * w k) := by
            rw [Finset.mul_sum]
            apply Finset.sum_le_sum; intro k hk
            rw [Finset.mem_Icc] at hk
            have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
            -- w/k² ≤ N^{-3/4} · k^{-5/4} · w
            have hrw : w k / (k : ℝ) ^ 2 =
                (k : ℝ) ^ (-(5:ℝ)/4) * w k * (k : ℝ) ^ (-(3:ℝ)/4) := by
              rw [show (k : ℝ) ^ 2 = (k : ℝ) ^ (2:ℝ) from by
                rw [← Real.rpow_natCast]; norm_num,
                div_eq_mul_inv, ← Real.rpow_neg (le_of_lt hk_pos)]
              have h_exp : (k : ℝ) ^ (-(5:ℝ)/4) * (k : ℝ) ^ (-(3:ℝ)/4) =
                  (k : ℝ) ^ (-(2:ℝ)) := by
                rw [← Real.rpow_add hk_pos]; norm_num
              -- w * k^{-2} = k^{-5/4} * w * k^{-3/4}
              -- since k^{-5/4} * k^{-3/4} = k^{-2}
              calc w k * (k : ℝ) ^ (-(2:ℝ))
                  = ((k : ℝ) ^ (-(5:ℝ)/4) * (k : ℝ) ^ (-(3:ℝ)/4)) * w k := by
                    rw [h_exp]; ring
                _ = (k : ℝ) ^ (-(5:ℝ)/4) * w k * (k : ℝ) ^ (-(3:ℝ)/4) := by ring
            rw [hrw, show (k : ℝ) ^ (-(5:ℝ)/4) * w k * (k : ℝ) ^ (-(3:ℝ)/4) =
                (k : ℝ) ^ (-(3:ℝ)/4) * ((k : ℝ) ^ (-(5:ℝ)/4) * w k) from by ring]
            apply mul_le_mul_of_nonneg_right _ (by
              apply mul_nonneg (by positivity) (hw k (Finset.mem_Icc.mpr ⟨hk.1, hk.2⟩)))
            exact Real.rpow_le_rpow_of_nonpos hN_pos
              (by exact_mod_cast show N ≤ k by omega) (by norm_num)
        _ ≤ (N : ℝ) ^ (-(3:ℝ)/4) * tail_bound :=
            mul_le_mul_of_nonneg_left h_tail (by positivity)
    -- N^{3/4} · N^{-3/4} = 1
    calc C_m * (N : ℝ) ^ ((3:ℝ)/4) *
          (Icc (N+1) M).sum (fun k => w k / (k : ℝ) ^ 2)
        ≤ C_m * (N : ℝ) ^ ((3:ℝ)/4) * ((N : ℝ) ^ (-(3:ℝ)/4) * tail_bound) :=
          mul_le_mul_of_nonneg_left h_wk (by positivity)
      _ = C_m * ((N : ℝ) ^ ((3:ℝ)/4) * (N : ℝ) ^ (-(3:ℝ)/4)) * tail_bound := by ring
      _ = C_m * 1 * tail_bound := by rw [rpow_cancel_34 N hN]
      _ = C_m * tail_bound := by ring
  -- Combine
  linarith [h_split]

end
