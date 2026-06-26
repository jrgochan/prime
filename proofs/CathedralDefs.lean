/-
  CathedralDefs.lean — Shared Definitions for Comparator

  ════════════════════════════════════════════════════════════════

  Mathlib-only definitions used by both Challenge.lean and Solution.lean.
  Both files import this module, ensuring the comparator sees identical
  definition IDs in the lean4export output.

  Created: June 25, 2026 — comparator compatibility
-/

import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.ArithmeticFunction.Moebius
import Mathlib.NumberTheory.Harmonic.EulerMascheroni
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Basic
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.LinearAlgebra.Matrix.DotProduct
import Mathlib.Data.Matrix.Basic

noncomputable section
open Real Matrix Finset Filter ArithmeticFunction

namespace CathedralDefs

/-- The cotangent function: cot(x) = cos(x)/sin(x) -/
def cotFn (x : ℝ) : ℝ := Real.cos x / Real.sin x

/-- The Vasyunin cotangent sum:
    V(a, b) = Σ_{m=1}^{a-1} {mb/a} · cot(πm/a) -/
def vasyuninSum (a b : ℕ) : ℝ :=
  if a ≤ 1 then 0
  else ∑ m ∈ Ico 1 a,
    Int.fract ((m * b : ℕ) / (a : ℝ)) * cotFn (Real.pi * m / a)

/-- The exact Vasyunin-Báez-Duarte Gram matrix entry. -/
def vasyuninGramEntry (j k : ℕ) : ℝ :=
  let d := Nat.gcd j k
  let jp := j / d
  let kp := k / d
  if j = k then
    (Real.log (2 * Real.pi) - eulerMascheroniConstant) / (j : ℝ) - 1 / (j : ℝ) ^ 2
  else
    let jf : ℝ := j
    let kf : ℝ := k
    let term1 := (Real.log (2 * Real.pi) - eulerMascheroniConstant) / 2 * (1 / jf + 1 / kf)
    let term2 := (jf - kf) / (2 * jf * kf) * Real.log (kf / jf)
    let term3 := Real.pi * (d : ℝ) / (2 * jf * kf) *
                 (vasyuninSum jp kp + vasyuninSum kp jp)
    let term4 := 1 / (jf * kf)
    term1 + term2 - term3 - term4

/-- The N×N exact discrete Gram matrix. -/
def vasyuninGramMatrix (N : ℕ) : Matrix (Fin N) (Fin N) ℝ :=
  Matrix.of (fun i j => vasyuninGramEntry (i.val + 1) (j.val + 1))

/-- The logarithmic cutoff Möbius witness vector:
    v_k = -μ(k) · (1 - ln(k)/ln(N)) -/
def logCutoffWitness (N : ℕ) (i : Fin N) : ℝ :=
  -(↑(moebius (i.val + 1)) : ℝ) * (1 - Real.log ↑(i.val + 1) / Real.log ↑N)

end CathedralDefs
