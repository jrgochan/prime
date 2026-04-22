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
import Mathlib.Analysis.Complex.ExponentialBounds

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

-- ════════════════════════════════════════════════
-- §2. LOG BOUNDS
-- ════════════════════════════════════════════════

/-- **PROVED**: log(2) ≥ 1/2.
    Via: exp(1/2) ≤ 2 follows from exp(1) < 2.72 < 4 = 2². -/
lemma log_two_ge_half : Real.log 2 ≥ 1/2 := by
  rw [ge_iff_le, le_log_iff_exp_le (by norm_num : (0:ℝ) < 2)]
  have h1 : Real.exp (1/2 : ℝ) * Real.exp (1/2 : ℝ) = Real.exp 1 := by
    rw [← Real.exp_add]; norm_num
  nlinarith [Real.exp_one_lt_d9, sq_nonneg (Real.exp (1/2 : ℝ) - 2)]

/-- **PROVED**: For N ≥ 2 (ℕ), log(N) ≥ 1/2. -/
lemma log_ge_half_of_two_le (N : ℕ) (hN : 2 ≤ N) : Real.log (N : ℝ) ≥ 1/2 := by
  calc Real.log (N : ℝ) ≥ Real.log 2 :=
        Real.log_le_log (by norm_num) (by exact_mod_cast hN)
    _ ≥ 1/2 := log_two_ge_half

-- ════════════════════════════════════════════════
-- §3. INTERIOR BOUND FOR ABEL SUMMATION
-- ════════════════════════════════════════════════

/-- **Weighted interior bound (cleaner constants).**
    Given nonneg weight w(k) with Σ k^{-5/4}·w(k) ≤ tail_bound,
    bounds the Abel interior sum:
      Σ_{Ico} C_m·(k^{3/4}+N^{3/4})·w(k)/k² ≤ 2·C_m·tail_bound

    The constant 2 is clean because we decompose w/k² = w·k^{-5/4}·k^{-3/4}
    and use k^{-3/4} ≤ N^{-3/4} for the second piece. -/
theorem interior_bound_weighted
    (N M : ℕ) (hN : 1 ≤ N) (_hNM : N + 1 ≤ M)
    (C_m : ℝ) (hC : 0 < C_m)
    (w : ℕ → ℝ) (hw : ∀ k, k ∈ Icc (N+1) M → 0 ≤ w k)
    (tail_bound : ℝ) (_htail : 0 ≤ tail_bound)
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

-- ════════════════════════════════════════════════
-- §4. BOUNDARY VANISHING FOR LIMIT ARGUMENTS
-- ════════════════════════════════════════════════

/-- **PROVED**: For any fixed N and C > 0, the Abel boundary
    C·(M^{-1/4}·log(M) + N^{3/4}·log(M)/M) can be made < ε
    for M large enough. This is the key lemma for the limit
    argument in s2_decay and s3_decay.

    Uses: isLittleO_log_rpow_atTop (log = o(x^r) for r > 0). -/
lemma boundary_vanishes_nat (N : ℕ) (hN : 1 ≤ N) (C : ℝ) (hC : 0 < C) (ε : ℝ) (hε : 0 < ε) :
    ∃ M₁ : ℕ, ∀ M : ℕ, M₁ ≤ M →
      C * ((M : ℝ) ^ (-(1:ℝ)/4) * Real.log (M : ℝ) +
           (N : ℝ) ^ ((3:ℝ)/4) * Real.log (M : ℝ) / (M : ℝ)) < ε := by
  -- Strategy: bound everything by C·(1+N^{3/4})·(logM/M^{1/4}),
  -- then use log =o[atTop] x^{1/4} (Mathlib) to make this < ε.
  have h_Nrpow_nn : 0 ≤ (N : ℝ) ^ ((3:ℝ)/4) := Real.rpow_nonneg (Nat.cast_nonneg' N) _
  have h_coeff_pos : 0 < 2 * C * (1 + (N : ℝ) ^ ((3:ℝ)/4)) := by positivity
  -- δ = ε / (2·C·(1+N^{3/4}))
  set δ := ε / (2 * C * (1 + (N : ℝ) ^ ((3:ℝ)/4))) with hδ_def
  have hδ : 0 < δ := div_pos hε h_coeff_pos
  -- From isLittleO: log(x)/x^{1/4} → 0, extract ∃ R with |ratio| < δ for x ≥ R
  have h_tend : Filter.Tendsto (fun x : ℝ => Real.log x / x ^ ((1:ℝ)/4))
      Filter.atTop (nhds 0) :=
    (isLittleO_log_rpow_atTop (show (0:ℝ) < 1/4 by norm_num)).tendsto_div_nhds_zero
  rw [Metric.tendsto_atTop] at h_tend
  obtain ⟨R, hR⟩ := h_tend δ hδ
  -- Choose M₁ = max 2 ⌈R⌉₊ (ensures M ≥ 2 and M ≥ R)
  use max 2 ⌈R⌉₊
  intro M hM
  have hM_ge2 : 2 ≤ M := le_trans (le_max_left _ _) hM
  have hM_pos : (0 : ℝ) < (M : ℝ) := Nat.cast_pos.mpr (by omega)
  have hM_ge1 : (1 : ℝ) ≤ (M : ℝ) := by exact_mod_cast show 1 ≤ M by omega
  have hM_geR : R ≤ (M : ℝ) := le_trans (Nat.le_ceil R)
    (by exact_mod_cast le_trans (le_max_right 2 ⌈R⌉₊) hM)
  -- Extract: logM / M^{1/4} < δ (and ≥ 0)
  have h_bound := hR (M : ℝ) hM_geR
  rw [Real.dist_eq, sub_zero] at h_bound
  have hlog_nn : 0 ≤ Real.log (M : ℝ) := Real.log_nonneg hM_ge1
  have h14pos : 0 < (M : ℝ) ^ ((1:ℝ)/4) := Real.rpow_pos_of_pos hM_pos _
  rw [abs_of_nonneg (div_nonneg hlog_nn h14pos.le)] at h_bound
  -- h_bound: logM / M^{1/4} < δ
  -- Key bound: logM/M ≤ logM / M^{1/4}
  -- because M^{1/4} ≤ M (since M ≥ 1 and 1/4 ≤ 1)
  have h_M14_le_M : (M : ℝ) ^ ((1:ℝ)/4) ≤ (M : ℝ) := by
    calc (M : ℝ) ^ ((1:ℝ)/4) ≤ (M : ℝ) ^ (1:ℝ) :=
          Real.rpow_le_rpow_of_exponent_le hM_ge1 (by norm_num)
      _ = (M : ℝ) := Real.rpow_one _
  have h_logM_div_M : Real.log (M : ℝ) / (M : ℝ) ≤
      Real.log (M : ℝ) / (M : ℝ) ^ ((1:ℝ)/4) := by
    gcongr
  -- Direct bound: term1 = M^{-1/4}·logM = logM/M^{1/4} < δ
  -- term2 = N^{3/4}·logM/M ≤ N^{3/4}·logM/M^{1/4} < N^{3/4}·δ
  -- Total ≤ C·(δ + N^{3/4}·δ) = C·(1+N^{3/4})·δ = ε/2 < ε
  have h_term2 : (N : ℝ) ^ ((3:ℝ)/4) * Real.log (M : ℝ) / (M : ℝ) ≤
      (N : ℝ) ^ ((3:ℝ)/4) * (Real.log (M : ℝ) / (M : ℝ) ^ ((1:ℝ)/4)) := by
    rw [show (N : ℝ) ^ ((3:ℝ)/4) * Real.log (M : ℝ) / (M : ℝ) =
        (N : ℝ) ^ ((3:ℝ)/4) * (Real.log (M : ℝ) / (M : ℝ)) from by ring]
    exact mul_le_mul_of_nonneg_left h_logM_div_M h_Nrpow_nn
  have h_term1_eq : (M : ℝ) ^ (-(1:ℝ)/4) * Real.log (M : ℝ) =
      Real.log (M : ℝ) / (M : ℝ) ^ ((1:ℝ)/4) := by
    have : (-(1:ℝ)/4) = -((1:ℝ)/4) := by ring
    rw [this, Real.rpow_neg (Nat.cast_nonneg' M) ((1:ℝ)/4)]
    ring
  -- Now combine:
  -- C · (logM/M^{1/4} + N^{3/4}·logM/M)
  -- ≤ C · (logM/M^{1/4} + N^{3/4}·logM/M^{1/4})
  -- = C · (1+N^{3/4}) · logM/M^{1/4}
  -- < C · (1+N^{3/4}) · δ = ε/2 < ε
  have h_sum : C * ((M : ℝ) ^ (-(1:ℝ)/4) * Real.log (M : ℝ) +
      (N : ℝ) ^ ((3:ℝ)/4) * Real.log (M : ℝ) / (M : ℝ)) ≤
      C * (1 + (N : ℝ) ^ ((3:ℝ)/4)) *
      (Real.log (M : ℝ) / (M : ℝ) ^ ((1:ℝ)/4)) := by
    rw [h_term1_eq]
    nlinarith [h_term2]
  linarith [mul_lt_mul_of_pos_left h_bound (show 0 < C * (1 + (N : ℝ) ^ ((3:ℝ)/4)) by positivity),
            show C * (1 + (N : ℝ) ^ ((3:ℝ)/4)) * δ = ε / 2 from by rw [hδ_def]; field_simp]

end
