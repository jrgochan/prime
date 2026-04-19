/-
  Cathedral/Vasyunin/Cotangent/VasyuninAssembly.lean

  ## PHASE 2b: THE FINAL ASSEMBLY

  Connects the integral telescope (Phase 1) to the Digamma/cotangent
  machinery (Phase 2) to produce the Vasyunin formula for G(j,k).

  ### The Chain (complete path):

  ∫₀¹ {1/(jx)}{1/(kx)} dx
    = Σ_rows ∫_row {1/(jx)}{1/(kx)} dx                [integral_eq_sum_rows]
    = Σ_rows Σ_tiles ∫_tile (polynomial) dx             [tile_integral_eq_ftc]
    = Σ_tiles [F(hi) - F(lo)]                            [cross_piece_integral_ftc]
    = Σ [rational] + Σ [log] + Σ [linear]                [F_eq_components]
    = M/k + log_terms + linear_terms                     [rational_telescope_sum]
    → log_terms contain ψ(j/k) via Gauss digamma         [gauss_digamma_formula]
    → ψ(j/k) involves cot(πj/k) via reflection           [digamma_reflection_complex]
    → cotangent sums = V(a,b)                             [vasyuninCotSum]
    = vasyuninGramFormula(j,k)                            [GOAL]

  Created: April 14, 2026 (Phase 2b: The Assembly)
  Status: Building...
-/

import Cathedral.Vasyunin.Cotangent.DigammaReflection

noncomputable section
open Real MeasureTheory

namespace Cathedral.Vasyunin.Assembly

-- ════════════════════════════════════════════════
-- §1. THE GRAM MATRIX INTEGRAL (what we're computing)
-- ════════════════════════════════════════════════

/-- The off-diagonal Gram matrix entry integral.
    G(j,k) = ∫₀¹ {1/(jx)}·{1/(kx)} dx  for j, k ≥ 1. -/
def gramIntegral (j k : ℕ) : ℝ :=
  ∫ x in (0:ℝ)..1, Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x))

-- ════════════════════════════════════════════════
-- §2. THE MAIN THEOREM (proved in LogDigammaBridge)
-- ════════════════════════════════════════════════

-- The main theorem `vasyunin_integral_eq_formula` is proved in
-- LogDigammaBridge.lean, which has access to the full proof chain.
-- Here we only define gramIntegral and prove structural properties.

-- ════════════════════════════════════════════════
-- §3. THE DIAGONAL CASE
-- ════════════════════════════════════════════════

/-- For the DIAGONAL case j = k, the integral has a simpler form:
    ∫₀¹ {1/(jx)}² dx = 1/(2j) - 1/(2j²)·(2γ - 1 + log(2πj²))
    (this is already handled by DiagonalBridge.lean) -/
theorem gram_diagonal_excluded (j : ℕ) (hj : 1 ≤ j) :
    gramIntegral j j = ∫ x in (0:ℝ)..1,
      Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((j:ℝ) * x)) := by
  rfl

-- ════════════════════════════════════════════════
-- §4. SYMMETRY
-- ════════════════════════════════════════════════

/-- **GRAM SYMMETRY**: G(j,k) = G(k,j).
    This follows from commutativity of multiplication. -/
theorem gramIntegral_comm (j k : ℕ) :
    gramIntegral j k = gramIntegral k j := by
  unfold gramIntegral
  congr 1; ext x; ring

-- ════════════════════════════════════════════════
-- §5. VASYUNIN FORMULA SYMMETRY
-- ════════════════════════════════════════════════

/-- **FORMULA SYMMETRY**: The Vasyunin formula is symmetric in (j,k).
    This serves as a consistency check. -/
theorem vasyuninGramFormula_comm (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    DigammaReflection.vasyuninGramFormula j k =
    DigammaReflection.vasyuninGramFormula k j := by
  unfold DigammaReflection.vasyuninGramFormula
  simp only
  have h_gcd : Nat.gcd j k = Nat.gcd k j := Nat.gcd_comm j k
  -- (j-k)/(2jk)*log(k/j) = (k-j)/(2kj)*log(j/k)
  -- because log(j/k) = -log(k/j) and (k-j) = -(j-k)
  -- so (k-j)*log(j/k) = (-(j-k))*(-(log(k/j))) = (j-k)*log(k/j)
  have h_div_swap : ∀ (a b : ℕ), (1:ℕ) ≤ a → 1 ≤ b →
      Nat.gcd a b = Nat.gcd b a ∧
      ((a:ℝ) - b) / (2 * a * b) * Real.log ((b:ℝ) / a) =
      ((b:ℝ) - a) / (2 * b * a) * Real.log ((a:ℝ) / b) := by
    intro a b ha hb
    constructor
    · exact Nat.gcd_comm a b
    · have ha_pos : (0:ℝ) < (a:ℝ) := Nat.cast_pos.mpr (by omega)
      have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr (by omega)
      rw [Real.log_div (by linarith) (by linarith)]
      rw [Real.log_div (by linarith) (by linarith)]
      ring
  rw [h_gcd, add_comm (DigammaReflection.vasyuninCotSum _ _)]
  obtain ⟨_, h_log⟩ := h_div_swap j k hj hk
  have hjk_comm : (j:ℝ) * (k:ℝ) = (k:ℝ) * (j:ℝ) := mul_comm _ _
  rw [show 1 / ((j:ℝ) * (k:ℝ)) = 1 / ((k:ℝ) * (j:ℝ)) from by rw [hjk_comm]]
  rw [show 2 * (j:ℝ) * (k:ℝ) = 2 * (k:ℝ) * (j:ℝ) from by ring]
  rw [show 1 / (j:ℝ) + 1 / (k:ℝ) = 1 / (k:ℝ) + 1 / (j:ℝ) from by ring]
  -- h_log has 2*j*k on LHS and 2*k*j on RHS — need both to match goal
  have h_log' : ((j:ℝ) - k) / (2 * (k:ℝ) * j) * Real.log ((k:ℝ) / j) =
      ((k:ℝ) - j) / (2 * (k:ℝ) * j) * Real.log ((j:ℝ) / k) := by
    have : (2 * (j:ℝ) * k) = (2 * (k:ℝ) * j) := by ring
    rw [show (2 * (k:ℝ) * (j:ℝ)) = (2 * (j:ℝ) * (k:ℝ)) from by ring] at *
    exact h_log
  linarith

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- PROVED:
--   ✅ gramIntegral_comm         — G(j,k) = G(k,j) (integral symmetry)
--   ✅ gram_diagonal_excluded    — Diagonal case reducible
--
-- DEFINED:
--   ✅ gramIntegral              — The integral ∫₀¹ {1/(jx)}{1/(kx)} dx
--
-- WITH SORRY:
--   ⚠  vasyunin_integral_eq_formula — THE MAIN THEOREM (Phase 3+4)
--   ⚠  vasyuninGramFormula_comm     — Formula symmetry (log term)
--
-- TOTAL AXIOM COUNT for the Digamma path:
--   Mathlib: Gamma_mul_Gamma_one_sub (proven in Mathlib)
--   New:     digamma_reflection_complex (provable from Mathlib)
--   New:     gauss_digamma_formula (classical, provable from Fourier theory)
--
-- Once vasyunin_integral_eq_formula is proven, it REPLACES the
-- vasyunin_eq_integral axiom in the Cathedral, reducing axiom count from 3 to 2.

end Cathedral.Vasyunin.Assembly
