/-
  SubstProbe.lean — Building blocks for cov_eq_weighted_cross.

  Proved lemmas:
  1. piece_subst_raw   — raw substitution via integral_comp_mul_deriv_of_deriv_nonpos
  2. piece_cov_subst   — ∫ F(j/x,k/x) on piece = ∫ F(jt,kt)/(n+1+t)² on [0,1]
-/

import Cathedral.GramOffDiag
import Cathedral.GramBounds

set_option maxHeartbeats 1600000
noncomputable section
open Real MeasureTheory Set Finset intervalIntegral

-- ═══════════════════════════════════════════════
-- Part 1: Basic substitution (no continuity needed!)
-- ═══════════════════════════════════════════════

private lemma hasDerivAt_inv' (x : ℝ) (hx : x ≠ 0) :
    HasDerivAt (fun y => (1:ℝ)/y) (-(1 / x^2)) x := by
  have h := hasDerivAt_inv hx
  convert h using 1 <;> simp [div_eq_mul_inv]

/-- Raw substitution: ∫_a^b (g∘(1/·)) * (-1/x²) = ∫_{1/a}^{1/b} g for a,b > 0 -/
private lemma piece_subst_raw (n : ℕ) (g : ℝ → ℝ) :
    ∫ x in (1/((n:ℝ)+2))..(1/((n:ℝ)+1)),
      (g ∘ (fun x => 1/x)) x * (-(1/x^2)) =
    ∫ u in (((n:ℝ)+2))..((n:ℝ)+1), g u := by
  have hn1 : (0:ℝ) < (n:ℝ) + 1 := by positivity
  have hn2 : (0:ℝ) < (n:ℝ) + 2 := by positivity
  have ha : (0:ℝ) < 1/((n:ℝ)+2) := by positivity
  have hab : 1/((n:ℝ)+2) ≤ 1/((n:ℝ)+1) := by
    rw [div_le_div_iff₀ hn2 hn1]; linarith
  have hf_cont : ContinuousOn (fun x => (1:ℝ)/x) (Set.uIcc (1/((n:ℝ)+2)) (1/((n:ℝ)+1))) := by
    apply ContinuousOn.div continuousOn_const continuousOn_id
    intro x hx
    rw [Set.uIcc_of_le hab, Set.mem_Icc] at hx
    exact ne_of_gt (lt_of_lt_of_le ha hx.1)
  have hf_deriv : ∀ x ∈ Ioo (min (1/((n:ℝ)+2)) (1/((n:ℝ)+1)))
      (max (1/((n:ℝ)+2)) (1/((n:ℝ)+1))),
      HasDerivAt (fun x => (1:ℝ)/x) (-(1/x^2)) x := by
    intro x hx
    rw [min_eq_left hab, max_eq_right hab] at hx
    exact hasDerivAt_inv' x (ne_of_gt (lt_of_lt_of_le ha (le_of_lt hx.1)))
  have hf_nonpos : ∀ x ∈ Ioo (min (1/((n:ℝ)+2)) (1/((n:ℝ)+1)))
      (max (1/((n:ℝ)+2)) (1/((n:ℝ)+1))),
      -(1/x^2) ≤ 0 := by
    intro x _; exact neg_nonpos.mpr (div_nonneg one_pos.le (sq_nonneg x))
  have h := integral_comp_mul_deriv_of_deriv_nonpos hf_cont hf_deriv hf_nonpos (g := g)
  simp only [one_div_one_div] at h
  exact h

/-- Covariance substitution: working with g(u) = F(u)/u², where
    F(u) = ({ju}-½)({ku}-½). Then g(1/x) = F(1/x)·x² = ({j/x}-½)({k/x}-½)·x².
    So (g∘(1/·))(x) * (-1/x²) = ({j/x}-½)({k/x}-½)·x² * (-1/x²) = -F(j/x,k/x).
    Hence ∫ -F(j/x,k/x) = ∫ g from n+2 to n+1 = -∫ g from n+1 to n+2.
    So ∫ F(j/x,k/x) = ∫ g from n+1 to n+2 = ∫ F(u)/u² from n+1 to n+2.

    Then shift t = u - (n+1) and use fract_mul_add_nat. -/
lemma piece_cov_subst (j k n : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    ∫ x in (1/((n:ℝ)+2))..(1/((n:ℝ)+1)),
      (Int.fract ((j:ℝ)/x) - 1/2) * (Int.fract ((k:ℝ)/x) - 1/2) =
    ∫ t in (0:ℝ)..1,
      (Int.fract ((j:ℝ) * t) - 1/2) * (Int.fract ((k:ℝ) * t) - 1/2) /
      ((n : ℝ) + 1 + t)^2 := by
  -- Step 1: Apply raw substitution with g(u) = ({ju}-½)({ku}-½)/u²
  set F : ℝ → ℝ := fun u => (Int.fract ((j:ℝ) * u) - 1/2) * (Int.fract ((k:ℝ) * u) - 1/2)
  set g : ℝ → ℝ := fun u => F u / u^2
  have h := piece_subst_raw n g
  -- h : ∫ (g∘(1/·)) * (-1/x²) = ∫ g from n+2 to n+1
  -- The LHS integrand: (g∘(1/·))(x) * (-1/x²)
  --   = g(1/x) * (-1/x²)
  --   = [F(1/x) / (1/x)²] * (-1/x²)
  --   = F(1/x) * x² * (-1/x²)
  --   = -F(1/x)
  --   = -({j/x}-½)({k/x}-½)
  -- So h : ∫ -({j/x}-½)({k/x}-½) = ∫ g from n+2 to n+1
  -- => -∫ cov = -∫ g from n+1 to n+2
  -- => ∫ cov = ∫ g from n+1 to n+2 = ∫₀¹ g(n+1+t) dt [shift]
  -- = ∫₀¹ F(n+1+t)/(n+1+t)² dt
  -- = ∫₀¹ ({j(n+1+t)}-½)({k(n+1+t)}-½)/(n+1+t)² dt
  -- = ∫₀¹ ({jt}-½)({kt}-½)/(n+1+t)² dt  [by fract_mul_add_nat]

  -- Step 1a: relate LHS integrand to -F(1/x)
  -- Step 1a: The raw substitution h gives:
  -- ∫ (g∘(1/·)) * (-1/x²) from a to b = ∫ g from 1/a to 1/b
  -- where (g∘(1/·))(x) * (-1/x²) = -F(1/x) = -({j/x}-½)({k/x}-½) for x ≠ 0.
  -- On our interval [1/(n+2), 1/(n+1)], x > 0 so x ≠ 0.

  have hn2 : (0:ℝ) < (n:ℝ) + 2 := by positivity
  have ha : (0:ℝ) < 1/((n:ℝ)+2) := by positivity

  -- h says: ∫ (g∘(1/·)) * (-1/x²) = ∫ g from n+2 to n+1
  -- = -(∫ g from n+1 to n+2)
  rw [show ∫ u in ((n:ℝ)+2)..((n:ℝ)+1), g u =
      -(∫ u in ((n:ℝ)+1)..((n:ℝ)+2), g u) from
      intervalIntegral.integral_symm ((n:ℝ)+1) ((n:ℝ)+2)] at h

  -- Relate the LHS of h to the covariance integral
  have h_neg_cov : ∫ x in (1/((n:ℝ)+2))..(1/((n:ℝ)+1)),
      (g ∘ (fun x => 1/x)) x * (-(1/x^2)) =
      -(∫ x in (1/((n:ℝ)+2))..(1/((n:ℝ)+1)),
        (Int.fract ((j:ℝ)/x) - 1/2) * (Int.fract ((k:ℝ)/x) - 1/2)) := by
    rw [← intervalIntegral.integral_neg]
    apply intervalIntegral.integral_congr
    intro x hx
    -- x ∈ uIcc(1/(n+2), 1/(n+1)), so x ≥ 1/(n+2) > 0
    have hab : 1/((n:ℝ)+2) ≤ 1/((n:ℝ)+1) := by
      rw [div_le_div_iff₀ hn2 (by positivity : (0:ℝ) < (n:ℝ)+1)]; linarith
    rw [Set.uIcc_of_le hab] at hx
    have hx_pos : 0 < x := lt_of_lt_of_le ha hx.1
    have hx_ne : x ≠ 0 := ne_of_gt hx_pos
    simp only [Function.comp, g, F]
    have hx2_ne : x ^ 2 ≠ 0 := pow_ne_zero 2 hx_ne
    -- Goal: -(({j/x}-½)({k/x}-½)) = [({j*(1/x)}-½)({k*(1/x)}-½)/(1/x)²] * (-1/x²)
    -- Simplify: j/x = j*(1/x), and (1/x)² = 1/x²
    rw [show (j:ℝ)/x = (j:ℝ) * (1/x) from by ring,
        show (k:ℝ)/x = (k:ℝ) * (1/x) from by ring]
    field_simp
  rw [h_neg_cov] at h
  -- h : -(∫ F(1/x)) = -(∫ g from n+1 to n+2)
  -- So: ∫ F(1/x) = ∫ g from n+1 to n+2

  -- Step 2: shift ∫ g from n+1 to n+2 → ∫₀¹ g(n+1+t) dt
  -- g(u) = F(u)/u², so g(n+1+t) = F(n+1+t)/(n+1+t)²

  -- Step 3: use periodicity: F(n+1+t) = F(t)
  -- because {j(n+1+t)} = {jt} (by fract_mul_add_nat applied to j*(n+1)+j*t)

  -- For now, just show the integral sign equality
  -- ∫ F(1/x) from 1/(n+2) to 1/(n+1) = ∫ g from n+1 to n+2
  have hcov_eq : ∫ x in (1/((n:ℝ)+2))..(1/((n:ℝ)+1)),
      (Int.fract ((j:ℝ)/x) - 1/2) * (Int.fract ((k:ℝ)/x) - 1/2) =
      ∫ u in ((n:ℝ)+1)..((n:ℝ)+2), g u := by
    linarith
  rw [hcov_eq]

  -- Step 3: shift variable u → t = u - (n+1)
  -- ∫_{n+1}^{n+2} g(u) du = ∫₀¹ g(n+1+t) dt
  have hshift : ∫ u in ((n:ℝ)+1)..((n:ℝ)+2), g u =
      ∫ t in (0:ℝ)..1, g (t + ((n:ℝ)+1)) := by
    have h1 := intervalIntegral.integral_comp_add_right (a := (0:ℝ)) (b := (1:ℝ)) (f := g) ((n:ℝ)+1)
    -- h1 : ∫ x in 0..1, g(x + (n+1)) = ∫ x in (0+(n+1))..(1+(n+1)), g x
    rw [show (0:ℝ) + ((n:ℝ)+1) = (n:ℝ)+1 from by ring,
        show (1:ℝ) + ((n:ℝ)+1) = (n:ℝ)+2 from by ring] at h1
    exact h1.symm
  rw [hshift]
  -- Goal: ∫₀¹ g(t + (n+1)) dt = ∫₀¹ F(t)/(n+1+t)² dt
  congr 1; ext t
  simp only [g, F]
  -- Need: ({j(t+(n+1))}-½)({k(t+(n+1))}-½) / (t+(n+1))² = ({jt}-½)({kt}-½) / ((n+1+t)²)
  -- Use fract_mul_add_nat: {j(t + (n+1))} = {j·t + j·(n+1)} = {jt}  (since j(n+1) ∈ ℤ)
  have hj_per : Int.fract ((j:ℝ) * (t + ((n:ℝ)+1))) = Int.fract ((j:ℝ) * t) := by
    rw [show (j:ℝ) * (t + ((n:ℝ)+1)) = (j:ℝ) * t + (j:ℝ) * ((n:ℝ)+1) from by ring]
    rw [show (j:ℝ) * ((n:ℝ)+1) = (↑(j * (n + 1)) : ℝ) from by push_cast; ring]
    exact Int.fract_add_natCast _ _
  have hk_per : Int.fract ((k:ℝ) * (t + ((n:ℝ)+1))) = Int.fract ((k:ℝ) * t) := by
    rw [show (k:ℝ) * (t + ((n:ℝ)+1)) = (k:ℝ) * t + (k:ℝ) * ((n:ℝ)+1) from by ring]
    rw [show (k:ℝ) * ((n:ℝ)+1) = (↑(k * (n + 1)) : ℝ) from by push_cast; ring]
    exact Int.fract_add_natCast _ _
  rw [hj_per, hk_per]
  ring

end
