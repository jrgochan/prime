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
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic

noncomputable section
open Real Finset

namespace Cathedral.Vasyunin.DigammaBridge

-- ════════════════════════════════════════════════════════════════
-- §1. THE COT → DIGAMMA SUBSTITUTION (real version)
-- ════════════════════════════════════════════════════════════════

/-- **The real cotangent-digamma identity**:

    For 1 ≤ m < a:
      cot(πm/a) = (1/π) · (ψ((a-m)/a) - ψ(m/a))

    This is the REAL VERSION of digamma_reflection_rational,
    extracted from the complex statement via Complex.ofReal casting.

    The Complex version is already proved in DigammaReflection.lean.
    This states the relationship we need for the Vasyunin bridge.

    For now we state this as an axiom that follows from the proved
    complex version by taking real parts. The graduation is
    straightforward (Complex.digamma at real points = real logDeriv Γ,
    which is proved as digamma_ofReal in GammaMultiplication.lean). -/
axiom cot_eq_digamma_real (m a : ℕ) (hm : 1 ≤ m) (hma : m < a) :
    1 / Real.tan (Real.pi * m / a) =
    (1 / Real.pi) *
    (logDeriv Real.Gamma ((a - m : ℕ) / (a : ℝ)) - logDeriv Real.Gamma ((m : ℝ) / a))

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
theorem gram_entry_digamma_form (j k : ℕ) (hj : 2 ≤ j) (hk : 2 ≤ k) (hjk : j ≠ k) :
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
  sorry -- Needs: unfold vasyuninGramFormula, substitute vasyunin_as_digamma

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
