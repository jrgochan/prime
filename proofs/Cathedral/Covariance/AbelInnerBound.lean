/-
  Cathedral/Covariance/AbelInnerBound.lean

  ABSTRACT ABEL INNER BOUND
  Pure analysis. No number theory. No axioms. No sorry.

  THE KEY LEMMA: Abel summation by parts gives
    |sum a_j f_j| <= M * (|f(n-1)| + TV(f))
  where M = sup |A(m)| and TV = total variation.

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

/-- **ABSTRACT ABEL BOUND**: If all partial sums of a are bounded by M,
    then |sum a_j f_j| <= M * (|f(n-1)| + TV(f)).

    Uses Mathlib's Finset.sum_range_by_parts for the Abel identity.
    PROVED. Zero sorry. Pure analysis. -/
theorem abel_bound_simple (n : Nat) (hn : 0 < n) (a f : Nat -> Real)
    (M : Real) (_hM : 0 <= M)
    (h_partial : forall m, m < n -> |partialSum a m| <= M) :
    |Finset.sum (Finset.range n) (fun j => a j * f j)| <=
      M * (|f (n - 1)| + totalVariation n f) := by
  -- Step 1: Commute a*f to f*a
  simp_rw [show forall j, a j * f j = f j * a j from fun j => mul_comm _ _]
  -- Step 2: Apply Abel identity
  have h_abel := Finset.sum_range_by_parts f a n
  simp only [smul_eq_mul] at h_abel
  rw [h_abel]
  -- Step 3: Partial sum identities
  have h_ps_total : (range n).sum a = partialSum a (n - 1) := by
    simp [partialSum]
    have : n - 1 + 1 = n := Nat.succ_pred_eq_of_pos hn
    rw [this]
  have h_ps_i : forall i, (range (i + 1)).sum a = partialSum a i := by
    intro i; simp [partialSum]
  -- Step 4: |x - y| <= |x| + |y|
  calc |f (n - 1) * (range n).sum a -
        (range (n - 1)).sum (fun i => (f (i + 1) - f i) * (range (i + 1)).sum a)|
      <= |f (n - 1) * (range n).sum a| +
         |(range (n - 1)).sum (fun i => (f (i + 1) - f i) * (range (i + 1)).sum a)| :=
        abs_sub _ _
    -- Step 5: |f*S| = |f|*|S| and |S| <= M
    _ <= |f (n - 1)| * M +
         (range (n - 1)).sum (fun i => |(f (i + 1) - f i) * (range (i + 1)).sum a|) := by
        gcongr
        · rw [abs_mul, h_ps_total]
          exact mul_le_mul_of_nonneg_left (h_partial (n-1) (by omega)) (abs_nonneg _)
        · exact Finset.abs_sum_le_sum_abs _ _
    -- Step 6: |product| = |factor1|*|factor2| and |A(i)| <= M
    _ <= |f (n - 1)| * M +
         (range (n - 1)).sum (fun i => |f (i + 1) - f i| * M) := by
        gcongr with i hi
        rw [abs_mul, h_ps_i]
        exact mul_le_mul_of_nonneg_left
          (h_partial i (by simp [Finset.mem_range] at hi; omega))
          (abs_nonneg _)
    -- Step 7: Factor out M
    _ = M * (|f (n - 1)| + totalVariation n f) := by
        simp only [totalVariation]
        rw [<- Finset.sum_mul]
        ring

/-- **INNER SUM BOUND**: If partial sums <= M, |f(n-1)| <= E, TV <= V,
    then |sum a_j f_j| <= M * (E + V). PROVED. -/
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

/-- **PERPENDICULAR INNER BOUND**: Specialization for the perpendicular bridge.
    PROVED. -/
theorem perp_inner_from_abel (n : Nat) (hn : 0 < n) (v gperp_k : Nat -> Real)
    (C_PNT C_end C_TV : Real) (hPNT : 0 <= C_PNT)
    (h_partial : forall m, m < n -> |partialSum v m| <= C_PNT)
    (h_endpoint : |gperp_k (n - 1)| <= C_end)
    (h_tv : totalVariation n gperp_k <= C_TV) :
    |Finset.sum (Finset.range n) (fun j => v j * gperp_k j)| <= C_PNT * (C_end + C_TV) :=
  inner_sum_bound n hn v gperp_k C_PNT C_end C_TV hPNT h_partial h_endpoint h_tv

end Cathedral.Covariance.AbelInnerBound

end
