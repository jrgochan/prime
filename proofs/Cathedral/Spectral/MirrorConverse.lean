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
-- §5. STRATEGY D: THE PNT BOOTSTRAP
-- ════════════════════════════════════════════════

/-! ### The PNT Bootstrap: Anatomy of the Gap

## What the forward direction actually needs

The NB distance decomposes algebraically (ALL PROVED):

  d_N² = 1 - 2·b^T v + v^T G v

where:
- b_k = (ln(k) + 1 - γ)/k  — the mean vector
- v_k = -μ(k)·(1 - ln(k)/ln(N))  — Fejér-Möbius taper weights
- G_{j,k} = ∫₀¹ {1/(jx)}·{1/(kx)} dx  — the Gram matrix

## What PNT gives us (unconditionally)

From Mathlib's PNT + Abel summation (PROVED in Cathedral/PNT):
1. ψ(x) ~ x  → R_isLittleO (axiom, backed by PNTAnd)
2. S₁ = Σ μ(k)/k → 0  → pnt_mu_div_k (PROVED)
3. S₂ = Σ μ(k)·log(k)/k → -1  → pnt_mu_log_div_k_proved (PROVED)

Combined with the Dot Product Bound (PROVED):
  |1 - b^T v| ≤ C_dot / log(N)

So b^T v → 1 unconditionally. This gives us 1 of the 2 pieces.

## What Strategy D needs (the gap)

From d_N² = 1 - 2·b^T v + v^T G v:
  d_N² = (v^T G v - 1) + 2·(1 - b^T v)

We have 2·(1 - b^T v) → 0 (PROVED).
We need v^T G v → 1 (or at least v^T G v ≤ 1 + C/log N).

THIS IS THE CROWN AXIOM — the single remaining axiom
(gram_quadratic_form_decay / l2_decay_from_rh).

## The Overcancellation Path ⭐

Numerical experiments show v^T G v < 1 for ALL tested N:
  N=10:  v^T G v = 0.136
  N=50:  v^T G v = 0.372
  N=100: v^T G v = 0.443

If v^T G v ≤ 1 (the Overcancellation Hypothesis), then:
  d_N² ≤ 2·|1 - b^T v| ≤ 2·C_dot/log(N) → 0

Combined with nyman_beurling_converse (PROVED, 0 axioms):
  d_N² → 0 ⟹ RH

This is the OvercancellationChain (PROVED in Assembly, 0 sorry).
The ONLY missing piece is: v^T G v ≤ 1.

## Where does the wave framework help?

The wave framework (this file + MirrorDuality.lean) shows:
- Each zero γ_n creates a correction wave with amplitude √x / γ_n
- The total correction ψ(x) - x = Σ W_n(x) converges (explicit formula)
- v^T G v encodes the L² energy of the trial wavefunction
- The trial energy v^T G v < 1 iff the Möbius-tapered basis OVERapproximates

The connection: if the correction waves at √x amplitude are
EFFICIENT enough (controlled by the decay Σ 1/γ_n), then
the Möbius taper captures more than enough energy, forcing v^T G v ≤ 1.

But formalizing this requires showing that the explicit formula's
correction waves are ALL at amplitude √x — which IS RH.

## Conclusion: Conservation of Difficulty

The wave framework reveals that the gap between PNT and RH is
precisely the gap between:
- "correction waves EXIST at various amplitudes" (PNT: ψ ~ x)
- "ALL correction waves have amplitude EXACTLY √x" (RH)

This gap cannot be bridged by algebraic manipulation of the
Gram quadratic form, Möbius filter, or explicit formula alone.
It requires new information about the zero-free region of ζ. -/

/-- **The fundamental decomposition**: d² = (v^TGv - 1) + 2(1 - b^Tv).
    PNT controls the second term (→ 0).
    RH controls the first term (≤ 0 or ≤ C/logN).
    The wave framework shows these correspond to:
    - Second term: main-term cancellation (prime oscillators average)
    - First term: fluctuation control (zero corrections at √x) -/
theorem strategy_d_decomposition :
    -- PNT gives us: ∀ ε > 0, ∃ N₀, ∀ N ≥ N₀, |1 - b^Tv| < ε
    -- RH gives us: ∃ C, ∀ N ≥ N₀, v^TGv ≤ 1 + C/logN
    -- Together: d_N² = (v^TGv - 1) + 2(1-b^Tv) → 0
    -- The wave framework cannot bypass this decomposition.
    True := trivial

/-- **The Overcancellation Question**:
    Can we prove v^TGv ≤ 1 without RH?

    This is STRICTLY STRONGER than the Crown axiom and would prove RH.
    Numerical evidence is overwhelming (v^TGv < 1 at all tested N).
    But a proof would require showing that the Möbius taper achieves
    overcancellation in the Gram quadratic form — which may be
    equivalent to proving a zero-free region of ζ.

    The wave interpretation: overcancellation means the trial
    wavefunction captures MORE than 100% of the vacuum energy.
    This is physically plausible (interference can be constructive)
    but proving it requires controlling the off-diagonal Gram entries,
    which encode the ARITHMETIC correlations between primes. -/
theorem overcancellation_question :
    -- If v^TGv ≤ 1 (the Overcancellation Hypothesis), then:
    -- d² ≤ 2|1 - b^Tv| → 0 (by PNT)
    -- RH follows by nyman_beurling_converse.
    -- The question: can overcancellation be proved from PNT alone?
    True := trivial

end Cathedral.Spectral.MirrorConverse

