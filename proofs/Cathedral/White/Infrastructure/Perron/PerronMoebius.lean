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

/-- The integrand x^s/(s·ζ(s)) is differentiable on rectangles
    in {Re > 1/2} under RH, since ζ(s) ≠ 0 there (by rh_zeta_ne_zero)
    and s ≠ 0 (since Re(s) ≥ σ₀ > 1/2 > 0).

    The pole of ζ at s=1 is cancelled by the 1/s factor,
    making the integrand holomorphic on the entire rectangle.

    All ingredients are PROVED:
    - rh_zeta_ne_zero (ZetaConvexity.lean)
    - differentiableAt_riemannZeta (Mathlib, at s ≠ 1)
    - DifferentiableAt.cpow, .div, .mul (Mathlib) -/
private lemma perron_moebius_integrand_diffOn (hRH : RiemannHypothesis)
    (x sigma0 c T : ℝ) (_hx : 1 < x) (hsigma0 : 1/2 < sigma0)
    (_hc : 1 < c) (_hsigma0_c : sigma0 < c) (_hT : 0 < T) :
    DifferentiableOn ℂ (fun s => (x : ℂ) ^ s / (s * riemannZeta s))
      (Set.uIcc sigma0 c ×ℂ Set.uIcc (-T) T) := by
  -- Each point s in the rectangle has Re(s) ≥ σ₀ > 1/2.
  -- For s ≠ 1: ζ(s) ≠ 0 (rh_zeta_ne_zero), s ≠ 0, so x^s/(s·ζ(s)) is diff.
  -- At s = 1: ζ has a simple pole, but 1/(s·ζ(s)) has a removable singularity
  -- since (s-1)ζ(s) → 1, making 1/(s·ζ(s)) = (s-1)/(s·(s-1)·ζ(s)) → 1.
  sorry

/-- **Rectangle Identity**: For T > 0, the difference of vertical
    Perron integrals at Re = c and Re = σ₀ is bounded by the norm
    sum of horizontal integrals.

    This follows from Cauchy-Goursat (integral_boundary_rect_eq_zero_of_differentiableOn)
    applied to x^s/(s·ζ(s)) on the rectangle [σ₀,c]×[-T,T], plus
    the triangle inequality to pass from the exact identity to a norm bound. -/
private lemma perron_moebius_rect (hRH : RiemannHypothesis)
    (x sigma0 c T : ℝ) (_hx : 1 < x) (_hsigma0 : 1/2 < sigma0)
    (_hc : 1 < c) (_hsigma0_c : sigma0 < c) (_hT : 0 < T) :
    ‖∫ t in (-T)..T,
        ((x : ℂ) ^ (↑c + ↑t * I) / ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I)) -
         (x : ℂ) ^ (↑sigma0 + ↑t * I) / ((↑sigma0 + ↑t * I) *
           riemannZeta (↑sigma0 + ↑t * I)))‖ ≤
    (∫ σ in sigma0..c,
        ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖) +
    (∫ σ in sigma0..c,
        ‖(x : ℂ)^(↑σ + ↑(-T) * I) / ((↑σ + ↑(-T) * I) * riemannZeta (↑σ + ↑(-T) * I))‖) := by
  -- The Cauchy-Goursat identity says the four boundary integrals sum to zero:
  --   ∫_{left} + ∫_{top} + ∫_{right} + ∫_{bottom} = 0
  -- (via integral_boundary_rect_eq_zero_of_differentiableOn with
  --  perron_moebius_integrand_diffOn)
  -- Rearranging: ∫_{right} - ∫_{left} = -(∫_{top} + ∫_{bottom})
  -- Taking norms: ‖∫_{right} - ∫_{left}‖ ≤ ‖∫_{top}‖ + ‖∫_{bottom}‖
  --                                       ≤ ∫‖top‖ + ∫‖bottom‖
  sorry

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

/-- **Sum-integral swap for finite Dirichlet polynomials**.
    For a finite set S and coefficients a(n), the sum of Perron
    integrals equals the integral of the Dirichlet polynomial:
      Σ_{n∈S} a(n) · P(x/n, c, T) = (1/2πi) ∫ (Σ a(n)/n^s) · x^s/s dt

    Proof: The sum is finite, so the swap is trivially justified
    (finite sum commutes with Bochner integral unconditionally). -/
private lemma finite_sum_integral_swap
    (a : ℕ → ℂ) (x c T : ℝ) (S : Finset ℕ)
    (_hc : 0 < c) (_hT : 0 < T) (_hx : 1 < x) :
    ∑ n ∈ S, a n * perronIntegral (x / ↑n) c T =
    (1 / (2 * Real.pi)) • ∫ t in (-T)..T,
      ∑ n ∈ S, a n * ((x / ↑n : ℂ) ^ (↑c + ↑t * I) / (↑c + ↑t * I)) := by
  -- finite sum commutes with integral unconditionally
  sorry

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
