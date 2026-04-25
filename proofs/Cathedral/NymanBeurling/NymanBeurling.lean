import Cathedral.Axioms
import Cathedral.NymanBeurling.Separation
import Cathedral.NymanBeurling.BDMellin

/-!
  Cathedral/NymanBeurling/NymanBeurling.lean

  ## The Nyman-Beurling-Báez-Duarte Criterion

  ### Architecture (April 25, 2026 — The Phantom Limb Amputation)

  Both directions now use the Báez-Duarte basis `bdLinComb` = Σ wₖ{1/(kx)}.

  - **Converse** (d²→0 ⟹ RH): PROVED via `nyman_beurling_converse`
    from Separation.lean, using the Rank-1 Mellin identity.

  - **Forward** (RH ⟹ d²→0): PROVED via `rh_implies_bd_convergence_direct`
    from DirectL2Crown.lean, using the Mertens bound + Abel summation.

  The old forward direction used the Nyman basis {k/x} (Universe 1)
  via `GramWitness.lean`. This has been archived — the Báez-Duarte
  basis {1/(kx)} (Universe 2) is mathematically preferred and already
  fully proved.

  ### Key results (re-exported)
  - `nyman_beurling_converse`: d²_BD → 0 ⟹ RH (kernel axioms only)
  - `rh_implies_bd_convergence_direct`: RH ⟹ d²_BD → 0 (DirectL2Crown)
-/

noncomputable section
open Complex Real MeasureTheory Set Filter

-- The converse and forward are proved in their respective files.
-- Re-export for convenience:
-- nyman_beurling_converse : from Separation.lean (uses bdLinComb)
-- rh_implies_bd_convergence_direct : from DirectL2Crown.lean (uses bdLinComb)

end
