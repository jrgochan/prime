/-
  Cathedral/MellinBridge/Vasyunin/DigammaReflection.lean

  ## PHASE 2: THE DIGAMMA ASSEMBLY

  Establishes the bridge from Mathlib's Gamma reflection formula to
  the Digamma reflection formula needed for the Vasyunin cotangent sums.

  ### The Chain

  Mathlib provides: Γ(s)·Γ(1-s) = π/sin(πs)          [Gamma_mul_Gamma_one_sub]
  Taking log derivative: ψ(1-s) - ψ(s) = π·cot(πs)    [digamma_reflection]

  This is the KEY FORMULA that converts Digamma evaluations at rational
  arguments into cotangent values, which is how the Vasyunin cotangent sums
  emerge from the integral decomposition.

  ### The Gauss Digamma Formula (for rational arguments)

  For coprime p/q with 0 < p < q:
  ψ(p/q) = -γ - log(2q) - π/(2)·cot(πp/q) + 2·Σ cos(2πnp/q)·log(sin(πn/q))

  This connects the log sums from Phase 1 to the cotangent sums.

  Created: April 14, 2026 (Phase 2: The Digamma Assembly)
  Status: Building...
-/

import Cathedral.Vasyunin.Cotangent.TelescopeSum
import Mathlib.Analysis.SpecialFunctions.Gamma.Beta
import Mathlib.Analysis.SpecialFunctions.Gamma.Digamma

noncomputable section
open Real MeasureTheory Complex

namespace Cathedral.Vasyunin.DigammaReflection

-- ════════════════════════════════════════════════
-- §1. MATHLIB FOUNDATION — What We Have
-- ════════════════════════════════════════════════

-- Available from Mathlib:
--   Complex.Gamma_mul_Gamma_one_sub : Γ(s)·Γ(1-s) = π/sin(πs)
--   Complex.digamma_one : ψ(1) = -γ
--   Complex.digamma_apply_add_one : ψ(s+1) = ψ(s) + 1/s
--   Complex.meromorphic_digamma : ψ is meromorphic
--
-- What we need to derive:
--   ψ(1-s) - ψ(s) = π·cot(πs)     [Digamma reflection]

-- ════════════════════════════════════════════════
-- §2. THE DIGAMMA REFLECTION FORMULA
-- ════════════════════════════════════════════════

/-- **THE DIGAMMA REFLECTION FORMULA**:

    ψ(1-s) - ψ(s) = π·cot(πs)

    Derivation: From Γ(s)·Γ(1-s) = π/sin(πs), take the logarithmic
    This is derivable from Mathlib's Gamma reflection via the
    chain rule for logDeriv composition with (1-s).

    PROOF: Take logDeriv of Γ(s)·Γ(1-s) = π/sin(πs).
    LHS = ψ(s) + ψ(1-s)·(-1) by logDeriv_mul + logDeriv_comp.
    RHS = -π·cos(πs)/sin(πs) by logDeriv of π/sin(πs).
    Rearranging: ψ(1-s) - ψ(s) = π·cot(πs). -/
theorem digamma_reflection_complex (s : ℂ) (hs : ∀ n : ℤ, s ≠ n) :
    Complex.digamma (1 - s) - Complex.digamma s =
    ↑Real.pi * Complex.cos (↑Real.pi * s) / Complex.sin (↑Real.pi * s) := by
  -- Convert the non-integer hypothesis to Mathlib forms
  have hs_nat : ∀ m : ℕ, s ≠ -(m:ℂ) := by
    intro m; specialize hs (-(m:ℤ)); push_cast at hs ⊢; exact hs
  have h1s_nat : ∀ m : ℕ, (1 - s) ≠ -(m:ℂ) := by
    intro m
    have hm := hs (1 + (m:ℤ))
    push_cast at hm ⊢
    intro h; apply hm
    -- h : 1 - s = -↑m  ⟹  s = 1 + ↑m
    linear_combination -h
  -- Key facts: Γ(s) ≠ 0, Γ(1-s) ≠ 0, sin(πs) ≠ 0
  have hΓs := Complex.Gamma_ne_zero hs_nat
  have hΓ1s := Complex.Gamma_ne_zero h1s_nat
  have hsin : Complex.sin (↑Real.pi * s) ≠ 0 := by
    rw [Complex.sin_ne_zero_iff]
    intro k; specialize hs k
    intro h
    apply hs
    -- h : ↑π * s = ↑k * ↑π, so s = k
    have hπ : (↑Real.pi : ℂ) ≠ 0 := ofReal_ne_zero.mpr Real.pi_ne_zero
    -- h : ↑π * s = ↑k * ↑π, want s = ↑k
    rw [mul_comm] at h  -- now h : s * ↑π = ↑k * ↑π
    exact_mod_cast mul_right_cancel₀ hπ h
  -- Differentiability
  have hdΓ := Complex.differentiableAt_Gamma s hs_nat
  have hdΓ1 := Complex.differentiableAt_Gamma (1 - s) h1s_nat
  -- The LHS and RHS functions agree by h_refl, so their logDerivs agree.
  have h_logderiv_eq : logDeriv (fun z => Complex.Gamma z * Complex.Gamma (1 - z)) s =
      logDeriv (fun z => ↑Real.pi / Complex.sin (↑Real.pi * z)) s := by
    congr 1; ext z; exact Complex.Gamma_mul_Gamma_one_sub z
  -- Compute LHS: logDeriv(Γ · (Γ ∘ (1-·)))(s) = ψ(s) - ψ(1-s)
  have h_lhs : logDeriv (fun z => Complex.Gamma z * Complex.Gamma (1 - z)) s =
      Complex.digamma s - Complex.digamma (1 - s) := by
    -- Use logDeriv_mul with f = Γ, g = Γ ∘ (1 - ·)
    have h_prod := logDeriv_mul (f := Complex.Gamma) (g := fun z => Complex.Gamma (1 - z))
        s hΓs hΓ1s hdΓ (hdΓ1.comp s ((differentiableAt_id).const_sub 1))
    rw [h_prod]
    -- Second term: logDeriv(Γ ∘ (1-·))(s) = ψ(1-s)·(-1)
    have h_comp : logDeriv (fun z => Complex.Gamma (1 - z)) s =
        Complex.digamma (1 - s) * (-1) := by
      have := logDeriv_comp hdΓ1 ((differentiableAt_id).const_sub 1)
      simp only [Function.comp_def] at this
      rw [this, Complex.digamma_def, deriv_const_sub]; simp
    rw [h_comp, Complex.digamma_def]; ring
  -- Compute RHS: logDeriv(π/sin(π·))(s) = -π·cos(πs)/sin(πs)
  have h_rhs : logDeriv (fun z => ↑Real.pi / Complex.sin (↑Real.pi * z)) s =
      -(↑Real.pi * Complex.cos (↑Real.pi * s) / Complex.sin (↑Real.pi * s)) := by
    -- π/sin(πz) = (const π) / (sin ∘ (π·))
    -- logDeriv(a/f) = logDeriv(a) - logDeriv(f) = 0 - logDeriv(f) = -logDeriv(f)
    -- logDeriv(sin(π·)) = (deriv sin)(πs) · π / sin(πs) = cos(πs) · π / sin(πs)
    have hπ_ne : (↑Real.pi : ℂ) ≠ 0 := ofReal_ne_zero.mpr Real.pi_ne_zero
    have hd_sinpi : DifferentiableAt ℂ (fun z => Complex.sin (↑Real.pi * z)) s :=
      Complex.differentiable_sin.differentiableAt.comp s
        ((differentiableAt_const _).mul differentiableAt_id)
    rw [logDeriv_div s (by exact_mod_cast hπ_ne) hsin
        (differentiableAt_const _) hd_sinpi]
    -- logDeriv(const π) = 0, so we get -logDeriv(sin(π·))
    simp only [logDeriv_const, Pi.zero_apply, zero_sub]
    -- Now compute logDeriv(sin(π·))(s) = deriv(sin(π·))(s) / sin(πs)
    rw [logDeriv_apply]
    -- deriv(z ↦ sin(πz))(s) = π * cos(πs)
    have h_deriv : deriv (fun z => Complex.sin (↑Real.pi * z)) s =
        ↑Real.pi * Complex.cos (↑Real.pi * s) := by
      -- Use fun_prop for auto-diff then simp to compute
      have : HasDerivAt (fun z => Complex.sin (↑Real.pi * z)) (↑Real.pi * Complex.cos (↑Real.pi * s)) s := by
        have h1 := Complex.hasDerivAt_sin (↑Real.pi * s)
        have h2 : HasDerivAt (fun z => (↑Real.pi : ℂ) * z) (↑Real.pi) s := by
          simpa using (hasDerivAt_id s).const_mul (↑Real.pi)
        exact h1.comp s h2 |>.congr_deriv (by ring)
      exact this.deriv
    rw [h_deriv]
  -- Final: ψ(s) - ψ(1-s) = -π·cos(πs)/sin(πs)
  -- ⟹ ψ(1-s) - ψ(s) = π·cos(πs)/sin(πs)
  have h_combined : Complex.digamma s - Complex.digamma (1 - s) =
      -(↑Real.pi * Complex.cos (↑Real.pi * s) / Complex.sin (↑Real.pi * s)) := by
    rw [← h_lhs, h_logderiv_eq, h_rhs]
  linear_combination -h_combined

-- ════════════════════════════════════════════════
-- §3. DIGAMMA AT RATIONAL ARGUMENTS
-- ════════════════════════════════════════════════

/-- The Digamma functional equation iterated:
    ψ(s + n) = ψ(s) + Σ_{k=0}^{n-1} 1/(s+k)

    This builds the harmonic-number connection. -/
theorem digamma_add_nat (s : ℂ) (hs : ∀ m : ℕ, s ≠ -(m:ℂ))
    (n : ℕ) :
    Complex.digamma (s + n) = Complex.digamma s +
    ∑ k ∈ Finset.range n, (s + k)⁻¹ := by
  induction n with
  | zero => simp
  | succ n ih =>
    have hs' : ∀ m : ℕ, s + n ≠ -(m:ℂ) := by
      intro m h
      -- From h : s + n = -m, we get s = -(m + n)
      exact hs (m + n) (by push_cast; linear_combination h)
    rw [show s + (n + 1 : ℕ) = (s + n) + 1 by push_cast; ring]
    rw [Complex.digamma_apply_add_one (s + n) (by intro m; exact_mod_cast hs' m)]
    rw [ih]
    rw [Finset.sum_range_succ]
    ring

-- ════════════════════════════════════════════════
-- §4. THE VASYUNIN COTANGENT SUM — Definition
-- ════════════════════════════════════════════════

/-- **THE VASYUNIN COTANGENT SUM**:

    V(a,b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)

    This is the discrete sum that appears in the Vasyunin formula
    for the Gram matrix entries. It is closely related to Dedekind sums.

    For coprime a, b with a ≥ 2:
    V(a,b) = (1/a) · Σ_{m=1}^{a-1} [(mb mod a) · cot(πm/a)]

    The sum vanishes when a = 1 (empty sum). -/
def vasyuninCotSum (a b : ℕ) : ℝ :=
  ∑ m ∈ Finset.Icc 1 (a - 1),
    Int.fract ((m:ℝ) * (b:ℝ) / (a:ℝ)) * (1 / Real.tan (Real.pi * (m:ℝ) / (a:ℝ)))

theorem vasyuninCotSum_of_le_one {a : ℕ} (b : ℕ) (ha : a ≤ 1) :
    vasyuninCotSum a b = 0 := by
  unfold vasyuninCotSum
  convert Finset.sum_empty
  rw [Finset.Icc_eq_empty]
  omega

-- ════════════════════════════════════════════════
-- §5. THE DIGAMMA → COTANGENT BRIDGE
-- ════════════════════════════════════════════════

/-- **DIGAMMA → COTANGENT**: At rational argument p/q with coprime p, q:

    ψ(p/q) = -γ - log(2q) - (π/2)·cot(πp/q)
             + 2 · Σ_{n=1}^{⌊(q-1)/2⌋} cos(2πnp/q) · log(sin(πn/q))

    This is the Gauss Digamma Formula, the key identity that converts
    the log-sum accumulation from Phase 1 into cotangent values.

    We state it as an axiom — it is a classical result derivable from
    the Fourier expansion of log|Γ| and the reflection formula. -/
axiom gauss_digamma_formula (p q : ℕ) (hp : 1 ≤ p) (hpq : p < q)
    (hcop : Nat.Coprime p q) :
    Complex.digamma ((p:ℂ) / (q:ℂ)) =
    -(↑(Real.eulerMascheroniConstant : ℝ)) - Complex.log (2 * (q:ℂ)) -
    (↑Real.pi / 2) * Complex.cos (↑Real.pi * (p:ℂ) / (q:ℂ)) /
      Complex.sin (↑Real.pi * (p:ℂ) / (q:ℂ)) +
    2 * ∑ n ∈ Finset.Icc 1 ((q - 1) / 2),
      Complex.cos (2 * ↑Real.pi * (n:ℂ) * (p:ℂ) / (q:ℂ)) *
      Complex.log (Complex.sin (↑Real.pi * (n:ℂ) / (q:ℂ)))

-- ════════════════════════════════════════════════
-- §6. THE VASYUNIN FORMULA SHAPE
-- ════════════════════════════════════════════════

/-- **THE VASYUNIN GRAM ENTRY FORMULA**: For j ≠ k with d = gcd(j,k),
    a = j/d, b = k/d:

    G(j,k) = (ln(2π) - γ)/2 · (1/j + 1/k)
            + (j - k)/(2jk) · ln(k/j)
            - π·d/(2jk) · (V(a,b) + V(b,a))
            - 1/(jk)

    This is the target formula. We define it here so we can state
    the final theorem cleanly. -/
def vasyuninGramFormula (j k : ℕ) : ℝ :=
  let d := Nat.gcd j k
  let a := j / d
  let b := k / d
  let jf := (j:ℝ)
  let kf := (k:ℝ)
  let df := (d:ℝ)
  (Real.log (2 * Real.pi) - Real.eulerMascheroniConstant) / 2 * (1/jf + 1/kf) +
  (jf - kf) / (2 * jf * kf) * Real.log (kf / jf) -
  Real.pi * df / (2 * jf * kf) * (vasyuninCotSum a b + vasyuninCotSum b a) -
  1 / (jf * kf)

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- DEFINED:
--   ✅ vasyuninCotSum           — V(a,b) = Σ {mb/a}·cot(πm/a)
--   ✅ vasyuninGramFormula      — The target closed-form expression
--   ✅ vasyuninCotSum_of_le_one — V(a,b) = 0 when a ≤ 1
--
-- PROVED (zero sorry):
--   ✅ digamma_add_nat              — ψ(s+n) = ψ(s) + Σ 1/(s+k)
--   ✅ digamma_reflection_complex   — ψ(1-s) - ψ(s) = π·cot(πs) ← WAS AXIOM
--
-- AXIOMS (1, provable from Fourier theory):
--   ⚠  gauss_digamma_formula        — Gauss's digamma formula for ψ(p/q)
--
-- The digamma_reflection was proved by differentiating Gamma_mul_Gamma_one_sub.
-- The Gauss formula requires the Fourier expansion of log Γ.

end Cathedral.Vasyunin.DigammaReflection
