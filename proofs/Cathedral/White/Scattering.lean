/-!
  # The Parseval Bridge: Fourier-Mellin Connection

  Establishes the Parseval/Plancherel identity connecting the L²(0,1) norm
  of the BD residual to the critical-line Mellin integral.

  ## Main Results

  * `fourier_eq_mellin_critical` : the Fourier transform of the flattened
    residual equals the Mellin transform on the critical line
  * `fourier_inv_autocorr_proved` : autocorrelation at zero = ∫|F[g_N]|²
  * `mellin_fourier_scale_proved` : 2π rescaling between Fourier and Mellin
  * `parseval_bridge_white` : ∫₀¹|r_N|² = (1/2π)∫|M(1/2+it)|² dt

  ## Strategy

  1. Change of variables connecting Fourier and Mellin representations
  2. Plancherel theorem (via Mathlib's `fourierTransformĺi`)
  3. Linear substitution t = 2πξ
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

/-- The Fourier integral of `g_N` matches the Mellin transform on the critical line.

    `F[g_N](ξ) = M_{r_N}(1/2 + 2πiξ)`

    where `M_{r_N}(s) = ∫₀¹ r_N(x) x^{s-1} dx` is the Mellin transform.
    Proof: change of variables `x = e^{-u}` in the Fourier integral. -/
lemma fourier_eq_mellin_critical (N : ℕ) (v : Fin (N - 1) → ℝ) (ξ : ℝ) :
    (∫ u : ℝ, flattenedResidualC N v u *
      Complex.exp (-2 * Real.pi * ξ * u * Complex.I)) =
    mellinBDResidual N v ((1/2 : ℂ) + (2 * Real.pi * ξ) * Complex.I) := by
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
  -- Step 3: Apply the antitone CoV (4.28 API)
  have h_cov := MeasureTheory.integral_image_eq_integral_deriv_smul_of_antitoneOn
    measurableSet_Ioi
    (fun u hu => hasDerivWithinAt_exp_neg u hu)
    exp_neg_antitoneOn gM
  rw [exp_neg_image_Ioi] at h_cov
  -- h_cov : ∫_{Ioo(0,1)} gM = ∫_{Ioi(0)} (-(-exp(-u))) • gM(exp(-u))
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
  have hx_pos : (0 : ℝ) < rexp (-u) := exp_pos _
  have hx_ne : (rexp (-u) : ℂ) ≠ 0 := Complex.ofReal_ne_zero.mpr (ne_of_gt hx_pos)
  -- Prove the exponential identity:
  -- ↑(rexp(-u/2)) * cexp(-2πξuI) = ↑(rexp(-u))^s
  have h_exp_id : (rexp (-u / 2) : ℂ) * Complex.exp (-2 * ↑Real.pi * ↑ξ * ↑u * Complex.I) =
      (rexp (-u) : ℂ) ^ s := by
    rw [Complex.cpow_def_of_ne_zero hx_ne]
    have h_log : Complex.log (↑(rexp (-u))) = ↑(-u) := by
      rw [← Complex.ofReal_log (le_of_lt hx_pos), Real.log_exp]
    rw [h_log]
    have h_prod : ↑(-u) * s = ↑(-u / 2) + (-2 * ↑Real.pi * ↑ξ * ↑u) * Complex.I := by
      simp only [hs_def]; push_cast; ring
    rw [h_prod, Complex.exp_add, Complex.ofReal_exp]
  rw [Complex.ofReal_mul, mul_assoc, h_exp_id]
  change _ = (rexp (-u) : ℂ) * (↑(bdResidualV N v (rexp (-u))) * ↑(rexp (-u)) ^ (s - 1))
  rw [mul_left_comm]
  congr 1
  rw [Complex.cpow_def_of_ne_zero hx_ne, Complex.cpow_def_of_ne_zero hx_ne]
  have h_log : Complex.log (↑(rexp (-u))) = ↑(-u) := by
    rw [← Complex.ofReal_log (le_of_lt hx_pos), Real.log_exp]
  rw [h_log]
  rw [show ↑(-u) * s = ↑(-u) * (s - 1) + ↑(-u) from by ring]
  rw [Complex.exp_add, mul_comm, Complex.ofReal_exp]

-- ════════════════════════════════════════════════
-- §2. AXIOM 3 ELIMINATION (Spectral Condition)
-- ════════════════════════════════════════════════

/-- The autocorrelation at zero equals the integral of `|F[g_N]|²`.

    `h(0) = ∫ |g_N(u)|² du = ∫ |ĝ_N(ξ)|² dξ`

    The last equality is Plancherel's theorem for L² functions.
    Since `g_N ∈ L¹ ∩ L²` (from `flattenedResidualV_bound`), we apply
    `plancherel_integral_axiom` (proved via Mathlib's `fourierTransformĺi`). -/

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

/-- The 2π rescaling connecting Fourier (ξ-convention) to
    Mellin (t-convention) on the critical line.

    `∫ |F[g_N](ξ)|² dξ = (1/2π) ∫ |M_{r_N}(1/2+it)|² dt`

    Proof: change of variables `t = 2πξ`, `dt = 2π dξ`. -/
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

/-- **The Parseval Bridge**: `∫₀¹ |r_N(x)|² dx = (1/2π) ∫ |M_{r_N}(1/2 + it)|² dt`.

    Connects the L²(0,1) norm of the BD residual to the critical-line
    Mellin integral via Plancherel's theorem and a change of variables. -/
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
