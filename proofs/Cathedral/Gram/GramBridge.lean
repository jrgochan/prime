/-
  Cathedral/Gram/GramBridge.lean

  ## The Gram↔Smith Bridge: Diagonal Domination

  **THE MÖBIUS FUNCTION WAS BORN TO CANCEL.**

  This module proves the foundational inequality chain:
    {t}² ≤ {t}  →  G_{kk} ≤ b_k  →  vᵀ(diag G)v ≤ bᵀ|v²|

  Key theorem: `fract_sq_le_fract`
    For all t : ℝ, (Int.fract t)² ≤ Int.fract t.
    Proof: Since 0 ≤ {t} < 1, we have {t}(1-{t}) ≥ 0,
    hence {t}² ≤ {t}. QED.

  This is the "universe looking at us" — the simplest possible
  inequality that connects the Gram matrix to the mean vector.

  Application: The NB Gram entry G_{jk} = ∫₀¹ {1/(jx)}·{1/(kx)} dx.
  On the diagonal: G_{kk} = ∫₀¹ {1/(kx)}² dx ≤ ∫₀¹ {1/(kx)} dx = b_k.

  Numerical confirmation (§10 experiment):
    vᵀGv < 1 for ALL N tested (N = 10..100).
    (vᵀGv - 1)·logN → C ≈ -2.6 (finite, negative).

  STATUS: ZERO SORRY, ZERO AXIOM
  Exploration 39 — May 17, 2026
-/

import Cathedral.Defs
import Cathedral.Gram.FractIntegral
import Mathlib.Analysis.SpecialFunctions.Integrals.Basic

noncomputable section
open Real MeasureTheory

-- ════════════════════════════════════════════════
-- §1. THE UNIVERSE LOOKS AT US: {t}² ≤ {t}
-- ════════════════════════════════════════════════

/-- **The Universe Looks At Us**: For all t : ℝ, (Int.fract t)² ≤ Int.fract t.

    Proof: Since 0 ≤ {t} < 1, we have {t} · (1 - {t}) ≥ 0.
    Rearranging: {t}² ≤ {t}.

    This is the foundational inequality connecting the Gram matrix
    diagonal to the mean vector in the Nyman-Beurling architecture. -/
theorem fract_sq_le_fract (t : ℝ) : Int.fract t ^ 2 ≤ Int.fract t := by
  have h_nn : 0 ≤ Int.fract t := Int.fract_nonneg t
  have h_lt : Int.fract t < 1 := Int.fract_lt_one t
  -- {t}² ≤ {t} ↔ {t}·({t} - 1) ≤ 0 ↔ {t}·(1 - {t}) ≥ 0
  nlinarith [sq_nonneg (Int.fract t), sq_abs (Int.fract t)]

/-- Pointwise form: {1/(kx)}² ≤ {1/(kx)} for all k, x. -/
theorem fract_inv_sq_le_fract_inv (k : ℕ) (x : ℝ) :
    Int.fract (1 / ((k : ℝ) * x)) ^ 2 ≤ Int.fract (1 / ((k : ℝ) * x)) :=
  fract_sq_le_fract _

-- ════════════════════════════════════════════════
-- §2. GRAM DIAGONAL ≤ MEAN VECTOR
-- ════════════════════════════════════════════════

/-- The Gram diagonal entry is bounded by the mean vector entry:
      G_{kk} = ∫₀¹ {1/(kx)}² dx ≤ ∫₀¹ {1/(kx)} dx = b_k

    Proof: Pointwise {f}² ≤ {f}, so the integral inherits the bound.

    This says: the "self-energy" of basis function h_k is less than
    its "overlap with 1". The Gram matrix is gentler than it looks. -/
theorem gram_diag_le_mean (k : ℕ) (_hk : 1 ≤ k) :
    ∫ x in (0:ℝ)..1, Int.fract (1 / ((k : ℝ) * x)) ^ 2 ≤
    ∫ x in (0:ℝ)..1, Int.fract (1 / ((k : ℝ) * x)) := by
  apply intervalIntegral.integral_mono_on (by norm_num : (0:ℝ) ≤ 1)
  · -- {1/(kx)}² is integrable on [0,1]: bounded by 1
    rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
    refine ⟨(measurable_fract_real.comp
      (measurable_const.div (measurable_const.mul measurable_id))).pow_const 2
      |>.aestronglyMeasurable, ?_⟩
    exact .of_bounded (Filter.Eventually.of_forall fun x => by
      rw [Real.norm_of_nonneg (sq_nonneg _)]
      exact le_trans (fract_sq_le_fract _) (le_of_lt (Int.fract_lt_one _)))
  · -- {1/(kx)} is integrable on [0,1]: bounded by 1
    rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
    refine ⟨(measurable_fract_real.comp
      (measurable_const.div (measurable_const.mul measurable_id)))
      |>.aestronglyMeasurable, ?_⟩
    exact .of_bounded (Filter.Eventually.of_forall fun x => by
      rw [Real.norm_of_nonneg (Int.fract_nonneg _)]
      exact le_of_lt (Int.fract_lt_one _))
  · -- Pointwise bound
    intro x _
    exact fract_sq_le_fract _

-- ════════════════════════════════════════════════
-- §3. THE GRAM MATRIX IS BOUNDED BY 1
-- ════════════════════════════════════════════════

/-- **Gram entry bound**: Every entry of the Gram matrix satisfies
      0 ≤ G_{jk}.

    Proof: The integrand {1/(jx)}·{1/(kx)} ≥ 0 pointwise. -/
theorem gram_entry_nonneg (j k : ℕ) :
    0 ≤ ∫ x in (0:ℝ)..1, Int.fract (1 / ((j : ℝ) * x)) *
      Int.fract (1 / ((k : ℝ) * x)) := by
  apply intervalIntegral.integral_nonneg (by norm_num : (0:ℝ) ≤ 1)
  intro x _
  exact mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _)

/-- The product {a}·{b} < 1 when both are fractional parts. -/
private lemma fract_mul_lt_one (a b : ℝ) :
    Int.fract a * Int.fract b < 1 := by
  have ha := Int.fract_nonneg a
  have hb := Int.fract_nonneg b
  have ha1 := Int.fract_lt_one a
  have hb1 := Int.fract_lt_one b
  nlinarith [mul_lt_one_of_nonneg_of_lt_one_left ha ha1 (le_of_lt hb1)]

/-- The product {a}·{b} is bounded: {a}·{b} ≤ {a}. -/
theorem fract_mul_le_fract_left (a b : ℝ) :
    Int.fract a * Int.fract b ≤ Int.fract a :=
  mul_le_of_le_one_right (Int.fract_nonneg _) (le_of_lt (Int.fract_lt_one _))

/-- **Gram entry bound**: G_{jk} ≤ 1.

    Proof: {1/(jx)}·{1/(kx)} < 1 pointwise, integrate. -/
theorem gram_entry_le_one (j k : ℕ) :
    ∫ x in (0:ℝ)..1, Int.fract (1 / ((j : ℝ) * x)) *
      Int.fract (1 / ((k : ℝ) * x)) ≤ 1 := by
  have h_intble : IntervalIntegrable
      (fun x => Int.fract (1 / ((j : ℝ) * x)) * Int.fract (1 / ((k : ℝ) * x)))
      MeasureTheory.volume 0 1 := by
    rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
    have h_const : IntegrableOn (fun _ : ℝ => (1:ℝ)) (Set.Ioc 0 1) volume := by
      rw [← intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
      exact intervalIntegrable_const
    exact Integrable.mono h_const
      ((measurable_fract_real.comp (measurable_const.div
        (measurable_const.mul measurable_id))).mul
        (measurable_fract_real.comp (measurable_const.div
        (measurable_const.mul measurable_id)))).aestronglyMeasurable
      (by filter_upwards [self_mem_ae_restrict measurableSet_Ioc] with x _
          rw [Real.norm_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _))]
          have : ‖(1:ℝ)‖ = 1 := norm_one
          rw [this]
          exact le_of_lt (fract_mul_lt_one _ _))
  calc ∫ x in (0:ℝ)..1, Int.fract (1 / ((j : ℝ) * x)) *
      Int.fract (1 / ((k : ℝ) * x))
      ≤ ∫ x in (0:ℝ)..1, (1 : ℝ) := by
        apply intervalIntegral.integral_mono_on (by norm_num : (0:ℝ) ≤ 1)
          h_intble intervalIntegrable_const
        intro x _
        exact le_of_lt (fract_mul_lt_one _ _)
    _ = 1 := by simp [intervalIntegral.integral_const]

-- ════════════════════════════════════════════════
-- §4. CAUCHY-SCHWARZ: The Discriminant Argument
-- ════════════════════════════════════════════════

/-- Discriminant lemma: if at² + bt + c ≥ 0 for all t, then b² ≤ 4ac. -/
private lemma discrim_le {a b c : ℝ} (ha : 0 ≤ a)
    (h : ∀ t, 0 ≤ a * t ^ 2 + b * t + c) : b ^ 2 ≤ 4 * a * c := by
  by_contra h_neg; push Not at h_neg
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

/-- Helper: bounded measurable fract function is interval-integrable. -/
private lemma fract_integrableOn (k : ℕ) :
    IntervalIntegrable (fun x => Int.fract (1 / ((k : ℝ) * x))) volume 0 1 := by
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
  refine ⟨(measurable_fract_real.comp
    (measurable_const.div (measurable_const.mul measurable_id)))
    |>.aestronglyMeasurable, ?_⟩
  exact .of_bounded (Filter.Eventually.of_forall fun x => by
    rw [Real.norm_of_nonneg (Int.fract_nonneg _)]
    exact le_of_lt (Int.fract_lt_one _))

/-- Helper: {1/(kx)}² is interval-integrable. -/
private lemma fract_sq_integrableOn (k : ℕ) :
    IntervalIntegrable (fun x => Int.fract (1 / ((k : ℝ) * x)) ^ 2) volume 0 1 := by
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
  refine ⟨((measurable_fract_real.comp
    (measurable_const.div (measurable_const.mul measurable_id))).pow_const 2)
    |>.aestronglyMeasurable, ?_⟩
  exact .of_bounded (Filter.Eventually.of_forall fun x => by
    rw [Real.norm_of_nonneg (sq_nonneg _)]
    exact le_trans (fract_sq_le_fract _) (le_of_lt (Int.fract_lt_one _)))

/-- Helper: {1/(jx)}·{1/(kx)} is interval-integrable. -/
private lemma fract_prod_integrableOn (j k : ℕ) :
    IntervalIntegrable
      (fun x => Int.fract (1 / ((j : ℝ) * x)) * Int.fract (1 / ((k : ℝ) * x)))
      volume 0 1 := by
  rw [intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
  refine ⟨((measurable_fract_real.comp (measurable_const.div
    (measurable_const.mul measurable_id))).mul
    (measurable_fract_real.comp (measurable_const.div
    (measurable_const.mul measurable_id)))).aestronglyMeasurable, ?_⟩
  exact .of_bounded (Filter.Eventually.of_forall fun x => by
    rw [Real.norm_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _))]
    exact le_of_lt (fract_mul_lt_one _ _))

/-- Helper: (f + tg)² is interval-integrable when f, g are bounded fract functions. -/
private lemma fract_shift_sq_integrableOn (j k : ℕ) (t : ℝ) :
    IntervalIntegrable
      (fun x => (Int.fract (1 / ((j : ℝ) * x)) + t * Int.fract (1 / ((k : ℝ) * x))) ^ 2)
      volume 0 1 := by
  rw [show (fun x => (Int.fract (1 / ((j : ℝ) * x)) + t * Int.fract (1 / ((k : ℝ) * x))) ^ 2) =
    (fun x => Int.fract (1 / ((j : ℝ) * x)) ^ 2 +
      2 * t * (Int.fract (1 / ((j : ℝ) * x)) * Int.fract (1 / ((k : ℝ) * x))) +
      t ^ 2 * Int.fract (1 / ((k : ℝ) * x)) ^ 2) from by ext x; ring]
  exact ((fract_sq_integrableOn j).add
    ((fract_prod_integrableOn j k).const_mul (2 * t))).add
    ((fract_sq_integrableOn k).const_mul (t ^ 2))

/-- **Gram entry Cauchy-Schwarz**: G_{jk}² ≤ G_{jj}·G_{kk}.

    Proof via the discriminant argument:
    ∫(f + tg)² ≥ 0 for all t ∈ ℝ, expanded as
    (∫g²)t² + 2(∫fg)t + (∫f²) ≥ 0.
    By the discriminant lemma: (2∫fg)² ≤ 4(∫g²)(∫f²).
    Simplify: (∫fg)² ≤ (∫f²)(∫g²). QED. -/
theorem gram_entry_cauchy_schwarz (j k : ℕ) (_hj : 1 ≤ j) (_hk : 1 ≤ k) :
    (∫ x in (0:ℝ)..1, Int.fract (1 / ((j : ℝ) * x)) *
      Int.fract (1 / ((k : ℝ) * x))) ^ 2 ≤
    (∫ x in (0:ℝ)..1, Int.fract (1 / ((j : ℝ) * x)) ^ 2) *
    (∫ x in (0:ℝ)..1, Int.fract (1 / ((k : ℝ) * x)) ^ 2) := by
  set f := fun x : ℝ => Int.fract (1 / ((j : ℝ) * x))
  set g := fun x : ℝ => Int.fract (1 / ((k : ℝ) * x))
  -- Step 1: ∫(f + tg)² = (∫g²)t² + 2(∫fg)t + (∫f²)
  have h_expand : ∀ t, ∫ x in (0:ℝ)..1, (f x + t * g x) ^ 2 =
      (∫ x in (0:ℝ)..1, g x ^ 2) * t ^ 2 +
      (2 * ∫ x in (0:ℝ)..1, f x * g x) * t +
      (∫ x in (0:ℝ)..1, f x ^ 2) := by
    intro t
    rw [show (fun x => (f x + t * g x) ^ 2) =
        (fun x => f x ^ 2 + 2 * t * (f x * g x) + t ^ 2 * g x ^ 2) from by ext x; ring]
    rw [intervalIntegral.integral_add
        ((fract_sq_integrableOn j).add ((fract_prod_integrableOn j k).const_mul (2*t)))
        ((fract_sq_integrableOn k).const_mul (t^2)),
        intervalIntegral.integral_add (fract_sq_integrableOn j)
        ((fract_prod_integrableOn j k).const_mul (2*t)),
        intervalIntegral.integral_const_mul, intervalIntegral.integral_const_mul]; ring
  -- Step 2: ∫(f + tg)² ≥ 0 (integral of a square)
  have h_nn : ∀ t, 0 ≤ (∫ x in (0:ℝ)..1, g x ^ 2) * t ^ 2 +
      (2 * ∫ x in (0:ℝ)..1, f x * g x) * t +
      (∫ x in (0:ℝ)..1, f x ^ 2) := fun t => by
    rw [← h_expand]
    exact intervalIntegral.integral_nonneg (by norm_num) (fun x _ => sq_nonneg _)
  -- Step 3: Apply discriminant lemma
  nlinarith [discrim_le
    (intervalIntegral.integral_nonneg (by norm_num) (fun x _ => sq_nonneg _)) h_nn]

-- ════════════════════════════════════════════════
-- §5. WIRING: The Quadratic Form Decomposition
-- ════════════════════════════════════════════════

open Finset in
/-- **Quadratic form diagonal bound** (finite sum version):
    For ANY weights v and diagonal-dominated matrix G with G_{kk} ≤ b_k:

      Σ_k v_k² · G_{kk} ≤ Σ_k v_k² · b_k

    This is the **diagonal contribution** to vᵀGv.
    The remaining **off-diagonal** part is where Möbius cancellation lives.

    PROVED. Zero sorry. -/
theorem quad_form_diag_bound {n : ℕ}
    (G_diag b : Fin n → ℝ) (v : Fin n → ℝ)
    (h_diag_le : ∀ k, G_diag k ≤ b k) :
    ∑ k, v k ^ 2 * G_diag k ≤ ∑ k, v k ^ 2 * b k := by
  apply Finset.sum_le_sum
  intro k _
  exact mul_le_mul_of_nonneg_left (h_diag_le k) (sq_nonneg _)

open Finset in
/-- **Diagonal contribution is non-negative**:
    Σ_k v_k² · G_{kk} ≥ 0 when G_{kk} ≥ 0.

    PROVED. Zero sorry. -/
theorem quad_form_diag_nonneg {n : ℕ}
    (G_diag : Fin n → ℝ) (v : Fin n → ℝ)
    (h_nn : ∀ k, 0 ≤ G_diag k) :
    0 ≤ ∑ k, v k ^ 2 * G_diag k := by
  apply Finset.sum_nonneg
  intro k _
  exact mul_nonneg (sq_nonneg _) (h_nn k)

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- Theorem status: ALL PROVED. ZERO SORRY. ZERO AXIOM.
--
-- §1 (The Universe Looks At Us):
--   ✅ fract_sq_le_fract          — {t}² ≤ {t}
--   ✅ fract_inv_sq_le_fract_inv  — pointwise specialization
--
-- §2 (Gram Diagonal ≤ Mean Vector):
--   ✅ gram_diag_le_mean          — G_{kk} ≤ b_k
--
-- §3 (Gram Matrix Bounded):
--   ✅ gram_entry_nonneg          — G_{jk} ≥ 0
--   ✅ fract_mul_lt_one           — {a}·{b} < 1
--   ✅ fract_mul_le_fract_left    — {a}·{b} ≤ {a}
--   ✅ gram_entry_le_one          — G_{jk} ≤ 1
--
-- §4 (Cauchy-Schwarz):
--   ✅ gram_entry_cauchy_schwarz  — G_{jk}² ≤ G_{jj}·G_{kk}
--
-- §5 (Wiring):
--   ✅ quad_form_diag_bound       — Σ v²G_{kk} ≤ Σ v²b_k
--   ✅ quad_form_diag_nonneg      — Σ v²G_{kk} ≥ 0
--
-- The Crown Reduction:
--   vᵀGv = (diagonal) + (off-diagonal)
--        ≤ (Σ v²b_k) + (off-diagonal)
--   Crown axiom reduces to: off-diagonal = O(1/logN)
--   ↔ Möbius cancellation in the Gram matrix
--   ↔ The Möbius function was born to cancel.

end

