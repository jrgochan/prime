/-
  Cathedral/Covariance/AbelCovarianceBound.lean

  ## Closing abel_summation_covariance_bound

  TARGET: Replace the axiom `abel_summation_covariance_bound`
  (WitnessConditional.lean:62) with a theorem.

  ### Circularity Analysis (discovered May 10, 2026)

  The existing L² decay chain is CIRCULAR with respect to this axiom:
    bd_gram_form_decay (MontgomeryVaughan.lean)
    → mertens_implies_l2_decay (MoebiusL1Bound.lean)
    → abel_summation_covariance_bound (WitnessConditional.lean) ← TARGET!

  Therefore, we CANNOT use any of:
  - mertens_implies_l2_decay
  - l2_from_pointwise_bound_derived
  - bd_gram_form_decay
  - critical_line_mellin_bound
  to close this axiom.

  ### Strategy (Non-Circular)

  We prove a DIRECT L² bound ∫(1-f_N)² ≤ C/logN without going
  through the covariance decomposition. Then:

    vᵀCv ≤ ∫(1-f)²     [since (1-bᵀv)² ≥ 0, from PROVED identity]
         ≤ C_l2/logN     [from direct L² bound]

  The direct L² bound requires:
  - Step A: ∫(1-f)² = 1 - 2bᵀv + vᵀGv         [PROVED: bd_l2_error_eq_quad_error]
  - Step B: bᵀv = 1 + O(1/logN)                 [PROVED: DotProductBound]
  - Step C: vᵀGv ≤ 1 + C_G/logN                 [NEEDED: direct gram bound]
  - Step D: 1-2(1-ε)+(1+C_G/logN) = 2ε+C_G/logN ≤ C/logN ✓

  Step C is the genuine gap. It requires the Selberg-type estimate
  on the Gram form, which is the content of the Báez-Duarte theorem.

  ### What this axiom actually says

  Given: |M(x)| ≤ C · x^{1/2} · log²(x)
  Prove: vᵀCv ≤ C_cov / log(N)

  ### Available tools (all PROVED, no circularity)

  ✅ abel_summation, abel_summation_abs_bound (AbelSummation.lean)
  ✅ bd_l2_error_eq_quad_error (VasyuninBypass.lean)
  ✅ vasyunin_bd_index_bridge (VasyuninBypass.lean)
  ✅ moebius_dot_product_approx_one_uniform_34 (DotProductBound.lean)
  ✅ inner_sum_abel, quadForm_as_double_sum (QuadFormIdentity.lean)
  ✅ gram_form_direct_bound (BilinearAbel.lean) — but gives K=O(N), not 1+C/logN
  ✅ S₁, S₂, S₃ tail decay (AbelTail/*.lean — PROVED)
  ✅ logsq_le_rpow_quarter, mertens_half_implies_three_quarter (THIS FILE)

  May 10, 2026 — cleanup-v17
-/

import Cathedral.Defs
import Cathedral.NymanBeurling.BDBridge
import Cathedral.NymanBeurling.VasyuninBypass
import Cathedral.Covariance.DotProductBound
import Cathedral.Covariance.CovarianceAbel
import Cathedral.MellinBridge.AbelSummation
import Cathedral.MellinBridge.BDWeights

noncomputable section
open Real Matrix Finset MeasureTheory Filter Cathedral.Vasyunin ArithmeticFunction

-- ═══════════════════════════════════════════════
-- §1. MERTENS DOWNGRADE: x^{1/2}·log² → x^{3/4}
-- ═══════════════════════════════════════════════

/-- For y ≥ 1: log²(y) · y^{-1/4} ≤ 9.

    Proof: log²(y) · y^{-1/4} = (log(y) · y^{-1/8})².
    Using y·e^{-y} ≤ e^{-1} with y = log(x)/8:
      log(x) · x^{-1/8} ≤ 8/e.
    So log²(x) · x^{-1/4} ≤ (8/e)² = 64/e² ≈ 8.66 ≤ 9. -/
theorem logsq_le_rpow_quarter (y : ℝ) (hy : 1 ≤ y) :
    (Real.log y) ^ 2 * y ^ (-(1:ℝ)/4) ≤ 9 := by
  have hy_pos : 0 < y := lt_of_lt_of_le one_pos hy
  -- Split y^{-1/4} = y^{-1/8} · y^{-1/8}
  have h_split : y ^ (-(1:ℝ)/4) = y ^ (-(1:ℝ)/8) * y ^ (-(1:ℝ)/8) := by
    rw [← rpow_add hy_pos]; congr 1; ring
  -- log²(y) · y^{-1/4} = (log(y) · y^{-1/8})²
  have h_sq : (Real.log y) ^ 2 * y ^ (-(1:ℝ)/4) =
      (Real.log y * y ^ (-(1:ℝ)/8)) ^ 2 := by
    rw [h_split]; ring
  rw [h_sq]
  -- Key: log(y) · y^{-1/8} ≤ 8 · exp(-1)
  -- From: (log(y)/8) · exp(-log(y)/8) ≤ exp(-1) (by mul_exp_neg_le_exp_neg_one)
  have h_factor : Real.log y * y ^ (-(1:ℝ)/8) ≤ 8 * Real.exp (-1) := by
    have h := mul_exp_neg_le_exp_neg_one (Real.log y / 8)
    have h_exp : Real.exp (-(Real.log y / 8)) = y ^ (-(1:ℝ)/8) := by
      rw [show -(Real.log y / 8) = Real.log y * (-(1:ℝ)/8) from by ring]
      rw [← rpow_def_of_pos hy_pos]
    rw [h_exp] at h; linarith
  -- So (log(y) · y^{-1/8})² ≤ (8·exp(-1))² ≤ 9
  have h_nn : 0 ≤ Real.log y * y ^ (-(1:ℝ)/8) :=
    mul_nonneg (Real.log_nonneg hy) (rpow_pos_of_pos hy_pos _).le
  have h_sq_bound : (Real.log y * y ^ (-(1:ℝ)/8)) ^ 2 ≤ (8 * Real.exp (-1)) ^ 2 :=
    sq_le_sq' (by linarith) h_factor
  -- 64/e² ≤ 9 (since e > 2.718, e² > 7.389)
  have h_exp_bound : (8 * Real.exp (-1)) ^ 2 ≤ 9 := by
    have he : (2.7182818283 : ℝ) < Real.exp 1 := exp_one_gt_d9
    rw [show (8 * Real.exp (-1)) ^ 2 = 64 * (Real.exp (-1)) ^ 2 from by ring,
        show Real.exp (-1) = (Real.exp 1)⁻¹ from Real.exp_neg 1, inv_pow,
        show 64 * ((Real.exp 1) ^ 2)⁻¹ = 64 / (Real.exp 1) ^ 2 from by ring,
        div_le_iff₀ (by positivity)]
    nlinarith [mul_self_nonneg (Real.exp 1 - 2.7182818283)]
  linarith

/-- Mertens x^{1/2}·log² implies Mertens x^{3/4}.

    Since y^{1/2}·log²y = y^{3/4}·(log²y·y^{-1/4}) ≤ 9·y^{3/4}
    for y ≥ 1, we get C·y^{1/2}·log²y ≤ 9C·y^{3/4}. -/
theorem mertens_half_implies_three_quarter
    (C_m : ℝ) (hC : 0 < C_m)
    (hM : ∀ y : ℝ, y ≥ 2 →
      |((_root_.mertensFunction y : ℤ) : ℝ)| ≤ C_m * y ^ ((1:ℝ)/2) * (Real.log y) ^ 2) :
    ∃ C' : ℝ, C' > 0 ∧ ∀ y : ℝ, y ≥ 2 →
      |((_root_.mertensFunction y : ℤ) : ℝ)| ≤ C' * y ^ ((3:ℝ)/4) := by
  refine ⟨9 * C_m, by positivity, fun y hy => ?_⟩
  have hy_pos : 0 < y := by linarith
  have hy_ge1 : 1 ≤ y := by linarith
  have h := hM y hy
  have h_logsq := logsq_le_rpow_quarter y hy_ge1
  calc |((_root_.mertensFunction y : ℤ) : ℝ)|
      ≤ C_m * y ^ ((1:ℝ)/2) * (Real.log y) ^ 2 := h
    _ = C_m * (y ^ ((3:ℝ)/4) * ((Real.log y) ^ 2 * y ^ (-(1:ℝ)/4))) := by
        have : y ^ ((1:ℝ)/2) = y ^ ((3:ℝ)/4) * y ^ (-(1:ℝ)/4) := by
          rw [← rpow_add hy_pos]; congr 1; ring
        rw [this]; ring
    _ ≤ C_m * (y ^ ((3:ℝ)/4) * 9) := by
        gcongr
    _ = 9 * C_m * y ^ ((3:ℝ)/4) := by ring

-- ═══════════════════════════════════════════════
-- §2. THE NON-CIRCULAR ASSEMBLY
-- ═══════════════════════════════════════════════

/-- **THEOREM** (replaces axiom `abel_summation_covariance_bound`):
    Under Mertens x^{1/2}·log²x, the covariance form decays.

    **Non-circular proof route:**
    1. Get dot product bound |1-bᵀv| ≤ C_dot/logN  [DotProductBound, uses x^{3/4}]
    2. Get L² bound ∫(1-f)² ≤ C_l2/logN             [DIRECT, non-circular]
    3. Use identity (1-bᵀv)² + vᵀCv = ∫(1-f)²      [PROVED]
    4. Since (1-bᵀv)² ≥ 0, conclude vᵀCv ≤ C_l2/logN

    Step 2 is the KEY step. It requires bounding
      1 - 2bᵀv + vᵀGv ≤ C/logN
    which amounts to showing vᵀGv ≤ 1 + C'/logN.

    The gram form bound needs the double Abel summation
    with Mertens cancellation exploited across both indices.
    This is the Selberg/Báez-Duarte estimate. -/
theorem abel_summation_covariance_bound_proved
    (hMertens : ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((_root_.mertensFunction x : ℤ) : ℝ)| ≤ C * x ^ ((1:ℝ)/2) * (Real.log x) ^ 2) :
    ∃ C_cov : ℝ, C_cov > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) ≤ C_cov / Real.log ↑N := by
  -- Extract constant and downgrade to x^{3/4}
  obtain ⟨C_m, hC_m_pos, hM⟩ := hMertens
  obtain ⟨C_34, hC_34_pos, hM34⟩ := mertens_half_implies_three_quarter C_m hC_m_pos hM
  -- ═══════════════════════════════════════════════
  -- Non-circular assembly:
  --
  -- We need ∃ C_l2, ∫(1-f)² ≤ C_l2/logN WITHOUT using this axiom.
  --
  -- The PROVED identity gives: (1-bᵀv)² + vᵀCv = ∫(1-f)²
  -- Since (1-bᵀv)² ≥ 0: vᵀCv ≤ ∫(1-f)²
  --
  -- So we need a DIRECT bound on ∫(1-f)² = 1 - 2bᵀv + vᵀGv.
  -- We know bᵀv = 1 + O(1/logN) (PROVED, no circularity).
  -- We need vᵀGv ≤ 1 + C/logN (the gram form bound).
  --
  -- The gram form bound is:
  --   ∫₀¹ f_N(x)² dx = ∫₀¹ |Σ_k v_k {k/x}|² dx ≤ 1 + C/logN
  --
  -- Under Mertens x^{1/2}·log²x, this follows from:
  --   vᵀGv = Σ_j Σ_k v_j v_k G(j,k)
  -- where the double Abel approach controls the sum via
  -- Möbius cancellation.
  --
  -- THIS IS THE REMAINING GAP (Selberg/Báez-Duarte estimate).
  -- ═══════════════════════════════════════════════
  sorry -- DEPRECATED: Bypassed by MellinCrown.lean (Selberg estimate)

-- ═══════════════════════════════════════════════
-- §3. AUDIT
-- ═══════════════════════════════════════════════

/-!
### Sorry Status

| # | Theorem | Status |
|---|---------|--------|
| 1 | `logsq_le_rpow_quarter` | ✅ **PROVED** |
| 2 | `mertens_half_implies_three_quarter` | ✅ **PROVED** |
| 3 | `abel_summation_covariance_bound_proved` | ❌ sorry (gram form) |

### Circularity Map

```mermaid
graph TD
    A[abel_summation_covariance_bound] -->|used by| B[mertens_implies_l2_decay]
    B -->|used by| C[bd_gram_form_decay]
    C -->|used by| D[l2_from_pointwise_bound_derived]
    C -->|used by| E[critical_line_mellin_bound]
    
    style A fill:#ff6b6b,stroke:#333,color:#fff
    style B fill:#ff9999,stroke:#333
    style C fill:#ff9999,stroke:#333
    style D fill:#ff9999,stroke:#333
    style E fill:#ff9999,stroke:#333
```

All red nodes depend on the target axiom. They CANNOT be used in the proof.

### Non-circular tools (green)

```mermaid
graph TD
    F[bd_l2_error_eq_quad_error ✅] --> G[vasyunin_bd_index_bridge ✅]
    G --> H["Identity: (1-bᵀv)² + vᵀCv = ∫(1-f)²"]
    I[moebius_dot_product_approx_one_uniform_34 ✅] --> J["|1-bᵀv| ≤ C/logN"]
    K[inner_sum_abel ✅] --> L[Double Abel decomposition]
    L --> M["vᵀGv ≤ 1+C/logN ← THE GAP"]
    M --> N["∫(1-f)² ≤ C'/logN"]
    H --> O[vᵀCv ≤ ∫(1-f)²]
    N --> O
    O --> P[abel_summation_covariance_bound ← CLOSES!]
    
    style M fill:#ff6b6b,stroke:#333,color:#fff
    style P fill:#ffd93d,stroke:#333
```

### Next Steps

The **sole remaining gap** is: vᵀGv ≤ 1 + C/logN under Mertens x^{1/2}·log²x.

**Approach 1 (Double Abel)**: Use inner_sum_abel (PROVED) for each row, then
sum over rows. Requires off-diagonal Gram entry bounds with GCD structure.
Key identity: G(j,k) involves digamma/cotangent sums. ESTIMATED: 2 sessions.

**Approach 2 (Frequency Domain)**: Build a DIRECT Parseval argument that
doesn't go through mertens_implies_l2_decay. Use the Mellin representation
of f_N on the critical line + Plancherel. Requires new Mellin-side lemmas
but avoids the circularity. ESTIMATED: 3 sessions.

**Approach 3 (Hybrid)**: Prove vᵀGv = 1 + O(1/logN) by combining:
- Diagonal: Σ v_k² G(k,k) → (6/π²)·(some convergent series) (uses ζ(2))
- Off-diagonal: cancellation from Möbius (uses inner_sum_abel)
ESTIMATED: 2-3 sessions.
-/

end
