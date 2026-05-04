/-
  Cathedral/Zeta/ZetaMeromorphic.lean

  ## The Riemann Zeta Function is Meromorphic

  Exploration 25 — Phase 1 of the Littlewood Maneuver.
  Gives the Cathedral its first globally meromorphic Riemann zeta function.

  ### Strategy
  - For s ≠ 1: ζ is differentiable on {1}ᶜ (open set) → analytic → meromorphic.
  - For s = 1: Use n = 2. The function (z-1)² · ζ(z) evaluates to 0 at z=1
    and has limit 0. By the removable singularity theorem, it is analytic.

  ### Dependencies: Mathlib (ζ, MeromorphicAt, RemovableSingularity, CauchyIntegral).
-/

import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.Analysis.Meromorphic.Basic
import Mathlib.Analysis.Complex.RemovableSingularity
import Mathlib.Analysis.Complex.CauchyIntegral

noncomputable section
open Complex Filter Set
open scoped Topology

namespace Cathedral.Zeta.ZetaMeromorphic

-- ═══════════════════════════════════════════
-- §1. MeromorphicAt for s ≠ 1
-- ═══════════════════════════════════════════

/-- ζ is differentiable on {1}ᶜ, which is open. -/
private lemma riemannZeta_differentiableOn :
    DifferentiableOn ℂ riemannZeta {(1 : ℂ)}ᶜ :=
  fun _s hs => (differentiableAt_riemannZeta hs).differentiableWithinAt

/-- ζ(s) is meromorphic at any s ≠ 1. -/
theorem riemannZeta_meromorphicAt_ne_one {s : ℂ} (hs : s ≠ 1) :
    MeromorphicAt riemannZeta s :=
  (riemannZeta_differentiableOn.analyticAt
    (isOpen_compl_singleton.mem_nhds hs)).meromorphicAt

-- ═══════════════════════════════════════════
-- §2. MeromorphicAt at s = 1 (Simple Pole)
-- ═══════════════════════════════════════════

/-- (z-1)² · ζ(z) is continuous at z = 1.

    Value at z=1: 0²·ζ(1) = 0.
    Limit at z=1: 0 (since (z-1)·[(z-1)·ζ(z)] → 0·1 = 0). -/
private lemma continuousAt_sq_mul_zeta :
    ContinuousAt (fun z => (z - 1) ^ 2 * riemannZeta z) 1 := by
  -- Suffices: Tendsto f (𝓝 1) (𝓝 (f 1)) where f 1 = 0
  rw [ContinuousAt]
  simp only [sub_self, zero_pow, ne_eq, OfNat.ofNat_ne_zero, not_false_eq_true, zero_mul]
  -- Need: Tendsto (fun z => (z-1)^2 * ζ(z)) (𝓝 1) (𝓝 0)
  -- Use Metric.tendsto_nhds: for all ε > 0, eventually dist(f z, 0) < ε
  rw [Metric.tendsto_nhds]
  intro ε hε
  -- Get δ₁ from residue: dist((z-1)*ζ(z), 1) < 1 eventually on 𝓝[≠] 1
  have h_res_evt : ∀ᶠ z in 𝓝[≠] (1:ℂ), dist ((z - 1) * riemannZeta z) 1 < 1 :=
    riemannZeta_residue_one.eventually (Metric.ball_mem_nhds 1 one_pos)
  -- Extract δ₁ from the punctured nhd filter
  rw [eventually_nhdsWithin_iff] at h_res_evt
  -- h_res_evt : ∀ᶠ z in 𝓝 1, z ∈ {1}ᶜ → dist((z-1)*ζ(z), 1) < 1
  rw [Metric.eventually_nhds_iff] at h_res_evt
  obtain ⟨δ₁, hδ₁_pos, hδ₁⟩ := h_res_evt
  -- Get δ₂ = ε/2 for ‖z-1‖ < ε/2
  set δ := min δ₁ (ε / 2) with hδ_def
  have hδ_pos : 0 < δ := lt_min hδ₁_pos (half_pos hε)
  rw [Metric.eventually_nhds_iff]
  refine ⟨δ, hδ_pos, fun z hz => ?_⟩
  rw [dist_zero_right]
  by_cases hne : z = 1
  · subst hne; simp [sub_self, hε]
  · -- z ≠ 1: use the residue bound
    have hz_δ₁ : dist z 1 < δ₁ := lt_of_lt_of_le hz (min_le_left _ _)
    have hz_ε2 : dist z 1 < ε / 2 := lt_of_lt_of_le hz (min_le_right _ _)
    -- From residue: dist((z-1)*ζ(z), 1) < 1, so ‖(z-1)*ζ(z)‖ ≤ 2
    have h_ne_mem : z ∈ ({(1:ℂ)}ᶜ : Set ℂ) := by
      simp only [mem_compl_iff, mem_singleton_iff]; exact hne
    have h_res : dist ((z - 1) * riemannZeta z) 1 < 1 := hδ₁ hz_δ₁ h_ne_mem
    rw [dist_eq_norm] at h_res
    have h_triangle := norm_le_insert' ((z - 1) * riemannZeta z) (1 : ℂ)
    -- norm_le_insert' : ‖a‖ ≤ ‖a - b‖ + ‖b‖
    -- So ‖(z-1)*ζ(z)‖ ≤ ‖(z-1)*ζ(z) - 1‖ + ‖1‖ = ‖(z-1)*ζ(z) - 1‖ + 1
    simp only [norm_one] at h_triangle
    have h_bound : ‖(z - 1) * riemannZeta z‖ ≤ 2 := by linarith
    -- ‖(z-1)^2 * ζ(z)‖ = ‖z-1‖ · ‖(z-1)*ζ(z)‖ ≤ (ε/2) · 2 = ε
    have h_factor : ‖(z - 1) ^ 2 * riemannZeta z‖ =
        ‖z - 1‖ * ‖(z - 1) * riemannZeta z‖ := by
      rw [show (z - 1) ^ 2 * riemannZeta z = (z - 1) * ((z - 1) * riemannZeta z) from by ring,
          norm_mul]
    rw [h_factor]
    rw [dist_eq_norm] at hz_ε2
    nlinarith [norm_nonneg ((z - 1) * riemannZeta z), norm_nonneg (z - 1)]

/-- The Riemann zeta function is meromorphic at s = 1 (simple pole).

    Uses n = 2: (z-1)² · ζ(z) has value 0 at z=1 matching its limit,
    so the removable singularity theorem gives analyticity. -/
theorem riemannZeta_meromorphicAt_one : MeromorphicAt riemannZeta 1 := by
  refine ⟨2, ?_⟩
  simp only [smul_eq_mul]
  apply analyticAt_of_differentiable_on_punctured_nhds_of_continuousAt
  · -- (z-1)^2 * ζ(z) is differentiable for z ≠ 1
    apply eventually_nhdsWithin_of_forall
    intro z (hz : z ≠ 1)
    exact ((differentiableAt_id.sub (differentiableAt_const 1)).pow 2).mul
      (differentiableAt_riemannZeta hz)
  · -- (z-1)^2 * ζ(z) is continuous at z = 1
    exact continuousAt_sq_mul_zeta

-- ═══════════════════════════════════════════
-- §3. Global Meromorphy
-- ═══════════════════════════════════════════

/-- **THEOREM**: The Riemann zeta function is meromorphic at every point. -/
theorem riemannZeta_meromorphicAt (s : ℂ) : MeromorphicAt riemannZeta s := by
  by_cases hs : s = 1
  · subst hs; exact riemannZeta_meromorphicAt_one
  · exact riemannZeta_meromorphicAt_ne_one hs

/-- The Riemann zeta function is meromorphic on any set. -/
theorem riemannZeta_meromorphicOn (U : Set ℂ) : MeromorphicOn riemannZeta U :=
  fun s _ => riemannZeta_meromorphicAt s

/-- The Riemann zeta function is globally meromorphic (ℂ → ℂ). -/
theorem riemannZeta_meromorphic : Meromorphic riemannZeta :=
  fun s => riemannZeta_meromorphicAt s

end Cathedral.Zeta.ZetaMeromorphic
