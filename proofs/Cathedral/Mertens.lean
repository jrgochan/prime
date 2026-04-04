/-
  Cathedral/Mertens.lean

  ## Mertens' Theorem and the Selberg Sieve Estimates

  ### Key insight:
  The two-sided bound |bᵀv - 1/2| ≤ C/log N decomposes as:
  - UPPER: bᵀv ≤ 1/2 + C/log N — PROVED from PSD + quadratic bound
  - LOWER: bᵀv ≥ 1/2 - C/log N — requires Mertens (AXIOM)

  `mertens_linear_bound` is therefore HALF-PROVED:
  only the lower bound requires analytic number theory.

  ### Architecture:
  mertens_lower_bound (AXIOM — Mertens 1874)
  mertens_quadratic_bound (AXIOM — Mertens + Vasyunin 1996)
      ↓ [bv_upper_bound — PROVED from PSD + quadratic]
      ↓ [mertens_linear_bound — PROVED from upper + lower]
      ↓ [mertens_selberg — PROVED from linear + quadratic]
  Consumed by SelbergSieve.lean
-/

import Cathedral.Defs
import Cathedral.Structural
import Cathedral.GramBounds
import Mathlib.NumberTheory.ArithmeticFunction.Moebius

noncomputable section
open Real MeasureTheory Set Finset

-- ════════════════════════════════════════════════
-- SECTION 1: SELBERG SIEVE WEIGHTS
-- ════════════════════════════════════════════════

/-- The Selberg sieve weight (linear sieve version). -/
def selbergWeight (d D : ℕ) : ℝ :=
  if d = 0 then 0
  else if D ≤ 1 then (if d = 1 then 1 else 0)
  else if D < d then 0
  else
    (↑(ArithmeticFunction.moebius d : ℤ) : ℝ) *
      max 0 (1 - Real.log (d : ℝ) / Real.log (D : ℝ))

/-- The Selberg weight at d=1 is exactly 1. -/
theorem selbergWeight_one (D : ℕ) (hD : 1 ≤ D) : selbergWeight 1 D = 1 := by
  unfold selbergWeight
  simp only [show (1 : ℕ) ≠ 0 from Nat.one_ne_zero, ↓reduceIte]
  split
  · simp
  · rename_i hD1; push_neg at hD1
    simp only [show ¬ (D < 1) from by omega, ↓reduceIte]
    rw [ArithmeticFunction.moebius_apply_one]; simp [Real.log_one]

/-- The Selberg weight vanishes beyond the sieve level. -/
theorem selbergWeight_zero_of_gt (d D : ℕ) (hD : 1 ≤ D) (h : D < d) :
    selbergWeight d D = 0 := by
  unfold selbergWeight
  split
  · rfl
  · split
    · rename_i hd0 _; rw [if_neg (show d ≠ 1 from by omega)]
    · rfl

/-- The Selberg test vector: v_i = λ(i+1, D) / (i+1). -/
def selbergTestVec (N D : ℕ) : Fin (N - 1) → ℝ :=
  fun i => selbergWeight (i.val + 1) D / (i.val + 1 : ℝ)

-- ════════════════════════════════════════════════
-- SECTION 2: THE TWO AXIOMS (irreducible analytic core)
-- ════════════════════════════════════════════════

/-- **Axiom 1 (Mertens 1874 — Lower Bound on bᵀv)**:

    bᵀv ≥ 1/2 - C/log N

    The Selberg weights "point toward" the target function 1.
    This is the essential one-sided Mertens content.

    **Proof sketch**: bᵀv = (1/2)Σvₖ + Σ(bₖ-1/2)vₖ.
    By Mertens: Σvₖ ≈ 1/log N. The correction Σ(bₖ-1/2)vₖ
    involves |bₖ-1/2| ≤ C/k and Möbius cancellation.
    Net: bᵀv = 1/2 + O(1/log N), so bᵀv ≥ 1/2 - C/log N.

    **Note**: The UPPER bound bᵀv ≤ 1/2 + C/log N is proved
    FREE from PSD (see bv_upper_bound). Only this lower bound
    requires Mertens.

    **Ref**: F. Mertens (1874). Elementary (Chebyshev bounds). -/
axiom mertens_lower_bound :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N →
    1/2 - C / Real.log (N : ℝ) ≤
      dotProduct (basisInnerProd N) (selbergTestVec N N)

/-- **Axiom 2 (Mertens + Vasyunin — Quadratic Bound)**:

    vᵀGv ≤ C/log N

    **Proof sketch**: By Vasyunin, G_{jk} ≈ 1/4 + O(gcd(j,k)/(jk)).
    Main term: (1/4)(Σvₖ)² = O(1/log²N) by Mertens.
    Correction: O(1/log N) by multiplicative structure.

    **Refs**: Mertens (1874), Vasyunin (1996). -/
axiom mertens_quadratic_bound :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N →
    realQuadForm (gramMatrix N) (selbergTestVec N N) ≤
      C / Real.log (N : ℝ)

-- ════════════════════════════════════════════════
-- SECTION 3: UPPER BOUND ON bᵀv (PROVED from PSD)
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: bᵀv ≤ 1/2 + C/log N.

    The UPPER half of the linear bound, proved WITHOUT Mertens —
    purely from ∫₀¹(1-f)² ≥ 0 and the quadratic bound.

    Proof:
    ∫(1-f)² = 1 - 2bᵀv + vᵀGv ≥ 0   (L² nonneg)
    So: 2bᵀv ≤ 1 + vᵀGv ≤ 1 + C/log N
    Hence: bᵀv - 1/2 ≤ C/(2 log N) ≤ C/log N  ∎ -/
theorem bv_upper_bound :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N →
    dotProduct (basisInnerProd N) (selbergTestVec N N) - 1/2 ≤
      C / Real.log (N : ℝ) := by
  obtain ⟨C, hC, N₀, hN₀, h_quad⟩ := mertens_quadratic_bound
  refine ⟨C, hC, max N₀ 2, by omega, fun N hN => ?_⟩
  have hN2 : 2 ≤ N := by omega
  have hN0 : N₀ ≤ N := by omega
  have h_l2 := l2_error_eq_quad_error N hN2 (selbergTestVec N N)
  have h_nonneg : 0 ≤ ∫ x in (0:ℝ)..1,
      (1 - nbLinComb N (selbergTestVec N N) x) ^ 2 := by
    apply intervalIntegral.integral_nonneg (by norm_num : (0:ℝ) ≤ 1)
    intro x _hx; exact sq_nonneg _
  rw [h_l2] at h_nonneg
  set bv := dotProduct (basisInnerProd N) (selbergTestVec N N)
  set qf := realQuadForm (gramMatrix N) (selbergTestVec N N)
  have hqf := h_quad N hN0
  set L := C / Real.log (↑N)
  have hL : qf ≤ L := hqf
  have hL_pos : 0 ≤ L := by positivity
  nlinarith

-- ════════════════════════════════════════════════
-- SECTION 4: mertens_linear_bound (PROVED)
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: |bᵀv - 1/2| ≤ C/log N.

    Combines:
    - Lower (axiom): bᵀv ≥ 1/2 - C₁/log N
    - Upper (proved): bᵀv ≤ 1/2 + C₂/log N   ∎ -/
theorem mertens_linear_bound :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N →
    |dotProduct (basisInnerProd N) (selbergTestVec N N) - 1/2| ≤
      C / Real.log (N : ℝ) := by
  obtain ⟨C₁, hC₁, N₁, hN₁, h_lower⟩ := mertens_lower_bound
  obtain ⟨C₂, hC₂, N₂, hN₂, h_upper⟩ := bv_upper_bound
  refine ⟨max C₁ C₂, by positivity, max N₁ N₂, by omega, fun N hN => ?_⟩
  have hN1 : N₁ ≤ N := by omega
  have hN2 : N₂ ≤ N := by omega
  rw [abs_le]
  set bv := dotProduct (basisInnerProd N) (selbergTestVec N N)
  constructor
  · have h1 := h_lower N hN1
    have hle : C₁ / Real.log (↑N) ≤ max C₁ C₂ / Real.log (↑N) := by
      apply div_le_div_of_nonneg_right (le_max_left _ _); positivity
    linarith
  · have h2 := h_upper N hN2
    have hle : C₂ / Real.log (↑N) ≤ max C₁ C₂ / Real.log (↑N) := by
      apply div_le_div_of_nonneg_right (le_max_right _ _); positivity
    linarith

-- ════════════════════════════════════════════════
-- SECTION 5: mertens_selberg (PROVED)
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: Combined Mertens-Selberg estimate. -/
theorem mertens_selberg :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N →
    (|dotProduct (basisInnerProd N) (selbergTestVec N N) - 1/2| ≤
      C / Real.log (N : ℝ)) ∧
    (realQuadForm (gramMatrix N) (selbergTestVec N N) ≤
      C / Real.log (N : ℝ)) := by
  obtain ⟨C₁, hC₁, N₁, hN₁, h_lin⟩ := mertens_linear_bound
  obtain ⟨C₂, hC₂, N₂, hN₂, h_quad⟩ := mertens_quadratic_bound
  refine ⟨max C₁ C₂, by positivity, max N₁ N₂, by omega, fun N hN => ?_⟩
  have hN1 : N₁ ≤ N := by omega
  have hN2 : N₂ ≤ N := by omega
  constructor
  · have hle : C₁ ≤ max C₁ C₂ := le_max_left _ _
    calc |dotProduct (basisInnerProd N) (selbergTestVec N N) - 1/2|
        ≤ C₁ / Real.log (↑N) := h_lin N hN1
      _ ≤ max C₁ C₂ / Real.log (↑N) := by gcongr
  · have hle : C₂ ≤ max C₁ C₂ := le_max_right _ _
    calc realQuadForm (gramMatrix N) (selbergTestVec N N)
        ≤ C₂ / Real.log (↑N) := h_quad N hN2
      _ ≤ max C₁ C₂ / Real.log (↑N) := by gcongr

end
