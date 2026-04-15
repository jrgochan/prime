/-
  Cathedral/FractIntegral.lean

  ## Per-entry Fractional Part Integral Analysis

  This file contains the analysis of ∫₀¹ {k/x}dx, the inner product
  of the Nyman-Beurling basis function with the constant function 1.

  ### Architecture:
  fract_integral_eq_tsum (THEOREM — proved via x-domain partition + assembly)
    ↓ [floor_div_eq_on_Ioc — THEOREM: ⌊k/x⌋ = n on Ioc(k/(n+1), k/n)]
    ↓ [fract_div_eq_on_Ioc — THEOREM: {k/x} = k/x - n]
    ↓ [integral_div_sub_const_on_piece — THEOREM: per-interval FTC]
    ↓ [fract_integral_piece — THEOREM: a.e. congr bridge]
    ↓ [fract_integral_telescope — THEOREM: finite telescoping]
    ↓ [fract_integral_tail_bound — THEOREM: tail → 0]
    ↓ [fract_div_intervalIntegrable — THEOREM: floor measurable → fract measurable → bounded]
  summable_log_correction (THEOREM — was axiom, proved via comparison + sign flip)
      ↓ [hasSum_telescoping_inv — THEOREM (telescoping series)]
      ↓ [fract_integral_as_one_plus — THEOREM]
      ↓ [fract_integral_identity — THEOREM (sign flip)]
  log_harmonic_tail_bound (THEOREM — was axiom, proved via per_term_log_bound)
      ↓ [basis_entry_lower — THEOREM: ∫₀¹{k/x}dx ≥ 1/2 - 1/(2k)]

  ### Proof sketch:
  Change of variables u = k/x gives ∫₀¹{k/x}dx = k·Σ_{n≥k}(log(1+1/n) - 1/(n+1)).
  On each interval [n,n+1), {u} = u-n, so ∫_n^{n+1} (u-n)/u² du = log(1+1/n) - 1/(n+1).
  Rewriting 1/(n+1) = 1/n - 1/(n(n+1)) and telescoping Σ 1/(n(n+1)) = 1/k:
  ∫₀¹{k/x}dx = 1 - k·Σ_{n≥k}(1/n - log(1+1/n)).
  Each correction term 1/n - log(1+1/n) ∈ (0, 1/(2n²)), so
  k·Σ ≤ (k+1)/(2k) = 1/2 + 1/(2k), giving ∫ ≥ 1/2 - 1/(2k).
-/

import Cathedral.Defs
import Mathlib.Analysis.SpecialFunctions.Log.Deriv

noncomputable section
open Real MeasureTheory

-- ════════════════════════════════════════════════
-- LAYER 0: X-DOMAIN PARTITION PROOF
-- (was: fract_integral_as_sum axiom — now eliminated)
-- ════════════════════════════════════════════════

/-- **THEOREM**: ∫_n^{n+1} (x-n)/x² dx = log(1+1/n) - 1/(n+1).
    Proof: (x-n)/x² = 1/x - n/x². By FTC with antiderivative log(x) + n/x:
    [log(x) + n/x]_n^{n+1} = log((n+1)/n) + n/(n+1) - 1 = log(1+1/n) - 1/(n+1). -/
theorem interval_sub_div_sq (n : ℕ) (hn : 1 ≤ n) :
    ∫ x in ((n : ℕ) : ℝ)..((n : ℕ) : ℝ) + 1, (x - ((n : ℕ) : ℝ)) / x ^ 2 =
    Real.log (1 + 1 / ((n : ℕ) : ℝ)) - 1 / (((n : ℕ) : ℝ) + 1) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  -- Antiderivative F(x) = log(x) + n/x, F'(x) = 1/x - n/x² = (x-n)/x²
  have hF : ∀ x ∈ Set.uIcc ((n : ℕ) : ℝ) (((n : ℕ) : ℝ) + 1),
      HasDerivAt (fun x => Real.log x + (↑n : ℝ) * x⁻¹)
        ((x - (↑n : ℝ)) / x ^ 2) x := by
    intro x hx
    have hx_pos : (0 : ℝ) < x := by
      simp at hx; linarith
    have hx_ne : x ≠ 0 := ne_of_gt hx_pos
    have hlog := Real.hasDerivAt_log hx_ne
    have hinv := hasDerivAt_inv hx_ne
    -- log'(x) = x⁻¹, (x⁻¹)' = -(x²)⁻¹
    -- (log x + n·x⁻¹)' = x⁻¹ + n·(-(x²)⁻¹) = x⁻¹ - n/x² = (x-n)/x²
    convert hlog.add (hinv.const_mul (↑n : ℝ)) using 1
    field_simp; ring
  have hint : IntervalIntegrable
      (fun x => (x - (↑n : ℝ)) / x ^ 2) MeasureTheory.volume
      ((n : ℕ) : ℝ) (((n : ℕ) : ℝ) + 1) := by
    apply ContinuousOn.intervalIntegrable
    apply ContinuousOn.div
    · exact continuousOn_id.sub continuousOn_const
    · exact continuousOn_pow 2
    · intro x hx; simp at hx
      exact pow_ne_zero 2 (ne_of_gt (by linarith))
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hF hint]
  -- Goal: log(↑n+1) + ↑n*(↑n+1)⁻¹ - (log ↑n + ↑n*(↑n)⁻¹) = log(1+1/↑n) - 1/(↑n+1)
  -- Auxiliary facts for algebra
  have h1 : (↑n : ℝ) * (↑n : ℝ)⁻¹ = 1 := mul_inv_cancel₀ (ne_of_gt hn_pos)
  have h2 : Real.log (1 + 1 / (↑n : ℝ)) = Real.log ((↑n : ℝ) + 1) - Real.log (↑n : ℝ) := by
    conv_lhs => rw [show (1 : ℝ) + 1 / (↑n : ℝ) = ((↑n : ℝ) + 1) / (↑n : ℝ) from by field_simp]
    exact Real.log_div (by linarith : (↑n : ℝ) + 1 ≠ 0) (ne_of_gt hn_pos)
  have h3 : (↑n : ℝ) * ((↑n : ℝ) + 1)⁻¹ + ((↑n : ℝ) + 1)⁻¹ = 1 := by
    rw [show (↑n : ℝ) * ((↑n : ℝ) + 1)⁻¹ + ((↑n : ℝ) + 1)⁻¹
      = ((↑n : ℝ) + 1) * ((↑n : ℝ) + 1)⁻¹ from by ring]
    exact mul_inv_cancel₀ (by linarith : (↑n : ℝ) + 1 ≠ 0)
  have h4 : 1 / ((↑n : ℝ) + 1) = ((↑n : ℝ) + 1)⁻¹ := one_div _
  linarith

/-- On Ioc(k/(n+1), k/n), ⌊k/x⌋ = n. -/
private lemma floor_div_eq_on_Ioc (k : ℕ) (n : ℕ) (hk : 1 ≤ k) (hn : 1 ≤ n)
    (x : ℝ) (hx_lo : (k : ℝ) / ((n : ℝ) + 1) < x) (hx_hi : x ≤ (k : ℝ) / (n : ℝ)) :
    ⌊(k : ℝ) / x⌋ = (n : ℤ) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hn1_pos : (0 : ℝ) < (n : ℝ) + 1 := by linarith
  have hx_pos : (0 : ℝ) < x := by linarith [div_pos hk_pos hn1_pos]
  rw [Int.floor_eq_iff]
  constructor
  · rw [Int.cast_natCast, le_div_iff₀ hx_pos]
    nlinarith [mul_div_cancel₀ (k : ℝ) (ne_of_gt hn_pos)]
  · rw [Int.cast_natCast, div_lt_iff₀ hx_pos]
    nlinarith [mul_div_cancel₀ (k : ℝ) (ne_of_gt hn1_pos)]

/-- On Ioc(k/(n+1), k/n), {k/x} = k/x - n. -/
lemma fract_div_eq_on_Ioc (k : ℕ) (n : ℕ) (hk : 1 ≤ k) (hn : 1 ≤ n)
    (x : ℝ) (hx_lo : (k : ℝ) / ((n : ℝ) + 1) < x) (hx_hi : x ≤ (k : ℝ) / (n : ℝ)) :
    Int.fract ((k : ℝ) / x) = (k : ℝ) / x - (n : ℝ) := by
  unfold Int.fract
  rw [floor_div_eq_on_Ioc k n hk hn x hx_lo hx_hi]; simp [Int.cast_natCast]

/-- Pure calculus: ∫_{k/(n+1)}^{k/n} (k/x - n) dx = k·(log(1+1/n) - 1/(n+1)). -/
private lemma integral_div_sub_const_on_piece (k : ℕ) (n : ℕ) (hk : 1 ≤ k) (hn : 1 ≤ n) :
    ∫ x in ((k : ℝ) / ((n : ℝ) + 1))..((k : ℝ) / (n : ℝ)),
      ((k : ℝ) / x - (n : ℝ)) =
    (k : ℝ) * (Real.log (1 + 1 / (n : ℝ)) - 1 / ((n : ℝ) + 1)) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hn1_pos : (0 : ℝ) < (n : ℝ) + 1 := by linarith
  have hkn1_pos : (0 : ℝ) < (k : ℝ) / ((n : ℝ) + 1) := div_pos hk_pos hn1_pos
  have hkn_pos : (0 : ℝ) < (k : ℝ) / (n : ℝ) := div_pos hk_pos hn_pos
  have hle : (k : ℝ) / ((n : ℝ) + 1) ≤ (k : ℝ) / (n : ℝ) :=
    div_le_div_of_nonneg_left (le_of_lt hk_pos) hn_pos (by linarith)
  have hF : ∀ x ∈ Set.uIcc ((k : ℝ) / ((n : ℝ) + 1)) ((k : ℝ) / (n : ℝ)),
      HasDerivAt (fun x => (k : ℝ) * Real.log x - (n : ℝ) * x)
        ((k : ℝ) / x - (n : ℝ)) x := by
    intro x hx; rw [Set.uIcc_of_le hle] at hx
    have hx_pos : (0 : ℝ) < x := lt_of_lt_of_le hkn1_pos hx.1
    convert (Real.hasDerivAt_log (ne_of_gt hx_pos)).const_mul (k : ℝ) |>.sub
      ((hasDerivAt_id x).const_mul (n : ℝ)) using 1
    simp [mul_comm (k : ℝ) x⁻¹, div_eq_mul_inv]
  have hint : IntervalIntegrable (fun x => (k : ℝ) / x - (n : ℝ)) volume
      ((k : ℝ) / ((n : ℝ) + 1)) ((k : ℝ) / (n : ℝ)) := by
    apply ContinuousOn.intervalIntegrable
    exact (continuousOn_const.div continuousOn_id (fun x hx => by
      rw [Set.uIcc_of_le hle] at hx; exact ne_of_gt (lt_of_lt_of_le hkn1_pos hx.1))).sub
      continuousOn_const
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hF hint]
  have h1 : Real.log ((k : ℝ) / (n : ℝ)) - Real.log ((k : ℝ) / ((n : ℝ) + 1)) =
      Real.log (((n : ℝ) + 1) / (n : ℝ)) := by
    rw [← Real.log_div (ne_of_gt hkn_pos) (ne_of_gt hkn1_pos)]; congr 1; field_simp
  rw [show (k : ℝ) * Real.log ((k : ℝ) / (n : ℝ)) - (n : ℝ) * ((k : ℝ) / (n : ℝ)) -
      ((k : ℝ) * Real.log ((k : ℝ) / ((n : ℝ) + 1)) - (n : ℝ) * ((k : ℝ) / ((n : ℝ) + 1))) =
      (k : ℝ) * (Real.log ((k : ℝ) / (n : ℝ)) - Real.log ((k : ℝ) / ((n : ℝ) + 1))) -
      (n : ℝ) * ((k : ℝ) / (n : ℝ) - (k : ℝ) / ((n : ℝ) + 1)) from by ring, h1]
  have h2 : Real.log (((n : ℝ) + 1) / (n : ℝ)) = Real.log (1 + 1 / (n : ℝ)) := by
    congr 1; field_simp
  rw [h2]; have : (n : ℝ) * ((k : ℝ) / (n : ℝ) - (k : ℝ) / ((n : ℝ) + 1)) =
      (k : ℝ) / ((n : ℝ) + 1) := by field_simp; ring
  rw [this]; ring

/-- The fract integral on a piece equals the closed form via a.e. congr. -/
private lemma fract_integral_piece (k : ℕ) (n : ℕ) (hk : 1 ≤ k) (hn : 1 ≤ n) :
    ∫ x in ((k : ℝ) / ((n : ℝ) + 1))..((k : ℝ) / (n : ℝ)),
      Int.fract ((k : ℝ) / x) =
    (k : ℝ) * (Real.log (1 + 1 / (n : ℝ)) - 1 / ((n : ℝ) + 1)) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hle : (k : ℝ) / ((n : ℝ) + 1) ≤ (k : ℝ) / (n : ℝ) :=
    div_le_div_of_nonneg_left (le_of_lt hk_pos) hn_pos (by linarith)
  rw [← integral_div_sub_const_on_piece k n hk hn,
    intervalIntegral.integral_of_le hle, intervalIntegral.integral_of_le hle]
  exact integral_congr_ae ((ae_restrict_mem measurableSet_Ioc).mono
    (fun x hx => fract_div_eq_on_Ioc k n hk hn x hx.1 hx.2))

/-- Floor is measurable: preimage of each {n} is Ico(n, n+1). -/
private lemma measurable_floor_real : Measurable (Int.floor : ℝ → ℤ) := by
  intro s hs
  have key : Int.floor ⁻¹' s = ⋃ n ∈ s, Set.Ico (↑n : ℝ) ((↑n : ℝ) + 1) := by
    ext x; simp only [Set.mem_preimage, Set.mem_iUnion, Set.mem_Ico, exists_prop]
    constructor
    · intro h; exact ⟨⌊x⌋, h, Int.floor_le x, Int.lt_floor_add_one x⟩
    · rintro ⟨n, hn, h1, h2⟩
      rwa [show ⌊x⌋ = n from Int.floor_eq_iff.mpr ⟨h1, h2⟩]
  rw [key]
  exact MeasurableSet.biUnion s.to_countable (fun n _ => measurableSet_Ico)

/-- Fract is measurable: fract x = x - ↑⌊x⌋. -/
lemma measurable_fract_real : Measurable (Int.fract : ℝ → ℝ) :=
  measurable_id.sub ((by fun_prop : Measurable (fun n : ℤ => (n : ℝ))).comp measurable_floor_real)

/-- Fract(k/x) is measurable. -/
private lemma measurable_fract_div (k : ℕ) :
    Measurable (fun x : ℝ => Int.fract ((k : ℝ) / x)) :=
  measurable_fract_real.comp (measurable_const.div measurable_id)

/-- **THEOREM** (was axiom): {k/x} is integrable on any finite interval.
    Proof: bounded by 1, measurable (floor→fract→composition), finite measure. -/
theorem fract_div_intervalIntegrable (k : ℕ) (a b : ℝ) :
    IntervalIntegrable (fun x => Int.fract ((k : ℝ) / x)) volume a b :=
  (IntegrableOn.of_bound (by simp)
    (measurable_fract_div k).aestronglyMeasurable.restrict 1
    (ae_of_all _ (fun x => by
      rw [Real.norm_eq_abs, abs_of_nonneg (Int.fract_nonneg _)]
      exact le_of_lt (Int.fract_lt_one _)))).intervalIntegrable

/-- Finite telescoping of fract integral pieces. -/
private lemma fract_integral_telescope (k : ℕ) (hk : 1 ≤ k) (N : ℕ) :
    ∑ j ∈ Finset.range (N + 1),
      ∫ x in ((k : ℝ) / ((k : ℝ) + (j : ℝ) + 1))..((k : ℝ) / ((k : ℝ) + (j : ℝ))),
        Int.fract ((k : ℝ) / x) =
    ∫ x in ((k : ℝ) / ((k : ℝ) + (N : ℝ) + 1))..(1 : ℝ),
      Int.fract ((k : ℝ) / x) := by
  induction N with
  | zero =>
    rw [Finset.sum_range_one]; simp only [Nat.cast_zero, add_zero]
    congr 1; exact div_self (ne_of_gt (show (0 : ℝ) < (k : ℝ) by positivity))
  | succ N ih =>
    rw [Finset.sum_range_succ, ih]
    set a := (k : ℝ) / ((k : ℝ) + (N : ℝ) + 2) with ha_def
    set b := (k : ℝ) / ((k : ℝ) + (N : ℝ) + 1) with hb_def
    have key := intervalIntegral.integral_add_adjacent_intervals
      (fract_div_intervalIntegrable k a b) (fract_div_intervalIntegrable k b 1)
    rw [add_comm]; convert key using 2 <;> simp [ha_def, hb_def] <;> ring_nf

/-- Tail bound: ‖∫₀^ε {k/x} dx‖ ≤ ε. -/
private lemma fract_integral_tail_bound (k : ℕ) (ε : ℝ) (hε : 0 ≤ ε) :
    ‖∫ x in (0 : ℝ)..ε, Int.fract ((k : ℝ) / x)‖ ≤ ε := by
  have h1 : ∀ x ∈ Set.uIoc (0 : ℝ) ε, ‖Int.fract ((k : ℝ) / x)‖ ≤ 1 := by
    intro x _; rw [Real.norm_eq_abs, abs_of_nonneg (Int.fract_nonneg _)]
    exact le_of_lt (Int.fract_lt_one _)
  calc ‖∫ x in (0 : ℝ)..ε, Int.fract ((k : ℝ) / x)‖
      ≤ 1 * |ε - 0| := intervalIntegral.norm_integral_le_of_norm_le_const h1
    _ = ε := by rw [sub_zero, abs_of_nonneg hε, one_mul]

/-- Helper: k/(k+N+1) → 0. -/
private lemma tendsto_k_div_k_add (k : ℕ) :
    Filter.Tendsto (fun N : ℕ => (k : ℝ) / ((k : ℝ) + (N : ℝ) + 1))
      Filter.atTop (nhds 0) := by
  rw [show (0 : ℝ) = (k : ℝ) * 0 from (mul_zero _).symm]
  apply Filter.Tendsto.const_mul
  · apply Filter.Tendsto.comp tendsto_inv_atTop_zero
    apply Filter.tendsto_atTop_atTop_of_monotone
    · intro a b h; push_cast; linarith [show (a : ℝ) ≤ b from Nat.cast_le.mpr h]
    · intro b; use ⌈b⌉₊; linarith [Nat.le_ceil b]

/-- **THEOREM** (was axiom): ∫₀¹ {k/x}dx = k · Σ (log(1+1/(m+k)) - 1/(m+k+1)).
    Proved by x-domain partition: piece formula + telescoping + tail vanishing. -/
theorem fract_integral_eq_tsum (k : ℕ) (hk : 1 ≤ k) :
    ∫ x in (0:ℝ)..1, Int.fract ((k : ℝ) / x) =
    (k : ℝ) * ∑' (m : ℕ),
      (Real.log (1 + 1 / ((m + k : ℕ) : ℝ)) - 1 / (((m + k : ℕ) : ℝ) + 1)) := by
  set I := ∫ x in (0:ℝ)..1, Int.fract ((k : ℝ) / x)
  set g : ℕ → ℝ := fun m =>
    Real.log (1 + 1 / ((m + k : ℕ) : ℝ)) - 1 / (((m + k : ℕ) : ℝ) + 1)
  -- Each piece equals k * g(j)
  have hpiece : ∀ j : ℕ,
      ∫ x in ((k : ℝ) / ((k : ℝ) + (j : ℝ) + 1))..((k : ℝ) / ((k : ℝ) + (j : ℝ))),
        Int.fract ((k : ℝ) / x) = (k : ℝ) * g j := by
    intro j; convert fract_integral_piece k (j + k) hk (by omega) using 2 <;> push_cast <;> ring
  -- Partial sums via telescope
  have hpartial : ∀ N : ℕ,
      ∑ j ∈ Finset.range (N + 1), (k : ℝ) * g j =
      ∫ x in ((k : ℝ) / ((k : ℝ) + (N : ℝ) + 1))..(1 : ℝ), Int.fract ((k : ℝ) / x) := by
    intro N; rw [← fract_integral_telescope k hk N]
    exact Finset.sum_congr rfl (fun j _ => (hpiece j).symm)
  -- Remainder = tail integral
  have hremainder : ∀ N : ℕ,
      I - ∑ j ∈ Finset.range (N + 1), (k : ℝ) * g j =
      ∫ x in (0 : ℝ)..((k : ℝ) / ((k : ℝ) + (N : ℝ) + 1)), Int.fract ((k : ℝ) / x) := by
    intro N; rw [hpartial, sub_eq_iff_eq_add]
    exact (intervalIntegral.integral_add_adjacent_intervals
      (fract_div_intervalIntegrable k _ _) (fract_div_intervalIntegrable k _ _)).symm
  -- Nonneg pieces
  have hnn : ∀ m, 0 ≤ (k : ℝ) * g m := by
    intro m; rw [← hpiece m]
    apply intervalIntegral.integral_nonneg
    · exact div_le_div_of_nonneg_left
        (le_of_lt (Nat.cast_pos.mpr (by omega : 0 < k)))
        (show (0 : ℝ) < (k : ℝ) + (↑m : ℝ) by positivity)
        (show (k : ℝ) + (↑m : ℝ) ≤ (k : ℝ) + (↑m : ℝ) + 1 by linarith)
    · intro x _; exact Int.fract_nonneg _
  -- HasSum via nonneg convergence
  have hhas : HasSum (fun m => (k : ℝ) * g m) I := by
    rw [hasSum_iff_tendsto_nat_of_nonneg hnn]
    rw [Metric.tendsto_atTop]
    intro ε hε
    obtain ⟨N₀, hN₀⟩ := exists_nat_gt ((k : ℝ) / ε)
    use N₀ + 1; intro N hN; rw [dist_eq_norm]
    obtain ⟨M, rfl⟩ := Nat.exists_eq_succ_of_ne_zero (by omega : N ≠ 0)
    rw [show ∑ j ∈ Finset.range (M + 1), ↑k * g j - I =
      -(I - ∑ j ∈ Finset.range (M + 1), ↑k * g j) from by ring, norm_neg, hremainder]
    calc ‖∫ x in (0 : ℝ)..↑k / (↑k + ↑M + 1), Int.fract (↑k / x)‖
        ≤ (k : ℝ) / ((k : ℝ) + (M : ℝ) + 1) := fract_integral_tail_bound k _ (by positivity)
      _ < ε := by
          rw [div_lt_iff₀ (by positivity : (0 : ℝ) < ↑k + ↑M + 1)]
          have hN₀' : (k : ℝ) < ε * N₀ := by rw [div_lt_iff₀ hε] at hN₀; linarith
          have hNM : (N₀ : ℝ) ≤ (M : ℝ) + 1 := by exact_mod_cast (show N₀ ≤ M + 1 by omega)
          nlinarith [show (0 : ℝ) ≤ (k : ℝ) from Nat.cast_nonneg k, hε]
  -- Conclude
  calc I = ∑' m, ((k : ℝ) * g m) := hhas.tsum_eq.symm
    _ = (k : ℝ) * ∑' m, g m := tsum_mul_left

-- summable_log_correction: proved below in Layer 2, after per_term_log_bound
-- and summable_inv_sq_shift are available.

-- ════════════════════════════════════════════════
-- LAYER 1: TELESCOPING SERIES
-- ════════════════════════════════════════════════

/-- **THEOREM**: Telescoping Σ_{m≥0} (1/(m+k) - 1/(m+k+1)) = 1/k.
    Proof: The partial sums telescope to 1/k - 1/(n+k) → 1/k. -/
lemma hasSum_telescoping_inv (k : ℕ) (hk : 1 ≤ k) :
    HasSum (fun m : ℕ => 1 / ((m + k : ℕ) : ℝ) - 1 / (((m + k : ℕ) : ℝ) + 1))
      (1 / (k : ℝ)) := by
  have hnn : ∀ m : ℕ, 0 ≤ 1 / ((m + k : ℕ) : ℝ) - 1 / (((m + k : ℕ) : ℝ) + 1) := by
    intro m
    have h1 : (0 : ℝ) < ((m + k : ℕ) : ℝ) := by positivity
    have h2 : (0 : ℝ) < ((m + k : ℕ) : ℝ) + 1 := by linarith
    rw [div_sub_div _ _ (ne_of_gt h1) (ne_of_gt h2)]
    exact div_nonneg (by linarith) (by positivity)
  rw [hasSum_iff_tendsto_nat_of_nonneg hnn]
  have hpartial : ∀ n : ℕ, ∑ i ∈ Finset.range n,
      (1 / ((i + k : ℕ) : ℝ) - 1 / (((i + k : ℕ) : ℝ) + 1)) =
      1 / (k : ℝ) - 1 / ((n + k : ℕ) : ℝ) := by
    intro n; induction n with
    | zero => simp
    | succ n ih =>
      rw [Finset.sum_range_succ, ih]
      have h1 : (0 : ℝ) < ((n + k : ℕ) : ℝ) := by positivity
      have h3 : (0 : ℝ) < ((n + 1 + k : ℕ) : ℝ) := by positivity
      have hkp : (0 : ℝ) < (k : ℝ) := by positivity
      have h1ne : ((n + k : ℕ) : ℝ) ≠ 0 := ne_of_gt h1
      have h3ne : ((n + 1 + k : ℕ) : ℝ) ≠ 0 := ne_of_gt h3
      have hkne : (k : ℝ) ≠ 0 := ne_of_gt hkp
      have h1p1 : ((n + k : ℕ) : ℝ) + 1 = ((n + 1 + k : ℕ) : ℝ) := by push_cast; ring
      rw [h1p1]; field_simp; push_cast; ring
  simp_rw [hpartial]
  suffices htend : Filter.Tendsto (fun n : ℕ => (1 : ℝ) / ((n + k : ℕ) : ℝ))
      Filter.atTop (nhds 0) by
    have := htend.const_sub (1 / (k : ℝ))
    simp only [sub_zero] at this; exact this
  have hcast : ∀ n : ℕ, (1 : ℝ) / ((n + k : ℕ) : ℝ) = ((n + k : ℕ) : ℝ)⁻¹ := by
    intro n; rw [one_div]
  simp_rw [hcast]
  apply Filter.Tendsto.comp tendsto_inv_atTop_zero
  apply Filter.tendsto_atTop_atTop_of_monotone
  · intro a b h; show ((a + k : ℕ) : ℝ) ≤ ((b + k : ℕ) : ℝ); exact_mod_cast Nat.add_le_add_right h k
  · intro b
    obtain ⟨n, hn⟩ := exists_nat_ge b
    exact ⟨n, le_trans hn (by exact_mod_cast Nat.le_add_right n k)⟩

private lemma tsum_telescoping_inv (k : ℕ) (hk : 1 ≤ k) :
    ∑' (m : ℕ), (1 / ((m + k : ℕ) : ℝ) - 1 / (((m + k : ℕ) : ℝ) + 1))
    = 1 / (k : ℝ) :=
  (hasSum_telescoping_inv k hk).tsum_eq

-- ════════════════════════════════════════════════
-- LAYER 2: TAIL BOUND (was axiom)
-- ════════════════════════════════════════════════

/-- Per-term bound: 1/n - log(1+1/n) ≤ 1/(2n²) for n ≥ 1.
    Uses Mathlib's le_log_one_add_of_nonneg: 2x/(x+2) ≤ log(1+x). -/
private lemma per_term_log_bound (n : ℕ) (hn : 1 ≤ n) :
    1 / ((n : ℕ) : ℝ) - Real.log (1 + 1 / ((n : ℕ) : ℝ))
    ≤ 1 / (2 * ((n : ℕ) : ℝ) ^ 2) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hlog := le_log_one_add_of_nonneg (show (0 : ℝ) ≤ 1 / (n : ℝ) from by positivity)
  -- Simplify the Mathlib bound: 2*(1/n)/(1/n + 2) = 2/(2n+1)
  have key : 2 * (1 / (↑n : ℝ)) / (1 / ↑n + 2) = 2 / (2 * ↑n + 1) := by
    have : (↑n : ℝ) ≠ 0 := ne_of_gt hn_pos
    field_simp; ring
  rw [key] at hlog
  -- Now hlog : 2/(2n+1) ≤ log(1+1/n)
  -- Need: 1/n - log(1+1/n) ≤ 1/(2n²)
  -- Suffices: 1/n - 2/(2n+1) ≤ 1/(2n²), i.e., 1/(n(2n+1)) ≤ 1/(2n²)
  suffices h : 1 / (↑n : ℝ) - 2 / (2 * ↑n + 1) ≤ 1 / (2 * (↑n) ^ 2) by linarith
  have h1 : (↑n : ℝ) ≠ 0 := ne_of_gt hn_pos
  have h2 : (0 : ℝ) < 2 * ↑n + 1 := by linarith
  rw [div_sub_div _ _ h1 (ne_of_gt h2)]
  rw [div_le_div_iff₀ (mul_pos hn_pos h2) (by positivity : (0 : ℝ) < 2 * ↑n ^ 2)]
  nlinarith [sq_nonneg (↑n : ℝ)]

/-- 1/n² ≤ 2*(1/n - 1/(n+1)) for n ≥ 1 (comparison with double-telescoping). -/
private lemma inv_sq_le_double_tele (n : ℕ) (hn : 1 ≤ n) :
    1 / ((n : ℕ) : ℝ) ^ 2 ≤ 2 * (1 / ((n : ℕ) : ℝ) - 1 / (((n : ℕ) : ℝ) + 1)) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  -- Pre-simplify: 2*(1/n - 1/(n+1)) = 2/(n(n+1))
  have hrhs : 2 * (1 / (↑n : ℝ) - 1 / (↑n + 1)) = 2 / (↑n * (↑n + 1)) := by
    have : (↑n : ℝ) ≠ 0 := ne_of_gt hn_pos
    field_simp; ring
  rw [hrhs]
  -- Goal: 1/n² ≤ 2/(n(n+1)) ⟺ n(n+1) ≤ 2n² ⟺ n+1 ≤ 2n ⟺ 1 ≤ n ✓
  rw [div_le_div_iff₀ (by positivity : (0 : ℝ) < (↑n) ^ 2)
    (by positivity : (0 : ℝ) < ↑n * (↑n + 1))]
  nlinarith [show (1 : ℝ) ≤ ↑n from Nat.one_le_cast.mpr hn, sq_nonneg (↑n : ℝ)]

/-- Summability of 1/(m+k)²: dominated by 2× telescoping series. -/
private lemma summable_inv_sq_shift (k : ℕ) (hk : 1 ≤ k) :
    Summable (fun m : ℕ => 1 / (((m + k : ℕ) : ℝ) ^ 2)) :=
  Summable.of_nonneg_of_le (fun m => by positivity)
    (fun m => inv_sq_le_double_tele (m + k) (by omega))
    ((hasSum_telescoping_inv k hk).summable.mul_left 2)

/-- **THEOREM** (was axiom): The log-harmonic correction is summable.
    Proof: |log(1+1/n) - 1/n| = 1/n - log(1+1/n) ≤ 1/(2n²),
    and 1/(2n²) is summable, so by comparison + sign flip. -/
theorem summable_log_correction (k : ℕ) (hk : 1 ≤ k) :
    Summable (fun m : ℕ =>
      Real.log (1 + 1 / ((m + k : ℕ) : ℝ)) - 1 / ((m + k : ℕ) : ℝ)) := by
  -- The negated terms 1/n - log(1+1/n) are nonneg (log(1+x) ≤ x)
  have hnn : ∀ m : ℕ, 0 ≤ 1 / ((m + k : ℕ) : ℝ) -
      Real.log (1 + 1 / ((m + k : ℕ) : ℝ)) := by
    intro m
    have : Real.log (1 + 1 / ((m + k : ℕ) : ℝ)) ≤ 1 / ((m + k : ℕ) : ℝ) := by
      rw [Real.log_le_iff_le_exp (by positivity)]
      linarith [Real.add_one_le_exp (1 / ((m + k : ℕ) : ℝ))]
    linarith
  -- Negated terms bounded by 1/(2(m+k)²), which is summable
  have hsumm_neg : Summable (fun m : ℕ =>
      1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ))) :=
    Summable.of_nonneg_of_le hnn
      (fun m => per_term_log_bound (m + k) (by omega))
      ((summable_inv_sq_shift k hk).mul_left (1/2) |>.congr (fun m => by
        show 1 / 2 * (1 / ((m + k : ℕ) : ℝ) ^ 2) = 1 / (2 * ((m + k : ℕ) : ℝ) ^ 2)
        ring))
  -- Summable (-f) → Summable f
  exact summable_neg_iff.mp (hsumm_neg.congr (fun m => by ring))

/-- For n ≥ 2: 1/n² ≤ 1/(n-1) - 1/n = 1/((n-1)n) (tighter comparison). -/
private lemma inv_sq_le_shifted_tele (m : ℕ) (k : ℕ) (hk : 1 ≤ k) :
    1 / (((m + 1 + k : ℕ) : ℝ) ^ 2) ≤
    1 / ((m + k : ℕ) : ℝ) - 1 / ((m + 1 + k : ℕ) : ℝ) := by
  -- n = m+1+k ≥ 2, n-1 = m+k ≥ 1
  -- Need: 1/n² ≤ 1/(n-1) - 1/n = 1/((n-1)n)
  -- ⟺ (n-1)n ≤ n² ⟺ n-1 ≤ n ✓
  have hmk : (0 : ℝ) < ((m + k : ℕ) : ℝ) := by positivity
  have hmk1 : (0 : ℝ) < ((m + 1 + k : ℕ) : ℝ) := by positivity
  rw [div_sub_div _ _ (ne_of_gt hmk) (ne_of_gt hmk1)]
  rw [div_le_div_iff₀ (by positivity : (0 : ℝ) < ((m + 1 + k : ℕ) : ℝ) ^ 2)
    (by positivity : (0 : ℝ) < ((m + k : ℕ) : ℝ) * ((m + 1 + k : ℕ) : ℝ))]
  have : ((m + k : ℕ) : ℝ) = ((m + 1 + k : ℕ) : ℝ) - 1 := by push_cast; ring
  nlinarith [sq_nonneg ((m + 1 + k : ℕ) : ℝ)]

/-- Bound: Σ_{m≥0} 1/(m+k)² ≤ (k+1)/k².
    Split as f(0) + tail, then compare tail against shifted telescoping. -/
private lemma tsum_inv_sq_bound (k : ℕ) (hk : 1 ≤ k) :
    ∑' (m : ℕ), (1 / (((m + k : ℕ) : ℝ) ^ 2))
    ≤ ((k : ℝ) + 1) / ((k : ℝ) ^ 2) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := by positivity
  have hsumm := summable_inv_sq_shift k hk
  -- Split: Σ_{m≥0} = f(0) + Σ_{m≥0} f(m+1)
  rw [hsumm.tsum_eq_zero_add]
  simp only [Nat.zero_add]
  -- f(0) = 1/k²; need: 1/k² + Σ_{m≥0} 1/(m+1+k)² ≤ (k+1)/k²
  -- Σ_{m≥0} 1/(m+1+k)² ≤ Σ_{m≥0} (1/(m+k) - 1/(m+1+k)) = 1/k (telescoping)
  have htail_summ : Summable (fun m => 1 / (((m + 1 + k : ℕ) : ℝ) ^ 2)) :=
    hsumm.comp_injective (fun a b h => by omega)
  have htail : ∑' m, (1 / (((m + 1 + k : ℕ) : ℝ) ^ 2)) ≤ 1 / (k : ℝ) := by
    calc ∑' m, (1 / (((m + 1 + k : ℕ) : ℝ) ^ 2))
        ≤ ∑' m, (1 / ((m + k : ℕ) : ℝ) - 1 / ((m + 1 + k : ℕ) : ℝ)) :=
          htail_summ.tsum_le_tsum
            (fun m => inv_sq_le_shifted_tele m k hk)
            ((hasSum_telescoping_inv k hk).summable.congr (fun m => by
              push_cast; congr 1; ring))
      _ = 1 / (k : ℝ) := by
          have : (fun m : ℕ => 1 / ((m + k : ℕ) : ℝ) - 1 / ((m + 1 + k : ℕ) : ℝ)) =
            (fun m : ℕ => 1 / ((m + k : ℕ) : ℝ) - 1 / (((m + k : ℕ) : ℝ) + 1)) := by
            ext m; congr 1; push_cast; ring
          rw [this, (hasSum_telescoping_inv k hk).tsum_eq]
  -- 1/k² + 1/k = (k+1)/k²
  have : 1 / (k : ℝ) ^ 2 + 1 / (k : ℝ) = ((k : ℝ) + 1) / ((k : ℝ) ^ 2) := by
    field_simp; ring
  linarith

/-- **THEOREM** (was axiom): k·Σ_{n≥k}(1/n - log(1+1/n)) ≤ 1/2 + 1/(2k). -/
theorem log_harmonic_tail_bound (k : ℕ) (hk : 1 ≤ k) :
    (k : ℝ) * ∑' (m : ℕ),
      (1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ)))
    ≤ 1 / 2 + 1 / (2 * (k : ℝ)) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := by positivity
  -- Summability (negate summable_log_correction)
  have hsumm : Summable (fun m : ℕ =>
      1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ))) := by
    have := (summable_log_correction k hk).neg; simp only [neg_sub] at this; exact this
  -- Step 1: tsum comparison via per-term bound
  have hcomp : ∑' m, (1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ)))
      ≤ (1 / 2) * ∑' m, (1 / ((m + k : ℕ) : ℝ) ^ 2) := by
    calc ∑' m, (1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ)))
        ≤ ∑' m, (1 / (2 * ((m + k : ℕ) : ℝ) ^ 2)) :=
          hsumm.tsum_le_tsum (fun m => per_term_log_bound (m + k) (by omega))
            ((summable_inv_sq_shift k hk).mul_left (1/2) |>.congr (fun m => by
              show 1 / 2 * (1 / ((m + k : ℕ) : ℝ) ^ 2) = 1 / (2 * ((m + k : ℕ) : ℝ) ^ 2)
              ring))
      _ = (1 / 2) * ∑' m, (1 / ((m + k : ℕ) : ℝ) ^ 2) := by
          rw [← tsum_mul_left]; congr 1; ext m; ring
  -- Step 2: Apply tsum_inv_sq_bound and assemble
  calc (k : ℝ) * ∑' m, (1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ)))
      ≤ (k : ℝ) * ((1 / 2) * ∑' m, (1 / ((m + k : ℕ) : ℝ) ^ 2)) :=
        mul_le_mul_of_nonneg_left hcomp (le_of_lt hk_pos)
    _ ≤ (k : ℝ) * ((1 / 2) * (((k : ℝ) + 1) / ((k : ℝ) ^ 2))) :=
        mul_le_mul_of_nonneg_left
          (mul_le_mul_of_nonneg_left (tsum_inv_sq_bound k hk) (by norm_num))
          (le_of_lt hk_pos)
    _ = 1 / 2 + 1 / (2 * (k : ℝ)) := by field_simp

-- ════════════════════════════════════════════════
-- LAYER 3: INTEGRAL IDENTITIES
-- ════════════════════════════════════════════════

/-- **THEOREM**: ∫₀¹ {k/x}dx = 1 + k·Σ(log(1+1/n) - 1/n).
    From fract_integral_eq_tsum by splitting each term:
    log - 1/(n+1) = (log - 1/n) + (1/n - 1/(n+1))
    and using Σ(1/n - 1/(n+1)) = 1/k (telescoping). -/
theorem fract_integral_as_one_plus (k : ℕ) (hk : 1 ≤ k) :
    ∫ x in (0:ℝ)..1, Int.fract ((k : ℝ) / x) =
    1 + (k : ℝ) * ∑' (m : ℕ),
      (Real.log (1 + 1 / ((m + k : ℕ) : ℝ)) - 1 / ((m + k : ℕ) : ℝ)) := by
  have h := fract_integral_eq_tsum k hk
  rw [h]
  have htel := tsum_telescoping_inv k hk
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hsumm_log := summable_log_correction k hk
  have hsumm_tel := (hasSum_telescoping_inv k hk).summable
  have hgoal : ∑' (m : ℕ),
      (Real.log (1 + 1 / ((m + k : ℕ) : ℝ)) - 1 / (((m + k : ℕ) : ℝ) + 1)) =
      ∑' (m : ℕ), (Real.log (1 + 1 / ((m + k : ℕ) : ℝ)) - 1 / ((m + k : ℕ) : ℝ)) +
        1 / (k : ℝ) := by
    rw [← htel, ← Summable.tsum_add hsumm_log hsumm_tel]; congr 1; ext m; ring
  rw [hgoal, mul_add, mul_one_div_cancel (ne_of_gt hk_pos)]
  ring

/-- **THEOREM**: ∫₀¹ {k/x}dx = 1 - k · Σ(1/n - log(1+1/n)).
    Sign flip via tsum_neg. -/
theorem fract_integral_identity (k : ℕ) (hk : 1 ≤ k) :
    ∫ x in (0:ℝ)..1, Int.fract ((k : ℝ) / x) =
    1 - (k : ℝ) * ∑' (m : ℕ),
      (1 / ((m + k : ℕ) : ℝ) - Real.log (1 + 1 / ((m + k : ℕ) : ℝ))) := by
  have h := fract_integral_as_one_plus k hk
  rw [h]
  have key : ∑' (m : ℕ), (1 / ((m + k : ℕ) : ℝ) -
      Real.log (1 + 1 / ((m + k : ℕ) : ℝ))) =
    - ∑' (m : ℕ), (Real.log (1 + 1 / ((m + k : ℕ) : ℝ)) -
      1 / ((m + k : ℕ) : ℝ)) := by
    rw [← tsum_neg]; congr 1; ext m; ring
  rw [key]; ring

-- ════════════════════════════════════════════════
-- LAYER 4: THE PER-ENTRY BOUND
-- ════════════════════════════════════════════════

/-- **THEOREM**: ∫₀¹ {k/x}dx ≥ 1/2 - 1/(2k).
    From fract_integral_identity + log_harmonic_tail_bound:
    ∫ = 1 - k·tail ≥ 1 - (1/2 + 1/(2k)) = 1/2 - 1/(2k). -/
theorem basis_entry_lower (k : ℕ) (hk : 1 ≤ k) :
    ∫ x in (0:ℝ)..1, Int.fract ((k : ℝ) / x) ≥ (1:ℝ)/2 - 1 / (2 * (k : ℝ)) := by
  have h1 := fract_integral_identity k hk
  have h2 := log_harmonic_tail_bound k hk
  linarith

end
