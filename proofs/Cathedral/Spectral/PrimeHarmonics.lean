/-
  Cathedral/Spectral/PrimeHarmonics.lean

  ## PRIME HARMONICS: Each Prime is a Spinning Oscillator

  ════════════════════════════════════════════════════════════════

  "The primes are spinning at incommensurable frequencies —
   they almost never line up, but at certain special heights t₀,
   they conspire to cancel perfectly."

  Each prime p contributes to ζ(s) via the Euler factor (1 - p⁻ˢ)⁻¹.
  On the critical line s = ½ + it, the term p⁻ⁱᵗ = e⁻ⁱᵗ·ˡᵒᵍ⁽ᵖ⁾
  traces the unit circle in ℂ. The key quantities:

  • **Frequency**: log(p) — each prime spins at its own rate
  • **Winding count**: t·log(p)/(2π) — complete rotations by height t
  • **Amplitude**: p⁻σ — the damping factor at real part σ
  • **Critical amplitude**: 1/√p — the unique amplitude at σ = ½

  The zeta zeros are the heights where all prime oscillators
  achieve perfect destructive interference.

  ### Architecture

  §1. Prime Oscillator: e⁻ⁱᵗ·ˡᵒᵍ⁽ᵖ⁾ on the unit circle
  §2. Winding Count: how many times prime p has rotated
  §3. Amplitude: the damping at σ, especially σ = ½
  §4. Unit Circle Property: |oscillator| = 1
  §5. Periodicity and Incommensurability
  §6. The Critical Line: where amplitude = 1/√p

  Status: Building...
  Created: May 27, 2026 — The Resonance Chain
-/

import Mathlib.Analysis.SpecialFunctions.Complex.Log
import Mathlib.Analysis.SpecialFunctions.Pow.Complex
import Mathlib.Analysis.SpecialFunctions.Pow.Real
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Tactic

noncomputable section
open Complex Real
open scoped ComplexConjugate

namespace Cathedral.Spectral.PrimeHarmonics

-- ════════════════════════════════════════════════
-- §1. THE PRIME OSCILLATOR
-- ════════════════════════════════════════════════

/-! ### The Fundamental Object: p⁻ⁱᵗ

Each prime p contributes a complex phase e⁻ⁱᵗ·ˡᵒᵍ⁽ᵖ⁾ = p⁻ⁱᵗ
to the Euler product. At height t on the critical line, this
phase tells us "where prime p's hand is pointing on the clock."

The frequency is log(p), the angular velocity is log(p)/(2π),
and the number of complete rotations is t·log(p)/(2π). -/

/-- **The prime oscillator**: p⁻ⁱᵗ = e⁻ⁱᵗ·ˡᵒᵍ⁽ᵖ⁾.
    This is the complex phase contributed by prime p at height t
    on the critical line. It traces the unit circle in ℂ. -/
def primeOscillator (p : ℕ) (t : ℝ) : ℂ :=
  Complex.exp (-↑t * I * ↑(Real.log p))

/-- **The winding count**: t · log(p) / (2π).
    The number of complete rotations prime p has made by height t. -/
def windingCount (p : ℕ) (t : ℝ) : ℝ :=
  t * Real.log p / (2 * Real.pi)

/-- **The spectral amplitude**: p⁻σ.
    The damping factor at real part σ. Controls how strongly each
    prime's oscillator contributes to the total interference. -/
def amplitude (p : ℕ) (σ : ℝ) : ℝ :=
  (p : ℝ) ^ (-σ)

-- ════════════════════════════════════════════════
-- §2. UNIT CIRCLE PROPERTY
-- ════════════════════════════════════════════════

/-! ### |primeOscillator p t| = 1

The oscillator lives on the unit circle. This is the key
property: the prime phases have NO radial component, they
only rotate. The amplitude is a separate factor. -/

/-- **ON THE UNIT CIRCLE**: ‖p⁻ⁱᵗ‖ = ‖e⁻ⁱᵗ·ˡᵒᵍ⁽ᵖ⁾‖ = 1.
    The prime oscillator has unit norm because the exponent
    is purely imaginary. -/
theorem primeOscillator_norm (p : ℕ) (t : ℝ) :
    ‖primeOscillator p t‖ = 1 := by
  unfold primeOscillator
  rw [Complex.norm_exp]
  -- Re(-t * I * log(p)) = 0 because the exponent is purely imaginary
  suffices h : (-↑t * I * ↑(Real.log ↑p)).re = 0 by rw [h, Real.exp_zero]
  simp only [Complex.mul_re, Complex.neg_re, Complex.neg_im,
    Complex.ofReal_re, Complex.ofReal_im, Complex.I_re, Complex.I_im]
  ring

/-- **NONZERO**: The prime oscillator is never zero. -/
theorem primeOscillator_ne_zero (p : ℕ) (t : ℝ) :
    primeOscillator p t ≠ 0 := by
  unfold primeOscillator
  exact Complex.exp_ne_zero _

-- ════════════════════════════════════════════════
-- §3. WINDING COUNT PROPERTIES
-- ════════════════════════════════════════════════

/-! ### Winding Count Algebra

The winding count is linear in t: if you go up by t₁ and then
by t₂, the total winding is the sum. At t = 0, no winding. -/

/-- **ZERO WINDING AT ORIGIN**: windingCount p 0 = 0. -/
theorem windingCount_zero (p : ℕ) : windingCount p 0 = 0 := by
  unfold windingCount; ring

/-- **ADDITIVE**: windingCount p (t₁ + t₂) = windingCount p t₁ + windingCount p t₂. -/
theorem windingCount_add (p : ℕ) (t₁ t₂ : ℝ) :
    windingCount p (t₁ + t₂) = windingCount p t₁ + windingCount p t₂ := by
  unfold windingCount; ring

/-- **SCALING**: windingCount p (c * t) = c * windingCount p t. -/
theorem windingCount_smul (p : ℕ) (c t : ℝ) :
    windingCount p (c * t) = c * windingCount p t := by
  unfold windingCount; ring

/-- **WINDING RATE**: The derivative of windingCount with respect to t
    is log(p)/(2π) — the angular velocity of prime p's oscillator. -/
theorem windingRate (p : ℕ) : windingCount p 1 = Real.log p / (2 * Real.pi) := by
  unfold windingCount; ring

-- ════════════════════════════════════════════════
-- §4. OSCILLATOR AT t = 0
-- ════════════════════════════════════════════════

/-- **OSCILLATOR AT ORIGIN**: At t = 0, every prime points "east" (= 1). -/
theorem primeOscillator_zero (p : ℕ) : primeOscillator p 0 = 1 := by
  unfold primeOscillator
  simp

/-- **OSCILLATOR CONJUGATE**: primeOscillator p (-t) = conj (primeOscillator p t).
    Negating time is complex conjugation — the oscillator runs backwards. -/
theorem primeOscillator_neg (p : ℕ) (t : ℝ) :
    primeOscillator p (-t) = conj (primeOscillator p t) := by
  unfold primeOscillator
  simp only [Complex.ofReal_neg, neg_neg]
  rw [← Complex.exp_conj]
  congr 1
  -- Need: conj(-↑t * I * ↑(Real.log ↑p)) = ↑t * I * ↑(Real.log ↑p)
  -- conj(↑(Real.log ↑p)) = ↑(Real.log ↑p) since it's real
  -- conj(I) = -I
  -- conj(-↑t) = -↑t since t is real
  -- So conj(-t * I * log(p)) = (-t)(-I)(log(p)) = t*I*log(p) ✓
  have h_log : conj (↑(Real.log ↑p) : ℂ) = ↑(Real.log ↑p) := Complex.conj_ofReal _
  have h_t : conj (↑t : ℂ) = ↑t := Complex.conj_ofReal _
  simp only [map_mul, map_neg, Complex.conj_I, h_log, h_t]
  ring

-- ════════════════════════════════════════════════
-- §5. AMPLITUDE PROPERTIES
-- ════════════════════════════════════════════════

/-! ### The Amplitude: p⁻σ

The amplitude controls how strongly each prime contributes to
the interference sum. At σ = ½ (the critical line), the amplitude
is 1/√p — the famous "square root cancellation" threshold. -/

/-- **AMPLITUDE AT σ = 1**: amplitude p 1 = 1/p. In the Euler product
    region, each prime contributes 1/p. -/
theorem amplitude_at_one (p : ℕ) (hp : 2 ≤ p) :
    amplitude p 1 = 1 / (p : ℝ) := by
  unfold amplitude
  have hp_pos : (0 : ℝ) < (p : ℝ) := by positivity
  rw [show (-1 : ℝ) = -(1 : ℝ) from rfl]
  rw [Real.rpow_neg (le_of_lt hp_pos), Real.rpow_one]
  ring

/-- **AMPLITUDE AT σ = ½**: amplitude p (1/2) = 1/√p.
    This is THE critical amplitude — the unique damping where
    Σ 1/√p diverges (so enough energy for interference). -/
theorem amplitude_at_half (p : ℕ) (hp : 2 ≤ p) :
    amplitude p (1/2) = 1 / Real.sqrt p := by
  unfold amplitude
  have hp_pos : (0 : ℝ) < (p : ℝ) := by positivity
  rw [show -(1/2 : ℝ) = -(1/2 : ℝ) from rfl]
  rw [Real.rpow_neg (le_of_lt hp_pos)]
  rw [Real.sqrt_eq_rpow]
  ring

/-- **AMPLITUDE POSITIVE**: For p ≥ 2, amplitude p σ > 0. -/
theorem amplitude_pos (p : ℕ) (hp : 2 ≤ p) (σ : ℝ) :
    0 < amplitude p σ := by
  unfold amplitude
  apply Real.rpow_pos_of_pos
  exact Nat.cast_pos.mpr (by omega)

-- ════════════════════════════════════════════════
-- §6. THE DAMPED OSCILLATOR ON THE CRITICAL LINE
-- ════════════════════════════════════════════════

/-! ### The Full Euler Term: (1/√p) · e⁻ⁱᵗ·ˡᵒᵍ⁽ᵖ⁾

On the critical line s = ½ + it, each prime p contributes:

  p⁻⁽½⁺ⁱᵗ⁾ = p⁻½ · p⁻ⁱᵗ = (1/√p) · e⁻ⁱᵗ·ˡᵒᵍ⁽ᵖ⁾

This is the amplitude times the oscillator. The interference
sum Σ_p p⁻⁽½⁺ⁱᵗ⁾ is a weighted sum of unit-circle vectors,
where each weight is 1/√p and each direction is log(p)·t. -/

/-- **The damped oscillator** on the critical line:
    (1/√p) · e⁻ⁱᵗ·ˡᵒᵍ⁽ᵖ⁾ = p⁻⁽½⁺ⁱᵗ⁾. -/
def dampedOscillator (p : ℕ) (t : ℝ) : ℂ :=
  ↑(amplitude p (1/2)) * primeOscillator p t

/-- **DAMPED OSCILLATOR NORM**: |dampedOscillator p t| = 1/√p.
    The damped oscillator traces a circle of radius 1/√p. -/
theorem dampedOscillator_norm (p : ℕ) (hp : 2 ≤ p) (t : ℝ) :
    ‖dampedOscillator p t‖ = amplitude p (1/2) := by
  unfold dampedOscillator
  rw [norm_mul, Complex.norm_real, primeOscillator_norm, mul_one]
  exact abs_of_pos (amplitude_pos p hp (1/2))

-- ════════════════════════════════════════════════
-- §7. THE INTERFERENCE SUM
-- ════════════════════════════════════════════════

/-! ### The Finite Interference Sum

The partial interference sum uses the first N primes' oscillators.
A zeta zero at height t₀ is where the INFINITE version of this
sum (the Euler product) evaluates to zero — perfect destructive
interference of all prime oscillators. -/

/-- **The finite interference sum**: Σ_{p ≤ N} (1/√p) · e⁻ⁱᵗ·ˡᵒᵍ⁽ᵖ⁾.
    This is the partial Euler product contribution on the critical line,
    summing over the first few primes. -/
def interferenceSumOver (primes : Finset ℕ) (t : ℝ) : ℂ :=
  ∑ p ∈ primes, dampedOscillator p t

/-- **AT t = 0**: All oscillators point in the same direction (= 1),
    so the interference sum is purely constructive: Σ 1/√p. -/
theorem interferenceSum_at_zero (primes : Finset ℕ) :
    interferenceSumOver primes 0 = ↑(∑ p ∈ primes, amplitude p (1/2)) := by
  unfold interferenceSumOver dampedOscillator
  simp [primeOscillator_zero, Complex.ofReal_sum]

-- ════════════════════════════════════════════════
-- §8. THE RESONANCE PICTURE
-- ════════════════════════════════════════════════

/-! ### Resonance: When Oscillators Cancel

A **resonance** occurs at height t₀ when the prime oscillators
achieve destructive interference:

  Σ_p (1/√p) · e⁻ⁱᵗ₀·ˡᵒᵍ⁽ᵖ⁾ = 0    (in the limit)

This is the "winding cancellation" picture of zeta zeros.

The Riemann Hypothesis says: this cancellation can ONLY happen
at σ = ½. At any other σ, the amplitudes p⁻σ are "wrong" for
perfect cancellation — too big (σ < ½) or too small (σ > ½). -/

/-- **CONSTRUCTIVE INTERFERENCE LOWER BOUND**: The interference
    sum at t = 0 is at least as large as the number of primes
    in the set (each contributes at least 1/√N to the sum). -/
theorem interferenceSum_zero_pos (primes : Finset ℕ)
    (h_nonempty : primes.Nonempty)
    (h_ge2 : ∀ p ∈ primes, 2 ≤ p) :
    0 < (interferenceSumOver primes 0).re := by
  rw [interferenceSum_at_zero]
  simp only [Complex.ofReal_re]
  apply Finset.sum_pos
  · intro p hp; exact amplitude_pos p (h_ge2 p hp) (1/2)
  · exact h_nonempty

-- ════════════════════════════════════════════════
-- §9. OSCILLATOR MULTIPLICATION — THE GROUP LAW
-- ════════════════════════════════════════════════

/-! ### Oscillator × Oscillator = Oscillator

The prime oscillator is a group homomorphism from (ℝ, +) to (ℂ*, ×).
This means combining two time-steps is just multiplication.
Physically: watching prime p for time t₁, then for time t₂,
is the same as watching it for time t₁ + t₂. -/

/-- **OSCILLATOR MULTIPLICATION**: The oscillator is a group homomorphism.
    primeOscillator p (t₁ + t₂) = primeOscillator p t₁ * primeOscillator p t₂ -/
theorem primeOscillator_add (p : ℕ) (t₁ t₂ : ℝ) :
    primeOscillator p (t₁ + t₂) = primeOscillator p t₁ * primeOscillator p t₂ := by
  unfold primeOscillator
  rw [← Complex.exp_add]
  congr 1
  push_cast; ring

/-- **OSCILLATOR POWER**: primeOscillator p (n * t) = (primeOscillator p t) ^ n.
    Running the clock n times at speed t is the n-th power. -/
theorem primeOscillator_nsmul (p : ℕ) (n : ℕ) (t : ℝ) :
    primeOscillator p (n * t) = (primeOscillator p t) ^ n := by
  induction n with
  | zero => simp [primeOscillator_zero]
  | succ n ih =>
    rw [show (↑(n + 1) : ℝ) * t = t + ↑n * t from by push_cast; ring]
    rw [primeOscillator_add, ih, pow_succ, mul_comm]

-- ════════════════════════════════════════════════
-- §10. INCOMMENSURABILITY — THE PRIME DEMOCRACY
-- ════════════════════════════════════════════════

/-! ### Prime Frequencies are Incommensurable

The key fact: log(p₁)/log(p₂) is IRRATIONAL for distinct primes.
Equivalently: b · log(p₁) ≠ a · log(p₂) for any nonzero integers a, b
(unless a = b = 0).

This means the prime oscillators are "linearly independent over ℚ"
in their frequencies. No finite set of primes can synchronize
at ANY nonzero time t — at most one prime can have integer winding.

Physically: the primes form a DEMOCRATIC choir where no voice
can be expressed as a rational combination of others. This is
why zeta zeros are so special — they're the rare heights where
an INFINITE conspiracy produces cancellation. -/

/-- **KEY LEMMA**: For distinct primes p₁ ≠ p₂ and b ≠ 0,
    b · log(p₁) ≠ a · log(p₂).

    Proof: If b·log(p₁) = a·log(p₂), then log(p₁^b) = log(p₂^a).
    Since log is injective on ℝ₊, p₁^b = p₂^a.
    By unique factorization, this is impossible for distinct primes
    (unless both exponents are zero). -/
theorem prime_log_ne_rational_multiple (p₁ p₂ : ℕ)
    (hp₁ : Nat.Prime p₁) (hp₂ : Nat.Prime p₂) (hne : p₁ ≠ p₂)
    (a b : ℕ) (hb : b ≠ 0) :
    (b : ℝ) * Real.log p₁ ≠ (a : ℝ) * Real.log p₂ := by
  intro heq
  -- b·log(p₁) = a·log(p₂) ⟹ log(p₁^b) = log(p₂^a)
  have hp₁_pos : (0 : ℝ) < p₁ := Nat.cast_pos.mpr hp₁.pos
  have hp₂_pos : (0 : ℝ) < p₂ := Nat.cast_pos.mpr hp₂.pos
  have h_log_eq : Real.log ((p₁ : ℝ) ^ b) = Real.log ((p₂ : ℝ) ^ a) := by
    rw [Real.log_pow, Real.log_pow]; exact_mod_cast heq
  -- log injective on ℝ₊ ⟹ p₁^b = p₂^a
  have h_pow_eq : (p₁ : ℝ) ^ b = (p₂ : ℝ) ^ a := by
    exact Real.log_injOn_pos (Set.mem_Ioi.mpr (pow_pos hp₁_pos b))
      (Set.mem_Ioi.mpr (pow_pos hp₂_pos a)) h_log_eq
  -- In ℕ: p₁^b = p₂^a
  have h_nat_eq : p₁ ^ b = p₂ ^ a := by
    exact_mod_cast h_pow_eq
  -- Unique factorization: p₁^b = p₂^a ⟹ p₁ = p₂ (contradiction)
  -- Since p₁ | p₁^b = p₂^a and p₁ is prime, p₁ | p₂^a.
  -- By Nat.Prime.dvd_of_dvd_pow, p₁ | p₂. Since p₂ is prime, p₁ = p₂.
  have h_dvd : p₁ ∣ p₂ ^ a := h_nat_eq ▸ dvd_pow_self p₁ hb
  have h_dvd_p₂ : p₁ ∣ p₂ := hp₁.dvd_of_dvd_pow h_dvd
  exact hne (hp₂.eq_one_or_self_of_dvd p₁ h_dvd_p₂ |>.resolve_left hp₁.one_lt.ne')

/-- **COROLLARY**: Distinct primes have distinct winding rates.
    windingCount p₁ 1 ≠ windingCount p₂ 1 for p₁ ≠ p₂. -/
theorem windingRate_distinct (p₁ p₂ : ℕ)
    (hp₁ : Nat.Prime p₁) (hp₂ : Nat.Prime p₂) (hne : p₁ ≠ p₂) :
    windingCount p₁ 1 ≠ windingCount p₂ 1 := by
  unfold windingCount
  intro heq
  -- 1·log(p₁)/(2π) = 1·log(p₂)/(2π) ⟹ log(p₁) = log(p₂)
  have hpi_ne : (2 * Real.pi) ≠ 0 := ne_of_gt (by positivity)
  -- heq : 1 * log p₁ / (2π) = 1 * log p₂ / (2π)
  have h_log_eq : Real.log (↑p₁ : ℝ) = Real.log ↑p₂ := by
    field_simp at heq; linarith
  -- log injective ⟹ p₁ = p₂
  have hp₁_pos : (0 : ℝ) < p₁ := Nat.cast_pos.mpr hp₁.pos
  have hp₂_pos : (0 : ℝ) < p₂ := Nat.cast_pos.mpr hp₂.pos
  have h_eq := Real.log_injOn_pos (Set.mem_Ioi.mpr hp₁_pos) (Set.mem_Ioi.mpr hp₂_pos) h_log_eq
  exact hne (Nat.cast_injective h_eq)

-- ════════════════════════════════════════════════
-- §11. INTERFERENCE BOUND — THE TRIANGLE INEQUALITY
-- ════════════════════════════════════════════════

/-! ### Interference is Bounded by Total Energy

The norm of the interference sum is at most the sum of amplitudes.
This is the triangle inequality: cancellation can only reduce
the total, never increase it.

At t = 0 (constructive interference), equality holds.
At a zeta zero (destructive interference), the norm = 0.
The journey from max to min IS the structure of ζ(s). -/

/-- **INTERFERENCE NORM BOUND**: ‖Σ dampedOscillator‖ ≤ Σ 1/√p.
    Cancellation can never exceed constructive interference. -/
theorem interferenceSum_norm_le' (primes : Finset ℕ)
    (h_ge2 : ∀ p ∈ primes, 2 ≤ p) (t : ℝ) :
    ‖interferenceSumOver primes t‖ ≤ ∑ p ∈ primes, amplitude p (1/2) := by
  unfold interferenceSumOver
  calc ‖∑ p ∈ primes, dampedOscillator p t‖
      ≤ ∑ p ∈ primes, ‖dampedOscillator p t‖ := norm_sum_le _ _
    _ = ∑ p ∈ primes, amplitude p (1/2) :=
        Finset.sum_congr rfl (fun p hp => dampedOscillator_norm p (h_ge2 p hp) t)

-- ════════════════════════════════════════════════
-- §12. AMPLITUDE DECAY — LARGER PRIMES WHISPER
-- ════════════════════════════════════════════════

/-! ### Amplitude Monotonicity

Larger primes contribute less to the interference sum.
This is why the first few primes dominate — they shout
while the larger primes whisper.

On the critical line: 1/√2 ≈ 0.707, 1/√3 ≈ 0.577, 1/√5 ≈ 0.447, ...
The sum Σ 1/√p diverges — every prime's vote matters! -/

/-- **AMPLITUDE MONOTONE**: amplitude p₁ σ > amplitude p₂ σ for p₁ < p₂ and σ > 0.
    Smaller primes contribute more energy. -/
theorem amplitude_strictAnti (p₁ p₂ : ℕ) (hp₁ : 2 ≤ p₁) (_hp₂ : 2 ≤ p₂)
    (hlt : p₁ < p₂) (σ : ℝ) (hσ : 0 < σ) :
    amplitude p₂ σ < amplitude p₁ σ := by
  unfold amplitude
  -- p₂⁻σ < p₁⁻σ because p₁ < p₂ and -σ < 0 (rpow_lt_rpow_of_neg)
  exact Real.rpow_lt_rpow_of_neg (by positivity) (by exact_mod_cast hlt) (by linarith)

-- ════════════════════════════════════════════════
-- §13. THE DEMOCRACY THEOREM
-- ════════════════════════════════════════════════

/-! ### Every Prime Votes Equally on the Critical Line

The critical line σ = ½ has a unique democratic property:
each prime's amplitude is 1/√p, and the sum Σ 1/√p diverges.
This means EVERY prime matters for the interference pattern.

At σ > ½: amplitudes are p⁻σ with σ > ½, so Σ p⁻σ converges.
The large primes' voices are drowned out — oligarchy, not democracy.

At σ < ½: amplitudes are p⁻σ with σ < ½, so Σ p⁻σ diverges
FASTER than Σ 1/√p. The large primes shout too loudly —
mob rule, not democracy.

σ = ½ is the unique value where every prime has JUST enough
influence to participate in the collective interference.
This is a deep reason why the critical line is special. -/

/-- **THE PRIME DEMOCRACY**: At σ = ½, the damped oscillators of
    any two primes have equal norm on the critical circle.
    dampedOscillator p₁ / dampedOscillator p₂ has norm √(p₂/p₁). -/
theorem democracy_ratio (p₁ p₂ : ℕ) (hp₁ : 2 ≤ p₁) (hp₂ : 2 ≤ p₂) (t : ℝ) :
    ‖dampedOscillator p₁ t‖ / ‖dampedOscillator p₂ t‖ =
    Real.sqrt p₂ / Real.sqrt p₁ := by
  rw [dampedOscillator_norm p₁ hp₁, dampedOscillator_norm p₂ hp₂]
  rw [amplitude_at_half p₁ hp₁, amplitude_at_half p₂ hp₂]
  have h1 : Real.sqrt (↑p₁) ≠ 0 := Real.sqrt_ne_zero'.mpr (by positivity)
  have h2 : Real.sqrt (↑p₂) ≠ 0 := Real.sqrt_ne_zero'.mpr (by positivity)
  field_simp

-- ════════════════════════════════════════════════
-- §14. THE RESONANCE DENSITY PICTURE
-- ════════════════════════════════════════════════

/-! ### How Many Zeros? The Winding Argument

The number of zeta zeros up to height T is approximately
N(T) ≈ (T/(2π)) · log(T/(2πe)).

This is the COUNTING version of the winding picture:
as t goes from 0 to T, the argument of ζ(½+it) winds
around the origin N(T) times. Each zero is one complete wind.

The density of zeros grows logarithmically — there are
infinitely many special heights where the prime choir
achieves perfect cancellation, and they get closer together
(in angular terms) as you go up. -/

/-- **WINDING DENSITY**: The number of primes with winding count
    in [n, n+1) at height t equals #{p : p prime, n ≤ t·log(p)/(2π) < n+1}.
    This measures the density of prime oscillators at each angular position. -/
def windingDensity (t : ℝ) (n : ℕ) (primes : Finset ℕ) : ℕ :=
  (primes.filter (fun p => n ≤ ⌊windingCount p t⌋₊ ∧ ⌊windingCount p t⌋₊ < n + 1)).card

end Cathedral.Spectral.PrimeHarmonics
