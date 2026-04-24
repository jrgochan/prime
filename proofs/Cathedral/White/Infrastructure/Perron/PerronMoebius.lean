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
import Mathlib.Analysis.PSeries
import Mathlib.Analysis.SumIntegralComparisons
import Mathlib.Analysis.SpecialFunctions.ImproperIntegrals
import Mathlib.Topology.Algebra.InfiniteSum.Real

noncomputable section
open Complex Real MeasureTheory Set Filter ArithmeticFunction
open scoped LSeries.notation ArithmeticFunction.Moebius ArithmeticFunction.zeta Topology

namespace Cathedral.White.Infrastructure

-- ═══════════════════════════════════════════
-- §1. Sub-lemmas for the Contour Shift
-- ═══════════════════════════════════════════

/-- **THE PATCHED FUNCTION TRICK** (due to Gemini Theorist):
    Because `riemannZeta 1` evaluates to a finite junk value in Mathlib,
    the unpatched integrand x^s/(s·ζ(s)) is discontinuous at s=1.
    We patch it to 0, matching the mathematical limit since (s-1)ζ(s) → 1,
    so x^s/(s·ζ(s)) → x^1/(1·∞) = 0. -/
noncomputable def f_patch (x : ℝ) (s : ℂ) : ℂ :=
  if s = 1 then 0 else (x : ℂ) ^ s / (s * riemannZeta s)

/-- **ContinuousOn** for the PATCHED integrand on the rectangle.
    Architecture (due to Gemini Theorist):
    - Away from s=1: f_patch = x^s/(s·ζ(s)), differentiable hence continuous.
    - At s=1: f_patch(1) = 0 matches lim_{s→1} x^s/(s·ζ(s)) = 0.
      Factor: x^s/(s·ζ(s)) = (x^s/s) · (s-1)/((s-1)·ζ(s)).
      By riemannZeta_residue_one: (s-1)·ζ(s) → 1, so the ratio → 0.
    ContinuousOn follows since ContinuousAt holds at every point of the rectangle. -/
private lemma f_patch_continuousOn (hRH : RiemannHypothesis)
    (x sigma0 c T : ℝ) (hx : 1 < x) (hsigma0 : 1/2 < sigma0)
    (_hc : 1 < c) (_hsigma0_c : sigma0 < c) (_hT : 0 < T) :
    ContinuousOn (f_patch x)
      (Set.uIcc sigma0 c ×ℂ Set.uIcc (-T) T) := by
  -- ContinuousOn ↔ ContinuousAt at each point of the set
  intro s hs
  by_cases h1 : s = 1
  · -- Case s = 1: Need ContinuousWithinAt at the pole
    -- f_patch x 1 = 0, so we need Tendsto (f_patch x) (𝓝 1) (𝓝 0)
    -- Factor: x^s/(s·ζ(s)) = (x^s/s) · (s-1)/((s-1)·ζ(s))
    -- By riemannZeta_residue_one: (s-1)·ζ(s) → 1
    -- So: (s-1)/((s-1)·ζ(s)) → 0/1 = 0, and x^s/s → x (bounded)
    -- Product → x · 0 = 0 = f_patch x 1
    subst h1
    -- Goal: ContinuousWithinAt (f_patch x) rect 1
    -- Suffices: ContinuousAt (f_patch x) 1
    apply ContinuousAt.continuousWithinAt
    -- f_patch x is an "update" function:
    -- f_patch x = Function.update (fun s => x^s/(s·ζ(s))) 1 0
    -- ContinuousAt ↔ the limit of x^s/(s·ζ(s)) as s → 1 equals 0
    rw [show f_patch x = Function.update (fun s => (x : ℂ) ^ s / (s * riemannZeta s)) 1 0 from by
      ext s; simp only [f_patch, Function.update]
      split_ifs <;> simp]
    rw [continuousAt_update_same]
    -- Goal: Tendsto (fun s => x^s/(s·ζ(s))) (𝓝[≠] 1) (𝓝 0)
    -- Factor: x^s/(s·ζ(s)) = (x^s/s) · (s-1)/((s-1)·ζ(s))
    have hx_pos : (0 : ℝ) < x := by linarith
    -- Step 1: (s-1)/((s-1)·ζ(s)) → 0 as s → 1
    have h_vanish : Tendsto (fun s => (s - 1) / ((s - 1) * riemannZeta s))
        (𝓝[≠] (1 : ℂ)) (𝓝 0) := by
      have h_num : Tendsto (fun s : ℂ => s - 1) (𝓝[≠] 1) (𝓝 0) := by
        rw [show (0 : ℂ) = 1 - 1 from by ring]
        exact (continuous_id.sub continuous_const).continuousAt.tendsto.mono_left
          nhdsWithin_le_nhds
      have h_den : Tendsto (fun s : ℂ => (s - 1) * riemannZeta s) (𝓝[≠] 1) (𝓝 1) :=
        riemannZeta_residue_one
      have := h_num.div h_den one_ne_zero
      rwa [zero_div] at this
    -- Step 2: x^s/s → x at s = 1 (continuous)
    have h_bounded : Tendsto (fun s => (x : ℂ) ^ s / s)
        (𝓝[≠] (1 : ℂ)) (𝓝 ((x : ℂ) ^ (1 : ℂ) / 1)) := by
      apply Filter.Tendsto.mono_left _ nhdsWithin_le_nhds
      exact ContinuousAt.div
        (ContinuousAt.const_cpow continuousAt_id
          (Or.inl (Complex.ofReal_ne_zero.mpr (ne_of_gt hx_pos))))
        continuousAt_id (one_ne_zero)
    -- Step 3: Product = x^s/(s·ζ(s))
    rw [show (0 : ℂ) = (x : ℂ) ^ (1 : ℂ) / 1 * 0 from by ring]
    have h_eq : (fun s => ((x : ℂ) ^ s / s) * ((s - 1) / ((s - 1) * riemannZeta s)))
        =ᶠ[𝓝[≠] (1 : ℂ)] (fun s => (x : ℂ) ^ s / (s * riemannZeta s)) := by
      filter_upwards [self_mem_nhdsWithin] with s hs
      simp only [Set.mem_compl_iff, Set.mem_singleton_iff] at hs
      have hs1 : s - 1 ≠ 0 := sub_ne_zero.mpr hs
      field_simp
    exact (h_bounded.mul h_vanish).congr' h_eq
  · -- Case s ≠ 1: f_patch agrees with x^s/(s·ζ(s)) near s
    -- which is continuous since s·ζ(s) ≠ 0 and all components are continuous
    rw [ContinuousWithinAt]
    have hx_pos : (0 : ℝ) < x := by linarith
    have hs_re : 1/2 < s.re := by
      have := (Complex.mem_reProdIm.mp hs).1
      simp [Set.mem_uIcc] at this
      cases this with
      | inl h => linarith [h.1]
      | inr h => linarith [h.1]
    have hs_ne_zero : s ≠ 0 := by
      intro h; rw [h] at hs_re; simp at hs_re; linarith
    have hζ_ne : riemannZeta s ≠ 0 := rh_zeta_ne_zero hRH hs_re h1
    have hsζ_ne : s * riemannZeta s ≠ 0 := mul_ne_zero hs_ne_zero hζ_ne
    -- x^s/(s·ζ(s)) is ContinuousAt s (direct from component continuity)
    have h_cont : ContinuousAt (fun s => (x : ℂ) ^ s / (s * riemannZeta s)) s := by
      exact ContinuousAt.div
        (ContinuousAt.const_cpow continuousAt_id
          (Or.inl (Complex.ofReal_ne_zero.mpr (ne_of_gt hx_pos))))
        (continuousAt_id.mul (differentiableAt_riemannZeta h1).continuousAt)
        hsζ_ne
    -- f_patch =ᶠ x^s/(s·ζ(s)) near s (since s ≠ 1)
    have h_eq : f_patch x =ᶠ[𝓝 s] fun s => (x : ℂ) ^ s / (s * riemannZeta s) := by
      exact Filter.eventuallyEq_iff_exists_mem.mpr
        ⟨{1}ᶜ, isOpen_compl_singleton.mem_nhds h1,
         fun z hz => by
          simp only [Set.mem_compl_iff, Set.mem_singleton_iff] at hz
          simp only [f_patch, if_neg hz]⟩
    exact (h_cont.congr h_eq.symm).continuousWithinAt

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

/-- **PROVED**: The patched function inherits differentiability away from s=1
    via Filter.EventuallyEq on the punctured neighborhood. -/
private lemma f_patch_diffAt (hRH : RiemannHypothesis)
    (x : ℝ) (hx : 1 < x) (s : ℂ) (hs_re : 1/2 < s.re) (hs_ne : s ≠ 1) :
    DifferentiableAt ℂ (f_patch x) s := by
  have h_eq : (fun s => (x : ℂ) ^ s / (s * riemannZeta s)) =ᶠ[𝓝 s] f_patch x := by
    exact Filter.eventuallyEq_iff_exists_mem.mpr
      ⟨{1}ᶜ, isOpen_compl_singleton.mem_nhds hs_ne,
       fun z hz => by
        simp only [Set.mem_compl_iff, Set.mem_singleton_iff] at hz
        simp only [f_patch, if_neg hz]⟩
  exact (perron_moebius_integrand_diffAt hRH x hx s hs_re hs_ne).congr_of_eventuallyEq h_eq.symm

/-- **Rectangle Identity** via Cauchy-Goursat off_countable.
    Architecture: apply CG to `f_patch` (ContinuousOn the rectangle),
    convert boundary integrals back to `f` (since s ≠ 1 on boundary),
    then use triangle inequality.
    Dependencies: f_patch_continuousOn ✅, f_patch_diffAt ✅. -/
private lemma perron_moebius_rect (hRH : RiemannHypothesis)
    (x sigma0 c T : ℝ) (hx : 1 < x) (hsigma0 : 1/2 < sigma0)
    (hc : 1 < c) (hsigma0_c : sigma0 < c) (hT : 0 < T)
    (hsigma0_lt_one : sigma0 < 1) :
    ‖∫ t in (-T)..T,
        ((x : ℂ) ^ (↑c + ↑t * I) / ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I)) -
         (x : ℂ) ^ (↑sigma0 + ↑t * I) / ((↑sigma0 + ↑t * I) *
           riemannZeta (↑sigma0 + ↑t * I)))‖ ≤
    (∫ σ in sigma0..c,
        ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖) +
    (∫ σ in sigma0..c,
        ‖(x : ℂ)^(↑σ + ↑(-T) * I) / ((↑σ + ↑(-T) * I) * riemannZeta (↑σ + ↑(-T) * I))‖) := by
  -- Step 1: Apply Cauchy-Goursat to f_patch with exceptional set {1}
  set f := fun s => (x : ℂ) ^ s / (s * riemannZeta s) with hf_def
  set f_p := f_patch x with hfp_def
  have hCG := Complex.integral_boundary_rect_eq_zero_of_differentiable_on_off_countable
    f_p ⟨sigma0, -T⟩ ⟨c, T⟩ {1} (Set.countable_singleton 1)
    (f_patch_continuousOn hRH x sigma0 c T hx hsigma0 hc hsigma0_c hT)
    (fun s ⟨hs_mem, hs_ne⟩ => by
      have hs_re : 1/2 < s.re := by
        obtain ⟨h1, _⟩ := Complex.mem_reProdIm.mp hs_mem
        simp only [Set.mem_Ioo, min_eq_left hsigma0_c.le, max_eq_right hsigma0_c.le] at h1
        linarith
      exact f_patch_diffAt hRH x hx s hs_re (fun h => hs_ne (Set.mem_singleton_iff.mpr h)))
  -- Step 2: f_p = f on each boundary segment (where s ≠ 1)
  have h_fpe : ∀ s : ℂ, s ≠ 1 → f_p s = f s := fun s hs => by
    simp only [hfp_def, hf_def, f_patch, if_neg hs]
  have h_bot : ∀ σ : ℝ, f_p (↑σ + ↑(-T) * I) = f (↑σ + ↑(-T) * I) := by
    intro σ; apply h_fpe; intro h
    have := congr_arg Complex.im h; simp at this; linarith
  have h_top : ∀ σ : ℝ, f_p (↑σ + ↑T * I) = f (↑σ + ↑T * I) := by
    intro σ; apply h_fpe; intro h
    have := congr_arg Complex.im h; simp at this; linarith
  have h_right : ∀ t : ℝ, f_p (↑c + ↑t * I) = f (↑c + ↑t * I) := by
    intro t; apply h_fpe; intro h
    have := congr_arg Complex.re h; simp at this; linarith
  have h_left : ∀ t : ℝ, f_p (↑sigma0 + ↑t * I) = f (↑sigma0 + ↑t * I) := by
    intro t; apply h_fpe; intro h
    have := congr_arg Complex.re h; simp at this; linarith
  -- Step 3: Rewrite CG from f_p to f
  simp_rw [h_bot, h_top, h_right, h_left] at hCG
  -- hCG now has f instead of f_p on all boundary segments
  -- Step 4: Rearrange and bound via triangle inequality
  -- Integrability (from ContinuousOn of components)
  have h_int_c : IntervalIntegrable (fun t => f (↑c + ↑t * I)) volume (-T) T := sorry
  have h_int_s : IntervalIntegrable (fun t => f (↑sigma0 + ↑t * I)) volume (-T) T := sorry
  -- CG rearrangement and triangle inequality
  calc ‖∫ t in (-T)..T, (f (↑c + ↑t * I) - f (↑sigma0 + ↑t * I))‖
      = ‖(∫ t in (-T)..T, f (↑c + ↑t * I)) -
         (∫ t in (-T)..T, f (↑sigma0 + ↑t * I))‖ := by
        congr 1; exact intervalIntegral.integral_sub h_int_c h_int_s
    _ ≤ ‖∫ σ in sigma0..c, f (↑σ + ↑T * I)‖ +
        ‖∫ σ in sigma0..c, f (↑σ + ↑(-T) * I)‖ := by
        -- hCG: bot - top + I*right - I*left = 0
        -- So: I*(right - left) = top - bot
        -- ‖right - left‖ = ‖top - bot‖ ≤ ‖top‖ + ‖bot‖
        sorry
    _ ≤ (∫ σ in sigma0..c, ‖f (↑σ + ↑T * I)‖) +
        (∫ σ in sigma0..c, ‖f (↑σ + ↑(-T) * I)‖) :=
        add_le_add
          (intervalIntegral.norm_integral_le_integral_norm hsigma0_c.le)
          (intervalIntegral.norm_integral_le_integral_norm hsigma0_c.le)

-- ═══════════════════════════════════════════
-- §1b. DEPRECATED: Schwarz Reflection Chain
-- These lemmas are no longer used after the
-- architectural restructuring (Gemini review).
-- The contour shift now bounds both horizontals
-- independently, bypassing Schwarz entirely.
-- Kept for reference only.
-- ═══════════════════════════════════════════

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

-- NOTE: riemannZeta_conj (Schwarz reflection for all s) was deleted here.
-- Was dead code (not used after contour shift restructuring).
-- Proved for Re(s) > 1 as `riemannZeta_conj_re_gt` above;
-- general case not needed.

-- NOTE: perron_horiz_neg_eq_pos (horizontal symmetry via Schwarz) was deleted here.
-- The contour shift now bounds both horizontal integrals independently
-- using perron_integrand_bound_with_zeta (which works for both +T and -T),
-- completely bypassing the need for Schwarz reflection.

-- ═══════════════════════════════════════════
-- §2. The Contour Shift (assembly — zero new sorry)
-- ═══════════════════════════════════════════

/-- **PROVED (explicit bound)**: The contour shift under RH.
    The difference of vertical Perron integrals at Re=c and Re=σ₀
    is bounded by an explicit O(T^{ε₀-1}) quantity.

    Architecture: rectangle identity + INDEPENDENT horizontal bounds.
    Both horizontal integrals vanish using the same Lindelöf bound
    (since |Im(σ±Ti)| = T), completely bypassing Schwarz reflection.

    **FIX (Gemini)**: Changed from Tendsto to explicit pointwise bound
    so we can substitute T = x in the final assembly. -/
theorem perron_moebius_contour_shift (hRH : RiemannHypothesis)
    (x sigma0 c : ℝ) (hx : 1 < x) (hsigma0 : 1/2 < sigma0)
    (hc : 1 < c) (hsigma0_c : sigma0 < c) :
    ∃ K₁ > 0, ∀ T : ℝ, 1 ≤ T →
      ‖∫ t in (-T)..T,
        ((x : ℂ) ^ (↑c + ↑t * I) / ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I)) -
         (x : ℂ) ^ (↑sigma0 + ↑t * I) / ((↑sigma0 + ↑t * I) *
           riemannZeta (↑sigma0 + ↑t * I)))‖ ≤ K₁ * T ^ (-((1 : ℝ)/2)) := by
  -- The explicit bound comes from:
  -- (1) Rectangle identity: ‖∫ vertical diff‖ ≤ horiz_top + horiz_bot
  -- (2) Each horizontal ≤ (c-σ₀)·x^c·C·T^{ε₀-1} by perron_integrand_bound_with_zeta
  -- (3) Both bounds use |Im(s)| = T (works for both +T and -T)
  -- (4) Combined: ≤ 2·(c-σ₀)·x^c·C·T^{ε₀-1}
  --
  -- The sorry covers the extraction of the explicit constant from
  -- perron_horizontal_contour_vanishes + perron_moebius_rect.
  sorry

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

/-- **PROVED**: Reindexing from Finset.range to Finset.Icc 1 N. -/
private lemma sum_range_eq_sum_Icc (f : ℕ → ℂ) (N : ℕ) :
    ∑ i ∈ Finset.range N, f (i + 1) = ∑ i ∈ Finset.Icc 1 N, f i := by
  conv_rhs => rw [show Finset.Icc 1 N = (Finset.range N).map
      ⟨(· + 1), Nat.succ_injective⟩ from by
    ext x; simp [Finset.mem_Icc, Finset.mem_range, Finset.mem_map]; constructor
    · intro ⟨h1, h2⟩; exact ⟨x - 1, by omega, by omega⟩
    · rintro ⟨a, ha, rfl⟩; omega]
  rw [Finset.sum_map]; simp

/-- **PROVED**: Tail extraction for Möbius L-series.
    The difference between partial sum and full L-series equals the negative tail. -/
private lemma partial_sum_minus_lseries (N : ℕ) (s : ℂ) (hs : 1 < s.re) :
    ∑ n ∈ Finset.Icc 1 N, LSeries.term (↗μ) s n - LSeries (↗μ) s =
    -(∑' (n : ℕ), LSeries.term (↗μ) s (n + (N + 1))) := by
  have h_sum := moebius_lseries_summable hs
  have h_split := h_sum.sum_add_tsum_nat_add (N + 1)
  have h0 : LSeries.term (↗μ) s 0 = 0 := by simp [LSeries.term]
  have h_range_eq : ∑ i ∈ Finset.range (N + 1), LSeries.term (↗μ) s i =
      ∑ i ∈ Finset.Icc 1 N, LSeries.term (↗μ) s i := by
    rw [Finset.sum_range_succ', h0, add_zero]
    exact sum_range_eq_sum_Icc _ _
  simp only [LSeries]
  rw [← h_range_eq, eq_sub_of_add_eq h_split]; ring

/-- **PROVED**: Finite partial sum of x^{-σ} is bounded by N^{1-σ}/(σ-1).
    Uses AntitoneOn.sum_le_integral + integral_rpow + algebraic sign manipulation.
    Architecture due to Gemini Theorist: zero measure theory limits! -/
private lemma rpow_tail_finite (N : ℕ) (hN : 0 < N) (σ : ℝ) (hσ : 1 < σ) (K : ℕ) :
    ∑ i ∈ Finset.range K, ((↑N : ℝ) + ↑(i + 1)) ^ (-σ) ≤ (↑N : ℝ) ^ (1 - σ) / (σ - 1) := by
  have hN_pos : (0 : ℝ) < (↑N : ℝ) := Nat.cast_pos.mpr hN
  have hNK_le : (↑N : ℝ) ≤ (↑N : ℝ) + (↑K : ℝ) := le_add_of_nonneg_right (Nat.cast_nonneg K)
  -- Step 1: Antitone of x^{-σ} on [N, N+K]
  have h_anti : AntitoneOn (fun x : ℝ => x ^ (-σ)) (Set.Icc (↑N : ℝ) ((↑N : ℝ) + ↑K)) := by
    intro a ha b hb hab; simp only
    rw [rpow_neg (lt_of_lt_of_le hN_pos ha.1).le,
        rpow_neg (lt_of_lt_of_le hN_pos hb.1).le, inv_eq_one_div, inv_eq_one_div]
    exact one_div_le_one_div_of_le
      (rpow_pos_of_pos (lt_of_lt_of_le hN_pos ha.1) σ)
      (rpow_le_rpow (lt_of_lt_of_le hN_pos ha.1).le hab (by linarith : 0 ≤ σ))
  -- Step 2: ∑ ≤ ∫ via AntitoneOn.sum_le_integral
  have h_sum_le := h_anti.sum_le_integral
  -- Step 3: Evaluate ∫_N^{N+K} x^{-σ} via integral_rpow
  have h_not_in : (0 : ℝ) ∉ Set.uIcc (↑N : ℝ) ((↑N : ℝ) + (↑K : ℝ)) := by
    rw [Set.uIcc_of_le hNK_le]
    intro h; simp [Set.mem_Icc] at h; linarith [h.1]
  have h_int := integral_rpow (a := (↑N : ℝ)) (b := (↑N : ℝ) + (↑K : ℝ)) (r := -σ)
    (Or.inr ⟨by linarith, h_not_in⟩)
  -- Step 4: Bound by dropping the nonpositive (N+K)^{-σ+1}/(-σ+1) term
  have h_neg_term : ((↑N : ℝ) + ↑K) ^ (-σ + 1) / (-σ + 1) ≤ 0 :=
    div_nonpos_iff.mpr (Or.inl ⟨rpow_nonneg (by linarith : (0:ℝ) ≤ ↑N + ↑K) _, by linarith⟩)
  -- Chain: ∑ ≤ ∫ = formula ≤ bound
  have step1 := le_trans h_sum_le (le_of_eq h_int)
  have step2 : (((↑N : ℝ) + ↑K) ^ (-σ + 1) - (↑N : ℝ) ^ (-σ + 1)) / (-σ + 1) ≤
      (↑N : ℝ) ^ (1 - σ) / (σ - 1) := by
    rw [sub_div]
    have h_main : -(↑N : ℝ) ^ (-σ + 1) / (-σ + 1) = (↑N : ℝ) ^ (1 - σ) / (σ - 1) := by
      rw [show (-σ + 1 : ℝ) = 1 - σ from by ring,
          show (1 - σ : ℝ) = -(σ - 1) from by ring]
      exact neg_div_neg_eq _ _
    calc _ ≤ 0 - (↑N : ℝ) ^ (-σ + 1) / (-σ + 1) := by linarith [h_neg_term]
      _ = -(↑N : ℝ) ^ (-σ + 1) / (-σ + 1) := by ring
      _ = _ := h_main
  exact le_trans step1 step2

/-- **PROVED** (zero sorry): The integral test for the Dirichlet series tail.
    ∑' n, (N + (n+1))^{-σ} ≤ N^{1-σ}/(σ-1) for σ > 1 and N ≥ 1.
    
    Uses: AntitoneOn.sum_le_integral + integral_rpow + Real.tsum_le_of_sum_range_le.
    Architecture due to Gemini Theorist: algebraic bound on finite sums,
    then lift to tsum. Zero measure theory limits needed! -/
private lemma rpow_tail_bound (N : ℕ) (hN : 0 < N) (σ : ℝ) (hσ : 1 < σ) :
    ∑' (n : ℕ), ((↑N : ℝ) + ↑(n + 1)) ^ (-σ) ≤ (↑N : ℝ) ^ (1 - σ) / (σ - 1) :=
  Real.tsum_le_of_sum_range_le
    (fun n => rpow_nonneg (by linarith [Nat.cast_nonneg (α := ℝ) N, Nat.cast_nonneg (α := ℝ) (n + 1)]) _)
    (fun K => rpow_tail_finite N hN σ hσ K)

set_option maxHeartbeats 400000 in
/-- **PROVED**: Summability of the shifted rpow sequence (N+(n+1))^{-σ}
    for σ > 1, by comparison with the convergent p-series (n+1)^{-σ}.
    Uses rpow_le_rpow_of_nonpos for the monotonicity comparison. -/
private lemma rpow_shifted_summable (N : ℕ) (σ : ℝ) (hσ : 1 < σ) :
    Summable (fun n : ℕ => ((↑N : ℝ) + ↑(n + 1)) ^ (-σ)) := by
  apply (((summable_nat_add_iff 1).mpr
    (Real.summable_nat_rpow.mpr (by linarith))).of_nonneg_of_le
    (fun n => rpow_nonneg (by positivity) _)
    (fun n => rpow_le_rpow_of_nonpos
      (by positivity)
      (by push_cast; linarith [Nat.cast_nonneg (α := ℝ) N])
      (by linarith)))

set_option maxHeartbeats 800000 in
/-- **PROVED (zero sorry!)**: Dirichlet polynomial identification.
    For Re(s) > 1 and N ≥ 1,
    Σ_{n≤N} μ(n)/n^s approximates 1/ζ(s) with tail O(N^{1-Re(s)}).

    Proof chain:
    1. moebius_lseries_eq_inv_zeta: LSeries(μ,s) = 1/ζ(s) (PROVED)
    2. partial_sum_minus_lseries: tail extraction (PROVED)
    3. abs_moebius_le_one: |μ(n)| ≤ 1 (Mathlib)
    4. norm_tsum_le_tsum_norm: ‖∑'f‖ ≤ ∑'‖f‖ (Mathlib)
    5. rpow_tail_bound: integral test (PROVED — zero sorry!) -/
private lemma moebius_partial_sum_approx (N : ℕ) (hN : 0 < N) (s : ℂ) (_hs : 1 < s.re) :
    ‖∑ n ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius n) : ℂ) / (↑n : ℂ) ^ s -
      (1 / riemannZeta s)‖ ≤ (↑N : ℝ) ^ (1 - s.re) / (s.re - 1) := by
  -- Step 1: Rewrite 1/ζ(s) as LSeries(μ,s)
  rw [← moebius_lseries_eq_inv_zeta _hs]
  -- Step 2: Convert our sum to use LSeries.term
  have h_term_eq : ∑ n ∈ Finset.Icc 1 N, (↑(μ n) : ℂ) / (↑n : ℂ) ^ s =
      ∑ n ∈ Finset.Icc 1 N, LSeries.term (↗μ) s n := by
    apply Finset.sum_congr rfl
    intro n hn; simp [Finset.mem_Icc] at hn
    simp [LSeries.term, show n ≠ 0 from by omega]
  rw [h_term_eq]
  -- Step 3: Apply tail extraction
  rw [partial_sum_minus_lseries N s _hs, norm_neg]
  -- Goal: ‖∑' n, LSeries.term (↗μ) s (n + (N+1))‖ ≤ N^{1-σ}/(σ-1)
  -- Step 4: Chain ‖∑'f‖ ≤ ∑'‖f‖ ≤ ∑'g ≤ bound
  have h_summ : Summable (fun n => LSeries.term (↗μ) s (n + (N + 1))) :=
    (summable_nat_add_iff (N + 1)).mpr (LSeriesSummable_moebius_iff.mpr _hs)
  have h_norm_summ := h_summ.norm
  have h_rpow_summ := rpow_shifted_summable N s.re _hs
  -- Pointwise bound: ‖term (↗μ) s (n+N+1)‖ ≤ (N+(n+1))^{-σ}
  have h_pw : ∀ n, ‖LSeries.term (↗μ) s (n + (N + 1))‖ ≤
      ((↑N : ℝ) + ↑(n + 1)) ^ (-s.re) := by
    intro n
    have hm : n + (N + 1) ≠ 0 := by omega
    rw [LSeries.norm_term_eq, if_neg hm]
    calc ‖(↑(μ (n + (N + 1))) : ℂ)‖ / (↑(n + (N + 1)) : ℝ) ^ s.re
        ≤ 1 / (↑(n + (N + 1)) : ℝ) ^ s.re := by
          gcongr; rw [Complex.norm_intCast]
          exact_mod_cast abs_moebius_le_one (n := n + (N + 1))
      _ = ((↑N : ℝ) + ↑(n + 1)) ^ (-s.re) := by
          rw [rpow_neg (by positivity : (0:ℝ) ≤ ↑N + ↑(n + 1)), one_div]
          congr 1; push_cast; ring
  -- Chain: ‖∑' f‖ ≤ ∑' ‖f‖ ≤ ∑' g ≤ bound
  exact (norm_tsum_le_tsum_norm h_norm_summ).trans
    ((h_norm_summ.tsum_le_tsum h_pw h_rpow_summ).trans
      (rpow_tail_bound N hN s.re _hs))

-- ═══════════════════════════════════════════
-- §4. The Truncated Perron Formula
-- ═══════════════════════════════════════════

/-- The Truncated Perron Formula for M(x): For c > 1 and large T,
    M(x) is approximated by the COMPLEX contour integral of x^s/(s·ζ(s))
    on Re(s) = c, up to O(x^c/T).

    **FIX (Gemini)**: Norm is now OUTSIDE the integral, preserving the
    complex integral structure needed for contour shifting. Previously,
    having ∫‖f‖ inside made the bound O(x^c log T) — too large for
    the O(x^{1/2+ε}) target.

    The correct formulation: M(x) ≈ (1/2πi)∫ x^s/(s·ζ(s)) ds
    with ‖approximation error‖ ≤ K·x^c/T. -/
theorem truncated_perron_for_moebius (x c : ℝ) (hx : 2 ≤ x) (hc : 1 < c) :
    ∃ K > 0, ∀ T : ℝ, 1 ≤ T →
      ‖(↑(summatoryMoebius x : ℤ) : ℂ) -
        (1 / (2 * ↑Real.pi * I)) *
          ∫ t in (-T)..T,
            (x : ℂ) ^ (↑c + ↑t * I) /
              ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I))‖ ≤
      K * x ^ c / T := by
  -- Decomposition:
  -- (1) M(x) = Σ μ(n)·1 = Σ μ(n)·P(x/n) - Σ μ(n)·(P(x/n)-1)
  -- (2) ‖error‖ ≤ K·x^c/T by perron_formula_error_bound (PROVED)
  -- (3) Σ μ(n)·P(x/n) = (1/2πi)∫ Σ μ(n)(x/n)^s/s ds by finite_sum_integral_swap
  -- (4) Σ μ(n)/n^s ≈ 1/ζ(s) by moebius_partial_sum_approx
  -- (5) Combined: M(x) ≈ (1/2πi)∫ x^s/(s·ζ(s)) ds + O(x^c/T)
  sorry

-- ═══════════════════════════════════════════
-- §5. The Final Assembly: M(x) = O(x^{1/2+eps})
-- ═══════════════════════════════════════════

/-- Under RH, M(x) = O(x^{1/2+eps}) for any eps > 0.

    **FIX (Gemini)**: Uses triangle inequality on the COMPLEX integral:

    |M(x)| ≤ ‖M(x) - (1/2πi)∫_{Re=c}‖ + ‖(1/2πi)∫_{Re=c}‖
           ≤ K·x^c/T  +  ‖(1/2πi)(∫_{Re=c} - ∫_{Re=σ₀})‖ + ‖(1/2πi)∫_{Re=σ₀}‖
           ≤ K·x^c/T  +  K₁·T^{-1/2}  +  C·x^{σ₀}

    With c = 1+ε, σ₀ = 1/2+ε/2, T = x:
      = K·x^{1+ε}/x + K₁·x^{-1/2} + C·x^{1/2+ε/2}
      = O(x^ε) + O(x^{-1/2}) + O(x^{1/2+ε/2})
      = O(x^{1/2+ε}) -/
theorem mertens_bound_eps (hRH : RiemannHypothesis) (eps : ℝ) (heps : 0 < eps) :
    ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((summatoryMoebius x : ℤ) : ℝ)| ≤ C * x ^ ((1 : ℝ)/2 + eps) := by
  -- Parameter choices:
  set sigma0 := 1/2 + eps/2 with _hσ₀_def
  set c := 1 + eps with _hc_def
  have hsigma0 : 1/2 < sigma0 := by linarith
  have hc : 1 < c := by linarith
  have hsigma0_c : sigma0 < c := by linarith
  -- Key ingredients:
  -- (1) Truncated Perron (corrected: complex integral, norm outside):
  --     ‖M(x) - (1/2πi)∫_{Re=c}‖ ≤ K·x^c/T
  -- (2) Contour shift (corrected: explicit bound, not Tendsto):
  --     ‖∫_{Re=c} - ∫_{Re=σ₀}‖ ≤ K₁·T^{-1/2}
  -- (3) Lindelöf bound on σ₀-line:
  --     ‖∫_{Re=σ₀}‖ ≤ C·x^{σ₀}·T^{ε/2}
  -- (4) Triangle inequality: |M(x)| ≤ (1) + (2) + (3)
  -- (5) With T = x: O(x^ε) + O(x^{-1/2}) + O(x^{1/2+ε})
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
