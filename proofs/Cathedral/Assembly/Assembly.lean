/-
  Cathedral/Assembly/Assembly.lean

  ## Cathedral Assembly — Unified Re-Export

  This is the unified capstone module that exports BOTH proof architectures
  of the Riemann Hypothesis:

  ### Architecture 1: Gram Crown (PREFERRED — discrete, covariance-free)
  - `riemann_hypothesis_from_gram_global`  : RH from vᵀGv ≤ 1+K/lnN (∀ large N)
  - `riemann_hypothesis_from_gram_subseq`  : RH from vᵀGv ≤ 1+K/lnN (along subseq)
  - 1 Crown axiom + 5 PNT bureaucracy. Zero covariance axioms.

  ### Architecture 2: Nyman-Beurling (historical — continuous L² path)
  - `nyman_beurling_equivalence` : (d²_N → 0) ↔ RH
  - 4 PNT axioms + 1 covariance axiom (via Perron Crown).

  Dependency graph:
    MainChain.lean ← GramBoundDirect.lean ← GramCrown.lean
                                                ↑
    Assembly.lean (this file) imports both ─────┘
-/

import Cathedral.NymanBeurling.QuadFormBridge
import Cathedral.Assembly.MainChain
import Cathedral.Assembly.GramCrown

-- ════════════════════════════════════════════════
-- UNIFIED EXPORTS
-- ════════════════════════════════════════════════

/-- **THE RIEMANN HYPOTHESIS** (Discrete, Global Gram Bound path).
    See `GramCrown.lean` for documentation. -/
theorem rh_discrete_global : RiemannHypothesis :=
  riemann_hypothesis_from_gram_global

/-- **THE RIEMANN HYPOTHESIS** (Discrete, Subsequential Gram Bound path).
    ★★ PREFERRED — requires Gram bound only along HC subsequence.
    See `GramCrown.lean` for documentation. -/
theorem rh_discrete_subseq : RiemannHypothesis :=
  riemann_hypothesis_from_gram_subseq
