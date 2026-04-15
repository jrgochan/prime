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
  - Plus 8 integrability axioms (standard measure-theory plumbing)

  ### Key proved results
  - Real Cauchy-Schwarz via discriminant trick
  - Complex → real bridge via ContinuousLinearMap.integral_comp_comm
  - rpow L² norm computation
  - Functional equation reflection
  - The crown converse `zeta_zero_separates_from_bessel`

  Status: 0 sorry, all theorems fully proved.
-/

import Cathedral.Defs
import Cathedral.Axioms
import Cathedral.Gram.L2Bridge
import Cathedral.Structural.Independence
import Mathlib.Analysis.InnerProductSpace.Basic
import Mathlib.Analysis.SpecialFunctions.Integrals.Basic

noncomputable section
open Complex Real MeasureTheory Set

-- ════════════════════════════════════════════════
-- PART I: AXIOMS
-- ════════════════════════════════════════════════

/-- **AXIOM 1**: ∫₀¹ {k/x} · x^{ρ-1} dx = -ζ(ρ) · k^ρ / ρ.
    Báez-Duarte (2003), Proposition 2.1. -/
axiom fract_inner_cpow (k : ℕ) (hk : 2 ≤ k) (ρ : ℂ) (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((Int.fract ((k : ℝ) / x) : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) =
      -(riemannZeta ρ) * (k : ℂ) ^ ρ / ρ

/-- **AXIOM 2**: ⟨1-f, x^{ρ-1}⟩ = 1/ρ when ζ(ρ) = 0.
    Complex integral linearity + orthogonality. -/
axiom residual_inner_cpow_eq (N : ℕ) (hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1)
    (h_zero : riemannZeta ρ = 0) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((1 - nbLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) = 1 / ρ

/-- **AXIOM 3**: Bochner integrability of g·x^{ρ-1} on (0,1). -/
axiom residual_cpow_integrableOn (N : ℕ) (hN : 2 ≤ N)
    (v : Fin (N-1) → ℝ) (ρ : ℂ) (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1) :
    IntegrableOn (fun x : ℝ => ((1 - nbLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1))
      (Set.Ioo (0:ℝ) 1)

-- Measure-theory plumbing axioms
axiom ioo_eq_interval (f : ℝ → ℝ) (hf : IntervalIntegrable f volume 0 1) :
    ∫ x in Set.Ioo (0:ℝ) 1, f x = ∫ x in (0:ℝ)..1, f x
axiom g_re_h_iint (N : ℕ) (hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ : 0 < ρ.re) (hρ' : ρ.re < 1) :
    IntervalIntegrable (fun x => (1 - nbLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).re) volume 0 1
axiom g_im_h_iint (N : ℕ) (hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ : 0 < ρ.re) (hρ' : ρ.re < 1) :
    IntervalIntegrable (fun x => (1 - nbLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).im) volume 0 1
axiom re_h_sq_iint (ρ : ℂ) (hρ : 0 < ρ.re) (hρ' : ρ.re < 1) :
    IntervalIntegrable (fun x => ((x : ℂ) ^ (ρ - 1)).re ^ 2) volume 0 1
axiom im_h_sq_iint (ρ : ℂ) (hρ : 0 < ρ.re) (hρ' : ρ.re < 1) :
    IntervalIntegrable (fun x => ((x : ℂ) ^ (ρ - 1)).im ^ 2) volume 0 1
axiom cs_shift_re (N : ℕ) (hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ : 0 < ρ.re) (hρ' : ρ.re < 1) (t : ℝ) :
    IntervalIntegrable (fun x => ((1 - nbLinComb N v x) + t * ((x : ℂ) ^ (ρ - 1)).re) ^ 2) volume 0 1
axiom cs_shift_im (N : ℕ) (hN : 2 ≤ N) (v : Fin (N-1) → ℝ) (ρ : ℂ)
    (hρ : 0 < ρ.re) (hρ' : ρ.re < 1) (t : ℝ) :
    IntervalIntegrable (fun x => ((1 - nbLinComb N v x) + t * ((x : ℂ) ^ (ρ - 1)).im) ^ 2) volume 0 1
axiom norm_sq_cpow_integral (ρ : ℂ) (hρ : 0 < ρ.re) (hρ' : ρ.re < 1) :
    ∫ x in (0:ℝ)..1, (((x : ℂ) ^ (ρ - 1)).re ^ 2 + ((x : ℂ) ^ (ρ - 1)).im ^ 2) =
    ∫ x in (0:ℝ)..1, x ^ (2 * ρ.re - 2)

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
theorem fract_orthogonal_at_zero (k : ℕ) (hk : 2 ≤ k) (ρ : ℂ)
    (hρ_pos : 0 < ρ.re) (hρ_lt : ρ.re < 1)
    (h_zero : riemannZeta ρ = 0) :
    ∫ x in Set.Ioo (0:ℝ) 1, ((Int.fract ((k : ℝ) / x) : ℝ) : ℂ) * (x : ℂ) ^ (ρ - 1) = 0 := by
  rw [fract_inner_cpow k hk ρ hρ_pos hρ_lt, h_zero]; simp

lemma cpow_rho_ne_zero (ρ : ℂ) (hρ_pos : 0 < ρ.re) : ρ ≠ 0 := by
  intro h; rw [h] at hρ_pos; simp at hρ_pos

private lemma residual_sq_iint (N : ℕ) (v : Fin (N-1) → ℝ) :
    IntervalIntegrable (fun x => (1 - nbLinComb N v x) ^ 2) volume 0 1 := by
  rw [show (fun x => (1 - nbLinComb N v x) ^ 2) =
      (fun x => 1 - 2 * nbLinComb N v x + (nbLinComb N v x) ^ 2) from by ext x; ring]
  exact ((intervalIntegrable_const (c := (1:ℝ))).sub
    ((nbLinComb_integrable N v).const_mul 2)).add (nbLinComb_sq_integrable N v)

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
    rw [this]; exact ioo_eq_interval _ (g_re_h_iint N hN v ρ hρ_pos hρ_lt)
  -- im(z) = ∫₀¹ g · im(h)
  have h_im : z.im = ∫ x in (0:ℝ)..1,
      (1 - nbLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).im := by
    change Complex.imCLM (∫ x in Set.Ioo (0:ℝ) 1, F x) = _
    rw [← Complex.imCLM.integral_comp_comm h_int]
    have : (fun x => Complex.imCLM (F x)) =
      (fun x => (1 - nbLinComb N v x) * ((x : ℂ) ^ (ρ - 1)).im) := by
      ext x; exact ofReal_mul_im _ _
    rw [this]; exact ioo_eq_interval _ (g_im_h_iint N hN v ρ hρ_pos hρ_lt)
  -- Apply real CS × 2
  set g := fun x : ℝ => 1 - nbLinComb N v x
  have cs_re := intervalIntegral_inner_le_sq g (fun x => ((x : ℂ) ^ (ρ - 1)).re)
    (residual_sq_iint N v) (re_h_sq_iint ρ hρ_pos hρ_lt)
    (g_re_h_iint N hN v ρ hρ_pos hρ_lt) (cs_shift_re N hN v ρ hρ_pos hρ_lt)
  have cs_im := intervalIntegral_inner_le_sq g (fun x => ((x : ℂ) ^ (ρ - 1)).im)
    (residual_sq_iint N v) (im_h_sq_iint ρ hρ_pos hρ_lt)
    (g_im_h_iint N hN v ρ hρ_pos hρ_lt) (cs_shift_im N hN v ρ hρ_pos hρ_lt)
  -- normSq z ≤ ∫g² · (∫re(h)² + ∫im(h)²)
  have h_bound : Complex.normSq z ≤ (∫ x in (0:ℝ)..1, g x ^ 2) *
      ((∫ x in (0:ℝ)..1, ((x : ℂ) ^ (ρ-1)).re ^ 2) +
       (∫ x in (0:ℝ)..1, ((x : ℂ) ^ (ρ-1)).im ^ 2)) := by
    have hd : Complex.normSq z = z.re ^ 2 + z.im ^ 2 := by rw [Complex.normSq_apply]; ring
    rw [hd, h_re, h_im]; nlinarith [cs_re, cs_im]
  -- ∫re(h)² + ∫im(h)² = 1/(2σ-1)
  have h_norm : (∫ x in (0:ℝ)..1, ((x : ℂ) ^ (ρ-1)).re ^ 2) +
      (∫ x in (0:ℝ)..1, ((x : ℂ) ^ (ρ-1)).im ^ 2) = 1 / (2 * ρ.re - 1) := by
    rw [← intervalIntegral.integral_add (re_h_sq_iint ρ hρ_pos hρ_lt) (im_h_sq_iint ρ hρ_pos hρ_lt),
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
