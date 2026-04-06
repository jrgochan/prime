/-
  Cathedral/Scratch/RunningAvg.lean

  Running average bound for coprime Bernoulli cross products.

  GOAL: For coprime α < β with α,β ≥ 1:
    max_{c∈[0,1]} |∫₀ᶜ ({αu}-½)({βu}-½) du - c/(12αβ)| ≤ 1/(4β)

  Strategy:
    1. At breakpoints K/β: use exact piece integrals from CoprimeCross
       Ψ(K/β) = K·α/(12β²) - partial_correction_sum - K/(12αβ)
    2. Between breakpoints: |change| ≤ 1/(4β) (crude bound)
    3. Bound the partial correction sums using non-negativity

  The partial correction sums satisfy 0 ≤ Σ_{i<K} corr_i ≤ (α²-1)/(12αβ),
  so Ψ(K/β) = K(α²-β²)/(12αβ²) - ... which is bounded by 1/(4β).
-/

import Cathedral.Scratch.CoprimeCross
import Cathedral.GramOffDiag

set_option maxHeartbeats 4000000
noncomputable section
open Real MeasureTheory Set Finset Int

-- ═══════════════════════════════════════════════
-- Helper: pointwise bound on Bernoulli cross product
-- ═══════════════════════════════════════════════

/-- |({αu}-½)({βu}-½)| ≤ 1/4 for all u. -/
private lemma cross_pointwise_bound (α β : ℕ) (u : ℝ) :
    |(Int.fract ((α:ℝ) * u) - 1/2) * (Int.fract ((β:ℝ) * u) - 1/2)| ≤ 1/4 := by
  rw [abs_mul]
  have h1 : |Int.fract ((α:ℝ) * u) - 1/2| ≤ 1/2 := by
    rw [abs_le]; constructor <;> linarith [Int.fract_nonneg ((α:ℝ) * u),
                                           Int.fract_lt_one ((α:ℝ) * u)]
  have h2 : |Int.fract ((β:ℝ) * u) - 1/2| ≤ 1/2 := by
    rw [abs_le]; constructor <;> linarith [Int.fract_nonneg ((β:ℝ) * u),
                                           Int.fract_lt_one ((β:ℝ) * u)]
  calc |Int.fract _ - 1/2| * |Int.fract _ - 1/2|
      ≤ (1/2) * (1/2) := mul_le_mul h1 h2 (abs_nonneg _) (by norm_num)
    _ = 1/4 := by norm_num

-- ═══════════════════════════════════════════════
-- Running integral bound between breakpoints
-- ═══════════════════════════════════════════════

/-- The running integral changes by at most 1/(4β) between consecutive breakpoints. -/
private lemma inter_breakpoint_bound (α β : ℕ) (_hα : 1 ≤ α) (hβ : 1 ≤ β)
    (c₁ c₂ : ℝ) (hc : c₁ ≤ c₂) (hlen : c₂ - c₁ ≤ 1 / (β:ℝ)) :
    |∫ u in c₁..c₂,
      (Int.fract ((α:ℝ) * u) - 1/2) * (Int.fract ((β:ℝ) * u) - 1/2)| ≤
    1 / (4 * (β:ℝ)) := by
  have hβ_pos : (0:ℝ) < (β:ℝ) := Nat.cast_pos.mpr (by omega)
  calc |∫ u in c₁..c₂, (Int.fract _ - 1/2) * (Int.fract _ - 1/2)|
      ≤ |∫ u in c₁..c₂, (1/4 : ℝ)| := by
        apply abs_le_abs_of_nonneg (by positivity)
        apply intervalIntegral.integral_mono_on hc
        · apply (intervalIntegrable_const (c := (1:ℝ))).mono_fun
          · exact ((measurable_fract.comp (measurable_const.mul measurable_id)).sub
              measurable_const).mul ((measurable_fract.comp (measurable_const.mul
              measurable_id)).sub measurable_const) |>.aestronglyMeasurable
          · filter_upwards with u
            exact le_trans (cross_pointwise_bound α β u) (by norm_num)
        · exact intervalIntegrable_const
        · intro u _; exact cross_pointwise_bound α β u
    _ = (1/4 : ℝ) * (c₂ - c₁) := by
        rw [intervalIntegral.integral_const, smul_eq_mul,
            show c₂ - c₁ = |c₂ - c₁| from (abs_of_nonneg (sub_nonneg.mpr hc)).symm]
        ring
    _ ≤ (1/4) * (1/(β:ℝ)) := by
        apply mul_le_mul_of_nonneg_left hlen; norm_num
    _ = 1 / (4 * (β:ℝ)) := by ring
  sorry -- integral comparison needs more careful measurability

-- ═══════════════════════════════════════════════
-- Running integral at breakpoints
-- ═══════════════════════════════════════════════

/-- At breakpoint K/β, the running integral equals the sum of piece integrals. -/
private lemma running_at_breakpoint (α β K : ℕ) (hα : 1 ≤ α) (hβ : 1 ≤ β)
    (hαβ : α < β) (hK : K ≤ β) (hcop : Nat.Coprime α β) :
    ∫ t in (0:ℝ)..((K:ℝ) / (β:ℝ)),
      (Int.fract ((α:ℝ) * t) - 1/2) * (Int.fract ((β:ℝ) * t) - 1/2) =
    ∑ k ∈ Finset.range K,
      ((α:ℝ) / (12 * (β:ℝ)^2) -
       (if (β - α : ℤ) < ((α * k % β : ℕ) : ℤ) then
         ((β - α * k % β : ℤ) : ℝ) * ((α : ℝ) - ((β - α * k % β : ℤ) : ℝ)) /
           (2 * (α : ℝ)^2 * (β : ℝ))
        else 0)) := by
  -- This follows from cross_telescope + piece_integral
  have h_tel := cross_telescope α β hβ (K - 1) (by omega : K - 1 < β)
  sorry

/-- The partial correction sum is non-negative. -/
private lemma partial_correction_nonneg (α β K : ℕ) (_hα : 1 ≤ α) (_hβ : 1 ≤ β)
    (_hαβ : α < β) (_hK : K ≤ β) :
    0 ≤ ∑ k ∈ Finset.range K,
      (if (β - α : ℤ) < ((α * k % β : ℕ) : ℤ) then
        ((β - α * k % β : ℤ) : ℝ) * ((α : ℝ) - ((β - α * k % β : ℤ) : ℝ)) /
          (2 * (α : ℝ)^2 * (β : ℝ))
       else 0) := by
  apply Finset.sum_nonneg
  intro k _
  split_ifs with h
  · -- correction term is r(α-r)/(2α²β) where r = β - αk%β
    -- Need 0 ≤ r and r ≤ α (from hαβ and the condition)
    have hm : α * k % β < β := Nat.mod_lt _ (by omega)
    have hr_pos : 0 < (β : ℤ) - (α * k % β : ℕ) := by omega
    have hr_le_α : (β : ℤ) - (α * k % β : ℕ) ≤ (α : ℤ) := by omega
    apply div_nonneg
    · apply mul_nonneg
      · exact_mod_cast le_of_lt hr_pos
      · have : ((β - α * k % β : ℤ) : ℝ) ≤ (α : ℝ) := by exact_mod_cast hr_le_α
        linarith
    · positivity
  · exact le_refl 0

/-- The partial correction sum is bounded by the full sum (α²-1)/(12αβ). -/
private lemma partial_correction_le_full (α β K : ℕ) (hα : 1 ≤ α) (hβ : 1 ≤ β)
    (hαβ : α < β) (hK : K ≤ β) (hcop : Nat.Coprime α β) :
    ∑ k ∈ Finset.range K,
      (if (β - α : ℤ) < ((α * k % β : ℕ) : ℤ) then
        ((β - α * k % β : ℤ) : ℝ) * ((α : ℝ) - ((β - α * k % β : ℤ) : ℝ)) /
          (2 * (α : ℝ)^2 * (β : ℝ))
       else 0) ≤
    ((α : ℝ)^2 - 1) / (12 * (α : ℝ) * (β : ℝ)) := by
  -- Partial sum ≤ full sum (since all terms ≥ 0)
  -- Full sum = (α²-1)/(12αβ) by correction_sum
  sorry

-- ═══════════════════════════════════════════════
-- Main running average bound
-- ═══════════════════════════════════════════════

/-- **MAIN**: The centered running average of the coprime Bernoulli
    cross product is bounded by 1/(4β).

    Ψ(c) = ∫₀ᶜ ({αu}-½)({βu}-½) du - c/(12αβ)
    satisfies |Ψ(c)| ≤ 1/(4β) for all c ∈ [0,1]. -/
theorem running_avg_coprime_bound (α β : ℕ) (hα : 1 ≤ α) (hβ : 1 ≤ β)
    (hαβ : α < β) (hcop : Nat.Coprime α β) (c : ℝ) (hc : c ∈ Icc (0:ℝ) 1) :
    |∫ u in (0:ℝ)..c,
      (Int.fract ((α:ℝ) * u) - 1/2) * (Int.fract ((β:ℝ) * u) - 1/2) -
      c / (12 * (α:ℝ) * (β:ℝ))| ≤ 1 / (4 * (β:ℝ)) := by
  -- Step 1: Write c = K/β + δ where K = ⌊βc⌋ and δ ∈ [0, 1/β)
  -- Step 2: At the breakpoint K/β, use running_at_breakpoint
  -- Step 3: Ψ(K/β) is bounded using partial_correction bounds
  -- Step 4: Between K/β and c, add inter_breakpoint_bound
  sorry

/-- Symmetric version for α > β. -/
theorem running_avg_coprime_bound_symm (α β : ℕ) (hα : 1 ≤ α) (hβ : 1 ≤ β)
    (hαβ : β < α) (hcop : Nat.Coprime α β) (c : ℝ) (hc : c ∈ Icc (0:ℝ) 1) :
    |∫ u in (0:ℝ)..c,
      (Int.fract ((α:ℝ) * u) - 1/2) * (Int.fract ((β:ℝ) * u) - 1/2) -
      c / (12 * (α:ℝ) * (β:ℝ))| ≤ 1 / (4 * (α:ℝ)) := by
  -- By symmetry: swap α,β in the integral, then apply running_avg_coprime_bound
  sorry

end
