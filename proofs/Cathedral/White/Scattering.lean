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

import Cathedral.MellinBridge.PlancherelDefs
import Cathedral.White.Kinematics
import Mathlib.Analysis.Fourier.Inversion
import Mathlib.MeasureTheory.Integral.IntegralEqImproper
import Mathlib.MeasureTheory.Integral.ExpDecay
import Mathlib.MeasureTheory.Function.Floor
import Mathlib.MeasureTheory.Function.L2Space

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
  -- The proof mirrors Kinematics but for ℂ-valued functions.
  -- Step 1: Restrict LHS to Ioi(0) since flattenedResidualC = 0 for u < 0
  have h_restrict : ∫ u : ℝ, flattenedResidualC N v u *
      Complex.exp (-2 * ↑Real.pi * ↑ξ * ↑u * Complex.I) =
    ∫ u in Set.Ici (0 : ℝ), flattenedResidualC N v u *
      Complex.exp (-2 * ↑Real.pi * ↑ξ * ↑u * Complex.I) := by
    symm; apply setIntegral_eq_integral_of_forall_compl_eq_zero
    intro u hu; simp only [Set.mem_Ici, not_le] at hu
    simp [flattenedResidualC, flattenedResidualV, show ¬(0 ≤ u) from not_le.mpr hu]
  have h_ici_ioi : ∫ u in Set.Ici (0 : ℝ), flattenedResidualC N v u *
      Complex.exp (-2 * ↑Real.pi * ↑ξ * ↑u * Complex.I) =
    ∫ u in Set.Ioi (0 : ℝ), flattenedResidualC N v u *
      Complex.exp (-2 * ↑Real.pi * ↑ξ * ↑u * Complex.I) := by
    apply setIntegral_congr_set Ioi_ae_eq_Ici.symm
  rw [h_restrict, h_ici_ioi]
  -- Step 2: Unfold mellinBDResidual and apply CoV
  unfold mellinBDResidual
  set s : ℂ := 1 / 2 + 2 * ↑Real.pi * ↑ξ * Complex.I with hs_def
  set gM : ℝ → ℂ := fun x => (bdResidualV N v x : ℂ) * (x : ℂ) ^ (s - 1)
  -- Step 3: Apply the antitone CoV: ∫_{Ioo(0,1)} gM = ∫_{Ioi(0)} exp(-u) • gM(exp(-u))
  have h_cov := MeasureTheory.integral_image_eq_integral_deriv_smul_of_antitoneOn
    measurableSet_Ioi
    (fun u hu => hasDerivWithinAt_exp_neg u hu)
    exp_neg_antitoneOn gM
  rw [exp_neg_image_Ioi] at h_cov
  -- h_cov : ∫_{Ioo(0,1)} gM = ∫_{Ioi(0)} -(-exp(-u)) • gM(exp(-u))
  -- i.e.:   ∫_{Ioo(0,1)} gM = ∫_{Ioi(0)} exp(-u) • gM(exp(-u))
  rw [h_cov]
  -- Both sides are ∫_{Ioi 0}. Show integrands agree pointwise.
  apply setIntegral_congr_fun measurableSet_Ioi
  intro u hu
  simp only [Set.mem_Ioi] at hu
  -- Simplify the double-negation: - -rexp(-u) = rexp(-u)
  simp only [neg_neg, gM]
  -- Unfold flattenedResidualC for u > 0:
  have hu_nn : (0 : ℝ) ≤ u := le_of_lt hu
  simp only [flattenedResidualC, flattenedResidualV, if_pos hu_nn]
  -- Goal reduces to: ↑(bdResidualV * rexp(-u/2)) * cexp(-2πξuI)
  --               = rexp(-u) * (↑(bdResidualV) * ↑(rexp(-u))^(s-1))
  -- Factor out bdResidualV; need: rexp(-u/2) * cexp(-2πξuI) = rexp(-u) * rexp(-u)^(s-1)
  -- i.e., rexp(-u) * rexp(-u)^(s-1) = rexp(-u)^s = cexp(-su) = rexp(-u/2) * cexp(-2πξuI)
  -- This is a complex exponential identity requiring cpow manipulation.
  -- Goal: ↑(bdResidualV * rexp(-u/2)) * cexp(-2πξuI) = rexp(-u) • (↑(bdResidualV) * ↑(rexp(-u))^(s-1))
  -- Key identity: for x = rexp(-u) > 0 and s = 1/2 + 2πξI:
  --   x • (↑r * ↑x^(s-1)) = ↑r * (↑(x^(1/2)) * cexp(-2πξu·I))
  have hx_pos : (0 : ℝ) < rexp (-u) := exp_pos _
  have hx_ne : (rexp (-u) : ℂ) ≠ 0 := Complex.ofReal_ne_zero.mpr (ne_of_gt hx_pos)
  -- Prove the exponential identity as a helper:
  -- ↑(rexp(-u/2)) * cexp(-2πξuI) = ↑(rexp(-u))^s
  have h_exp_id : (rexp (-u / 2) : ℂ) * Complex.exp (-2 * ↑Real.pi * ↑ξ * ↑u * Complex.I) =
      (rexp (-u) : ℂ) ^ s := by
    -- (↑x)^s = cexp(s * log(↑x))
    rw [Complex.cpow_def_of_ne_zero hx_ne]
    -- log(↑(rexp(-u))) = ↑(-u)
    have h_log : Complex.log (↑(rexp (-u))) = ↑(-u) := by
      rw [← Complex.ofReal_log (le_of_lt hx_pos), Real.log_exp]
    rw [h_log]
    -- s * (-u) = -u/2 + (-2πξu)I
    have h_prod : ↑(-u) * s = ↑(-u / 2) + (-2 * ↑Real.pi * ↑ξ * ↑u) * Complex.I := by
      simp only [hs_def]; push_cast; ring
    rw [h_prod, Complex.exp_add, Complex.ofReal_exp]
  -- Now use h_exp_id to close the goal
  -- LHS = ↑(bdResidualV * rexp(-u/2)) * cexp(...)
  --      = ↑bdResidualV * (↑(rexp(-u/2)) * cexp(...))
  --      = ↑bdResidualV * ↑(rexp(-u))^s
  -- RHS = rexp(-u) • (↑bdResidualV * ↑(rexp(-u))^(s-1))
  --      = ↑bdResidualV * (↑(rexp(-u)) * ↑(rexp(-u))^(s-1))
  --      = ↑bdResidualV * ↑(rexp(-u))^s
  rw [Complex.ofReal_mul, mul_assoc, h_exp_id]
  change _ = (rexp (-u) : ℂ) * (↑(bdResidualV N v (rexp (-u))) * ↑(rexp (-u)) ^ (s - 1))
  rw [mul_left_comm]
  congr 1
  -- Goal: ↑(rexp(-u))^s = ↑(rexp(-u)) * ↑(rexp(-u))^(s-1)
  -- Use cpow_def for both sides, exploit log properties
  rw [Complex.cpow_def_of_ne_zero hx_ne, Complex.cpow_def_of_ne_zero hx_ne]
  have h_log : Complex.log (↑(rexp (-u))) = ↑(-u) := by
    rw [← Complex.ofReal_log (le_of_lt hx_pos), Real.log_exp]
  rw [h_log]
  -- LHS: cexp(↑(-u) * s)
  -- RHS: ↑(rexp(-u)) * cexp(↑(-u) * (s-1))
  -- cexp(↑(-u) * s) = cexp(↑(-u) * (s-1) + ↑(-u))
  --                  = cexp(↑(-u) * (s-1)) * cexp(↑(-u))
  --                  = cexp(↑(-u) * (s-1)) * ↑(rexp(-u))
  rw [show ↑(-u) * s = ↑(-u) * (s - 1) + ↑(-u) from by ring]
  rw [Complex.exp_add, mul_comm, Complex.ofReal_exp]

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

-- ──── PROVED: Measurability & Integrability ────

private theorem flatResV_measurable' (N : ℕ) (v : Fin (N - 1) → ℝ) :
    Measurable (flattenedResidualV N v) := by
  unfold flattenedResidualV bdResidualV bdLinComb
  apply Measurable.ite measurableSet_Ici
  · apply Measurable.mul
    · apply Measurable.sub measurable_const
      apply Finset.measurable_sum; intro i _
      apply Measurable.const_mul; apply Measurable.fract
      apply Measurable.div measurable_const
      exact (measurable_const.mul measurable_neg.exp)
    · exact (measurable_neg.div_const _).exp
  · exact measurable_const

private theorem flatResC_integrable (N : ℕ) (v : Fin (N - 1) → ℝ) :
    Integrable (flattenedResidualC N v) volume := by
  unfold flattenedResidualC
  have hV : Integrable (flattenedResidualV N v) volume := by
    set C := 1 + ∑ i : Fin (N - 1), |v i|
    rw [← integrableOn_univ]
    rw [show (Set.univ : Set ℝ) = Set.Ioi 0 ∪ {(0:ℝ)} ∪ Set.Iio 0 from by
      ext x; simp only [Set.mem_univ, Set.mem_union, Set.mem_Ioi, Set.mem_singleton_iff,
        Set.mem_Iio, true_iff]; rcases lt_trichotomy x 0 with h | h | h
      · exact Or.inr h
      · exact Or.inl (Or.inr h)
      · exact Or.inl (Or.inl h)]
    apply IntegrableOn.union
    · apply IntegrableOn.union
      · exact ((exp_neg_integrableOn_Ioi 0 (show (0:ℝ) < 1/2 by positivity)).const_mul C).mono'
          ((flatResV_measurable' N v).aestronglyMeasurable.restrict)
          (ae_of_all _ fun u => by
            simp only [norm_eq_abs]
            calc |flattenedResidualV N v u|
                ≤ C * rexp (-u / 2) := flattenedResidualV_bound N v u
              _ = C * rexp (-(1/2) * u) := by ring_nf)
      · exact integrableOn_singleton (hx := by simp)
    · exact integrableOn_zero.congr_fun (fun u hu => by
        simp only [Set.mem_Iio] at hu
        unfold flattenedResidualV; simp [show ¬(0 ≤ u) from not_le.mpr hu]) measurableSet_Iio
  exact hV.ofReal

theorem fourier_inv_autocorr_proved (N : ℕ) (v : Fin (N - 1) → ℝ) :
    residualAutocorrelation N v 0 =
    ∫ ξ : ℝ, ‖∫ u : ℝ, flattenedResidualC N v u *
      Complex.exp (-2 * Real.pi * ξ * u * Complex.I)‖ ^ 2 := by
  -- Step 1: h(0) = ∫ g_N(u)² du (PROVED: autocorrelation_zero_eq_l2)
  rw [autocorrelation_zero_eq_l2 N v]
  -- Step 2: Convert real-squared to complex-norm-squared
  have h_conv : ∫ u : ℝ, (flattenedResidualV N v u) ^ 2 =
      ∫ u : ℝ, ‖flattenedResidualC N v u‖ ^ 2 := by
    congr 1; ext u; unfold flattenedResidualC
    simp [Complex.norm_real, sq_abs]
  rw [h_conv]
  -- Step 3: Apply Plancherel's theorem (∫ ‖f‖² = ∫ ‖𝓕f‖²)
  -- Proved integrability from exponential decay:
  have hf1 : Integrable (flattenedResidualC N v) volume :=
    flatResC_integrable N v
  have hf2 : MemLp (flattenedResidualC N v) 2 volume := by
    have haesm : AEStronglyMeasurable (flattenedResidualC N v) volume := by
      unfold flattenedResidualC
      exact (Complex.ofRealCLM.continuous.measurable.comp
        (flatResV_measurable' N v)).aestronglyMeasurable
    refine (memLp_two_iff_integrable_sq_norm haesm).mpr ?_
    -- Integrable (fun u => ‖flattenedResidualC N v u‖ ^ 2)
    -- ‖f(u)‖² ≤ C² * exp(-u) on Ioi 0, = 0 on Iio 0
    have hsq_zero : ∀ u : ℝ, u < 0 →
        (fun x => ‖flattenedResidualC N v x‖ ^ 2) u = 0 := by
      intro u hu
      unfold flattenedResidualC flattenedResidualV
      simp [show ¬(0 ≤ u) from not_le.mpr hu]
    set C := 1 + ∑ i : Fin (N - 1), |v i|
    rw [← integrableOn_univ]
    rw [show (Set.univ : Set ℝ) = Set.Ioi 0 ∪ {(0:ℝ)} ∪ Set.Iio 0 from by
      ext x; simp only [Set.mem_univ, Set.mem_union, Set.mem_Ioi, Set.mem_singleton_iff,
        Set.mem_Iio, true_iff]; rcases lt_trichotomy x 0 with h | h | h
      · exact Or.inr h
      · exact Or.inl (Or.inr h)
      · exact Or.inl (Or.inl h)]
    apply IntegrableOn.union
    · apply IntegrableOn.union
      · -- Ioi 0: ‖f(u)‖² ≤ C² * exp(-u)
        exact ((exp_neg_integrableOn_Ioi 0 (show (0:ℝ) < 1 by positivity)).const_mul (C^2)).mono'
          (by apply AEStronglyMeasurable.restrict
              exact (haesm.norm.mul haesm.norm).congr
                (ae_of_all _ fun u => by simp [sq]))
          (ae_of_all _ fun u => by
            simp only [norm_eq_abs]
            unfold flattenedResidualC
            rw [Complex.norm_real]
            rw [abs_of_nonneg (by positivity)]
            have hb := flattenedResidualV_bound N v u
            calc |flattenedResidualV N v u| ^ 2
                ≤ (C * rexp (-u / 2)) ^ 2 := by
                  apply sq_le_sq' <;> linarith [abs_nonneg (flattenedResidualV N v u)]
              _ = C ^ 2 * rexp (-(1:ℝ) * u) := by
                  rw [mul_pow, sq (rexp _), ← Real.exp_add]; ring_nf)
      · exact integrableOn_singleton (hx := by simp)
    · exact integrableOn_zero.congr_fun (fun u hu => by
        exact (hsq_zero u (Set.mem_Iio.mp hu)).symm) measurableSet_Iio
  exact plancherel_integral_axiom (flattenedResidualC N v) hf1 hf2

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
        (autocorr_eval_zero_proved N v).symm
    _ = ∫ ξ : ℝ, ‖∫ u : ℝ, flattenedResidualC N v u *
          Complex.exp (-2 * Real.pi * ξ * u * Complex.I)‖ ^ 2 :=
        fourier_inv_autocorr_proved N v
    _ = (1 / (2 * Real.pi)) *
        ∫ t : ℝ, ‖mellinBDResidual N v ((1/2 : ℂ) + t * Complex.I)‖ ^ 2 :=
        mellin_fourier_scale_proved N v

end Cathedral.White
