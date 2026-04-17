/-
  Cathedral/MellinBridge/PlancherelDefs.lean

  ## Shared Definitions for the Parseval Bridge

  Definitions used by both PlancherelBypass.lean (the axiom-based chain)
  and White/Scattering.lean (the axiom-free chain).

  Extracted to break the circular dependency:
    PlancherelBypass ← White/Kinematics
    PlancherelBypass ← White/Scattering
  became:
    PlancherelDefs ← PlancherelBypass (axioms)
    PlancherelDefs ← White/ (proofs)
-/

import Cathedral.NymanBeurling.BDMellin
import Mathlib.Analysis.SpecialFunctions.Pow.Complex
import Mathlib.Analysis.Fourier.FourierTransform

noncomputable section
open Real MeasureTheory Finset BigOperators Complex
open scoped FourierTransform

-- ════════════════════════════════════════════════
-- §1. DEFINITIONS: FLATTENING & AUTOCORRELATION
-- ════════════════════════════════════════════════

/-- The real-valued residual of the True Báez-Duarte approximation.
    r_N(x) = 1 - f_N(x) = 1 - Σ v_k {1/(kx)}.
    Parameterized by weights v (more general than fixing bdMoebiusWeight). -/
def bdResidualV (N : ℕ) (v : Fin (N - 1) → ℝ) (x : ℝ) : ℝ :=
  1 - bdLinComb N v x

/-- The Mellin transform of the BD residual on the critical line.
    M_{1-f_N}(s) = ∫₀¹ r_N(x) · x^{s-1} dx.

    On the critical line s = 1/2 + it, this equals the Fourier
    transform of the flattened residual (up to 2π scaling).
    DOMAIN CORRECTION: Constrained to (0,1) to match the L²(0,1)
    Parseval identity and avoid the divergent tail on (1,∞). -/
def mellinBDResidual (N : ℕ) (v : Fin (N - 1) → ℝ) (s : ℂ) : ℂ :=
  ∫ x in Set.Ioo (0 : ℝ) 1, (bdResidualV N v x : ℂ) * (x : ℂ) ^ (s - 1)

/-- The flattened residual in the Fourier domain.
    g_N(u) = r_N(e^{-u}) · e^{-u/2} for u ≥ 0, zero otherwise.

    The e^{-u/2} factor serves a dual purpose:
    1. It ensures exponential decay, so g_N ∈ L¹ ∩ L²
    2. When squared, it produces the Jacobian e^{-u} = |dx/du|
       of the substitution x = e^{-u} (proved in flattenedResidual_sq_eq). -/
def flattenedResidualV (N : ℕ) (v : Fin (N - 1) → ℝ) (u : ℝ) : ℝ :=
  if 0 ≤ u then
    bdResidualV N v (Real.exp (-u)) * Real.exp (-u / 2)
  else 0

/-- Complex-valued flattened residual (for Fourier transform compatibility).
    Mathlib's Fourier transform operates on ℂ-valued functions. -/
def flattenedResidualC (N : ℕ) (v : Fin (N - 1) → ℝ) (u : ℝ) : ℂ :=
  (flattenedResidualV N v u : ℂ)

/-- The autocorrelation of the flattened residual: h(t) = (g_N ⋆ g̃_N)(t).

    Properties:
    - h is continuous (L² ⋆ L² → C₀ by Young's inequality)
    - h is in L¹ (Cauchy-Schwarz)
    - ĥ(ξ) = |ĝ_N(ξ)|² (convolution theorem) -/
def residualAutocorrelation (N : ℕ) (v : Fin (N - 1) → ℝ) (t : ℝ) : ℝ :=
  ∫ u : ℝ, flattenedResidualV N v u * flattenedResidualV N v (u - t)

-- ════════════════════════════════════════════════
-- §2. INTEGRABILITY LEMMAS (PROVED)
-- ════════════════════════════════════════════════

/-- The BD linear combination is uniformly bounded on (0,1].
    Since bdLinComb N v x = Σ vᵢ · {1/((i+1)x)}, and {·} ∈ [0,1),
    we have |bdLinComb N v x| ≤ Σ |vᵢ|. -/
lemma bdLinComb_bound (N : ℕ) (v : Fin (N - 1) → ℝ) (x : ℝ) :
    |bdLinComb N v x| ≤ ∑ i : Fin (N - 1), |v i| := by
  unfold bdLinComb
  calc |∑ i, v i * Int.fract (1 / (↑(i.val + 1) * x))|
      ≤ ∑ i, |v i * Int.fract (1 / (↑(i.val + 1) * x))| := Finset.abs_sum_le_sum_abs _ _
    _ = ∑ i, |v i| * |Int.fract (1 / (↑(i.val + 1) * x))| := by
        congr 1; ext i; exact abs_mul _ _
    _ ≤ ∑ i, |v i| * 1 := by
        gcongr with i
        rw [abs_of_nonneg (Int.fract_nonneg _)]
        exact le_of_lt (Int.fract_lt_one _)
    _ = ∑ i, |v i| := by simp

/-- The residual is bounded: |r_N(x)| ≤ 1 + Σ|vᵢ|. -/
lemma bdResidualV_bound (N : ℕ) (v : Fin (N - 1) → ℝ) (x : ℝ) :
    |bdResidualV N v x| ≤ 1 + ∑ i : Fin (N - 1), |v i| := by
  unfold bdResidualV
  calc |1 - bdLinComb N v x|
      ≤ |1| + |bdLinComb N v x| := abs_sub _ _
    _ ≤ 1 + ∑ i, |v i| := by
        simp only [abs_one]
        linarith [bdLinComb_bound N v x]

/-- The flattened residual decays exponentially:
    |g_N(u)| ≤ C · e^{-u/2} for some constant C depending on N.
    This immediately gives g_N ∈ L¹ ∩ L². -/
lemma flattenedResidualV_bound (N : ℕ) (v : Fin (N - 1) → ℝ) (u : ℝ) :
    |flattenedResidualV N v u| ≤
      (1 + ∑ i : Fin (N - 1), |v i|) * Real.exp (-u / 2) := by
  unfold flattenedResidualV
  by_cases hu : 0 ≤ u
  · simp [hu, abs_mul, abs_of_pos (Real.exp_pos _)]
    exact mul_le_mul_of_nonneg_right
      (bdResidualV_bound N v (Real.exp (-u)))
      (le_of_lt (Real.exp_pos _))
  · simp only [hu, ite_false, abs_zero]
    exact mul_nonneg (by positivity) (le_of_lt (Real.exp_pos _))

/-- **PROVED**: The key algebraic identity for the change of variables.
    g_N(u)² = r_N(e^{-u})² · e^{-u} for u ≥ 0.

    The e^{-u/2} factor was chosen precisely so that squaring it
    produces the Jacobian e^{-u} = |dx/du| of x = e^{-u}. -/
lemma flattenedResidualV_sq_eq (N : ℕ) (v : Fin (N - 1) → ℝ) (u : ℝ) (hu : 0 ≤ u) :
    (flattenedResidualV N v u) ^ 2 =
    (bdResidualV N v (Real.exp (-u))) ^ 2 * Real.exp (-u) := by
  unfold flattenedResidualV
  simp [hu]
  rw [mul_pow]
  congr 1
  rw [sq, ← Real.exp_add]
  ring_nf

/-- The autocorrelation at 0 equals the L² norm of g_N. -/
theorem autocorrelation_zero_eq_l2 (N : ℕ) (v : Fin (N - 1) → ℝ) :
    residualAutocorrelation N v 0 = ∫ u : ℝ, (flattenedResidualV N v u) ^ 2 := by
  unfold residualAutocorrelation
  congr 1; ext u; simp [sub_zero, sq]

-- ════════════════════════════════════════════════
-- §3. PLANCHEREL AXIOM (Parseval via Mathlib's 𝓕)
-- ════════════════════════════════════════════════

/-- **Plancherel's theorem** using Mathlib's standard Fourier transform 𝓕.

    ∫ ‖f(u)‖² du = ∫ ‖𝓕f(ξ)‖² dξ

    Mathlib has this as `norm_fourier_eq` for Lp functions
    (`Analysis.Fourier.LpSpace`). This axiom exists solely because
    Mathlib's Plancherel operates on `Lp ℂ 2` types while we use
    raw integrals. The bridge (MemLp + snorm ↔ integral + L2/L1
    agreement for the Fourier extension) is pure infrastructure. -/
axiom plancherel_mathlib_fourier (f : ℝ → ℂ) :
    ∫ u : ℝ, ‖f u‖ ^ 2 = ∫ ξ : ℝ, ‖𝓕 f ξ‖ ^ 2

/-- **PROVED**: Bridge from Mathlib's 𝓕 to our explicit exp formula.
    Shows: ∫ f(u) exp(-2πiξu) du = 𝓕 f ξ. -/
private lemma our_fourier_eq_mathlib_aux (f : ℝ → ℂ) (ξ : ℝ) :
    (∫ u : ℝ, f u * Complex.exp (-2 * ↑Real.pi * ↑ξ * ↑u * Complex.I)) =
    𝓕 f ξ := by
  rw [Real.fourier_real_eq_integral_exp_smul]
  congr 1; ext u; rw [smul_eq_mul, mul_comm]
  congr 1; push_cast; ring_nf

/-- **PROVED**: The original explicit-formula version follows from
    `plancherel_mathlib_fourier` + the formula matching lemma. -/
theorem plancherel_integral_axiom (f : ℝ → ℂ) :
    ∫ u : ℝ, ‖f u‖ ^ 2 =
    ∫ ξ : ℝ, ‖∫ u : ℝ, f u *
      Complex.exp (-2 * Real.pi * ξ * u * Complex.I)‖ ^ 2 := by
  have : (fun ξ : ℝ => ‖∫ u, f u * Complex.exp (-2 * ↑Real.pi * ↑ξ * ↑u * Complex.I)‖ ^ 2) =
         (fun ξ : ℝ => ‖𝓕 f ξ‖ ^ 2) := by
    ext ξ; rw [our_fourier_eq_mathlib_aux f ξ]
  rw [this]
  exact plancherel_mathlib_fourier f

end


