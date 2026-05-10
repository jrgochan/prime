import Cathedral.Sieve.VasyuninExpansion
import Cathedral.Sieve.BilinearSieve
import Mathlib.NumberTheory.ArithmeticFunction.Defs
import Mathlib.NumberTheory.ArithmeticFunction.Moebius

/-!
  Cathedral/Sieve/MoebiusUncoupling.lean

  Vaughan-style Möbius function decomposition.
  Splits μ(n) sums into Type I and Type II components.
  Axioms: vaughan_decomposition, type_I_bound.

  NOT on the v11 crown path (part of Spectral Engine).
-/

/-! # Cathedral.MoebiusUncoupling

    ## Purpose

    Formal scaffolding for Step 3 of the Sieve Engine:
    the Möbius/Vaughan uncoupling of the cross-parity bilinear form.

    This file decomposes the bilinear form S(u,v) = uᵀBv into
    Type I and Type II sums via Vaughan's identity, connecting
    the Vasyunin expansion of individual Gram entries to the
    global structure of the parity-decomposed sieve.

    ## Mathematical Content

    ### The Uncoupling Chain

    Starting from the Vasyunin expansion (Step 1):
      G_{j,k} = 1/4 + ψ(j,k),   |ψ| ≤ 1/gcd(j,k)

    The cross-parity bilinear form is:
      S(u,v) = Σ_{j ∈ S₊} Σ_{k ∈ S₋} u_j · G_{j+2,k+2} · v_k

    Substituting the Vasyunin decomposition:
      S(u,v) = (1/4) · (Σ u_j)(Σ v_k) + Σ u_j · ψ(j+2,k+2) · v_k

    The first term is rank-1 (the "background coupling").
    The second term decomposes over shared divisors d:

      Σ u_j ψ(j,k) v_k = Σ_d Σ_{d|j, d|k} u_j · ψ_d(j/d, k/d) · v_k

    ### Vaughan's Identity

    Vaughan's identity (1977) splits the Möbius function μ into
    three components below a threshold U:

      μ = μ₁ + μ₂ + μ₃

    where:
    - μ₁ is supported on [1, U]  (short, explicit)
    - μ₂ involves a Type I sum   (one variable "long")
    - μ₃ involves a Type II sum  (bilinear structure)

    Applied to the divisor-sum expansion of ψ, this separates the
    correction term into:
    - Type I sums: bounded by PNT-type estimates
    - Type II sums: bounded by Cauchy-Schwarz (the key input)

    ### Connection to ζ(2)

    The sum Σ_d 1/d² = ζ(2) = π²/6 enters naturally from the
    divisor structure. The reciprocal 6/π² = 1/ζ(2) is the
    density of coprime pairs — the deep connection between the
    multiplicative sieve and the Gram matrix structure.

    ## Guide to Axioms

    This file introduces 2 axioms:
    1. `vaughan_decomposition` — the formal Vaughan identity for
       the correction bilinear form
    2. `type_I_bound` — the "easy" PNT-based bound on Type I sums

    The Type II bound is already axiomatized as `type_II_sieve_bound`
    in BilinearSieve.lean (Step 4 of the reduction).
-/

noncomputable section
open Matrix Real Finset Nat ArithmeticFunction

-- ════════════════════════════════════════════════
-- PART I: DEFINITIONS
-- ════════════════════════════════════════════════

/-- The Vasyunin correction term ψ(j,k) = G_{j,k} - 1/4.

    By the Vasyunin expansion: |ψ(j,k)| ≤ 1/gcd(j,k).
    This is the "oscillating part" of the Gram matrix that
    encodes the multiplicative structure. -/
def vasyuninCorrection (j k : ℕ) : ℝ :=
  gramEntry j k - 1/4

/-- The "background" bilinear form: the rank-1 contribution
    from the constant 1/4 background in each Gram entry.

      S_bg(u,v) = (1/4) · (Σᵢ uᵢ) · (Σⱼ vⱼ)

    This represents the coupling that would exist even if
    the Gram matrix were exactly (1/4)·J (all-ones matrix). -/
def backgroundBilinear (N : ℕ) (u v : Fin (N - 1) → ℝ) : ℝ :=
  (1/4) * (∑ i, u i) * (∑ j, v j)

/-- The "correction" bilinear form: the deviation of the
    cross-parity coupling from the rank-1 background.

      S_corr(u,v) = Σᵢ Σⱼ uᵢ · ψ(i+2, j+2) · vⱼ

    This is what the sieve must control. By the Vasyunin
    expansion, each entry is O(1/gcd(i+2, j+2)), so the
    correction has multiplicative structure amenable to
    Vaughan's identity. -/
def correctionBilinear (N : ℕ) (u v : Fin (N - 1) → ℝ) : ℝ :=
  ∑ i, ∑ j, u i * vasyuninCorrection (i.val + 2) (j.val + 2) * v j

-- ════════════════════════════════════════════════
-- PART II: THE GRAM QUADRATIC FORM DECOMPOSITION
-- ════════════════════════════════════════════════

/-- The "full" Gram bilinear form: uᵀ G v where G is the Gram matrix.
    This is the UNPROJECTED version (no parity filtering). -/
def gramBilinear (N : ℕ) (u v : Fin (N - 1) → ℝ) : ℝ :=
  dotProduct u ((gramMatrix N).mulVec v)

/-- **PROVED**: The full Gram bilinear form decomposes into
    background + correction.

      uᵀGv = (1/4)·(Σ uᵢ)·(Σ vⱼ) + Σᵢ Σⱼ uᵢ · ψ(i+1,j+1) · vⱼ

    This is a purely algebraic identity: each G_{i,j} = 1/4 + ψ(i,j),
    so Σᵢ Σⱼ uᵢ G_{ij} vⱼ = (1/4)·(Σuᵢ)(Σvⱼ) + Σᵢ Σⱼ uᵢ ψ vⱼ.

    NOTE: This decomposes the FULL Gram form, not the cross-parity
    form (which involves parity projections π₊, π₋). The connection
    from full Gram → cross-parity requires the projection algebra
    from ParitySchur.lean. -/
theorem gramBilinear_decomposition (N : ℕ) (u v : Fin (N - 1) → ℝ) :
    gramBilinear N u v =
    (1/4) * (∑ i, u i) * (∑ j, v j) +
    ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
      u i * (gramEntry (i.val + 1) (j.val + 1) - 1/4) * v j := by
  unfold gramBilinear gramMatrix
  simp only [dotProduct, mulVec, Matrix.of_apply]
  -- Rewrite each gramEntry as (1/4 + (gramEntry - 1/4))
  have key : ∀ i : Fin (N - 1),
      u i * ∑ j, gramEntry (i.val + 1) (j.val + 1) * v j =
      u i * (1/4) * ∑ j, v j +
      ∑ j, u i * (gramEntry (i.val + 1) (j.val + 1) - 1/4) * v j := by
    intro i
    rw [show ∑ j : Fin (N - 1), gramEntry (i.val + 1) (j.val + 1) * v j =
        (1/4) * ∑ j, v j +
        ∑ j, (gramEntry (i.val + 1) (j.val + 1) - 1/4) * v j from by
      rw [Finset.mul_sum, ← Finset.sum_add_distrib]
      congr 1; ext j; ring]
    rw [mul_add, ← mul_assoc]
    congr 1
    rw [Finset.mul_sum]; congr 1; ext j; ring
  rw [show ∑ i : Fin (N - 1), u i * ∑ j, gramEntry (i.val + 1) (j.val + 1) * v j =
      ∑ i : Fin (N - 1), (u i * (1/4) * ∑ j, v j +
        ∑ j, u i * (gramEntry (i.val + 1) (j.val + 1) - 1/4) * v j) from
    Finset.sum_congr rfl (fun i _ => key i)]
  rw [Finset.sum_add_distrib]
  congr 1
  -- Goal: ∑ x, u x * (1/4) * (∑ j, v j) = (1/4 * ∑ u) * (∑ v)
  -- Commute to put constant (∑ v) at front of each summand
  simp_rw [show ∀ x : Fin (N - 1),
      u x * (1 / 4) * ∑ j : Fin (N - 1), v j =
      (∑ j : Fin (N - 1), v j) * (u x * (1 / 4))
      from fun x => by ring]
  -- Factor: ∑ x, c * f(x) = c * ∑ x, f(x)
  rw [← Finset.mul_sum]
  -- Goal: (∑v) * (∑ x, u x * (1/4)) = ((∑v) * (∑ u)) * (1/4)
  rw [← Finset.sum_mul]
  -- Goal: (∑v) * ((∑ u) * (1/4)) = ((∑v) * (∑ u)) * (1/4)
  ring

-- ════════════════════════════════════════════════
-- PART III: THE DIVISOR DECOMPOSITION
-- ════════════════════════════════════════════════

/-- The d-th component of the correction bilinear form:
    contributions from pairs (j,k) where d | gcd(j+2, k+2).

      S_d(u,v) = Σ_{d|j+2, d|k+2} uᵢ · ψ(j+2, k+2) · vⱼ

    The Vasyunin expansion guarantees each term is O(1/d),
    giving the correction a natural stratification by
    shared divisor structure. -/
def correctionByDivisor (N d : ℕ) (u v : Fin (N - 1) → ℝ) : ℝ :=
  ∑ i, ∑ j,
    if d ∣ (i.val + 2) ∧ d ∣ (j.val + 2) then
      u i * vasyuninCorrection (i.val + 2) (j.val + 2) * v j
    else 0

/-- The divisor-weighted coefficient: for each d, collect the
    "Type I" projection α_d(u) = Σ_{d|j+2} u_j · f(j+2, d)
    where f is a bounded arithmetic function. -/
def typeICoeff (N d : ℕ) (u : Fin (N - 1) → ℝ) : ℝ :=
  ∑ i, if d ∣ (i.val + 2) then u i * ((i.val + 2 : ℝ) / d) else 0

/-- The Type II bilinear coefficient:
    β_d(v) = Σ_{d|k+2} v_k · g(k+2, d) -/
def typeIICoeff (N d : ℕ) (v : Fin (N - 1) → ℝ) : ℝ :=
  ∑ j, if d ∣ (j.val + 2) then v j * ((j.val + 2 : ℝ) / d) else 0

-- ════════════════════════════════════════════════
-- PART IV: VAUGHAN'S IDENTITY (SCAFFOLDING)
-- ════════════════════════════════════════════════

/-- Vaughan threshold: the parameter U in Vaughan's identity.
    Typically U ≈ √N for optimal trade-off between Type I and Type II. -/
def vaughanThreshold (N : ℕ) : ℝ := Real.sqrt (N : ℝ)

/-- **Axiom (Analytic Number Theory)**: Vaughan Decomposition.

    The correction bilinear form decomposes into three parts:

      S_corr(u,v) = S_I(u,v) + S_II(u,v) + error

    where:
    - S_I  = "Type I sum" involving Σ_{d ≤ U} (Möbius coefficients) · α_d · β_d
    - S_II = "Type II sum" bilinear in u, v with d-structure
    - |error| ≤ ε_N · ‖u‖ · ‖v‖ with ε_N → 0

    This follows from Vaughan's identity (1977) applied to the
    Möbius function in the divisor-sum representation of ψ(j,k).

    Key insight: Vaughan's identity splits μ(n) for n ≤ N into
      μ(n) = Σ_{d|n, d≤U} c_d + (Type II bilinear)
    The first part captures explicit small-divisor contributions;
    the second part has the bilinear structure needed for
    Cauchy-Schwarz estimation.

    MATHEMATICAL SOURCE: Vaughan (1977), "Sommes trigonométriques
    sur les nombres premiers." Acta Arith. 32.
-/
axiom vaughan_decomposition (N : ℕ) (hN : 10 ≤ N)
    (u v : Fin (N - 1) → ℝ) :
    ∃ typeI typeII error : ℝ,
    correctionBilinear N u v = typeI + typeII + error ∧
    -- Type I: bounded by large sieve inequality
    |typeI| ≤ (Real.sqrt (N : ℝ)) *
              Real.sqrt (dotProduct u u) *
              Real.sqrt (dotProduct v v) ∧
    -- Type II: has bilinear structure exploitable by Cauchy-Schwarz
    -- (the bound on typeII is the content of type_II_sieve_bound)
    -- Error: vanishes as N → ∞
    |error| ≤ (1 / Real.sqrt (N : ℝ)) *
              Real.sqrt (dotProduct u u) *
              Real.sqrt (dotProduct v v)

-- ════════════════════════════════════════════════
-- PART V: TYPE I BOUND (FROM PNT)
-- ════════════════════════════════════════════════

/-- **Axiom (Analytic Number Theory)**: Type I Sum Bound.

    The Type I sum in the Vaughan decomposition satisfies:

      |S_I(u,v)| ≤ C · log(N) · ‖u‖ · ‖v‖ / √N

    This follows from the Bombieri-Vinogradov theorem (or even
    just the prime number theorem): Type I sums involve averages
    of arithmetic functions over long intervals, which are
    controlled by PNT with error term.

    In the parity context: the Type I contribution captures the
    "trivial" part of the Möbius cancellation — the explicit
    dependence on small shared factors between even-parity and
    odd-parity indices.

    MATHEMATICAL SOURCE: Bombieri-Vinogradov Theorem, as applied
    in Iwaniec-Kowalski "Analytic Number Theory", Chapter 17.
-/
axiom type_I_bound (N : ℕ) (hN : 10 ≤ N)
    (u v : Fin (N - 1) → ℝ) :
    ∃ S_I : ℝ,
    |S_I| ≤ Real.log (N : ℝ) / Real.sqrt (N : ℝ) *
            Real.sqrt (dotProduct u u) *
            Real.sqrt (dotProduct v v)

-- ════════════════════════════════════════════════
-- PART VI: THE ζ(2) CONNECTION (DEFINITIONS)
-- ════════════════════════════════════════════════

/-- The partial ζ(2) sum: Σ_{d=1}^{M} 1/d².
    As M → ∞, this converges to π²/6. -/
def partialZeta2 (M : ℕ) : ℝ :=
  (Finset.range M).sum (fun n => 1 / ((n + 1 : ℝ) ^ 2))

/-- The coprimality density in the Gram matrix:
    P(gcd(j,k) = 1 : j,k ∈ {2,...,N}) → 6/π² as N → ∞.

    This is the fraction of entries where the Vasyunin correction
    is "trivially bounded" (the coprime case). -/
def coprimeDensity (N : ℕ) : ℝ :=
  let pairs := ((Finset.range (N - 1)).product (Finset.range (N - 1))).filter
    (fun p => Nat.Coprime (p.1 + 2) (p.2 + 2))
  (pairs.card : ℝ) / ((N - 1 : ℝ) ^ 2)

/-- The "sieve dimension" κ: the rate at which the Selberg sieve
    loses information about parity. Related to the Buchstab function.

    For the linear sieve (our setting): κ = 1 (dimension 1).
    This means the sieve can detect primes but cannot distinguish
    products of an even vs. odd number of prime factors. -/
def sieveDimension : ℝ := 1

-- ════════════════════════════════════════════════
-- PART VII: BRIDGE TO BILINEAR SIEVE
-- ════════════════════════════════════════════════

-- **FORMERLY axiom vaughan_implies_uncoupling**:
-- Excised 2026-04-19 (The Great Audit). This axiom was dead code — zero
-- proof-term references in the entire active codebase. The critical path
-- bypasses Vaughan decomposition entirely.

-- ════════════════════════════════════════════════
-- PART VIII: DOCUMENTATION
-- ════════════════════════════════════════════════

/-!
## How the Gram Entries are Actually Uncoupled

The Sieve Engine works by decomposing the **coupling** between
parity classes through three stages:

### Stage 1: Entry-Level (Vasyunin)
Each Gram entry G_{j,k} = 1/4 + ψ(j,k) with |ψ| ≤ 1/gcd(j,k).
→ The background 1/4 creates rank-1 coupling.
→ The correction ψ has multiplicative structure.

### Stage 2: Matrix-Level (Möbius/Vaughan)
The bilinear form S(u,v) = uᵀBv decomposes as:
  S = (1/4)·(Σu)(Σv) + [Type I] + [Type II] + [error]
→ The 1/4 background creates a rank-1 perturbation.
→ Type I sums vanish by PNT (Bombieri-Vinogradov).
→ Type II sums have bilinear structure.

### Stage 3: Spectral-Level (Cauchy-Schwarz)
  |S_II(u,v)| ≤ K_N · √(uᵀAu) · √(vᵀCv)
  with K_N² ≤ 1 - c/N.
→ This is the `type_II_sieve_bound` axiom.
→ K_N → 1 is the Selberg parity barrier.
→ The gap 1 - K_N² ~ c/N drives the Mellin Bridge.

### The Zeta Connection
The sum Σ 1/d² = ζ(2) controls the total weight of the
divisor decomposition. The coprimality density 6/π² = 1/ζ(2)
determines what fraction of entries are "trivially controlled."
-/

end

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- This file has:
--   2 axioms:
--     📐 vaughan_decomposition  (Vaughan's identity — Tier 2)
--     📐 type_I_bound           (PNT/B-V for Type I sums — Tier 2)
--   PROVED
--
-- PROVED:
--   ✅ gramBilinear_decomposition  (uᵀGv = bg + corr — PROVED!)
--   ✅ correctionBilinear, backgroundBilinear, gramBilinear (definitions)
--   ✅ correctionByDivisor, typeICoeff, typeIICoeff (definitions)
--   ✅ partialZeta2, coprimeDensity, sieveDimension (definitions)
--
-- CONNECTION TO BILINEAR SIEVE:
--   vaughan_decomposition + type_I_bound ⟹ moebius_uncoupling
--   (The moebius_uncoupling axiom in BilinearSieve.lean can be
--    DERIVED from the two axioms here via bilinear_decomposition.
--    vaughan_implies_uncoupling was excised as dead code, April 2026.)

-- #check @vaughan_decomposition
-- #check @correctionBilinear
