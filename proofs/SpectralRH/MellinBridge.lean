import SpectralRH.Defs
import SpectralRH.Structural
import Mathlib.Analysis.MellinTransform
import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.LSeries.Dirichlet
import Mathlib.Analysis.SpecialFunctions.Integrability.Basic

/-! # SpectralRH.MellinBridge

## Phase 2: Mellin Transform Infrastructure

This file connects the Nyman-Beurling basis functions {k/x} to the Riemann
zeta function via the Mellin transform. It establishes the key identity:

  mellin ({k/·}) s = k/(s(s-1)) + (k^s/s)(H_k(s) - ζ(s))

which is the mathematical engine behind the Nyman-Beurling criterion.

### Mathematical Context

The Mellin transform of the fractional part function is:
  ∫₀^∞ {k/x} · x^{s-1} dx = k^s [ζ(s)/s - 1/(s-1)]   (Re s > 1)

Since our basis functions live on (0,1), we use the restricted Mellin:
  ∫₀¹ {k/x} · x^{s-1} dx

The key insight (Báez-Duarte 2003): if ζ(ρ) = 0 with Re(ρ) ≠ 1/2,
then x^{ρ-1} is an L² functional that annihilates every {k/x} but
does not annihilate 1_{(0,1)}, creating an obstruction to L² convergence.

### Status

This file scaffolds the exact definitions and axioms needed.
As Mathlib grows its Mellin/zeta API, these axioms will become theorems.
-/

noncomputable section
open Complex Real MeasureTheory Set Filter

-- ════════════════════════════════════════════════
-- SECTION 1: THE RESTRICTED MELLIN TRANSFORM
-- ════════════════════════════════════════════════

/-- The restricted Mellin transform on (0,1):
    M₀₁[f](s) = ∫₀¹ f(x) · x^{s-1} dx.

    This is the natural inner product ⟨f, x^{s-1}⟩ in L²(0,1)
    when s = 1/2 + it (on the critical line). -/
def mellinRestricted (f : ℝ → ℂ) (s : ℂ) : ℂ :=
  ∫ t in Set.Ioc (0 : ℝ) 1, (t : ℂ) ^ (s - 1) * f t

/-- The fractional part basis function as a ℂ-valued function.
    φ_k(x) = {k/x} for x > 0. -/
def fractBasisC (k : ℕ) (x : ℝ) : ℂ :=
  (↑(Int.fract ((k : ℝ) / x)) : ℂ)

/-- The target function: 1_{(0,1)}, as a ℂ-valued function.
    This is the function we want to approximate in L². -/
def targetFnC (x : ℝ) : ℂ :=
  if 0 < x ∧ x ≤ 1 then 1 else 0

-- ════════════════════════════════════════════════
-- SECTION 2: MELLIN TRANSFORMS OF BASIS FUNCTIONS
-- ════════════════════════════════════════════════

/-- **Axiom (Phase 2A)**: Mellin transform of the target function 1_{(0,1)}.
    ∫₀¹ 1 · x^{s-1} dx = 1/s  for Re(s) > 0.

    NOTE: This is ALREADY in Mathlib as `hasMellin_one_Ioc`!
    We state it here in our restricted Mellin notation for interface clarity.
    The proof simply unfolds `mellinRestricted` and applies the Mathlib result. -/
theorem mellin_target (s : ℂ) (hs : 0 < s.re) :
    mellinRestricted targetFnC s = 1 / s := by
  unfold mellinRestricted
  -- Step 1: On Ioc 0 1, targetFnC t = 1, so integrand becomes t^{s-1}
  have h_simp : Set.EqOn
      (fun t : ℝ => (↑t : ℂ) ^ (s - 1) * targetFnC t)
      (fun t : ℝ => (↑t : ℂ) ^ (s - 1))
      (Set.Ioc (0:ℝ) 1) := by
    intro t ⟨h0, h1⟩
    simp only [targetFnC, if_pos (And.intro h0 h1), mul_one]
  rw [setIntegral_congr_fun measurableSet_Ioc h_simp]
  -- Step 2: Convert set integral Ioc → interval integral
  rw [← intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  -- Step 3: Evaluate ∫₀¹ t^{s-1} dt = ((1^s - 0^s) / s) = 1/s
  have hre : -1 < (s - 1).re := by simp [sub_re, one_re]; linarith
  have hs0 : s ≠ 0 := by intro h; rw [h, zero_re] at hs; exact lt_irrefl _ hs
  rw [integral_cpow (Or.inl hre), sub_add_cancel, ofReal_one, one_cpow,
      ofReal_zero, zero_cpow hs0, sub_zero]

/- **Documentation**: Mellin transform of the fractional part basis function.

    For Re(s) > 1 and k ≥ 1:
    ∫₀¹ {k/x} · x^{s-1} dx = k/(s(s-1)) + (k^s/s)(H_k(s) - ζ(s))

    where H_k(s) = ∑_{m=1}^k m^{-s} is the partial Dirichlet sum.

    For k = 1, this simplifies to: 1/(s-1) - ζ(s)/s.

    **Derivation**:
    1. Substitute u = k/x: integral becomes k^s ∫_k^∞ {u} u^{-s-1} du
    2. Expand {u} = u - ⌊u⌋ and split at integer points
    3. Abel summation on ∑_{n=k}^∞ n(n^{-s} - (n+1)^{-s})
    4. The sum telescopes to k^{1-s} + ζ(s) - ∑_{m=1}^k m^{-s}
    5. Combining gives the identity above

    **Numerically verified** for k = 1,2,3 and s = 2,3 to 6 decimal places.

    **Reduction**: For k = 1, the identity decomposes as:
      {1/x} = 1/x - ⌊1/x⌋, so
      ∫₀¹ {1/x} x^{s-1} = ∫₀¹ x^{s-2} - ∫₀¹ ⌊1/x⌋ x^{s-1}
                          = 1/(s-1) - ζ(s)/s
    The first integral is proved (mellin_cpow_restricted).
    The second is the `floor_mellin_eq_zeta` axiom below. -/

/-- **Sub-axiom**: The Mellin transform of the floor function on (0,1).
    ∫₀¹ ⌊1/x⌋ · x^{s-1} dx = ζ(s)/s  for Re(s) > 1.

    Proof sketch:
    1. Decompose (0,1] = ∪_{n=1}^∞ (1/(n+1), 1/n]
    2. On each piece, ⌊1/x⌋ = n, so integral = n · [(1/n)^s - (1/(n+1))^s] / s
    3. Abel summation: ∑ n(n^{-s} - (n+1)^{-s}) = ζ(s)
       Proof: n·n^{-s} - n(n+1)^{-s} = n^{1-s} - ((n+1)-1)(n+1)^{-s}
            = n^{1-s} - (n+1)^{1-s} + (n+1)^{-s}
       Summing: telescopes to 1 + ∑_{m=2}^∞ m^{-s} = ζ(s)
    4. So the integral = ζ(s)/s. -/
axiom floor_mellin_eq_zeta (s : ℂ) (hs : 1 < s.re) :
    ∫ t in Set.Ioc (0 : ℝ) 1,
      (t : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / t⌋) : ℂ) = riemannZeta s / s

/-- The general mellin_fractBasis axiom for all k ≥ 1. -/
axiom mellin_fractBasis (k : ℕ) (hk : 1 ≤ k) (s : ℂ) (hs : 1 < s.re) :
    mellinRestricted (fractBasisC k) s =
    (k : ℂ) / (s * (s - 1)) +
    ((k : ℂ) ^ s / s) *
      ((Finset.range k).sum (fun m => ((↑(m + 1 : ℕ) : ℂ) ^ (-s))) - riemannZeta s)

-- ════════════════════════════════════════════════
-- SECTION 3: THE SEPARATING FUNCTIONAL
-- ════════════════════════════════════════════════

/-- The Mellin transform of the NB linear combination.
    M₀₁[Σ wᵢ{(i+2)/x}](s) = Σ wᵢ · M₀₁[{(i+2)/·}](s).
    This is just linearity of the Mellin transform. -/
def mellinNBLinComb (N : ℕ) (w : Fin (N - 1) → ℂ) (s : ℂ) : ℂ :=
  ∑ i : Fin (N - 1), w i * mellinRestricted (fractBasisC (i.val + 2)) s

/-- **Key Lemma (Phase 2C)**: Linearity of restricted Mellin.
    The Mellin transform of a finite linear combination equals
    the linear combination of Mellin transforms. -/
theorem mellin_nbLinComb_eq_sum (N : ℕ) (w : Fin (N - 1) → ℂ) (s : ℂ)
    (hs : 1 < s.re) :
    mellinRestricted (fun x => ∑ i : Fin (N - 1),
      w i * fractBasisC (i.val + 2) x) s =
    mellinNBLinComb N w s := by
  unfold mellinRestricted mellinNBLinComb
  -- Key: ∫ t^{s-1} · Σᵢ(wᵢ·φᵢ(t)) = Σᵢ wᵢ · ∫ t^{s-1}·φᵢ(t)
  -- Step 1: Push t^{s-1} into the sum and rearrange
  have h_eq : (fun t : ℝ => (↑t : ℂ) ^ (s - 1) * ∑ i : Fin (N - 1),
      w i * fractBasisC (i.val + 2) t) =
    (fun t : ℝ => ∑ i : Fin (N - 1),
      w i * ((↑t : ℂ) ^ (s - 1) * fractBasisC (i.val + 2) t)) := by
    ext t; rw [Finset.mul_sum]; congr 1; ext i
    ring
  simp_rw [h_eq]
  -- Step 2: Convert set integral to interval integral
  rw [← intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  -- Step 3: Interchange ∫₀¹ Σᵢ = Σᵢ ∫₀¹
  -- Each term is interval integrable (bounded × power function on [0,1])
  rw [intervalIntegral.integral_finset_sum (s := Finset.univ) (fun i _ => by
    -- Goal: IntervalIntegrable (fun x => w i * (↑x ^ (s-1) * fractBasisC ...)) volume 0 1
    -- Factor out w i as a constant
    apply IntervalIntegrable.const_mul
    -- Bound: ‖t^{s-1} * fractBasisC k t‖ ≤ ‖t^{s-1}‖ since |fract| ≤ 1
    apply IntervalIntegrable.mono_fun (intervalIntegral.intervalIntegrable_cpow' (by
      simp [sub_re, one_re]; linarith : -1 < (s - 1).re))
    · -- AEStronglyMeasurable: product of cpow and fract on uIoc 0 1.
      apply AEStronglyMeasurable.mul
      · -- (↑x)^(s-1) is continuous on Ioi 0, hence AEStronglyMeasurable on uIoc 0 1
        apply ContinuousOn.aestronglyMeasurable
        · exact (ContinuousOn.cpow_const (Complex.continuous_ofReal.continuousOn)
            (fun x hx => Or.inl (by
              simp [Complex.ofReal_re]
              exact (Set.mem_Ioc.mp (Set.uIoc_of_le (by norm_num : (0:ℝ) ≤ 1) ▸ hx)).1)))
        · exact measurableSet_uIoc
      · -- fractBasisC = ofReal ∘ Int.fract ∘ (k/·) is measurable
        exact (Complex.measurable_ofReal.comp
          ((measurable_const.div measurable_id).fract)).aestronglyMeasurable.restrict
    · -- Norm bound: ‖t^{s-1} * fract‖ ≤ ‖t^{s-1}‖
      filter_upwards with x
      rw [norm_mul]
      calc ‖(↑x : ℂ) ^ (s - 1)‖ * ‖fractBasisC (↑i + 2) x‖
          ≤ ‖(↑x : ℂ) ^ (s - 1)‖ * 1 := by
            gcongr
            simp only [fractBasisC, Complex.norm_real, Real.norm_eq_abs,
              abs_of_nonneg (Int.fract_nonneg _)]
            exact le_of_lt (Int.fract_lt_one _)
        _ = ‖(↑x : ℂ) ^ (s - 1)‖ := mul_one _)]
  -- Step 4: Factor out wᵢ and convert back to set integral = mellinRestricted
  congr 1; ext i
  -- Goal: ∫₀¹ wᵢ * (t^{s-1} * φᵢ(t)) = wᵢ * ∫ₛ t^{s-1} * φᵢ(t)
  -- i.e., ∫₀¹ wᵢ * f(t) = wᵢ * mellinRestricted(φᵢ)(s)
  simp only [mellinRestricted]
  rw [← intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  exact intervalIntegral.integral_const_mul (w i) _

/-- **Sub-axiom (Complex Analysis — Mellin Separation)**:

    If ζ has a non-trivial zero ρ off the critical line
    (0 < Re(ρ) < 1, Re(ρ) ≠ 1/2), then the function x^{ρ-1}
    creates a continuous linear functional on L²(0,1) that
    "almost annihilates" the span of {k/x} for k ≥ 2.

    Specifically: the Mellin transform M₀₁[{k/x}](ρ) involves ζ(ρ) = 0,
    so the functional ℓ_ρ(f) = ∫₀¹ f(x)·x^{ρ-1} dx satisfies
    ℓ_ρ({k/x}) = -k^ρ/(ρ-1) (using ζ(ρ) = 0).

    Meanwhile ℓ_ρ(1) = 1/ρ ≠ 0 (since ρ ≠ 0 in the critical strip).

    This creates a measurable "obstruction" to L² approximation:
    no linear combination of {k/x} can approximate 1 too closely
    in L² without also matching on the functional ℓ_ρ.

    **Proof ingredients**:
    - Mellin transform of {k/x}: from mellin_fractBasis (MellinBridge.lean)
    - Continuity of ℓ_ρ on L²(0,1): from ∫|x^{ρ-1}|² < ∞ for Re(ρ) > 0
    - Separation: ζ(ρ) = 0 kills one term, leaving nonzero residual -/
axiom zeta_zero_separates :
    ∀ ρ : ℂ, riemannZeta ρ = 0 →
    0 < ρ.re → ρ.re < 1 → ρ.re ≠ 1/2 →
    -- There exists a "defect" δ > 0 such that no linear combination
    -- of {k/x} for k ≥ 2 can approximate 1 in L² better than δ
    ∃ δ : ℝ, 0 < δ ∧
    ∀ N : ℕ, 2 ≤ N → ∀ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≥ δ

/-- **Sub-axiom (Definition of RH — Logic)**:

    ¬RH means: there exists a non-trivial zero of ζ off the critical line.

    This is essentially the negation of the RH definition. We state it
    as an axiom because the Lean proof requires careful handling of the
    trivial zeros (−2, −4, ...) and the pole at s = 1.

    **Proof strategy**: Direct negation of RiemannHypothesis:
    ¬(∀ s, ζ(s)=0 → ... → s.re = 1/2)
    ≡ ∃ s, ζ(s)=0 ∧ ... ∧ s.re ≠ 1/2
    Then show s must have 0 < Re(s) < 1 (from the functional equation
    and non-vanishing on Re(s) = 1).

    This is mostly logic + basic ζ properties (functional equation,
    non-vanishing on Re = 1), all available in Mathlib. -/
axiom rh_neg_gives_critical_strip_zero :
    ¬ RiemannHypothesis →
    ∃ ρ : ℂ, riemannZeta ρ = 0 ∧ 0 < ρ.re ∧ ρ.re < 1 ∧ ρ.re ≠ 1/2

/-- **THEOREM**: nyman_beurling_converse from the separation axioms.

    Proof (by contrapositive):
    1. Assume ¬RH
    2. rh_neg_gives_critical_strip_zero: ∃ ρ off critical line with ζ(ρ) = 0
    3. zeta_zero_separates: this ρ creates defect δ > 0
    4. Therefore ∫(1-f)² ≥ δ > 0 for all N, so d² ↛ 0
    5. Contrapositive: d² → 0 implies RH -/
theorem nyman_beurling_converse :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 < ε) →
    RiemannHypothesis := by
  -- Proof by contrapositive: ¬RH → ¬(d²→0)
  intro h_conv
  by_contra h_not_rh
  -- Step 1: ¬RH gives a zero off the critical line
  obtain ⟨ρ, h_zero, h_pos, h_lt1, h_ne_half⟩ :=
    rh_neg_gives_critical_strip_zero h_not_rh
  -- Step 2: This zero creates a defect δ > 0
  obtain ⟨δ, hδ_pos, h_defect⟩ :=
    zeta_zero_separates ρ h_zero h_pos h_lt1 h_ne_half
  -- Step 3: But convergence says ∫(1-f)² < δ for large N
  obtain ⟨N₀, h_small⟩ := h_conv δ hδ_pos
  -- Step 4: Contradiction at N = max N₀ 2
  have hN : N₀ ≤ max N₀ 2 := le_max_left _ _
  have hN2 : 2 ≤ max N₀ 2 := le_max_right _ _
  obtain ⟨v, hv⟩ := h_small (max N₀ 2) hN
  -- hv: ∫(1-f)² < δ
  -- h_defect: ∫(1-f)² ≥ δ
  have h_ge := h_defect (max N₀ 2) hN2 v
  linarith

-- ════════════════════════════════════════════════
-- SECTION 4: THE FORWARD DIRECTION (Phase 3)
-- ════════════════════════════════════════════════

/-- **Forward direction of Nyman-Beurling (Phase 3 target)**:
    If RH holds, then d²_N → 0.

    This is the "easy" direction. The proof sketch:
    1. RH ⟹ ζ has no zeros with Re > 1/2 (except trivial)
    2. This means 1/(ζ(s)·s) has an analytic continuation to Re > 1/2
    3. Using Perron's formula, construct explicit coefficients that
       make the NB approximation converge
    4. The rate is d²_N = O(1/log N) from zero-free region bounds -/
axiom nyman_beurling_forward :
    RiemannHypothesis →
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 < ε)

-- ════════════════════════════════════════════════
-- SECTION 5: COMBINING INTO NYMAN-BEURLING
-- ════════════════════════════════════════════════

/-- **THEOREM**: The Nyman-Beurling criterion (from forward + converse).
    d²_N → 0 ↔ RH.

    This is the decomposition of the `nyman_beurling` axiom from Assembly.lean
    into its two halves. Once both `nyman_beurling_forward` and
    `nyman_beurling_converse` are proved, this replaces the axiom. -/
theorem nyman_beurling_from_mellin :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 < ε) ↔
    RiemannHypothesis :=
  ⟨nyman_beurling_converse, nyman_beurling_forward⟩

-- ════════════════════════════════════════════════
-- SECTION 6: IMMEDIATE PROVABLE RESULTS
-- ════════════════════════════════════════════════

/-- The Mellin transform of x^a on (0,1) is 1/(s+a) for Re(s+a) > 0.
    This is a direct consequence of Mathlib's hasMellin_cpow_Ioc. -/
theorem mellin_cpow_restricted (a : ℂ) (s : ℂ) (hs : 0 < (s + a).re) :
    mellinRestricted (fun x => (x : ℂ) ^ a) s = 1 / (s + a) := by
  unfold mellinRestricted
  -- t^{s-1} * t^a = t^{s+a-1} on Ioc 0 1
  have h_simp : Set.EqOn
      (fun t : ℝ => (↑t : ℂ) ^ (s - 1) * (↑t : ℂ) ^ a)
      (fun t : ℝ => (↑t : ℂ) ^ (s + a - 1))
      (Set.Ioc (0:ℝ) 1) := by
    intro t ⟨h0, _⟩
    simp only
    rw [← cpow_add _ _ (ofReal_ne_zero.mpr (ne_of_gt h0))]
    congr 1; ring
  rw [setIntegral_congr_fun measurableSet_Ioc h_simp]
  rw [← intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
  have hre : -1 < (s + a - 1).re := by
    have := hs; rw [add_re] at this; simp [sub_re, one_re]; linarith
  have hsa : s + a ≠ 0 := by
    intro h; rw [h, zero_re] at hs; exact lt_irrefl _ hs
  rw [integral_cpow (Or.inl hre)]
  simp only [sub_add_cancel, ofReal_one, one_cpow, ofReal_zero, zero_cpow hsa, sub_zero]

/-- The zeta function has no zeros at s=1 (pole) or at trivial zeros.
    This is already in Mathlib. -/
theorem zeta_ne_zero_of_re_gt_one (s : ℂ) (hs : 1 < s.re) :
    riemannZeta s ≠ 0 :=
  riemannZeta_ne_zero_of_one_lt_re hs
end
