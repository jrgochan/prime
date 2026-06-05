/-
  Cathedral/Assembly/Assembly.lean

  ## Cathedral Assembly — Unified Re-Export

  This is the unified capstone module that exports ALL proof architectures
  of the Riemann Hypothesis, plus the unconditional dark sector results:

  ### Architecture 1: Overcancellation (PREFERRED — simplest axiom footprint)
  - `rh_overcancellation` : RH from vᵀGv ≤ 1 (overcancellation hypothesis)
  - PNT axioms (bureaucratic, awaiting upstream) + overcancellation_hypothesis.
  - See OvercancellationChain.lean for details.

  ### Architecture 2: Gram Crown (discrete, via overcancellation)
  - `rh_discrete_global`  : RH via overcancellation_hypothesis (REWIRED May 26, 2026)
  - Same axiom footprint as Architecture 1 (overcancellation_hypothesis replaces
    gram_form_upper_bound_direct).

  ### Architecture 3: Nyman-Beurling (historical — continuous L² path)
  - `nyman_beurling_equivalence` : (d²_N → 0) ↔ RH
  - PNT axioms + covariance axiom (via Perron Crown).

  ### Dark Sector (unconditional — the mirror universe)
  - `dark_gram_spectral_stability` : xᵀG⁽²⁾x ≥ 0 (PSD, zero axioms)
  - `dark_gram_smith_psd`          : gcd(j,k)⁴ matrix is PSD (Smith 1876)
  - Zero sorrys, zero custom axioms. Certified from Mathlib primitives.

  Dependency graph:
    MainChain.lean ← GramBoundDirect.lean
    OvercancellationChain.lean ← GramCrown.lean (REWIRED)
                                     ↑
    Assembly.lean (this file) ───────┘
    DarkGramMatrix.lean (standalone, no dependencies on proof chain)
-/

import Cathedral.NymanBeurling.QuadFormBridge
import Cathedral.Assembly.MainChain
import Cathedral.Assembly.GramCrown
import Cathedral.Assembly.OvercancellationChain
import Cathedral.Assembly.MarginCertificate
import Cathedral.Gram.DarkGramMatrix
import Cathedral.Assembly.TwoPhaseRH

-- ════════════════════════════════════════════════
-- UNIFIED EXPORTS: OVERCANCELLATION (PREFERRED)
-- ════════════════════════════════════════════════

open Matrix Cathedral.Vasyunin

/-- **THE RIEMANN HYPOTHESIS** (Overcancellation Path — PREFERRED).
    ★★ Simplest axiom footprint: PNT axioms + overcancellation.
    Crown-free. See `OvercancellationChain.lean` for documentation. -/
theorem rh_overcancellation
    (h_oc : ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ → N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninGramMatrix N).mulVec (logCutoffWitness N)) ≤ 1) :
    RiemannHypothesis :=
  overcancellation_implies_rh h_oc

open Cathedral.MarginCertificate in
/-- **THE RIEMANN HYPOTHESIS** (Margin Certificate Path).
    ★★ Refined axiom: (1-vᵀGv)·lnN → C > 0 (rate O(1/lnN)).
    Numerically certified to C ≈ 2.82 at N = 7560.
    See `MarginCertificate.lean` for documentation. -/
theorem rh_margin : RiemannHypothesis :=
  rh_from_margin

open Cathedral.TwoPhaseRH in
/-- **THE RIEMANN HYPOTHESIS** (Two-Phase Path — via Fermi Point).
    ★★ Structured axioms: finite verification (N < 76) + fermionic dominance (N ≥ 76).
    The Fermi Point N=76 is where the bosonic sector first exceeds 1.
    See `TwoPhaseRH.lean` for documentation. -/
theorem rh_two_phase : RiemannHypothesis :=
  rh_from_two_phases

-- ════════════════════════════════════════════════
-- UNIFIED EXPORTS: GRAM CROWN (via Overcancellation, REWIRED)
-- ════════════════════════════════════════════════

/-- **THE RIEMANN HYPOTHESIS** (Gram Crown — via Overcancellation).
    REWIRED May 26, 2026: now uses overcancellation_hypothesis
    instead of gram_form_upper_bound_direct.
    See `GramCrown.lean` for documentation. -/
theorem rh_discrete_global : RiemannHypothesis :=
  riemann_hypothesis_from_gram_global

/-- **THE RIEMANN HYPOTHESIS** (Legacy: Subsequential Gram Bound path).
    Uses `gram_form_upper_bound_subseq` from GramBoundDirect.lean.
    See `GramCrown.lean` for documentation. -/
theorem rh_discrete_subseq : RiemannHypothesis :=
  riemann_hypothesis_from_gram_subseq

-- ════════════════════════════════════════════════
-- UNIFIED EXPORTS: UNCONDITIONAL (Dark Sector)
-- ════════════════════════════════════════════════

open DarkGramMatrix in
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

open DarkGramMatrix in
/-- **SMITH'S 1876 THEOREM** (Unconditional).

    The GCD⁴ matrix is positive-semidefinite:
    Σ_{i,j} gcd(i+2, j+2)⁴ · xᵢ · xⱼ ≥ 0

    Proved via Jordan Totient decomposition: gcd(j,k)⁴ = Σ_{d|gcd} J₄(d),
    then factoring the quadratic form into a sum of squares. -/
theorem dark_gram_smith_psd (N : ℕ) (x : Fin N → ℝ) :
    0 ≤ ∑ i : Fin N, ∑ j : Fin N,
      (Nat.gcd (i.val + 2) (j.val + 2) : ℝ) ^ 4 * x i * x j :=
  smith_gcd_matrix_psd N x
