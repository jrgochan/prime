/-
  Cathedral/White/Infrastructure/Perron/PerronMoebius.lean

  The Perron-Moebius Chain: M(x) = O(x^{1/2+eps}) under RH

  Architecture:
  1. perron_moebius_contour_shift: Contour shift Re=c to Re=sigma0
     - Sub-lemmas: integrand diffOn, rectangle identity, Schwarz reflection
  2. truncated_perron_for_moebius: M(x) approx contour integral
     - Sub-lemmas: sum-integral swap, tail truncation
  3. mertens_bound_eps: RH implies M(x) = O(x^{1/2+eps})
  4. mertens_bound_eps_implies_original: O(x^{1/2+eps}) implies O(x^{3/4}) (PROVED)

  Key Dependencies (all PROVED):
  - Perron/Formula.lean: perron_formula_error_bound
  - DirichletZetaInverse.lean: moebius_lseries_eq_inv_zeta
  - ZetaConvexity.lean: inv_zeta_bound_under_rh,
      perron_integrand_bound_with_zeta, perron_horizontal_contour_vanishes
-/

import Cathedral.White.Infrastructure.Perron.Formula
import Cathedral.White.Infrastructure.DirichletZetaInverse
import Cathedral.White.Infrastructure.ZetaConvexity

noncomputable section
open Complex Real MeasureTheory Set Filter ArithmeticFunction
open scoped LSeries.notation ArithmeticFunction.Moebius ArithmeticFunction.zeta Topology

namespace Cathedral.White.Infrastructure

-- ═══════════════════════════════════════════
-- §1. Sub-lemmas for the Contour Shift
-- ═══════════════════════════════════════════

/-- **ContinuousOn** for the integrand x^s/(s·ζ(s)) on the rectangle.
    riemannZeta is defined (finite) at all s including s=1, and s·ζ(s) ≠ 0
    at every point of the rectangle (s ≠ 0 since Re(s) > 1/2,
    and ζ(s) ≠ 0 for Re(s) > 1/2 under RH, except at s=1 where ζ(1) ≠ 0
    by definition). -/
private lemma perron_moebius_integrand_continuousOn (_hRH : RiemannHypothesis)
    (x sigma0 c T : ℝ) (_hx : 1 < x) (_hsigma0 : 1/2 < sigma0)
    (_hc : 1 < c) (_hsigma0_c : sigma0 < c) (_hT : 0 < T) :
    ContinuousOn (fun s => (x : ℂ) ^ s / (s * riemannZeta s))
      (Set.uIcc sigma0 c ×ℂ Set.uIcc (-T) T) := by
  -- riemannZeta is continuous on ℂ (defined everywhere, including s=1).
  -- x^s is continuous (x > 0 ∈ slitPlane).
  -- s·ζ(s) ≠ 0 on the rectangle: s ≠ 0 (Re > 1/2) and ζ(s) ≠ 0 (RH).
  sorry

/-- **PROVED**: The integrand x^s/(s·ζ(s)) is DifferentiableAt for s ≠ 1
    with Re(s) > 1/2 under RH.
    Uses: differentiableAt_riemannZeta (Mathlib), rh_zeta_ne_zero,
    DifferentiableAt.cpow, .div, .mul. -/
private lemma perron_moebius_integrand_diffAt (hRH : RiemannHypothesis)
    (x : ℝ) (hx : 1 < x) (s : ℂ) (hs_re : 1/2 < s.re) (hs_ne : s ≠ 1) :
    DifferentiableAt ℂ (fun s => (x : ℂ) ^ s / (s * riemannZeta s)) s := by
  have hx_pos : (0 : ℝ) < x := by linarith
  have hs_ne_zero : s ≠ 0 := by
    intro h; rw [h] at hs_re; simp at hs_re; linarith
  have hζ_ne : riemannZeta s ≠ 0 := rh_zeta_ne_zero hRH hs_re hs_ne
  have hsζ_ne : s * riemannZeta s ≠ 0 := mul_ne_zero hs_ne_zero hζ_ne
  exact DifferentiableAt.div
    (DifferentiableAt.const_cpow differentiableAt_id
      (Or.inl (Complex.ofReal_ne_zero.mpr (ne_of_gt hx_pos))))
    (differentiableAt_id.mul (differentiableAt_riemannZeta hs_ne))
    hsζ_ne

/-- **Rectangle Identity** via Cauchy-Goursat off_countable.
    Uses: integral_boundary_rect_eq_zero_of_differentiable_on_off_countable
    with exceptional set {1} (the pole of ζ).
    Sub-lemmas: perron_moebius_integrand_continuousOn (sorry),
    perron_moebius_integrand_diffAt (PROVED). -/
private lemma perron_moebius_rect (hRH : RiemannHypothesis)
    (x sigma0 c T : ℝ) (hx : 1 < x) (hsigma0 : 1/2 < sigma0)
    (hc : 1 < c) (hsigma0_c : sigma0 < c) (hT : 0 < T) :
    ‖∫ t in (-T)..T,
        ((x : ℂ) ^ (↑c + ↑t * I) / ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I)) -
         (x : ℂ) ^ (↑sigma0 + ↑t * I) / ((↑sigma0 + ↑t * I) *
           riemannZeta (↑sigma0 + ↑t * I)))‖ ≤
    (∫ σ in sigma0..c,
        ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖) +
    (∫ σ in sigma0..c,
        ‖(x : ℂ)^(↑σ + ↑(-T) * I) / ((↑σ + ↑(-T) * I) * riemannZeta (↑σ + ↑(-T) * I))‖) := by
  -- Step 1: Apply Cauchy-Goursat with exceptional set {1}
  set f := fun s => (x : ℂ) ^ s / (s * riemannZeta s) with _hf_def
  have hCG := Complex.integral_boundary_rect_eq_zero_of_differentiable_on_off_countable
    f ⟨sigma0, -T⟩ ⟨c, T⟩ {1} (Set.countable_singleton 1)
    (perron_moebius_integrand_continuousOn hRH x sigma0 c T hx hsigma0 hc hsigma0_c hT)
    (fun s ⟨hs_mem, hs_ne⟩ => by
      have hs_re : 1/2 < s.re := by
        have := (Complex.mem_reProdIm.mp hs_mem).1
        simp [Set.mem_Ioo, min_eq_left hsigma0_c.le, max_eq_right hsigma0_c.le] at this
        linarith
      have hs1 : s ≠ 1 := fun h => hs_ne (Set.mem_singleton_iff.mpr h)
      exact perron_moebius_integrand_diffAt hRH x hx s hs_re hs1)
  -- Step 2: Simplify the CG identity (remove smul_eq_mul)
  simp only [smul_eq_mul] at hCG
  -- hCG : (∫ σ in sigma0..c, f(σ+(-T)I)) - (∫ σ in sigma0..c, f(σ+TI))
  --       + I*(∫ t in (-T)..T, f(c+tI)) - I*(∫ t in (-T)..T, f(σ₀+tI)) = 0
  -- Step 3: Extract ‖∫f_right - ∫f_left‖ ≤ ‖∫f_bot‖ + ‖∫f_top‖
  have h_rearr : I * (∫ t in (-T)..T, f (↑c + ↑t * I)) -
      I * (∫ t in (-T)..T, f (↑sigma0 + ↑t * I)) =
    (∫ σ in sigma0..c, f (↑σ + ↑T * I)) -
    (∫ σ in sigma0..c, f (↑σ + ↑(-T) * I)) := by
    -- hCG: bot - top + I*right - I*left = 0
    -- Group: (bot - top) + (I*right - I*left) = 0
    -- So: I*right - I*left = -(bot - top) = top - bot
    set bot := ∫ σ in sigma0..c, f (↑σ + ↑(-T) * I)
    set top := ∫ σ in sigma0..c, f (↑σ + ↑T * I)
    set right := ∫ t in (-T)..T, f (↑c + ↑t * I)
    set left := ∫ t in (-T)..T, f (↑sigma0 + ↑t * I)
    -- hCG: (bot - top) + I * right - I * left = 0
    have h0 : (bot - top) + (I * right - I * left) = 0 := by ring_nf; ring_nf at hCG; exact hCG
    have := eq_neg_of_add_eq_zero_right h0
    -- this: I * right - I * left = -(bot - top) = top - bot
    rw [this, neg_sub]
  -- ‖I*(C - D)‖ = ‖C - D‖
  have h_norm_eq : ‖(∫ t in (-T)..T, f (↑c + ↑t * I)) -
      (∫ t in (-T)..T, f (↑sigma0 + ↑t * I))‖ =
    ‖(∫ σ in sigma0..c, f (↑σ + ↑T * I)) -
     (∫ σ in sigma0..c, f (↑σ + ↑(-T) * I))‖ := by
    have : I * ((∫ t in (-T)..T, f (↑c + ↑t * I)) -
        (∫ t in (-T)..T, f (↑sigma0 + ↑t * I))) =
      (∫ σ in sigma0..c, f (↑σ + ↑T * I)) -
      (∫ σ in sigma0..c, f (↑σ + ↑(-T) * I)) := by
      rw [mul_sub]; exact h_rearr
    rw [← this, norm_mul, Complex.norm_I, one_mul]
  -- Step 4: ‖∫ (f_c - f_σ₀)‖ = ‖∫ f_c - ∫ f_σ₀‖ (linearity)
  -- The LHS of the goal is ‖∫(f_c(t) - f_σ₀(t)) dt‖
  -- which equals ‖(∫ f_c) - (∫ f_σ₀)‖ by integral linearity
  -- Step 5: Chain the bounds
  -- The LHS is ‖∫ t, (f_c(t) - f_σ₀(t))‖.
  -- We know ∫ t, f_c(t) - f_σ₀(t) = ∫ f_c - ∫ f_σ₀  (by linearity, when both integrable)
  -- and ‖∫ f_c - ∫ f_σ₀‖ ≤ ‖∫ f_top‖ + ‖∫ f_bot‖ ≤ ∫‖f_top‖ + ∫‖f_bot‖.
  -- Use ContinuousOn → integrable from the ContinuousOn sorry
  -- Integrability of vertical integrands (follows from integrand_continuousOn sorry)
  have h_int_c : IntervalIntegrable (fun t => f (↑c + ↑t * I)) volume (-T) T := sorry
  have h_int_s : IntervalIntegrable (fun t => f (↑sigma0 + ↑t * I)) volume (-T) T := sorry
  -- Convert the goal to use `f`
  change ‖∫ t in (-T)..T, (f (↑c + ↑t * I) - f (↑sigma0 + ↑t * I))‖ ≤
    (∫ σ in sigma0..c, ‖f (↑σ + ↑T * I)‖) +
    (∫ σ in sigma0..c, ‖f (↑σ + ↑(-T) * I)‖)
  calc ‖∫ t in (-T)..T, (f (↑c + ↑t * I) - f (↑sigma0 + ↑t * I))‖
      = ‖(∫ t in (-T)..T, f (↑c + ↑t * I)) -
         (∫ t in (-T)..T, f (↑sigma0 + ↑t * I))‖ := by
        congr 1; exact intervalIntegral.integral_sub h_int_c h_int_s
    _ = ‖(∫ σ in sigma0..c, f (↑σ + ↑T * I)) -
         (∫ σ in sigma0..c, f (↑σ + ↑(-T) * I))‖ := h_norm_eq
    _ ≤ ‖∫ σ in sigma0..c, f (↑σ + ↑T * I)‖ +
        ‖∫ σ in sigma0..c, f (↑σ + ↑(-T) * I)‖ := norm_sub_le _ _
    _ ≤ (∫ σ in sigma0..c, ‖f (↑σ + ↑T * I)‖) +
        (∫ σ in sigma0..c, ‖f (↑σ + ↑(-T) * I)‖) :=
        add_le_add
          (intervalIntegral.norm_integral_le_integral_norm hsigma0_c.le)
          (intervalIntegral.norm_integral_le_integral_norm hsigma0_c.le)

/-- For real σ, T: σ + (-T)i = conj(σ + Ti). -/
private lemma conj_sigma_sub_ti (σ T : ℝ) :
    (↑σ : ℂ) + ↑(-T) * I = starRingEnd ℂ ((↑σ : ℂ) + ↑T * I) := by
  have h1 : (↑(-T) : ℂ) = -(↑T : ℂ) := by push_cast; ring
  rw [h1, neg_mul, map_add, Complex.conj_ofReal, map_mul, Complex.conj_ofReal,
      Complex.conj_I, mul_neg]

/-- arg(n : ℂ) = 0 for n : ℕ, since ↑n ≥ 0 on the real axis. -/
private lemma arg_natCast' (n : ℕ) : (n : ℂ).arg = 0 := by
  rw [show (n : ℂ) = ((n : ℝ) : ℂ) from by push_cast; ring]
  exact Complex.arg_ofReal_of_nonneg (Nat.cast_nonneg n)

/-- **PROVED**: conj(n^s) = n^(conj s) for n : ℕ, n > 0.
    Uses cpow_conj from Mathlib + the fact that arg(n) = 0 ≠ π. -/
private lemma conj_natCast_cpow (n : ℕ) (_hn : 0 < n) (s : ℂ) :
    starRingEnd ℂ ((n : ℂ) ^ s) = (n : ℂ) ^ (starRingEnd ℂ s) := by
  have h_arg : (n : ℂ).arg ≠ Real.pi := by rw [arg_natCast']; exact Real.pi_ne_zero.symm
  have h := Complex.cpow_conj (n : ℂ) s h_arg
  rw [show (starRingEnd ℂ) (n : ℂ) = (n : ℂ) from by
    rw [show (n : ℂ) = ((n : ℝ) : ℂ) from by push_cast; ring]; exact Complex.conj_ofReal _] at h
  exact h.symm

/-- **PROVED**: conj(term 1 s n) = term 1 (conj s) n for each n.
    Termwise conjugation of the ζ Dirichlet series. -/
private lemma conj_lseries_term (n : ℕ) (s : ℂ) :
    starRingEnd ℂ (LSeries.term 1 s n) = LSeries.term 1 (starRingEnd ℂ s) n := by
  unfold LSeries.term
  by_cases hn : n = 0
  · simp [hn]
  · simp only [hn, ↓reduceIte, Pi.one_apply, map_div₀, map_one]
    congr 1
    exact conj_natCast_cpow n (Nat.pos_of_ne_zero hn) s

/-- **PROVED**: Schwarz reflection for ζ when Re(s) > 1.
    ζ(conj s) = conj(ζ(s)) from the L-series + tsum conjugation. -/
private lemma riemannZeta_conj_re_gt {s : ℂ} (hs : 1 < s.re) :
    riemannZeta (starRingEnd ℂ s) = starRingEnd ℂ (riemannZeta s) := by
  have hs_conj : 1 < (starRingEnd ℂ s).re := by rw [Complex.conj_re]; exact hs
  rw [← LSeries_one_eq_riemannZeta hs_conj, ← LSeries_one_eq_riemannZeta hs]
  show LSeries 1 (starRingEnd ℂ s) = starRingEnd ℂ (LSeries 1 s)
  have h_sum : Summable (fun n => LSeries.term 1 s n) := LSeriesSummable_one_iff.mpr hs
  have h_tsum : starRingEnd ℂ (∑' n, LSeries.term 1 s n) =
      ∑' n, starRingEnd ℂ (LSeries.term 1 s n) :=
    Complex.conjCLE.toContinuousLinearMap.map_tsum h_sum
  simp only [LSeries]
  rw [h_tsum]
  congr 1; ext n
  exact (conj_lseries_term n s).symm

/-- Schwarz reflection for ζ: ζ(conj s) = conj(ζ(s)) for ALL s.
    PROVED for Re(s) > 1 via riemannZeta_conj_re_gt.
    The general case extends by uniqueness of meromorphic continuation
    (both sides are meromorphic and agree on {Re > 1}). -/
private lemma riemannZeta_conj (s : ℂ) :
    riemannZeta (starRingEnd ℂ s) = starRingEnd ℂ (riemannZeta s) := by
  -- For Re(s) > 1: proved above via L-series
  -- For Re(s) ≤ 1: follows by analytic continuation / functional equation
  -- Both sides are meromorphic in s and agree on the half-plane {Re > 1},
  -- hence they agree everywhere by the identity theorem.
  sorry

/-- Horizontal integral at height -T has the same norm as at height T.
    Uses Schwarz reflection: ζ(s̄) = ζ̄(s), hence ‖f(σ-Ti)‖ = ‖f(σ+Ti)‖
    for the integrand f(s) = x^s/(s·ζ(s)) with x > 0 real.

    PROVED modulo riemannZeta_conj (standard Schwarz reflection for ζ). -/
private lemma perron_horiz_neg_eq_pos (x sigma0 c T : ℝ) (hx : 1 < x) (_hT : 0 < T) :
    (∫ σ in sigma0..c,
        ‖(x : ℂ)^(↑σ + ↑(-T) * I) / ((↑σ + ↑(-T) * I) * riemannZeta (↑σ + ↑(-T) * I))‖) =
    (∫ σ in sigma0..c,
        ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖) := by
  congr 1; ext σ
  have hx_pos : (0 : ℝ) < x := by linarith
  -- Rewrite σ + (-T)i = conj(σ + Ti)
  rw [conj_sigma_sub_ti]
  -- Decompose norms and simplify
  simp only [norm_div, norm_mul]
  -- Now the goal splits into three factors:
  -- (1) ‖x^(conj s)‖ = x^Re(conj s) = x^Re(s) = ‖x^s‖
  -- (2) ‖conj s‖ = ‖s‖
  -- (3) ‖ζ(conj s)‖ = ‖conj(ζ(s))‖ = ‖ζ(s)‖
  rw [norm_cpow_eq_rpow_re_of_pos hx_pos, norm_cpow_eq_rpow_re_of_pos hx_pos,
      Complex.conj_re, RCLike.norm_conj,
      riemannZeta_conj, RCLike.norm_conj]

-- ═══════════════════════════════════════════
-- §2. The Contour Shift (assembly — zero new sorry)
-- ═══════════════════════════════════════════

/-- **The Contour Shift under RH**: The difference of vertical
    Perron integrals at Re=c and Re=σ₀ tends to zero.

    Assembly of: rectangle identity + Schwarz reflection + horizontal vanishing.
    All sorry are in the sub-lemmas above; this assembly is PROVED. -/
theorem perron_moebius_contour_shift (hRH : RiemannHypothesis)
    (x sigma0 c : ℝ) (hx : 1 < x) (hsigma0 : 1/2 < sigma0)
    (hc : 1 < c) (hsigma0_c : sigma0 < c) :
    Tendsto (fun T : ℝ =>
      ‖∫ t in (-T)..T,
        ((x : ℂ) ^ (↑c + ↑t * I) / ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I)) -
         (x : ℂ) ^ (↑sigma0 + ↑t * I) / ((↑sigma0 + ↑t * I) *
           riemannZeta (↑sigma0 + ↑t * I)))‖)
    atTop (nhds 0) := by
  -- Horizontal contour integral → 0 (PROVED in ZetaConvexity.lean)
  have h_horiz := perron_horizontal_contour_vanishes x c sigma0 hx hc hsigma0 hsigma0_c hRH
  -- Squeeze to zero
  apply squeeze_zero'
  · -- Nonneg
    exact Filter.Eventually.of_forall fun T => norm_nonneg _
  · -- Upper bound: eventually use rectangle identity
    apply Filter.Eventually.mono (Filter.eventually_gt_atTop 0)
    intro T hT_pos
    -- Rectangle identity + Schwarz reflection give:
    -- ‖∫(f_c - f_σ₀)‖ ≤ ∫‖horiz_top‖ + ∫‖horiz_bot‖ = 2·∫‖horiz_top‖
    calc _ ≤ (∫ σ in sigma0..c,
            ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖) +
          (∫ σ in sigma0..c,
            ‖(x : ℂ)^(↑σ + ↑(-T) * I) / ((↑σ + ↑(-T) * I) * riemannZeta (↑σ + ↑(-T) * I))‖) :=
        perron_moebius_rect hRH x sigma0 c T hx hsigma0 hc hsigma0_c hT_pos
      _ = (∫ σ in sigma0..c,
            ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖) +
          (∫ σ in sigma0..c,
            ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖) := by
        rw [perron_horiz_neg_eq_pos x sigma0 c T hx hT_pos]
      _ = 2 * (∫ σ in sigma0..c,
            ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖) := by
        ring
  · -- 2 × (something → 0) → 0
    -- h_horiz + h_horiz → 0+0 = 0, and 2f = f + f
    have h_sum := h_horiz.add h_horiz
    simp only [add_zero] at h_sum
    refine h_sum.congr (fun T => ?_)
    ring

-- ═══════════════════════════════════════════
-- §3. Sub-lemmas for the Truncated Perron Formula
-- ═══════════════════════════════════════════

/-- **PROVED**: Integrability of the Perron integrand on [-T, T] for y > 0.
    Uses: ContinuousOn.cpow (base in slitPlane since y > 0) + ContinuousOn.div. -/
private lemma perron_integrand_intervalIntegrable (y c T : ℝ) (hc : 0 < c) (hy : 0 < y) :
    IntervalIntegrable (fun t : ℝ =>
      (y : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I))
      MeasureTheory.volume (-T) T := by
  apply ContinuousOn.intervalIntegrable
  apply ContinuousOn.div
  · exact ContinuousOn.cpow continuousOn_const (by fun_prop)
      (fun _ _ => Complex.ofReal_mem_slitPlane.mpr hy)
  · fun_prop
  · intro t _ h; have := congr_arg Complex.re h
    simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im] at this
    linarith

/-- **PROVED (modulo integrability)**: Sum-integral swap for finite Dirichlet polynomials.
    Uses: Finset.mul_sum, intervalIntegral.integral_const_mul,
    intervalIntegral.integral_finset_sum.

    The only sorry is `perron_integrand_intervalIntegrable` (continuity of y^s/s). -/
private lemma finite_sum_integral_swap
    (a : ℕ → ℂ) (x c T : ℝ) (S : Finset ℕ)
    (hc : 0 < c) (_hT : 0 < T) (_hx : 1 < x) :
    ∑ n ∈ S, a n * perronIntegral (x / ↑n) c T =
    (1 / (2 * Real.pi)) • ∫ t in (-T)..T,
      ∑ n ∈ S, a n * ((x / ↑n : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)) := by
  -- Step 1: Unfold perronIntegral and fix casts
  simp only [perronIntegral, perronIntegrand]
  have h_cast : ∀ n : ℕ, (↑(x / ↑n) : ℂ) = (↑x : ℂ) / (↑n : ℂ) := by
    intro n; push_cast; ring
  simp_rw [h_cast]
  -- Step 2: Convert RHS ℝ-smul to ℂ-mul
  rw [show (1 / (2 * π) : ℝ) • (∫ t in (-T)..T,
      ∑ n ∈ S, a n * ((↑x / ↑n : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I))) =
    1 / (2 * (↑π : ℂ)) * ∫ t in (-T)..T,
      ∑ n ∈ S, a n * ((↑x / ↑n : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)) from by
    simp [Complex.ofReal_mul, Complex.ofReal_ofNat]]
  -- Step 3: Factor 1/(2π) out of the sum
  trans 1 / (2 * (↑π : ℂ)) * ∑ n ∈ S, a n * ∫ t in (-T)..T,
      (↑x / ↑n : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)
  · rw [Finset.mul_sum]; congr 1; ext n; ring
  congr 1
  -- Step 4: Pull a(n) into integral
  trans ∑ n ∈ S, ∫ t in (-T)..T,
      a n * ((↑x / ↑n : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I))
  · congr 1; ext n; exact (intervalIntegral.integral_const_mul _ _).symm
  -- Step 5: Swap sum and integral (by integral_finset_sum)
  symm
  apply intervalIntegral.integral_finset_sum
  -- Each summand a(n) * ((↑x/↑n)^(c+tI)/(c+tI)) is integrable on [-T,T]
  -- Uses perron_integrand_intervalIntegrable with y = x/n > 0
  intro n _
  apply IntervalIntegrable.const_mul
  -- Need: IntervalIntegrable (fun t => (↑x / ↑n : ℂ)^(c+tI)/(c+tI))
  -- This is the same as perron_integrand_intervalIntegrable (x/n) c T hc
  -- once we identify ↑(x/↑n : ℝ) with (↑x/↑n : ℂ)
  have : (fun t : ℝ => (↑x / ↑n : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)) =
    (fun t : ℝ => (↑(x / ↑n) : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)) := by
    ext t; congr 1; push_cast; ring
  rw [this]
  by_cases hn : n = 0
  · -- n = 0 case: x/0 = 0, and 0^(c+tI)/(c+tI) = 0 since c+tI ≠ 0
    subst hn; simp only [Nat.cast_zero, div_zero, Complex.ofReal_zero]
    have h_zero : (fun t : ℝ => (0 : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)) =
        (fun _ => (0 : ℂ)) := by
      ext t; have : ↑c + ↑t * I ≠ (0 : ℂ) := by
        intro h; have := congr_arg Complex.re h
        simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re,
              Complex.I_re, Complex.I_im] at this; linarith
      simp [Complex.zero_cpow this]
    rw [h_zero]; exact intervalIntegrable_const
  · exact perron_integrand_intervalIntegrable _ c T hc
      (div_pos (by linarith) (Nat.cast_pos.mpr (Nat.pos_of_ne_zero hn)))

/-- **Dirichlet polynomial identification**: For Re(s) > 1,
    Σ_{n≤N} μ(n)/n^s approximates 1/ζ(s) with tail O(N^{1-Re(s)}).
    Uses moebius_lseries_eq_inv_zeta (PROVED in DirichletZetaInverse.lean). -/
private lemma moebius_partial_sum_approx (N : ℕ) (s : ℂ) (_hs : 1 < s.re) :
    ‖∑ n ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius n) : ℂ) / (↑n : ℂ) ^ s -
      (1 / riemannZeta s)‖ ≤ (↑N : ℝ) ^ (1 - s.re) / (s.re - 1) := by
  sorry

-- ═══════════════════════════════════════════
-- §4. The Truncated Perron Formula
-- ═══════════════════════════════════════════

/-- The Truncated Perron Formula for M(x): For c > 1 and large T,
    M(x) is approximated by the contour integral of x^s/(s zeta(s))
    on Re(s) = c, up to O(x^c/T).

    Building blocks (all PROVED):
    1. perron_kernel_bound: each mu(n) P(x/n) approximates mu(n)
    2. perron_formula_error_bound: aggregate error control
    3. moebius_lseries_eq_inv_zeta: sum mu(n)/n^s = 1/zeta(s)

    Step-by-step:
    (a) M(x) = sum_{n<=x} mu(n) * 1
    (b) perron_kernel_gt_one: P(x/n,c,T) = 1 + O((x/n)^c / (T |log(x/n)|))
    (c) So M(x) = sum_{n<=x} mu(n) * P(x/n,c,T) - sum_{n<=x} mu(n) * (P-1)
    (d) |error| <= sum_{n<=x} (x/n)^c / (pi T |log(x/n)|)
        by perron_formula_error_bound (PROVED)
    (e) sum mu(n) * P(x/n,c,T) swaps sum and integral (finite sum!)
        = (1/2pi) integral sum mu(n) (x/n)^{c+it} / (c+it) dt
    (f) For Re(s) > 1: sum mu(n)/n^s = 1/zeta(s) - tail
        by moebius_lseries_eq_inv_zeta (PROVED)
    (g) So M(x) approx (1/2pi) integral x^s / (s zeta(s)) dt + errors

    Assembly of sub-lemmas. Sorry covers measure theory bookkeeping. -/
theorem truncated_perron_for_moebius (x c : ℝ) (hx : 2 ≤ x) (hc : 1 < c) :
    ∃ K > 0, ∀ T : ℝ, 1 ≤ T →
      |(↑(summatoryMoebius x : ℤ) : ℝ)| ≤
        (1 / (2 * Real.pi)) *
          ∫ t in (-T)..T,
            ‖(x : ℂ) ^ (↑c + ↑t * I) /
              ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I))‖ +
        K * x ^ c / T := by
  -- Decomposition:
  -- (1) M(x) = Σ μ(n) = Σ μ(n)·P(x/n) - Σ μ(n)·(P(x/n)-1)
  -- (2) |error| ≤ K·x^c/T by perron_formula_error_bound (PROVED)
  -- (3) Σ μ(n)·P(x/n) = (1/2π)∫ Σ μ(n)(x/n)^s/s dt by finite_sum_integral_swap
  -- (4) Σ μ(n)/n^s ≈ 1/ζ(s) by moebius_partial_sum_approx
  -- (5) Combining: ≈ (1/2π)∫ x^s/(s·ζ(s)) dt
  --
  -- The sorry here covers the integration bookkeeping.
  sorry

-- ═══════════════════════════════════════════
-- §5. The Final Assembly: M(x) = O(x^{1/2+eps})
-- ═══════════════════════════════════════════

/-- Under RH, M(x) = O(x^{1/2+eps}) for any eps > 0.

    Proof: Combine §2 (contour shift) + §4 (truncated Perron) + inv_zeta_bound_under_rh.
    Set sigma0 = 1/2 + eps/2, c = 1 + eps, T = x.

    1. |M(x)| <= (1/2pi) integral_{Re=c} + O(x^c/T)  (§4)
    2. integral_{Re=c} = integral_{Re=sigma0} + o(1)   (§2)
    3. integral_{Re=sigma0} <= C x^{sigma0} T^{eps/2}   (inv_zeta_bound_under_rh)
    4. Combined with T = x: M(x) = O(x^{1/2+eps}) -/
theorem mertens_bound_eps (hRH : RiemannHypothesis) (eps : ℝ) (heps : 0 < eps) :
    ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((summatoryMoebius x : ℤ) : ℝ)| ≤ C * x ^ ((1 : ℝ)/2 + eps) := by
  -- Parameter choices:
  set sigma0 := 1/2 + eps/2 with _hσ₀_def
  set c := 1 + eps with _hc_def
  have hsigma0 : 1/2 < sigma0 := by linarith
  have hc : 1 < c := by linarith
  have hsigma0_c : sigma0 < c := by linarith
  -- Combine contour shift + truncated Perron + Lindelöf bound
  have _hshift := perron_moebius_contour_shift hRH
  have _hperron := @truncated_perron_for_moebius
  have _hbound := inv_zeta_bound_under_rh hRH (eps/2) (by linarith)
  sorry

-- ═══════════════════════════════════════════
-- §6. From eps to the original form (PROVED)
-- ═══════════════════════════════════════════

/-- **PROVED**: The eps-version implies the 3/4-power version.
    Specializes eps = 1/4: |M(x)| <= C x^{3/4}. -/
theorem mertens_bound_eps_implies_original
    (hmert : ∀ eps : ℝ, eps > 0 → ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((summatoryMoebius x : ℤ) : ℝ)| ≤ C * x ^ ((1 : ℝ)/2 + eps)) :
    ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((summatoryMoebius x : ℤ) : ℝ)| ≤ C * x ^ ((3 : ℝ)/4) := by
  obtain ⟨C, hC_pos, hM⟩ := hmert (1/4 : ℝ) (by norm_num)
  exact ⟨C, hC_pos, fun x hx => by convert hM x hx using 2; norm_num⟩

-- NOTE: The bridge between summatoryMoebius (DirichletZetaInverse.lean)
-- and mertensFunction (MertensBound.lean) is handled in the
-- assembly file MertensFromPerron.lean.

end Cathedral.White.Infrastructure
