/-
  Cathedral/NumberTheory/SquarefreeJ2Sum.lean

  ## Graduation of squarefree_reciprocal_j2_sum

  ════════════════════════════════════════════════════════════════

  THEOREM: Σ_{d sqfree, d≥1} 1/J₂(d) = π²/6

  Strategy:
  1. Define sqfreeJ2Inv as a multiplicative ArithmeticFunction
  2. Prove the Euler factor = (1-1/p²)⁻¹
  3. Derive ∏(1-1/p²)⁻¹ = π²/6 from the ℂ Euler product for ζ(2)
  4. Prove summability via comparison with C/n^{3/2}
  5. Assembly: HasSum sqfreeJ2Inv (π²/6)

  Created: May 26, 2026 — The Euler Product Graduation Session
-/

-- (EulerProductLimit import removed — not needed, breaks circular dependency)
import Cathedral.Physics.Bridges.BernoulliSkeleton
import Mathlib.NumberTheory.EulerProduct.Basic
import Mathlib.NumberTheory.EulerProduct.DirichletLSeries
import Mathlib.NumberTheory.ZetaValues
import Mathlib.NumberTheory.LSeries.HurwitzZetaValues
import Mathlib.Analysis.PSeries
import Mathlib.Analysis.SpecialFunctions.Pow.Complex

noncomputable section
open Real Finset BigOperators Complex
open ArithmeticFunction Nat
open scoped ArithmeticFunction.Moebius

namespace Cathedral.NumberTheory.SquarefreeJ2Sum

-- Convenient abbreviation
private abbrev J₂ := Cathedral.Physics.BernoulliSkeleton.jordanTotient2

/-- For squarefree d = p₁···pₖ, J₂(d) = ∏_{p|d} (p²-1).
    Local proof: J₂(d) = d²·∏(1-1/p²). For sqfree d, d=∏p, so
    d²=∏p². Distributing: J₂(d) = ∏[p²·(1-1/p²)] = ∏(p²-1). -/
private theorem j2_eq_prod_sq_minus_one (d : ℕ) (_hd : 0 < d) (hd_sf : Squarefree d) :
    J₂ d = ∏ p ∈ d.primeFactors, ((p : ℝ) ^ 2 - 1) := by
  unfold J₂ Cathedral.Physics.BernoulliSkeleton.jordanTotient2
  have hd_eq : (d : ℝ) = ∏ p ∈ d.primeFactors, (p : ℝ) := by
    rw [← Nat.cast_prod]
    exact congrArg Nat.cast (Nat.prod_primeFactors_of_squarefree hd_sf).symm
  rw [hd_eq, ← Finset.prod_pow, ← Finset.prod_mul_distrib]
  apply Finset.prod_congr rfl
  intro p hp
  have hp_prime := (Nat.mem_primeFactors.mp hp).1
  have hp_ne : (p : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr hp_prime.ne_zero
  field_simp

-- ════════════════════════════════════════════════════════════════
-- §1. THE ARITHMETIC FUNCTION: sqfreeJ2Inv
-- ════════════════════════════════════════════════════════════════

/-- The squarefree reciprocal J₂ function.
    sqfreeJ2Inv(0) = 0
    sqfreeJ2Inv(n) = 1/J₂(n) for squarefree n ≥ 1
    sqfreeJ2Inv(n) = 0 for non-squarefree n -/
noncomputable def sqfreeJ2Inv : ArithmeticFunction ℝ :=
  ⟨fun n => if n = 0 then 0
            else if Squarefree n then 1 / J₂ n
            else 0, by simp⟩

theorem sqfreeJ2Inv_zero : sqfreeJ2Inv 0 = 0 := by
  simp [sqfreeJ2Inv]

theorem sqfreeJ2Inv_apply {n : ℕ} (hn : n ≠ 0) :
    sqfreeJ2Inv n = if Squarefree n then 1 / J₂ n else 0 := by
  simp [sqfreeJ2Inv, hn]

theorem sqfreeJ2Inv_one : sqfreeJ2Inv 1 = 1 := by
  simp [sqfreeJ2Inv, Cathedral.Physics.BernoulliSkeleton.j2_one]

theorem sqfreeJ2Inv_squarefree {n : ℕ} (hn : n ≠ 0) (hsf : Squarefree n) :
    sqfreeJ2Inv n = 1 / J₂ n := by
  simp [sqfreeJ2Inv, hn, hsf]

theorem sqfreeJ2Inv_not_squarefree {n : ℕ} (hn : n ≠ 0) (hnsf : ¬Squarefree n) :
    sqfreeJ2Inv n = 0 := by
  simp [sqfreeJ2Inv, hn, hnsf]

-- ════════════════════════════════════════════════════════════════
-- §2. MULTIPLICATIVITY
-- ════════════════════════════════════════════════════════════════

/-- sqfreeJ2Inv is multiplicative. -/
theorem isMultiplicative_sqfreeJ2Inv :
    IsMultiplicative sqfreeJ2Inv := by
  rw [IsMultiplicative.iff_ne_zero]
  constructor
  · exact sqfreeJ2Inv_one
  · intro m n hm hn hmn
    by_cases hsm : Squarefree m
    · by_cases hsn : Squarefree n
      · have hsmn : Squarefree (m * n) := (squarefree_mul hmn).mpr ⟨hsm, hsn⟩
        rw [sqfreeJ2Inv_squarefree (mul_ne_zero hm hn) hsmn,
            sqfreeJ2Inv_squarefree hm hsm,
            sqfreeJ2Inv_squarefree hn hsn]
        unfold J₂ at *
        rw [Cathedral.Physics.BernoulliSkeleton.j2_mul_coprime hmn]
        rw [one_div, one_div, one_div, mul_inv, mul_comm]
      · have hsmn : ¬Squarefree (m * n) := by
          intro h; exact hsn h.of_mul_right
        rw [sqfreeJ2Inv_not_squarefree (mul_ne_zero hm hn) hsmn,
            sqfreeJ2Inv_not_squarefree hn hsn]
        ring
    · have hsmn : ¬Squarefree (m * n) := by
        intro h; exact hsm h.of_mul_left
      rw [sqfreeJ2Inv_not_squarefree (mul_ne_zero hm hn) hsmn,
          sqfreeJ2Inv_not_squarefree hm hsm]
      ring

-- ════════════════════════════════════════════════════════════════
-- §3. VALUES ON PRIME POWERS
-- ════════════════════════════════════════════════════════════════

/-- On primes: sqfreeJ2Inv(p) = 1/(p²-1). -/
theorem sqfreeJ2Inv_prime {p : ℕ} (hp : p.Prime) :
    sqfreeJ2Inv p = 1 / ((p : ℝ) ^ 2 - 1) := by
  rw [sqfreeJ2Inv_squarefree hp.ne_zero hp.squarefree,
      j2_eq_prod_sq_minus_one p hp.pos hp.squarefree]
  simp [hp.primeFactors]

/-- On higher prime powers (k ≥ 2): sqfreeJ2Inv(p^k) = 0. -/
theorem sqfreeJ2Inv_prime_pow_ge2 {p k : ℕ} (hp : p.Prime) (hk : 2 ≤ k) :
    sqfreeJ2Inv (p ^ k) = 0 := by
  have hne : p ^ k ≠ 0 := pow_ne_zero _ hp.ne_zero
  apply sqfreeJ2Inv_not_squarefree hne
  intro hsf
  have ⟨_, hk1⟩ := (squarefree_pow_iff hp.ne_one (by omega)).mp hsf
  omega

/-- sqfreeJ2Inv is nonneg. -/
theorem sqfreeJ2Inv_nonneg (n : ℕ) : 0 ≤ sqfreeJ2Inv n := by
  rcases eq_or_ne n 0 with rfl | hn
  · simp
  · rw [sqfreeJ2Inv_apply hn]
    split_ifs with hsf
    · exact div_nonneg zero_le_one (le_of_lt
        (Cathedral.Physics.BernoulliSkeleton.j2_pos n (Nat.pos_of_ne_zero hn)))
    · exact le_refl 0

/-- The Euler factor tsum: ∑' e, sqfreeJ2Inv(p^e) = 1 + 1/(p²-1). -/
theorem euler_factor_eq {p : ℕ} (hp : p.Prime) :
    ∑' e : ℕ, sqfreeJ2Inv (p ^ e) = 1 + 1 / ((p : ℝ) ^ 2 - 1) := by
  have h_sum : HasSum (fun e : ℕ => sqfreeJ2Inv (p ^ e))
      (1 + 1 / ((p : ℝ) ^ 2 - 1)) := by
    rw [show (1 : ℝ) + 1 / ((p : ℝ) ^ 2 - 1) =
        sqfreeJ2Inv (p ^ 0) + sqfreeJ2Inv (p ^ 1) from by
          simp [pow_zero, pow_one, sqfreeJ2Inv_one, sqfreeJ2Inv_prime hp]]
    apply hasSum_of_isLUB_of_nonneg
    · intro e; exact sqfreeJ2Inv_nonneg _
    · rw [IsLUB, IsLeast]
      constructor
      · intro s hs
        rw [Set.mem_range] at hs
        obtain ⟨T, rfl⟩ := hs
        -- Split into e < 2 and e ≥ 2 parts
        have key : ∑ e ∈ T, sqfreeJ2Inv (p ^ e) =
            ∑ e ∈ T.filter (· < 2), sqfreeJ2Inv (p ^ e) +
            ∑ e ∈ T.filter (fun e => ¬(e < 2)), sqfreeJ2Inv (p ^ e) :=
          (Finset.sum_filter_add_sum_filter_not T (· < 2) (fun e => sqfreeJ2Inv (p ^ e))).symm
        -- The e ≥ 2 part vanishes
        have h_tail : ∑ e ∈ T.filter (fun e => ¬(e < 2)), sqfreeJ2Inv (p ^ e) = 0 := by
          apply Finset.sum_eq_zero
          intro e he
          rw [Finset.mem_filter] at he
          exact sqfreeJ2Inv_prime_pow_ge2 hp (by omega)
        rw [key, h_tail, add_zero]
        -- The e < 2 part is a subset of {0, 1}
        rw [show sqfreeJ2Inv (p ^ 0) + sqfreeJ2Inv (p ^ 1) =
          ∑ e ∈ ({0, 1} : Finset ℕ), sqfreeJ2Inv (p ^ e) from
            by simp [Finset.sum_pair (by norm_num : (0 : ℕ) ≠ 1)]]
        apply Finset.sum_le_sum_of_subset_of_nonneg
        · intro e he
          rw [Finset.mem_filter] at he
          have h01 : e = 0 ∨ e = 1 := by omega
          rcases h01 with rfl | rfl <;> simp
        · intro e _ _; exact sqfreeJ2Inv_nonneg _
      · intro b hb
        apply hb
        rw [Set.mem_range]
        exact ⟨{0, 1}, by simp [Finset.sum_pair (by norm_num : (0 : ℕ) ≠ 1)]⟩
  exact h_sum.tsum_eq

/-- The Euler factor equals (1-1/p²)⁻¹ = p²/(p²-1). -/
theorem euler_factor_eq_inv {p : ℕ} (hp : p.Prime) :
    ∑' e : ℕ, sqfreeJ2Inv (p ^ e) = (1 - 1 / (p : ℝ) ^ 2)⁻¹ := by
  rw [euler_factor_eq hp]
  have hp_pos : (0 : ℝ) < (p : ℝ) := Nat.cast_pos.mpr hp.pos
  have hp2_pos : (0 : ℝ) < (p : ℝ) ^ 2 := pow_pos hp_pos 2
  have hp2_sub_pos : (0 : ℝ) < (p : ℝ) ^ 2 - 1 := by
    have : (1 : ℝ) < (p : ℝ) ^ 2 := by
      calc (1 : ℝ) < 2 ^ 2 := by norm_num
        _ ≤ (p : ℝ) ^ 2 := by
          apply pow_le_pow_left₀ (by positivity)
          exact Nat.cast_le.mpr hp.two_le
    linarith
  have hp2_ne : (p : ℝ) ^ 2 ≠ 0 := ne_of_gt hp2_pos
  have hp2_sub_ne : (p : ℝ) ^ 2 - 1 ≠ 0 := ne_of_gt hp2_sub_pos
  -- 1 + 1/(p²-1) = p²/(p²-1)
  have h1 : (1 : ℝ) + 1 / ((p : ℝ) ^ 2 - 1) =
      (p : ℝ) ^ 2 / ((p : ℝ) ^ 2 - 1) := by
    rw [show (1 : ℝ) + 1 / ((p : ℝ) ^ 2 - 1) =
      ((p : ℝ) ^ 2 - 1 + 1) / ((p : ℝ) ^ 2 - 1) from by
        rw [add_div]; congr 1; rw [div_self hp2_sub_ne]]
    congr 1; ring
  -- (1 - 1/p²)⁻¹ = p²/(p²-1)
  have h2 : (1 - 1 / (p : ℝ) ^ 2)⁻¹ = (p : ℝ) ^ 2 / ((p : ℝ) ^ 2 - 1) := by
    rw [show (1 : ℝ) - 1 / (p : ℝ) ^ 2 = ((p : ℝ) ^ 2 - 1) / (p : ℝ) ^ 2 from
      by rw [sub_div, div_self hp2_ne]]
    rw [inv_div]
  rw [h1, h2]

-- ════════════════════════════════════════════════════════════════
-- §4. SUMMABILITY — via comparison with 1/n^(3/2)
-- ════════════════════════════════════════════════════════════════

/-- J₂(n) ≥ n for all squarefree n ≥ 1.
    Proof: J₂(n) = ∏(p²-1) for sqfree n. Since p²-1 ≥ p for primes p ≥ 2,
    and n = ∏p for sqfree n, we get J₂(n) ≥ ∏p = n. -/
theorem j2_ge_n (n : ℕ) (hn : 0 < n) (hsf : Squarefree n) :
    (n : ℝ) ≤ J₂ n := by
  rw [j2_eq_prod_sq_minus_one n hn hsf]
  -- n = ∏ p for sqfree n
  have hd : (n : ℝ) = ∏ p ∈ n.primeFactors, (p : ℝ) := by
    rw [← Nat.cast_prod]
    exact congrArg Nat.cast (Nat.prod_primeFactors_of_squarefree hsf).symm
  rw [hd]
  apply Finset.prod_le_prod
  · intro p hp
    exact Nat.cast_nonneg p
  · intro p hp
    have hp_prime := (Nat.mem_primeFactors.mp hp).1
    have hp_ge : (2 : ℝ) ≤ (p : ℝ) := Nat.cast_le.mpr hp_prime.two_le
    -- p ≤ p² - 1 for p ≥ 2
    nlinarith

/-- Key arithmetic bound: (p:ℝ)³ ≤ ((p:ℝ)²-1)² for primes p ≥ 2.
    Proof: expand to p⁴ - 2p² + 1 - p³ = p²(p-2)(p+1) + 1 ≥ 1. -/
private theorem sq_sub_one_sq_ge_cube_real (p : ℕ) (hp : p.Prime) :
    (p : ℝ) ^ 3 ≤ ((p : ℝ) ^ 2 - 1) ^ 2 := by
  have hp2 : (2 : ℝ) ≤ (p : ℝ) := Nat.cast_le.mpr hp.two_le
  nlinarith [sq_nonneg ((p : ℝ) ^ 2 - (p : ℝ) - 1)]

/-- J₂(n)² ≥ n³ for squarefree n ≥ 1.
    From (p²-1)² ≥ p³ for each prime p, and multiplicativity. -/
theorem j2_sq_ge_cube (n : ℕ) (hn : 0 < n) (hsf : Squarefree n) :
    (n : ℝ) ^ 3 ≤ (J₂ n) ^ 2 := by
  rw [j2_eq_prod_sq_minus_one n hn hsf, ← Finset.prod_pow]
  have hd : (n : ℝ) = ∏ p ∈ n.primeFactors, (p : ℝ) := by
    rw [← Nat.cast_prod]
    exact congrArg Nat.cast (Nat.prod_primeFactors_of_squarefree hsf).symm
  rw [hd, ← Finset.prod_pow]
  apply Finset.prod_le_prod
  · intro p hp; positivity
  · intro p hp
    have hp_prime := (Nat.mem_primeFactors.mp hp).1
    exact sq_sub_one_sq_ge_cube_real p hp_prime

/-- sqfreeJ2Inv is norm-summable.
    Proof: J₂(n)² ≥ n³ implies J₂(n) ≥ n^(3/2), so
    sqfreeJ2Inv(n) ≤ n^(-3/2), and ∑ n^(-3/2) converges. -/
theorem summable_sqfreeJ2Inv : Summable (‖sqfreeJ2Inv ·‖) := by
  -- Compare with the convergent p-series ((n : ℝ)^(3/2))⁻¹
  have h_pseries : Summable (fun n : ℕ => ((n : ℝ) ^ (3/2 : ℝ))⁻¹) :=
    Real.summable_nat_rpow_inv.mpr (by norm_num : (1 : ℝ) < 3/2)
  refine Summable.of_nonneg_of_le (fun n => norm_nonneg _) ?_ h_pseries
  intro n
  rw [Real.norm_eq_abs, abs_of_nonneg (sqfreeJ2Inv_nonneg n)]
  rcases eq_or_ne n 0 with rfl | hn
  · simp [sqfreeJ2Inv]
  · rw [sqfreeJ2Inv_apply hn]
    split_ifs with hsf
    · -- squarefree case: 1/J₂(n) ≤ (n^(3/2))⁻¹
      have hn_pos : 0 < n := Nat.pos_of_ne_zero hn
      have hj2_pos := Cathedral.Physics.BernoulliSkeleton.j2_pos n hn_pos
      have hj2_sq := j2_sq_ge_cube n hn_pos hsf
      have hn_r : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr hn_pos
      -- J₂(n) ≥ n^(3/2) follows from J₂(n)² ≥ n³ = (n^(3/2))²
      have hrpow_sq : ((n : ℝ) ^ (3/2 : ℝ)) ^ 2 = (n : ℝ) ^ 3 := by
        rw [← Real.rpow_natCast ((n : ℝ) ^ (3/2 : ℝ)) 2,
            ← Real.rpow_mul hn_r.le]
        norm_num
      have h_sq_le : ((n : ℝ) ^ (3/2 : ℝ)) ^ 2 ≤ (J₂ n) ^ 2 := hrpow_sq ▸ hj2_sq
      have h_rpow_nonneg : (0 : ℝ) ≤ (n : ℝ) ^ (3/2 : ℝ) := Real.rpow_nonneg hn_r.le _
      have h_rpow_le : (n : ℝ) ^ (3/2 : ℝ) ≤ J₂ n := by
        nlinarith [sq_nonneg (J₂ n - (n : ℝ) ^ (3/2 : ℝ)),
                   sq_nonneg ((n : ℝ) ^ (3/2 : ℝ))]
      -- 1/J₂(n) ≤ 1/n^(3/2) = (n^(3/2))⁻¹
      simp only [inv_eq_one_div]
      exact one_div_le_one_div_of_le (Real.rpow_pos_of_pos hn_r _) h_rpow_le
    · positivity

-- ════════════════════════════════════════════════════════════════
-- §5. EULER PRODUCT FOR ζ(2) — from ℂ to ℝ
-- ════════════════════════════════════════════════════════════════

/-- The Euler product ∏' p, (1 - 1/p²)⁻¹ = π²/6 (in ℝ).

    This follows from the complex Euler product for ζ(2):
    riemannZeta_eulerProduct_hasProd gives
      HasProd (fun p => (1-(p:ℂ)^(-2))⁻¹) (riemannZeta 2)
    and riemannZeta_two gives riemannZeta 2 = (π²/6 : ℂ).

    We project from ℂ to ℝ using that all factors are positive reals. -/
theorem hasProd_inv_one_sub_inv_sq :
    HasProd (fun p : Primes => (1 - 1 / (p : ℝ) ^ 2)⁻¹) (π ^ 2 / 6) := by
  -- Step 1: Get the ℂ Euler product at s = 2
  have hC := riemannZeta_eulerProduct_hasProd (show 1 < (2 : ℂ).re by norm_num)
  rw [riemannZeta_two] at hC
  -- hC : HasProd (fun p : Primes => (1 - (p:ℂ)^(-(2:ℂ)))⁻¹) ((π:ℂ)^2/6)
  -- Step 2: Show the factors are equal
  -- Define the ℝ-valued function
  set f : Primes → ℝ := fun p => (1 - 1 / (p : ℝ) ^ 2)⁻¹ with hf_def
  -- We want: HasProd f (π^2/6)
  -- Strategy: show HasProd (ofReal ∘ f) (ofReal (π^2/6)) and use IsInducing
  suffices h : HasProd (Complex.ofReal ∘ f) (Complex.ofReal (π ^ 2 / 6)) by
    exact (isUniformEmbedding_ofReal.isInducing.hasProd_iff
      (g := (ofRealHom : ℝ →+* ℂ)) f (π ^ 2 / 6)).mp h
  -- Show the ℂ product matches
  -- First show the target value
  have htarget : ((π : ℂ) ^ 2 / 6 : ℂ) = Complex.ofReal (π ^ 2 / 6) := by push_cast; ring
  rw [htarget] at hC
  -- Now show factor equality and transfer
  apply hC.congr_fun
  intro ⟨p, hp⟩
  -- Factor equality: ofReal (f ⟨p,hp⟩) = (1 - (p:ℂ)^(-2))⁻¹
  simp only [Function.comp, hf_def]
  -- Goal: ↑(1 - 1 / ↑p ^ 2)⁻¹ = (1 - (↑p ^ 2)⁻¹)⁻¹
  -- where LHS ↑p is (p:ℕ):ℝ and RHS ↑p is (p:ℕ):ℂ
  -- Normalize 1/x to x⁻¹ on LHS, then push_cast unifies
  simp only [one_div]
  push_cast
  -- Remaining: (1 - (↑p^2)⁻¹)⁻¹ = (1 - ↑p^(-2))⁻¹ where (-2) is cpow
  -- Convert cpow(-2) to (↑p^2)⁻¹ on the RHS
  have hp_ne_c : (p : ℂ) ≠ 0 := Nat.cast_ne_zero.mpr hp.ne_zero
  have : (p : ℂ) ^ (-(2 : ℂ)) = ((p : ℂ) ^ 2)⁻¹ := by
    rw [show (-(2 : ℂ)) = ((-2 : ℤ) : ℂ) from by push_cast; ring,
        cpow_intCast, zpow_neg]
    norm_cast
  rw [this]

-- ════════════════════════════════════════════════════════════════
-- §6. THE MAIN THEOREM
-- ════════════════════════════════════════════════════════════════

/-- The Euler product: ∏' p, (∑' e, sqfreeJ2Inv(p^e)) = ∑' n, sqfreeJ2Inv n. -/
theorem euler_product_hasProd :
    HasProd (fun p : Primes => ∑' e : ℕ, sqfreeJ2Inv (p ^ e))
      (∑' n : ℕ, sqfreeJ2Inv n) :=
  isMultiplicative_sqfreeJ2Inv.eulerProduct_hasProd summable_sqfreeJ2Inv

/-- Each Euler factor equals (1-1/p²)⁻¹. -/
theorem euler_product_factor_eq :
    (fun p : Primes => ∑' e : ℕ, sqfreeJ2Inv (p ^ e)) =
    (fun p : Primes => (1 - 1 / (p : ℝ) ^ 2)⁻¹) := by
  ext ⟨p, hp⟩
  exact euler_factor_eq_inv hp

/-- **MAIN THEOREM**: Σ_{d sqfree} 1/J₂(d) = π²/6.

    Proof chain:
    1. sqfreeJ2Inv is multiplicative (isMultiplicative_sqfreeJ2Inv)
    2. Euler product: ∏' p, (∑' e, f(p^e)) = ∑' n, f(n)
    3. Each Euler factor = (1-1/p²)⁻¹
    4. Product = π²/6 (hasProd_inv_one_sub_inv_sq)
    5. HasProd uniqueness: tsum = π²/6
    6. Convert tsum to HasSum -/
theorem squarefree_reciprocal_j2_sum :
    HasSum (fun d : ℕ => if d = 0 then 0
      else if Squarefree d then 1 / J₂ d else 0)
    (π ^ 2 / 6) := by
  -- Step 1: Show the function matches sqfreeJ2Inv
  have h_eq : (fun d : ℕ => if d = 0 then 0
    else if Squarefree d then 1 / J₂ d else 0) = sqfreeJ2Inv := by
    ext d; simp [sqfreeJ2Inv]
  rw [h_eq]
  -- Step 2: Get the Euler product
  have h_prod := euler_product_hasProd
  rw [euler_product_factor_eq] at h_prod
  -- Step 3: The product equals π²/6
  have h_val := hasProd_inv_one_sub_inv_sq
  -- Step 4: HasProd uniqueness gives the tsum value
  have h_tsum : ∑' n : ℕ, sqfreeJ2Inv n = π ^ 2 / 6 := by
    have := h_prod.tprod_eq
    rw [h_val.tprod_eq] at this
    exact this.symm
  -- Step 5: Convert tsum to HasSum
  exact h_tsum ▸ (summable_sqfreeJ2Inv.of_norm).hasSum

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit

### Status: 0 sorry — GRADUATION TARGET

| # | Result | Status |
|---|--------|--------|
| 1 | `sqfreeJ2Inv` | 📐 DEFINITION |
| 2 | `sqfreeJ2Inv_one` | 🎓 PROVED |
| 3 | `sqfreeJ2Inv_prime` | 🎓 PROVED |
| 4 | `sqfreeJ2Inv_prime_pow_ge2` | 🎓 PROVED |
| 5 | `sqfreeJ2Inv_nonneg` | 🎓 PROVED |
| 6 | `isMultiplicative_sqfreeJ2Inv` | 🎓 PROVED |
| 7 | `euler_factor_eq` | 🎓 PROVED (1 + 1/(p²-1)) |
| 8 | `euler_factor_eq_inv` | 🎓 PROVED (= (1-1/p²)⁻¹) |
| 9 | `j2_ge_n` | 🎓 PROVED (J₂(n) ≥ n for sqfree n) |
| 10 | `sq_sub_one_sq_ge_cube` | 🎓 PROVED ((p²-1)² ≥ p³) |
| 11 | `j2_sq_ge_cube` | 🎓 PROVED (J₂(n)² ≥ n³) |
| 12 | `summable_sqfreeJ2Inv` | 🎓 PROVED (comparison with n^(-3/2)) |
| 13 | `hasProd_inv_one_sub_inv_sq` | 🎓 PROVED (ℂ→ℝ Euler projection) |
| 14 | `euler_product_hasProd` | 🎓 PROVED (from Mathlib) |
| 15 | `euler_product_factor_eq` | 🎓 PROVED |
| 16 | `squarefree_reciprocal_j2_sum` | 🎓 PROVED (main theorem) |

### Proof Strategy for Key Results:

1. **`summable_sqfreeJ2Inv`** (norm summability):
   - Bound ‖sqfreeJ2Inv(n)‖ ≤ C/n^{3/2} using J₂(n) ≥ n·√(n/2)
   - Use `summable_nat_rpow_inv` for comparison
   - Alternative: Rankin's trick or Dirichlet series convergence

2. **`hasProd_inv_one_sub_inv_sq`** (∏(1-1/p²)⁻¹ = π²/6):
   - Use `riemannZeta_eulerProduct_hasProd` at s=2 (ℂ)
   - `riemannZeta_two : riemannZeta 2 = (π:ℂ)²/6`
   - Project ℂ HasProd to ℝ HasProd (all factors are positive reals)

3. **`j2_ge_n_times_totient`** (J₂ lower bound):
   - J₂(n) = ∏(p²-1) ≥ ∏p(p-1) = n·φ(n)
   - Combined with φ(n) ≥ √(n/2) gives J₂(n) ≥ n·√(n/2)
-/

end Cathedral.NumberTheory.SquarefreeJ2Sum

end
