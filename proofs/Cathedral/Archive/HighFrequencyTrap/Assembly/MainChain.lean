/-
  Cathedral/Assembly/MainChain.lean

  ## The Nyman-Beurling Equivalence — Cathedral Crown

  After the Great Purge (April 6, 2026), the constant witness path was
  amputated. The Cathedral now rests on two pillars:

  - **Pillar I (Converse):** d² → 0 ⟹ RH, via infinite-dimensional
    L² duality through the Mellin Bridge.
  - **Pillar II (Forward):** RH ⟹ d² → 0, via the Sieve Engine
    (Möbius weights annihilating the Θ(N²) off-diagonal mass).

  The Capstone: Nyman-Beurling iff characterization.

  Unconditional results preserved:
  - `nyman_beurling` (the iff)
  - `eigenvalue_limit_exists`
  - `log_grows_unboundedly` (standard calculus)
-/

import Cathedral.Defs
import Cathedral.Archive.HighFrequencyTrap.Structural.Structural
import Cathedral.Archive.HighFrequencyTrap.MellinBridge.Basic
import Cathedral.Archive.HighFrequencyTrap.Assembly.QuadFormBridge

noncomputable section
open Complex Real

-- ════════════════════════════════════════════════
-- PILLAR I: THE CONVERSE (L² Duality)
-- ════════════════════════════════════════════════

/-- **PILLAR I**: If d²_N → 0, then RH is true.
    The proof flows entirely through infinite-dimensional L² duality
    via the Mellin Bridge. This is fully proved from axioms in
    `MellinBridge/Separation.lean`. -/
theorem distance_converges_to_zero_implies_rh :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, nbDistSq' N < ε) →
    RiemannHypothesis := by
  intro h
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

-- ════════════════════════════════════════════════
-- PILLAR II: THE FORWARD DIRECTION (The Sieve Engine)
-- ════════════════════════════════════════════════

/-- **PILLAR II** (PROVED): If RH is true, the Möbius weights
    drive d² → 0. Formerly an axiom; now derived from
    `nyman_beurling_forward_from_sieve` + `existential_implies_infimum`. -/
theorem rh_implies_distance_converges_to_zero :
    RiemannHypothesis →
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, nbDistSq' N < ε) := by
  intro hRH ε hε
  obtain ⟨N₀, hN₀⟩ := nyman_beurling_forward_from_sieve hRH ε hε
  use max N₀ 2
  intro N hN
  have hN₀_le : N₀ ≤ N := le_trans (le_max_left _ _) hN
  have hN2 : 2 ≤ N := le_trans (le_max_right _ _) hN
  obtain ⟨v, hv⟩ := hN₀ N hN₀_le
  exact existential_implies_infimum N hN2 ε v hv

-- ════════════════════════════════════════════════
-- LOGARITHMIC DIVERGENCE (STANDARD CALCULUS)
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
-- THE NYMAN-BEURLING EQUIVALENCE (The Capstone)
-- ════════════════════════════════════════════════

/-- **THE NYMAN-BEURLING EQUIVALENCE** (BOTH DIRECTIONS PROVED)
    The Riemann Hypothesis holds if and only if the Nyman-Beurling
    distance d²_N converges to zero.

    - Forward: `rh_implies_distance_converges_to_zero` (PROVED via Mertens bypass)
    - Converse: `distance_converges_to_zero_implies_rh` (PROVED via Mellin Bridge) -/
theorem nyman_beurling_equivalence :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, nbDistSq' N < ε) ↔ RiemannHypothesis :=
  ⟨distance_converges_to_zero_implies_rh, rh_implies_distance_converges_to_zero⟩

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
#print axioms nyman_beurling_equivalence
