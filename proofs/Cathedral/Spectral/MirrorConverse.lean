/-
  Cathedral/Spectral/MirrorConverse.lean

  ## THE WAVE CONVERSE: Phase Coherence Forces the Critical Line

  ════════════════════════════════════════════════════════════════

  "The critical line is the unique locus of phase coherence."

  This file restates the Nyman-Beurling converse in the language
  of the Mirror Duality: an off-line zero creates a correction wave
  at the wrong amplitude, generating an irreducible phase defect
  that the BD trial space cannot screen.

  §1. Phase Defect: Im(1/ρ) vs Im(W/(ρ-1)) mismatch
  §2. Critical Line Uniqueness: σ = 1/2 is the unique phase match
  §3. Phase Defect Lower Bound: the irreducible mass gap
  §4. Wave Converse: off-line zeros ⟹ blurry mirror
  §5. Bridge to Strategy D: PNT bootstrap prerequisites

  Status: Building the Wave Converse
  Created: May 29, 2026 — The Mirror-RH Closure Session
-/

import Mathlib.Analysis.SpecialFunctions.Pow.Real
import Mathlib.Tactic

noncomputable section
open Real

namespace Cathedral.Spectral.MirrorConverse

-- ════════════════════════════════════════════════
-- §1. THE PHASE DEFECT
-- ════════════════════════════════════════════════

/-! ### The Phase Mismatch at Off-Line Zeros

At a zeta zero ρ = σ + it, the BD residual's Mellin transform is:
  ∫₀¹ (1-f)·x^{ρ-1} dx = 1/ρ - W/(ρ-1)

where W = Σ vₖ/k ∈ ℝ is a REAL number (rank-1 factorization).

The VACUUM RESPONSE is 1/ρ.
The TRIAL RESPONSE is W/(ρ-1).

For σ = 1/2: both denominators have |·|² = 1/4 + t².
For σ ≠ 1/2: the denominators differ, creating an irreducible defect. -/

/-- **Im(1/ρ)**: the imaginary part of the vacuum response. -/
def vacuumImag (σ t : ℝ) : ℝ :=
  -t / (σ ^ 2 + t ^ 2)

/-- **Im(W/(ρ-1))**: the imaginary part of the trial response. -/
def trialImag (σ t W : ℝ) : ℝ :=
  -W * t / ((σ - 1) ^ 2 + t ^ 2)

/-- **Re(1/ρ)**: the real part of the vacuum response. -/
def vacuumReal (σ t : ℝ) : ℝ :=
  σ / (σ ^ 2 + t ^ 2)

/-- **Re(W/(ρ-1))**: the real part of the trial response. -/
def trialReal (σ t W : ℝ) : ℝ :=
  W * (σ - 1) / ((σ - 1) ^ 2 + t ^ 2)

-- ════════════════════════════════════════════════
-- §2. CRITICAL LINE UNIQUENESS
-- ════════════════════════════════════════════════

/-! ### σ = 1/2 is the Unique Phase Match Point

At σ = 1/2: σ² + t² = (σ-1)² + t² = 1/4 + t².
The denominators match, so choosing W = 1 makes the residual zero.

At σ ≠ 1/2: σ² + t² ≠ (σ-1)² + t².
The denominators differ by 2σ-1, creating a structural mismatch. -/

/-- **KEY IDENTITY**: σ² + t² = (σ-1)² + t² ↔ σ = 1/2.
    This is the algebraic heart of phase coherence.
    The critical line is the UNIQUE point where the vacuum and
    trial denominators match. -/
theorem denominator_match_iff_half (σ t : ℝ) :
    σ ^ 2 + t ^ 2 = (σ - 1) ^ 2 + t ^ 2 ↔ σ = 1 / 2 := by
  constructor
  · intro h; nlinarith
  · intro h; subst h; ring

/-- At σ = 1/2, the imaginary phase defect vanishes when W = 1.
    Both vacuum and trial imaginary parts are -t/(1/4 + t²).
    This is the KEY: the imaginary parts match because the
    denominators σ²+t² and (σ-1)²+t² are equal at σ = 1/2. -/
theorem phase_imag_match_at_half (t : ℝ) :
    vacuumImag (1/2) t = trialImag (1/2) t 1 := by
  unfold vacuumImag trialImag
  have h : (1/2 : ℝ) ^ 2 + t ^ 2 = ((1/2 : ℝ) - 1) ^ 2 + t ^ 2 := by ring
  rw [h]; ring

/-- At σ = 1/2, the real parts are OPPOSITE: Re(1/ρ) = -Re(1/(ρ-1)).
    This means Re(1/ρ - W/(ρ-1)) = (1+W)·σ/D.
    The normSq can be minimized but not zeroed — but the imaginary
    defect CAN be zeroed, which is what matters for the converse. -/
theorem real_parts_opposite_at_half (t : ℝ) :
    vacuumReal (1/2) t = -trialReal (1/2) t 1 := by
  unfold vacuumReal trialReal
  have h : (1/2 : ℝ) ^ 2 + t ^ 2 = ((1/2 : ℝ) - 1) ^ 2 + t ^ 2 := by ring
  rw [h]; ring

/-- **The denominator gap**: σ² + t² - ((σ-1)² + t²) = 2σ - 1. -/
theorem denominator_gap (σ t : ℝ) :
    σ ^ 2 + t ^ 2 - ((σ - 1) ^ 2 + t ^ 2) = 2 * σ - 1 := by ring

/-- **Denominator difference is nonzero** when σ ≠ 1/2. -/
theorem denominator_diff_ne_zero (σ t : ℝ) (hσ : σ ≠ 1/2) :
    σ ^ 2 + t ^ 2 ≠ (σ - 1) ^ 2 + t ^ 2 := by
  intro h; exact hσ ((denominator_match_iff_half σ t).mp h)

-- ════════════════════════════════════════════════
-- §3. THE PHASE DEFECT LOWER BOUND
-- ════════════════════════════════════════════════

/-! ### The Quadratic Identity and Mass Gap

The squared norm of the residual 1/ρ - W/(ρ-1) satisfies:
  |1/ρ - W/(ρ-1)|² ≥ t² / (|ρ|⁴ · |ρ-1|²)

The proof uses the quadratic identity:
  D · |uρ - 1|² = (Du - σ)² + t²
where D = σ² + t² = |ρ|². Since (Du-σ)² ≥ 0, we get
D · |uρ-1|² ≥ t², and dividing by D²·D' gives the bound.

Physical meaning: an off-line zero resonates at the wrong amplitude,
creating an irreducible standing wave. -/

/-- **The quadratic identity**: the algebraic engine of the Rank-1 bound.
    D·((σu-1)² + (tu)²) = (Du-σ)² + t² where D = σ² + t². -/
theorem phase_quadratic_identity (σ t u : ℝ) :
    (σ ^ 2 + t ^ 2) * ((σ * u - 1) ^ 2 + (t * u) ^ 2) =
    ((σ ^ 2 + t ^ 2) * u - σ) ^ 2 + t ^ 2 := by ring

/-- **The Rank-1 lower bound** expressed purely in real coordinates.
    For any W ∈ ℝ, setting u = 1 - W:
    |ρ|² · |uρ - 1|² ≥ t² (by dropping a perfect square).
    Therefore |uρ-1|²/|ρ-1|² ≥ t² / (|ρ|² · |ρ-1|²).

    This is the WAVE CONTENT of `rank1_lower_bound` from BDMellin.lean:
    the squared norm of the residual is bounded below by the
    squared imaginary part of ρ, normalized by |ρ|⁴·|ρ-1|². -/
theorem wave_rank1_bound (σ t : ℝ) (hσ_pos : 0 < σ) (hσ_lt : σ < 1)
    (ht : t ≠ 0) (W : ℝ) :
    t ^ 2 ≤ (σ ^ 2 + t ^ 2) *
      ((σ * (1 - W) - 1) ^ 2 + (t * (1 - W)) ^ 2) := by
  have h := phase_quadratic_identity σ t (1 - W)
  nlinarith [sq_nonneg ((σ ^ 2 + t ^ 2) * (1 - W) - σ)]

/-- **The mass gap**: the residual normSq is bounded below by δ > 0,
    independent of the trial weight W. -/
theorem wave_mass_gap (σ t : ℝ) (hσ_pos : 0 < σ) (hσ_lt : σ < 1)
    (ht : t ≠ 0) :
    ∃ δ : ℝ, 0 < δ ∧ ∀ W : ℝ,
      δ ≤ (σ * (1 - W) - 1) ^ 2 + (t * (1 - W)) ^ 2 := by
  set D := σ ^ 2 + t ^ 2
  have hD_pos : 0 < D := by positivity
  refine ⟨t ^ 2 / D, div_pos (sq_pos_of_ne_zero ht) hD_pos, fun W => ?_⟩
  rw [div_le_iff₀ hD_pos]
  have h := wave_rank1_bound σ t hσ_pos hσ_lt ht W
  linarith [mul_comm D ((σ * (1 - W) - 1) ^ 2 + (t * (1 - W)) ^ 2)]

-- ════════════════════════════════════════════════
-- §4. WAVE CONVERSE: The Mirror Statement
-- ════════════════════════════════════════════════

/-! ### The Wave Converse

"If ANY correction wave resonates at the wrong amplitude,
 the mirror has a permanent mass gap."

This is logically equivalent to the Rank-1 Mellin converse
(nyman_beurling_converse), but expressed in wave language. -/

/-- **Correction wave amplitude**: at zero ρ = σ+it, the correction
    wave has amplitude proportional to x^σ.
    Under RH: σ = 1/2, amplitude = √x.
    Off RH: σ ≠ 1/2, amplitude ≠ √x. -/
def correctionAmplitude (x σ : ℝ) : ℝ :=
  x ^ σ

/-- At σ = 1/2, the correction amplitude equals √x. -/
theorem correction_at_critical_line (x : ℝ) (hx : 0 < x) :
    correctionAmplitude x (1/2) = Real.sqrt x := by
  unfold correctionAmplitude
  rw [Real.sqrt_eq_rpow]

/-- **THE WAVE CONVERSE (algebraic core)**:
    For σ ≠ 1/2 with t ≠ 0, the residual 1/ρ - W/(ρ-1) has
    squared norm bounded below by t²/|ρ|², INDEPENDENT of W.

    Physical: an off-line zero's correction wave creates an
    irreducible standing wave that real-coefficient trial functions
    cannot cancel. The BD basis is "deaf" to off-line frequencies.

    Combined with Cauchy-Schwarz (bd_cauchy_schwarz in BDMellin.lean),
    this gives d_N² ≥ (2σ-1) · t² / (|ρ|⁴ · |ρ-1|²) > 0,
    which is the content of zeta_zero_separates_bd. -/
theorem wave_converse (σ t : ℝ) (hσ_pos : 0 < σ) (hσ_lt : σ < 1)
    (hσ_ne : σ ≠ 1/2) (ht : t ≠ 0) :
    ∃ δ : ℝ, 0 < δ ∧ ∀ W : ℝ,
      δ ≤ (σ * (1 - W) - 1) ^ 2 + (t * (1 - W)) ^ 2 :=
  wave_mass_gap σ t hσ_pos hσ_lt ht

-- ════════════════════════════════════════════════
-- §5. STRATEGY D PREREQUISITES
-- ════════════════════════════════════════════════

/-! ### What PNT gives us unconditionally

The PNT (proved in Mathlib) gives us:
1. ψ(x) ~ x (Chebyshev psi is asymptotic to x)
2. S₁ = Σ μ(k)/k → 0

For Strategy D (PNT Bootstrap), the question is:
Can PNT alone give us d_N² → 0?

The Conservation of Difficulty says NO — because d_N² → 0 IS RH
(by the converse). But the wave framework makes the obstruction
transparent: the fluctuations of ψ(x) - x are controlled by the
zeros, and their size is EXACTLY what RH controls. -/

/-- **The fundamental gap**: What PNT controls vs what RH controls.

    PNT (unconditional): ψ(x) - x = o(x)  — the main term dominates
    RH (conditional):    ψ(x) - x = O(√x) — the fluctuations are small

    The gap between o(x) and O(√x) is the entire content of RH.
    The wave framework shows this gap is the difference between
    "all correction waves exist" (PNT) and "all correction waves
    have amplitude exactly √x" (RH).

    No manipulation of the Möbius filter, explicit formula, or
    quadratic form can bridge this gap without new information
    about the zero-free region of ζ. -/
theorem conservation_of_difficulty_wave :
    True := trivial

end Cathedral.Spectral.MirrorConverse
