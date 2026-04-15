/-
  Cathedral/Robin/HarmonicBounds.lean

  ## Harmonic Number Infrastructure

  The logarithmic sandwich that drives the Lagarias inequality:
    log(n+1) ≤ H_n ≤ 1 + log(n)

  All theorems use Mathlib's Harmonic.Bounds API.
  The Bounds theorems are natively real-valued (using implicit ℚ → ℝ cast).
-/

import Cathedral.Robin.Defs
import Mathlib.NumberTheory.Harmonic.Bounds
import Mathlib.NumberTheory.Harmonic.Int

open Real

-- ════════════════════════════════════════════════
-- PART I: POSITIVITY
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: H_n > 0 for n ≥ 1. -/
theorem harmonicR_pos {n : ℕ} (hn : 1 ≤ n) : 0 < harmonicR n := by
  unfold harmonicR
  exact_mod_cast harmonic_pos (by omega : n ≠ 0)

-- ════════════════════════════════════════════════
-- PART II: THE LOGARITHMIC SANDWICH
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: log(n+1) ≤ H_n.
    Lower bound from integral comparison (Mathlib).

    Mathlib's `log_add_one_le_harmonic` has type:
    `Real.log ↑(n + 1) ≤ (harmonic n : ℝ)` -/
theorem harmonicR_lower (n : ℕ) : log ↑(n + 1) ≤ harmonicR n := by
  unfold harmonicR
  exact log_add_one_le_harmonic n

/-- **THEOREM (PROVED)**: H_n ≤ 1 + log(n).
    Upper bound from integral comparison (Mathlib).

    Mathlib's `harmonic_le_one_add_log` has type:
    `(harmonic n : ℝ) ≤ 1 + Real.log ↑n` -/
theorem harmonicR_upper (n : ℕ) : harmonicR n ≤ 1 + log ↑n := by
  unfold harmonicR
  exact harmonic_le_one_add_log n

-- ════════════════════════════════════════════════
-- PART III: EXACT VALUES
-- ════════════════════════════════════════════════

/-- **THEOREM (PROVED)**: H₁ = 1. -/
theorem harmonicR_one : harmonicR 1 = 1 := by
  unfold harmonicR; norm_num

/-- **THEOREM (PROVED)**: H₂ = 3/2. -/
theorem harmonicR_two : harmonicR 2 = 3/2 := by
  unfold harmonicR; norm_num

/-- **THEOREM (PROVED)**: H₁ is positive (special case). -/
theorem harmonicR_one_pos : (0 : ℝ) < harmonicR 1 := by
  rw [harmonicR_one]; norm_num

/-- **THEOREM (PROVED)**: H₃ = 11/6. -/
theorem harmonicR_three : harmonicR 3 = 11/6 := by
  unfold harmonicR; norm_num

/-- **THEOREM (PROVED)**: H₄ = 25/12. -/
theorem harmonicR_four : harmonicR 4 = 25/12 := by
  unfold harmonicR; norm_num

/-- **THEOREM (PROVED)**: H_{n+1} > H_n for all n ≥ 1.
    Since H_{n+1} = H_n + 1/(n+1) and 1/(n+1) > 0. -/
theorem harmonicR_succ_gt {n : ℕ} (hn : 1 ≤ n) : harmonicR n < harmonicR (n + 1) := by
  unfold harmonicR
  have : (harmonic (n + 1) : ℝ) = (harmonic n : ℝ) + (1 : ℝ) / ((n : ℝ) + 1) := by
    rw [harmonic_succ]
    simp
  rw [this]
  linarith [show (0 : ℝ) < 1 / ((n : ℝ) + 1) from by positivity]

-- ════════════════════════════════════════════════
-- PART IV: LOGARITHMIC TAYLOR BOUNDS
-- ════════════════════════════════════════════════

/-- log(1+x) ≥ x - x²/2 + x³/3 - x⁴/4 for x ≥ 0.
    Proof: h(x) = log(1+x) - (x - x²/2 + x³/3 - x⁴/4) has h(0) = 0 and
    h'(x) = x⁴/(1+x) ≥ 0, so h is monotone.
    (Formerly in archived GramDiag.lean, moved here April 2026.) -/
lemma log_lower_quartic (x : ℝ) (hx : 0 ≤ x) :
    x - x^2/2 + x^3/3 - x^4/4 ≤ Real.log (1 + x) := by
  suffices h : 0 ≤ Real.log (1 + x) - (x - x^2/2 + x^3/3 - x^4/4) by linarith
  set f : ℝ → ℝ := fun t => Real.log (1 + t) - (t - t^2/2 + t^3/3 - t^4/4) with hf_def
  have hf0 : f 0 = 0 := by simp [hf_def, Real.log_one]
  have hcont : ContinuousOn f (Set.Ici 0) := by
    simp only [hf_def]
    apply ContinuousOn.sub
    · exact ContinuousOn.log (continuousOn_const.add continuousOn_id) (fun t ht => by
        simp only [Set.mem_Ici] at ht; linarith)
    · fun_prop
  have hdiff : DifferentiableOn ℝ f (interior (Set.Ici (0:ℝ))) := by
    simp only [interior_Ici, hf_def]
    intro t ht; simp only [Set.mem_Ioi] at ht
    apply DifferentiableAt.differentiableWithinAt
    apply DifferentiableAt.sub
    · exact (differentiableAt_id.const_add 1).log (ne_of_gt (by linarith : (0:ℝ) < 1 + t))
    · fun_prop
  have hderiv : ∀ t ∈ interior (Set.Ici (0:ℝ)), 0 ≤ deriv f t := by
    intro t ht; simp only [interior_Ici, Set.mem_Ioi] at ht
    have h1t : (0:ℝ) < 1 + t := by linarith
    have hdf : HasDerivAt f (t^4 / (1+t)) t := by
      simp only [hf_def]
      have h1 := (hasDerivAt_id t).const_add 1 |>.log (ne_of_gt h1t)
      have h2 := hasDerivAt_id t
      have h3 := (hasDerivAt_pow 2 t).div_const 2
      have h4 := (hasDerivAt_pow 3 t).div_const 3
      have h5 := (hasDerivAt_pow 4 t).div_const 4
      refine (h1.sub (((h2.sub h3).add h4).sub h5)).congr_deriv ?_
      simp only [id]; field_simp; ring
    rw [hdf.deriv]
    exact div_nonneg (pow_nonneg (le_of_lt ht) 4) (le_of_lt h1t)
  have hmono : MonotoneOn f (Set.Ici 0) :=
    monotoneOn_of_deriv_nonneg (convex_Ici 0) hcont hdiff hderiv
  have hfx : f 0 ≤ f x := hmono (Set.mem_Ici.mpr (le_refl 0)) (Set.mem_Ici.mpr hx) hx
  rw [hf0] at hfx; exact hfx

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- This file has:
--   ZERO sorry
--   ZERO axioms
--   10 PROVED theorems:
--     ✅ harmonicR_pos          — H_n > 0
--     ✅ harmonicR_lower        — log(n+1) ≤ H_n
--     ✅ harmonicR_upper        — H_n ≤ 1 + log(n)
--     ✅ harmonicR_one          — H₁ = 1
--     ✅ harmonicR_two          — H₂ = 3/2
--     ✅ harmonicR_one_pos      — 0 < H₁
--     ✅ harmonicR_three        — H₃ = 11/6
--     ✅ harmonicR_four         — H₄ = 25/12
--     ✅ harmonicR_succ_gt      — H_{n+1} > H_n
--     ✅ log_lower_quartic      — log(1+x) ≥ x - x²/2 + x³/3 - x⁴/4

