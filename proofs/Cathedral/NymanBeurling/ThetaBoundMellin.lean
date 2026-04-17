/-
  ThetaBoundMellin.lean — The Final Cleaving
  Executing the Theorist's Directive: Annihilation of the Last Sorry
-/
import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.LSeries.HurwitzZetaEven
import Mathlib.NumberTheory.ModularForms.JacobiTheta.Bounds
import Mathlib.Analysis.Real.Pi.Bounds

noncomputable section
open Complex Real MeasureTheory Set HurwitzZeta Filter HurwitzKernelBounds

private abbrev P₀ := (hurwitzEvenFEPair (0 : UnitAddCircle))

-- ════════════════════════════════════════════════════
-- NUMERIC HELPERS
-- ════════════════════════════════════════════════════

private lemma exp_neg_pi_lt_half : rexp (-π) < 1 / 2 := by
  rw [Real.exp_neg]; exact inv_lt_of_inv_lt₀ (by positivity) (by linarith [pi_gt_three, add_one_le_exp π])

private lemma crude_geom (t : ℝ) (ht : 1 ≤ t) :
    rexp (-π * t) / (1 - rexp (-π * t)) ≤ 2 * rexp (-π * t) := by
  have h_exp : rexp (-π * t) < 1 / 2 :=
    lt_of_le_of_lt (exp_le_exp.mpr (by nlinarith [pi_pos])) exp_neg_pi_lt_half
  rw [div_le_iff₀ (by linarith)]; nlinarith [exp_pos (-π * t)]

-- ════════════════════════════════════════════════════
-- EVENKERNEL BOUND (from previous session)
-- ════════════════════════════════════════════════════

private lemma evenKernel_eq_F_int {t : ℝ} (ht : 0 < t) :
    evenKernel (0 : UnitAddCircle) t = F_int 0 ((0 : ℝ) : UnitAddCircle) t := by
  have h1 := (hasSum_int_evenKernel (0 : ℝ) ht).tsum_eq
  simp only [add_zero] at h1; rw [QuotientAddGroup.mk_zero] at h1
  suffices F_int 0 ((0 : ℝ) : UnitAddCircle) t = ∑' (b : ℤ), rexp (-π * ↑b ^ 2 * t) by linarith
  simp only [F_int, Function.Periodic.lift_coe, f_int, add_zero, pow_zero, one_mul]

private lemma evenKernel_zero_sub_one_le {t : ℝ} (ht : 1 ≤ t) :
    ‖evenKernel (0 : UnitAddCircle) t - 1‖ ≤ 4 * rexp (-π * t) := by
  have ht_pos := lt_of_lt_of_le one_pos ht
  have hFint := F_int_eq_of_mem_Icc 0 ⟨le_refl _, zero_le_one⟩ ht_pos
  simp only [sub_zero] at hFint
  rw [evenKernel_eq_F_int ht_pos, hFint,
    show F_nat 0 0 t + F_nat 0 1 t - 1 = (F_nat 0 0 t - 1) + F_nat 0 1 t from by ring]
  calc ‖(F_nat 0 0 t - 1) + F_nat 0 1 t‖
      ≤ ‖F_nat 0 0 t - 1‖ + ‖F_nat 0 1 t‖ := norm_add_le _ _
    _ ≤ rexp (-π * t) / (1 - rexp (-π * t)) +
        rexp (-π * t) / (1 - rexp (-π * t)) := by
        gcongr
        · exact F_nat_zero_zero_sub_le ht_pos
        · have := F_nat_zero_le (show (0 : ℝ) ≤ 1 from zero_le_one) ht_pos
          simp only [one_pow, mul_one] at this; exact this
    _ = 2 * (rexp (-π * t) / (1 - rexp (-π * t))) := by ring
    _ ≤ 2 * (2 * rexp (-π * t)) := by gcongr; exact crude_geom t ht
    _ = 4 * rexp (-π * t) := by ring

-- ════════════════════════════════════════════════════
-- PHASE 1: The Algebraic Squeeze (Theorist's Gambit)
-- u^{3/2} * exp(-πu) ≤ exp(-π) for u ≥ 1
-- ════════════════════════════════════════════════════

private lemma u_pow_exp_bound (u : ℝ) (hu : 1 ≤ u) :
    u ^ (3 / 2 : ℝ) * rexp (-π * u) ≤ rexp (-π) := by
  have hu_pos : 0 < u := by linarith
  have h_log : Real.log u ≤ u - 1 := Real.log_le_sub_one_of_pos hu_pos
  have h_pi_bound : (3 / 2 : ℝ) ≤ π := by linarith [Real.pi_gt_three]
  have h_mul_log : (3 / 2 : ℝ) * Real.log u ≤ π * (u - 1) := by
    calc (3 / 2 : ℝ) * Real.log u
      _ ≤ (3 / 2 : ℝ) * (u - 1) := mul_le_mul_of_nonneg_left h_log (by norm_num)
      _ ≤ π * (u - 1) := mul_le_mul_of_nonneg_right h_pi_bound (by linarith)
  have h_exp : rexp ((3 / 2 : ℝ) * Real.log u) ≤ rexp (π * (u - 1)) :=
    Real.exp_le_exp.mpr h_mul_log
  have h_u_pow : u ^ (3 / 2 : ℝ) = rexp ((3 / 2 : ℝ) * Real.log u) := by
    rw [Real.rpow_def_of_pos hu_pos]; ring_nf
  rw [h_u_pow]
  calc rexp ((3 / 2 : ℝ) * Real.log u) * rexp (-π * u)
    _ ≤ rexp (π * (u - 1)) * rexp (-π * u) := mul_le_mul_of_nonneg_right h_exp (exp_pos _).le
    _ = rexp (π * u - π - π * u) := by rw [← Real.exp_add]; congr 1; ring
    _ = rexp (-π) := by congr 1; ring

-- ════════════════════════════════════════════════════
-- PHASE 2: The Symmetry Key
-- evenKernel(0, t) = cosKernel(0, t)
-- ════════════════════════════════════════════════════

private lemma evenKernel_eq_cosKernel (t : ℝ) :
    evenKernel (0 : UnitAddCircle) t = cosKernel (0 : UnitAddCircle) t := by
  have h_symm := hurwitzEvenFEPair_zero_symm
  have h_fg : P₀.f = P₀.g := by
    calc P₀.f = P₀.symm.g := rfl
      _ = P₀.g := congr_arg WeakFEPair.g h_symm
  have h_eval := congr_fun h_fg t
  exact Complex.ofReal_inj.mp h_eval

-- ════════════════════════════════════════════════════
-- PHASE 2.5: f_modif_norm on Ioo(0,1) — the inner sorry
-- ════════════════════════════════════════════════════

-- The key fact:
-- evenKernel_functional_equation: evenKernel a x = 1/x^{1/2} * cosKernel a (1/x)
-- Combined with evenKernel_eq_cosKernel:
-- evenKernel 0 x = x^{-1/2} * evenKernel 0 (1/x)

-- f_modif on Ioo(0,1):
-- = P₀.f t - (P₀.ε * ↑(t^{-P₀.k})) • P₀.g₀
-- = ofReal(ek(t)) - (1 * ↑(t^{-1/2})) • 1
-- = ofReal(ek(t)) - ofReal(t^{-1/2})  [since 1•1 = 1 and casting t^{-1/2}]

-- Hmm wait, ↑(t^{-1/2}) • 1 is (t^{-1/2} : ℂ) • (1 : ℂ) = (t^{-1/2} : ℂ)
-- Actually P₀.ε = (1 : ℂ). And t^{-P₀.k} = t^{-1/2} as a real.
-- And ε * ↑(t^{-k}) is (1 : ℂ) * ofReal(t^{-1/2}) = ofReal(t^{-1/2}) in ℂ.
-- And smearing by g₀ = (1 : ℂ): ofReal(t^{-1/2}) • 1 = ofReal(t^{-1/2}).

-- So f_modif(t) on Ioo(0,1) = ofReal(ek(t)) - ofReal(t^{-1/2})
-- = ofReal(ek(t) - t^{-1/2})

-- By FE: ek(t) = (1/t)^{1/2} * cosKernel(0, 1/t) = t^{-1/2} * ek(1/t) [using cosKernel=evenKernel]
-- So: ek(t) - t^{-1/2} = t^{-1/2} * (ek(1/t) - 1)

-- ‖f_modif(t)‖ = |ek(t) - t^{-1/2}| = t^{-1/2} * |ek(1/t) - 1|
-- ≤ t^{-1/2} * 4*exp(-π/t)  [by evenKernel_zero_sub_one_le at 1/t, since 1/t ≥ 1]

private lemma f_modif_norm_le_Ioo {t : ℝ} (ht0 : 0 < t) (ht1 : t < 1) :
    ‖P₀.f_modif t‖ ≤ t ^ (-(1:ℝ)/2) * (4 * rexp (-π * (1/t))) := by
  have h1 : t ∉ Ioi (1 : ℝ) := not_lt.mpr (le_of_lt ht1)
  have h2 : t ∈ Ioo (0 : ℝ) 1 := ⟨ht0, ht1⟩
  show ‖(Ioi 1).indicator (fun x ↦ P₀.f x - P₀.f₀) t +
       (Ioo 0 1).indicator (fun x ↦ P₀.f x - (P₀.ε * ↑(x ^ (-P₀.k))) • P₀.g₀) t‖ ≤ _
  rw [indicator_of_notMem h1, indicator_of_mem h2, zero_add]
  -- Goal: ‖P₀.f t - (P₀.ε * ↑(t^{-P₀.k})) • P₀.g₀‖ ≤ t^{-1/2} * (4 * exp(-π/t))
  -- Unfold: P₀.f t = ofReal(ek(t)), P₀.ε = 1, P₀.k = 1/2, P₀.g₀ = 1
  -- So: ‖ofReal(ek(t)) - ofReal(t^{-1/2})‖
  show ‖(↑(evenKernel (0 : UnitAddCircle) t) : ℂ) -
       ((1 : ℂ) * ↑(t ^ (-(1 / 2 : ℝ)))) • (1 : ℂ)‖ ≤ _
  simp only [one_mul, smul_eq_mul, mul_one]
  -- Goal: ‖↑(ek(t)) - ↑(t^{-1/2})‖ ≤ t^{-1/2} * (4 * exp(-π/t))
  rw [show (↑(evenKernel (0 : UnitAddCircle) t) : ℂ) - ↑(t ^ (-(1/2 : ℝ))) =
    (↑(evenKernel (0 : UnitAddCircle) t - t ^ (-(1/2 : ℝ))) : ℂ) from by push_cast; ring]
  rw [Complex.norm_real]
  -- Goal: ‖ek(t) - t^{-1/2}‖ ≤ t^{-1/2} * (4 * exp(-π/t))
  -- Use the functional equation: ek(t) = t^{-1/2} * cosKernel(0, 1/t)
  have h_fe := evenKernel_functional_equation (0 : UnitAddCircle) t
  -- h_fe: ek(t) = 1/t^{1/2} * cosKernel(0, 1/t)
  -- And cosKernel(0, ·) = evenKernel(0, ·):
  rw [← evenKernel_eq_cosKernel (1/t)] at h_fe
  -- h_fe: ek(t) = 1/t^{1/2} * ek(1/t)
  -- 1/t^{1/2} = t^{-1/2}:
  have h_rpow : (1 : ℝ) / t ^ (1/2 : ℝ) = t ^ (-(1/2 : ℝ)) := by
    rw [Real.rpow_neg ht0.le, one_div]
  rw [h_rpow] at h_fe
  -- h_fe: ek(t) = t^{-1/2} * ek(1/t)
  -- So: ek(t) - t^{-1/2} = t^{-1/2} * (ek(1/t) - 1)
  have h_diff : evenKernel (0 : UnitAddCircle) t - t ^ (-(1/2 : ℝ)) =
      t ^ (-(1/2 : ℝ)) * (evenKernel (0 : UnitAddCircle) (1/t) - 1) := by
    rw [h_fe]; ring
  rw [h_diff, norm_mul, Real.norm_rpow_of_nonneg ht0.le, Real.norm_of_nonneg ht0.le]
  -- Unify the exponent mismatch -(1/2) vs -1/2 via congr
  have h_exp_eq : (-(1 / 2 : ℝ)) = (-1 / 2 : ℝ) := by ring
  rw [h_exp_eq]
  gcongr
  exact evenKernel_zero_sub_one_le (le_div_iff₀ ht0 |>.mpr (by linarith))

end
