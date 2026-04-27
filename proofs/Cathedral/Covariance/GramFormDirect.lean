/-
  Cathedral/Covariance/GramFormDirect.lean

  ## Direct Proof of gram_form_upper_bound

  April 27, 2026 — Exploration 13
-/

import Cathedral.Defs
import Cathedral.NymanBeurling.BDBridge
import Cathedral.Covariance.DotProductBound
import Cathedral.AbelTail.S1Decay
import Cathedral.AbelTail.S2Decay

noncomputable section
open Real Matrix Finset MeasureTheory Filter Cathedral.Vasyunin ArithmeticFunction

/-- **THEOREM**: vᵀGv ≤ 1 + K/logN from L² and dot product bounds. -/
theorem gram_form_from_l2_and_dot
    (N : ℕ) (hN : 2 ≤ N)
    (C_l2 C_dot : ℝ) (hC_l2_pos : 0 < C_l2) (hC_dot_pos : 0 < C_dot)
    (h_l2 : ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 ≤
        C_l2 / Real.log ↑N)
    (h_dot : |1 - dotProduct (fun i => vasyuninMeanEntry (i.val + 1))
        (bdMoebiusWeight N)| ≤ C_dot / Real.log ↑N)
    (hlogN_pos : 0 < Real.log ↑N) :
    realQuadForm (Matrix.of fun i j =>
      vasyuninGramEntry (i.val + 1) (j.val + 1)) (bdMoebiusWeight N) ≤
    1 + (C_l2 + 2 * C_dot) / Real.log ↑N := by
  -- Abbreviate
  set Q := realQuadForm (Matrix.of fun i j =>
      vasyuninGramEntry (i.val + 1) (j.val + 1)) (bdMoebiusWeight N) with hQ_def
  set bv := dotProduct (fun i => vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight N)
      with hbv_def
  set I := ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 with hI_def
  -- The identity: I = 1 - 2bv + Q (from BDBridge.lean)
  have h_id : I = 1 - 2 * bv + Q := by
    simp only [hI_def, hQ_def, hbv_def]
    exact bd_l2_error_eq_quad_error N hN (bdMoebiusWeight N)
  -- Therefore: Q = I + 2bv - 1
  have h_Q_eq : Q = I + 2 * bv - 1 := by linarith
  -- From h_dot: bv ≤ 1 + C_dot/logN
  have h_bv : bv ≤ 1 + C_dot / Real.log ↑N := by
    have h_abs := abs_le.mp h_dot
    linarith [h_abs.1]
  -- Now Q = I + 2bv - 1 ≤ C_l2/logN + 2(1 + C_dot/logN) - 1
  -- = 1 + (C_l2 + 2C_dot)/logN
  have h_algebra : C_l2 / Real.log ↑N + 2 * (1 + C_dot / Real.log ↑N) - 1 =
      1 + (C_l2 + 2 * C_dot) / Real.log ↑N := by ring
  linarith [h_Q_eq, h_l2, h_bv, h_algebra]

end
