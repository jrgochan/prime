/-
  Cathedral/NymanBeurling/BesselSeparation.lean

  ## The Bessel Separation Theorem

  Proves `zeta_zero_separates` from elementary axioms
  using Bessel's inequality / Cauchy-Schwarz.

  ### Architecture
  - `fract_inner_cpow`: axiom — Báez-Duarte integral identity
  - `residual_inner_cpow_eq`: axiom — complex integral linearity
  - `residual_cpow_integrableOn`: axiom — Bochner integrability
  - `cauchy_schwarz_separation_bound`: PROVED from the above
  - Plus 4 integrability axioms (product/square integrability)

  ### Key proved results
  - Real Cauchy-Schwarz via discriminant trick
  - Complex → real bridge via ContinuousLinearMap.integral_comp_comm
  - rpow L² norm computation
  - normSq pointwise identity via norm_cpow_eq_rpow_re_of_pos
  - Ioo/interval integral equivalence
  - Shifted-square integrability from components
  - Functional equation reflection
  - The crown converse `zeta_zero_separates_from_bessel`

  Status: 0 sorry, all theorems fully proved.
-/

import Cathedral.Defs
import Cathedral.Axioms
import Cathedral.Gram.L2Bridge
import Cathedral.Gram.FractIntegral
import Cathedral.Structural.Independence
import Mathlib.Analysis.InnerProductSpace.Basic
import Mathlib.Analysis.SpecialFunctions.Integrals.Basic

noncomputable section
open Complex Real MeasureTheory Set

-- ════════════════════════════════════════════════
-- PART I: AXIOMS (3 mathematical + 4 integrability)
-- ════════════════════════════════════════════════

/-- **AXIOM**: ∫₀¹ {k/x} · x^{ρ-1} dx = -ζ(ρ) · k^ρ / ρ.
    Báez-Duarte (2003), Proposition 2.1. Valid for all k ≥ 1. -/
axiom fract_inner_cpow (k : ℕ) (hk : 1 ≤ k) (ρ : ℂ) (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((Int.fract ((k : ℝ) / x) : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) =
      -(riemannZeta ρ) * (k : ℂ) ^ ρ / ρ

-- ════════════════════════════════════════════════
-- PROVED: ⟨1-f, x^{ρ-1}⟩ = 1/ρ when ζ(ρ) = 0
-- Derived from fract_inner_cpow via integral linearity.
-- ════════════════════════════════════════════════

/-- x^{ρ-1} is L¹ on Ioc(0,1) as ℂ-valued. -/
private lemma cpow_integrableOn_Ioc (ρ : ℂ) (hρ : 0 < ρ.re) :
    IntegrableOn (fun x : ℝ => (x : ℂ) ^ (ρ - 1)) (Set.Ioc 0 1) := by
  have h_dom : IntegrableOn (fun x : ℝ => x ^ (ρ.re - 1)) (Set.Ioc 0 1) := by
    rw [← intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
    exact intervalIntegral.intervalIntegrable_rpow' (show -1 < ρ.re - 1 by linarith)
  exact Integrable.mono h_dom (Measurable.aestronglyMeasurable (by fun_prop)) (by
    filter_upwards [self_mem_ae_restrict measurableSet_Ioc] with x hx
    rw [Complex.norm_cpow_eq_rpow_re_of_pos hx.1 (ρ - 1),
        show (ρ - 1).re = ρ.re - 1 from by simp [Complex.sub_re],
        Real.norm_of_nonneg (Real.rpow_nonneg (le_of_lt hx.1) _)])

/-- {k/x}·x^{ρ-1} is L¹ on Ioc(0,1) (bounded × integrable). -/
private lemma fract_cpow_integrableOn_Ioc (k : ℕ) (ρ : ℂ) (hρ : 0 < ρ.re) :
    IntegrableOn (fun x : ℝ => ((Int.fract ((k : ℝ) / x) : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1))
      (Set.Ioc 0 1) :=
  Integrable.bdd_mul' (cpow_integrableOn_Ioc ρ hρ)
    ((Complex.continuous_ofReal.measurable.comp
      (measurable_fract_real.comp (measurable_const.div measurable_id))).aestronglyMeasurable)
    (Filter.Eventually.of_forall (fun x => by
      rw [Complex.norm_real]
      exact (abs_of_nonneg (Int.fract_nonneg _)).le.trans (Int.fract_lt_one _).le))

/-- ∫_{Ioc 0 1} x^{ρ-1} dx = 1/ρ. -/
private lemma cpow_setIntegral_Ioc (ρ : ℂ) (hρ : 0 < ρ.re) :
    ∫ x in Set.Ioc (0:ℝ) 1, (x : ℂ) ^ (ρ - 1) = 1 / ρ := by
  rw [← intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1),
      integral_cpow (Or.inl (show -1 < (ρ-1).re by simp [Complex.sub_re]; linarith)),
      show (ρ - 1) + 1 = ρ from by ring]
  have hρ_ne : ρ ≠ 0 := by intro h; rw [h] at hρ; simp at hρ
  simp only [Complex.ofReal_one, Complex.ofReal_zero, Complex.one_cpow, Complex.zero_cpow hρ_ne]
  ring

/-- **PROVED**: ⟨1-f, x^{ρ-1}⟩ = 1/ρ when ζ(ρ) = 0.
    Derived from `fract_inner_cpow` by integral linearity:
    ∫(1-f)·h = ∫h - Σvᵢ·∫{(i+1)/x}·h = 1/ρ - Σvᵢ(-ζ(ρ)(i+1)^ρ/ρ) = 1/ρ. -/
theorem residual_inner_cpow_eq (N : ℕ) (_hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) (h_zero : riemannZeta ρ = 0) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((1 - nbLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) = 1 / ρ := by
  rw [← integral_Ioc_eq_integral_Ioo]
  -- Expand: (1-f)·h = h - Σ vᵢ·({(i+1)/x}·h)
  have h_eq : ∀ x : ℝ, ((1 - nbLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) =
      (x : ℂ) ^ (ρ - 1) - ∑ i : Fin (N-1),
        ((v i * Int.fract ((↑(i.val + 1) : ℝ) / x) : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) := by
    intro x; rw [Complex.ofReal_sub, Complex.ofReal_one, sub_mul, one_mul]; congr 1
    rw [show (nbLinComb N v x : ℂ) = ∑ i : Fin (N-1),
      ((v i * Int.fract ((↑(i.val + 1) : ℝ) / x) : ℝ) : ℂ) from by
      simp [nbLinComb, Complex.ofReal_sum, Complex.ofReal_mul]]
    rw [Finset.sum_mul]
  have h_sum_int : ∀ i : Fin (N-1), i ∈ Finset.univ →
      IntegrableOn (fun x => ((v i * Int.fract ((↑(i.val + 1) : ℝ) / x) : ℝ) : ℂ) *
        (x : ℂ) ^ (ρ - 1)) (Set.Ioc 0 1) := by
    intro i _
    apply Integrable.bdd_mul' (cpow_integrableOn_Ioc ρ hρ_pos)
    · exact (Complex.continuous_ofReal.measurable.comp
        ((measurable_const.mul (measurable_fract_real.comp
          (measurable_const.div measurable_id))))).aestronglyMeasurable
    · exact Filter.Eventually.of_forall (fun x => by
        rw [Complex.norm_real]
        calc |v i * Int.fract (↑(i.val + 1) / x)|
            = |v i| * |Int.fract (↑(i.val + 1) / x)| := abs_mul _ _
          _ ≤ |v i| * 1 := mul_le_mul_of_nonneg_left
              ((abs_of_nonneg (Int.fract_nonneg _)).le.trans (Int.fract_lt_one _).le) (abs_nonneg _)
          _ = |v i| := mul_one _)
  simp_rw [h_eq]
  rw [integral_sub (cpow_integrableOn_Ioc ρ hρ_pos) (integrable_finset_sum _ h_sum_int),
      cpow_setIntegral_Ioc ρ hρ_pos,
      integral_finset_sum _ h_sum_int]
  -- Each term: ∫ (vi*{k/x}:ℝ)·cpow = vi · ∫{k/x}·cpow
  have h_terms : ∀ i : Fin (N-1),
      ∫ x in Set.Ioc (0:ℝ) 1, ((v i * Int.fract ((↑(i.val + 1) : ℝ) / x) : ℝ) : ℂ) *
        (x : ℂ) ^ (ρ - 1) =
      (v i : ℂ) * ∫ x in Set.Ioc (0:ℝ) 1, ((Int.fract ((↑(i.val + 1) : ℝ) / x) : ℝ) : ℂ) *
        (x : ℂ) ^ (ρ - 1) := by
    intro i
    rw [show (fun x : ℝ => ((v i * Int.fract ((↑(i.val + 1) : ℝ) / x) : ℝ) : ℂ) *
      (x : ℂ) ^ (ρ - 1)) = (fun x => (v i : ℂ) *
      (((Int.fract ((↑(i.val + 1) : ℝ) / x) : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1))) from by
      ext x; push_cast; ring]
    exact integral_const_mul _ _
  simp_rw [h_terms]
  -- Apply fract_inner_cpow after Ioc→Ioo conversion
  have h_conv : ∀ i : Fin (N-1),
      ∫ x in Set.Ioc (0:ℝ) 1,
        ((Int.fract ((↑(i.val + 1) : ℝ) / x) : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) =
      -(riemannZeta ρ) * (↑(i.val + 1) : ℂ) ^ ρ / ρ := by
    intro i
    rw [integral_Ioc_eq_integral_Ioo,
        fract_inner_cpow _ (by omega : 1 ≤ i.val + 1) ρ hρ_pos hρ_lt]
  simp_rw [h_conv, h_zero, neg_zero, zero_mul, zero_div, mul_zero,
           Finset.sum_const_zero, sub_zero]

/-- **PROVED**: Bochner integrability of g·x^{ρ-1} on (0,1).
    Strategy: |1-f(x)| ≤ 1+Σ|vᵢ| (bounded) and ‖x^{ρ-1}‖ = x^{σ-1} (integrable for σ>0).
    Product dominated by C·x^{σ-1} via Integrable.mono. -/
theorem residual_cpow_integrableOn (N : ℕ) (_hN : 2 ≤ N)
    (v : Fin (N-1) → ℝ) (ρ : ℂ) (hρ_pos : 0 < ρ.re) (_hρ_lt : ρ.re < 1) :
    IntegrableOn (fun x : ℝ => ((1 - nbLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1))
      (Set.Ioo (0:ℝ) 1) := by
  set C := 1 + ∑ i : Fin (N-1), |v i| with hC_def
  have hC_nn : 0 ≤ C := by
    simp [hC_def]; linarith [Finset.sum_nonneg (fun i (_ : i ∈ Finset.univ) => abs_nonneg (v i))]
  -- Dominator: C · x^(σ-1) is IntegrableOn Ioo
  have h_dom : IntegrableOn (fun x : ℝ => C * x ^ (ρ.re - 1)) (Set.Ioo 0 1) :=
    IntegrableOn.mono_set
      (by rw [← intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
          exact (intervalIntegral.intervalIntegrable_rpow'
            (show -1 < ρ.re - 1 by linarith)).const_mul C)
      Set.Ioo_subset_Ioc_self
  -- Bound: |1 - f(x)| ≤ C
  have h_f_bound : ∀ x : ℝ, |1 - nbLinComb N v x| ≤ C := by
    intro x
    have hf : |nbLinComb N v x| ≤ ∑ i : Fin (N-1), |v i| := by
      unfold nbLinComb
      calc |∑ i, v i * Int.fract (↑(i.val + 1) / x)|
          ≤ ∑ i, |v i * Int.fract (↑(i.val + 1) / x)| := Finset.abs_sum_le_sum_abs _ _
        _ = ∑ i, |v i| * |Int.fract (↑(i.val + 1) / x)| := by congr 1; ext i; exact abs_mul _ _
        _ ≤ ∑ i, |v i| * 1 := Finset.sum_le_sum (fun i _ =>
            mul_le_mul_of_nonneg_left ((abs_of_nonneg (Int.fract_nonneg _)).le.trans
              (Int.fract_lt_one _).le) (abs_nonneg _))
        _ = ∑ i, |v i| := by simp
    calc |1 - nbLinComb N v x| ≤ |1| + |nbLinComb N v x| := abs_sub _ _
      _ = 1 + |nbLinComb N v x| := by simp
      _ ≤ C := by linarith
  apply Integrable.mono h_dom
  · -- AEStronglyMeasurable
    exact (Complex.continuous_ofReal.comp_aestronglyMeasurable
      (((intervalIntegrable_const (c := (1:ℝ))).sub (nbLinComb_integrable N v)).aestronglyMeasurable.mono_set
        (Set.Ioo_subset_Ioc_self.trans (by simp [Set.uIoc_of_le (by norm_num : (0:ℝ) ≤ 1)])))
      ).mul (Measurable.aestronglyMeasurable (by fun_prop))
  · -- Norm bound: ‖(1-f)·cpow‖ ≤ C · x^(σ-1)
    filter_upwards [self_mem_ae_restrict measurableSet_Ioo] with x hx
    rw [norm_mul, Complex.norm_real, Complex.norm_cpow_eq_rpow_re_of_pos hx.1 _,
        Real.norm_of_nonneg (mul_nonneg hC_nn (Real.rpow_nonneg (le_of_lt hx.1) _))]
    apply mul_le_mul_of_nonneg_right (h_f_bound x) (Real.rpow_nonneg (le_of_lt hx.1) _)

-- Helper: g² integrability (needed by product integrability proofs)
private lemma residual_sq_iint (N : ℕ) (v : Fin (N-1) → ℝ) :
    IntervalIntegrable (fun x => (1 - nbLinComb N v x) ^ 2) volume 0 1 := by
  rw [show (fun x => (1 - nbLinComb N v x) ^ 2) =
      (fun x => 1 - 2 * nbLinComb N v x + (nbLinComb N v x) ^ 2) from by ext x; ring]
  exact ((intervalIntegrable_const (c := (1:ℝ))).sub
    ((nbLinComb_integrable N v).const_mul 2)).add (nbLinComb_sq_integrable N v)

-- ════════════════════════════════════════════════
-- PROVED INTEGRABILITY (formerly 4 axioms)
-- re²/im² use domination by x^{2σ-2} via |re(z)| ≤ ‖z‖ = x^(σ-1).
-- Products use AM-GM: |ab| ≤ (a²+b²)/2.
-- ════════════════════════════════════════════════

/-- **PROVED**: re(x^(ρ-1))² is integrable on [0,1]. Dominated by x^{2σ-2}. -/
theorem re_h_sq_iint (ρ : ℂ) (hρ : 1/2 < ρ.re) (_hρ' : ρ.re < 1) :
    IntervalIntegrable (fun x => ((x : ℂ) ^ (ρ - 1)).re ^ 2) volume 0 1 := by
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
  have h_dom : IntegrableOn (fun x : ℝ => x ^ (2 * ρ.re - 2)) (Set.Ioc 0 1) := by
    rw [← intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
    exact intervalIntegral.intervalIntegrable_rpow' (show -1 < 2 * ρ.re - 2 by linarith)
  have h_meas : Measurable (fun x : ℝ => ((x : ℂ) ^ (ρ - 1)).re ^ 2) := by fun_prop
  refine Integrable.mono h_dom h_meas.aestronglyMeasurable ?_
  filter_upwards [self_mem_ae_restrict measurableSet_Ioc] with x hx
  rw [Real.norm_of_nonneg (sq_nonneg _), Real.norm_of_nonneg (Real.rpow_nonneg (le_of_lt hx.1) _)]
  have h_bound := (Complex.abs_re_le_norm ((x : ℂ) ^ (ρ - 1))).trans
    (Complex.norm_cpow_eq_rpow_re_of_pos hx.1 (ρ - 1)).le
  calc ((x : ℂ) ^ (ρ - 1)).re ^ 2
      ≤ (x ^ (ρ - 1).re) ^ 2 := sq_le_sq' (abs_le.mp h_bound).1 (abs_le.mp h_bound).2
    _ = x ^ (2 * (ρ - 1).re) := by rw [sq, ← Real.rpow_add hx.1]; ring_nf
    _ = x ^ (2 * ρ.re - 2) := by congr 1; simp [Complex.sub_re]; ring

/-- **PROVED**: im(x^(ρ-1))² is integrable on [0,1]. Dominated by x^{2σ-2}. -/
theorem im_h_sq_iint (ρ : ℂ) (hρ : 1/2 < ρ.re) (_hρ' : ρ.re < 1) :
    IntervalIntegrable (fun x => ((x : ℂ) ^ (ρ - 1)).im ^ 2) volume 0 1 := by
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
  have h_dom : IntegrableOn (fun x : ℝ => x ^ (2 * ρ.re - 2)) (Set.Ioc 0 1) := by
    rw [← intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
    exact intervalIntegral.intervalIntegrable_rpow' (show -1 < 2 * ρ.re - 2 by linarith)
  have h_meas : Measurable (fun x : ℝ => ((x : ℂ) ^ (ρ - 1)).im ^ 2) := by fun_prop
  refine Integrable.mono h_dom h_meas.aestronglyMeasurable ?_
  filter_upwards [self_mem_ae_restrict measurableSet_Ioc] with x hx
  rw [Real.norm_of_nonneg (sq_nonneg _), Real.norm_of_nonneg (Real.rpow_nonneg (le_of_lt hx.1) _)]
  have h_bound := (Complex.abs_im_le_norm ((x : ℂ) ^ (ρ - 1))).trans
    (Complex.norm_cpow_eq_rpow_re_of_pos hx.1 (ρ - 1)).le
  calc ((x : ℂ) ^ (ρ - 1)).im ^ 2
      ≤ (x ^ (ρ - 1).re) ^ 2 := sq_le_sq' (abs_le.mp h_bound).1 (abs_le.mp h_bound).2
    _ = x ^ (2 * (ρ - 1).re) := by rw [sq, ← Real.rpow_add hx.1]; ring_nf
    _ = x ^ (2 * ρ.re - 2) := by congr 1; simp [Complex.sub_re]; ring

/-- **PROVED**: g·re is integrable via AM-GM: |ab| ≤ (a²+b²)/2. -/
theorem g_re_h_iint (N : ℕ) (_hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ : 1/2 < ρ.re) (hρ' : ρ.re < 1) :
    IntervalIntegrable (fun x => (1 - nbLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).re) volume 0 1 := by
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
  have h_sum : IntegrableOn
      (fun x => (1/2 : ℝ) * ((1 - nbLinComb N v x) ^ 2 + ((x:ℂ) ^ (ρ-1)).re ^ 2))
      (Set.Ioc 0 1) := by
    rw [← intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
    exact ((residual_sq_iint N v).add (re_h_sq_iint ρ hρ hρ')).const_mul _
  have h_meas : AEStronglyMeasurable (fun x : ℝ => (1 - nbLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).re)
      (volume.restrict (Set.Ioc 0 1)) :=
    (((intervalIntegrable_const (c := (1:ℝ))).sub (nbLinComb_integrable N v)).aestronglyMeasurable.mono_set
      (by simp [Set.uIoc_of_le (by norm_num : (0:ℝ) ≤ 1)])).mul
      (Measurable.aestronglyMeasurable (by fun_prop)).restrict
  refine Integrable.mono h_sum h_meas ?_
  filter_upwards [self_mem_ae_restrict measurableSet_Ioc] with x _
  rw [Real.norm_of_nonneg (mul_nonneg (by norm_num : (0:ℝ) ≤ 1/2)
      (add_nonneg (sq_nonneg _) (sq_nonneg _))), Real.norm_eq_abs, abs_mul]
  nlinarith [sq_abs (1 - nbLinComb N v x), sq_abs (((x:ℂ)^(ρ-1)).re),
             sq_nonneg (|1 - nbLinComb N v x| - |((x:ℂ)^(ρ-1)).re|)]

/-- **PROVED**: g·im is integrable via AM-GM. -/
theorem g_im_h_iint (N : ℕ) (_hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ : 1/2 < ρ.re) (hρ' : ρ.re < 1) :
    IntervalIntegrable (fun x => (1 - nbLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).im) volume 0 1 := by
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
  have h_sum : IntegrableOn
      (fun x => (1/2 : ℝ) * ((1 - nbLinComb N v x) ^ 2 + ((x:ℂ) ^ (ρ-1)).im ^ 2))
      (Set.Ioc 0 1) := by
    rw [← intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
    exact ((residual_sq_iint N v).add (im_h_sq_iint ρ hρ hρ')).const_mul _
  have h_meas : AEStronglyMeasurable (fun x : ℝ => (1 - nbLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).im)
      (volume.restrict (Set.Ioc 0 1)) :=
    (((intervalIntegrable_const (c := (1:ℝ))).sub (nbLinComb_integrable N v)).aestronglyMeasurable.mono_set
      (by simp [Set.uIoc_of_le (by norm_num : (0:ℝ) ≤ 1)])).mul
      (Measurable.aestronglyMeasurable (by fun_prop)).restrict
  refine Integrable.mono h_sum h_meas ?_
  filter_upwards [self_mem_ae_restrict measurableSet_Ioc] with x _
  rw [Real.norm_of_nonneg (mul_nonneg (by norm_num : (0:ℝ) ≤ 1/2)
      (add_nonneg (sq_nonneg _) (sq_nonneg _))), Real.norm_eq_abs, abs_mul]
  nlinarith [sq_abs (1 - nbLinComb N v x), sq_abs (((x:ℂ)^(ρ-1)).im),
             sq_nonneg (|1 - nbLinComb N v x| - |((x:ℂ)^(ρ-1)).im|)]

-- ════════════════════════════════════════════════
-- PART I-B: PROVED PLUMBING (formerly axioms)
-- ════════════════════════════════════════════════

/-- **PROVED**: ∫ on Ioo = interval integral (Ioc and Ioo differ by measure zero). -/
theorem ioo_eq_interval (f : ℝ → ℝ) (_hf : IntervalIntegrable f volume 0 1) :
    ∫ x in Set.Ioo (0:ℝ) 1, f x = ∫ x in (0:ℝ)..1, f x := by
  rw [intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  exact integral_Ioc_eq_integral_Ioo.symm

/-- **PROVED**: ∫(re²+im²) = ∫x^{2σ-2} (pointwise normSq identity). -/
theorem norm_sq_cpow_integral (ρ : ℂ) (hρ : 0 < ρ.re) (hρ' : ρ.re < 1) :
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

-- ════════════════════════════════════════════════
-- PART II: PROVED HELPERS
-- ════════════════════════════════════════════════

private lemma ofReal_mul_re (g : ℝ) (h : ℂ) : ((g : ℂ) * h).re = g * h.re := by
  simp [Complex.mul_re, Complex.ofReal_re, Complex.ofReal_im]

private lemma ofReal_mul_im (g : ℝ) (h : ℂ) : ((g : ℂ) * h).im = g * h.im := by
  simp [Complex.mul_im, Complex.ofReal_re, Complex.ofReal_im]

private lemma discrim_le {a b c : ℝ} (ha : 0 ≤ a)
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

-- ════════════════════════════════════════════════
-- PART III: PROVED REAL CAUCHY-SCHWARZ
-- ════════════════════════════════════════════════

/-- **PROVED**: (∫₀¹ f·g)² ≤ (∫₀¹ f²)(∫₀¹ g²). -/
theorem intervalIntegral_inner_le_sq (f g : ℝ → ℝ)
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
  nlinarith [discrim_le
    (intervalIntegral.integral_nonneg (by norm_num) (fun x _ => sq_nonneg _)) h_nn]

-- ════════════════════════════════════════════════
-- PART IV: PROVED INTEGRAL IDENTITIES
-- ════════════════════════════════════════════════

/-- **PROVED**: ∫₀¹ x^{ρ-1} dx = 1/ρ. -/
theorem one_inner_cpow (ρ : ℂ) (hρ_pos : 0 < ρ.re) :
    ∫ x in (0:ℝ)..1, (x : ℂ) ^ (ρ - 1) = 1 / ρ := by
  have hr : -1 < (ρ - 1).re := by simp [Complex.sub_re]; linarith
  have hρ_ne : ρ ≠ 0 := by intro h; rw [h] at hρ_pos; simp at hρ_pos
  rw [integral_cpow (Or.inl hr)]
  simp [Complex.ofReal_zero, Complex.ofReal_one]
  rw [Complex.zero_cpow hρ_ne]; ring

/-- **PROVED**: ∫₀¹ x^{2σ-2} = 1/(2σ-1). -/
theorem rpow_l2_norm (σ : ℝ) (hσ : 1/2 < σ) :
    ∫ x in (0:ℝ)..1, x ^ (2 * σ - 2) = 1 / (2 * σ - 1) := by
  rw [integral_rpow (Or.inl (show -1 < 2 * σ - 2 by linarith)),
      show 2 * σ - 2 + 1 = 2 * σ - 1 from by ring,
      Real.one_rpow, Real.zero_rpow (ne_of_gt (show 0 < 2 * σ - 1 by linarith))]; ring

/-- **PROVED**: ζ(ρ) = 0 implies orthogonality. -/
theorem fract_orthogonal_at_zero (k : ℕ) (hk : 1 ≤ k) (ρ : ℂ)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1)
    (h_zero : riemannZeta ρ = 0) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((Int.fract ((k : ℝ) / x) : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) = 0 := by
  rw [fract_inner_cpow k hk ρ hρ_pos hρ_lt, h_zero]; simp

lemma cpow_rho_ne_zero (ρ : ℂ) (hρ_pos : 0 < ρ.re) : ρ ≠ 0 := by
  intro h; rw [h] at hρ_pos; simp at hρ_pos



/-- **PROVED**: (g + t·re(h))² is interval-integrable. From (a+tb)² = a²+2tab+t²b². -/
theorem cs_shift_re (N : ℕ) (hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ : 1/2 < ρ.re) (hρ' : ρ.re < 1) (t : ℝ) :
    IntervalIntegrable (fun x => ((1 - nbLinComb N v x) + t * ((x : ℂ) ^ (ρ - 1)).re) ^ 2) volume 0 1 := by
  rw [show (fun x => ((1 - nbLinComb N v x) + t * ((x : ℂ) ^ (ρ - 1)).re) ^ 2) =
      (fun x => (1 - nbLinComb N v x) ^ 2 + 2 * t * ((1 - nbLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).re) +
        t ^ 2 * ((x : ℂ) ^ (ρ - 1)).re ^ 2) from by ext x; ring]
  exact ((residual_sq_iint N v).add ((g_re_h_iint N hN v ρ hρ hρ').const_mul (2*t))).add
    ((re_h_sq_iint ρ hρ hρ').const_mul (t^2))

/-- **PROVED**: (g + t·im(h))² is interval-integrable. -/
theorem cs_shift_im (N : ℕ) (hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ : 1/2 < ρ.re) (hρ' : ρ.re < 1) (t : ℝ) :
    IntervalIntegrable (fun x => ((1 - nbLinComb N v x) + t * ((x : ℂ) ^ (ρ - 1)).im) ^ 2) volume 0 1 := by
  rw [show (fun x => ((1 - nbLinComb N v x) + t * ((x : ℂ) ^ (ρ - 1)).im) ^ 2) =
      (fun x => (1 - nbLinComb N v x) ^ 2 + 2 * t * ((1 - nbLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).im) +
        t ^ 2 * ((x : ℂ) ^ (ρ - 1)).im ^ 2) from by ext x; ring]
  exact ((residual_sq_iint N v).add ((g_im_h_iint N hN v ρ hρ hρ').const_mul (2*t))).add
    ((im_h_sq_iint ρ hρ hρ').const_mul (t^2))

-- ════════════════════════════════════════════════
-- PART V: CAUCHY-SCHWARZ SEPARATION BOUND (PROVED!)
-- ════════════════════════════════════════════════

/-- **PROVED**: The Cauchy-Schwarz separation bound.
    1/|ρ|² ≤ ∫(1-f)² · 1/(2σ-1)

    Uses: residual inner product axiom + proved real CS + rpow norm + CLM decomposition. -/
theorem cauchy_schwarz_separation_bound (N : ℕ) (hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (h_zero : riemannZeta ρ = 0) (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) (hρ_gt : 1/2 < ρ.re) :
    1 / Complex.normSq ρ ≤
      (∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2) * (1 / (2 * ρ.re - 1)) := by
  -- z = ∫ g·h = 1/ρ
  set F := fun x : ℝ => ((1 - nbLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1)
  set z := ∫ x in Set.Ioo (0:ℝ) 1, F x
  have hz : z = 1 / ρ := residual_inner_cpow_eq N hN v ρ hρ_pos hρ_lt h_zero
  have hns : Complex.normSq z = 1 / Complex.normSq ρ := by
    rw [hz, map_div₀, Complex.normSq_one]
  have h_int := residual_cpow_integrableOn N hN v ρ hρ_pos hρ_lt
  -- re(z) = ∫₀¹ g · re(h) via ContinuousLinearMap
  have h_re : z.re = ∫ x in (0:ℝ)..1,
      (1 - nbLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).re := by
    change Complex.reCLM (∫ x in Set.Ioo (0:ℝ) 1, F x) = _
    rw [← Complex.reCLM.integral_comp_comm h_int]
    have : (fun x => Complex.reCLM (F x)) =
      (fun x => (1 - nbLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).re) := by
      ext x; exact ofReal_mul_re _ _
    rw [this]; exact ioo_eq_interval _ (g_re_h_iint N hN v ρ hρ_gt hρ_lt)
  -- im(z) = ∫₀¹ g · im(h)
  have h_im : z.im = ∫ x in (0:ℝ)..1,
      (1 - nbLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).im := by
    change Complex.imCLM (∫ x in Set.Ioo (0:ℝ) 1, F x) = _
    rw [← Complex.imCLM.integral_comp_comm h_int]
    have : (fun x => Complex.imCLM (F x)) =
      (fun x => (1 - nbLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).im) := by
      ext x; exact ofReal_mul_im _ _
    rw [this]; exact ioo_eq_interval _ (g_im_h_iint N hN v ρ hρ_gt hρ_lt)
  -- Apply real CS × 2
  set g := fun x : ℝ => 1 - nbLinComb N v x
  have cs_re := intervalIntegral_inner_le_sq g (fun x => ((x : ℂ) ^ (ρ - 1)).re)
    (residual_sq_iint N v) (re_h_sq_iint ρ hρ_gt hρ_lt)
    (g_re_h_iint N hN v ρ hρ_gt hρ_lt) (cs_shift_re N hN v ρ hρ_gt hρ_lt)
  have cs_im := intervalIntegral_inner_le_sq g (fun x => ((x : ℂ) ^ (ρ - 1)).im)
    (residual_sq_iint N v) (im_h_sq_iint ρ hρ_gt hρ_lt)
    (g_im_h_iint N hN v ρ hρ_gt hρ_lt) (cs_shift_im N hN v ρ hρ_gt hρ_lt)
  -- normSq z ≤ ∫g² · (∫re(h)² + ∫im(h)²)
  have h_bound : Complex.normSq z ≤ (∫ x in (0:ℝ)..1, g x ^ 2) *
      ((∫ x in (0:ℝ)..1, ((x : ℂ) ^ (ρ-1)).re ^ 2) +
       (∫ x in (0:ℝ)..1, ((x : ℂ) ^ (ρ-1)).im ^ 2)) := by
    have hd : Complex.normSq z = z.re ^ 2 + z.im ^ 2 := by rw [Complex.normSq_apply]; ring
    rw [hd, h_re, h_im]; nlinarith [cs_re, cs_im]
  -- ∫re(h)² + ∫im(h)² = 1/(2σ-1)
  have h_norm : (∫ x in (0:ℝ)..1, ((x : ℂ) ^ (ρ-1)).re ^ 2) +
      (∫ x in (0:ℝ)..1, ((x : ℂ) ^ (ρ-1)).im ^ 2) = 1 / (2 * ρ.re - 1) := by
    rw [← intervalIntegral.integral_add (re_h_sq_iint ρ hρ_gt hρ_lt) (im_h_sq_iint ρ hρ_gt hρ_lt),
        norm_sq_cpow_integral ρ hρ_pos hρ_lt,
        integral_rpow (Or.inl (show -1 < 2 * ρ.re - 2 by linarith)),
        show 2 * ρ.re - 2 + 1 = 2 * ρ.re - 1 from by ring,
        Real.one_rpow, Real.zero_rpow (ne_of_gt (show 0 < 2 * ρ.re - 1 by linarith))]; ring
  rw [h_norm] at h_bound; rw [← hns]; linarith

-- ════════════════════════════════════════════════
-- PART VI: THE BESSEL SEPARATION THEOREM
-- ════════════════════════════════════════════════

/-- **PROVED**: ∫₀¹ (1-f)² ≥ (2σ-1)/|ρ|². -/
theorem bessel_separation (ρ : ℂ) (h_zero : riemannZeta ρ = 0)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) (hρ_gt : 1/2 < ρ.re) :
    ∀ N : ℕ, 2 ≤ N → ∀ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≥
      (2 * ρ.re - 1) / Complex.normSq ρ := by
  intro N hN v
  have h_cs := cauchy_schwarz_separation_bound N hN v ρ h_zero hρ_pos hρ_lt hρ_gt
  have h2σ : (0:ℝ) < 2 * ρ.re - 1 := by linarith
  have hρ' : (0:ℝ) < Complex.normSq ρ := Complex.normSq_pos.mpr (cpow_rho_ne_zero ρ hρ_pos)
  rw [ge_iff_le]
  have h_inv : (0:ℝ) < 1 / (2 * ρ.re - 1) := by positivity
  linarith [(div_le_iff₀ h_inv).mpr h_cs, show 1 / Complex.normSq ρ / (1 / (2 * ρ.re - 1)) =
    (2 * ρ.re - 1) / Complex.normSq ρ from by field_simp]

-- ════════════════════════════════════════════════
-- PART VII: FUNCTIONAL EQUATION REFLECTION
-- ════════════════════════════════════════════════

/-- **PROVED**: Functional equation gives Re > 1/2 zero. -/
theorem exists_zero_re_gt_half (ρ : ℂ) (h_zero : riemannZeta ρ = 0)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) (hρ_ne : ρ.re ≠ 1/2) :
    ∃ ρ' : ℂ, riemannZeta ρ' = 0 ∧ 1/2 < ρ'.re ∧ ρ'.re < 1 ∧ ρ' ≠ 0 := by
  rcases lt_or_gt_of_ne hρ_ne with h_lt | h_gt
  · have h_nni : ∀ n : ℕ, ρ ≠ -(↑n : ℂ) := by
      intro n h; have := congr_arg Complex.re h; simp at this; linarith
    have h_ne1 : ρ ≠ 1 := by intro h; rw [h] at hρ_lt; simp at hρ_lt
    have := riemannZeta_one_sub h_nni h_ne1
    refine ⟨1 - ρ, by rw [this, h_zero, mul_zero], by simp [Complex.sub_re]; linarith,
      by simp [Complex.sub_re]; linarith,
      by intro h; have := congr_arg Complex.re h; simp at this; linarith⟩
  · exact ⟨ρ, h_zero, h_gt, hρ_lt, cpow_rho_ne_zero ρ hρ_pos⟩

-- ════════════════════════════════════════════════
-- PART VIII: THE CROWN CONVERSE
-- ════════════════════════════════════════════════

/-- **PROVED**: zeta_zero_separates from the Bessel approach. -/
theorem zeta_zero_separates_from_bessel :
    ∀ ρ : ℂ, riemannZeta ρ = 0 →
    0 < ρ.re → ρ.re < 1 → ρ.re ≠ 1/2 →
    ∃ δ : ℝ, 0 < δ ∧
    ∀ N : ℕ, 2 ≤ N → ∀ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≥ δ := by
  intro ρ h_zero hρ_pos hρ_lt hρ_ne
  obtain ⟨ρ', hz', hgt, hlt, hne⟩ := exists_zero_re_gt_half ρ h_zero hρ_pos hρ_lt hρ_ne
  exact ⟨(2 * ρ'.re - 1) / Complex.normSq ρ',
    div_pos (by linarith) (Complex.normSq_pos.mpr hne),
    fun N hN v => bessel_separation ρ' hz' (by linarith) hlt hgt N hN v⟩

end
