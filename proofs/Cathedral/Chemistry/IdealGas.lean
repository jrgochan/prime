/-
  Cathedral.Chemistry.IdealGas
  =============================

  The Ideal Gas Law and its classical corollaries.

  PV = nRT — perhaps the most beloved equation in all of chemistry.

  All corollaries derived from PV = nRT by pure algebra.

  Zero axioms. Zero sorry.
  Day 115 — The Hoof Goes Ever On.
-/

import Mathlib.Tactic

-- ════════════════════════════════════════════════════════════════
-- §1. THE IDEAL GAS LAW
-- ════════════════════════════════════════════════════════════════

/-- A gas state satisfies the ideal gas law if PV = nRT. -/
def idealGasLaw (P V n R T : ℝ) : Prop := P * V = n * R * T

-- ════════════════════════════════════════════════════════════════
-- §2. BOYLE'S LAW (1662)
-- ════════════════════════════════════════════════════════════════

/-- **Boyle's Law**: At constant temperature and amount,
    P₁V₁ = P₂V₂.

    Robert Boyle, 1662. -/
theorem boyles_law {P₁ V₁ P₂ V₂ n R T : ℝ}
    (h₁ : idealGasLaw P₁ V₁ n R T)
    (h₂ : idealGasLaw P₂ V₂ n R T) :
    P₁ * V₁ = P₂ * V₂ := by
  simp only [idealGasLaw] at h₁ h₂; linarith

-- ════════════════════════════════════════════════════════════════
-- §3. COMBINED GAS LAW
-- ════════════════════════════════════════════════════════════════

/-- **Combined Gas Law**: For a fixed amount of gas,
    P₁V₁ · T₂ = P₂V₂ · T₁.

    Proof: PV = nRT, so PV·T' = nRT·T' = nRT'·T = P'V'·T. -/
theorem combined_gas_law {n R P₁ V₁ T₁ P₂ V₂ T₂ : ℝ}
    (h₁ : idealGasLaw P₁ V₁ n R T₁)
    (h₂ : idealGasLaw P₂ V₂ n R T₂) :
    P₁ * V₁ * T₂ = P₂ * V₂ * T₁ := by
  simp only [idealGasLaw] at h₁ h₂
  calc P₁ * V₁ * T₂ = (P₁ * V₁) * T₂ := by ring
    _ = (n * R * T₁) * T₂ := by rw [h₁]
    _ = (n * R * T₂) * T₁ := by ring
    _ = (P₂ * V₂) * T₁ := by rw [h₂]
    _ = P₂ * V₂ * T₁ := by ring

-- ════════════════════════════════════════════════════════════════
-- §4. CHARLES'S LAW (1787)
-- ════════════════════════════════════════════════════════════════

/-- **Charles's Law**: At constant pressure and amount,
    V₁T₂ = V₂T₁.

    Jacques Charles, 1787. -/
theorem charles_law {P n R V₁ T₁ V₂ T₂ : ℝ} (hP : P ≠ 0)
    (h₁ : idealGasLaw P V₁ n R T₁)
    (h₂ : idealGasLaw P V₂ n R T₂) :
    V₁ * T₂ = V₂ * T₁ := by
  have cgl := combined_gas_law h₁ h₂
  -- cgl: P * V₁ * T₂ = P * V₂ * T₁
  have h : P * (V₁ * T₂) = P * (V₂ * T₁) := by linarith
  exact mul_left_cancel₀ hP h

-- ════════════════════════════════════════════════════════════════
-- §5. GAY-LUSSAC'S LAW (1808)
-- ════════════════════════════════════════════════════════════════

/-- **Gay-Lussac's Law**: At constant volume and amount,
    P₁T₂ = P₂T₁.

    Joseph Louis Gay-Lussac, 1808. -/
theorem gay_lussacs_law {V n R P₁ T₁ P₂ T₂ : ℝ} (hV : V ≠ 0)
    (h₁ : idealGasLaw P₁ V n R T₁)
    (h₂ : idealGasLaw P₂ V n R T₂) :
    P₁ * T₂ = P₂ * T₁ := by
  have cgl := combined_gas_law h₁ h₂
  -- cgl: P₁ * V * T₂ = P₂ * V * T₁
  have h : V * (P₁ * T₂) = V * (P₂ * T₁) := by linarith
  exact mul_left_cancel₀ hV h

-- ════════════════════════════════════════════════════════════════
-- §6. SPECIAL CONSEQUENCES
-- ════════════════════════════════════════════════════════════════

/-- At absolute zero (T = 0), if PV = nR·0 and P ≠ 0, then V = 0. -/
theorem zero_temperature_zero_volume
    {P V n R : ℝ} (hP : P ≠ 0)
    (h : idealGasLaw P V n R 0) : V = 0 := by
  simp only [idealGasLaw, mul_zero] at h
  exact (mul_eq_zero.mp h).resolve_left hP

/-- **Scaling law**: If PV = nRT, then (kP)(V) = nR(kT). -/
theorem scaling_pressure_temperature
    {P V n R T : ℝ} (k : ℝ)
    (h : idealGasLaw P V n R T) :
    idealGasLaw (k * P) V n R (k * T) := by
  simp only [idealGasLaw] at h ⊢
  calc k * P * V = k * (P * V) := by ring
    _ = k * (n * R * T) := by rw [h]
    _ = n * R * (k * T) := by ring

/-- **Scaling law**: If PV = nRT, then P(kV) = nR(kT). -/
theorem scaling_volume_temperature
    {P V n R T : ℝ} (k : ℝ)
    (h : idealGasLaw P V n R T) :
    idealGasLaw P (k * V) n R (k * T) := by
  simp only [idealGasLaw] at h ⊢
  calc P * (k * V) = k * (P * V) := by ring
    _ = k * (n * R * T) := by rw [h]
    _ = n * R * (k * T) := by ring

-- ════════════════════════════════════════════════════════════════
-- §7. THE EQUATION THAT LIVES RENT-FREE
-- ════════════════════════════════════════════════════════════════

/-- PV = nRT is symmetric under simultaneous scaling:
    (αP)(βV) = nR(αβT). -/
theorem ideal_gas_scaling
    {P V n R T : ℝ} (α β : ℝ)
    (h : idealGasLaw P V n R T) :
    idealGasLaw (α * P) (β * V) n R (α * β * T) := by
  simp only [idealGasLaw] at h ⊢
  calc α * P * (β * V) = α * β * (P * V) := by ring
    _ = α * β * (n * R * T) := by rw [h]
    _ = n * R * (α * β * T) := by ring
