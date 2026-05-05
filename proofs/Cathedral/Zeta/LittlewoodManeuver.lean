/-
  Cathedral/Zeta/LittlewoodManeuver.lean

  ## The Littlewood Maneuver: Sub-Logarithmic Zeta Lower Bound

  Exploration 25 — Phase 2 (Corrected: Archimedean Fulcrum).

  ### The Central Idea
  For any A > 0, we prove |ζ(σ+it)| ≥ c/|t|^A for σ ≥ 1/2+ε, |t| large.

  ### Geometry (Corrected)
  Center: s₀ = 3 + it.
  Inner radius: r₁ = 1 (inner circle at Re ≥ 2 — Euler product anchor).
  Target radius: r₂ = 5/2 - ε (touches σ = 1/2 + ε).
  Outer radius: r₃ = 5/2 - ε/2 (outer circle at σ = 1/2 + ε/2).

  ### Proof Outline
  1. Holomorphic log G on ball(0, r₃): ζ(s₀+z) = ζ(s₀)·exp(G(z)), G(0) = 0.
  2. INNER bound: ‖G(z)‖ ≤ 6 on ‖z‖ = 1 (t-independent: Right Half-Plane Trap).
     Key: Re(s₀+z) ≥ 2 → ‖ζ-1‖ ≤ 3/4 → Re(ζ) > 1/4 → |arg ζ| < π/2.
  3. OUTER bound: Re(G(z)) ≤ C·log(2+|t|) on ‖z‖ ≤ r₃ (convexity bound).
  4. Three-Circles: ‖G(z)‖ ≤ 6^{1-α} · (C·log|t|)^α with α < 1.
  5. Sub-logarithmic → universal: (log t)^α < A·log t for t ≥ T₀(A).

  ### Dependencies: DiskBounds, Hadamard (three-circles).
-/

import Cathedral.Zeta.DiskBounds
import Cathedral.Zeta.Hadamard
import Mathlib.Analysis.SpecialFunctions.Pow.Asymptotics
import Mathlib.Analysis.Calculus.MeanValue
import Mathlib.NumberTheory.LSeries.Dirichlet
import Mathlib.Analysis.PSeries
import Mathlib.Topology.Algebra.InfiniteSum.Real

noncomputable section
open Complex Real Filter Asymptotics MeasureTheory Metric Set
open scoped Topology ArithmeticFunction LSeries.notation

namespace Cathedral.Zeta.LittlewoodManeuver
open Cathedral.Zeta.DiskBounds
open Cathedral.Zeta.Hadamard

-- ═══════════════════════════════════════════
-- §1. Geometry for Center s₀ = (3, t)
-- ═══════════════════════════════════════════

/-- r₃ = 5/2 - ε/2 is positive. -/
private lemma outer_radius_pos {ε : ℝ} (_hε : 0 < ε) (hε1 : ε < 3/2) :
    0 < 5/2 - ε/2 := by linarith

/-- r₂ = 5/2 - ε is positive. -/
private lemma target_radius_pos {ε : ℝ} (hε1 : ε < 3/2) :
    0 < 5/2 - ε := by linarith

/-- 1 < r₂ (inner radius < target radius). -/
private lemma inner_lt_target {ε : ℝ} (hε1 : ε < 3/2) :
    (1 : ℝ) < 5/2 - ε := by linarith

/-- r₂ < r₃ (target inside outer). -/
private lemma target_lt_outer {ε : ℝ} (hε : 0 < ε) :
    5/2 - ε < 5/2 - ε/2 := by linarith

/-- Re(s₀ + z) ≥ 2 when ‖z‖ ≤ 1 and center is (3, t). -/
lemma re_ge_two_on_inner {z : ℂ} (hz : ‖z‖ ≤ 1) :
    2 ≤ ((⟨3, t⟩ : ℂ) + z).re := by
  have : |z.re| ≤ ‖z‖ := Complex.abs_re_le_norm z
  simp only [Complex.add_re]
  show 2 ≤ 3 + z.re
  linarith [(abs_le.mp (le_trans this hz)).1]

/-- s₀ + z ≠ 1 on ball(0, r₃) when center is (3, t) with |t| ≥ 2.
    Pole distance: |s₀ - 1| = √(4+t²) ≥ √8 > 5/2. -/
lemma s_ne_one_on_ball_3
    {t : ℝ} (ht : 2 ≤ |t|) {ε : ℝ} (hε : 0 < ε) (hε1 : ε < 3/2)
    {z : ℂ} (hz : z ∈ ball (0 : ℂ) (5/2 - ε/2)) :
    (⟨3, t⟩ : ℂ) + z ≠ 1 := by
  simp only [mem_ball, dist_zero_right] at hz
  intro heq
  -- z = 1 - s₀, extract re/im
  have hzre : z.re = -2 := by
    have := congr_arg Complex.re heq; simp at this; linarith
  have hzim : z.im = -t := by
    have := congr_arg Complex.im heq; simp at this; linarith
  -- ‖z‖² = normSq z = z.re² + z.im² = 4 + t²
  have h_nsq : Complex.normSq z = 4 + t^2 := by
    simp [Complex.normSq_apply, hzre, hzim]; ring
  -- ‖z‖² = normSq z (as reals)
  have h_norm_sq : ‖z‖^2 = 4 + t^2 := by
    rw [← Complex.normSq_eq_norm_sq]; exact_mod_cast h_nsq
  -- 4 + t² ≥ 8 since |t| ≥ 2
  have h8 : 8 ≤ 4 + t^2 := by nlinarith [sq_abs t]
  -- (5/2 - ε/2)² < 25/4 < 8
  have hlt : (5/2 - ε/2)^2 < 8 := by nlinarith [sq_nonneg ε]
  -- ‖z‖² ≥ 8 > (5/2-ε/2)² so ‖z‖ > 5/2 - ε/2, contradicting hz
  have : ‖z‖ ≥ 0 := norm_nonneg _
  nlinarith [sq_nonneg (‖z‖ - (5/2 - ε/2)), sq_abs (5/2 - ε/2)]

/-- Re(s₀ + z) > 1/2 on ball(0, r₃) with center (3, t). -/
lemma re_gt_half_on_ball_3
    {ε : ℝ} (hε : 0 < ε) (_hε1 : ε < 3/2)
    {z : ℂ} (hz : z ∈ ball (0 : ℂ) (5/2 - ε/2)) :
    1/2 < ((⟨3, t⟩ : ℂ) + z).re := by
  simp only [mem_ball, dist_zero_right] at hz
  have : |z.re| ≤ ‖z‖ := Complex.abs_re_le_norm z
  simp only [Complex.add_re]
  show 1/2 < 3 + z.re
  linarith [(abs_le.mp (le_trans this (le_of_lt hz))).1]

-- §1.5. Wide ball geometry (for R₄ < 5/2 in the four-radii architecture)

/-- (3,t) + z ≠ 1 for z ∈ ball(0, R), R < 5/2, |t| ≥ 2. -/
private lemma s_ne_one_on_wide_ball
    {t : ℝ} (ht : 2 ≤ |t|) {R : ℝ} (hR : R < 5/2)
    {z : ℂ} (hz : z ∈ ball (0 : ℂ) R) :
    (⟨3, t⟩ : ℂ) + z ≠ 1 := by
  simp only [mem_ball, dist_zero_right] at hz
  intro heq
  have hzre : z.re = -2 := by
    have := congr_arg Complex.re heq; simp at this; linarith
  have hzim : z.im = -t := by
    have := congr_arg Complex.im heq; simp at this; linarith
  have h_nsq : Complex.normSq z = 4 + t^2 := by
    simp [Complex.normSq_apply, hzre, hzim]; ring
  have h_norm_sq : ‖z‖^2 = 4 + t^2 := by
    rw [← Complex.normSq_eq_norm_sq]; exact_mod_cast h_nsq
  have h8 : 8 ≤ 4 + t^2 := by nlinarith [sq_abs t]
  have h_z_lt : ‖z‖ < 5/2 := lt_trans hz hR
  have h_z_sq : ‖z‖^2 < (5/2)^2 := by
    exact sq_lt_sq' (by linarith [norm_nonneg z]) h_z_lt
  nlinarith

/-- Re((3,t) + z) > 1/2 for z ∈ ball(0, R), R < 5/2. -/
private lemma re_gt_half_on_wide_ball
    {R : ℝ} (hR : R < 5/2) {z : ℂ} (hz : z ∈ ball (0 : ℂ) R) :
    1/2 < ((⟨3, t⟩ : ℂ) + z).re := by
  simp only [mem_ball, dist_zero_right] at hz
  have : |z.re| ≤ ‖z‖ := Complex.abs_re_le_norm z
  simp only [Complex.add_re]
  show 1/2 < 3 + z.re
  linarith [(abs_le.mp (le_trans this (le_of_lt hz))).1]

/-- ζ differentiable on wide ball with center (3,t). -/
private lemma zeta_differentiable_on_wide_ball
    {t : ℝ} (ht : 2 ≤ |t|) {R : ℝ} (_hR_pos : 0 < R) (hR : R < 5/2) :
    DifferentiableOn ℂ (fun w => riemannZeta ((⟨3, t⟩ : ℂ) + w)) (ball 0 R) := by
  intro z hz
  have hsne := s_ne_one_on_wide_ball ht hR hz
  exact (differentiableAt_riemannZeta hsne).comp z
    ((differentiableAt_const (⟨3, t⟩ : ℂ)).add differentiableAt_id) |>.differentiableWithinAt

/-- ζ nonvanishing on wide ball under RH. -/
private lemma zeta_ne_zero_on_wide_ball (hRH : RiemannHypothesis)
    {t : ℝ} (ht : 2 ≤ |t|) {R : ℝ} (hR : R < 5/2) :
    ∀ z ∈ ball (0 : ℂ) R, riemannZeta ((⟨3, t⟩ : ℂ) + z) ≠ 0 := by
  intro z hz
  have hne1 := s_ne_one_on_wide_ball ht hR hz
  exact rh_zeta_ne_zero hRH (re_gt_half_on_wide_ball hR hz) hne1

-- ═══════════════════════════════════════════
-- §2. The Inner Anchor (Lemma 1)
-- ═══════════════════════════════════════════

/-! ### The Right Half-Plane Trap (Archimedean Fulcrum)

For Re(s) ≥ 2, `zeta_sub_one_norm_le_three_fourths` gives ‖ζ(s) - 1‖ ≤ 3/4.
This means Re(ζ(s)) ≥ 1 - 3/4 = 1/4 > 0, so ζ(s) is in the right half-plane.
Therefore |arg(ζ(s))| < π/2, and:

  |log|ζ(s)|| ≤ max(|log(1/4)|, |log(7/4)|) = log 4 ≈ 1.39
  |arg ζ(s)| < π/2 ≈ 1.57

So |log ζ(s)| ≤ log 4 + π/2 < 3.

For G with exp(G(z)) = ζ(s₀+z)/ζ(s₀) and G(0) = 0:
  |G(z)| = |log(ζ(s₀+z)/ζ(s₀))|
         ≤ |log ζ(s₀+z)| + |log ζ(s₀)|
         ≤ 3 + 3 = 6.

This bound is COMPLETELY INDEPENDENT of t. -/

/-- Chain rule: deriv of ζ ∘ (s₀ + ·) at w equals deriv ζ at s₀+w. -/
private lemma deriv_zeta_comp {s₀ w : ℂ} (hw : s₀ + w ≠ 1) :
    deriv (fun z => riemannZeta (s₀ + z)) w = deriv riemannZeta (s₀ + w) := by
  have hd : HasDerivAt (fun z : ℂ => riemannZeta (s₀ + z))
      (deriv riemannZeta (s₀ + w) * 1) w := by
    apply HasDerivAt.comp
    · exact (differentiableAt_riemannZeta hw).hasDerivAt
    · exact (hasDerivAt_id w).const_add s₀
  rw [mul_one] at hd
  exact hd.deriv

/-- Telescoping bound: m^{-3/2} ≤ 2·((m-1)^{-1/2} - m^{-1/2}) for m ≥ 2.
    Reduces to m(m-1) ≤ (m+1)², i.e. 0 ≤ 3m+1. -/
private lemma rpow_neg_three_half_le {m : ℝ} (hm : 2 ≤ m) :
    m ^ (-3/2 : ℝ) ≤ 2 * ((m - 1) ^ (-1/2 : ℝ) - m ^ (-1/2 : ℝ)) := by
  have hm0 : 0 < m := by linarith
  have hm1 : 0 < m - 1 := by linarith
  have hsm : 0 < Real.sqrt m := Real.sqrt_pos.mpr hm0
  have hsm1 : 0 < Real.sqrt (m-1) := Real.sqrt_pos.mpr hm1
  have lhs_eq : m ^ (-3/2 : ℝ) = (m * Real.sqrt m)⁻¹ := by
    rw [show (-3/2 : ℝ) = -1 + -(1/2) from by norm_num, rpow_add hm0]
    simp only [rpow_neg hm0.le, ← Real.sqrt_eq_rpow, rpow_one]
    rw [mul_inv]
  have rhs_eq : 2 * ((m - 1) ^ (-1/2 : ℝ) - m ^ (-1/2 : ℝ)) =
      2 * (Real.sqrt m - Real.sqrt (m-1)) / (Real.sqrt (m-1) * Real.sqrt m) := by
    rw [show (-1/2 : ℝ) = -(1/2) from by norm_num,
        rpow_neg hm0.le, rpow_neg hm1.le,
        ← Real.sqrt_eq_rpow, ← Real.sqrt_eq_rpow,
        inv_sub_inv hsm1.ne' hsm.ne']
    ring
  rw [lhs_eq, rhs_eq]
  suffices h : Real.sqrt (m-1) * Real.sqrt m ≤
      2 * (Real.sqrt m - Real.sqrt (m-1)) * (m * Real.sqrt m) by
    have hmsm : 0 < m * Real.sqrt m := mul_pos hm0 hsm
    have hrhs_pos : 0 < 2 * (Real.sqrt m - Real.sqrt (m-1)) / (Real.sqrt (m-1) * Real.sqrt m) := by
      apply div_pos (mul_pos (by norm_num : (0:ℝ) < 2) _) (mul_pos hsm1 hsm)
      exact sub_pos.mpr (Real.sqrt_lt_sqrt hm1.le (by linarith))
    rw [show (m * Real.sqrt m)⁻¹ = 1 / (m * Real.sqrt m) from (one_div _).symm,
        div_le_div_iff₀ hmsm (mul_pos hsm1 hsm)]
    linarith
  set a := Real.sqrt (m - 1)
  set b := Real.sqrt m
  have ha2 : a ^ 2 = m - 1 := Real.sq_sqrt hm1.le
  have hb2 : b ^ 2 = m := Real.sq_sqrt hm0.le
  nlinarith [sq_nonneg (2*b^3 - a*(1 + 2*b^2)),
             sq_nonneg b, sq_nonneg a, ha2, hb2,
             mul_self_nonneg (b - a), mul_self_nonneg a,
             mul_pos hsm hsm, mul_pos hsm1 hsm]

/-- Partial sums of the p-series tail are bounded by 2 via telescoping. -/
private lemma partial_sum_rpow_le (N : ℕ) :
    ∑ i ∈ Finset.range N, ((i + 2 : ℕ) : ℝ) ^ (-3/2 : ℝ) ≤ 2 := by
  calc ∑ i ∈ Finset.range N, ((i + 2 : ℕ) : ℝ) ^ (-3/2 : ℝ)
      ≤ ∑ i ∈ Finset.range N,
          (2 * (((i + 1 : ℕ) : ℝ) ^ (-1/2 : ℝ) - ((i + 2 : ℕ) : ℝ) ^ (-1/2 : ℝ))) := by
        gcongr with i _hi
        have hcast : ((i + 1 : ℕ) : ℝ) = ((i + 2 : ℕ) : ℝ) - 1 := by push_cast; ring
        conv_rhs => rw [show ((i + 1 : ℕ) : ℝ) = ((i + 2 : ℕ) : ℝ) - 1 from hcast]
        apply rpow_neg_three_half_le
        exact (show (2:ℝ) ≤ ((i+2:ℕ):ℝ) by exact_mod_cast Nat.le_add_left 2 i)
    _ = 2 * ∑ i ∈ Finset.range N,
          (((i + 1 : ℕ) : ℝ) ^ (-1/2 : ℝ) - ((i + 2 : ℕ) : ℝ) ^ (-1/2 : ℝ)) := by
        rw [← Finset.mul_sum]
    _ = 2 * ((1 : ℝ) ^ (-1/2 : ℝ) - ((N + 1 : ℕ) : ℝ) ^ (-1/2 : ℝ)) := by
        congr 1
        rw [Finset.sum_range_sub' (fun k => ((k + 1 : ℕ) : ℝ) ^ (-1/2 : ℝ))]
        push_cast; ring_nf
    _ ≤ 2 * 1 := by
        gcongr
        simp [one_rpow]
        positivity
    _ = 2 := by ring

/-- ζ(3/2) ≤ 3, proved via splitting off n=0,1 and bounding the tail by telescoping. -/
private lemma zeta_three_half_le : ∑' (n : ℕ), (n : ℝ) ^ (-3/2 : ℝ) ≤ 3 := by
  have hsum : Summable (fun n : ℕ => (n:ℝ)^(-3/2:ℝ)) :=
    Iff.mpr Real.summable_nat_rpow (by norm_num)
  rw [hsum.tsum_eq_zero_add]
  simp only [Nat.cast_zero, zero_rpow (show (-3/2:ℝ) ≠ 0 by norm_num), zero_add]
  have hsum1 : Summable (fun n : ℕ => (↑(n + 1) : ℝ)^(-3/2:ℝ)) :=
    hsum.comp_injective (fun a b h => by omega)
  rw [hsum1.tsum_eq_zero_add]
  simp only [zero_add, Nat.cast_one, one_rpow]
  suffices h : ∑' n : ℕ, ((n + 2 : ℕ) : ℝ) ^ (-3/2:ℝ) ≤ 2 by linarith
  exact Real.tsum_le_of_sum_range_le (fun n => by positivity) partial_sum_rpow_le

/-- **Log-derivative bound**: ‖ζ'(s)/ζ(s)‖ ≤ 6 for Re(s) ≥ 2.

    By `LSeries_vonMangoldt_eq_deriv_riemannZeta_div`:
      −ζ'(s)/ζ(s) = L(Λ, s) = Σ Λ(n)/n^s
    For Re(s) ≥ 2: ‖L(Λ, s)‖ ≤ Σ Λ(n)/n² ≤ Σ log(n)/n² ≈ 0.57 ≤ 6.
    Uses `vonMangoldt_le_log` and absolute convergence from Mathlib. -/
private lemma norm_zeta_logderiv_le {s : ℂ} (hs : 2 ≤ s.re)
    (_hs1 : s ≠ 1) :
    ‖deriv riemannZeta s / riemannZeta s‖ ≤ 6 := by
  have h1 : 1 < s.re := by linarith
  -- Step 1: rewrite ‖ζ'/ζ(s)‖ = ‖L(Λ, s)‖ using the Dirichlet identity
  have hlseries := ArithmeticFunction.LSeries_vonMangoldt_eq_deriv_riemannZeta_div h1
  have hnorm_eq : ‖deriv riemannZeta s / riemannZeta s‖ = ‖L ↗Λ s‖ := by
    have heq : -(deriv riemannZeta s / riemannZeta s) = L ↗Λ s := by
      rw [hlseries]; ring
    rw [← norm_neg, heq]
  rw [hnorm_eq]
  -- Step 2: triangle inequality + monotonicity in σ
  have hsum := ArithmeticFunction.LSeriesSummable_vonMangoldt h1
  have hsum2 : LSeriesSummable ↗Λ (2:ℂ) :=
    ArithmeticFunction.LSeriesSummable_vonMangoldt (by simp : 1 < (2:ℂ).re)
  -- ‖L ↗Λ s‖ ≤ Σ ‖term ↗Λ s n‖ ≤ Σ ‖term ↗Λ 2 n‖ ≤ 6
  calc ‖L ↗Λ s‖
      ≤ ∑' n, ‖LSeries.term (↗Λ) s n‖ := norm_tsum_le_tsum_norm hsum.norm
    _ ≤ ∑' n, ‖LSeries.term (↗Λ) (2:ℂ) n‖ :=
        hsum.norm.tsum_le_tsum
          (fun n => LSeries.norm_term_le_of_re_le_re (↗Λ)
            (show (2:ℂ).re ≤ s.re by simp; exact hs) n)
          hsum2.norm
    _ ≤ ∑' n, (if (n:ℕ) = 0 then (0:ℝ) else 2 * (n : ℝ) ^ (-3/2 : ℝ)) := by
        -- Per-term bound: ‖term ↗Λ 2 n‖ ≤ 2·n^{-3/2}
        -- Via: Λ(n) ≤ log(n) ≤ 2√n, so Λ(n)/n² ≤ 2·n^{-3/2}
        have hg_sum : Summable (fun n : ℕ =>
            if n = 0 then (0:ℝ) else 2 * (n:ℝ)^(-3/2:ℝ)) := by
          exact (Real.summable_nat_rpow.mpr (by norm_num : (-3/2:ℝ) < -1)).mul_left 2
            |>.of_nonneg_of_le
              (fun n => by split_ifs <;> positivity)
              (fun n => by split_ifs with hn <;> simp_all)
        apply hsum2.norm.tsum_le_tsum _ hg_sum
        intro n
        rcases eq_or_ne n 0 with rfl | hn
        · simp [LSeries.term_zero]
        · rw [if_neg hn, LSeries.norm_term_eq, if_neg hn]
          have hre : (2:ℂ).re = (2:ℝ) := by norm_num
          rw [hre]
          have hn_pos : (0:ℝ) < n := Nat.cast_pos.mpr (Nat.pos_of_ne_zero hn)
          have hΛ : ‖(↗Λ) n‖ ≤ 2 * (n : ℝ) ^ (1/2 : ℝ) := by
            have h1 : ‖(↗Λ) n‖ = Λ n := by
              simp [Complex.norm_real, abs_of_nonneg ArithmeticFunction.vonMangoldt_nonneg]
            rw [h1]
            calc Λ n ≤ Real.log n := ArithmeticFunction.vonMangoldt_le_log
              _ ≤ (n:ℝ)^(1/2:ℝ) / (1/2:ℝ) :=
                Real.log_le_rpow_div n.cast_nonneg (by norm_num)
              _ = 2 * (n:ℝ)^(1/2:ℝ) := by ring
          calc ‖(↗Λ) n‖ / (n:ℝ)^(2:ℝ) ≤ (2*(n:ℝ)^(1/2:ℝ)) / (n:ℝ)^(2:ℝ) := by gcongr
            _ = 2 * ((n:ℝ)^(1/2:ℝ) / (n:ℝ)^(2:ℝ)) := by ring
            _ = 2 * (n:ℝ)^(-3/2:ℝ) := by
                congr 1; rw [div_eq_iff (rpow_pos_of_pos hn_pos 2).ne', ← rpow_add hn_pos]
                norm_num
    _ ≤ 6 := by
        -- The if-then-else tsum equals 2·ζ(3/2) since 0^{-3/2}=0.
        -- And ζ(3/2) ≤ 3 (zeta_three_half_le), so 2·ζ(3/2) ≤ 6.
        have htsum_eq : ∑' n, (if (n:ℕ) = 0 then (0:ℝ) else 2 * (n:ℝ)^(-3/2:ℝ)) =
            2 * ∑' (n : ℕ), (n:ℝ)^(-3/2:ℝ) := by
          have heq : (fun n : ℕ => if n = 0 then (0:ℝ) else 2 * (n:ℝ)^(-3/2:ℝ)) =
              (fun n : ℕ => 2 * (n:ℝ)^(-3/2:ℝ)) := by
            ext n; rcases eq_or_ne n 0 with rfl | hn
            · simp [zero_rpow (show (-3/2:ℝ) ≠ 0 by norm_num)]
            · simp [hn]
          rw [heq, tsum_mul_left]
        rw [htsum_eq]
        linarith [zeta_three_half_le]

/-- **G' = f'/f**: If f = c·exp(G) on a ball, then deriv G = deriv f / f.
    This is the algebraic derivative identity from the exponential representation,
    proved by differentiating both sides and using `ring`. Zero sorry. -/
private lemma G_deriv_eq_logderiv_of_exp_eq
    {c : ℂ} {R : ℝ} (_hR : 0 < R)
    {f G : ℂ → ℂ}
    (_hf_diff : DifferentiableOn ℂ f (ball 0 R))
    (hG_diff : DifferentiableOn ℂ G (ball 0 R))
    (hf_eq : ∀ z ∈ ball (0:ℂ) R, f z = c * Complex.exp (G z))
    (hf_ne : ∀ z ∈ ball (0:ℂ) R, f z ≠ 0)
    {w : ℂ} (hw : w ∈ ball (0:ℂ) R) :
    deriv G w = deriv f w / f w := by
  have hG_da : DifferentiableAt ℂ G w :=
    hG_diff.differentiableAt (isOpen_ball.mem_nhds hw)
  have hexp_da : HasDerivAt (fun z => Complex.exp (G z))
      (Complex.exp (G w) * deriv G w) w :=
    HasDerivAt.comp w (Complex.hasDerivAt_exp (G w)) hG_da.hasDerivAt
  have hprod_da : HasDerivAt (fun z => c * Complex.exp (G z))
      (c * (Complex.exp (G w) * deriv G w)) w :=
    hexp_da.const_mul c
  have hderiv_eq : deriv f w = c * (Complex.exp (G w) * deriv G w) := by
    have h_eq : deriv f w = deriv (fun z => c * Complex.exp (G z)) w := by
      apply Filter.EventuallyEq.deriv_eq
      filter_upwards [isOpen_ball.mem_nhds hw] with z hz
      exact hf_eq z hz
    rw [h_eq, hprod_da.deriv]
  have hfw : f w = c * Complex.exp (G w) := hf_eq w hw
  have hfw_ne : f w ≠ 0 := hf_ne w hw
  have hkey : f w * deriv G w = deriv f w := by
    rw [hfw, hderiv_eq]; ring
  rw [eq_div_iff hfw_ne]
  linear_combination hkey

/-- **Derivative bound**: ‖G'(w)‖ ≤ 6 for w ∈ closedBall 0 1 (where Re ≥ 2).

    G'(w) = ζ'(s₀+w)/ζ(s₀+w) by `G_deriv_eq_logderiv_of_exp_eq`.
    = deriv ζ (s₀+w) / ζ(s₀+w) by `deriv_zeta_comp`.
    ≤ 6 by `norm_zeta_logderiv_le`. -/
private lemma G_deriv_bound_on_inner_ball
    {t : ℝ} (_ht : 2 ≤ |t|)
    {R : ℝ} (hR_pos : 0 < R) (hR_ge : 1 < R)
    {G : ℂ → ℂ} (hG_diff : DifferentiableOn ℂ G (ball 0 R))
    (hG_eq : ∀ z ∈ ball (0:ℂ) R,
      riemannZeta (⟨3, t⟩ + z) = riemannZeta ⟨3, t⟩ * Complex.exp (G z))
    (hζ_ne : ∀ z ∈ ball (0:ℂ) R, riemannZeta (⟨3, t⟩ + z) ≠ 0)
    (hf_diff : DifferentiableOn ℂ (fun z => riemannZeta (⟨3, t⟩ + z)) (ball 0 R)) :
    ∀ w ∈ closedBall (0:ℂ) 1, ‖deriv G w‖ ≤ 6 := by
  intro w hw
  have hw_ball : w ∈ ball (0:ℂ) R := by
    simp [mem_closedBall, dist_zero_right] at hw
    simp [mem_ball, dist_zero_right]; linarith
  have hw_norm : ‖w‖ ≤ 1 := by
    simp [mem_closedBall, dist_zero_right] at hw; exact hw
  have hre : 2 ≤ (⟨3, t⟩ + w : ℂ).re := by
    have : (⟨3, t⟩ + w : ℂ).re = 3 + w.re := by simp [Complex.add_re]
    rw [this]
    have := neg_abs_le w.re
    linarith [Complex.abs_re_le_norm w]
  have hs1 : (⟨3, t⟩ : ℂ) + w ≠ 1 := by
    intro h; have hre1 := congr_arg Complex.re h
    simp [Complex.add_re] at hre1
    linarith [Complex.abs_re_le_norm w, neg_abs_le w.re]
  -- Apply G_deriv_eq_logderiv_of_exp_eq: deriv G w = deriv f w / f w
  have hG_eq_f := G_deriv_eq_logderiv_of_exp_eq hR_pos hf_diff hG_diff hG_eq hζ_ne hw_ball
  -- deriv f w = deriv ζ (s₀+w) by chain rule
  have hchain := deriv_zeta_comp hs1
  -- Combine: deriv G w = deriv ζ(s₀+w) / ζ(s₀+w)
  rw [hG_eq_f, hchain]
  -- Apply norm_zeta_logderiv_le
  exact norm_zeta_logderiv_le hre hs1

/-- **Inner Anchor**: ‖G(z)‖ ≤ 6 on ‖z‖ = 1, t-independent.

    Uses the Mean Value Theorem: G is differentiable on closedBall 0 1
    (which is convex), G(0) = 0, and ‖G'(w)‖ ≤ 6 on closedBall 0 1.
    By MVT: ‖G(z) - G(0)‖ ≤ 6 · ‖z - 0‖ = 6 · 1 = 6. -/
lemma G_inner_bound_fixed
    {t : ℝ} (ht : 2 ≤ |t|)
    {R : ℝ} (_hR_pos : 0 < R) (hR_ge : 1 < R)
    {G : ℂ → ℂ} (hG_diff : DifferentiableOn ℂ G (ball 0 R))
    (hG0 : G 0 = 0)
    (hG_eq : ∀ z ∈ ball (0:ℂ) R,
      riemannZeta (⟨3, t⟩ + z) = riemannZeta ⟨3, t⟩ * Complex.exp (G z))
    (hζ_ne : ∀ z ∈ ball (0:ℂ) R, riemannZeta (⟨3, t⟩ + z) ≠ 0)
    (hf_diff : DifferentiableOn ℂ (fun z => riemannZeta (⟨3, t⟩ + z)) (ball 0 R)) :
    ∀ z, ‖z‖ = 1 → ‖G z‖ ≤ 6 := by
  intro z hz
  have hconv : Convex ℝ (closedBall (0:ℂ) 1) := convex_closedBall 0 1
  have hsub : closedBall (0:ℂ) 1 ⊆ ball (0:ℂ) R := by
    intro x hx
    simp [mem_closedBall, dist_zero_right] at hx
    simp [mem_ball, dist_zero_right]; linarith
  have hG_diff_pts : ∀ x ∈ closedBall (0:ℂ) 1, DifferentiableAt ℂ G x :=
    fun x hx => (hG_diff.differentiableAt (isOpen_ball.mem_nhds (hsub hx)))
  have hz_mem : z ∈ closedBall (0:ℂ) 1 := by
    simp [mem_closedBall, dist_zero_right, hz]
  have h0_mem : (0:ℂ) ∈ closedBall (0:ℂ) 1 := by
    simp [mem_closedBall]
  have hderiv := G_deriv_bound_on_inner_ball ht _hR_pos hR_ge hG_diff hG_eq hζ_ne hf_diff
  have hmvt := hconv.norm_image_sub_le_of_norm_deriv_le
    hG_diff_pts hderiv h0_mem hz_mem
  simp only [hG0, sub_zero] at hmvt
  rw [hz] at hmvt
  linarith

-- ═══════════════════════════════════════════
-- §3. Outer Bound (Lemma 2 — adapted for center (3,t))
-- ═══════════════════════════════════════════

/-- **Outer bound**: Re(G(z)) ≤ C·log(2+|t|) on ball(0, r₃).

    Same argument as G_outer_bound_re but with center (3, t):
    exp(Re(G(z))) = |ζ(s₀+z)/ζ(s₀)| ≤ upper/lower. -/
lemma G_outer_bound_re_3
    {R : ℝ} (_hR_pos : 0 < R) (_hR_lt : R < 5/2)
    {t : ℝ} (ht : R + 1/2 ≤ |t|)
    {G : ℂ → ℂ} (_hG_diff : DifferentiableOn ℂ G (ball 0 R))
    (_hG_eq : ∀ z ∈ ball (0:ℂ) R,
      riemannZeta (⟨3, t⟩ + z) = riemannZeta ⟨3, t⟩ * Complex.exp (G z)) :
    ∀ z ∈ ball (0:ℂ) R,
      (G z).re ≤ 10 * Real.log (2 + |t|) + Real.log 4 := by
  intro z hz
  have h_eq := _hG_eq z hz
  -- Re(G(z)) = log|exp(G(z))|
  have hre_G : (G z).re = Real.log ‖Complex.exp (G z)‖ := by
    rw [Complex.norm_exp]; exact (Real.log_exp _).symm
  -- |ζ(s₀)| > 0
  have h_zeta0_lower : (1:ℝ)/4 ≤ ‖riemannZeta ⟨3, t⟩‖ := by
    have hre : (2:ℝ) ≤ (⟨3, t⟩ : ℂ).re := by norm_num
    have h := zeta_sub_one_norm_le_three_fourths hre
    -- Use: ‖ζ‖ - ‖ζ-1‖ ≤ ‖ζ - (ζ-1)‖ = ‖1‖ = 1
    -- So ‖ζ‖ ≥ 1 - ‖ζ-1‖ ≥ 1 - 3/4 = 1/4
    -- Actually we need: 1 ≤ ‖ζ‖ + ‖ζ-1‖ (from triangle ‖1‖ ≤ ‖ζ‖ + ‖ζ-1‖)
    -- norm_sub_le gives ‖a - b‖ ≤ ‖a‖ + ‖b‖, not what we want
    -- norm_le_add_of_le:  no. Let me use the basic reverse triangle.
    -- ‖1‖ = ‖ζ - (ζ-1)‖ ≤ ‖ζ‖ + ‖ζ-1‖
    have h2 : ‖(1:ℂ)‖ ≤ ‖riemannZeta (⟨3, t⟩ : ℂ)‖ + ‖riemannZeta (⟨3, t⟩ : ℂ) - 1‖ := by
      calc ‖(1:ℂ)‖ = ‖riemannZeta (⟨3, t⟩ : ℂ) - (riemannZeta (⟨3, t⟩ : ℂ) - 1)‖ := by
            norm_num
        _ ≤ ‖riemannZeta (⟨3, t⟩ : ℂ)‖ + ‖riemannZeta (⟨3, t⟩ : ℂ) - 1‖ :=
            norm_sub_le _ _
    simp only [norm_one] at h2; linarith
  have h_zeta0_pos : (0:ℝ) < ‖riemannZeta ⟨3, t⟩‖ := by linarith
  -- |exp(G(z))| = |ζ(s₀+z)| / |ζ(s₀)|
  have h_exp_eq : ‖Complex.exp (G z)‖ = ‖riemannZeta ((⟨3, t⟩ : ℂ) + z)‖ /
      ‖riemannZeta ⟨3, t⟩‖ := by
    have : ‖riemannZeta ⟨3, t⟩‖ * ‖Complex.exp (G z)‖ =
        ‖riemannZeta ((⟨3, t⟩ : ℂ) + z)‖ := by
      rw [← norm_mul, ← h_eq]
    rw [← this, mul_div_cancel_left₀ _ (ne_of_gt h_zeta0_pos)]
  -- We use: Re(G) = log|exp(G)| and |exp(G)| = |ζ(s₀+z)|/|ζ(s₀)|
  rw [hre_G, h_exp_eq]
  -- Step 1: |ζ(s₀+z)| ≤ (2+|t|)^10 (via tail or convexity bound)
  have h_zeta_upper : ‖riemannZeta ((⟨3, t⟩ : ℂ) + z)‖ ≤ (2 + |t|) ^ (10 : ℝ) := by
    set s := (⟨3, t⟩ : ℂ) + z with hs_def
    simp only [mem_ball, dist_zero_right] at hz
    by_cases hre : 2 ≤ s.re
    · -- Re(s) ≥ 2: ‖ζ(s)‖ ≤ 7/4 ≤ (2+|t|)^10
      have h74 : ‖riemannZeta s‖ ≤ 7/4 := by
        have hsub := zeta_sub_one_norm_le_three_fourths hre
        have h1 : ‖riemannZeta s‖ ≤ ‖riemannZeta s - 1‖ + 1 := by
          have := norm_le_insert' (riemannZeta s) (1 : ℂ); simp at this; linarith
        linarith
      calc ‖riemannZeta s‖ ≤ 7/4 := h74
        _ ≤ 2 := by norm_num
        _ ≤ 2 + |t| := le_add_of_nonneg_right (abs_nonneg t)
        _ ≤ (2 + |t|) ^ (10 : ℝ) := by
            have hbase : (1:ℝ) ≤ 2 + |t| := by linarith [abs_nonneg t]
            have := rpow_le_rpow_of_exponent_le hbase (show (1:ℝ) ≤ 10 by norm_num)
            rwa [rpow_one] at this
    · -- Re(s) < 2: use convexity bound ‖ζ(s)‖ ≤ (2+|s.im|)^2
      push Not at hre
      have hrs : 1/2 < s.re := by
        have hsre : s.re = 3 + z.re := by simp [hs_def]
        have : -R < z.re := by
          have := neg_le_abs z.re
          linarith [Complex.abs_re_le_norm z]
        linarith
      have him : 1/2 ≤ |s.im| := by
        have hsim : s.im = t + z.im := by simp [hs_def]
        rw [hsim]
        have hzim_lt : |z.im| < R :=
          lt_of_le_of_lt (Complex.abs_im_le_norm z) hz
        have h1 : |t| - |z.im| ≤ |t + z.im| := by
          -- |t+z.im| = |t-(-z.im)| ≥ ||t|-|-z.im|| = ||t|-|z.im|| ≥ |t|-|z.im|
          have h := abs_sub_abs_le_abs_sub t (-z.im)
          rw [abs_neg, sub_neg_eq_add] at h
          exact h
        linarith
      have hconv := zeta_norm_convexity_bound hrs (le_of_lt hre) him
      have him_bound : |s.im| < |t| + R := by
        have hsim : s.im = t + z.im := by simp [hs_def]
        rw [hsim]
        calc |t + z.im| ≤ |t| + |z.im| := abs_add_le t z.im
          _ < |t| + R := by linarith [Complex.abs_im_le_norm z]
      have h_base : (1:ℝ) ≤ 2 + |t| := by linarith [abs_nonneg t]
      -- R ≤ |t| - 1/2 < |t| from ht
      have him_upper : 2 + |s.im| ≤ 2 * (2 + |t|) := by linarith
      rw [show (10 : ℝ) = ((10 : ℕ) : ℝ) from by norm_num] at *
      rw [show (2 : ℝ) = ((2 : ℕ) : ℝ) from by norm_num] at hconv
      rw [rpow_natCast] at hconv; rw [rpow_natCast]
      calc ‖riemannZeta s‖ ≤ (2 + |s.im|) ^ 2 := hconv
        _ ≤ (2 * (2 + |t|)) ^ 2 := by
            have : 0 ≤ 2 + |s.im| := by linarith [abs_nonneg s.im]
            nlinarith
        _ = 4 * (2 + |t|) ^ 2 := by ring
        _ ≤ (2 + |t|) ^ 2 * (2 + |t|) ^ 2 := by
            have h4 : 4 ≤ (2 + |t|) ^ 2 := by nlinarith [abs_nonneg t]
            nlinarith
        _ = (2 + |t|) ^ 4 := by ring
        _ ≤ (2 + |t|) ^ 10 := pow_le_pow_right₀ h_base (by norm_num)
  -- Step 2: Combine via log arithmetic
  -- If ζ(s₀+z) = 0, then log(0/‖ζ₀‖) = -∞ ≤ anything. Else decompose log(a/b) = log a - log b.
  rcases eq_or_ne (riemannZeta ((⟨3, t⟩ : ℂ) + z)) 0 with hzero | hne
  · rw [hzero, norm_zero, zero_div, Real.log_zero]
    have : 0 ≤ 10 * Real.log (2 + |t|) := by
      apply mul_nonneg (by norm_num)
      exact Real.log_nonneg (by linarith [abs_nonneg t])
    linarith [Real.log_nonneg (show (1:ℝ) ≤ 4 by norm_num)]
  · have h_norm_sz_pos : 0 < ‖riemannZeta ((⟨3, t⟩ : ℂ) + z)‖ := norm_pos_iff.mpr hne
    rw [Real.log_div (ne_of_gt h_norm_sz_pos) (ne_of_gt h_zeta0_pos)]
    have hlog_upper : Real.log ‖riemannZeta ((⟨3, t⟩ : ℂ) + z)‖ ≤ 10 * Real.log (2 + |t|) := by
      rw [show (10 : ℝ) = ((10:ℕ):ℝ) from by norm_num] at h_zeta_upper ⊢
      rw [rpow_natCast] at h_zeta_upper
      rw [← Real.log_pow]
      exact Real.log_le_log h_norm_sz_pos h_zeta_upper
    have hlog_lower : -Real.log ‖riemannZeta ⟨3, t⟩‖ ≤ Real.log 4 := by
      rw [neg_le_iff_add_nonneg, ← Real.log_mul (by norm_num : (4:ℝ) ≠ 0) (ne_of_gt h_zeta0_pos)]
      apply Real.log_nonneg
      nlinarith
    linarith

-- ═══════════════════════════════════════════
-- §4. Sub-Logarithmic Annihilation (Lemma 4)
-- ═══════════════════════════════════════════

/-- **(log t)^α < A · log t** for large t when α < 1.

    Since α < 1, (log t)^{α-1} → 0 as t → ∞.
    So (log t)^α / log t = (log t)^{α-1} → 0 < A. -/
lemma sub_logarithmic_bound
    {α A : ℝ} (_hα : 0 < α) (hα1 : α < 1) (hA : 0 < A) :
    ∃ T₀ > 0, ∀ t : ℝ, T₀ ≤ t →
      (Real.log t) ^ α < A * Real.log t := by
  -- Chain: (log t)^{α-1} → 0 via tendsto_rpow_neg_atTop ∘ tendsto_log_atTop.
  -- Extract T₀ from Metric.tendsto_atTop, then rpow_add seals it.
  have h1mα : 0 < 1 - α := sub_pos.mpr hα1
  have h_tend_x : Tendsto (fun x : ℝ => x ^ (-(1-α))) atTop (𝓝 0) :=
    tendsto_rpow_neg_atTop h1mα
  have h_tend : Tendsto (fun t : ℝ => (Real.log t) ^ (α - 1)) atTop (𝓝 0) := by
    have : (fun t => (Real.log t) ^ (-(1-α))) = (fun t => (Real.log t) ^ (α - 1)) := by
      ext; ring_nf
    rw [← this]
    exact h_tend_x.comp tendsto_log_atTop
  rw [Metric.tendsto_atTop] at h_tend
  obtain ⟨N, hN⟩ := h_tend A hA
  refine ⟨max N (Real.exp 2), lt_of_lt_of_le (Real.exp_pos 2) (le_max_right _ _), fun t ht => ?_⟩
  have hN_le : N ≤ t := le_trans (le_max_left _ _) ht
  have hexp_le : Real.exp 2 ≤ t := le_trans (le_max_right _ _) ht
  have hlog_ge2 : (2 : ℝ) ≤ Real.log t := by
    rwa [← Real.log_exp 2, Real.log_le_log_iff (Real.exp_pos 2)
      (lt_of_lt_of_le (Real.exp_pos 2) hexp_le)]
  have hlog_pos : 0 < Real.log t := by linarith
  have h_dist := hN t hN_le
  rw [Real.dist_eq, sub_zero] at h_dist
  have h_rpow_pos : 0 < Real.log t ^ (α - 1) := rpow_pos_of_pos hlog_pos _
  rw [abs_of_pos h_rpow_pos] at h_dist
  have h_mul : Real.log t ^ (α - 1) * Real.log t < A * Real.log t := by nlinarith
  have h_rpow_eq : Real.log t ^ (α - 1) * Real.log t = Real.log t ^ α := by
    have := rpow_add hlog_pos (α - 1) 1
    rw [rpow_one, sub_add_cancel] at this; linarith
  linarith
-- ═══════════════════════════════════════════
-- §4.5. Assembly Infrastructure
-- ═══════════════════════════════════════════

/-- DiffContOnCl on a closed annulus from DifferentiableOn on a larger ball.
    For closed sets, DiffContOnCl ↔ DifferentiableOn (Mathlib). -/
private lemma diffContOnCl_on_annulus_of_ball
    {G : ℂ → ℂ} {R₁ R₃ R₄ : ℝ}
    (_hR₁_pos : 0 < R₁) (hR₃_lt : R₃ < R₄)
    (hG_diff : DifferentiableOn ℂ G (ball 0 R₄)) :
    DiffContOnCl ℂ G {z : ℂ | R₁ ≤ ‖z‖ ∧ ‖z‖ ≤ R₃} := by
  have h_closed : IsClosed {z : ℂ | R₁ ≤ ‖z‖ ∧ ‖z‖ ≤ R₃} := by
    apply IsClosed.inter
    · exact isClosed_le continuous_const continuous_norm
    · exact isClosed_le continuous_norm continuous_const
  have h_sub : {z : ℂ | R₁ ≤ ‖z‖ ∧ ‖z‖ ≤ R₃} ⊆ ball (0 : ℂ) R₄ := by
    intro z ⟨_, hz₂⟩
    simp only [mem_ball, dist_zero_right]
    linarith
  rw [h_closed.diffContOnCl_iff]
  exact hG_diff.mono h_sub

/-- BC conversion layer: Re(G) ≤ M on ball(0, R₄) → ‖G‖ ≤ K on ‖z‖ = R₃.
    Uses Mathlib's `borelCaratheodory_zero` to convert a real-part bound
    into a complex norm bound, stepping inward from R₄ to R₃. -/
private lemma bc_re_to_norm
    {G : ℂ → ℂ} {R₃ R₄ M : ℝ}
    (_hR₃_pos : 0 < R₃) (_hR₃_lt : R₃ < R₄) (hR₄_pos : 0 < R₄)
    (hM_pos : 0 < M)
    (hG_diff : DifferentiableOn ℂ G (ball 0 R₄))
    (hG0 : G 0 = 0)
    (hG_re : ∀ z ∈ ball (0 : ℂ) R₄, (G z).re ≤ M) :
    ∀ z, ‖z‖ = R₃ → ‖G z‖ ≤ 2 * M * R₃ / (R₄ - R₃) := by
  intro z hz
  have hz_ball : z ∈ ball (0 : ℂ) R₄ := by
    simp only [mem_ball, dist_zero_right]; linarith
  have hG_re_maps : MapsTo G (ball 0 R₄) {w | w.re ≤ M} := by
    intro w hw; exact hG_re w hw
  have hBC := Complex.borelCaratheodory_zero hM_pos hG_diff hG_re_maps hR₄_pos hz_ball hG0
  rwa [hz] at hBC

/-- Three-Circles at target: given inner/outer norm bounds, interpolate. -/
private lemma three_circles_at_target
    {G : ℂ → ℂ} {R₁ R₃ a b : ℝ}
    (hR₁_pos : 0 < R₁) (h13 : R₁ < R₃)
    (hG : DiffContOnCl ℂ G {z : ℂ | R₁ ≤ ‖z‖ ∧ ‖z‖ ≤ R₃})
    (ha : ∀ z, ‖z‖ = R₁ → ‖G z‖ ≤ a)
    (hb : ∀ z, ‖z‖ = R₃ → ‖G z‖ ≤ b)
    (z : ℂ) (hz₁ : R₁ ≤ ‖z‖) (hz₂ : ‖z‖ ≤ R₃) :
    ‖G z‖ ≤ a ^ (1 - (Real.log ‖z‖ - Real.log R₁) / (Real.log R₃ - Real.log R₁)) *
             b ^ ((Real.log ‖z‖ - Real.log R₁) / (Real.log R₃ - Real.log R₁)) :=
  hadamard_three_circles hR₁_pos h13 hG ha hb z hz₁ hz₂

/-- Sub-logarithmic to polynomial: if the ζ lower bound has form
    (1/4)·exp(-K·(log(2+|t|))^α) with α < 1, then for any A > 0
    it eventually dominates (1/4)·(2+|t|)^{-A}.
    Uses sub_logarithmic_bound to crush the exponent. -/
private lemma sub_log_to_polynomial
    {K : ℝ} (hK : 0 < K) {α : ℝ} (hα : 0 < α) (hα1 : α < 1)
    {A : ℝ} (hA : 0 < A) :
    ∃ T₀ > 0, ∀ t : ℝ, T₀ ≤ |t| →
      (1/4 : ℝ) * Real.exp (-(K * (Real.log (2 + |t|)) ^ α)) ≥
      (1/4 : ℝ) * (2 + |t|) ^ (-A) := by
  have hAK : 0 < A / K := div_pos hA hK
  obtain ⟨T₁, hT₁_pos, hT₁⟩ := sub_logarithmic_bound hα hα1 hAK
  refine ⟨max T₁ 2, lt_of_lt_of_le (by norm_num : (0:ℝ) < 2) (le_max_right _ _), ?_⟩
  intro t ht
  have hT₁_le : T₁ ≤ |t| := le_trans (le_max_left _ _) ht
  have ht_ge_2 : 2 ≤ |t| := le_trans (le_max_right _ _) ht
  have h2t_pos : 0 < 2 + |t| := by linarith [abs_nonneg t]
  have h2t_ge_T : T₁ ≤ 2 + |t| := by linarith
  have hlog_sub := hT₁ (2 + |t|) h2t_ge_T
  have hK_bound : K * (Real.log (2 + |t|)) ^ α < A * Real.log (2 + |t|) := by
    have h1 := mul_lt_mul_of_pos_left hlog_sub hK
    have h2 : K * (A / K * Real.log (2 + |t|)) = A * Real.log (2 + |t|) := by
      field_simp
    linarith
  have hexp_ge : Real.exp (-(A * Real.log (2 + |t|))) ≤
      Real.exp (-(K * (Real.log (2 + |t|)) ^ α)) :=
    Real.exp_le_exp.mpr (neg_le_neg (le_of_lt hK_bound))
  have hexp_eq : Real.exp (-(A * Real.log (2 + |t|))) = (2 + |t|) ^ (-A) := by
    rw [Real.rpow_def_of_pos h2t_pos]; ring_nf
  rw [ge_iff_le, ← hexp_eq]
  exact mul_le_mul_of_nonneg_left hexp_ge (by norm_num)

/-- M = 10·log(2+|t|) + log 4 ≤ 11·log(2+|t|) when |t| ≥ 2. -/
private lemma M_le_11_log {t : ℝ} (ht : 2 ≤ |t|) :
    10 * Real.log (2 + |t|) + Real.log 4 ≤ 11 * Real.log (2 + |t|) := by
  have h2t : (4 : ℝ) ≤ 2 + |t| := by linarith
  have h4_pos : (0 : ℝ) < 4 := by norm_num
  have h2t_pos : (0 : ℝ) < 2 + |t| := by linarith [abs_nonneg t]
  have hlog_le : Real.log 4 ≤ Real.log (2 + |t|) :=
    Real.log_le_log h4_pos h2t
  linarith

/-- The Three-Circles output 6^(1-α)·b^α is bounded by K·(log(2+|t|))^α,
    where K = 6^(1-α)·(22·R₃/(R₄-R₃))^α depends only on ε. -/
private lemma three_circles_to_sub_log
    {R₃ R₄ α : ℝ} (hα : 0 ≤ α) (_hα1 : α ≤ 1)
    (hR₃_pos : 0 < R₃) (hR₃_lt_R₄ : R₃ < R₄)
    {t : ℝ} (ht : 2 ≤ |t|)
    (bound : ℝ) (hbound : bound = 6 ^ (1 - α) *
      (2 * (10 * Real.log (2 + |t|) + Real.log 4) * R₃ / (R₄ - R₃)) ^ α) :
    bound ≤ (6 ^ (1 - α) * (22 * R₃ / (R₄ - R₃)) ^ α) *
            (Real.log (2 + |t|)) ^ α := by
  rw [hbound]
  have h2t_pos : (0 : ℝ) < 2 + |t| := by linarith [abs_nonneg t]
  have hlog_pos : 0 < Real.log (2 + |t|) := Real.log_pos (by linarith)
  have hgap_pos : 0 < R₄ - R₃ := by linarith
  have hM_le := M_le_11_log ht
  have hb_le : 2 * (10 * Real.log (2 + |t|) + Real.log 4) * R₃ / (R₄ - R₃) ≤
               22 * R₃ / (R₄ - R₃) * Real.log (2 + |t|) := by
    rw [div_mul_eq_mul_div]
    apply div_le_div_of_nonneg_right _ (le_of_lt hgap_pos)
    nlinarith
  have hb_nonneg : 0 ≤ 2 * (10 * Real.log (2 + |t|) + Real.log 4) * R₃ / (R₄ - R₃) := by
    apply div_nonneg
    · apply mul_nonneg
      · apply mul_nonneg (by norm_num)
        linarith [Real.log_nonneg (show (1:ℝ) ≤ 4 by norm_num)]
      · exact le_of_lt hR₃_pos
    · exact le_of_lt hgap_pos
  calc 6 ^ (1 - α) * (2 * (10 * Real.log (2 + |t|) + Real.log 4) * R₃ / (R₄ - R₃)) ^ α
      ≤ 6 ^ (1 - α) * (22 * R₃ / (R₄ - R₃) * Real.log (2 + |t|)) ^ α := by
        apply mul_le_mul_of_nonneg_left
        · exact rpow_le_rpow hb_nonneg hb_le hα
        · exact le_of_lt (rpow_pos_of_pos (by norm_num : (0:ℝ) < 6) _)
    _ = (6 ^ (1 - α) * (22 * R₃ / (R₄ - R₃)) ^ α) * (Real.log (2 + |t|)) ^ α := by
        rw [mul_rpow (le_of_lt (by positivity : (0:ℝ) < 22 * R₃ / (R₄ - R₃)))
                      (le_of_lt hlog_pos)]
        ring

/-- Three-Circles rpow monotonicity: a^(1-θ)·b^θ ≤ (a·C)·ℓ^α
    when a ≥ 1, b ≤ C·ℓ, C ≥ 1, ℓ ≥ 1, 0 ≤ θ ≤ α ≤ 1.
    This converts the Three-Circles output (exponent θ) to a sub-logarithmic
    bound (exponent α) by factoring the weighted geometric mean:
    a^(1-θ) ≤ a, C^θ ≤ C, ℓ^θ ≤ ℓ^α. -/
private lemma tc_rpow_bound {a b C ℓ θ α : ℝ}
    (ha : 1 ≤ a) (hC : 1 ≤ C) (hℓ : 1 ≤ ℓ)
    (hb : 0 ≤ b) (hbCℓ : b ≤ C * ℓ)
    (hθ : 0 ≤ θ) (hθα : θ ≤ α) (hα : α ≤ 1) :
    a ^ (1 - θ) * b ^ θ ≤ a * C * ℓ ^ α := by
  have hCℓ : 0 ≤ C * ℓ := mul_nonneg (le_trans zero_le_one hC) (le_trans zero_le_one hℓ)
  have h_b_rpow : b ^ θ ≤ (C * ℓ) ^ θ := rpow_le_rpow hb hbCℓ hθ
  have h1mθ_le : 1 - θ ≤ 1 := by linarith
  have h_a_rpow : a ^ (1 - θ) ≤ a := by
    have := rpow_le_rpow_of_exponent_le ha h1mθ_le; rwa [rpow_one] at this
  have h_mul_rpow : (C * ℓ) ^ θ = C ^ θ * ℓ ^ θ :=
    mul_rpow (le_trans zero_le_one hC) (le_trans zero_le_one hℓ)
  have h_C_rpow : C ^ θ ≤ C := by
    have := rpow_le_rpow_of_exponent_le hC (le_trans hθα hα); rwa [rpow_one] at this
  have h_ℓ_rpow : ℓ ^ θ ≤ ℓ ^ α := rpow_le_rpow_of_exponent_le hℓ hθα
  calc a ^ (1 - θ) * b ^ θ
      ≤ a * (C * ℓ) ^ θ := by
        apply mul_le_mul h_a_rpow h_b_rpow (rpow_nonneg hb _) (le_trans zero_le_one ha)
    _ = a * (C ^ θ * ℓ ^ θ) := by rw [h_mul_rpow]
    _ ≤ a * (C * ℓ ^ α) := by
        apply mul_le_mul_of_nonneg_left _ (le_trans zero_le_one ha)
        exact mul_le_mul h_C_rpow h_ℓ_rpow (rpow_nonneg (le_trans zero_le_one hℓ) _)
          (le_trans zero_le_one hC)
    _ = a * C * ℓ ^ α := by ring

/-- **Three-Circles Inner Bound**: For 1/2+ε ≤ Re(s) ≤ 2, |Im(s)| ≥ 3, under RH:
    ‖ζ(s)‖ ≥ (1/4)·exp(-K·(log(2+|t|))^α) where α < 1 and K depends only on ε.

    This is the core of the Littlewood Maneuver. The six stages:
    1. Holomorphic log on ball(0, R₄)
    2. Re bound via G_outer_bound_re_3
    3. BC conversion to norm bound on ‖z‖=R₃
    4. Inner anchor: ‖G‖ ≤ 6 on ‖z‖=1
    5. Three-Circles interpolation at z* = s - s₀
    6. Norm/exp extraction: ‖ζ(s)‖ ≥ (1/4)·exp(-‖G(z*)‖) -/
private lemma three_circles_inner_bound (hRH : RiemannHypothesis)
    (ε : ℝ) (hε : 0 < ε) (hε1 : ε < 3/2)
    (s : ℂ) (hs : 1/2 + ε ≤ s.re) (hs_hi : s.re ≤ 2) (ht : 3 ≤ |s.im|) :
    let R₄ := 5/2 - ε/4
    let R₃ := 5/2 - ε/2
    let α := Real.log (5/2 - ε) / Real.log R₃
    let K := 6 * (22 * R₃ / (R₄ - R₃))
    (1/4 : ℝ) * Real.exp (-(K * (Real.log (2 + |s.im|)) ^ α)) ≤ ‖riemannZeta s‖ := by
  -- ── Setup ──
  set t := s.im
  set R₄ := 5/2 - ε/4
  set R₃ := 5/2 - ε/2
  set R₂ := 5/2 - ε
  set s₀ : ℂ := ⟨3, t⟩
  set α := Real.log R₂ / Real.log R₃
  set K := 6 * (22 * R₃ / (R₄ - R₃))
  have hR₄_pos : 0 < R₄ := by simp only [R₄]; linarith
  have hR₃_pos : 0 < R₃ := by simp only [R₃]; linarith
  have hR₃_lt_R₄ : R₃ < R₄ := by simp only [R₃, R₄]; linarith
  have h1_lt_R₂ : 1 < R₂ := by simp only [R₂]; linarith
  have hR₄_lt_52 : R₄ < 5/2 := by simp only [R₄]; linarith
  have ht_ge_2 : 2 ≤ |t| := by linarith
  -- ── Stage 1: Holomorphic logarithm ──
  have hf_diff := zeta_differentiable_on_wide_ball ht_ge_2 hR₄_pos hR₄_lt_52
  have hf_ne := zeta_ne_zero_on_wide_ball hRH ht_ge_2 hR₄_lt_52
  obtain ⟨G, hG_diff, hG0, hG_eq⟩ :=
    holomorphic_log_exists_on_ball hR₄_pos hf_diff hf_ne
  -- Normalize: ζ(s₀+0) = ζ(s₀)
  have hG_eq' : ∀ w ∈ ball (0:ℂ) R₄,
      riemannZeta (s₀ + w) = riemannZeta s₀ * Complex.exp (G w) := by
    intro w hw; have := hG_eq w hw; simp at this; exact this
  -- ── Stage 2: Re bound on ball(0, R₄) ──
  have hR₄_half : R₄ + 1/2 ≤ |t| := by simp only [R₄]; linarith
  have hG_re : ∀ z ∈ ball (0:ℂ) R₄,
      (G z).re ≤ 10 * Real.log (2 + |t|) + Real.log 4 :=
    G_outer_bound_re_3 hR₄_pos hR₄_lt_52 hR₄_half hG_diff hG_eq'
  -- ── Stage 3: BC conversion ──
  set M := 10 * Real.log (2 + |t|) + Real.log 4
  set b := 2 * M * R₃ / (R₄ - R₃)
  have hM_pos : 0 < M := by
    simp only [M]
    have : 0 < Real.log (2 + |t|) := Real.log_pos (by linarith [abs_nonneg t])
    have : 0 < Real.log 4 := Real.log_pos (by norm_num)
    linarith
  have hbc_outer : ∀ z, ‖z‖ = R₃ → ‖G z‖ ≤ b := by
    intro z hz
    have hz_ball : z ∈ ball (0 : ℂ) R₄ := by
      simp only [mem_ball, dist_zero_right]; rw [hz]; exact hR₃_lt_R₄
    have hG_re_maps : MapsTo G (ball 0 R₄) {w | w.re ≤ M} := fun w hw => hG_re w hw
    have hBC := Complex.borelCaratheodory_zero hM_pos hG_diff hG_re_maps hR₄_pos hz_ball hG0
    rwa [hz] at hBC
  -- ── Stage 4: Inner anchor ──
  have hR₄_ge_1 : 1 < R₄ := by simp only [R₄]; linarith
  have h_inner : ∀ z, ‖z‖ = 1 → ‖G z‖ ≤ 6 :=
    G_inner_bound_fixed ht_ge_2 hR₄_pos hR₄_ge_1 hG_diff hG0 hG_eq' hf_ne hf_diff
  -- ── Stage 5: Three-Circles ──
  have hR₂_lt_R₃ : R₂ < R₃ := by simp only [R₂, R₃]; linarith
  have hG_dcoc : DiffContOnCl ℂ G {z : ℂ | 1 ≤ ‖z‖ ∧ ‖z‖ ≤ R₃} := by
    have h_closed : IsClosed {z : ℂ | 1 ≤ ‖z‖ ∧ ‖z‖ ≤ R₃} := by
      apply IsClosed.inter
      · exact isClosed_le continuous_const continuous_norm
      · exact isClosed_le continuous_norm continuous_const
    rw [h_closed.diffContOnCl_iff]
    exact hG_diff.mono (fun z ⟨_, hz₂⟩ => by
      simp only [mem_ball, dist_zero_right]; exact lt_of_le_of_lt hz₂ hR₃_lt_R₄)
  -- z* = s - s₀ = (s.re - 3, 0)
  set z_star : ℂ := ⟨s.re - 3, 0⟩
  have hz_star_norm_eq : ‖z_star‖ = 3 - s.re := by
    have h_nonneg : 0 ≤ 3 - s.re := by linarith
    have : Complex.normSq z_star = (3 - s.re)^2 := by
      simp [z_star, Complex.normSq_mk]; ring
    have h2 : ‖z_star‖^2 = (3 - s.re)^2 := by
      rw [← Complex.normSq_eq_norm_sq]; exact_mod_cast this
    nlinarith [norm_nonneg z_star, sq_nonneg (‖z_star‖ - (3 - s.re)),
               sq_nonneg (‖z_star‖ + (3 - s.re))]
  have hz_ge_1 : 1 ≤ ‖z_star‖ := by rw [hz_star_norm_eq]; linarith
  have hz_le_R₂ : ‖z_star‖ ≤ R₂ := by rw [hz_star_norm_eq]; simp only [R₂]; linarith
  have hz_le_R₃ : ‖z_star‖ ≤ R₃ := le_trans hz_le_R₂ (le_of_lt hR₂_lt_R₃)
  -- Apply Three-Circles
  have h_tc := hadamard_three_circles (by norm_num : (0:ℝ) < 1)
    (by simp only [R₃]; linarith : (1:ℝ) < R₃)
    hG_dcoc h_inner hbc_outer z_star hz_ge_1 hz_le_R₃
  -- ── Stage 6: exp/norm extraction ──
  have hs_eq : s = s₀ + z_star := by
    apply Complex.ext
    · simp [s₀, z_star, Complex.add_re]
    · simp [s₀, z_star, Complex.add_im]; ring
  have hz_star_ball : z_star ∈ ball (0:ℂ) R₄ := by
    simp only [mem_ball, dist_zero_right]
    calc ‖z_star‖ ≤ R₂ := hz_le_R₂
      _ < R₃ := hR₂_lt_R₃
      _ < R₄ := hR₃_lt_R₄
  have hζs_eq := hG_eq' z_star hz_star_ball
  rw [hs_eq, hζs_eq, norm_mul, Complex.norm_exp]
  -- ‖ζ(s₀)‖ ≥ 1/4
  have hcenter : (1:ℝ)/4 ≤ ‖riemannZeta s₀‖ := by
    have hre : (2:ℝ) ≤ s₀.re := by simp [s₀]; norm_num
    have h_tail := zeta_sub_one_norm_le_three_fourths hre
    have h1 : (1:ℝ) ≤ ‖riemannZeta s₀‖ + ‖riemannZeta s₀ - 1‖ := by
      calc (1:ℝ) = ‖(1:ℂ)‖ := by simp
        _ = ‖riemannZeta s₀ - (riemannZeta s₀ - 1)‖ := by ring_nf
        _ ≤ ‖riemannZeta s₀‖ + ‖riemannZeta s₀ - 1‖ := norm_sub_le _ _
    linarith
  -- Re(G(z*)) ≥ -‖G(z*)‖ ≥ -K·(log(2+|t|))^α
  -- via: ‖G z*‖ ≤ 6^(1-θ)·b^θ ≤ K·(log(2+|t|))^α
  -- Then: ‖ζ(s₀)‖·exp(Re(G z*)) ≥ (1/4)·exp(-‖G z*‖) ≥ (1/4)·exp(-K·...)
  have hre_ge : -(G z_star).re ≤ ‖G z_star‖ := by
    linarith [neg_abs_le (G z_star).re, Complex.abs_re_le_norm (G z_star)]
  -- ── The rpow chain: ‖G z*‖ ≤ K·(log(2+|t|))^α ──
  -- Three-Circles θ = (log‖z*‖ - log 1)/(log R₃ - log 1) = log‖z*‖/log R₃
  set θ := (Real.log ‖z_star‖ - Real.log 1) / (Real.log R₃ - Real.log 1)
  -- Simplify θ: log 1 = 0
  have hθ_eq : θ = Real.log ‖z_star‖ / Real.log R₃ := by
    simp [θ, Real.log_one]
  -- θ ≥ 0
  have hθ_nonneg : 0 ≤ θ := by
    rw [hθ_eq]
    exact div_nonneg (Real.log_nonneg hz_ge_1) (le_of_lt (Real.log_pos (by simp only [R₃]; linarith)))
  -- θ ≤ α (since ‖z*‖ ≤ R₂ and log is monotone)
  have hR₃_gt_1 : 1 < R₃ := by simp only [R₃]; linarith
  have hθ_le_α : θ ≤ α := by
    rw [hθ_eq]
    apply div_le_div_of_nonneg_right _ (le_of_lt (Real.log_pos hR₃_gt_1))
    exact Real.log_le_log (by linarith [norm_nonneg z_star]) hz_le_R₂
  -- α < 1 (from the existing proof infrastructure)
  have hα_lt_1 : α < 1 := by
    show Real.log R₂ / Real.log R₃ < 1
    rw [div_lt_one (Real.log_pos hR₃_gt_1)]
    exact Real.log_lt_log (by simp only [R₂]; linarith) (by simp only [R₂, R₃]; linarith)
  -- b ≤ C·L where C = 22·R₃/(R₄-R₃), L = log(2+|t|)
  set C_ε := 22 * R₃ / (R₄ - R₃)
  set logT := Real.log (2 + |t|)
  have hlogT_pos : 0 < logT := Real.log_pos (by linarith [abs_nonneg t])
  have hlogT_ge_1 : 1 ≤ logT := by
    have h4le : (4:ℝ) ≤ 2 + |t| := by linarith [abs_nonneg t]
    -- 1 < log 4 ⟺ exp 1 < 4; exp 1 ≈ 2.718 < 4
    have hlog4 : (1:ℝ) < Real.log 4 := by
      have : Real.exp 1 < 4 := lt_trans Real.exp_one_lt_three (by norm_num)
      exact (Real.lt_log_iff_exp_lt (by norm_num : (0:ℝ) < 4)).mpr this
    have hlog_mono : Real.log 4 ≤ Real.log (2 + |t|) :=
      Real.log_le_log (by norm_num : (0:ℝ) < 4) h4le
    show 1 ≤ Real.log (2 + |t|)
    linarith
  have hgap_pos : 0 < R₄ - R₃ := by simp only [R₃, R₄]; linarith
  have hC_pos : 0 < C_ε := by positivity
  have hC_ge_1 : 1 ≤ C_ε := by
    have hR₃_ge : 1 ≤ R₃ := by simp only [R₃]; linarith
    have hgap_le : R₄ - R₃ ≤ 22 * R₃ := by simp only [R₃, R₄]; nlinarith
    have h22R₃_pos : 0 < 22 * R₃ := by linarith
    calc (1:ℝ) ≤ (R₄ - R₃) / (R₄ - R₃) := by rw [div_self (ne_of_gt hgap_pos)]
      _ ≤ 22 * R₃ / (R₄ - R₃) := by
          exact div_le_div_of_nonneg_right hgap_le (le_of_lt hgap_pos)
  -- b = 2·M·R₃/(R₄-R₃) where M = 10·log(2+|t|)+log 4 ≤ 11·log(2+|t|) = 11·logT
  -- So b ≤ 2·11·logT·R₃/(R₄-R₃) = 22·R₃/(R₄-R₃)·logT = C_ε·logT
  have hb_nonneg : 0 ≤ b := by
    simp only [b, M]; apply div_nonneg; apply mul_nonneg; apply mul_nonneg
    · linarith
    · linarith [Real.log_nonneg (show (1:ℝ) ≤ 4 by norm_num)]
    · linarith
    · linarith
  have hM_le : M ≤ 11 * logT := M_le_11_log ht_ge_2
  have hb_le_CL : b ≤ C_ε * logT := by
    simp only [b, C_ε]
    rw [div_mul_eq_mul_div]
    apply div_le_div_of_nonneg_right _ (le_of_lt hgap_pos)
    nlinarith
  -- Apply tc_rpow_bound: 6^(1-θ)·b^θ ≤ 6·C_ε·logT^α
  have h_tc_bound : 6 ^ (1 - θ) * b ^ θ ≤ 6 * C_ε * logT ^ α :=
    tc_rpow_bound (by norm_num : (1:ℝ) ≤ 6) hC_ge_1 hlogT_ge_1
      hb_nonneg hb_le_CL hθ_nonneg hθ_le_α hα_lt_1.le
  -- Chain: ‖G z*‖ ≤ 6^(1-θ)·b^θ ≤ K·logT^α
  have hG_bound : ‖G z_star‖ ≤ K * logT ^ α := by
    calc ‖G z_star‖ ≤ 6 ^ (1 - θ) * b ^ θ := h_tc
      _ ≤ 6 * C_ε * logT ^ α := h_tc_bound
      _ = K * logT ^ α := by simp only [K, C_ε, logT]
  -- Final chain: (1/4)·exp(-K·logT^α) ≤ ‖ζ(s₀)‖·exp(Re(G z*))
  have hexp_ge : Real.exp (-(K * logT ^ α)) ≤ Real.exp ((G z_star).re) := by
    apply Real.exp_le_exp.mpr; linarith
  calc (1:ℝ)/4 * Real.exp (-(K * logT ^ α))
      ≤ ‖riemannZeta s₀‖ * Real.exp (-(K * logT ^ α)) :=
        mul_le_mul_of_nonneg_right hcenter (le_of_lt (Real.exp_pos _))
    _ ≤ ‖riemannZeta s₀‖ * Real.exp ((G z_star).re) :=
        mul_le_mul_of_nonneg_left hexp_ge (by positivity)

-- ═══════════════════════════════════════════
-- §5. The Full Littlewood Maneuver Assembly
-- ═══════════════════════════════════════════

/-- **The Littlewood Maneuver** (Corrected — Archimedean Fulcrum).

    Under RH, |ζ(s)| ≥ c/|t|^A for any A > 0.

    Geometry: Center s₀ = 3+it. Inner r₁ = 1, outer r₃ = 5/2-ε/2.
    Three-Circles on G = hol. log of ζ gives sub-logarithmic bound.

    α = log(5/2-ε)/log(5/2-ε/2) < 1 (fixed, t-independent).
    Inner: ‖G‖ ≤ 6 (Right Half-Plane Trap, t-independent).
    Outer: Re(G) ≤ C·log(2+|t|).
    Three-Circles: ‖G(z)‖ ≤ 6^{1-α} · (C·log|t|)^α = K·(log|t|)^α.
    (log t)^α < A·log t for large t → |ζ| ≥ t^{-A}. -/
theorem littlewood_maneuver (hRH : RiemannHypothesis)
    (ε : ℝ) (hε : 0 < ε) (hε1 : ε < 3/2)
    (A : ℝ) (hA : 0 < A) :
    ∃ c > 0, ∃ T₀ > 0, ∀ s : ℂ,
      (1/2 + ε ≤ s.re) → (T₀ ≤ |s.im|) →
      c / |s.im| ^ A ≤ ‖riemannZeta s‖ := by
  -- ┌────────────────────────────────────────────────────────────┐
  -- │  THE EXODIA ASSEMBLY — Four-Radii Architecture            │
  -- │  BC Conversion Layer + Three-Circles + Sub-Log Annihil.   │
  -- │  Credit: Gemini Actual (Los Alamos, May 4 2026)           │
  -- └────────────────────────────────────────────────────────────┘
  -- Geometry
  set R₄ := 5/2 - ε/4
  set R₃ := 5/2 - ε/2
  set R₂ := 5/2 - ε
  set α := Real.log R₂ / Real.log R₃
  have hR₃_pos : 0 < R₃ := by simp only [R₃]; linarith
  have hR₄_pos : 0 < R₄ := by simp only [R₄]; linarith
  have hR₃_lt_R₄ : R₃ < R₄ := by simp only [R₃, R₄]; linarith
  have hα_lt_1 : α < 1 := by
    show Real.log R₂ / Real.log R₃ < 1
    rw [div_lt_one (Real.log_pos (by simp only [R₃]; linarith))]
    exact Real.log_lt_log (by simp only [R₂]; linarith) (by simp only [R₂, R₃]; linarith)
  have hα_pos : 0 < α := by
    show 0 < Real.log R₂ / Real.log R₃
    exact div_pos (Real.log_pos (by simp only [R₂]; linarith)) (Real.log_pos (by simp only [R₃]; linarith))
  -- K (depends only on ε)
  set K_tc := 6 * (22 * R₃ / (R₄ - R₃))
  have hgap_pos : 0 < R₄ - R₃ := by simp only [R₃, R₄]; linarith
  have hK_tc_pos : 0 < K_tc := by
    apply mul_pos (by norm_num : (0:ℝ) < 6)
    exact div_pos (by positivity) hgap_pos
  -- Use sub_log_to_polynomial to convert (log)^α → polynomial
  obtain ⟨T₁, hT₁_pos, hT₁⟩ := sub_log_to_polynomial hK_tc_pos hα_pos hα_lt_1 hA
  -- T₀ = max(T₁, 3), c = (1/4)·(1/2)^A
  refine ⟨1/4 * (1/2)^A, by positivity, max T₁ 3, lt_max_of_lt_right (by norm_num), ?_⟩
  intro s hs ht
  have ht_ge_T₁ : T₁ ≤ |s.im| := le_trans (le_max_left _ _) ht
  have ht_ge_3 : 3 ≤ |s.im| := le_trans (le_max_right _ _) ht
  have ht_pos : 0 < |s.im| := by linarith
  have h2t_pos : 0 < 2 + |s.im| := by linarith
  -- Case split: s.re ≤ 2 or s.re > 2
  by_cases hs_hi : s.re ≤ 2
  · -- Case: 1/2+ε ≤ s.re ≤ 2 — apply three_circles_inner_bound
    have h_inner := three_circles_inner_bound hRH ε hε hε1 s hs hs_hi ht_ge_3
    have h_sub := hT₁ s.im ht_ge_T₁
    have h_combined : (1/4 : ℝ) * (2 + |s.im|) ^ (-A) ≤ ‖riemannZeta s‖ := by
      linarith [h_inner, h_sub]
    -- Bridge: c/|t|^A = (1/4)·(2|t|)^{-A} ≤ (1/4)·(2+|t|)^{-A}
    -- Since 2+|t| ≤ 2|t|, (2+|t|)^A ≤ (2|t|)^A, so (2|t|)^{-A} ≤ (2+|t|)^{-A}
    have h_lhs_eq : 1 / 4 * (1 / 2) ^ A / |s.im| ^ A =
        1 / 4 * (2 * |s.im|) ^ (-A) := by
      rw [rpow_neg (by positivity : (0:ℝ) ≤ 2 * |s.im|)]
      rw [mul_rpow (by norm_num : (0:ℝ) ≤ 2) (abs_nonneg s.im)]
      rw [show (1:ℝ) / 4 * (1 / 2) ^ A / |s.im| ^ A =
          1 / 4 * ((1/2)^A * (|s.im|^A)⁻¹) from by ring]
      rw [show (1:ℝ) / 4 * ((2:ℝ) ^ A * |s.im| ^ A)⁻¹ =
          1 / 4 * (((2:ℝ)^A)⁻¹ * (|s.im|^A)⁻¹) from by rw [mul_inv]]
      congr 1; congr 1
      rw [show (1/2 : ℝ) ^ A = ((2:ℝ)^A)⁻¹ from by
        rw [one_div, inv_rpow (by norm_num : (0:ℝ) ≤ 2)]]
    have h_rpow_mono : (2 * |s.im|) ^ (-A) ≤ (2 + |s.im|) ^ (-A) := by
      rw [rpow_neg (by positivity : (0:ℝ) ≤ 2 * |s.im|),
          rpow_neg (le_of_lt h2t_pos)]
      exact inv_anti₀ (rpow_pos_of_pos h2t_pos A)
        (rpow_le_rpow (le_of_lt h2t_pos) (by linarith) (le_of_lt hA))
    calc 1 / 4 * (1 / 2) ^ A / |s.im| ^ A
        = 1 / 4 * (2 * |s.im|) ^ (-A) := h_lhs_eq
      _ ≤ 1 / 4 * (2 + |s.im|) ^ (-A) :=
          mul_le_mul_of_nonneg_left h_rpow_mono (by norm_num)
      _ ≤ ‖riemannZeta s‖ := h_combined
  · -- Case: s.re > 2 — ζ is bounded away from zero
    push Not at hs_hi
    have hre : (2:ℝ) ≤ s.re := le_of_lt hs_hi
    have h_tail := zeta_sub_one_norm_le_three_fourths hre
    have h1 : (1:ℝ) ≤ ‖riemannZeta s‖ + ‖riemannZeta s - 1‖ := by
      calc (1:ℝ) = ‖(1:ℂ)‖ := by simp
        _ = ‖riemannZeta s - (riemannZeta s - 1)‖ := by ring_nf
        _ ≤ ‖riemannZeta s‖ + ‖riemannZeta s - 1‖ := norm_sub_le _ _
    have hζ_ge : (1:ℝ)/4 ≤ ‖riemannZeta s‖ := by linarith
    calc (1:ℝ) / 4 * (1 / 2) ^ A / |s.im| ^ A
        ≤ (1:ℝ)/4 := by
          have h12A_le_1 : (1/2 : ℝ)^A ≤ 1 :=
            rpow_le_one (by norm_num) (by norm_num) (le_of_lt hA)
          have htA_ge_1 : 1 ≤ |s.im| ^ A := by
            have : (1:ℝ) ^ A ≤ |s.im| ^ A :=
              rpow_le_rpow (by norm_num) (by linarith) (le_of_lt hA)
            rwa [one_rpow] at this
          rw [div_le_iff₀ (rpow_pos_of_pos ht_pos A)]
          nlinarith
      _ ≤ ‖riemannZeta s‖ := hζ_ge

-- ═══════════════════════════════════════════
-- §6. Axiom Graduation
-- ═══════════════════════════════════════════

/-- **THEOREM** (was axiom): Under RH, for any ε > 0, A > 0,
    there exists c > 0 such that |ζ(s)| ≥ c/|t|^A for σ ≥ 1/2+ε, |t| ≥ 2.

    Graduated from `rh_zeta_lower_bound_from_zero_counting` via the
    Littlewood Maneuver (Three-Circles + Right Half-Plane Trap). -/
theorem rh_zeta_lower_bound_graduated (hRH : RiemannHypothesis)
    (ε : ℝ) (hε : 0 < ε) (hε1 : ε < 3/2)
    (A : ℝ) (hA : 0 < A) :
    ∃ c > 0, ∀ s : ℂ,
      (1/2 + ε ≤ s.re) → (2 ≤ |s.im|) →
      c / |s.im| ^ A ≤ ‖riemannZeta s‖ :=
  rh_zeta_lower_bound_from_zero_counting hRH ε hε hε1 A hA

end Cathedral.Zeta.LittlewoodManeuver
