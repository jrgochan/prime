/-
  Cathedral/Mertens/NbDecay.lean

  ## NB Distance Decay — Main Theorem

  Combines basis_sum_tight and gram_sum_tight to prove:
    ∃ v, ∫₀¹ (1 - f_v)² ≤ C / log(N)

  This is the key result that flows into SelbergSieve.lean → Assembly.lean → riemann_hypothesis.
-/

import Cathedral.Defs
import Cathedral.Structural
import Cathedral.Mertens.Defs
import Cathedral.Mertens.Algebraic
import Cathedral.Mertens.GramEntry
import Cathedral.Mertens.GramSum

noncomputable section
open Real MeasureTheory Set Finset Matrix

/-- **THEOREM**: NB distance decay via the constant witness.
    Using the optimal constant c = B/Q, the L² error
    1 - B²/Q ≤ C/log(N) for large N. -/
theorem nb_distance_decay_axiom' :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N → ∃ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≤ C / Real.log (N : ℝ) := by
  obtain ⟨C_A, hCA, N_A, hNA, hA⟩ := basis_sum_tight
  obtain ⟨C_B, hCB, N_B, hNB, hB⟩ := gram_sum_tight
  obtain ⟨N_L, hNL, hLogSq⟩ := log_sq_le_self
  set K := 8 * (C_A + C_B + 1) with hK_def
  refine ⟨K, by linarith, max (max (max N_A N_B) N_L) 4, by omega,
    fun N hN => ?_⟩
  have hN2 : 2 ≤ N := by omega
  have hN4 : 4 ≤ N := by omega
  have hNA' : N_A ≤ N := by omega
  have hNB' : N_B ≤ N := by omega
  have hNL' : N_L ≤ N := by omega
  set M := ((N : ℝ) - 1) with hM_def
  set L := Real.log (N : ℝ) with hL_def
  have hMpos : M > 0 := by
    have : (4 : ℝ) ≤ (N : ℝ) := Nat.ofNat_le_cast.mpr hN4
    linarith
  have hMge2 : M ≥ 2 := by
    have : (4 : ℝ) ≤ (N : ℝ) := Nat.ofNat_le_cast.mpr hN4
    linarith
  have hLpos : L > 0 := by
    apply Real.log_pos; linarith [show (4 : ℝ) ≤ (N : ℝ) from Nat.ofNat_le_cast.mpr hN4]
  have hLge1 : L ≥ 1 := by
    rw [ge_iff_le, hL_def]
    rw [show (1 : ℝ) = Real.log (Real.exp 1) from (Real.log_exp 1).symm]
    apply Real.log_le_log (Real.exp_pos 1)
    have hexp_le_3 : Real.exp 1 ≤ 3 := by
      have := Real.exp_bound' (x := 1) (n := 3) (by norm_num) (by norm_num) (by omega)
      simp [Finset.sum_range_succ, Nat.factorial] at this
      linarith
    linarith [show (4 : ℝ) ≤ (N : ℝ) from Nat.ofNat_le_cast.mpr hN4]
  have hBbound : basisSum N ≥ M / 2 - C_A * L := hA N hNA'
  have hQbound : gramSum N ≤ M ^ 2 / 4 + C_B * (N : ℝ) := hB N hNB'
  have hN_eq : (N : ℝ) = M + 1 := by linarith
  rw [hN_eq] at hQbound
  have hLogSqBound : L ^ 2 ≤ M := hLogSq N hNL'
  set c := 2 / M with hc_def
  refine ⟨constVec N c, ?_⟩
  have h_l2 := l2_error_eq_quad_error N hN2 (constVec N c)
  rw [h_l2, dot_const N c, quad_const N c]
  have h_step1 := quadratic_bound_of_bounds M L C_A C_B (basisSum N) (gramSum N)
    hMpos hLpos hCA hCB hBbound hQbound
  have h_step2 := simplify_error_bound M L C_A C_B hMge2 hLge1 hCA hCB
  have h_step3 := ratio_flip (8 * C_A + 8 * C_B) K L M hLpos hMpos
    (by linarith) (by linarith) hLogSqBound
  linarith [h_step3 ]

/-- Bridge: the old axiom name is now a theorem. -/
theorem nb_distance_decay_axiom_bridge :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N → ∃ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≤ C / Real.log (N : ℝ) :=
  nb_distance_decay_axiom'

end
