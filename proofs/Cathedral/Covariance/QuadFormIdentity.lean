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
    realQuadForm G v = Σ_{j=1}^{N-1} Σ_{k=1}^{N-1} v_j · v_k · G(j,k)

    Mechanical index rewriting: Fin(N-1) ↔ Icc 1 (N-1) applied twice,
    using fin_sum_eq_icc_sum from Engine.lean. -/
theorem quadForm_as_double_sum (N : ℕ) (hN : 3 ≤ N) :
    Cathedral.Variational.realQuadForm (Matrix.of fun (i j : Fin (N - 1)) =>
      vasyuninGramEntry (i.val + 1) (j.val + 1)) (bdMoebiusWeight N) =
    ∑ j ∈ Finset.Icc 1 (N - 1), ∑ k ∈ Finset.Icc 1 (N - 1),
      gramProduct N j k := by
  -- Step 1: bdMoebiusWeight N i = bdWeight N (i.val + 1)
  have h_weight : ∀ i : Fin (N - 1), bdMoebiusWeight N i = bdWeight N (i.val + 1) := by
    intro i; unfold bdMoebiusWeight bdWeight; rfl
  -- Step 2: Unfold realQuadForm and rewrite summands
  unfold Cathedral.Variational.realQuadForm
  simp only [dotProduct, Matrix.mulVec, Matrix.of_apply]
  simp_rw [Finset.mul_sum]
  -- Now goal: Σ i, Σ j, w(i) * (G(i+1,j+1) * w(j)) = Σ_Icc Σ_Icc gramProduct
  -- Step 3: Rewrite each summand as gramProduct N (i+1) (j+1)
  have h_summand : ∀ (i j : Fin (N - 1)),
      bdMoebiusWeight N i * (vasyuninGramEntry (i.val + 1) (j.val + 1) *
        bdMoebiusWeight N j) =
      gramProduct N (i.val + 1) (j.val + 1) := by
    intro i j; rw [h_weight i, h_weight j]; unfold gramProduct; ring
  simp_rw [h_summand]
  -- Now goal: Σ i : Fin(N-1), Σ j : Fin(N-1), gramProduct N (i+1) (j+1)
  --         = Σ j ∈ Icc 1 (N-1), Σ k ∈ Icc 1 (N-1), gramProduct N j k
  -- Step 4: Apply fin_sum_eq_icc_sum to inner sum first
  have h_inner : ∀ (i : Fin (N - 1)),
      ∑ j : Fin (N - 1), gramProduct N (i.val + 1) (j.val + 1) =
      ∑ k ∈ Finset.Icc 1 (N - 1), gramProduct N (i.val + 1) k := by
    intro i; exact fin_sum_eq_icc_sum (by omega : 2 ≤ N) _
  simp_rw [h_inner]
  -- Step 5: Apply fin_sum_eq_icc_sum to outer sum
  exact fin_sum_eq_icc_sum (by omega : 2 ≤ N)
    (fun j => ∑ k ∈ Finset.Icc 1 (N - 1), gramProduct N j k)

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
theorem inner_sum_abel (N : ℕ) (hN : 3 ≤ N) (j : ℕ) (_hj : 1 ≤ j) :
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
    logWeight(N, N-1) = 1 - log(N-1)/log(N) = (log(N)-log(N-1))/log(N)
                      = log(N/(N-1))/log(N) ≤ log(2)/log(N) ≤ 2/log(N). -/
theorem logWeight_at_N_minus_1 (N : ℕ) (hN : 10 ≤ N) :
    |logWeight N (N - 1)| ≤ 2 / Real.log ↑N := by
  unfold logWeight
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have hN1_pos : (0 : ℝ) < (N - 1 : ℕ) := Nat.cast_pos.mpr (by omega)
  have hlogN_pos : 0 < Real.log ↑N :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  have hlogN_ne : Real.log (↑N : ℝ) ≠ 0 := ne_of_gt hlogN_pos
  -- log(N-1) ≤ log(N)
  have h_mono : Real.log (↑(N - 1) : ℝ) ≤ Real.log ↑N :=
    Real.log_le_log hN1_pos (by exact_mod_cast show N - 1 ≤ N by omega)
  -- 0 ≤ 1 - log(N-1)/log(N)
  have h_nn : 0 ≤ 1 - Real.log (↑(N - 1) : ℝ) / Real.log ↑N := by
    rw [sub_nonneg, div_le_one hlogN_pos]
    exact h_mono
  rw [abs_of_nonneg h_nn]
  -- 1 - log(N-1)/log(N) = (log(N) - log(N-1))/log(N)
  have h_eq : 1 - Real.log (↑(N - 1) : ℝ) / Real.log ↑N =
      (Real.log ↑N - Real.log (↑(N - 1) : ℝ)) / Real.log ↑N := by
    field_simp
  rw [h_eq]
  -- goal: (logN - logN1) / logN ≤ 2 / logN, suffices logN - logN1 ≤ 2
  suffices h : Real.log ↑N - Real.log (↑(N - 1) : ℝ) ≤ 2 by
    exact div_le_div_of_nonneg_right h hlogN_pos.le
  -- Need: (log(N) - log(N-1)) · 1 ≤ 2
  -- log(N) - log(N-1) = log(N/(N-1)) ≤ log(2) < 1 < 2
  have h_diff : Real.log ↑N - Real.log (↑(N - 1) : ℝ) =
      Real.log (↑N / ↑(N - 1) : ℝ) := by
    rw [Real.log_div (ne_of_gt hN_pos) (ne_of_gt hN1_pos)]
  rw [h_diff]
  have h_ratio : (↑N : ℝ) / ↑(N - 1) ≤ 2 := by
    rw [div_le_iff₀ hN1_pos]
    have hN_eq : (↑N : ℝ) = (↑(N - 1) : ℝ) + 1 := by
      rw [Nat.cast_sub (by omega : 1 ≤ N)]; simp
    have hN1_ge : (↑(N - 1) : ℝ) ≥ 1 := by exact_mod_cast show 1 ≤ N - 1 by omega
    linarith
  -- log(N/(N-1)) ≤ log(2) ≤ 2
  calc Real.log (↑N / ↑(N - 1) : ℝ)
      ≤ Real.log 2 := Real.log_le_log (by positivity) h_ratio
    _ ≤ 2 := by
        have h := Real.log_le_sub_one_of_pos (show (0 : ℝ) < 2 by norm_num)
        linarith

-- ═══════════════════════════════════════════════
-- §5. GRAM ENTRY GROWTH
-- ═══════════════════════════════════════════════

/-- Diagonal Gram entry bound: |G(k,k)| ≤ (log(2π)+1)/k.
    Uses the closed form G(k,k) = (log(2π)-γ)/k - 1/k².
    Since log(2π)-γ > 0 and 1/k² ≤ (log(2π)-γ)/k (for k ≥ 1),
    we have 0 ≤ G(k,k) ≤ (log(2π)-γ)/k ≤ (log(2π)+1)/k. -/
theorem gramEntry_diag_bound (k : ℕ) (hk : 1 ≤ k) :
    |vasyuninGramEntry k k| ≤ (Real.log (2 * Real.pi) + 1) / (k : ℝ) := by
  rw [vasyuninGramEntry_diag]
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hk_ge : (1 : ℝ) ≤ (k : ℝ) := by exact_mod_cast hk
  have h_log_pos : 0 < Real.log (2 * Real.pi) := by
    apply Real.log_pos; linarith [Real.pi_gt_three]
  -- log(2π) - γ > 0 (since γ < 2/3 < log(2π) ≈ 1.84)
  have h_log2pi : Real.log (2 * Real.pi) = Real.log 2 + Real.log Real.pi :=
    Real.log_mul (by norm_num : (2:ℝ) ≠ 0) (ne_of_gt Real.pi_pos)
  have h_log2 := Real.log_two_gt_d9
  have h_log_pi : 1 < Real.log Real.pi := by
    have : 1 < Real.log 3 := by
      rw [show (1 : ℝ) = Real.log (Real.exp 1) from (Real.log_exp 1).symm]
      exact Real.log_lt_log (Real.exp_pos 1) Real.exp_one_lt_three
    exact lt_trans this (Real.log_lt_log (by norm_num : (0:ℝ) < 3) Real.pi_gt_three)
  have h_a_pos : 0 < Real.log (2 * Real.pi) - eulerMascheroniConstant := by
    linarith [Real.eulerMascheroniConstant_lt_two_thirds]
  -- Stronger: log(2π) - γ > 1 (since log(2) > 0.69, log(π) > 1, γ < 2/3)
  have h_a_pos_strong : 1 < Real.log (2 * Real.pi) - eulerMascheroniConstant := by
    linarith [Real.eulerMascheroniConstant_lt_two_thirds]
  -- The expression a/k - 1/k² = (a·k - 1)/k² ≥ 0 for a > 0, k ≥ 1
  -- (since a·k ≥ a ≥ log(2π) - 2/3 > 1)
  -- And a/k - 1/k² ≤ a/k ≤ (log(2π)+1)/k
  -- Use: a/k - 1/k² ≤ a/k (subtract nonneg)
  have h_sub_le : (Real.log (2 * Real.pi) - eulerMascheroniConstant) / (k : ℝ) -
      1 / (k : ℝ) ^ 2 ≤
      (Real.log (2 * Real.pi) - eulerMascheroniConstant) / (k : ℝ) :=
    sub_le_self _ (by positivity)
  -- a ≤ log(2π) + 1 (since γ > 0)
  have h_a_le : Real.log (2 * Real.pi) - eulerMascheroniConstant ≤
      Real.log (2 * Real.pi) + 1 := by
    linarith [one_half_lt_eulerMascheroniConstant]
  -- 0 ≤ G(k,k): a/k - 1/k² ≥ 0 iff a·k ≥ 1
  -- We have a > 1 (since log(2π) > 1.69, γ < 0.67) and k ≥ 1, so a·k ≥ a > 1.
  have h_nn : 0 ≤ (Real.log (2 * Real.pi) - eulerMascheroniConstant) / (k : ℝ) -
      1 / (k : ℝ) ^ 2 := by
    have hak : 1 ≤ (Real.log (2 * Real.pi) - eulerMascheroniConstant) * (k : ℝ) :=
      le_of_lt (lt_of_lt_of_le h_a_pos_strong (le_mul_of_one_le_right (le_of_lt h_a_pos) hk_ge))
    have hk_sq_pos : (0 : ℝ) < (k : ℝ) ^ 2 := by positivity
    rw [sub_nonneg, div_le_div_iff₀ hk_sq_pos hk_pos, one_mul]
    nlinarith [show (k : ℝ) ^ 2 * ((Real.log (2 * Real.pi) - eulerMascheroniConstant) / (k : ℝ)) =
        (Real.log (2 * Real.pi) - eulerMascheroniConstant) * (k : ℝ) from by field_simp]
  rw [abs_of_nonneg h_nn]
  -- a/k - 1/k² ≤ a/k ≤ (log(2π)+1)/k
  calc (Real.log (2 * Real.pi) - eulerMascheroniConstant) / (k : ℝ) -
        1 / (k : ℝ) ^ 2
      ≤ (Real.log (2 * Real.pi) - eulerMascheroniConstant) / (k : ℝ) := h_sub_le
    _ ≤ (Real.log (2 * Real.pi) + 1) / (k : ℝ) := by
        gcongr

/-- ⚠️ DEPRECATED/NUMERICALLY-UNVERIFIED — Off-diagonal Gram entry growth bound.

    The proposed bound |G(j,k)| ≤ C · log(max(j,k)+1) / min(j,k) is
    plausible but unproved. The ORIGINAL bound |G(j,k)| ≤ C·(1/j + 1/k)
    was NUMERICALLY FALSIFIED by 512-bit MPFR Rust telemetry in
    Exploration 13 — Dedekind cotangent sums grow logarithmically.

    This lemma is NOT required for the Crown Axiom graduation path.
    The Abel summation approach (inner_sum_abel) handles the full sum
    Σ_k v_k G(j,k) directly, without needing individual entry bounds.
    The correct architecture uses MellinCrown.lean (frequency domain).

    DO NOT attempt to prove the O(1/max(j,k)) version — it is FALSE.

    Status: OFF-PATH. Superseded by MellinCrown + Abel summation. -/
theorem DEPRECATED_gramEntry_growth_bound (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    |vasyuninGramEntry j k| ≤
    2 * Real.log (↑(max j k) + 1) / ↑(min j k) := by
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
