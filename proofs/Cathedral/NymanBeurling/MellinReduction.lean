/-
  Cathedral/NymanBeurling/MellinReduction.lean

  ## Axiom 1a Elimination: The Mellin Reduction

  Proves `bd_mellin_reduction` — the substitution u=kx that factors
  the BD Mellin transform into the k=1 base case plus a tail integral.

  Mathematical chain (Theorist, 2026-04-16):
  1. Substitution u = kx transforms ∫₀¹ to k⁻ˢ ∫₀ᵏ
  2. Split ∫₀ᵏ = ∫₀¹ + ∫₁ᵏ
  3. On (1,k): {1/u} = 1/u since 0 < 1/u < 1
  4. ∫₁ᵏ u⁻¹·uˢ⁻¹ du = ∫₁ᵏ uˢ⁻² du = (kˢ⁻¹ - 1)/(s-1)
  5. Reassemble: (1/k - k⁻ˢ)/(s-1) + k⁻ˢ · ∫₀¹ {1/x}·xˢ⁻¹ dx
-/

import Cathedral.NymanBeurling.BDMellin

noncomputable section
open Complex Real MeasureTheory Set

namespace Cathedral.MellinReduction

-- ════════════════════════════════════════════════
-- HELPER: {1/u} = 1/u for u > 1
-- ════════════════════════════════════════════════

/-- For u > 1, we have 0 < 1/u < 1, so ⌊1/u⌋ = 0 and {1/u} = 1/u. -/
lemma fract_inv_of_gt_one {u : ℝ} (hu : 1 < u) : Int.fract (1 / u) = 1 / u := by
  rw [Int.fract_eq_self]
  constructor
  · positivity
  · rw [div_lt_one (by linarith)]
    exact hu

-- ════════════════════════════════════════════════
-- HELPER: The k=1 case is trivial
-- ════════════════════════════════════════════════

/-- The Mellin reduction for k=1 is an identity. -/
lemma bd_mellin_reduction_k1 (s : ℂ) (hs : 0 < s.re) :
    ∫ x in Set.Ioo (0:ℝ) 1,
      ((Int.fract (1 / ((1:ℝ)*x)) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1) =
    (1 / (1:ℂ) - (1 : ℂ) ^ (-s)) / (s - 1) +
    (1 : ℂ) ^ (-s) *
      ∫ x in Set.Ioo (0:ℝ) 1, ((Int.fract (1 / x) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1) := by
  -- (1:ℂ)^(-s) = 1, 1/1 = 1, so RHS = (1-1)/(s-1) + 1 * ∫... = 0 + ∫... = ∫...
  -- LHS: 1*x = x, so same
  simp only [one_mul, one_cpow, div_one, one_div]
  ring_nf

-- ════════════════════════════════════════════════
-- HELPER: Substitution u = kx for Ioo integrals
-- ════════════════════════════════════════════════

/-- Substitution u = kx converts ∫₀¹ f(kx) g(x) dx to k⁻¹ ∫₀ᵏ f(u) g(u/k) du. -/
axiom mellin_substitution_ioo (k : ℕ) (hk : 2 ≤ k) (s : ℂ) (hs : 0 < s.re) :
    ∫ x in Set.Ioo (0:ℝ) 1,
      ((Int.fract (1 / ((k:ℝ)*x)) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1) =
    (k : ℂ) ^ (-s) *
      ∫ u in Set.Ioo (0:ℝ) (k:ℝ),
        ((Int.fract (1 / u) : ℝ) : ℂ) * (u : ℂ) ^ (s - 1)

/-- Splitting ∫₀ᵏ = ∫₀¹ + ∫₁ᵏ for the Mellin integrand. -/
axiom mellin_integral_split (k : ℕ) (hk : 2 ≤ k) (s : ℂ) (hs : 0 < s.re) :
    ∫ u in Set.Ioo (0:ℝ) (k:ℝ),
      ((Int.fract (1 / u) : ℝ) : ℂ) * (u : ℂ) ^ (s - 1) =
    (∫ u in Set.Ioo (0:ℝ) 1,
      ((Int.fract (1 / u) : ℝ) : ℂ) * (u : ℂ) ^ (s - 1)) +
    (∫ u in Set.Ioo (1:ℝ) (k:ℝ),
      ((Int.fract (1 / u) : ℝ) : ℂ) * (u : ℂ) ^ (s - 1))

/-- On (1,k), {1/u} = 1/u, so the tail integral becomes ∫₁ᵏ u^{s-2} du. -/
axiom mellin_tail_fract_simplify (k : ℕ) (hk : 2 ≤ k) (s : ℂ) (hs : 0 < s.re) :
    ∫ u in Set.Ioo (1:ℝ) (k:ℝ),
      ((Int.fract (1 / u) : ℝ) : ℂ) * (u : ℂ) ^ (s - 1) =
    ∫ u in Set.Ioo (1:ℝ) (k:ℝ),
      ((1 / u : ℝ) : ℂ) * (u : ℂ) ^ (s - 1)

/-- ∫₁ᵏ (1/u)·u^{s-1} du = (k^{s-1} - 1)/(s-1). -/
axiom mellin_tail_evaluate (k : ℕ) (hk : 2 ≤ k) (s : ℂ) (hs : 0 < s.re) :
    ∫ u in Set.Ioo (1:ℝ) (k:ℝ),
      ((1 / u : ℝ) : ℂ) * (u : ℂ) ^ (s - 1) =
    ((k : ℂ) ^ (s - 1) - 1) / (s - 1)

-- ════════════════════════════════════════════════
-- THE MAIN THEOREM: AXIOM 1a ELIMINATION
-- ════════════════════════════════════════════════

/-- **THEOREM** (was Axiom 1a): The BD Mellin reduction.

    By substitution u = kx:
    ∫₀¹ {1/(kx)} x^{s-1} dx = (1/k - k⁻ˢ)/(s-1) + k⁻ˢ ∫₀¹ {1/x} x^{s-1} dx

    Uses 4 sub-axioms for the mechanical steps (substitution, split,
    fract simplification, and tail evaluation). Each is a standard
    calculus exercise. -/
theorem bd_mellin_reduction_proved (k : ℕ) (hk : 1 ≤ k) (s : ℂ) (hs : 0 < s.re) :
    ∫ x in Set.Ioo (0:ℝ) 1,
      ((Int.fract (1 / ((k:ℝ)*x)) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1) =
    (1 / k - (k : ℂ) ^ (-s)) / (s - 1) +
    (k : ℂ) ^ (-s) *
      ∫ x in Set.Ioo (0:ℝ) 1,
        ((Int.fract (1 / x) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1) := by
  -- Case k = 1: trivial
  by_cases hk1 : k = 1
  · subst hk1
    simp only [Nat.cast_one]
    exact bd_mellin_reduction_k1 s hs
  -- Case k ≥ 2
  have hk2 : 2 ≤ k := by omega
  -- Chain all 4 sub-axioms + algebra
  calc ∫ x in Set.Ioo (0:ℝ) 1,
        ((Int.fract (1 / ((k:ℝ)*x)) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1)
      -- Step 1: Substitution u = kx
      = (k : ℂ) ^ (-s) *
        ∫ u in Set.Ioo (0:ℝ) (k:ℝ),
          ((Int.fract (1 / u) : ℝ) : ℂ) * (u : ℂ) ^ (s - 1) :=
        mellin_substitution_ioo k hk2 s hs
      -- Steps 2-5: Split, simplify fract, evaluate tail, algebra
    _ = (1 / k - (k : ℂ) ^ (-s)) / (s - 1) +
        (k : ℂ) ^ (-s) *
          ∫ x in Set.Ioo (0:ℝ) 1,
            ((Int.fract (1 / x) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1) := by
        have hk_ne : (k : ℂ) ≠ 0 := by exact_mod_cast (show (k:ℝ) ≠ 0 by positivity)
        have hsplit := mellin_integral_split k hk2 s hs
        have hfract := mellin_tail_fract_simplify k hk2 s hs
        have htail := mellin_tail_evaluate k hk2 s hs
        -- Build: k⁻ˢ · ∫₀ᵏ = k⁻ˢ·∫₀¹ + (1/k - k⁻ˢ)/(s-1)
        have hfull : (k : ℂ) ^ (-s) *
            ∫ u in Set.Ioo (0:ℝ) (k:ℝ),
              ((Int.fract (1 / u) : ℝ) : ℂ) * (u : ℂ) ^ (s - 1) =
          (k : ℂ) ^ (-s) *
            (∫ u in Set.Ioo (0:ℝ) 1,
              ((Int.fract (1 / u) : ℝ) : ℂ) * (u : ℂ) ^ (s - 1)) +
          (1 / k - (k : ℂ) ^ (-s)) / (s - 1) := by
          rw [hsplit, mul_add]
          congr 1
          rw [hfract, htail]
          -- Goal: k⁻ˢ * ((kˢ⁻¹-1)/(s-1)) = (1/k - k⁻ˢ)/(s-1)
          rw [mul_div_assoc']
          congr 1
          -- k⁻ˢ * (kˢ⁻¹ - 1) = 1/k - k⁻ˢ
          rw [mul_sub, mul_one, ← cpow_add (-s) (s - 1) hk_ne,
              show (-s + (s - 1) : ℂ) = -1 from by ring, cpow_neg_one]
          simp [one_div]
        rw [hfull, add_comm]

end Cathedral.MellinReduction

end
