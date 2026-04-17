/-
  Cathedral/MellinBridge/DomainConnected.lean

  Proves that {s : ℂ | 0 < s.re ∧ s ≠ 1} is preconnected.
  Uses explicit path construction.
-/
import Mathlib.Analysis.Convex.PathConnected
import Mathlib.Analysis.Complex.Basic

noncomputable section
open Complex Set

private def p_up : ℂ := 2 + 2 * I
private def p_down : ℂ := 2 - 2 * I

private lemma p_up_re : p_up.re = 2 := by unfold p_up; simp
private lemma p_down_re : p_down.re = 2 := by unfold p_down; simp

private lemma p_up_mem :
    0 < p_up.re ∧ p_up ≠ 1 := by
  refine ⟨by rw [p_up_re]; norm_num, ?_⟩
  unfold p_up; intro h
  have him := congr_arg Complex.im h; simp at him

private lemma p_down_mem :
    0 < p_down.re ∧ p_down ≠ 1 := by
  refine ⟨by rw [p_down_re]; norm_num, ?_⟩
  unfold p_down; intro h
  have him := congr_arg Complex.im h; simp at him

/-- Points on a segment between Re > 0 endpoints have Re > 0. -/
private lemma re_pos_of_segment {a b : ℂ} (ha : 0 < a.re) (hb : 0 < b.re)
    {z : ℂ} (hz : z ∈ segment ℝ a b) : 0 < z.re := by
  obtain ⟨c, d, hc, hd, hcd, rfl⟩ := hz
  simp only [add_re, smul_re]
  rcases eq_or_lt_of_le hc with rfl | hc_pos
  · simp at hcd; rw [hcd]; simp; exact hb
  · exact add_pos_of_pos_of_nonneg (mul_pos hc_pos ha) (mul_nonneg hd hb.le)

/-- For any a ≠ 1, at least one of the line segments a to p_up or a to p_down
    avoids 1. -/
private lemma not_both_blocked (a : ℂ) (ha_ne : a ≠ 1) :
    (∀ z ∈ segment ℝ a p_up, z ≠ 1) ∨ (∀ z ∈ segment ℝ a p_down, z ≠ 1) := by
  -- By contradiction: suppose both segments contain 1
  by_contra hboth
  push Not at hboth
  obtain ⟨⟨z₁, hz₁, rfl⟩, ⟨z₂, hz₂, rfl⟩⟩ := hboth
  -- z₁ = 1 ∈ segment a p_up: ∃ c₁ d₁ ≥ 0, c₁+d₁=1, c₁•a + d₁•p_up = 1
  obtain ⟨c₁, d₁, hc₁, hd₁, hcd₁, heq₁⟩ := hz₁
  -- z₂ = 1 ∈ segment a p_down: ∃ c₂ d₂ ≥ 0, c₂+d₂=1, c₂•a + d₂•p_down = 1
  obtain ⟨c₂, d₂, hc₂, hd₂, hcd₂, heq₂⟩ := hz₂
  -- From imaginary parts:
  -- c₁·a.im + 2·d₁ = 0  (from heq₁)
  -- c₂·a.im - 2·d₂ = 0  (from heq₂)
  have him₁ : c₁ * a.im + d₁ * 2 = 0 := by
    have := congr_arg Complex.im heq₁
    unfold p_up at this
    simp at this; linarith
  have him₂ : c₂ * a.im - d₂ * 2 = 0 := by
    have := congr_arg Complex.im heq₂
    unfold p_down at this
    simp at this; linarith
  -- From him₁: d₁ = -c₁·a.im/2, so c₁·a.im = -2·d₁ ≤ 0
  have h1 : c₁ * a.im ≤ 0 := by linarith
  -- From him₂: d₂ = c₂·a.im/2, so c₂·a.im = 2·d₂ ≥ 0
  have h2 : c₂ * a.im ≥ 0 := by linarith
  -- c₁ > 0 (since c₁ + d₁ = 1 and d₁ ≥ 0, c₁ ≤ 1; if c₁ = 0, d₁ = 1 and p_up = 1, false)
  have hc₁_pos : 0 < c₁ := by
    rcases eq_or_lt_of_le hc₁ with rfl | h
    · simp at hcd₁; rw [hcd₁] at heq₁; simp [p_up] at heq₁
      -- 1 • p_up = p_up = 2 + 2I ≠ 1
      have := congr_arg Complex.im heq₁
      simp at this
    · exact h
  have hc₂_pos : 0 < c₂ := by
    rcases eq_or_lt_of_le hc₂ with rfl | h
    · simp at hcd₂; rw [hcd₂] at heq₂; simp [p_down] at heq₂
      have := congr_arg Complex.im heq₂
      simp at this
    · exact h
  -- From h1 and hc₁_pos: a.im ≤ 0
  have ha_im_le : a.im ≤ 0 := by nlinarith
  -- From h2 and hc₂_pos: a.im ≥ 0
  have ha_im_ge : a.im ≥ 0 := by nlinarith
  -- Therefore a.im = 0
  have ha_im : a.im = 0 := le_antisymm ha_im_le ha_im_ge
  have hd₁_zero : d₁ = 0 := by
    have : c₁ * a.im = 0 := by rw [ha_im]; ring
    linarith
  -- Then c₁ = 1
  have hc₁_one : c₁ = 1 := by linarith
  -- From heq₁: 1•a + 0•p_up = a = 1
  have : a = 1 := by
    rw [hc₁_one, hd₁_zero] at heq₁
    simp at heq₁; exact heq₁
  exact ha_ne this

/-- On the segment p_up to p_down, Re equals 2. -/
private lemma re_eq_two_on_segment {z : ℂ} (hz : z ∈ segment ℝ p_up p_down) :
    z.re = 2 := by
  obtain ⟨c, d, hc, hd, hcd, rfl⟩ := hz
  have h1 : (c • p_up).re = c * 2 := by simp [p_up_re]
  have h2 : (d • p_down).re = d * 2 := by simp [p_down_re]
  simp only [add_re, h1, h2]
  linarith

/-- The segment from p_up to p_down stays in {Re > 0, ≠ 1}. -/
private lemma segment_up_down_subset : segment ℝ p_up p_down ⊆ {s : ℂ | 0 < s.re ∧ s ≠ 1} := by
  intro z hz
  refine ⟨by linarith [re_eq_two_on_segment hz], ?_⟩
  intro heq
  linarith [re_eq_two_on_segment hz, congr_arg Complex.re heq, one_re]

/-- {Re > 0} \ {1} is path-connected. -/
theorem domain_path_connected :
    IsPathConnected {s : ℂ | 0 < s.re ∧ s ≠ 1} := by
  refine ⟨p_up, p_up_mem, fun {s} hs => ?_⟩
  rcases not_both_blocked s hs.2 with h | h
  · -- Segment s → p_up avoids 1 and stays in {Re > 0}
    have hseg : segment ℝ s p_up ⊆ {s : ℂ | 0 < s.re ∧ s ≠ 1} := fun z hz =>
      ⟨re_pos_of_segment hs.1 (by rw [p_up_re]; norm_num) hz, h z hz⟩
    exact (JoinedIn.of_segment_subset hseg).symm
  · -- Segment s → p_down, then p_down → p_up
    have hseg1 : segment ℝ s p_down ⊆ {s : ℂ | 0 < s.re ∧ s ≠ 1} := fun z hz =>
      ⟨re_pos_of_segment hs.1 (by rw [p_down_re]; norm_num) hz, h z hz⟩
    exact ((JoinedIn.of_segment_subset hseg1).trans (JoinedIn.of_segment_subset segment_up_down_subset).symm).symm

/-- {Re > 0} \ {1} is preconnected. -/
theorem domain_preconnected : IsPreconnected {s : ℂ | 0 < s.re ∧ s ≠ 1} :=
  domain_path_connected.isConnected.isPreconnected
