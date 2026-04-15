import Cathedral.Axioms
import Cathedral.NymanBeurling.Separation
import Cathedral.Vasyunin.Proof.Chain

/-!
  Cathedral/NymanBeurling/NymanBeurling.lean

  ## The Nyman-Beurling Criterion

  The full Nyman-Beurling criterion: d²_N → 0 ↔ RH.

  ### Architecture
  - Converse (d²→0 ⟹ RH): Proved in Separation.lean via contrapositive
  - Forward (RH ⟹ d²→0): Proved in Chain.lean via witness bound → quadform
    divergence → algebraic bridge

  ### Axiom dependencies
  - `zeta_zero_separates` (Tier 3, in Axioms.lean) — converse
  - `algebraic_nb_bridge` (Tier 4, in Chain.lean) — forward
  - `witness_covariance_decay` (Tier 1, in WitnessAsymptotics) — forward (via chain)
  - `witness_numerator_convergence` (Tier 2, in WitnessAsymptotics) — forward (via chain)

  ### Key result
  - `nyman_beurling_iff_rh`: d²_N → 0 ↔ RH — **FULLY PROVED** from axioms
-/

noncomputable section
open Complex Real MeasureTheory Set Filter

-- ════════════════════════════════════════════════
-- THE FULL BICONDITIONAL
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED!)**: The Nyman-Beurling criterion.
    d²_N → 0 ↔ RH.

    Both directions are theorems:
    - (⟸) nyman_beurling_converse (Separation.lean)
    - (⟹) nyman_beurling_forward_from_sieve (Chain.lean) -/
theorem nyman_beurling_iff_rh :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 < ε) ↔
    RiemannHypothesis :=
  ⟨nyman_beurling_converse,
   Cathedral.Vasyunin.nyman_beurling_forward_from_sieve⟩

end
