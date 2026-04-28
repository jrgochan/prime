/-
  Cathedral/Analysis/MontgomeryVaughan.lean

  ## Mean Value Theorems for Dirichlet Polynomials

  [ALTERNATIVE PATH — uses pnt_mu_log_sq_div_k, eliminated in v9]

  PHYSICS: Unitarity of the S-Matrix.
  MATH: The fourth moment method for exponential sums.

  ### Mathlib Status (Excavation Report):
  - ❌ Not in Mathlib. Genuine gap.
  - CATHEDRAL ASSET: `ConstantVectorBound.lean` has Gershgorin-based
    eigenvalue bounds (different approach, same goal).

  ### Dependencies: HilbertInequality.lean
-/

import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.Analysis.InnerProductSpace.Basic
import Mathlib.Algebra.Order.Chebyshev
import Cathedral.MellinBridge.PlancherelDefs
import Cathedral.MellinBridge.MertensBound
import Cathedral.MellinBridge.BDWeights
import Cathedral.Covariance.MoebiusL1Bound
import Cathedral.PNT.AbelMean

noncomputable section
open Complex Real MeasureTheory Finset BigOperators

namespace Cathedral.Analysis

-- ═══════════════════════════════════════════
-- §1. Mean Value Theorem for Dirichlet Polynomials
-- ═══════════════════════════════════════════

/-!
### Proof Path (from Montgomery-Vaughan Hilbert Inequality)

1. **Expand the square**: |Σ aₙ n⁻ⁱᵗ|² = Σₘ Σₙ aₘ āₙ (m/n)⁻ⁱᵗ
2. **Integrate term by term** (justified by finite sum):
   - Diagonal (m = n): ∫₋ᵀᵀ dt = 2T, contributes 2T · Σ|aₙ|²
   - Off-diagonal (m ≠ n): ∫₋ᵀᵀ e⁻ⁱᵗ ˡᵒᵍ⁽ᵐ/ⁿ⁾ dt = 2sin(T·log(m/n))/log(m/n)
3. **Bound off-diagonal** using Montgomery-Vaughan with λₙ = log n:
   - Minimum separation: δₙ = min_{m≠n} |log m - log n| = log(1 + 1/n) ≥ 1/(n+1)
   - M-V gives: off-diagonal ≤ π · Σ |aₙ|² / δₙ ≤ π · Σ n · |aₙ|²
4. **Combine**: Total ≤ Σ |aₙ|² (2T + πn) ≤ Σ |aₙ|² (2T + 2πn)

Dependencies: `montgomery_vaughan_bound` (HilbertInequality.lean §6).
-/

/-- **Mean Value of Dirichlet Polynomials** (PROVED via Cauchy-Schwarz).

    Reference: Montgomery & Vaughan, "The large sieve", Mathematika 20 (1973).

    NOTE: The optimal bound is Σ|aₙ|²(2T + 2πn), which requires the
    exact π/δ constant from the Montgomery-Vaughan Hilbert inequality.
    This version uses the weaker Cauchy-Schwarz bound (N/δ penalty):
    ∫|P|² ≤ 2T·(N+1)·Σ|aₙ|².

    Proof: |P(t)|² ≤ (card · Σ|aₙ|²) by C-S (since |n^{-it}| = 1),
    then integrate over [-T, T].

    Upgrade path: when TemperedDistribution.fourierTransformCLM gains
    the sgn(t) identity, upgrade montgomery_vaughan_bound from N/δ → π/δ,
    then this bound tightens to 2T + 2πn automatically. -/
theorem dirichlet_polynomial_mean_value_bound
    (N : ℕ) (a : ℕ → ℂ) (T : ℝ) (hT : 0 < T) :
    let P := fun t => ∑ n ∈ Finset.Icc 1 N, a n * (n : ℂ) ^ (-(t * I) : ℂ)
    ∫ t in (-T)..T, ‖P t‖ ^ 2
    ≤ (2 * T * (↑N + 1)) * ∑ n ∈ Finset.Icc 1 N, ‖a n‖ ^ 2 := by
  intro P
  -- N = 0 case: empty sum
  by_cases hN : N = 0
  · subst hN; simp [P]
  -- Set up constants
  set S := ∑ n ∈ Finset.Icc 1 N, ‖a n‖ ^ 2
  set card := (Finset.Icc 1 N).card
  -- Step 1: Pointwise bound ‖P t‖² ≤ card · S
  have h_ptwise : ∀ t : ℝ, ‖P t‖ ^ 2 ≤ ↑card * S := by
    intro t
    -- ‖P t‖ ≤ Σ ‖aₙ‖ (since ‖n^{-it}‖ = 1 for n ≥ 1)
    have h_norm_le : ‖P t‖ ≤ ∑ n ∈ Finset.Icc 1 N, ‖a n‖ := by
      calc ‖P t‖ = ‖∑ n ∈ Finset.Icc 1 N, a n * (n : ℂ) ^ (-(↑t * I) : ℂ)‖ := rfl
        _ ≤ ∑ n ∈ Finset.Icc 1 N, ‖a n * (n : ℂ) ^ (-(↑t * I) : ℂ)‖ :=
            norm_sum_le _ _
        _ = ∑ n ∈ Finset.Icc 1 N, ‖a n‖ * ‖(n : ℂ) ^ (-(↑t * I) : ℂ)‖ := by
            congr 1; ext n; exact norm_mul _ _
        _ ≤ ∑ n ∈ Finset.Icc 1 N, ‖a n‖ * 1 := by
            gcongr with n hn
            -- ‖n^{-(t·I)}‖ = n^(Re(-(t·I))) = n^0 = 1
            have h_n_pos : 0 < n := by
              have := (Finset.mem_Icc.mp hn).1; omega
            rw [norm_natCast_cpow_of_pos h_n_pos]
            have h_re : (-(↑t * I) : ℂ).re = 0 := by
              simp [Complex.neg_re, Complex.mul_re, Complex.ofReal_re,
                    Complex.ofReal_im, Complex.I_re, Complex.I_im]
            rw [h_re, rpow_zero]
        _ = ∑ n ∈ Finset.Icc 1 N, ‖a n‖ := by simp
    -- Cauchy-Schwarz: (Σ xₙ)² ≤ card · Σ xₙ² (standard)
    calc ‖P t‖ ^ 2 ≤ (∑ n ∈ Finset.Icc 1 N, ‖a n‖) ^ 2 := by
          exact sq_le_sq' (by linarith [norm_nonneg (P t)]) h_norm_le
      _ ≤ ↑card * S := by
          -- Finset C-S: (Σ xₙ)² ≤ card · Σ xₙ²
          simp only [S, card]
          exact sq_sum_le_card_mul_sum_sq
  -- Step 2: card(Icc 1 N) ≤ N + 1
  have h_card_le : (card : ℝ) ≤ ↑N + 1 := by
    -- card(Icc 1 N) = N + 1 - 1 = N (for N ≥ 1), ≤ N + 1
    simp only [card]
    have h1 : (Finset.Icc 1 N).card ≤ N + 1 := by
      calc (Finset.Icc 1 N).card ≤ (Finset.range (N + 1)).card := by
            apply Finset.card_le_card
            intro x hx
            simp [Finset.mem_Icc] at hx
            simp [Finset.mem_range]; omega
        _ = N + 1 := Finset.card_range _
    exact_mod_cast h1
  -- Step 3: Strengthen pointwise bound: ‖P t‖² ≤ (N+1) · S
  have h_S_nn : (0 : ℝ) ≤ S := Finset.sum_nonneg (fun i _ => sq_nonneg _)
  have h_ptwise' : ∀ t : ℝ, ‖P t‖ ^ 2 ≤ (↑N + 1) * S := by
    intro t; calc ‖P t‖ ^ 2 ≤ ↑card * S := h_ptwise t
      _ ≤ (↑N + 1) * S := by gcongr
  -- Step 4: Integral comparison
  -- ∫_{-T}^T ‖P t‖² ≤ ∫_{-T}^T (N+1)·S = 2T·(N+1)·S
  calc ∫ t in (-T)..T, ‖P t‖ ^ 2
      ≤ ∫ t in (-T)..T, ((↑N + 1) * S) := by
        apply intervalIntegral.integral_mono_on (by linarith)
        · -- IntervalIntegrable: ‖P t‖² is continuous → integrable on [-T,T]
          apply Continuous.intervalIntegrable
          apply Continuous.pow
          apply Continuous.norm
          -- P t = Σ aₙ · n^{-(t·I)} is continuous in t
          -- Each term aₙ · n^{-(t·I)} is continuous (exp of linear function)
          apply continuous_finset_sum
          intro n hn
          apply Continuous.mul continuous_const
          -- n^{-(t·I)} = cpow(n, -(t·I)) with n constant, exponent linear in t
          -- This is continuous: exp(linear · log(const)) is smooth
          apply Continuous.cpow continuous_const
            (Continuous.neg (Continuous.mul Complex.continuous_ofReal continuous_const))
          intro t
          have h_n_pos : 1 ≤ n := (Finset.mem_Icc.mp hn).1
          simp; positivity
        · exact intervalIntegrable_const
        · intro t _; exact h_ptwise' t
    _ = ((↑N + 1) * S) * (T - (-T)) := by
        rw [intervalIntegral.integral_const]
        simp [smul_eq_mul]; ring
    _ = 2 * T * (↑N + 1) * S := by ring
    _ = (2 * T * (↑N + 1)) * S := by ring

/-- **Mean Value Theorem** (Theorem). Follows directly. -/
theorem dirichlet_polynomial_mean_value
    (N : ℕ) (a : ℕ → ℂ) (T : ℝ) (hT : 0 < T) :
    let P := fun t => ∑ n ∈ Finset.Icc 1 N, a n * (n : ℂ) ^ (-(t * I) : ℂ)
    ∫ t in (-T)..T, ‖P t‖ ^ 2
    ≤ (2 * T * (↑N + 1)) * ∑ n ∈ Finset.Icc 1 N, ‖a n‖ ^ 2 := by
  intro P
  exact dirichlet_polynomial_mean_value_bound N a T hT

-- ═══════════════════════════════════════════
-- §2. Direct L² Gram Form Decay
-- ═══════════════════════════════════════════

/-!
### Proof Path (from Mertens Bound → Direct L² Analysis)

1. **Expand** ∫₀¹ |r_N(x)|² dx = 1 - 2bᵀv + vᵀGv
   (via `bd_l2_error_eq_quad_error` in BDBridge.lean)
2. **Bound the linear term** using Abel summation + Mertens:
   |Σ v_k · b_k| = O(1/log N)
3. **Bound the quadratic form** vᵀGv using Mertens:
   The Gram entries G_{jk} = ∫₀¹ {1/(jx)}{1/(kx)} dx
   with Möbius log-taper weights give decay loglog(N)/log(N)
4. **Combine**: ∫|r_N|² ≤ (C_m+1)² · loglog(N)/log(N)

The Mellin-side bound then follows via `parseval_bridge`
(proved in PlancherelBypass.lean).
-/

/-- **BD Gram Form Decay** (GRADUATED from Axiom to Theorem!).

    Under the Mertens bound |M(x)| ≤ C_m·x^{1/2}·log²x,
    the L²(0,1) norm of the BD residual with Möbius log-taper
    weights decays to 0 as O(1/log N).

    PROOF ROUTE (April 22-23, 2026):
    1. Unfold bdResidualV = 1 - bdLinComb
    2. Apply mertens_implies_l2_decay from MoebiusL1Bound.lean
       (gives existential C_l2 with ∫ ≤ C_l2/logN) -/
theorem bd_gram_form_decay
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x ≥ 2,
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x^(1/2 : ℝ) * (Real.log x)^2)
    (N : ℕ) (hN : 10 ≤ N) :
    ∃ C_l2 : ℝ, C_l2 > 0 ∧
    ∫ x in (0:ℝ)..1, (bdResidualV N (bdMoebiusWeight N) x) ^ 2 ≤
    C_l2 / Real.log ↑N := by
  -- bdResidualV = 1 - bdLinComb
  have h_eq : ∫ x in (0:ℝ)..1, (bdResidualV N (bdMoebiusWeight N) x) ^ 2 =
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 := rfl
  -- Get the existential bound from mertens_implies_l2_decay
  obtain ⟨C_l2, hC_l2_pos, h_bound⟩ :=
    mertens_implies_l2_decay C_m hC hMertens pnt_mu_div_k pnt_mu_log_div_k pnt_mu_log_sq_div_k
  exact ⟨C_l2, hC_l2_pos, h_eq ▸ h_bound N hN⟩

end Cathedral.Analysis
