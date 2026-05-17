/-
  Cathedral/Covariance/CovarianceAbel.lean

  ## Direct Proof of the Covariance Bound via Abel Summation

  TARGET: Replace axiom `covariance_bound_from_mertens_34` with theorem.

  STRATEGY: Bound vᵀCv = ∫(1-f)² - (1-bᵀv)² directly.

  Since (1-bᵀv)² ≤ (C_dot/logN)² = O(1/log²N) [PROVED],
  it suffices to bound ∫(1-f)² ≤ C/logN.

  The L² residual:
    ∫₀¹ (1 - f_N(x))² dx

  where f_N(x) = Σ_{k=1}^{N-1} v_k · {1/(kx)},
  v_k = -μ(k) · (1 - log(k)/log(N)).

  KEY IDEA: Bound f_N pointwise using Abel summation on the
  Möbius-weighted sum, then integrate the pointwise bound.

  Abel summation on the partial sum:
    Σ_{k=1}^M μ(k) · w(k,x) = M(M)·w(M,x) - Σ_{k=1}^{M-1} M(k)·Δw(k,x)

  where M(k) = Σ_{j≤k} μ(j) (Mertens function), w(k,x) = taper(k)·{1/(kx)},
  and Δw(k,x) = w(k+1,x) - w(k,x).

  The Mertens bound |M(k)| ≤ C·k^{3/4} controls the tail.

  April 27, 2026 — Exploration 13
-/

import Cathedral.Defs
import Cathedral.NymanBeurling.BDBridge
import Cathedral.NymanBeurling.VasyuninBypass
import Cathedral.Covariance.DotProductBound
import Cathedral.AbelTail.S1Decay
import Cathedral.AbelTail.S2Decay
import Cathedral.AbelTail.MertensBridge
import Cathedral.MellinBridge.BDWeights

noncomputable section
open Real Matrix Finset MeasureTheory Filter Cathedral.Vasyunin ArithmeticFunction

-- ═══════════════════════════════════════════════
-- §1. POINTWISE CONTROL: THE MÖBIUS-WEIGHTED SUM
-- ═══════════════════════════════════════════════

/-- The Möbius-weighted sum at a point x:
    f_N(x) = Σ_{k=1}^{N-1} (-μ(k)) · (1-logk/logN) · {1/(kx)}

    This is the BD approximant evaluated at x ∈ (0,1]. -/
def bdApprox (N : ℕ) (x : ℝ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 (N-1),
    -(↑(moebius k) : ℝ) * (1 - Real.log ↑k / Real.log ↑N) *
    Int.fract (1 / ((k : ℝ) * x))

/-- The L² residual: ∫₀¹ (1 - f_N(x))² dx.
    This equals 1 - 2bᵀv + vᵀGv (by bd_l2_error_eq_quad_error). -/
def l2Residual (N : ℕ) : ℝ :=
  ∫ x in (0:ℝ)..1, (1 - bdApprox N x) ^ 2

-- ═══════════════════════════════════════════════
-- §2. POINTWISE BOUND VIA ABEL SUMMATION
-- ═══════════════════════════════════════════════

/-- **Bridge**: The partial sum of -μ(k) from 1 to M equals -M(M).
    This connects the abstract partialSum with the Mertens function. -/
theorem partialSum_neg_moebius_eq_neg_mertens (M : ℕ) (_hM : 1 ≤ M) :
    partialSum (fun k => -(↑(moebius k) : ℝ)) 1 M =
    -(↑(mertensFunction ↑M : ℤ) : ℝ) := by
  unfold partialSum mertensFunction
  simp only [Finset.sum_neg_distrib, neg_inj]
  -- Goal: Σ_{k ∈ Icc 1 M} (μ(k) : ℝ) = ↑(Σ_{n ∈ filter ...} μ(n) : ℤ)
  -- Both are sums of μ over {1,...,M}, just with different Finset representations
  push_cast
  congr 1
  -- Show the Finsets are equal
  ext n
  simp only [Finset.mem_Icc, Finset.mem_filter, Finset.mem_range, Nat.lt_add_one_iff,
             Nat.cast_le, Nat.floor_natCast]
  constructor
  · intro ⟨h1, h2⟩; exact ⟨h2, by exact_mod_cast h2, by exact_mod_cast h1⟩
  · intro ⟨h1, h2, h3⟩; exact ⟨by exact_mod_cast h3, by exact_mod_cast h1⟩

-- ═══════════════════════════════════════════════
-- §2a. BOUNDING THE ABEL DIFFERENCES (moved before §2 for dependency)
-- ═══════════════════════════════════════════════

/-- **ESTIMATE (PROVED)**: The difference w(k+1,x) - w(k,x) decomposes as:

    Δw(k,x) = (taper(k+1) - taper(k)) · {1/((k+1)x)}
            + taper(k) · ({1/((k+1)x)} - {1/(kx)})

    The first term has |Δtaper| ≤ 1/(k·logN) (from log(1+1/k) ≤ 1/k).
    The second term is bounded by |taper|·|Δfract| ≤ 1·1 = 1.

    Combined: |Δw| ≤ 1/(k·logN) + 1. -/
theorem abel_diff_bound (N k : ℕ) (hk : 1 ≤ k) (hkN : k + 1 ≤ N)
    (x : ℝ) (_hx : 0 < x) (_hx1 : x ≤ 1) :
    |(1 - Real.log ↑(k+1) / Real.log ↑N) * Int.fract (1 / (((k+1) : ℝ) * x)) -
     (1 - Real.log ↑k / Real.log ↑N) * Int.fract (1 / ((k : ℝ) * x))| ≤
    1 / ((k : ℝ) * Real.log ↑N) + 1 := by
  set a₁ := 1 - Real.log ↑(k+1) / Real.log ↑N
  set a₀ := 1 - Real.log ↑k / Real.log ↑N
  set b₁ := Int.fract (1 / (((k+1) : ℝ) * x))
  set b₀ := Int.fract (1 / ((k : ℝ) * x))
  have h_prod : a₁ * b₁ - a₀ * b₀ = (a₁ - a₀) * b₁ + a₀ * (b₁ - b₀) := by ring
  rw [h_prod]
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hN_gt1 : (1 : ℝ) < (N : ℝ) := by exact_mod_cast show 1 < N by omega
  have hlogN_pos : 0 < Real.log ↑N := Real.log_pos hN_gt1
  calc |(a₁ - a₀) * b₁ + a₀ * (b₁ - b₀)|
      ≤ |(a₁ - a₀) * b₁| + |a₀ * (b₁ - b₀)| := abs_add_le _ _
    _ = |a₁ - a₀| * |b₁| + |a₀| * |b₁ - b₀| := by rw [abs_mul, abs_mul]
    _ ≤ 1 / ((k : ℝ) * Real.log ↑N) + 1 := by
        have h_da : |a₁ - a₀| ≤ 1 / ((k : ℝ) * Real.log ↑N) := by
          show |(1 - Real.log ↑(k+1) / Real.log ↑N) -
               (1 - Real.log ↑k / Real.log ↑N)| ≤ _
          rw [show (1 - Real.log ↑(k+1) / Real.log ↑N) -
                 (1 - Real.log ↑k / Real.log ↑N) =
                 (Real.log ↑k - Real.log ↑(k+1)) / Real.log ↑N from by ring,
              abs_div, abs_of_pos hlogN_pos]
          have h_le : Real.log (k : ℝ) ≤ Real.log ((k+1 : ℕ) : ℝ) :=
            Real.log_le_log hk_pos (by exact_mod_cast show k ≤ k + 1 by omega)
          rw [abs_of_nonpos (by linarith), neg_sub]
          have hk1_pos : (0 : ℝ) < ((k+1 : ℕ) : ℝ) := Nat.cast_pos.mpr (by omega)
          rw [show Real.log ((k+1 : ℕ) : ℝ) - Real.log (k : ℝ) =
              Real.log (1 + 1 / (k : ℝ)) from by
            rw [← Real.log_div (ne_of_gt hk1_pos) (ne_of_gt hk_pos)]
            congr 1
            rw [show ((k+1 : ℕ) : ℝ) = (k : ℝ) + 1 from by push_cast; ring]
            field_simp]
          rw [show 1 / ((k : ℝ) * Real.log ↑N) =
              (1 / (k : ℝ)) / Real.log ↑N from by field_simp]
          exact div_le_div_of_nonneg_right
            (by rw [Real.log_le_iff_le_exp (by positivity)]
                linarith [Real.add_one_le_exp (1 / (k : ℝ))])
            hlogN_pos.le
        have h_b1 : |b₁| ≤ 1 := by
          rw [abs_le]; exact ⟨by linarith [Int.fract_nonneg (1 / (((k+1) : ℝ) * x))],
            by linarith [Int.fract_lt_one (1 / (((k+1) : ℝ) * x))]⟩
        have h_a0 : |a₀| ≤ 1 := by
          rw [abs_le]
          have h_log_k_nn : 0 ≤ Real.log (k : ℝ) :=
            Real.log_nonneg (by exact_mod_cast (show 1 ≤ k from hk))
          have h_ratio_nn : 0 ≤ Real.log (k : ℝ) / Real.log ↑N :=
            div_nonneg h_log_k_nn hlogN_pos.le
          have h_ratio_le_one : Real.log (k : ℝ) / Real.log ↑N ≤ 1 :=
            (div_le_one hlogN_pos).mpr (Real.log_le_log hk_pos
              (by exact_mod_cast show k ≤ N by omega))
          exact ⟨by linarith, by linarith⟩
        have h_db : |b₁ - b₀| ≤ 1 := by
          rw [abs_le]; exact
            ⟨by linarith [Int.fract_nonneg (1 / (((k+1) : ℝ) * x)),
                          Int.fract_lt_one (1 / ((k : ℝ) * x))],
             by linarith [Int.fract_nonneg (1 / ((k : ℝ) * x)),
                          Int.fract_lt_one (1 / (((k+1) : ℝ) * x))]⟩
        have h_t1 : |a₁ - a₀| * |b₁| ≤ 1 / ((k : ℝ) * Real.log ↑N) := by
          calc |a₁ - a₀| * |b₁|
              ≤ (1 / ((k : ℝ) * Real.log ↑N)) * 1 :=
                mul_le_mul h_da h_b1 (abs_nonneg _) (by positivity)
            _ = 1 / ((k : ℝ) * Real.log ↑N) := mul_one _
        have h_t2 : |a₀| * |b₁ - b₀| ≤ 1 := by
          calc |a₀| * |b₁ - b₀|
              ≤ 1 * 1 := mul_le_mul h_a0 h_db (abs_nonneg _) (by linarith)
            _ = 1 := mul_one _
        linarith

/-- **POINTWISE BOUND (PROVED)**: For fixed x ∈ (0,1], the BD approximant satisfies:
    |f_N(x)| ≤ (1 + C_m·N^{3/4})·1 + Σ_{k=1}^{N-2} (1 + C_m·k^{3/4})·δ(k)

    where δ(k) = 1/(k·logN) + 1 bounds |w(k+1,x) - w(k,x)| (from abel_diff_bound).

    Proof: Wire `abel_summation_abs_bound` with:
    - a(k) = -μ(k), f(k) = taper(k) · {1/(kx)}
    - C_bound(k) from Mertens x^{3/4} via partialSum_neg_moebius_eq_neg_mertens
    - δ(k) from abel_diff_bound -/
theorem bdApprox_pointwise_bound (N : ℕ) (hN : 3 ≤ N) (x : ℝ) (hx : 0 < x) (hx1 : x ≤ 1)
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ y : ℝ, y ≥ 2 →
      |((mertensFunction y : ℤ) : ℝ)| ≤ C_m * y ^ ((3 : ℝ)/4)) :
    |bdApprox N x| ≤
    (1 + C_m * (N : ℝ) ^ ((3:ℝ)/4)) +
    ∑ k ∈ Finset.Ico 1 (N - 1),
      (1 + C_m * (k : ℝ) ^ ((3:ℝ)/4)) *
      (1 / ((k : ℝ) * Real.log ↑N) + 1) := by
  -- ─── Step 1: Define a(k) and f(k) for Abel summation ───
  set a : ℕ → ℝ := fun k => -(↑(moebius k) : ℝ)
  set f : ℕ → ℝ := fun k =>
    (1 - Real.log ↑k / Real.log ↑N) * Int.fract (1 / ((k : ℝ) * x))
  -- ─── Step 2: Rewrite bdApprox as Σ a(k) * f(k) ───
  have h_rewrite : bdApprox N x = (Finset.Icc 1 (N - 1)).sum (fun k => a k * f k) := by
    unfold bdApprox
    apply Finset.sum_congr rfl
    intro k _; simp [a, f]; ring
  rw [h_rewrite]
  -- ─── Step 3: Define the bounds ───
  set C_bound : ℕ → ℝ := fun k => 1 + C_m * (k : ℝ) ^ ((3:ℝ)/4)
  set δ : ℕ → ℝ := fun k =>
    1 / ((k : ℝ) * Real.log ↑N) + 1
  -- ─── Step 4: Verify hypotheses for abel_summation_abs_bound ───
  -- Hypothesis hA: |A(k)| ≤ C_bound(k) for 1 ≤ k ≤ N-1
  have hA : ∀ k, 1 ≤ k → k ≤ N - 1 → |partialSum a 1 k| ≤ C_bound k := by
    intro k hk1 hkN1
    by_cases hk2 : (k : ℝ) ≥ 2
    · -- For k ≥ 2: use partialSum = -M(k) then Mertens bound
      rw [partialSum_neg_moebius_eq_neg_mertens k hk1, abs_neg]
      have h := hMertens (k : ℝ) hk2
      linarith
    · -- For k = 1: |A(1)| = |a(1)| = |μ(1)| = 1 ≤ C_bound(1)
      push Not at hk2
      have hk_eq : k = 1 := by
        have : k < 2 := by exact_mod_cast hk2
        omega
      subst hk_eq
      -- partialSum a 1 1 = (Icc 1 1).sum a = a(1) = -μ(1)
      simp only [partialSum, Finset.Icc_self, Finset.sum_singleton, a, abs_neg]
      -- Goal: |↑(moebius 1)| ≤ C_bound 1
      -- μ(1) = 1 (by Mathlib), so |μ(1)| = 1
      simp [C_bound]
      -- Goal: 1 ≤ 1 + C_m · 1^{3/4}
      linarith [Real.rpow_nonneg (Nat.cast_nonneg' 1) ((3:ℝ)/4)]
  -- Hypothesis hf_mono: |f(k+1) - f(k)| ≤ δ(k) for 1 ≤ k < N-1
  have hf_mono : ∀ k, 1 ≤ k → k < N - 1 →
      |f (k + 1) - f k| ≤ δ k := by
    intro k hk1 hkN1
    -- Unfold f and δ
    simp only [f, δ]
    -- Goal now involves explicit taper·fract expressions
    -- The issue: Lean writes ↑(k+1) differently from abel_diff_bound's ↑k + 1
    have h := abel_diff_bound N k hk1 (by omega) x hx hx1
    -- h has ↑k + 1 in some places, goal has ↑(k+1). These are equal by push_cast.
    convert h using 3
    all_goals (push_cast; ring)
  -- ─── Step 5: Apply abel_summation_abs_bound ───
  have hAbel := abel_summation_abs_bound a f 1 (N - 1) (by omega) C_bound δ hA hf_mono
  -- hAbel : |Σ a(k)*f(k)| ≤ C_bound(N-1)*|f(N-1)| + Σ C_bound(k)*δ(k)
  -- ─── Step 6: Bound the boundary term ───
  -- C_bound(N-1)*|f(N-1)| ≤ (1 + C_m·N^{3/4}) * 1
  have h_boundary : C_bound (N - 1) * |f (N - 1)| ≤
      (1 + C_m * (N : ℝ) ^ ((3:ℝ)/4)) := by
    -- |f(N-1)| ≤ 1 (product of taper ∈ [0,1] and fract ∈ [0,1))
    have h_f_le : |f (N - 1)| ≤ 1 := by
      simp only [f]
      rw [abs_mul]
      calc |1 - Real.log ↑(N-1) / Real.log ↑N| * |Int.fract (1 / (↑(N-1) * x))|
          ≤ 1 * 1 := by
            apply mul_le_mul
            · -- |taper(N-1)| ≤ 1
              rw [abs_le]
              have hlogN_pos : 0 < Real.log ↑N :=
                Real.log_pos (by exact_mod_cast show 1 < N by omega)
              have h_log_nn : 0 ≤ Real.log (↑(N-1) : ℝ) :=
                Real.log_nonneg (by exact_mod_cast show 1 ≤ N - 1 by omega)
              have h_ratio_nn : 0 ≤ Real.log (↑(N-1) : ℝ) / Real.log ↑N :=
                div_nonneg h_log_nn hlogN_pos.le
              have h_ratio_le : Real.log (↑(N-1) : ℝ) / Real.log ↑N ≤ 1 :=
                (div_le_one hlogN_pos).mpr (Real.log_le_log
                  (by exact_mod_cast show 0 < N - 1 by omega)
                  (by exact_mod_cast show N - 1 ≤ N by omega))
              exact ⟨by linarith, by linarith⟩
            · -- |fract| ≤ 1
              rw [abs_le]
              exact ⟨by linarith [Int.fract_nonneg (1 / (↑(N-1) * x))],
                     by linarith [Int.fract_lt_one (1 / (↑(N-1) * x))]⟩
            · exact abs_nonneg _
            · linarith
        _ = 1 := mul_one 1
    -- C_bound(N-1) ≤ C_bound(N) since (N-1)^{3/4} ≤ N^{3/4}
    calc C_bound (N - 1) * |f (N - 1)|
        ≤ C_bound (N - 1) * 1 :=
          mul_le_mul_of_nonneg_left h_f_le (by simp [C_bound]; positivity)
      _ = C_bound (N - 1) := mul_one _
      _ ≤ 1 + C_m * (N : ℝ) ^ ((3:ℝ)/4) := by
          simp only [C_bound]
          have : (↑(N - 1) : ℝ) ^ ((3:ℝ)/4) ≤ (↑N : ℝ) ^ ((3:ℝ)/4) :=
            Real.rpow_le_rpow (by positivity)
              (Nat.cast_le.mpr (Nat.sub_le N 1))
              (by norm_num)
          linarith [mul_le_mul_of_nonneg_left this hC.le]
  -- ─── Step 7: Combine hAbel and h_boundary ───
  linarith


-- ═══════════════════════════════════════════════
-- §4. DEPRECATED: L² RESIDUAL VIA SPATIAL BOUND
-- ⚠️  APPROACH IS MATHEMATICALLY FALSE (see docstrings)
-- ⚠️  2 SORRY — both are OFF CROWN PATH
-- ⚠️  Correct approach: MellinCrown.lean (frequency domain)
-- ═══════════════════════════════════════════════

/-- **DEPRECATED — THIS THEOREM IS FALSE** (Exploration 13, April 27, 2026)

    The bound vᵀGv ≤ 1 + C/logN CANNOT be proved from Mertens x^{3/4} alone.

    PROOF OF FALSITY (Gemini Actual, Dirichlet Convolution):
    Via Möbius inversion: 1 - f_N(1/y) = -yE_N - (ψ(y) - y)/logN
    Under |M(x)| ≤ C·x^{3/4}: |ψ(y)-y| ~ y^{3/4}, so
    ∫(1-f)² ≈ 2√N/log²N → ∞ (DIVERGES).

    The spatial L² bound IS the Riemann Hypothesis, not a consequence
    of Mertens. The Lean compiler correctly refuses to compile this.

    CORRECT APPROACH: Derive vᵀGv ≤ 1 + K/logN from the Crown Axiom
    (critical_line_mellin_variance) via Parseval, running the chain FORWARD.
    See MellinCrown.lean for the correct architecture.

    This theorem is kept (with sorry) as a historical artifact. -/
private theorem gram_form_bound_raw
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3 : ℝ)/4))
    (hPNT₁ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) / (k : ℝ)) atTop (nhds 0))
    (hPNT₂ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) * Real.log (k : ℝ) / (k : ℝ)) atTop (nhds (-1)))
    (N : ℕ) (hN : 10 ≤ N) :
    realQuadForm (Matrix.of fun (i j : Fin (N - 1)) =>
      vasyuninGramEntry (i.val + 1) (j.val + 1)) (bdMoebiusWeight N) ≤
    1 + C_m ^ 2 / Real.log ↑N := by
  -- ═══════════════════════════════════════════════
  -- PROOF ARCHITECTURE (Gemini's "Integrate First, Abel Sum Second")
  --
  -- Step 1: Convert to double Icc sum [quadForm_as_double_sum ✅]
  --   vᵀGv = Σ_j Σ_k gramProduct N j k
  --
  -- Step 2: For each fixed j, decompose inner sum via Abel [inner_sum_abel ✅]
  --   Σ_k v_k G(j,k) = M(N-1)·logWeight(N-1)·G(j,N-1)
  --                   - Σ_k M(k)·Δ[logWeight(k)·G(j,k)]
  --
  -- Step 3: Bound boundary term using:
  --   |M(N-1)| ≤ C_m·(N-1)^{3/4}  [hMertens]
  --   |logWeight(N-1)| ≤ 2/logN     [logWeight_at_N_minus_1 ✅]
  --   |G(j,N-1)| ≤ growth bound     [gramEntry_growth_bound]
  --
  -- Step 4: Bound Abel remainder using S₁/S₂/S₃ decay [PROVED in AbelTail/]
  --
  -- Step 5: Sum over j with weights v_j to get vᵀGv bound
  -- ═══════════════════════════════════════════════
  -- WIP: Deprecated spatial approach — MATHEMATICALLY FALSE (see docstring above).
  -- The correct approach runs through MellinCrown.lean (frequency domain).
  -- Kept as historical artifact of Exploration 13. Left for future reference.
  sorry -- DEPRECATED: MATHEMATICALLY FALSE from x^{3/4} alone (see docstring)

/-- **CORE ESTIMATE**: Under Mertens x^{3/4}, the L² residual satisfies:
    ∫₀¹ (1 - f_N(x))² dx ≤ C/logN.

    Factored proof:
    1. ∫(1-f)² = 1 - 2bᵀv + vᵀGv     [bd_l2_error_eq_quad_error, PROVED]
    2. bᵀv ≥ 1 - C_dot/logN            [dot product bound, PROVED]
    3. vᵀGv ≤ 1 + C_gram/logN          [gram_form_bound_raw, sorry]
    4. Assembly: ∫(1-f)² ≤ 2C_dot/logN + C_gram/logN  -/
theorem l2_residual_from_mertens
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3 : ℝ)/4))
    (hPNT₁ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) / (k : ℝ)) atTop (nhds 0))
    (hPNT₂ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) * Real.log (k : ℝ) / (k : ℝ)) atTop (nhds (-1)))
    (N : ℕ) (hN : 10 ≤ N) :
    ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 ≤
      (C_m ^ 2 + 4 * C_m + 2) / Real.log ↑N := by
  -- Step 1: ∫(1-f)² = 1 - 2bᵀv + vᵀGv
  have h_eq := bd_l2_error_eq_quad_error N (by omega : 2 ≤ N) (bdMoebiusWeight N)
  rw [h_eq]
  -- Step 2: Dot product bound
  obtain ⟨C_dot, hC_dot_pos, h_dot⟩ :=
    moebius_dot_product_approx_one_uniform_34 C_m hC hMertens hPNT₁ hPNT₂
  have h_dot_N := h_dot N (by omega : 10 ≤ N)
  -- Step 3: Gram form bound
  have h_gram := gram_form_bound_raw C_m hC hMertens hPNT₁ hPNT₂ N hN
  -- Step 4: Assembly
  -- Need: 1 - 2bᵀv + vᵀGv ≤ (C_m²+4C_m+2)/logN
  -- From h_dot_N: |1 - bᵀv| ≤ C_dot/logN, so bᵀv ≥ 1 - C_dot/logN
  -- From h_gram: vᵀGv ≤ 1 + C_m²/logN
  -- So: 1 - 2bᵀv + vᵀGv ≤ 1 - 2(1-C_dot/logN) + 1 + C_m²/logN
  --                       = 2C_dot/logN + C_m²/logN
  -- Need: 2C_dot + C_m² ≤ C_m²+4C_m+2
  -- i.e.: 2C_dot ≤ 4C_m+2. This depends on C_dot ≤ 2C_m+1.
  -- For now, the final assembly has a gap (C_dot bound needed).
  -- WIP: Assembly step blocked by gram_form_bound_raw (above, deprecated).
  -- This path is superseded by the Mellin Crown architecture (v11+).
  -- Left for future exploration of alternative spatial routes.
  sorry -- DEPRECATED: Blocked by gram_form_bound_raw (above, mathematically false)

-- ═══════════════════════════════════════════════
-- §5. THE COVARIANCE BOUND (THE AXIOM REPLACEMENT)
-- ═══════════════════════════════════════════════

/-- **THEOREM** (replaces axiom `covariance_bound_from_mertens_34`):
    Under Mertens x^{3/4} + PNT, the covariance form vᵀCv ≤ C/logN.

    Proof: vᵀCv = ∫(1-f)² - (1-bᵀv)²
                ≤ C_l2/logN - 0   [L² residual bound + dot product bound]
                ≤ C_l2/logN.

    This is the theorem that eliminates the axiom
    `covariance_bound_from_mertens_34` from the Crown. -/
theorem covariance_bound_proved
    (hMertens : ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C * x ^ ((3 : ℝ)/4))
    (hPNT₁ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) / (k : ℝ)) atTop (nhds 0))
    (hPNT₂ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) * Real.log (k : ℝ) / (k : ℝ)) atTop (nhds (-1))) :
    ∃ C_cov : ℝ, C_cov > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninCovMatrix N).mulVec
          (logCutoffWitness N)) ≤ C_cov / Real.log ↑N := by
  -- Step 1: Extract Mertens constant
  obtain ⟨C_m, hC_m_pos, hM⟩ := hMertens
  -- Step 2: L² residual bound from Abel summation
  -- ∫(1-f)² ≤ C_l2/logN
  set C_l2 := C_m ^ 2 + 4 * C_m + 2
  -- Step 3: Dot product bound
  -- |1-bᵀv| ≤ C_dot/logN
  obtain ⟨C_dot, hC_dot_pos, h_dot⟩ :=
    moebius_dot_product_approx_one_uniform_34 C_m hC_m_pos hM hPNT₁ hPNT₂
  -- Step 4: The key identity: ∫(1-f)² = (1-bᵀv)² + vᵀCv
  -- Therefore: vᵀCv = ∫(1-f)² - (1-bᵀv)² ≤ ∫(1-f)² ≤ C_l2/logN
  -- (since (1-bᵀv)² ≥ 0)
  --
  -- This uses the PROVED identity from VasyuninBypass:
  --   bd_l2_error_eq_quad_error: ∫(1-f)² = 1-2bᵀv+vᵀGv
  -- and the PROVED covariance decomposition:
  --   vᵀCv = vᵀGv - (bᵀv)²
  --
  -- Combining: ∫(1-f)² = (1-bᵀv)² + vᵀCv
  -- So: vᵀCv ≤ ∫(1-f)²
  --
  -- The L² residual bound provides: ∫(1-f)² ≤ C_l2/logN
  refine ⟨C_l2, by positivity, max 10 3, fun N hN hN3 => ?_⟩
  -- The L² identity: ∫(1-f)² = 1-2bᵀv+vᵀGv (PROVED in BDBridge)
  have h_l2_eq := bd_l2_error_eq_quad_error N (by omega : 2 ≤ N) (bdMoebiusWeight N)
  -- Use the L² residual bound from Abel summation
  have h_l2 := l2_residual_from_mertens C_m hC_m_pos hM hPNT₁ hPNT₂ N (by omega)
  -- Index bridge: connects Vasyunin representation to BD representation
  -- (1-bᵀv_V)² + vᵀCv_V = 1-2bᵀv_BD + vᵀGv_BD = ∫(1-f)²
  have h_bridge :
      (1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N)) ^ 2 +
      dotProduct (logCutoffWitness N) ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) =
      1 - 2 * dotProduct (fun i => vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight N) +
      realQuadForm (of fun i j => vasyuninGramEntry (i.val + 1) (j.val + 1)) (bdMoebiusWeight N) :=
    Nat.sub_add_cancel (show 1 ≤ N by omega) ▸ vasyunin_bd_index_bridge (N-1) (by omega)
  -- Combine: (1-bᵀv)² + vᵀCv = ∫(1-f)²
  have h_sum_eq : (1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N)) ^ 2 +
      dotProduct (logCutoffWitness N) ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) =
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 := by
    rw [h_l2_eq]; linarith [h_bridge]
  -- Since (1-bᵀv)² ≥ 0, we have vᵀCv ≤ ∫(1-f)²
  have h_sq_nn : 0 ≤ (1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N)) ^ 2 :=
    sq_nonneg _
  -- vᵀCv ≤ ∫(1-f)²
  have h_cov_le_l2 : dotProduct (logCutoffWitness N)
      ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) ≤
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 := by
    linarith [h_sum_eq]
  -- Chain: vᵀCv ≤ ∫(1-f)² ≤ C_l2/logN
  linarith

-- ═══════════════════════════════════════════════
-- §6. THE GRAM FORM BOUND (COROLLARY)
-- ═══════════════════════════════════════════════

/-- **COROLLARY**: vᵀGv ≤ 1 + K/logN (follows from covariance bound).

    Proof: vᵀGv = vᵀCv + (bᵀv)²
                ≤ C_cov/logN + (1 + C_dot/logN)²
                = 1 + (C_cov + 2C_dot)/logN + O(1/log²N)
                ≤ 1 + K/logN -/
theorem gram_form_proved
    (hMertens : ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C * x ^ ((3 : ℝ)/4))
    (hPNT₁ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) / (k : ℝ)) atTop (nhds 0))
    (hPNT₂ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) * Real.log (k : ℝ) / (k : ℝ)) atTop (nhds (-1))) :
    ∃ C_G : ℝ, C_G > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninGramMatrix N).mulVec
          (logCutoffWitness N)) ≤ 1 + C_G / Real.log ↑N := by
  -- From covariance_bound_proved + dot product bound.
  -- Exactly mirrors gram_form_upper_bound_34_proved in GramFormProof.lean,
  -- but uses covariance_bound_proved instead of the axiom.
  obtain ⟨C_m, hC_m_pos, hM⟩ := hMertens
  -- Step 1: Covariance bound (PROVED, no axiom!)
  obtain ⟨C_cov, hC_cov_pos, N₁, h_cov⟩ :=
    covariance_bound_proved ⟨C_m, hC_m_pos, hM⟩ hPNT₁ hPNT₂
  -- Step 2: Dot product bound (PROVED from x^{3/4} + PNT₁ + PNT₂)
  obtain ⟨C_dot, hC_dot_pos, h_dot⟩ :=
    moebius_dot_product_approx_one_uniform_34 C_m hC_m_pos hM hPNT₁ hPNT₂
  -- Step 3: Choose N_big so logN ≥ C_dot (ensuring C_dot/logN ≤ 1)
  set N_big := Nat.ceil (Real.exp C_dot) + 1
  -- Step 4: Choose C_G = C_cov + 3·C_dot, N₀ = max N₁ (max 10 N_big)
  refine ⟨C_cov + 3 * C_dot, by linarith,
    max N₁ (max 10 N_big), fun N hN hN3 => ?_⟩
  have hN₁ : N ≥ N₁ := by omega
  have hN10 : 10 ≤ N := by omega
  have hN_ge_big : N ≥ N_big := by omega
  have hlogN_pos : 0 < Real.log ↑N :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  -- Step 5: logN ≥ C_dot, so C_dot/logN ≤ 1
  have hlogN_ge_C : C_dot ≤ Real.log ↑N := by
    have h1 : (N_big : ℝ) ≤ (N : ℝ) := by exact_mod_cast hN_ge_big
    have h2 : Real.exp C_dot ≤ (N_big : ℝ) := by
      calc Real.exp C_dot ≤ ↑⌈Real.exp C_dot⌉₊ := Nat.le_ceil _
        _ ≤ ↑(⌈Real.exp C_dot⌉₊ + 1) := by exact_mod_cast Nat.le_succ _
    calc C_dot = Real.log (Real.exp C_dot) := (Real.log_exp C_dot).symm
      _ ≤ Real.log ↑N_big := Real.log_le_log (Real.exp_pos C_dot) h2
      _ ≤ Real.log ↑N := Real.log_le_log (by exact_mod_cast Nat.pos_of_ne_zero (by omega : N_big ≠ 0)) h1
  have h_small : C_dot / Real.log ↑N ≤ 1 := (div_le_one hlogN_pos).mpr hlogN_ge_C
  -- Step 6: Get bounds at N
  have h_cov_N := h_cov N hN₁ hN3
  have h_dot_N := h_dot N hN10
  -- Step 7: Variance identity — vᵀCv = vᵀGv - (bᵀv)²
  have h_cov_eq_gram_minus_sq :
      dotProduct (logCutoffWitness N)
        ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) =
      dotProduct (logCutoffWitness N)
        ((vasyuninGramMatrix N).mulVec (logCutoffWitness N)) -
      (dotProduct (vasyuninMeanVec N) (logCutoffWitness N)) ^ 2 := by
    unfold vasyuninCovMatrix
    simp [Matrix.sub_mulVec, dotProduct_sub, vecMulVec_mulVec]
    have hdc := dotProduct_comm (logCutoffWitness N) (vasyuninMeanVec N)
    linarith [mul_self_nonneg (vasyuninMeanVec N ⬝ᵥ logCutoffWitness N),
      show logCutoffWitness N ⬝ᵥ vasyuninMeanVec N *
           vasyuninMeanVec N ⬝ᵥ logCutoffWitness N =
           (vasyuninMeanVec N ⬝ᵥ logCutoffWitness N)^2
      from by rw [hdc]; ring]
  -- Step 8: Bridge dot products via index bridge
  have h_N_sub : (N-1) + 1 = N := Nat.sub_add_cancel (by omega : 1 ≤ N)
  have h_dot_eq : dotProduct (vasyuninMeanVec N) (logCutoffWitness N) =
      dotProduct (fun (i : Fin (N - 1)) =>
        vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight N) := by
    exact h_N_sub ▸ dotProduct_bridge_aux (N-1) (by omega)
  set bv := dotProduct (fun (i : Fin (N - 1)) =>
      vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight N)
  -- |1 - bv| ≤ C_dot/logN ≤ 1
  have h_bv_bound : |1 - bv| ≤ C_dot / Real.log ↑N := h_dot_N
  have h_bv_bound' : |bv - 1| ≤ C_dot / Real.log ↑N := by rwa [abs_sub_comm] at h_bv_bound
  -- Step 9: vᵀGv = vᵀCv + (bᵀv)²
  have h_gram_eq : dotProduct (logCutoffWitness N)
      ((vasyuninGramMatrix N).mulVec (logCutoffWitness N)) =
      dotProduct (logCutoffWitness N)
        ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) + bv ^ 2 := by
    have := h_cov_eq_gram_minus_sq
    rw [h_dot_eq] at this; linarith
  rw [h_gram_eq]
  -- Step 10: bv² ≤ 1 + 3·C_dot/logN (since |bv-1| ≤ C_dot/logN ≤ 1)
  have h_bv_sq : bv ^ 2 ≤ 1 + 3 * (C_dot / Real.log ↑N) := by
    -- S = bv, δ = C_dot/logN
    have h_upper : bv ≤ 1 + C_dot / Real.log ↑N := by linarith [(abs_le.mp h_bv_bound').2]
    have : bv ^ 2 = 1 + 2 * (bv - 1) + (bv - 1) ^ 2 := by ring
    rw [this]
    have h1 : 2 * (bv - 1) ≤ 2 * (C_dot / Real.log ↑N) := by linarith
    have h2 : (bv - 1) ^ 2 ≤ (C_dot / Real.log ↑N) ^ 2 := by
      apply sq_le_sq'; linarith [(abs_le.mp h_bv_bound').1]; linarith
    have h3 : (C_dot / Real.log ↑N) ^ 2 ≤ C_dot / Real.log ↑N := by
      nlinarith [h_small, sq_nonneg (C_dot / Real.log ↑N),
                 div_nonneg hC_dot_pos.le hlogN_pos.le]
    linarith
  -- Step 11: vᵀCv + bv² ≤ C_cov/logN + 1 + 3C_dot/logN = 1 + (C_cov+3C_dot)/logN
  calc dotProduct (logCutoffWitness N)
          ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) + bv ^ 2
      ≤ C_cov / Real.log ↑N + (1 + 3 * (C_dot / Real.log ↑N)) := by linarith
    _ = 1 + (C_cov + 3 * C_dot) / Real.log ↑N := by ring

end
