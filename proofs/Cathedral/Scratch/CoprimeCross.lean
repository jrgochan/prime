/-
  Cathedral/Scratch/CoprimeCross.lean

  Proof of: ∫₀¹ ({αt}-½)({βt}-½) dt = 1/(12αβ) for coprime α,β.

  Strategy (for 1 ≤ α < β, gcd(α,β)=1):
  1. Split ∫₀¹ into β pieces via {βt} periodicity
  2. Substitute u = βt-k on piece k
  3. CRT reindex: m = αk mod β permutes {0,...,β-1}
  4. Case analysis:
     - Case 1 (m ≤ β-α): integral = α/(12β)
     - Case 2 (m > β-α): integral = α/(12β) - r(α-r)/(2α²) where r = β-m
  5. Sum = α/(12β) - (α²-1)/(12αβ) = 1/(12αβ)
-/

import Cathedral.GramOffDiag
import Cathedral.GramBounds
import Mathlib.MeasureTheory.Function.Floor

set_option maxHeartbeats 4000000
noncomputable section
open Real MeasureTheory Set Finset Int

-- ═══════════════════════════════════════════════
-- Helper: {x + n} = {x} for integer n
-- ═══════════════════════════════════════════════

private lemma fract_add_nat_mul (x : ℝ) (n k : ℕ) :
    Int.fract ((n : ℝ) * x + (k : ℝ)) = Int.fract ((n : ℝ) * x) := by
  rw [Int.fract_add_natCast]

private lemma fract_of_nonneg_lt_one' (x : ℝ) (h0 : 0 ≤ x) (h1 : x < 1) :
    Int.fract x = x := Int.fract_eq_self.mpr ⟨h0, h1⟩

private lemma ae_ne_one : ∀ᵐ u : ℝ ∂volume, u ≠ 1 :=
  compl_mem_ae_iff.mpr volume_singleton

private lemma ae_ne (c : ℝ) : ∀ᵐ u : ℝ ∂volume, u ≠ c :=
  compl_mem_ae_iff.mpr volume_singleton

-- ═══════════════════════════════════════════════
-- Case 1: Linear piece (no floor jump)
-- ∫₀¹ ((αu+m)/β - ½)(u-½) du = α/(12β)
-- when αu+m ≤ β for all u ∈ [0,1], i.e., m ≤ β-α
-- ═══════════════════════════════════════════════

/-- When m ≤ β-α, the integral over [0,1] is α/(12β). -/
private lemma case1_integral (α β m : ℕ) (hα : 1 ≤ α) (hβ : 1 ≤ β)
    (hαβ : α < β) (hm : m ≤ β - α) :
    ∫ u in (0:ℝ)..1,
      ((α : ℝ) * u + (m : ℝ)) / (β : ℝ) * (u - 1/2) -
      (1/2) * (u - 1/2) = (α : ℝ) / (12 * (β : ℝ)) := by
  -- Integrand expanded: (α/β)u² + (m/β - α/(2β) - 1/2)u + (1/4 - m/(2β))
  -- Antideriv: (α/β)u³/3 + ((m-α/2)/β - 1/2)u²/2 + (1/4 - m/(2β))u
  -- At u=1: α/(3β) + m/(2β) - α/(4β) - 1/4 + 1/4 - m/(2β) = α/(12β)
  have hβ_pos : (0 : ℝ) < (β : ℝ) := Nat.cast_pos.mpr (by omega)
  have hβ_ne : (β : ℝ) ≠ 0 := ne_of_gt hβ_pos
  -- Use single antiderivative
  have hderiv : ∀ x ∈ Set.uIcc (0:ℝ) 1,
      HasDerivAt (fun u => (α : ℝ) * u^3 / (3 * (β : ℝ)) +
        ((m : ℝ) / (β : ℝ) - (α : ℝ) / (2*(β : ℝ)) - 1/2) * u^2 / 2 +
        (1/4 - (m : ℝ) / (2*(β : ℝ))) * u)
        (((α : ℝ) * x + (m : ℝ)) / (β : ℝ) * (x - 1/2) - 1/2 * (x - 1/2)) x := by
    intro x _
    have h1 := ((hasDerivAt_pow 3 x).const_mul ((α : ℝ))).div_const (3 * (β : ℝ))
    have h2 := ((hasDerivAt_pow 2 x).const_mul
      ((m : ℝ) / (β : ℝ) - (α : ℝ) / (2*(β : ℝ)) - 1/2)).div_const 2
    have h3 := (hasDerivAt_id x).const_mul (1/4 - (m : ℝ) / (2*(β : ℝ)))
    convert (h1.add h2).add h3 using 1
    field_simp; ring
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hderiv
      (by apply ContinuousOn.intervalIntegrable; fun_prop)]
  simp; field_simp; ring

/-- The polynomial integral α/(12β) holds for ALL m, not just m ≤ β-α. -/
private lemma poly_integral (α β : ℕ) (m : ℝ) (hβ : 1 ≤ β) :
    ∫ u in (0:ℝ)..1,
      ((α : ℝ) * u + m) / (β : ℝ) * (u - 1/2) -
      (1/2) * (u - 1/2) = (α : ℝ) / (12 * (β : ℝ)) := by
  have hβ_pos : (0 : ℝ) < (β : ℝ) := Nat.cast_pos.mpr (by omega)
  have hβ_ne : (β : ℝ) ≠ 0 := ne_of_gt hβ_pos
  have hderiv : ∀ x ∈ Set.uIcc (0:ℝ) 1,
      HasDerivAt (fun u => (α : ℝ) / (3 * (β : ℝ)) * u^3 +
        (m / (β : ℝ) - (α : ℝ) / (2 * (β : ℝ)) - 1/2) / 2 * u^2 +
        (-m / (2 * (β : ℝ)) + 1/4) * u)
      (((α : ℝ) * x + m) / (β : ℝ) * (x - 1/2) - 1/2 * (x - 1/2)) x := by
    intro x _
    have h1 : HasDerivAt (fun u => (α : ℝ) / (3 * (β : ℝ)) * u^3) ((α : ℝ) / (β : ℝ) * x^2) x := by
      have := (hasDerivAt_pow 3 x).const_mul ((α : ℝ) / (3 * (β : ℝ)))
      convert this using 1; field_simp; ring
    have h2 : HasDerivAt (fun u => (m / (β : ℝ) - (α : ℝ) / (2 * (β : ℝ)) - 1/2) / 2 * u^2)
        ((m / (β : ℝ) - (α : ℝ) / (2 * (β : ℝ)) - 1/2) * x) x := by
      have := (hasDerivAt_pow 2 x).const_mul ((m / (β : ℝ) - (α : ℝ) / (2 * (β : ℝ)) - 1/2) / 2)
      convert this using 1; ring
    have h3 : HasDerivAt (fun u => (-m / (2 * (β : ℝ)) + 1/4) * u) (-m / (2 * (β : ℝ)) + 1/4) x := by
      have := (hasDerivAt_id x).const_mul (-m / (2 * (β : ℝ)) + 1/4)
      convert this using 1; ring
    convert (h1.add h2).add h3 using 1; field_simp; ring
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hderiv
      (by apply ContinuousOn.intervalIntegrable; fun_prop)]
  simp; field_simp; ring

-- ═══════════════════════════════════════════════
-- Case 2: Split piece (floor jump at u = (β-m)/α)
-- Integral = α/(12β) - r(α-r)/(2α²)  where r = β-m
-- ═══════════════════════════════════════════════

/-- When m > β-α, the correction is -r(α-r)/(2α²) where r = β-m. -/
private lemma case2_correction (α β m : ℕ) (hα : 1 ≤ α) (hβ : 1 ≤ β)
    (hαβ : α < β) (hm_lo : β - α < m) (hm_hi : m < β) :
    ∫ u in ((β - m : ℝ) / (α : ℝ))..1, (u - 1/2 : ℝ) =
    (β - m : ℝ) * ((α : ℝ) - (β - m : ℝ)) / (2 * (α : ℝ)^2) := by
  have hα_pos : (0 : ℝ) < (α : ℝ) := Nat.cast_pos.mpr (by omega)
  have hα_ne : (α : ℝ) ≠ 0 := ne_of_gt hα_pos
  -- Direct FTC
  have hderiv : ∀ x ∈ Set.uIcc ((β - m : ℝ) / (α : ℝ)) 1,
      HasDerivAt (fun u => u^2 / 2 - u / 2) (x - 1/2) x := by
    intro x _
    have h1 : HasDerivAt (fun u => u^2 / 2) x x := by
      have := (hasDerivAt_pow 2 x).div_const 2
      convert this using 1; ring
    have h2 : HasDerivAt (fun u => u / 2) (1/2 : ℝ) x := by
      have := (hasDerivAt_id x).div_const 2
      convert this using 1
    convert h1.sub h2 using 1
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hderiv
      (by apply ContinuousOn.intervalIntegrable
          exact (continuous_id.sub continuous_const).continuousOn)]
  field_simp; ring

-- Helper: Σ_{i=0}^{n-1} (i+1) = n(n+1)/2
private lemma sum_shift (n : ℕ) :
    (Finset.range n).sum (fun i => ((i : ℝ) + 1)) = (n : ℝ) * ((n : ℝ) + 1) / 2 := by
  induction n with
  | zero => simp
  | succ k ih => rw [Finset.sum_range_succ, ih]; push_cast; ring

-- Helper: Σ_{i=0}^{n-1} (i+1)² = n(n+1)(2n+1)/6
private lemma sum_sq_shift (n : ℕ) :
    (Finset.range n).sum (fun i => ((i : ℝ) + 1)^2) = (n : ℝ) * ((n : ℝ) + 1) * (2 * (n : ℝ) + 1) / 6 := by
  induction n with
  | zero => simp
  | succ k ih => rw [Finset.sum_range_succ, ih]; push_cast; ring

lemma sum_r_times_complement (α : ℕ) (_hα : 1 ≤ α) :
    (Finset.range (α - 1)).sum (fun r =>
      ((r : ℝ) + 1) * ((α : ℝ) - ((r : ℝ) + 1))) =
    (α : ℝ) * ((α : ℝ)^2 - 1) / 6 := by
  -- Expand: (r+1)(α-r-1) = α(r+1) - (r+1)²
  conv_lhs =>
    arg 2; ext r
    rw [show ((r:ℝ)+1)*((α:ℝ)-((r:ℝ)+1)) = (α:ℝ)*((r:ℝ)+1) - ((r:ℝ)+1)^2 from by ring]
  rw [Finset.sum_sub_distrib]
  -- Factor α out: α·Σ(r+1) - Σ(r+1)²
  rw [← Finset.mul_sum]
  rw [sum_shift (α - 1), sum_sq_shift (α - 1)]
  -- Now it's algebra with n = α-1
  have hα1 : (α : ℝ) - 1 = ((α - 1 : ℕ) : ℝ) := by
    rw [Nat.cast_sub _hα]; ring
  rw [← hα1]; ring

-- ═══════════════════════════════════════════════
-- CRT: βk mod α is a permutation of {0,...,α-1}
-- ═══════════════════════════════════════════════

/-- For coprime α,β: multiplication by β is a bijection on ℤ/αℤ. -/
lemma coprime_mul_bij (α β : ℕ) (hα : 1 ≤ α)
    (hcop : Nat.Coprime α β) :
    (Finset.range α).image (fun k => k * β % α) = Finset.range α := by
  haveI : NeZero α := ⟨by omega⟩
  ext x; simp only [Finset.mem_image, Finset.mem_range]
  constructor
  · rintro ⟨k, _, rfl⟩; exact Nat.mod_lt _ (by omega)
  · intro hx
    have hβu : IsUnit ((β : ZMod α)) := by
      rw [ZMod.isUnit_iff_coprime]; exact hcop.symm
    obtain ⟨u, hu⟩ := hβu
    use ((x : ZMod α) * ↑u⁻¹).val
    refine ⟨ZMod.val_lt _, ?_⟩
    have h1 : ((((x : ZMod α) * ↑u⁻¹).val * β : ℕ) : ZMod α) = (x : ZMod α) := by
      push_cast; rw [ZMod.natCast_zmod_val, mul_assoc, ← hu]; simp
    have := congr_arg ZMod.val h1
    rwa [ZMod.val_natCast, ZMod.val_natCast, Nat.mod_eq_of_lt hx] at this

-- ═══════════════════════════════════════════════
-- Layer 2: Integrability + splitting
-- ═══════════════════════════════════════════════

private lemma cross_integrable (α β : ℕ) (a b : ℝ) :
    IntervalIntegrable (fun t => (Int.fract ((α : ℝ) * t) - 1/2) *
      (Int.fract ((β : ℝ) * t) - 1/2)) volume a b := by
  apply (intervalIntegrable_const (c := (1 : ℝ))).mono_fun
  · exact ((measurable_fract.comp (measurable_const.mul measurable_id)).sub
      measurable_const).mul ((measurable_fract.comp (measurable_const.mul
      measurable_id)).sub measurable_const) |>.aestronglyMeasurable
  · filter_upwards with t
    show ‖(Int.fract (↑α * t) - 1/2) * (Int.fract (↑β * t) - 1/2)‖ ≤ ‖(1 : ℝ)‖
    rw [Real.norm_eq_abs, Real.norm_eq_abs, abs_one, abs_mul]
    calc |(Int.fract ((α : ℝ) * t) - 1/2)| * |(Int.fract ((β : ℝ) * t) - 1/2)|
        ≤ (1/2 : ℝ) * (1/2) := by
          apply mul_le_mul
          · rw [abs_le]; constructor <;> linarith [Int.fract_nonneg (↑α * t), Int.fract_lt_one (↑α * t)]
          · rw [abs_le]; constructor <;> linarith [Int.fract_nonneg (↑β * t), Int.fract_lt_one (↑β * t)]
          · exact abs_nonneg _
          · norm_num
      _ ≤ 1 := by norm_num

private lemma cross_telescope (α β : ℕ) (_hβ : 1 ≤ β) (M : ℕ) (_hM : M < β) :
    ∑ k ∈ Finset.range (M + 1),
      ∫ t in ((k : ℝ) / (β : ℝ))..((↑k + 1) / (β : ℝ)),
        (Int.fract ((α : ℝ) * t) - 1/2) * (Int.fract ((β : ℝ) * t) - 1/2) =
    ∫ t in (0 : ℝ)..((↑M + 1) / (β : ℝ)),
        (Int.fract ((α : ℝ) * t) - 1/2) * (Int.fract ((β : ℝ) * t) - 1/2) := by
  induction M with
  | zero => rw [Finset.sum_range_one]; simp
  | succ M ih =>
    rw [Finset.sum_range_succ, ih (by omega)]
    have hcast : (↑(M + 1) : ℝ) = (M : ℝ) + 1 := by push_cast; ring
    simp only [hcast]
    exact intervalIntegral.integral_add_adjacent_intervals
      (cross_integrable α β 0 _) (cross_integrable α β _ _)

private lemma cross_split (α β : ℕ) (hβ : 1 ≤ β) :
    ∫ t in (0:ℝ)..1, (Int.fract ((α : ℝ) * t) - 1/2) *
                      (Int.fract ((β : ℝ) * t) - 1/2) =
    ∑ k ∈ Finset.range β,
      ∫ t in ((k : ℝ) / (β : ℝ))..((↑k + 1) / (β : ℝ)),
        (Int.fract ((α : ℝ) * t) - 1/2) * (Int.fract ((β : ℝ) * t) - 1/2) := by
  have hβ_pos : (0 : ℝ) < (β : ℝ) := Nat.cast_pos.mpr (by omega)
  set f := fun t => (Int.fract ((α : ℝ) * t) - 1/2) * (Int.fract ((β : ℝ) * t) - 1/2)
  have hep : ((↑(β-1) : ℝ) + 1) / (β : ℝ) = 1 := by
    have : (↑(β - 1) : ℝ) + 1 = (β : ℝ) := by
      rw [Nat.cast_sub (by omega)]; push_cast; linarith
    rw [this]; field_simp
  calc ∫ t in (0:ℝ)..1, f t
      = ∫ t in (0:ℝ)..((↑(β-1) + 1) / (β : ℝ)), f t := by rw [hep]
    _ = ∑ k ∈ Finset.range β, ∫ t in ((k : ℝ) / (β : ℝ))..((↑k + 1) / (β : ℝ)), f t := by
        rw [← cross_telescope α β hβ (β - 1) (by omega)]
        rw [show β - 1 + 1 = β from by omega]

-- ═══════════════════════════════════════════════
-- Layer 1: Per-piece integral (verified)
-- ═══════════════════════════════════════════════

private lemma piece_integral (α β k : ℕ) (hα : 1 ≤ α) (hβ : 1 ≤ β)
    (hαβ : α < β) (hk : k < β) (_hcop : Nat.Coprime α β) :
    ∫ t in ((k : ℝ) / (β : ℝ))..((↑k + 1) / (β : ℝ)),
      (Int.fract ((α : ℝ) * t) - 1/2) * (Int.fract ((β : ℝ) * t) - 1/2) =
    (α : ℝ) / (12 * (β : ℝ)^2) -
    (if (β - α : ℤ) < ((α * k % β : ℕ) : ℤ) then
      ((β - α * k % β : ℤ) : ℝ) * ((α : ℝ) - ((β - α * k % β : ℤ) : ℝ)) /
        (2 * (α : ℝ)^2 * (β : ℝ))
    else 0) := by
  have hβ_pos : (0 : ℝ) < (β : ℝ) := Nat.cast_pos.mpr (by omega)
  have hβ_ne : (β : ℝ) ≠ 0 := ne_of_gt hβ_pos
  have hα_pos : (0 : ℝ) < (α : ℝ) := Nat.cast_pos.mpr (by omega)
  -- ─── A: Define g, prove f(t) = g(βt + (-k)) ───
  set g : ℝ → ℝ := fun u =>
    (Int.fract ((α : ℝ) * ((u + (k : ℝ)) / (β : ℝ))) - 1/2) *
    (Int.fract (u + (k : ℝ)) - 1/2) with hg_def
  have h_eq : (fun t => (Int.fract ((α : ℝ) * t) - 1/2) *
      (Int.fract ((β : ℝ) * t) - 1/2)) =
      (fun t => g ((β : ℝ) * t + (-(k : ℝ)))) := by
    ext t; simp only [g]
    congr 1
    · congr 1
      rw [show (β : ℝ) * t + -(k : ℝ) + (k : ℝ) = (β : ℝ) * t from by ring]
      rw [show (β : ℝ) * t / (β : ℝ) = t from by field_simp]
    · congr 1
      rw [show (β : ℝ) * t + -(k : ℝ) + (k : ℝ) = (β : ℝ) * t from by ring]
  -- ─── B: Substitution via integral_comp_mul_add ───
  rw [show (fun t => (Int.fract ((α : ℝ) * t) - 1/2) *
      (Int.fract ((β : ℝ) * t) - 1/2)) =
      (fun t => g ((β : ℝ) * t + (-(k : ℝ)))) from h_eq]
  rw [intervalIntegral.integral_comp_mul_add g hβ_ne,
    show (β : ℝ) * ((k : ℝ) / (β : ℝ)) + -(k : ℝ) = 0 from by field_simp; ring,
    show (β : ℝ) * (((k : ℝ) + 1) / (β : ℝ)) + -(k : ℝ) = 1 from by field_simp; ring]
  -- Now: β⁻¹ • ∫₀¹ g(u) du = target
  -- ─── C: Simplify g to ({(αu+m)/β}-1/2)({u}-1/2) ───
  set m := α * k % β
  have g_eq : ∀ u : ℝ, g u =
      (Int.fract (((α : ℝ) * u + (m : ℝ)) / (β : ℝ)) - 1/2) * (Int.fract u - 1/2) := by
    intro u; simp only [g]
    have hfract_α : Int.fract ((α : ℝ) * ((u + (k : ℝ)) / (β : ℝ))) =
        Int.fract (((α : ℝ) * u + ((α * k % β : ℕ) : ℝ)) / (β : ℝ)) := by
      rw [show (α : ℝ) * ((u + (k : ℝ)) / (β : ℝ)) =
          ((α : ℝ) * u + (α : ℝ) * (k : ℝ)) / (β : ℝ) from by field_simp]
      have hqm_r : (α : ℝ) * (k : ℝ) = ((α * k / β : ℕ) : ℝ) * (β : ℝ) + ((α * k % β : ℕ) : ℝ) := by
        have h := Nat.div_add_mod (α * k) β
        have : ((α * k : ℕ) : ℝ) = ((β * (α * k / β) + α * k % β : ℕ) : ℝ) := by exact_mod_cast h.symm
        push_cast at this ⊢; nlinarith
      rw [show ((α : ℝ) * u + (α : ℝ) * (k : ℝ)) / (β : ℝ) =
          ((α * k / β : ℕ) : ℝ) + ((α : ℝ) * u + ((α * k % β : ℕ) : ℝ)) / (β : ℝ) from by
        rw [hqm_r]; field_simp; ring,
        show ((α * k / β : ℕ) : ℝ) + ((α : ℝ) * u + ((α * k % β : ℕ) : ℝ)) / (β : ℝ) =
          ((α : ℝ) * u + ((α * k % β : ℕ) : ℝ)) / (β : ℝ) + ((α * k / β : ℕ) : ℝ) from by ring,
        Int.fract_add_natCast]
    rw [hfract_α, Int.fract_add_natCast]
  simp_rw [g_eq]
  -- ─── D: Case split on m ≤ β-α ───
  by_cases hcase : (β - α : ℤ) < ((m : ℕ) : ℤ)
  · -- Case 2: m > β-α (floor jump at u₀ = (β-m)/α)
    simp only [hcase, if_true]
    have hm_lo : β - α < m := by omega
    have hm_lt : m < β := Nat.mod_lt _ (by omega)
    -- u₀ = (β - m)/α is the breakpoint
    set u₀ : ℝ := ((β : ℝ) - (m : ℝ)) / (α : ℝ)
    -- u₀ ∈ (0, 1) since β - α < m < β and 1 ≤ α < β
    have hu₀_pos : 0 < u₀ := by
      show 0 < ((β : ℝ) - (m : ℝ)) / (α : ℝ)
      apply div_pos
      · exact sub_pos.mpr (by exact_mod_cast hm_lt)
      · exact hα_pos
    have hu₀_lt1 : u₀ < 1 := by
      show ((β : ℝ) - (m : ℝ)) / (α : ℝ) < 1
      rw [div_lt_one hα_pos]
      have : (m : ℝ) > (β : ℝ) - (α : ℝ) := by exact_mod_cast hcase
      linarith
    -- Step 1: ae rewrite the fract integrand to polynomial minus correction
    -- For u ∈ (0,1) \ {u₀}, the fract integrand equals:
    --   ((αu+m)/β - 1/2)(u-1/2) - (if u₀ < u then (u-1/2) else 0)
    -- Integrate: = ∫₀¹ poly - ∫_{u₀}¹ (u-1/2)
    -- = case1_integral - case2_correction
    -- Then scale by β⁻¹.
    --
    -- High-level: instead of ae rewriting the full integrand,
    -- we use ∫₀¹ = ∫₀^{u₀} + ∫_{u₀}¹ and ae-rewrite each piece.
    -- On ∫₀^{u₀}: fract = identity (ae, excluding {u₀})
    -- On ∫_{u₀}¹: fract = identity - 1 for (αu+m)/β, identity for u (ae, excluding {u₀, 1})
    have hm_bound_lt : (m : ℤ) + (α : ℤ) > (β : ℤ) := by omega
    have hm_bound_lt2 : (m : ℕ) + α < 2 * β := by omega
    -- Add fract_of_ge_one_lt_two helper
    have fract_ge1 : ∀ (x : ℝ), 1 ≤ x → x < 2 → Int.fract x = x - 1 := by
      intro x h0 h1
      have : Int.fract x = Int.fract (x - 1 + 1) := by ring_nf
      rw [this, show (1 : ℝ) = ((↑1 : ℤ) : ℝ) from by norm_cast, Int.fract_add_intCast,
          Int.fract_eq_self]
      push_cast; constructor <;> linarith
    -- Step 1: Integral on [0, u₀]
    have h_int1 : ∫ u in (0:ℝ)..u₀,
        (Int.fract (((α : ℝ) * u + (m : ℝ)) / (β : ℝ)) - 1/2) * (Int.fract u - 1/2) =
        ∫ u in (0:ℝ)..u₀,
        (((α : ℝ) * u + (m : ℝ)) / (β : ℝ) - 1/2) * (u - 1/2) := by
      apply intervalIntegral.integral_congr_ae
      filter_upwards [ae_ne_one, ae_ne u₀] with u hne1 hneu₀ hu
      rw [Set.uIoc_of_le (le_of_lt hu₀_pos)] at hu
      have hu0 : 0 < u := hu.1
      have huu₀ : u ≤ u₀ := hu.2
      have hlt_u₀ : u < u₀ := lt_of_le_of_ne huu₀ hneu₀
      have hu_lt1 : u < 1 := lt_trans hlt_u₀ hu₀_lt1
      -- {u} = u since 0 ≤ u < 1
      rw [fract_of_nonneg_lt_one' u (le_of_lt hu0) hu_lt1]
      -- (αu+m)/β < 1 since αu < α·u₀ = β-m, so αu+m < β
      have hx_lt1 : ((α : ℝ) * u + (m : ℝ)) / (β : ℝ) < 1 := by
        rw [div_lt_one hβ_pos]
        have h_au_lt : (α : ℝ) * u < (α : ℝ) * u₀ :=
          mul_lt_mul_of_pos_left hlt_u₀ hα_pos
        have h_au0 : (α : ℝ) * u₀ = (β : ℝ) - (m : ℝ) := by
          show (α : ℝ) * (((β : ℝ) - (m : ℝ)) / (α : ℝ)) = _
          rw [mul_div_cancel₀ _ (ne_of_gt hα_pos)]
        linarith
      have h_div_nn : (0:ℝ) ≤ ((α : ℝ) * u + (m : ℝ)) / (β : ℝ) := by
        apply div_nonneg _ (le_of_lt hβ_pos)
        have : (0:ℝ) ≤ (α : ℝ) * u := mul_nonneg (Nat.cast_nonneg _) (le_of_lt hu0)
        have : (0 : ℝ) ≤ (m : ℝ) := Nat.cast_nonneg _
        linarith
      rw [fract_of_nonneg_lt_one' _ h_div_nn hx_lt1]
    -- Step 2: Integral on [u₀, 1]
    have h_int2 : ∫ u in u₀..1,
        (Int.fract (((α : ℝ) * u + (m : ℝ)) / (β : ℝ)) - 1/2) * (Int.fract u - 1/2) =
        ∫ u in u₀..1,
        (((α : ℝ) * u + (m : ℝ)) / (β : ℝ) - 1 - 1/2) * (u - 1/2) := by
      apply intervalIntegral.integral_congr_ae
      filter_upwards [ae_ne_one, ae_ne u₀] with u hne1 hneu₀ hu
      rw [Set.uIoc_of_le (le_of_lt hu₀_lt1)] at hu
      have hu_gt_u₀ : u₀ < u := hu.1
      have hu_le1 : u ≤ 1 := hu.2
      have hu_lt1 : u < 1 := lt_of_le_of_ne hu_le1 hne1
      -- {u} = u since 0 ≤ u < 1
      rw [fract_of_nonneg_lt_one' u (by linarith) hu_lt1]
      -- (αu+m)/β ∈ [1, 2) since u > u₀ = (β-m)/α
      have hx_ge1 : 1 ≤ ((α : ℝ) * u + (m : ℝ)) / (β : ℝ) := by
        rw [le_div_iff₀ hβ_pos]
        have : (α : ℝ) * u₀ = (β : ℝ) - (m : ℝ) := by
          show (α : ℝ) * (((β : ℝ) - (m : ℝ)) / (α : ℝ)) = _
          rw [mul_div_cancel₀ _ (ne_of_gt hα_pos)]
        nlinarith
      have hx_lt2 : ((α : ℝ) * u + (m : ℝ)) / (β : ℝ) < 2 := by
        rw [div_lt_iff₀ hβ_pos]
        have : (m : ℝ) + (α : ℝ) < 2 * (β : ℝ) := by exact_mod_cast hm_bound_lt2
        nlinarith
      rw [fract_ge1 _ hx_ge1 hx_lt2]
    -- Integrability (bounded measurable × bounded measurable on compact)
    have hint_ig : ∀ (a b : ℝ), IntervalIntegrable
        (fun u => (Int.fract (((α : ℝ) * u + (m : ℝ)) / (β : ℝ)) - 1/2) * (Int.fract u - 1/2))
        volume a b := by
      intro a b
      have hmeas : AEStronglyMeasurable
          (fun u => (Int.fract (((α : ℝ) * u + (m : ℝ)) / (β : ℝ)) - 1/2) * (Int.fract u - 1/2))
          volume := by
        exact ((measurable_fract.comp ((measurable_const.mul measurable_id).add
            measurable_const |>.div_const _)).sub measurable_const |>.mul
            (measurable_fract.sub measurable_const)).aestronglyMeasurable
      have hbound : ∀ u : ℝ,
          ‖(Int.fract (((α : ℝ) * u + (m : ℝ)) / (β : ℝ)) - 1/2) * (Int.fract u - 1/2)‖ ≤ 1 := by
        intro u; simp only [norm_mul, Real.norm_eq_abs]
        have h1 : |Int.fract (((α : ℝ) * u + (m : ℝ)) / (β : ℝ)) - 1/2| ≤ 1/2 := by
          rw [abs_le]; constructor
          · linarith [Int.fract_nonneg (((α : ℝ) * u + (m : ℝ)) / (β : ℝ))]
          · linarith [Int.fract_lt_one (((α : ℝ) * u + (m : ℝ)) / (β : ℝ))]
        have h2 : |Int.fract u - 1/2| ≤ 1/2 := by
          rw [abs_le]; constructor
          · linarith [Int.fract_nonneg u]
          · linarith [Int.fract_lt_one u]
        calc |Int.fract _ - 1/2| * |Int.fract u - 1/2| ≤ (1/2) * (1/2) :=
              mul_le_mul h1 h2 (abs_nonneg _) (by linarith)
          _ ≤ 1 := by norm_num
      constructor <;> exact Measure.integrableOn_of_bounded measure_Ioc_lt_top.ne hmeas
        (by filter_upwards with u; exact hbound u)
    have hint_poly : ∀ (a b : ℝ), IntervalIntegrable
        (fun u => (((α : ℝ) * u + (m : ℝ)) / (β : ℝ) - 1/2) * (u - 1/2))
        volume a b := by
      intro a b; apply ContinuousOn.intervalIntegrable; fun_prop
    have hint_lin : ∀ (a b : ℝ), IntervalIntegrable (fun u => u - (1:ℝ)/2) volume a b := by
      intro a b; apply ContinuousOn.intervalIntegrable; fun_prop
    -- Split ∫₀¹ = ∫₀^{u₀} + ∫_{u₀}¹
    rw [(intervalIntegral.integral_add_adjacent_intervals (hint_ig 0 u₀) (hint_ig u₀ 1)).symm,
        h_int1, h_int2]
    -- Now: β⁻¹ • (∫₀^{u₀} poly + ∫_{u₀}¹ (x-1-1/2)(u-1/2))
    -- Ring: (x-1-1/2)(u-1/2) = (x-1/2)(u-1/2) - (u-1/2)
    simp_rw [show ∀ u : ℝ,
        (((α : ℝ) * u + (m : ℝ)) / (β : ℝ) - 1 - 1/2) * (u - 1/2) =
        (((α : ℝ) * u + (m : ℝ)) / (β : ℝ) - 1/2) * (u - 1/2) - (u - 1/2) from fun u => by ring]
    -- Split ∫_{u₀}¹ (f - g) = ∫_{u₀}¹ f - ∫_{u₀}¹ g
    rw [intervalIntegral.integral_sub (hint_poly u₀ 1) (hint_lin u₀ 1)]
    -- Recombine: ∫₀^{u₀} f + (∫_{u₀}¹ f - ∫_{u₀}¹ g) = (∫₀^{u₀} f + ∫_{u₀}¹ f) - ∫_{u₀}¹ g
    -- = ∫₀¹ f - ∫_{u₀}¹ g
    rw [show (∫ u in (0:ℝ)..u₀, (((α : ℝ) * u + (m : ℝ)) / (β : ℝ) - 1/2) * (u - 1/2)) +
        ((∫ u in u₀..1, (((α : ℝ) * u + (m : ℝ)) / (β : ℝ) - 1/2) * (u - 1/2)) -
         (∫ u in u₀..1, u - 1/2)) =
        ((∫ u in (0:ℝ)..u₀, (((α : ℝ) * u + (m : ℝ)) / (β : ℝ) - 1/2) * (u - 1/2)) +
         (∫ u in u₀..1, (((α : ℝ) * u + (m : ℝ)) / (β : ℝ) - 1/2) * (u - 1/2))) -
        (∫ u in u₀..1, u - 1/2) from by ring,
        intervalIntegral.integral_add_adjacent_intervals (hint_poly 0 u₀) (hint_poly u₀ 1)]
    -- Apply poly_integral: ∫₀¹ poly = α/(12β)
    simp_rw [show ∀ u : ℝ,
        (((α : ℝ) * u + (m : ℝ)) / (β : ℝ) - 1/2) * (u - 1/2) =
        ((α : ℝ) * u + (m : ℝ)) / (β : ℝ) * (u - 1/2) - 1/2 * (u - 1/2) from fun u => by ring]
    rw [poly_integral α β (m : ℝ) hβ]
    -- Apply case2_correction: ∫_{u₀}¹ (u-1/2) = r(α-r)/(2α²)
    have h_corr : ∫ u in u₀..1, (u - 1/2 : ℝ) =
        ((β : ℝ) - (m : ℝ)) * ((α : ℝ) - ((β : ℝ) - (m : ℝ))) / (2 * (α : ℝ)^2) := by
      show ∫ u in ((β : ℝ) - (m : ℝ)) / (α : ℝ)..1, (u - 1/2 : ℝ) = _
      exact case2_correction α β m hα hβ hαβ hm_lo (Nat.mod_lt _ (by omega))
    rw [h_corr]
    -- Final algebra: β⁻¹ • (α/(12β) - r(α-r)/(2α²)) = α/(12β²) - r(α-r)/(2α²β)
    -- where r = β - m = β - α*k%β, and the RHS uses (β - α*k%β : ℤ) cast
    rw [smul_eq_mul]
    -- Now need: (β⁻¹) * (α/(12β) - (β-m)(α-(β-m))/(2α²)) = α/(12β²) - cast · cast / (2α²β)
    -- The cast issue: RHS has (↑(↑β - ↑α * ↑k % ↑β) : ℝ) which is ((β - m : ℤ) : ℝ)
    -- since m = α*k%β. And (β : ℝ) - (m : ℝ) = ((β - m : ℤ) : ℝ).
    -- Similarly for (α : ℝ) - ((β - m : ℤ) : ℝ)
    have hm_eq : (m : ℕ) = α * k % β := rfl
    -- β - m as Int cast
    have h_bm : ((β : ℤ) - (↑(α * k % β) : ℤ) : ℤ) = ((β : ℤ) - (m : ℤ)) := by rfl
    -- Push casts and simplify
    push_cast [hm_eq]
    have hα_ne : (α : ℝ) ≠ 0 := ne_of_gt hα_pos
    -- Normalize: (↑(α * k % β) : ℝ) = (↑(↑α * ↑k % ↑β) : ℝ) where inner ↑ is Nat→Int
    have hmod_cast : ((α * k % β : ℕ) : ℝ) = (((α : ℤ) * (k : ℤ) % (β : ℤ) : ℤ) : ℝ) := by push_cast; rfl
    rw [hmod_cast]
    field_simp
  · -- Case 1: m ≤ β-α (no floor jump)
    simp only [hcase, if_false, sub_zero]
    have hm_bound : (m : ℤ) + (α : ℤ) ≤ (β : ℤ) := by omega
    have hm_le : (m : ℕ) ≤ β - α := by omega
    -- ae rewrite fract → identity (except at u=1, measure zero)
    have h_int_eq : ∫ u in (0:ℝ)..1,
        (Int.fract (((α : ℝ) * u + (m : ℝ)) / (β : ℝ)) - 1/2) * (Int.fract u - 1/2) =
        ∫ u in (0:ℝ)..1,
        (((α : ℝ) * u + (m : ℝ)) / (β : ℝ) - 1/2) * (u - 1/2) := by
      apply intervalIntegral.integral_congr_ae
      filter_upwards [ae_ne_one] with u hne hu
      rw [Set.uIoc_of_le (by norm_num : (0:ℝ) ≤ 1)] at hu
      have hlt1 : u < 1 := lt_of_le_of_ne hu.2 hne
      have hu_nn : (0 : ℝ) ≤ u := le_of_lt hu.1
      rw [fract_of_nonneg_lt_one' u hu_nn hlt1]
      have hnn : (0 : ℝ) ≤ ((α : ℝ) * u + (m : ℝ)) / (β : ℝ) := by
        apply div_nonneg _ (le_of_lt hβ_pos)
        have : (0 : ℝ) ≤ (α : ℝ) * u := mul_nonneg (Nat.cast_nonneg _) hu_nn
        have : (0 : ℝ) ≤ (m : ℝ) := Nat.cast_nonneg _
        linarith
      have hlt : ((α : ℝ) * u + (m : ℝ)) / (β : ℝ) < 1 := by
        rw [div_lt_one hβ_pos]
        have : (α : ℝ) * u < (α : ℝ) := by
          exact mul_lt_of_lt_one_right (show (0:ℝ) < (α : ℝ) from hα_pos) hlt1
        have : (m : ℝ) + (α : ℝ) ≤ (β : ℝ) := by exact_mod_cast hm_bound
        linarith
      rw [fract_of_nonneg_lt_one' _ hnn hlt]
    rw [h_int_eq]
    simp_rw [show ∀ u : ℝ,
        (((α : ℝ) * u + (m : ℝ)) / (β : ℝ) - 1/2) * (u - 1/2) =
        ((α : ℝ) * u + (m : ℝ)) / (β : ℝ) * (u - 1/2) - 1/2 * (u - 1/2) from fun u => by ring]
    rw [case1_integral α β m hα hβ hαβ hm_le, smul_eq_mul]
    field_simp

-- ═══════════════════════════════════════════════
-- Layer 3-4: Sum algebra
-- ═══════════════════════════════════════════════

private lemma leading_sum (α β : ℕ) (hβ : 1 ≤ β) :
    ∑ _k ∈ Finset.range β, (α : ℝ) / (12 * (β : ℝ)^2) =
    (α : ℝ) / (12 * (β : ℝ)) := by
  rw [Finset.sum_const, Finset.card_range, nsmul_eq_mul]
  have hβ_pos : (0 : ℝ) < (β : ℝ) := Nat.cast_pos.mpr (by omega)
  field_simp
-- CRT helpers for correction_sum
private lemma mul_mod_injective (α β : ℕ) (_hβ : 1 ≤ β) (hcop : Nat.Coprime α β) :
    ∀ k₁ ∈ Finset.range β, ∀ k₂ ∈ Finset.range β,
      α * k₁ % β = α * k₂ % β → k₁ = k₂ := by
  intro k₁ hk₁ k₂ hk₂ h
  haveI : NeZero β := ⟨by omega⟩
  have hαu : IsUnit ((α : ZMod β)) := by
    rw [ZMod.isUnit_iff_coprime]; exact hcop
  have h_zmod : ((α * k₁ : ℕ) : ZMod β) = ((α * k₂ : ℕ) : ZMod β) := by
    rw [ZMod.natCast_eq_natCast_iff']; exact h
  push_cast at h_zmod
  have h_eq : (k₁ : ZMod β) = (k₂ : ZMod β) := hαu.mul_left_cancel h_zmod
  rwa [ZMod.natCast_eq_natCast_iff', Nat.mod_eq_of_lt (Finset.mem_range.mp hk₁),
    Nat.mod_eq_of_lt (Finset.mem_range.mp hk₂)] at h_eq

private lemma sum_reindex (α β : ℕ) (hβ : 1 ≤ β) (hcop : Nat.Coprime α β)
    (f : ℕ → ℝ) :
    ∑ k ∈ Finset.range β, f (α * k % β) =
    ∑ m ∈ Finset.range β, f m := by
  apply Finset.sum_nbij (fun k => α * k % β)
  · intro k _; exact Finset.mem_range.mpr (Nat.mod_lt _ (by omega))
  · exact mul_mod_injective α β hβ hcop
  · intro m hm
    haveI : NeZero β := ⟨by omega⟩
    have hαu : IsUnit ((α : ZMod β)) := by
      rw [ZMod.isUnit_iff_coprime]; exact hcop
    obtain ⟨u, hu⟩ := hαu
    use ((m : ZMod β) * ↑u⁻¹).val
    refine ⟨Finset.mem_range.mpr (ZMod.val_lt _), ?_⟩
    have : ((α * ((m : ZMod β) * ↑u⁻¹).val : ℕ) : ZMod β) = (m : ZMod β) := by
      push_cast; rw [ZMod.natCast_zmod_val, mul_comm (α : ZMod β), mul_assoc, ← hu]; simp
    rwa [ZMod.natCast_eq_natCast_iff', Nat.mod_eq_of_lt (Finset.mem_range.mp hm)] at this
  · intro _ _; rfl

-- Direct sum evaluation (after CRT reindexing)
private lemma correction_sum_direct (α β : ℕ) (hα : 1 ≤ α) (_hβ : 1 ≤ β) (hαβ : α < β) :
    ∑ m ∈ Finset.range β,
      (if (β - α : ℤ) < ((m : ℕ) : ℤ) then
        ((β - m : ℤ) : ℝ) * ((α : ℝ) - ((β - m : ℤ) : ℝ)) /
          (2 * (α : ℝ)^2 * (β : ℝ))
      else 0) =
    ((α : ℝ)^2 - 1) / (12 * (α : ℝ) * (β : ℝ)) := by
  -- Use calc with clean intermediate
  calc ∑ m ∈ Finset.range β,
        (if (β - α : ℤ) < ((m : ℕ) : ℤ) then
          ((β - m : ℤ) : ℝ) * ((α : ℝ) - ((β - m : ℤ) : ℝ)) /
            (2 * (α : ℝ)^2 * (β : ℝ))
        else 0)
      = ∑ r ∈ Finset.range (α - 1),
          ((r : ℝ) + 1) * ((α : ℝ) - ((r : ℝ) + 1)) /
            (2 * (α : ℝ)^2 * (β : ℝ)) := by
        -- Convert if to filter, then reparametrize
        have hcond : ∀ m, ((β - α : ℤ) < ((m : ℕ) : ℤ)) = (β - α < m) := by
          intro m; exact propext ⟨fun h => by omega, fun h => by omega⟩
        simp_rw [hcond]
        rw [← Finset.sum_filter]
        apply Finset.sum_nbij' (fun m => β - 1 - m) (fun r => β - 1 - r)
        · intro m hm
          simp only [Finset.mem_filter, Finset.mem_range] at hm
          rw [Finset.mem_range]; omega
        · intro r hr
          have hr' := Finset.mem_range.mp hr
          simp only [Finset.mem_filter, Finset.mem_range]
          exact ⟨by omega, by omega⟩
        · intro m hm
          simp only [Finset.mem_filter, Finset.mem_range] at hm; omega
        · intro r hr
          have hr' := Finset.mem_range.mp hr; omega
        · intro m hm
          simp only [Finset.mem_filter, Finset.mem_range] at hm
          have hcast : ((β : ℤ) - (m : ℤ)) = ((β - 1 - m : ℕ) : ℤ) + 1 := by omega
          congr 1; congr 1
          · exact_mod_cast hcast
          · exact_mod_cast congrArg (fun x => (α : ℤ) - x) hcast
    _ = ((α : ℝ)^2 - 1) / (12 * (α : ℝ) * (β : ℝ)) := by
        rw [← Finset.sum_div, sum_r_times_complement α hα]
        have hα_pos : (0 : ℝ) < (α : ℝ) := Nat.cast_pos.mpr (by omega)
        have hβ_pos : (0 : ℝ) < (β : ℝ) := Nat.cast_pos.mpr (by omega)
        field_simp; ring

private lemma correction_sum (α β : ℕ) (hα : 1 ≤ α) (hβ : 1 ≤ β)
    (hαβ : α < β) (hcop : Nat.Coprime α β) :
    ∑ k ∈ Finset.range β,
      (if (β - α : ℤ) < ((α * k % β : ℕ) : ℤ) then
        ((β - α * k % β : ℤ) : ℝ) * ((α : ℝ) - ((β - α * k % β : ℤ) : ℝ)) /
          (2 * (α : ℝ)^2 * (β : ℝ))
      else 0) =
    ((α : ℝ)^2 - 1) / (12 * (α : ℝ) * (β : ℝ)) := by
  -- Define f so that the summand = f(α*k%β)
  set f : ℕ → ℝ := fun m =>
    if (β - α : ℤ) < ((m : ℕ) : ℤ) then
      ((β - m : ℤ) : ℝ) * ((α : ℝ) - ((β - m : ℤ) : ℝ)) /
        (2 * (α : ℝ)^2 * (β : ℝ))
    else 0
  -- The summand equals f(α*k%β)
  have hf : ∀ k ∈ Finset.range β,
      (if (β - α : ℤ) < ((α * k % β : ℕ) : ℤ) then
        ((β - α * k % β : ℤ) : ℝ) * ((α : ℝ) - ((β - α * k % β : ℤ) : ℝ)) /
          (2 * (α : ℝ)^2 * (β : ℝ))
      else 0) = f (α * k % β) := by
    intro k _; rfl
  rw [Finset.sum_congr rfl hf]
  -- Step 1: Σ_k f(α*k%β) = Σ_m f(m) by CRT
  rw [sum_reindex α β hβ hcop]
  -- Step 2: Σ_m f(m) = correction_sum_direct
  exact correction_sum_direct α β hα hβ hαβ

-- ═══════════════════════════════════════════════
-- Main theorem assembly
-- ═══════════════════════════════════════════════

/-- **MAIN**: ∫₀¹ ({αt}-½)({βt}-½) dt = 1/(12αβ) for coprime α < β.
    Proof: split by β-periodicity, evaluate each piece, sum. -/
theorem cross_product_coprime_lt (α β : ℕ) (hα : 1 ≤ α) (hβ : 1 ≤ β)
    (hαβ : α < β) (hcop : Nat.Coprime α β) :
    ∫ t in (0:ℝ)..1, (Int.fract ((α : ℝ) * t) - 1/2) *
                      (Int.fract ((β : ℝ) * t) - 1/2) =
    1 / (12 * ((α : ℝ) * (β : ℝ))) := by
  rw [cross_split α β hβ]
  rw [Finset.sum_congr rfl (fun k hk =>
    piece_integral α β k hα hβ hαβ (Finset.mem_range.mp hk) hcop)]
  rw [Finset.sum_sub_distrib, leading_sum α β hβ, correction_sum α β hα hβ hαβ hcop]
  -- Pure algebra: α/(12β) - (α²-1)/(12αβ) = 1/(12αβ)
  have hα_pos : (0 : ℝ) < (α : ℝ) := Nat.cast_pos.mpr (by omega)
  have hβ_pos : (0 : ℝ) < (β : ℝ) := Nat.cast_pos.mpr (by omega)
  field_simp; ring

/-- Symmetric case: same formula for α > β. -/
theorem cross_product_coprime_gt (α β : ℕ) (hα : 1 ≤ α) (hβ : 1 ≤ β)
    (hαβ : β < α) (hcop : Nat.Coprime α β) :
    ∫ t in (0:ℝ)..1, (Int.fract ((α : ℝ) * t) - 1/2) *
                      (Int.fract ((β : ℝ) * t) - 1/2) =
    1 / (12 * ((α : ℝ) * (β : ℝ))) := by
  -- By commutativity of multiplication and symmetry of coprimality
  have h_comm : ∀ s : ℝ, (Int.fract ((α : ℝ) * s) - 1/2) *
      (Int.fract ((β : ℝ) * s) - 1/2) =
    (Int.fract ((β : ℝ) * s) - 1/2) * (Int.fract ((α : ℝ) * s) - 1/2) := by
    intro s; ring
  simp_rw [h_comm]
  rw [show (α : ℝ) * (β : ℝ) = (β : ℝ) * (α : ℝ) from mul_comm _ _]
  exact cross_product_coprime_lt β α hβ hα hαβ hcop.symm

/-- **FULL COPRIME THEOREM**: covers both α < β and β < α. -/
theorem cross_product_coprime' (α β : ℕ) (hα : 1 ≤ α) (hβ : 1 ≤ β)
    (hne : α ≠ β) (hcop : Nat.Coprime α β) :
    ∫ t in (0:ℝ)..1, (Int.fract ((α : ℝ) * t) - 1/2) *
                      (Int.fract ((β : ℝ) * t) - 1/2) =
    1 / (12 * ((α : ℝ) * (β : ℝ))) := by
  rcases Nat.lt_or_gt_of_ne hne with h | h
  · exact cross_product_coprime_lt α β hα hβ h hcop
  · exact cross_product_coprime_gt α β hα hβ h hcop

end
