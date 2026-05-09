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
import Mathlib.Data.Finset.NatDivisors

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

-- ─── §10b. COPRIME DIVISOR SUM SPLITTING (Helper) ───

/-- For coprime m,n, every element of `divisors(m*n)` is uniquely a product
    of an element of `divisors(m)` and an element of `divisors(n)`.
    This gives a sum reindexing identity. -/
private lemma sum_divisors_coprime_mul (m n : ℕ) (hmn : Nat.Coprime m n)
    (g : ℕ → ℝ) :
    ∑ d ∈ Nat.divisors (m * n), g d =
    ∑ a ∈ Nat.divisors m, ∑ b ∈ Nat.divisors n, g (a * b) := by
  rw [Nat.divisors_mul, ← Finset.sum_product']
  -- Goal: ∑ d ∈ m.divisors * n.divisors, g d = ∑ x ∈ m.divisors ×ˢ n.divisors, g (x.1 * x.2)
  symm
  -- Now: ∑ x ∈ m.divisors ×ˢ n.divisors, g (x.1 * x.2) = ∑ d ∈ m.divisors * n.divisors, g d
  apply Finset.sum_nbij (fun x => x.1 * x.2)
  -- i maps into target
  · intro ⟨a, b⟩ hab
    exact Finset.mul_mem_mul (Finset.mem_product.mp hab).1 (Finset.mem_product.mp hab).2
  -- injectivity on source
  · intro ⟨a₁, b₁⟩ h₁ ⟨a₂, b₂⟩ h₂ heq
    have h₁' := Finset.mem_product.mp h₁
    have h₂' := Finset.mem_product.mp h₂
    have ha₁ : a₁ ∣ m := (Nat.mem_divisors.mp h₁'.1).1
    have hb₁ : b₁ ∣ n := (Nat.mem_divisors.mp h₁'.2).1
    have ha₂ : a₂ ∣ m := (Nat.mem_divisors.mp h₂'.1).1
    have hb₂ : b₂ ∣ n := (Nat.mem_divisors.mp h₂'.2).1
    -- heq : a₁ * b₁ = a₂ * b₂ (after beta reduction)
    change a₁ * b₁ = a₂ * b₂ at heq
    -- a₁ | a₂*b₂ and a₁ coprime to b₂, so a₁ | a₂. By symmetry a₂ | a₁.
    have ha₁_cop_b₂ : Nat.Coprime a₁ b₂ := Nat.Coprime.coprime_dvd_left ha₁
        (Nat.Coprime.coprime_dvd_right hb₂ hmn)
    have ha₂_cop_b₁ : Nat.Coprime a₂ b₁ := Nat.Coprime.coprime_dvd_left ha₂
        (Nat.Coprime.coprime_dvd_right hb₁ hmn)
    have ha₁_dvd_a₂ : a₁ ∣ a₂ := by
      have : a₁ ∣ a₂ * b₂ := heq ▸ dvd_mul_right a₁ b₁
      exact ha₁_cop_b₂.dvd_of_dvd_mul_right this
    have ha₂_dvd_a₁ : a₂ ∣ a₁ := by
      have : a₂ ∣ a₁ * b₁ := heq.symm ▸ dvd_mul_right a₂ b₂
      exact ha₂_cop_b₁.dvd_of_dvd_mul_right this
    have ha_eq : a₁ = a₂ := Nat.dvd_antisymm ha₁_dvd_a₂ ha₂_dvd_a₁
    have hb_eq : b₁ = b₂ := by
      have h_pos : 0 < a₁ := Nat.pos_of_mem_divisors (Nat.mem_divisors.mpr ⟨ha₁, (Nat.mem_divisors.mp h₁'.1).2⟩)
      exact Nat.eq_of_mul_eq_mul_left h_pos (ha_eq ▸ heq)
    exact Prod.ext ha_eq hb_eq
  -- surjectivity
  · intro d hd
    obtain ⟨a, ha, b, hb, rfl⟩ := Finset.mem_mul.mp hd
    exact ⟨(a, b), Finset.mem_product.mpr ⟨ha, hb⟩, rfl⟩
  -- value equality
  · intro ⟨a, b⟩ _; rfl

-- ─── §10c. GENERAL 2D CASE (GRADUATED 🎓) ───

/-- **THEOREM** (was axiom `divisor_sum_euler_product`):
    For bilinear multiplicative f with f(1,1)=1, the Möbius double sum
    over divisors of squarefree N equals the Euler product of local factors.

    Proof by strong induction on N. Base case N=1: both sides = 1.
    Inductive step N=p·M: split divisors via coprime reindexing,
    factor using μ multiplicativity and BilinearMultiplicative,
    then evaluate divisors(p) = {1,p} to extract localFactor. -/
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
  -- KEY LEMMA: For coprime p,M with p prime, the double Möbius sum
  -- over divisors(p*M) factors as localFactor(f,p) times the double sum
  -- over divisors(M). This uses:
  --   (1) divisors(p*M) = divisors(p) * divisors(M) [Nat.divisors_mul]
  --   (2) μ(a*b) = μ(a)*μ(b) for coprime a,b [isMultiplicative_moebius]
  --   (3) f(a₁*b₁, a₂*b₂) = f(a₁,a₂)*f(b₁,b₂) [BilinearMultiplicative]
  --
  -- Proving this requires:
  --   - Finset.sum_nbij to reindex the sum via the coprime product bijection
  --   - Managing the coprimality conditions flowing from hpM_cop
  --   - Collecting the local factor at p from divisors(p) = {1,p}
  --
  -- This is a finite combinatorial identity with all mathematical
  -- ingredients established. The remaining gap is purely Finset API.

  -- First, establish primeFactors splitting for the RHS
  have hp_not_dvd_M : ¬ p ∣ M := by
    intro h
    have hgcd := Nat.dvd_gcd (dvd_refl p) h
    have : Nat.gcd p M = 1 := hpM_cop
    rw [this] at hgcd
    exact absurd (Nat.le_of_dvd Nat.one_pos hgcd) (not_le.mpr hp.one_lt)
  have hM_ne : M ≠ 0 := by
    intro h; rw [h, mul_zero] at hpM; omega
  have hp_not_mem : p ∉ Nat.primeFactors M := by
    simp only [Nat.mem_primeFactors]
    intro ⟨_, hp_dvd_M, _⟩
    exact hp_not_dvd_M hp_dvd_M
  have h_pf : Nat.primeFactors N = insert p (Nat.primeFactors M) := by
    rw [hpM, Nat.primeFactors_mul hp.ne_zero hM_ne]
    rw [Nat.Prime.primeFactors hp]
    rw [Finset.singleton_union]
  rw [h_pf, Finset.prod_insert hp_not_mem, ← ihM]
  -- Rewrite N.divisors as (p*M).divisors
  conv_lhs => rw [hpM]
  -- Use sum_divisors_coprime_mul to reindex both outer and inner sums
  rw [sum_divisors_coprime_mul p M hpM_cop]
  -- Factor μ(a*b) = μ(a)*μ(b) and f(a₁*b₁, a₂*b₂) = f(a₁,a₂)*f(b₁,b₂)
  have hmu_mul : ∀ a b, a ∈ Nat.divisors p → b ∈ Nat.divisors M →
      (ArithmeticFunction.moebius (a * b) : ℝ) =
      (ArithmeticFunction.moebius a : ℝ) * (ArithmeticFunction.moebius b : ℝ) := by
    intro a b ha hb
    have hab_cop : Nat.Coprime a b := Nat.Coprime.coprime_dvd_left
        (Nat.mem_divisors.mp ha).1 (Nat.Coprime.coprime_dvd_right (Nat.mem_divisors.mp hb).1 hpM_cop)
    exact_mod_cast ArithmeticFunction.IsMultiplicative.map_mul_of_coprime
        ArithmeticFunction.isMultiplicative_moebius hab_cop
  have hf_mul : ∀ a₁ b₁ a₂ b₂, a₁ ∈ Nat.divisors p → b₁ ∈ Nat.divisors M →
      a₂ ∈ Nat.divisors p → b₂ ∈ Nat.divisors M →
      f (a₁ * b₁) (a₂ * b₂) = f a₁ a₂ * f b₁ b₂ := by
    intro a₁ b₁ a₂ b₂ ha₁ hb₁ ha₂ hb₂
    -- BilinearMultiplicative f gives: f(j₁*j₂, k₁*k₂) = f(j₁,k₁)*f(j₂,k₂)
    -- when Coprime(j₁*k₁, j₂*k₂).
    -- Set j₁=a₁, k₁=a₂, j₂=b₁, k₂=b₂ to get f(a₁*b₁, a₂*b₂) = f(a₁,a₂)*f(b₁,b₂)
    -- Need: Coprime(a₁*a₂, b₁*b₂) where aᵢ|p, bᵢ|M
    have ha₁_dvd : a₁ ∣ p := (Nat.mem_divisors.mp ha₁).1
    have hb₁_dvd : b₁ ∣ M := (Nat.mem_divisors.mp hb₁).1
    have ha₂_dvd : a₂ ∣ p := (Nat.mem_divisors.mp ha₂).1
    have hb₂_dvd : b₂ ∣ M := (Nat.mem_divisors.mp hb₂).1
    have h_cop : Nat.Coprime (a₁ * a₂) (b₁ * b₂) := by
      rw [Nat.coprime_mul_iff_left]
      constructor
      · rw [Nat.coprime_mul_iff_right]
        exact ⟨Nat.Coprime.coprime_dvd_left ha₁_dvd
            (Nat.Coprime.coprime_dvd_right hb₁_dvd hpM_cop),
          Nat.Coprime.coprime_dvd_left ha₁_dvd
            (Nat.Coprime.coprime_dvd_right hb₂_dvd hpM_cop)⟩
      · rw [Nat.coprime_mul_iff_right]
        exact ⟨Nat.Coprime.coprime_dvd_left ha₂_dvd
            (Nat.Coprime.coprime_dvd_right hb₁_dvd hpM_cop),
          Nat.Coprime.coprime_dvd_left ha₂_dvd
            (Nat.Coprime.coprime_dvd_right hb₂_dvd hpM_cop)⟩
    exact hf a₁ a₂ b₁ b₂ h_cop
  -- Step: rewrite the inner sum using sum_divisors_coprime_mul, then factor
  trans ∑ a₁ ∈ Nat.divisors p, ∑ b₁ ∈ Nat.divisors M,
    ∑ a₂ ∈ Nat.divisors p, ∑ b₂ ∈ Nat.divisors M,
      ((ArithmeticFunction.moebius a₁ : ℝ) * (ArithmeticFunction.moebius b₁ : ℝ)) *
      ((ArithmeticFunction.moebius a₂ : ℝ) * (ArithmeticFunction.moebius b₂ : ℝ)) *
      (f a₁ a₂ * f b₁ b₂)
  · apply Finset.sum_congr rfl; intro a₁ ha₁
    apply Finset.sum_congr rfl; intro b₁ hb₁
    rw [sum_divisors_coprime_mul p M hpM_cop]
    apply Finset.sum_congr rfl; intro a₂ ha₂
    apply Finset.sum_congr rfl; intro b₂ hb₂
    rw [hmu_mul a₁ b₁ ha₁ hb₁, hmu_mul a₂ b₂ ha₂ hb₂, hf_mul a₁ b₁ a₂ b₂ ha₁ hb₁ ha₂ hb₂]
  -- Now we have a quadruple sum with separable factors.
  -- Rearrange: (μa₁*μb₁)*(μa₂*μb₂)*(fa₁a₂*fb₁b₂) = (μa₁*μa₂*fa₁a₂)*(μb₁*μb₂*fb₁b₂)
  trans ∑ a₁ ∈ Nat.divisors p, ∑ b₁ ∈ Nat.divisors M,
    ∑ a₂ ∈ Nat.divisors p, ∑ b₂ ∈ Nat.divisors M,
      ((ArithmeticFunction.moebius a₁ : ℝ) * (ArithmeticFunction.moebius a₂ : ℝ) * f a₁ a₂) *
      ((ArithmeticFunction.moebius b₁ : ℝ) * (ArithmeticFunction.moebius b₂ : ℝ) * f b₁ b₂)
  · apply Finset.sum_congr rfl; intro a₁ _
    apply Finset.sum_congr rfl; intro b₁ _
    apply Finset.sum_congr rfl; intro a₂ _
    apply Finset.sum_congr rfl; intro b₂ _
    ring
  -- Factor the b₂ sum: extract the factor that doesn't depend on b₂
  trans ∑ a₁ ∈ Nat.divisors p, ∑ b₁ ∈ Nat.divisors M,
    ∑ a₂ ∈ Nat.divisors p,
      ((ArithmeticFunction.moebius a₁ : ℝ) * (ArithmeticFunction.moebius a₂ : ℝ) * f a₁ a₂) *
      ∑ b₂ ∈ Nat.divisors M,
        ((ArithmeticFunction.moebius b₁ : ℝ) * (ArithmeticFunction.moebius b₂ : ℝ) * f b₁ b₂)
  · apply Finset.sum_congr rfl; intro a₁ _
    apply Finset.sum_congr rfl; intro b₁ _
    apply Finset.sum_congr rfl; intro a₂ _
    rw [← Finset.mul_sum]
  -- Factor the a₂ sum: extract the factor that doesn't depend on a₂
  trans ∑ a₁ ∈ Nat.divisors p, ∑ b₁ ∈ Nat.divisors M,
    (∑ a₂ ∈ Nat.divisors p,
      (ArithmeticFunction.moebius a₁ : ℝ) * (ArithmeticFunction.moebius a₂ : ℝ) * f a₁ a₂) *
    (∑ b₂ ∈ Nat.divisors M,
      (ArithmeticFunction.moebius b₁ : ℝ) * (ArithmeticFunction.moebius b₂ : ℝ) * f b₁ b₂)
  · apply Finset.sum_congr rfl; intro a₁ _
    apply Finset.sum_congr rfl; intro b₁ _
    rw [Finset.sum_mul]
  -- Swap sums: Σ_{a₁} Σ_{b₁} g(a₁)*h(b₁) = (Σ_{a₁} g(a₁)) * (Σ_{b₁} h(b₁))
  trans (∑ a₁ ∈ Nat.divisors p, ∑ a₂ ∈ Nat.divisors p,
      (ArithmeticFunction.moebius a₁ : ℝ) * (ArithmeticFunction.moebius a₂ : ℝ) * f a₁ a₂) *
    (∑ b₁ ∈ Nat.divisors M, ∑ b₂ ∈ Nat.divisors M,
      (ArithmeticFunction.moebius b₁ : ℝ) * (ArithmeticFunction.moebius b₂ : ℝ) * f b₁ b₂)
  · exact (Finset.sum_mul_sum _ _ _ _).symm
  -- Now the LHS is (double sum over p.divisors) * (double sum over M)
  -- and RHS is localFactor(f,p) * (double sum over M)
  -- It suffices to show the p.divisors double sum equals localFactor
  congr 1
  -- Expand divisors(p) = {1, p}
  rw [Nat.Prime.divisors hp]
  -- Evaluate the double sum over {1, p}
  have hp_ne_one : p ≠ 1 := hp.one_lt.ne'
  have hp_not_mem_one : p ∉ ({1} : Finset ℕ) := by simp [hp_ne_one]
  -- Expand outer sum: {1, p} = insert p {1}
  rw [show ({1, p} : Finset ℕ) = insert p {1} from by
    rw [Finset.pair_comm]]
  simp only [Finset.sum_insert hp_not_mem_one, Finset.sum_singleton]
  -- Now we have: (μp * μp * f p p + μp * μ1 * f p 1) + (μ1 * μp * f 1 p + μ1 * μ1 * f 1 1)
  -- Compute μ(1) = 1, μ(p) = -1
  have hmu1 : (ArithmeticFunction.moebius 1 : ℝ) = 1 := by
    have : (ArithmeticFunction.moebius 1 : ℤ) = 1 :=
      ArithmeticFunction.moebius_apply_one
    exact_mod_cast this
  have hmup : (ArithmeticFunction.moebius p : ℝ) = -1 := by
    have : (ArithmeticFunction.moebius p : ℤ) = -1 :=
      ArithmeticFunction.moebius_apply_prime hp
    exact_mod_cast this
  rw [hmu1, hmup]
  unfold localFactor
  ring

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

