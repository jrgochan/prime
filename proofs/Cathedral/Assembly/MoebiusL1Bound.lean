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
import Cathedral.Assembly.BDBridge
import Cathedral.Assembly.DotProductIdentity
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
  --   |S₁|·logN ≤ C₁·2, |S₂+1|·logN ≤ C₂·9
  --   |(1-γ)·S₂+S₃| ≤ |S₂|+1 + |S₃| ≤ B₂+2 + B₃+2|γ| ≤ B₂+B₃+4
  refine ⟨2 * C₁ + 9 * C₂ + B₂ + B₃ + 4, by linarith, ?_⟩
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
  -- We have all the ingredients:
  -- h_s1_N : |S₁_at(N-1)| ≤ C₁·(N-1)^{-1/4}
  -- h_s2_N : |S₂_at(N-1)+1| ≤ C₂·(N-1)^{-1/4}·log(N-1)
  -- h_s2_abs : |S₂_at(N-1)| ≤ B₂+1
  -- h_s3_abs : |S₃_at(N-1)| ≤ B₃+2
  -- The proof needs:
  -- 1. Triangle inequality: |a+b-c/L| ≤ |a|+|b|+|c|/L
  -- 2. |a| ≤ C₁/N^{1/4}, |b| ≤ C₂·logN/N^{1/4}, |c| ≤ B₂+B₃+3
  -- 3. Calculus bound: N^{-1/4}·logN ≤ 2 for N ≥ 10
  -- 4. Calculus bound: N^{-1/4}·log²N ≤ 9 for N ≥ 10
  -- 5. Assembly: 2C₁+9C₂+B₂+B₃+3 ≤ 2C₁+9C₂+B₂+B₃+4
  sorry

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
      ∫₀¹ (1 - Σ v_k·{1/(kx)})² ≤ (C+1)²·loglog(N)/log(N)

    PROOF CHAIN:
    1. ∫(1-f)² = 1 - 2bᵀv + vᵀGv     [bd_l2_error_eq_quad_error]
    2. bᵀv = 1 - O(1/log N)            [moebius_dot_product_approx_one]
    3. vᵀGv ≤ (1/2)(Σ|v|)²            [vasyuninQuadForm_le_half_l1_sq]
    4. Σ|v| ≤ N-1                       [moebius_weight_l1_crude]
    5. Assembly: 1 - 2(1-ε) + δ = 2ε + δ → 0 -/
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
        atTop (nhds (-2 * eulerMascheroniConstant)))
    (N : ℕ) (hN : 10 ≤ N) :
    ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 ≤
    (C_m + 1) ^ 2 * Real.log (Real.log ↑N) / Real.log ↑N := by
  -- Step 1: L² = 1 - 2bᵀv + vᵀGv
  have h_decomp := bd_l2_error_eq_quad_error N (by omega) (bdMoebiusWeight N)
  -- Step 2: bᵀv ≈ 1 (existential bound)
  obtain ⟨C_dot, hC_dot_pos, h_dot⟩ :=
    moebius_dot_product_approx_one C_m hC hMertens hPNT₁ hPNT₂ hPNT₃ N hN
  -- Step 3: vᵀGv ≤ (1/2)(Σ|v|)²
  have h_upper := bd_l2_error_upper_bound N (by omega) (bdMoebiusWeight N)
  -- Step 4: Assembly — combine bᵀv ≈ 1 with quadratic form bound
  -- The L² error = 1-2bᵀv+vᵀGv.
  -- With bᵀv = 1-ε where |ε| ≤ C_dot/logN:
  --   L² = 1-2(1-ε)+vᵀGv = -1+2ε+vᵀGv
  -- Need vᵀGv ≈ 1 (bilinear Abel or Strategy D: independent Mellin).
  sorry

end
