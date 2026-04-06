/-
  Cathedral/Mertens/Harmonic.lean

  ## Harmonic number bounds.

  Defines harmonicFin and proves harmonicFin_le: H_n ≤ 1 + log(n).
-/

import Cathedral.Defs

noncomputable section
open Real MeasureTheory Set Finset

/-- Harmonic number: H_n = Σ_{i=0}^{n-1} 1/(i+1). -/
noncomputable def harmonicFin (n : ℕ) : ℝ :=
  ∑ i : Fin n, 1 / ((i.val : ℝ) + 1)

/-- 1/(k+1) ≤ log(k+1) - log(k) for k ≥ 1. -/
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

/-- Harmonic bound: H_n ≤ 1 + log(n) for n ≥ 1. -/
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

end
