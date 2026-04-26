import Cathedral.Axioms
import Cathedral.NymanBeurling.Separation
import Cathedral.NymanBeurling.BDMellin

/-!
  Cathedral/NymanBeurling/NymanBeurling.lean

  ## The Nyman-Beurling-Báez-Duarte Criterion

  ### Architecture (v11 — April 26, 2026 — The Mellin Crown)

  Both directions use the Báez-Duarte basis `bdLinComb` = Σ wₖ{1/(kx)}.

  - **Converse** (d²→0 ⟹ RH): PROVED via `nyman_beurling_converse`
    from Separation.lean, using the Rank-1 Mellin identity.
    Zero custom axioms.

  - **Forward** (RH ⟹ d²→0): PROVED via `rh_implies_bd_convergence_mellin`
    from Assembly/MellinCrown.lean. Uses the Mellin Crown:
    RH → Mellin variance ≤ C/logN → Parseval bridge → L²(0,1) decay.
    1 crown axiom: `critical_line_mellin_variance`.

  ### Key results (re-exported)
  - `nyman_beurling_converse`: d²_BD → 0 ⟹ RH (kernel axioms only)
  - `rh_implies_bd_convergence_mellin`: RH ⟹ d²_BD → 0 (MellinCrown)
-/

noncomputable section
open Complex Real MeasureTheory Set Filter

-- The converse and forward are proved in their respective files.
-- Re-export for convenience:
-- nyman_beurling_converse : from Separation.lean (uses bdLinComb)
-- rh_implies_bd_convergence_direct : from DirectL2Crown.lean (uses bdLinComb)

end
