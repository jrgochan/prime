import PrimeNumberTheoremAnd.RosserSchoenfeldPrime

open Finset Filter Asymptotics Real

lemma iic_eq_ioc_filter_prime (n : ℕ) :
    (Finset.Iic n).filter Nat.Prime = (Finset.Ioc 0 n).filter Nat.Prime := by
  ext p; simp only [mem_filter, mem_Iic, mem_Ioc]
  exact ⟨fun ⟨h1, h2⟩ => ⟨⟨h2.pos, h1⟩, h2⟩, fun ⟨⟨_, h2⟩, h3⟩ => ⟨h2, h3⟩⟩

theorem mertens_first_prime_proved :
    Asymptotics.IsEquivalent Filter.atTop
      (fun x : ℝ => ∑ p ∈ (Finset.Ioc 0 ⌊x⌋₊).filter Nat.Prime,
        Real.log p / p)
      (fun x => Real.log x) := by
  rw [Asymptotics.IsEquivalent]
  have h_tends' : Tendsto (fun x : ℝ =>
      ∑ p ∈ (Finset.Ioc 0 ⌊x⌋₊).filter Nat.Prime, Real.log ↑p / ↑p - Real.log x)
      atTop (nhds mertensConstant) := 
    RS_prime.mertens_first_theorem.congr (fun x => by rw [iic_eq_ioc_filter_prime])
  have h_bounded := h_tends'.isBigO_one ℝ  
  have h_one_o_log : IsLittleO atTop (fun (_ : ℝ) => (1 : ℝ)) (fun x => Real.log x) := by
    rw [isLittleO_iff]
    intro c hc
    filter_upwards [eventually_ge_atTop (Real.exp c⁻¹)] with x hx
    simp only [norm_one, norm_eq_abs]
    have hx_ge_1 : 1 ≤ x := le_trans (one_le_exp (inv_nonneg.mpr hc.le)) hx
    rw [abs_of_nonneg (Real.log_nonneg hx_ge_1)]
    rw [show (1 : ℝ) = c * c⁻¹ from (mul_inv_cancel₀ hc.ne').symm]
    exact mul_le_mul_of_nonneg_left
      (show c⁻¹ ≤ Real.log x from (Real.log_exp c⁻¹ ▸ Real.log_le_log (exp_pos _) hx))
      hc.le
  exact h_bounded.trans_isLittleO h_one_o_log

#print axioms mertens_first_prime_proved
