/-
  Cathedral/Physics/RamanujanBridge.lean

  ## THE RAMANUJAN GRAM MATRIX: gcd(j,k)²/(12·j·k)

  ════════════════════════════════════════════════════════════════

  The classical Ramanujan integral identity:

    ∫₀¹ B̃₁(jt) · B̃₁(kt) dt = gcd(j,k)² / (12·j·k)

  where B̃₁(x) = {x} - 1/2 is the periodized first Bernoulli polynomial.

  This defines a THIRD Gram-like matrix R that sits between the positive
  Gram matrix G⁽¹⁾ and the dark Gram matrix G⁽²⁾:

    R_{j,k}  = gcd(j,k)²/(12·j·k)     — gcd² structure
    G⁽²⁾_{j,k} = gcd(j,k)⁴/(180·j²·k²) — gcd⁴ structure

  Key relationship:
    R_{j,k} = 15 · (j·k / gcd(j,k)²) · G⁽²⁾_{j,k}

  ### Proof Strategy (Fourier Series)

  The Fourier series of B̃₁(x) = {x} - 1/2 is:
    B̃₁(x) = -Σ_{n=1}^∞ sin(2πnx)/(πn)

  So:
    ∫₀¹ B̃₁(jt)·B̃₁(kt)dt = Σ_{n,m} 1/(π²nm) ∫₀¹ sin(2πnjt)sin(2πmkt)dt

  By orthogonality: ∫₀¹ sin(2πat)sin(2πbt)dt = δ_{a,b}/2.
  The condition nj = mk (with j = d·j', k = d·k', gcd(j',k')=1) gives
  solutions n = k'r, m = j'r for r = 1,2,...

  The sum becomes:
    Σ_{r=1}^∞ 1/(2π²·k'r·j'r) = 1/(2π²·j'k') · ζ(2) = 1/(12·j'k')

  Since j'k' = jk/d², we get gcd(j,k)²/(12jk). ∎

  ### PSD Structure

  R is positive-semidefinite via the Jordan/Euler decomposition:
    gcd(j,k)² = Σ_{d|gcd(j,k)} J₂(d)

  where J₂(d) = d² · ∏_{p|d}(1-1/p²) is Jordan's totient of order 2.
  Since J₂(d) > 0 for all d ≥ 1, the same Smith rank-1 argument applies.

  Status: CERTIFIED — algebraic definition matches analytic integral
  Dependencies: DarkGramMatrix, RamanujanInnerProduct
  Created: May 15, 2026 — The Ramanujan Bridge Session
-/

import Cathedral.Physics.DarkGramMatrix
import Cathedral.Spectral.RamanujanInnerProduct

noncomputable section
open Real Finset

namespace Cathedral.Physics.RamanujanBridge

-- ════════════════════════════════════════════════════════════════
-- §1. THE RAMANUJAN GRAM ENTRY
-- ════════════════════════════════════════════════════════════════

/-- **DEFINITION**: The Ramanujan Gram entry.

    R(j,k) = gcd(j,k)² / (12 · j · k)

    This is the inner product ∫₀¹ B̃₁(jt)·B̃₁(kt)dt of
    periodized first Bernoulli polynomials.

    Physical interpretation: R measures the "first-order resonance"
    between frequencies j and k. It captures the gcd²/(jk) scaling
    that dominates the arithmetic structure. -/
noncomputable def ramanujanEntry (j k : ℕ) : ℝ :=
  (Nat.gcd j k : ℝ) ^ 2 / (12 * (j : ℝ) * (k : ℝ))

-- ════════════════════════════════════════════════════════════════
-- §2. BASIC PROPERTIES
-- ════════════════════════════════════════════════════════════════

/-- R is symmetric. -/
theorem ramanujan_symmetric (j k : ℕ) :
    ramanujanEntry j k = ramanujanEntry k j := by
  unfold ramanujanEntry; rw [Nat.gcd_comm]; ring

/-- R is nonneg. -/
theorem ramanujan_nonneg (j k : ℕ) (hj : 0 < j) (hk : 0 < k) :
    0 ≤ ramanujanEntry j k := by
  unfold ramanujanEntry
  positivity

/-- R is strictly positive for j, k ≥ 1. -/
theorem ramanujan_pos (j k : ℕ) (hj : 0 < j) (hk : 0 < k) :
    0 < ramanujanEntry j k := by
  unfold ramanujanEntry
  apply div_pos
  · exact sq_pos_of_pos (Nat.cast_pos.mpr (Nat.gcd_pos_of_pos_left k hj))
  · apply mul_pos; apply mul_pos
    · positivity
    · exact Nat.cast_pos.mpr hj
    · exact Nat.cast_pos.mpr hk

/-- The diagonal: R(k,k) = k/(12) = 1/12 · k⁰... wait.
    gcd(k,k) = k, so R(k,k) = k²/(12k²) = 1/12. -/
theorem ramanujan_diagonal (k : ℕ) (hk : 0 < k) :
    ramanujanEntry k k = 1 / 12 := by
  unfold ramanujanEntry; rw [Nat.gcd_self]
  have hk_ne : (k : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  field_simp

/-- Coprime entry: R(j,k) = 1/(12jk) when gcd(j,k) = 1. -/
theorem ramanujan_coprime (j k : ℕ) (h : Nat.Coprime j k) :
    ramanujanEntry j k = 1 / (12 * (j : ℝ) * (k : ℝ)) := by
  unfold ramanujanEntry; rw [Nat.Coprime.gcd_eq_one h]; simp

-- ════════════════════════════════════════════════════════════════
-- §3. RELATIONSHIP TO DARK GRAM
-- ════════════════════════════════════════════════════════════════

/-- **KEY THEOREM**: The entrywise relationship between R and G⁽²⁾.

    R(j,k) = 15 · (j · k / gcd(j,k)²) · G⁽²⁾(j,k)

    Equivalently, writing j = d·j', k = d·k' with gcd(j',k')=1:
    R(j,k) = 15 · j' · k' · G⁽²⁾(j,k)

    This shows R and G⁽²⁾ have the SAME sign structure (both positive)
    but R gives MORE weight to coprime pairs (where j'k' is large)
    and LESS weight to divisor pairs (where j'k' = j/k is small). -/
theorem ramanujan_vs_dark (j k : ℕ) (hj : 0 < j) (hk : 0 < k) :
    ramanujanEntry j k =
    15 * ((j : ℝ) * (k : ℝ) / (Nat.gcd j k : ℝ) ^ 2) *
    DarkGramMatrix.darkGramEntry_n2 j k := by
  unfold ramanujanEntry DarkGramMatrix.darkGramEntry_n2
  have hj_ne : (j : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hk_ne : (k : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have hg_ne : (Nat.gcd j k : ℝ) ≠ 0 :=
    Nat.cast_ne_zero.mpr (Nat.gcd_pos_of_pos_left k hj).ne'
  field_simp
  ring

-- ════════════════════════════════════════════════════════════════
-- §3.5. THE GLASS: ANALYTIC CERTIFICATION
-- ════════════════════════════════════════════════════════════════

/-- **THE GLASS**: The algebraic definition `ramanujanEntry` equals
    the certified analytic integral `sawtoothInnerProduct`.

    ramanujanEntry(j,k) = ∫₀¹ B₁({jt})·B₁({kt}) dt

    This is the connection between the algebraic dark-sector
    infrastructure (GCD arithmetic) and the analytic positive-sector
    infrastructure (actual integrals). The RHS was proved = gcd²/(12jk)
    in RamanujanInnerProduct.lean. -/
theorem ramanujan_entry_eq_integral (j k : ℕ) (hj : 0 < j) (hk : 0 < k) :
    ramanujanEntry j k =
    Cathedral.RamanujanInnerProduct.sawtoothInnerProduct j k := by
  unfold ramanujanEntry
  rw [Cathedral.RamanujanInnerProduct.sawtooth_inner_product j k hj hk]

/-- **THE GLASS (Positive Sector)**: The positive Gram entry
    ∫₀¹ {jt}·{kt} dt decomposes as ramanujanEntry + 1/4.

    G⁽¹⁾(j,k) = R(j,k) + 1/4
             = 15·j'k'·G⁽²⁾(j,k) + 1/4

    This connects the positive sector directly to the dark crystal. -/
theorem positive_gram_via_ramanujan (j k : ℕ) (hj : 0 < j) (hk : 0 < k) :
    ∫ t in (0:ℝ)..1, Int.fract (↑j * t) * Int.fract (↑k * t) =
    ramanujanEntry j k + 1 / 4 := by
  rw [Cathedral.RamanujanInnerProduct.fract_inner_product j k hj hk]
  simp only [ramanujanEntry]

/-- **THE FULL GLASS**: The positive Gram entry expressed via dark Gram.

    G⁽¹⁾(j,k) = 15·(jk/gcd²)·G⁽²⁾(j,k) + 1/4

    This is the **complete S-duality bridge** — the positive sector
    expressed entirely in terms of the dark crystal and GCD arithmetic. -/
theorem positive_gram_via_dark (j k : ℕ) (hj : 0 < j) (hk : 0 < k) :
    ∫ t in (0:ℝ)..1, Int.fract (↑j * t) * Int.fract (↑k * t) =
    15 * ((j : ℝ) * (k : ℝ) / (Nat.gcd j k : ℝ) ^ 2) *
      DarkGramMatrix.darkGramEntry_n2 j k + 1 / 4 := by
  rw [positive_gram_via_ramanujan j k hj hk, ramanujan_vs_dark j k hj hk]

-- ════════════════════════════════════════════════════════════════
-- §4. JORDAN'S TOTIENT J₂ AND SMITH DECOMPOSITION
-- ════════════════════════════════════════════════════════════════

/-- **DEFINITION**: Jordan's Totient J₂(d) = d² · ∏_{p|d}(1 - 1/p²).

    This is the order-2 generalization of Euler's totient φ = J₁.
    The Dirichlet identity: Σ_{d|n} J₂(d) = n². -/
noncomputable def jordanTotient2 (d : ℕ) : ℝ :=
  (d : ℝ) ^ 2 * ∏ p ∈ d.primeFactors, (1 - 1 / (p : ℝ) ^ 2)

/-- J₂(1) = 1. -/
theorem jordan2_one : jordanTotient2 1 = 1 := by
  unfold jordanTotient2; simp [Nat.primeFactors]

/-- J₂(d) > 0 for all d ≥ 1.
    Since 1 - 1/p² > 0 for primes p ≥ 2 (as p² ≥ 4 > 1). -/
theorem jordan2_pos (d : ℕ) (hd : 0 < d) : 0 < jordanTotient2 d := by
  unfold jordanTotient2
  apply mul_pos
  · positivity
  · apply Finset.prod_pos
    intro p hp
    have hp_prime := (Nat.mem_primeFactors.mp hp).1
    have hp2 : 2 ≤ p := hp_prime.two_le
    have hp_pos : (0 : ℝ) < (p : ℝ) := by positivity
    rw [sub_pos, div_lt_one (by positivity)]
    calc (1 : ℝ) < 2 ^ 2 := by norm_num
      _ ≤ (p : ℝ) ^ 2 := by
        apply pow_le_pow_left₀ (by positivity : (0 : ℝ) ≤ 2)
        exact Nat.cast_le.mpr hp2

-- ── ArithmeticFunction machinery for J₂ ──

open ArithmeticFunction in
private noncomputable def jordanTotient2AF : ArithmeticFunction ℝ :=
  ⟨fun d => if d = 0 then 0 else jordanTotient2 d, by simp⟩

private theorem jordanTotient2AF_apply {d : ℕ} (hd : d ≠ 0) :
    jordanTotient2AF d = jordanTotient2 d := if_neg hd

private theorem jordanTotient2_mul_coprime {a b : ℕ}
    (hab : Nat.Coprime a b) :
    jordanTotient2 (a * b) = jordanTotient2 a * jordanTotient2 b := by
  unfold jordanTotient2
  by_cases ha : a = 0
  · simp [ha]
  by_cases hb : b = 0
  · simp [hb]
  rw [Nat.cast_mul, mul_pow, Nat.primeFactors_mul ha hb,
      Finset.prod_union hab.disjoint_primeFactors]
  ring

open ArithmeticFunction in
private theorem isMultiplicative_jordanTotient2AF :
    IsMultiplicative jordanTotient2AF := by
  rw [IsMultiplicative.iff_ne_zero]
  constructor
  · simp [jordanTotient2AF, jordan2_one]
  · intro m n hm hn hmn
    simp only [jordanTotient2AF_apply hm, jordanTotient2AF_apply hn,
               jordanTotient2AF_apply (mul_ne_zero hm hn)]
    exact jordanTotient2_mul_coprime hmn

theorem jordanTotient2_prime_pow (p k : ℕ) (hp : p.Prime) (hk : 0 < k) :
    jordanTotient2 (p ^ k) =
      (p : ℝ) ^ (2 * k) - (p : ℝ) ^ (2 * (k - 1)) := by
  unfold jordanTotient2
  rw [Nat.primeFactors_prime_pow hk.ne' hp, Finset.prod_singleton, Nat.cast_pow]
  have hp_ne : (p : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr hp.ne_zero
  rw [pow_mul' (p : ℝ) 2 k, pow_mul' (p : ℝ) 2 (k - 1)]
  obtain ⟨m, hm⟩ := Nat.exists_eq_succ_of_ne_zero hk.ne'
  subst hm
  simp only [Nat.succ_sub_one, pow_succ]
  field_simp

/-- J₂(p) = p² - 1 for prime p. -/
theorem jordan2_prime (p : ℕ) (hp : p.Prime) :
    jordanTotient2 p = (p : ℝ) ^ 2 - 1 := by
  rw [show p = p ^ 1 from (pow_one p).symm, jordanTotient2_prime_pow p 1 hp (by omega)]
  simp

private theorem jordan2_sum_prime_pow (p k : ℕ) (hp : p.Prime) (hk : 0 < k) :
    ∑ d ∈ (p ^ k).divisors, jordanTotient2 d = (p : ℝ) ^ (2 * k) := by
  rw [Nat.sum_divisors_prime_pow hp]
  induction k with
  | zero => omega
  | succ n ih =>
    rw [Finset.sum_range_succ]
    by_cases hn : n = 0
    · subst hn
      simp only [Finset.sum_range_succ, Finset.sum_range_zero, pow_zero]
      rw [jordan2_one, jordanTotient2_prime_pow p 1 hp (by omega)]
      simp
    · have hn_pos : 0 < n := Nat.pos_of_ne_zero hn
      rw [ih hn_pos, jordanTotient2_prime_pow p (n + 1) hp (by omega)]
      simp only [Nat.succ_sub_one]
      ring

open ArithmeticFunction ArithmeticFunction.zeta in
private theorem zeta_mul_jordan2_eq_pow2_on_prime_powers (p i : ℕ) (hp : p.Prime) :
    (ζ * jordanTotient2AF) (p ^ i) = ArithmeticFunction.pow 2 (p ^ i) := by
  rw [ArithmeticFunction.coe_zeta_mul_apply]
  have hdiv : ∀ d ∈ (p ^ i).divisors, jordanTotient2AF d = jordanTotient2 d := by
    intro d hd
    exact jordanTotient2AF_apply (Nat.pos_of_mem_divisors hd).ne'
  rw [Finset.sum_congr rfl hdiv]
  rcases Nat.eq_zero_or_pos i with rfl | hi
  · simp [jordan2_one, ArithmeticFunction.pow_apply]
  · rw [jordan2_sum_prime_pow p i hp hi]
    simp only [ArithmeticFunction.pow_apply]
    rw [if_neg (by omega : ¬(2 = 0 ∧ p ^ i = 0))]
    push_cast
    rw [pow_mul']

open ArithmeticFunction ArithmeticFunction.zeta in
private theorem zeta_mul_jordan2_eq_pow2 :
    (ζ : ArithmeticFunction ℝ) * jordanTotient2AF =
      (ArithmeticFunction.pow 2 : ArithmeticFunction ℕ) := by
  ext n
  rcases Nat.eq_zero_or_pos n with rfl | hn
  · simp
  · have hf : IsMultiplicative ((ζ : ArithmeticFunction ℝ) * jordanTotient2AF) :=
      isMultiplicative_zeta.natCast (R := ℝ) |>.mul isMultiplicative_jordanTotient2AF
    have hg : IsMultiplicative ((↑(ArithmeticFunction.pow 2 : ArithmeticFunction ℕ) : ArithmeticFunction ℝ)) :=
      isMultiplicative_pow.natCast
    rw [hf.multiplicative_factorization _ hn.ne', hg.multiplicative_factorization _ hn.ne']
    apply Finsupp.prod_congr
    intro p hp
    have hprime : p.Prime := Nat.prime_of_mem_primeFactors hp
    exact zeta_mul_jordan2_eq_pow2_on_prime_powers p _ hprime

open ArithmeticFunction ArithmeticFunction.zeta in
theorem jordan2_dirichlet_identity (n : ℕ) (hn : 0 < n) :
    ∑ d ∈ n.divisors, jordanTotient2 d = (n : ℝ) ^ 2 := by
  have key : ((ζ : ArithmeticFunction ℝ) * jordanTotient2AF) n =
      ((ArithmeticFunction.pow 2 : ArithmeticFunction ℕ) : ArithmeticFunction ℝ) n :=
    congr_fun (congr_arg DFunLike.coe zeta_mul_jordan2_eq_pow2) n
  rw [ArithmeticFunction.coe_zeta_mul_apply] at key
  have hdiv : ∀ d ∈ n.divisors, jordanTotient2AF d = jordanTotient2 d := by
    intro d hd
    exact jordanTotient2AF_apply (Nat.pos_of_mem_divisors hd).ne'
  rw [Finset.sum_congr rfl hdiv] at key
  simp [ArithmeticFunction.pow_apply, hn.ne'] at key
  exact_mod_cast key

/-- gcd(j,k)² = Σ_{d|gcd(j,k)} J₂(d). -/
theorem gcd_pow2_jordan2_decomposition (j k : ℕ) (hj : 0 < j) (_hk : 0 < k) :
    (Nat.gcd j k : ℝ) ^ 2 = ∑ d ∈ (Nat.gcd j k).divisors, jordanTotient2 d :=
  (jordan2_dirichlet_identity (Nat.gcd j k) (Nat.gcd_pos_of_pos_left k hj)).symm

set_option linter.unnecessarySeqFocus false in
set_option maxHeartbeats 400000 in
/-- **THEOREM**: The Ramanujan matrix is PSD.

    Σ_{i,j} gcd(i+1, j+1)² · x_i · x_j ≥ 0

    Proof: Same Smith rank-1 argument as for gcd⁴.
    gcd(j,k)² = Σ_d J₂(d), so Q(x) = Σ_d J₂(d)·(Σ_i 𝟙_{d|i+1} x_i)² ≥ 0.

    The decomposition identity is extracted as gcd2_sos_decomposition.

    **J₂ SOS Decomposition**: the gcd² quadratic form equals a sum of J₂-weighted squares. -/
theorem gcd2_sos_decomposition (N : ℕ) (x : Fin N → ℝ) :
    ∑ i : Fin N, ∑ j : Fin N,
      (Nat.gcd (i.val + 1) (j.val + 1) : ℝ) ^ 2 * x i * x j =
    ∑ d ∈ Finset.Icc 1 N,
      jordanTotient2 d * (∑ i : Fin N, if d ∣ (i.val + 1) then x i else 0) ^ 2 := by
  set y : ℕ → ℝ := fun d => ∑ i : Fin N, if d ∣ (i.val + 1) then x i else 0
  have ysq : ∀ d, (y d) ^ 2 =
      ∑ i : Fin N, ∑ j : Fin N,
        (if d ∣ (i.val + 1) then x i else 0) * (if d ∣ (j.val + 1) then x j else 0) := by
    intro d; rw [sq]; simp only [y]; exact Fintype.sum_mul_sum _ _
  change _ = ∑ d ∈ Finset.Icc 1 N, jordanTotient2 d * (y d) ^ 2
  simp_rw [ysq, Finset.mul_sum]
  rw [Finset.sum_comm (s := Finset.Icc 1 N) (t := Finset.univ)]
  simp_rw [Finset.sum_comm (s := Finset.Icc 1 N) (t := Finset.univ)]
  congr 1; ext i; congr 1; ext j
  rw [show (Nat.gcd (i.val + 1) (j.val + 1) : ℝ) ^ 2 * x i * x j =
    (∑ d ∈ (Nat.gcd (i.val + 1) (j.val + 1)).divisors, jordanTotient2 d) * x i * x j from by
      rw [jordan2_dirichlet_identity _ (Nat.gcd_pos_of_pos_left _ (by omega))]]
  have hlift : ∑ d ∈ (Nat.gcd (i.val + 1) (j.val + 1)).divisors, jordanTotient2 d =
      ∑ d ∈ Finset.Icc 1 N,
        if d ∣ (i.val + 1) ∧ d ∣ (j.val + 1) then jordanTotient2 d else 0 := by
    rw [← Finset.sum_filter]
    apply Finset.sum_congr
    · ext d
      rw [Finset.mem_filter]
      constructor
      · intro hd
        have hd_pos := Nat.pos_of_mem_divisors hd
        have hd_dvd := Nat.dvd_of_mem_divisors hd
        have hd_le : d ≤ N := by
          have := Nat.le_of_dvd (by omega) (dvd_trans hd_dvd (Nat.gcd_dvd_left _ _))
          omega
        exact ⟨Finset.mem_Icc.mpr ⟨hd_pos, hd_le⟩,
               (DarkGramMatrix.mem_gcd_divisors_iff (by omega) (by omega)).mp hd⟩
      · intro ⟨_, hdvd⟩
        exact (DarkGramMatrix.mem_gcd_divisors_iff (by omega) (by omega)).mpr hdvd
    · intro _ _; rfl
  rw [hlift, Finset.sum_mul, Finset.sum_mul]
  congr 1; ext d
  split_ifs <;> simp_all <;> try ring

theorem gcd2_matrix_psd (N : ℕ) (x : Fin N → ℝ) :
    0 ≤ ∑ i : Fin N, ∑ j : Fin N,
      (Nat.gcd (i.val + 1) (j.val + 1) : ℝ) ^ 2 * x i * x j := by
  rw [gcd2_sos_decomposition]
  apply Finset.sum_nonneg
  intro d hd
  apply mul_nonneg
  · exact le_of_lt (jordan2_pos d (by rw [Finset.mem_Icc] at hd; omega))
  · exact sq_nonneg _

/-- **THEOREM**: The Ramanujan matrix is PSD.

    Σ_{i,j} R(i+1, j+1) · x_i · x_j ≥ 0

    Follows from gcd2_matrix_psd by factoring out 1/12. -/
theorem ramanujan_matrix_psd (N : ℕ) (x : Fin N → ℝ) :
    0 ≤ ∑ i : Fin N, ∑ j : Fin N,
      ramanujanEntry (i.val + 1) (j.val + 1) * x i * x j := by
  -- R(j,k) = gcd²/(12jk). Factor: R(j,k)·xᵢ·xⱼ = (1/12)·gcd²·(xᵢ/j)·(xⱼ/k).
  -- Set zᵢ = xᵢ/(i+1), then Σ R·x·x = (1/12)·Σ gcd²·z·z ≥ 0.
  set z : Fin N → ℝ := fun i => x i / (i.val + 1 : ℝ)
  have hconv : ∀ (i j : Fin N),
      ramanujanEntry (i.val + 1) (j.val + 1) * x i * x j =
      (1 / 12) * ((Nat.gcd (i.val + 1) (j.val + 1) : ℝ) ^ 2 * z i * z j) := by
    intro i j
    unfold ramanujanEntry
    simp only [z]
    have hi_ne : ((i.val + 1 : ℕ) : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
    have hj_ne : ((j.val + 1 : ℕ) : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
    rw [show (i.val + 1 : ℝ) = ((i.val + 1 : ℕ) : ℝ) from by push_cast; ring]
    rw [show (j.val + 1 : ℝ) = ((j.val + 1 : ℕ) : ℝ) from by push_cast; ring]
    field_simp
  simp_rw [hconv, ← Finset.mul_sum]
  apply mul_nonneg
  · norm_num
  · exact gcd2_matrix_psd N z

-- ════════════════════════════════════════════════════════════════
-- §5. THE S-DUALITY GLASS FOR J₂ ↔ J₄
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: J₂ and J₄ are related by the glass factor.

    J₄(d) = J₂(d) · d² · ∏_{p|d}(1 + 1/p²)⁻¹  ... actually:

    J₂(d) = d² · ∏(1-1/p²)
    J₄(d) = d⁴ · ∏(1-1/p⁴)
           = d⁴ · ∏(1-1/p²)(1+1/p²)
           = d² · J₂(d) · ∏(1+1/p²)

    So J₄(d) = d² · J₂(d) · glassFactor_product(d).

    This means the dark PSD is "amplified" relative to the Ramanujan
    PSD by the d² · glass factor. For large d, this amplification
    grows like d², explaining why divisor pairs are stronger in dark. -/
theorem jordan4_from_jordan2 (d : ℕ) (_hd : 0 < d) :
    DarkGramMatrix.jordanTotient4 d =
    jordanTotient2 d * (d : ℝ) ^ 2 *
      ∏ p ∈ d.primeFactors, (1 + 1 / (p : ℝ) ^ 2) := by
  unfold DarkGramMatrix.jordanTotient4 jordanTotient2
  -- Factor: (1 - 1/p⁴) = (1 - 1/p²)(1 + 1/p²) at each prime
  have hfactor : ∀ p ∈ d.primeFactors,
      (1 : ℝ) - 1 / (p : ℝ) ^ 4 = (1 - 1 / (p : ℝ) ^ 2) * (1 + 1 / (p : ℝ) ^ 2) := by
    intro p hp
    have hp_ne : (p : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (Nat.Prime.ne_zero (Nat.mem_primeFactors.mp hp).1)
    have hp2_ne : (p : ℝ) ^ 2 ≠ 0 := pow_ne_zero _ hp_ne
    have hp4_ne : (p : ℝ) ^ 4 ≠ 0 := pow_ne_zero _ hp_ne
    field_simp
    ring
  rw [Finset.prod_congr rfl hfactor, Finset.prod_mul_distrib]
  ring

-- ════════════════════════════════════════════════════════════════
-- §6. THE INTERPOLATION CHAIN: R → G⁽²⁾ → CROWN
-- ════════════════════════════════════════════════════════════════

/-! ### The Interpolation Chain

  We now have THREE matrices with gcd-power structure:

  | Matrix | Entry | GCD power | Diagonal | PSD? |
  |--------|-------|-----------|----------|------|
  | R      | gcd²/(12jk) | 2 | 1/12 (constant!) | YES |
  | G⁽²⁾  | gcd⁴/(180j²k²) | 4 | 1/180 (constant!) | YES (proved) |
  | G⁽¹⁾  | Vasyunin cotangent | mixed | c/k - 1/k² (decaying) | YES (proved) |

  KEY OBSERVATION: Both R and G⁽²⁾ have CONSTANT diagonals!
  R(k,k) = 1/12 and G⁽²⁾(k,k) = 1/180.
  The positive G⁽¹⁾ is the ONLY one with a decaying diagonal.

  This means:
  1. R and G⁽²⁾ are "thermally equilibrated" — equal self-energy at all modes
  2. G⁽¹⁾ privileges small k — the UV modes carry more self-energy
  3. The comparison G⁽¹⁾ ↔ R must account for this UV enhancement

  ### The UV-IR Split Strategy

  Partition modes into UV (k ≤ K) and IR (k > K) for some cutoff K.

  **UV modes** (k ≤ K): G⁽¹⁾(k,k) ≈ c/k ≫ R(k,k) = 1/12
    → The positive sector is UV-dominated
    → But the witness entries |v_k| ≤ 1 are bounded, so the UV
      contribution to vᵀG⁽¹⁾v is ≤ C·Σ_{k≤K} 1/k ≈ C·ln(K)

  **IR modes** (k > K): G⁽¹⁾(k,k) ≈ c/k ≪ R(k,k) = 1/12
    → The Ramanujan matrix DOMINATES in the IR
    → Ramanujan PSD gives vᵀRv|_IR ≥ 0, bounding the IR contribution

  The UV-IR split at K = O(lnN) would give:
    UV contribution: O(ln(lnN)) — negligible
    IR contribution: bounded by Ramanujan PSD
    Total: vᵀG⁽¹⁾v ≤ C·ln(lnN) + IR_bound → 0? Not quite...

  Actually the UV contribution from the diagonal alone is:
    D_UV = Σ_{k≤K} v_k² · c/k ≈ c · ln(K)
  which is O(ln(lnN)) if K = lnN. This is small but doesn't → 0.
-/

/-- The Ramanujan trace: Σ R(k,k) = N/12. -/
theorem ramanujan_trace (N : ℕ) :
    (Finset.range N).sum (fun k => ramanujanEntry (k + 1) (k + 1)) =
    N / 12 := by
  simp only [ramanujan_diagonal _ (Nat.succ_pos _)]
  simp [Finset.sum_const, Finset.card_range]
  ring

-- ════════════════════════════════════════════════════════════════
-- §7. THE GLASS DECOMPOSITION OF THE QUADRATIC FORM
-- ════════════════════════════════════════════════════════════════

/-! ### The Quadratic Form Decomposition

  Since G⁽¹⁾(j,k) = R(j,k) + 1/4, we get for any vector v:

      Σᵢⱼ G⁽¹⁾(i,j)·vᵢ·vⱼ = Σᵢⱼ R(i,j)·vᵢ·vⱼ + (1/4)·(Σₖ vₖ)²

  The positive-sector quadratic form decomposes into:
  1. The Ramanujan form vᵀRv (PSD, GCD arithmetic)
  2. A rank-1 shift (1/4)·(Σvₖ)²

  For the Baez-Duarte distance:
    d²_N = 1 - 2·vᵀb + vᵀG⁽¹⁾v
         = 1 - 2·vᵀb + vᵀRv + (1/4)·(Σvₖ)²

  The rank-1 term vanishes when Σvₖ → 0 (PNT for the Möbius witness).
  What remains is the Ramanujan residual vᵀRv.

  This is the **spectral path to the critical line**:
  RH ⟺ d²_N → 0 ⟺ (with Σvₖ → 0) vᵀRv → 0. -/

/-- **GLASS DECOMPOSITION**: The positive Gram quadratic form splits as
    vᵀG⁽¹⁾v = vᵀRv + (1/4)·(Σvₖ)².

    The proof is just distributing the sum:
    Σᵢⱼ (R(i,j) + 1/4)·vᵢ·vⱼ = Σᵢⱼ R(i,j)·vᵢ·vⱼ + (1/4)·Σᵢ vᵢ · Σⱼ vⱼ. -/
theorem glass_quadratic_form (N : ℕ) (v : Fin N → ℝ) :
    ∑ i : Fin N, ∑ j : Fin N,
      (ramanujanEntry (i.val + 1) (j.val + 1) + 1 / 4) * v i * v j =
    ∑ i : Fin N, ∑ j : Fin N,
      ramanujanEntry (i.val + 1) (j.val + 1) * v i * v j +
    1 / 4 * (∑ k : Fin N, v k) ^ 2 := by
  -- Split (R + 1/4)·vi·vj into R·vi·vj + (1/4)·vi·vj
  have hsplit : ∀ i j : Fin N,
      (ramanujanEntry (i.val + 1) (j.val + 1) + 1 / 4) * v i * v j =
      ramanujanEntry (i.val + 1) (j.val + 1) * v i * v j + 1 / 4 * (v i * v j) := by
    intro i j; ring
  simp_rw [hsplit]
  simp_rw [Finset.sum_add_distrib]
  congr 1
  rw [sq, Fintype.sum_mul_sum]
  simp_rw [← Finset.mul_sum]

/-- The rank-1 term is nonneg. -/
theorem rank1_nonneg (N : ℕ) (v : Fin N → ℝ) :
    0 ≤ 1 / 4 * (∑ k : Fin N, v k) ^ 2 := by
  apply mul_nonneg (by norm_num) (sq_nonneg _)

/-- **GLASS LOWER BOUND**: vᵀG⁽¹⁾v ≥ vᵀRv.

    Since the rank-1 term (1/4)·(Σv)² ≥ 0, the Ramanujan form
    provides a LOWER bound on the positive Gram form.

    Consequence: if vᵀRv ≥ c > 0 for the BD witness,
    then d²_N ≥ 1 - 2vᵀb + c. -/
theorem glass_lower_bound (N : ℕ) (v : Fin N → ℝ) :
    ∑ i : Fin N, ∑ j : Fin N,
      ramanujanEntry (i.val + 1) (j.val + 1) * v i * v j ≤
    ∑ i : Fin N, ∑ j : Fin N,
      (ramanujanEntry (i.val + 1) (j.val + 1) + 1 / 4) * v i * v j := by
  rw [glass_quadratic_form]
  linarith [rank1_nonneg N v]

/-- **GLASS UPPER BOUND**: vᵀG⁽¹⁾v ≤ vᵀRv + (1/4)·N²·‖v‖²∞.

    When |vₖ| ≤ M for all k, the rank-1 term is at most (1/4)·N²·M².
    This bounds the damage from the rank-1 noise. -/
theorem glass_upper_bound (N : ℕ) (v : Fin N → ℝ) (M : ℝ) (_hM : 0 ≤ M)
    (hv : ∀ k : Fin N, |v k| ≤ M) :
    ∑ i : Fin N, ∑ j : Fin N,
      (ramanujanEntry (i.val + 1) (j.val + 1) + 1 / 4) * v i * v j ≤
    ∑ i : Fin N, ∑ j : Fin N,
      ramanujanEntry (i.val + 1) (j.val + 1) * v i * v j +
    1 / 4 * ((N : ℝ) * M) ^ 2 := by
  rw [glass_quadratic_form]
  have hsum : |∑ k : Fin N, v k| ≤ (N : ℝ) * M := calc
    |∑ k : Fin N, v k|
      ≤ ∑ k : Fin N, |v k| := Finset.abs_sum_le_sum_abs _ _
    _ ≤ ∑ _k : Fin N, M := Finset.sum_le_sum (fun k _ => hv k)
    _ = (N : ℝ) * M := by simp [Finset.sum_const]
  have hbounds := abs_le.mp hsum
  have hsq : (∑ k : Fin N, v k) ^ 2 ≤ ((N : ℝ) * M) ^ 2 :=
    sq_le_sq' hbounds.1 hbounds.2
  linarith

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit

### Sorry: 0 🎓 — FULLY CERTIFIED

### Custom Axioms: 0

### PROVED:
| # | Result | Status |
|---|--------|--------|
| 1 | `ramanujanEntry` | 📐 DEFINITION |
| 2 | `ramanujan_symmetric` | 🎓 PROVED |
| 3 | `ramanujan_nonneg` | 🎓 PROVED |
| 4 | `ramanujan_pos` | 🎓 PROVED |
| 5 | `ramanujan_diagonal` | 🎓 PROVED (= 1/12, constant!) |
| 6 | `ramanujan_coprime` | 🎓 PROVED |
| 7 | `ramanujan_vs_dark` | 🎓 PROVED (R = 15·j'k'·G⁽²⁾) |
| 8 | `ramanujan_entry_eq_integral` | 🎓 **THE GLASS** (R = ∫B₁·B₁) |
| 9 | `positive_gram_via_ramanujan` | 🎓 **THE GLASS** (G⁽¹⁾ = R + 1/4) |
| 10 | `positive_gram_via_dark` | 🎓 **THE FULL GLASS** (G⁽¹⁾ = 15·j'k'·G⁽²⁾ + 1/4) |
| 11 | `jordanTotient2` | 📐 DEFINITION |
| 12 | `jordan2_one` | 🎓 PROVED |
| 13 | `jordan2_pos` | 🎓 PROVED |
| 14 | `jordan4_from_jordan2` | 🎓 PROVED (J₄ = J₂·d²·glass) |
| 15 | `ramanujan_trace` | 🎓 PROVED (Σ R = N/12) |
| 16 | `glass_quadratic_form` | 🎓 **BD DECOMPOSITION** (vᵀG¹v = vᵀRv + ¼(Σv)²) |
| 17 | `rank1_nonneg` | 🎓 PROVED |
| 18 | `glass_lower_bound` | 🎓 PROVED (vᵀRv ≤ vᵀG¹v) |
| 19 | `glass_upper_bound` | 🎓 PROVED (vᵀG¹v ≤ vᵀRv + ¼N²M²) |

### The Glass Connection (May 16, 2026)
The Ramanujan Bridge imports `RamanujanInnerProduct` and formally
certifies that `ramanujanEntry` equals the analytic integral
`∫₀¹ B₁({jt})·B₁({kt})dt`, connecting dark (GCD) to light (integral).

### The BD Decomposition (May 16, 2026, 3:20 AM)
The glass quadratic form theorem decomposes the BD distance as:
  d²_N = 1 - 2vᵀb + vᵀRv + (1/4)·(Σvₖ)²
The rank-1 term (1/4)·(Σvₖ)² vanishes by PNT (Σμ(k)/k → 0).
What remains is vᵀRv — the Ramanujan residual, pure GCD arithmetic.
-/

end Cathedral.Physics.RamanujanBridge

end
