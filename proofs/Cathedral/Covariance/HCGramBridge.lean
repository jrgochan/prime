/-
  Cathedral/Covariance/HCGramBridge.lean

  ## HC-Gram Bridge: Connecting HC Numbers to the Gram Bound

  This file provides the bridge between the HC number formalization
  (HighlyComposite.lean) and the subsequential Gram bound axiom
  (GramBoundDirect.lean).

  ### Architecture

  ```
  HighlyComposite.lean                    GramBoundDirect.lean
  ┌─────────────────┐                    ┌─────────────────────┐
  │ hcSubseq        │──(HC-specific)───→ │ gram_form_upper_    │
  │ hcSubseq_isHC   │   Gram bound       │ bound_subseq        │
  │ hcSubseq_tendsto│                    │                     │
  └─────────────────┘                    │ gram_bound_subseq_  │
                                         │ implies_rh (PROVED) │
                                         └─────────────────────┘
  ```

  The KEY missing piece (axiom `hc_gram_bound`) is:
    For all HC numbers N ≥ 3:
      v_N^T G_N v_N ≤ 1 + K / ln(N)

  This is where the arithmetic structure of HC numbers must be exploited:
  - HC numbers have divisors: every small prime divides them
  - Mertens' product: Π_{p|N}(1-1/p) ~ e^{-γ}/lnN at HC numbers
  - GCD partition: the Euler product over primes dividing N controls vᵀGv

  Created: May 12, 2026 — Exploration 36
  Status: Structural bridge (1 axiom: hc_gram_bound)
-/

import Cathedral.Covariance.HighlyComposite
import Cathedral.Vasyunin.Proof.GramBoundDirect

noncomputable section
open Filter Cathedral.Vasyunin Real Matrix

namespace Cathedral.Covariance

-- ════════════════════════════════════════════════
-- §1. THE HC-SPECIFIC GRAM BOUND (THE CORE GAP)
-- ════════════════════════════════════════════════

/-- **AXIOM (THE CORE GAP)**: The Gram form bound holds at HC numbers.

    For all HC numbers N ≥ 3:
      vᵀGv ≤ 1 + K / ln(N)

    where v is the log-cutoff Möbius witness.

    **Why this should be true** (from the GCD path):
    1. vᵀGv = Σ_{d|N!} R₂(d) via GCD partition (PROVED)
    2. R₂(d) = Π_{p|d} (1 - 1/p) via Euler product (PROVED)
    3. At HC numbers, the dominant stratum d=1 gives R₂(1) = 1
    4. The correction Σ_{d≥2} R₂(d) ≤ K/ln(N) by Mertens' product
    5. Sum rule: Σ R₂(d) → 1, so the correction → 0

    **Numerical evidence** (GPU-certified, HC Gram Oracle v2):
      N=2520:  vᵀGv = 0.6446, gap = 0.3554, gap·lnN = 2.79
      N=5040:  vᵀGv = 0.6705, gap = 0.3295, gap·lnN = 2.81
      N=10080: vᵀGv = 0.6928, gap = 0.3072, gap·lnN = 2.83
      N=55440: vᵀGv = 0.7367, gap = 0.2633, gap·lnN = 2.87

    In fact vᵀGv < 1 at ALL tested HC numbers (K = 0 suffices!),
    but we state the weaker bound with K > 0 for robustness. -/
axiom hc_gram_bound :
    ∃ K : ℝ, K > 0 ∧
    ∀ N : ℕ, IsHighlyComposite N → N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninGramMatrix N).mulVec (logCutoffWitness N)) ≤
        1 + K / Real.log ↑N

-- ════════════════════════════════════════════════
-- §2. HC GRAM BOUND → SUBSEQUENTIAL GRAM BOUND
-- ════════════════════════════════════════════════

/-- **THEOREM**: The HC-specific Gram bound implies the generic
    subsequential Gram bound (which itself implies RH, PROVED).

    This is the bridge: hc_gram_bound → gram_form_upper_bound_subseq.
    The HC subsequence from HighlyComposite.lean provides the witness. -/
theorem hc_gram_implies_subseq_gram (h : ∃ K : ℝ, K > 0 ∧
    ∀ N : ℕ, IsHighlyComposite N → N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninGramMatrix N).mulVec (logCutoffWitness N)) ≤
        1 + K / Real.log ↑N) :
    ∃ K_G : ℝ, K_G > 0 ∧
    ∃ (Ns : ℕ → ℕ), Tendsto Ns atTop atTop ∧
    ∀ m : ℕ, Ns m ≥ 3 →
      dotProduct (logCutoffWitness (Ns m))
        ((vasyuninGramMatrix (Ns m)).mulVec (logCutoffWitness (Ns m))) ≤
        1 + K_G / Real.log ↑(Ns m) := by
  obtain ⟨K, hK_pos, h_bound⟩ := h
  exact ⟨K, hK_pos, hcSubseq, hcSubseq_tendsto, fun m hm =>
    h_bound (hcSubseq m) (hcSubseq_isHC m) hm⟩

/-- **COROLLARY**: The HC Gram bound implies the Riemann Hypothesis. -/
theorem hc_gram_bound_implies_rh :
    (∃ K : ℝ, K > 0 ∧
    ∀ N : ℕ, IsHighlyComposite N → N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninGramMatrix N).mulVec (logCutoffWitness N)) ≤
        1 + K / Real.log ↑N) →
    RiemannHypothesis := by
  intro h
  exact Cathedral.Vasyunin.gram_bound_subseq_implies_rh (hc_gram_implies_subseq_gram h)

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

/-!
## Audit

### Sorry: 0
### Axioms: 1
- `hc_gram_bound`: The HC-specific Gram bound (THE CORE GAP)

### Architecture (complete proof chain):
```
  hc_gram_bound (AXIOM — the only gap)
       ↓
  hc_gram_implies_subseq_gram (PROVED)
       ↓
  gram_bound_subseq_implies_rh (PROVED, GramBoundDirect.lean)
       ↓
  RiemannHypothesis
```

### Proof strategy for hc_gram_bound:
1. **GCD expansion**: vᵀGv = Σ_d R₂(d) (TaperDecomposition + GCDPartition)
2. **Euler product**: R₂(d) = Π_{p|d}(1-1/p) (EulerProduct.lean)
3. **HC structure**: N divisible by all primes ≤ N^{1/loglogN}
4. **Mertens' 3rd**: Π_{p≤x}(1-1/p) ~ e^{-γ}/ln(x) (EulerProduct.lean, 1 sorry)
5. **Assembly**: Sum over strata converges to 1, rate O(1/lnN)

This reduces the Riemann Hypothesis to a SINGLE arithmetic inequality
about the divisor structure of highly composite numbers.
-/

end Cathedral.Covariance
