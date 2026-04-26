/-
  Cathedral/AbelTail/RectangleBound.lean

  ## Rectangle Bound and Finite Telescoping

  The "Bypass A" (Theorist directive): the shifted rectangle trick.
    k^{-5/4} ≤ ∫_{k-1}^{k} t^{-5/4} dt = 4·((k-1)^{-1/4} - k^{-1/4})

  Because t^{-5/4} is decreasing, k^{-5/4} is the MINIMUM on [k-1, k].

  Then: Σ_{k=N+1}^M k^{-5/4} ≤ 4·N^{-1/4}  (by telescoping).

  This is the engine that converts power-law decay into finite sums.
-/

import Cathedral.AbelTail.Antiderivative

noncomputable section
open Real Finset BigOperators MeasureTheory

-- ════════════════════════════════════════════════
-- §1. RECTANGLE BOUND
-- ════════════════════════════════════════════════

/-- **PROVED**: k^{-5/4} ≤ 4·((k-1)^{-1/4} - k^{-1/4}) for k ≥ 2.
    Because t^{-5/4} is decreasing, k^{-5/4} = min value on [k-1, k].
    Uses: ∫_{k-1}^{k} t^{-5/4} dt = 4·((k-1)^{-1/4} - k^{-1/4}) [antiderivative]
          k^{-5/4} ≤ ∫_{k-1}^{k} t^{-5/4} dt  [rectangle bound] -/
theorem rpow_54_le_integral (k : ℕ) (hk : 2 ≤ k) :
    (k : ℝ) ^ (-(5:ℝ)/4) ≤
    4 * (((k : ℝ) - 1) ^ (-(1:ℝ)/4) - (k : ℝ) ^ (-(1:ℝ)/4)) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hkm1_pos : (0 : ℝ) < (k : ℝ) - 1 := by
    have : (2 : ℝ) ≤ (k : ℝ) := Nat.ofNat_le_cast.mpr hk
    linarith
  have hle : (k : ℝ) - 1 ≤ (k : ℝ) := by linarith
  -- Step 1: Evaluate the integral via antiderivative
  have h_int := integral_rpow_54 ((k:ℝ) - 1) (k:ℝ) hkm1_pos hle
  have h_int' : ∫ t in ((k:ℝ) - 1)..(k:ℝ), t ^ (-(5:ℝ)/4) =
      4 * (((k:ℝ) - 1) ^ (-(1:ℝ)/4) - (k:ℝ) ^ (-(1:ℝ)/4)) := by
    rw [h_int]; ring
  -- Step 2: Rectangle bound: k^{-5/4} ≤ ∫_{k-1}^k t^{-5/4} dt
  suffices h : (k : ℝ) ^ (-(5:ℝ)/4) ≤ ∫ t in ((k:ℝ) - 1)..(k:ℝ), t ^ (-(5:ℝ)/4) by
    linarith [h_int']
  have h_const_eq : ∫ t in ((k:ℝ) - 1)..(k:ℝ), (k : ℝ) ^ (-(5:ℝ)/4) =
      (k : ℝ) ^ (-(5:ℝ)/4) := by
    rw [intervalIntegral.integral_const]; simp [sub_sub_cancel]
  rw [← h_const_eq]
  have hint_rpow : IntervalIntegrable (fun t => t ^ (-(5:ℝ)/4)) MeasureTheory.volume
      ((k:ℝ) - 1) (k:ℝ) := by
    apply ContinuousOn.intervalIntegrable
    apply ContinuousOn.rpow continuousOn_id continuousOn_const
    intro t ht
    left
    rw [Set.uIcc_of_le hle] at ht
    exact ne_of_gt (lt_of_lt_of_le hkm1_pos ht.1)
  apply intervalIntegral.integral_mono_on (by linarith)
    (intervalIntegrable_const) hint_rpow
  intro t ht
  have ht_pos : 0 < t := lt_of_lt_of_le hkm1_pos ht.1
  exact Real.rpow_le_rpow_of_nonpos ht_pos ht.2 (by norm_num)

-- ════════════════════════════════════════════════
-- §2. FINITE TELESCOPING SUM
-- ════════════════════════════════════════════════

/-- **PROVED**: Σ_{k=N+1}^{M} k^{-5/4} ≤ 4·N^{-1/4} for N ≥ 1.
    Each term telescopes via rpow_54_le_integral, then the sum telescopes. -/
theorem finite_rpow_54_tail_bound (N M : ℕ) (hN : 1 ≤ N) (hNM : N + 1 ≤ M) :
    (Icc (N+1) M).sum (fun k => (k : ℝ) ^ (-(5:ℝ)/4)) ≤
    4 * (N : ℝ) ^ (-(1:ℝ)/4) := by
  have hbridge : ∀ k : ℕ, N + 1 ≤ k → k ≤ M →
      (k : ℝ) ^ (-(5:ℝ)/4) ≤
      4 * (((k : ℝ) - 1) ^ (-(1:ℝ)/4) - (k : ℝ) ^ (-(1:ℝ)/4)) := by
    intro k hk _
    exact rpow_54_le_integral k (by omega)
  calc (Icc (N+1) M).sum (fun k => (k : ℝ) ^ (-(5:ℝ)/4))
      ≤ (Icc (N+1) M).sum (fun k =>
        4 * (((k : ℝ) - 1) ^ (-(1:ℝ)/4) - (k : ℝ) ^ (-(1:ℝ)/4))) := by
        apply Finset.sum_le_sum
        intro k hk
        rw [Finset.mem_Icc] at hk
        exact hbridge k hk.1 hk.2
    _ = 4 * (Icc (N+1) M).sum (fun k =>
        ((k : ℝ) - 1) ^ (-(1:ℝ)/4) - (k : ℝ) ^ (-(1:ℝ)/4)) := by
        rw [← Finset.mul_sum]
    _ ≤ 4 * (N : ℝ) ^ (-(1:ℝ)/4) := by
        apply mul_le_mul_of_nonneg_left _ (by norm_num : (0:ℝ) ≤ 4)
        suffices htel : (Icc (N+1) M).sum (fun k =>
            ((k : ℝ) - 1) ^ (-(1:ℝ)/4) - (k : ℝ) ^ (-(1:ℝ)/4)) =
            (N : ℝ) ^ (-(1:ℝ)/4) - (M : ℝ) ^ (-(1:ℝ)/4) by
          rw [htel]
          have : 0 ≤ (M : ℝ) ^ (-(1:ℝ)/4) := by positivity
          linarith
        have hle : N + 1 ≤ M := hNM
        obtain ⟨d, rfl⟩ := Nat.exists_eq_add_of_le hle
        induction d with
        | zero =>
          simp [Finset.Icc_self]
        | succ n ih =>
          rw [show N + 1 + (n + 1) = N + 1 + n + 1 from by omega]
          rw [Finset.sum_Icc_succ_top (by omega : N + 1 ≤ N + 1 + n + 1)]
          have ih' := ih (by omega) (fun k hk1 hk2 => hbridge k hk1 (by omega)) (by omega)
          rw [ih']
          push_cast; ring_nf

end
