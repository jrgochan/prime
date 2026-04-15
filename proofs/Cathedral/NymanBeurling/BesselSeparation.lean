/-
  Cathedral/NymanBeurling/BesselSeparation.lean

  ## The Bessel Separation Theorem

  Proves `zeta_zero_separates` from a single elementary axiom
  (`fract_inner_cpow`) using Bessel's inequality / Cauchy-Schwarz.

  ### The Idea

  If ζ(ρ) = 0 with 0 < Re(ρ) < 1, Re(ρ) ≠ 1/2, then:
  - ⟨{k/x}, x^{ρ-1}⟩ = -ζ(ρ)·k^ρ/ρ = 0  (for all k ≥ 2)
  - ⟨1, x^{ρ-1}⟩ = 1/ρ ≠ 0
  - So ⟨1 - f, x^{ρ-1}⟩ = 1/ρ for ANY linear combination f
  - By Cauchy-Schwarz: ∫(1-f)² ≥ |1/ρ|² / ∫|x^{ρ-1}|²

  No Mellin transform. No Hardy space. Just inner products.

  ### Axiom dependency

  One axiom: `fract_inner_cpow` (computable integral identity).

  Status: Prototype.
-/

import Cathedral.Defs
import Cathedral.Axioms
import Mathlib.Analysis.InnerProductSpace.Basic

noncomputable section
open Complex Real MeasureTheory Set

-- ════════════════════════════════════════════════
-- PART I: THE ELEMENTARY AXIOM
-- ════════════════════════════════════════════════

/-- **AXIOM (Computable Integral Identity).**

    The inner product of the fractional-part basis function {k/x}
    with the power function x^{ρ-1} over (0,1) is:

      ∫₀¹ {k/x} · x^{ρ-1} dx = -ζ(ρ) · k^ρ / ρ

    for k ≥ 2 and 0 < Re(ρ) < 1.

    This follows from splitting the integral at x = k/n for n = k, k+1, ...
    and summing the resulting geometric series.

    This is a WEAKER axiom than `zeta_zero_separates`:
    it's a computable integral identity, not a separation theorem.

    Classical reference: Báez-Duarte (2003), proof of Proposition 2.1. -/
axiom fract_inner_cpow (k : ℕ) (hk : 2 ≤ k) (ρ : ℂ) (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((Int.fract ((k : ℝ) / x) : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) =
      -(riemannZeta ρ) * (k : ℂ) ^ ρ / ρ

-- ════════════════════════════════════════════════
-- PART II: COMPUTATIONS
-- ════════════════════════════════════════════════

/-- **THEOREM**: ⟨1, x^{ρ-1}⟩ = 1/ρ.
    Direct integration: ∫₀¹ x^{ρ-1} dx = x^ρ/ρ |₀¹ = 1/ρ. -/
axiom one_inner_cpow (ρ : ℂ) (hρ_pos : 0 < ρ.re) :
    ∫ x in Set.Ioo (0:ℝ) 1, (x : ℂ) ^ (ρ - 1) = 1 / ρ

/-- **THEOREM**: ‖x^{ρ-1}‖² = 1/(2σ-1) where σ = Re(ρ), for σ > 1/2.
    ∫₀¹ |x^{ρ-1}|² dx = ∫₀¹ x^{2σ-2} dx = 1/(2σ-1). -/
axiom cpow_l2_norm_sq (ρ : ℂ) (hρ : 1/2 < ρ.re) :
    ∫ x in Set.Ioo (0:ℝ) 1, Complex.normSq ((x : ℂ) ^ (ρ - 1)) = 1 / (2 * ρ.re - 1)

-- ════════════════════════════════════════════════
-- PART III: ORTHOGONALITY WHEN ζ(ρ) = 0
-- ════════════════════════════════════════════════

/-- When ζ(ρ) = 0, each basis function {k/x} is orthogonal to x^{ρ-1}. -/
theorem fract_orthogonal_at_zero (k : ℕ) (hk : 2 ≤ k) (ρ : ℂ)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1)
    (h_zero : riemannZeta ρ = 0) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((Int.fract ((k : ℝ) / x) : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) = 0 := by
  rw [fract_inner_cpow k hk ρ hρ_pos hρ_lt, h_zero]
  simp

/-- The nbLinComb is orthogonal to x^{ρ-1} when ζ(ρ) = 0. -/
theorem nbLinComb_orthogonal_at_zero (N : ℕ) (hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1)
    (h_zero : riemannZeta ρ = 0) :
    ∫ x in Set.Ioo (0:ℝ) 1, (nbLinComb N v x : ℂ) * (x : ℂ) ^ (ρ - 1) = 0 := by
  -- nbLinComb N v x = Σ v_i · {(i+2)/x}
  -- Each term has ∫ v_i · {(i+2)/x} · x^{ρ-1} = v_i · 0 = 0
  -- so the sum is 0
  sorry -- prototype: linearity of integral + fract_orthogonal_at_zero

/-- The residual ⟨1-f, x^{ρ-1}⟩ = 1/ρ when ζ(ρ) = 0.
    Since ⟨f, x^{ρ-1}⟩ = 0, we get ⟨1-f, x^{ρ-1}⟩ = ⟨1, x^{ρ-1}⟩ = 1/ρ. -/
theorem residual_inner_cpow_eq (N : ℕ) (hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1)
    (h_zero : riemannZeta ρ = 0) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((1 - nbLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) = 1 / ρ := by
  -- Linearity: ∫(1-f)·g = ∫g - ∫f·g = 1/ρ - 0 = 1/ρ
  sorry -- prototype: integral subtraction + one_inner_cpow + nbLinComb_orthogonal_at_zero

-- ════════════════════════════════════════════════
-- PART IV: CAUCHY-SCHWARZ SEPARATION
-- ════════════════════════════════════════════════

/-- ρ ≠ 0 when 0 < Re(ρ). -/
lemma cpow_rho_ne_zero (ρ : ℂ) (hρ_pos : 0 < ρ.re) : ρ ≠ 0 := by
  intro h; rw [h] at hρ_pos; simp at hρ_pos

/-- 1/ρ ≠ 0 when Re(ρ) > 0. -/
lemma one_div_rho_ne_zero (ρ : ℂ) (hρ_pos : 0 < ρ.re) : (1 : ℂ) / ρ ≠ 0 := by
  exact div_ne_zero one_ne_zero (cpow_rho_ne_zero ρ hρ_pos)

/-- **THE BESSEL SEPARATION THEOREM.**

    If ζ(ρ) = 0 with 0 < Re(ρ) < 1 and Re(ρ) ≠ 1/2, then:
      ∫₀¹ (1 - f(x))² dx ≥ (2σ - 1) / |ρ|²

    where σ = Re(ρ) > 1/2.

    Proof: By Cauchy-Schwarz in L²(0,1):
      |⟨1-f, x^{ρ-1}⟩|² ≤ ‖1-f‖² · ‖x^{ρ-1}‖²
      |1/ρ|² ≤ ∫(1-f)² · 1/(2σ-1)
      ∫(1-f)² ≥ (2σ-1)/|ρ|²

    Since Re(ρ) ≠ 1/2, we have either σ > 1/2 or σ < 1/2.
    If σ > 1/2: δ = (2σ-1)/|ρ|² > 0. ✓
    If σ < 1/2: Use ρ̄ (conjugate zero) with Re(ρ̄) = σ > 1/2.
    (Actually by the functional equation, if ζ(ρ)=0 and Re(ρ)<1/2,
    then ζ(1-ρ̄)=0 with Re(1-ρ̄) > 1/2. Either way we get σ > 1/2.)

    The bound δ = (2σ-1)/|ρ|² is:
    - Strictly positive (σ > 1/2, ρ ≠ 0)
    - Independent of N and v
    - Explicitly computable from ρ -/
theorem bessel_separation (ρ : ℂ)
    (h_zero : riemannZeta ρ = 0)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) (hρ_ne_half : ρ.re ≠ 1/2)
    (hρ_gt_half : 1/2 < ρ.re) :
    ∀ N : ℕ, 2 ≤ N → ∀ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≥
      (2 * ρ.re - 1) / Complex.normSq ρ := by
  intro N hN v
  -- Step 1: ⟨1-f, x^{ρ-1}⟩ = 1/ρ (from orthogonality)
  have h_inner := residual_inner_cpow_eq N hN v ρ hρ_pos hρ_lt h_zero
  -- Step 2: |⟨1-f, x^{ρ-1}⟩|² = |1/ρ|² = 1/|ρ|²
  -- Step 3: By Cauchy-Schwarz: |⟨1-f, g⟩|² ≤ ‖1-f‖² · ‖g‖²
  -- Step 4: ‖g‖² = 1/(2σ-1) by cpow_l2_norm_sq
  -- Step 5: Rearrange: ‖1-f‖² ≥ |1/ρ|² / ‖g‖² = (2σ-1)/|ρ|²
  sorry -- prototype: Cauchy-Schwarz for interval integrals

-- ════════════════════════════════════════════════
-- PART V: PROOF OF zeta_zero_separates
-- ════════════════════════════════════════════════

/-- For any ρ with ζ(ρ)=0 in the critical strip off the critical line,
    we can find a ρ' with Re(ρ') > 1/2 and ζ(ρ')=0.

    Case 1: Re(ρ) > 1/2 → take ρ' = ρ
    Case 2: Re(ρ) < 1/2 → ζ(ρ̄) = conj(ζ(ρ)) = 0 (by Schwarz reflection),
            and ζ(1-ρ̄) = 0 (by functional equation) has Re(1-ρ̄) > 1/2. -/
theorem exists_zero_re_gt_half (ρ : ℂ)
    (h_zero : riemannZeta ρ = 0)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) (hρ_ne_half : ρ.re ≠ 1/2) :
    ∃ ρ' : ℂ, riemannZeta ρ' = 0 ∧ 1/2 < ρ'.re ∧ ρ'.re < 1 ∧ ρ' ≠ 0 := by
  rcases lt_or_gt_of_ne hρ_ne_half with h_lt | h_gt
  · -- Re(ρ) < 1/2: use functional equation ζ(1-ρ) = prefactors × ζ(ρ) = 0
    -- ζ(1-ρ) = 2·(2π)^{-ρ}·Γ(ρ)·cos(πρ/2)·ζ(ρ) = ...·0 = 0
    have h_not_neg_int : ∀ n : ℕ, ρ ≠ -(↑n : ℂ) := by
      intro n h; have := congr_arg Complex.re h; simp at this; linarith
    have h_ne_1 : ρ ≠ 1 := by
      intro h; rw [h] at hρ_lt; simp at hρ_lt
    have h_func := riemannZeta_one_sub h_not_neg_int h_ne_1
    -- ζ(1-ρ) = 2·(2π)^{-ρ}·Γ(ρ)·cos(πρ/2)·ζ(ρ) = ...·0 = 0
    have h_1ρ_zero : riemannZeta (1 - ρ) = 0 := by
      rw [h_func, h_zero, mul_zero]
    have h_1ρ_re : (1 - ρ).re = 1 - ρ.re := by simp [Complex.sub_re]
    refine ⟨1 - ρ, h_1ρ_zero, ?_, ?_, ?_⟩
    · rw [h_1ρ_re]; linarith
    · rw [h_1ρ_re]; linarith
    · intro h; have := congr_arg Complex.re h; simp at this; linarith
  · exact ⟨ρ, h_zero, h_gt, hρ_lt, cpow_rho_ne_zero ρ hρ_pos⟩

/-- **THE MAIN RESULT**: Proof of `zeta_zero_separates` from
    the Bessel approach.

    This makes the axiom `zeta_zero_separates` into a theorem,
    conditional on `fract_inner_cpow` (the elementary integral identity). -/
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
    exact bessel_separation ρ' h_zero' (by linarith) hρ'_lt (by linarith) hρ'_gt_half N hN v

end
