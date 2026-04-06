/-
  Cathedral/Assembly.lean

  ## Re-export barrel for backwards compatibility.

  Assembly is split into:
  - Assembly/DropAssembly.lean  — algebraic drop bounds (not on critical path)
  - Assembly/QuadFormBridge.lean — variational principle & NB distance structure
  - Assembly/MainChain.lean     — THE RIEMANN HYPOTHESIS
-/

import Cathedral.Assembly.DropAssembly
import Cathedral.Assembly.QuadFormBridge
import Cathedral.Assembly.MainChain
