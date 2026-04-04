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

/-- The floor-weighted integrand is integrable on (0,1].
    Proof: bound ‖t^{s-1}·⌊1/t⌋‖ ≤ ‖t^{s-2}‖ via ⌊x⌋ ≤ x,
    and t^{s-2} is integrable for Re(s-2) > -1 (i.e., Re(s) > 1). -/
private lemma floor_mellin_integrableOn (s : ℂ) (hs : 1 < s.re) :
    IntegrableOn (fun x : ℝ => (↑x : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / x⌋) : ℂ))
      (Ioc 0 1) volume := by
  have hg : IntegrableOn (fun x : ℝ => (↑x : ℂ) ^ (s - 2)) (Ioc 0 1) volume := by
    have h := @intervalIntegral.intervalIntegrable_cpow' 0 1 (s-2) (by simp [sub_re]; linarith)
    rwa [intervalIntegrable_iff_integrableOn_Ioc_of_le (by linarith : (0:ℝ) ≤ 1)] at h
  exact Integrable.mono hg
    (by apply AEStronglyMeasurable.mul
        · exact (ContinuousOn.cpow continuous_ofReal.continuousOn continuousOn_const
            (fun x hx => by left; simp [ofReal_re]; exact hx) |>.mono Ioc_subset_Ioi_self
            ).aestronglyMeasurable measurableSet_Ioc
        · exact ((Measurable.of_discrete (α := ℤ)).comp
            ((measurable_const.div measurable_id).floor)).aestronglyMeasurable.restrict)
    (by apply ae_restrict_of_ae_restrict_of_subset Ioc_subset_Ioi_self
        apply (ae_restrict_mem measurableSet_Ioi).mono
        intro t ht; rw [mem_Ioi] at ht
        rw [norm_mul, norm_ofReal_cpow t ht, norm_ofReal_cpow t ht]
        simp only [sub_re, one_re]
        have h_nn : (0 : ℤ) ≤ ⌊(1:ℝ)/t⌋ := Int.floor_nonneg.mpr (div_nonneg one_pos.le ht.le)
        rw [Complex.norm_intCast, abs_of_nonneg (by exact_mod_cast h_nn)]
        calc t ^ (s.re - 1) * (⌊(1:ℝ)/t⌋ : ℝ)
            ≤ t ^ (s.re - 1) * (1/t) := mul_le_mul_of_nonneg_left (Int.floor_le _) (rpow_nonneg ht.le _)
          _ = t ^ (s.re - 2) := by
              rw [mul_one_div, div_eq_mul_inv, ← rpow_neg_one t, ← rpow_add ht]; congr 1; ring)

/-- ⋃_N Ioc(1/(N+1), 1) = Ioc(0, 1). -/
private lemma iUnion_Ioc_inv :
    ⋃ N : ℕ, Ioc (1 / ((N : ℝ) + 1)) 1 = Ioc (0 : ℝ) 1 := by
  ext x; simp only [mem_iUnion, mem_Ioc]; constructor
  · rintro ⟨N, hlo, hhi⟩; exact ⟨by linarith [show (0:ℝ) < 1/((N:ℝ)+1) from by positivity], hhi⟩
  · rintro ⟨hx, hx1⟩; obtain ⟨N, hN⟩ := exists_nat_gt (1/x - 1); refine ⟨N, ?_, hx1⟩
    have hN1 : (0:ℝ) < (N:ℝ)+1 := by linarith [Nat.cast_nonneg (α := ℝ) N]
    rw [div_lt_iff₀ hN1]; linarith [(div_lt_iff₀ hx).mp (by linarith : 1/x < (N:ℝ)+1)]

/-- The sequence Ioc(1/(N+1), 1) is monotone. -/
private lemma mono_Ioc_inv : Monotone (fun N : ℕ => Ioc (1 / ((N : ℝ) + 1)) (1 : ℝ)) := by
  intro m n hmn; apply Ioc_subset_Ioc_left
  apply div_le_div_of_nonneg_left (by linarith)
    (by have := Nat.cast_nonneg (α := ℝ) n; linarith)
    (by show (m:ℝ)+1 ≤ (n:ℝ)+1; have : (m:ℝ) ≤ (n:ℝ) := Nat.cast_le.mpr hmn; linarith)

/-- On piece Ioc(1/(n+2), 1/(n+1)), ⌊1/t⌋ = n+1, so the integral
    equals (n+1)·[(1/(n+1))^s - (1/(n+2))^s]/s, the n-th Abel sum term. -/
private lemma piece_setIntegral (s : ℂ) (hs : 1 < s.re) (n : ℕ) :
    ∫ t in Set.Ioc (1/((n:ℝ)+2)) (1/((n:ℝ)+1)),
      (↑t : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / t⌋) : ℂ)
    = (↑(n + 1) : ℂ) * (((↑(1/((n:ℝ)+1)) : ℂ) ^ s -
        (↑(1/((n:ℝ)+2)) : ℂ) ^ s) / s) := by
  -- Step 1: On this piece, ⌊1/t⌋ = n+1, so f(t) = (n+1)·t^{s-1}
  have h_eq_on : Set.EqOn
      (fun t : ℝ => (↑t : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / t⌋) : ℂ))
      (fun t : ℝ => (↑(n + 1) : ℂ) * (↑t : ℂ) ^ (s - 1))
      (Set.Ioc (1/((n:ℝ)+2)) (1/((n:ℝ)+1))) := by
    intro t ⟨ht_lo, ht_hi⟩
    have hfl : ⌊(1:ℝ)/t⌋ = ((n+1 : ℕ) : ℤ) := by
      apply floor_inv_eq_on_Ioc (n+1) (by omega) t
      · rwa [show 1/((↑(n+1:ℕ):ℝ)+1) = 1/((n:ℝ)+2) from by push_cast; ring]
      · rwa [show 1/(↑(n+1:ℕ):ℝ) = 1/((n:ℝ)+1) from by push_cast; ring]
    show (↑t : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / t⌋) : ℂ) =
         (↑(n + 1) : ℂ) * (↑t : ℂ) ^ (s - 1)
    rw [hfl]; push_cast; ring
  -- Step 2: Replace integrand and pull out constant
  rw [setIntegral_congr_fun measurableSet_Ioc h_eq_on]
  rw [show ∫ x in Set.Ioc (1/((n:ℝ)+2)) (1/((n:ℝ)+1)),
        (↑(n+1) : ℂ) * (↑x : ℂ) ^ (s-1) =
      (↑(n+1) : ℂ) * ∫ x in Set.Ioc (1/((n:ℝ)+2)) (1/((n:ℝ)+1)),
        (↑x : ℂ) ^ (s-1) from integral_const_mul _ _]
  congr 1
  -- Step 3: The set integral = the cpow formula = [(1/(n+1))^s - (1/(n+2))^s]/s
  have h := integral_cpow_piece' s hs (n+1) (by omega)
  rw [intervalIntegral.integral_of_le (show 1/((↑(n+1:ℕ):ℝ)+1) ≤ 1/(↑(n+1:ℕ):ℝ) from by
    apply div_le_div_of_nonneg_left (by linarith) (by positivity)
    linarith [Nat.cast_nonneg (α := ℝ) n])] at h
  convert h using 2 <;> push_cast <;> ring

/-- Inductive decomposition: ∫_{Ioc(1/(N+1), 1)} f = partial Abel sum / s. -/
private lemma integral_decomp (s : ℂ) (hs : 1 < s.re) : ∀ N : ℕ,
    ∫ t in Set.Ioc (1/((N:ℝ)+1)) 1,
      (↑t : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / t⌋) : ℂ)
    = ∑ n ∈ Finset.range N,
        (↑(n + 1) : ℂ) * (((↑(1/((n:ℝ)+1)) : ℂ) ^ s -
          (↑(1/((n:ℝ)+2)) : ℂ) ^ s) / s) := by
  intro N; induction N with
  | zero =>
    simp only [Finset.range_zero, Finset.sum_empty]
    convert setIntegral_empty (f := fun t : ℝ => (↑t : ℂ) ^ (s-1) * (↑(⌊(1:ℝ)/t⌋) : ℂ))
    simp
  | succ k ih =>
    -- Ioc(1/(k+2), 1) = Ioc(1/(k+2), 1/(k+1)) ∪ Ioc(1/(k+1), 1)
    let f : ℝ → ℂ := fun x => (↑x : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / x⌋) : ℂ)
    have h_union : Set.Ioc (1/((k:ℝ)+2)) (1/((k:ℝ)+1)) ∪ Set.Ioc (1/((k:ℝ)+1)) 1
        = Set.Ioc (1/((k:ℝ)+2)) 1 := by
      apply Set.Ioc_union_Ioc_eq_Ioc
      · apply div_le_div_of_nonneg_left (by linarith) (by positivity)
        linarith [Nat.cast_nonneg (α := ℝ) k]
      · rw [div_le_one (by positivity : (0:ℝ) < (k:ℝ)+1)]
        linarith [Nat.cast_nonneg (α := ℝ) k]
    have h_disj : Disjoint (Set.Ioc (1/((k:ℝ)+2)) (1/((k:ℝ)+1)))
        (Set.Ioc (1/((k:ℝ)+1)) 1) := Set.Ioc_disjoint_Ioc_of_le le_rfl
    have h_int_full := floor_mellin_integrableOn s hs
    have h_int_piece : IntegrableOn f (Set.Ioc (1/((k:ℝ)+2)) (1/((k:ℝ)+1))) volume :=
      h_int_full.mono_set (fun x ⟨hlo, hhi⟩ => ⟨by
        linarith [div_pos (one_pos) (by positivity : (0:ℝ) < (k:ℝ)+2)], by
        have : 1/((k:ℝ)+1) ≤ 1 := by
          rw [div_le_one (by positivity : (0:ℝ) < (k:ℝ)+1)]
          linarith [Nat.cast_nonneg (α := ℝ) k]
        linarith⟩)
    have h_int_rest : IntegrableOn f (Set.Ioc (1/((k:ℝ)+1)) 1) volume :=
      h_int_full.mono_set (fun x ⟨hlo, hhi⟩ =>
        ⟨by linarith [div_pos (one_pos) (by positivity : (0:ℝ) < (k:ℝ)+1)], hhi⟩)
    -- Split integral over union
    rw [show (↑(k + 1) : ℝ) + 1 = (k : ℝ) + 2 from by push_cast; ring]
    rw [← h_union]
    rw [setIntegral_union h_disj measurableSet_Ioc h_int_piece h_int_rest]
    rw [Finset.sum_range_succ, ih]
    rw [show (↑k : ℝ) + 1 = ((k:ℝ) + 1) from rfl]
    rw [add_comm]
    congr 1
    exact piece_setIntegral s hs k

theorem floor_mellin_eq_zeta (s : ℂ) (hs : 1 < s.re) :
    ∫ t in Set.Ioc (0 : ℝ) 1,
      (t : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / t⌋) : ℂ) = riemannZeta s / s := by
  -- By monotone convergence: partial integrals → full integral
  let f : ℝ → ℂ := fun x => (↑x : ℂ) ^ (s - 1) * (↑(⌊(1 : ℝ) / x⌋) : ℂ)
  have h_tendsto_int : Tendsto
      (fun N : ℕ => ∫ x in Ioc (1/((N:ℝ)+1)) 1, f x)
      atTop (nhds (∫ x in Ioc 0 1, f x)) := by
    rw [← iUnion_Ioc_inv]
    exact tendsto_setIntegral_of_monotone (fun _ => measurableSet_Ioc) mono_Ioc_inv
      (iUnion_Ioc_inv ▸ floor_mellin_integrableOn s hs)
  show ∫ t in Set.Ioc 0 1, f t = riemannZeta s / s
  -- Rewrite partial integrals using integral_decomp
  have h_eq : ∀ N : ℕ, ∫ x in Ioc (1/((N:ℝ)+1)) 1, f x =
      ∑ n ∈ Finset.range N,
        (↑(n + 1) : ℂ) * (((↑(1/((n:ℝ)+1)) : ℂ) ^ s -
          (↑(1/((n:ℝ)+2)) : ℂ) ^ s) / s) := integral_decomp s hs
  -- Rewrite Abel sum using partial_sum_eq'
  have h_eq2 : ∀ N : ℕ, ∫ x in Ioc (1/((N:ℝ)+1)) 1, f x =
      (∑ n ∈ Finset.range N, (↑(1/((n:ℝ)+1)) : ℂ) ^ s -
        (↑N : ℂ) * (↑(1/((N:ℝ)+1)) : ℂ) ^ s) / s := by
    intro N
    rw [h_eq]
    have h := partial_sum_eq' s N
    convert h using 1
    congr 1; ext n; simp [mul_div_assoc]
  -- Build: partial integrals → ζ(s)/s
  -- First: ∑ (1/(n+1))^s → ζ(s)
  have h_zeta := partial_zeta_tendsto' s hs
  have h_zeta' : Tendsto (fun N : ℕ => ∑ n ∈ Finset.range N,
      (↑(1/((n:ℝ)+1)) : ℂ) ^ s) atTop (nhds (riemannZeta s)) := by
    have := h_zeta.congr (fun N => (partial_zeta_eq' s hs N).symm)
    exact this
  -- Second: N·(1/(N+1))^s → 0
  have h_tail := tail_vanishes' s hs
  -- Combine: (∑ - tail) / s → (ζ(s) - 0) / s = ζ(s) / s
  have h_tendsto_abel : Tendsto (fun N : ℕ =>
      (∑ n ∈ Finset.range N, (↑(1/((n:ℝ)+1)) : ℂ) ^ s -
        (↑N : ℂ) * (↑(1/((N:ℝ)+1)) : ℂ) ^ s) / s)
      atTop (nhds (riemannZeta s / s)) := by
    have h_sub := h_zeta'.sub h_tail
    simp only [sub_zero] at h_sub
    exact Tendsto.div_const h_sub s
  -- The partial integrals also tend to ζ(s)/s
  have h_tendsto_zeta : Tendsto (fun N : ℕ =>
      ∫ x in Ioc (1/((N:ℝ)+1)) 1, f x) atTop (nhds (riemannZeta s / s)) := by
    exact h_tendsto_abel.congr (fun N => (h_eq2 N).symm)
  -- By uniqueness of limits
  exact tendsto_nhds_unique h_tendsto_int h_tendsto_zeta

/-- On Ioc(k/(n+1), k/n), ⌊k/t⌋ = n (generalized floor). -/
private lemma floor_div_eq_on_Ioc_gen (k : ℕ) (n : ℕ) (hk : 1 ≤ k) (hn : 1 ≤ n)
    (t : ℝ) (ht_lo : (k : ℝ)/((n : ℝ)+1) < t) (ht_hi : t ≤ (k : ℝ)/(n : ℝ)) :
    ⌊(k : ℝ)/t⌋ = (n : ℤ) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hn1_pos : (0 : ℝ) < (n : ℝ) + 1 := by linarith
  have ht_pos : (0 : ℝ) < t := by linarith [div_pos hk_pos hn1_pos]
  rw [Int.floor_eq_iff]
  constructor
  · rw [Int.cast_natCast, le_div_iff₀ ht_pos]
    nlinarith [mul_div_cancel₀ (k : ℝ) (ne_of_gt hn_pos)]
  · rw [Int.cast_natCast, div_lt_iff₀ ht_pos]
    nlinarith [mul_div_cancel₀ (k : ℝ) (ne_of_gt hn1_pos)]

/-- ∫₀¹ t^{s-1}·(k/t) dt = k/(s-1) for Re(s) > 1. -/
private lemma mellin_div_integral (s : ℂ) (hs : 1 < s.re) (k : ℕ) (_hk : 1 ≤ k) :
    ∫ t in Set.Ioc (0:ℝ) 1, (↑t : ℂ) ^ (s - 1) * ((↑k : ℂ) / (↑t : ℂ)) =
    (↑k : ℂ) / (s - 1) := by
  -- Step 1: Replace integrand with k · t^{s-2}
  have h_eq : Set.EqOn
      (fun t : ℝ => (↑t : ℂ) ^ (s - 1) * ((↑k : ℂ) / (↑t : ℂ)))
      (fun t : ℝ => (↑k : ℂ) * (↑t : ℂ) ^ (s - 2))
      (Set.Ioc (0:ℝ) 1) := by
    intro t ⟨ht_lo, _⟩
    have ht' : (↑t : ℂ) ≠ 0 := ofReal_ne_zero.mpr (ne_of_gt ht_lo)
    show (↑t : ℂ) ^ (s - 1) * ((↑k : ℂ) / (↑t : ℂ)) = (↑k : ℂ) * (↑t : ℂ) ^ (s - 2)
    rw [show (s - 2 : ℂ) = (s - 1) + (-1) from by ring, cpow_add _ _ ht',
        Complex.cpow_neg_one]
    ring
  rw [setIntegral_congr_fun measurableSet_Ioc h_eq]
  -- Step 2: Pull out k
  rw [show ∫ x in Set.Ioc (0:ℝ) 1, (↑k : ℂ) * (↑x : ℂ) ^ (s - 2) =
      (↑k : ℂ) * ∫ x in Set.Ioc (0:ℝ) 1, (↑x : ℂ) ^ (s - 2) from integral_const_mul _ _]
  -- Step 3: Evaluate ∫ t^{s-2} = 1/(s-1)
  rw [← intervalIntegral.integral_of_le (le_of_lt (by linarith : (0:ℝ) < 1))]
  rw [integral_cpow (Or.inl (show -1 < (s - 2).re from by simp [sub_re]; linarith))]
  rw [show s - 2 + 1 = s - 1 from by ring]
  rw [ofReal_one, one_cpow, ofReal_zero,
      zero_cpow (show s - 1 ≠ 0 from by
        intro h; have := congr_arg re h; simp [sub_re, one_re] at this; linarith)]
  rw [sub_zero, mul_one_div]

/-- ⋃_N Ioc(k/(N+1), 1) = Ioc(0, 1). -/
private lemma iUnion_Ioc_gen (k : ℕ) (hk : 1 ≤ k) :
    ⋃ N : ℕ, Ioc ((k:ℝ)/((N:ℝ)+1)) 1 = Ioc (0:ℝ) 1 := by
  ext x; simp only [mem_iUnion, mem_Ioc]; constructor
  · rintro ⟨N, hlo, hhi⟩
    exact ⟨by linarith [show (0:ℝ) < (k:ℝ)/((N:ℝ)+1) from by positivity], hhi⟩
  · rintro ⟨hx, hx1⟩
    obtain ⟨N, hN⟩ := exists_nat_gt ((k:ℝ)/x - 1)
    refine ⟨N, ?_, hx1⟩
    have hN1 : (0:ℝ) < (N:ℝ)+1 := by linarith [Nat.cast_nonneg (α := ℝ) N]
    rw [div_lt_iff₀ hN1]
    linarith [(div_lt_iff₀ hx).mp (by linarith : (k:ℝ)/x < (N:ℝ)+1)]

/-- The sequence Ioc(k/(N+1), 1) is monotone. -/
private lemma mono_Ioc_gen (k : ℕ) (hk : 1 ≤ k) :
    Monotone (fun N : ℕ => Ioc ((k:ℝ)/((N:ℝ)+1)) (1:ℝ)) := by
  intro m n hmn; apply Ioc_subset_Ioc_left
  apply div_le_div_of_nonneg_left
    (show (0:ℝ) ≤ (k:ℝ) from by positivity)
    (show (0:ℝ) < (m:ℝ)+1 from by positivity)
    (show (m:ℝ)+1 ≤ (n:ℝ)+1 from by
      have : (m:ℝ) ≤ (n:ℝ) := by exact_mod_cast hmn
      linarith)

/-- Per-piece integral: ∫ t^{s-1}·n on Ioc(k/(n+1), k/n). -/
private lemma piece_setIntegral_gen (k n : ℕ) (hk : 1 ≤ k) (hn : 1 ≤ n) (s : ℂ) (hs : 1 < s.re) :
    ∫ t in Ioc ((k:ℝ)/((n:ℝ)+1)) ((k:ℝ)/(n:ℝ)),
      (↑t : ℂ) ^ (s - 1) * (↑(⌊(k:ℝ)/t⌋) : ℂ) =
    (↑n : ℂ) * ((↑((k:ℝ)/(n:ℝ)) : ℂ) ^ s - (↑((k:ℝ)/((n:ℝ)+1)) : ℂ) ^ s) / s := by
  -- Replace ⌊k/t⌋ with n on this piece
  have h_eq : Set.EqOn
      (fun t : ℝ => (↑t : ℂ) ^ (s - 1) * (↑(⌊(k:ℝ)/t⌋) : ℂ))
      (fun t : ℝ => (↑t : ℂ) ^ (s - 1) * (↑n : ℂ))
      (Ioc ((k:ℝ)/((n:ℝ)+1)) ((k:ℝ)/(n:ℝ))) := by
    intro t ⟨ht_lo, ht_hi⟩
    have := floor_div_eq_on_Ioc_gen k n hk hn t ht_lo ht_hi
    simp only [this]; push_cast; norm_cast
  rw [setIntegral_congr_fun measurableSet_Ioc h_eq]
  have hab : (k:ℝ)/((n:ℝ)+1) ≤ (k:ℝ)/(n:ℝ) :=
    div_le_div_of_nonneg_left (show (0:ℝ) ≤ k from by positivity) (by positivity)
      (by linarith [show (0:ℝ) < (n:ℝ) from by positivity])
  rw [setIntegral_congr_fun measurableSet_Ioc (fun t _ => mul_comm _ _)]
  rw [show ∫ t in Ioc ((k:ℝ)/((n:ℝ)+1)) ((k:ℝ)/(n:ℝ)), (↑n : ℂ) * (↑t : ℂ) ^ (s - 1) =
      (↑n : ℂ) * ∫ t in Ioc ((k:ℝ)/((n:ℝ)+1)) ((k:ℝ)/(n:ℝ)), (↑t : ℂ) ^ (s - 1)
    from integral_const_mul _ _]
  rw [← intervalIntegral.integral_of_le hab]
  rw [integral_cpow (Or.inl (by simp [sub_re]; linarith))]
  rw [show s - 1 + 1 = s from by ring]; ring

/-- Generalized integrability for floor_div on Ioc(0,1). -/
private lemma floor_div_integrableOn (s : ℂ) (hs : 1 < s.re) (k : ℕ) (hk : 1 ≤ k) :
    IntegrableOn (fun t : ℝ => (↑t : ℂ) ^ (s - 1) * (↑(⌊(k:ℝ)/t⌋) : ℂ))
      (Ioc 0 1) volume := by
  have hg : IntegrableOn (fun x : ℝ => (↑x : ℂ) ^ (s - 2)) (Ioc 0 1) volume := by
    have h := @intervalIntegral.intervalIntegrable_cpow' 0 1 (s-2) (by simp [sub_re]; linarith)
    rwa [intervalIntegrable_iff_integrableOn_Ioc_of_le (by linarith : (0:ℝ) ≤ 1)] at h
  exact Integrable.mono (hg.norm.const_mul (↑k : ℝ))
    (by apply AEStronglyMeasurable.mul
        · exact (ContinuousOn.cpow continuous_ofReal.continuousOn continuousOn_const
            (fun x hx => by left; simp [ofReal_re]; exact hx) |>.mono Ioc_subset_Ioi_self
            ).aestronglyMeasurable measurableSet_Ioc
        · exact ((Measurable.of_discrete (α := ℤ)).comp
            ((measurable_const.div measurable_id).floor)).aestronglyMeasurable.restrict)
    (by apply ae_restrict_of_ae_restrict_of_subset Ioc_subset_Ioi_self
        apply (ae_restrict_mem measurableSet_Ioi).mono
        intro t ht; rw [mem_Ioi] at ht
        rw [norm_mul, norm_ofReal_cpow t ht, norm_ofReal_cpow t ht]
        simp only [sub_re, one_re]
        have h_nn : (0 : ℤ) ≤ ⌊(k:ℝ)/t⌋ := Int.floor_nonneg.mpr (div_nonneg (by positivity) ht.le)
        rw [Complex.norm_intCast, abs_of_nonneg (by exact_mod_cast h_nn)]
        calc t ^ (s.re - 1) * (⌊(k:ℝ)/t⌋ : ℝ)
            ≤ t ^ (s.re - 1) * ((k:ℝ)/t) := mul_le_mul_of_nonneg_left (Int.floor_le _) (rpow_nonneg ht.le _)
          _ = (↑k : ℝ) * t ^ (s.re - 2) := by
              rw [mul_comm, div_mul_eq_mul_div, mul_div_assoc, div_eq_mul_inv, ← rpow_neg_one t,
                  ← rpow_add ht]; congr 1; ring
          _ ≤ ‖(↑k : ℝ) * t ^ (s.re - 2)‖ := le_norm_self _
          _ = _ := by simp)

/-- N·(k/(N+1))^s → 0 as N → ∞ for Re(s) > 1. -/
private lemma tail_vanishes_gen (s : ℂ) (hs : 1 < s.re) (k : ℕ) (_hk : 1 ≤ k) :
    Tendsto (fun N : ℕ => (↑N : ℂ) * (↑((k:ℝ)/((N:ℝ)+1)) : ℂ) ^ s) atTop (nhds 0) := by
  have h_rewrite : ∀ N : ℕ,
      (↑N : ℂ) * (↑((k:ℝ)/((N:ℝ)+1)) : ℂ) ^ s =
      (↑k : ℂ) ^ s * ((↑N : ℂ) * (↑(1/((N:ℝ)+1)) : ℂ) ^ s) := by
    intro N
    have hk_nn : (0:ℝ) ≤ (k:ℝ) := by positivity
    have hN1_nn : (0:ℝ) ≤ 1/((N:ℝ)+1) := by positivity
    rw [show (k:ℝ)/((N:ℝ)+1) = (k:ℝ) * (1/((N:ℝ)+1)) from by ring,
        Complex.ofReal_mul (k:ℝ) (1/((N:ℝ)+1)),
        mul_cpow_ofReal_nonneg hk_nn hN1_nn]
    push_cast; rw [mul_comm (↑N : ℂ), mul_assoc]; congr 1; exact mul_comm _ _
  rw [show (0:ℂ) = (↑k : ℂ) ^ s * 0 from by simp]
  exact (tail_vanishes' s hs).const_mul _ |>.congr (fun N => (h_rewrite N).symm)

/-- Generalized Abel summation: ∑_{i<M} (k+i)·[a_{k+i} - a_{k+i+1}]
    = k·a_k + ∑_{i<M} a_{k+i+1} - (k+M)·a_{k+M+1} - a_k.
    Actually we want: = ∑_{i<M} a_{k+i+1} + k·a_k - (k+M)·a_{k+M+1}
    Simplified: sums ∑_{i=0}^{M-1} (k+i)(a_{k+i} - a_{k+i+1})
    = k·a_k + ∑_{i=1}^{M-1} a_{k+i} - (k+M-1)·a_{k+M}
    We need to match: k + k^s·∑n^{-s} - N·tail form. -/
private lemma abel_sum_gen (a : ℕ → ℂ) (k : ℕ) : ∀ M : ℕ,
    ∑ i ∈ Finset.range M, (↑(k + i) : ℂ) * (a (k + i) - a (k + i + 1)) =
    ∑ i ∈ Finset.range M, a (k + i + 1) + (↑k : ℂ) * a k -
      (↑(k + M) : ℂ) * a (k + M) := by
  intro M; induction M with
  | zero => simp
  | succ m ih =>
    rw [Finset.sum_range_succ, Finset.sum_range_succ, ih]
    push_cast; ring

/-- The partial Abel sum connects to partial ζ sums for the generalized k-floor. -/
private lemma partial_sum_gen (s : ℂ) (k : ℕ) (M : ℕ) :
    ∑ i ∈ Finset.range (M+1),
      (↑(k + i) : ℂ) * ((↑((k:ℝ)/(↑(k+i):ℝ)) : ℂ) ^ s -
        (↑((k:ℝ)/(↑(k+i)+1)) : ℂ) ^ s) / s =
    (∑ i ∈ Finset.range (M+1), (↑((k:ℝ)/(↑(k+i)+1)) : ℂ) ^ s +
      (↑k : ℂ) * (↑((k:ℝ)/(↑k:ℝ)) : ℂ) ^ s -
      (↑(k + (M+1)) : ℂ) * (↑((k:ℝ)/(↑(k+(M+1)):ℝ)) : ℂ) ^ s) / s := by
  have hab := abel_sum_gen (fun n => (↑((k:ℝ)/(↑n:ℝ)) : ℂ) ^ s) k (M+1)
  rw [← Finset.sum_div]; congr 1
  convert hab using 2 <;> simp [Nat.cast_add, Nat.cast_one]

/-- Inductive decomposition: ∫_{Ioc(k/(k+M+1), 1)} f = ∑_{i<M+1} piece(k, k+i).
    By induction on M, splitting Ioc at each step and applying piece_setIntegral_gen. -/
private lemma integral_decomp_gen (s : ℂ) (hs : 1 < s.re) (k : ℕ) (hk : 1 ≤ k) :
    ∀ M : ℕ,
    ∫ t in Set.Ioc ((k:ℝ)/(↑(k+M)+1)) 1,
      (↑t : ℂ) ^ (s - 1) * (↑(⌊(k:ℝ)/t⌋) : ℂ)
    = ∑ i ∈ Finset.range (M+1),
        (↑(k + i) : ℂ) * ((↑((k:ℝ)/(↑(k+i):ℝ)) : ℂ) ^ s -
          (↑((k:ℝ)/(↑(k+i)+1)) : ℂ) ^ s) / s := by
  intro M; induction M with
  | zero =>
    have hk0 : k + 0 = k := Nat.add_zero k
    rw [show (0:ℕ) + 1 = 1 from rfl, hk0]
    simp only [Finset.range_one, Finset.sum_singleton, Nat.add_zero]
    have h1 : Set.Ioc ((k:ℝ)/((k:ℝ)+1)) (1:ℝ) = Set.Ioc ((k:ℝ)/((k:ℝ)+1)) ((k:ℝ)/(k:ℝ)) := by
      rw [div_self (by positivity : (k:ℝ) ≠ 0)]
    rw [h1]
    exact piece_setIntegral_gen k k hk hk s hs
  | succ m ih =>
    -- Simplify k + (m+1) = k + m + 1 at Nat level
    rw [show k + (m + 1) = k + m + 1 from by omega]
    -- Set up interval splitting
    have hk_m1 : (0:ℝ) < ↑(k+m)+1 := by positivity
    have hk_m2 : (0:ℝ) < ↑(k+m+1)+1 := by positivity
    have h_le : (k:ℝ)/(↑(k+m+1)+1) ≤ (k:ℝ)/(↑(k+m)+1) :=
      div_le_div_of_nonneg_left (by positivity) hk_m1 (by push_cast; linarith)
    have h_le1 : (k:ℝ)/(↑(k+m)+1) ≤ 1 := by
      rw [div_le_one hk_m1]; push_cast; linarith [Nat.cast_nonneg (α := ℝ) m]
    have h_union : Set.Ioc ((k:ℝ)/(↑(k+m+1)+1)) ((k:ℝ)/(↑(k+m)+1)) ∪
        Set.Ioc ((k:ℝ)/(↑(k+m)+1)) 1 = Set.Ioc ((k:ℝ)/(↑(k+m+1)+1)) 1 :=
      Set.Ioc_union_Ioc_eq_Ioc h_le h_le1
    have h_disj : Disjoint (Set.Ioc ((k:ℝ)/(↑(k+m+1)+1)) ((k:ℝ)/(↑(k+m)+1)))
        (Set.Ioc ((k:ℝ)/(↑(k+m)+1)) 1) := Set.Ioc_disjoint_Ioc_of_le le_rfl
    have h_int_full := floor_div_integrableOn s hs k hk
    have h_int_piece : IntegrableOn (fun (t : ℝ) => (↑t : ℂ) ^ (s - 1) * (↑(⌊(k:ℝ)/t⌋) : ℂ))
        (Set.Ioc ((k:ℝ)/(↑(k+m+1)+1)) ((k:ℝ)/(↑(k+m)+1))) volume :=
      h_int_full.mono_set (fun x ⟨hlo, hhi⟩ =>
        ⟨by linarith [div_pos (by positivity : (0:ℝ) < k) hk_m2], by linarith⟩)
    have h_int_rest : IntegrableOn (fun (t : ℝ) => (↑t : ℂ) ^ (s - 1) * (↑(⌊(k:ℝ)/t⌋) : ℂ))
        (Set.Ioc ((k:ℝ)/(↑(k+m)+1)) 1) volume :=
      h_int_full.mono_set (fun x ⟨hlo, hhi⟩ =>
        ⟨by linarith [div_pos (by positivity : (0:ℝ) < k) hk_m1], hhi⟩)
    -- Split the integral
    rw [← h_union, setIntegral_union h_disj measurableSet_Ioc h_int_piece h_int_rest]
    rw [ih]
    -- Goal: ∫ piece + ∑ range(m+1) = ∑ range((m+1)+1)
    conv_rhs => rw [Finset.sum_range_succ]
    -- Goal: ∫ piece + ∑ range(m+1) = ∑ range(m+1) + last
    rw [add_comm (∫ _ in _, _)]
    congr 1
    -- piece: ∫ Ioc(k/(↑(k+m+1)+1), k/(↑(k+m)+1)) = ↑(k+(m+1)) * ...
    -- piece_setIntegral_gen: ∫ Ioc(k/(↑(k+m+1)+1), k/↑(k+m+1)) = ↑(k+m+1) * ...
    -- These are the same since ↑(k+m)+1 = ↑(k+m+1)
    have h_n_cast : (↑(k+m) : ℝ) + 1 = ↑(k+m+1) := by push_cast; ring
    rw [h_n_cast]
    exact piece_setIntegral_gen k (k + m + 1) hk (by omega) s hs

/-- ∫₀¹ t^{s-1}·⌊k/t⌋ dt = k/s + (k^s/s)·(ζ(s) - ∑_{m<k}(m+1)^{-s}). -/
private lemma floor_div_mellin (s : ℂ) (hs : 1 < s.re) (k : ℕ) (hk : 1 ≤ k) :
    ∫ t in Set.Ioc (0:ℝ) 1,
      (↑t : ℂ) ^ (s - 1) * (↑(⌊(k : ℝ)/t⌋) : ℂ) =
    (↑k : ℂ) / s + ((k : ℂ) ^ s / s) *
      (riemannZeta s - (Finset.range k).sum (fun m => ((↑(m + 1 : ℕ) : ℂ) ^ (-s)))) := by
  -- Monotone convergence: partial integrals → full integral
  let f : ℝ → ℂ := fun t => (↑t : ℂ) ^ (s - 1) * (↑(⌊(k : ℝ)/t⌋) : ℂ)
  have h_tendsto_int : Tendsto
      (fun N : ℕ => ∫ t in Ioc ((k:ℝ)/((N:ℝ)+1)) 1, f t)
      atTop (nhds (∫ t in Ioc 0 1, f t)) := by
    rw [← iUnion_Ioc_gen k hk]
    exact tendsto_setIntegral_of_monotone (fun _ => measurableSet_Ioc) (mono_Ioc_gen k hk)
      (iUnion_Ioc_gen k hk ▸ floor_div_integrableOn s hs k hk)
  show ∫ t in Set.Ioc 0 1, f t =
    (↑k : ℂ) / s + ((k : ℂ) ^ s / s) *
      (riemannZeta s - (Finset.range k).sum (fun m => ((↑(m + 1 : ℕ) : ℂ) ^ (-s))))
  -- The partial integrals also tend to the target (via Abel sums)
  have h_tendsto_target : Tendsto
      (fun N : ℕ => ∫ t in Ioc ((k:ℝ)/((N:ℝ)+1)) 1, f t)
      atTop (nhds ((↑k : ℂ) / s + ((k : ℂ) ^ s / s) *
        (riemannZeta s - (Finset.range k).sum (fun m => ((↑(m + 1 : ℕ) : ℂ) ^ (-s)))))) := by
    -- Step 1: Partial integrals = Abel sum formula (induction)
    -- After inductive decomposition + Abel summation, each partial integral equals:
    -- [(↑k) + (↑k)^s · ∑_{n=k+1}^{N} n^{-s} - N·(k/(N+1))^s] / s
    have h_eq : ∀ᶠ N : ℕ in atTop, ∫ t in Ioc ((k:ℝ)/((N:ℝ)+1)) 1, f t =
        ((↑k : ℂ) + (↑k : ℂ) ^ s *
          (∑ n ∈ Finset.Icc (k+1) N, ((↑(n : ℕ) : ℂ) ^ (-s))) -
          (↑N : ℂ) * (↑((k:ℝ)/((N:ℝ)+1)) : ℂ) ^ s) / s := by
      filter_upwards [Filter.Ici_mem_atTop k] with N hN
      have hN' : k ≤ N := hN
      obtain ⟨M, rfl⟩ : ∃ M, N = k + M := ⟨N - k, by omega⟩
      -- Now N is replaced by k + M everywhere
      rw [integral_decomp_gen s hs k hk M]
      -- Apply partial Abel summation
      rw [partial_sum_gen s k M]
      -- Goal now: (∑ a_{k+i+1} + k·a_k - (k+M+1)·a_{k+M+1}) / s = target / s
      -- Both sides have /s, so congr 1 to compare numerators
      -- Then: k/k = 1, (k/n)^s = k^s·n^{-s}, reindex sums
      sorry  -- pure algebra: k/k=1, (k/n)^s = k^s·n^{-s}, Finset reindexing
    -- Step 2: ∑_{n=k+1}^{N} n^{-s} → ζ(s) - ∑_{n=1}^{k} n^{-s}
    have h_tail_zeta : Tendsto
        (fun N : ℕ => ∑ n ∈ Finset.Icc (k+1) N, ((↑(n:ℕ) : ℂ) ^ (-s)))
        atTop (nhds (riemannZeta s -
          (Finset.range k).sum (fun m => ((↑(m + 1 : ℕ) : ℂ) ^ (-s))))) := by
      have hs0 : s ≠ 0 := ne_of_apply_ne re (by linarith : s.re ≠ 0)
      -- Rewrite: eventually Icc = range - range
      suffices h : Tendsto (fun N : ℕ =>
          ∑ m ∈ Finset.range N, ((↑(m+1:ℕ) : ℂ) ^ (-s)) -
          ∑ m ∈ Finset.range k, ((↑(m+1:ℕ) : ℂ) ^ (-s)))
          atTop (nhds (riemannZeta s -
            (Finset.range k).sum (fun m => ((↑(m + 1 : ℕ) : ℂ) ^ (-s))))) by
        apply h.congr'
        apply Filter.eventually_atTop.mpr
        refine ⟨k + 1, fun N hN => ?_⟩
        symm; dsimp only
        rw [show Finset.Icc (k+1) N = Finset.Ico (k+1) (N+1) from by
          ext n; simp only [Finset.mem_Icc, Finset.mem_Ico]; omega]
        rw [Finset.sum_Ico_eq_add_neg _ (by omega : k+1 ≤ N+1)]
        rw [Finset.sum_range_succ', Finset.sum_range_succ']
        simp only [Nat.cast_zero, zero_cpow (neg_ne_zero.mpr hs0)]
        push_cast; ring
      -- Partial zeta convergence: ∑ range(N) g → ζ
      have h_pzeta : Tendsto (fun N : ℕ =>
          ∑ m ∈ Finset.range N, ((↑(m+1:ℕ) : ℂ) ^ (-s)))
          atTop (nhds (riemannZeta s)) := by
        have := partial_zeta_tendsto' s hs
        apply this.congr (fun N => ?_)
        congr 1; ext n
        rw [one_div, inv_eq_one_div, cpow_neg, one_div]
        congr 1; push_cast; ring
      exact h_pzeta.sub tendsto_const_nhds
    -- Step 3: N·(k/(N+1))^s → 0
    have h_tail := tail_vanishes_gen s hs k hk
    -- Step 4: Combine convergences
    have h_conv : Tendsto (fun N : ℕ =>
        ((↑k : ℂ) + (↑k : ℂ) ^ s *
          (∑ n ∈ Finset.Icc (k+1) N, ((↑(n : ℕ) : ℂ) ^ (-s))) -
          (↑N : ℂ) * (↑((k:ℝ)/((N:ℝ)+1)) : ℂ) ^ s) / s)
        atTop (nhds (((↑k : ℂ) + (↑k : ℂ) ^ s *
          (riemannZeta s - (Finset.range k).sum (fun m => ((↑(m + 1 : ℕ) : ℂ) ^ (-s)))) - 0) / s)) :=
      Tendsto.div_const
        (((h_tail_zeta.const_mul _).const_add _).sub h_tail) s
    -- Step 5: Simplify 0 and rewrite target
    simp only [sub_zero] at h_conv
    have h_algebra : ((↑k : ℂ) + (↑k : ℂ) ^ s *
        (riemannZeta s - (Finset.range k).sum (fun m => ((↑(m + 1 : ℕ) : ℂ) ^ (-s))))) / s =
      (↑k : ℂ) / s + ((k : ℂ) ^ s / s) *
        (riemannZeta s - (Finset.range k).sum (fun m => ((↑(m + 1 : ℕ) : ℂ) ^ (-s)))) := by
      ring
    rw [h_algebra] at h_conv
    exact h_conv.congr' (h_eq.mono (fun N hN => hN.symm))
  -- By uniqueness of limits
  exact tendsto_nhds_unique h_tendsto_int h_tendsto_target

/-- The general mellin_fractBasis for all k ≥ 1. -/
theorem mellin_fractBasis (k : ℕ) (hk : 1 ≤ k) (s : ℂ) (hs : 1 < s.re) :
    mellinRestricted (fractBasisC k) s =
    (k : ℂ) / (s * (s - 1)) +
    ((k : ℂ) ^ s / s) *
      ((Finset.range k).sum (fun m => ((↑(m + 1 : ℕ) : ℂ) ^ (-s))) - riemannZeta s) := by
  -- Split {k/t} = k/t - ⌊k/t⌋
  unfold mellinRestricted fractBasisC
  -- Step 1: Replace {k/t} with k/t - ⌊k/t⌋ pointwise
  have h_fract_eq : Set.EqOn
      (fun t : ℝ => (↑t : ℂ) ^ (s - 1) * (↑(Int.fract ((k : ℝ) / t)) : ℂ))
      (fun t : ℝ => (↑t : ℂ) ^ (s - 1) * ((↑k : ℂ) / (↑t : ℂ)) -
                     (↑t : ℂ) ^ (s - 1) * (↑(⌊(k : ℝ) / t⌋) : ℂ))
      (Set.Ioc (0:ℝ) 1) := by
    intro t ⟨ht_lo, _⟩
    show (↑t : ℂ) ^ (s - 1) * (↑(Int.fract ((k : ℝ) / t)) : ℂ) =
         (↑t : ℂ) ^ (s - 1) * ((↑k : ℂ) / (↑t : ℂ)) -
         (↑t : ℂ) ^ (s - 1) * (↑(⌊(k : ℝ) / t⌋) : ℂ)
    rw [← mul_sub]
    congr 1
    -- {x} = x - ⌊x⌋
    rw [Int.fract]
    push_cast; norm_cast
  rw [setIntegral_congr_fun measurableSet_Ioc h_fract_eq]
  -- Step 2: ∫(f - g) = ∫f - ∫g
  rw [integral_sub
    (by -- IntegrableOn t^{s-1}·(k/t) = k·t^{s-2}
      have h_cpow : IntegrableOn (fun t : ℝ => (↑t : ℂ) ^ (s - 2)) (Ioc 0 1) volume := by
        have h := @intervalIntegral.intervalIntegrable_cpow' 0 1 (s-2) (by simp [sub_re]; linarith)
        rwa [intervalIntegrable_iff_integrableOn_Ioc_of_le (by linarith : (0:ℝ) ≤ 1)] at h
      apply IntegrableOn.congr_fun (h_cpow.const_mul (↑k : ℂ)) _ measurableSet_Ioc
      intro t ht
      show (↑k : ℂ) * (↑t : ℂ) ^ (s - 2) = (↑t : ℂ) ^ (s - 1) * ((↑k : ℂ) / (↑t : ℂ))
      have ht' : (↑t : ℂ) ≠ 0 := ofReal_ne_zero.mpr (ne_of_gt ht.1)
      rw [show (s - 2 : ℂ) = (s - 1) + (-1) from by ring, cpow_add _ _ ht', Complex.cpow_neg_one]
      ring : IntegrableOn (fun t : ℝ => (↑t : ℂ) ^ (s-1) * ((↑k:ℂ)/(↑t:ℂ)))
      (Set.Ioc 0 1) volume)
    (by -- IntegrableOn t^{s-1}·⌊k/t⌋: dominate by k·t^{Re(s)-2}
      have hg : IntegrableOn (fun x : ℝ => (↑x : ℂ) ^ (s - 2)) (Ioc 0 1) volume := by
        have h := @intervalIntegral.intervalIntegrable_cpow' 0 1 (s-2) (by simp [sub_re]; linarith)
        rwa [intervalIntegrable_iff_integrableOn_Ioc_of_le (by linarith : (0:ℝ) ≤ 1)] at h
      exact Integrable.mono (hg.norm.const_mul (↑k : ℝ))
        (by apply AEStronglyMeasurable.mul
            · exact (ContinuousOn.cpow continuous_ofReal.continuousOn continuousOn_const
                (fun x hx => by left; simp [ofReal_re]; exact hx) |>.mono Ioc_subset_Ioi_self
                ).aestronglyMeasurable measurableSet_Ioc
            · exact ((Measurable.of_discrete (α := ℤ)).comp
                ((measurable_const.div measurable_id).floor)).aestronglyMeasurable.restrict)
        (by apply ae_restrict_of_ae_restrict_of_subset Ioc_subset_Ioi_self
            apply (ae_restrict_mem measurableSet_Ioi).mono
            intro t ht; rw [mem_Ioi] at ht
            rw [norm_mul, norm_ofReal_cpow t ht, norm_ofReal_cpow t ht]
            simp only [sub_re, one_re]
            have h_nn : (0 : ℤ) ≤ ⌊(k:ℝ)/t⌋ := Int.floor_nonneg.mpr (div_nonneg (by positivity) ht.le)
            rw [Complex.norm_intCast, abs_of_nonneg (by exact_mod_cast h_nn)]
            calc t ^ (s.re - 1) * (⌊(k:ℝ)/t⌋ : ℝ)
                ≤ t ^ (s.re - 1) * ((k:ℝ)/t) := mul_le_mul_of_nonneg_left (Int.floor_le _) (rpow_nonneg ht.le _)
              _ = (↑k : ℝ) * t ^ (s.re - 2) := by
                  rw [mul_comm, div_mul_eq_mul_div, mul_div_assoc,
                      div_eq_mul_inv, ← rpow_neg_one t,
                      ← rpow_add ht]; congr 1; ring
              _ ≤ ‖(↑k : ℝ) * t ^ (s.re - 2)‖ := le_norm_self _
              _ = _ := by simp)
      : IntegrableOn (fun t : ℝ => (↑t : ℂ) ^ (s-1) * (↑(⌊(k:ℝ)/t⌋):ℂ))
      (Set.Ioc 0 1) volume)]
  -- Step 3: Apply mellin_div_integral and floor_div_mellin
  rw [mellin_div_integral s hs k hk, floor_div_mellin s hs k hk]
  -- Step 4: Algebra: k/(s-1) - [k/s + (k^s/s)·(ζ - ∑)] = k/(s(s-1)) + (k^s/s)·(∑ - ζ)
  have hs_ne : s ≠ 0 := by
    intro h; rw [h, zero_re] at hs; linarith
  have hs1_ne : s - 1 ≠ 0 := by
    intro h; have := congr_arg re h; simp [sub_re, one_re] at this; linarith
  field_simp
  ring

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
