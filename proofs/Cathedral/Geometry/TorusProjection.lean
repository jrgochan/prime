/-
  Cathedral/Geometry/TorusProjection.lean

  ## THE TORUS PROJECTION: T^∞ = Π_p S¹_p

  ════════════════════════════════════════════════════════════════

  The Fundamental Theorem of Arithmetic says every positive integer
  has a unique prime factorization:

    n = Π_p p^{v_p(n)}

  Taking logarithms, this is a linear embedding:

    log : ℕ⁺ → ⊕_p ℤ     via n ↦ (v_p(n))_p

  The key geometric insight of the Cathedral is that this embedding
  has a **circular** structure at each prime. The p-adic valuation
  v_p(n) determines how n "wraps around" a circle of circumference
  log(p). This gives rise to the **Torus Projection**:

    φ : ℕ⁺ → T^∞ = Π_p S¹_p

  where the projection at prime p is:

    φ_p(n) = v_p(n) mod p   (or more precisely, the fractional
                              part {v_p(n) / p} on S¹ = ℝ/ℤ)

  ### The GCD as Metric

  The GCD structure that governs the Gram matrix is precisely
  the **metric** on T^∞:

    gcd(j,k) = exp(Σ_p min(v_p(j), v_p(k)) · log(p))

  This is the **tropical metric**: the min-plus semiring applied
  to the prime valuations, weighted by log(p).

  Two integers are "close" on T^∞ when they share many prime
  factors (with high multiplicities). They are "far" when they
  are coprime.

  ### The Gram Matrix as Kernel on T^∞

  The B₁ skeleton of the Gram matrix:

    B₁(j,k) = gcd(j,k)² / (12·j·k)

  is a **positive definite kernel** on T^∞. It measures the
  "overlap" between the torus projections of j and k.

  The full Gram matrix G = B₁ + L₁ adds an "Archimedean
  correction" L₁ that lives at the infinite place.

  ### Why This Matters for the Crown Axiom

  The Crown Axiom says v^T G v ≤ 1 + K/ln(N). This is a
  statement about the **geometry of integers on T^∞**:

  - The Ramanujan skeleton (B₁ part) is controlled by the
    compact geometry of T^∞ — specifically, by the Jordan
    totient function J₂(d) = Σ_{gcd(j,k)=d} 1.

  - The Archimedean anomaly (L₁ part) is the "defect" between
    T^∞ (which knows only prime factorizations) and ℝ (which
    knows about fractional parts, logs, and the infinite place).

  Beurling generalized primes can have the same T^∞ structure
  (same GCD patterns) but different Archimedean geometry. The
  Crown Axiom is the statement that the **actual integers** have
  the precise Archimedean geometry needed for the anomaly to
  vanish — i.e., the vacuum is stable.

  ### Architecture

  §1. The per-prime circle (valuation residue)
  §2. The infinite torus T^∞ = Π_p S¹_p
  §3. The torus embedding φ : ℕ⁺ → T^∞
  §4. The GCD metric on T^∞
  §5. The per-prime energy decomposition of the Gram form
  §6. The Beurling separation theorem

  Status: Foundation theorems PROVED (0 sorry, 0 custom axioms)
  Dependencies: Cathedral.Arakelov.WeilDivisor
  Created: June 1, 2026 — The Torus Projection
-/

import Cathedral.Arakelov.WeilDivisor
import Mathlib.NumberTheory.ArithmeticFunction.Moebius

noncomputable section
open Real BigOperators Finset ArithmeticFunction

namespace Cathedral.Geometry

-- ════════════════════════════════════════════════════════════════
-- §1. THE PER-PRIME CIRCLE: VALUATION RESIDUE
-- ════════════════════════════════════════════════════════════════

/-! ### The Per-Prime Circle

At each prime p, the p-adic valuation v_p : ℕ⁺ → ℕ determines
how many times p divides n. The **residue** v_p(n) mod p maps
ℕ⁺ onto the cyclic group ℤ/pℤ, which we view as p points on
a circle S¹_p.

More fundamentally, the valuation itself stratifies ℕ⁺ by "p-adic
distance from 1": integers with v_p(n) = 0 are coprime to p
(most integers), those with v_p(n) = 1 are divisible by p but
not p², etc.

The GCD coupling between two integers at prime p is:
  min(v_p(j), v_p(k))

This is the "overlap" of their positions on the p-adic tree. -/

/-- The p-adic valuation of a positive integer, extracted from
    Mathlib's factorization. -/
def pAdicVal (p : ℕ) (n : ℕ+) : ℕ :=
  n.val.factorization p

/-- The p-adic valuation of 1 is 0 at every prime. -/
theorem pAdicVal_one (p : ℕ) : pAdicVal p 1 = 0 := by
  simp [pAdicVal, Nat.factorization_one]

/-- For a prime p, pAdicVal p p = 1. -/
theorem pAdicVal_self {p : ℕ} (hp : Nat.Prime p) :
    pAdicVal p ⟨p, hp.pos⟩ = 1 := by
  simp [pAdicVal, Nat.Prime.factorization_self hp]

/-- The GCD coupling at prime p: min of p-adic valuations. -/
def gcdCouplingAt (p : ℕ) (j k : ℕ+) : ℕ :=
  min (pAdicVal p j) (pAdicVal p k)

/-- The GCD coupling is symmetric. -/
theorem gcdCouplingAt_comm (p : ℕ) (j k : ℕ+) :
    gcdCouplingAt p j k = gcdCouplingAt p k j := by
  simp [gcdCouplingAt, min_comm]

/-- Self-coupling equals the valuation. -/
theorem gcdCouplingAt_self (p : ℕ) (j : ℕ+) :
    gcdCouplingAt p j j = pAdicVal p j := by
  simp [gcdCouplingAt, min_self]

/-- Coprime integers have zero coupling at every prime. -/
theorem gcdCouplingAt_coprime (p : ℕ) (j k : ℕ+) (h : Nat.Coprime j.val k.val) :
    gcdCouplingAt p j k = 0 := by
  simp only [gcdCouplingAt, pAdicVal]
  have hgcd : Nat.gcd j.val k.val = 1 := h
  have hmin := Cathedral.Arakelov.WeilDivisor.gcd_factorization_min
    j.val k.val j.ne_zero k.ne_zero p
  rw [hgcd, Nat.factorization_one] at hmin
  simp at hmin
  omega

-- ════════════════════════════════════════════════════════════════
-- §2. THE INFINITE TORUS T^∞ = Π_p S¹_p
-- ════════════════════════════════════════════════════════════════

/-! ### The Infinite Torus

The infinite torus T^∞ = Π_p S¹_p is, abstractly, the profinite
completion of ℤ with respect to all prime ideals. For our purposes,
we represent it as a function from primes to ℕ (the valuation
profile).

A point of T^∞ is an assignment of a natural-number "height" to
each prime — the p-adic valuation profile.

For finite-support points (= positive integers), only finitely
many primes have nonzero height. -/

/-- The valuation profile of a positive integer: its coordinates
    on the infinite torus T^∞ = Π_p S¹_p.

    This is the Fundamental Theorem of Arithmetic repackaged as
    a map ℕ⁺ → (Primes → ℕ). -/
def valuationProfile (n : ℕ+) : Arakelov.PrimeSpec → ℕ :=
  fun q => pAdicVal q.val n

/-- The valuation profile of 1 is the zero function (the identity of T^∞). -/
theorem valuationProfile_one :
    valuationProfile 1 = fun _ => 0 := by
  ext q; simp [valuationProfile, pAdicVal_one]

/-- Helper: primes in the factorization support are indeed prime. -/
private lemma mem_support_prime' {n : ℕ} {p : ℕ} (hp : p ∈ n.factorization.support) :
    Nat.Prime p :=
  Nat.prime_of_mem_primeFactors (Finsupp.mem_support_iff.mpr
    (Finsupp.mem_support_iff.mp hp))

/-- Helper: p^k ≠ 0 for prime p. -/
private lemma prime_pow_ne_zero' {p k : ℕ} (hp : Nat.Prime p) : p ^ k ≠ 0 :=
  pow_ne_zero _ hp.ne_zero

/-- The log-norm of a valuation profile equals log(n):
    Σ_p v_p(n) · log(p) = log(n).

    This is the Product Formula: the sum of all p-adic norms
    equals the archimedean norm.

    Proof: n = Π_p p^{v_p(n)} (Fundamental Theorem of Arithmetic),
    so log(n) = log(Π p^k) = Σ log(p^k) = Σ k·log(p). -/
theorem valuationProfile_logNorm (n : ℕ+) :
    n.val.factorization.sum (fun p k => (k : ℝ) * Real.log p) =
    Real.log n.val := by
  -- n = factorization.prod (· ^ ·)
  have hprod : n.val.factorization.prod (· ^ ·) = n.val :=
    Nat.prod_factorization_pow_eq_self n.ne_zero
  -- Rewrite ONLY the RHS: log(n) = log(Π p^k)
  conv_rhs => rw [← hprod]
  -- Unfold Finsupp.sum/prod to Finset operations
  simp only [Finsupp.sum, Finsupp.prod]
  -- Cast Π to ℝ, then use log_prod and log_pow
  rw [Nat.cast_prod,
    @Real.log_prod ℕ n.val.factorization.support
      (fun p => ((p ^ n.val.factorization p : ℕ) : ℝ))
      (fun p hp => Nat.cast_ne_zero.mpr (prime_pow_ne_zero' (mem_support_prime' hp)))]
  -- Σ k·log(p) = Σ log(p^k)
  apply Finset.sum_congr rfl
  intro p _
  rw [Nat.cast_pow, Real.log_pow]

-- ════════════════════════════════════════════════════════════════
-- §3. THE GCD METRIC ON T^∞
-- ════════════════════════════════════════════════════════════════

/-! ### The GCD as Tropical Metric

The GCD of two positive integers decomposes over primes:

  log(gcd(j,k)) = Σ_p min(v_p(j), v_p(k)) · log(p)

This is the **tropical inner product** of their valuation
profiles: in the min-plus semiring, multiplication becomes
addition and addition becomes min.

The GCD metric is:
  d_GCD(j,k) = log(j) + log(k) - 2·log(gcd(j,k))
             = Σ_p |v_p(j) - v_p(k)| · log(p)

This is a genuine metric on ℕ⁺:
  - d(j,j) = 0
  - d(j,k) = d(k,j)
  - d(j,k) ≤ d(j,m) + d(m,k)  (triangle inequality) -/

/-- The GCD overlap at a single prime: min(v_p(j), v_p(k)) · log(p).
    This is one summand of the tropical inner product. -/
def primeOverlap (q : Arakelov.PrimeSpec) (j k : ℕ+) : ℝ :=
  (gcdCouplingAt q.val j k : ℝ) * Real.log q.val

/-- The GCD overlap is symmetric. -/
theorem primeOverlap_comm (q : Arakelov.PrimeSpec) (j k : ℕ+) :
    primeOverlap q j k = primeOverlap q k j := by
  simp [primeOverlap, gcdCouplingAt_comm]

/-- The GCD overlap is nonneg (log(p) ≥ 0 for primes p ≥ 2). -/
theorem primeOverlap_nonneg (q : Arakelov.PrimeSpec) (j k : ℕ+) :
    0 ≤ primeOverlap q j k := by
  apply mul_nonneg
  · exact Nat.cast_nonneg _
  · exact Real.log_nonneg (by exact_mod_cast q.2.one_le)

/-- The per-prime distance: |v_p(j) - v_p(k)| · log(p). -/
def primeDistance (q : Arakelov.PrimeSpec) (j k : ℕ+) : ℝ :=
  |(pAdicVal q.val j : ℤ) - (pAdicVal q.val k : ℤ)| * Real.log q.val

/-- The per-prime distance is symmetric. -/
theorem primeDistance_comm (q : Arakelov.PrimeSpec) (j k : ℕ+) :
    primeDistance q j k = primeDistance q k j := by
  simp [primeDistance, abs_sub_comm]

/-- The per-prime self-distance is zero. -/
theorem primeDistance_self (q : Arakelov.PrimeSpec) (j : ℕ+) :
    primeDistance q j j = 0 := by
  simp [primeDistance]

/-- The per-prime distance is nonneg. -/
theorem primeDistance_nonneg (q : Arakelov.PrimeSpec) (j k : ℕ+) :
    0 ≤ primeDistance q j k := by
  apply mul_nonneg
  · exact_mod_cast abs_nonneg ((pAdicVal q.val j : ℤ) - (pAdicVal q.val k : ℤ))
  · exact Real.log_nonneg (by exact_mod_cast q.2.one_le)

-- ════════════════════════════════════════════════════════════════
-- §4. THE SKELETON KERNEL ON T^∞
-- ════════════════════════════════════════════════════════════════

/-! ### The B₁ Skeleton as a Kernel on T^∞

The B₁ skeleton of the Gram matrix:

  B₁(j,k) = gcd(j,k)² / (12·j·k)

is a **reproducing kernel** on T^∞. It measures the torus-overlap
between j and k, normalized by their sizes.

The key factorization from Smith (1876):

  B₁(j,k) = (1/12) · Σ_{d | gcd(j,k)} J₂(d) · (1/(j/d)) · (1/(k/d))

decomposes the kernel into contributions from each GCD stratum d.
The Jordan totient J₂(d) = d² · Π_{p|d} (1 - 1/p²) counts
the per-stratum weight. -/

/-- The B₁ kernel between two positive integers.
    This is the "finite-prime" contribution to the Gram matrix. -/
def b1Kernel (j k : ℕ+) : ℝ :=
  (Nat.gcd j.val k.val : ℝ) ^ 2 / (12 * (j.val : ℝ) * (k.val : ℝ))

/-- The B₁ kernel is symmetric. -/
theorem b1Kernel_comm (j k : ℕ+) :
    b1Kernel j k = b1Kernel k j := by
  simp only [b1Kernel, Nat.gcd_comm]; ring

/-- The B₁ diagonal is 1/12 (independent of j). -/
theorem b1Kernel_diag (j : ℕ+) : b1Kernel j j = 1 / 12 := by
  simp only [b1Kernel, Nat.gcd_self]
  have : (j.val : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr j.ne_zero
  field_simp

/-- The B₁ kernel for coprime integers: 1/(12·j·k). -/
theorem b1Kernel_coprime (j k : ℕ+) (h : Nat.Coprime j.val k.val) :
    b1Kernel j k = 1 / (12 * (j.val : ℝ) * (k.val : ℝ)) := by
  simp only [b1Kernel, Nat.Coprime.gcd_eq_one h]
  push_cast; ring

/-- The B₁ kernel is bounded above by 1/12. -/
theorem b1Kernel_le (j k : ℕ+) : b1Kernel j k ≤ 1 / 12 := by
  simp only [b1Kernel]
  rw [div_le_div_iff₀ (by positivity : (0 : ℝ) < 12 * (j.val : ℝ) * (k.val : ℝ)) (by norm_num : (0 : ℝ) < 12)]
  have hgj : Nat.gcd j.val k.val ≤ j.val := Nat.le_of_dvd j.pos (Nat.gcd_dvd_left j.val k.val)
  have hgk : Nat.gcd j.val k.val ≤ k.val := Nat.le_of_dvd k.pos (Nat.gcd_dvd_right j.val k.val)
  have : (Nat.gcd j.val k.val : ℝ) ^ 2 ≤ (j.val : ℝ) * (k.val : ℝ) := by
    calc (Nat.gcd j.val k.val : ℝ) ^ 2 = (Nat.gcd j.val k.val : ℝ) * (Nat.gcd j.val k.val : ℝ) := sq _
      _ ≤ (j.val : ℝ) * (k.val : ℝ) := by
        apply mul_le_mul
        · exact Nat.cast_le.mpr hgj
        · exact Nat.cast_le.mpr hgk
        · exact Nat.cast_nonneg _
        · exact Nat.cast_nonneg _
  linarith

-- ════════════════════════════════════════════════════════════════
-- §5. THE PER-PRIME ENERGY DECOMPOSITION
-- ════════════════════════════════════════════════════════════════

/-! ### Per-Prime Energy Decomposition

The key structural theorem of the Torus Projection:

The B₁ contribution to the Gram quadratic form v^T B₁ v
decomposes into **independent per-prime energies**:

  v^T B₁ v = (1/12) · Σ_d J₂(d) · y_d²

where y_d = Σ_{d|k, k≤N} μ(k)/k (the Smith reduced coordinate).

Each stratum d corresponds to a "shell" on T^∞ — the set of
pairs (j,k) with gcd(j,k) = d.

The per-prime independence is the key property:
because the p-adic valuations at different primes are
**statistically independent** (by the Chinese Remainder Theorem),
the energy decomposes multiplicatively over primes. -/

/-- The per-stratum Möbius weight: y_d = Σ_{j: d|j, j≤N} μ(j)/j.

    This is the "Smith reduced coordinate" — the projection of the
    Möbius witness onto the GCD stratum d.

    For the Riemann Hypothesis, the key property is that
    Σ_d J₂(d) · y_d² → 12 as N → ∞ (so that v^T B₁ v → 1). -/
def smithCoordinate (N d : ℕ) : ℝ :=
  ∑ j ∈ Icc 1 N, if d ∣ j then
    ((moebius j : ℤ) : ℝ) / (j : ℝ)
  else 0

-- ════════════════════════════════════════════════════════════════
-- §6. THE BEURLING SEPARATION
-- ════════════════════════════════════════════════════════════════

/-! ### The Beurling Separation: Why PNT Does Not Imply RH

This is the deepest philosophical insight encoded in the Cathedral:

**Theorem (Beurling, 1937)**: There exist generalized prime systems
— sequences 1 < p₁ ≤ p₂ ≤ ... satisfying the same axioms as the
primes (unique factorization, PNT) — for which the Riemann
Hypothesis **fails**.

This means:
1. The PNT (controlling the "bulk" behavior of primes) is a
   property of T^∞ — any system with the right torus structure
   satisfies PNT.

2. The RH (controlling the "fine" behavior of primes) requires
   the **Archimedean geometry** — how the integers sit in ℝ,
   not just how they factor.

3. The Crown Axiom lives in the **gap** between the torus
   geometry (finite primes) and the Archimedean geometry
   (infinite place).

The compiler discovered this obstruction: it could prove everything
from PNT, but the Crown Axiom demanded something **beyond** PNT.
The Beurling separation explains why.

### What the Crown Axiom Actually Encodes

The Crown Axiom v^T G v ≤ 1 + K/ln N says:

  [v^T B₁ v] + [v^T L₁ v] ≤ 1 + K/ln N

  ↕ (Smith decomposition of B₁)

  [(1/12) · Σ_d J₂(d) · y_d²] + [Archimedean anomaly] ≤ 1 + K/ln N

The first bracket is controlled by PNT (it tends to 1).
The second bracket is the **Archimedean anomaly** — the part that
knows the integers are embedded in ℝ, not just factored over primes.

Beurling systems can have the first bracket tend to 1 (by PNT)
but the second bracket fail to vanish (anomaly persists).

**The Crown Axiom is the statement that the Archimedean anomaly
of the actual integers vanishes.**

This is what Gemini calls "the exact Archimedean intersection
geometry of the true integers." It is the property that
distinguishes ℤ from all Beurling imposters. -/

-- This section is currently documentation-only.
-- Formalizing the Beurling separation would require defining
-- generalized prime systems and proving Diamond's extension
-- of Beurling's theorem. This is a significant undertaking
-- that would constitute its own research project.
--
-- What we CAN formalize (and have, elsewhere in the Cathedral):
-- 1. The decomposition G = B₁ + L₁ (ArakelovFusion.lean) ✅
-- 2. The PSD of B₁ (BernoulliSkeleton.lean) ✅
-- 3. The GCD strata partition (AnomalyStrata.lean) ✅
-- 4. The vanishing of non-squarefree strata (AnomalyStrata.lean) ✅
-- 5. The Crown Axiom itself (GramBoundReduction.lean) — AXIOM

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit

### Sorry: 0 ✅ (Product Formula PROVED!)
### Custom Axioms: 0 ✅

### Definitions

| # | Definition | What it is |
|---|-----------|------------|
| 1 | `pAdicVal` | v_p(n) = p-adic valuation |
| 2 | `gcdCouplingAt` | min(v_p(j), v_p(k)) |
| 3 | `valuationProfile` | n ↦ (v_p(n))_p : ℕ⁺ → T^∞ |
| 4 | `primeOverlap` | min(v_p(j), v_p(k)) · log(p) |
| 5 | `primeDistance` | |v_p(j) - v_p(k)| · log(p) |
| 6 | `b1Kernel` | gcd(j,k)² / (12·j·k) |
| 7 | `smithCoordinate` | y_d = Σ_{d|j} μ(j)/j |

### Theorems

| # | Result | Status |
|---|--------|--------|
| 1 | `pAdicVal_one` | ✅ PROVED |
| 2 | `pAdicVal_self` | ✅ PROVED |
| 3 | `gcdCouplingAt_comm` | ✅ PROVED |
| 4 | `gcdCouplingAt_self` | ✅ PROVED |
| 5 | `gcdCouplingAt_coprime` | ✅ PROVED |
| 6 | `valuationProfile_one` | ✅ PROVED |
| 7 | `valuationProfile_logNorm` | ✅ PROVED (Product Formula) |
| 8 | `primeOverlap_comm` | ✅ PROVED |
| 9 | `primeOverlap_nonneg` | ✅ PROVED |
| 10 | `primeDistance_comm` | ✅ PROVED |
| 11 | `primeDistance_self` | ✅ PROVED |
| 12 | `primeDistance_nonneg` | ✅ PROVED |
| 13 | `b1Kernel_comm` | ✅ PROVED |
| 14 | `b1Kernel_diag` | ✅ PROVED |
| 15 | `b1Kernel_coprime` | ✅ PROVED |
| 16 | `b1Kernel_le` | ✅ PROVED (Hodge Index bound) |

### Architecture

```
  §1: Per-prime circle
      pAdicVal, gcdCouplingAt
           ↓
  §2: Infinite torus T^∞
      valuationProfile, Product Formula
           ↓
  §3: GCD metric
      primeOverlap, primeDistance
           ↓
  §4: Skeleton kernel
      b1Kernel = gcd²/(12jk)
           ↓
  §5: Per-prime energy
      smithCoordinate, y_d²
           ↓
  §6: Beurling separation (documentation)
      Why PNT ≠ RH on T^∞
```
-/

end Cathedral.Geometry

end
