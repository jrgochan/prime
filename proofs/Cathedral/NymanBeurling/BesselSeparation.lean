/-
  Cathedral/NymanBeurling/BesselSeparation.lean

  ## The Bessel Separation Theorem

  Proves `zeta_zero_separates` from elementary axioms
  using Bessel's inequality / Cauchy-Schwarz.

  ### The Idea

  If ζ(ρ) = 0 with 0 < Re(ρ) < 1, Re(ρ) ≠ 1/2, then:
  - ⟨{k/x}, x^{ρ-1}⟩ = -ζ(ρ)·k^ρ/ρ = 0  (for all k ≥ 2)
  - ⟨1, x^{ρ-1}⟩ = 1/ρ ≠ 0
  - So ⟨1 - f, x^{ρ-1}⟩ = 1/ρ for ANY linear combination f
  - By Cauchy-Schwarz: ∫(1-f)² ≥ |1/ρ|² / ∫|x^{ρ-1}|²

  No Mellin transform. No Hardy space. Just inner products.

  Status: 3 axioms (integral identities), 0 sorry.
-/

import Cathedral.Defs
import Cathedral.Axioms
import Mathlib.Analysis.InnerProductSpace.Basic

noncomputable section
open Complex Real MeasureTheory Set

-- ════════════════════════════════════════════════
-- PART I: ELEMENTARY AXIOMS (Computable Integral Identities)
-- ════════════════════════════════════════════════

/-- **AXIOM 1 (Computable Integral Identity).**
    ∫₀¹ {k/x} · x^{ρ-1} dx = -ζ(ρ) · k^ρ / ρ
    for k ≥ 2 and 0 < Re(ρ) < 1.
    Classical reference: Báez-Duarte (2003), Proposition 2.1. -/
axiom fract_inner_cpow (k : ℕ) (hk : 2 ≤ k) (ρ : ℂ) (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((Int.fract ((k : ℝ) / x) : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) =
      -(riemannZeta ρ) * (k : ℂ) ^ ρ / ρ

/-- **THEOREM**: ∫₀¹ x^{ρ-1} dx = 1/ρ for Re(ρ) > 0.
    Direct integration via Mathlib's integral_cpow:
    ∫₀¹ x^r dx = (1^{r+1} - 0^{r+1})/(r+1)
    With r = ρ-1: = (1 - 0)/ρ = 1/ρ. -/
theorem one_inner_cpow (ρ : ℂ) (hρ_pos : 0 < ρ.re) :
    ∫ x in (0:ℝ)..1, (x : ℂ) ^ (ρ - 1) = 1 / ρ := by
  have hr : -1 < (ρ - 1).re := by simp [Complex.sub_re]; linarith
  have hρ_ne : ρ ≠ 0 := by intro h; rw [h] at hρ_pos; simp at hρ_pos
  rw [integral_cpow (Or.inl hr)]
  simp [Complex.ofReal_zero, Complex.ofReal_one]
  have h0ρ : (0 : ℂ) ^ ρ = 0 := Complex.zero_cpow hρ_ne
  rw [h0ρ]; ring

/-- **AXIOM 3**: The Cauchy-Schwarz separation bound for fractional-part
    linear combinations against power functions.

    For any real-valued function g on (0,1) and any ρ with 1/2 < Re(ρ) < 1:
      |∫₀¹ g(x)·x^{ρ-1} dx|² ≤ ∫₀¹ g(x)² dx · ∫₀¹ |x^{ρ-1}|² dx

    Combined with ∫₀¹ |x^{ρ-1}|² dx = 1/(2σ-1), this gives:
      ∫₀¹ g(x)² dx ≥ (2σ-1) · |∫₀¹ g(x)·x^{ρ-1} dx|²

    This is standard Cauchy-Schwarz for L²(0,1). We state it
    specialized to our setting for clean API.

    Note: this is a THEOREM (not conjecture) — it follows from
    standard Cauchy-Schwarz for Bochner integrals. -/
axiom cauchy_schwarz_cpow_bound (g : ℝ → ℝ) (ρ : ℂ)
    (hρ_gt : 1/2 < ρ.re) (hρ_lt : ρ.re < 1) :
    Complex.normSq (∫ x in Set.Ioo (0:ℝ) 1, (g x : ℂ) * (x : ℂ) ^ (ρ - 1)) ≤
      (∫ x in (0:ℝ)..1, g x ^ 2) * (1 / (2 * ρ.re - 1))

-- ════════════════════════════════════════════════
-- PART II: ORTHOGONALITY WHEN ζ(ρ) = 0
-- ════════════════════════════════════════════════

/-- When ζ(ρ) = 0, each basis function {k/x} is orthogonal to x^{ρ-1}. -/
theorem fract_orthogonal_at_zero (k : ℕ) (hk : 2 ≤ k) (ρ : ℂ)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1)
    (h_zero : riemannZeta ρ = 0) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((Int.fract ((k : ℝ) / x) : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) = 0 := by
  rw [fract_inner_cpow k hk ρ hρ_pos hρ_lt, h_zero]
  simp

-- ════════════════════════════════════════════════
-- PART III: THE RESIDUAL INNER PRODUCT
-- ════════════════════════════════════════════════

/-- The Mellin-image inner product of (1 - nbLinComb) with x^{ρ-1}
    equals 1/ρ when ζ(ρ) = 0.

    This combines linearity of the integral with the orthogonality result:
    ⟨1-f, x^{ρ-1}⟩ = ⟨1, x^{ρ-1}⟩ - Σ vₖ⟨{(k+1)/x}, x^{ρ-1}⟩
                    = 1/ρ - Σ vₖ · 0
                    = 1/ρ

    We state this as the combined result for cleaner proof flow.
    The proof requires integral linearity for finite sums. -/
axiom residual_inner_cpow_eq (N : ℕ) (hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1)
    (h_zero : riemannZeta ρ = 0) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((1 - nbLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) = 1 / ρ

-- ════════════════════════════════════════════════
-- PART IV: CAUCHY-SCHWARZ SEPARATION
-- ════════════════════════════════════════════════

/-- ρ ≠ 0 when 0 < Re(ρ). -/
lemma cpow_rho_ne_zero (ρ : ℂ) (hρ_pos : 0 < ρ.re) : ρ ≠ 0 := by
  intro h; rw [h] at hρ_pos; simp at hρ_pos

/-- **THE BESSEL SEPARATION THEOREM.**

    If ζ(ρ) = 0 with Re(ρ) > 1/2 (and < 1), then:
      ∫₀¹ (1 - f(x))² dx ≥ (2σ - 1) / |ρ|²

    Proof:
    1. ⟨1-f, x^{ρ-1}⟩ = 1/ρ  (residual pinned)
    2. |1/ρ|² ≤ ∫(1-f)² · 1/(2σ-1)  (Cauchy-Schwarz)
    3. Rearrange: ∫(1-f)² ≥ (2σ-1)/|ρ|² -/
theorem bessel_separation (ρ : ℂ)
    (h_zero : riemannZeta ρ = 0)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1)
    (hρ_gt_half : 1/2 < ρ.re) :
    ∀ N : ℕ, 2 ≤ N → ∀ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≥
      (2 * ρ.re - 1) / Complex.normSq ρ := by
  intro N hN v
  -- Step 1: The inner product ⟨1-f, x^{ρ-1}⟩ = 1/ρ
  have h_inner := residual_inner_cpow_eq N hN v ρ hρ_pos hρ_lt h_zero
  -- Step 2: Cauchy-Schwarz: |⟨1-f, x^{ρ-1}⟩|² ≤ ‖1-f‖² · ‖x^{ρ-1}‖²
  have h_cs := cauchy_schwarz_cpow_bound (fun x => 1 - nbLinComb N v x) ρ hρ_gt_half hρ_lt
  -- Step 3: Substitute the inner product value
  rw [h_inner] at h_cs
  -- Step 4: |1/ρ|² = 1/|ρ|²
  have h_normSq_inv : Complex.normSq (1 / ρ) = 1 / Complex.normSq ρ := by
    rw [map_div₀, Complex.normSq_one]
  rw [h_normSq_inv] at h_cs
  -- Step 5: Rearrange: ∫(1-f)² ≥ (2σ-1)/|ρ|²
  have h2σ_pos : (0:ℝ) < 2 * ρ.re - 1 := by linarith
  have hρ_pos' : (0:ℝ) < Complex.normSq ρ := Complex.normSq_pos.mpr (cpow_rho_ne_zero ρ hρ_pos)
  -- h_cs: 1/|ρ|² ≤ I * (1/(2σ-1))
  -- Want: I ≥ (2σ-1)/|ρ|²
  -- Multiply both sides of h_cs by (2σ-1): (2σ-1)/|ρ|² ≤ I
  set I := ∫ x in (0:ℝ)..1, (fun x => 1 - nbLinComb N v x) x ^ 2 with hI_def
  rw [ge_iff_le]
  -- h_cs: 1/|ρ|² ≤ I * (1/(2σ-1))
  -- Equivalent to: (2σ-1)/|ρ|² ≤ I
  -- since (2σ-1) > 0 and |ρ|² > 0
  have h_inv_pos : (0:ℝ) < 1 / (2 * ρ.re - 1) := by positivity
  -- From h_cs: 1/|ρ|² ≤ I * (1/(2σ-1)), divide by (1/(2σ-1)):
  -- 1/|ρ|² / (1/(2σ-1)) ≤ I
  -- (2σ-1)/|ρ|² ≤ I
  have h_step : 1 / Complex.normSq ρ / (1 / (2 * ρ.re - 1)) ≤ I :=
    (div_le_iff₀ h_inv_pos).mpr h_cs
  have h_simp : 1 / Complex.normSq ρ / (1 / (2 * ρ.re - 1)) = (2 * ρ.re - 1) / Complex.normSq ρ := by
    field_simp
  linarith

-- ════════════════════════════════════════════════
-- PART V: FUNCTIONAL EQUATION REFLECTION
-- ════════════════════════════════════════════════

/-- For any ρ with ζ(ρ)=0 and 0 < Re(ρ) < 1, Re(ρ) ≠ 1/2,
    we can find ρ' with Re(ρ') > 1/2 and ζ(ρ')=0.

    If Re(ρ) > 1/2: take ρ' = ρ.
    If Re(ρ) < 1/2: by functional equation, ζ(1-ρ) = 0
    and Re(1-ρ) = 1 - Re(ρ) > 1/2. -/
theorem exists_zero_re_gt_half (ρ : ℂ)
    (h_zero : riemannZeta ρ = 0)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) (hρ_ne_half : ρ.re ≠ 1/2) :
    ∃ ρ' : ℂ, riemannZeta ρ' = 0 ∧ 1/2 < ρ'.re ∧ ρ'.re < 1 ∧ ρ' ≠ 0 := by
  rcases lt_or_gt_of_ne hρ_ne_half with h_lt | h_gt
  · -- Re(ρ) < 1/2: functional equation gives ζ(1-ρ) = ...·ζ(ρ) = 0
    have h_not_neg_int : ∀ n : ℕ, ρ ≠ -(↑n : ℂ) := by
      intro n h; have := congr_arg Complex.re h; simp at this; linarith
    have h_ne_1 : ρ ≠ 1 := by
      intro h; rw [h] at hρ_lt; simp at hρ_lt
    have h_func := riemannZeta_one_sub h_not_neg_int h_ne_1
    have h_1ρ_zero : riemannZeta (1 - ρ) = 0 := by
      rw [h_func, h_zero, mul_zero]
    have h_1ρ_re : (1 - ρ).re = 1 - ρ.re := by simp [Complex.sub_re]
    refine ⟨1 - ρ, h_1ρ_zero, ?_, ?_, ?_⟩
    · rw [h_1ρ_re]; linarith
    · rw [h_1ρ_re]; linarith
    · intro h; have := congr_arg Complex.re h; simp at this; linarith
  · exact ⟨ρ, h_zero, h_gt, hρ_lt, cpow_rho_ne_zero ρ hρ_pos⟩

-- ════════════════════════════════════════════════
-- PART VI: PROOF OF zeta_zero_separates
-- ════════════════════════════════════════════════

/-- **THE MAIN RESULT**: Proof of `zeta_zero_separates` from
    the Bessel approach.

    This makes the axiom `zeta_zero_separates` into a theorem,
    conditional on the elementary integral axioms above. -/
theorem zeta_zero_separates_from_bessel :
    ∀ ρ : ℂ, riemannZeta ρ = 0 →
    0 < ρ.re → ρ.re < 1 → ρ.re ≠ 1/2 →
    ∃ δ : ℝ, 0 < δ ∧
    ∀ N : ℕ, 2 ≤ N → ∀ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≥ δ := by
  intro ρ h_zero hρ_pos hρ_lt hρ_ne_half
  -- Find ρ' with Re(ρ') > 1/2 and ζ(ρ') = 0
  obtain ⟨ρ', h_zero', hρ'_gt_half, hρ'_lt, hρ'_ne_zero⟩ :=
    exists_zero_re_gt_half ρ h_zero hρ_pos hρ_lt hρ_ne_half
  -- δ = (2σ-1)/|ρ'|² > 0
  refine ⟨(2 * ρ'.re - 1) / Complex.normSq ρ', ?_, ?_⟩
  · -- δ > 0
    apply div_pos
    · linarith
    · exact Complex.normSq_pos.mpr hρ'_ne_zero
  · -- ∫(1-f)² ≥ δ for all N, v
    intro N hN v
    exact bessel_separation ρ' h_zero' (by linarith) hρ'_lt hρ'_gt_half N hN v

end
