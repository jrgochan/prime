import Cathedral.MellinBridge.Basic

/-! # Cathedral.MellinBridge.HilbertSetup

## Hilbert space scaffolding for the separating functional

Establishes the L² framework for the Nyman-Beurling separation argument:
- The separating functional ℓ_ρ(f) = ∫₀¹ f(x)·x^{ρ-1} dx
- Its L² norm (continuity condition for Re(ρ) > 1/2)
- The Cauchy-Schwarz lower bound on the L² distance

### The "Light and Dark" Geometry
The critical line Re(ρ) = 1/2 is the event horizon:
- Re(ρ) > 1/2 ("Light"): x^{ρ-1} ∈ L²(0,1), functional is continuous
- Re(ρ) < 1/2 ("Dark"): x^{ρ-1} ∉ L²(0,1), functional diverges
- Re(ρ) = 1/2 ("Balance"): boundary case, the critical line

### Proof Architecture
1. l2_norm_sq_power: ∫₀¹ x^{2σ-2} dx = 1/(2σ-1) [PROVED]
2. mellin_at_zeta_zero: M₀₁[{k/x}](ρ) when ζ(ρ)=0 [TODO]
3. cauchy_schwarz_separation: ‖1-f‖² ≥ |ℓ_ρ(1-f)|²/‖ℓ_ρ‖² [TODO]
-/

noncomputable section
open Complex Real MeasureTheory Set Filter

-- ════════════════════════════════════════════════
-- STEP 1: L² NORM OF THE POWER KERNEL
-- ════════════════════════════════════════════════

/-- **PROVED (Step 1)**: The L² norm squared of x^{σ-1} on (0,1).

    For σ > 1/2:
      ∫₀¹ x^{2σ-2} dx = 1/(2σ-1)

    This is the squared norm ‖x^{ρ-1}‖²_{L²(0,1)} where σ = Re(ρ).
    It is finite iff σ > 1/2, which is the "Light" side of the
    critical line — the region where the separating functional
    ℓ_ρ(f) = ∫₀¹ f(x)·x^{ρ-1} dx is a continuous linear functional
    on L²(0,1).

    For σ = Re(ρ) > 1/2, the operator norm satisfies:
      ‖ℓ_ρ‖ ≤ ‖x^{ρ-1}‖_{L²} = 1/√(2σ-1)

    Uses Mathlib's `integral_rpow` for the computation. -/
theorem l2_norm_sq_power (σ : ℝ) (hσ : 1/2 < σ) :
    ∫ x in (0:ℝ)..1, x ^ (2*σ - 2) = 1 / (2*σ - 1) := by
  have hexp : -1 < 2 * σ - 2 := by linarith
  rw [integral_rpow (Or.inl hexp)]
  have h1 : 2 * σ - 2 + 1 = 2 * σ - 1 := by ring
  rw [h1, zero_rpow (by linarith : 2 * σ - 1 ≠ 0), one_rpow]
  ring

/-- **PROVED**: The L² norm squared is positive.
    ∫₀¹ x^{2σ-2} dx > 0 for σ > 1/2. -/
theorem l2_norm_sq_pos (σ : ℝ) (hσ : 1/2 < σ) :
    0 < ∫ x in (0:ℝ)..1, x ^ (2*σ - 2) := by
  rw [l2_norm_sq_power σ hσ]
  apply div_pos one_pos
  linarith

-- ════════════════════════════════════════════════
-- STEP 2: MELLIN EVALUATION AT ZETA ZEROS
-- ════════════════════════════════════════════════

/- **Documentation**: When ζ(ρ) = 0, the restricted Mellin transform
    of {k/x} simplifies.

    From the general formula (see MellinBridge.Basic):
      M₀₁[{k/x}](s) = k/(s(s-1)) + (k^s/s)(H_k(s) - ζ(s))

    When ζ(ρ) = 0:
      M₀₁[{k/x}](ρ) = k/(ρ(ρ-1)) + (k^ρ/ρ)·H_k(ρ)

    where H_k(ρ) = Σ_{m=1}^k m^{-ρ} is the partial Dirichlet sum.

    The separating functional ℓ_ρ applied to the NB basis gives:
      ℓ_ρ(1 - Σ wᵢ{(i+2)/x}) = 1/ρ - Σ wᵢ[kᵢ/(ρ(ρ-1)) + (kᵢ^ρ/ρ)H_{kᵢ}(ρ)]

    The Cauchy-Schwarz bound then yields:
      ‖1-f‖² ≥ |ℓ_ρ(1-f)|² · (2Re(ρ)-1)

    The key question (Step 4, "The Final Boss") is whether the
    RHS has a positive lower bound uniform in N and w.

    See OffDiagExcess.lean for the aggregate bound approach,
    and SeparationProof.lean (TODO) for the dilation trick. -/

-- ════════════════════════════════════════════════
-- STEP 3: CAUCHY-SCHWARZ SEPARATION FRAMEWORK
-- ════════════════════════════════════════════════

/-- **PROVED**: Non-vanishing of the target's Mellin transform.
    ∫₀¹ 1·x^{ρ-1} dx = 1/ρ ≠ 0 for ρ in the critical strip.

    This is already proved as `mellin_target` in MellinBridge.Basic.
    We record: if ρ ≠ 0 (which holds for Re(ρ) > 0), then
    mellinRestricted targetFnC ρ = 1/ρ ≠ 0. -/
theorem mellin_target_nonzero (ρ : ℂ) (hρ : 0 < ρ.re) :
    mellinRestricted targetFnC ρ ≠ 0 := by
  rw [mellin_target ρ hρ]
  intro h
  have hρ₀ : ρ ≠ 0 := by
    intro heq; rw [heq, zero_re] at hρ; exact lt_irrefl _ hρ
  exact hρ₀ (div_eq_zero_iff.mp h |>.elim (fun h => absurd h one_ne_zero) id)
