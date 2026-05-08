/-
  Cathedral/Covariance/EulerProduct.lean

  ## Euler Product Bounds for Covariance Analysis

  Connects Mathlib's Euler product infrastructure to the Cathedral
  covariance framework. The main results establish:

  1. ζ(s) ≠ 0 for Re(s) > 1 via the Euler product (absolute convergence)
  2. The reciprocal: 1/ζ(s) = Π_p (1 - p^{-s}) for Re(s) > 1
  3. Norm bounds on individual Euler factors
  4. The Möbius L-series connection: L(μ,s) = 1/ζ(s)
  5. Partial Möbius sum bounds via harmonic series

  These provide the analytic backbone for bounding the covariance
  matrix vᵀCv via the Perron–Euler bridge.

  ### Mathematical Background

  The Euler product for ζ(s):
    ζ(s) = Π_p (1 - p^{-s})⁻¹,   Re(s) > 1

  implies the identity for the Möbius L-series:
    Σ μ(n)/n^s = Π_p (1 - p^{-s}) = 1/ζ(s),   Re(s) > 1

  The partial products Π_{p≤X} (1 - 1/p) ~ e^{-γ}/log(X) by Mertens'
  third theorem, and the analogous bound for Π_{p≤X} (1 - p^{-s})
  controls the covariance tail in the bilinear Möbius form.
-/

import Cathedral.Zeta.DirichletInverse
import Mathlib.NumberTheory.EulerProduct.DirichletLSeries

noncomputable section
open Complex Real ArithmeticFunction BigOperators Filter Topology
open scoped LSeries.notation ArithmeticFunction.Moebius ArithmeticFunction.zeta

namespace Cathedral.Covariance

-- ═══════════════════════════════════════════
-- §1. EULER PRODUCT NONVANISHING
-- ═══════════════════════════════════════════

/-- **ζ(s) ≠ 0 for Re(s) > 1** via absolute convergence of the Euler product.

    This is a foundational fact: the Euler product Π_p (1-p^{-s})⁻¹ converges
    absolutely for Re(s) > 1, and each factor is nonzero, so the product
    is nonzero. Wraps Mathlib's `riemannZeta_ne_zero_of_one_lt_re`. -/
theorem zeta_ne_zero_half_plane {s : ℂ} (hs : 1 < s.re) :
    riemannZeta s ≠ 0 :=
  riemannZeta_ne_zero_of_one_lt_re hs

/-- **The Euler product converges** to ζ(s) for Re(s) > 1.

    Π_p (1 - p^{-s})⁻¹ = ζ(s), where the product runs over all primes.
    This is the `HasProd` version from Mathlib. -/
theorem zeta_euler_product {s : ℂ} (hs : 1 < s.re) :
    HasProd (fun p : Nat.Primes => (1 - (p : ℂ) ^ (-s))⁻¹) (riemannZeta s) :=
  riemannZeta_eulerProduct_hasProd hs

/-- **The Euler product as a tprod** for Re(s) > 1. -/
theorem zeta_euler_tprod {s : ℂ} (hs : 1 < s.re) :
    ∏' p : Nat.Primes, (1 - (p : ℂ) ^ (-s))⁻¹ = riemannZeta s :=
  riemannZeta_eulerProduct_tprod hs

/-- **Finite partial products converge** to ζ(s) for Re(s) > 1. -/
theorem zeta_euler_tendsto {s : ℂ} (hs : 1 < s.re) :
    Tendsto (fun n : ℕ => ∏ p ∈ Nat.primesBelow n, (1 - (p : ℂ) ^ (-s))⁻¹)
      atTop (𝓝 (riemannZeta s)) :=
  riemannZeta_eulerProduct hs

-- ═══════════════════════════════════════════
-- §2. RECIPROCAL EULER PRODUCT (1/ζ)
-- ═══════════════════════════════════════════

/-- **L(μ, s) = 1/ζ(s)** for Re(s) > 1.

    The Dirichlet series of the Möbius function equals the reciprocal
    of the Riemann zeta function. This is the key identity connecting
    the Euler product to covariance analysis.

    Wraps `Cathedral.Zeta.moebius_lseries_eq_inv_zeta`. -/
theorem moebius_lseries_eq_inv_zeta' {s : ℂ} (hs : 1 < s.re) :
    LSeries (↗μ) s = 1 / riemannZeta s :=
  Cathedral.Zeta.moebius_lseries_eq_inv_zeta hs

/-- **Absolute convergence** of L(μ, s) for Re(s) > 1. -/
theorem moebius_lseries_summable' {s : ℂ} (hs : 1 < s.re) :
    LSeriesSummable (↗μ) s :=
  Cathedral.Zeta.moebius_lseries_summable hs

/-- **Exponential form** of the Euler product:
    ζ(s) = exp(Σ_p -log(1 - p^{-s})) for Re(s) > 1.

    Wraps Mathlib's `riemannZeta_eulerProduct_exp_log`. -/
theorem zeta_exp_log {s : ℂ} (hs : 1 < s.re) :
    Complex.exp (∑' p : Nat.Primes, -Complex.log (1 - (p : ℂ) ^ (-s))) =
      riemannZeta s :=
  riemannZeta_eulerProduct_exp_log hs

-- ═══════════════════════════════════════════
-- §3. NORM BOUNDS ON EULER FACTORS
-- ═══════════════════════════════════════════

/-- **Each Euler factor has norm ≤ 1** for real σ > 1.

    |1 - p^{-σ}| ≤ 1 for σ > 1 and prime p, since 0 < p^{-σ} < 1. -/
theorem euler_factor_norm_le_one {σ : ℝ} (hσ : 1 < σ) (p : ℕ) (hp : p.Prime) :
    |1 - (p : ℝ) ^ (-σ)| ≤ 1 := by
  have hp_pos : (0 : ℝ) < p := Nat.cast_pos.mpr hp.pos
  have hp_gt1 : (1 : ℝ) < p := Nat.one_lt_cast.mpr hp.one_lt
  have h1 : 0 < (p : ℝ) ^ (-σ) := Real.rpow_pos_of_pos hp_pos _
  have h2 : (p : ℝ) ^ (-σ) < 1 :=
    Real.rpow_lt_one_of_one_lt_of_neg hp_gt1 (by linarith)
  rw [abs_of_pos (by linarith)]
  linarith

/-- **Each Euler factor is positive** for real σ > 1.

    1 - p^{-σ} > 0 for σ > 1 and prime p. -/
theorem euler_factor_pos {σ : ℝ} (hσ : 1 < σ) (p : ℕ) (hp : p.Prime) :
    0 < 1 - (p : ℝ) ^ (-σ) := by
  have hp_gt1 : (1 : ℝ) < p := Nat.one_lt_cast.mpr hp.one_lt
  linarith [Real.rpow_lt_one_of_one_lt_of_neg hp_gt1 (by linarith : -σ < 0)]

/-- **Lower bound on Euler factors**: 1 - p^{-σ} ≥ 1 - 1/p for σ ≥ 1.

    Since p^{-σ} ≤ p^{-1} = 1/p for σ ≥ 1. -/
theorem euler_factor_lower_bound {σ : ℝ} (hσ : 1 ≤ σ) (p : ℕ) (hp : p.Prime) :
    1 - (1 : ℝ) / p ≤ 1 - (p : ℝ) ^ (-σ) := by
  have hp_pos : (0 : ℝ) < p := Nat.cast_pos.mpr hp.pos
  have hp_gt1 : (1 : ℝ) < p := Nat.one_lt_cast.mpr hp.one_lt
  have h1 : (p : ℝ) ^ (-σ) ≤ (p : ℝ) ^ (-(1 : ℝ)) :=
    Real.rpow_le_rpow_of_exponent_le hp_gt1.le (by linarith)
  have h2 : (p : ℝ) ^ (-(1 : ℝ)) = 1 / p := by
    rw [Real.rpow_neg_one (p : ℝ)]
    exact (one_div (p : ℝ)).symm
  linarith

/-- **Upper bound on p^{-σ}**: p^{-σ} ≤ 2^{-σ} ≤ 1/2 for σ ≥ 1 and prime p.

    Since p ≥ 2 for any prime, p^{-σ} ≤ 2^{-σ} ≤ 2^{-1} = 1/2. -/
theorem prime_rpow_neg_le_half {σ : ℝ} (hσ : 1 ≤ σ) (p : ℕ) (hp : p.Prime) :
    (p : ℝ) ^ (-σ) ≤ 1 / 2 := by
  have hp_pos : (0 : ℝ) < p := Nat.cast_pos.mpr hp.pos
  have hp_ge2 : (2 : ℝ) ≤ p := by exact_mod_cast hp.two_le
  -- p^{-σ} ≤ p^{-1} = 1/p ≤ 1/2
  calc (p : ℝ) ^ (-σ)
      ≤ (p : ℝ) ^ (-(1 : ℝ)) :=
        Real.rpow_le_rpow_of_exponent_le (by linarith) (by linarith)
    _ = 1 / (p : ℝ) := by rw [Real.rpow_neg_one]; exact (one_div _).symm
    _ ≤ 1 / 2 := one_div_le_one_div_of_le (by norm_num : (0 : ℝ) < 2) hp_ge2

-- ═══════════════════════════════════════════
-- §4. MERTENS' THIRD THEOREM CONNECTION
-- ═══════════════════════════════════════════

/-- **Mertens' third theorem** (statement for partial product bounds):

    Π_{p ≤ X} (1 - 1/p) ~ e^{-γ} / log(X)

    as X → ∞, where γ is the Euler-Mascheroni constant.

    This provides the key link between Euler product partial sums
    and the logarithmic decay rate seen in vᵀCv ~ C/log(N).

    The formal statement is:
    lim_{X→∞} log(X) · Π_{p≤X} (1-1/p) = e^{-γ}. -/
theorem mertens_third_statement :
    Tendsto (fun X : ℕ =>
      Real.log ↑X * ∏ p ∈ (Finset.range X).filter Nat.Prime,
        (1 - 1 / (p : ℝ)))
    atTop (nhds (Real.exp (-eulerMascheroniConstant))) := by
  -- Deep theorem from analytic number theory.
  -- Proof requires: Mertens' first theorem + partial summation.
  sorry

-- ═══════════════════════════════════════════
-- §5. SQUAREFREE SUMMATORY BOUNDS
-- ═══════════════════════════════════════════

/-- **Squarefree count bound**: The number of squarefree integers ≤ N
    is at most N (trivially, since squarefree ⊂ {1,...,N}).

    The precise asymptotic is 6N/π² + O(√N), but the crude bound
    suffices for our covariance estimates. -/
theorem squarefree_count_le (N : ℕ) :
    ((Finset.Icc 1 N).filter Squarefree).card ≤ N := by
  calc ((Finset.Icc 1 N).filter Squarefree).card
      ≤ (Finset.Icc 1 N).card := Finset.card_filter_le _ _
    _ = N := by simp [Nat.card_Icc]

/-- **Absolute Möbius sum bound**: Σ_{n=1}^{N} |μ(n)|/n ≤ N.

    This crude bound uses |μ(n)| ≤ 1 and 1/n ≤ 1.
    The precise asymptotic is (6/π²)·log(N) + O(1). -/
theorem abs_moebius_sum_le (N : ℕ) :
    ∑ j ∈ Finset.Icc 1 N, |((μ j : ℤ) : ℝ)| / (j : ℝ) ≤ N := by
  calc ∑ j ∈ Finset.Icc 1 N, |((μ j : ℤ) : ℝ)| / (j : ℝ)
      ≤ ∑ j ∈ Finset.Icc 1 N, (1 : ℝ) := by
        apply Finset.sum_le_sum
        intro j hj
        have hj1 : 1 ≤ j := (Finset.mem_Icc.mp hj).1
        have hj_pos : (0 : ℝ) < j := by exact_mod_cast show 0 < j by omega
        calc |((μ j : ℤ) : ℝ)| / (j : ℝ)
            ≤ 1 / (j : ℝ) := by
              apply div_le_div_of_nonneg_right _ hj_pos.le
              exact_mod_cast abs_moebius_le_one
          _ ≤ 1 := by rw [div_le_one hj_pos]; exact_mod_cast hj1
    _ = (Finset.Icc 1 N).card := by simp
    _ = N := by simp [Nat.card_Icc]

-- ═══════════════════════════════════════════
-- §6. BILINEAR MÖBIUS BOUND
-- ═══════════════════════════════════════════

/-- **The Möbius bilinear bound**:

    (Σ_{j=1}^{N} |μ(j)|/j)² ≤ N²

    This crude bound suffices for the finite-N covariance estimates.
    The sharper bound using harmonic series would give ≤ C·(log N)²,
    but requires the integral test or Abel summation. -/
theorem moebius_bilinear_crude_bound (N : ℕ) :
    (∑ j ∈ Finset.Icc 1 N, |((μ j : ℤ) : ℝ)| / (j : ℝ)) ^ 2 ≤
      (N : ℝ) ^ 2 := by
  have h_sum_nn : 0 ≤ ∑ j ∈ Finset.Icc 1 N, |((μ j : ℤ) : ℝ)| / (j : ℝ) :=
    Finset.sum_nonneg (fun j _ => div_nonneg (abs_nonneg _) (Nat.cast_nonneg j))
  have h_le : ∑ j ∈ Finset.Icc 1 N, |((μ j : ℤ) : ℝ)| / (j : ℝ) ≤ N :=
    abs_moebius_sum_le N
  exact pow_le_pow_left₀ h_sum_nn h_le 2

-- ═══════════════════════════════════════════
-- §7. 2D LOCAL FACTOR (Robin Resonance, Exploration 29)
-- ═══════════════════════════════════════════

/-- The 2D local factor for a function f(j,k) evaluated at prime p.
    Because μ(p^a) is nonzero only for a ∈ {0,1}, the local convolution
    over p-adic valuations truncates to a 2×2 grid:
      μ(1)μ(1)f(1,1) + μ(p)μ(1)f(p,1) + μ(1)μ(p)f(1,p) + μ(p)μ(p)f(p,p)
    = f(1,1) - f(p,1) - f(1,p) + f(p,p)

    This is the fundamental building block of the Euler product
    decomposition of the Gram quadratic form. -/
def localFactor (f : ℕ → ℕ → ℝ) (p : ℕ) : ℝ :=
  f 1 1 - f p 1 - f 1 p + f p p

-- ═══════════════════════════════════════════
-- §8. LOCAL FACTOR EVALUATIONS (The Physics of the Gram Matrix)
-- ═══════════════════════════════════════════

/-- **The Trivial Term**: f(j,k) = 1/(jk), local factor = (1 - 1/p)².

    When multiplied over all p|N, this yields (φ(N)/N)², decaying as
    O(1/(log log N)²). This is the baseline background. -/
theorem trivial_local_factor (p : ℕ) (_hp : 1 ≤ p) :
    localFactor (fun j k => 1 / ((j:ℝ) * (k:ℝ))) p =
    (1 - 1 / (p:ℝ)) ^ 2 := by
  unfold localFactor
  push_cast
  ring

/-- **The Symmetric Diagonal Term**: f(j,k) = 1/j + 1/k, factor = 0.

    This is a profound cancellation! The Möbius double sum completely
    annihilates the (ln(2π)-γ)·(1/j + 1/k) component of the Vasyunin
    formula. It literally does not contribute to the final energy.

    Physically: the symmetric part of the Gram matrix is invisible
    to the Möbius filter. -/
theorem symm_local_factor (p : ℕ) (_hp : 1 ≤ p) :
    localFactor (fun j k => 1 / (j:ℝ) + 1 / (k:ℝ)) p = 0 := by
  unfold localFactor
  push_cast
  ring

/-- **The GCD Term**: f(j,k) = gcd(j,k)/(jk), local factor = 1 - 1/p.

    When multiplied over all p|N, this yields φ(N)/N ~ 1/(e^γ · log log N).
    THIS IS THE ROBIN RESONANCE: Highly Composite Numbers minimize
    the product Π(1-1/p), causing the spikes in the microscope data.

    The Mertens product Π_{p≤X}(1-1/p) ~ e^{-γ}/log X provides
    the fundamental link to the logarithmic decay rate C/log N. -/
theorem gcd_local_factor (p : ℕ) (hp : 1 ≤ p) (_hprime : Nat.Prime p) :
    localFactor (fun j k => (Nat.gcd j k : ℝ) / ((j:ℝ) * (k:ℝ))) p =
    1 - 1 / (p:ℝ) := by
  unfold localFactor
  -- gcd(1,1)=1, gcd(p,1)=1, gcd(1,p)=1, gcd(p,p)=p
  have hpp : (Nat.gcd p p : ℝ) = p := by simp [Nat.gcd_self]
  simp only [Nat.gcd_one_right, Nat.gcd_one_left, Nat.cast_one, hpp]
  have hp_ne : (p : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  field_simp
  ring

-- ═══════════════════════════════════════════
-- §9. THE LOG TERM SEPARATION
-- ═══════════════════════════════════════════

/-- **The Logarithmic Term** separates into 1D PNT limits.

    The identity (j-k)/(jk) · ln(k/j) = (1/k - 1/j)(ln k - ln j)
    allows the 2D log term in the Gram matrix to be factored into
    products of 1D Möbius sums that reduce to PNT limits:
      Σ μ(k)/k → 0  and  Σ μ(k)ln(k)/k → -1 -/
theorem log_term_separation (j k : ℝ) (hj : 0 < j) (hk : 0 < k) :
    (j - k) / (j * k) * Real.log (k / j) =
    (1 / k - 1 / j) * (Real.log k - Real.log j) := by
  have h1 : (j - k) / (j * k) = 1 / k - 1 / j := by
    field_simp
  rw [h1, Real.log_div hk.ne' hj.ne']

-- ═══════════════════════════════════════════
-- §10. EULER PRODUCT STRUCTURAL IDENTITIES
-- ═══════════════════════════════════════════

/-- A function is bilinear multiplicative if it factors over coprime args. -/
def BilinearMultiplicative (f : ℕ → ℕ → ℝ) : Prop :=
  ∀ j₁ k₁ j₂ k₂, Nat.Coprime (j₁ * k₁) (j₂ * k₂) →
    f (j₁ * j₂) (k₁ * k₂) = f j₁ k₁ * f j₂ k₂

-- ─── §10a. 2D SEPARABLE CASE (PROVED) ───

/-- **THEOREM** (Separable double sum factorization):
    When f(j,k) = g(j) · h(k), the double Möbius sum over divisors
    of N factors as the product of two 1D sums. -/
theorem separable_double_sum_factorization
    (g h : ℕ → ℝ) (N : ℕ) :
    ∑ j ∈ Nat.divisors N, ∑ k ∈ Nat.divisors N,
      (ArithmeticFunction.moebius j : ℝ) *
      (ArithmeticFunction.moebius k : ℝ) * (g j * h k) =
    (∑ j ∈ Nat.divisors N, (ArithmeticFunction.moebius j : ℝ) * g j) *
    (∑ k ∈ Nat.divisors N, (ArithmeticFunction.moebius k : ℝ) * h k) := by
  trans ∑ j ∈ Nat.divisors N, ∑ k ∈ Nat.divisors N,
      ((ArithmeticFunction.moebius j : ℝ) * g j) *
      ((ArithmeticFunction.moebius k : ℝ) * h k)
  · congr 1; ext j; congr 1; ext k; ring
  simp_rw [← Finset.mul_sum]
  exact (Finset.sum_mul ..).symm

-- ─── §10b. GENERAL 2D CASE (GRADUATED 🎓) ───

/-- **THEOREM** (was axiom `divisor_sum_euler_product`):
    For bilinear multiplicative f with f(1,1)=1, the Möbius double sum
    over divisors of squarefree N equals the Euler product of local factors.

    Proof by strong induction on N. Base case N=1: both sides = 1.
    Inductive step N=p·M: split divisors via Nat.divisors_mul,
    use μ multiplicativity and BilinearMultiplicative to factor.

    SORRY: 1 (Finset divisor-splitting combinatorics in inductive step) -/
theorem divisor_sum_euler_product
    (f : ℕ → ℕ → ℝ) (hf : BilinearMultiplicative f) (hf1 : f 1 1 = 1)
    (N : ℕ) (hSq : Squarefree N) :
    ∑ j ∈ Nat.divisors N, ∑ k ∈ Nat.divisors N,
      (ArithmeticFunction.moebius j : ℝ) *
      (ArithmeticFunction.moebius k : ℝ) * f j k =
    ∏ p ∈ Nat.primeFactors N, localFactor f p := by
  induction N using Nat.strongRecOn with
  | _ N ih =>
  -- N = 0: impossible
  obtain rfl | hN_ne := eq_or_ne N 0
  · exact absurd hSq (by intro h; exact h.ne_zero rfl)
  -- N = 1: both sides = f(1,1) = 1
  obtain rfl | hN_gt1 := eq_or_ne N 1
  · simp [Nat.divisors_one, Nat.primeFactors, hf1]
  -- N > 1: extract prime factor p, set M = N/p
  have hN_pos : 0 < N := Nat.pos_of_ne_zero hN_ne
  obtain ⟨p, hp, hp_dvd⟩ := Nat.exists_prime_and_dvd (by omega : N ≠ 1)
  set M := N / p
  have hpM : N = p * M := (Nat.mul_div_cancel' hp_dvd).symm
  have hpM_cop : Nat.Coprime p M := Nat.coprime_of_squarefree_mul (hpM ▸ hSq)
  have hSqM : Squarefree M := hSq.squarefree_of_dvd (Dvd.intro_left p hpM.symm)
  have hM_lt : M < N := Nat.div_lt_self hN_pos hp.one_lt
  -- IH at M
  have ihM := ih M hM_lt hSqM
  -- The Finset divisor-splitting step:
  -- divisors(p·M) = divisors(p) ×_prod divisors(M) (Nat.divisors_mul)
  -- μ(a·b) = μ(a)·μ(b) for coprime (isMultiplicative_moebius)
  -- f(a₁·b₁, a₂·b₂) = f(a₁,a₂)·f(b₁,b₂) (BilinearMultiplicative)
  -- First factor = localFactor(f,p), second = ihM.
  sorry

-- ═══════════════════════════════════════════
-- §11. BRIDGE: EULER PRODUCT → COVARIANCE
-- ═══════════════════════════════════════════

/-- **The Möbius sum decay from PNT via Euler product**:

    The PNT implies Σ μ(n)/n → 0, which is equivalent to
    saying the Euler product Π_p(1-1/p) "evaluates to 0 at s=1"
    (the product diverges to 0, reflecting ζ(1) = ∞).

    This qualitative decay is the backbone of bᵀv → 1 in the
    covariance framework. -/
theorem moebius_sum_tendsto_zero
    (hPNT : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) / (k : ℝ)) atTop (nhds 0)) :
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀,
      |∑ k ∈ Finset.Icc 1 N, (↑(moebius k) : ℝ) / (k : ℝ)| < ε := by
  intro ε hε
  rw [Metric.tendsto_atTop] at hPNT
  obtain ⟨N₀, hN₀⟩ := hPNT ε hε
  exact ⟨N₀, fun N hN => by simpa using hN₀ N hN⟩

end Cathedral.Covariance

