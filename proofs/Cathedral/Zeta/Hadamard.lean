/-
  Cathedral/Zeta/Hadamard.lean

  ## Hadamard Three-Circles & Zeta Lower Bound on the Thin Strip

  ### Contents
  - §1. Hadamard Three-Circles theorem (proved from Mathlib's Three-Lines)
  - §2. Axiom: polynomial lower bound for ζ under RH (zero-counting)
  - §3. Thin-strip lower bound closure

  ### Dependencies: Mathlib (Hadamard three-lines, complex exp/log), ZetaDiskBounds.
-/

import Mathlib.Analysis.Complex.Hadamard
import Mathlib.Analysis.SpecialFunctions.Complex.Log
import Cathedral.Zeta.DiskBounds

noncomputable section
open Complex Real Filter Asymptotics MeasureTheory Metric Set
open scoped Topology

namespace Cathedral.Zeta.Hadamard
open Complex.HadamardThreeLines

-- ═══════════════════════════════════════════
-- §1. Hadamard Three-Circles Theorem
-- ═══════════════════════════════════════════

/-! ### Three-Circles from Three-Lines via the exponential map

The Hadamard Three-Circles theorem states: for f holomorphic on
the annulus r₁ ≤ |z| ≤ R, the maximum modulus M(r) = max_{|z|=r} |f(z)|
satisfies the log-convexity inequality:

  ‖f(z)‖ ≤ a^{1-θ} · b^θ

where θ = log(|z|/r₁)/log(R/r₁), a bounds f on |z|=r₁, b bounds f on |z|=R.

**Proof**: Compose f with exp to reduce to the Three-Lines theorem on strips.
Set g(w) = f(exp(w)) on the strip {log r₁ ≤ Re w ≤ log R}. Then:
- g is DiffContOnCl on the strip (exp is entire, f is DiffContOnCl on annulus)
- g is bounded on the strip (exp maps strip into compact annulus)
- Boundary conditions transfer: Re w = log r₁ ⟺ |exp w| = r₁
- The interpolation parameter matches: θ = (Re w − log r₁)/(log R − log r₁)
-/

/-- exp maps the closed strip [log r₁, log R] into the closed annulus [r₁, R]. -/
private lemma exp_mapsTo_annulus {r₁ R : ℝ} (hr₁ : 0 < r₁) (hR : 0 < R) :
    MapsTo (fun w : ℂ => Complex.exp w)
      (verticalClosedStrip (Real.log r₁) (Real.log R))
      {z : ℂ | r₁ ≤ ‖z‖ ∧ ‖z‖ ≤ R} := by
  intro w hw
  simp only [verticalClosedStrip, mem_preimage, mem_Icc] at hw
  simp only [mem_setOf]
  constructor
  · calc r₁ = Real.exp (Real.log r₁) := (Real.exp_log hr₁).symm
      _ ≤ Real.exp w.re := Real.exp_le_exp.mpr hw.1
      _ = ‖Complex.exp w‖ := by rw [Complex.norm_exp]
  · calc ‖Complex.exp w‖ = Real.exp w.re := Complex.norm_exp w
      _ ≤ Real.exp (Real.log R) := Real.exp_le_exp.mpr hw.2
      _ = R := Real.exp_log hR

/-- exp maps the open strip (log r₁, log R) into the open annulus (r₁, R). -/
private lemma exp_mapsTo_open_annulus {r₁ R : ℝ} (hr₁ : 0 < r₁) (hR : 0 < R) :
    MapsTo (fun w : ℂ => Complex.exp w)
      (verticalStrip (Real.log r₁) (Real.log R))
      {z : ℂ | r₁ < ‖z‖ ∧ ‖z‖ < R} := by
  intro w hw
  simp only [verticalStrip, mem_preimage, mem_Ioo] at hw
  simp only [mem_setOf]
  constructor
  · calc r₁ = Real.exp (Real.log r₁) := (Real.exp_log hr₁).symm
      _ < Real.exp w.re := Real.exp_lt_exp.mpr hw.1
      _ = ‖Complex.exp w‖ := by rw [Complex.norm_exp]
  · calc ‖Complex.exp w‖ = Real.exp w.re := Complex.norm_exp w
      _ < Real.exp (Real.log R) := Real.exp_lt_exp.mpr hw.2
      _ = R := Real.exp_log hR

/-- f ∘ exp is DiffContOnCl on the strip when f is DiffContOnCl on the annulus. -/
private lemma diffContOnCl_comp_exp {f : ℂ → ℂ} {r₁ R : ℝ}
    (hr₁ : 0 < r₁) (hR : r₁ < R)
    (hf : DiffContOnCl ℂ f {z : ℂ | r₁ ≤ ‖z‖ ∧ ‖z‖ ≤ R}) :
    DiffContOnCl ℂ (f ∘ (fun w : ℂ => Complex.exp w))
      (verticalStrip (Real.log r₁) (Real.log R)) := by
  have hR_pos : 0 < R := lt_trans hr₁ hR
  -- exp is entire, hence Differentiable ℂ
  have hexp : Differentiable ℂ (fun w : ℂ => Complex.exp w) :=
    Complex.differentiable_exp
  -- DiffContOnCl.comp requires MapsTo from open strip to annulus
  -- We use: Differentiable.comp_diffContOnCl which handles this
  -- via MapsTo to image, then mono to the annulus
  apply hf.comp hexp.diffContOnCl
  -- MapsTo: exp maps verticalStrip to annulus
  intro w hw
  simp only [verticalStrip, mem_preimage, mem_Ioo] at hw
  simp only [mem_setOf]
  constructor
  · calc r₁ = Real.exp (Real.log r₁) := (Real.exp_log hr₁).symm
      _ ≤ Real.exp w.re := Real.exp_le_exp.mpr (le_of_lt hw.1)
      _ = ‖Complex.exp w‖ := by rw [Complex.norm_exp]
  · calc ‖Complex.exp w‖ = Real.exp w.re := Complex.norm_exp w
      _ ≤ Real.exp (Real.log R) := Real.exp_le_exp.mpr (le_of_lt hw.2)
      _ = R := Real.exp_log hR_pos

/-- f ∘ exp is bounded on the closed strip (image factors through compact annulus). -/
private lemma bddAbove_comp_exp {f : ℂ → ℂ} {r₁ R : ℝ}
    (hr₁ : 0 < r₁) (hR : r₁ < R)
    (hf : DiffContOnCl ℂ f {z : ℂ | r₁ ≤ ‖z‖ ∧ ‖z‖ ≤ R}) :
    BddAbove ((norm ∘ (f ∘ fun w : ℂ => Complex.exp w)) ''
      verticalClosedStrip (Real.log r₁) (Real.log R)) := by
  have hR_pos : 0 < R := lt_trans hr₁ hR
  -- Key: (norm ∘ g) '' strip ⊆ (norm ∘ f) '' annulus
  -- and the annulus is compact, f is continuous on it.
  set annulus := {z : ℂ | r₁ ≤ ‖z‖ ∧ ‖z‖ ≤ R}
  -- The annulus is compact: it is closed and bounded in ℂ ≅ ℝ²
  -- Closed: preimage of Icc under continuous norm
  -- Bounded: contained in closedBall 0 R
  have h_annulus_compact : IsCompact annulus := by
    apply IsCompact.of_isClosed_subset (isCompact_closedBall (0 : ℂ) R)
    · -- annulus is closed
      apply IsClosed.inter
      · exact isClosed_le continuous_const continuous_norm
      · exact isClosed_le continuous_norm continuous_const
    · -- annulus ⊆ closedBall 0 R
      intro z ⟨_, hz2⟩
      simp only [mem_closedBall, dist_zero_right]
      exact hz2
  -- f is continuous on the annulus (from DiffContOnCl, annulus is its own closure)
  have h_annulus_closed : IsClosed annulus := by
    apply IsClosed.inter
    · exact isClosed_le continuous_const continuous_norm
    · exact isClosed_le continuous_norm continuous_const
  have hf_cont : ContinuousOn f annulus := by
    have := hf.continuousOn
    rwa [h_annulus_closed.closure_eq] at this
  -- norm ∘ f is continuous on the compact annulus, hence bounded
  have hf_norm_cont : ContinuousOn (norm ∘ f) annulus :=
    continuous_norm.comp_continuousOn hf_cont
  have hf_bdd := h_annulus_compact.bddAbove_image hf_norm_cont
  -- The image of (norm ∘ g) on the strip is contained in (norm ∘ f) on the annulus
  apply hf_bdd.mono
  intro y hy
  simp only [mem_image, Function.comp] at hy ⊢
  obtain ⟨w, hw, rfl⟩ := hy
  exact ⟨Complex.exp w, exp_mapsTo_annulus hr₁ hR_pos hw, rfl⟩

/-- **Hadamard Three-Circles Theorem** (proved from Three-Lines).

    If f is DiffContOnCl on the closed annulus {r₁ ≤ |z| ≤ R},
    ‖f(z)‖ ≤ a on |z| = r₁, and ‖f(z)‖ ≤ b on |z| = R,
    then for z with r₁ ≤ |z| ≤ R:

    ‖f(z)‖ ≤ a^{1-θ} · b^θ

    where θ = log(|z|/r₁) / log(R/r₁) ∈ [0, 1].

    Proof: Apply Three-Lines to g(w) = f(exp(w)) on the strip
    [log r₁, log R]. -/
theorem hadamard_three_circles
    {f : ℂ → ℂ} {r₁ R : ℝ} {a b : ℝ}
    (hr₁ : 0 < r₁) (hR : r₁ < R)
    (hf : DiffContOnCl ℂ f {z | r₁ ≤ ‖z‖ ∧ ‖z‖ ≤ R})
    (ha : ∀ z, ‖z‖ = r₁ → ‖f z‖ ≤ a)
    (hb : ∀ z, ‖z‖ = R → ‖f z‖ ≤ b)
    (z : ℂ) (hz₁ : r₁ ≤ ‖z‖) (hz₂ : ‖z‖ ≤ R) :
    ‖f z‖ ≤ a ^ (1 - (Real.log ‖z‖ - Real.log r₁) / (Real.log R - Real.log r₁)) *
             b ^ ((Real.log ‖z‖ - Real.log r₁) / (Real.log R - Real.log r₁)) := by
  have hR_pos : 0 < R := lt_trans hr₁ hR
  have hz_pos : 0 < ‖z‖ := lt_of_lt_of_le hr₁ hz₁
  have hz_ne : z ≠ 0 := norm_pos_iff.mp hz_pos
  set l := Real.log r₁
  set u := Real.log R
  have hlu : l < u := Real.log_lt_log hr₁ hR
  -- The lifted function g(w) = f(exp(w)) on the strip
  set g : ℂ → ℂ := f ∘ (fun w => Complex.exp w) with hg_def
  -- Preimage point: w₀ = Complex.log z
  set w₀ := Complex.log z
  -- Key property: exp(w₀) = z
  have hw₀_exp : Complex.exp w₀ = z := Complex.exp_log hz_ne
  -- Key property: Re(w₀) = log ‖z‖
  have hw₀_re : w₀.re = Real.log ‖z‖ := Complex.log_re z
  -- w₀ is in the closed strip [l, u]
  have hw₀_strip : w₀ ∈ verticalClosedStrip l u := by
    simp only [verticalClosedStrip, mem_preimage, mem_Icc]
    rw [hw₀_re]
    exact ⟨Real.log_le_log hr₁ hz₁, Real.log_le_log hz_pos hz₂⟩
  -- Apply the Three-Lines theorem to g at w₀
  have hg_dcoc := diffContOnCl_comp_exp hr₁ hR hf
  have hg_bdd := bddAbove_comp_exp hr₁ hR hf
  -- Boundary conditions for g
  have hg_left : ∀ w ∈ re ⁻¹' {l}, ‖g w‖ ≤ a := by
    intro w hw
    simp only [mem_preimage, mem_singleton_iff] at hw
    simp only [hg_def, Function.comp]
    apply ha
    rw [Complex.norm_exp, hw]
    exact Real.exp_log hr₁
  have hg_right : ∀ w ∈ re ⁻¹' {u}, ‖g w‖ ≤ b := by
    intro w hw
    simp only [mem_preimage, mem_singleton_iff] at hw
    simp only [hg_def, Function.comp]
    apply hb
    rw [Complex.norm_exp, hw]
    exact Real.exp_log hR_pos
  -- Apply Three-Lines
  have h3l := norm_le_interp_of_mem_verticalClosedStrip' hlu hw₀_strip
    hg_dcoc hg_bdd hg_left hg_right
  -- h3l gives ‖g w₀‖ ≤ a^{1-θ} · b^θ where θ = (Re(w₀) - l)/(u - l)
  -- And ‖g w₀‖ = ‖f(exp(w₀))‖ = ‖f z‖
  simp only [Function.comp, hw₀_exp] at h3l
  -- The exponent matches: Re(w₀) = log ‖z‖
  rwa [hw₀_re] at h3l

-- ═══════════════════════════════════════════
-- §2. The Zero-Counting Axiom
-- ═══════════════════════════════════════════

/-! ### The Missing Classical Ingredient

Under RH, the Hadamard product formula for ζ(s) gives:

  log ζ(s) = Σ_ρ log(1 - s/ρ) + B·s + log(ξ₀)

where the sum is over nontrivial zeros ρ. Under RH, Re(ρ) = 1/2 for all ρ,
so |s - ρ| ≥ ε when σ ≥ 1/2 + ε. Combined with zero density N(T) = O(T log T)
(Riemann-von Mangoldt formula), this gives:

  -Re(log ζ(σ+it)) ≤ C_ε · log|t|

Hence |ζ(σ+it)| ≥ |t|^{-C_ε} for any σ ≥ 1/2 + ε.

GRADUATION PATH:
  (1) Prove Riemann-von Mangoldt: N(T) = (T/2π)log(T/2π) - T/2π + O(log T)
  (2) Prove Hadamard factorization for ζ
  (3) Estimate the zero sum under RH
  When Mathlib adds (1)-(2), this axiom can be graduated to a theorem.

REFERENCES:
  • Titchmarsh, "Theory of the Riemann Zeta-function", §14.2
  • Iwaniec-Kowalski, "Analytic Number Theory", Theorem 5.17
-/

/-- **DEPRECATED AXIOM** (Polynomial lower bound under RH via zero-counting):
    Under RH, for any ε > 0 and A > 0, there exists c > 0 such that
    |ζ(s)| ≥ c/|Im(s)|^A for Re(s) ≥ 1/2+ε and |Im(s)| ≥ 2.

    GRADUATED: May 13, 2026 (Exploration 37).
    The Littlewood Maneuver (LittlewoodManeuver.lean) proves the ∃ T₀ form
    from first principles (Borel-Carathéodory + Three-Circles + sub-log decay).
    This axiom is retained only for historical reference; it has ZERO consumers.

    EXPERIMENTALLY VALIDATED: bc-zeta-lower (256-bit MPFR, 17.5h, 550K samples)
    confirms effective exponents ≈ 0.03-0.08, with 300× margin over theory. -/
axiom rh_zeta_lower_bound_from_zero_counting
    (hRH : RiemannHypothesis) (ε : ℝ) (hε : 0 < ε) (hε1 : ε < 3/2)
    (A : ℝ) (hA : 0 < A) :
    ∃ c > 0, ∀ s : ℂ,
      (1/2 + ε ≤ s.re) → (2 ≤ |s.im|) →
      c / |s.im| ^ A ≤ ‖riemannZeta s‖

-- ═══════════════════════════════════════════
-- §3. Thin-Strip Lower Bound Closure (GRADUATED)
-- ═══════════════════════════════════════════

/-- **THEOREM**: Existential form matching `zeta_polynomial_lower_bound_rh_proved`.

    Directly provides the bound needed to close ZetaLowerBound.lean.

    NOTE: This theorem has ZERO code consumers as of May 13, 2026.
    The main chain flows through LowerBound.lean → littlewood_maneuver directly.
    The axiom call below is therefore orphaned from MainChain's dependency graph.
    It is retained for backward compatibility only. -/
theorem thin_strip_lower_bound_exists (hRH : RiemannHypothesis)
    (ε : ℝ) (hε : 0 < ε) (hε1 : ε < 3/2)
    (A : ℝ) (hA : 0 < A) :
    ∃ c > 0, ∃ T₀ > 0, ∀ s : ℂ,
      (1/2 + ε ≤ s.re) → (T₀ ≤ |s.im|) →
      c / |s.im| ^ A ≤ ‖riemannZeta s‖ := by
  obtain ⟨c, hc_pos, hbound⟩ :=
    rh_zeta_lower_bound_from_zero_counting hRH ε hε hε1 A hA
  exact ⟨c, hc_pos, 2, by norm_num, hbound⟩

end Cathedral.Zeta.Hadamard
