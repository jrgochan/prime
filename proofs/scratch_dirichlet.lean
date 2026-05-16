import Mathlib.NumberTheory.ArithmeticFunction.Moebius
import Mathlib.Tactic.FieldSimp
import Mathlib.Data.Real.Basic

open Finset

-- Cancel: gcd²/(12jk) · (12k · q) = gcd²/j · q
lemma cancel_12k (a b j k : ℝ) (hj : j ≠ 0) (hk : k ≠ 0) :
    a / (12 * j * k) * (12 * k * b) = a * b / j := by field_simp

-- Key reindexing:
-- Σ_{k=1}^N gcd(j,k)²·q_k = Σ_{e|j} J₂(e)·(Σ_{r=1}^{N/e} q_{er})
-- This is the "Dirichlet fiberization by common divisor"

-- Actually, for smith_solve, let me try a simpler approach.
-- After canceling 12k, we have:
-- (1/j) · Σ_k gcd(j,k+1)² · q_{k+1}
-- = (1/j) · Σ_k (Σ_{e|gcd(j,k+1)} J₂(e)) · q_{k+1}
-- = (1/j) · Σ_k Σ_{e|gcd(j,k+1)} J₂(e) · q_{k+1}
-- = (1/j) · Σ_{e|j} J₂(e) · Σ_{k: e|(k+1)} q_{k+1}   [collect by e]
-- = (1/j) · Σ_{e|j} J₂(e) · (φ(e)/J₂(e))              [moebius_cancellation]
-- = (1/j) · Σ_{e|j} φ(e)
-- = 1

-- The "collect by e" step needs the Fubini identity:
-- Σ_{k<N} Σ_{e|gcd(j,k+1)} f(e,k+1) = Σ_{e|j} Σ_{r<N/e} f(e, e*(r+1))
-- This is because k+1 ranges over {1,...,N}, and for each e|j,
-- the values of k+1 divisible by e are exactly {e, 2e, ..., ⌊N/e⌋·e}

-- Let me test just this reindexing
-- Simpler statement: for fixed j with hj : 0 < j,
-- Σ_{k<N} Σ_{e∈(gcd(j,k+1)).divisors} f(e,k+1)
-- = Σ_{e∈j.divisors} Σ_{r<N/e} f(e, e*(r+1))

-- This is the core combinatorial identity we need.
-- The bijection: for (k, e) with k < N and e | gcd(j, k+1),
-- set r = (k+1)/e - 1, so k+1 = e*(r+1), r < N/e.
-- Conversely: for (e, r) with e | j and r < N/e,
-- set k = e*(r+1) - 1, so k < N and e | (k+1) and e | j, so e | gcd(j, k+1).

theorem gcd_fiber_reindex (f : ℕ → ℕ → ℝ) (j N : ℕ) (hj : 0 < j) :
    ∑ k ∈ range N, ∑ e ∈ (Nat.gcd j (k + 1)).divisors, f e (k + 1) =
    ∑ e ∈ j.divisors, ∑ r ∈ range (N / e), f e (e * (r + 1)) := by
  rw [sum_sigma', sum_sigma']
  apply sum_nbij'
    (fun ⟨k, e⟩ => ⟨e, (k + 1) / e - 1⟩)
    (fun ⟨e, r⟩ => ⟨e * (r + 1) - 1, e⟩)
  · -- Forward: (k, e ∈ gcd(j,k+1).divisors) → (e ∈ j.divisors, r < N/e)
    intro ⟨k, e⟩ hmem
    simp only [mem_sigma, mem_range] at hmem ⊢
    have hk_lt : k < N := hmem.1
    have he_dvd_g : e ∣ Nat.gcd j (k + 1) := Nat.dvd_of_mem_divisors hmem.2
    have he_dvd_j : e ∣ j := dvd_trans he_dvd_g (Nat.gcd_dvd_left j (k + 1))
    have he_dvd_k : e ∣ (k + 1) := dvd_trans he_dvd_g (Nat.gcd_dvd_right j (k + 1))
    have he_pos : 0 < e := Nat.pos_of_mem_divisors hmem.2
    constructor
    · exact Nat.mem_divisors.mpr ⟨he_dvd_j, hj.ne'⟩
    · -- (k+1)/e - 1 < N/e, i.e., (k+1)/e ≤ N/e
      have : (k + 1) / e ≤ N / e := Nat.div_le_div_right (by omega)
      have : 0 < (k + 1) / e := Nat.div_pos (Nat.le_of_dvd (by omega) he_dvd_k) he_pos
      omega
  · -- Backward: (e ∈ j.divisors, r < N/e) → (e*(r+1)-1 < N, e ∈ gcd(j,e*(r+1)).divisors)
    intro ⟨e, r⟩ hmem
    simp only [mem_sigma, mem_range] at hmem ⊢
    have he_dvd_j : e ∣ j := Nat.dvd_of_mem_divisors hmem.1
    have he_pos : 0 < e := Nat.pos_of_mem_divisors hmem.1
    have hr_lt : r < N / e := hmem.2
    have h_prod_le : e * (r + 1) ≤ N := by
      calc e * (r + 1) ≤ e * (N / e) := Nat.mul_le_mul_left e hr_lt
        _ ≤ N := Nat.mul_div_le N e
    have he_prod_pos : 0 < e * (r + 1) := by positivity
    constructor
    · omega
    · -- e | gcd(j, e*(r+1))
      have he_dvd_er : e ∣ e * (r + 1) := dvd_mul_right e (r + 1)
      rw [show e * (r + 1) - 1 + 1 = e * (r + 1) from by omega]
      exact Nat.mem_divisors.mpr ⟨Nat.dvd_gcd he_dvd_j he_dvd_er,
        (Nat.gcd_pos_of_pos_left _ hj).ne'⟩
  · -- Left inverse
    intro ⟨k, e⟩ hmem
    simp only [mem_sigma, mem_range] at hmem
    have he_dvd_g : e ∣ Nat.gcd j (k + 1) := Nat.dvd_of_mem_divisors hmem.2
    have he_dvd_k : e ∣ (k + 1) := dvd_trans he_dvd_g (Nat.gcd_dvd_right j (k + 1))
    have he_pos : 0 < e := Nat.pos_of_mem_divisors hmem.2
    ext
    · simp
      rw [show (k + 1) / e - 1 + 1 = (k + 1) / e from by
        exact Nat.succ_pred_eq_of_pos (Nat.div_pos (Nat.le_of_dvd (by omega) he_dvd_k) he_pos)]
      rw [Nat.mul_div_cancel' he_dvd_k]; omega
    · simp
  · -- Right inverse
    intro ⟨e, r⟩ hmem
    simp only [mem_sigma, mem_range] at hmem
    have he_pos : 0 < e := Nat.pos_of_mem_divisors hmem.1
    have he_prod_pos : 0 < e * (r + 1) := by positivity
    ext
    · simp
    · simp
      rw [show e * (r + 1) - 1 + 1 = e * (r + 1) from by omega]
      rw [Nat.mul_div_cancel_left _ he_pos]
      omega
  · -- Function value
    intro ⟨k, e⟩ hmem
    simp only
    have he_dvd_g : e ∣ Nat.gcd j (k + 1) := Nat.dvd_of_mem_divisors (mem_sigma.mp hmem).2
    have he_dvd_k : e ∣ (k + 1) := dvd_trans he_dvd_g (Nat.gcd_dvd_right j (k + 1))
    have he_pos : 0 < e := Nat.pos_of_mem_divisors (mem_sigma.mp hmem).2
    congr 1
    rw [show (k + 1) / e - 1 + 1 = (k + 1) / e from
      Nat.succ_pred_eq_of_pos (Nat.div_pos (Nat.le_of_dvd (by omega) he_dvd_k) he_pos)]
    exact (Nat.mul_div_cancel' he_dvd_k).symm
