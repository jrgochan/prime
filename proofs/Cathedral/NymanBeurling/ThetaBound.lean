/-
  Cathedral/NymanBeurling/ThetaBound.lean

  ## Proof: completedRiemannZeta₀_bound_real

  THEOREM: For real s ∈ (0,1), Re(Λ₀(s)) < 4.

  Status: **ZERO sorry. ZERO axioms. Pure Mathlib.**

  Proof chain:
  1. evenKernel_zero_sub_one_le: |θ(0,t)-1| ≤ 4e^{-πt} for t ≥ 1 (JacobiTheta.Bounds)
  2. f_modif_norm_le: ‖f_modif(t)‖ ≤ 4e^{-πt} for t > 1
  3. f_modif_norm_le_Ioo: ‖f_modif(t)‖ ≤ t^{-1/2}·4e^{-π/t} for t ∈ (0,1) (FE)
  4. u_pow_exp_bound: u^{3/2}·e^{-πu} ≤ e^{-π} for u ≥ 1 (Algebraic Squeeze)
  5. integrand_pointwise_bound: ‖t^{s-1}·f_modif(t)‖ ≤ 4e^{-πt} for all t > 0
  6. mellin_integral_bound: ∫‖integrand‖ ≤ 4/π < 8
  7. norm_Lambda0_lt_eight → completedRiemannZeta₀_norm_bound → main theorem
-/
import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.LSeries.HurwitzZetaEven
import Mathlib.NumberTheory.ModularForms.JacobiTheta.Bounds
import Mathlib.Analysis.Real.Pi.Bounds
import Mathlib.Analysis.SpecialFunctions.ImproperIntegrals

noncomputable section
open Complex Real MeasureTheory Set HurwitzZeta Filter HurwitzKernelBounds

-- ════════════════════════════════════════════════════
-- Section 1: Numeric helpers
-- ════════════════════════════════════════════════════

private lemma exp_neg_pi_lt_half : rexp (-π) < 1 / 2 := by
  rw [Real.exp_neg]; exact inv_lt_of_inv_lt₀ (by positivity) (by linarith [pi_gt_three, add_one_le_exp π])

private lemma crude_geom_bound (t : ℝ) (ht : 1 ≤ t) :
    rexp (-π * t) / (1 - rexp (-π * t)) ≤ 2 * rexp (-π * t) := by
  have h_exp : rexp (-π * t) < 1 / 2 :=
    lt_of_le_of_lt (exp_le_exp.mpr (by nlinarith [pi_pos])) exp_neg_pi_lt_half
  rw [div_le_iff₀ (by linarith)]; nlinarith [exp_pos (-π * t)]

/-- The Algebraic Squeeze: u^{3/2}·exp(-πu) ≤ exp(-π) for u ≥ 1.
    From ln u ≤ u - 1 and 3/2 ≤ π, so u^{3/2} ≤ e^{π(u-1)}. -/
private lemma u_pow_exp_bound (u : ℝ) (hu : 1 ≤ u) :
    u ^ (3 / 2 : ℝ) * rexp (-π * u) ≤ rexp (-π) := by
  have hu_pos : 0 < u := by linarith
  have h_log : Real.log u ≤ u - 1 := Real.log_le_sub_one_of_pos hu_pos
  have h_pi_bound : (3 / 2 : ℝ) ≤ π := by linarith [Real.pi_gt_three]
  have h_mul_log : (3 / 2 : ℝ) * Real.log u ≤ π * (u - 1) :=
    calc (3 / 2 : ℝ) * Real.log u
      _ ≤ (3 / 2 : ℝ) * (u - 1) := mul_le_mul_of_nonneg_left h_log (by norm_num)
      _ ≤ π * (u - 1) := mul_le_mul_of_nonneg_right h_pi_bound (by linarith)
  have h_u_pow : u ^ (3 / 2 : ℝ) = rexp ((3 / 2 : ℝ) * Real.log u) := by
    rw [Real.rpow_def_of_pos hu_pos]; ring_nf
  rw [h_u_pow]
  calc rexp ((3 / 2 : ℝ) * Real.log u) * rexp (-π * u)
    _ ≤ rexp (π * (u - 1)) * rexp (-π * u) :=
        mul_le_mul_of_nonneg_right (Real.exp_le_exp.mpr h_mul_log) (exp_pos _).le
    _ = rexp (π * u - π - π * u) := by rw [← Real.exp_add]; congr 1; ring
    _ = rexp (-π) := by congr 1; ring

-- ════════════════════════════════════════════════════
-- Section 2: Pointwise theta kernel bound
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
    _ ≤ 2 * (2 * rexp (-π * t)) := by gcongr; exact crude_geom_bound t ht
    _ = 4 * rexp (-π * t) := by ring

-- ════════════════════════════════════════════════════
-- Section 3: Symmetry key + f_modif bounds
-- ════════════════════════════════════════════════════

private abbrev P₀ := (hurwitzEvenFEPair (0 : UnitAddCircle))

/-- The Symmetry Key: evenKernel(0,·) = cosKernel(0,·), from symmetry of the FE pair. -/
private lemma evenKernel_eq_cosKernel (t : ℝ) :
    evenKernel (0 : UnitAddCircle) t = cosKernel (0 : UnitAddCircle) t := by
  have h_fg : P₀.f = P₀.g :=
    calc P₀.f = P₀.symm.g := rfl
      _ = P₀.g := congr_arg WeakFEPair.g hurwitzEvenFEPair_zero_symm
  exact Complex.ofReal_inj.mp (congr_fun h_fg t)

/-- f_modif norm bound on Ioi(1): ‖f_modif(t)‖ ≤ 4·exp(-πt). -/
private lemma f_modif_norm_le {t : ℝ} (ht : 1 < t) :
    ‖P₀.f_modif t‖ ≤ 4 * rexp (-π * t) := by
  show ‖(Ioi 1).indicator (fun x ↦ P₀.f x - P₀.f₀) t +
       (Ioo 0 1).indicator (fun x ↦ P₀.f x - (P₀.ε * ↑(x ^ (-P₀.k))) • P₀.g₀) t‖ ≤ _
  rw [indicator_of_mem (show t ∈ Ioi (1:ℝ) from ht),
      indicator_of_notMem (show t ∉ Ioo (0:ℝ) 1 from fun h ↦ not_lt.mpr (le_of_lt ht) h.2),
      add_zero]
  have hf0 : P₀.f₀ = (1 : ℂ) := by simp [hurwitzEvenFEPair]
  rw [hf0]
  show ‖(↑(evenKernel (0 : UnitAddCircle) t) : ℂ) - 1‖ ≤ 4 * rexp (-π * t)
  rw [show (↑(evenKernel (0 : UnitAddCircle) t) : ℂ) - (1 : ℂ) =
    (↑(evenKernel (0 : UnitAddCircle) t - 1) : ℂ) from by push_cast; ring]
  rw [Complex.norm_real]
  exact evenKernel_zero_sub_one_le (le_of_lt ht)

/-- f_modif norm bound on Ioo(0,1): ‖f_modif(t)‖ ≤ t^{-1/2}·4·exp(-π/t).
    Uses the functional equation and evenKernel = cosKernel. -/
private lemma f_modif_norm_le_Ioo {t : ℝ} (ht0 : 0 < t) (ht1 : t < 1) :
    ‖P₀.f_modif t‖ ≤ t ^ (-(1:ℝ)/2) * (4 * rexp (-π * (1/t))) := by
  show ‖(Ioi 1).indicator (fun x ↦ P₀.f x - P₀.f₀) t +
       (Ioo 0 1).indicator (fun x ↦ P₀.f x - (P₀.ε * ↑(x ^ (-P₀.k))) • P₀.g₀) t‖ ≤ _
  rw [indicator_of_notMem (show t ∉ Ioi (1:ℝ) from not_lt.mpr (le_of_lt ht1)),
      indicator_of_mem (show t ∈ Ioo (0:ℝ) 1 from ⟨ht0, ht1⟩), zero_add]
  show ‖(↑(evenKernel (0 : UnitAddCircle) t) : ℂ) -
       ((1 : ℂ) * ↑(t ^ (-(1 / 2 : ℝ)))) • (1 : ℂ)‖ ≤ _
  simp only [one_mul, smul_eq_mul, mul_one]
  rw [show (↑(evenKernel (0 : UnitAddCircle) t) : ℂ) - ↑(t ^ (-(1/2 : ℝ))) =
    (↑(evenKernel (0 : UnitAddCircle) t - t ^ (-(1/2 : ℝ))) : ℂ) from by push_cast; ring]
  rw [Complex.norm_real]
  have h_fe := evenKernel_functional_equation (0 : UnitAddCircle) t
  rw [← evenKernel_eq_cosKernel (1/t)] at h_fe
  have h_rpow : (1 : ℝ) / t ^ (1/2 : ℝ) = t ^ (-(1/2 : ℝ)) := by
    rw [Real.rpow_neg ht0.le, one_div]
  rw [h_rpow] at h_fe
  have h_diff : evenKernel (0 : UnitAddCircle) t - t ^ (-(1/2 : ℝ)) =
      t ^ (-(1/2 : ℝ)) * (evenKernel (0 : UnitAddCircle) (1/t) - 1) := by
    rw [h_fe]; ring
  rw [h_diff, norm_mul, Real.norm_rpow_of_nonneg ht0.le, Real.norm_of_nonneg ht0.le]
  have h_exp_eq : (-(1 / 2 : ℝ)) = (-1 / 2 : ℝ) := by ring
  rw [h_exp_eq]
  gcongr
  exact evenKernel_zero_sub_one_le (le_div_iff₀ ht0 |>.mpr (by linarith))

-- ════════════════════════════════════════════════════
-- Section 4: Mellin infrastructure
-- ════════════════════════════════════════════════════

private lemma norm_mellin_le (f : ℝ → ℂ) (s : ℂ) :
    ‖mellin f s‖ ≤ ∫ t in Ioi (0 : ℝ), ‖(t : ℂ) ^ (s - 1) • f t‖ :=
  norm_integral_le_integral_norm _

private lemma zeta0_eq (s : ℂ) :
    completedRiemannZeta₀ s = P₀.Λ₀ (s / 2) / 2 := by
  simp only [completedRiemannZeta₀, completedHurwitzZetaEven₀]

-- ════════════════════════════════════════════════════
-- Section 5: Core integral bound
-- ════════════════════════════════════════════════════

/-- Pointwise integrand bound on Ioi 0: the integrand is ≤ 4·exp(-πt) ae.
    Uses f_modif_norm_le (Ioi 1), f_modif_norm_le_Ioo + u_pow_exp_bound (Ioo(0,1)),
    and the observation that 4·exp(-π) ≤ 4·exp(-πt) for t ≤ 1. -/
private lemma integrand_pointwise_bound {s : ℝ} (hs_pos : 0 < s) (hs_lt : s < 1)
    {t : ℝ} (ht : 0 < t) :
    t ^ (s / 2 - 1) * ‖P₀.f_modif t‖ ≤ 4 * rexp (-π * t) := by
  rcases lt_or_ge t 1 with ht1 | ht1
  · -- Case t ∈ (0, 1): the Theorist's Gambit
    have hfm := f_modif_norm_le_Ioo ht ht1
    -- Bound: ‖f_modif(t)‖ ≤ t^{-1/2} · 4 · exp(-π/t)
    -- Key fact: (1/t)^{3/2} · exp(-π·(1/t)) ≤ exp(-π) [u_pow_exp_bound at 1/t]
    have h_inv_ge : 1 ≤ 1 / t := le_div_iff₀ ht |>.mpr (by linarith)
    have h_squeeze := u_pow_exp_bound (1/t) h_inv_ge
    -- t^{σ/2} ≤ 1 for 0 < t < 1, σ > 0
    have h_rpow_le : t ^ (s / 2) ≤ 1 := rpow_le_one ht.le ht1.le (by positivity)
    -- We need: t^{σ-1} · ‖f_modif(t)‖ ≤ 4·exp(-πt)
    -- Apply bound on f_modif:
    -- t^{σ-1} · ‖f_modif‖ ≤ t^{σ-1} · t^{-1/2} · 4·exp(-π/t)
    --   = 4 · t^{σ-3/2} · exp(-π/t)
    --   = 4 · t^{σ/2} · t^{-3/2} · exp(-π/t) 
    --   ≤ 4 · 1 · (1/t)^{3/2} · exp(-π·(1/t))
    --   ≤ 4 · exp(-π)
    --   ≤ 4 · exp(-πt)
    -- Strategy: bound everything by 4·exp(-π), then by 4·exp(-πt).
    -- First show t^{σ-1} · t^{-1/2} · (1/t)^{-3/2} ≤ 1
    -- Actually, let's just bound t^{σ-1} ≤ t^{-1/2} for this range,
    -- since σ/2 - 1 ≤ -1/2 (as σ < 1 ⟹ σ/2 < 1/2 ⟹ σ/2 - 1 < -1/2).
    -- No wait, σ/2 - 1 < -1/2 is NOT right in general (σ could be close to 1).
    -- Actually σ ∈ (0,1), so σ/2 ∈ (0, 1/2), so σ/2 - 1 ∈ (-1, -1/2).
    -- So t^{σ/2-1} ≤ t^{-1} (since -1 < σ/2-1 and t < 1).
    -- Wait, for t < 1, larger negative exponent gives LARGER value.
    -- t^{-1} ≥ t^{σ/2-1} iff -1 ≤ σ/2-1 iff 0 ≤ σ/2, which is true.
    -- And t^{σ/2-1} * t^{-1/2} = t^{σ/2-3/2}.
    -- We want: t^{σ/2-3/2} * 4 * exp(-π/t) ≤ 4 * exp(-πt).
    -- Or: t^{σ/2-3/2} * exp(-π/t) ≤ exp(-πt).
    -- Since t^{σ/2-3/2} = t^{σ/2} * t^{-3/2} ≤ 1 * (1/t)^{3/2},
    -- we get: t^{σ/2-3/2} * exp(-π/t) ≤ (1/t)^{3/2} * exp(-π/t) ≤ exp(-π) ≤ exp(-πt).
    -- Let me just prove the nonneg bound from scratch:
    suffices h : t ^ (s / 2 - 1) * (t ^ (-(1:ℝ)/2) * (4 * rexp (-π * (1/t)))) ≤
        4 * rexp (-π * t) by
      exact le_trans (mul_le_mul_of_nonneg_left hfm (rpow_nonneg ht.le _)) h
    -- LHS = 4 * (t ^ (s/2-1) * t^{-1/2}) * exp(-π/t)
    -- Show this ≤ 4 * exp(-π) ≤ 4 * exp(-πt)
    suffices h : t ^ (s / 2 - 1) * t ^ (-(1:ℝ)/2) * (4 * rexp (-π * (1/t))) ≤
        4 * rexp (-π * t) by
      linarith [mul_assoc (t ^ (s / 2 - 1)) (t ^ (-(1:ℝ)/2)) (4 * rexp (-π * (1/t)))]
    -- Reorganize: = 4 * ((t^{σ/2-1} * t^{-1/2}) * exp(-π/t))
    -- = 4 * (t^{σ/2-3/2} * exp(-π/t))  [rpow_add]
    have := mul_assoc (t ^ (s / 2 - 1)) (t ^ (-(1:ℝ)/2)) (4 * rexp (-π * (1/t)))
    -- Just bound the whole product directly
    -- t^{s/2-1} * t^{-1/2} = t^{s/2-3/2}
    -- = t^{s/2} * t^{-3/2}
    -- ≤ 1 * (1/t)^{3/2}
    -- so LHS ≤ 4 * (1/t)^{3/2} * exp(-π/t) ≤ 4 * exp(-π) ≤ 4 * exp(-πt)
    calc t ^ (s / 2 - 1) * t ^ (-(1:ℝ)/2) * (4 * rexp (-π * (1/t)))
      _ ≤ (1/t) ^ (3/2 : ℝ) * (4 * rexp (-π * (1/t))) := by
            gcongr
            rw [← rpow_add ht]
            rw [one_div, inv_rpow ht.le, ← rpow_neg ht.le]
            apply rpow_le_rpow_of_exponent_ge ht ht1.le
            linarith
      _ = 4 * ((1/t) ^ (3/2 : ℝ) * rexp (-π * (1/t))) := by ring
      _ ≤ 4 * rexp (-π) :=
            mul_le_mul_of_nonneg_left h_squeeze (by norm_num)
      _ ≤ 4 * rexp (-π * t) := by
            have h_exp : -π ≤ -π * t := by nlinarith [pi_pos]
            exact mul_le_mul_of_nonneg_left (Real.exp_le_exp.mpr h_exp) (by norm_num)
  · rcases eq_or_lt_of_le ht1 with rfl | ht1'
    · -- t = 1: f_modif(1) = 0
      have : P₀.f_modif 1 = 0 := by
        have h1 : (1 : ℝ) ∉ Ioi (1 : ℝ) := by simp
        have h2 : (1 : ℝ) ∉ Ioo (0 : ℝ) 1 := fun h => (lt_irrefl 1 h.2)
        show (Ioi (1:ℝ)).indicator (fun x ↦ P₀.f x - P₀.f₀) 1 +
             (Ioo (0:ℝ) 1).indicator (fun x ↦ P₀.f x - (P₀.ε * ↑(x ^ (-P₀.k))) • P₀.g₀) 1 = 0
        rw [indicator_of_notMem h1, indicator_of_notMem h2, add_zero]
      simp [this]; positivity
    · -- t > 1: standard bound via f_modif_norm_le
      calc t ^ (s / 2 - 1) * ‖P₀.f_modif t‖
          ≤ 1 * ‖P₀.f_modif t‖ :=
              mul_le_mul_of_nonneg_right
                (rpow_le_one_of_one_le_of_nonpos (le_of_lt ht1') (by linarith))
                (norm_nonneg _)
        _ = ‖P₀.f_modif t‖ := one_mul _
        _ ≤ 4 * rexp (-π * t) := f_modif_norm_le ht1'

/-- The Mellin integral of the modified theta kernel is < 8 for real σ ∈ (0, 1/2).

    Uses the pointwise bound ‖integrand‖ ≤ 4·exp(-πt) and the explicit integral
    ∫₀^∞ 4·exp(-πt) dt = 4/π < 2. -/
private lemma mellin_integral_bound (s : ℝ) (hs_pos : 0 < s) (hs_lt : s < 1) :
    ∫ t in Ioi (0 : ℝ),
      ‖(t : ℂ) ^ ((↑s / 2 : ℂ) - 1) • P₀.toStrongFEPair.f t‖ < 8 := by
  -- The integral comparison: ∫ ‖integrand‖ ≤ ∫ 4·exp(-πt) = 4/π < 8
  have h_bound : IntegrableOn (fun t ↦ 4 * rexp (-π * t)) (Ioi (0 : ℝ)) :=
    (integrableOn_exp_mul_Ioi (show (-π : ℝ) < 0 from neg_lt_zero.mpr pi_pos) 0).const_mul 4
  have h_le : ∀ᵐ (t : ℝ) ∂(volume.restrict (Ioi (0 : ℝ))),
      ‖((t : ℝ) : ℂ) ^ ((↑s / 2 : ℂ) - 1) • P₀.f_modif t‖ ≤ 4 * rexp ((-π) * t) := by
    filter_upwards [ae_restrict_mem measurableSet_Ioi] with t ht
    rw [norm_smul, Complex.norm_cpow_eq_rpow_re_of_pos (mem_Ioi.mp ht)]
    simp only [sub_re, ofReal_re, div_ofNat, one_re]
    exact integrand_pointwise_bound hs_pos hs_lt (mem_Ioi.mp ht)
  calc ∫ t in Ioi (0 : ℝ),
        ‖(t : ℂ) ^ ((↑s / 2 : ℂ) - 1) • P₀.toStrongFEPair.f t‖
      ≤ ∫ t in Ioi (0 : ℝ), 4 * rexp (-π * t) :=
          integral_mono_of_nonneg
            (Eventually.of_forall (fun _ ↦ norm_nonneg _))
            h_bound h_le
    _ = 4 * (∫ t in Ioi (0 : ℝ), rexp (-π * t)) := by rw [integral_const_mul]
    _ = 4 * (-rexp (-π * 0) / (-π)) := by
          rw [integral_exp_mul_Ioi (show (-π : ℝ) < 0 from neg_lt_zero.mpr pi_pos) 0]
    _ = 4 / π := by rw [mul_zero, Real.exp_zero]; ring
    _ < 8 := by rw [div_lt_iff₀ pi_pos]; linarith [pi_gt_three]

-- ════════════════════════════════════════════════════
-- Section 6: Main theorem chain
-- ════════════════════════════════════════════════════

private lemma norm_Lambda0_lt_eight (s : ℝ) (hs_pos : 0 < s) (hs_lt : s < 1) :
    ‖P₀.Λ₀ ((↑s : ℂ) / 2)‖ < 8 := by
  show ‖mellin P₀.toStrongFEPair.f ((↑s : ℂ) / 2)‖ < 8
  exact (norm_mellin_le _ _).trans_lt (mellin_integral_bound s hs_pos hs_lt)

private lemma completedRiemannZeta₀_norm_bound (s : ℝ) (hs_pos : 0 < s) (hs_lt : s < 1) :
    ‖completedRiemannZeta₀ (s : ℂ)‖ < 4 := by
  rw [zeta0_eq, norm_div, Complex.norm_ofNat]
  linarith [norm_Lambda0_lt_eight s hs_pos hs_lt]

theorem completedRiemannZeta₀_bound_real_proved
    (s : ℝ) (hs_pos : 0 < s) (hs_lt : s < 1) :
    (completedRiemannZeta₀ (s : ℂ)).re < 4 :=
  (Complex.re_le_norm _).trans_lt (completedRiemannZeta₀_norm_bound s hs_pos hs_lt)

end
