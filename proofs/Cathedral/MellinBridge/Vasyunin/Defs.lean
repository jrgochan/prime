/-
  Cathedral/MellinBridge/Vasyunin.lean

  ## The Vasyunin Discrete Formula

  Replaces the continuous integral definition of the Gram matrix with
  the exact Vasyunin cotangent sum. NO MEASURE THEORY. NO INTEGRALS.

  G(j,k) = (ln(2π) - γ)/2 · (1/j + 1/k)
            + (j-k)/(2jk) · ln(k/j)
            - πd/(2jk) · (V(j',k') + V(k',j'))
            - 1/(jk)

  where d = gcd(j,k), j' = j/d, k' = k/d, and
  V(a,b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)

  Source: Vasyunin (1995), Báez-Duarte (2003 IMRN)
  Verified: Attack 7, 256-bit MPFR, G(1,1) exact to 15 digits

  Created: April 9, 2026 (Calculus is Dead)
-/

import Mathlib.Data.Real.Basic
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Analysis.SpecialFunctions.ExpDeriv
import Mathlib.Analysis.Complex.ExponentialBounds
import Mathlib.Analysis.Real.Pi.Bounds
import Mathlib.NumberTheory.Harmonic.EulerMascheroni
import Mathlib.LinearAlgebra.Matrix.DotProduct
import Mathlib.NumberTheory.ArithmeticFunction.Moebius
import Mathlib.Data.Matrix.Basic
import Mathlib.LinearAlgebra.Matrix.PosDef
import Cathedral.LinearAlgebra.ShermanMorrison
import Cathedral.LinearAlgebra.SchurComplement

noncomputable section
open Real Matrix Finset

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- PART I: CONSTANTS AND PRIMITIVES
-- ════════════════════════════════════════════════

/-- Euler-Mascheroni constant γ ≈ 0.5772 -/
local notation "γ" => Real.eulerMascheroniConstant

/-- The cotangent function: cot(x) = cos(x)/sin(x) -/
def cot (x : ℝ) : ℝ := Real.cos x / Real.sin x

-- ════════════════════════════════════════════════
-- PART II: THE VASYUNIN COTANGENT SUM
-- ════════════════════════════════════════════════

/-- The Vasyunin cotangent sum:
    V(a, b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a)

    This finite sum encodes the arithmetic cross-talk between
    frequencies 1/a and 1/b in the Báez-Duarte basis.

    If a = 1, the range is empty and V(1, b) = 0.
    If a ≤ 1, defined as 0 for convenience.

    Properties:
    - V(a,b) depends only on (a,b) with gcd(a,b) = 1
    - The sum has exactly (a-1) terms
    - Computation cost: O(a) arithmetic operations -/
noncomputable def vasyuninSum (a b : ℕ) : ℝ :=
  if a ≤ 1 then 0
  else ∑ m ∈ Ico 1 a,
    Int.fract ((m * b : ℕ) / (a : ℝ)) * cot (Real.pi * m / a)

/-- V(1, b) = 0: the cotangent sum over an empty range. -/
theorem vasyuninSum_one (b : ℕ) : vasyuninSum 1 b = 0 := by
  unfold vasyuninSum; simp

/-- V(0, b) = 0 by convention. -/
theorem vasyuninSum_zero (b : ℕ) : vasyuninSum 0 b = 0 := by
  unfold vasyuninSum; simp


-- ════════════════════════════════════════════════
-- PART III: THE EXACT DISCRETE GRAM ENTRY
-- ════════════════════════════════════════════════

/-- The exact Vasyunin-Báez-Duarte Gram matrix entry.
    NO INTEGRALS. Pure discrete arithmetic.

    G(j,k) = (ln(2π) - γ)/2 · (1/j + 1/k)
              + (j-k)/(2jk) · ln(k/j)
              - πd/(2jk) · (V(j',k') + V(k',j'))
              - 1/(jk)

    where d = gcd(j,k), j' = j/d, k' = k/d.

    Special case j = k:
      G(j,j) = (ln(2π) - γ)/j - 1/j²

    Verified in Attack 7 (256-bit MPFR):
    - G(1,1) = 0.260661401507813 (exact match to closed form)
    - G(1,2) = 0.272209255990873 (exact match to integration)
    - G(2,2) = 0.380330700753906 (exact match to closed form) -/
noncomputable def vasyuninGramEntry (j k : ℕ) : ℝ :=
  let d := Nat.gcd j k
  let jp := j / d
  let kp := k / d
  if j = k then
    (Real.log (2 * Real.pi) - γ) / (j : ℝ) - 1 / (j : ℝ) ^ 2
  else
    let jf : ℝ := j
    let kf : ℝ := k
    let term1 := (Real.log (2 * Real.pi) - γ) / 2 * (1 / jf + 1 / kf)
    let term2 := (jf - kf) / (2 * jf * kf) * Real.log (kf / jf)
    let term3 := Real.pi * (d : ℝ) / (2 * jf * kf) *
                 (vasyuninSum jp kp + vasyuninSum kp jp)
    let term4 := 1 / (jf * kf)
    term1 + term2 - term3 - term4

/-- The diagonal Gram entry has a simplified form.
    G(k,k) = (ln(2π) - γ)/k - 1/k² -/
theorem vasyuninGramEntry_diag (k : ℕ) :
    vasyuninGramEntry k k =
    (Real.log (2 * Real.pi) - γ) / (k : ℝ) - 1 / (k : ℝ) ^ 2 := by
  unfold vasyuninGramEntry; simp

-- ════════════════════════════════════════════════
-- PART IV: THE EXACT MEAN VECTOR
-- ════════════════════════════════════════════════

/-- The closed-form mean vector entry:
    b_k = (ln(k) + 1 - γ) / k

    This is the inner product ⟨1, h_k⟩ in L²(0,1)
    where h_k(x) = {1/(kx)} is the Báez-Duarte basis.

    Verified to 12+ digits against numerical quadrature. -/
noncomputable def vasyuninMeanEntry (k : ℕ) : ℝ :=
  (Real.log (k : ℝ) + 1 - γ) / (k : ℝ)

/-- The first mean entry: b₁ = 1 - γ ≈ 0.4228.
    b₁ = (ln(1) + 1 - γ) / 1 = (0 + 1 - γ) / 1 = 1 - γ. -/
theorem vasyuninMeanEntry_one :
    vasyuninMeanEntry 1 = 1 - γ := by
  unfold vasyuninMeanEntry
  simp [Real.log_one]

/-- The first diagonal Gram entry: G(1,1) = ln(2π) - γ - 1 ≈ 0.261.
    From the diagonal formula with k = 1. -/
theorem vasyuninGramEntry_one_one :
    vasyuninGramEntry 1 1 = Real.log (2 * Real.pi) - γ - 1 := by
  rw [vasyuninGramEntry_diag]
  simp

/-- The second mean entry: b₂ = (ln(2) + 1 - γ) / 2 ≈ 0.5600. -/
theorem vasyuninMeanEntry_two :
    vasyuninMeanEntry 2 = (Real.log 2 + 1 - γ) / 2 := by
  unfold vasyuninMeanEntry; norm_num

/-- The second diagonal Gram entry: G(2,2) = (ln(2π) - γ)/2 - 1/4. -/
theorem vasyuninGramEntry_two_two :
    vasyuninGramEntry 2 2 =
    (Real.log (2 * Real.pi) - γ) / 2 - 1 / 4 := by
  rw [vasyuninGramEntry_diag]; norm_num

-- ════════════════════════════════════════════════
-- PART V: THE MATRICES
-- ════════════════════════════════════════════════

/-- The N×N exact discrete Gram matrix. -/
noncomputable def vasyuninGramMatrix (N : ℕ) : Matrix (Fin N) (Fin N) ℝ :=
  Matrix.of (fun i j => vasyuninGramEntry (i.val + 1) (j.val + 1))

/-- The mean vector b ∈ ℝᴺ. -/
noncomputable def vasyuninMeanVec (N : ℕ) : Fin N → ℝ :=
  fun i => vasyuninMeanEntry (i.val + 1)

/-- The covariance matrix C = G - bbᵀ.
    This is the Gram matrix with the rank-1 mean removed. -/
noncomputable def vasyuninCovMatrix (N : ℕ) : Matrix (Fin N) (Fin N) ℝ :=
  vasyuninGramMatrix N - vecMulVec (vasyuninMeanVec N) (vasyuninMeanVec N)

/-- The diagonal of the Gram matrix satisfies the diagonal formula. -/
theorem vasyuninGramMatrix_diag (N : ℕ) (i : Fin N) :
    vasyuninGramMatrix N i i =
    (Real.log (2 * Real.pi) - γ) / (i.val + 1 : ℝ) -
      1 / (i.val + 1 : ℝ) ^ 2 := by
  unfold vasyuninGramMatrix
  simp [of_apply, vasyuninGramEntry_diag]


end Cathedral.Vasyunin
