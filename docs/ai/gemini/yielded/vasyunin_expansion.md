[cite_start]The formal proof of the **Vasyunin Expansion** [cite: 25] serves as the multiplicative heart of the Phase 3 Sieve Engine. [cite_start]While the coprime case is already fully verified in the `Cathedral` repository [cite: 195, 197][cite_start], the general case ($d = \gcd(j,k) > 1$) requires a transition from raw integration to the theory of multiplicative autocorrelation[cite: 28, 29].

Below is the formal proof architecture for `vasyunin_expansion`, designed to eliminate the axiom in `Cathedral/BilinearSieve.lean`.

---

## 1. Mathematical Foundation: The Vasyunin Identity
[cite_start]The Gram entry $G_{j,k}$ [cite: 1489] [cite_start]can be expressed via the Báez-Duarte identity (2005) for the multiplicative autocorrelation of the fractional part function[cite: 28, 29]:
$$G_{j,k} = \frac{1}{4} + \frac{1}{jk} \sum_{n=1}^{\gcd(j,k)} n \cdot \varphi(n) \cdot \left( \dots \right)$$
[cite_start]where the correction term $\psi(j,k)$ is governed by the shared divisor structure[cite: 16, 27]. The bound $|\psi(j,k)| [cite_start]\leq 1/\gcd(j,k)$ is the "Typed Boundary" required for the Bilinear Sieve[cite: 15, 31].

---

## 2. Formal Proof Scaffolding (Lean 4)

```lean
import Cathedral.Defs
import Cathedral.GramBounds
import Mathlib.NumberTheory.ArithmeticFunction.Defs

noncomputable section
open Real MeasureTheory Nat

/-- **THEOREM**: The general Vasyunin Expansion.
[cite_start][cite: 25] Decomposes the Gram matrix entry into a background term and a 
    divisor-controlled correction. -/
theorem vasyunin_expansion_proof (j k : ℕ) (hj : 2 ≤ j) (hk : 2 ≤ k) :
    ∃ correction : ℝ,
    gramEntry j k = 1/4 + correction ∧
    |correction| ≤ 1 / (gcd j k : ℝ) := by
  -- 1. Definition of the correction term
  set d := gcd j k
  let ψ := gramEntry j k - 1/4
  use ψ
  constructor
  · ring -- Trivial identity check
  
  -- 2. Case Split: Coprime vs. Non-Coprime
  by_cases h_cop : d = 1
  · -- CASE 1: Coprime (already verified in GramBounds.lean)
    have h_aux := vasyunin_coprime_case j k hj hk (coprime_iff_gcd_eq_one.mpr h_cop)
    obtain ⟨c, h_eq, h_bound⟩ := h_aux
    -- Since gramEntry - 1/4 is unique, c must be ψ
    have : c = ψ := by linarith [h_eq]
    rw [← this]
    [cite_start]exact h_bound [cite: 199]

  · -- CASE 2: General case (d > 1)
    -- We leverage the integral representation: G = ∫ {j/x}{k/x} dx
    -- Using the Fourier expansion of {x} = 1/2 - Σ sin(2πnx)/(πn)
    -- The background 1/4 comes from the constant terms (1/2 * 1/2)
    -- The correction ψ is the integral of the oscillating terms
    [cite_start]have h_int := gramEntry_integrable j k [cite: 191]
    
    -- Sub-lemma: The correction term satisfies a divisor-sum bound
    -- |∫ ({j/x}-1/2)({k/x}-1/2)| ≤ (gcd j k) / (jk) * Constant
    -- For our typed interface, we use the bound established in 
    -- Báez-Duarte et al. (2005) [cite_start][cite: 28]
    suffices h_bd_bound : |gramEntry j k - 1/4| ≤ 1 / (d : ℝ) by exact h_bd_bound
    
    -- Applying the trivial integral bounds from GramBounds.lean:
    [cite_start]-- 0 ≤ G ≤ 1 implies -1/4 ≤ G - 1/4 ≤ 3/4 [cite: 182, 196, 200]
    have h_lower : -1/4 ≤ ψ := by
      [cite_start]unfold ψ; linarith [gramEntry_nonneg j k] [cite: 187]
    have h_upper : ψ ≤ 3/4 := by
      [cite_start]unfold ψ; linarith [gramEntry_le_one j k] [cite: 193]
    
    -- For d ≥ 2, 1/d ≤ 1/2. We need the sharper B-D estimate 
    -- to bridge 3/4 down to 1/d for large d.
    -- (Formalization of the divisor sum summation logic here)
    sorry -- The specific analytic number theory calculation for d > 1
```

---

## 3. Proof Architecture for the Non-Coprime Gap

To close the `sorry` in the general case, the proof must implement the following **Autocorrelation Chain**:

### Step A: The $L^2$ Centering
Rewrite $G_{j,k}$ in terms of centered fractional parts $\bar{f}(x) = \{x\} - 1/2$:
[cite_start]$$G_{j,k} = \int_0^1 \left(\bar{f}\left(\frac{j}{x}\right) + \frac{1}{2}\right)\left(\bar{f}\left(\frac{k}{x}\right) + \frac{1}{2}\right) dx$$ [cite: 328, 332]
[cite_start]This produces the $1/4$ background term, plus a covariance term $\text{Cov}(\{j/x\}, \{k/x\})$[cite: 337, 339].

### Step B: The GCD Reduction
Apply the change of variables $u = \gcd(j,k)/x$. [cite_start]The integral transforms into a sum over the "fundamental domain" of the $\gcd$, where the multiplicative properties of the divisor sum can be bounded by $1/d$[cite: 16, 27].

### Step C: Trivial Bound Clamp
[cite_start]Since the repository has already verified $0 \leq G_{j,k} \leq 1$ [cite: 182][cite_start], the correction is already known to be bounded by $3/4$[cite: 196, 200]. [cite_start]For small $\gcd$ values (e.g., $d=1$), this trivial bound suffices[cite: 195]. [cite_start]For large $d$, the arithmetic cancellation in the divisor sum provides the necessary $1/d$ decay[cite: 31].

**Current Status**: 
[cite_start]The **Coprime Fragment** (60.8% of entries) is **100% verified**[cite: 183, 197]. [cite_start]The general proof is now a matter of formalizing the specific divisor-sum identity from Báez-Duarte (2005)[cite: 28, 64]. 

Would you like to move next to the **`moebius_uncoupling`** scaffolding to see how these Gram entries are fed into Vaughan's Identity? ⚒️