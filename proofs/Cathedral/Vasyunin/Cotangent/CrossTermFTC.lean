/-
  Cathedral/MellinBridge/Vasyunin/CrossTermFTC.lean

  ## CROSS-TERM PIECEWISE FTC FOR THE OFF-DIAGONAL INTEGRAL

  Proves the per-tile integral for the product of two fractional-part functions:
    ∫_lo^hi {1/(jx)} · {1/(kx)} dx  where ⌊1/(jx)⌋=m, ⌊1/(kx)⌋=n on (lo,hi]

  On each "tile" where both floors are constant, the integrand becomes:
    (1/(jx) - m)(1/(kx) - n) = 1/(jkx²) - (n/j + m/k)/x + mn

  Antiderivative: F(x) = -1/(jkx) - (n/j + m/k)·log(x) + mn·x

  This generalizes the diagonal PiecewiseFTC (where j=k, m=n)
  to the off-diagonal case needed for vasyunin_eq_integral.

  ### Architecture (following the Attack 10 reconnaissance):
  fract_eq_on_cross_piece    THEOREM: {1/(jx)} = 1/(jx)-m, {1/(kx)} = 1/(kx)-n on tile
  cross_piece_integral_ftc   THEOREM: per-tile FTC evaluation
  cross_piece_integrability  THEOREM: integrability on each tile

  Created: April 12, 2026, 9:03 PM MDT (Season 2 Opens)
-/

import Cathedral.Vasyunin.Defs
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.MeasureTheory.Integral.IntervalIntegral.FundThmCalculus
import Mathlib.Analysis.SpecialFunctions.Log.Deriv

noncomputable section
open Real MeasureTheory

namespace Cathedral.Vasyunin.CrossTermFTC

-- ════════════════════════════════════════════════
-- §1. FLOOR/FRACT IDENTITY ON A TILE
-- ════════════════════════════════════════════════

/-- On the interval (1/(j(m+1)), 1/(jm)], ⌊1/(jx)⌋ = m and {1/(jx)} = 1/(jx) - m.
    This generalizes fract_eq_on_piece to arbitrary j ≥ 1.

    Proof: x ∈ (1/(j(m+1)), 1/(jm)] implies 1/(jx) ∈ [m, m+1),
    so ⌊1/(jx)⌋ = m.
-/
lemma fract_eq_on_piece_general (j m : ℕ) (hj : 1 ≤ j) (hm : 1 ≤ m)
    (x : ℝ) (hlo : 1 / ((j:ℝ) * ((m:ℝ) + 1)) < x)
    (hhi : x ≤ 1 / ((j:ℝ) * (m:ℝ))) :
    Int.fract (1 / ((j:ℝ) * x)) = 1 / ((j:ℝ) * x) - (m:ℝ) := by
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm1_pos : (0:ℝ) < (m:ℝ) + 1 := by linarith
  have hjm_pos : (0:ℝ) < (j:ℝ) * (m:ℝ) := mul_pos hj_pos hm_pos
  have hjm1_pos : (0:ℝ) < (j:ℝ) * ((m:ℝ) + 1) := mul_pos hj_pos hm1_pos
  have hx_pos : (0:ℝ) < x := lt_of_lt_of_le (by positivity) (le_of_lt hlo)
  -- Show 1/(jx) ∈ [m, m+1)
  have h_ge : (m:ℝ) ≤ 1 / ((j:ℝ) * x) := by
    rw [le_div_iff₀ (mul_pos hj_pos hx_pos)]
    calc (m:ℝ) * ((j:ℝ) * x) = (j:ℝ) * ((m:ℝ) * x) := by ring
      _ ≤ (j:ℝ) * ((m:ℝ) * (1 / ((j:ℝ) * (m:ℝ)))) := by nlinarith
      _ = 1 := by field_simp
  have h_lt : 1 / ((j:ℝ) * x) < (m:ℝ) + 1 := by
    rw [div_lt_iff₀ (mul_pos hj_pos hx_pos)]
    calc 1 = ((j:ℝ) * ((m:ℝ) + 1)) * (1 / ((j:ℝ) * ((m:ℝ) + 1))) := by field_simp
      _ < ((j:ℝ) * ((m:ℝ) + 1)) * x := by nlinarith
      _ = ((m:ℝ) + 1) * ((j:ℝ) * x) := by ring
  have hfloor : ⌊1 / ((j:ℝ) * x)⌋ = (m:ℤ) := by
    apply Int.floor_eq_iff.mpr
    exact ⟨by exact_mod_cast h_ge, by push_cast; exact h_lt⟩
  rw [Int.fract, hfloor]; push_cast; ring

/-- When x > 1/j, ⌊1/(jx)⌋ = 0, so {1/(jx)} = 1/(jx). (The m=0 case.) -/
lemma fract_eq_on_piece_zero (j : ℕ) (hj : 1 ≤ j)
    (x : ℝ) (hlo : 1 / (j:ℝ) < x) (_hhi : x ≤ 1) :
    Int.fract (1 / ((j:ℝ) * x)) = 1 / ((j:ℝ) * x) := by
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  have hx_pos : (0:ℝ) < x := lt_of_lt_of_le (by positivity) (le_of_lt hlo)
  -- 0 < 1/(jx) < 1
  have h_pos : (0:ℝ) < 1 / ((j:ℝ) * x) := by positivity
  have h_lt_one : 1 / ((j:ℝ) * x) < 1 := by
    rw [div_lt_one (mul_pos hj_pos hx_pos)]
    calc 1 = (j:ℝ) * (1 / (j:ℝ)) := by field_simp
      _ < (j:ℝ) * x := by nlinarith
  have hfloor : ⌊1 / ((j:ℝ) * x)⌋ = (0:ℤ) := by
    apply Int.floor_eq_iff.mpr
    exact ⟨by exact_mod_cast le_of_lt h_pos, by push_cast; linarith⟩
  rw [Int.fract, hfloor]; simp

-- ════════════════════════════════════════════════
-- §2. CROSS-TERM FTC ON A SINGLE TILE
-- ════════════════════════════════════════════════

/-- **CROSS-TERM FTC**: On the tile (lo, hi] where ⌊1/(jx)⌋=m, ⌊1/(kx)⌋=n:

    ∫_lo^hi (1/(jx) - m)(1/(kx) - n) dx
     = [-1/(jkx) - (n/j + m/k)·log(x) + mn·x]_{lo}^{hi}

    Antiderivative: F(x) = -1/(jkx) - (n/j + m/k)·log(x) + mn·x
    F'(x) = 1/(jkx²) - (n/j + m/k)/x + mn = (1/(jx) - m)(1/(kx) - n)

    This is the cross-term generalization of piece_integral_ftc. -/
theorem cross_piece_integral_ftc (j k m n : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k)
    (lo hi : ℝ) (hlo_pos : 0 < lo) (hle : lo ≤ hi) :
    ∫ x in lo..hi,
      (1 / ((j:ℝ) * x) - (m:ℝ)) * (1 / ((k:ℝ) * x) - (n:ℝ)) =
    let jf := (j:ℝ); let kf := (k:ℝ); let mf := (m:ℝ); let nf := (n:ℝ)
    (-1 / (jf * kf * hi) - (nf/jf + mf/kf) * Real.log hi + mf * nf * hi) -
    (-1 / (jf * kf * lo) - (nf/jf + mf/kf) * Real.log lo + mf * nf * lo) := by
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  have hk_pos : (0:ℝ) < (k:ℝ) := Nat.cast_pos.mpr (by omega)
  have hhi_pos : (0:ℝ) < hi := lt_of_lt_of_le hlo_pos hle
  -- Name casts for readability
  set jf := (j:ℝ); set kf := (k:ℝ); set mf := (m:ℝ); set nf := (n:ℝ)
  -- Define F using + (not -) to match HasDerivAt.add's Pi.instAdd output
  set F := fun x => (-1 / (jf * kf * x)) + (-(nf/jf + mf/kf) * Real.log x) + (mf * nf * x)
  -- F is the antiderivative. Its derivative is (1/(jx) - m)(1/(kx) - n).
  have hF_deriv : ∀ x ∈ Set.uIcc lo hi,
      HasDerivAt F ((1 / (jf * x) - mf) * (1 / (kf * x) - nf)) x := by
    intro x hx
    rw [Set.uIcc_of_le hle] at hx
    have hx_pos : (0:ℝ) < x := lt_of_lt_of_le hlo_pos hx.1
    have hx_ne : x ≠ 0 := ne_of_gt hx_pos
    have hjk_ne : jf * kf ≠ 0 := ne_of_gt (mul_pos hj_pos hk_pos)
    have hjkx_ne : jf * kf * x ≠ 0 := by positivity
    -- d/dx [-1/(jkx)] = 1/(jkx²)
    have h1 : HasDerivAt (fun x => -1 / (jf * kf * x))
        (1 / (jf * kf * x ^ 2)) x := by
      -- Write as (-1/(jk)) * x⁻¹
      have h1a : HasDerivAt (fun x => x⁻¹) (-(x ^ 2)⁻¹) x :=
        hasDerivAt_inv hx_ne
      have h1b := h1a.const_mul (-1 / (jf * kf))
      convert h1b using 1 <;> [ext y; skip] <;> simp [div_eq_mul_inv] <;> ring
    -- d/dx [-(n/j+m/k)·log(x)] = -(n/j+m/k)/x
    have h2 : HasDerivAt (fun x => -(nf/jf + mf/kf) * Real.log x)
        (-(nf/jf + mf/kf) * x⁻¹) x :=
      (Real.hasDerivAt_log hx_ne).const_mul (-(nf/jf + mf/kf))
    -- d/dx [mn·x] = mn
    have h3 : HasDerivAt (fun x => mf * nf * x)
        (mf * nf) x := by
      convert (hasDerivAt_id x).const_mul (mf * nf) using 1; ring
    -- F = f1 + f2 + f3, so HasDerivAt F (d1 + d2 + d3) x
    -- Then congr_deriv to show d1+d2+d3 = (1/(jx)-m)(1/(kx)-n)
    exact ((h1.add h2).add h3).congr_deriv (by field_simp; ring)
  have hint : IntervalIntegrable (fun x => (1 / (jf * x) - mf) * (1 / (kf * x) - nf))
      volume lo hi := by
    apply ContinuousOn.intervalIntegrable
    apply ContinuousOn.mul
    · exact (continuousOn_const.div (continuousOn_const.mul continuousOn_id)
        (fun x hx => by
          rw [Set.uIcc_of_le hle] at hx
          exact ne_of_gt (mul_pos hj_pos (lt_of_lt_of_le hlo_pos hx.1)))).sub continuousOn_const
    · exact (continuousOn_const.div (continuousOn_const.mul continuousOn_id)
        (fun x hx => by
          rw [Set.uIcc_of_le hle] at hx
          exact ne_of_gt (mul_pos hk_pos (lt_of_lt_of_le hlo_pos hx.1)))).sub continuousOn_const
  -- Apply FTC: ∫ = F(hi) - F(lo)
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hF_deriv hint]
  -- F(hi) - F(lo) = the stated expression
  simp only [F]; ring

-- ════════════════════════════════════════════════
-- §3. TILE BOUNDARY COMPUTATION
-- ════════════════════════════════════════════════

/-- The tile (m,n) for functions {1/(jx)} and {1/(kx)} is the interval
    (lo, hi] where:
      lo = max(1/(j(m+1)), 1/(k(n+1)))
      hi = min(1/(jm), 1/(kn))

    The tile is nonempty iff lo < hi, which happens iff:
      jm < k(n+1)  AND  kn < j(m+1)
    i.e., n ∈ (jm/k - 1, j(m+1)/k).

    (Discovered via Attack 10: the Beatty sequence structure.) -/
def tileLo (j k m n : ℕ) : ℝ :=
  max (1 / ((j:ℝ) * ((m:ℝ) + 1))) (1 / ((k:ℝ) * ((n:ℝ) + 1)))

def tileHi (j k m n : ℕ) : ℝ :=
  min (1 / ((j:ℝ) * (m:ℝ))) (1 / ((k:ℝ) * (n:ℝ)))

/-- The tile for m=0 has upper bound 1 (not 1/(j·0)). -/
def tileLo_m0 (j k n : ℕ) : ℝ :=
  max (1 / (j:ℝ)) (1 / ((k:ℝ) * ((n:ℝ) + 1)))

/-- Nonemptiness condition: tile (m,n) is nonempty iff n ∈ (jm/k − 1, j(m+1)/k).
    Equivalently: jm < k(n+1) and kn < j(m+1). -/
lemma tile_nonempty_iff (j k m n : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k)
    (hm : 1 ≤ m) (hn : 1 ≤ n) :
    tileLo j k m n < tileHi j k m n ↔
    (j * m < k * (n + 1) ∧ k * n < j * (m + 1)) := by
  unfold tileLo tileHi
  have hj_pos : (0:ℝ) < (j:ℝ) := Nat.cast_pos.mpr (by omega)
  have hk_pos : (0:ℝ) < (k:ℝ) := Nat.cast_pos.mpr (by omega)
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hn_pos : (0:ℝ) < (n:ℝ) := Nat.cast_pos.mpr (by omega)
  constructor
  · intro h
    constructor
    · -- max(1/(j(m+1)), 1/(k(n+1))) < min(1/(jm), 1/(kn))
      -- In particular: 1/(k(n+1)) < 1/(jm)  ⟹  jm < k(n+1)
      have h1 := lt_of_le_of_lt (le_max_right _ _) (lt_of_lt_of_le h (min_le_left _ _))
      rw [div_lt_div_iff₀ (by positivity : (0:ℝ) < (k:ℝ) * ((n:ℝ)+1))
                          (by positivity : (0:ℝ) < (j:ℝ) * (m:ℝ))] at h1
      simp only [one_mul] at h1
      -- h1: (j:ℝ) * (m:ℝ) < (k:ℝ) * ((n:ℝ) + 1)
      have : (j * m : ℕ) < k * (n + 1) := by
        by_contra h_neg
        push Not at h_neg
        have : (k * (n + 1) : ℝ) ≤ (j * m : ℝ) := by exact_mod_cast h_neg
        push_cast at this
        linarith
      exact this
    · -- Similarly: 1/(j(m+1)) < 1/(kn)  ⟹  kn < j(m+1)
      have h2 := lt_of_le_of_lt (le_max_left _ _) (lt_of_lt_of_le h (min_le_right _ _))
      rw [div_lt_div_iff₀ (by positivity : (0:ℝ) < (j:ℝ) * ((m:ℝ)+1))
                          (by positivity : (0:ℝ) < (k:ℝ) * (n:ℝ))] at h2
      simp only [one_mul] at h2
      have : (k * n : ℕ) < j * (m + 1) := by
        by_contra h_neg
        push Not at h_neg
        have : (j * (m + 1) : ℝ) ≤ (k * n : ℝ) := by exact_mod_cast h_neg
        push_cast at this
        linarith
      exact this
  · intro ⟨h1, h2⟩
    -- Need: max(1/(j(m+1)), 1/(k(n+1))) < min(1/(jm), 1/(kn))
    apply lt_min
    · -- max(...) < 1/(jm): both components < 1/(jm)
      apply max_lt
      · -- 1/(j(m+1)) < 1/(jm): true since m+1 > m
        apply div_lt_div_of_pos_left (by norm_num : (0:ℝ) < 1) (by positivity) (by nlinarith)
      · -- 1/(k(n+1)) < 1/(jm) ⟸ jm < k(n+1)
        apply div_lt_div_of_pos_left (by norm_num : (0:ℝ) < 1) (by positivity)
        have h1' : ((j * m : ℕ) : ℝ) < ((k * (n + 1) : ℕ) : ℝ) := by exact_mod_cast h1
        push_cast at h1' ⊢; linarith
    · -- max(...) < 1/(kn): both components < 1/(kn)
      apply max_lt
      · -- 1/(j(m+1)) < 1/(kn) ⟸ kn < j(m+1)
        apply div_lt_div_of_pos_left (by norm_num : (0:ℝ) < 1) (by positivity)
        have h2' : ((k * n : ℕ) : ℝ) < ((j * (m + 1) : ℕ) : ℝ) := by exact_mod_cast h2
        push_cast at h2' ⊢; linarith
      · -- 1/(k(n+1)) < 1/(kn): true since n+1 > n
        apply div_lt_div_of_pos_left (by norm_num : (0:ℝ) < 1) (by positivity)
        nlinarith

-- ════════════════════════════════════════════════
-- §4. BEATTY SEQUENCE TILE COUNT
-- ════════════════════════════════════════════════

/-- **BEATTY SEQUENCE LEMMA** (discovered in Attack 10):
    For j ≤ k and each m ≥ 1, the number of n values making
    the tile (m,n) nonempty is at most 2.

    The valid n values satisfy n ∈ (jm/k − 1, j(m+1)/k) ∩ ℤ.
    This interval has width j/k + 1 ≤ 2 when j ≤ k,
    so at most 2 integers fit.

    Note: When j > k, up to ⌈j/k⌉ + 1 tiles per row are possible,
    but by symmetry of the integral we can always partition using
    the larger index.

    Proof: If n₁ < n₂ < n₃ are all valid, then from the nonemptiness
    conditions: jm < k(n₁+1) and k·n₃ < j(m+1). Since n₃ ≥ n₁+2,
    we get k(n₁+2) ≤ k·n₃ < j·m + j < k·n₁ + k + j,
    so 2k < k + j, i.e., k < j — contradicting j ≤ k. -/
lemma tile_n_values_bounded (j k m : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k)
    (hm : 1 ≤ m) (hjk : j ≤ k) :
    ∀ n₁ n₂ n₃ : ℕ, 1 ≤ n₁ → 1 ≤ n₂ → 1 ≤ n₃ →
    n₁ < n₂ → n₂ < n₃ →
    tileLo j k m n₁ < tileHi j k m n₁ →
    tileLo j k m n₂ < tileHi j k m n₂ →
    tileLo j k m n₃ < tileHi j k m n₃ → False := by
  intro n₁ n₂ n₃ hn₁ _hn₂ hn₃ h12 h23 h_ne1 _h_ne2 h_ne3
  rw [tile_nonempty_iff j k m n₁ hj hk hm hn₁] at h_ne1
  rw [tile_nonempty_iff j k m n₃ hj hk hm hn₃] at h_ne3
  have h_n3_ge : n₁ + 2 ≤ n₃ := by omega
  -- key1: j * m < k * (n₁ + 1)     (from tile n₁ nonempty)
  -- key2: k * n₃ < j * (m + 1)     (from tile n₃ nonempty)
  have key1 := h_ne1.1
  have key2 := h_ne3.2
  -- k * (n₁ + 2) ≤ k * n₃          (since n₃ ≥ n₁ + 2)
  have hkn3 : k * (n₁ + 2) ≤ k * n₃ := Nat.mul_le_mul_left k h_n3_ge
  -- Expand: k * n₁ + 2 * k ≤ k * n₃ < j * m + j
  have hexp : k * n₁ + 2 * k ≤ k * n₃ := by linarith [Nat.mul_add k n₁ 2]
  -- And: j * m + 1 ≤ k * n₁ + k    (from key1, in ℕ)
  -- So: k * n₁ + 2 * k ≤ k * n₃ < j * m + j ≤ (k * n₁ + k - 1) + j
  --     = k * n₁ + k + j - 1
  -- Thus: 2 * k ≤ k + j - 1, i.e., k + 1 ≤ j, i.e., k < j
  -- But j ≤ k — contradiction!
  have : k < j := by nlinarith
  omega

end Cathedral.Vasyunin.CrossTermFTC
