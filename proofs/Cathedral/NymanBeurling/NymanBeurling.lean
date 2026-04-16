import Cathedral.Axioms
import Cathedral.NymanBeurling.Separation
import Cathedral.NymanBeurling.BDMellin
import Cathedral.Assembly.GramWitness

/-!
  Cathedral/NymanBeurling/NymanBeurling.lean

  ## The Nyman-Beurling Criterion

  ### Current Architecture (April 15, 2026 — Post Rank-1 Mellin Miracle)

  - **Converse** (d²→0 ⟹ RH): Uses `bdLinComb` = Σ wₖ{1/(kx)} (θ ≤ 1)
    - PROVED from `bd_mellin_at_zero` (1 axiom, Rank-1 Mellin)
    - The rank-1 structure M[h_k](ρ) = 1/(k(ρ-1)) makes separation trivial

  - **Forward** (RH ⟹ d²→0): Uses `nbLinComb` = Σ wₖ{k/x} (θ > 1)
    - PROVED from `witness_l2_error_decay_gram` (1 axiom)
    - NOTE: This direction is vacuously correct for {k/x} since the
      high-frequency basis unconditionally spans L²(0,1). The true
      content is in the forward direction for {1/(kx)}, which requires
      migrating the Gram matrix infrastructure to the BD basis.

  ### Key results
  - `nyman_beurling_converse`: d²_N(BD) → 0 ⟹ RH (1 axiom)
  - `nyman_beurling_forward_direct`: RH ⟹ d²_N(HF) → 0 (1 axiom)

  ### Future work
  Unify both directions on the BD basis by migrating gramEntry from
  ∫{j/x}{k/x}dx to ∫{1/(jx)}{1/(kx)}dx, making `nyman_beurling_iff_rh`
  a true biconditional on a single basis.
-/

noncomputable section
open Complex Real MeasureTheory Set Filter

-- The converse and forward are proved in their respective files.
-- Re-export for convenience:
-- nyman_beurling_converse : from Separation.lean (uses bdLinComb)
-- nyman_beurling_forward_direct : from GramWitness.lean (uses nbLinComb)

end
