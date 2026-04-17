import Cathedral.Vasyunin.Proof.WitnessAsymptotics
import Cathedral.Vasyunin.Proof.Chain
import Cathedral.NymanBeurling.NymanBeurling

set_option maxHeartbeats 200000

theorem abel_summation_covariance_bound :
    (∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 → := by
  intro n; induction n with | zero => simp | succ n ih => simp [ih]
