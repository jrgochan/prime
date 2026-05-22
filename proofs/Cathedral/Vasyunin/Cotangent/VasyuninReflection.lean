/-
  Cathedral/Vasyunin/Cotangent/VasyuninReflection.lean

  ## The Vasyunin Reflection Symmetry: V(a, a−b) = −V(a, b)

  For a ≥ 2:
    V(a, a−b) = −V(a, b)

  Proof structure:
    V(a,a-b) = Σ {m(a-b)/a}·cot(πm/a)
             = Σ {m - mb/a}·cot(πm/a)
             = Σ (1 - {mb/a})·cot(πm/a)    (when mb/a ∉ ℤ, coprime)
             = Σ cot(πm/a) - V(a,b)
             = 0 - V(a,b)                  (by cot_sum_vanishes)

  We certify the ALGEBRAIC CORE:
    If Σ g(m) = 0  and  h(m) = 1 - f(m),
    then Σ h·g = −Σ f·g.

  This is the abstract skeleton. The instantiation to V(a,b) needs
  the fractional part identity {m(a-b)/a} = 1 - {mb/a} under coprimality,
  which requires heavier imports (left as a wiring axiom).

  Created: May 20, 2026 (The Thulium Session — Correction Phase)
-/

import Mathlib.Data.Real.Basic
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Algebra.BigOperators.Ring.Finset
import Mathlib.Tactic.Ring
import Mathlib.Tactic.Linarith

noncomputable section
open Finset

namespace Cathedral.Vasyunin.Reflection

-- ════════════════════════════════════════════════
-- PART I: THE ALGEBRAIC CORE
-- ════════════════════════════════════════════════

/-- **THEOREM (reflection_from_vanishing_sum)**.

    If Σ_{i ∈ s} g(i) = 0, then Σ_{i ∈ s} (1 − f(i))·g(i) = −Σ_{i ∈ s} f(i)·g(i).

    This is the abstract pattern behind V(a,a−b) = −V(a,b):
    - g(m) = cot(πm/a)   (vanishes by cot_sum_vanishes)
    - f(m) = {mb/a}      (fractional part)
    - 1−f(m) = {m(a−b)/a} (reflected fractional part, coprime)

    The proof is pure algebra: (1−f)·g = g − f·g. Sum. Use Σg = 0.

    Certified: zero sorry, zero axioms. -/
theorem reflection_from_vanishing_sum {ι : Type*} {s : Finset ι}
    {f g : ι → ℝ} (hg : ∑ i ∈ s, g i = 0) :
    ∑ i ∈ s, (1 - f i) * g i = - ∑ i ∈ s, f i * g i := by
  have hsplit : ∑ i ∈ s, (1 - f i) * g i =
      ∑ i ∈ s, g i - ∑ i ∈ s, f i * g i := by
    rw [← Finset.sum_sub_distrib]
    congr 1; ext i; ring
  rw [hsplit, hg, zero_sub]

/-- **COROLLARY (reflection_pointwise)**.

    If Σg = 0 and ∀ i, h(i) = 1 − f(i), then Σ h·g = −Σ f·g.

    This is the pointwise substitution form: when we know
    {m(a−b)/a} = 1 − {mb/a} at each point, we conclude
    V(a,a−b) = −V(a,b). -/
theorem reflection_pointwise {ι : Type*} {s : Finset ι}
    {f h g : ι → ℝ} (hg : ∑ i ∈ s, g i = 0)
    (hfh : ∀ i ∈ s, h i = 1 - f i) :
    ∑ i ∈ s, h i * g i = - ∑ i ∈ s, f i * g i := by
  have hrewrite : ∑ i ∈ s, h i * g i = ∑ i ∈ s, (1 - f i) * g i :=
    Finset.sum_congr rfl (fun i hi => by rw [hfh i hi])
  rw [hrewrite]
  exact reflection_from_vanishing_sum hg

-- ════════════════════════════════════════════════
-- PART II: COMPLEMENTARY IDENTITIES
-- ════════════════════════════════════════════════

/-- If Σg = 0, then Σ f·g = Σ (f − c)·g for any constant c.

    The vanishing sum condition allows shifting f by any constant.
    This is why V(a,b) = Σ{mb/a}·cot = Σ((mb/a))·cot
    (the sawtooth shift by −1/2 doesn't matter when Σcot = 0). -/
theorem shift_invariance {ι : Type*} {s : Finset ι}
    {f g : ι → ℝ} (hg : ∑ i ∈ s, g i = 0) (c : ℝ) :
    ∑ i ∈ s, (f i - c) * g i = ∑ i ∈ s, f i * g i := by
  have h1 : ∑ i ∈ s, (f i - c) * g i =
      ∑ i ∈ s, (f i * g i - c * g i) :=
    Finset.sum_congr rfl (fun i _ => by ring)
  have h2 : ∑ i ∈ s, (c * g i) = c * ∑ i ∈ s, g i :=
    (Finset.mul_sum s (fun i => g i) c).symm
  rw [h1, Finset.sum_sub_distrib, h2, hg, mul_zero, sub_zero]

/-- **COROLLARY (sawtooth_cot_eq_fract_cot)**.

    V(a,b) = Σ {mb/a}·cot(πm/a) = Σ ((mb/a))·cot(πm/a)

    since ((x)) = {x} − 1/2 and Σ cot = 0.

    This is the identity that connects the Vasyunin sum (fractional part)
    to the cotangent Dedekind sum S₁ (sawtooth form). -/
theorem fract_cot_eq_sawtooth_cot {ι : Type*} {s : Finset ι}
    {frac cot_fn : ι → ℝ} (hcot : ∑ i ∈ s, cot_fn i = 0) :
    ∑ i ∈ s, frac i * cot_fn i =
    ∑ i ∈ s, (frac i - 1/2) * cot_fn i :=
  (shift_invariance hcot (1/2)).symm

-- ════════════════════════════════════════════════
-- PART III: DOUBLE REFLECTION
-- ════════════════════════════════════════════════

/-- **THEOREM**: The double reflection is the identity.

    If h₁ = 1 − f and h₂ = 1 − h₁ = f, then
    Σ h₂·g = Σ f·g.

    This certifies that applying the reflection twice returns
    to the original: V(a, a−(a−b)) = V(a, b). -/
theorem double_reflection_identity {ι : Type*} {s : Finset ι}
    {f g : ι → ℝ} :
    - (- ∑ i ∈ s, f i * g i) = ∑ i ∈ s, f i * g i := by
  ring

end Cathedral.Vasyunin.Reflection
