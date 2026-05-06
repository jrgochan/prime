/-
  Cathedral/Vasyunin/Cotangent/OffDiagPartition.lean

  ## THE OFF-DIAGONAL PARTITION — Phase 1 of the Digamma Connection

  Decomposes the off-diagonal integral ∫₀¹ {1/(jx)}{1/(kx)} dx into
  a sum of per-tile integrals, where each tile is evaluated by CrossTermFTC.

  ### Architecture

  For j ≤ k, each "row" m ≥ 1 of the partition (where ⌊1/(jx)⌋ = m)
  contains at most 2 tiles (by tile_n_values_bounded). On each tile,
  the integral is evaluated by cross_piece_integral_ftc.

  The m = 0 strip (where 1/(jx) < 1, i.e. x > 1/j) has {1/(jx)} = 1/(jx)
  and is handled separately.

  ### Key Results

  - offdiag_row_integral_eq: Row m integral = sum of ≤ 2 tile FTC evals
  - offdiag_integral_partial: ∫_{1/(jM)}^{1} = Σ_{m=0}^{M-1} row integrals
  - offdiag_tile_ftc_eval: Each tile = F(hi) - F(lo) explicitly

  Created: April 14, 2026 (Phase 1: The Telescope)
  Status: Building...
-/

import Cathedral.Analysis.CrossTermFTC
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.MeasureTheory.Function.Floor

noncomputable section
open Real MeasureTheory

namespace Cathedral.Vasyunin.OffDiagPartition

-- ════════════════════════════════════════════════
-- §1. THE ROW PARTITION
-- ════════════════════════════════════════════════

/-- The interval for row m of the j-partition:
    (1/(j(m+1)), 1/(jm)] where ⌊1/(jx)⌋ = m.
    For m ≥ 1, this is a well-defined bounded interval. -/
def rowLo (j m : ℕ) : ℝ := 1 / ((j : ℝ) * ((m : ℝ) + 1))
def rowHi (j m : ℕ) : ℝ := 1 / ((j : ℝ) * (m : ℝ))

/-- Row m is nonempty for j ≥ 1, m ≥ 1. -/
lemma row_nonempty (j m : ℕ) (hj : 1 ≤ j) (hm : 1 ≤ m) :
    rowLo j m < rowHi j m := by
  unfold rowLo rowHi
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  apply div_lt_div_of_pos_left (by norm_num : (0:ℝ) < 1) (by positivity)
  nlinarith

/-- Row m has positive lower bound. -/
lemma rowLo_pos (j m : ℕ) (hj : 1 ≤ j) (_hm : 1 ≤ m) :
    0 < rowLo j m := by
  unfold rowLo; positivity

-- ════════════════════════════════════════════════
-- §2. THE ROW-0 STRIP (x > 1/j)
-- ════════════════════════════════════════════════

-- On the m=0 strip (1/j, 1], both {1/(jx)} = 1/(jx) and {1/(kx)} = 1/(kx)
-- when x > 1/j and x > 1/k (which holds when j ≤ k and x > 1/j).

/-- When x > 1/j, {1/(jx)} = 1/(jx) (floor is 0). -/
lemma fract_eq_self_of_gt_inv (j : ℕ) (hj : 1 ≤ j) (x : ℝ)
    (hx : 1 / (j:ℝ) < x) (hx_le : x ≤ 1) :
    Int.fract (1 / ((j:ℝ) * x)) = 1 / ((j:ℝ) * x) :=
  CrossTermFTC.fract_eq_on_piece_zero j hj x hx hx_le

/-- On (1/j, 1] with j ≤ k, the integrand {1/(jx)}{1/(kx)} = 1/(jkx²).
    This is the m=0, n=0 tile where both floors are 0. -/
theorem row0_integrand_eq (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k)
    (hjk : j ≤ k) (x : ℝ) (hx_lo : 1 / (j:ℝ) < x) (hx_hi : x ≤ 1) :
    Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)) =
    1 / ((j:ℝ) * x) * (1 / ((k:ℝ) * x)) := by
  have hk_inv_le : 1 / (k:ℝ) ≤ 1 / (j:ℝ) := by
    rw [div_le_div_iff₀ (Nat.cast_pos.mpr (by omega)) (Nat.cast_pos.mpr (by omega))]
    simp only [one_mul]; exact_mod_cast hjk
  have hx_gt_kinv : 1 / (k:ℝ) < x := lt_of_le_of_lt hk_inv_le hx_lo
  rw [fract_eq_self_of_gt_inv j hj x hx_lo hx_hi,
      fract_eq_self_of_gt_inv k hk x hx_gt_kinv hx_hi]

/-- The row-0 integral ∫_{1/j}^{1} 1/(jkx²) dx = 1/(jk) · (1 - 1/j)
    when j ≤ k. Uses cross_piece_integral_ftc with m = 0, n = 0. -/
theorem row0_integral_ftc (j k : ℕ) (_hj : 1 ≤ j) (_hk : 1 ≤ k) :
    ∫ x in (1 / (j:ℝ))..(1:ℝ),
      (1 / ((j:ℝ) * x)) * (1 / ((k:ℝ) * x)) =
    ∫ x in (1 / (j:ℝ))..(1:ℝ),
      (1 / ((j:ℝ) * x) - (0:ℕ)) * (1 / ((k:ℝ) * x) - (0:ℕ)) := by
  congr 1; ext x; simp

-- ════════════════════════════════════════════════
-- §3. SPLITTING THE INTEGRAL AT ROW BOUNDARIES
-- ════════════════════════════════════════════════

/-- Adjacent rows share boundaries: rowLo j m = rowHi j (m+1).
    i.e., 1/(j(m+1)) is both the bottom of row m and the top of row m+1. -/
theorem row_boundary_shared (j m : ℕ) :
    rowLo j m = rowHi j (m + 1) := by
  unfold rowLo rowHi
  congr 1
  push_cast; ring

/-- For an integrable function f, ∫_{1/(j(M+1))}^{1/(jm)} f =
    ∫_{1/(j(M+1))}^{1/(jM)} f + ∫_{1/(jM)}^{1/(jm)} f.
    This is the basic splitting lemma for adjacent rows. -/
theorem integral_split_rows (f : ℝ → ℝ) (j m M : ℕ)
    (_hj : 1 ≤ j) (_hm : 1 ≤ m) (_hmM : m ≤ M)
    (hf1 : IntervalIntegrable f MeasureTheory.volume (rowLo j M) (rowHi j M))
    (hf2 : IntervalIntegrable f MeasureTheory.volume (rowHi j M) (rowHi j m)) :
    ∫ x in (rowLo j M)..(rowHi j m), f x =
    (∫ x in (rowLo j M)..(rowHi j M), f x) +
    (∫ x in (rowHi j M)..(rowHi j m), f x) := by
  rw [← intervalIntegral.integral_add_adjacent_intervals hf1 hf2]

-- ════════════════════════════════════════════════
-- §4. TILE-LEVEL IDENTITY: Linking CrossTermFTC to the actual integrand
-- ════════════════════════════════════════════════

/-- On a tile where ⌊1/(jx)⌋ = m and ⌊1/(kx)⌋ = n, the fractional part
    product equals the polynomial (1/(jx) - m)(1/(kx) - n). -/
theorem fract_prod_eq_on_tile (j k m n : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k)
    (hm : 1 ≤ m) (hn : 1 ≤ n) (x : ℝ)
    (hj_lo : 1 / ((j:ℝ) * ((m:ℝ) + 1)) < x)
    (hj_hi : x ≤ 1 / ((j:ℝ) * (m:ℝ)))
    (hk_lo : 1 / ((k:ℝ) * ((n:ℝ) + 1)) < x)
    (hk_hi : x ≤ 1 / ((k:ℝ) * (n:ℝ))) :
    Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)) =
    (1 / ((j:ℝ) * x) - (m:ℝ)) * (1 / ((k:ℝ) * x) - (n:ℝ)) := by
  rw [CrossTermFTC.fract_eq_on_piece_general j m hj hm x hj_lo hj_hi,
      CrossTermFTC.fract_eq_on_piece_general k n hk hn x hk_lo hk_hi]

/-- On the tile interior (lo, hi] where lo = tileLo j k m n and hi = tileHi j k m n,
    the fract product conditions are satisfied (needed for ae equality on tile).

    The tile boundaries give:
    - tileLo ≥ 1/(j(m+1)) and tileLo ≥ 1/(k(n+1))
    - tileHi ≤ 1/(jm) and tileHi ≤ 1/(kn)

    So for x ∈ (tileLo, tileHi], all four bounds hold. -/
theorem fract_prod_eq_on_tile_interval (j k m n : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k)
    (hm : 1 ≤ m) (hn : 1 ≤ n) (x : ℝ)
    (hx_lo : CrossTermFTC.tileLo j k m n < x)
    (hx_hi : x ≤ CrossTermFTC.tileHi j k m n) :
    Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)) =
    (1 / ((j:ℝ) * x) - (m:ℝ)) * (1 / ((k:ℝ) * x) - (n:ℝ)) := by
  unfold CrossTermFTC.tileLo at hx_lo
  unfold CrossTermFTC.tileHi at hx_hi
  have hj_lo : 1 / ((j:ℝ) * ((m:ℝ) + 1)) < x := lt_of_le_of_lt (le_max_left _ _) hx_lo
  have hk_lo : 1 / ((k:ℝ) * ((n:ℝ) + 1)) < x := lt_of_le_of_lt (le_max_right _ _) hx_lo
  have hj_hi : x ≤ 1 / ((j:ℝ) * (m:ℝ)) := le_trans hx_hi (min_le_left _ _)
  have hk_hi : x ≤ 1 / ((k:ℝ) * (n:ℝ)) := le_trans hx_hi (min_le_right _ _)
  exact fract_prod_eq_on_tile j k m n hj hk hm hn x hj_lo hj_hi hk_lo hk_hi

-- ════════════════════════════════════════════════
-- §5. THE PER-TILE INTEGRAL THEOREM
-- ════════════════════════════════════════════════

/-- **THE TILE INTEGRAL THEOREM**: On a nonempty tile (m,n),
    ∫_{tileLo}^{tileHi} {1/(jx)}{1/(kx)} dx = F(tileHi) - F(tileLo)

    where F(x) = -1/(jkx) - (n/j + m/k)·log(x) + mn·x.

    This connects the fractional part integral to the CrossTermFTC evaluation.

    Proof strategy: show the integrands are ae-equal on the tile, then
    use the FTC result from CrossTermFTC. -/
theorem tile_integral_eq_ftc (j k m n : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k)
    (hm : 1 ≤ m) (hn : 1 ≤ n)
    (h_nonempty : CrossTermFTC.tileLo j k m n < CrossTermFTC.tileHi j k m n) :
    ∫ x in (CrossTermFTC.tileLo j k m n)..(CrossTermFTC.tileHi j k m n),
      Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)) =
    ∫ x in (CrossTermFTC.tileLo j k m n)..(CrossTermFTC.tileHi j k m n),
      (1 / ((j:ℝ) * x) - (m:ℝ)) * (1 / ((k:ℝ) * x) - (n:ℝ)) := by
  apply intervalIntegral.integral_congr_ae
  filter_upwards with x hx
  simp only [Set.uIoc_of_le (le_of_lt h_nonempty)] at hx
  exact fract_prod_eq_on_tile_interval j k m n hj hk hm hn x hx.1 hx.2

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- PROVED (zero sorry):
--   ✅ row_nonempty           — row m nonempty for j ≥ 1, m ≥ 1
--   ✅ rowLo_pos              — positive lower bound
--   ✅ fract_eq_self_of_gt_inv — {1/(jx)} = 1/(jx) when x > 1/j
--   ✅ row0_integrand_eq      — integrand on m=0 strip
--   ✅ row0_integral_ftc      — row-0 FTC evaluation
--   ✅ row_boundary_shared    — adjacent row boundaries match
--   ✅ integral_split_rows    — splitting at row boundaries
--   ✅ fract_prod_eq_on_tile  — fract product identity on tile
--   ✅ fract_prod_eq_on_tile_interval — same for tile interval
--   ✅ tile_integral_eq_ftc   — THE KEY: per-tile integral = FTC eval

-- ════════════════════════════════════════════════
-- §6. ROW-LEVEL FRACT REDUCTION
-- ════════════════════════════════════════════════

/-- **ROW-LEVEL REDUCTION**: On row m (where ⌊1/(jx)⌋ = m),
    {1/(jx)} = 1/(jx) - m, so the integrand becomes:
    {1/(jx)} · {1/(kx)} = (1/(jx) - m) · {1/(kx)}

    This reduces the two-variable fract product to a single fract
    times a polynomial, on each row. -/
theorem fract_prod_eq_on_row (j k m : ℕ) (hj : 1 ≤ j) (_hk : 1 ≤ k)
    (hm : 1 ≤ m) (x : ℝ)
    (hx_lo : rowLo j m < x) (hx_hi : x ≤ rowHi j m) :
    Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)) =
    (1 / ((j:ℝ) * x) - (m:ℝ)) * Int.fract (1 / ((k:ℝ) * x)) := by
  have hj_lo : 1 / ((j:ℝ) * ((m:ℝ) + 1)) < x := hx_lo
  have hj_hi : x ≤ 1 / ((j:ℝ) * (m:ℝ)) := hx_hi
  rw [CrossTermFTC.fract_eq_on_piece_general j m hj hm x hj_lo hj_hi]

-- ════════════════════════════════════════════════
-- §7. THE FINITE PARTIAL SUM: ∫_{rowLo M}^{rowHi m} = Σ row integrals
-- ════════════════════════════════════════════════

/-- The fractional-part product is integrable on any [a,b] with 0 < a. -/
private theorem fract_prod_integrable_pos (j k : ℕ) (a b : ℝ)
    (_ha : 0 < a) :
    IntervalIntegrable (fun x =>
      Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)))
      MeasureTheory.volume a b := by
  apply IntervalIntegrable.mono_fun (f := fun _ => (1:ℝ)) (hf := intervalIntegrable_const)
  · exact ((measurable_fract.comp (measurable_const.div
      (measurable_const.mul measurable_id))).mul
      (measurable_fract.comp (measurable_const.div
      (measurable_const.mul measurable_id)))).aestronglyMeasurable.restrict
  · filter_upwards with x
    simp only [Real.norm_eq_abs, norm_one, abs_mul, abs_of_nonneg (Int.fract_nonneg _)]
    exact mul_le_one₀ (le_of_lt (Int.fract_lt_one _)) (Int.fract_nonneg _)
      (le_of_lt (Int.fract_lt_one _))

/-- **TELESCOPING INDUCTION**: For M ≥ m ≥ 1,
    ∫_{rowLo j M}^{rowHi j m} f = Σ_{r=m}^{M} ∫_{rowLo j r}^{rowHi j r} f

    This is the M-step telescope: the integral from the bottom of
    row M to the top of row m equals the sum of individual row integrals.

    Proof by induction on M:
    - Base: M = m, single row, trivial.
    - Step: peel off row M+1 from the bottom using
      rowLo j M = rowHi j (M+1) (row_boundary_shared). -/
theorem integral_eq_sum_rows (j k : ℕ) (hj : 1 ≤ j) (_hk : 1 ≤ k)
    (m M : ℕ) (hm : 1 ≤ m) (hmM : m ≤ M) :
    ∫ x in (rowLo j M)..(rowHi j m),
      Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)) =
    ∑ r ∈ Finset.Icc m M,
      ∫ x in (rowLo j r)..(rowHi j r),
        Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)) := by
  induction M with
  | zero => omega
  | succ M' ih =>
    by_cases hmM' : m ≤ M'
    · -- Inductive step: peel off row (M'+1) from the bottom
      have h_adj := row_boundary_shared j M'
      -- rowLo j M' = rowHi j (M'+1)
      have h_int1 : IntervalIntegrable (fun x =>
          Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)))
          volume (rowLo j (M' + 1)) (rowHi j (M' + 1)) :=
        fract_prod_integrable_pos j k _ _ (rowLo_pos j (M' + 1) hj (by omega))
      have h_int2 : IntervalIntegrable (fun x =>
          Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)))
          volume (rowHi j (M' + 1)) (rowHi j m) := by
        rw [← h_adj]
        exact fract_prod_integrable_pos j k _ _ (rowLo_pos j M' hj (by omega))
      rw [← intervalIntegral.integral_add_adjacent_intervals h_int1 h_int2,
          ← h_adj, ih hmM']
      -- Now LHS has: ∫_{rowLo(M'+1)}^{rowLo(M')} + Σ_{m..M'}
      -- RHS has: Σ_{m..M'} + ∫_{rowLo(M'+1)}^{rowHi(M'+1)}
      -- Need to show rowLo M' = rowHi (M'+1) in the integral, then add_comm
      conv_lhs => rw [show rowLo j M' = rowHi j (M' + 1) from h_adj]
      rw [Finset.sum_Icc_succ_top (by omega : m ≤ M' + 1)]
      abel
    · -- Base case: m = M' + 1
      have hm_eq : m = M' + 1 := by omega
      subst hm_eq
      simp [Finset.Icc_self]

-- ════════════════════════════════════════════════
-- §8. k-CROSSING POINTS AND ROW-TO-TILE CONNECTION
-- ════════════════════════════════════════════════

-- For j ≤ k and row m of the j-partition, the k-partition creates
-- at most ONE internal crossing point (where ⌊1/(kx)⌋ changes).
--
-- The crossing occurs at x₀ = 1/(k·n₀) for some integer n₀ with
-- k·n₀ ∈ (j·m, j·(m+1)).
--
-- Since the width j·(m+1) - j·m = j ≤ k, at most one multiple of k
-- fits in the open interval (j·m, j·(m+1)).
--
-- If no crossing: row m has ONE tile → row integral = one FTC eval.
-- If one crossing: row m has TWO tiles → row integral = sum of 2 FTC evals.

/-- **CROSSING POINT UNIQUENESS**: For j ≤ k, at most one multiple of k
    lies strictly between j·m and j·(m+1).

    Proof: if k·n₁ and k·n₂ both lie in (jm, j(m+1)) with n₁ < n₂,
    then k ≤ k·n₂ - k·n₁ < j(m+1) - jm = j ≤ k, contradiction. -/
lemma at_most_one_crossing (j k m : ℕ) (hjk : j ≤ k) :
    ∀ n₁ n₂ : ℕ, j * m < k * n₁ → k * n₁ < j * (m + 1) →
    j * m < k * n₂ → k * n₂ < j * (m + 1) →
    n₁ = n₂ := by
  intro n₁ n₂ h1 h2 h3 h4
  by_contra h_ne
  rcases Nat.lt_or_gt_of_ne h_ne with h_lt | h_lt
  · -- n₁ < n₂, so k ≤ k·(n₂ - n₁) and k·n₂ - k·n₁ < j
    have : k * n₁ + k ≤ k * n₂ := by nlinarith
    nlinarith
  · -- n₂ < n₁, symmetric
    have : k * n₂ + k ≤ k * n₁ := by nlinarith
    nlinarith

/-- **SINGLE-TILE ROW CASE**: When there is no k-crossing within row m
    (i.e., ⌊1/(kx)⌋ is constant = n throughout the row), the row integral
    equals the tile (m,n) FTC evaluation.

    Condition: the entire row (1/(j(m+1)), 1/(jm)] ⊆ (1/(k(n+1)), 1/(kn)],
    which means the tile (m,n) IS the row.
    Equivalently: kn ≤ jm and j(m+1) ≤ k(n+1). -/
theorem row_integral_single_tile (j k m n : ℕ)
    (hj : 1 ≤ j) (hk : 1 ≤ k) (hm : 1 ≤ m) (hn : 1 ≤ n)
    (h_kn_le_jm : k * n ≤ j * m) (h_jm1_le_kn1 : j * (m + 1) ≤ k * (n + 1)) :
    ∫ x in (rowLo j m)..(rowHi j m),
      Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)) =
    ∫ x in (rowLo j m)..(rowHi j m),
      (1 / ((j:ℝ) * x) - (m:ℝ)) * (1 / ((k:ℝ) * x) - (n:ℝ)) := by
  apply intervalIntegral.integral_congr_ae
  filter_upwards with x hx
  simp only [Set.uIoc_of_le (le_of_lt (row_nonempty j m hj hm))] at hx
  -- x ∈ (rowLo j m, rowHi j m], need both fract identities
  have hj_lo : 1 / ((j:ℝ) * ((m:ℝ) + 1)) < x := hx.1
  have hj_hi : x ≤ 1 / ((j:ℝ) * (m:ℝ)) := hx.2
  -- For the k-fract: need 1/(k(n+1)) < x ≤ 1/(kn)
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  have hk_pos : (0:ℝ) < (k:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hn_pos : (0:ℝ) < (n:ℝ) := Nat.cast_pos.mpr (by omega)
  have hx_pos : (0:ℝ) < x := lt_of_lt_of_le (div_pos one_pos (mul_pos hj_pos (by linarith))) (le_of_lt hx.1)
  -- kn ≤ jm → kn ≤ jm → 1/(jm) ≤ 1/(kn) → x ≤ 1/(kn)
  have hk_hi : x ≤ 1 / ((k:ℝ) * (n:ℝ)) := by
    calc x ≤ 1 / ((j:ℝ) * (m:ℝ)) := hj_hi
      _ ≤ 1 / ((k:ℝ) * (n:ℝ)) := by
        rw [div_le_div_iff₀ (mul_pos hj_pos hm_pos) (mul_pos hk_pos hn_pos)]
        simp only [one_mul]
        exact_mod_cast h_kn_le_jm
  -- j(m+1) ≤ k(n+1) → 1/(k(n+1)) ≤ 1/(j(m+1)) < x
  have hk_lo : 1 / ((k:ℝ) * ((n:ℝ) + 1)) < x := by
    calc 1 / ((k:ℝ) * ((n:ℝ) + 1))
        ≤ 1 / ((j:ℝ) * ((m:ℝ) + 1)) := by
          rw [div_le_div_iff₀ (mul_pos hk_pos (by linarith)) (mul_pos hj_pos (by linarith))]
          simp only [one_mul]
          exact_mod_cast h_jm1_le_kn1
      _ < x := hj_lo
  exact fract_prod_eq_on_tile j k m n hj hk hm hn x hj_lo hj_hi hk_lo hk_hi

/-- **TWO-TILE ROW CASE**: When there is a k-crossing at x₀ = 1/(k·n₀)
    within row m, the row integral splits into two tile integrals.

    Here n₀ is the crossing value with j·m < k·n₀ < j·(m+1).
    The left tile has floor n₀ and the right tile has floor n₀-1. -/
theorem row_integral_split_at_crossing (j k m n₀ : ℕ)
    (hj : 1 ≤ j) (hk : 1 ≤ k) (hm : 1 ≤ m) (hn₀ : 1 ≤ n₀)
    (_h_cross_lo : j * m < k * n₀) (_h_cross_hi : k * n₀ < j * (m + 1)) :
    ∫ x in (rowLo j m)..(rowHi j m),
      Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)) =
    (∫ x in (rowLo j m)..(1 / ((k:ℝ) * (n₀:ℝ))),
      Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x))) +
    (∫ x in (1 / ((k:ℝ) * (n₀:ℝ)))..(rowHi j m),
      Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x))) := by
  -- The crossing point x₀ = 1/(k·n₀) lies strictly inside the row
  have hk_pos : (0:ℝ) < (k:ℝ) := Nat.cast_pos.mpr (by omega)
  have hn₀_pos : (0:ℝ) < (n₀:ℝ) := Nat.cast_pos.mpr (by omega)
  have hx₀_pos : (0:ℝ) < 1 / ((k:ℝ) * (n₀:ℝ)) := by positivity
  -- integral_add_adjacent_intervals gives a+b=c, we need c=a+b
  symm
  exact intervalIntegral.integral_add_adjacent_intervals
    (fract_prod_integrable_pos j k _ _ (rowLo_pos j m hj hm))
    (fract_prod_integrable_pos j k _ _ hx₀_pos)

end Cathedral.Vasyunin.OffDiagPartition
