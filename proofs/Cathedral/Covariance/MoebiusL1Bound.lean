/-
  Cathedral/Assembly/MoebiusL1Bound.lean

  ## THE MÖBIUS LINEAR TERM AND L² ASSEMBLY

  This file contains the two key theorems connecting the Möbius
  weights to the Báez-Duarte L² criterion:

  1. `moebius_dot_product_approx_one`:
     bᵀv ≈ 1, i.e., the dot product of the Vasyunin mean vector
     with the Möbius log-taper weights converges to 1.

  2. `mertens_implies_l2_decay`:
     The L² error ∫(1 - Σ v_k·{1/(kx)})² → 0.
-/

import Cathedral.MellinBridge.BDWeights
import Cathedral.MellinBridge.MertensBound
import Cathedral.Vasyunin.Augmented.DiagBound
import Cathedral.Vasyunin.Proof.WitnessConditional
import Cathedral.NymanBeurling.BDBridge
import Cathedral.Covariance.DotProductIdentity
import Cathedral.Covariance.CalcBounds
import Cathedral.AbelTail.L2Bridge
import Cathedral.NymanBeurling.VasyuninBypass
import Cathedral.AbelTail.S1Decay
import Cathedral.AbelTail.S2Decay

noncomputable section
open Real MeasureTheory Finset Cathedral.Vasyunin ArithmeticFunction Filter

-- ════════════════════════════════════════════════
-- §1. |v_k| ≤ 1 BOUND
-- ════════════════════════════════════════════════

/-- **PROVED**: Each |v_k| ≤ 1 for the Möbius log-taper weights.

    Since |μ(k)| ≤ 1 and 0 ≤ logWeight(N,k) ≤ 1 for k ≤ N,
    we have |v_k| = |μ(k)|·logWeight(N,k) ≤ 1. -/
theorem bdMoebiusWeight_abs_le_one (N : ℕ) (hN : 2 ≤ N) (i : Fin (N - 1)) :
    |bdMoebiusWeight N i| ≤ 1 := by
  unfold bdMoebiusWeight logWeight
  -- Step 1: |μ(k)| ≤ 1 → -1 ≤ μ(k) ≤ 1
  have h_mu : |(↑(moebius (i.val + 1)) : ℝ)| ≤ 1 := by exact_mod_cast abs_moebius_le_one
  rw [abs_le] at h_mu
  obtain ⟨h_mu_lo, h_mu_hi⟩ := h_mu
  -- Step 2: log(k+1)/log(N) ∈ [0,1] for k+1 ≤ N
  have hlog_N_pos : 0 < Real.log (N : ℝ) :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  have h_lw_le : 1 - Real.log (↑(i.val + 1)) / Real.log ↑N ≤ 1 := by
    have : (1 : ℝ) ≤ ((i.val + 1 : ℕ) : ℝ) := by exact_mod_cast show 1 ≤ i.val + 1 by omega
    linarith [div_nonneg (Real.log_nonneg this) hlog_N_pos.le]
  have h_lw_nn : (0 : ℝ) ≤ 1 - Real.log (↑(i.val + 1)) / Real.log ↑N := by
    have h_div : Real.log (↑(i.val + 1)) / Real.log ↑N ≤ 1 := by
      rw [div_le_one hlog_N_pos]
      exact Real.log_le_log (by exact_mod_cast (show 0 < i.val + 1 by omega))
        (by exact_mod_cast (show i.val + 1 ≤ N by omega))
    linarith
  -- Step 3: |(-μ)·w| ≤ 1 from -1 ≤ μ ≤ 1 and 0 ≤ w ≤ 1
  rw [abs_le]
  constructor <;> nlinarith

-- ════════════════════════════════════════════════
-- §2. ℓ¹ NORM BOUND
-- ════════════════════════════════════════════════

/-- **PROVED**: Σ|v_k| ≤ N-1 (crude bound using |v_k| ≤ 1). -/
theorem moebius_weight_l1_crude (N : ℕ) (hN : 2 ≤ N) :
    ∑ i : Fin (N - 1), |bdMoebiusWeight N i| ≤ (N : ℝ) - 1 := by
  calc ∑ i : Fin (N - 1), |bdMoebiusWeight N i|
      ≤ ∑ _i : Fin (N - 1), (1 : ℝ) :=
        Finset.sum_le_sum fun i _ => bdMoebiusWeight_abs_le_one N hN i
    _ = (Fintype.card (Fin (N - 1)) : ℝ) := by
        simp [Finset.sum_const, nsmul_eq_mul, mul_one]
    _ = ((N - 1 : ℕ) : ℝ) := by simp [Fintype.card_fin]
    _ = (N : ℝ) - 1 := by
        rw [Nat.cast_sub (by omega : 1 ≤ N)]
        simp

-- ════════════════════════════════════════════════
-- §3. THE DOT PRODUCT bᵀv ≈ 1 (LINEAR TERM BOUND)
-- ════════════════════════════════════════════════

/-- **THEOREM**: The dot product bᵀv converges to 1 at rate O(1/log N).

    The dot product decomposes algebraically as:
      1 - bᵀv = (1-γ)·S₁(N-1) + (S₂(N-1)+1)
                 - [(1-γ)·S₂(N-1) + S₃(N-1)] / log(N)

    Under PNT₁ (S₁→0) and PNT₂ (S₂→-1), the first two terms
    decay as O(N^{-1/4}), which is O(1/logN) for N ≥ 10.
    The third term has main value (γ+1)/logN ≈ 1.577/logN.

    The bound is existential: ∃ C_dot > 0 depending on C_m. -/
theorem moebius_dot_product_approx_one
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x ≥ 2,
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x^(1/2 : ℝ) * (Real.log x)^2)
    -- PNT hypotheses (standard consequences of RH/Mertens)
    (hPNT₁ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) / (k : ℝ)) atTop (nhds 0))
    (hPNT₂ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) * Real.log (k : ℝ) / (k : ℝ)) atTop (nhds (-1)))
    (hPNT₃ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) * (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
        atTop (nhds (-2 * eulerMascheroniConstant)))
    (N : ℕ) (hN : 10 ≤ N) :
    ∃ C_dot : ℝ, C_dot > 0 ∧
    |1 - dotProduct (fun i => vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight N)| ≤
    C_dot / Real.log ↑N := by
  -- Step 0: Convert Mertens bound from O(√x·log²x) to O(x^{3/4})
  have hMertens34 : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ (64 * C_m) * x ^ ((3:ℝ)/4) := by
    intro x hx
    have hx_pos : (0 : ℝ) < x := by linarith
    calc |((mertensFunction x : ℤ) : ℝ)|
        ≤ C_m * x ^ ((1:ℝ)/2) * (Real.log x) ^ 2 := hMertens x hx
      _ ≤ C_m * (64 * x ^ ((3:ℝ)/4)) := by
          have h_key : x ^ ((1:ℝ)/2) * (Real.log x) ^ 2 ≤ 64 * x ^ ((3:ℝ)/4) := by
            have ht_ge1 : 1 ≤ x ^ ((1:ℝ)/8) := by
              rw [← Real.rpow_zero x]
              exact Real.rpow_le_rpow_of_exponent_le (by linarith) (by norm_num)
            have h_log_le : Real.log (x ^ ((1:ℝ)/8)) ≤ x ^ ((1:ℝ)/8) := by
              linarith [Real.add_one_le_exp (Real.log (x ^ ((1:ℝ)/8))),
                        Real.exp_log (lt_of_lt_of_le one_pos ht_ge1)]
            have h_log_eq : Real.log x = 8 * Real.log (x ^ ((1:ℝ)/8)) := by
              rw [Real.log_rpow hx_pos]; ring
            have h_t_sq : (x ^ ((1:ℝ)/8)) ^ 2 = x ^ ((1:ℝ)/4) := by
              rw [← Real.rpow_natCast (x ^ ((1:ℝ)/8)) 2,
                  ← Real.rpow_mul (le_of_lt hx_pos)]
              norm_num
            calc x ^ ((1:ℝ)/2) * (Real.log x) ^ 2
                = x ^ ((1:ℝ)/2) * (64 * (Real.log (x ^ ((1:ℝ)/8))) ^ 2) := by
                  rw [h_log_eq]; ring
              _ ≤ x ^ ((1:ℝ)/2) * (64 * (x ^ ((1:ℝ)/8)) ^ 2) := by
                  apply mul_le_mul_of_nonneg_left _ (le_of_lt (Real.rpow_pos_of_pos hx_pos _))
                  apply mul_le_mul_of_nonneg_left _ (by norm_num)
                  exact pow_le_pow_left₀ (Real.log_nonneg ht_ge1) h_log_le 2
              _ = 64 * (x ^ ((1:ℝ)/2) * x ^ ((1:ℝ)/4)) := by rw [h_t_sq]; ring
              _ = 64 * x ^ ((3:ℝ)/4) := by
                  congr 1; rw [← Real.rpow_add hx_pos]; norm_num
          nlinarith [Real.rpow_pos_of_pos hx_pos ((1:ℝ)/2),
                     Real.rpow_pos_of_pos hx_pos ((3:ℝ)/4)]
      _ = (64 * C_m) * x ^ ((3:ℝ)/4) := by ring
  -- Step 1: S₁ decay: ∃ C₁ > 0, |S₁(N)| ≤ C₁·N^{-1/4}
  obtain ⟨C₁, hC₁_pos, h_s1⟩ := s1_decay (64 * C_m) (by positivity) hMertens34 hPNT₁
  -- Step 2: S₂ decay: ∃ C₂ > 0, |S₂(N)+1| ≤ C₂·N^{-1/4}·log(N)
  obtain ⟨C₂, hC₂_pos, h_s2⟩ := s2_decay (64 * C_m) (by positivity) hMertens34 hPNT₂
  -- Step 3: Bound S₂ and S₃ universally using tendsto_universal_bound
  obtain ⟨B₂, hB₂_ge, h_s2_univ⟩ := tendsto_universal_bound hPNT₂
  obtain ⟨B₃, hB₃_ge, h_s3_univ⟩ := tendsto_universal_bound hPNT₃
  -- |S₂(n)+1| ≤ B₂ for all n, |S₃(n)+2γ| ≤ B₃ for all n
  -- Step 4: Choose C_dot
  -- From the algebraic identity + triangle inequality:
  --   |1-bᵀv|·logN ≤ |1-γ|·|S₁|·logN + |S₂+1|·logN + |(1-γ)·S₂+S₃|
  -- Using (N-1)^{-1/4}·logN ≤ 2:
  --   |S₁|·logN ≤ C₁·2, |S₂+1|·logN ≤ C₂·10
  --   |(1-γ)·S₂+S₃| ≤ |S₂|+1 + |S₃| ≤ B₂+2 + B₃+2|γ| ≤ B₂+B₃+4
  refine ⟨2 * C₁ + 10 * C₂ + B₂ + B₃ + 4, by linarith, ?_⟩
  -- Key facts about N
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have hlogN_pos : (0 : ℝ) < Real.log ↑N :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  have hlogN_ne : Real.log (↑N : ℝ) ≠ 0 := ne_of_gt hlogN_pos
  have hN1_ge2 : 2 ≤ N - 1 := by omega
  -- Step 5: Apply the algebraic identity
  have h_identity := one_minus_dotProduct_identity N (by omega) hlogN_ne
  -- Step 6: Get S₁ and S₂ decay bounds at N-1
  have h_s1_N := h_s1 (N - 1) hN1_ge2
  have h_s2_N := h_s2 (N - 1) hN1_ge2
  -- Step 7: Universal bounds on |S₂| and |S₃|
  have h_s2_abs : |S₂_at (N - 1)| ≤ B₂ + 1 := by
    have h1 := h_s2_univ (N - 1)
    -- h1 : |Σ μ·logk/k - (-1)| ≤ B₂, this is |S₂+1| ≤ B₂
    -- Need: |S₂| ≤ B₂ + 1
    unfold S₂_at
    -- Now goal has the raw sum. h1 also has the raw sum.
    -- |Σ - (-1)| ≤ B₂ means -B₂ ≤ Σ+1 ≤ B₂ so -B₂-1 ≤ Σ ≤ B₂-1
    have h2 := abs_le.mp h1
    exact abs_le.mpr ⟨by linarith, by linarith⟩
  have h_s3_abs : |S₃_at (N - 1)| ≤ B₃ + 2 := by
    have h1 := h_s3_univ (N - 1)
    -- h1 : |Σ μ·log²k/k - (-2γ)| ≤ B₃
    unfold S₃_at
    have h2 := abs_le.mp h1
    -- -B₃ ≤ Σ + 2γ ≤ B₃, so -B₃-2γ ≤ Σ ≤ B₃-2γ
    -- eulerMascheroniConstant ∈ (1/2, 2/3), so 2γ ∈ (1, 4/3) ⊂ (0,2)
    have hγ_pos : 0 < eulerMascheroniConstant := by
      linarith [one_half_lt_eulerMascheroniConstant]
    have hγ_lt1 : eulerMascheroniConstant < 1 := by
      linarith [eulerMascheroniConstant_lt_two_thirds]
    exact abs_le.mpr ⟨by nlinarith, by nlinarith⟩
  -- Step 8: Rewrite using the identity
  rw [h_identity]
  -- Goal: |(1-γ)·S₁ + (S₂+1) - [(1-γ)·S₂+S₃]/logN| ≤ C_dot/logN
  -- Step 8a: Calculus bounds
  have h_calc1 := rpow_quarter_logN_le_two N hN
  -- (N-1)^{-1/4} · logN ≤ 2
  have h_calc2 := rpow_quarter_logsq_le_ten N hN
  -- (N-1)^{-1/4} · log(N-1) · logN ≤ 10
  -- Step 8b: Convert decay bounds to 1/logN bounds
  -- |S₁|·logN ≤ C₁·(N-1)^{-1/4}·logN ≤ 2·C₁
  have h_s1_logN : |S₁_at (N - 1)| * Real.log ↑N ≤ 2 * C₁ := by
    calc |S₁_at (N - 1)| * Real.log ↑N
        ≤ C₁ * (↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log ↑N :=
          mul_le_mul_of_nonneg_right h_s1_N (le_of_lt hlogN_pos)
      _ = C₁ * ((↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log ↑N) := by ring
      _ ≤ C₁ * 2 := mul_le_mul_of_nonneg_left h_calc1 hC₁_pos.le
      _ = 2 * C₁ := by ring
  -- |S₂+1|·logN ≤ C₂·(N-1)^{-1/4}·log(N-1)·logN ≤ 9·C₂
  have h_s2_logN : |S₂_at (N - 1) - (-1)| * Real.log ↑N ≤ 10 * C₂ := by
    calc |S₂_at (N - 1) - (-1)| * Real.log ↑N
        ≤ C₂ * (↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log (↑(N - 1) : ℝ) * Real.log ↑N :=
          mul_le_mul_of_nonneg_right h_s2_N (le_of_lt hlogN_pos)
      _ = C₂ * ((↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log (↑(N - 1) : ℝ) * Real.log ↑N) := by ring
      _ ≤ C₂ * 10 := mul_le_mul_of_nonneg_left h_calc2 hC₂_pos.le
      _ = 10 * C₂ := by ring
  -- Step 8c: Triangle inequality + assembly
  -- Sufficient: |...|·logN ≤ C_dot (since div by logN > 0)
  suffices h_main : |(1 - eulerMascheroniConstant) * S₁_at (N - 1) +
      (S₂_at (N - 1) + 1) -
      ((1 - eulerMascheroniConstant) * S₂_at (N - 1) + S₃_at (N - 1)) /
        Real.log ↑N| * Real.log ↑N ≤
      2 * C₁ + 10 * C₂ + B₂ + B₃ + 4 by
    rw [le_div_iff₀ hlogN_pos]
    linarith
  -- Now: |A + B - C/L| · L ≤ D
  -- Use: |A + B - C/L|·L ≤ (|A| + |B| + |C|/L)·L = |A|·L + |B|·L + |C|
  -- We need triangle inequality: |a + b - c| ≤ |a| + |b| + |c|
  -- and |S₂+1| = |S₂ - (-1)|
  -- Key: |S₂+1| = |S₂ - (-1)| for matching h_s2_logN
  have h_s2_eq : S₂_at (N - 1) + 1 = S₂_at (N - 1) - (-1) := by ring
  -- Bound |(1-γ)·S₂+S₃|
  have h_num : |(1 - eulerMascheroniConstant) * S₂_at (N - 1) +
      S₃_at (N - 1)| ≤ B₂ + B₃ + 3 := by
    have hγ01 : 0 < 1 - eulerMascheroniConstant ∧
        1 - eulerMascheroniConstant < 1 := by
      constructor
      · linarith [eulerMascheroniConstant_lt_two_thirds]
      · linarith [one_half_lt_eulerMascheroniConstant]
    -- |(1-γ)·S₂| ≤ |S₂| since |1-γ| < 1
    have h_s2_bound : -(B₂ + 1) ≤ (1 - eulerMascheroniConstant) * S₂_at (N - 1) ∧
        (1 - eulerMascheroniConstant) * S₂_at (N - 1) ≤ B₂ + 1 := by
      constructor
      · nlinarith [abs_le.mp h_s2_abs]
      · nlinarith [abs_le.mp h_s2_abs]
    have h_s3_bound := abs_le.mp h_s3_abs
    exact abs_le.mpr ⟨by nlinarith, by nlinarith⟩
  -- Bound |div term| · logN = |numerator| (cancel logN)
  have h_div_logN : |((1 - eulerMascheroniConstant) * S₂_at (N - 1) +
      S₃_at (N - 1)) / Real.log ↑N| * Real.log ↑N ≤ B₂ + B₃ + 3 := by
    rw [abs_div, abs_of_pos hlogN_pos, div_mul_cancel₀ _ hlogN_ne]
    exact h_num
  -- Bound |(1-γ)·S₁|·logN ≤ |S₁|·logN ≤ 2C₁
  have h_term1_logN : |(1 - eulerMascheroniConstant) * S₁_at (N - 1)| *
      Real.log ↑N ≤ 2 * C₁ := by
    have hγ_bound : |1 - eulerMascheroniConstant| ≤ 1 := by
      apply abs_le.mpr; constructor
      · have := eulerMascheroniConstant_lt_two_thirds; linarith
      · have := one_half_lt_eulerMascheroniConstant; linarith
    have h1 : |(1 - eulerMascheroniConstant) * S₁_at (N - 1)| ≤
        |S₁_at (N - 1)| := by
      rw [abs_mul]
      exact le_trans (mul_le_mul_of_nonneg_right hγ_bound (abs_nonneg _))
        (by rw [one_mul])
    calc |(1 - eulerMascheroniConstant) * S₁_at (N - 1)| * Real.log ↑N
        ≤ |S₁_at (N - 1)| * Real.log ↑N :=
          mul_le_mul_of_nonneg_right h1 (le_of_lt hlogN_pos)
      _ ≤ 2 * C₁ := h_s1_logN
  -- Final: |A+B-C/L|·L ≤ |A|·L + |B·L| + |C/L|·L by triangle ineq
  -- Note: |a+b-c| ≤ |a| + |b-c| ≤ |a| + |b| + |c|
  -- This is the abs triangle inequality applied twice.
  have h_tri1 : ∀ a b c : ℝ, |a + b - c| ≤ |a| + |b| + |c| := by
    intro a b c
    have hab : |a + b| ≤ |a| + |b| := by
      rcases le_or_gt 0 (a + b) with h | h
      · rw [abs_of_nonneg h]; linarith [le_abs_self a, le_abs_self b]
      · rw [abs_of_neg h]; linarith [neg_abs_le a, neg_abs_le b]
    have habc : |a + b - c| ≤ |a + b| + |c| := by
      rcases le_or_gt 0 (a + b - c) with h | h
      · rw [abs_of_nonneg h]; linarith [le_abs_self (a + b), neg_abs_le c]
      · rw [abs_of_neg h]; linarith [neg_abs_le (a + b), le_abs_self c]
    linarith
  calc |(1 - eulerMascheroniConstant) * S₁_at (N - 1) +
        (S₂_at (N - 1) + 1) -
        ((1 - eulerMascheroniConstant) * S₂_at (N - 1) + S₃_at (N - 1)) /
          Real.log ↑N| * Real.log ↑N
      ≤ (|(1 - eulerMascheroniConstant) * S₁_at (N - 1)| +
         |S₂_at (N - 1) + 1| +
         |((1 - eulerMascheroniConstant) * S₂_at (N - 1) + S₃_at (N - 1)) /
           Real.log ↑N|) * Real.log ↑N := by
        apply mul_le_mul_of_nonneg_right _ (le_of_lt hlogN_pos)
        exact h_tri1 _ _ _
    _ = |(1 - eulerMascheroniConstant) * S₁_at (N - 1)| * Real.log ↑N +
        |S₂_at (N - 1) + 1| * Real.log ↑N +
        |((1 - eulerMascheroniConstant) * S₂_at (N - 1) + S₃_at (N - 1)) /
          Real.log ↑N| * Real.log ↑N := by ring
    _ ≤ 2 * C₁ + 10 * C₂ + (B₂ + B₃ + 3) := by
        rw [h_s2_eq]
        linarith [h_term1_logN, h_s2_logN, h_div_logN]
    _ ≤ 2 * C₁ + 10 * C₂ + B₂ + B₃ + 4 := by linarith

/-- **UNIFORM VERSION**: The same bound holds with a UNIFORM C_dot for all N ≥ 10.
    The constant C_dot = 2C₁+10C₂+B₂+B₃+4 depends only on the PNT tail bounds,
    not on N. This version makes the uniformity explicit. -/
theorem moebius_dot_product_approx_one_uniform
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x ≥ 2,
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x^(1/2 : ℝ) * (Real.log x)^2)
    (hPNT₁ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) / (k : ℝ)) atTop (nhds 0))
    (hPNT₂ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) * Real.log (k : ℝ) / (k : ℝ)) atTop (nhds (-1)))
    (hPNT₃ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) * (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
        atTop (nhds (-2 * eulerMascheroniConstant))) :
    ∃ C_dot : ℝ, C_dot > 0 ∧ ∀ (N : ℕ), 10 ≤ N →
    |1 - dotProduct (fun i => vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight N)| ≤
    C_dot / Real.log ↑N := by
  -- Extract the N-independent constants from PNT tail bounds
  -- (same steps as in moebius_dot_product_approx_one, but BEFORE fixing N)
  have hMertens34 : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ (64 * C_m) * x ^ ((3:ℝ)/4) := by
    intro x hx
    have hx_pos : (0 : ℝ) < x := by linarith
    calc |((mertensFunction x : ℤ) : ℝ)|
        ≤ C_m * x ^ ((1:ℝ)/2) * (Real.log x) ^ 2 := hMertens x hx
      _ ≤ C_m * (64 * x ^ ((3:ℝ)/4)) := by
          have h_key : x ^ ((1:ℝ)/2) * (Real.log x) ^ 2 ≤ 64 * x ^ ((3:ℝ)/4) := by
            have ht_ge1 : 1 ≤ x ^ ((1:ℝ)/8) := by
              rw [← Real.rpow_zero x]
              exact Real.rpow_le_rpow_of_exponent_le (by linarith) (by norm_num)
            have h_log_le : Real.log (x ^ ((1:ℝ)/8)) ≤ x ^ ((1:ℝ)/8) := by
              linarith [Real.add_one_le_exp (Real.log (x ^ ((1:ℝ)/8))),
                        Real.exp_log (lt_of_lt_of_le one_pos ht_ge1)]
            have h_log_eq : Real.log x = 8 * Real.log (x ^ ((1:ℝ)/8)) := by
              rw [Real.log_rpow hx_pos]; ring
            have h_t_sq : (x ^ ((1:ℝ)/8)) ^ 2 = x ^ ((1:ℝ)/4) := by
              rw [← Real.rpow_natCast (x ^ ((1:ℝ)/8)) 2,
                  ← Real.rpow_mul (le_of_lt hx_pos)]
              norm_num
            calc x ^ ((1:ℝ)/2) * (Real.log x) ^ 2
                = x ^ ((1:ℝ)/2) * (64 * (Real.log (x ^ ((1:ℝ)/8))) ^ 2) := by
                  rw [h_log_eq]; ring
              _ ≤ x ^ ((1:ℝ)/2) * (64 * (x ^ ((1:ℝ)/8)) ^ 2) := by
                  apply mul_le_mul_of_nonneg_left _ (le_of_lt (Real.rpow_pos_of_pos hx_pos _))
                  apply mul_le_mul_of_nonneg_left _ (by norm_num)
                  exact pow_le_pow_left₀ (Real.log_nonneg ht_ge1) h_log_le 2
              _ = 64 * (x ^ ((1:ℝ)/2) * x ^ ((1:ℝ)/4)) := by rw [h_t_sq]; ring
              _ = 64 * x ^ ((3:ℝ)/4) := by
                  congr 1; rw [← Real.rpow_add hx_pos]; norm_num
          nlinarith [Real.rpow_pos_of_pos hx_pos ((1:ℝ)/2),
                     Real.rpow_pos_of_pos hx_pos ((3:ℝ)/4)]
      _ = (64 * C_m) * x ^ ((3:ℝ)/4) := by ring
  obtain ⟨C₁, hC₁_pos, h_s1⟩ := s1_decay (64 * C_m) (by positivity) hMertens34 hPNT₁
  obtain ⟨C₂, hC₂_pos, h_s2⟩ := s2_decay (64 * C_m) (by positivity) hMertens34 hPNT₂
  obtain ⟨B₂, hB₂_ge, h_s2_univ⟩ := tendsto_universal_bound hPNT₂
  obtain ⟨B₃, hB₃_ge, h_s3_univ⟩ := tendsto_universal_bound hPNT₃
  -- C_dot is uniform — constructed from N-independent quantities
  refine ⟨2 * C₁ + 10 * C₂ + B₂ + B₃ + 4, by linarith, fun N hN => ?_⟩
  -- Now prove for this specific N — same proof as moebius_dot_product_approx_one
  -- (lines 160-301), but using the C₁, C₂, B₂, B₃ we already extracted.
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have hlogN_pos : (0 : ℝ) < Real.log ↑N :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  have hlogN_ne : Real.log (↑N : ℝ) ≠ 0 := ne_of_gt hlogN_pos
  have hN1_ge2 : 2 ≤ N - 1 := by omega
  have h_identity := one_minus_dotProduct_identity N (by omega) hlogN_ne
  have h_s1_N := h_s1 (N - 1) hN1_ge2
  have h_s2_N := h_s2 (N - 1) hN1_ge2
  have h_s2_abs : |S₂_at (N - 1)| ≤ B₂ + 1 := by
    have h1 := h_s2_univ (N - 1)
    unfold S₂_at
    have h2 := abs_le.mp h1
    exact abs_le.mpr ⟨by linarith, by linarith⟩
  have h_s3_abs : |S₃_at (N - 1)| ≤ B₃ + 2 := by
    have h1 := h_s3_univ (N - 1)
    unfold S₃_at
    have h2 := abs_le.mp h1
    have hγ_pos : 0 < eulerMascheroniConstant := by
      linarith [one_half_lt_eulerMascheroniConstant]
    have hγ_lt1 : eulerMascheroniConstant < 1 := by
      linarith [eulerMascheroniConstant_lt_two_thirds]
    exact abs_le.mpr ⟨by nlinarith, by nlinarith⟩
  rw [h_identity]
  have h_calc1 := rpow_quarter_logN_le_two N hN
  have h_calc2 := rpow_quarter_logsq_le_ten N hN
  have h_s1_logN : |S₁_at (N - 1)| * Real.log ↑N ≤ 2 * C₁ := by
    calc |S₁_at (N - 1)| * Real.log ↑N
        ≤ C₁ * (↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log ↑N :=
          mul_le_mul_of_nonneg_right h_s1_N (le_of_lt hlogN_pos)
      _ = C₁ * ((↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log ↑N) := by ring
      _ ≤ C₁ * 2 := mul_le_mul_of_nonneg_left h_calc1 hC₁_pos.le
      _ = 2 * C₁ := by ring
  have h_s2_logN : |S₂_at (N - 1) - (-1)| * Real.log ↑N ≤ 10 * C₂ := by
    calc |S₂_at (N - 1) - (-1)| * Real.log ↑N
        ≤ C₂ * (↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log (↑(N - 1) : ℝ) * Real.log ↑N :=
          mul_le_mul_of_nonneg_right h_s2_N (le_of_lt hlogN_pos)
      _ = C₂ * ((↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log (↑(N - 1) : ℝ) * Real.log ↑N) := by ring
      _ ≤ C₂ * 10 := mul_le_mul_of_nonneg_left h_calc2 hC₂_pos.le
      _ = 10 * C₂ := by ring
  suffices h_main : |(1 - eulerMascheroniConstant) * S₁_at (N - 1) +
      (S₂_at (N - 1) + 1) -
      ((1 - eulerMascheroniConstant) * S₂_at (N - 1) + S₃_at (N - 1)) /
        Real.log ↑N| * Real.log ↑N ≤
      2 * C₁ + 10 * C₂ + B₂ + B₃ + 4 by
    rw [le_div_iff₀ hlogN_pos]
    linarith
  have h_s2_eq : S₂_at (N - 1) + 1 = S₂_at (N - 1) - (-1) := by ring
  have h_num : |(1 - eulerMascheroniConstant) * S₂_at (N - 1) +
      S₃_at (N - 1)| ≤ B₂ + B₃ + 3 := by
    have hγ01 : 0 < 1 - eulerMascheroniConstant ∧
        1 - eulerMascheroniConstant < 1 := by
      constructor
      · linarith [eulerMascheroniConstant_lt_two_thirds]
      · linarith [one_half_lt_eulerMascheroniConstant]
    have h_s2_bound : -(B₂ + 1) ≤ (1 - eulerMascheroniConstant) * S₂_at (N - 1) ∧
        (1 - eulerMascheroniConstant) * S₂_at (N - 1) ≤ B₂ + 1 := by
      constructor
      · nlinarith [abs_le.mp h_s2_abs]
      · nlinarith [abs_le.mp h_s2_abs]
    have h_s3_bound := abs_le.mp h_s3_abs
    exact abs_le.mpr ⟨by nlinarith, by nlinarith⟩
  have h_div_logN : |((1 - eulerMascheroniConstant) * S₂_at (N - 1) +
      S₃_at (N - 1)) / Real.log ↑N| * Real.log ↑N ≤ B₂ + B₃ + 3 := by
    rw [abs_div, abs_of_pos hlogN_pos, div_mul_cancel₀ _ hlogN_ne]
    exact h_num
  have h_term1_logN : |(1 - eulerMascheroniConstant) * S₁_at (N - 1)| *
      Real.log ↑N ≤ 2 * C₁ := by
    have hγ_bound : |1 - eulerMascheroniConstant| ≤ 1 := by
      apply abs_le.mpr; constructor
      · have := eulerMascheroniConstant_lt_two_thirds; linarith
      · have := one_half_lt_eulerMascheroniConstant; linarith
    have h1 : |(1 - eulerMascheroniConstant) * S₁_at (N - 1)| ≤
        |S₁_at (N - 1)| := by
      rw [abs_mul]
      exact le_trans (mul_le_mul_of_nonneg_right hγ_bound (abs_nonneg _))
        (by rw [one_mul])
    calc |(1 - eulerMascheroniConstant) * S₁_at (N - 1)| * Real.log ↑N
        ≤ |S₁_at (N - 1)| * Real.log ↑N :=
          mul_le_mul_of_nonneg_right h1 (le_of_lt hlogN_pos)
      _ ≤ 2 * C₁ := h_s1_logN
  have h_tri1 : ∀ a b c : ℝ, |a + b - c| ≤ |a| + |b| + |c| := by
    intro a b c
    have hab : |a + b| ≤ |a| + |b| := by
      rcases le_or_gt 0 (a + b) with h | h
      · rw [abs_of_nonneg h]; linarith [le_abs_self a, le_abs_self b]
      · rw [abs_of_neg h]; linarith [neg_abs_le a, neg_abs_le b]
    have habc : |a + b - c| ≤ |a + b| + |c| := by
      rcases le_or_gt 0 (a + b - c) with h | h
      · rw [abs_of_nonneg h]; linarith [le_abs_self (a + b), neg_abs_le c]
      · rw [abs_of_neg h]; linarith [neg_abs_le (a + b), le_abs_self c]
    linarith
  calc |(1 - eulerMascheroniConstant) * S₁_at (N - 1) +
        (S₂_at (N - 1) + 1) -
        ((1 - eulerMascheroniConstant) * S₂_at (N - 1) + S₃_at (N - 1)) /
          Real.log ↑N| * Real.log ↑N
      ≤ (|(1 - eulerMascheroniConstant) * S₁_at (N - 1)| +
         |S₂_at (N - 1) + 1| +
         |((1 - eulerMascheroniConstant) * S₂_at (N - 1) + S₃_at (N - 1)) /
           Real.log ↑N|) * Real.log ↑N := by
        apply mul_le_mul_of_nonneg_right _ (le_of_lt hlogN_pos)
        exact h_tri1 _ _ _
    _ = |(1 - eulerMascheroniConstant) * S₁_at (N - 1)| * Real.log ↑N +
        |S₂_at (N - 1) + 1| * Real.log ↑N +
        |((1 - eulerMascheroniConstant) * S₂_at (N - 1) + S₃_at (N - 1)) /
          Real.log ↑N| * Real.log ↑N := by ring
    _ ≤ 2 * C₁ + 10 * C₂ + (B₂ + B₃ + 3) := by
        rw [h_s2_eq]
        linarith [h_term1_logN, h_s2_logN, h_div_logN]
    _ ≤ 2 * C₁ + 10 * C₂ + B₂ + B₃ + 4 := by linarith

-- ════════════════════════════════════════════════
-- §4. QUADRATIC FORM BOUND VIA L² BOUND
-- ════════════════════════════════════════════════

/-- **PROVED**: vᵀGv for Möbius weights is bounded by (N-1)²/2. -/
theorem moebius_quadform_finite_bound (N : ℕ) (hN : 2 ≤ N) :
    realQuadForm (Matrix.of fun i j =>
      vasyuninGramEntry (i.val + 1) (j.val + 1))
      (bdMoebiusWeight N) ≤ ((N : ℝ) - 1) ^ 2 / 2 := by
  have h_l1 := moebius_weight_l1_crude N hN
  -- Step 1: vᵀGv ≤ (1/2)(Σ|v|)²
  suffices h_quad : realQuadForm (Matrix.of fun i j =>
      vasyuninGramEntry (i.val + 1) (j.val + 1))
      (bdMoebiusWeight N) ≤ (1/2) * (∑ i : Fin (N-1), |bdMoebiusWeight N i|)^2 by
    calc realQuadForm _ (bdMoebiusWeight N)
        ≤ (1/2) * (∑ i : Fin (N-1), |bdMoebiusWeight N i|)^2 := h_quad
      _ ≤ (1/2) * ((N : ℝ) - 1)^2 := by
          apply mul_le_mul_of_nonneg_left _ (by norm_num)
          exact pow_le_pow_left₀ (Finset.sum_nonneg fun i _ => abs_nonneg _) h_l1 2
      _ = ((N : ℝ) - 1)^2 / 2 := by ring
  -- Step 2: Match the quadratic form with vasyuninQuadForm_le_half_l1_sq
  unfold realQuadForm
  simp only [dotProduct, Matrix.mulVec, Matrix.of_apply]
  simp_rw [Finset.mul_sum]
  have h := vasyuninQuadForm_le_half_l1_sq (bdMoebiusWeight N)
  calc ∑ i, ∑ j, bdMoebiusWeight N i *
        (vasyuninGramEntry (↑i + 1) (↑j + 1) * bdMoebiusWeight N j)
      = ∑ i, ∑ j, bdMoebiusWeight N i * bdMoebiusWeight N j *
          vasyuninGramEntry (↑i + 1) (↑j + 1) := by
        congr 1; ext i; congr 1; ext j; ring
    _ ≤ _ := h

-- ════════════════════════════════════════════════
-- §5. THE MAIN ASSEMBLY: Mertens + PNT → L² bound
-- ════════════════════════════════════════════════

/-- **THEOREM (with PNT hypotheses)**: Mertens + PNT → L² decay.

    Under |M(x)| ≤ C·√x·log²x and PNT limits S₁→0, S₂→-1:
      ∃ C > 0, ∀ N ≥ 10, ∫₀¹ (1 - Σ v_k·{1/(kx)})² ≤ C / log(N)

    PROOF CHAIN:
    1. ∫(1-f)² = (1-bᵀv)² + vᵀCv       [covariance decomposition]
    2. |1-bᵀv| ≤ C_dot/logN            [moebius_dot_product_approx_one]
    3. vᵀCv ≤ C_cov/logN               [abel_summation_covariance_bound]
    4. Assembly: (C_dot/logN)² + C_cov/logN ≤ (C_dot²+C_cov)/logN -/
theorem mertens_implies_l2_decay
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x ≥ 2,
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x^(1/2 : ℝ) * (Real.log x)^2)
    -- PNT hypotheses
    (hPNT₁ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) / (k : ℝ)) atTop (nhds 0))
    (hPNT₂ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) * Real.log (k : ℝ) / (k : ℝ)) atTop (nhds (-1)))
    (hPNT₃ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) * (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
        atTop (nhds (-2 * eulerMascheroniConstant))) :
    ∃ C_l2 : ℝ, C_l2 > 0 ∧ ∀ (N : ℕ), 10 ≤ N →
    ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 ≤
    C_l2 / Real.log ↑N := by
  -- ══════════════════════════════════════════════
  -- EXTRACT ALL CONSTANTS BEFORE CHOOSING C_l2
  -- ══════════════════════════════════════════════
  -- Step 1: Covariance bound from Mertens → ∃ C_cov, N₀, vᵀCv ≤ C_cov/logN
  obtain ⟨C_cov, hC_cov_pos, N₀, h_cov⟩ :=
    Cathedral.Vasyunin.abel_summation_covariance_bound ⟨C_m, hC, hMertens⟩
  -- Step 2: UNIFORM dot product bound from PNT → ∃ C_dot, ∀ N ≥ 10, |1-bᵀv| ≤ C_dot/logN
  obtain ⟨C_dot, hC_dot_pos, h_dot_uniform⟩ :=
    moebius_dot_product_approx_one_uniform C_m hC hMertens hPNT₁ hPNT₂ hPNT₃
  -- ══════════════════════════════════════════════
  -- CHOOSE C_l2 (now that C_dot and C_cov are known)
  -- ══════════════════════════════════════════════
  set N_big : ℕ := max N₀ 10
  have hN_big_pos : 0 < (N_big : ℝ) := Nat.cast_pos.mpr (by omega)
  have hlog_Nbig_pos : 0 < Real.log ↑N_big :=
    Real.log_pos (by exact_mod_cast (show 1 < N_big by omega))
  -- For N ≥ N₀: ∫ ≤ (C_dot² + C_cov)/logN
  -- For N < N₀: ∫ ≤ N² ≤ N_big², need N_big²·logN_big ≤ C_l2
  refine ⟨C_dot ^ 2 + C_cov + (↑N_big + 1) ^ 2 * Real.log ↑N_big + 1,
          by positivity, fun N hN => ?_⟩
  -- ══════════════════════════════════════════════
  -- SETUP
  -- ══════════════════════════════════════════════
  set C_l2 : ℝ := C_dot ^ 2 + C_cov + (↑N_big + 1) ^ 2 * Real.log ↑N_big + 1
  have hlogN_pos : 0 < Real.log (N : ℝ) := by
    apply Real.log_pos; exact_mod_cast (show 1 < N by omega)
  have hlogN_ge1 : 1 ≤ Real.log (N : ℝ) := by
    -- log(N) ≥ log(e) = 1 since N ≥ 10 > e
    calc (1 : ℝ) = Real.log (Real.exp 1) := (Real.log_exp 1).symm
      _ ≤ Real.log N := Real.log_le_log (Real.exp_pos 1)
          (by calc Real.exp 1 ≤ 3 := by linarith [Real.exp_one_lt_d9]
              _ ≤ (N : ℝ) := by exact_mod_cast (show 3 ≤ N by omega))
  have hC_l2_pos : 0 < C_l2 := by positivity
  -- ══════════════════════════════════════════════
  -- CASE SPLIT
  -- ══════════════════════════════════════════════
  by_cases hN_large : N₀ ≤ N
  · -- CASE 1: N ≥ N₀ — use covariance decomposition
    -- Pattern from VasyuninBypass.rh_implies_bd_convergence_vasyunin (lines 178-201)
    have h_eq := bd_l2_error_eq_quad_error N (by omega : 2 ≤ N) (bdMoebiusWeight N)
    have h_vtCv := h_cov N hN_large (by omega : 3 ≤ N)
    have h_dot_N := h_dot_uniform N hN
    -- Step 1: ∫ = 1-2bᵀv + vᵀGv = (1-bᵀv_V)² + vᵀCv_V
    -- Step 2: Bound each piece, then combine ≤ C_l2/logN
    calc ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2
        = 1 - 2 * dotProduct (fun i => vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight N) +
          realQuadForm (Matrix.of fun i j => vasyuninGramEntry (i.val + 1) (j.val + 1))
            (bdMoebiusWeight N) := h_eq
      _ = (1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N)) ^ 2 +
          dotProduct (logCutoffWitness N)
            ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) :=
          (Nat.sub_add_cancel (show 1 ≤ N by omega) ▸
            vasyunin_bd_index_bridge (N-1) (by omega)).symm
      _ ≤ C_dot ^ 2 / Real.log ↑N + C_cov / Real.log ↑N := by
          apply add_le_add
          · -- (1-bᵀv_V)² ≤ C_dot²/logN
            -- First: bᵀv_V = bᵀv_BD via dotProduct_bridge_aux
            have h_dot_eq := dotProduct_bridge_aux (N-1) (by omega : 2 ≤ N-1)
            -- h_dot_eq at (N-1)+1: rewrite to N
            have h_N_sub : (N - 1) + 1 = N := Nat.sub_add_cancel (by omega : 1 ≤ N)
            -- Use ▸ (subst) to transport Fin((N-1)+1) → Fin(N)
            -- dotProduct_bridge_aux gives:
            --   bᵀv_V((N-1)+1) = bᵀv_BD((N-1)+1)
            -- We need to show (1 - bᵀv_V(N))² ≤ ...
            -- Using ▸ with h_N_sub to transport:
            have h_eq_dot : (1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N)) ^ 2 =
                (1 - dotProduct (fun i => vasyuninMeanEntry (i.val + 1))
                  (bdMoebiusWeight N)) ^ 2 := by
              congr 1; congr 1
              exact Nat.sub_add_cancel (show 1 ≤ N by omega) ▸ h_dot_eq
            rw [h_eq_dot, ← sq_abs]
            calc |1 - dotProduct (fun i => vasyuninMeanEntry (↑i + 1))
                    (bdMoebiusWeight N)| ^ 2
                ≤ (C_dot / Real.log ↑N) ^ 2 := by
                  apply pow_le_pow_left₀ (abs_nonneg _) h_dot_N
              _ = C_dot ^ 2 / (Real.log ↑N) ^ 2 := div_pow _ _ _
              _ ≤ C_dot ^ 2 / Real.log ↑N := by
                  apply div_le_div_of_nonneg_left (by positivity) hlogN_pos
                  nlinarith [sq_nonneg (Real.log ↑N - 1)]
          · -- vᵀCv_V ≤ C_cov/logN (direct from h_vtCv)
            exact h_vtCv
      _ = (C_dot ^ 2 + C_cov) / Real.log ↑N := by rw [add_div]
      _ ≤ C_l2 / Real.log ↑N := by
          apply div_le_div_of_nonneg_right _ hlogN_pos.le
          -- C_l2 = C_dot² + C_cov + (N_big+1)²*logN_big + 1
          -- So C_dot² + C_cov ≤ C_l2
          have : (0 : ℝ) ≤ (↑N_big + 1) ^ 2 * Real.log ↑N_big + 1 := by
            have := sq_nonneg ((↑N_big : ℝ) + 1)
            have := hlog_Nbig_pos.le
            nlinarith
          linarith
  · -- CASE 2: N < N₀ — use crude bound
    push Not at hN_large
    have hN_le_Nbig : N ≤ N_big := by omega
    have h_crude := l2_crude_upper_bound N (bdMoebiusWeight N)
    have hN_pos' : (0 : ℝ) < N := Nat.cast_pos.mpr (by omega)
    have h_l1 := moebius_weight_l1_crude N (by omega : 2 ≤ N)
    calc ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2
        ≤ (1 + ∑ i : Fin (N - 1), |bdMoebiusWeight N i|) ^ 2 := h_crude
      _ ≤ (↑N : ℝ) ^ 2 := by
          have h_sum := h_l1
          have h_sum_nn := Finset.sum_nonneg (fun i (_ : i ∈ Finset.univ)
            => abs_nonneg (bdMoebiusWeight N i))
          nlinarith
      _ ≤ (↑N_big + 1) ^ 2 := by
          apply sq_le_sq'
          · linarith [hN_pos', hN_big_pos]
          · exact_mod_cast (show N ≤ N_big + 1 by omega)
      _ ≤ C_l2 / Real.log ↑N := by
          rw [le_div_iff₀ hlogN_pos]
          -- Need: (N_big+1)² · logN ≤ C_l2
          -- Since N ≤ N_big, logN ≤ logN_big
          have hlogN_le : Real.log ↑N ≤ Real.log ↑N_big :=
            Real.log_le_log (by positivity) (by exact_mod_cast show N ≤ N_big by omega)
          calc (↑N_big + 1) ^ 2 * Real.log ↑N
              ≤ (↑N_big + 1) ^ 2 * Real.log ↑N_big :=
                mul_le_mul_of_nonneg_left hlogN_le (sq_nonneg _)
            _ ≤ C_l2 := by
                show _ ≤ C_dot ^ 2 + C_cov + (↑N_big + 1) ^ 2 * Real.log ↑N_big + 1
                linarith [sq_nonneg C_dot, hC_cov_pos]

end

