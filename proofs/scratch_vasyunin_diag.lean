/-
  scratch_vasyunin_diag.lean — Exploration: proving vasyunin_eq_integral diagonal case

  TARGET: vasyuninGramEntry k k = ∫₀¹ {1/(kx)}² dx

  KNOWN: vasyuninGramEntry k k = (ln(2π) - γ)/k - 1/k²

  STRATEGY:
  By substitution u = kx:
    ∫₀¹ {1/(kx)}² dx = (1/k) ∫₀ᵏ {1/u}² du

  Split ∫₀ᵏ into ∫₀¹ + ∫₁ᵏ:
  - On (1, k): {1/u} = 1/u since 0 < 1/u < 1
    ∫₁ᵏ (1/u)² du = 1 - 1/k
  - On (0, 1): piecewise on (1/(n+1), 1/n) where {1/u} = 1/u - n
    ∫₁/(n+1)^{1/n} (1/u - n)² du = -2n·ln(1+1/n) + (2n+1)/(n+1)

  So ∫₀¹ {1/(kx)}² dx = (1/k)[∫₀¹ {1/u}² du + 1 - 1/k]

  We need: ∫₀¹ {1/u}² du = ln(2π) - γ - 1

  This requires: Σ_{n≥1} [-2n·ln(1+1/n) + 2 - 1/(n+1)]
  Using: n·ln((n+1)/n) telescopes via Stirling / log-factorial identities
-/

import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.MeasureTheory.Integral.IntervalIntegral.FundThmCalculus
import Mathlib.MeasureTheory.Function.Floor
import Mathlib.Analysis.SpecialFunctions.Log.Deriv
import Mathlib.NumberTheory.Harmonic.EulerMascheroni
import Cathedral.MellinBridge.Vasyunin.MeanIntegral

noncomputable section
open Real MeasureTheory

-- ════════════════════════════════════════════════
-- §1. PIECE INTEGRAL: ∫_{1/(n+1)}^{1/n} {1/u}² du
-- ════════════════════════════════════════════════

/-- On (1/(n+1), 1/n) with n ≥ 1, ⌊1/u⌋ = n, so {1/u} = 1/u - n. -/
lemma fract_inv_eq_on_piece (n : ℕ) (hn : n ≥ 1) (u : ℝ)
    (hu_lo : 1 / ((n : ℝ) + 1) < u) (hu_hi : u < 1 / (n : ℝ)) :
    Int.fract (1 / u) = 1 / u - (n : ℝ) := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have hn1_pos : (0 : ℝ) < (n : ℝ) + 1 := by linarith
  have hu_pos : (0 : ℝ) < u := lt_trans (div_pos one_pos hn1_pos) hu_lo
  have hu_ne : u ≠ 0 := ne_of_gt hu_pos
  -- 1/u > n (from u < 1/n)
  have h_inv_gt : (n : ℝ) < 1 / u := by
    rw [one_div, lt_inv_comm₀ hn_pos hu_pos]
    rwa [one_div] at hu_hi
  -- 1/u < n+1 (from u > 1/(n+1))
  have h_inv_lt : 1 / u < (n : ℝ) + 1 := by
    rw [one_div, inv_lt_comm₀ hu_pos hn1_pos]
    rwa [one_div] at hu_lo
  -- Floor = n
  have h_floor : ⌊1 / u⌋ = (n : ℤ) := by
    rw [Int.floor_eq_iff]
    constructor
    · exact_mod_cast h_inv_gt.le
    · push_cast; linarith
  rw [Int.fract, h_floor, Int.cast_natCast]

/-- The antiderivative of (1/u - n)² is -1/u - 2n·ln(u) + n²·u. -/
lemma hasDerivAt_piece_antideriv (n : ℕ) (u : ℝ) (hu : u ≠ 0) :
    HasDerivAt (fun u => -1/u - 2*(n : ℝ)*Real.log u + (n : ℝ)^2*u)
      ((1/u - (n : ℝ))^2) u := by
  have hu_pos_or_neg := ne_iff_lt_or_gt.mp hu
  -- d/du[-1/u] = 1/u²
  -- d/du[-2n·ln(u)] = -2n/u
  -- d/du[n²·u] = n²
  -- Total = 1/u² - 2n/u + n² = (1/u - n)²
  sorry -- FTC computation, needs HasDerivAt for each term

-- ════════════════════════════════════════════════
-- §2. UPPER INTERVAL: ∫₁ᵏ (1/u)² du = 1 - 1/k
-- ════════════════════════════════════════════════

/-- On (1, k) with k ≥ 1, {1/u} = 1/u since 0 < 1/u < 1. -/
lemma fract_inv_eq_self_above_one (u : ℝ) (hu : 1 < u) :
    Int.fract (1 / u) = 1 / u := by
  have hu_pos : (0 : ℝ) < u := by linarith
  have h_pos : (0 : ℝ) < 1 / u := div_pos one_pos hu_pos
  have h_lt : 1 / u < 1 := by rwa [div_lt_one hu_pos]
  rw [Int.fract_eq_self.mpr ⟨le_of_lt h_pos, h_lt⟩]

/-- ∫₁ᵏ (1/u)² du = 1 - 1/k -/
theorem upper_sq_integral (k : ℕ) (hk : 1 ≤ k) :
    ∫ u in (1:ℝ)..(k:ℝ), (1/u)^2 = 1 - 1/(k:ℝ) := by
  -- Antiderivative: F(u) = -1/u, F'(u) = 1/u² = (1/u)²
  have hle : (1:ℝ) ≤ (k:ℝ) := by exact_mod_cast hk
  have hF : ∀ u ∈ Set.uIcc (1:ℝ) (k:ℝ),
      HasDerivAt (fun u => -(u⁻¹)) (u⁻¹^2) u := by
    intro u hu
    rw [Set.uIcc_of_le hle] at hu
    have hu_pos : (0 : ℝ) < u := lt_of_lt_of_le one_pos hu.1
    have hd := hasDerivAt_inv (ne_of_gt hu_pos)
    -- hd : HasDerivAt (·⁻¹) (-(u^2)⁻¹) u
    -- We want: HasDerivAt (-(·⁻¹)) ((u^2)⁻¹) u = HasDerivAt (-(·⁻¹)) (u⁻¹^2) u
    have := hd.neg
    simp only [inv_pow] at this ⊢
    convert this using 1
    ring
  -- Convert (1/u)^2 to u⁻¹^2
  have hcongr : (fun u : ℝ => (1/u)^2) = (fun u => u⁻¹^2) := by
    ext u; simp [one_div]
  rw [hcongr]
  have hint : IntervalIntegrable (fun u : ℝ => u⁻¹^2) volume (1:ℝ) (k:ℝ) := by
    apply ContinuousOn.intervalIntegrable
    apply ContinuousOn.pow
    exact continuousOn_inv₀.mono (by
      intro u hu; rw [Set.uIcc_of_le hle] at hu
      exact ne_of_gt (lt_of_lt_of_le one_pos hu.1))
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hF hint]
  simp [inv_one]; ring

-- ════════════════════════════════════════════════
-- §3. THE UNIVERSAL INTEGRAL: ∫₀¹ {1/u}² du = ln(2π) - γ - 1
-- ════════════════════════════════════════════════

-- This is the HARD part. Each piece gives:
--   ∫_{1/(n+1)}^{1/n} (1/u - n)² du = -2n·ln(1+1/n) + (2n+1)/(n+1)
-- Summing: Σ_{n≥1} [-2n·ln(1+1/n) + 2 - 1/(n+1)]
-- = -2·Σ n·ln((n+1)/n) + 2N - (H_{N+1} - 1)
--
-- Key: Σ_{n=1}^N n·ln((n+1)/n) = (N+1)·ln(N+1) - ln((N+1)!)
-- And ln(N!) = Σ ln(k) so we need Stirling: ln(N!) ~ N·ln(N) - N + ½ln(2πN)
--
-- The CRITICAL number-theoretic identity is:
-- ln(2π) = lim_{N→∞} [2·Σ_{n=1}^N n·ln((n+1)/n) - 2N + H_{N+1}]
--        = lim_{N→∞} [2(N+1)·ln(N+1) - 2·ln((N+1)!) - 2N + H_{N+1}]
--
-- This is essentially Stirling's formula in disguise.

-- For now, let's state what we need and leave the hard analysis for later:

/-- **THE STIRLING-EULER IDENTITY** (the key analytic lemma).
    ∫₀¹ {1/u}² du = ln(2π) - γ - 1.
    This encodes the Stirling constant 2π into the fractional-part integral. -/
axiom fract_inv_sq_integral :
    ∫ u in (0:ℝ)..1, Int.fract (1 / u) ^ 2 =
    Real.log (2 * Real.pi) - Real.eulerMascheroniConstant - 1

-- ════════════════════════════════════════════════
-- §4. ASSEMBLY: diagonal case of vasyunin_eq_integral
-- ════════════════════════════════════════════════

-- If we can prove fract_inv_sq_integral, then:
-- ∫₀¹ {1/(kx)}² dx
--   = (1/k) ∫₀ᵏ {1/u}² du           (by substitution u = kx)
--   = (1/k) [∫₀¹ {1/u}² du + ∫₁ᵏ (1/u)² du]   (split + piece)
--   = (1/k) [(ln(2π) - γ - 1) + (1 - 1/k)]
--   = (1/k) [ln(2π) - γ - 1/k]
--   = (ln(2π) - γ)/k - 1/k²
--   = vasyuninGramEntry k k  ✓

-- This reduces vasyunin_eq_integral for j=k to fract_inv_sq_integral!

end
