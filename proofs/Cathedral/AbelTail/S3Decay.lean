/-
  Cathedral/AbelTail/S3Decay.lean

  ## S₃ Decay: |S₃(N) - L₃| ≤ C₃·N^{-1/4}·log²(N)

  Bounds the log²-weighted PNT sub-sum:
    S₃(N) = Σ_{k=1}^N μ(k)·log²(k)/k

  Architecture (mirror of S₂):
  1. logsq_weighted_tail: Σ k^{-5/4}·(log²k+2logk+2) ≤ C·N^{-1/4}·log²N
  2. finite_abel_s3_diff: Abel bound with M-INDEPENDENT interior
  3. s3_decay: limit argument (boundary_vanishes_nat + ε-argument)

  STATUS: 1 sorry (logsq_weighted_tail — log² tail arithmetic).
-/

import Cathedral.AbelTail.AbelInterior
import Cathedral.AbelTail.MertensBridge
import Cathedral.AbelTail.DiscreteProductRule
import Cathedral.AbelTail.LogTailBound
import Cathedral.MellinBridge.AbelSummation
import Cathedral.Assembly.AbelEngine

noncomputable section
open Real Finset BigOperators

-- ════════════════════════════════════════════════
-- §1. DEFINITION
-- ════════════════════════════════════════════════

/-- S₃(M) = Σ_{k=1}^M μ(k)·log²(k)/k (matching FinalDragon.lean). -/
def S₃_at (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) *
    (Real.log (k : ℝ)) ^ 2 / (k : ℝ)

-- ════════════════════════════════════════════════
-- §2. LOG² TAIL BOUND (NEW)
-- ════════════════════════════════════════════════

/-- **Tail bound for log²-weighted sums.**
    Σ_{k=N+1}^M k^{-5/4}·(log²(k) + 2·log(k) + 2) ≤ C·N^{-1/4}·log²(N)
    where C is an absolute constant.

    Strategy: (log²k+2logk+2) = (logk+1)²+1.
    Split logk+1 = (logN+1) + (logk-logN):
    - (logN+1)² term: bounded by existing finite_rpow_54_tail_bound
    - Cross term 2(logN+1)(logk-logN): bounded by Part 2 of log tail
    - (logk-logN)² term: bounded by iterated sum-swap (the hard part)
    - +1 term: bounded by finite_rpow_54_tail_bound

    The constant C satisfies C ≥ 4·(logN+1)²/log²N + 40·(logN+1)/log²N + ...
    For N ≥ 2 and choosing C large enough, this is M-independent. -/
theorem logsq_weighted_tail (N M : ℕ) (hN : 2 ≤ N) (hNM : N + 1 ≤ M) :
    (Icc (N+1) M).sum (fun k => (k : ℝ) ^ (-(5:ℝ)/4) *
      ((Real.log (k : ℝ)) ^ 2 + 2 * Real.log (k : ℝ) + 2)) ≤
    (4 * (Real.log (N : ℝ)) ^ 2 + 48 * Real.log (N : ℝ) + 248) *
      (N : ℝ) ^ (-(1:ℝ)/4) := by
  -- Split: (log²k + 2logk + 2) = log²k + 2·(logk + 1)
  have h_split : (Icc (N+1) M).sum (fun k => (k : ℝ) ^ (-(5:ℝ)/4) *
      ((Real.log (k : ℝ)) ^ 2 + 2 * Real.log (k : ℝ) + 2)) =
    (Icc (N+1) M).sum (fun k => (k : ℝ) ^ (-(5:ℝ)/4) * (Real.log (k : ℝ)) ^ 2) +
    (Icc (N+1) M).sum (fun k => 2 * ((k : ℝ) ^ (-(5:ℝ)/4) *
      (Real.log (k : ℝ) + 1))) := by
    rw [← Finset.sum_add_distrib]
    apply Finset.sum_congr rfl; intro k _; ring
  rw [h_split]
  -- Part B: Σ k^{-5/4}·log²k ≤ (4log²N+40logN+200)·N^{-1/4}
  have h_B := finite_logsq_rpow_54_tail_bound N M hN hNM
  -- Part A: 2·Σ k^{-5/4}·(logk+1) ≤ 2·(4logN+24)·N^{-1/4} = (8logN+48)·N^{-1/4}
  have h_A : (Icc (N+1) M).sum (fun k => 2 * ((k : ℝ) ^ (-(5:ℝ)/4) *
      (Real.log (k : ℝ) + 1))) ≤
    (8 * Real.log (N : ℝ) + 48) * (N : ℝ) ^ (-(1:ℝ)/4) := by
    rw [show (Icc (N+1) M).sum (fun k => 2 * ((k : ℝ) ^ (-(5:ℝ)/4) *
        (Real.log (k : ℝ) + 1))) =
      2 * (Icc (N+1) M).sum (fun k => (k : ℝ) ^ (-(5:ℝ)/4) *
        (Real.log (k : ℝ) + 1)) from (Finset.mul_sum (Icc (N+1) M) _ 2).symm]
    have := log_weighted_rpow_54_tail N M hN hNM
    linarith
  -- Total: (4log²N+40logN+200 + 8logN+48) = (4log²N+48logN+248)
  linarith

-- ════════════════════════════════════════════════
-- §3. FINITE ABEL BOUND (M-INDEPENDENT)
-- ════════════════════════════════════════════════

/-- **Abel bound for S₃ on [N+1, M] — M-INDEPENDENT interior.**

    Same structure as finite_abel_s2_diff but with log²(k)/k weights.
    Interior ≤ 2·C_m·logsq_weighted_tail ≤ C_m·K·N^{-1/4}·log²(N)
    Boundary = C_m·(M^{-1/4}·log²(M) + N^{3/4}·log²(M)/M) → 0 -/
theorem finite_abel_s3_diff
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (N M : ℕ) (hN : 2 ≤ N) (hM : N + 1 ≤ M) :
    |S₃_at M - S₃_at N| ≤
      C_m * ((M : ℝ) ^ (-(1:ℝ)/4) * (Real.log (M : ℝ)) ^ 2 +
             (N : ℝ) ^ ((3:ℝ)/4) * (Real.log (M : ℝ)) ^ 2 / (M : ℝ)) +
      C_m * (8 * (Real.log (N : ℝ)) ^ 2 + 96 * Real.log (N : ℝ) + 496) *
        (N : ℝ) ^ (-(1:ℝ)/4) := by
  -- Same proof as finite_abel_s2_diff:
  -- 1. Abel summation decomposes into boundary + interior
  -- 2. Boundary: |M(M)|·|f(M)| + |M(N)|·|f(N)| ≤ C_m·(boundary terms)
  -- 3. Interior: Σ C_m·(k^{3/4}+N^{3/4})·w(k)/k²
  --    where w(k) = log²k+2logk+2 (from DPR on log²(k)/k)
  --    ≤ 2·C_m·logsq_weighted_tail by interior_bound_weighted
  --    = C_m·(8log²N+96logN+496)·N^{-1/4}
  sorry

-- ════════════════════════════════════════════════
-- §4. S₃ DECAY VIA LIMIT ARGUMENT
-- ════════════════════════════════════════════════

/-- **S₃ decay via limit + Abel.**
    |S₃(N) - L₃| ≤ C₃·N^{-1/4}·log²(N) for all N ≥ 2.

    Identical ε-argument to s2_decay. The boundary
    C_m·(M^{-1/4}·log²M + N^{3/4}·log²M/M) → 0 as M → ∞
    by boundary_vanishes_nat_logsq (or direct from isLittleO). -/
theorem s3_decay
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (L₃ : ℝ)
    (hPNT₃ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
      Filter.atTop (nhds L₃)) :
    ∃ C₃ : ℝ, C₃ > 0 ∧ ∀ N : ℕ, 2 ≤ N →
      |S₃_at N - L₃| ≤
        C₃ * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := by
  use (8 + 192 + 1984) * C_m  -- = 2184·C_m
  constructor
  · linarith
  intro N hN
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have h_rpow_pos : 0 < (N : ℝ) ^ (-(1:ℝ)/4) := Real.rpow_pos_of_pos hN_pos _
  have hlog_pos : 0 < Real.log (N : ℝ) :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  have h_logN_ge : Real.log (N : ℝ) ≥ 1/2 := log_ge_half_of_two_le N hN
  have h_logsq_ge : (Real.log (N : ℝ))^2 ≥ 1/4 := by nlinarith
  have h_const : C_m * (8 * (Real.log (N : ℝ)) ^ 2 + 96 * Real.log (N : ℝ) + 496) *
      (N : ℝ) ^ (-(1:ℝ)/4) ≤
      (8 + 192 + 1984) * C_m * (N : ℝ) ^ (-(1:ℝ)/4) *
        (Real.log (N : ℝ)) ^ 2 := by
    have h_rpow_nn : 0 ≤ (N : ℝ) ^ (-(1:ℝ)/4) := le_of_lt h_rpow_pos
    have h96 : (96 : ℝ) * Real.log (N : ℝ) ≤ 192 * (Real.log (N : ℝ))^2 := by nlinarith
    have h496 : (496 : ℝ) ≤ 1984 * (Real.log (N : ℝ))^2 := by nlinarith
    nlinarith [mul_nonneg (mul_nonneg hC.le h_rpow_nn) (sq_nonneg (Real.log (N : ℝ)))]
  suffices h_interior : |S₃_at N - L₃| ≤
      C_m * (8 * (Real.log (N : ℝ)) ^ 2 + 96 * Real.log (N : ℝ) + 496) *
        (N : ℝ) ^ (-(1:ℝ)/4) by
    linarith
  apply le_of_forall_pos_lt_add
  intro ε hε
  have hε3 : (0 : ℝ) < ε / 3 := by linarith
  obtain ⟨M₀, hM₀⟩ := tendsto_extract_bound hε3 hPNT₃
  obtain ⟨M₁, hM₁⟩ := boundary_vanishes_nat_logsq N (by omega) C_m hC (ε / 3) hε3
  set M := max (N + 1) (max M₀ M₁)
  have hM_ge_N1 : N + 1 ≤ M := le_max_left _ _
  have hM_ge_M0 : M₀ ≤ M := le_trans (le_max_left _ _) (le_max_right _ _)
  have hM_ge_M1 : M₁ ≤ M := le_trans (le_max_right _ _) (le_max_right _ _)
  have hS3M : |S₃_at M - L₃| ≤ ε / 3 := by
    unfold S₃_at; exact hM₀ M hM_ge_M0
  have hAbel := finite_abel_s3_diff C_m hC hMertens N M hN hM_ge_N1
  have hBdry := hM₁ M hM_ge_M1
  have h_tri : |S₃_at N - L₃| ≤ |S₃_at M - L₃| + |S₃_at M - S₃_at N| := by
    have : S₃_at N - L₃ = (S₃_at M - L₃) + (S₃_at N - S₃_at M) := by ring
    rw [this]
    calc |S₃_at M - L₃ + (S₃_at N - S₃_at M)|
        ≤ |S₃_at M - L₃| + |S₃_at N - S₃_at M| := abs_add_le _ _
      _ = |S₃_at M - L₃| + |S₃_at M - S₃_at N| := by
          congr 1; exact abs_sub_comm _ _
  calc |S₃_at N - L₃|
      ≤ |S₃_at M - L₃| + |S₃_at M - S₃_at N| := h_tri
    _ ≤ ε / 3 + |S₃_at M - S₃_at N| := by linarith [hS3M]
    _ ≤ ε / 3 + (C_m * ((M : ℝ) ^ (-(1:ℝ)/4) * (Real.log (M : ℝ)) ^ 2 +
            (N : ℝ) ^ ((3:ℝ)/4) * (Real.log (M : ℝ)) ^ 2 / (M : ℝ)) +
          C_m * (8 * (Real.log (N : ℝ)) ^ 2 + 96 * Real.log (N : ℝ) + 496) *
            (N : ℝ) ^ (-(1:ℝ)/4)) := by linarith [hAbel]
    _ < ε / 3 + (ε / 3 +
          C_m * (8 * (Real.log (N : ℝ)) ^ 2 + 96 * Real.log (N : ℝ) + 496) *
            (N : ℝ) ^ (-(1:ℝ)/4)) := by linarith [hBdry]
    _ = C_m * (8 * (Real.log (N : ℝ)) ^ 2 + 96 * Real.log (N : ℝ) + 496) *
          (N : ℝ) ^ (-(1:ℝ)/4) + 2 * ε / 3 := by ring
    _ < C_m * (8 * (Real.log (N : ℝ)) ^ 2 + 96 * Real.log (N : ℝ) + 496) *
          (N : ℝ) ^ (-(1:ℝ)/4) + ε := by linarith

end
