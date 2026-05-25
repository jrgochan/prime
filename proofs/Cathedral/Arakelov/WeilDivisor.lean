/-
  Cathedral/Arakelov/WeilDivisor.lean

  ## WEIL DIVISORS ON Spec(ℤ)

  ════════════════════════════════════════════════════════════════

  A Weil divisor on Spec(ℤ) is a formal ℤ-linear combination of
  prime ideals. Since prime ideals of ℤ are in bijection with
  prime numbers, a Weil divisor is a finitely-supported function
  from primes to ℤ:

    D = Σ_p n_p · (p)

  This is Layer 1 of the Arakelov Bridge:
  Weil divisors → Arithmetic divisors → Intersection pairing → RH

  Status: ALL PROVED (0 sorry, 0 axioms)
  Dependencies: Mathlib (Finsupp, Nat.factorization, log)
  Created: May 25, 2026 — The Arakelov Road
-/

import Mathlib.Data.Finsupp.Defs
import Mathlib.Data.Finsupp.Basic
import Mathlib.Data.Nat.Factorization.Basic
import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Data.PNat.Basic

noncomputable section
open Real BigOperators

namespace Cathedral.Arakelov

-- ════════════════════════════════════════════════════════════════
-- §1. THE PRIME SPECTRUM OF ℤ
-- ════════════════════════════════════════════════════════════════

/-- A point of the prime spectrum of ℤ — a prime number. -/
abbrev PrimeSpec := Nat.Primes

-- ════════════════════════════════════════════════════════════════
-- §2. WEIL DIVISORS
-- ════════════════════════════════════════════════════════════════

/-- A Weil divisor on Spec(ℤ): a finitely-supported function
    from prime numbers to ℤ. `D q` = multiplicity of (q) in D.

    Using `abbrev` so Lean sees through to Finsupp and all
    the group structure + function application works. -/
abbrev WeilDivisor := PrimeSpec →₀ ℤ

namespace WeilDivisor

/-- A divisor is effective if all coefficients are nonneg. -/
def IsEffective (D : WeilDivisor) : Prop := ∀ q : PrimeSpec, 0 ≤ D q

/-- The zero divisor is effective. -/
theorem zero_isEffective : IsEffective 0 := fun _ => le_refl _

-- ════════════════════════════════════════════════════════════════
-- §3. PRINCIPAL DIVISORS
-- ════════════════════════════════════════════════════════════════

/-- A single-prime divisor: n copies of the prime ideal (q). -/
abbrev ofSingle (q : PrimeSpec) (n : ℤ) : WeilDivisor :=
  Finsupp.single q n

/-- The principal divisor of a prime: div(p) = 1·(p). -/
def ofPrime (q : PrimeSpec) : WeilDivisor := ofSingle q 1

/-- The principal divisor of a prime is effective. -/
theorem ofPrime_isEffective (q : PrimeSpec) : IsEffective (ofPrime q) := by
  intro r
  simp only [ofPrime, Finsupp.single_apply]
  split <;> omega

/-- The support of div(p) is {p}. -/
theorem ofPrime_support (q : PrimeSpec) :
    (ofPrime q).support = {q} :=
  Finsupp.support_single_ne_zero _ (by omega : (1 : ℤ) ≠ 0)

-- ════════════════════════════════════════════════════════════════
-- §4. THE LOG-DEGREE
-- ════════════════════════════════════════════════════════════════

/-- The log-degree of a Weil divisor: Σ D(p) · log(p).
    This is the "finite part" of the Arakelov height. -/
def logDegree (D : WeilDivisor) : ℝ :=
  D.sum fun q n => (n : ℝ) * Real.log q.val

/-- The log-degree of the zero divisor is zero. -/
theorem logDegree_zero : logDegree (0 : WeilDivisor) = 0 :=
  Finsupp.sum_zero_index

/-- The log-degree is additive. -/
theorem logDegree_add (D₁ D₂ : WeilDivisor) :
    logDegree (D₁ + D₂) = logDegree D₁ + logDegree D₂ := by
  unfold logDegree
  simp [Finsupp.sum_add_index, add_mul]

/-- The log-degree of n·(q) is n·log(q). -/
theorem logDegree_ofSingle (q : PrimeSpec) (n : ℤ) :
    logDegree (ofSingle q n) = (n : ℝ) * Real.log q.val := by
  simp [logDegree, Finsupp.sum_single_index]

/-- The log-degree of div(q) = log(q). -/
theorem logDegree_ofPrime (q : PrimeSpec) :
    logDegree (ofPrime q) = Real.log q.val := by
  simp [ofPrime, logDegree_ofSingle]

-- ════════════════════════════════════════════════════════════════
-- §5. THE FINITE INTERSECTION PAIRING
-- ════════════════════════════════════════════════════════════════

/-- The finite intersection pairing between two Weil divisors:
    ⟨D₁, D₂⟩_fin = Σ_p D₁(p) · D₂(p) · log(p).

    This is the non-archimedean part of the Arakelov pairing. -/
def finiteIntersection (D₁ D₂ : WeilDivisor) : ℝ :=
  (D₁.support ∪ D₂.support).sum fun q =>
    (D₁ q : ℝ) * (D₂ q : ℝ) * Real.log q.val

/-- The finite intersection pairing is symmetric. -/
theorem finiteIntersection_comm (D₁ D₂ : WeilDivisor) :
    finiteIntersection D₁ D₂ = finiteIntersection D₂ D₁ := by
  simp only [finiteIntersection, Finset.union_comm]
  congr 1; ext q; ring

/-- The finite intersection of a divisor with itself is nonneg
    when the divisor is effective. -/
theorem finiteIntersection_self_nonneg (D : WeilDivisor) (_hD : IsEffective D) :
    0 ≤ finiteIntersection D D := by
  apply Finset.sum_nonneg
  intro q _
  apply mul_nonneg
  · exact mul_self_nonneg (D q : ℝ)
  · exact Real.log_nonneg (by exact_mod_cast q.2.one_le)

-- ════════════════════════════════════════════════════════════════
-- §6. THE GCD CONNECTION
-- ════════════════════════════════════════════════════════════════

/-- The factorization of gcd equals the inf of factorizations.
    This is the bridge between GCD structure and divisor theory. -/
theorem gcd_factorization_eq_inf (j k : ℕ) (hj : j ≠ 0) (hk : k ≠ 0) :
    (Nat.gcd j k).factorization = j.factorization ⊓ k.factorization :=
  Nat.factorization_gcd hj hk

/-- Pointwise: the p-adic valuation of gcd(j,k) = min of valuations. -/
theorem gcd_factorization_min (j k : ℕ) (hj : j ≠ 0) (hk : k ≠ 0) (p : ℕ) :
    (Nat.gcd j k).factorization p = min (j.factorization p) (k.factorization p) := by
  have h := Nat.factorization_gcd hj hk
  exact congr_fun (congr_arg DFunLike.coe h) p

/-- For PNat values, gcd is always positive. -/
theorem pnat_gcd_pos (j k : ℕ+) : 0 < Nat.gcd j.val k.val :=
  Nat.gcd_pos_of_pos_left k.val j.pos

/-- The GCD factorization for PNat inputs (Finsupp equality). -/
theorem pnat_gcd_factorization_eq (j k : ℕ+) :
    (Nat.gcd j.val k.val).factorization = j.val.factorization ⊓ k.val.factorization :=
  Nat.factorization_gcd j.ne_zero k.ne_zero

end WeilDivisor

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit

### Sorry: 0 ✅
### Custom Axioms: 0 ✅

### Definitions (6):

| # | Definition | What it is |
|---|-----------|-----------|
| 1 | `PrimeSpec` | Points of Spec(ℤ) = prime numbers |
| 2 | `WeilDivisor` | Formal ℤ-combination of primes (PrimeSpec →₀ ℤ) |
| 3 | `ofSingle` | n copies of (p) |
| 4 | `ofPrime` | div(p) = 1·(p) |
| 5 | `logDegree` | Σ D(p)·log(p) |
| 6 | `finiteIntersection` | Σ D₁(p)·D₂(p)·log(p) |

### Theorems (11):

| # | Result | Status |
|---|--------|--------|
| 1 | `zero_isEffective` | **🎓** |
| 2 | `ofPrime_isEffective` | **🎓** |
| 3 | `ofPrime_support` | **🎓** |
| 4 | `logDegree_zero` | **🎓** |
| 5 | `logDegree_add` | **🎓** |
| 6 | `logDegree_ofSingle` | **🎓** |
| 7 | `logDegree_ofPrime` | **🎓** |
| 8 | `finiteIntersection_comm` | **🎓** |
| 9 | `finiteIntersection_self_nonneg` | **🎓** |
| 10 | `gcd_factorization_min` | **🎓** (bridge to GCD) |
| 11 | `pnat_gcd_factorization` | **🎓** (PNat version) |

### Architecture

```
PrimeSpec = Nat.Primes     ← points of Spec(ℤ)
     ↓
WeilDivisor = PrimeSpec →₀ ℤ   ← free abelian group on primes
     │
     ├── ofSingle / ofPrime  ← generators
     ├── logDegree           ← Σ D(p)·log(p) = non-archimedean height
     ├── finiteIntersection  ← Σ D₁(p)·D₂(p)·log(p)
     └── gcd_factorization   ← bridge to Cathedral Gram matrix
```
-/

end Cathedral.Arakelov

end
