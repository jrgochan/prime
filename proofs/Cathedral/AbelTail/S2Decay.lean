/-
  Cathedral/AbelTail/S2Decay.lean

  ## S₂ Decay: |S₂(N) + 1| ≤ C₂·N^{-1/4}·log(N)

  Bounds the log-weighted PNT sub-sum:
    S₂(N) = Σ_{k=1}^N μ(k)·log(k)/k

  Architecture:
  1. log_weighted_rpow_54_tail (LogTailBound.lean):
     Σ k^{-5/4}·(log(k)+1) ≤ (4·log(N)+24)·N^{-1/4}
  2. finite_abel_s2_diff: Abel bound with M-INDEPENDENT interior
  3. s2_decay: limit argument (same as proved s1_decay)

  Dependencies: S1Decay, LogTailBound, DiscreteProductRule
-/

import Cathedral.AbelTail.S1Decay
import Cathedral.AbelTail.LogTailBound

noncomputable section
open Real Finset BigOperators

-- ════════════════════════════════════════════════
-- §1. DEFINITION
-- ════════════════════════════════════════════════

/-- S₂(M) = Σ_{k=1}^M μ(k)·log(k)/k (matching FinalDragon.lean). -/
def S₂_at (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) *
    Real.log (k : ℝ) / (k : ℝ)

-- ════════════════════════════════════════════════
-- §2. FINITE ABEL BOUND (M-INDEPENDENT)
-- ════════════════════════════════════════════════

/-- **Abel bound for S₂ on [N+1, M] — M-INDEPENDENT interior.**

    Same structure as the PROVED finite_abel_s1_diff but with:
    - f(k) = log(k)/k instead of 1/k
    - |Δf| ≤ (log(k)+1)/k² [from s2_discrete_diff_bound, PROVED]

    Interior ≤ C_m · (7·log(N)+20) · N^{-1/4}
             ≤ 27 · C_m · N^{-1/4} · log(N)  [for N ≥ 2] -/
theorem finite_abel_s2_diff
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (N M : ℕ) (hN : 2 ≤ N) (hM : N + 1 ≤ M) :
    |S₂_at M - S₂_at N| ≤
      C_m * ((M : ℝ) ^ (-(1:ℝ)/4) * Real.log (M : ℝ) +
             (N : ℝ) ^ ((3:ℝ)/4) * Real.log (M : ℝ) / (M : ℝ)) +
      C_m * 27 * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := by
  -- Structure identical to finite_abel_s1_diff (PROVED, 150 lines).
  -- Key difference: interior uses log_weighted_rpow_54_tail from LogTailBound.lean.
  sorry

-- ════════════════════════════════════════════════
-- §3. S₂ DECAY
-- ════════════════════════════════════════════════

/-- **S₂ decay via limit + Abel (same architecture as proved s1_decay).**
    |S₂(N)+1| ≤ C₂·N^{-1/4}·log(N) for all N ≥ 2.

    For each N ≥ 2:
    1. From PNT₂ (S₂ → -1), choose M ≥ N+1 with |S₂(M)-(-1)| < N^{-1/4}·log(N)
    2. Triangle: |S₂(N)-(-1)| ≤ |S₂(M)-(-1)| + |S₂(M)-S₂(N)|
    3. |S₂(M)-(-1)| < N^{-1/4}·log(N) (by choice of M)
    4. |S₂(M)-S₂(N)| ≤  ... (from finite_abel_s2_diff)
    5. Total: |S₂(N)-(-1)| ≤ C₂ · N^{-1/4} · log(N)

    C₂ = 1 + 28·C_m. Depends on finite_abel_s2_diff. -/
theorem s2_decay
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (hPNT₂ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        Real.log (k : ℝ) / (k : ℝ))
      Filter.atTop (nhds (-1))) :
    ∃ C₂ : ℝ, C₂ > 0 ∧ ∀ N : ℕ, 2 ≤ N →
      |S₂_at N - (-1)| ≤ C₂ * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := by
  -- Depends on finite_abel_s2_diff for the M-independent bound.
  -- Same limit argument as s1_decay.
  sorry

end
