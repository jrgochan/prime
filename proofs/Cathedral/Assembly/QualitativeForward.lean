/-
  Cathedral/Assembly/QualitativeForward.lean

  ## ATTEMPT: PNT → d² → 0 → RH (Unconditional Forward)

  If this compiles with zero sorry, it would prove the Riemann Hypothesis!
  (Because PNT is unconditionally true.)

  The forward direction decomposes as:
    d² = (1 - bᵀw)² + wᵀCw

  where w = bdMoebiusWeight, b = mean vector, C = covariance matrix.

  From PNT: bᵀw → 1, so (1-bᵀw)² → 0.
  The gap: does wᵀCw → 0 from PNT alone?

  This file explores what's provable unconditionally.
-/

import Cathedral.Defs
import Cathedral.NymanBeurling.BDMellin
import Cathedral.AbelTail.S1Decay
import Cathedral.Covariance.DotProductBound
import Cathedral.Covariance.GramFormProof
import Cathedral.PNT.AbelMean

noncomputable section
open Real Matrix Finset MeasureTheory Filter Cathedral.Vasyunin ArithmeticFunction

-- ═══════════════════════════════════════════════
-- §1. WHAT WE HAVE UNCONDITIONALLY
-- ═══════════════════════════════════════════════

-- PROVED (graduated from axiom):
-- pnt_mu_div_k : S₁ → 0

-- PNT AXIOMS (unconditional, from PrimeNumberTheoremAnd):
-- pnt_mu_log_div_k : S₂ → -1

-- ═══════════════════════════════════════════════
-- §2. THE QUALITATIVE FORWARD PROOF (attempt)
-- ═══════════════════════════════════════════════

/-- **UNCONDITIONAL FORWARD**: PNT → d² → 0.

    If proved, combined with nyman_beurling_converse (PROVED, zero sorry),
    this gives an unconditional proof of the Riemann Hypothesis.

    The attempt: use the PROVED `mertens_implies_l2_decay_34` with
    a Mertens bound hypothesis. The question is whether we can provide
    the x^{3/4} Mertens bound unconditionally.

    STATUS: This theorem statement is CORRECT. The proof requires
    providing |M(x)| ≤ C·x^{3/4} unconditionally, which is equivalent
    to showing ζ(s) has no zeros with Re(s) > 3/4 — which is itself
    a consequence of RH and NOT known to follow from PNT alone.

    CONCLUSION: The gap between PNT and RH is precisely the
    Mertens exponent: PNT gives M(x) = o(x) [exponent 1],
    RH gives M(x) = O(x^{1/2+ε}) [exponent 1/2+ε].
    We need exponent ≤ 3/4 for the forward direction.

    This is NOT a bug in the architecture — it IS the mathematics.
    The Nyman-Beurling criterion is an EQUIVALENCE, not a one-way
    implication. The forward direction genuinely requires RH-strength
    input (or something close to it). -/
theorem pnt_implies_bd_convergence :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε) := by
  -- To use mertens_implies_l2_decay_34, we need x^{3/4} Mertens.
  -- The PNT gives |M(x)| ≤ C·x·exp(-c·(logx)^{1/10}), which is
  -- weaker than x^{3/4} for large x.
  --
  -- The honest gap: we cannot derive |M(x)| ≤ C·x^{3/4} from PNT alone.
  -- This bound requires the Riemann Hypothesis (or a strong zero-free region).
  --
  -- If this sorry could be eliminated, RH would follow immediately
  -- from the PROVED nyman_beurling_converse.
  sorry

/-- **THE DREAM**: If pnt_implies_bd_convergence were proved,
    RH would follow unconditionally. -/
theorem rh_from_pnt (h : ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀,
    ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε) :
    RiemannHypothesis :=
  nyman_beurling_converse h

-- ═══════════════════════════════════════════════
-- §3. THE PRECISE GAP
-- ═══════════════════════════════════════════════

/-!
## The Mathematics of the Gap

The Nyman-Beurling equivalence is:
  RH ↔ d²_N → 0

The forward direction (RH → d²→0) works because:
  RH → |M(x)| = O(x^{1/2+ε}) → |M(x)| ≤ C·x^{3/4}
  → S₁ decays at rate N^{-1/4}
  → dot product bᵀw ≈ 1 at rate 1/logN
  → gram form wᵀGw ≈ 1 at rate 1/logN
  → d² ≤ C/logN → 0

The unconditional PNT gives:
  |M(x)| ≤ C·x·exp(-c·(logx)^{1/10})

This is weaker than x^{3/4} because:
  x·exp(-c·(logx)^{1/10}) > x^{3/4} for large x

(The sub-exponential exp(-c·(logx)^{1/10}) decays slower than x^{-1/4}.)

**The gap is the Mertens exponent**:
  | Source       | Bound          | Exponent | d²→0? |
  |-------------|----------------|----------|-------|
  | PNT (uncond)| M(x) = o(x)   | 1-ε      | ❌     |
  | Zero-free   | M(x)·exp(...)  | ~1       | ❌     |
  | **x^{3/4}** | **M(x)=O(x^{3/4})** | **3/4** | **✅** |
  | Density Hyp | M(x)=O(x^{1/2+ε}) | 1/2+ε | ✅   |
  | RH          | M(x)=O(x^{1/2+ε}) | 1/2+ε | ✅   |

The x^{3/4} bound sits precisely at the threshold where the
Abel summation machinery produces convergent L² errors.

**This is NOT a limitation of our proof** — it IS the mathematics.
The Nyman-Beurling criterion encodes RH, so the forward direction
must inherently use RH-strength information.
-/

end
