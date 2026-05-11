/-
  Cathedral.lean — The Front Door

  This file is the single entry point for verifying the Cathedral's
  primary exports. Import only this file to build the crown path
  without pulling in exploratory modules.

  ## Primary Exports

  1. `nyman_beurling_equivalence` (Analytic Crown)
     RH ↔ d²_N → 0 in the Báez-Duarte basis.
     Axiom footprint: 1 literature axiom (baez_duarte_forward).

  2. `rh_from_oracle` (Oracle Crown)
     RH from DD-precision GPU-certified Gram bounds.
     Axiom footprint: oracle_certificates + 2 PNT imports.

  ## Verification

  ```
  cd proofs
  lake build Cathedral
  ```

  This builds the crown path. The only warnings are
  inherited deprecations from upstream PNTA dependencies
  (not Cathedral sorry's on the primary path).

  Created: May 10, 2026
-/

import Cathedral.Assembly.MainChain
import Cathedral.Assembly.OracleCascade

/-!
## Axiom Audit

Run `#print axioms` on the primary exports to verify the
axiom footprint. The converse direction has zero custom axioms.
-/

-- ════════════════════════════════════════════════
-- CROWN PATH VERIFICATION
-- ════════════════════════════════════════════════

-- Uncomment to verify axiom footprints:
-- #print axioms Cathedral.Assembly.MainChain.nyman_beurling_equivalence
-- #print axioms Cathedral.Assembly.OracleCascade.rh_from_oracle
