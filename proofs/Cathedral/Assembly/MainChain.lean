/-
  Cathedral/Assembly/MainChain.lean

  ## The Riemann Hypothesis — Final Proof Chain

  The crown jewel: from moebius_test_bound through distance_converges_to_zero
  to riemann_hypothesis. Also contains nyman_beurling (iff characterization)
  and eigenvalue_limit_exists (unconditional).

  ```
  moebius_test_bound → nb_distance_scaling → distance_converges_to_zero
      → nyman_beurling_converse → riemann_hypothesis
  ```
-/

import Cathedral.Defs
import Cathedral.Structural
import Cathedral.Quantitative
import Cathedral.MellinBridge
import Cathedral.SelbergSieve
import Cathedral.Assembly.QuadFormBridge

noncomputable section
open Complex Real

-- ════════════════════════════════════════════════
-- TEST VECTOR BOUND
-- ════════════════════════════════════════════════

/-- **THEOREM**: Test vector bound from the constant witness. -/
theorem moebius_test_bound :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N → ∃ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≤ C / Real.log (N : ℝ) :=
  moebius_test_bound_from_selberg

-- ════════════════════════════════════════════════
-- DISTANCE SCALING
-- ════════════════════════════════════════════════

/-- **THEOREM**: d²_N ≤ C/log(N) for sufficiently large N. -/
theorem nb_distance_scaling :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N → nbDistSq' N ≤ C / Real.log (N : ℝ) := by
  obtain ⟨C, hC, N₀, hN₀, h_test⟩ := moebius_test_bound
  exact ⟨C, hC, N₀, hN₀, fun N hN => by
    obtain ⟨v, hv⟩ := h_test N hN
    have h_bridge := l2_error_eq_quad_error N (by omega) v
    have h_var := nbDistSq_le_test_vector N (by omega) v
    calc nbDistSq' N ≤ 1 - 2 * dotProduct (basisInnerProd N) v +
          realQuadForm (gramMatrix N) v := h_var
      _ = ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 := h_bridge.symm
      _ ≤ C / Real.log (N : ℝ) := hv⟩

-- ════════════════════════════════════════════════
-- LOGARITHMIC DIVERGENCE
-- ════════════════════════════════════════════════

/-- **THEOREM**: C/log(N) < ε eventually (standard calculus). -/
theorem log_grows_unboundedly (C : ℝ) (hC : 0 < C) (ε : ℝ) (hε : 0 < ε) :
    ∃ N₀ : ℕ, ∀ N : ℕ, N₀ ≤ N → C / Real.log (N : ℝ) < ε := by
  have h := tendsto_log_atTop.eventually (Filter.eventually_ge_atTop (C / ε + 1))
  rw [Filter.eventually_atTop] at h
  obtain ⟨M, hM⟩ := h
  use ⌈max M 2⌉₊
  intro N hN
  have hN_cast : (N : ℝ) ≥ max M 2 := le_trans (Nat.le_ceil _) (by exact_mod_cast hN)
  have hN_ge_M : (N : ℝ) ≥ M := le_trans (le_max_left _ _) hN_cast
  have hlog_pos : 0 < Real.log (N : ℝ) := Real.log_pos (by linarith [le_max_right M 2])
  have hlog_gt : C / ε < Real.log (N : ℝ) := by linarith [hM N hN_ge_M]
  rw [div_lt_iff₀ hlog_pos]
  have : C < ε * Real.log (N : ℝ) := by
    calc C = ε * (C / ε) := by field_simp
      _ < ε * Real.log (N : ℝ) := by nlinarith
  linarith

-- ════════════════════════════════════════════════
-- NYMAN-BEURLING HELPERS
-- ════════════════════════════════════════════════

/-- **THEOREM**: Existential L² form implies infimum form. -/
theorem existential_implies_infimum (N : ℕ) (hN : 2 ≤ N) (ε : ℝ)
    (v : Fin (N - 1) → ℝ)
    (hv : ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 < ε) :
    nbDistSq' N < ε :=
  calc nbDistSq' N ≤ 1 - 2 * dotProduct (basisInnerProd N) v +
        realQuadForm (gramMatrix N) v := nbDistSq_le_test_vector N hN v
    _ = ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 := (l2_error_eq_quad_error N hN v).symm
    _ < ε := hv

/-- **THEOREM**: Nyman-Beurling criterion: RH ⟺ d² → 0. -/
theorem nyman_beurling :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, nbDistSq' N < ε) ↔ RiemannHypothesis := by
  constructor
  · intro h
    apply nyman_beurling_converse
    intro ε hε
    obtain ⟨N₀, hN₀⟩ := h ε hε
    use max N₀ 2
    intro N hN
    have hN2 : 2 ≤ N := le_trans (le_max_right _ _) hN
    have hNn : N₀ ≤ N := le_trans (le_max_left _ _) hN
    use (gramMatrix N)⁻¹.mulVec (basisInnerProd N)
    have h_bridge := l2_error_eq_quad_error N hN2
        ((gramMatrix N)⁻¹.mulVec (basisInnerProd N))
    rw [h_bridge]
    have h_dist := hN₀ N hNn
    have h_quad := nbDistSq_as_quadform N hN2
    set c := (gramMatrix N)⁻¹.mulVec (basisInnerProd N) with hc_def
    set b := basisInnerProd N
    set G := gramMatrix N
    have h_unit : IsUnit G.det := gramMatrix_isUnit_det N hN2
    have h_Gc : G.mulVec c = b := by
      simp [hc_def, G, Matrix.mulVec_mulVec, Matrix.mul_nonsing_inv _ h_unit, Matrix.one_mulVec]
    have h_cGc : dotProduct c (G.mulVec c) = dotProduct c b := by rw [h_Gc]
    have h_quad := nbDistSq_as_quadform N hN2
    simp only [realQuadForm] at h_quad ⊢
    have h_comm : dotProduct b c = dotProduct c b := dotProduct_comm b c
    linarith [h_dist, h_cGc, h_comm]
  · intro h
    have h_exist := nyman_beurling_forward h
    intro ε hε
    obtain ⟨N₀, hN₀⟩ := h_exist ε hε
    use max N₀ 2
    intro N hN
    have hN2 : 2 ≤ N := le_trans (le_max_right _ _) hN
    have hNn : N₀ ≤ N := le_trans (le_max_left _ _) hN
    obtain ⟨v, hv⟩ := hN₀ N hNn
    exact existential_implies_infimum N hN2 ε v hv

-- ════════════════════════════════════════════════
-- THE RIEMANN HYPOTHESIS
-- ════════════════════════════════════════════════

/-- **THEOREM**: The Nyman-Beurling distance converges to zero. -/
theorem distance_converges_to_zero :
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, nbDistSq' N < ε := by
  intro ε hε
  obtain ⟨C, hC_pos, N_scale, hN_scale, h_scale⟩ := nb_distance_scaling
  obtain ⟨N_log, h_log⟩ := log_grows_unboundedly C hC_pos ε hε
  use max N_scale N_log
  intro N hN
  have h1 : N_scale ≤ N := le_trans (le_max_left _ _) hN
  have h2 : N_log ≤ N := le_trans (le_max_right _ _) hN
  calc nbDistSq' N ≤ C / Real.log (N : ℝ) := h_scale N h1
    _ < ε := h_log N h2

/-- **THE RIEMANN HYPOTHESIS** -/
theorem riemann_hypothesis : RiemannHypothesis := by
  apply nyman_beurling_converse
  intro ε hε
  obtain ⟨N₀, hN₀⟩ := distance_converges_to_zero ε hε
  use max N₀ 2
  intro N hN
  have hN2 : 2 ≤ N := le_trans (le_max_right _ _) hN
  have hNN : N₀ ≤ N := le_trans (le_max_left _ _) hN
  use (gramMatrix N)⁻¹.mulVec (basisInnerProd N)
  have h_bridge := l2_error_eq_quad_error N hN2
      ((gramMatrix N)⁻¹.mulVec (basisInnerProd N))
  rw [h_bridge]
  have h_dist := hN₀ N hNN
  set c := (gramMatrix N)⁻¹.mulVec (basisInnerProd N) with hc_def
  set b := basisInnerProd N
  set G := gramMatrix N
  have h_unit : IsUnit G.det := gramMatrix_isUnit_det N hN2
  have h_Gc : G.mulVec c = b := by
    simp [hc_def, G, Matrix.mulVec_mulVec, Matrix.mul_nonsing_inv _ h_unit, Matrix.one_mulVec]
  have h_cGc : dotProduct c (G.mulVec c) = dotProduct c b := by rw [h_Gc]
  have h_quad := nbDistSq_as_quadform N hN2
  simp only [realQuadForm] at h_quad ⊢
  have h_comm : dotProduct b c = dotProduct c b := dotProduct_comm b c
  linarith [h_dist, h_cGc, h_comm]

-- ════════════════════════════════════════════════
-- UNCONDITIONAL RESULTS
-- ════════════════════════════════════════════════

/-- The eigenvalue limit exists (unconditional). -/
theorem eigenvalue_limit_exists :
    ∃ L : ℝ, 0 ≤ L ∧
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, |lambdaMin N - L| < ε := by
  set f := fun n => lambdaMin (n + 2) with hf_def
  have hanti : Antitone f := lambdaMin_shifted_antitone
  have hbdd : BddBelow (Set.range f) := by
    use 0; intro x ⟨n, hn⟩; rw [← hn]
    exact le_of_lt (lambdaMin_pos (n + 2) (by omega))
  have htend := tendsto_atTop_ciInf hanti hbdd
  set L := ⨅ n, f n with hL_def
  have hL_nonneg : 0 ≤ L := by
    apply le_ciInf; intro n
    exact le_of_lt (lambdaMin_pos (n + 2) (by omega))
  rw [Metric.tendsto_atTop] at htend
  refine ⟨L, hL_nonneg, fun ε hε => ?_⟩
  obtain ⟨a, ha⟩ := htend ε hε
  refine ⟨a + 2, fun N hN => ?_⟩
  have hNa : a ≤ N - 2 := by omega
  have hfN : f (N - 2) = lambdaMin N := by
    simp [hf_def]; congr 1; omega
  have := ha (N - 2) hNa
  rw [hfN, Real.dist_eq] at this
  exact this

end

-- ════════════════════════════════════════════════
-- AXIOM AUDIT
-- ════════════════════════════════════════════════
#print axioms riemann_hypothesis
