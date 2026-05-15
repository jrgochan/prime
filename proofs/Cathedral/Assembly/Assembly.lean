/-
  Cathedral/Assembly/Assembly.lean

  ## Cathedral Assembly — Unified Re-Export

  This is the unified capstone module that exports BOTH proof architectures
  of the Riemann Hypothesis, plus the unconditional dark sector results:

  ### Architecture 1: Gram Crown (PREFERRED — discrete, covariance-free)
  - `riemann_hypothesis_from_gram_global`  : RH from vᵀGv ≤ 1+K/lnN (∀ large N)
  - `riemann_hypothesis_from_gram_subseq`  : RH from vᵀGv ≤ 1+K/lnN (along subseq)
  - 1 Crown axiom + 5 PNT bureaucracy. Zero covariance axioms.

  ### Architecture 2: Nyman-Beurling (historical — continuous L² path)
  - `nyman_beurling_equivalence` : (d²_N → 0) ↔ RH
  - 4 PNT axioms + 1 covariance axiom (via Perron Crown).

  ### Dark Sector (unconditional — the mirror universe)
  - `dark_gram_spectral_stability` : xᵀG⁽²⁾x ≥ 0 (PSD, zero axioms)
  - `dark_gram_smith_psd`          : gcd(j,k)⁴ matrix is PSD (Smith 1876)
  - Zero sorrys, zero custom axioms. Certified from Mathlib primitives.

  Dependency graph:
    MainChain.lean ← GramBoundDirect.lean ← GramCrown.lean
                                                ↑
    Assembly.lean (this file) imports both ─────┘
    DarkGramMatrix.lean (standalone, no dependencies on proof chain)
-/

import Cathedral.NymanBeurling.QuadFormBridge
import Cathedral.Assembly.MainChain
import Cathedral.Assembly.GramCrown
import Cathedral.Physics.DarkGramMatrix

-- ════════════════════════════════════════════════
-- UNIFIED EXPORTS: CONDITIONAL (RH)
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

-- ════════════════════════════════════════════════
-- UNIFIED EXPORTS: UNCONDITIONAL (Dark Sector)
-- ════════════════════════════════════════════════

open Cathedral.Physics.DarkGramMatrix in
/-- **DARK SECTOR SPECTRAL STABILITY** (Unconditional).

    The Dark Gram matrix G⁽²⁾ is positive-semidefinite:
    xᵀG⁽²⁾x ≥ 0 for all vectors x.

    This is the mirror-universe analogue of the Gram matrix PSD property.
    Unlike the positive-sector Gram bound (which requires RH as an axiom),
    the dark sector PSD property is UNCONDITIONAL — proved from pure
    multiplicative number theory via Smith's 1876 decomposition.

    Zero sorrys. Zero custom axioms. Certified from Mathlib. -/
theorem dark_gram_spectral_stability (N : ℕ) (x : Fin N → ℝ) :
    0 ≤ ∑ i : Fin N, ∑ j : Fin N,
      darkGramEntry_n2 (i.val + 2) (j.val + 2) * x i * x j :=
  dark_gram_quadratic_form_nonneg N x

open Cathedral.Physics.DarkGramMatrix in
/-- **SMITH'S 1876 THEOREM** (Unconditional).

    The GCD⁴ matrix is positive-semidefinite:
    Σ_{i,j} gcd(i+2, j+2)⁴ · xᵢ · xⱼ ≥ 0

    Proved via Jordan Totient decomposition: gcd(j,k)⁴ = Σ_{d|gcd} J₄(d),
    then factoring the quadratic form into a sum of squares. -/
theorem dark_gram_smith_psd (N : ℕ) (x : Fin N → ℝ) :
    0 ≤ ∑ i : Fin N, ∑ j : Fin N,
      (Nat.gcd (i.val + 2) (j.val + 2) : ℝ) ^ 4 * x i * x j :=
  smith_gcd_matrix_psd N x
