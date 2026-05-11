import Mathlib.Analysis.SpecialFunctions.Log.Deriv
import Mathlib.Analysis.Calculus.Deriv.MeanValue
import Mathlib.Algebra.Order.Floor.Semifield

open Real Set

noncomputable section

-- ═══ INFRASTRUCTURE: Derivative-based log bounds ═══

private def g (x : ℝ) : ℝ := x - x⁻¹ - 2 * Real.log x

private lemma g_hasDerivAt (x : ℝ) (hx : x ≠ 0) :
    HasDerivAt g ((x - 1)^2 / x^2) x := by
  have h : HasDerivAt g (1 - (-(x ^ 2)⁻¹) - 2 * x⁻¹) x :=
    ((hasDerivAt_id x).sub (hasDerivAt_inv hx)).sub ((hasDerivAt_log hx).const_mul 2)
  convert h using 1; field_simp; ring

private lemma g_nonneg {x : ℝ} (hx : 1 ≤ x) : 0 ≤ g x := by
  have hne : ∀ y : ℝ, y ∈ Ici (1:ℝ) → y ≠ 0 :=
    fun y hy => ne_of_gt (lt_of_lt_of_le one_pos hy)
  have hmono : MonotoneOn g (Ici 1) :=
    monotoneOn_of_deriv_nonneg (convex_Ici 1)
      ((continuousOn_id.sub (continuousOn_inv₀.mono hne)).sub
        (continuousOn_const.mul (continuousOn_log.mono hne)))
      (fun y hy => (g_hasDerivAt y (hne y (interior_subset hy))).differentiableAt.differentiableWithinAt)
      (fun y hy => by rw [(g_hasDerivAt y (hne y (interior_subset hy))).deriv]; positivity)
  have g1 : g 1 = 0 := by simp [g, Real.log_one]
  linarith [hmono (mem_Ici.mpr le_rfl) (mem_Ici.mpr hx) hx]

-- AM log bound: log((m+1)/m) ≤ (2m+1)/(2m(m+1))
lemma log_le_am (m : ℕ) (hm : 1 ≤ m) :
    Real.log (((m:ℝ) + 1) / (m:ℝ)) ≤
    (2*(m:ℝ) + 1) / (2*(m:ℝ)*((m:ℝ) + 1)) := by
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have hx_ge : 1 ≤ ((m:ℝ) + 1) / (m:ℝ) := by rw [le_div_iff₀ hm_pos]; linarith
  have hg := g_nonneg hx_ge
  simp only [g, inv_div] at hg
  have heq : ((m:ℝ) + 1) / (m:ℝ) - (m:ℝ) / ((m:ℝ) + 1) =
      (2*(m:ℝ) + 1) / ((m:ℝ) * ((m:ℝ) + 1)) := by field_simp; ring
  suffices 2 * Real.log (((m:ℝ) + 1) / (m:ℝ)) ≤
      2 * ((2*(m:ℝ) + 1) / (2*(m:ℝ)*((m:ℝ) + 1))) by linarith
  have : 2 * ((2*(m:ℝ) + 1) / (2*(m:ℝ)*((m:ℝ) + 1))) =
      (2*(m:ℝ) + 1) / ((m:ℝ) * ((m:ℝ) + 1)) := by field_simp
  rw [this]; linarith

-- Simple upper bound: log((m+1)/m) ≤ 1/m
lemma log_le_inv (m : ℕ) (hm : 1 ≤ m) :
    Real.log (((m:ℝ) + 1) / (m:ℝ)) ≤ 1 / (m:ℝ) := by
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have h := log_le_sub_one_of_pos (show (0:ℝ) < ((m:ℝ) + 1) / (m:ℝ) by positivity)
  have : ((m:ℝ) + 1) / (m:ℝ) - 1 = 1 / (m:ℝ) := by field_simp; ring
  linarith

-- Simple lower bound: log((m+1)/m) ≥ 1/(m+1)
lemma log_ge_inv_succ (m : ℕ) (hm : 1 ≤ m) :
    1 / ((m:ℝ) + 1) ≤ Real.log (((m:ℝ) + 1) / (m:ℝ)) := by
  have hm_pos : (0:ℝ) < (m:ℝ) := Nat.cast_pos.mpr (by omega)
  have h := one_sub_inv_le_log_of_pos (show (0:ℝ) < ((m:ℝ) + 1) / (m:ℝ) by positivity)
  rw [inv_div] at h
  have : 1 - (m:ℝ) / ((m:ℝ) + 1) = 1 / ((m:ℝ) + 1) := by field_simp; ring
  linarith

-- ═══ TEST: rowTerm_nonneg skeleton ═══
-- R(m) = 1/b - (n/a + m/b)·L + n/(a(m+1))
-- Using AM bound L ≤ (2m+1)/(2m(m+1)):
-- R ≥ (am - bn)/(2abm(m+1)) where n = ⌊am/b⌋
-- Since b·⌊am/b⌋ ≤ am, we have am - bn ≥ 0. ✓

-- R(m) ≤ (a+b)/(ab) · 1/m² via using L ≤ 1/m and L ≥ 1/(m+1)
