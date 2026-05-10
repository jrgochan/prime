/-
  Cathedral/AbelTail/S1Decay.lean

  ## S₁ Decay: |S₁(N)| ≤ C·N^{-1/4}

  The PROVED decay bound for the unweighted PNT sub-sum:
    S₁(N) = Σ_{k=1}^N μ(k)/k

  Strategy:
  1. finite_abel_s1_diff: Abel summation on [N+1, M] gives
     |S₁(M) - S₁(N)| ≤ C_m·(boundary + 5·N^{-1/4})
  2. s1_decay: Choose M from PNT (S₁ → 0) to close the triangle
     |S₁(N)| ≤ |S₁(M)| + |S₁(M) - S₁(N)|

  This is the HARDEST section and it's COMPLETELY PROVED.
-/

import Cathedral.AbelTail.AbelInterior
import Cathedral.AbelTail.RectangleBound
import Cathedral.AbelTail.Telescoping
import Cathedral.AbelTail.MertensBridge
import Cathedral.AbelTail.Engine
import Cathedral.MellinBridge.AbelSummation

noncomputable section
open Real Finset BigOperators

-- ════════════════════════════════════════════════
-- §1. PNT SUB-SUM DEFINITIONS
-- ════════════════════════════════════════════════

/-- S₁(M) = Σ_{k=1}^M μ(k)/k (matching FinalDragon.lean). -/
def S₁_at (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ)

-- ════════════════════════════════════════════════
-- §2. FINITE ABEL BOUND ON S₁ DIFFERENCE
-- ════════════════════════════════════════════════

/-- **PROVED**: For M ≥ N+1 ≥ 3, Abel summation on [N+1, M] gives:
    |S₁(M) - S₁(N)| ≤ C_m·(M^{-1/4} + N^{3/4}/M) + C_m·5·N^{-1/4} -/
theorem finite_abel_s1_diff
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (N M : ℕ) (hN : 2 ≤ N) (hM : N + 1 ≤ M) :
    |S₁_at M - S₁_at N| ≤
      C_m * ((M : ℝ) ^ (-(1:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4) / (M : ℝ)) +
      C_m * 5 * (N : ℝ) ^ (-(1:ℝ)/4) := by
  -- ─── Step 0: Basic positivity ───
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have hM_pos : (0 : ℝ) < (M : ℝ) := Nat.cast_pos.mpr (by omega)
  -- ─── Step 1: S₁(M) - S₁(N) = Σ_{k=N+1}^M μ(k)/k ───
  have h_diff : S₁_at M - S₁_at N =
      (Icc (N+1) M).sum (fun k => (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ)) := by
    unfold S₁_at
    rw [show Icc 1 M = Icc 1 N ∪ Icc (N+1) M from by
      ext k; simp [Finset.mem_Icc, Finset.mem_union]; omega]
    rw [Finset.sum_union (by
      rw [Finset.disjoint_left]; intro k hk1 hk2
      simp [Finset.mem_Icc] at hk1 hk2; omega)]
    ring
  -- ─── Step 2: Rewrite as Σ a(k)·f(k) form ───
  have h_mul : ∀ k : ℕ, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ) =
      (↑(ArithmeticFunction.moebius k) : ℝ) * (1 / (k : ℝ)) := by
    intro k; ring
  rw [h_diff, show (Icc (N+1) M).sum (fun k => (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ)) =
      (Icc (N+1) M).sum (fun k => (↑(ArithmeticFunction.moebius k) : ℝ) * (1 / (k : ℝ))) from
      Finset.sum_congr rfl (fun k _ => h_mul k)]
  -- ─── Step 3: Apply abel_summation_abs_bound ───
  set a := fun k => (↑(ArithmeticFunction.moebius k) : ℝ)
  set f : ℕ → ℝ := fun k => 1 / (k : ℝ)
  set C_bound : ℕ → ℝ := fun k => C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4))
  set δ : ℕ → ℝ := fun k => 1 / ((k : ℝ) * ((k : ℝ) + 1))
  have hAbel := abel_summation_abs_bound a f (N+1) M hM C_bound δ
    (fun k hk1 hk2 => by
      simp only [a, C_bound]
      unfold partialSum
      rw [partial_sum_eq_mertens_diff N k (by omega) (by omega)]
      have hMk := hMertens (k : ℝ) (by exact_mod_cast show 2 ≤ k by omega)
      have hMN := hMertens (N : ℝ) (by exact_mod_cast hN)
      calc |((mertensFunction (k:ℝ) : ℤ) : ℝ) - ((mertensFunction (N:ℝ) : ℤ) : ℝ)|
          ≤ |((mertensFunction (k:ℝ) : ℤ) : ℝ)| + |((mertensFunction (N:ℝ) : ℤ) : ℝ)| :=
            abs_sub _ _
        _ ≤ C_m * (k : ℝ) ^ ((3:ℝ)/4) + C_m * (N : ℝ) ^ ((3:ℝ)/4) :=
            add_le_add hMk hMN
        _ = C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) := by ring)
    (fun k hk1 hk2 => by
      simp only [f]
      have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
      have hk1_cast : ((k + 1 : ℕ) : ℝ) = (k : ℝ) + 1 := by push_cast; ring
      rw [hk1_cast]
      rw [show 1 / ((k : ℝ) + 1) - 1 / (k : ℝ) = -(1 / ((k : ℝ) * ((k : ℝ) + 1))) from by
        field_simp; ring]
      rw [abs_neg, abs_of_nonneg (by positivity)])
  -- ─── Step 4: Bound the Abel output ───
  calc |(Icc (N+1) M).sum (fun k => a k * f k)|
      ≤ C_bound M * |f M| + (Ico (N+1) M).sum (fun k => C_bound k * δ k) := hAbel
    _ ≤ C_m * ((M : ℝ) ^ (-(1:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4) / (M : ℝ)) +
        C_m * 5 * (N : ℝ) ^ (-(1:ℝ)/4) := by
      apply add_le_add
      · -- Boundary: C_bound(M)*|f(M)| ≤ C_m*(M^{-1/4} + N^{3/4}/M)
        simp only [C_bound, f]
        rw [abs_of_nonneg (by positivity)]
        have hM_pos' : (0 : ℝ) < (M : ℝ) := Nat.cast_pos.mpr (by omega)
        rw [show C_m * ((M : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) * (1 / (M : ℝ)) =
            C_m * ((M : ℝ) ^ ((3:ℝ)/4) / (M : ℝ) + (N : ℝ) ^ ((3:ℝ)/4) / (M : ℝ)) from by ring]
        gcongr
        rw [rpow_34_div_eq M (by omega)]
      · -- Interior sum ≤ C_m * 5 * N^{-1/4}
        simp only [C_bound, δ]
        have h_ico_icc : (Ico (N+1) M).sum (fun k =>
            C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) *
            (1 / ((k : ℝ) * ((k : ℝ) + 1)))) ≤
          (Icc (N+1) M).sum (fun k =>
            C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) *
            (1 / ((k : ℝ) * ((k : ℝ) + 1)))) := by
          apply Finset.sum_le_sum_of_subset_of_nonneg Finset.Ico_subset_Icc_self
          intro k _ _
          apply mul_nonneg (mul_nonneg (by linarith) (add_nonneg (by positivity) (by positivity)))
          positivity
        have h_split : (Icc (N+1) M).sum (fun k =>
            C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) *
            (1 / ((k : ℝ) * ((k : ℝ) + 1)))) ≤
          C_m * (Icc (N+1) M).sum (fun k => (k : ℝ) ^ (-(5:ℝ)/4)) +
          C_m * (N : ℝ) ^ ((3:ℝ)/4) * (1 / ((N : ℝ) + 1)) := by
          have h_eq : (Icc (N+1) M).sum (fun k =>
              C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) *
              (1 / ((k : ℝ) * ((k : ℝ) + 1)))) =
            (Icc (N+1) M).sum (fun k =>
              C_m * (k : ℝ) ^ ((3:ℝ)/4) / ((k : ℝ) * ((k : ℝ) + 1))) +
            (Icc (N+1) M).sum (fun k =>
              C_m * (N : ℝ) ^ ((3:ℝ)/4) / ((k : ℝ) * ((k : ℝ) + 1))) := by
            rw [← Finset.sum_add_distrib]
            apply Finset.sum_congr rfl; intro k _; ring
          rw [h_eq]
          apply add_le_add
          · rw [Finset.mul_sum]
            apply Finset.sum_le_sum
            intro k hk
            rw [Finset.mem_Icc] at hk
            have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
            have hkk1_ge_k2 : (k : ℝ) ^ 2 ≤ (k : ℝ) * ((k : ℝ) + 1) := by nlinarith
            have hk34_div : C_m * (k : ℝ) ^ ((3:ℝ)/4) / ((k : ℝ) * ((k : ℝ) + 1)) ≤
                C_m * (k : ℝ) ^ ((3:ℝ)/4) / (k : ℝ) ^ 2 := by
              apply div_le_div_of_nonneg_left (by positivity) (by positivity) hkk1_ge_k2
            have hk_rpow : C_m * (k : ℝ) ^ ((3:ℝ)/4) / (k : ℝ) ^ 2 =
                C_m * (k : ℝ) ^ (-(5:ℝ)/4) := by
              have h_k2 : (k : ℝ) ^ (2 : ℕ) = (k : ℝ) ^ (2 : ℝ) :=
                (Real.rpow_natCast _ _).symm
              rw [show (k : ℝ) ^ 2 = (k : ℝ) ^ (2 : ℕ) from by norm_num, h_k2]
              rw [div_eq_mul_inv, ← Real.rpow_neg (le_of_lt hk_pos)]
              rw [show C_m * (k : ℝ) ^ ((3:ℝ)/4) * (k : ℝ) ^ (-(2:ℝ)) =
                  C_m * ((k : ℝ) ^ ((3:ℝ)/4) * (k : ℝ) ^ (-(2:ℝ))) from by ring]
              rw [← Real.rpow_add hk_pos]
              norm_num
            linarith
          · have h_factor : (Icc (N+1) M).sum (fun k =>
                C_m * (N : ℝ) ^ ((3:ℝ)/4) / ((k : ℝ) * ((k : ℝ) + 1))) =
              C_m * (N : ℝ) ^ ((3:ℝ)/4) * (Icc (N+1) M).sum (fun k =>
                1 / ((k : ℝ) * ((k : ℝ) + 1))) := by
              rw [Finset.mul_sum]
              apply Finset.sum_congr rfl; intro k _; ring
            rw [h_factor]
            apply mul_le_mul_of_nonneg_left
              (finite_inv_kk1_bound N M (by omega) (by omega)) (by positivity)
        have h_rpow := finite_rpow_54_tail_bound N M (by omega : 1 ≤ N) (by omega : N + 1 ≤ M)
        have h_N34 : C_m * (N : ℝ) ^ ((3:ℝ)/4) * (1 / ((N : ℝ) + 1)) ≤
            C_m * 1 * (N : ℝ) ^ (-(1:ℝ)/4) := by
          have hN_pos' : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
          have h_inv : (1:ℝ) / ((N:ℝ) + 1) ≤ 1 / (N:ℝ) := by
            apply one_div_le_one_div_of_le hN_pos' (by linarith)
          have h_rpow_div : (N : ℝ) ^ ((3:ℝ)/4) / (N : ℝ) = (N : ℝ) ^ (-(1:ℝ)/4) := by
            have : (N : ℝ) ^ ((3:ℝ)/4) / (N : ℝ) =
                (N : ℝ) ^ ((3:ℝ)/4) * (N : ℝ) ^ (-(1:ℝ)) := by
              rw [Real.rpow_neg (le_of_lt hN_pos'), Real.rpow_one, div_eq_mul_inv]
            rw [this, ← Real.rpow_add hN_pos']
            congr 1; ring
          have h1 : C_m * (N : ℝ) ^ ((3:ℝ)/4) * (1 / ((N : ℝ) + 1)) ≤
              C_m * (N : ℝ) ^ ((3:ℝ)/4) * (1 / (N : ℝ)) :=
            mul_le_mul_of_nonneg_left h_inv (by positivity)
          have h2 : C_m * (N : ℝ) ^ ((3:ℝ)/4) * (1 / (N : ℝ)) =
              C_m * 1 * (N : ℝ) ^ (-(1:ℝ)/4) := by
            rw [show C_m * (N : ℝ) ^ ((3:ℝ)/4) * (1 / (N : ℝ)) =
                C_m * ((N : ℝ) ^ ((3:ℝ)/4) / (N : ℝ)) from by ring]
            rw [h_rpow_div]; ring
          linarith
        have h_cm4 : C_m * (Icc (N+1) M).sum (fun k => (k : ℝ) ^ (-(5:ℝ)/4)) ≤
            C_m * (4 * (N : ℝ) ^ (-(1:ℝ)/4)) := by
          apply mul_le_mul_of_nonneg_left h_rpow (by linarith)
        linarith

-- ════════════════════════════════════════════════
-- §3. S₁ DECAY VIA LIMIT ARGUMENT
-- ════════════════════════════════════════════════

/-- **PROVED**: |S₁(N)| ≤ C · N^{-1/4} for N ≥ 2.

    For each N ≥ 2:
    1. From PNT (S₁ → 0), choose M ≥ N+1 with |S₁(M)| < N^{-1/4}
    2. Triangle: |S₁(N)| ≤ |S₁(M)| + |S₁(M) - S₁(N)|
    3. |S₁(M)| < N^{-1/4} (by choice of M)
    4. |S₁(M)-S₁(N)| ≤ C_m·(M^{-1/4}+N^{3/4}/M+5N^{-1/4}) ≤ 7C_m·N^{-1/4}
    5. Total: |S₁(N)| ≤ (1+7C_m)·N^{-1/4}

    C = 1+7C_m is UNIFORM (independent of the choice of M). -/
theorem s1_decay
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (hPNT₁ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ))
      Filter.atTop (nhds 0)) :
    ∃ C₁ : ℝ, C₁ > 0 ∧ ∀ N : ℕ, 2 ≤ N →
      |S₁_at N| ≤ C₁ * (N : ℝ) ^ (-(1:ℝ)/4) := by
  use 1 + 7 * C_m
  constructor
  · linarith
  intro N hN
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have h_eps : (0 : ℝ) < (N : ℝ) ^ (-(1:ℝ)/4) := Real.rpow_pos_of_pos hN_pos _
  -- Step 1: From PNT, get M₀ with |S₁(M)| < N^{-1/4} for M ≥ M₀
  obtain ⟨M₀, hM₀⟩ := tendsto_extract_bound h_eps hPNT₁
  -- Step 2: Choose M = max(N+1, M₀)
  set M := max (N + 1) M₀
  have hM_ge_N1 : N + 1 ≤ M := le_max_left _ _
  have hM_ge_M0 : M₀ ≤ M := le_max_right _ _
  -- Step 3: |S₁(M)| < N^{-1/4}
  have hS1M : |S₁_at M| ≤ (N : ℝ) ^ (-(1:ℝ)/4) := by
    have := hM₀ M hM_ge_M0; simp at this; exact this
  -- Step 4: Abel bound
  have hAbel := finite_abel_s1_diff C_m hC hMertens N M hN hM_ge_N1
  -- Step 5: M^{-1/4} ≤ N^{-1/4} and N^{3/4}/M ≤ N^{-1/4}
  have hM_ge_N : (N : ℝ) ≤ (M : ℝ) := by exact_mod_cast (show N ≤ M by omega)
  have hM_pos : (0 : ℝ) < (M : ℝ) := Nat.cast_pos.mpr (by omega)
  have h1 : (M : ℝ) ^ (-(1:ℝ)/4) ≤ (N : ℝ) ^ (-(1:ℝ)/4) :=
    Real.rpow_le_rpow_of_nonpos hN_pos hM_ge_N (show -(1:ℝ)/4 ≤ 0 by norm_num)
  have h2 : (N : ℝ) ^ ((3:ℝ)/4) / (M : ℝ) ≤ (N : ℝ) ^ (-(1:ℝ)/4) := by
    rw [div_le_iff₀ hM_pos]
    have h34 : (N : ℝ) ^ ((3:ℝ)/4) = (N : ℝ) ^ (-(1:ℝ)/4) * (N : ℝ) ^ (1:ℝ) := by
      rw [← Real.rpow_add hN_pos]; congr 1; norm_num
    rw [h34, Real.rpow_one]
    exact mul_le_mul_of_nonneg_left hM_ge_N (Real.rpow_nonneg hN_pos.le _)
  -- Step 6: Triangle + combine
  have h_tri : |S₁_at N| ≤ |S₁_at M| + |S₁_at M - S₁_at N| := by
    calc |S₁_at N| = |S₁_at M + (S₁_at N - S₁_at M)| := by ring_nf
      _ ≤ |S₁_at M| + |S₁_at N - S₁_at M| := abs_add_le _ _
      _ = |S₁_at M| + |S₁_at M - S₁_at N| := by rw [abs_sub_comm]
  calc |S₁_at N| ≤ |S₁_at M| + |S₁_at M - S₁_at N| := h_tri
    _ ≤ (N : ℝ) ^ (-(1:ℝ)/4) +
        (C_m * ((M : ℝ) ^ (-(1:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4) / (M : ℝ)) +
         C_m * 5 * (N : ℝ) ^ (-(1:ℝ)/4)) := by linarith
    _ ≤ (1 + 7 * C_m) * (N : ℝ) ^ (-(1:ℝ)/4) := by nlinarith [h_eps]

end
