/-
  Cathedral/Covariance/QuadFormIdentity.lean

  ## Quadratic Form Decomposition via Abel on the Discrete Matrix

  STRATEGY (Gemini Tactical): "Integrate First, Abel Sum Second."

  Instead of Abel-summing the continuous function f_N(x) pointwise,
  Abel-sum the DISCRETE matrix vᵀGv = Σ_{j,k} v_j v_k G_{jk}.

  For each fixed j, apply abel_summation to the k-index of:
    Σ_k v_k · G_{j,k}

  This produces boundary terms that algebraically cancel the
  divergent parts of the diagonal, leaving only the S₁/S₂/S₃-bounded
  remainder terms.

  ### Architecture (mirrors DotProductIdentity.lean)
  1. quadForm_as_double_sum: Unfold quad form into double Icc sum
  2. Apply abel_summation to the k-index for fixed j
  3. Show that boundary terms are controlled by taper vanishing
  4. Wire S₁/S₂/S₃ bounds into the Abel remainder

  April 27, 2026 — Exploration 13
-/

import Cathedral.Defs
import Cathedral.NymanBeurling.BDBridge
import Cathedral.MellinBridge.BDWeights
import Cathedral.MellinBridge.AbelSummation
import Cathedral.AbelTail.S1Decay
import Cathedral.AbelTail.S2Decay
import Cathedral.AbelTail.S3UniformBound
import Cathedral.Covariance.DotProductIdentity
import Cathedral.Vasyunin.Augmented.DiagBound

noncomputable section
open Real Matrix Finset BigOperators Cathedral.Vasyunin ArithmeticFunction

-- ═══════════════════════════════════════════════
-- §1. HELPERS: ℕ-INDEXED WEIGHT AND PRODUCT
-- ═══════════════════════════════════════════════

/-- The BD weight at a natural number k (not Fin-indexed).
    w(N,k) = -μ(k) · (1 - log(k)/log(N)) -/
def bdWeight (N k : ℕ) : ℝ :=
  -(↑(moebius k) : ℝ) * logWeight N k

/-- The Gram product: v_j · v_k · G(j,k) -/
def gramProduct (N j k : ℕ) : ℝ :=
  bdWeight N j * bdWeight N k * vasyuninGramEntry j k

-- ═══════════════════════════════════════════════
-- §2. QUADRATIC FORM AS DOUBLE ICC SUM
-- ═══════════════════════════════════════════════

/-- Unfold the Fin-indexed quadratic form into a double Icc sum.
    realQuadForm G v = Σ_{j=1}^{N-1} Σ_{k=1}^{N-1} v_j · v_k · G(j,k) -/
theorem quadForm_as_double_sum (N : ℕ) (hN : 3 ≤ N) :
    realQuadForm (Matrix.of fun (i j : Fin (N - 1)) =>
      vasyuninGramEntry (i.val + 1) (j.val + 1)) (bdMoebiusWeight N) =
    ∑ j ∈ Finset.Icc 1 (N - 1), ∑ k ∈ Finset.Icc 1 (N - 1),
      gramProduct N j k := by
  sorry

-- ═══════════════════════════════════════════════
-- §3. INNER ABEL: FIX j, ABEL SUM OVER k
-- ═══════════════════════════════════════════════

/-- For fixed j, the inner sum Σ_k v_k · G_{j,k} decomposes
    via abel_summation on k.

    The key: v_k = a(k) · f(k) where:
    - a(k) = -μ(k) (the "coefficient" for Abel)
    - f(k) = logWeight(N,k) · G(j,k) (the "smooth function")

    Abel gives:
    Σ_{k=1}^M a(k)·f(k) = A(M)·f(M) - Σ_{k=1}^{M-1} A(k)·Δf(k)

    where A(k) = Σ_{ℓ=1}^k (-μ(ℓ)) = -M(k). -/
theorem inner_sum_abel (N : ℕ) (hN : 3 ≤ N) (j : ℕ) (hj : 1 ≤ j) :
    ∑ k ∈ Finset.Icc 1 (N - 1),
      bdWeight N k * vasyuninGramEntry j k =
    partialSum (fun k => -(↑(moebius k) : ℝ)) 1 (N - 1) *
      (logWeight N (N - 1) * vasyuninGramEntry j (N - 1)) -
    ∑ k ∈ Finset.Ico 1 (N - 1),
      partialSum (fun k => -(↑(moebius k) : ℝ)) 1 k *
      (logWeight N (k + 1) * vasyuninGramEntry j (k + 1) -
       logWeight N k * vasyuninGramEntry j k) := by
  -- This is abel_summation applied with a(k)=-μ(k) and f(k)=logWeight(N,k)·G(j,k)
  have h := abel_summation (fun k => -(↑(moebius k) : ℝ))
    (fun k => logWeight N k * vasyuninGramEntry j k) 1 (N - 1) (by omega)
  -- Rewrite LHS: Σ a(k)*f(k) = Σ (-μ(k))*(logWeight*G) = Σ bdWeight*G
  convert h using 1
  apply Finset.sum_congr rfl; intro k _; unfold bdWeight; ring

-- ═══════════════════════════════════════════════
-- §4. BOUNDARY CONTROL
-- ═══════════════════════════════════════════════

/-- The boundary term for the inner Abel sum is controlled.
    The key: logWeight(N, N-1) = 1 - log(N-1)/log(N) ≈ 1/log(N) → 0.
    And partialSum = -M(N-1) = O(N^{3/4}) by Mertens. -/
theorem logWeight_at_N_minus_1 (N : ℕ) (hN : 10 ≤ N) :
    |logWeight N (N - 1)| ≤ 2 / Real.log ↑N := by
  sorry

-- ═══════════════════════════════════════════════
-- §5. GRAM ENTRY GROWTH
-- ═══════════════════════════════════════════════

/-- Diagonal Gram entry bound: G(k,k) ≈ const/k. -/
theorem gramEntry_diag_bound (k : ℕ) (hk : 1 ≤ k) :
    |vasyuninGramEntry k k| ≤ (Real.log (2 * Real.pi) + 1) / (k : ℝ) := by
  sorry

/-- Off-diagonal Gram entry bound: |G(j,k)| ≤ C·(1/j + 1/k). -/
theorem gramEntry_off_diag_bound (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hjk : j ≠ k) :
    |vasyuninGramEntry j k| ≤
    (Real.log (2 * Real.pi) + 2) / 2 * (1 / (j : ℝ) + 1 / (k : ℝ)) := by
  sorry

-- ═══════════════════════════════════════════════
-- §6. STATUS
-- ═══════════════════════════════════════════════

-- This file has:
--   5 sorry declarations (scaffolding)
--
-- The key insight from Gemini: the Abel summation on the k-index
-- of the discrete matrix produces boundary terms that cancel the
-- diagonal divergence. The S₁/S₂/S₃ machinery then bounds
-- the remaining terms.
--
-- NEXT: Prove inner_sum_abel (direct from abel_summation),
-- then wire the boundary + remainder bounds.

end
