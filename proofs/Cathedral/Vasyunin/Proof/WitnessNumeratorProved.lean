/-
  Cathedral/Vasyunin/Proof/WitnessNumeratorProved.lean

  ## Graduation of witness_numerator_convergence

  Proves bᵀv → 1 as a THEOREM from the PNT axioms:
    - pnt_mu_div_k:       Σ μ(k)/k → 0
    - pnt_mu_log_div_k:   Σ μ(k)·ln(k)/k → -1
    - pnt_mu_log_sq_div_k: Σ μ(k)·ln²(k)/k → -2γ

  Status: GRADUATED 🎓 (May 7, 2026)
  Dependencies: pnt_mu_div_k, pnt_mu_log_div_k, pnt_mu_log_sq_div_k
-/

import Cathedral.PNT.AbelMean
import Cathedral.Vasyunin.Augmented.Rayleigh

set_option maxHeartbeats 4800000

noncomputable section
open Real Matrix Finset Filter
open Cathedral.Vasyunin

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- §1. PNT SUB-SUM DEFINITIONS
-- ════════════════════════════════════════════════

-- Mirror the definitions from AbelMean.lean (private there).

private def myS₁ (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ)

private def myS₂ (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) *
    Real.log (k : ℝ) / (k : ℝ)

private def myS₃ (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) *
    (Real.log (k : ℝ)) ^ 2 / (k : ℝ)

-- ════════════════════════════════════════════════
-- §2. ALGEBRAIC DOT-PRODUCT EXPANSION
-- ════════════════════════════════════════════════

/-- **Dot product expansion.**
    bᵀv = -((1-γ)·S₁) - S₂ + [(1-γ)·S₂ + S₃]/logN,  where sums range over 1..N-1.

    Proof strategy:
    1. Rewrite N = (N-1)+1 to enable Fin.sum_univ_castSucc
    2. Kill last term (1 - logN/logN = 0)
    3. Suffices: each summand decomposes via ring
    4. Shatter into four Fin sums, convert to Icc via fin_sum_eq_icc_sum -/
private lemma dot_expansion (N : ℕ) (hN : 10 ≤ N) :
    dotProduct (vasyuninMeanVec N) (logCutoffWitness N) =
    -((1 - Real.eulerMascheroniConstant) * myS₁ (N - 1)) -
    myS₂ (N - 1) +
    ((1 - Real.eulerMascheroniConstant) * myS₂ (N - 1) + myS₃ (N - 1)) /
      Real.log (N : ℝ) := by
  -- Rewrite N as (N-1)+1 so Fin.sum_univ_castSucc can fire on Fin(N) → Fin(N-1) + last
  conv_lhs => rw [show N = (N - 1) + 1 from by omega]
  unfold dotProduct vasyuninMeanVec logCutoffWitness moebiusFn vasyuninMeanEntry
  rw [Fin.sum_univ_castSucc]
  -- Kill the last term: boundary vanishing (1 - logN/logN = 0)
  have h_last : 1 - Real.log ↑((Fin.last (N - 1)).val + 1) / Real.log ↑((N - 1) + 1) = 0 := by
    simp only [Fin.val_last]
    have hN_pos : (0 : ℝ) < ((N - 1 + 1 : ℕ) : ℝ) := Nat.cast_pos.mpr (by omega)
    rw [div_self (Real.log_ne_zero_of_pos_of_ne_one hN_pos
      (by exact_mod_cast (show (N - 1 + 1 : ℕ) ≠ 1 from by omega)))]
    simp
  simp only [h_last, mul_zero, neg_mul, add_zero, Fin.val_castSucc]
  simp only [show (N - 1 + 1 : ℕ) = N from by omega]
  -- Decompose each summand via ring, then shatter + convert to Icc sums
  suffices h : ∀ (i : Fin (N - 1)),
      (Real.log ((i.val + 1 : ℕ) : ℝ) + 1 - eulerMascheroniConstant) / ((i.val + 1 : ℕ) : ℝ) *
        -(↑(ArithmeticFunction.moebius (i.val + 1)) *
          (1 - Real.log ((i.val + 1 : ℕ) : ℝ) / Real.log (N : ℝ))) =
      -(1 - eulerMascheroniConstant) *
        ((↑(ArithmeticFunction.moebius (i.val + 1)) : ℝ) / ((i.val + 1 : ℕ) : ℝ)) -
      ((↑(ArithmeticFunction.moebius (i.val + 1)) : ℝ) *
        Real.log ((i.val + 1 : ℕ) : ℝ) / ((i.val + 1 : ℕ) : ℝ)) +
      ((1 - eulerMascheroniConstant) / Real.log (N : ℝ)) *
        ((↑(ArithmeticFunction.moebius (i.val + 1)) : ℝ) *
          Real.log ((i.val + 1 : ℕ) : ℝ) / ((i.val + 1 : ℕ) : ℝ)) +
      (1 / Real.log (N : ℝ)) *
        ((↑(ArithmeticFunction.moebius (i.val + 1)) : ℝ) *
          (Real.log ((i.val + 1 : ℕ) : ℝ)) ^ 2 / ((i.val + 1 : ℕ) : ℝ)) by
    simp_rw [h]
    simp_rw [Finset.sum_add_distrib, Finset.sum_sub_distrib, ← Finset.mul_sum]
    have hN2 : 2 ≤ N := by omega
    have h₁ : ∑ i : Fin (N - 1),
        (↑(ArithmeticFunction.moebius (i.val + 1)) : ℝ) / ((i.val + 1 : ℕ) : ℝ) =
        myS₁ (N - 1) := by
      unfold myS₁; exact fin_sum_eq_icc_sum hN2
        (fun k => (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ))
    have h₂ : ∑ i : Fin (N - 1),
        (↑(ArithmeticFunction.moebius (i.val + 1)) : ℝ) *
        Real.log ((i.val + 1 : ℕ) : ℝ) / ((i.val + 1 : ℕ) : ℝ) = myS₂ (N - 1) := by
      unfold myS₂; exact fin_sum_eq_icc_sum hN2
        (fun k => (↑(ArithmeticFunction.moebius k) : ℝ) * Real.log (k : ℝ) / (k : ℝ))
    have h₃ : ∑ i : Fin (N - 1),
        (↑(ArithmeticFunction.moebius (i.val + 1)) : ℝ) *
        (Real.log ((i.val + 1 : ℕ) : ℝ)) ^ 2 / ((i.val + 1 : ℕ) : ℝ) = myS₃ (N - 1) := by
      unfold myS₃; exact fin_sum_eq_icc_sum hN2
        (fun k => (↑(ArithmeticFunction.moebius k) : ℝ) * (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
    rw [h₁, h₂, h₃]
    ring
  intro i; ring

-- ════════════════════════════════════════════════
-- §3. ERROR REWRITING
-- ════════════════════════════════════════════════

/-- Pure algebraic identity: shift the error expression so that each
    term has a natural PNT limit (S₁→0, S₂+1→0, S₃+2γ→0). -/
private lemma error_shift (s1 s2 s3 LN G : ℝ) :
    -((1 - G) * s1) - s2 + ((1 - G) * s2 + s3) / LN - 1 =
    -(1 - G) * s1 - (s2 + 1) +
    ((1 - G) * (s2 + 1) + (s3 + 2 * G) - (1 + G)) / LN := by
  ring

-- ════════════════════════════════════════════════
-- §4. PNT LIMITS ON N-1
-- ════════════════════════════════════════════════

/-- If f(M) → L, then f(N-1) → L. -/
private lemma tendsto_pred {f : ℕ → ℝ} {L : ℝ}
    (hf : Tendsto f atTop (nhds L)) :
    Tendsto (fun N => f (N - 1)) atTop (nhds L) := by
  apply hf.comp
  rw [Filter.tendsto_atTop_atTop]
  intro b; exact ⟨b + 1, fun n hn => by omega⟩

-- ════════════════════════════════════════════════
-- §5. THE GRADUATION THEOREM
-- ════════════════════════════════════════════════

/-- **THEOREM** (was AXIOM — now GRADUATED! 🎓)

    bᵀv → 1 as N → ∞. Proved from PNT axioms.

    The proof:
    1. Expand bᵀv = -((1-γ)·S₁) - S₂ + [(1-γ)·S₂ + S₃]/logN
    2. Shift: bᵀv - 1 = -(1-γ)·S₁ - (S₂+1) + [(1-γ)·(S₂+1) + (S₃+2γ) - (1+γ)]/logN
    3. By PNT: S₁→0, S₂+1→0, S₃+2γ→0
    4. Therefore bᵀv - 1 → 0·0 - 0 + (0+0-(1+γ))·0 = 0

    Dependencies: pnt_mu_div_k, pnt_mu_log_div_k, pnt_mu_log_sq_div_k -/
theorem witness_numerator_convergence_proved :
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      |dotProduct (vasyuninMeanVec N) (logCutoffWitness N) - 1| < ε := by
  intro ε hε
  set G := Real.eulerMascheroniConstant
  -- PNT limits shifted to N-1
  have hS₁ : Tendsto (fun N => myS₁ (N - 1)) atTop (nhds 0) :=
    tendsto_pred pnt_mu_div_k
  have hS₂ : Tendsto (fun N => myS₂ (N - 1)) atTop (nhds (-1)) :=
    tendsto_pred pnt_mu_log_div_k
  have hS₃ : Tendsto (fun N => myS₃ (N - 1)) atTop (nhds (-2 * G)) :=
    tendsto_pred pnt_mu_log_sq_div_k
  -- 1/log(N) → 0
  have hInvLog : Tendsto (fun N : ℕ => 1 / Real.log (N : ℝ)) atTop (nhds 0) := by
    have hlog : Tendsto (fun N : ℕ => Real.log (N : ℝ)) atTop atTop :=
      Real.tendsto_log_atTop.comp tendsto_natCast_atTop_atTop
    rw [show (0 : ℝ) = 1 * 0 from by ring]
    exact tendsto_const_nhds.mul (tendsto_inv_atTop_zero.comp hlog)
  -- Term 1: -(1-G)·S₁(N-1) → 0
  have hT1 : Tendsto (fun N => -(1 - G) * myS₁ (N - 1)) atTop (nhds 0) := by
    rw [show (0 : ℝ) = -(1 - G) * 0 from by ring]
    exact hS₁.const_mul _
  -- Term 2: -(S₂(N-1) + 1) → 0
  have hT2 : Tendsto (fun N => -(myS₂ (N - 1) + 1)) atTop (nhds 0) := by
    rw [show (0 : ℝ) = -((-1) + 1) from by ring]
    exact (hS₂.add tendsto_const_nhds).neg
  -- Term 3: numerator/logN → 0
  --   numerator = (1-G)·(S₂+1) + (S₃+2G) - (1+G)
  --     → (1-G)·0 + 0 - (1+G) = -(1+G)
  --   So numerator/logN → -(1+G) · 0 = 0
  have hNumerator : Tendsto
      (fun N => (1 - G) * (myS₂ (N - 1) + 1) + (myS₃ (N - 1) + 2 * G) - (1 + G))
      atTop (nhds (-(1 + G))) := by
    have h_s2p1 : Tendsto (fun N => myS₂ (N - 1) + 1) atTop (nhds (-1 + 1)) :=
      hS₂.add tendsto_const_nhds
    have h1 : Tendsto (fun N => (1 - G) * (myS₂ (N - 1) + 1))
        atTop (nhds ((1 - G) * (-1 + 1))) :=
      h_s2p1.const_mul _
    have h2 : Tendsto (fun N => myS₃ (N - 1) + 2 * G)
        atTop (nhds (-2 * G + 2 * G)) :=
      hS₃.add tendsto_const_nhds
    have h3 : Tendsto
        (fun N => (1 - G) * (myS₂ (N - 1) + 1) + (myS₃ (N - 1) + 2 * G))
        atTop (nhds ((1 - G) * (-1 + 1) + (-2 * G + 2 * G))) :=
      h1.add h2
    have h4 : Tendsto
        (fun N => (1 - G) * (myS₂ (N - 1) + 1) + (myS₃ (N - 1) + 2 * G) - (1 + G))
        atTop (nhds ((1 - G) * (-1 + 1) + (-2 * G + 2 * G) - (1 + G))) :=
      h3.sub tendsto_const_nhds
    convert h4 using 1
    ring_nf
  have hT3 : Tendsto
      (fun N : ℕ => ((1 - G) * (myS₂ (N - 1) + 1) + (myS₃ (N - 1) + 2 * G) - (1 + G)) /
        Real.log (N : ℝ))
      atTop (nhds 0) := by
    rw [show (0 : ℝ) = -(1 + G) * 0 from by ring]
    have : (fun N : ℕ =>
        ((1 - G) * (myS₂ (N - 1) + 1) + (myS₃ (N - 1) + 2 * G) - (1 + G)) /
        Real.log (N : ℝ)) =
        (fun N => ((1 - G) * (myS₂ (N - 1) + 1) + (myS₃ (N - 1) + 2 * G) - (1 + G)) *
        (1 / Real.log (N : ℝ))) := by ext N; ring
    rw [this]
    exact hNumerator.mul hInvLog
  -- Combined: error → 0
  have hCombined : Tendsto
      (fun N : ℕ => -(1 - G) * myS₁ (N - 1) - (myS₂ (N - 1) + 1) +
        ((1 - G) * (myS₂ (N - 1) + 1) + (myS₃ (N - 1) + 2 * G) - (1 + G)) /
        Real.log (N : ℝ))
      atTop (nhds 0) := by
    rw [show (0 : ℝ) = 0 + 0 + 0 from by ring]
    exact (hT1.add hT2).add hT3
  -- Convert Tendsto to ε-δ
  rw [Metric.tendsto_atTop] at hCombined
  obtain ⟨N_conv, hN_conv⟩ := hCombined ε hε
  refine ⟨max N_conv 10, fun N hN => ?_⟩
  have hN10 : 10 ≤ N := by omega
  -- Apply the algebraic expansion
  rw [dot_expansion N hN10]
  -- Apply error shift to match the convergence terms
  rw [error_shift (myS₁ (N - 1)) (myS₂ (N - 1)) (myS₃ (N - 1))
    (Real.log (N : ℝ)) G]
  -- The result follows from the convergence bound
  have h := hN_conv N (by omega)
  rw [dist_comm, Real.dist_eq] at h
  rwa [zero_sub, abs_neg] at h

end Cathedral.Vasyunin
