/-
  Cathedral/AbelTail/S2Decay.lean

  ## S₂ Decay: |S₂(N) + 1| ≤ C₂·N^{-1/4}·log(N)

  Bounds the log-weighted PNT sub-sum:
    S₂(N) = Σ_{k=1}^N μ(k)·log(k)/k

  Architecture:
  1. log_weighted_rpow_54_tail (LogTailBound.lean):
     Σ k^{-5/4}·(log(k)+1) ≤ (4·log(N)+24)·N^{-1/4}
  2. finite_abel_s2_diff: Abel bound with M-INDEPENDENT interior
  3. s2_decay: limit argument (same as proved s1_decay)

  Dependencies: S1Decay, LogTailBound, DiscreteProductRule
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

/-- S₂(M) = Σ_{k=1}^M μ(k)·log(k)/k (matching FinalDragon.lean). -/
def S₂_at (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) *
    Real.log (k : ℝ) / (k : ℝ)

-- ════════════════════════════════════════════════
-- §2. FINITE ABEL BOUND (M-INDEPENDENT)
-- ════════════════════════════════════════════════

/-- **Abel bound for S₂ on [N+1, M] — M-INDEPENDENT interior.**

    Same structure as the PROVED finite_abel_s1_diff but with:
    - f(k) = log(k)/k instead of 1/k
    - |Δf| ≤ (log(k)+1)/k² [from s2_discrete_diff_bound, PROVED]

    Interior ≤ 2·C_m·(4·log(N)+24)·N^{-1/4} = C_m·(8·log(N)+48)·N^{-1/4} -/
theorem finite_abel_s2_diff
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (N M : ℕ) (hN : 2 ≤ N) (hM : N + 1 ≤ M) :
    |S₂_at M - S₂_at N| ≤
      C_m * ((M : ℝ) ^ (-(1:ℝ)/4) * Real.log (M : ℝ) +
             (N : ℝ) ^ ((3:ℝ)/4) * Real.log (M : ℝ) / (M : ℝ)) +
      C_m * (8 * Real.log (N : ℝ) + 48) * (N : ℝ) ^ (-(1:ℝ)/4) := by
  -- ─── Step 0: Basic positivity ───
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have hM_pos : (0 : ℝ) < (M : ℝ) := Nat.cast_pos.mpr (by omega)
  -- ─── Step 1: S₂(M) - S₂(N) = Σ_{k=N+1}^M μ(k)·log(k)/k ───
  have h_diff : S₂_at M - S₂_at N =
      (Icc (N+1) M).sum (fun k => (↑(ArithmeticFunction.moebius k) : ℝ) *
        Real.log (k : ℝ) / (k : ℝ)) := by
    unfold S₂_at
    rw [show Icc 1 M = Icc 1 N ∪ Icc (N+1) M from by
      ext k; simp [Finset.mem_Icc, Finset.mem_union]; omega]
    rw [Finset.sum_union (by
      rw [Finset.disjoint_left]; intro k hk1 hk2
      simp [Finset.mem_Icc] at hk1 hk2; omega)]
    ring
  -- ─── Step 2: Rewrite as Σ a(k)·f(k) form ───
  rw [h_diff]
  -- ─── Step 3: Apply abel_summation_abs_bound ───
  set a := fun k => (↑(ArithmeticFunction.moebius k) : ℝ)
  set f : ℕ → ℝ := fun k => Real.log (k : ℝ) / (k : ℝ)
  set C_bound : ℕ → ℝ := fun k => C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4))
  set δ : ℕ → ℝ := fun k => (Real.log (k : ℝ) + 1) / (k : ℝ) ^ 2
  -- The sum has the a·f form
  have h_af : ∀ k, (↑(ArithmeticFunction.moebius k) : ℝ) *
      Real.log (k : ℝ) / (k : ℝ) = a k * f k := by
    intro k; simp only [a, f]; ring
  rw [show (Icc (N+1) M).sum (fun k => (↑(ArithmeticFunction.moebius k) : ℝ) *
      Real.log (k : ℝ) / (k : ℝ)) =
      (Icc (N+1) M).sum (fun k => a k * f k) from
      Finset.sum_congr rfl (fun k _ => h_af k)]
  have hAbel := abel_summation_abs_bound a f (N+1) M hM C_bound δ
    (fun k hk1 hk2 => by
      simp only [a, C_bound]
      unfold partialSum
      exact mertens_partial_sum_bound C_m hMertens N k hN (by omega))
    (fun k hk1 hk2 => by
      simp only [f, δ]
      have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
      have hk1_cast : ((k + 1 : ℕ) : ℝ) = (k : ℝ) + 1 := by push_cast; ring
      rw [hk1_cast, show Real.log ((k:ℝ) + 1) / ((k:ℝ) + 1) - Real.log (k:ℝ) / (k:ℝ) =
          -(Real.log (k:ℝ) / (k:ℝ) - Real.log ((k:ℝ) + 1) / ((k:ℝ) + 1)) from by ring]
      rw [abs_neg]
      exact s2_discrete_diff_bound k (by omega))
  -- ─── Step 4: Bound the Abel output ───
  calc |(Icc (N+1) M).sum (fun k => a k * f k)|
      ≤ C_bound M * |f M| + (Ico (N+1) M).sum (fun k => C_bound k * δ k) := hAbel
    _ ≤ C_m * ((M : ℝ) ^ (-(1:ℝ)/4) * Real.log (M : ℝ) +
             (N : ℝ) ^ ((3:ℝ)/4) * Real.log (M : ℝ) / (M : ℝ)) +
        C_m * (8 * Real.log (N : ℝ) + 48) * (N : ℝ) ^ (-(1:ℝ)/4) := by
      apply add_le_add
      · -- Boundary: C_bound(M)*|f(M)| = C_m*(M^{3/4}+N^{3/4})*(log(M)/M)
        simp only [C_bound, f]
        rw [abs_of_nonneg (div_nonneg (Real.log_nonneg (by exact_mod_cast show 1 ≤ M by omega))
            (by positivity))]
        rw [show C_m * ((M : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) *
            (Real.log (M : ℝ) / (M : ℝ)) =
            C_m * ((M : ℝ) ^ ((3:ℝ)/4) * Real.log (M : ℝ) / (M : ℝ) +
                   (N : ℝ) ^ ((3:ℝ)/4) * Real.log (M : ℝ) / (M : ℝ)) from by ring]
        gcongr
        rw [show (M : ℝ) ^ ((3:ℝ)/4) * Real.log (M : ℝ) / (M : ℝ) =
            ((M : ℝ) ^ ((3:ℝ)/4) / (M : ℝ)) * Real.log (M : ℝ) from by ring]
        rw [rpow_34_div_eq M (by omega)]
      · -- Interior: ≤ C_m * (8*logN+48) * N^{-1/4}
        simp only [C_bound, δ]
        have h_int := interior_bound_weighted N M (by omega) hM C_m hC
          (fun k => Real.log (k : ℝ) + 1)
          (fun k hk => by
            rw [Finset.mem_Icc] at hk
            have : (1 : ℝ) ≤ (k : ℝ) := by exact_mod_cast show 1 ≤ k by omega
            linarith [Real.log_nonneg this])
          ((4 * Real.log (N : ℝ) + 24) * (N : ℝ) ^ (-(1:ℝ)/4))
          (by
            apply mul_nonneg
            · have : (1 : ℝ) ≤ (N : ℝ) := by exact_mod_cast show 1 ≤ N by omega
              linarith [Real.log_nonneg this]
            · positivity)
          (log_weighted_rpow_54_tail N M hN hM)
        -- 2 * C_m * ((4*logN+24) * N^{-1/4}) = C_m * (8*logN+48) * N^{-1/4}
        linarith

-- ════════════════════════════════════════════════
-- §3. S₂ DECAY
-- ════════════════════════════════════════════════

/-- **S₂ decay via limit + Abel (same architecture as proved s1_decay).**
    |S₂(N)+1| ≤ C₂·N^{-1/4}·log(N) for all N ≥ 2.

    For each N ≥ 2:
    1. From PNT₂ (S₂ → -1), choose M ≥ N+1 with |S₂(M)-(-1)| < N^{-1/4}·log(N)
    2. Triangle: |S₂(N)-(-1)| ≤ |S₂(M)-(-1)| + |S₂(M)-S₂(N)|
    3. |S₂(M)-(-1)| < N^{-1/4}·log(N) (by choice of M)
    4. |S₂(M)-S₂(N)| ≤  ... (from finite_abel_s2_diff)
    5. Total: |S₂(N)-(-1)| ≤ C₂ · N^{-1/4} · log(N)

    C₂ = 1 + 28·C_m. Depends on finite_abel_s2_diff. -/
theorem s2_decay
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (hPNT₂ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        Real.log (k : ℝ) / (k : ℝ))
      Filter.atTop (nhds (-1))) :
    ∃ C₂ : ℝ, C₂ > 0 ∧ ∀ N : ℕ, 2 ≤ N →
      |S₂_at N - (-1)| ≤ C₂ * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := by
  -- Interior = C_m·(8·logN+48)·N^{-1/4} is M-independent.
  -- Using logN ≥ 1/2: (8·logN+48) ≤ (8+96)·logN = 104·logN.
  -- Boundary → 0 as M → ∞, and |S₂(M)+1| → 0 by Tendsto.
  -- So |S₂(N)+1| ≤ 0 + 0 + 104·C_m·N^{-1/4}·logN.
  use 104 * C_m
  constructor
  · linarith
  intro N hN
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have h_rpow_pos : 0 < (N : ℝ) ^ (-(1:ℝ)/4) := Real.rpow_pos_of_pos hN_pos _
  have hlog_pos : 0 < Real.log (N : ℝ) :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  -- Step 1: Absorb constant term: (8·logN+48) ≤ 104·logN
  have h_logN_ge : Real.log (N : ℝ) ≥ 1/2 := log_ge_half_of_two_le N hN
  have h_const : C_m * (8 * Real.log (N : ℝ) + 48) * (N : ℝ) ^ (-(1:ℝ)/4) ≤
      104 * C_m * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := by
    have h_rpow_nn : 0 ≤ (N : ℝ) ^ (-(1:ℝ)/4) := le_of_lt h_rpow_pos
    -- 8·logN + 48 ≤ 104·logN iff 48 ≤ 96·logN iff logN ≥ 1/2
    have h48 : (48 : ℝ) ≤ 96 * Real.log (N : ℝ) := by nlinarith
    -- C_m * (8*logN+48) * rpow ≤ C_m * 104*logN * rpow
    -- = 104 * C_m * rpow * logN
    nlinarith [mul_nonneg (mul_nonneg hC.le h_rpow_nn) hlog_pos.le]
  -- Step 2: The bound |S₂(N)+1| ≤ C_m·(8·logN+48)·N^{-1/4} via ε-argument
  -- For all ε > 0, choose M large enough that:
  --   (a) |S₂(M)+1| < ε
  --   (b) C_m·boundary(M,N) < ε
  -- Then |S₂(N)+1| ≤ 2ε + interior(N). Since this holds for all ε > 0,
  -- |S₂(N)+1| ≤ interior(N).
  suffices h_interior : |S₂_at N - (-1)| ≤
      C_m * (8 * Real.log (N : ℝ) + 48) * (N : ℝ) ^ (-(1:ℝ)/4) by
    linarith
  -- We prove: for all ε > 0, |S₂(N)+1| ≤ interior + ε
  apply le_of_forall_pos_lt_add
  intro ε hε
  -- From PNT₂: ∃ M₀, ∀ M ≥ M₀, |S₂(M)+1| < ε/2
  have hε2 : (0 : ℝ) < ε / 2 := by linarith
  obtain ⟨M₀, hM₀⟩ := tendsto_extract_bound hε2 hPNT₂
  -- Choose M = max(N+1, M₀) — boundary vanishes via sorry for now
  -- The boundary = C_m·(M^{-1/4}·logM + N^{3/4}·logM/M)
  -- This → 0 as M → ∞. We need it < ε/2.
  -- For M large enough: M^{-1/4}·logM < ε/(4·C_m) and N^{3/4}·logM/M < ε/(4·C_m).
  -- Both hold for M > some M₁(N, ε, C_m). The existence of M₁ needs
  -- Tendsto (fun M => M^{-1/4}·logM) atTop (nhds 0), which is in Mathlib.
  sorry

end
