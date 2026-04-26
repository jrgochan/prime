/-
  Cathedral/Vasyunin/Proof/LambdaTrick.lean

  ## The λ-Trick: Scalar Parabola Optimization

  The Theorist's Nuclear Shortcut (April 18, 2026):
  For ANY test vector y with bᵀy ≠ 0 and yᵀGy > 0,
  the scaled vector v = (bᵀy/yᵀGy)·y achieves:

    ∫₀¹ (1 - bdLinComb N v x)² = 1 - (bᵀy)²/yᵀGy

  Proof: Pure scalar parabola optimization.
  This bypasses all matrix inverse machinery.

  Reference: Theorist Encryption "WHITE SINGLET — THE ONE CROWN", §I.
-/

import Cathedral.NymanBeurling.BDBridge
import Cathedral.Vasyunin.Augmented.Rayleigh
import Cathedral.LinearAlgebra.Variational

noncomputable section
open Real Matrix Finset MeasureTheory

-- ════════════════════════════════════════════════
-- §1. THE SCALAR PARABOLA (Pure Algebra)
-- ════════════════════════════════════════════════

/-- The scalar parabola identity: for v = λ·y,
    the quadratic form 1 - 2λS + λ²P minimized at λ = S/P
    gives value 1 - S²/P. -/
theorem scalar_parabola_minimum (S P : ℝ) (hP : 0 < P) :
    1 - 2 * (S / P) * S + (S / P) ^ 2 * P = 1 - S ^ 2 / P := by
  field_simp
  ring

-- ════════════════════════════════════════════════
-- §2. THE λ-TRICK FOR BD VECTORS
-- ════════════════════════════════════════════════

/-- dotProduct distributes scalar multiplication on the right. -/
lemma dotProduct_scale_right {n : ℕ} (b y : Fin n → ℝ) (c : ℝ) :
    dotProduct b (fun i => c * y i) = c * dotProduct b y := by
  simp only [dotProduct]
  rw [show (∑ i, b i * (c * y i)) = ∑ i, c * (b i * y i) from
    Finset.sum_congr rfl (fun i _ => by ring)]
  rw [Finset.mul_sum]

/-- realQuadForm distributes scalar multiplication quadratically. -/
lemma quadForm_scale {n : ℕ} (G : Matrix (Fin n) (Fin n) ℝ) (y : Fin n → ℝ) (c : ℝ) :
    realQuadForm G (fun i => c * y i) = c ^ 2 * realQuadForm G y := by
  unfold realQuadForm
  have h_mv : G.mulVec (fun i => c * y i) = fun i => c * (G.mulVec y i) := by
    ext i; simp only [Matrix.mulVec, dotProduct]
    rw [show (∑ j, G i j * (c * y j)) = c * ∑ j, G i j * y j from by
      rw [show (∑ j, G i j * (c * y j)) = ∑ j, c * (G i j * y j) from
        Finset.sum_congr rfl (fun j _ => by ring)]
      rw [Finset.mul_sum]]
  rw [h_mv]
  simp only [dotProduct]
  rw [show (∑ i, c * y i * (c * G.mulVec y i)) = c ^ 2 * ∑ i, y i * G.mulVec y i from by
    rw [show (∑ i, c * y i * (c * G.mulVec y i)) = ∑ i, c ^ 2 * (y i * G.mulVec y i) from
      Finset.sum_congr rfl (fun i _ => by ring)]
    rw [Finset.mul_sum]]

/-- **THE λ-TRICK**: For any y with yᵀGy > 0, the vector v = (bᵀy/yᵀGy)·y
    achieves ∫₀¹(1 - f(v))² = 1 - (bᵀy)²/yᵀGy.

    This is the Theorist's "scalar parabola optimization" —
    no matrix inverses, no Sherman-Morrison, just calculus 101. -/
theorem lambda_trick_integral (N : ℕ) (hN : 2 ≤ N)
    (y : Fin (N - 1) → ℝ)
    (hP : 0 < realQuadForm
      (Matrix.of fun i j : Fin (N - 1) =>
        Cathedral.Vasyunin.vasyuninGramEntry (i.val + 1) (j.val + 1)) y) :
    let b := fun i : Fin (N - 1) => Cathedral.Vasyunin.vasyuninMeanEntry (i.val + 1)
    let G := Matrix.of fun i j : Fin (N - 1) =>
      Cathedral.Vasyunin.vasyuninGramEntry (i.val + 1) (j.val + 1)
    let S := dotProduct b y
    let P := realQuadForm G y
    let v := fun i => (S / P) * y i
    ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 = 1 - S ^ 2 / P := by
  simp only
  set b := fun i : Fin (N - 1) => Cathedral.Vasyunin.vasyuninMeanEntry (i.val + 1)
  set G := Matrix.of fun i j : Fin (N - 1) =>
    Cathedral.Vasyunin.vasyuninGramEntry (i.val + 1) (j.val + 1)
  set S := dotProduct b y
  set P := realQuadForm G y
  set v := fun i => (S / P) * y i
  -- Step 1: ∫(1-f)² = 1 - 2bᵀv + vᵀGv
  rw [bd_l2_error_eq_quad_error N hN v]
  -- Step 2: bᵀv = (S/P)·S
  have h_bv : dotProduct (fun i => Cathedral.Vasyunin.vasyuninMeanEntry (i.val + 1)) v =
      S / P * S := by
    show dotProduct b v = S / P * S
    exact dotProduct_scale_right b y (S / P)
  -- Step 3: vᵀGv = (S/P)²·P
  have h_Gv : realQuadForm
      (Matrix.of fun i j : Fin (N - 1) =>
        Cathedral.Vasyunin.vasyuninGramEntry (i.val + 1) (j.val + 1)) v =
      (S / P) ^ 2 * P := by
    show realQuadForm G v = (S / P) ^ 2 * P
    exact quadForm_scale G y (S / P)
  -- Step 4: Combine and apply scalar parabola
  rw [h_bv, h_Gv]
  -- Associativity fix: `S / P * S` vs `(S / P) * S`
  have : 1 - 2 * (S / P * S) + (S / P) ^ 2 * P =
      1 - 2 * (S / P) * S + (S / P) ^ 2 * P := by ring
  rw [this]
  exact scalar_parabola_minimum S P hP

-- ════════════════════════════════════════════════
-- §3. THE GRAM DECOMPOSITION (G = C + bbᵀ ⟹ P = Q + S²)
-- ════════════════════════════════════════════════

/-- The Gram decomposition: yᵀGy = yᵀCy + (bᵀy)².
    Since G = C + bbᵀ, this is just linear algebra. -/
theorem gram_cov_decomposition {n : ℕ}
    (b : Fin n → ℝ)
    (C : Matrix (Fin n) (Fin n) ℝ)
    (G : Matrix (Fin n) (Fin n) ℝ)
    (y : Fin n → ℝ)
    (hG : G = C + vecMulVec b b) :
    realQuadForm G y = realQuadForm C y + (dotProduct b y) ^ 2 := by
  -- Expand everything in terms of sums
  unfold realQuadForm dotProduct
  -- G.mulVec y = C.mulVec y + (vecMulVec b b).mulVec y
  have h1 : G.mulVec y = C.mulVec y + (vecMulVec b b).mulVec y := by
    rw [hG, Matrix.add_mulVec]
  -- (vecMulVec b b).mulVec y i = b i * Σ b_j y_j
  have h2 : ∀ i : Fin n, (vecMulVec b b).mulVec y i = b i * ∑ j, b j * y j := by
    intro i
    simp [Matrix.mulVec, vecMulVec, dotProduct, Finset.mul_sum, mul_assoc]
  -- Expand using h1 and h2
  conv_lhs => rw [show G.mulVec y = fun i => C.mulVec y i + b i * ∑ j, b j * y j from by
    ext i; rw [← h2 i]; simp [h1]]
  simp only []
  rw [show (∑ i, y i * (C.mulVec y i + b i * ∑ j, b j * y j)) =
      (∑ i, y i * C.mulVec y i) + (∑ i, b i * y i) ^ 2 from by
    rw [show (∑ i, y i * (C.mulVec y i + b i * ∑ j, b j * y j)) =
        (∑ i, y i * C.mulVec y i) + ∑ i, y i * (b i * ∑ j, b j * y j) from by
      rw [← Finset.sum_add_distrib]; congr 1; ext i; ring]
    congr 1
    rw [show (∑ i, y i * (b i * ∑ j, b j * y j)) =
        (∑ i, b i * y i) * (∑ j, b j * y j) from by
      rw [Finset.sum_mul]; congr 1; ext; ring]
    ring]

/-- The corollary: 1 - S²/P = 1/(1 + S²/Q) when P = Q + S² and Q > 0. -/
theorem parabola_to_rayleigh (S Q : ℝ) (hQ : 0 < Q) :
    1 - S ^ 2 / (Q + S ^ 2) = 1 / (1 + S ^ 2 / Q) := by
  have hP : 0 < Q + S ^ 2 := by positivity
  have hQ_ne : Q ≠ 0 := ne_of_gt hQ
  field_simp
  ring

-- ════════════════════════════════════════════════
-- §4. THE DIMENSION BRIDGE (Vasyunin N-1 = BD N)
-- ════════════════════════════════════════════════

/-- The BD Gram matrix for bdLinComb N equals vasyuninGramMatrix (N-1).
    Both are (N-1)×(N-1) matrices with entries vasyuninGramEntry(i+1,j+1). -/
theorem bd_gram_eq_vasyunin (N : ℕ) :
    (Matrix.of fun i j : Fin (N - 1) =>
      Cathedral.Vasyunin.vasyuninGramEntry (i.val + 1) (j.val + 1)) =
    Cathedral.Vasyunin.vasyuninGramMatrix (N - 1) := by
  ext i j
  simp [Cathedral.Vasyunin.vasyuninGramMatrix, Matrix.of_apply]

/-- The BD mean vector for bdLinComb N equals vasyuninMeanVec (N-1). -/
theorem bd_mean_eq_vasyunin (N : ℕ) :
    (fun i : Fin (N - 1) => Cathedral.Vasyunin.vasyuninMeanEntry (i.val + 1)) =
    Cathedral.Vasyunin.vasyuninMeanVec (N - 1) := by
  ext i
  simp [Cathedral.Vasyunin.vasyuninMeanVec]

-- ════════════════════════════════════════════════
-- §5. WITNESS PROPERTIES
-- ════════════════════════════════════════════════

open Cathedral.Vasyunin in
/-- The log cutoff witness is nonzero for N ≥ 3. -/
theorem Cathedral.Vasyunin.logCutoffWitness_ne_zero' (N : ℕ) (hN : N ≥ 3) :
    logCutoffWitness N ≠ 0 := by
  intro h_eq
  have h0 : logCutoffWitness N ⟨0, by omega⟩ = 0 := by rw [h_eq]; rfl
  simp only [logCutoffWitness, moebiusFn] at h0
  rw [ArithmeticFunction.moebius_apply_one] at h0
  simp [Real.log_one] at h0

open Cathedral.Vasyunin in
/-- The log cutoff witness has strictly positive covariance vᵀCv > 0. -/
theorem Cathedral.Vasyunin.log_cutoff_witness_pos' (N : ℕ) (hN : N ≥ 3) :
    dotProduct (logCutoffWitness N) ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) > 0 :=
  Cathedral.Variational.posSemidef_pos_of_ne_zero
    (vasyuninCovMatrix N)
    (vasyuninCovMatrix_hermitian N)
    (vasyuninCovMatrix_posSemidef N hN)
    (vasyuninCovMatrix_isUnit_det N hN)
    (logCutoffWitness N)
    (Cathedral.Vasyunin.logCutoffWitness_ne_zero' N hN)

-- ════════════════════════════════════════════════
-- §6. KILLING algebraic_nb_bridge
-- ════════════════════════════════════════════════

/-- P > 0 for the BD Gram matrix applied to logCutoffWitness. -/
private theorem bd_gram_pos (N : ℕ) (hN3 : N - 1 ≥ 3) :
    0 < realQuadForm
      (Matrix.of fun i j : Fin (N - 1) =>
        Cathedral.Vasyunin.vasyuninGramEntry (i.val + 1) (j.val + 1))
      (Cathedral.Vasyunin.logCutoffWitness (N - 1)) := by
  rw [show (Matrix.of fun i j : Fin (N - 1) =>
      Cathedral.Vasyunin.vasyuninGramEntry (i.val + 1) (j.val + 1)) =
    Cathedral.Vasyunin.vasyuninGramMatrix (N - 1) from bd_gram_eq_vasyunin N]
  -- PosDef implies xᵀGx > 0 for x ≠ 0
  have hPD := Cathedral.Vasyunin.vasyuninGramMatrix_posDef (N - 1) hN3
  have hne := Cathedral.Vasyunin.logCutoffWitness_ne_zero' (N - 1) hN3
  unfold realQuadForm
  exact Cathedral.Variational.posSemidef_pos_of_ne_zero
    (Cathedral.Vasyunin.vasyuninGramMatrix (N - 1))
    hPD.isHermitian hPD.posSemidef
    (by have := hPD.isUnit; rwa [isUnit_iff_isUnit_det] at this)
    (Cathedral.Vasyunin.logCutoffWitness (N - 1)) hne

/-- Q > 0 for the Vasyunin covariance applied to logCutoffWitness. -/
private theorem bd_cov_pos (N : ℕ) (hN3 : N - 1 ≥ 3) :
    0 < realQuadForm
      (Cathedral.Vasyunin.vasyuninCovMatrix (N - 1))
      (Cathedral.Vasyunin.logCutoffWitness (N - 1)) := by
  unfold realQuadForm
  exact Cathedral.Vasyunin.log_cutoff_witness_pos' (N - 1) hN3

/-- The Gram decomposition for the BD/Vasyunin matrices. -/
private theorem bd_gram_decomp (N : ℕ) :
    realQuadForm (Matrix.of fun i j : Fin (N - 1) =>
      Cathedral.Vasyunin.vasyuninGramEntry (i.val + 1) (j.val + 1))
      (Cathedral.Vasyunin.logCutoffWitness (N - 1)) =
    realQuadForm (Cathedral.Vasyunin.vasyuninCovMatrix (N - 1))
      (Cathedral.Vasyunin.logCutoffWitness (N - 1)) +
    (dotProduct (Cathedral.Vasyunin.vasyuninMeanVec (N - 1))
      (Cathedral.Vasyunin.logCutoffWitness (N - 1))) ^ 2 := by
  rw [bd_gram_eq_vasyunin N]
  exact gram_cov_decomposition
    (Cathedral.Vasyunin.vasyuninMeanVec (N - 1))
    (Cathedral.Vasyunin.vasyuninCovMatrix (N - 1))
    (Cathedral.Vasyunin.vasyuninGramMatrix (N - 1))
    (Cathedral.Vasyunin.logCutoffWitness (N - 1))
    (by -- G = C + bbᵀ, i.e., vasyuninGramMatrix = vasyuninCovMatrix + vecMulVec b b
     ext i j
     simp [Cathedral.Vasyunin.vasyuninCovMatrix, Cathedral.Vasyunin.vasyuninGramMatrix,
           vecMulVec, Cathedral.Vasyunin.vasyuninMeanVec, Matrix.of_apply])

/-- **THE BRIDGE PROVED**: Rayleigh divergence → L² convergence.

    From log_cutoff_witness_bound at size (N-1), the Rayleigh quotient
    of the log-cutoff witness on the BD Gram matrix grows ≥ c·log(N-1).
    The λ-trick converts this into:
      ∫₀¹(1 - bdLinComb N v x)² ≤ 1/(1 + c·log(N-1)) → 0

    This DIRECTLY bridges the algebraic world to the L² world,
    bypassing algebraic_nb_bridge and all matrix inverse machinery. -/
theorem forward_bridge_from_lambda_trick
    (c : ℝ) (hc : 0 < c)
    (h_witness : ∃ N₀ : ℕ, ∀ M : ℕ, M ≥ N₀ →
      c * Real.log (M : ℝ) ≤ Cathedral.Vasyunin.rayleighQuotient M
        (Cathedral.Vasyunin.logCutoffWitness M)) :
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε := by
  intro ε hε
  obtain ⟨M₀, h_rayleigh⟩ := h_witness
  -- Step A: Choose N large enough that 1/(1 + c·log(N-1)) < ε
  set N₀ := max (M₀ + 1) 5
  -- We need a large-enough bound; pick N₀ so that c·log(N₀-1) > 1/ε - 1
  -- For now, we use the Archimedean property of log
  suffices h_suff : ∃ N₁ : ℕ, N₁ ≥ N₀ ∧
      ∀ N ≥ N₁, ∃ v : Fin (N - 1) → ℝ,
        ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε by
    obtain ⟨N₁, _, h⟩ := h_suff
    exact ⟨N₁, h⟩
  -- Use Tendsto to find N₁ with c·log(N₁-1) large enough
  have h_exist : ∃ K : ℕ, K ≥ N₀ ∧ 1 / ε - 1 < c * Real.log ((K - 1 : ℕ) : ℝ) := by
    -- log → ∞, so ∃ M with log M > (1/ε - 1) / c
    -- Then K = M + 1 gives log (K-1) = log M > (1/ε - 1)/c
    obtain ⟨R, hR⟩ := (Filter.tendsto_atTop_atTop.mp Real.tendsto_log_atTop
      ((1 / ε - 1) / c + 1))
    set K := max (⌈R⌉₊ + 2) (N₀ + 1)
    refine ⟨K, by omega, ?_⟩
    have hK_sub : (K - 1 : ℕ) ≥ ⌈R⌉₊ + 1 := by omega
    have hR_le : R ≤ ((K - 1 : ℕ) : ℝ) := by
      have h1 : R ≤ (⌈R⌉₊ : ℝ) := Nat.le_ceil R
      have h2 : (⌈R⌉₊ : ℝ) ≤ ((K - 1 : ℕ) : ℝ) := by exact_mod_cast (show ⌈R⌉₊ ≤ K - 1 by omega)
      linarith
    have hlog_bound := hR ((K - 1 : ℕ) : ℝ) hR_le
    calc 1 / ε - 1
        < (1 / ε - 1) / c * c + c := by rw [div_mul_cancel₀ _ (ne_of_gt hc)]; linarith
      _ = ((1 / ε - 1) / c + 1) * c := by ring
      _ ≤ Real.log ((K - 1 : ℕ) : ℝ) * c := by nlinarith
      _ = c * Real.log ((K - 1 : ℕ) : ℝ) := by ring
  obtain ⟨K, hK_ge, hK_log⟩ := h_exist
  refine ⟨K, hK_ge, fun N hN => ?_⟩
  have hN5 : N ≥ 5 := by omega
  have hN2 : 2 ≤ N := by omega
  have hN3 : N - 1 ≥ 3 := by omega
  have hNM : N - 1 ≥ M₀ := by omega
  -- Step B: Construct the witness via the λ-trick
  set M := N - 1
  set y := Cathedral.Vasyunin.logCutoffWitness M
  set G_bd := Matrix.of fun i j : Fin (N - 1) =>
    Cathedral.Vasyunin.vasyuninGramEntry (i.val + 1) (j.val + 1)
  set b_bd := fun i : Fin (N - 1) => Cathedral.Vasyunin.vasyuninMeanEntry (i.val + 1)
  set S := dotProduct b_bd y
  set P := realQuadForm G_bd y
  set Q := realQuadForm (Cathedral.Vasyunin.vasyuninCovMatrix M) y
  -- Step C: Key properties
  have hP_pos : 0 < P := bd_gram_pos N hN3
  have hQ_pos : 0 < Q := bd_cov_pos N hN3
  have hP_eq : P = Q + S ^ 2 := by
    show realQuadForm G_bd y = Q + (dotProduct b_bd y) ^ 2
    rw [show b_bd = Cathedral.Vasyunin.vasyuninMeanVec M from (bd_mean_eq_vasyunin N).symm]
    exact bd_gram_decomp N
  -- Step D: The Rayleigh quotient bound
  have h_ray_bound : c * Real.log (M : ℝ) ≤ S ^ 2 / Q := by
    have h_rq := h_rayleigh M hNM
    unfold Cathedral.Vasyunin.rayleighQuotient at h_rq
    rw [show Cathedral.Vasyunin.vasyuninMeanVec M =
        b_bd from (bd_mean_eq_vasyunin N)] at h_rq
    exact h_rq
  -- Step E: Apply the λ-trick
  set v := fun i : Fin (N - 1) => (S / P) * y i
  refine ⟨v, ?_⟩
  -- ∫(1-f)² = 1 - S²/P
  rw [lambda_trick_integral N hN2 y hP_pos]
  -- 1 - S²/P = 1/(1 + S²/Q) since P = Q + S²
  rw [show (1 : ℝ) - S ^ 2 / P = 1 - S ^ 2 / (Q + S ^ 2) from by rw [hP_eq]]
  rw [parabola_to_rayleigh S Q hQ_pos]
  -- 1/(1 + S²/Q) < ε since S²/Q ≥ c·log M ≥ c·log(K-1) > 1/ε - 1
  have h_denom_pos : 0 < 1 + S ^ 2 / Q := by positivity
  have hlog_M : 0 < Real.log (M : ℝ) :=
    Real.log_pos (by exact_mod_cast (show 1 < M by omega))
  have h_clog_K : 1 / ε - 1 < c * Real.log (M : ℝ) := by
    calc 1 / ε - 1 < c * Real.log ((K - 1 : ℕ) : ℝ) := hK_log
      _ ≤ c * Real.log (M : ℝ) := by
          apply mul_le_mul_of_nonneg_left _ (le_of_lt hc)
          apply Real.log_le_log (by exact_mod_cast (show 0 < K - 1 by omega))
          exact_mod_cast (show K - 1 ≤ M by omega)
  -- 1/ε < 1 + c·log M ≤ 1 + S²/Q
  have h_inv_eps : 1 / ε < 1 + S ^ 2 / Q := by linarith
  rw [div_lt_iff₀ h_denom_pos]
  -- Need: 1 < ε * (1 + S²/Q)
  have h_one_lt : 1 < ε * (1 + S ^ 2 / Q) := by
    have : 1 / ε * ε = 1 := div_mul_cancel₀ 1 (ne_of_gt hε)
    nlinarith [mul_pos hε h_denom_pos]
  linarith

end
