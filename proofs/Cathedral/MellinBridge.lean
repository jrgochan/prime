import Cathedral.Defs
import Cathedral.Structural
import Mathlib.Analysis.MellinTransform
import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.LSeries.Dirichlet
import Mathlib.NumberTheory.LSeries.Nonvanishing
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

-- ════════════════════════════════════════════════
-- HELPER LEMMAS for floor_mellin_eq_zeta
-- Proven constructively from Mathlib primitives.
-- ════════════════════════════════════════════════

/-- On Ioc(1/(n+1), 1/n), ⌊1/t⌋ = n. -/
private lemma floor_inv_eq_on_Ioc (n : ℕ) (hn : 1 ≤ n)
    (t : ℝ) (ht_lo : 1 / ((n : ℝ) + 1) < t) (ht_hi : t ≤ 1 / (n : ℝ)) :
    ⌊(1 : ℝ) / t⌋ = (n : ℤ) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hn1_pos : (0 : ℝ) < (n : ℝ) + 1 := by linarith
  have ht_pos : (0 : ℝ) < t := by linarith [div_pos one_pos hn1_pos]
  rw [Int.floor_eq_iff]
  constructor
  · rw [Int.cast_natCast, le_div_iff₀ ht_pos]
    nlinarith [mul_div_cancel₀ (1 : ℝ) (ne_of_gt hn_pos)]
  · rw [Int.cast_natCast, div_lt_iff₀ ht_pos]
    nlinarith [mul_div_cancel₀ (1 : ℝ) (ne_of_gt hn1_pos)]

/-- Per-piece integral: ∫_{1/(n+1)}^{1/n} t^{s-1} dt = [(1/n)^s - (1/(n+1))^s]/s. -/
private lemma integral_cpow_piece' (s : ℂ) (hs : 1 < s.re) (n : ℕ) (_hn : 1 ≤ n) :
    ∫ t in (1/((n:ℝ)+1))..(1/(n:ℝ)),
      (↑t : ℂ) ^ (s - 1) =
    ((↑(1/(n:ℝ)) : ℂ) ^ s - (↑(1/((n:ℝ)+1)) : ℂ) ^ s) / s := by
  rw [integral_cpow (Or.inl (by simp [sub_re, one_re]; linarith : -1 < (s-1).re)), sub_add_cancel]

/-- (1/n)^s = (n^s)⁻¹ for positive n, via the complex cpow API. -/
private lemma ofReal_inv_cpow' (n : ℕ) (_hn : 1 ≤ n) (s : ℂ) :
    (↑(1 / (n : ℝ)) : ℂ) ^ s = ((↑(n : ℝ) : ℂ) ^ s)⁻¹ := by
  rw [one_div, ofReal_inv]
  exact inv_cpow _ _ (by
    rw [arg_ofReal_of_nonneg (le_of_lt (Nat.cast_pos.mpr (by omega)))]
    exact ne_of_gt Real.pi_pos |>.symm)

/-- Abel summation by induction: ∑ (n+1)(aₙ₊₁ - aₙ₊₂) = ∑ aₙ₊₁ - N·aₙ₊₁.
    Pure linear algebra — zero sorry, zero axioms. -/
private lemma abel_sum' (a : ℕ → ℂ) : ∀ N : ℕ,
    ∑ n ∈ Finset.range N, (↑(n + 1) : ℂ) * (a (n + 1) - a (n + 2)) =
    ∑ n ∈ Finset.range N, a (n + 1) - (↑N : ℂ) * a (N + 1) := by
  intro N; induction N with
  | zero => simp
  | succ k ih =>
    rw [Finset.sum_range_succ, Finset.sum_range_succ, ih]
    push_cast; ring

/-- The partial Abel sum connects to partial ζ sums. -/
private lemma partial_sum_eq' (s : ℂ) (N : ℕ) :
    ∑ n ∈ Finset.range N,
      (↑(n + 1) : ℂ) * ((↑(1/((n:ℝ)+1)) : ℂ) ^ s - (↑(1/((n:ℝ)+2)) : ℂ) ^ s) / s =
    (∑ n ∈ Finset.range N, (↑(1/((n:ℝ)+1)) : ℂ) ^ s -
      (↑N : ℂ) * (↑(1/((N:ℝ)+1)) : ℂ) ^ s) / s := by
  have hab := abel_sum' (fun n => (↑(1/(n:ℝ)) : ℂ) ^ s) N
  rw [← Finset.sum_div]; congr 1
  convert hab using 2 <;> simp [Nat.cast_add, Nat.cast_one]

/-- Converts partial sums from ofReal form to 1/n^s form for ζ connection. -/
private lemma partial_zeta_eq' (s : ℂ) (_hs : 1 < s.re) (N : ℕ) :
    ∑ n ∈ Finset.range N, (↑(1/((n:ℝ)+1)) : ℂ) ^ s =
    ∑ n ∈ Finset.range N, 1 / (↑((n:ℝ)+1) : ℂ) ^ s := by
  congr 1; ext n
  have h := ofReal_inv_cpow' (n+1) (by omega) s
  rw [show (1 / ((n : ℝ) + 1)) = (1 / (↑(n + 1) : ℝ)) from by push_cast; ring] at *
  rw [h, inv_eq_one_div]
  congr 1; push_cast; ring

/-- ‖(↑x)^s‖ = x^{Re(s)} for x > 0, proved from cpow_def. -/
private lemma norm_ofReal_cpow (x : ℝ) (hx : 0 < x) (s : ℂ) : ‖(↑x : ℂ) ^ s‖ = x ^ s.re := by
  rw [cpow_def_of_ne_zero (ofReal_ne_zero.mpr (ne_of_gt hx))]
  rw [norm_exp, mul_re, log_re, log_im, arg_ofReal_of_nonneg (le_of_lt hx)]
  simp [abs_of_pos hx]
  exact (rpow_def_of_pos hx s.re).symm

open Topology in
/-- (N+1)^{1-σ} → 0 for σ > 1, via `tendsto_rpow_neg_atTop`. -/
private lemma rpow_neg_tendsto' (σ : ℝ) (hσ : 1 < σ) :
    Tendsto (fun N : ℕ => ((N : ℝ) + 1) ^ (1 - σ)) atTop (nhds 0) := by
  have hp : 0 < σ - 1 := by linarith
  have h1 : Tendsto (fun N : ℕ => ((N : ℝ) + 1)) atTop atTop :=
    tendsto_atTop_add_const_right _ 1 tendsto_natCast_atTop_atTop
  have h2 := (tendsto_rpow_neg_atTop hp).comp h1
  refine h2.congr (fun N => ?_)
  simp only [Function.comp]; congr 1; ring

open Topology in
/-- N·(1/(N+1))^s → 0 as N → ∞ for Re(s) > 1.
    Proof: ‖N·(1/(N+1))^s‖ ≤ (N+1)^{1-Re(s)} → 0 by squeeze.
    Zero sorry, zero axioms. -/
private lemma tail_vanishes' (s : ℂ) (hs : 1 < s.re) :
    Tendsto (fun N : ℕ => (↑N : ℂ) * (↑(1/((N:ℝ)+1)) : ℂ) ^ s) atTop (nhds 0) := by
  apply NormedAddGroup.tendsto_nhds_zero.mpr
  intro ε hε
  have h_tail := NormedAddGroup.tendsto_nhds_zero.mp (rpow_neg_tendsto' s.re hs) ε hε
  filter_upwards [h_tail] with N hN
  have hN1 : (0 : ℝ) < (N : ℝ) + 1 := by positivity
  calc ‖(↑N : ℂ) * (↑(1/((N:ℝ)+1)) : ℂ) ^ s‖
      = (N : ℝ) * ‖(↑(1/((N:ℝ)+1)) : ℂ) ^ s‖ := by
        rw [norm_mul, Complex.norm_natCast]
    _ = (N : ℝ) * (1 / ((N : ℝ) + 1)) ^ s.re := by
        rw [norm_ofReal_cpow _ (by positivity) _]
    _ ≤ ((N : ℝ) + 1) * (1 / ((N : ℝ) + 1)) ^ s.re := by
        apply mul_le_mul_of_nonneg_right _
          (rpow_nonneg (by positivity : (0:ℝ) ≤ 1/((N:ℝ)+1)) s.re)
        show (N : ℝ) ≤ (N : ℝ) + 1; linarith
    _ = ((N : ℝ) + 1) * ((N : ℝ) + 1) ^ (-s.re) := by
        congr 1; rw [one_div]
        rw [inv_rpow (by positivity : (0:ℝ) ≤ (N:ℝ)+1), rpow_neg (by positivity)]
    _ = ((N : ℝ) + 1) ^ (1 - s.re) := by
        rw [mul_comm, ← rpow_add_one (ne_of_gt hN1)]; congr 1; ring
    _ ≤ ‖((N : ℝ) + 1) ^ (1 - s.re)‖ := le_norm_self _
    _ < ε := hN

open Topology in
/-- Partial sums of ζ(s) converge: ∑_{n=0}^{N-1} 1/((n+1)^s) → ζ(s). -/
private lemma partial_zeta_tendsto' (s : ℂ) (hs : 1 < s.re) :
    Tendsto (fun N : ℕ => ∑ n ∈ Finset.range N, 1 / (↑((n:ℝ)+1) : ℂ) ^ s)
      atTop (nhds (riemannZeta s)) := by
  rw [zeta_eq_tsum_one_div_nat_cpow hs]
  have h0 : (1 : ℂ) / (0 : ℂ) ^ s = 0 := by
    rw [zero_cpow (by intro h; rw [h, zero_re] at hs; linarith), div_zero]
  have hS := summable_one_div_nat_cpow.mpr hs
  have hH := hS.hasSum.tendsto_sum_nat
  apply Filter.Tendsto.congr (fun N => _) (hH.comp (tendsto_add_atTop_nat 1))
  intro N; simp only [Function.comp]
  rw [Finset.sum_range_succ']
  simp only [Nat.cast_zero, h0, add_zero]
  congr 1; ext n; congr 1; push_cast; ring

/-- **THEOREM** (was axiom): The Mellin transform of the floor function on (0,1).
    ∫₀¹ ⌊1/x⌋ · x^{s-1} dx = ζ(s)/s  for Re(s) > 1.

    **Proof**: Decompose (0,1] into pieces (1/(n+1), 1/n], evaluate the
    per-piece integral via `integral_cpow`, apply Abel summation, and
    take the limit using `summable_one_div_nat_cpow` and
    `zeta_eq_tsum_one_div_nat_cpow`.

    **STATUS**: All component lemmas fully verified (zero sorry).
    One sorry remains in this theorem body for the integral decomposition
    assembly (connecting the finite partial sums to the set integral). -/
theorem floor_mellin_eq_zeta (s : ℂ) (hs : 1 < s.re) :
    ∫ t in Set.Ioc (0 : ℝ) 1,
      (t : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / t⌋) : ℂ) = riemannZeta s / s := by
  -- The limit of partial Abel sums gives ζ(s)/s (assembly_limit).
  -- The partial sums equal the integral over (1/(N+1), 1) which
  -- converges to the integral over (0,1) as N → ∞.
  sorry

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
  ∑ i : Fin (N - 1), w i * mellinRestricted (fractBasisC (i.val + 1)) s

/-- **Key Lemma (Phase 2C)**: Linearity of restricted Mellin.
    The Mellin transform of a finite linear combination equals
    the linear combination of Mellin transforms. -/
theorem mellin_nbLinComb_eq_sum (N : ℕ) (w : Fin (N - 1) → ℂ) (s : ℂ)
    (hs : 1 < s.re) :
    mellinRestricted (fun x => ∑ i : Fin (N - 1),
      w i * fractBasisC (i.val + 1) x) s =
    mellinNBLinComb N w s := by
  unfold mellinRestricted mellinNBLinComb
  -- Key: ∫ t^{s-1} · Σᵢ(wᵢ·φᵢ(t)) = Σᵢ wᵢ · ∫ t^{s-1}·φᵢ(t)
  -- Step 1: Push t^{s-1} into the sum and rearrange
  have h_eq : (fun t : ℝ => (↑t : ℂ) ^ (s - 1) * ∑ i : Fin (N - 1),
      w i * fractBasisC (i.val + 1) t) =
    (fun t : ℝ => ∑ i : Fin (N - 1),
      w i * ((↑t : ℂ) ^ (s - 1) * fractBasisC (i.val + 1) t)) := by
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
      calc ‖(↑x : ℂ) ^ (s - 1)‖ * ‖fractBasisC (↑i + 1) x‖
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

/-- Helper: cos(π·(n+1)) = (-1)^(n+1).
    Proved by induction using Complex.cos_pi and Complex.cos_add_pi. -/
private lemma cos_pi_mul_succ (n : ℕ) :
    Complex.cos (↑Real.pi * ↑(n + 1)) = (-1) ^ (n + 1) := by
  induction n with
  | zero => simp [Complex.cos_pi]
  | succ k ih =>
    have h1 : (↑Real.pi : ℂ) * (↑(k + 1 + 1) : ℂ) =
              (↑Real.pi : ℂ) * (↑(k + 1) : ℂ) + ↑Real.pi := by
      push_cast; ring
    rw [h1, Complex.cos_add_pi, ih]
    ring

/-- **THEOREM (proved from Mathlib)**: cos(π·n) ≠ 0 for n ≥ 1.

    Since cos(πn) = (-1)^n and (-1)^n ≠ 0.

    Proof: By induction using Complex.cos_pi (= -1) and
    Complex.cos_add_pi (cos(x+π) = -cos(x)), we show
    cos(π·(n+1)) = (-1)^{n+1}, which is nonzero. -/
theorem cos_int_mul_pi_ne_zero (n : ℕ) :
    Complex.cos (↑Real.pi * ↑(n + 1)) ≠ 0 := by
  rw [cos_pi_mul_succ]
  exact pow_ne_zero _ (by norm_num : (-1 : ℂ) ≠ 0)



/-- **THEOREM (proved from Mathlib)**: ζ at negative odd integers (and s=1) is nonzero.

    For k = 0: ζ(1) ≠ 0 by riemannZeta_ne_zero_of_one_le_re.
    For k ≥ 1: Uses functional equation (riemannZeta_one_sub):
      ζ(-(2k-1)) = ζ(1-2k) = 2·(2π)^{-2k}·Γ(2k)·cos(πk)·ζ(2k)
    All five factors are nonzero:
      - 2 ≠ 0 (trivial)
      - (2π)^{-2k} ≠ 0 (2π ≠ 0, cpow_eq_zero_iff)
      - Γ(2k) ≠ 0 (Complex.Gamma_ne_zero, 2k ≥ 2 not a non-positive int)
      - cos(πk) ≠ 0 (cos_pi_mul_succ: cos(πk) = (-1)^k)
      - ζ(2k) ≠ 0 (riemannZeta_ne_zero_of_one_le_re, Re(2k) ≥ 2) -/
theorem zeta_neg_odd_ne_zero (k : ℕ) :
    riemannZeta (↑(-(2 * (k : ℤ) - 1))) ≠ 0 := by
  cases k with
  | zero =>
    norm_num
    exact riemannZeta_ne_zero_of_one_le_re le_rfl
  | succ n =>
    have h_eq : (↑(-(2 * (↑(n + 1) : ℤ) - 1)) : ℂ) = 1 - ↑(2 * (n + 1) : ℕ) := by
      push_cast; ring
    rw [h_eq]
    have hs : ∀ m : ℕ, (↑(2 * (n + 1) : ℕ) : ℂ) ≠ -↑m := by
      intro m h; have := congr_arg Complex.re h; simp at this
      linarith [Nat.cast_nonneg (α := ℝ) m]
    have hs1 : (↑(2 * (n + 1) : ℕ) : ℂ) ≠ 1 := by
      intro h; have := congr_arg Complex.re h; simp at this; linarith
    rw [riemannZeta_one_sub hs hs1]
    -- Product of 5 nonzero factors is nonzero
    apply mul_ne_zero
    apply mul_ne_zero
    apply mul_ne_zero
    apply mul_ne_zero
    · -- 2 ≠ 0
      exact two_ne_zero
    · -- (2π)^(-s) ≠ 0: since 2π ≠ 0
      rw [Ne, Complex.cpow_eq_zero_iff]; push_neg; intro h
      exact absurd h (mul_ne_zero two_ne_zero (by exact_mod_cast Real.pi_ne_zero))
    · -- Γ(2(n+1)) ≠ 0: positive integer, not a pole
      apply Complex.Gamma_ne_zero
      intro m h; have := congr_arg Complex.re h; simp at this
      linarith [Nat.cast_nonneg (α := ℝ) m]
    · -- cos(π(n+1)) ≠ 0: cos(πk) = (-1)^k
      have hcos : (↑Real.pi : ℂ) * ↑(2 * (n + 1) : ℕ) / 2 = ↑Real.pi * ↑(n + 1) := by
        push_cast; ring
      rw [hcos, cos_pi_mul_succ]
      exact pow_ne_zero _ (by norm_num : (-1 : ℂ) ≠ 0)
    · -- ζ(2(n+1)) ≠ 0: Re = 2(n+1) ≥ 2 ≥ 1
      exact riemannZeta_ne_zero_of_one_le_re (by simp; linarith [Nat.zero_le n])


/-- **THEOREM (proved from Mathlib + zeta_neg_odd_ne_zero)**:
    Non-trivial zeros of ζ have positive real part.

    Proof by contrapositive: assume Re(s) ≤ 0 and derive contradiction.
    Case analysis on whether s is a non-positive integer:

    A) s not a non-positive integer:
       Functional equation ζ(1-s) = [factors]·ζ(s).
       Since ζ(s) = 0: ζ(1-s) = 0. But Re(1-s) ≥ 1, so ζ(1-s) ≠ 0
       by Mathlib's riemannZeta_ne_zero_of_one_le_re. Contradiction.

    B) s = -n for n : ℕ:
       - n = 0: ζ(0) = -1/2 ≠ 0 (Mathlib: riemannZeta_zero)
       - n+1 even (= 2j): trivial zero, excluded by hypothesis
       - n+1 odd (= 2j+1): ζ ≠ 0 by zeta_neg_odd_ne_zero -/
theorem zeta_nontrivial_zero_re_pos :
    ∀ s : ℂ, riemannZeta s = 0 →
    (¬∃ n : ℕ, s = -2 * (↑n + 1)) →
    0 < s.re := by
  intro s h_zero h_not_triv
  by_contra h_not_pos
  push_neg at h_not_pos
  by_cases h_int : ∃ n : ℕ, s = -(↑n : ℂ)
  · -- Case B: s = -n for some n : ℕ
    obtain ⟨n, rfl⟩ := h_int
    rcases n with _ | m
    · -- n = 0: ζ(0) = -1/2 ≠ 0
      simp at h_zero; rw [riemannZeta_zero] at h_zero; norm_num at h_zero
    · -- n = m+1: even or odd?
      rcases Nat.even_or_odd (m + 1) with ⟨j, hj⟩ | ⟨j, hj⟩
      · -- Even: m+1 = 2j → trivial zero, excluded by hypothesis
        have hj_pos : 1 ≤ j := by omega
        exfalso; apply h_not_triv; refine ⟨j - 1, ?_⟩
        have : (↑(j - 1) : ℂ) + 1 = ↑j := by
          rw [Nat.cast_sub hj_pos]; push_cast; ring
        rw [this]; push_cast [hj]; ring
      · -- Odd: m+1 = 2j+1 → zeta_neg_odd_ne_zero
        have := zeta_neg_odd_ne_zero (j + 1)
        apply this
        have key : (-(2 * (↑(j + 1) : ℤ) - 1)) = -(↑(m + 1) : ℤ) := by omega
        rw [show (↑(-(2 * (↑(j + 1) : ℤ) - 1)) : ℂ) = (↑(-(↑(m + 1) : ℤ)) : ℂ) from
          congr_arg _ key]
        simp only [Int.cast_neg, Int.cast_natCast]
        exact h_zero
  · -- Case A: s is NOT a non-positive integer → functional equation
    push_neg at h_int
    have hs1 : s ≠ 1 := by
      intro heq; rw [heq] at h_not_pos; norm_num at h_not_pos
    have h_func := riemannZeta_one_sub h_int hs1
    have h_1s_zero : riemannZeta (1 - s) = 0 := by rw [h_func, h_zero, mul_zero]
    have h_re : 1 ≤ (1 - s).re := by simp [Complex.sub_re]; linarith
    exact absurd h_1s_zero (riemannZeta_ne_zero_of_one_le_re h_re)

/-- **THEOREM**: ¬RH → ∃ zero in critical strip off critical line.

    Proof:
    1. push_neg on ¬RH: ∃ s with ζ(s) = 0, not trivial, s ≠ 1, Re ≠ 1/2
    2. Re(s) > 0: from zeta_nontrivial_zero_re_pos (functional equation)
    3. Re(s) < 1: from Mathlib's riemannZeta_ne_zero_of_one_le_re
       (if Re(s) ≥ 1 then ζ(s) ≠ 0, contradiction) -/
theorem rh_neg_gives_critical_strip_zero :
    ¬ RiemannHypothesis →
    ∃ ρ : ℂ, riemannZeta ρ = 0 ∧ 0 < ρ.re ∧ ρ.re < 1 ∧ ρ.re ≠ 1/2 := by
  intro h
  -- Push the negation: ∃ s, ζ(s) = 0 ∧ (∀ n, s ≠ ...) ∧ s ≠ 1 ∧ Re(s) ≠ 1/2
  unfold RiemannHypothesis at h
  push_neg at h
  obtain ⟨s, h_zero, h_not_triv, h_ne_1, h_re_ne_half⟩ := h
  -- Convert ∀ n, s ≠ -2*(n+1) back to ¬∃ n, s = -2*(n+1)
  have h_not_triv' : ¬∃ n : ℕ, s = -2 * (↑n + 1) := by
    push_neg; exact h_not_triv
  refine ⟨s, h_zero, ?_, ?_, h_re_ne_half⟩
  · -- 0 < Re(s): from functional equation (axiom)
    exact zeta_nontrivial_zero_re_pos s h_zero h_not_triv'
  · -- Re(s) < 1: from Mathlib (if Re ≥ 1 then ζ ≠ 0)
    by_contra h_ge
    push_neg at h_ge
    exact absurd h_zero (riemannZeta_ne_zero_of_one_le_re h_ge)

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
