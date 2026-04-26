/-
  Cathedral/Perron/ContourShift.lean

  The contour shift under RH: shifting ∫_{Re=c} to ∫_{Re=σ₀} via Cauchy-Goursat.

  Contents:
  1. f_patch: patched integrand (continuous at s=1)
  2. f_patch_continuousOn, f_patch_diffAt: regularity
  3. perron_moebius_rect: rectangle identity via Cauchy-Goursat
  4. Schwarz reflection lemmas (deprecated but kept for reference)
  5. perron_moebius_contour_shift: THE contour shift theorem
  6. perron_moebius_contour_shift_factored: factored corollary

  Key Dependencies (all PROVED):
  - Perron/Formula.lean: perron_formula_error_bound
  - DirichletZetaInverse.lean: moebius_lseries_eq_inv_zeta
  - ZetaConvexity.lean: inv_zeta_bound_under_rh,
      perron_integrand_bound_with_zeta, perron_horizontal_contour_vanishes
-/

import Cathedral.Perron.Formula
import Cathedral.White.Infrastructure.DirichletZetaInverse
import Cathedral.White.Infrastructure.ZetaConvexity

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
  -- Integrability: f is ContinuousOn the vertical lines (since s ≠ 1 and s·ζ(s) ≠ 0)
  have h_cont_vert : ∀ (σ : ℝ), σ ≠ 1 → (1/2 < σ) →
      ContinuousOn (fun t : ℝ => f (↑σ + ↑t * I)) (Set.uIcc (-T) T) := by
    intro σ hσ hσ_half
    have hs_ne_one : ∀ t : ℝ, (↑σ + ↑t * I : ℂ) ≠ 1 := by
      intro t h
      apply hσ
      have hre := congr_arg Complex.re h
      simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im] at hre
      have him := congr_arg Complex.im h
      simp [Complex.add_im, Complex.ofReal_im, Complex.mul_im, Complex.ofReal_re, Complex.I_re, Complex.I_im] at him
      -- him : t = 0, hre : σ = 1
      exact hre
    apply ContinuousOn.div
    · exact ContinuousOn.cpow continuousOn_const (by fun_prop)
        (fun _ _ => Complex.ofReal_mem_slitPlane.mpr (by linarith))
    · apply ContinuousOn.mul (by fun_prop)
      -- riemannZeta ∘ (σ + t*I) is continuous: composition of differentiable functions
      exact (fun t _ =>
        ContinuousAt.continuousWithinAt <|
          ContinuousAt.comp
            (differentiableAt_riemannZeta (hs_ne_one t)).continuousAt
            (by fun_prop : ContinuousAt (fun t : ℝ => (↑σ + ↑t * I : ℂ)) t))
    · intro t _ h
      apply absurd h
      apply mul_ne_zero
      · -- σ + t*I ≠ 0 since Re(s) = σ > 1/2 > 0
        intro h0; have := congr_arg Complex.re h0; simp at this; linarith
      · -- ζ(σ + t*I) ≠ 0 under RH
        exact rh_zeta_ne_zero hRH (by simp; linarith) (hs_ne_one t)
  have h_int_c : IntervalIntegrable (fun t => f (↑c + ↑t * I)) volume (-T) T :=
    (h_cont_vert c (by linarith) (by linarith)).intervalIntegrable
  have h_int_s : IntervalIntegrable (fun t => f (↑sigma0 + ↑t * I)) volume (-T) T :=
    (h_cont_vert sigma0 (by linarith) (by linarith)).intervalIntegrable
  -- CG rearrangement and triangle inequality
  calc ‖∫ t in (-T)..T, (f (↑c + ↑t * I) - f (↑sigma0 + ↑t * I))‖
      = ‖(∫ t in (-T)..T, f (↑c + ↑t * I)) -
         (∫ t in (-T)..T, f (↑sigma0 + ↑t * I))‖ := by
        congr 1; exact intervalIntegral.integral_sub h_int_c h_int_s
    _ ≤ ‖∫ σ in sigma0..c, f (↑σ + ↑T * I)‖ +
        ‖∫ σ in sigma0..c, f (↑σ + ↑(-T) * I)‖ := by
        -- Convert smul to mul and normalize Complex.mk projections
        simp only [smul_eq_mul] at hCG
        have h_eq : I * ((∫ t in (-T)..T, f (↑c + ↑t * I)) -
            (∫ t in (-T)..T, f (↑sigma0 + ↑t * I))) =
          (∫ σ in sigma0..c, f (↑σ + ↑T * I)) -
          (∫ σ in sigma0..c, f (↑σ + ↑(-T) * I)) := by linear_combination hCG
        -- ‖right - left‖ = ‖I * (right - left)‖ = ‖top - bot‖ ≤ ‖top‖ + ‖bot‖
        calc ‖(∫ t in (-T)..T, f (↑c + ↑t * I)) -
              (∫ t in (-T)..T, f (↑sigma0 + ↑t * I))‖
            = ‖I * ((∫ t in (-T)..T, f (↑c + ↑t * I)) -
              (∫ t in (-T)..T, f (↑sigma0 + ↑t * I)))‖ := by
              rw [norm_mul, Complex.norm_I, one_mul]
          _ = ‖(∫ σ in sigma0..c, f (↑σ + ↑T * I)) -
              (∫ σ in sigma0..c, f (↑σ + ↑(-T) * I))‖ := by
              rw [h_eq]
          _ ≤ _ := norm_sub_le _ _
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

/-- **PROVED**: The contour shift under RH.
    Exporting `T_min = max T₀ 1` eliminates the "Small T" trap entirely!
    NOTE: x is now quantified AFTER the constants, and x^c is explicitly extracted! -/
theorem perron_moebius_contour_shift (hRH : RiemannHypothesis)
    (sigma0 c : ℝ) (hsigma0 : 1/2 < sigma0)
    (hc : 1 < c) (hsigma0_c : sigma0 < c) (hsigma0_lt_one : sigma0 < 1) :
    ∃ K₁ > 0, ∃ T_min ≥ (1 : ℝ), ∀ x : ℝ, 1 < x → ∀ T : ℝ, T_min ≤ T →
      ‖∫ t in (-T)..T,
        ((x : ℂ) ^ (↑c + ↑t * I) / ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I)) -
         (x : ℂ) ^ (↑sigma0 + ↑t * I) / ((↑sigma0 + ↑t * I) *
           riemannZeta (↑sigma0 + ↑t * I)))‖ ≤ K₁ * x ^ c * T ^ (-((1 : ℝ)/2)) := by
  set ε₀ := min (sigma0 - 1/2) (1/2)
  have hε₀_pos : 0 < ε₀ := lt_min (by linarith) (by norm_num)
  have hε₀_le_half : ε₀ ≤ 1/2 := min_le_right _ _
  have h_half_plus_ε₀ : 1/2 + ε₀ ≤ sigma0 := by
    have : ε₀ ≤ sigma0 - 1/2 := min_le_left _ _; linarith
  obtain ⟨C, hC_pos, T₀, hT₀_pos, hzeta_bound⟩ := inv_zeta_bound_under_rh hRH ε₀ hε₀_pos

  -- K₁ is purely absolute, depending only on c, σ₀, and C (NOT on x!)
  set K₁ := 2 * (c - sigma0) * C + 1
  have hK₁_pos : K₁ > 0 := by
    simp only [K₁]
    have hx_pos : (0 : ℝ) < c - sigma0 := by linarith
    linarith [mul_pos (mul_pos (by linarith : (0:ℝ) < 2) hx_pos) hC_pos]

  set T_min := max T₀ 1
  have hT_min_ge_1 : 1 ≤ T_min := le_max_right _ _

  refine ⟨K₁, hK₁_pos, T_min, hT_min_ge_1, fun x hx T hT_large => ?_⟩
  have hT_pos : (0 : ℝ) < T := by linarith
  have h_large : max T₀ 1 ≤ T := hT_large

  have h_rect := perron_moebius_rect hRH x sigma0 c T hx hsigma0 hc hsigma0_c hT_pos hsigma0_lt_one

  calc ‖∫ t in (-T)..T,
      ((x : ℂ) ^ (↑c + ↑t * I) / ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I)) -
       (x : ℂ) ^ (↑sigma0 + ↑t * I) / ((↑sigma0 + ↑t * I) *
         riemannZeta (↑sigma0 + ↑t * I)))‖
      ≤ (∫ σ in sigma0..c,
          ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖) +
        (∫ σ in sigma0..c,
          ‖(x : ℂ)^(↑σ + ↑(-T) * I) / ((↑σ + ↑(-T) * I) * riemannZeta (↑σ + ↑(-T) * I))‖) :=
      h_rect
    _ ≤ K₁ * x ^ c * T ^ (-((1 : ℝ)/2)) := by
      have h_bound_top := perron_integrand_bound_with_zeta x c sigma0 C T₀
        hx hsigma0 hsigma0_c hC_pos hT₀_pos ε₀ hε₀_pos h_half_plus_ε₀ hzeta_bound
      have h_pw_top := h_bound_top T h_large
      -- Top horizontal bound
      have h_top_bound : (∫ σ in sigma0..c,
          ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖) ≤
          (c - sigma0) * (x ^ c * C * T ^ (ε₀ - 1)) := by
        have h_intble : IntervalIntegrable (fun σ =>
            ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖)
            volume sigma0 c := by
          apply IntervalIntegrable.mono_fun' (intervalIntegrable_const
            (c := x ^ c * C * T ^ (ε₀ - 1)))
          · apply ContinuousOn.aestronglyMeasurable _ measurableSet_uIoc
            apply ContinuousOn.norm
            have hφ : Continuous (fun σ : ℝ => (↑σ + ↑T * I : ℂ)) :=
              continuous_ofReal.add continuous_const
            have hs_ne : ∀ σ : ℝ, (↑σ + ↑T * I : ℂ) ≠ 1 := by
              intro σ h; have := congr_arg Complex.im h
              simp [Complex.add_im, Complex.ofReal_im, Complex.mul_im,
                Complex.ofReal_re, Complex.I_re, Complex.I_im] at this; linarith
            apply ContinuousOn.div
            · exact hφ.continuousOn.const_cpow
                (Or.inl (Complex.ofReal_ne_zero.mpr (by linarith : (x : ℝ) ≠ 0)))
            · exact hφ.continuousOn.mul (fun σ _ => ContinuousAt.continuousWithinAt <|
                ContinuousAt.comp (differentiableAt_riemannZeta (hs_ne σ)).continuousAt hφ.continuousAt)
            · intro σ hσ_mem; apply mul_ne_zero
              · intro h0; have := congr_arg Complex.im h0
                simp [Complex.add_im, Complex.ofReal_im, Complex.mul_im,
                  Complex.ofReal_re, Complex.I_re, Complex.I_im] at this; linarith
              · have hre : (↑σ + ↑T * I : ℂ).re = σ := by
                  simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re,
                    Complex.I_re, Complex.I_im, Complex.ofReal_im]
                have hσ_ge : sigma0 ≤ σ := by
                  have := Set.uIoc_subset_uIcc hσ_mem
                  rw [Set.uIcc_of_le (le_of_lt hsigma0_c)] at this; exact this.1
                exact rh_zeta_ne_zero hRH (by rw [hre]; linarith) (hs_ne σ)
          · apply (ae_restrict_mem measurableSet_uIoc).mono
            intro σ hσ; simp only [Real.norm_of_nonneg (norm_nonneg _)]
            exact h_pw_top σ (Set.uIoc_subset_uIcc hσ)
        calc ∫ σ in sigma0..c,
              ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖
            ≤ ∫ _σ in sigma0..c, x ^ c * C * T ^ (ε₀ - 1) :=
              intervalIntegral.integral_mono_on (by linarith) h_intble intervalIntegrable_const
                (fun σ hσ => h_pw_top σ (Set.Icc_subset_uIcc hσ))
          _ = (c - sigma0) * (x ^ c * C * T ^ (ε₀ - 1)) := by
              rw [intervalIntegral.integral_const, smul_eq_mul]
      -- Bottom horizontal bound (|Im(σ+(-T)i)| = T by abs_neg)
      have h_bot_bound : (∫ σ in sigma0..c,
          ‖(x : ℂ)^(↑σ + ↑(-T) * I) / ((↑σ + ↑(-T) * I) * riemannZeta (↑σ + ↑(-T) * I))‖) ≤
          (c - sigma0) * (x ^ c * C * T ^ (ε₀ - 1)) := by
        have h_pw_bot : ∀ σ ∈ Set.uIcc sigma0 c,
            ‖(x : ℂ) ^ (↑σ + ↑(-T) * I) / ((↑σ + ↑(-T) * I) *
              riemannZeta (↑σ + ↑(-T) * I))‖ ≤ x ^ c * C * T ^ (ε₀ - 1) := by
          intro σ hσ_mem
          have hσ_le_c : σ ≤ c := by rw [Set.uIcc_of_le (le_of_lt hsigma0_c)] at hσ_mem; exact hσ_mem.2
          have hσ₀_le : sigma0 ≤ σ := by rw [Set.uIcc_of_le (le_of_lt hsigma0_c)] at hσ_mem; exact hσ_mem.1
          set s : ℂ := ↑σ + ↑(-T) * I with hs_def
          have hs_re : s.re = σ := by simp [hs_def, Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im, Complex.ofReal_im]
          have hs_im : s.im = -T := by
            simp [hs_def, Complex.add_im, Complex.ofReal_im, Complex.mul_im, Complex.ofReal_re, Complex.I_re, Complex.I_im]
          have hs_abs_im : |s.im| = T := by rw [hs_im, abs_neg, abs_of_pos hT_pos]
          have h_re_bound : 1/2 + ε₀ ≤ s.re := by rw [hs_re]; linarith
          have hT₀_le_im : T₀ ≤ |s.im| := by rw [hs_abs_im]; exact le_trans (le_max_left _ _) h_large
          have h_inv_zeta : ‖(1 : ℂ) / riemannZeta s‖ ≤ C * T ^ ε₀ := by
            have := hzeta_bound s h_re_bound hT₀_le_im; rwa [hs_abs_im] at this
          rw [norm_div, norm_mul, norm_cpow_eq_rpow_re_of_pos (by linarith : (0:ℝ) < x), hs_re]
          have h_norm_s_ge_T : T ≤ ‖s‖ := by rw [← hs_abs_im]; exact abs_im_le_norm s
          have hx_σ_le_c : x ^ σ ≤ x ^ c := rpow_le_rpow_of_exponent_le (le_of_lt hx) hσ_le_c
          have h_zeta_norm_inv : 1 / ‖riemannZeta s‖ ≤ C * T ^ ε₀ := by rwa [norm_div, norm_one] at h_inv_zeta
          by_cases hζ_zero : ‖riemannZeta s‖ = 0
          · simp [hζ_zero]; exact mul_nonneg (mul_nonneg (rpow_nonneg (by linarith) _) hC_pos.le) (rpow_nonneg (by linarith) _)
          · have hζ_pos : 0 < ‖riemannZeta s‖ := lt_of_le_of_ne (norm_nonneg _) (fun h => hζ_zero h.symm)
            rw [div_mul_eq_div_div]
            have h_factor1 : x ^ σ / ‖s‖ ≤ x ^ c / T := div_le_div₀ (by positivity) hx_σ_le_c hT_pos h_norm_s_ge_T
            calc x ^ σ / ‖s‖ / ‖riemannZeta s‖ = (x ^ σ / ‖s‖) * (1 / ‖riemannZeta s‖) := by ring
              _ ≤ (x ^ c / T) * (C * T ^ ε₀) := by apply mul_le_mul h_factor1 h_zeta_norm_inv (by positivity) (by positivity)
              _ = x ^ c * C * (T ^ ε₀ / T) := by ring
              _ = x ^ c * C * T ^ (ε₀ - 1) := by congr 1; rw [rpow_sub (by linarith : (0:ℝ) < T), rpow_one]
        have h_intble : IntervalIntegrable (fun σ =>
            ‖(x : ℂ)^(↑σ + ↑(-T) * I) / ((↑σ + ↑(-T) * I) * riemannZeta (↑σ + ↑(-T) * I))‖)
            volume sigma0 c := by
          apply IntervalIntegrable.mono_fun' (intervalIntegrable_const (c := x ^ c * C * T ^ (ε₀ - 1)))
          · apply ContinuousOn.aestronglyMeasurable _ measurableSet_uIoc; apply ContinuousOn.norm
            have hφ : Continuous (fun σ : ℝ => (↑σ + ↑(-T) * I : ℂ)) := continuous_ofReal.add continuous_const
            have hs_ne : ∀ σ : ℝ, (↑σ + ↑(-T) * I : ℂ) ≠ 1 := by
              intro σ h; have := congr_arg Complex.im h
              simp [Complex.add_im, Complex.ofReal_im, Complex.mul_im, Complex.ofReal_re, Complex.I_re, Complex.I_im] at this; linarith
            apply ContinuousOn.div
            · exact hφ.continuousOn.const_cpow (Or.inl (Complex.ofReal_ne_zero.mpr (by linarith : (x : ℝ) ≠ 0)))
            · exact hφ.continuousOn.mul (fun σ _ => ContinuousAt.continuousWithinAt <|
                ContinuousAt.comp (differentiableAt_riemannZeta (hs_ne σ)).continuousAt hφ.continuousAt)
            · intro σ hσ_mem; apply mul_ne_zero
              · intro h0; have := congr_arg Complex.im h0
                simp [Complex.add_im, Complex.ofReal_im, Complex.mul_im, Complex.ofReal_re, Complex.I_re, Complex.I_im] at this; linarith
              · have hre : (↑σ + ↑(-T) * I : ℂ).re = σ := by simp [Complex.add_re, Complex.ofReal_re, Complex.mul_re, Complex.I_re, Complex.I_im, Complex.ofReal_im]
                have hσ_ge : sigma0 ≤ σ := by have := Set.uIoc_subset_uIcc hσ_mem; rw [Set.uIcc_of_le (le_of_lt hsigma0_c)] at this; exact this.1
                exact rh_zeta_ne_zero hRH (by rw [hre]; linarith) (hs_ne σ)
          · apply (ae_restrict_mem measurableSet_uIoc).mono
            intro σ hσ; simp only [Real.norm_of_nonneg (norm_nonneg _)]
            exact h_pw_bot σ (Set.uIoc_subset_uIcc hσ)
        calc ∫ σ in sigma0..c,
              ‖(x : ℂ)^(↑σ + ↑(-T) * I) / ((↑σ + ↑(-T) * I) * riemannZeta (↑σ + ↑(-T) * I))‖
            ≤ ∫ _σ in sigma0..c, x ^ c * C * T ^ (ε₀ - 1) :=
              intervalIntegral.integral_mono_on (by linarith) h_intble intervalIntegrable_const
                (fun σ hσ => h_pw_bot σ (Set.Icc_subset_uIcc hσ))
          _ = (c - sigma0) * (x ^ c * C * T ^ (ε₀ - 1)) := by rw [intervalIntegral.integral_const, smul_eq_mul]
      -- Combined: top + bot ≤ 2·(c-σ₀)·x^c·C·T^{ε₀-1}
      have h_combined : (∫ σ in sigma0..c,
          ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖) +
        (∫ σ in sigma0..c,
          ‖(x : ℂ)^(↑σ + ↑(-T) * I) / ((↑σ + ↑(-T) * I) * riemannZeta (↑σ + ↑(-T) * I))‖) ≤
        2 * (c - sigma0) * x ^ c * C * T ^ (ε₀ - 1) := by linarith
      have h_exp : T ^ (ε₀ - 1) ≤ T ^ (-((1 : ℝ)/2)) := by
        apply rpow_le_rpow_of_exponent_le (by linarith); linarith
      calc (∫ σ in sigma0..c,
            ‖(x : ℂ)^(↑σ + ↑T * I) / ((↑σ + ↑T * I) * riemannZeta (↑σ + ↑T * I))‖) +
          (∫ σ in sigma0..c,
            ‖(x : ℂ)^(↑σ + ↑(-T) * I) / ((↑σ + ↑(-T) * I) * riemannZeta (↑σ + ↑(-T) * I))‖)
          ≤ 2 * (c - sigma0) * x ^ c * C * T ^ (ε₀ - 1) := h_combined
        _ = 2 * (c - sigma0) * C * x ^ c * T ^ (ε₀ - 1) := by ring
        _ ≤ 2 * (c - sigma0) * C * x ^ c * T ^ (-((1 : ℝ)/2)) := by
            apply mul_le_mul_of_nonneg_left h_exp
            apply mul_nonneg (mul_nonneg (mul_nonneg (by linarith) (by linarith)) hC_pos.le) (rpow_nonneg (by linarith) _)
        _ ≤ (2 * (c - sigma0) * C + 1) * x ^ c * T ^ (-((1 : ℝ)/2)) := by
            have h_pos_term : 0 ≤ 1 * x ^ c * T ^ (-((1 : ℝ)/2)) := by
              apply mul_nonneg (mul_nonneg zero_le_one (rpow_nonneg (by linarith) _)) (rpow_nonneg (by linarith) _)
            linarith
        _ = K₁ * x ^ c * T ^ (-((1 : ℝ)/2)) := by rfl

/-- **PROVED**: Corollary of the contour shift with the 1/(2πi) prefactor.
    The difference stays inside the integral to avoid integral_sub. -/
theorem perron_moebius_contour_shift_factored (hRH : RiemannHypothesis)
    (sigma0 c : ℝ) (hsigma0 : 1/2 < sigma0)
    (hc : 1 < c) (hsigma0_c : sigma0 < c) (hsigma0_lt_one : sigma0 < 1) :
    ∃ K₁ > 0, ∃ T_min ≥ (1 : ℝ), ∀ x : ℝ, 1 < x → ∀ T : ℝ, T_min ≤ T →
      ‖(1 / (2 * ↑Real.pi * I)) *
          ∫ t in (-T)..T,
            ((x : ℂ) ^ (↑c + ↑t * I) / ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I)) -
             (x : ℂ) ^ (↑sigma0 + ↑t * I) / ((↑sigma0 + ↑t * I) *
               riemannZeta (↑sigma0 + ↑t * I)))‖ ≤
      K₁ * x ^ c * T ^ (-((1 : ℝ)/2)) := by
  obtain ⟨K₁, hK₁, T_min, hT_min, h_raw⟩ :=
    perron_moebius_contour_shift hRH sigma0 c hsigma0 hc hsigma0_c hsigma0_lt_one
  refine ⟨K₁, hK₁, T_min, hT_min, fun x hx T hT => ?_⟩
  have h2 := h_raw x hx T hT
  -- ‖a * ∫(f-g)‖ = ‖a‖ * ‖∫(f-g)‖ ≤ 1 * ‖∫(f-g)‖ ≤ K₁ * x^c * T^{-1/2}
  set a := (1 : ℂ) / (2 * ↑Real.pi * I)
  -- ‖1/(2πi)‖ = 1/(2π) ≤ 1
  have h_norm_a : ‖a‖ ≤ 1 := by
    simp only [a]
    rw [norm_div, norm_one, norm_mul, norm_mul, Complex.norm_two, Complex.norm_I, mul_one]
    rw [show ‖(↑Real.pi : ℂ)‖ = Real.pi from by
      rw [Complex.norm_real]; exact abs_of_pos Real.pi_pos]
    rw [div_le_one (by positivity : (0:ℝ) < 2 * Real.pi)]
    linarith [Real.pi_gt_three]
  calc ‖a * ∫ t in (-T)..T, _‖
      = ‖a‖ * ‖∫ t in (-T)..T, _‖ := norm_mul a _
    _ ≤ 1 * ‖∫ t in (-T)..T, _‖ := by gcongr
    _ = ‖∫ t in (-T)..T, _‖ := one_mul _
    _ ≤ K₁ * x ^ c * T ^ (-((1 : ℝ)/2)) := h2

end Cathedral.White.Infrastructure
