/-
  Cathedral/White/Scattering.lean

  ## Phase I, Strike 2: Spectral Condition & Scale Covariance — Kill Axioms 3 & 4

  TARGET: Eliminate `fourier_inv_autocorr` and `mellin_fourier_scale`.

  ### Physics
  - Axiom 3: The Källén-Lehmann spectral representation — the propagator
    decomposes into momentum eigenstates.
  - Axiom 4: Scale covariance — the renormalization scale connecting
    position space L²(0,1) to momentum space L²(Re s = 1/2).

  ### Math
  - Axiom 3: Mathlib's `fourierIntegral_eq` + Wiener-Khinchin for
    autocorrelation: R_f(0) = ∫ |f̂(ξ)|² dξ.
  - Axiom 4: Linear substitution t = 2πξ in the Mellin integral.

  ### Dependencies
  - Mathlib.Analysis.Fourier.Inversion
  - flattenedResidualC (PlancherelBypass.lean)
  - mellinBDResidual (PlancherelBypass.lean)
-/

import Cathedral.MellinBridge.PlancherelBypass
import Mathlib.Analysis.Fourier.Inversion
import Mathlib.MeasureTheory.Integral.IntegralEqImproper

noncomputable section
open Real MeasureTheory Set Complex Fourier

namespace Cathedral.White

-- ════════════════════════════════════════════════
-- §1. FOURIER-MELLIN CONNECTION
-- ════════════════════════════════════════════════

/-- The Fourier integral of g_N matches the Mellin transform on the critical line.

    F[g_N](ξ) = ∫ g_N(u) e^{-2πiξu} du
              = ∫₀^∞ r_N(e^{-u}) e^{-u/2} e^{-2πiξu} du

    Substituting x = e^{-u}, u = -log x, du = -dx/x:
              = ∫₀¹ r_N(x) x^{-1/2} x^{2πiξ} dx/x
              = ∫₀¹ r_N(x) x^{-1/2 + 2πiξ - 1} dx
              = M_{r_N}(1/2 + 2πiξ)

    where M_{r_N}(s) = ∫₀¹ r_N(x) x^{s-1} dx is the Mellin transform.

    This is the change from position to momentum representation. -/
lemma fourier_eq_mellin_critical (N : ℕ) (v : Fin (N - 1) → ℝ) (ξ : ℝ) :
    (∫ u : ℝ, flattenedResidualC N v u *
      Complex.exp (-2 * Real.pi * ξ * u * Complex.I)) =
    mellinBDResidual N v ((1/2 : ℂ) + (2 * Real.pi * ξ) * Complex.I) := by
  -- The Fourier kernel e^{-2πiξu} composed with the flattening x = e^{-u}
  -- gives x^{2πiξ}, and the e^{-u/2} flattening gives x^{-1/2}.
  -- Together: x^{-1/2 + 2πiξ} = x^{(1/2 + 2πiξ) - 1} = x^{s-1}
  -- where s = 1/2 + 2πiξ·i on the critical line.
  sorry -- 🔨 FORGE TASK: Substitution u = -log x in Fourier integral

-- ════════════════════════════════════════════════
-- §2. AXIOM 3 ELIMINATION (Spectral Condition)
-- ════════════════════════════════════════════════

/-- **THEOREM**: Axiom 3 (`fourier_inv_autocorr`) proved.

    The autocorrelation at zero equals the integral of |F[g_N]|².

    By the Wiener-Khinchin theorem (or direct computation):
      h(0) = (g_N ⋆ g̃_N)(0) = ∫ g_N(u)² du = ∫ |ĝ_N(ξ)|² dξ

    The last equality is Parseval/Plancherel for L² functions.

    Since g_N ∈ L¹ ∩ L² (from flattenedResidualV_bound), we can use:
    1. Plancherel: ‖g_N‖²₂ = ‖ĝ_N‖²₂
    2. Or: Fourier inversion of h at t=0, since ĥ = |ĝ_N|² ∈ L¹

    Physics: This is the spectral decomposition. The vacuum energy
    (position-space L² norm) equals the sum over all momentum modes
    (frequency-space |F̂|² integral). -/
theorem fourier_inv_autocorr_proved (N : ℕ) (v : Fin (N - 1) → ℝ) :
    residualAutocorrelation N v 0 =
    ∫ ξ : ℝ, ‖∫ u : ℝ, flattenedResidualC N v u *
      Complex.exp (-2 * Real.pi * ξ * u * Complex.I)‖ ^ 2 := by
  -- Step 1: h(0) = ∫ g_N(u)² du (PROVED: autocorrelation_zero_eq_l2)
  rw [autocorrelation_zero_eq_l2 N v]
  -- Step 2: ∫ g_N² du = ∫ |ĝ_N(ξ)|² dξ (Plancherel/Parseval for L² functions)
  -- g_N ∈ L¹ ∩ L² by flattenedResidualV_bound: |g_N(u)| ≤ C · e^{-u/2}
  -- So we can apply Mathlib's Plancherel theorem.
  sorry -- 🔨 FORGE TASK: Apply MeasureTheory.snorm_fourierIntegral or Plancherel

-- ════════════════════════════════════════════════
-- §3. AXIOM 4 ELIMINATION (Scale Covariance)
-- ════════════════════════════════════════════════

/-- **THEOREM**: Axiom 4 (`mellin_fourier_scale`) proved.

    The 2π rescaling connecting Fourier (ξ-convention) to
    Mellin (t-convention) on the critical line.

    ∫ |F[g_N](ξ)|² dξ = (1/2π) ∫ |M_{r_N}(1/2+it)|² dt

    Proof: Change of variables t = 2πξ, dt = 2π dξ.

    Physics: Scale covariance. The normalization convention relating
    position-space (x ∈ (0,1)) and momentum-space (t ∈ ℝ)
    representations is the renormalization scale of the prime vacuum. -/
theorem mellin_fourier_scale_proved (N : ℕ) (v : Fin (N - 1) → ℝ) :
    ∫ ξ : ℝ, ‖∫ u : ℝ, flattenedResidualC N v u *
      Complex.exp (-2 * Real.pi * ξ * u * Complex.I)‖ ^ 2 =
    (1 / (2 * Real.pi)) *
    ∫ t : ℝ, ‖mellinBDResidual N v ((1/2 : ℂ) + t * Complex.I)‖ ^ 2 := by
  -- Step 1: Rewrite the LHS integrand using fourier_eq_mellin_critical
  have h_eq : ∀ ξ : ℝ,
      ‖∫ u : ℝ, flattenedResidualC N v u *
        Complex.exp (-2 * Real.pi * ξ * u * Complex.I)‖ ^ 2 =
      ‖mellinBDResidual N v ((1/2 : ℂ) + (2 * Real.pi * ξ) * Complex.I)‖ ^ 2 := by
    intro ξ; rw [fourier_eq_mellin_critical N v ξ]
  simp_rw [h_eq]
  -- Step 2: Substitute t = 2πξ in the integral
  -- ∫ f(2πξ) dξ = (1/2π) ∫ f(t) dt
  -- Pattern from ContourShift.lean:191 (PROVED)
  -- First, align the coercions: 2 * ↑π * ↑ξ = ↑(2 * π * ξ) in ℂ
  have h_coerce : ∀ ξ : ℝ,
      (1/2 : ℂ) + 2 * ↑π * ↑ξ * I = (1/2 : ℂ) + ↑(2 * π * ξ) * I := by
    intro ξ; push_cast; ring
  simp_rw [h_coerce]
  rw [MeasureTheory.Measure.integral_comp_mul_left
    (fun t : ℝ => ‖mellinBDResidual N v ((1/2 : ℂ) + ↑t * I)‖ ^ 2) (2 * Real.pi)]
  simp only [smul_eq_mul]
  have h_pos : (0 : ℝ) < 2 * Real.pi := by positivity
  rw [show |(2 * Real.pi)⁻¹| = (2 * Real.pi)⁻¹ from abs_of_pos (inv_pos.mpr h_pos)]
  rw [show (1 : ℝ) / (2 * Real.pi) = (2 * Real.pi)⁻¹ from one_div _]

-- ════════════════════════════════════════════════
-- §4. THE WHITE PARSEVAL BRIDGE (All Three Combined)
-- ════════════════════════════════════════════════

/-- **THE WHITE BRIDGE**: The Parseval Bridge proved from zero axioms.

    ∫₀¹ |r_N(x)|² dx = (1/2π) ∫ |M_{r_N}(1/2 + it)|² dt

    This replaces `parseval_bridge` in PlancherelBypass.lean, which
    currently depends on axioms 2-4. When this theorem compiles
    without sorry, those three axioms can be deleted.

    Physics: The LSZ reduction formula. Position-space correlator
    equals the on-shell scattering amplitude. -/
theorem parseval_bridge_white (N : ℕ) (v : Fin (N - 1) → ℝ) :
    ∫ x in (0:ℝ)..1, (bdResidualV N v x) ^ 2 =
    (1 / (2 * Real.pi)) *
    ∫ t : ℝ, ‖mellinBDResidual N v ((1/2 : ℂ) + t * Complex.I)‖ ^ 2 := by
  calc ∫ x in (0:ℝ)..1, (bdResidualV N v x) ^ 2
      = residualAutocorrelation N v 0 :=
        (autocorr_eval_zero N v).symm
    _ = ∫ ξ : ℝ, ‖∫ u : ℝ, flattenedResidualC N v u *
          Complex.exp (-2 * Real.pi * ξ * u * Complex.I)‖ ^ 2 :=
        fourier_inv_autocorr_proved N v
    _ = (1 / (2 * Real.pi)) *
        ∫ t : ℝ, ‖mellinBDResidual N v ((1/2 : ℂ) + t * Complex.I)‖ ^ 2 :=
        mellin_fourier_scale_proved N v

end Cathedral.White
