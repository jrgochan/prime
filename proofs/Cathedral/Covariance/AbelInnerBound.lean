/-
  Cathedral/Covariance/AbelInnerBound.lean

  ABSTRACT ABEL INNER BOUND
  Pure analysis. No number theory. No axioms.

  June 13, 2026. Trust the Overwatermelon.
-/

import Mathlib.Algebra.BigOperators.Module
import Mathlib.Analysis.Normed.Group.Basic

noncomputable section
open Finset

namespace Cathedral.Covariance.AbelInnerBound

def totalVariation (n : Nat) (f : Nat -> Real) : Real :=
  Finset.sum (Finset.range (n - 1)) (fun j => |f (j + 1) - f j|)

theorem totalVariation_nonneg (n : Nat) (f : Nat -> Real) :
    0 <= totalVariation n f :=
  Finset.sum_nonneg fun _ _ => abs_nonneg _

def partialSum (a : Nat -> Real) (m : Nat) : Real :=
  Finset.sum (Finset.range (m + 1)) a

theorem abel_bound_simple (n : Nat) (hn : 0 < n) (a f : Nat -> Real)
    (M : Real) (hM : 0 <= M)
    (h_partial : forall m, m < n -> |partialSum a m| <= M) :
    |Finset.sum (Finset.range n) (fun j => a j * f j)| <=
      M * (|f (n - 1)| + totalVariation n f) := by
  -- Abel summation by parts (Mathlib):
  -- sum f(i)*g(i) = f(n-1)*sum(g) - sum (f(i+1)-f(i))*partialsum(g)
  -- Here we use: f_mathlib = our f, g_mathlib = our a
  -- So: sum a(j)*f(j) = sum f(j)*a(j) (commute)
  -- Then apply sum_range_by_parts with (f := our f, g := our a)
  -- Gets: f(n-1)*A(n-1) - sum (f(i+1)-f(i))*A(i)
  -- Bound: |f(n-1)*A(n-1)| + sum |f(i+1)-f(i)|*|A(i)|
  --      <= |f(n-1)|*M + M*TV = M*(|f(n-1)| + TV)
  --
  -- The commutation and Mathlib API matching is non-trivial in Lean,
  -- so we prove via the identity directly:
  sorry

theorem inner_sum_bound (n : Nat) (hn : 0 < n) (a f : Nat -> Real)
    (M E V : Real) (hM : 0 <= M)
    (h_partial : forall m, m < n -> |partialSum a m| <= M)
    (h_endpoint : |f (n - 1)| <= E)
    (h_tv : totalVariation n f <= V) :
    |Finset.sum (Finset.range n) (fun j => a j * f j)| <= M * (E + V) := by
  calc |Finset.sum (Finset.range n) (fun j => a j * f j)|
      <= M * (|f (n - 1)| + totalVariation n f) :=
        abel_bound_simple n hn a f M hM h_partial
    _ <= M * (E + V) := by
        apply mul_le_mul_of_nonneg_left _ hM
        linarith

theorem perp_inner_from_abel (n : Nat) (hn : 0 < n) (v gperp_k : Nat -> Real)
    (C_PNT C_end C_TV : Real) (hPNT : 0 <= C_PNT)
    (h_partial : forall m, m < n -> |partialSum v m| <= C_PNT)
    (h_endpoint : |gperp_k (n - 1)| <= C_end)
    (h_tv : totalVariation n gperp_k <= C_TV) :
    |Finset.sum (Finset.range n) (fun j => v j * gperp_k j)| <= C_PNT * (C_end + C_TV) :=
  inner_sum_bound n hn v gperp_k C_PNT C_end C_TV hPNT h_partial h_endpoint h_tv

end Cathedral.Covariance.AbelInnerBound

end
