/-
  Cathedral/Scratch/SoftProbe.lean

  PROBE A: "Soft" approach to gram_entry_offdiag_upper.

  Strategy: Use the substitution identity + periodic integral formula
  to represent gramEntry as a WEIGHTED periodic integral, then bound
  the correction from the weight.

  Key steps tested here:
  1. ∫₀¹ t · {nt} dt = (3n+1)/(12n)  [piece-by-piece]
  2. fract_mul_add_nat from GramOffDiag  [periodicity: {j(n+t)} = {jt}]
  3. gramEntry as weighted sum of periodic pieces
  4. Covariance bound via the weight correction
-/

import Cathedral.GramOffDiag
import Cathedral.GramBounds

set_option maxHeartbeats 800000

noncomputable section
open Real MeasureTheory Set Finset

-- ═══════════════════════════════════════════════
-- PROBE 1: Piece integral ∫_{m/n}^{(m+1)/n} t·(nt-m) dt = (3m+2)/(6n²)
-- ═══════════════════════════════════════════════

/-- The polynomial antiderivative for t·(nt-m) = nt²-mt. -/
private lemma antideriv_piece (n m : ℕ) (x : ℝ) (hx : x ≠ 0 ∨ True) :
    HasDerivAt (fun t => (n : ℝ) * t^3 / 3 - (m : ℝ) * t^2 / 2)
      (x * ((n : ℝ) * x - (m : ℝ))) x := by
  have h1 := (hasDerivAt_pow 3 x).const_mul (n : ℝ)
  have h2 := (hasDerivAt_pow 2 x).const_mul (m : ℝ)
  convert (h1.div_const 3).sub (h2.div_const 2) using 1
  ring

/-- Piece integral computation:
    ∫_{m/n}^{(m+1)/n} t·(nt-m) dt = (3m+2)/(6n²). -/
lemma piece_cross_integral (n : ℕ) (m : ℕ) (hn : 1 ≤ n) (hm : m < n) :
    ∫ t in ((m : ℝ) / (n : ℝ))..((↑m + 1) / (n : ℝ)),
      t * ((n : ℝ) * t - (m : ℝ)) = (3 * (m : ℝ) + 2) / (6 * (n : ℝ)^2) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hle : (m : ℝ) / (n : ℝ) ≤ ((m : ℝ) + 1) / (n : ℝ) := by
    apply div_le_div_of_nonneg_right _ (le_of_lt hn_pos); linarith
  have hcont : ContinuousOn (fun t => t * ((n : ℝ) * t - (m : ℝ)))
      (Set.uIcc ((m : ℝ)/(n : ℝ)) (((m : ℝ)+1)/(n : ℝ))) :=
    ContinuousOn.mul continuousOn_id
      ((continuousOn_const.mul continuousOn_id).sub continuousOn_const)
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt
    (fun x _ => antideriv_piece n m x (Or.inr trivial))
    hcont.intervalIntegrable]
  -- Now simplify the evaluation: F((m+1)/n) - F(m/n)
  field_simp
  ring

-- ═══════════════════════════════════════════════
-- PROBE 2: Sum over pieces → ∫₀¹ t·{nt} = (3n+1)/(12n)
-- ═══════════════════════════════════════════════

/-- On (m/n, (m+1)/n), {nt} = nt - m. Note: strict inequality on right needed. -/
lemma fract_nat_mul_on_piece (n : ℕ) (m : ℕ) (hn : 1 ≤ n) (hm : m < n)
    (t : ℝ) (ht_lo : (m : ℝ) / (n : ℝ) < t) (ht_hi : t < ((m : ℝ) + 1) / (n : ℝ)) :
    Int.fract ((n : ℝ) * t) = (n : ℝ) * t - (m : ℝ) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  unfold Int.fract
  have hfloor : ⌊(n : ℝ) * t⌋ = (m : ℤ) := by
    rw [Int.floor_eq_iff]
    constructor
    · rw [Int.cast_natCast]
      nlinarith [mul_div_cancel₀ (m : ℝ) (ne_of_gt hn_pos)]
    · rw [Int.cast_natCast]
      have := mul_div_cancel₀ ((m : ℝ) + 1) (ne_of_gt hn_pos)
      push_cast; nlinarith
  rw [hfloor, Int.cast_natCast]

/-- ∫₀¹ t·{nt} dt = (3n+1)/(12n) for n ≥ 1.
    This is the base case for the periodic integral formula.
    Proof: Split [0,1] into n equal pieces using the breakpoints m/n.
    On each piece, {nt} = nt - m, so the integral reduces to piece_cross_integral.
    Sum the results: Σ_{m=0}^{n-1} (3m+2)/(6n²) = (3n+1)/(12n). -/
theorem fract_linear_integral (n : ℕ) (hn : 1 ≤ n) :
    ∫ t in (0:ℝ)..1, t * Int.fract ((n : ℝ) * t) = (3 * (n : ℝ) + 1) / (12 * (n : ℝ)) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  -- Step 1: Split [0,1] into n pieces and use ae replacement
  -- On each piece (m/n, (m+1)/n), {nt} = nt - m a.e.
  -- So t·{nt} = t·(nt - m) a.e. on each piece.
  -- Step 2: The integral over each piece equals the polynomial piece integral.
  -- Step 3: Sum gives Σ (3m+2)/(6n²).
  -- Step 4: Arithmetic: Σ_{m=0}^{n-1} (3m+2) = 3·n(n-1)/2 + 2n = n(3n+1)/2.
  -- So total = n(3n+1)/2 / (6n²) = (3n+1)/(12n).

  -- For now, we build the telescoping structure:
  -- ∫₀¹ = Σ_{m=0}^{n-1} ∫_{m/n}^{(m+1)/n}
  -- Each piece: ae congr gives ∫ t·{nt} = ∫ t·(nt-m) = piece_cross_integral
  sorry -- Needs: intervalIntegral.sum_integral_adjacent_intervals + ae congr

-- ═══════════════════════════════════════════════
-- PROBE 3: Periodicity decomposition for gramEntry
-- ═══════════════════════════════════════════════

/-- Key identity: gramEntry(j,k) = Σ_{n≥1} ∫₀¹ {js}{ks}/(n+s)² ds.

    Proof outline:
    - gramEntry = ∫₀¹ {j/x}{k/x} dx
    - Substitute u = 1/x: = ∫₁^∞ {ju}{ku}/u² du
    - Split: = Σ_{n≥1} ∫_n^{n+1} {ju}{ku}/u² du
    - On [n,n+1), substitute s = u-n: = Σ ∫₀¹ {j(n+s)}{k(n+s)}/(n+s)² ds
    - By fract_mul_add_nat: {j(n+s)} = {js}, {k(n+s)} = {ks}
    - So = Σ ∫₀¹ {js}{ks}/(n+s)² ds -/
theorem gramEntry_as_weighted_periodic (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    gramEntry j k = ∫ s in (0:ℝ)..1,
      Int.fract ((j : ℝ) * s) * Int.fract ((k : ℝ) * s) *
      (∑' n : ℕ, 1 / ((↑n + 1 + s)^2)) := by
  sorry -- Requires: substitution + Fubini + periodicity

-- ═══════════════════════════════════════════════
-- PROBE 4: The weight function properties
-- ═══════════════════════════════════════════════

/-- W(s) = Σ_{n≥0} 1/(n+1+s)² is positive for s ∈ [0,1]. -/
lemma hurwitz_weight_pos (s : ℝ) (hs : 0 ≤ s) :
    0 < ∑' n : ℕ, 1 / ((↑n + 1 + s)^2) := by
  sorry -- Need summability + le_tsum

/-- ∫₀¹ W(s) ds = 1.
    This is the KEY property that makes the mean extraction work.
    Proof: ∫₀¹ Σ 1/(n+1+s)² ds = Σ ∫₀¹ 1/(n+1+s)² ds
         = Σ [1/(n+1) - 1/(n+2)] = 1 (telescope). -/
theorem hurwitz_weight_integral_eq_one :
    ∫ s in (0:ℝ)..1, ∑' n : ℕ, 1 / ((↑n + 1 + s)^2) = 1 := by
  sorry -- Requires: interchange sum/integral + telescoping

-- ═══════════════════════════════════════════════
-- PROBE 5: The periodic integral formula
-- ═══════════════════════════════════════════════

/-- For α = 1: ∫₀¹ {t}·{βt} dt = (3β+1)/(12β) = 1/4 + 1/(12β). -/
theorem periodic_integral_alpha_one (β : ℕ) (hβ : 1 ≤ β) :
    ∫ t in (0:ℝ)..1, Int.fract t * Int.fract ((β : ℝ) * t) =
    (3 * (β : ℝ) + 1) / (12 * (β : ℝ)) := by
  -- {t} = t for t ∈ [0,1), so this reduces to fract_linear_integral
  sorry

/-- General coprime case: ∫₀¹ {αt}·{βt} dt = 1/4 + 1/(12αβ).
    For coprime α, β with α,β ≥ 1. -/
theorem periodic_integral_coprime (α β : ℕ) (hα : 1 ≤ α) (hβ : 1 ≤ β)
    (hcoprime : Nat.Coprime α β) :
    ∫ t in (0:ℝ)..1, Int.fract ((α : ℝ) * t) * Int.fract ((β : ℝ) * t) =
    1 / 4 + 1 / (12 * (α : ℝ) * (β : ℝ)) := by
  sorry -- Full proof: decompose into αβ sub-intervals, compute each, sum

/-- General case: ∫₀¹ {as}·{bs} ds = 1/4 + gcd(a,b)²/(12ab). -/
theorem periodic_integral_general (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b) :
    ∫ s in (0:ℝ)..1, Int.fract ((a : ℝ) * s) * Int.fract ((b : ℝ) * s) =
    1 / 4 + (Nat.gcd a b : ℝ)^2 / (12 * (a : ℝ) * (b : ℝ)) := by
  -- Reduce to coprime: a = g·α, b = g·β, substitute t = g·s
  sorry

-- ═══════════════════════════════════════════════
-- PROBE 6: Soft bound via weight correction
-- ═══════════════════════════════════════════════

/-- If gramEntry = ∫F·W with ∫F = 1/4 + g²/(12jk) and ∫W = 1,
    then gramEntry = 1/4 + g²/(12jk) + ∫F·(W-1).
    The correction ∫F·(W-1) can be bounded using the variation of W
    and the periodicity of F (period 1/g).

    For g periods of F in [0,1], the Riemann-sum approximation
    gives |∫F·(W-1)| ≤ C·‖W'‖_∞/(g) · ∫|F|.

    Concretely: |correction| ≤ C/g for some universal C.
    Combined: gramEntry ≤ 1/4 + g²/(12jk) + C/g.

    For this to give gramEntry ≤ 1/4 + g/(jk),
    we need g²/(12jk) + C/g ≤ g/(jk).
    i.e., C ≤ g²(12-g)/(12jk) · g.  Not clear this closes for g=1... -/
theorem soft_correction_bound (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hjk : j ≠ k)
    (h_big : 12 < j * k) :
    gramEntry j k ≤ 1 / 4 + (Nat.gcd j k : ℝ) / ((j : ℝ) * (k : ℝ)) := by
  -- This is the HARD case. The soft approach may not close.
  -- We need to bound: |∫₀¹ {js}{ks}·(W-1)| ≤ g/(jk) - g²/(12jk) = g(12-g)/(12jk).
  sorry

-- ═══════════════════════════════════════════════
-- ASSEMBLER: Full theorem using case split
-- ═══════════════════════════════════════════════

theorem gram_entry_offdiag_upper_soft (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) (hjk : j ≠ k) :
    gramEntry j k ≤ 1 / 4 + (Nat.gcd j k : ℝ) / ((j : ℝ) * (k : ℝ)) := by
  by_cases h_small : j * k ≤ 12
  · -- Already proved case
    have h1 := gram_entry_offdiag_upper_all j k hj hk h_small
    have hgcd_ge : (1 : ℝ) ≤ (Nat.gcd j k : ℝ) :=
      Nat.one_le_cast.mpr (Nat.one_le_iff_ne_zero.mpr (Nat.gcd_ne_zero_left (by omega)))
    have hjk_pos : (0 : ℝ) < (j : ℝ) * (k : ℝ) :=
      mul_pos (Nat.cast_pos.mpr (by omega)) (Nat.cast_pos.mpr (by omega))
    linarith [div_le_div_of_nonneg_right hgcd_ge (le_of_lt hjk_pos)]
  · push_neg at h_small
    exact soft_correction_bound j k hj hk hjk h_small

end
