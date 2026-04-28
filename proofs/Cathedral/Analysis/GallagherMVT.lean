/-
  Cathedral/Analysis/GallagherMVT.lean

  ## The Gallagher Bypass: MVT via Fejér Kernel

  ### Architecture (April 27, 2026 — GEMINI TACTICAL DIRECTIVE)

  Gemini's CRITICAL OVERRIDE: DO NOT attempt Vaaler's lemma.
  Instead, prove the MVT directly using the Fejér kernel.

  The key identity: for δ-separated frequencies λₙ,
    ∫ₐ |Σ aₙ e^{iλₙt}|² · δ · K(δt) dt = Σ |aₙ|²
  where K = sinc² (Fejér kernel).

  Proof:
  1. Expand |f|² = Σₘ Σₙ aₘ āₙ e^{i(λₘ-λₙ)t}
  2. Swap ∫ and Σ (integral_finset_sum, finite sums)
  3. Each term: aₘāₙ · δ · ∫ e^{iωt} K(δt) dt = aₘāₙ · K̂(ω/δ)
  4. FK4: K̂(ξ) = Λ(ξ) = 0 for |ξ| ≥ 1
  5. For m ≠ n: |λₘ-λₙ| ≥ δ, so |ω/δ| ≥ 1, so K̂ = 0
  6. For m = n: K̂(0) = Λ(0) = 1
  7. Therefore: I = Σ |aₙ|²

  This BYPASSES the Montgomery-Vaughan Hilbert inequality entirely.
  The constant is not π/δ but just 1 (exact identity, not inequality).

  ### Dependencies
  - HilbertInequality.lean (FK1-FK4, all PROVED)
  - PlancherelDefs.lean (Plancherel, PROVED)

  ### Sorry Status
  - cross_term_integral: 1 sorry (change of variables + FK identity)
  - fejer_orthogonality: 1 sorry (|f|² expansion + FK4 assembly)
  These are ASSEMBLY sorrys using only proved infrastructure.
-/

import Cathedral.Analysis.HilbertInequality
import Cathedral.MellinBridge.PlancherelDefs

noncomputable section
open Complex Real Finset BigOperators MeasureTheory
open scoped FourierTransform

namespace Cathedral.Analysis

-- ═══════════════════════════════════════════════
-- §1. TRIGONOMETRIC POLYNOMIAL DEFINITIONS
-- ═══════════════════════════════════════════════

/-- A trigonometric polynomial: f(t) = Σ aₙ e^{2πiλₙt} -/
def trigPoly {N : ℕ} (a : Fin N → ℂ) (lam : Fin N → ℝ) (t : ℝ) : ℂ :=
  ∑ n : Fin N, a n * Complex.exp (2 * π * lam n * t * I)

/-- The Fejér-weighted L² integral:
    I = ∫ₐ |f(t)|² · δ · K(δt) dt
    where K = sinc² is the Fejér kernel. -/
def fejerWeightedL2 {N : ℕ} (a : Fin N → ℂ) (lam : Fin N → ℝ) (δ : ℝ) : ℝ :=
  ∫ t : ℝ, ‖trigPoly a lam t‖ ^ 2 * (δ * fejerKernel (δ * t))

-- ═══════════════════════════════════════════════
-- §2. THE CROSS-TERM IDENTITY
-- ═══════════════════════════════════════════════

-- The scaling lemma is incorporated directly into cross_term_integral
-- via integral_comp_mul_left from Mathlib.
-- For f(t) = cos(2πωt):
--   ∫ cos(2πωt) · δ · K(δt) dt = ∫ cos(2π(ω/δ)u) · K(u) du = Λ(ω/δ)

/-- Each cross-term integral equals K̂ evaluated at the frequency difference.

    ∫ cos(2πωt) · δ · K(δt) dt = Λ(ω/δ)

    where Λ(ξ) = max(1-|ξ|, 0) is the triangle function (= K̂).

    Proof: Change of variables u = δt, then apply fejerKernel_fourier_eq_triangle.
    The change of variables gives:
      ∫ cos(2πωt) · δ · K(δt) dt = ∫ cos(2π(ω/δ)u) · K(u) du
    and the RHS equals Λ(ω/δ) by the proved FK identity. -/
theorem cross_term_integral (ω δ : ℝ) (hδ : 0 < δ) :
    ∫ t : ℝ, Real.cos (2 * π * ω * t) * (δ * fejerKernel (δ * t)) =
    triangleFunction (ω / δ) := by
  -- Step 1: Rearrange: cos(2πωt)·δ·K(δt) = δ·(K(δt)·cos(2π(ω/δ)·(δt)))
  have h_eq : ∀ t, Real.cos (2 * π * ω * t) * (δ * fejerKernel (δ * t)) =
      δ * (fejerKernel (δ * t) * Real.cos (2 * π * (ω / δ) * (δ * t))) := by
    intro t
    -- cos argument: 2πωt = 2π(ω/δ)(δt) after clearing denominator
    have h1 : (2 : ℝ) * π * ω * t = 2 * π * (ω / δ) * (δ * t) := by field_simp
    -- Rewrite cos arg, then commute: cos(X)·(δ·K) = (δ·K)·cos(X) = δ·(K·cos(X))
    rw [h1, mul_comm (Real.cos _) (δ * fejerKernel (δ * t)), mul_assoc]
  simp_rw [h_eq]
  -- Step 2: Factor out δ as smul
  rw [show (fun t => δ * (fejerKernel (δ * t) * Real.cos (2 * π * (ω / δ) * (δ * t)))) =
    (fun t => δ • (fejerKernel (δ * t) * Real.cos (2 * π * (ω / δ) * (δ * t)))) from by
    ext t; simp [smul_eq_mul]]
  rw [integral_smul]
  -- Goal: δ • ∫ K(δt) · cos(2π(ω/δ)(δt)) dt = Λ(ω/δ)
  -- Step 3: COV u = δt: ∫ g(δt) = |δ⁻¹| • ∫ g(u)
  have h_cov := Measure.integral_comp_mul_left
    (fun u => fejerKernel u * Real.cos (2 * π * (ω / δ) * u)) δ
  -- h_cov: ∫ g(δt) = |δ⁻¹| • ∫ g(u)
  -- But our integral has g(δ*t) expanded, match it:
  conv_lhs => rw [show (fun t => fejerKernel (δ * t) * Real.cos (2 * π * (ω / δ) * (δ * t))) =
    (fun t => (fun u => fejerKernel u * Real.cos (2 * π * (ω / δ) * u)) (δ * t)) from by
    ext t; simp]
  rw [h_cov]
  -- Goal: δ • (|δ⁻¹| • ∫ K(u) · cos(2π(ω/δ)u) du) = Λ(ω/δ)
  rw [smul_comm, smul_smul, abs_inv, abs_of_pos hδ,
    inv_mul_cancel₀ (ne_of_gt hδ), one_smul]
  exact fejerKernel_fourier_eq_triangle (ω / δ)
/-- Helper: for δ-separated frequencies, the triangle function
    Λ((λₘ-λₙ)/δ) equals the Kronecker delta.

    m = n → Λ(0) = 1
    m ≠ n → |λₘ-λₙ| ≥ δ → |(λₘ-λₙ)/δ| ≥ 1 → Λ = 0 -/
theorem triangle_kronecker {N : ℕ} {lam : Fin N → ℝ} {δ : ℝ}
    (hδ : 0 < δ) (h_sep : IsDeltaSeparated lam δ)
    (m n : Fin N) :
    triangleFunction ((lam m - lam n) / δ) =
    if m = n then 1 else 0 := by
  split
  case isTrue h =>
    -- m = n: Λ(0/δ) = Λ(0) = 1
    subst h; simp [triangleFunction_zero]
  case isFalse h =>
    -- m ≠ n: |λₘ-λₙ| ≥ δ, so |(λₘ-λₙ)/δ| ≥ 1
    have h_sep_mn := h_sep m n h
    have h_ge : 1 ≤ |(lam m - lam n) / δ| := by
      rw [abs_div, abs_of_pos hδ]
      rwa [le_div_iff₀ hδ, one_mul]
    -- Λ(ξ) = max(1-|ξ|, 0) = 0 when 1 ≤ |ξ|
    unfold triangleFunction
    simp only [max_eq_right_iff]
    linarith

/-- **FEJÉR ORTHOGONALITY**: For δ-separated frequencies, the
    Fejér-weighted L² integral equals the sum of squared amplitudes.

    ∫ₐ |Σ aₙ e^{2πiλₙt}|² · δ · K(δt) dt = Σ |aₙ|²

    This is the Gallagher bypass: instead of bounding the bilinear form
    Σ aₘāₙ/(λₘ-λₙ) via Montgomery-Vaughan, we DIRECTLY prove that
    the Fejér-weighted integral collapses to the diagonal.

    Dependencies (ALL PROVED):
    - cross_term_integral (above, uses fejerKernel_fourier_eq_triangle)
    - triangleFunction_support: Λ(ξ) = 0 for |ξ| ≥ 1  ✅
    - triangleFunction_zero: Λ(0) = 1  ✅
    - integral_finset_sum (Mathlib): ∫Σ = Σ∫  ✅ -/

-- Helper: Each cross-term is integrable (bounded × integrable = integrable)
private lemma cross_term_integrable
    (c₁ c₂ : ℂ) (l₁ l₂ δ : ℝ) (hδ : 0 < δ) :
    Integrable (fun (t : ℝ) => (c₁ * cexp (2 * ↑π * ↑l₁ * ↑t * I) *
      ((starRingEnd ℂ) c₂ * (starRingEnd ℂ) (cexp (2 * ↑π * ↑l₂ * ↑t * I)))).re *
      (δ * fejerKernel (δ * t))) := by
  -- The integrand is f(t) * g(t) where f(t) = Re(complex), g(t) = δK(δt)
  -- |f(t)| ≤ ‖c₁‖·‖c₂‖ since |Re(z)| ≤ ‖z‖ ≤ ‖c₁‖·‖c₂‖ (exp has unit norm)
  -- g is integrable by FK3 + COV
  have h_wt : Integrable (fun t => δ * fejerKernel (δ * t)) :=
    (fejerKernel_integrable.comp_mul_left' (ne_of_gt hδ)).const_mul δ
  apply h_wt.bdd_mul
  · -- AEStronglyMeasurable: composition of continuous functions
    -- Re of (c₁ * exp(iλ₁t) * conj(c₂) * conj(exp(iλ₂t))) is continuous hence measurable
    fun_prop
  · -- Norm bound: ‖Re(z)‖ ≤ ‖c₁‖ * ‖c₂‖
    filter_upwards with t
    rw [Real.norm_eq_abs]
    calc |(c₁ * cexp (2 * ↑π * ↑l₁ * ↑t * I) *
            ((starRingEnd ℂ) c₂ * (starRingEnd ℂ) (cexp (2 * ↑π * ↑l₂ * ↑t * I)))).re|
        ≤ ‖c₁ * cexp (2 * ↑π * ↑l₁ * ↑t * I) *
            ((starRingEnd ℂ) c₂ * (starRingEnd ℂ) (cexp (2 * ↑π * ↑l₂ * ↑t * I)))‖ :=
          Complex.abs_re_le_norm _
      _ ≤ ‖c₁‖ * ‖c₂‖ := by
          simp only [norm_mul, map_mul, Complex.norm_conj]
          -- Need: ‖cexp(2πl₁t·I)‖ = 1 and ‖cexp(2πl₂t·I)‖ = 1
          have h1 : ‖cexp (2 * ↑π * ↑l₁ * ↑t * I)‖ = 1 := by
            rw [show (2 : ℂ) * ↑π * ↑l₁ * ↑t * I = ↑(2 * π * l₁ * t) * I from by push_cast; ring]
            exact Complex.norm_exp_ofReal_mul_I _
          have h2 : ‖cexp (2 * ↑π * ↑l₂ * ↑t * I)‖ = 1 := by
            rw [show (2 : ℂ) * ↑π * ↑l₂ * ↑t * I = ↑(2 * π * l₂ * t) * I from by push_cast; ring]
            exact Complex.norm_exp_ofReal_mul_I _
          rw [h1, h2, mul_one, mul_one]

theorem fejer_orthogonality
    {N : ℕ} (a : Fin N → ℂ) (lam : Fin N → ℝ) (δ : ℝ) (hδ : 0 < δ)
    (h_sep : IsDeltaSeparated lam δ) :
    fejerWeightedL2 a lam δ = ∑ n : Fin N, ‖a n‖ ^ 2 := by
  unfold fejerWeightedL2 trigPoly
  -- INNER PRODUCT APPROACH
  -- Step 1: ‖z‖² = ⟪z, z⟫_ℝ (real inner product on ℂ)
  simp_rw [← @real_inner_self_eq_norm_sq ℂ]
  -- Step 2: ⟪Σ fₙ, Σ fₘ⟫ = Σₙ Σₘ ⟪fₙ, fₘ⟫
  simp_rw [@sum_inner ℝ ℂ _ _ _ _ Finset.univ, @inner_sum ℝ ℂ _ _ _ _ Finset.univ]
  -- Goal: ∫ (Σₓ Σᵢ ⟪aₓeₓ, aᵢeᵢ⟫_ℝ) * w(t) = Σₓ ⟪aₓ, aₓ⟫_ℝ
  -- Step 3: ⟪w, z⟫_ℝ = Re(z * conj w) (Complex.inner)
  simp_rw [Complex.inner]
  -- Goal: ∫ (Σ Σ Re(aᵢeᵢ * conj(aₓeₓ))) * w = Σ Re(aₓ * conj(aₓ))
  -- Step 4: Swap ∫ and Σ Σ
  -- First: distribute w over the sum: (Σ Σ f) * w = Σ Σ (f * w)
  simp_rw [Finset.sum_mul]
  -- Now: ∫ Σₓ Σᵢ Re(...) * w = Σₓ Re(...)
  -- Goal: ∫ Σₓ Σᵢ Re(aᵢeᵢ * conj(aₓ) · conj(eₓ)) * w = Σₓ Re(aₓ * conj(aₓ))
  -- Step 5: Expand conj(aₓ * eₓ) = conj(aₓ) * conj(eₓ)
  simp_rw [map_mul (starRingEnd ℂ)]
  -- Step 6: Swap ∫ and ΣΣ using integral_finset_sum
  rw [integral_finset_sum Finset.univ (fun x _ => by
    -- Integrability: ∑ᵢ Re(aᵢeᵢ·conj(aₓ)·conj(eₓ)) · δK(δt) is integrable
    -- Each summand is integrable (bounded × integrable = integrable)
    -- since |Re(·)| ≤ ‖aᵢ‖·‖aₓ‖ (exp has unit norm) and δK(δt) ∈ L¹ (FK3)
    exact integrable_finset_sum _ (fun i _ => cross_term_integrable (a i) (a x) (lam i) (lam x) δ hδ))]
  -- Main goal: Σₓ ∫ (Σᵢ ...) * w = Σₓ Re(aₓ * conj(aₓ))
  congr 1; ext x
  -- Step 7: Inner swap ∫ and Σᵢ
  rw [integral_finset_sum Finset.univ (fun i _ => cross_term_integrable (a i) (a x) (lam i) (lam x) δ hδ)]
  -- DIAGONAL COLLAPSE via Finset.sum_eq_single_of_mem
  rw [Finset.sum_eq_single_of_mem x (Finset.mem_univ x)]
  · -- DIAGONAL CASE (i = x): exp(z) * conj(exp(z)) = |exp(z)|² = 1
    have h_exp_cancel : ∀ t : ℝ,
      (a x * cexp (2 * ↑π * ↑(lam x) * ↑t * I) *
        ((starRingEnd ℂ) (a x) * (starRingEnd ℂ) (cexp (2 * ↑π * ↑(lam x) * ↑t * I)))).re =
      (a x * (starRingEnd ℂ) (a x)).re := by
      intro t
      -- Rearrange: a*e*(conj a * conj e) = (a*conj a) * (e*conj e)
      rw [show a x * cexp (2 * ↑π * ↑(lam x) * ↑t * I) *
        ((starRingEnd ℂ) (a x) * (starRingEnd ℂ) (cexp (2 * ↑π * ↑(lam x) * ↑t * I))) =
        (a x * (starRingEnd ℂ) (a x)) *
        (cexp (2 * ↑π * ↑(lam x) * ↑t * I) *
         (starRingEnd ℂ) (cexp (2 * ↑π * ↑(lam x) * ↑t * I))) from by ring]
      -- e * conj(e) = ↑(normSq e)
      rw [Complex.mul_conj (cexp _)]
      -- Now goal has: (↑normSq(a) * ↑normSq(exp(...))).re = (↑normSq(a)).re
      have h_ns : Complex.normSq (cexp (2 * ↑π * ↑(lam x) * ↑t * I)) = 1 := by
        rw [Complex.normSq_eq_norm_sq]
        have : (2 * ↑π * ↑(lam x) * ↑t * I : ℂ) = ↑(2 * π * lam x * t) * I := by push_cast; ring
        rw [this, Complex.norm_exp_ofReal_mul_I]; norm_num
      rw [h_ns, Complex.ofReal_one, mul_one]
    simp_rw [h_exp_cancel]
    -- Goal: ∫ Re(aₓ·conj(aₓ)) * δK(δt) dt = Re(aₓ·conj(aₓ))
    -- Factor out constant c = Re(aₓ·conj(aₓ)):
    -- ∫ c * g(t) dt = c * ∫ g(t) dt = c * 1 = c  (FK3: ∫ δK(δt) = 1)
    rw [show (fun t => (a x * (starRingEnd ℂ) (a x)).re * (δ * fejerKernel (δ * t))) =
      (fun t => (a x * (starRingEnd ℂ) (a x)).re • (δ * fejerKernel (δ * t))) from by
      ext; simp [smul_eq_mul]]
    rw [integral_smul, smul_eq_mul]
    -- Goal: Re(aₓ·conj(aₓ)) * ∫ δK(δt) dt = Re(aₓ·conj(aₓ))
    -- FK3 scaled: ∫ δK(δt) dt = 1
    have h_fk3 : ∫ t : ℝ, δ * fejerKernel (δ * t) = 1 := by
      -- COV u = δt: ∫ g(δt) dt = |δ⁻¹| ∫ g(u) du
      have h_cov := Measure.integral_comp_mul_left (fun u => fejerKernel u) δ
      -- ∫ K(δt) dt = |δ⁻¹| · ∫ K(u) du
      -- ∫ δ·K(δt) dt = δ · ∫ K(δt) dt = δ · |δ⁻¹| · ∫ K(u) du = 1 · ∫ K(u) du = 1
      rw [show (fun t => δ * fejerKernel (δ * t)) =
        (fun t => δ • (fejerKernel (δ * t))) from by ext; simp [smul_eq_mul]]
      rw [integral_smul, h_cov, smul_comm, smul_smul,
        abs_inv, abs_of_pos hδ, inv_mul_cancel₀ (ne_of_gt hδ), one_smul]
      exact fejerKernel_integral
    rw [h_fk3, mul_one]
  · -- OFF-DIAGONAL CASE (i ≠ x)
    intro i _ hix
    -- Goal: ∫ Re(aᵢ·eᵢ · conj(aₓ)·conj(eₓ)) · δK(δt) dt = 0
    -- where eⱼ = exp(2πiλⱼt), |λᵢ-λₓ| ≥ δ
    --
    -- PROOF DECOMPOSITION:
    -- 1. eᵢ·conj(eₓ) = exp(2πi(λᵢ-λₓ)t) [exp algebra]
    -- 2. Let c = aᵢ·conj(aₓ), ω = λᵢ-λₓ
    -- 3. Re(c·exp(iωt)) = Re(c)·cos(ωt) - Im(c)·sin(ωt)
    -- 4. ∫ Re(c)·cos(ωt)·δK(δt) = Re(c)·Λ(ω/δ) [cross_term_integral]
    -- 5. ∫ Im(c)·sin(ωt)·δK(δt) = Im(c)·0 [sin × even = odd, ∫ = 0]
    -- 6. Λ(ω/δ) = 0 [triangle_kronecker: |ω|/δ ≥ 1]
    -- 7. Total = Re(c)·0 - Im(c)·0 = 0
    --
    -- Steps 4,6 use PROVED lemmas (cross_term_integral, triangle_kronecker).
    -- Step 5 uses parity (odd × even function over ℝ integrates to 0).
    -- Steps 1-3 are algebraic wiring.
    --
    -- Establish the frequency gap
    have h_gap : δ ≤ |lam i - lam x| := h_sep i x hix
    -- triangle_kronecker: Λ((λᵢ-λₓ)/δ) = 0 since i ≠ x
    have h_tri_zero : triangleFunction ((lam i - lam x) / δ) = 0 := by
      have := triangle_kronecker hδ h_sep i x
      rw [if_neg hix] at this; exact this
    -- The cross-term integral gives:
    -- ∫ cos(2π(lam i - lam x)t) · δK(δt) = Λ((lam i - lam x)/δ) = 0
    have h_cos_zero : ∫ t : ℝ, Real.cos (2 * π * (lam i - lam x) * t) *
        (δ * fejerKernel (δ * t)) = 0 := by
      rw [cross_term_integral _ _ hδ, h_tri_zero]
    -- The sin integral vanishes by parity (sin is odd, K is even):
    -- ∫ sin(2π(lam i - lam x)t) · δK(δt) = 0
    have h_sin_zero : ∫ t : ℝ, Real.sin (2 * π * (lam i - lam x) * t) *
        (δ * fejerKernel (δ * t)) = 0 := by
      -- Parity argument: sin(ωt) is odd, δK(δt) is even
      -- So the integrand is odd: f(-t) = sin(-ωt)·δK(-δt) = -sin(ωt)·δK(δt) = -f(t)
      -- ∫ f(t) dt = ∫ f(-t) dt [COV t→-t, Lebesgue measure invariant]
      --           = ∫ -f(t) dt = -∫ f(t) dt
      -- So 2·∫ f = 0, hence ∫ f = 0
      set f := fun t => Real.sin (2 * π * (lam i - lam x) * t) * (δ * fejerKernel (δ * t))
      -- f(-t) = -f(t) because sin is odd and K is even
      have h_odd : ∀ t, f (-t) = -f t := by
        intro t; simp only [f]
        rw [show 2 * π * (lam i - lam x) * (-t) = -(2 * π * (lam i - lam x) * t) from by ring,
           Real.sin_neg,
           show δ * (-t) = -(δ * t) from by ring,
           fejerKernel_even]
        ring
      -- COV t → -t: ∫ f(t) = ∫ f(-t) [Lebesgue measure is symmetric]
      have h_cov : ∫ t, f t = ∫ t, f (-t) := by
        have : (fun t => f (-t)) = (fun t => f ((-1) * t)) := by ext; simp
        rw [this, Measure.integral_comp_mul_left f (-1 : ℝ)]
        simp [abs_of_pos (show (0 : ℝ) < 1 from one_pos)]
      -- ∫ f = ∫ (-f) = -∫ f, so 2∫f = 0
      linarith [show ∫ t, f (-t) = ∫ t, -f t from by congr 1; ext t; exact h_odd t,
                show ∫ t, -f t = -(∫ t, f t) from integral_neg f]
    -- FINAL ASSEMBLY: decompose Re(aᵢeᵢ·conj(aₓ)conj(eₓ)) into cos/sin parts
    -- aᵢeᵢ·conj(aₓ)conj(eₓ) = (aᵢ·conj aₓ)·(eᵢ·conj eₓ) = c·exp(2πi(λᵢ-λₓ)t)
    -- Re(c·exp(iωt)) = Re(c)·cos(ωt) - Im(c)·sin(ωt)
    set c := a i * (starRingEnd ℂ) (a x) with hc_def
    set ω := lam i - lam x with hω_def
    -- Rewrite integrand: Re(aᵢeᵢ·conj aₓ·conj eₓ)·w = (Re(c)·cos(ωt) - Im(c)·sin(ωt))·w
    have h_decomp : ∀ t : ℝ,
      (a i * cexp (2 * ↑π * ↑(lam i) * ↑t * I) *
        ((starRingEnd ℂ) (a x) * (starRingEnd ℂ) (cexp (2 * ↑π * ↑(lam x) * ↑t * I)))).re *
        (δ * fejerKernel (δ * t)) =
      c.re * (Real.cos (2 * π * ω * t) * (δ * fejerKernel (δ * t))) -
      c.im * (Real.sin (2 * π * ω * t) * (δ * fejerKernel (δ * t))) := by
      intro t
      -- Factor out the weight: suffices to prove the Re identity
      suffices h_re : (a i * cexp (2 * ↑π * ↑(lam i) * ↑t * I) *
        ((starRingEnd ℂ) (a x) * (starRingEnd ℂ) (cexp (2 * ↑π * ↑(lam x) * ↑t * I)))).re =
        c.re * Real.cos (2 * π * ω * t) - c.im * Real.sin (2 * π * ω * t) by
        rw [h_re]; ring
      -- Step 1: Rearrange to c * (exp(λᵢ) * conj(exp(λₓ)))
      have h1 : a i * cexp (2 * ↑π * ↑(lam i) * ↑t * I) *
        ((starRingEnd ℂ) (a x) * (starRingEnd ℂ) (cexp (2 * ↑π * ↑(lam x) * ↑t * I))) =
        c * (cexp (2 * ↑π * ↑(lam i) * ↑t * I) *
          (starRingEnd ℂ) (cexp (2 * ↑π * ↑(lam x) * ↑t * I))) := by
        -- (a i * e_i) * (conj(a x) * conj(e_x)) = (a i * conj(a x)) * (e_i * conj(e_x))
        simp only [hc_def, mul_assoc, mul_comm ((starRingEnd ℂ) (a x)), mul_left_comm]
      rw [h1]
      -- Step 2: conj(exp(2πiλₓt)) = exp(-2πiλₓt)
      have h_conj : (starRingEnd ℂ) (cexp (2 * ↑π * ↑(lam x) * ↑t * I)) =
          cexp (-(2 * ↑π * ↑(lam x) * ↑t * I)) := by
        rw [← Complex.exp_conj]
        congr 1
        simp [map_mul, Complex.conj_I, Complex.conj_ofReal, map_ofNat]
      rw [h_conj]
      -- Step 3: exp(a) * exp(-b) = exp(a-b)
      rw [← Complex.exp_add]
      -- Combine exponents: 2πiλᵢt + (-2πiλₓt) = 2πiωt
      have h_arg : 2 * ↑π * ↑(lam i) * ↑t * I + -(2 * ↑π * ↑(lam x) * ↑t * I) =
          ↑(2 * π * ω * t) * I := by
        push_cast [hω_def]; ring
      rw [h_arg]
      -- Step 4: exp(↑θ * I) = ↑(cos θ) + ↑(sin θ) * I (Euler's formula)
      rw [Complex.exp_mul_I]
      -- Step 5: Re(c * (↑cos + ↑sin * I)) = c.re * cos - c.im * sin
      -- exp_mul_I gives: ↑(Real.cos θ) + ↑(Real.sin θ) * I
      -- so Re(c * this) = c.re * cos - c.im * sin by direct complex mul
      simp only [Complex.mul_re, Complex.add_re, Complex.add_im,
            Complex.ofReal_re, Complex.ofReal_im,
            Complex.mul_im, Complex.I_re, Complex.I_im, mul_zero, mul_one,
            sub_zero, zero_mul, add_zero, zero_add,
            ← Complex.ofReal_cos, ← Complex.ofReal_sin]
    simp_rw [h_decomp]
    -- ∫ (c.re·cos·w - c.im·sin·w) = c.re·∫cos·w - c.im·∫sin·w = 0 - 0 = 0
    have h_eq : ∀ t, c.re * (Real.cos (2 * π * ω * t) * (δ * fejerKernel (δ * t))) -
        c.im * (Real.sin (2 * π * ω * t) * (δ * fejerKernel (δ * t))) =
        (fun t => c.re * (Real.cos (2 * π * ω * t) * (δ * fejerKernel (δ * t)))) t -
        (fun t => c.im * (Real.sin (2 * π * ω * t) * (δ * fejerKernel (δ * t)))) t := by
      intro t; rfl
    simp_rw [h_eq]
    -- Integrability: bounded trig × integrable weight (Integrable.bdd_mul)
    -- δK(δt) is integrable by FK3 + COV (proved in cross_term_integral)
    have h_wt : Integrable (fun t => δ * fejerKernel (δ * t)) := by
      -- FK is integrable → FK(δ·) is integrable → δ·FK(δ·) is integrable
      exact (fejerKernel_integrable.comp_mul_left' (ne_of_gt hδ)).const_mul δ
    have h_int_cos : Integrable (fun t => Real.cos (2 * π * ω * t) *
        (δ * fejerKernel (δ * t))) :=
      h_wt.bdd_mul (Real.continuous_cos.comp (continuous_const.mul continuous_id)).aestronglyMeasurable
        (by filter_upwards; intro t; rw [Real.norm_eq_abs]; exact Real.abs_cos_le_one _)
    have h_int_sin : Integrable (fun t => Real.sin (2 * π * ω * t) *
        (δ * fejerKernel (δ * t))) :=
      h_wt.bdd_mul (Real.continuous_sin.comp (continuous_const.mul continuous_id)).aestronglyMeasurable
        (by filter_upwards; intro t; rw [Real.norm_eq_abs]; exact Real.abs_sin_le_one _)
    rw [integral_sub (h_int_cos.const_mul _) (h_int_sin.const_mul _)]
    simp only [integral_const_mul, h_cos_zero, h_sin_zero, mul_zero, sub_self]

-- ═══════════════════════════════════════════════
-- §4. THE FEJÉR-WEIGHTED MVT
-- ═══════════════════════════════════════════════

/-- **NON-NEGATIVITY**: The Fejér-weighted L² integral is non-negative.
    Follows immediately from FK1 (fejerKernel_nonneg). -/
theorem fejerWeightedL2_nonneg
    {N : ℕ} (a : Fin N → ℂ) (lam : Fin N → ℝ) (δ : ℝ) (hδ : 0 < δ) :
    0 ≤ fejerWeightedL2 a lam δ := by
  unfold fejerWeightedL2
  apply integral_nonneg
  intro t
  apply mul_nonneg
  · exact sq_nonneg _
  · apply mul_nonneg (le_of_lt hδ)
    exact fejerKernel_nonneg _

/-- **GALLAGHER MVT (Fejér-weighted version)**:
    For δ-separated frequencies and the Fejér weight δ·K(δt):

      ∫_ℝ |Σ aₙ e^{2πiλₙt}|² · δ · K(δt) dt = Σ |aₙ|²

    This is an EXACT IDENTITY, not an inequality.
    It bypasses Montgomery-Vaughan entirely. -/
theorem gallagher_mvt
    {N : ℕ} (a : Fin N → ℂ) (lam : Fin N → ℝ) (δ : ℝ) (hδ : 0 < δ)
    (h_sep : IsDeltaSeparated lam δ) :
    ∫ t : ℝ, ‖trigPoly a lam t‖ ^ 2 * (δ * fejerKernel (δ * t)) =
    ∑ n : Fin N, ‖a n‖ ^ 2 :=
  fejer_orthogonality a lam δ hδ h_sep

-- ═══════════════════════════════════════════════
-- §5. COROLLARIES
-- ═══════════════════════════════════════════════

-- **UPPER BOUND**: The sharp-interval integral is bounded by the
-- Fejér-weighted integral (divided by the minimum of K on the interval).
--
-- For |t| ≤ T with δ chosen appropriately:
--   ∫_{-T}^{T} |f(t)|² dt ≤ C(δ,T) · Σ |aₙ|²
--
-- The optimal C(δ,T) = 2T + O(1/δ) recovers the classical MVT.

-- For the Cathedral, the direct application is:
-- The Crown Axiom needs ∫_ℝ |M|² ≤ C/logN.
-- By structural decomposition M = R + (ζ/s)·D (PROVED),
-- the Fejér orthogonality gives control of ∫|D|²·w
-- and the rational part R is explicitly bounded.

-- ═══════════════════════════════════════════════
-- §6. AUDIT
-- ═══════════════════════════════════════════════

-- PROVED (zero sorry):
--   ✅ trigPoly — definition
--   ✅ fejerWeightedL2 — definition
--   ✅ fejerWeightedL2_nonneg — K ≥ 0 (from FK1, PROVED)
--   ✅ fejerKernel_fourier_eq_triangle — ∫ K·cos = Λ (HilbertInequality, PROVED)
--
-- SORRY (2, both ASSEMBLY of proved components):
--   🟡 cross_term_integral — COV + fejerKernel_fourier_eq_triangle
--   🟡 fejer_orthogonality — |f|² expansion + FK4 + FK3
--
-- These sorrys use ONLY proved infrastructure:
--   - fejerKernel_fourier_eq_triangle (PROVED, HilbertInequality.lean)
--   - triangleFunction_support (PROVED)
--   - triangleFunction_zero (PROVED)
--   - integral_comp_mul_left (Mathlib)
--   - integral_finset_sum (Mathlib)

end Cathedral.Analysis

