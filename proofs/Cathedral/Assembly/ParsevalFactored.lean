/-
  Cathedral/Assembly/ParsevalFactored.lean

  # Phase 1: Parseval Bridge × Mellin Factorization

  ## Purpose

  Wire the PROVED Parseval bridge to the PROVED Mellin residual
  decomposition, establishing:

    ∫₀¹|r_N|² = (1/2π) ∫ ‖R_N(½+it) + (ζ(½+it)/(½+it))·D_N(½+it)‖² dt

  where R_N is the rational part and D_N is the BD Dirichlet polynomial.

  ## Key Achievement

  This file makes the Mellin structure EXPLICIT in the L² identity,
  enabling the Moment Method path:
  1. ParsevalFactored (this file): L² = (1/2π)∫‖R + (ζ/s)·D‖²
  2. ZetaEnvelope: bound ∫‖R + (ζ/s)·D‖² using MVT + fourth moment
  3. CoefficientDecay: Σ|v_k|²/k = O(1/logN) from PNT

  ## Dependencies (ALL PROVED)
  - Cathedral.White.Scattering (parseval_bridge_white)
  - Cathedral.Assembly.MellinResidualExpansion (mellin_residual_poly_form)
  - Cathedral.Analysis.MontgomeryVaughan (dirichlet_polynomial_mean_value_bound)

  Created: May 14, 2026 — Exploration 36
  Status: Phase 1 of Moment Method + Large Sieve Plan
-/

import Cathedral.White.Scattering
import Cathedral.Assembly.MellinResidualExpansion
import Cathedral.Analysis.MontgomeryVaughan

noncomputable section
open Real MeasureTheory Complex Set Filter Finset BigOperators

namespace Cathedral.MomentMethod

-- ════════════════════════════════════════════════
-- §1. INTEGRAND FACTORIZATION
-- ════════════════════════════════════════════════

/-- **PROVED**: The Mellin residual on the critical line decomposes as
    R_N(s) + (ζ(s)/s)·D_N(s), where:
    - R_N is a rational function (no ζ dependence)
    - D_N is a Dirichlet polynomial (finite sum, no ζ)
    - ζ(s)/s is the single factor carrying analytic information

    Validity: Re(s) > 0 and s ≠ 1. Both hold on s = ½+it for all t ∈ ℝ.

    This is the KEY structural fact that enables the Moment Method:
    the ζ factor multiplies a FINITE Dirichlet polynomial, which
    is bounded by the proved MVT. -/
theorem mellin_factored_on_critical_line (N : ℕ) (v : Fin (N - 1) → ℝ) (t : ℝ) :
    let s := (1/2 : ℂ) + t * Complex.I
    mellinBDResidual N v s =
    bdRationalPart N v s +
    (riemannZeta s / s) * bdDirichletPoly N v s := by
  intro s
  apply mellin_residual_poly_form N v s
  · -- Re(s) > 0: Re(1/2 + it) = 1/2 > 0
    simp only [s, Complex.add_re, Complex.ofReal_re, Complex.mul_re,
               Complex.ofReal_re, Complex.I_re, Complex.ofReal_im,
               Complex.I_im]
    norm_num
  · -- s ≠ 1: 1/2 + it ≠ 1 because Im(1/2 + it) = t, Im(1) = 0,
    --         and Re(1/2+it) = 1/2 ≠ 1
    simp only [s]
    intro h
    have hre : ((1 : ℂ)/2 + ↑t * I).re = (1 : ℂ).re := congrArg Complex.re h
    simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re,
          Complex.ofReal_im, Complex.I_im] at hre

-- ════════════════════════════════════════════════
-- §2. THE PARSEVAL-FACTORED IDENTITY
-- ════════════════════════════════════════════════

/-- **PROVED**: The L²(0,1) norm of the BD residual equals the
    critical-line integral of the factored Mellin transform.

    ∫₀¹ |r_N(x)|² dx = (1/2π) ∫ ‖R_N(½+it) + (ζ(½+it)/(½+it))·D_N(½+it)‖² dt

    Proof: Combine `parseval_bridge_white` (PROVED) with
    `mellin_factored_on_critical_line` (PROVED). -/
theorem parseval_factored (N : ℕ) (v : Fin (N - 1) → ℝ) :
    ∫ x in (0:ℝ)..1, (bdResidualV N v x) ^ 2 =
    (1 / (2 * Real.pi)) *
    ∫ t : ℝ, ‖bdRationalPart N v ((1/2 : ℂ) + t * I) +
              (riemannZeta ((1/2 : ℂ) + t * I) / ((1/2 : ℂ) + t * I)) *
              bdDirichletPoly N v ((1/2 : ℂ) + t * I)‖ ^ 2 := by
  -- Step 1: Apply the Parseval bridge (PROVED)
  rw [Cathedral.White.parseval_bridge_white N v]
  -- Step 2: The integrands agree pointwise via mellin_factored_on_critical_line
  congr 1
  apply integral_congr_ae
  filter_upwards with t
  congr 1
  rw [mellin_factored_on_critical_line N v t]

-- ════════════════════════════════════════════════
-- §3. DIRICHLET POLYNOMIAL EXTRACTION
-- ════════════════════════════════════════════════

/-- The BD Dirichlet polynomial coefficient at index k.

    For the log-cutoff weights: a_k = v_k · k^{-1/2}
    where v_k = -μ(k) · (1 - log(k)/logN). -/
def bdDirichletCoeff (N : ℕ) (v : Fin (N - 1) → ℝ) (k : ℕ) : ℂ :=
  if h : k ∈ Finset.Icc 1 (N - 1) then
    (v ⟨k - 1, by have := (Finset.mem_Icc.mp h).1; have := (Finset.mem_Icc.mp h).2; omega⟩ : ℂ) *
    (k : ℂ) ^ (-(1/2 : ℂ))
  else 0

/-- **PROVED**: The BD Dirichlet polynomial on the critical line is a
    standard Dirichlet polynomial in the MVT sense.

    D_N(½+it) = Σ_{k=1}^{N-1} v_k · k^{-½-it}
              = Σ_{k=1}^{N-1} (v_k/√k) · k^{-it}

    The MVT applies to the k^{-it} sum with coefficients v_k/√k. -/
theorem bd_dirichlet_as_exp_sum (N : ℕ) (v : Fin (N - 1) → ℝ) (t : ℝ) :
    bdDirichletPoly N v ((1/2 : ℂ) + t * I) =
    ∑ i : Fin (N - 1), (v i : ℂ) * (↑(i.val + 1 : ℕ) : ℂ) ^ (-(1/2 : ℂ) - t * I) := by
  unfold bdDirichletPoly
  congr 1; ext i
  congr 1
  show (↑(i.val + 1 : ℕ) : ℂ) ^ (-((1 / 2 : ℂ) + ↑t * I)) =
       (↑(i.val + 1 : ℕ) : ℂ) ^ (-(1 / 2 : ℂ) - ↑t * I)
  congr 1; ring

-- ════════════════════════════════════════════════
-- §4. RATIONAL PART BOUND ON THE CRITICAL LINE
-- ════════════════════════════════════════════════

/-- **Helper (not on critical path)**: The rational part is bounded.
    On the critical line s = 1/2 + it, |1/s| ≤ 2 and |1/(s-1)| ≤ 2. -/
theorem rational_part_bounded (N : ℕ) (v : Fin (N - 1) → ℝ) (t : ℝ) :
    ‖bdRationalPart N v ((1/2 : ℂ) + t * I)‖ ≤
    2 + 2 * ∑ i : Fin (N - 1), |v i| / (↑(i.val + 1) : ℝ) := by
  set s := (1/2 : ℂ) + ↑t * I with hs_def
  unfold bdRationalPart
  -- Key bounds: |s| ≥ 1/2, |s - 1| ≥ 1/2
  have hs_re : s.re = 1/2 := by
    rw [hs_def]; simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.ofReal_im, Complex.I_im]
  have hs1_re : (s - 1).re = -1/2 := by
    rw [hs_def]
    simp [Complex.sub_re, Complex.add_re, Complex.ofReal_re, Complex.mul_re,
      Complex.I_re, Complex.ofReal_im, Complex.I_im, Complex.one_re]
    norm_num
  have hs_lb : (1:ℝ)/2 ≤ ‖s‖ := by
    by_contra h; push Not at h
    have hnsq : Complex.normSq s = s.re * s.re + s.im * s.im := by
      rw [Complex.normSq_apply]
    have hnorm : (Complex.normSq s : ℝ) = ‖s‖ ^ 2 := by
      rw [← Complex.normSq_eq_norm_sq]
    have : s.re * s.re ≤ Complex.normSq s := by rw [hnsq]; linarith [mul_self_nonneg s.im]
    rw [hs_re] at this
    nlinarith [norm_nonneg s]
  have hs1_lb : (1:ℝ)/2 ≤ ‖s - 1‖ := by
    by_contra h; push Not at h
    have hnsq : Complex.normSq (s - 1) = (s - 1).re * (s - 1).re + (s - 1).im * (s - 1).im := by
      rw [Complex.normSq_apply]
    have hnorm : (Complex.normSq (s - 1) : ℝ) = ‖s - 1‖ ^ 2 := by
      rw [← Complex.normSq_eq_norm_sq]
    have : (s - 1).re * (s - 1).re ≤ Complex.normSq (s - 1) := by
      rw [hnsq]; linarith [mul_self_nonneg (s - 1).im]
    rw [hs1_re] at this
    nlinarith [norm_nonneg (s - 1)]
  have hs_ne : s ≠ 0 := by
    intro h; have h_norm : ‖s‖ = 0 := by rw [h, norm_zero]
    linarith
  have hs1_ne : s - 1 ≠ 0 := by
    intro h; have h_norm : ‖s - 1‖ = 0 := by rw [h, norm_zero]
    linarith
  -- Triangle inequality
  calc ‖1 / s - ∑ i : Fin (N - 1), (↑(v i) : ℂ) / ((↑(↑i.val + 1 : ℕ) : ℂ) * (s - 1))‖
      ≤ ‖(1 : ℂ) / s‖ + ‖∑ i, (↑(v i) : ℂ) / ((↑(↑i.val + 1 : ℕ) : ℂ) * (s - 1))‖ :=
        norm_sub_le _ _
    _ ≤ 2 + ∑ i, ‖(↑(v i) : ℂ) / ((↑(↑i.val + 1 : ℕ) : ℂ) * (s - 1))‖ := by
        gcongr
        · -- ‖1/s‖ ≤ 2
          rw [norm_div, norm_one]
          exact div_le_of_le_mul₀ (norm_nonneg _) (by norm_num) (by linarith)
        · exact norm_sum_le _ _
    _ ≤ 2 + ∑ i, 2 * (|v i| / (↑(i.val + 1) : ℝ)) := by
        gcongr with i
        rw [norm_div, norm_mul, Complex.norm_natCast, Complex.norm_real, Real.norm_eq_abs]
        have hk_pos : (0:ℝ) < (↑(i.val + 1) : ℝ) := Nat.cast_pos.mpr (by omega)
        -- Goal: |v i| / (↑(i+1) * ‖s-1‖) ≤ 2 * (|v i| / ↑(i+1))
        have hs1_pos : (0:ℝ) < ‖s - 1‖ := by linarith
        -- Rewrite: a/(b*c) = (a/b)/c, and (a/b)/c ≤ (a/b)*2 iff 1/c ≤ 2 iff c ≥ 1/2
        rw [div_mul_eq_div_div]
        -- Goal: |v i| / (↑(i+1) * ‖s-1‖) ≤ 2 * (|v i| / ↑(i+1))
        have ha_nn : 0 ≤ |v i| / ↑(i.val + 1) := div_nonneg (abs_nonneg _) (by positivity)
        have h1 : |v i| / ↑(i.val + 1) / ‖s - 1‖ ≤ |v i| / ↑(i.val + 1) / (1/2) :=
          div_le_div_of_nonneg_left ha_nn (by linarith : (0:ℝ) < 1/2) hs1_lb
        have h2 : |v i| / ↑(i.val + 1) / (1/2) = 2 * (|v i| / ↑(i.val + 1)) := by ring
        linarith
    _ = 2 + 2 * ∑ i : Fin (N - 1), |v i| / (↑(i.val + 1) : ℝ) := by
        congr 1; rw [Finset.mul_sum]

-- ════════════════════════════════════════════════
-- §5. AUDIT
-- ════════════════════════════════════════════════

/-!
## Audit — ParsevalFactored (Phase 1)

### Theorems: 4
  1. `mellin_factored_on_critical_line` — PROVED ✅
     M_{r_N}(½+it) = R_N(½+it) + (ζ/(½+it))·D_N(½+it)
  2. `parseval_factored` — PROVED ✅
     ∫₀¹|r_N|² = (1/2π)∫‖R + (ζ/s)·D‖²
  3. `bd_dirichlet_as_exp_sum` — PROVED ✅
     D_N on critical line = standard exponential sum
  4. `rational_part_bounded` — PROVED ✅
     |R_N(½+it)| bounded on critical line

### Sorry: 0 🏛️ (trivial bound |s-1| ≥ ½ for s = ½+it — PROVED)

### Dependencies (ALL PROVED):
  - parseval_bridge_white (White/Scattering.lean)
  - mellin_residual_poly_form (Assembly/MellinResidualExpansion.lean)
-/

end Cathedral.MomentMethod
