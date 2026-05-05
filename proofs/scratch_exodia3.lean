/-
  Scratch file: Exodia Assembly — The Three-Circles Inner Bound
  Testing the widened geometry for R₄ = 5/2 - ε/4.
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

namespace ScratchAssembly
open Cathedral.Zeta.DiskBounds
open Cathedral.Zeta.Hadamard

-- ═══════════════════════════════════════════
-- Wider geometry lemmas for center (3, t) and R < 5/2
-- ═══════════════════════════════════════════

/-- (3,t) + z ≠ 1 for z ∈ ball(0, R), R < 5/2, |t| ≥ 2.
    Generalizes s_ne_one_on_ball_3 from R = 5/2-ε/2 to any R < 5/2. -/
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
  -- ‖z‖² ≥ 8, but ‖z‖ < R < 5/2, so ‖z‖² < (5/2)² = 25/4 < 8. Contradiction.
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

/-- ζ(s₀ + z) differentiable on ball(0, R), R < 5/2, center (3,t), |t| ≥ 2.
    Uses the fact that 1 is outside ball(s₀, R). -/
private lemma zeta_differentiable_on_wide_ball
    {t : ℝ} (ht : 2 ≤ |t|) {R : ℝ} (hR_pos : 0 < R) (hR : R < 5/2) :
    DifferentiableOn ℂ (fun w => riemannZeta ((⟨3, t⟩ : ℂ) + w)) (ball 0 R) := by
  intro z hz
  have hsne := s_ne_one_on_wide_ball ht hR hz
  exact (differentiableAt_riemannZeta hsne).comp z
    ((differentiableAt_const (⟨3, t⟩ : ℂ)).add differentiableAt_id) |>.differentiableWithinAt

/-- ζ(s₀ + z) ≠ 0 on ball(0, R), R < 5/2, center (3,t), |t| ≥ 2, under RH. -/
private lemma zeta_ne_zero_on_wide_ball (hRH : RiemannHypothesis)
    {t : ℝ} (ht : 2 ≤ |t|) {R : ℝ} (hR : R < 5/2) :
    ∀ z ∈ ball (0 : ℂ) R, riemannZeta ((⟨3, t⟩ : ℂ) + z) ≠ 0 := by
  intro z hz
  have hne1 := s_ne_one_on_wide_ball ht hR hz
  exact rh_zeta_ne_zero hRH (re_gt_half_on_wide_ball hR hz) hne1

#check @s_ne_one_on_wide_ball
#check @re_gt_half_on_wide_ball
#check @zeta_differentiable_on_wide_ball
#check @zeta_ne_zero_on_wide_ball

end ScratchAssembly
