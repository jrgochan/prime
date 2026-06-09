/-
  Cathedral/Vasyunin/Cotangent/VasyuninDigammaBridge.lean

  ## THE VASYUNIN-DIGAMMA BRIDGE

  ════════════════════════════════════════════════════════════════

  Expresses the Vasyunin cotangent sum V(a,b) in terms of the
  digamma function ψ, using the proved identity:

    cot(πm/a) = (1/π) · (ψ((a-m)/a) - ψ(m/a))

  Combined with the proved digamma sum identity:

    Σ_{m=1}^{a-1} ψ(m/a) = -(a-1)γ - a·log(a)

  this gives a complete algebraic/analytic handle on V(a,b).

  ### The Bridge

  V(a,b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)
         = (1/π) · Σ_{m=1}^{a-1} {mb/a} · (ψ((a-m)/a) - ψ(m/a))

  This is the link from the spatial (Gram matrix) world to the
  analytic (digamma/Mellin) world. The Gram entry becomes a
  weighted sum of digamma values at rationals.

  Created: June 8, 2026 — 2:47 AM, Sunglasses Session 🕶️💎🐴
  Status: Building the wire...
-/

import Cathedral.Vasyunin.Cotangent.DigammaReflection
import Cathedral.Analysis.GammaMultiplication
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic

noncomputable section
open Real Finset

namespace Cathedral.Vasyunin.DigammaBridge

-- ════════════════════════════════════════════════════════════════
-- §1. THE COT → DIGAMMA SUBSTITUTION (real version)
-- ════════════════════════════════════════════════════════════════

/-- **The real cotangent-digamma identity** (GRADUATED 💜):

    For 1 ≤ m < a:
      cot(πm/a) = (1/π) · (ψ((a-m)/a) - ψ(m/a))

    PROVED by casting the complex `digamma_reflection_rational`
    through `digamma_ofReal` (both proved in the Cathedral),
    then extracting via `Complex.ofReal_injective`.

    Sophie Germain would be proud. 💜 -/
theorem cot_eq_digamma_real (m a : ℕ) (hm : 1 ≤ m) (hma : m < a) :
    1 / Real.tan (Real.pi * m / a) =
    (1 / Real.pi) *
    (logDeriv Real.Gamma ((a - m : ℕ) / (a : ℝ)) - logDeriv Real.Gamma ((m : ℝ) / a)) := by
  -- Setup: positivity for the rational arguments
  have ha_pos : (0 : ℝ) < a := Nat.cast_pos.mpr (by omega)
  have pos_nneg : ∀ (x : ℝ), 0 < x → ∀ n : ℕ, x ≠ -(n : ℝ) :=
    fun x hx n => by linarith [show (0:ℝ) ≤ (n:ℝ) from Nat.cast_nonneg n]
  have hm_pos : (0 : ℝ) < (m : ℝ) / a := div_pos (Nat.cast_pos.mpr (by omega)) ha_pos
  have ham_pos : (0 : ℝ) < ((a - m : ℕ) : ℝ) / a :=
    div_pos (Nat.cast_pos.mpr (by omega)) ha_pos
  -- Step 1: The PROVED complex identity
  have h := Cathedral.Vasyunin.DigammaReflection.digamma_reflection_rational m a hm hma
  -- Step 2: digamma_ofReal (PROVED): ψ_ℂ(↑s) = ↑(logDeriv Γ s)
  have hψ1 := Cathedral.Analysis.GammaMultiplication.digamma_ofReal
    ((a - m : ℕ) / (a : ℝ)) (pos_nneg _ ham_pos)
  have hψ2 := Cathedral.Analysis.GammaMultiplication.digamma_ofReal
    ((m : ℝ) / a) (pos_nneg _ hm_pos)
  -- Step 3: Cast ℝ rationals ↑(n/a) = (n:ℂ)/(a:ℂ) for substitution
  rw [show (↑((a - m : ℕ) / (a : ℝ)) : ℂ) = ((a - m : ℕ) : ℂ) / (a : ℂ)
    from by push_cast; rfl] at hψ1
  rw [show (↑((m : ℝ) / (a : ℝ)) : ℂ) = (m : ℂ) / (a : ℂ)
    from by push_cast; rfl] at hψ2
  -- Step 4: Substitute ψ_ℂ → ↑(logDeriv Γ) in the complex identity
  rw [hψ1, hψ2] at h
  -- h : ↑(ψ₁) - ↑(ψ₂) = ↑π · cos_ℂ(↑π·(m:ℂ)/(a:ℂ)) / sin_ℂ(↑π·(m:ℂ)/(a:ℂ))
  -- Step 5: Combine LHS as ↑(difference)
  rw [← Complex.ofReal_sub] at h
  -- Step 6: Show RHS is also ↑(real expression)
  have h_rhs : (↑Real.pi : ℂ) * Complex.cos (↑Real.pi * ((m:ℂ) / (a:ℂ))) /
      Complex.sin (↑Real.pi * ((m:ℂ) / (a:ℂ))) =
      ↑(Real.pi * Real.cos (Real.pi * m / a) / Real.sin (Real.pi * m / a)) := by
    -- Cast the trig argument: ↑π · (m:ℂ)/(a:ℂ) = ↑(π·m/a)
    have harg : (↑Real.pi : ℂ) * ((m:ℂ) / (a:ℂ)) = ↑(Real.pi * (m:ℝ) / (a:ℝ)) := by
      push_cast; ring
    rw [harg]
    -- Complex.cos(↑θ) = ↑(cos θ), Complex.sin(↑θ) = ↑(sin θ)
    rw [← Complex.ofReal_cos, ← Complex.ofReal_sin]
    -- ↑π · ↑(cos θ) / ↑(sin θ) = ↑(π · cos θ / sin θ)
    push_cast; ring
  rw [h_rhs] at h
  -- Step 7: Extract real equation via ofReal injectivity
  -- h : ↑(ψ₁ - ψ₂) = ↑(π · cos θ / sin θ)
  have h_real := Complex.ofReal_injective h
  -- h_real : ψ₁ - ψ₂ = π · cos(πm/a) / sin(πm/a)
  -- Step 8: Convert to goal form: 1/tan = (1/π)·(ψ-ψ) = cos/sin
  rw [h_real]
  -- Goal: 1/tan(πm/a) = (1/π) · (π · cos(πm/a) / sin(πm/a))
  have hpi_ne : Real.pi ≠ 0 := Real.pi_ne_zero
  -- Simplify RHS: (1/π) · (π · cos / sin) = cos / sin
  rw [show (1 / Real.pi) * (Real.pi * Real.cos (Real.pi * ↑m / ↑a) /
      Real.sin (Real.pi * ↑m / ↑a)) =
      Real.cos (Real.pi * ↑m / ↑a) / Real.sin (Real.pi * ↑m / ↑a)
    from by field_simp]
  -- Goal: (tan(πm/a))⁻¹ = cos(πm/a) / sin(πm/a)
  -- tan = sin/cos, so tan⁻¹ = (sin/cos)⁻¹ = cos/sin ✓
  rw [Real.tan_eq_sin_div_cos]
  simp [inv_div]

-- ════════════════════════════════════════════════════════════════
-- §2. THE VASYUNIN-DIGAMMA BRIDGE
-- ════════════════════════════════════════════════════════════════

/-- **THE VASYUNIN-DIGAMMA BRIDGE**.

    V(a,b) = (1/π) · Σ_{m=1}^{a-1} {mb/a} · (ψ((a-m)/a) - ψ(m/a))

    This expresses the Vasyunin cotangent sum ENTIRELY in terms
    of the digamma function, which has known evaluations at
    rational arguments (Gauss digamma formula, now proved).

    Proof sketch: substitute cot(πm/a) = (1/π)(ψ((a-m)/a) - ψ(m/a))
    into each term of V(a,b) = Σ {mb/a} · cot(πm/a).

    This is the LAST WIRING before the Gram entry becomes a
    closed form expressible via γ and log. -/
theorem vasyunin_as_digamma (a b : ℕ) (ha : 2 ≤ a) :
    Cathedral.Vasyunin.DigammaReflection.vasyuninCotSum a b =
    (1 / Real.pi) *
    ∑ m ∈ Icc 1 (a - 1),
      Int.fract ((m : ℝ) * b / a) *
      (logDeriv Real.Gamma ((a - m : ℕ) / (a : ℝ)) - logDeriv Real.Gamma ((m : ℝ) / a)) := by
  unfold Cathedral.Vasyunin.DigammaReflection.vasyuninCotSum
  rw [Finset.mul_sum]
  apply Finset.sum_congr rfl
  intro m hm
  rw [Finset.mem_Icc] at hm
  have hm1 : 1 ≤ m := hm.1
  have hma : m < a := by omega
  rw [cot_eq_digamma_real m a hm1 hma]
  ring

-- ════════════════════════════════════════════════════════════════
-- §3. THE GRAM ENTRY AS DIGAMMA
-- ════════════════════════════════════════════════════════════════

/-- **THE GRAM ENTRY DIGAMMA FORM**.

    For j ≠ k with d = gcd(j,k), a = j/d, b = k/d:

    G(j,k) = (C/2)·(1/j + 1/k)
           + (j-k)/(2jk)·ln(k/j)
           - d/(2jk) · Σ_{m} {mb/a}·(ψ((a-m)/a) - ψ(m/a))
           - d/(2jk) · Σ_{m} {ma/b}·(ψ((b-m)/b) - ψ(m/b))
           - 1/(jk)

    where C = ln(2π) - γ.

    This is EXACTLY the Vasyunin Gram formula from DigammaReflection.lean
    with the V+V terms replaced by their digamma form.

    All digamma values at rationals are computable via the Gauss formula.
    The γ emerges from ψ(1) = -γ.
    The ln(4π) emerges from the combination of ln(2π) in C and
    the log terms in the Gauss digamma formula.

    This is where γ + ln(4π) comes from. 💎 -/
theorem gram_entry_digamma_form (j k : ℕ) (_hj : 2 ≤ j) (_hk : 2 ≤ k) (_hjk : j ≠ k) :
    let d := Nat.gcd j k
    let a := j / d
    let b := k / d
    Cathedral.Vasyunin.DigammaReflection.vasyuninGramFormula j k =
    (Real.log (2 * Real.pi) - eulerMascheroniConstant) / 2 * (1/(j:ℝ) + 1/(k:ℝ)) +
    ((j:ℝ) - k) / (2 * j * k) * Real.log ((k:ℝ) / j) -
    Real.pi * (d:ℝ) / (2 * j * k) *
      ((1 / Real.pi) *
       (∑ m ∈ Icc 1 (a - 1),
         Int.fract ((m:ℝ) * b / a) *
         (logDeriv Real.Gamma (((a - m : ℕ):ℝ) / a) - logDeriv Real.Gamma ((m:ℝ) / a))) +
       (1 / Real.pi) *
       (∑ m ∈ Icc 1 (b - 1),
         Int.fract ((m:ℝ) * a / b) *
         (logDeriv Real.Gamma (((b - m : ℕ):ℝ) / b) - logDeriv Real.Gamma ((m:ℝ) / b)))) -
    1 / ((j:ℝ) * k) := by
  -- The key insight: vasyuninGramFormula uses V(a,b)+V(b,a) where
  -- V(x,y) = vasyuninCotSum x y. By vasyunin_as_digamma,
  -- each V becomes (1/π)·Σ of digamma differences.
  -- The proof is: unfold the definition, substitute the proved identity.
  unfold Cathedral.Vasyunin.DigammaReflection.vasyuninGramFormula
  simp only []
  -- We need j/d ≥ 2 and k/d ≥ 2 to apply vasyunin_as_digamma.
  -- Since j ≥ 2, k ≥ 2, j ≠ k, and d = gcd(j,k):
  --   If d = j, then a = 1 and j | k, so k ≥ 2j (since j ≠ k and j | k),
  --   giving b = k/j ≥ 2. In this case V(a=1,b) = 0 (empty sum) and
  --   the (1/π)·Σ over Icc 1 0 is also 0. ✓
  --   Symmetrically for d = k.
  -- So we handle a ≤ 1 ∨ b ≤ 1 with empty-sum matching.
  -- For now we use a single rewrite:
  have ha_cases : 2 ≤ j / Nat.gcd j k ∨ j / Nat.gcd j k ≤ 1 := by omega
  have hb_cases : 2 ≤ k / Nat.gcd j k ∨ k / Nat.gcd j k ≤ 1 := by omega
  -- Rewrite V(a,b) and V(b,a) using the digamma bridge
  rcases ha_cases with ha2 | ha1
  · -- a ≥ 2: can apply vasyunin_as_digamma to V(a,b)
    rw [vasyunin_as_digamma (j / Nat.gcd j k) (k / Nat.gcd j k) ha2]
    rcases hb_cases with hb2 | hb1
    · -- b ≥ 2: can apply vasyunin_as_digamma to V(b,a)
      rw [vasyunin_as_digamma (k / Nat.gcd j k) (j / Nat.gcd j k) hb2]
    · -- b ≤ 1: V(b,a) = 0 and Icc 1 (b-1) = ∅
      rw [Cathedral.Vasyunin.DigammaReflection.vasyuninCotSum_of_le_one
        (j / Nat.gcd j k) hb1]
      have : k / Nat.gcd j k - 1 = 0 := by omega
      rw [this]; simp []
  · -- a ≤ 1: V(a,b) = 0
    rw [Cathedral.Vasyunin.DigammaReflection.vasyuninCotSum_of_le_one
      (k / Nat.gcd j k) ha1]
    have : j / Nat.gcd j k - 1 = 0 := by omega
    rcases hb_cases with hb2 | hb1
    · rw [vasyunin_as_digamma (k / Nat.gcd j k) (j / Nat.gcd j k) hb2]
      rw [this]; simp []
    · rw [Cathedral.Vasyunin.DigammaReflection.vasyuninCotSum_of_le_one
        (j / Nat.gcd j k) hb1]
      have hb0 : k / Nat.gcd j k - 1 = 0 := by omega
      rw [this, hb0]; simp []

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit — VasyuninDigammaBridge.lean (June 8, 2026)

### Sorry: 1
  `gram_entry_digamma_form` — needs vasyuninGramFormula unfolding + substitution.
  The pieces are all proved; this is pure wiring.

### Custom Axioms: 1
  `cot_eq_digamma_real` — Real version of the complex digamma reflection.
  Graduation: apply digamma_ofReal (proved in GammaMultiplication.lean)
  to digamma_reflection_rational (proved in DigammaReflection.lean).
  This is pure type-casting, ~20 lines.

### Theorems: 1
  `vasyunin_as_digamma` — V(a,b) = (1/π) · Σ frac · (ψ-ψ). **PROVED** ✅

### THE BRIDGE MAP 🌉💎

```
DigammaReflection.lean
  digamma_reflection_rational [PROVED]
    ↓ cot_eq_digamma_real [axiom, graduable]
    ↓
VasyuninDigammaBridge.lean (THIS FILE)
  vasyunin_as_digamma [PROVED] ← THE KEY STONE
    ↓
  gram_entry_digamma_form [sorry, wiring]
    ↓
  vtGv = 1 - (γ+ln(4π))/lnN [needs Mellin sum]
    ↓
  Diamond 53 💎🐴🌟💜
```

June 8, 2026. 2:47 AM. Sunglasses at night.
c = the speed at which light crosses the bridge. 🕶️🌉💎🐴
-/

end Cathedral.Vasyunin.DigammaBridge

end
