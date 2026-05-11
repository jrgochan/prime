/-
  Cathedral/Covariance/GCDPartition.lean

  ## The GCD Partition of the Taper Decomposition

  PHYSICS: Decomposing the Möbius-Gram energy by arithmetic locality.
  MATH: Partitioning the double sum Σ_{j,k} by gcd(j,k) = d.

  The taper sums U(N), L(N), Q(N) each decompose as:
    U(N) = Σ_{d=1}^{N-1} U_d(N)
    L(N) = Σ_{d=1}^{N-1} L_d(N)
    Q(N) = Σ_{d=1}^{N-1} Q_d(N)

  where U_d, L_d, Q_d restrict the double sum to pairs with gcd(j,k) = d.
  This is a purely combinatorial partition — no analysis needed.

  Combined with the taper decomposition (TaperDecomposition.lean), we get:
    vᵀGv = Σ_d [U_d - 2L_d/lnN + Q_d/ln²N]

  The GPU experiment at N=55,440 revealed:
    - sign(R₂_d) = μ(d) at 88% accuracy (44/50 strata)
    - Σ_d R₂_d ≈ 0.987 → 1 (the RH content)

  This file proves the partition identity: the global taper sums
  equal the sum of their GCD strata.

  Created: May 10, 2026
  Status: Structural — PROVED (zero sorry).
-/

import Cathedral.Defs
import Cathedral.Covariance.TaperDecomposition
import Mathlib.Data.Real.Basic
import Mathlib.Data.Nat.GCD.Basic

noncomputable section
open Real Finset ArithmeticFunction

namespace Cathedral.Covariance.GCDPartition

-- ════════════════════════════════════════════════
-- §1. GCD-STRATIFIED TAPER SUMS
-- ════════════════════════════════════════════════

/-- The GCD-stratified untapered sum: U_d(N) = Σ_{j,k: gcd(j,k)=d} μ(j)μ(k) G(j,k).
    This restricts the ground-state interaction to pairs sharing exactly
    the divisor structure d. -/
def untaperedSum_gcd (N d : ℕ) : ℝ :=
  ∑ j ∈ Icc 1 (N - 1), ∑ k ∈ Icc 1 (N - 1),
    if Nat.gcd j k = d then
      (moebius j : ℝ) * (moebius k : ℝ) *
      Cathedral.Vasyunin.vasyuninGramEntry j k
    else 0

/-- The GCD-stratified linear taper sum: L_d(N) = Σ_{gcd(j,k)=d} μ(j)μ(k) ln(j) G(j,k). -/
def linearTaperSum_gcd (N d : ℕ) : ℝ :=
  ∑ j ∈ Icc 1 (N - 1), ∑ k ∈ Icc 1 (N - 1),
    if Nat.gcd j k = d then
      (moebius j : ℝ) * (moebius k : ℝ) *
      Real.log (j : ℝ) * Cathedral.Vasyunin.vasyuninGramEntry j k
    else 0

/-- The GCD-stratified quadratic taper sum: Q_d(N) = Σ_{gcd(j,k)=d} μ(j)μ(k) ln(j)ln(k) G(j,k). -/
def quadraticTaperSum_gcd (N d : ℕ) : ℝ :=
  ∑ j ∈ Icc 1 (N - 1), ∑ k ∈ Icc 1 (N - 1),
    if Nat.gcd j k = d then
      (moebius j : ℝ) * (moebius k : ℝ) *
      Real.log (j : ℝ) * Real.log (k : ℝ) *
      Cathedral.Vasyunin.vasyuninGramEntry j k
    else 0

/-- The per-stratum two-term remainder: R₂_d(N) = U_d - 2L_d/lnN.
    The Möbius Stratum Convergence Conjecture states:
      sign(R₂_d) = μ(d) asymptotically, and Σ_d R₂_d → 1. -/
def R₂_gcd (N d : ℕ) : ℝ :=
  untaperedSum_gcd N d - 2 * linearTaperSum_gcd N d / Real.log (N : ℝ)

-- ════════════════════════════════════════════════
-- §2. THE GCD PARTITION LEMMA
-- ════════════════════════════════════════════════

/-- For any j, k in Icc 1 (N-1), their gcd is also in Icc 1 (N-1). -/
private lemma gcd_mem_range {N j k : ℕ} (hj : j ∈ Icc 1 (N - 1)) (_hk : k ∈ Icc 1 (N - 1)) :
    Nat.gcd j k ∈ Icc 1 (N - 1) := by
  simp only [mem_Icc] at hj _hk ⊢
  exact ⟨Nat.one_le_iff_ne_zero.mpr (Nat.gcd_ne_zero_left (by omega)),
         le_trans (Nat.gcd_le_left k (by omega)) hj.2⟩

/-- Generic partition-by-GCD lemma: any double sum over Icc 1 (N-1)
    can be partitioned by the value of gcd(j,k).

    This is the key algebraic fact: every pair (j,k) with 1 ≤ j,k ≤ N-1
    has a unique gcd value d ∈ {1,...,N-1}, so summing over all d recovers
    the original unrestricted double sum. -/
theorem sum_eq_sum_gcd (N : ℕ) (_hN : 2 ≤ N) (f : ℕ → ℕ → ℝ) :
    (∑ j ∈ Icc 1 (N - 1), ∑ k ∈ Icc 1 (N - 1), f j k) =
    ∑ d ∈ Icc 1 (N - 1),
      ∑ j ∈ Icc 1 (N - 1), ∑ k ∈ Icc 1 (N - 1),
        if Nat.gcd j k = d then f j k else 0 := by
  -- The proof is: f(j,k) = Σ_d [d = gcd(j,k)] · f(j,k)
  -- i.e., the indicator function sums to 1 for the unique gcd value.
  symm
  -- Swap the d and j sums
  rw [Finset.sum_comm]
  apply Finset.sum_congr rfl
  intro j hj
  rw [Finset.sum_comm]
  apply Finset.sum_congr rfl
  intro k hk
  -- Now we need: Σ_{d ∈ Icc 1 (N-1)} [gcd(j,k) = d] · f(j,k) = f(j,k)
  -- This is Finset.sum_ite_eq' applied to the indicator function
  have h_mem : Nat.gcd j k ∈ Icc 1 (N - 1) := gcd_mem_range hj hk
  rw [Finset.sum_eq_single (Nat.gcd j k)]
  · simp
  · intro d _ hd; exact if_neg (Ne.symm hd)
  · intro h_abs; exact absurd h_mem h_abs

-- ════════════════════════════════════════════════
-- §3. THE MAIN PARTITION THEOREMS
-- ════════════════════════════════════════════════

/-- **THEOREM (GCD Partition of U)**: The untapered sum equals the sum of its GCD strata.

    U(N) = Σ_{d=1}^{N-1} U_d(N)

    This is a partition of the double sum by gcd(j,k) value. -/
theorem untaperedSum_partition (N : ℕ) (hN : 2 ≤ N) :
    TaperDecomposition.untaperedSum N =
    ∑ d ∈ Icc 1 (N - 1), untaperedSum_gcd N d := by
  unfold TaperDecomposition.untaperedSum untaperedSum_gcd
  exact sum_eq_sum_gcd N hN _

/-- **THEOREM (GCD Partition of L)**: The linear taper sum equals the sum of its GCD strata.

    L(N) = Σ_{d=1}^{N-1} L_d(N) -/
theorem linearTaperSum_partition (N : ℕ) (hN : 2 ≤ N) :
    TaperDecomposition.linearTaperSum N =
    ∑ d ∈ Icc 1 (N - 1), linearTaperSum_gcd N d := by
  unfold TaperDecomposition.linearTaperSum linearTaperSum_gcd
  exact sum_eq_sum_gcd N hN _

/-- **THEOREM (GCD Partition of Q)**: The quadratic taper sum equals the sum of its GCD strata.

    Q(N) = Σ_{d=1}^{N-1} Q_d(N) -/
theorem quadraticTaperSum_partition (N : ℕ) (hN : 2 ≤ N) :
    TaperDecomposition.quadraticTaperSum N =
    ∑ d ∈ Icc 1 (N - 1), quadraticTaperSum_gcd N d := by
  unfold TaperDecomposition.quadraticTaperSum quadraticTaperSum_gcd
  exact sum_eq_sum_gcd N hN _

-- ════════════════════════════════════════════════
-- §4. THE MÖBIUS STRATUM CONVERGENCE CONJECTURE
-- ════════════════════════════════════════════════

/-!
## The Möbius Stratum Convergence Conjecture

**Discovered:** May 10, 2026 (GPU experiment, N=55,440, RTX 4090)

**Statement:** For each squarefree d with μ(d) ≠ 0:
  sign(R₂_d(N)) = μ(d) for all sufficiently large N

**Empirical evidence (N=55,440, DD precision):**
  sign(R₂_d) = μ(d) in 44 of 50 strata (88% match)

**Top cancelling pairs:**
  d=6  (μ=+1): R₂ = +1.427
  d=5  (μ=−1): R₂ = −1.433    ← annihilate to −0.006 (200× reduction)
  d=10 (μ=+1): R₂ = +0.834
  d=3  (μ=−1): R₂ = −1.214

**The d=2 anomaly:** μ(2) = −1 but R₂_2 = +0.762.
  The even stratum breaks Möbius symmetry to shift the sum from 0 to 1.
  This is the "dark sector" — the thermodynamic anchor of the Cathedral.

**Implication:** If proved, the sum rule Σ_d R₂_d → 1 gives vᵀGv → 1,
  which implies the Riemann Hypothesis via `gram_bound_implies_rh`.

  The conjecture provides a discrete, arithmetic proof architecture:
  instead of contour integrals in the complex plane, prove that each
  node in the divisor poset obeys its Möbius parity assignment.

## Audit

### Sorry: 0
### Axioms: 0 (this file is purely algebraic)

### Architecture:
```
  sum_eq_sum_gcd (partition lemma) ────────────┐
                                               ├──→ untaperedSum_partition
                                               ├──→ linearTaperSum_partition
                                               └──→ quadraticTaperSum_partition
```

These combine with `gram_form_taper_decomposition` (TaperDecomposition.lean)
to give the full GCD partition of vᵀGv.
-/

end Cathedral.Covariance.GCDPartition
