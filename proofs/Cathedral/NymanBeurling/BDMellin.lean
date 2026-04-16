/-
  Cathedral/NymanBeurling/BDMellin.lean

  ## The Rank-1 Mellin Miracle

  Proves `zeta_zero_separates_bd` — the NB converse for the correct
  Báez-Duarte basis h_k(x) = {1/(kx)}.

  ### The Rank-1 Structure
  At a ζ zero ρ (where ζ(ρ) = 0, 0 < Re(ρ) < 1):
    M[h_k](ρ) = ∫₀¹ {1/(kx)}·x^{ρ-1} dx = 1/(k(ρ-1))

  This is a rank-1 tensor: M[h_k](ρ) = (1/k) · (1/(ρ-1)).
  The k-dependence and ρ-dependence completely factorize.

  ### The Separation Argument
  For any REAL linear combination f_w = Σ wₖ h_k:
    ℓ_ρ(1 - f_w) = 1/ρ - W/(ρ-1)  where W = Σ wₖ/k ∈ ℝ

  Since Im(1/ρ) ≠ 0 for non-trivial zeros (t ≠ 0), and W/(ρ-1)
  traces a real line in ℂ as W varies, the residual can NEVER be zero.

  This gives: |ℓ_ρ(1-f_w)|² ≥ t²/(|ρ|⁴|ρ-1|²) > 0
  And by Cauchy-Schwarz: d²_N ≥ (2σ-1) · t²/(|ρ|⁴|ρ-1|²) > 0

  ### Axioms (5 sub-axioms, down from 6 original)
  All 6 original axioms are now THEOREMS. Remaining sub-axioms:
  1. `bd_mellin_reduction` — Basis Collapse: u=kx substitution
  2. `bd_mellin_base_case` — Identity Theorem: k=1 analytic continuation
  3. `bd_cauchy_schwarz` — L² Cauchy-Schwarz (sed port)
  4. `completedRiemannZeta₀_bound_real` — θ-integral bound
  5. `bd_integral_linearity` — integral linearity (sed port)

  Status: 0 sorry.
-/

import Cathedral.Defs
import Cathedral.Gram.FractIntegral
import Mathlib.Analysis.SpecialFunctions.Integrals.Basic
import Mathlib.NumberTheory.LSeries.RiemannZeta

noncomputable section
open Complex Real MeasureTheory Set

-- ════════════════════════════════════════════════
-- DEFINITION: BD linear combination
-- ════════════════════════════════════════════════

/-- The Báez-Duarte linear combination: φ_w(x) = Σᵢ wᵢ · {1/((i+1)x)}.
    Uses the CORRECT BD basis h_k(x) = {1/(kx)} with θ = 1/k ≤ 1.
    By the Nyman-Beurling theorem: inf_w ‖1 - φ_w‖²_{L²(0,1)} → 0 iff RH. -/
def bdLinComb (N : ℕ) (w : Fin (N - 1) → ℝ) (x : ℝ) : ℝ :=
  ∑ i : Fin (N - 1), w i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x))

/-- A single scaled BD basis function is integrable on [0,1]. -/
private lemma bd_single_fract_integrable (k : ℕ) (c : ℝ) :
    IntervalIntegrable (fun x : ℝ => c * Int.fract (1 / ((k : ℝ) * x)))
      MeasureTheory.volume 0 1 := by
  have h_meas : Measurable (fun x : ℝ => c * Int.fract (1 / ((k : ℝ) * x))) :=
    (measurable_fract_real.comp (measurable_const.div
      (measurable_const.mul measurable_id))).const_mul c
  have h_bound : ∀ x : ℝ, ‖c * Int.fract (1 / ((k : ℝ) * x))‖ ≤ |c| := by
    intro x; rw [Real.norm_eq_abs, abs_mul]
    exact mul_le_of_le_one_right (abs_nonneg _)
      ((abs_of_nonneg (Int.fract_nonneg _)).le.trans (Int.fract_lt_one _).le)
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
  exact ⟨h_meas.aestronglyMeasurable, .of_bounded
    (Filter.Eventually.of_forall (fun x => h_bound x))⟩

/-- The BD linear combination is integrable on [0,1]. -/
theorem bdLinComb_integrable (N : ℕ) (v : Fin (N - 1) → ℝ) :
    IntervalIntegrable (bdLinComb N v) MeasureTheory.volume 0 1 := by
  unfold bdLinComb
  have h_sum : (fun x : ℝ => ∑ i : Fin (N - 1), v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x))) =
    (∑ i : Fin (N - 1), fun x : ℝ => v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x))) := by
    ext x; simp [Finset.sum_apply]
  rw [h_sum]
  apply IntervalIntegrable.sum; intro i _
  exact bd_single_fract_integrable (i.val + 1) (v i)

/-- bdLinComb is square-integrable on [0,1]. -/
private lemma bdLinComb_sq_integrable (N : ℕ) (v : Fin (N - 1) → ℝ) :
    IntervalIntegrable (fun x => (bdLinComb N v x) ^ 2) MeasureTheory.volume 0 1 := by
  have h_meas : Measurable (fun x : ℝ => bdLinComb N v x) := by
    unfold bdLinComb
    exact Finset.measurable_sum _ (fun i _ =>
      (measurable_fract_real.comp (measurable_const.div
        (measurable_const.mul measurable_id))).const_mul (v i))
  set C := ∑ i : Fin (N-1), |v i|
  have h_bound : ∀ x, ‖(bdLinComb N v x) ^ 2‖ ≤ C ^ 2 := by
    intro x; rw [Real.norm_eq_abs, abs_of_nonneg (sq_nonneg _)]
    have h_abs : |bdLinComb N v x| ≤ C := by
      unfold bdLinComb
      calc |∑ i, v i * Int.fract (1 / (↑(i.val + 1) * x))|
          ≤ ∑ i, |v i * Int.fract (1 / (↑(i.val + 1) * x))| := Finset.abs_sum_le_sum_abs _ _
        _ = ∑ i, |v i| * |Int.fract (1 / (↑(i.val + 1) * x))| := by congr 1; ext i; exact abs_mul _ _
        _ ≤ ∑ i, |v i| * 1 := by
          apply Finset.sum_le_sum; intro i _
          exact mul_le_mul_of_nonneg_left ((abs_of_nonneg (Int.fract_nonneg _)).le.trans
            (Int.fract_lt_one _).le) (abs_nonneg _)
        _ = C := by simp [C]
    have hC_nn : 0 ≤ C := by positivity
    have h1 : bdLinComb N v x ≤ C := (le_abs_self _).trans h_abs
    have h2 : -(C) ≤ bdLinComb N v x := le_trans (neg_le_neg h_abs) (neg_abs_le _)
    exact sq_le_sq' h2 h1
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
  exact ⟨(h_meas.pow_const 2).aestronglyMeasurable, .of_bounded
    (Filter.Eventually.of_forall (fun x => h_bound x))⟩

/-- The residual squared is integrable on [0,1]. -/
private lemma bd_residual_sq_iint (N : ℕ) (v : Fin (N - 1) → ℝ) :
    IntervalIntegrable (fun x => (1 - bdLinComb N v x) ^ 2) MeasureTheory.volume 0 1 := by
  rw [show (fun x => (1 - bdLinComb N v x) ^ 2) =
      (fun x => 1 - 2 * bdLinComb N v x + (bdLinComb N v x) ^ 2) from by ext x; ring]
  exact ((intervalIntegrable_const (c := (1:ℝ))).sub
    ((bdLinComb_integrable N v).const_mul 2)).add (bdLinComb_sq_integrable N v)

-- ════════════════════════════════════════════════
-- AXIOM 1: BD Mellin transform at ζ zeros
-- ════════════════════════════════════════════════

-- The Mellin transform of the BD basis at ζ zeros:
-- ∫₀¹ {1/(kx)} · x^{ρ-1} dx = 1/(k(ρ-1))
--
-- Proof via the Basis Collapse (Theorist, 2026-04-15):
-- 1. bd_mellin_reduction: factors out k via u=kx substitution
-- 2. bd_mellin_base_case: k=1 case via identity theorem
-- 3. Algebraic cancellation: k^{-ρ} terms annihilate at zeros

/-- **SUB-AXIOM 1a** (Basis Collapse): Factors out k for any s with Re(s) > 0.
    By substitution u = kx, the integral splits into:
    - The tail integral ∫₁ᵏ (1/u)·u^{s-1} du = (k^{s-1}-1)/(s-1)
    - A k^{-s} multiple of the k=1 base case -/
axiom bd_mellin_reduction (k : ℕ) (hk : 1 ≤ k) (s : ℂ) (hs : 0 < s.re) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((Int.fract (1 / ((k:ℝ)*x)) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1) =
    (1 / k - (k : ℂ) ^ (-s)) / (s - 1) +
    (k : ℂ) ^ (-s) * ∫ x in Set.Ioo (0:ℝ) 1, ((Int.fract (1 / x) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1)

/-- **SUB-AXIOM 1b** (Identity Theorem): Base case k=1 analytically continued.
    F(s) = ∫₀¹ {1/x}·x^{s-1} dx equals G(s) = 1/(s-1) - ζ(s)/s.
    FloorMellin.lean proves F = G for Re(s) > 1; the identity theorem
    extends this to all Re(s) > 0, s ≠ 1. -/
axiom bd_mellin_base_case (s : ℂ) (hs : 0 < s.re) (hs1 : s ≠ 1) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((Int.fract (1 / x) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1) =
    1 / (s - 1) - riemannZeta s / s

/-- **THEOREM** (Replaces Axiom 1): BD Mellin transform at a zeta zero.
    Chains the Basis Collapse + Identity Theorem + ζ(ρ)=0 cancellation. -/
theorem bd_mellin_at_zero (k : ℕ) (hk : 1 ≤ k) (ρ : ℂ)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1)
    (h_zero : riemannZeta ρ = 0) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((Int.fract (1 / ((k : ℝ) * x)) : ℝ) : ℂ) *
      (x : ℂ) ^ (ρ - 1) = 1 / ((k : ℂ) * (ρ - 1)) := by
  have hρ1 : ρ ≠ 1 := by intro h; rw [h] at hρ_lt; norm_num at hρ_lt
  -- Apply the Basis Collapse
  rw [bd_mellin_reduction k hk ρ hρ_pos]
  -- Apply the Base Case
  rw [bd_mellin_base_case ρ hρ_pos hρ1]
  -- Apply ζ(ρ) = 0
  rw [h_zero, zero_div, sub_zero]
  -- Algebra: the k^{-ρ} terms perfectly cancel
  have hk_ne : (k : ℂ) ≠ 0 := by exact_mod_cast ne_of_gt (by omega : 0 < k)
  have hp_ne : ρ - 1 ≠ 0 := sub_ne_zero.mpr hρ1
  calc (1 / ↑k - (↑k) ^ (-ρ)) / (ρ - 1) + (↑k) ^ (-ρ) * (1 / (ρ - 1))
    _ = (1 / ↑k) / (ρ - 1) - ((↑k) ^ (-ρ)) / (ρ - 1) + ((↑k) ^ (-ρ)) / (ρ - 1) := by ring
    _ = (1 / ↑k) / (ρ - 1) := by ring
    _ = 1 / ((↑k) * (ρ - 1)) := by rw [div_div]

-- ════════════════════════════════════════════════
-- SHARED HELPERS (basis-independent, from BesselSeparation)
-- ════════════════════════════════════════════════

/-- re(x^(ρ-1))² is integrable on [0,1]. Dominated by x^{2σ-2}. -/
private lemma bd_re_h_sq_iint (ρ : ℂ) (hρ : 1/2 < ρ.re) (_hρ' : ρ.re < 1) :
    IntervalIntegrable (fun x => ((x : ℂ) ^ (ρ - 1)).re ^ 2) volume 0 1 := by
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
  have h_dom : IntegrableOn (fun x : ℝ => x ^ (2 * ρ.re - 2)) (Set.Ioc 0 1) := by
    rw [← intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
    exact intervalIntegral.intervalIntegrable_rpow' (show -1 < 2 * ρ.re - 2 by linarith)
  refine Integrable.mono h_dom (Measurable.aestronglyMeasurable (by fun_prop)) ?_
  filter_upwards [self_mem_ae_restrict measurableSet_Ioc] with x hx
  rw [Real.norm_of_nonneg (sq_nonneg _), Real.norm_of_nonneg (Real.rpow_nonneg (le_of_lt hx.1) _)]
  have h_bound := (Complex.abs_re_le_norm ((x : ℂ) ^ (ρ - 1))).trans
    (Complex.norm_cpow_eq_rpow_re_of_pos hx.1 (ρ - 1)).le
  calc ((x : ℂ) ^ (ρ - 1)).re ^ 2
      ≤ (x ^ (ρ - 1).re) ^ 2 := sq_le_sq' (abs_le.mp h_bound).1 (abs_le.mp h_bound).2
    _ = x ^ (2 * (ρ - 1).re) := by rw [sq, ← Real.rpow_add hx.1]; ring_nf
    _ = x ^ (2 * ρ.re - 2) := by congr 1; simp [Complex.sub_re]; ring

/-- im(x^(ρ-1))² is integrable on [0,1]. Dominated by x^{2σ-2}. -/
private lemma bd_im_h_sq_iint (ρ : ℂ) (hρ : 1/2 < ρ.re) (_hρ' : ρ.re < 1) :
    IntervalIntegrable (fun x => ((x : ℂ) ^ (ρ - 1)).im ^ 2) volume 0 1 := by
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
  have h_dom : IntegrableOn (fun x : ℝ => x ^ (2 * ρ.re - 2)) (Set.Ioc 0 1) := by
    rw [← intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
    exact intervalIntegral.intervalIntegrable_rpow' (show -1 < 2 * ρ.re - 2 by linarith)
  refine Integrable.mono h_dom (Measurable.aestronglyMeasurable (by fun_prop)) ?_
  filter_upwards [self_mem_ae_restrict measurableSet_Ioc] with x hx
  rw [Real.norm_of_nonneg (sq_nonneg _), Real.norm_of_nonneg (Real.rpow_nonneg (le_of_lt hx.1) _)]
  have h_bound := (Complex.abs_im_le_norm ((x : ℂ) ^ (ρ - 1))).trans
    (Complex.norm_cpow_eq_rpow_re_of_pos hx.1 (ρ - 1)).le
  calc ((x : ℂ) ^ (ρ - 1)).im ^ 2
      ≤ (x ^ (ρ - 1).re) ^ 2 := sq_le_sq' (abs_le.mp h_bound).1 (abs_le.mp h_bound).2
    _ = x ^ (2 * (ρ - 1).re) := by rw [sq, ← Real.rpow_add hx.1]; ring_nf
    _ = x ^ (2 * ρ.re - 2) := by congr 1; simp [Complex.sub_re]; ring

/-- Ioo integral = interval integral (Ioc and Ioo differ by measure zero). -/
private lemma bd_ioo_eq_interval (f : ℝ → ℝ) (_hf : IntervalIntegrable f volume 0 1) :
    ∫ x in Set.Ioo (0:ℝ) 1, f x = ∫ x in (0:ℝ)..1, f x := by
  rw [intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  exact integral_Ioc_eq_integral_Ioo.symm

/-- ∫(re²+im²) = ∫x^{2σ-2} (pointwise normSq identity). -/
private lemma bd_norm_sq_cpow_integral (ρ : ℂ) (hρ : 0 < ρ.re) (hρ' : ρ.re < 1) :
    ∫ x in (0:ℝ)..1, (((x : ℂ) ^ (ρ - 1)).re ^ 2 + ((x : ℂ) ^ (ρ - 1)).im ^ 2) =
    ∫ x in (0:ℝ)..1, x ^ (2 * ρ.re - 2) := by
  apply intervalIntegral.integral_congr
  intro x hx
  simp only [Set.uIcc_of_le (by norm_num : (0:ℝ) ≤ 1), Set.mem_Icc] at hx
  show ((x : ℂ) ^ (ρ - 1)).re ^ 2 + ((x : ℂ) ^ (ρ - 1)).im ^ 2 = x ^ (2 * ρ.re - 2)
  rcases eq_or_lt_of_le hx.1 with rfl | hx_pos
  · have h_ne : ρ - 1 ≠ 0 := by
      intro h; have := congr_arg Complex.re h; simp at this; linarith
    simp only [Complex.ofReal_zero, zero_cpow h_ne, Complex.zero_re, Complex.zero_im]
    simp [Real.zero_rpow (show 2 * ρ.re - 2 ≠ 0 by linarith)]
  · have h1 : ((x : ℂ) ^ (ρ-1)).re ^ 2 + ((x : ℂ) ^ (ρ-1)).im ^ 2 =
        Complex.normSq ((x : ℂ) ^ (ρ-1)) := by rw [Complex.normSq_apply]; ring
    rw [h1, Complex.normSq_eq_norm_sq, Complex.norm_cpow_eq_rpow_re_of_pos hx_pos,
        sq, ← Real.rpow_add hx_pos]
    congr 1; simp [Complex.sub_re]; ring

private lemma bd_discrim_le {a b c : ℝ} (ha : 0 ≤ a)
    (h : ∀ t, 0 ≤ a * t ^ 2 + b * t + c) : b ^ 2 ≤ 4 * a * c := by
  by_contra h_neg; push_neg at h_neg
  rcases eq_or_lt_of_le ha with rfl | ha_pos
  · simp at h h_neg
    have hb : b ≠ 0 := by intro hb; simp [hb] at h_neg
    have := h (-(c + 1) / b); rw [mul_div_cancel₀ _ hb] at this; linarith
  · have h4 : (0:ℝ) < 4 * a := by linarith
    have hm := h (-b / (2 * a))
    have heq : a * (-b / (2 * a)) ^ 2 + b * (-b / (2 * a)) + c =
        c - b ^ 2 / (4 * a) := by field_simp; ring
    rw [heq] at hm
    have h1 : b ^ 2 / (4 * a) ≤ c := by linarith
    have h2 : b ^ 2 ≤ c * (4 * a) := by rwa [div_le_iff₀ h4] at h1
    linarith

/-- (∫₀¹ f·g)² ≤ (∫₀¹ f²)(∫₀¹ g²). -/
private lemma bd_cs_inner_le_sq (f g : ℝ → ℝ)
    (hf2 : IntervalIntegrable (fun x => f x ^ 2) volume 0 1)
    (hg2 : IntervalIntegrable (fun x => g x ^ 2) volume 0 1)
    (hfg : IntervalIntegrable (fun x => f x * g x) volume 0 1)
    (hft : ∀ t, IntervalIntegrable (fun x => (f x + t * g x) ^ 2) volume 0 1) :
    (∫ x in (0:ℝ)..1, f x * g x) ^ 2 ≤
      (∫ x in (0:ℝ)..1, f x ^ 2) * (∫ x in (0:ℝ)..1, g x ^ 2) := by
  have h_expand : ∀ t, ∫ x in (0:ℝ)..1, (f x + t * g x) ^ 2 =
      (∫ x in (0:ℝ)..1, g x ^ 2) * t ^ 2 +
      (2 * ∫ x in (0:ℝ)..1, f x * g x) * t +
      (∫ x in (0:ℝ)..1, f x ^ 2) := by
    intro t
    rw [show (fun x => (f x + t * g x) ^ 2) =
        (fun x => f x ^ 2 + 2 * t * (f x * g x) + t ^ 2 * g x ^ 2) from by ext x; ring]
    rw [intervalIntegral.integral_add (hf2.add (hfg.const_mul (2*t))) (hg2.const_mul (t^2)),
        intervalIntegral.integral_add hf2 (hfg.const_mul (2*t)),
        intervalIntegral.integral_const_mul, intervalIntegral.integral_const_mul]; ring
  have h_nn : ∀ t, 0 ≤ (∫ x in (0:ℝ)..1, g x ^ 2) * t ^ 2 +
      (2 * ∫ x in (0:ℝ)..1, f x * g x) * t + (∫ x in (0:ℝ)..1, f x ^ 2) := fun t => by
    rw [← h_expand]; exact intervalIntegral.integral_nonneg (by norm_num) (fun x _ => sq_nonneg _)
  nlinarith [bd_discrim_le
    (intervalIntegral.integral_nonneg (by norm_num) (fun x _ => sq_nonneg _)) h_nn]

-- ════════════════════════════════════════════════
-- PROVED: Cauchy-Schwarz for BD residual
-- (Port of cauchy_schwarz_separation_bound from BesselSeparation)
-- ════════════════════════════════════════════════

/-- BD residual is Bochner-integrable on Ioo(0,1). -/
private lemma bd_residual_cpow_integrableOn (N : ℕ) (_hN : 2 ≤ N)
    (v : Fin (N-1) → ℝ) (ρ : ℂ) (hρ_pos : 0 < ρ.re) (_hρ_lt : ρ.re < 1) :
    IntegrableOn (fun x : ℝ => ((1 - bdLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1))
      (Set.Ioo (0:ℝ) 1) := by
  set C := 1 + ∑ i : Fin (N-1), |v i| with hC_def
  have hC_nn : 0 ≤ C := by simp [hC_def]; linarith [Finset.sum_nonneg (fun i (_ : i ∈ Finset.univ) => abs_nonneg (v i))]
  have h_dom : IntegrableOn (fun x : ℝ => C * x ^ (ρ.re - 1)) (Set.Ioo 0 1) :=
    IntegrableOn.mono_set
      (by rw [← intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
          exact (intervalIntegral.intervalIntegrable_rpow'
            (show -1 < ρ.re - 1 by linarith)).const_mul C)
      Set.Ioo_subset_Ioc_self
  have h_f_bound : ∀ x : ℝ, |1 - bdLinComb N v x| ≤ C := by
    intro x
    have hf : |bdLinComb N v x| ≤ ∑ i : Fin (N-1), |v i| := by
      unfold bdLinComb
      calc |∑ i, v i * Int.fract (1 / (↑(i.val + 1) * x))|
          ≤ ∑ i, |v i * Int.fract (1 / (↑(i.val + 1) * x))| := Finset.abs_sum_le_sum_abs _ _
        _ = ∑ i, |v i| * |Int.fract (1 / (↑(i.val + 1) * x))| := by congr 1; ext i; exact abs_mul _ _
        _ ≤ ∑ i, |v i| * 1 := Finset.sum_le_sum (fun i _ =>
            mul_le_mul_of_nonneg_left ((abs_of_nonneg (Int.fract_nonneg _)).le.trans
              (Int.fract_lt_one _).le) (abs_nonneg _))
        _ = ∑ i, |v i| := by simp
    calc |1 - bdLinComb N v x| ≤ |1| + |bdLinComb N v x| := abs_sub _ _
      _ = 1 + |bdLinComb N v x| := by simp
      _ ≤ C := by linarith
  apply Integrable.mono h_dom
  · exact (Complex.continuous_ofReal.comp_aestronglyMeasurable
      (((intervalIntegrable_const (c := (1:ℝ))).sub (bdLinComb_integrable N v)).aestronglyMeasurable.mono_set
        (Set.Ioo_subset_Ioc_self.trans (by simp [Set.uIoc_of_le (by norm_num : (0:ℝ) ≤ 1)])))
      ).mul (Measurable.aestronglyMeasurable (by fun_prop))
  · filter_upwards [self_mem_ae_restrict measurableSet_Ioo] with x hx
    rw [norm_mul, Complex.norm_real, Complex.norm_cpow_eq_rpow_re_of_pos hx.1 _,
        Real.norm_of_nonneg (mul_nonneg hC_nn (Real.rpow_nonneg (le_of_lt hx.1) _))]
    apply mul_le_mul_of_nonneg_right (h_f_bound x) (Real.rpow_nonneg (le_of_lt hx.1) _)

/-- BD g·re(h) is integrable via AM-GM. -/
private lemma bd_g_re_h_iint (N : ℕ) (_hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ : 1/2 < ρ.re) (hρ' : ρ.re < 1) :
    IntervalIntegrable (fun x => (1 - bdLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).re) volume 0 1 := by
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
  have h_sum : IntegrableOn
      (fun x => (1/2 : ℝ) * ((1 - bdLinComb N v x) ^ 2 + ((x:ℂ) ^ (ρ-1)).re ^ 2))
      (Set.Ioc 0 1) := by
    rw [← intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
    exact ((bd_residual_sq_iint N v).add (bd_re_h_sq_iint ρ hρ hρ')).const_mul _
  have h_meas : AEStronglyMeasurable (fun x : ℝ => (1 - bdLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).re)
      (volume.restrict (Set.Ioc 0 1)) :=
    (((intervalIntegrable_const (c := (1:ℝ))).sub (bdLinComb_integrable N v)).aestronglyMeasurable.mono_set
      (by simp [Set.uIoc_of_le (by norm_num : (0:ℝ) ≤ 1)])).mul
      (Measurable.aestronglyMeasurable (by fun_prop)).restrict
  refine Integrable.mono h_sum h_meas ?_
  filter_upwards [self_mem_ae_restrict measurableSet_Ioc] with x _
  rw [Real.norm_of_nonneg (mul_nonneg (by norm_num : (0:ℝ) ≤ 1/2)
      (add_nonneg (sq_nonneg _) (sq_nonneg _))), Real.norm_eq_abs, abs_mul]
  nlinarith [sq_abs (1 - bdLinComb N v x), sq_abs (((x:ℂ)^(ρ-1)).re),
             sq_nonneg (|1 - bdLinComb N v x| - |((x:ℂ)^(ρ-1)).re|)]

/-- BD g·im(h) is integrable via AM-GM. -/
private lemma bd_g_im_h_iint (N : ℕ) (_hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ : 1/2 < ρ.re) (hρ' : ρ.re < 1) :
    IntervalIntegrable (fun x => (1 - bdLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).im) volume 0 1 := by
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
  have h_sum : IntegrableOn
      (fun x => (1/2 : ℝ) * ((1 - bdLinComb N v x) ^ 2 + ((x:ℂ) ^ (ρ-1)).im ^ 2))
      (Set.Ioc 0 1) := by
    rw [← intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
    exact ((bd_residual_sq_iint N v).add (bd_im_h_sq_iint ρ hρ hρ')).const_mul _
  have h_meas : AEStronglyMeasurable (fun x : ℝ => (1 - bdLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).im)
      (volume.restrict (Set.Ioc 0 1)) :=
    (((intervalIntegrable_const (c := (1:ℝ))).sub (bdLinComb_integrable N v)).aestronglyMeasurable.mono_set
      (by simp [Set.uIoc_of_le (by norm_num : (0:ℝ) ≤ 1)])).mul
      (Measurable.aestronglyMeasurable (by fun_prop)).restrict
  refine Integrable.mono h_sum h_meas ?_
  filter_upwards [self_mem_ae_restrict measurableSet_Ioc] with x _
  rw [Real.norm_of_nonneg (mul_nonneg (by norm_num : (0:ℝ) ≤ 1/2)
      (add_nonneg (sq_nonneg _) (sq_nonneg _))), Real.norm_eq_abs, abs_mul]
  nlinarith [sq_abs (1 - bdLinComb N v x), sq_abs (((x:ℂ)^(ρ-1)).im),
             sq_nonneg (|1 - bdLinComb N v x| - |((x:ℂ)^(ρ-1)).im|)]

/-- BD (g + t·re(h))² is interval-integrable. -/
private lemma bd_cs_shift_re (N : ℕ) (hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ : 1/2 < ρ.re) (hρ' : ρ.re < 1) (t : ℝ) :
    IntervalIntegrable (fun x => ((1 - bdLinComb N v x) + t * ((x : ℂ) ^ (ρ - 1)).re) ^ 2) volume 0 1 := by
  rw [show (fun x => ((1 - bdLinComb N v x) + t * ((x : ℂ) ^ (ρ - 1)).re) ^ 2) =
      (fun x => (1 - bdLinComb N v x) ^ 2 + 2 * t * ((1 - bdLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).re) +
        t ^ 2 * ((x : ℂ) ^ (ρ - 1)).re ^ 2) from by ext x; ring]
  exact ((bd_residual_sq_iint N v).add ((bd_g_re_h_iint N hN v ρ hρ hρ').const_mul (2*t))).add
    ((bd_re_h_sq_iint ρ hρ hρ').const_mul (t^2))

/-- BD (g + t·im(h))² is interval-integrable. -/
private lemma bd_cs_shift_im (N : ℕ) (hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ : 1/2 < ρ.re) (hρ' : ρ.re < 1) (t : ℝ) :
    IntervalIntegrable (fun x => ((1 - bdLinComb N v x) + t * ((x : ℂ) ^ (ρ - 1)).im) ^ 2) volume 0 1 := by
  rw [show (fun x => ((1 - bdLinComb N v x) + t * ((x : ℂ) ^ (ρ - 1)).im) ^ 2) =
      (fun x => (1 - bdLinComb N v x) ^ 2 + 2 * t * ((1 - bdLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).im) +
        t ^ 2 * ((x : ℂ) ^ (ρ - 1)).im ^ 2) from by ext x; ring]
  exact ((bd_residual_sq_iint N v).add ((bd_g_im_h_iint N hN v ρ hρ hρ').const_mul (2*t))).add
    ((bd_im_h_sq_iint ρ hρ hρ').const_mul (t^2))

private lemma bd_ofReal_mul_re (g : ℝ) (h : ℂ) : ((g : ℂ) * h).re = g * h.re := by
  simp [Complex.mul_re, Complex.ofReal_re, Complex.ofReal_im]

private lemma bd_ofReal_mul_im (g : ℝ) (h : ℂ) : ((g : ℂ) * h).im = g * h.im := by
  simp [Complex.mul_im, Complex.ofReal_re, Complex.ofReal_im]

/-- **THEOREM** (Replaces Axiom 2): Complex Cauchy-Schwarz for the BD residual.
    |∫₀¹ (1-f) · x^{ρ-1} dx|² ≤ (∫₀¹ (1-f)² dx) · 1/(2σ-1) -/
theorem bd_cauchy_schwarz (N : ℕ) (hN : 2 ≤ N) (v : Fin (N - 1) → ℝ) (ρ : ℂ)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) (hρ_gt : 1/2 < ρ.re) :
    Complex.normSq (∫ x in Set.Ioo (0:ℝ) 1,
      ((1 - bdLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1)) ≤
    (∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2) * (1 / (2 * ρ.re - 1)) := by
  set F := fun x : ℝ => ((1 - bdLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1)
  set z := ∫ x in Set.Ioo (0:ℝ) 1, F x
  have h_int := bd_residual_cpow_integrableOn N hN v ρ hρ_pos hρ_lt
  -- re(z) = ∫₀¹ g · re(h) via ContinuousLinearMap
  have h_re : z.re = ∫ x in (0:ℝ)..1,
      (1 - bdLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).re := by
    change Complex.reCLM (∫ x in Set.Ioo (0:ℝ) 1, F x) = _
    rw [← Complex.reCLM.integral_comp_comm h_int]
    have : (fun x => Complex.reCLM (F x)) =
      (fun x => (1 - bdLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).re) := by
      ext x; exact bd_ofReal_mul_re _ _
    rw [this]; exact bd_ioo_eq_interval _ (bd_g_re_h_iint N hN v ρ hρ_gt hρ_lt)
  -- im(z) = ∫₀¹ g · im(h)
  have h_im : z.im = ∫ x in (0:ℝ)..1,
      (1 - bdLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).im := by
    change Complex.imCLM (∫ x in Set.Ioo (0:ℝ) 1, F x) = _
    rw [← Complex.imCLM.integral_comp_comm h_int]
    have : (fun x => Complex.imCLM (F x)) =
      (fun x => (1 - bdLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).im) := by
      ext x; exact bd_ofReal_mul_im _ _
    rw [this]; exact bd_ioo_eq_interval _ (bd_g_im_h_iint N hN v ρ hρ_gt hρ_lt)
  -- Apply real CS × 2
  set g := fun x : ℝ => 1 - bdLinComb N v x
  have cs_re := bd_cs_inner_le_sq g (fun x => ((x : ℂ) ^ (ρ - 1)).re)
    (bd_residual_sq_iint N v) (bd_re_h_sq_iint ρ hρ_gt hρ_lt)
    (bd_g_re_h_iint N hN v ρ hρ_gt hρ_lt) (bd_cs_shift_re N hN v ρ hρ_gt hρ_lt)
  have cs_im := bd_cs_inner_le_sq g (fun x => ((x : ℂ) ^ (ρ - 1)).im)
    (bd_residual_sq_iint N v) (bd_im_h_sq_iint ρ hρ_gt hρ_lt)
    (bd_g_im_h_iint N hN v ρ hρ_gt hρ_lt) (bd_cs_shift_im N hN v ρ hρ_gt hρ_lt)
  -- normSq z ≤ ∫g² · (∫re(h)² + ∫im(h)²)
  have h_bound : Complex.normSq z ≤ (∫ x in (0:ℝ)..1, g x ^ 2) *
      ((∫ x in (0:ℝ)..1, ((x : ℂ) ^ (ρ-1)).re ^ 2) +
       (∫ x in (0:ℝ)..1, ((x : ℂ) ^ (ρ-1)).im ^ 2)) := by
    have hd : Complex.normSq z = z.re ^ 2 + z.im ^ 2 := by rw [Complex.normSq_apply]; ring
    rw [hd, h_re, h_im]; nlinarith [cs_re, cs_im]
  -- ∫re(h)² + ∫im(h)² = 1/(2σ-1)
  have h_norm : (∫ x in (0:ℝ)..1, ((x : ℂ) ^ (ρ-1)).re ^ 2) +
      (∫ x in (0:ℝ)..1, ((x : ℂ) ^ (ρ-1)).im ^ 2) = 1 / (2 * ρ.re - 1) := by
    rw [← intervalIntegral.integral_add (bd_re_h_sq_iint ρ hρ_gt hρ_lt) (bd_im_h_sq_iint ρ hρ_gt hρ_lt),
        bd_norm_sq_cpow_integral ρ hρ_pos hρ_lt,
        integral_rpow (Or.inl (show -1 < 2 * ρ.re - 2 by linarith)),
        show 2 * ρ.re - 2 + 1 = 2 * ρ.re - 1 from by ring,
        Real.one_rpow, Real.zero_rpow (ne_of_gt (show 0 < 2 * ρ.re - 1 by linarith))]; ring
  rw [h_norm] at h_bound; linarith

-- ════════════════════════════════════════════════
-- PROVED (modulo 3 sub-axioms): ζ has no real zeros in (0,1)
-- Strategy: The Jacobi Theta Bypass
-- ════════════════════════════════════════════════

/-- Pole terms: for real s ∈ (0,1), -1/s - 1/(1-s) ≤ -4.
    Follows from AM-GM: s(1-s) ≤ 1/4. -/
private lemma pole_terms_le_neg_four (s : ℝ) (hs_pos : 0 < s) (hs_lt : s < 1) :
    -1 / s + -1 / (1 - s) ≤ -4 := by
  have hs1 : 0 < 1 - s := by linarith
  rw [div_add_div _ _ (ne_of_gt hs_pos) (ne_of_gt hs1)]
  rw [div_le_iff₀ (mul_pos hs_pos hs1)]
  nlinarith [sq_nonneg (s - 1/2)]

/-- **SUB-AXIOM 3a** (θ-integral bound): The entire function Λ₀(s) satisfies
    Re(Λ₀(s)) < 4 for real s ∈ (0,1).

    Proof path: Λ₀(s) = ∫₁^∞ (x^{s/2-1} + x^{(1-s)/2-1}) ω(x) dx / 2
    where ω(x) = Σ_{n≥1} e^{-πn²x}. For s ∈ (0,1) and x ≥ 1,
    x^{negative} ≤ 1, so the integrand ≤ 2ω(x).
    The integral ∫₁^∞ ω(x) dx ≤ e^{-π}/(π(1-e^{-π})) ≈ 0.015,
    giving Λ₀(s) ≤ 0.030 ≪ 4. -/
axiom completedRiemannZeta₀_bound_real (s : ℝ) (hs_pos : 0 < s) (hs_lt : s < 1) :
    (completedRiemannZeta₀ (s : ℂ)).re < 4

-- NOTE: completedRiemannZeta₀_real (sub-axiom 3b) was originally here but is unused.
-- The real-part extraction is handled directly by push_cast + ring.

-- PROVED: Gammaℝ(s) ≠ 0 for real s > 0.  (Mathlib: Gammaℝ_ne_zero_of_re_pos)

/-- The completed zeta function is negative for real s ∈ (0,1).
    By the Jacobi Theta Bypass: Λ(s) = Λ₀(s) - 1/s - 1/(1-s),
    where Λ₀(s) < 4 and -1/s - 1/(1-s) ≤ -4. -/
private theorem completedRiemannZeta_neg_on_unit_interval
    (s : ℝ) (hs_pos : 0 < s) (hs_lt : s < 1) :
    (completedRiemannZeta (s : ℂ)).re < 0 := by
  have h_eq := completedRiemannZeta_eq (s : ℂ)
  have h_Λ₀_bound := completedRiemannZeta₀_bound_real s hs_pos hs_lt
  have h_poles := pole_terms_le_neg_four s hs_pos hs_lt
  have h_re : (completedRiemannZeta (s : ℂ)).re =
      (completedRiemannZeta₀ (s : ℂ)).re +
      (-1 / s + -1 / (1 - s)) := by
    conv_lhs => rw [h_eq]
    -- For real s: 1/(s:ℂ) = (1/s : ℝ) and 1/((1-s):ℂ) = (1/(1-s) : ℝ)
    have hs_ne : (s : ℂ) ≠ 0 := by exact_mod_cast ne_of_gt hs_pos
    have hs1_ne : (1 : ℂ) - (s : ℂ) ≠ 0 := by
      rw [← Complex.ofReal_one, ← Complex.ofReal_sub]
      exact_mod_cast ne_of_gt (by linarith : (0:ℝ) < 1 - s)
    rw [show (1 : ℂ) / (s : ℂ) = ((1 / s : ℝ) : ℂ) from by push_cast; rfl]
    rw [show (1 : ℂ) / ((1 : ℂ) - (s : ℂ)) = (((1 / (1 - s)) : ℝ) : ℂ) from by push_cast; rfl]
    simp only [Complex.sub_re, Complex.ofReal_re]
    ring
  rw [h_re]; linarith

/-- **THEOREM** (Replaces Axiom 3): ζ(s) ≠ 0 for real s ∈ (0,1).
    Proof via the Jacobi Theta Bypass:
    riemannZeta s = completedRiemannZeta s / Gammaℝ s,
    where the numerator < 0 and the denominator ≠ 0. -/
theorem zeta_no_real_zeros_in_strip (s : ℝ) (hs_pos : 0 < s) (hs_lt : s < 1) :
    riemannZeta (s : ℂ) ≠ 0 := by
  have hs_ne : (s : ℂ) ≠ 0 := by exact_mod_cast ne_of_gt hs_pos
  rw [riemannZeta_def_of_ne_zero hs_ne]
  have h_neg := completedRiemannZeta_neg_on_unit_interval s hs_pos hs_lt
  have h_gamma := Gammaℝ_ne_zero_of_re_pos (by simp [hs_pos] : 0 < (s : ℂ).re)
  apply div_ne_zero
  · intro h; rw [h] at h_neg; simp at h_neg
  · exact h_gamma

-- ════════════════════════════════════════════════
-- PROVED: Helper lemmas
-- ════════════════════════════════════════════════

/-- ρ ≠ 0 when Re(ρ) > 0. -/
private lemma rho_ne_zero (ρ : ℂ) (hρ : 0 < ρ.re) : ρ ≠ 0 := by
  intro h; rw [h] at hρ; simp at hρ

/-- ρ-1 ≠ 0 when Re(ρ) < 1. -/
private lemma rho_sub_one_ne_zero (ρ : ℂ) (hρ : ρ.re < 1) : ρ - 1 ≠ 0 := by
  intro h; have := congr_arg Complex.re h; simp at this; linarith

/-- ∫₀¹ x^{ρ-1} dx = 1/ρ (Ioo version). -/
private lemma one_inner_cpow' (ρ : ℂ) (hρ_pos : 0 < ρ.re) :
    ∫ x in Set.Ioo (0:ℝ) 1, (x : ℂ) ^ (ρ - 1) = 1 / ρ := by
  rw [← integral_Ioc_eq_integral_Ioo,
      ← intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1),
      integral_cpow (Or.inl (show -1 < (ρ-1).re by simp [Complex.sub_re]; linarith)),
      show (ρ - 1) + 1 = ρ from by ring]
  have hρ_ne : ρ ≠ 0 := rho_ne_zero ρ hρ_pos
  simp only [Complex.ofReal_one, Complex.ofReal_zero, Complex.one_cpow, Complex.zero_cpow hρ_ne]
  ring

-- ════════════════════════════════════════════════
-- PROVED: Integral linearity for BD residual
-- (Port of residual_inner_cpow_eq from BesselSeparation)
-- ════════════════════════════════════════════════

/-- x^{ρ-1} is L¹ on Ioc(0,1) as ℂ-valued. -/
private lemma bd_cpow_integrableOn_Ioc (ρ : ℂ) (hρ : 0 < ρ.re) :
    IntegrableOn (fun x : ℝ => (x : ℂ) ^ (ρ - 1)) (Set.Ioc 0 1) := by
  have h_dom : IntegrableOn (fun x : ℝ => x ^ (ρ.re - 1)) (Set.Ioc 0 1) := by
    rw [← intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
    exact intervalIntegral.intervalIntegrable_rpow' (show -1 < ρ.re - 1 by linarith)
  exact Integrable.mono h_dom (Measurable.aestronglyMeasurable (by fun_prop)) (by
    filter_upwards [self_mem_ae_restrict measurableSet_Ioc] with x hx
    rw [Complex.norm_cpow_eq_rpow_re_of_pos hx.1 (ρ - 1),
        show (ρ - 1).re = ρ.re - 1 from by simp [Complex.sub_re],
        Real.norm_of_nonneg (Real.rpow_nonneg (le_of_lt hx.1) _)])

/-- {1/(kx)}·x^{ρ-1} is L¹ on Ioc(0,1) (bounded × integrable). -/
private lemma bd_fract_cpow_integrableOn_Ioc (k : ℕ) (ρ : ℂ) (hρ : 0 < ρ.re) :
    IntegrableOn (fun x : ℝ => ((Int.fract (1 / ((k : ℝ) * x)) : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1))
      (Set.Ioc 0 1) :=
  Integrable.bdd_mul' (bd_cpow_integrableOn_Ioc ρ hρ)
    ((Complex.continuous_ofReal.measurable.comp
      (measurable_fract_real.comp (measurable_const.div
        (measurable_const.mul measurable_id)))).aestronglyMeasurable)
    (Filter.Eventually.of_forall (fun x => by
      rw [Complex.norm_real]
      exact (abs_of_nonneg (Int.fract_nonneg _)).le.trans (Int.fract_lt_one _).le))

/-- **THEOREM** (Replaces Axiom 4): Integral linearity for the BD residual.
    ∫(1-f)·h = ∫h - Σ vᵢ·∫(fᵢ·h)

    Proved by porting residual_inner_cpow_eq from BesselSeparation.lean. -/
theorem bd_integral_linearity (N : ℕ) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((1 - bdLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) =
    (∫ x in Set.Ioo (0:ℝ) 1, (x : ℂ) ^ (ρ - 1)) -
    ∑ i : Fin (N-1), (v i : ℂ) *
      ∫ x in Set.Ioo (0:ℝ) 1, ((Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) : ℝ) : ℂ) *
        (x : ℂ) ^ (ρ - 1) := by
  rw [← integral_Ioc_eq_integral_Ioo]
  -- Expand: (1-f)·h = h - Σ vᵢ·({1/((i+1)x)}·h)
  have h_eq : ∀ x : ℝ, ((1 - bdLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) =
      (x : ℂ) ^ (ρ - 1) - ∑ i : Fin (N-1),
        ((v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) := by
    intro x; rw [Complex.ofReal_sub, Complex.ofReal_one, sub_mul, one_mul]; congr 1
    rw [show (bdLinComb N v x : ℂ) = ∑ i : Fin (N-1),
      ((v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) : ℝ) : ℂ) from by
      simp [bdLinComb, Complex.ofReal_sum, Complex.ofReal_mul]]
    rw [Finset.sum_mul]
  have h_sum_int : ∀ i : Fin (N-1), i ∈ Finset.univ →
      IntegrableOn (fun x => ((v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) : ℝ) : ℂ) *
        (x : ℂ) ^ (ρ - 1)) (Set.Ioc 0 1) := by
    intro i _
    apply Integrable.bdd_mul' (bd_cpow_integrableOn_Ioc ρ hρ_pos)
    · exact (Complex.continuous_ofReal.measurable.comp
        ((measurable_const.mul (measurable_fract_real.comp
          (measurable_const.div (measurable_const.mul measurable_id)))))).aestronglyMeasurable
    · exact Filter.Eventually.of_forall (fun x => by
        rw [Complex.norm_real]
        calc |v i * Int.fract (1 / (↑(i.val + 1) * x))|
            = |v i| * |Int.fract (1 / (↑(i.val + 1) * x))| := abs_mul _ _
          _ ≤ |v i| * 1 := mul_le_mul_of_nonneg_left
              ((abs_of_nonneg (Int.fract_nonneg _)).le.trans (Int.fract_lt_one _).le) (abs_nonneg _)
          _ = |v i| := mul_one _)
  simp_rw [h_eq]
  rw [integral_sub (bd_cpow_integrableOn_Ioc ρ hρ_pos) (integrable_finset_sum _ h_sum_int),
      integral_finset_sum _ h_sum_int]
  -- Factor out vᵢ from each integral
  have h_terms : ∀ i : Fin (N-1),
      ∫ x in Set.Ioc (0:ℝ) 1, ((v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) : ℝ) : ℂ) *
        (x : ℂ) ^ (ρ - 1) =
      (v i : ℂ) * ∫ x in Set.Ioc (0:ℝ) 1, ((Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) : ℝ) : ℂ) *
        (x : ℂ) ^ (ρ - 1) := by
    intro i
    rw [show (fun x : ℝ => ((v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) : ℝ) : ℂ) *
      (x : ℂ) ^ (ρ - 1)) = (fun x => (v i : ℂ) *
      (((Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1))) from by
      ext x; push_cast; ring]
    exact integral_const_mul _ _
  simp_rw [h_terms]
  -- Convert Ioc back to Ioo
  congr 1
  · exact integral_Ioc_eq_integral_Ioo
  · congr 1; ext i
    congr 1; exact integral_Ioc_eq_integral_Ioo

-- ════════════════════════════════════════════════
-- PROVED: The BD residual Mellin transform
-- ════════════════════════════════════════════════

/-- **PROVED**: The BD residual's Mellin transform.
    ∫₀¹ (1 - bdLinComb) · x^{ρ-1} dx = 1/ρ - W/(ρ-1)
    where W = Σ vₖ/(k+1) ∈ ℝ.

    This is the key identity that makes the Rank-1 argument work:
    the integral depends on v only through the single real number W. -/
theorem bd_residual_mellin (N : ℕ) (_hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) (h_zero : riemannZeta ρ = 0) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((1 - bdLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) =
    1 / ρ - (∑ i : Fin (N-1), (v i : ℂ) / (↑(i.val + 1) : ℂ)) * (1 / (ρ - 1)) := by
  -- Step 1: Apply integral linearity to split the integral
  rw [bd_integral_linearity N v ρ hρ_pos hρ_lt]
  -- Step 2: The first integral is 1/ρ
  rw [one_inner_cpow' ρ hρ_pos]
  -- Step 3: Each basis integral is 1/((i+1)(ρ-1)) by bd_mellin_at_zero
  -- After linearity: 1/ρ - Σᵢ vᵢ · ∫{1/((i+1)x)}·cpow
  -- Each integral = 1/((i+1)(ρ-1))
  congr 1
  have h_terms : ∀ i : Fin (N-1),
      ∫ x in Set.Ioo (0:ℝ) 1, ((Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) : ℝ) : ℂ) *
        (x : ℂ) ^ (ρ - 1) = 1 / ((↑(i.val + 1) : ℂ) * (ρ - 1)) := by
    intro i
    exact bd_mellin_at_zero (i.val + 1) (by omega) ρ hρ_pos hρ_lt h_zero
  simp_rw [h_terms]
  -- Now LHS = 1/ρ - Σ vᵢ * (1/((i+1)(ρ-1)))
  -- RHS = 1/ρ - (Σ vᵢ/(i+1)) * (1/(ρ-1))
  -- Rewrite each term: vᵢ * (1/((i+1)(ρ-1))) = vᵢ/(i+1) * (1/(ρ-1))
  have key : ∀ i : Fin (N-1), (v i : ℂ) * (1 / ((↑(i.val + 1) : ℂ) * (ρ - 1))) =
      (v i : ℂ) / (↑(i.val + 1) : ℂ) * (1 / (ρ - 1)) := by
    intro i
    have hi : (↑(i.val + 1) : ℂ) ≠ 0 := by exact_mod_cast Nat.succ_ne_zero i.val
    have hρ1 : ρ - 1 ≠ 0 := rho_sub_one_ne_zero ρ hρ_lt
    field_simp
  simp_rw [key, ← Finset.sum_mul]

-- ════════════════════════════════════════════════
-- PROVED: The Rank-1 lower bound on |residual|²
-- ════════════════════════════════════════════════

/-- The key quadratic identity: D·((σu-1)² + (tu)²) = (Du-σ)² + t²
    where D = σ² + t² = |ρ|². This is the perfect-square decomposition
    that makes the Rank-1 lower bound trivial. -/
private lemma quadratic_sq_identity (σ t u : ℝ) :
    (σ^2 + t^2) * ((σ * u - 1)^2 + (t * u)^2) =
    ((σ^2 + t^2) * u - σ)^2 + t^2 := by ring

/-- normSq of the numerator (1-W)ρ-1 in terms of real components. -/
private lemma normSq_linear_sub (σ t u : ℝ) :
    (σ * u - 1)^2 + (t * u)^2 = (σ^2 + t^2) * u^2 - 2 * σ * u + 1 := by ring

/-- **PROVED (Rank-1 Lower Bound)**: For all W ∈ ℝ,
    |1/ρ - W/(ρ-1)|² ≥ t² / (|ρ|⁴·|ρ-1|²).

    This is the geometric heart of the Rank-1 Mellin Miracle.
    The key identity: setting u = 1-W,
      |ρ|² · normSq((u·ρ - 1)) = (|ρ|²·u - σ)² + t²
    which is ≥ t² (perfect square ≥ 0).
    Therefore normSq(1/ρ - W/(ρ-1)) ≥ t²/(|ρ|⁴·|ρ-1|²). -/
theorem rank1_lower_bound (ρ : ℂ) (hρ_ne : ρ ≠ 0) (hρ1_ne : ρ - 1 ≠ 0)
    (_him : ρ.im ≠ 0) (W : ℝ) :
    ρ.im ^ 2 / (Complex.normSq ρ ^ 2 * Complex.normSq (ρ - 1)) ≤
    Complex.normSq (1 / ρ - (W : ℂ) / (ρ - 1)) := by
  set σ := ρ.re; set t := ρ.im
  have hD_pos : 0 < Complex.normSq ρ := Complex.normSq_pos.mpr hρ_ne
  have hD2_pos : 0 < Complex.normSq (ρ - 1) := Complex.normSq_pos.mpr hρ1_ne
  -- Step 1: Express as quotient
  have heq : 1 / ρ - (↑W : ℂ) / (ρ - 1) = ((1 - ↑W) * ρ - 1) / (ρ * (ρ - 1)) := by
    field_simp; ring
  rw [heq, map_div₀, map_mul]
  -- Step 2: Compute re/im of numerator
  set z := (1 - (↑W : ℂ)) * ρ - 1
  have hz_re : z.re = σ * (1 - W) - 1 := by
    simp [z, Complex.mul_re, Complex.sub_re, Complex.ofReal_re, Complex.ofReal_im,
      Complex.one_re]; ring
  have hz_im : z.im = t * (1 - W) := by
    simp [z, Complex.mul_im, Complex.sub_im, Complex.ofReal_re, Complex.ofReal_im,
      Complex.one_im]; ring
  -- Step 3: normSq z = z.re² + z.im²
  have hnum_ns : Complex.normSq z = (σ * (1 - W) - 1)^2 + (t * (1 - W))^2 := by
    rw [Complex.normSq_apply, hz_re, hz_im]; ring
  have hD_eq : Complex.normSq ρ = σ^2 + t^2 := by
    rw [Complex.normSq_apply]; ring
  rw [hnum_ns]
  -- Step 4: Reduce to the core real inequality
  -- Goal: t²/(D²·D2) ≤ ((σ(1-W)-1)²+(t(1-W))²)/(D·D2)
  -- Suffices: t² ≤ ((σ(1-W)-1)²+(t(1-W))²) · D
  suffices h : t^2 ≤ ((σ * (1 - W) - 1)^2 + (t * (1 - W))^2) * Complex.normSq ρ by
    rw [div_le_div_iff₀ (mul_pos (pow_pos hD_pos 2) hD2_pos) (mul_pos hD_pos hD2_pos)]
    nlinarith [mul_pos hD_pos hD2_pos]
  -- Step 5: The quadratic identity closes it
  rw [hD_eq]
  nlinarith [quadratic_sq_identity σ t (1 - W),
    sq_nonneg ((σ^2 + t^2) * (1 - W) - σ)]

-- ════════════════════════════════════════════════
-- PROVED: Functional equation reflection
-- ════════════════════════════════════════════════

/-- **PROVED**: If ρ has 0 < Re < 1 and Re ≠ 1/2, there exists ρ'
    with ζ(ρ') = 0, 1/2 < Re(ρ') < 1, and Im(ρ') ≠ 0. -/
theorem bd_exists_zero_re_gt_half (ρ : ℂ) (h_zero : riemannZeta ρ = 0)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) (hρ_ne : ρ.re ≠ 1/2) :
    ∃ ρ' : ℂ, riemannZeta ρ' = 0 ∧ 1/2 < ρ'.re ∧ ρ'.re < 1 ∧ ρ'.im ≠ 0 := by
  -- Helper: ρ with Im=0 can't be a zero in (0,1)
  have no_real_zero : ∀ s : ℂ, riemannZeta s = 0 → 0 < s.re → s.re < 1 → s.im ≠ 0 := by
    intro s hs hs_pos hs_lt him
    -- If Im(s) = 0 then s = (s.re : ℂ)
    have hreal : s = (s.re : ℂ) := by
      apply Complex.ext <;> simp [him]
    rw [hreal] at hs
    exact absurd hs (zeta_no_real_zeros_in_strip s.re hs_pos hs_lt)
  -- Step 1: Get a zero with Re > 1/2 (by functional equation reflection if needed)
  rcases lt_or_gt_of_ne hρ_ne with h_lt | h_gt
  · -- Case Re(ρ) < 1/2: reflect to 1-ρ which has Re > 1/2
    have h_nni : ∀ n : ℕ, ρ ≠ -(↑n : ℂ) := by
      intro n h; have := congr_arg Complex.re h; simp at this; linarith
    have h_ne1 : ρ ≠ 1 := by intro h; rw [h] at hρ_lt; simp at hρ_lt
    have h_func := riemannZeta_one_sub h_nni h_ne1
    have h_1ρ_zero : riemannZeta (1 - ρ) = 0 := by rw [h_func, h_zero, mul_zero]
    refine ⟨1 - ρ, h_1ρ_zero, by simp [Complex.sub_re]; linarith,
      by simp [Complex.sub_re]; linarith, ?_⟩
    -- Im(1-ρ) = -Im(ρ), so Im(1-ρ) ≠ 0 ↔ Im(ρ) ≠ 0
    simp [Complex.sub_im]
    exact no_real_zero ρ h_zero hρ_pos hρ_lt
  · -- Case Re(ρ) > 1/2: use ρ directly
    exact ⟨ρ, h_zero, h_gt, hρ_lt, no_real_zero ρ h_zero hρ_pos hρ_lt⟩

-- ════════════════════════════════════════════════
-- THE CROWN: ζ zero separation for BD basis
-- ════════════════════════════════════════════════

/-- **THEOREM**: ζ zero separation for the BD basis.

    If ζ(ρ) = 0 with 0 < Re(ρ) < 1 and Re(ρ) ≠ 1/2, then for all
    N ≥ 2 and all real weight vectors v, the L² distance from 1 to
    bdLinComb(v) is bounded below:

      ∫₀¹ (1 - bdLinComb N v x)² dx ≥ δ > 0

    **Proof** (via Cauchy-Schwarz + Rank-1):
    1. Get ρ' with ζ(ρ')=0, Re(ρ')>1/2, Im(ρ')≠0
    2. bd_residual_mellin: ∫(1-f)·cpow = 1/ρ' - W/(ρ'-1)
    3. rank1_lower_bound: |1/ρ' - W/(ρ'-1)|² ≥ δ₀ > 0
    4. bd_cauchy_schwarz: |∫(1-f)·cpow|² ≤ ∫(1-f)² · 1/(2σ'-1)
    5. Combine: ∫(1-f)² ≥ (2σ'-1) · δ₀ -/
theorem zeta_zero_separates_bd :
    ∀ ρ : ℂ, riemannZeta ρ = 0 →
    0 < ρ.re → ρ.re < 1 → ρ.re ≠ 1/2 →
    ∃ δ : ℝ, 0 < δ ∧
    ∀ N : ℕ, 2 ≤ N → ∀ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 ≥ δ := by
  intro ρ h_zero hρ_pos hρ_lt hρ_ne
  -- Step 1: Get a zero with Re > 1/2 and Im ≠ 0
  obtain ⟨ρ', hz', hgt', hlt', him'⟩ :=
    bd_exists_zero_re_gt_half ρ h_zero hρ_pos hρ_lt hρ_ne
  have hρ'_pos : 0 < ρ'.re := by linarith
  have hρ'_ne : ρ' ≠ 0 := rho_ne_zero ρ' hρ'_pos
  have hρ'1_ne : ρ' - 1 ≠ 0 := rho_sub_one_ne_zero ρ' hlt'
  -- Step 2: Define δ using the sharp Rank-1 bound (no phantom factor)
  set σ' := ρ'.re
  set t' := ρ'.im
  -- The minimum of |1/ρ' - W/(ρ'-1)|² over W ∈ ℝ is t'²/(|ρ'|⁴·|ρ'-1|²)
  -- Our separation bound is (2σ'-1) times this minimum:
  set δ₀ := t' ^ 2 /
    (Complex.normSq ρ' ^ 2 * Complex.normSq (ρ' - 1))
  set δ := (2 * σ' - 1) * δ₀
  have hδ₀_pos : 0 < δ₀ := by
    apply div_pos
    · exact sq_pos_of_ne_zero him'
    · exact mul_pos (sq_pos_of_ne_zero (ne_of_gt (Complex.normSq_pos.mpr hρ'_ne)))
        (Complex.normSq_pos.mpr hρ'1_ne)
  have hδ_pos : 0 < δ := mul_pos (by linarith) hδ₀_pos
  refine ⟨δ, hδ_pos, fun N hN v => ?_⟩
  -- Step 3: Compute the residual integral via bd_residual_mellin
  set W := ∑ i : Fin (N-1), v i / (↑(i.val + 1) : ℝ)
  have h_resid := bd_residual_mellin N hN v ρ' hρ'_pos hlt' hz'
  -- Step 4: Cauchy-Schwarz gives: normSq(integral) ≤ ∫(1-f)² · 1/(2σ'-1)
  have h_cs := bd_cauchy_schwarz N hN v ρ' hρ'_pos hlt' hgt'
  -- Step 5: Rank-1 gives: normSq(1/ρ' - W'/(ρ'-1)) ≥ δ₀
  -- where W' = Σ vᵢ/(i+1) cast to ℂ and divided appropriately
  -- The integral equals 1/ρ' - (Σ vᵢ/(i+1)) · 1/(ρ'-1) by h_resid
  -- So normSq(integral) = normSq(1/ρ' - (Σ vᵢ/(i+1)) · 1/(ρ'-1))
  -- But rank1_lower_bound needs W : ℝ such that W/(ρ-1) matches.
  -- The residual is 1/ρ' - (Σ (vᵢ:ℂ)/(i+1)) * (1/(ρ'-1))
  -- = 1/ρ' - (↑W' : ℂ) * (1/(ρ'-1)) where W' = Σ vᵢ/(i+1) ∈ ℝ
  -- = 1/ρ' - (↑W' : ℂ) / (ρ'-1)
  -- Rewrite the normSq of the integral using h_resid
  have h_W_cast : (∑ i : Fin (N-1), (v i : ℂ) / (↑(i.val + 1) : ℂ)) = (↑W : ℂ) := by
    simp only [W, Complex.ofReal_sum, Complex.ofReal_div, Complex.ofReal_natCast]
  have h_resid' : ∫ x in Set.Ioo (0:ℝ) 1,
      ((1 - bdLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ' - 1) =
      1 / ρ' - (↑W : ℂ) / (ρ' - 1) := by
    rw [h_resid, h_W_cast]; ring
  -- Apply rank1_lower_bound (PROVED): normSq(1/ρ' - ↑W/(ρ'-1)) ≥ δ₀
  have h_rank1 := rank1_lower_bound ρ' hρ'_ne hρ'1_ne him' W
  -- Combine: normSq(integral) ≥ δ₀
  have h_ns_ge : δ₀ ≤ Complex.normSq (∫ x in Set.Ioo (0:ℝ) 1,
      ((1 - bdLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ' - 1)) := by
    rw [h_resid']; exact h_rank1
  -- From CS: ∫(1-f)² · 1/(2σ'-1) ≥ normSq(integral) ≥ δ₀
  -- So ∫(1-f)² ≥ (2σ'-1) · δ₀ = δ
  have h_2σ_pos : (0:ℝ) < 2 * σ' - 1 := by linarith
  have h_inv_pos : (0:ℝ) < 1 / (2 * σ' - 1) := by positivity
  -- h_cs: normSq(integral) ≤ ∫(1-f)² * (1/(2σ'-1))
  -- h_ns_ge: δ₀ ≤ normSq(integral)
  -- Therefore: δ₀ ≤ ∫(1-f)² * (1/(2σ'-1))
  -- So ∫(1-f)² ≥ δ₀ * (2σ'-1) = (2σ'-1) * δ₀ = δ
  rw [ge_iff_le]
  have h_combined : δ₀ ≤ (∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2) *
      (1 / (2 * σ' - 1)) := le_trans h_ns_ge h_cs
  -- h_combined: δ₀ ≤ ∫(1-f)² * (1/(2σ'-1))
  -- goal: δ ≤ ∫(1-f)²  where δ = (2σ'-1) * δ₀
  -- So: (2σ'-1) * δ₀ ≤ ∫(1-f)²
  -- From h_combined: δ₀ ≤ I * (1/(2σ'-1)), multiply by (2σ'-1):
  have h_mul : δ₀ * (2 * σ' - 1) ≤
      (∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2) *
      (1 / (2 * σ' - 1)) * (2 * σ' - 1) :=
    mul_le_mul_of_nonneg_right h_combined (le_of_lt h_2σ_pos)
  have h_cancel : (1 : ℝ) / (2 * σ' - 1) * (2 * σ' - 1) = 1 :=
    div_mul_cancel₀ 1 (ne_of_gt h_2σ_pos)
  rw [mul_assoc, h_cancel, mul_one] at h_mul
  linarith

end
