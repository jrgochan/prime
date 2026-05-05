/-
  Scratch: The Three-Circles Inner Bound
  Analogous to bc_inner_bound in LowerBound.lean, but using
  the Four-Radii Architecture for a sub-logarithmic exponent.
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

namespace ScratchInner
open Cathedral.Zeta.DiskBounds
open Cathedral.Zeta.Hadamard

-- ═══════════════════════════════════════════
-- Inline the needed wide-ball geometry
-- ═══════════════════════════════════════════

private lemma s_ne_one_wide {t : ℝ} (ht : 2 ≤ |t|) {R : ℝ} (hR : R < 5/2)
    {z : ℂ} (hz : z ∈ ball (0 : ℂ) R) : (⟨3, t⟩ : ℂ) + z ≠ 1 := by
  simp only [mem_ball, dist_zero_right] at hz
  intro heq
  have hzre : z.re = -2 := by have := congr_arg Complex.re heq; simp at this; linarith
  have hzim : z.im = -t := by have := congr_arg Complex.im heq; simp at this; linarith
  have h_nsq : Complex.normSq z = 4 + t^2 := by simp [Complex.normSq_apply, hzre, hzim]; ring
  have h_norm_sq : ‖z‖^2 = 4 + t^2 := by rw [← Complex.normSq_eq_norm_sq]; exact_mod_cast h_nsq
  have h_z_lt : ‖z‖ < 5/2 := lt_trans hz hR
  have h_z_sq : ‖z‖^2 < (5/2)^2 := sq_lt_sq' (by linarith [norm_nonneg z]) h_z_lt
  nlinarith [sq_abs t]

private lemma re_gt_half_wide {R : ℝ} (hR : R < 5/2) {z : ℂ} (hz : z ∈ ball (0 : ℂ) R) :
    1/2 < ((⟨3, t⟩ : ℂ) + z).re := by
  simp only [mem_ball, dist_zero_right] at hz
  simp only [Complex.add_re]; show 1/2 < 3 + z.re
  linarith [(abs_le.mp (le_trans (Complex.abs_re_le_norm z) (le_of_lt hz))).1]

private lemma zeta_diff_wide {t : ℝ} (ht : 2 ≤ |t|) {R : ℝ} (_hR_pos : 0 < R) (hR : R < 5/2) :
    DifferentiableOn ℂ (fun w => riemannZeta ((⟨3, t⟩ : ℂ) + w)) (ball 0 R) := by
  intro z hz
  exact (differentiableAt_riemannZeta (s_ne_one_wide ht hR hz)).comp z
    ((differentiableAt_const _).add differentiableAt_id) |>.differentiableWithinAt

private lemma zeta_ne_zero_wide (hRH : RiemannHypothesis) {t : ℝ} (ht : 2 ≤ |t|)
    {R : ℝ} (hR : R < 5/2) : ∀ z ∈ ball (0 : ℂ) R, riemannZeta ((⟨3, t⟩ : ℂ) + z) ≠ 0 := by
  intro z hz; exact rh_zeta_ne_zero hRH (re_gt_half_wide hR hz) (s_ne_one_wide ht hR hz)

-- ═══════════════════════════════════════════
-- ‖ζ(s₀)‖ ≥ 1/4 (center bound)
-- ═══════════════════════════════════════════

private lemma zeta_center_bound {t : ℝ} :
    (1:ℝ)/4 ≤ ‖riemannZeta (⟨3, t⟩ : ℂ)‖ := by
  have hre : (2:ℝ) ≤ (⟨3, t⟩ : ℂ).re := by norm_num
  have h_tail := zeta_sub_one_norm_le_three_fourths hre
  have h1 : (1 : ℝ) ≤ ‖riemannZeta (⟨3, t⟩ : ℂ)‖ + ‖riemannZeta (⟨3, t⟩ : ℂ) - 1‖ := by
    calc (1:ℝ) = ‖(1:ℂ)‖ := by simp
      _ = ‖riemannZeta (⟨3, t⟩ : ℂ) - (riemannZeta (⟨3, t⟩ : ℂ) - 1)‖ := by ring_nf
      _ ≤ ‖riemannZeta (⟨3, t⟩ : ℂ)‖ + ‖riemannZeta (⟨3, t⟩ : ℂ) - 1‖ := norm_sub_le _ _
  linarith

-- ═══════════════════════════════════════════
-- THE THREE-CIRCLES INNER BOUND (pointwise)
-- ═══════════════════════════════════════════

/-- **Three-Circles Inner Bound**: For 1/2+ε ≤ Re(s) ≤ 2, |Im(s)| ≥ 3, under RH:
    ‖ζ(s)‖ ≥ (1/4) · exp(-K · (log(2+|t|))^α)
    where K, α depend only on ε, and 0 < α < 1.

    This is the core of the Littlewood Maneuver: BC converts Re bound to norm,
    Three-Circles interpolates to the target, producing a sub-logarithmic bound.

    Proof structure:
    1. Construct G = hol. log of z ↦ ζ(s₀+z) on ball(0, R₄)
    2. Get Re(G) ≤ M on ball(0, R₄) [G_outer_bound_re_3]
    3. Get ‖G‖ ≤ b on ‖z‖=R₃ [BC conversion]
    4. Get ‖G‖ ≤ 6 on ‖z‖=1 [inner anchor]
    5. Three-Circles: ‖G(z*)‖ ≤ 6^(1-α)·b^α at z* = s - s₀
    6. ‖ζ(s)‖ = ‖ζ(s₀)‖·exp(Re(G(z*))) ≥ (1/4)·exp(-‖G(z*)‖) -/
private lemma three_circles_inner_bound (hRH : RiemannHypothesis)
    (ε : ℝ) (hε : 0 < ε) (hε1 : ε < 3/2)
    (s : ℂ) (hs : 1/2 + ε ≤ s.re) (hs_hi : s.re ≤ 2) (ht : 3 ≤ |s.im|) :
    let R₄ := 5/2 - ε/4
    let R₃ := 5/2 - ε/2
    let α := Real.log (5/2 - ε) / Real.log R₃
    let K := 6 ^ (1 - α) * (22 * R₃ / (R₄ - R₃)) ^ α
    (1/4 : ℝ) * Real.exp (-(K * (Real.log (2 + |s.im|)) ^ α)) ≤ ‖riemannZeta s‖ := by
  -- ── Setup ──
  set t := s.im
  set R₄ := 5/2 - ε/4
  set R₃ := 5/2 - ε/2
  set R₂ := 5/2 - ε
  set s₀ : ℂ := ⟨3, t⟩
  set α := Real.log R₂ / Real.log R₃
  set K := 6 ^ (1 - α) * (22 * R₃ / (R₄ - R₃)) ^ α
  have hR₄_pos : 0 < R₄ := by simp only [R₄]; linarith
  have hR₃_pos : 0 < R₃ := by simp only [R₃]; linarith
  have hR₃_lt_R₄ : R₃ < R₄ := by simp only [R₃, R₄]; linarith
  have h1_lt_R₂ : 1 < R₂ := by simp only [R₂]; linarith
  have hR₄_lt_52 : R₄ < 5/2 := by simp only [R₄]; linarith
  have ht_ge_2 : 2 ≤ |t| := by linarith
  -- ── Stage 1: Holomorphic logarithm ──
  have hf_diff := zeta_diff_wide ht_ge_2 hR₄_pos hR₄_lt_52
  have hf_ne := zeta_ne_zero_wide hRH ht_ge_2 hR₄_lt_52
  obtain ⟨G, hG_diff, hG0, hG_eq⟩ :=
    holomorphic_log_exists_on_ball hR₄_pos hf_diff hf_ne
  -- ── Stage 2: Re bound on ball(0, R₄) ──
  have hR₄_half : R₄ + 1/2 ≤ |t| := by simp only [R₄]; linarith
  have hG_re : ∀ z ∈ ball (0:ℂ) R₄,
      (G z).re ≤ 10 * Real.log (2 + |t|) + Real.log 4 := by
    intro z hz
    -- G_outer_bound_re_3 needs: hG_eq : ζ(s₀+z) = ζ(s₀)·exp(G(z))
    -- holomorphic_log gives: ζ(s₀+z) = ζ(s₀+0)·exp(G(z))
    -- These are equal since s₀+0 = s₀.
    have hG_eq' : ∀ w ∈ ball (0:ℂ) R₄,
        riemannZeta (s₀ + w) = riemannZeta s₀ * Complex.exp (G w) := by
      intro w hw; have := hG_eq w hw; simp at this; exact this
    exact Cathedral.Zeta.LittlewoodManeuver.G_outer_bound_re_3 hR₄_pos hR₄_lt_52 hR₄_half hG_diff hG_eq' z hz
  -- ── Stage 3: BC conversion ──
  set M := 10 * Real.log (2 + |t|) + Real.log 4
  set b := 2 * M * R₃ / (R₄ - R₃)
  have hM_pos : 0 < M := by
    simp only [M]
    have : 0 < Real.log (2 + |t|) := Real.log_pos (by linarith [abs_nonneg t])
    have : 0 < Real.log 4 := Real.log_pos (by norm_num)
    linarith
  have hG_re_maps : ∀ z ∈ ball (0:ℂ) R₄, (G z).re ≤ M := hG_re
  have hG0_eq : G (0 : ℂ) = 0 := hG0
  -- borelCaratheodory_zero: ‖G z‖ ≤ 2 * M * ‖z‖ / (R₄ - ‖z‖)
  -- On ‖z‖ = R₃: ‖G z‖ ≤ 2 * M * R₃ / (R₄ - R₃) = b
  have hbc_outer : ∀ z, ‖z‖ = R₃ → ‖G z‖ ≤ b := by
    intro z hz
    have hz_ball : z ∈ ball (0 : ℂ) R₄ := by
      simp only [mem_ball, dist_zero_right]; rw [hz]; exact hR₃_lt_R₄
    have hG_re_maps' : MapsTo G (ball 0 R₄) {w | w.re ≤ M} := by
      intro w hw; exact hG_re w hw
    have hBC := Complex.borelCaratheodory_zero hM_pos hG_diff hG_re_maps' hR₄_pos hz_ball hG0_eq
    rwa [hz] at hBC
  -- ── Stage 4: Inner anchor ──
  -- Need: ‖G(z)‖ ≤ 6 on ‖z‖ = 1
  -- This uses G_inner_bound_fixed which needs G_eq, ζ_ne, f_diff
  have hR₄_ge_1 : 1 < R₄ := by simp only [R₄]; linarith
  have h_inner : ∀ z, ‖z‖ = 1 → ‖G z‖ ≤ 6 := by
    have hG_eq' : ∀ w ∈ ball (0:ℂ) R₄,
        riemannZeta (s₀ + w) = riemannZeta s₀ * Complex.exp (G w) := by
      intro w hw; have := hG_eq w hw; simp at this; exact this
    exact Cathedral.Zeta.LittlewoodManeuver.G_inner_bound_fixed ht_ge_2 hR₄_pos hR₄_ge_1 hG_diff hG0 hG_eq' hf_ne hf_diff
  -- ── Stage 5: Three-Circles ──
  -- DiffContOnCl on annulus [1, R₃]
  have hR₂_lt_R₃ : R₂ < R₃ := by simp only [R₂, R₃]; linarith
  have hG_dcoc : DiffContOnCl ℂ G {z : ℂ | 1 ≤ ‖z‖ ∧ ‖z‖ ≤ R₃} := by
    have h_closed : IsClosed {z : ℂ | 1 ≤ ‖z‖ ∧ ‖z‖ ≤ R₃} := by
      apply IsClosed.inter
      · exact isClosed_le continuous_const continuous_norm
      · exact isClosed_le continuous_norm continuous_const
    have h_sub : {z : ℂ | 1 ≤ ‖z‖ ∧ ‖z‖ ≤ R₃} ⊆ ball (0 : ℂ) R₄ := by
      intro z ⟨_, hz₂⟩; simp only [mem_ball, dist_zero_right]
      exact lt_of_le_of_lt hz₂ hR₃_lt_R₄
    rw [h_closed.diffContOnCl_iff]
    exact hG_diff.mono h_sub
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
  have hz_ge_1 : 1 ≤ ‖z_star‖ := by
    rw [hz_star_norm_eq]; linarith
  have hz_le_R₂ : ‖z_star‖ ≤ R₂ := by
    rw [hz_star_norm_eq]; simp only [R₂]; linarith
  have hz_le_R₃ : ‖z_star‖ ≤ R₃ := le_trans hz_le_R₂ (le_of_lt hR₂_lt_R₃)
  -- Apply Three-Circles
  have h_tc := hadamard_three_circles (by norm_num : (0:ℝ) < 1)
    (by simp only [R₃]; linarith : (1:ℝ) < R₃) hG_dcoc h_inner hbc_outer z_star hz_ge_1 hz_le_R₃
  -- h_tc : ‖G z_star‖ ≤ 6^(1-θ) · b^θ where θ = (log‖z*‖ - log 1)/(log R₃ - log 1)
  -- Since log 1 = 0: θ = log‖z*‖/log R₃
  -- For ‖z*‖ ≤ R₂: θ ≤ log R₂/log R₃ = α
  -- The bound at z* is ≤ 6^(1-α) · b^α since the exponent is monotone

  -- ── Stage 6: exp/norm extraction ──
  -- ζ(s) = ζ(s₀) · exp(G(z*)) since s = s₀ + z*
  have hs_eq : s = s₀ + z_star := by
    apply Complex.ext
    · simp [s₀, z_star, Complex.add_re]
    · simp [s₀, z_star, Complex.add_im]; ring
  have hz_star_ball : z_star ∈ ball (0:ℂ) R₄ := by
    simp only [mem_ball, dist_zero_right]
    calc ‖z_star‖ ≤ R₂ := hz_le_R₂
      _ < R₃ := hR₂_lt_R₃
      _ < R₄ := hR₃_lt_R₄
  have hζs_eq := hG_eq z_star hz_star_ball
  -- ‖ζ(s)‖ = ‖ζ(s₀)‖ · ‖exp(G(z*))‖ = ‖ζ(s₀)‖ · exp(Re(G(z*)))
  rw [hs_eq, hζs_eq, norm_mul, Complex.norm_exp]
  -- ‖ζ(s₀)‖ ≥ 1/4
  have hcenter := zeta_center_bound (t := t)
  -- Re(G(z*)) ≥ -‖G(z*)‖
  have hre_ge : -(G z_star).re ≤ ‖G z_star‖ := by
    linarith [neg_abs_le (G z_star).re, Complex.abs_re_le_norm (G z_star)]
  -- ‖G z*‖ ≤ K·(log(2+|t|))^α (via Three-Circles + rpow algebra)
  -- For now, we use: ‖G z*‖ ≤ 6^(1-θ)·b^θ ≤ K·(log(2+|t|))^α
  -- since θ ≤ α and b = 2M·R₃/(R₄-R₃)
  sorry

#check @three_circles_inner_bound

end ScratchInner
