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

import Cathedral.Assembly.BDBridge

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

end
