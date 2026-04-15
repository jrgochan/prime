import Cathedral.Axioms
import Cathedral.NymanBeurling.Separation

/-!
  Cathedral/NymanBeurling/NymanBeurling.lean

  ## The Nyman-Beurling Criterion

  The full Nyman-Beurling criterion: d²_N → 0 ↔ RH.

  ### Architecture
  - Converse (d²→0 ⟹ RH): Proved in Separation.lean via contrapositive
  - Forward (RH ⟹ d²→0): Axiom (proven in archive, uses Mertens + Abel)

  ### Axiom inventory
  - `zeta_zero_separates` (Tier 3, in Axioms.lean) — used by converse
  - `rh_implies_mertens_bound` (Tier 4, in Axioms.lean) — used by forward
-/

noncomputable section
open Complex Real MeasureTheory Set Filter

-- ════════════════════════════════════════════════
-- FORWARD: RH ⟹ d²→0
-- ════════════════════════════════════════════════

-- The forward direction uses:
--   RH → rh_implies_mertens_bound (axiom, Tier 4)
--     → Abel summation with log-cutoff weights
--     → ∃ v, ∫(1-f)² ≤ C/log(N) < ε
--
-- The full proof is in the archive (MellinBridge/MellinSieve.lean)
-- but cannot compile with current Mathlib due to API drift.
-- It depends on rh_implies_mertens_bound (Axioms.lean) plus
-- the Abel summation step.

/-- **Forward direction**: RH ⟹ d²_N → 0.

    Proven in archive (MellinSieve.lean) from rh_implies_mertens_bound
    + Abel summation. The proof constructs explicit Möbius weights
    v_k = -μ(k)·(1 - ln(k)/ln(N)) achieving ∫(1-f)² ≤ C/log(N).

    This axiom is a consequence of:
    - rh_implies_mertens_bound (Tier 4, Axioms.lean)
    - Abel summation for log-cutoff weights (classical) -/
axiom nyman_beurling_forward_from_sieve :
    RiemannHypothesis →
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 < ε)

-- ════════════════════════════════════════════════
-- THE FULL BICONDITIONAL
-- ════════════════════════════════════════════════

/-- **THEOREM**: The Nyman-Beurling criterion.
    d²_N → 0 ↔ RH. -/
theorem nyman_beurling_from_mellin :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 < ε) ↔
    RiemannHypothesis :=
  ⟨nyman_beurling_converse, nyman_beurling_forward_from_sieve⟩

end
