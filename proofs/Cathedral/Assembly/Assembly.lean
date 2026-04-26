/-
  Cathedral/Assembly/Assembly.lean

  ## Re-export barrel for the Assembly capstone module.

  Assembly contains the capstone theorems that wire
  the Cathedral's topic modules into final equivalences:
  - MainChain.lean       — nyman_beurling_equivalence (THE theorem)
  - PerronCrown.lean     — RH → d² → 0 via Perron-Möbius chain
  - OneCrown.lean        — One-axiom crown
  - DirectL2Crown.lean   — Direct L² crown
  - FinalDragon.lean     — Re-export facade
-/

import Cathedral.NymanBeurling.QuadFormBridge
import Cathedral.Assembly.MainChain
