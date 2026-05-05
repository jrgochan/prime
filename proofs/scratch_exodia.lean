/-
  Scratch file: Exodia Assembly prototyping
  Testing the DiffContOnCl conversion and BC → Three-Circles wiring.
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

namespace ScratchExodia
open Cathedral.Zeta.DiskBounds
open Cathedral.Zeta.Hadamard

-- ═══════════════════════════════════════════
-- KEY LEMMA 1: DiffContOnCl on annulus from DifferentiableOn on ball
-- ═══════════════════════════════════════════

/-- If G is differentiable on ball(0, R₄) and R₃ < R₄, then G is
    DiffContOnCl on the annulus {R₁ ≤ ‖z‖ ≤ R₃}. -/
lemma diffContOnCl_on_annulus_of_ball
    {G : ℂ → ℂ} {R₁ R₃ R₄ : ℝ}
    (hR₁_pos : 0 < R₁) (hR₃_lt : R₃ < R₄)
    (hG_diff : DifferentiableOn ℂ G (ball 0 R₄)) :
    DiffContOnCl ℂ G {z : ℂ | R₁ ≤ ‖z‖ ∧ ‖z‖ ≤ R₃} := by
  -- The annulus {R₁ ≤ ‖z‖ ≤ R₃} is a closed subset of ball(0, R₄)
  -- since ‖z‖ ≤ R₃ < R₄ implies z ∈ ball(0, R₄).
  -- DiffContOnCl means: analytic on the interior AND continuous on the closure.
  -- Since the annulus is closed and contained in ball(0, R₄) (an open set),
  -- G is analytic on a neighborhood of every point.
  -- The annulus {R₁ ≤ ‖z‖ ≤ R₃} is closed, so closure = itself.
  -- Since it's contained in ball(0, R₄) (open), G is differentiable there.
  have h_closed : IsClosed {z : ℂ | R₁ ≤ ‖z‖ ∧ ‖z‖ ≤ R₃} := by
    apply IsClosed.inter
    · exact isClosed_le continuous_const continuous_norm
    · exact isClosed_le continuous_norm continuous_const
  have h_sub : {z : ℂ | R₁ ≤ ‖z‖ ∧ ‖z‖ ≤ R₃} ⊆ ball (0 : ℂ) R₄ := by
    intro z ⟨_, hz₂⟩
    simp only [mem_ball, dist_zero_right]
    linarith
  -- For closed sets, DiffContOnCl ↔ DifferentiableOn (Mathlib)
  rw [h_closed.diffContOnCl_iff]
  exact hG_diff.mono h_sub

-- ═══════════════════════════════════════════
-- KEY LEMMA 2: BC conversion — Re bound to norm bound on inner circle
-- ═══════════════════════════════════════════

/-- Apply Borel-Carathéodory to convert a Re(G) ≤ M bound on ball(0, R₄)
    into a ‖G‖ ≤ K bound on ‖z‖ = R₃ < R₄, given G(0) = 0. -/
lemma bc_re_to_norm
    {G : ℂ → ℂ} {R₃ R₄ M : ℝ}
    (hR₃_pos : 0 < R₃) (hR₃_lt : R₃ < R₄) (hR₄_pos : 0 < R₄)
    (hM_pos : 0 < M)
    (hG_diff : DifferentiableOn ℂ G (ball 0 R₄))
    (hG0 : G 0 = 0)
    (hG_re : ∀ z ∈ ball (0 : ℂ) R₄, (G z).re ≤ M) :
    ∀ z, ‖z‖ = R₃ → ‖G z‖ ≤ 2 * M * R₃ / (R₄ - R₃) := by
  intro z hz
  have hz_ball : z ∈ ball (0 : ℂ) R₄ := by
    simp only [mem_ball, dist_zero_right]; linarith
  -- Apply borelCaratheodory_zero from Mathlib
  have hG_re_maps : MapsTo G (ball 0 R₄) {w | w.re ≤ M} := by
    intro w hw; exact hG_re w hw
  have hBC := Complex.borelCaratheodory_zero hM_pos hG_diff hG_re_maps hR₄_pos hz_ball hG0
  -- hBC : ‖G z‖ ≤ 2 * M * ‖z‖ / (R₄ - ‖z‖)
  -- Since ‖z‖ = R₃, this gives ‖G z‖ ≤ 2 * M * R₃ / (R₄ - R₃)
  rwa [hz] at hBC

-- ═══════════════════════════════════════════
-- KEY LEMMA 3: Three-Circles at target point
-- ═══════════════════════════════════════════

/-- Given inner bound ‖G‖ ≤ a on ‖z‖ = R₁ and outer bound ‖G‖ ≤ b on ‖z‖ = R₃,
    with G DiffContOnCl on the annulus, bound ‖G(z)‖ at ‖z‖ = R₂. -/
lemma three_circles_at_target
    {G : ℂ → ℂ} {R₁ R₂ R₃ a b : ℝ}
    (hR₁_pos : 0 < R₁) (h12 : R₁ < R₂) (h23 : R₂ < R₃)
    (hG : DiffContOnCl ℂ G {z : ℂ | R₁ ≤ ‖z‖ ∧ ‖z‖ ≤ R₃})
    (ha : ∀ z, ‖z‖ = R₁ → ‖G z‖ ≤ a)
    (hb : ∀ z, ‖z‖ = R₃ → ‖G z‖ ≤ b)
    (z : ℂ) (hz : ‖z‖ = R₂) :
    ‖G z‖ ≤ a ^ (1 - (Real.log ‖z‖ - Real.log R₁) / (Real.log R₃ - Real.log R₁)) *
             b ^ ((Real.log ‖z‖ - Real.log R₁) / (Real.log R₃ - Real.log R₁)) := by
  have hz₁ : R₁ ≤ ‖z‖ := by rw [hz]; linarith
  have hz₂ : ‖z‖ ≤ R₃ := by rw [hz]; linarith
  exact hadamard_three_circles hR₁_pos (by linarith : R₁ < R₃) hG ha hb z hz₁ hz₂

-- ═══════════════════════════════════════════
-- TEST: Check that it compiles
-- ═══════════════════════════════════════════

#check diffContOnCl_on_annulus_of_ball
#check bc_re_to_norm
#check three_circles_at_target

end ScratchExodia
