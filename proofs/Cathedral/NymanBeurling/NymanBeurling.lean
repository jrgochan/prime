import Cathedral.Axioms
import Cathedral.NymanBeurling.Separation
import Cathedral.Assembly.GramWitness

/-!
  Cathedral/NymanBeurling/NymanBeurling.lean

  ## The Nyman-Beurling Criterion

  The full Nyman-Beurling criterion: d²_N → 0 ↔ RH.

  ### Architecture
  - Converse (d²→0 ⟹ RH): Proved in Separation.lean via contrapositive
  - Forward (RH ⟹ d²→0): Proved in GramWitness.lean via
      witness_l2_error_decay_gram → nbDistSq_le_test_vector → l2_error_eq_quad_error

  ### Axiom dependencies (ONLY 2 on the forward path!)
  - `zeta_zero_separates` (Tier 3, in Axioms.lean) — converse
  - `witness_l2_error_decay_gram` (Tier 1, in GramWitness.lean) — forward

  ### Key result
  - `nyman_beurling_iff_rh`: d²_N → 0 ↔ RH — **FULLY PROVED** from 2 axioms
-/

noncomputable section
open Complex Real MeasureTheory Set Filter

-- ════════════════════════════════════════════════
-- THE FULL BICONDITIONAL
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED!)**: The Nyman-Beurling criterion.
    d²_N → 0 ↔ RH.

    Both directions are theorems:
    - (⟸) nyman_beurling_converse (Separation.lean, 1 axiom)
    - (⟹) nyman_beurling_forward_direct (GramWitness.lean, 1 axiom)

    Total axiom count: **2** (zeta_zero_separates + witness_l2_error_decay_gram) -/
theorem nyman_beurling_iff_rh :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 < ε) ↔
    RiemannHypothesis :=
  ⟨nyman_beurling_converse,
   nyman_beurling_forward_direct⟩

end
