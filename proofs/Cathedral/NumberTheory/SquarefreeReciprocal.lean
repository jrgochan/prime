import Cathedral.NumberTheory.BaselMoebius
import Cathedral.Physics.GramWiring.CoprimeDiagonal
import Cathedral.Analysis.DirichletTest

/-!
  # Squarefree Reciprocal Sum — The Graduation

  ## Σ_{k≤N, sqfree} 1/k ≥ (1/2)·logN  for N ≥ 3

  ════════════════════════════════════════════════════════════════

  This file graduates the `squarefree_reciprocal_lower` axiom in
  CoprimeDiagonal.lean by proving it as a theorem.

  ## Strategy: Direct Comparison
  Instead of Abel summation (which requires Q(N) ≥ N/2),
  we use a direct comparison:

    Σ_{sqfree k≤N} 1/k ≥ Σ_{odd k≤N} 1/(2k)

  because every other integer is odd, and among the first N
  integers, the squarefree ones include all integers not
  divisible by any prime square.

  More concretely, we use the Möbius identity:
    Σ_{sqfree k≤N} 1/k = Σ_{k≤N} μ²(k)/k
  and bound it below via the harmonic series minus a correction.

  Status: see audit at bottom.

  Created: May 14, 2026 — Squarefree Axiom Graduation Campaign
-/

noncomputable section
open Real Finset ArithmeticFunction
open scoped ArithmeticFunction.Moebius

namespace Cathedral.NumberTheory.SquarefreeReciprocal

-- ════════════════════════════════════════════════════════════════
-- §1. THE SQUAREFREE COUNTING FUNCTION
-- ════════════════════════════════════════════════════════════════

/-- The squarefree counting function Q(N) = #{k ≤ N : squarefree}. -/
def sqfreeCount (N : ℕ) : ℕ :=
  ((Finset.Icc 1 N).filter Squarefree).card

/-- Q(1) = 1 (1 is squarefree). -/
theorem sqfreeCount_one : sqfreeCount 1 = 1 := by
  unfold sqfreeCount
  simp [Finset.filter_singleton]

/-- **THEOREM**: Q(N) ≤ N (trivially). -/
theorem sqfreeCount_le (N : ℕ) : sqfreeCount N ≤ N := by
  unfold sqfreeCount
  calc ((Finset.Icc 1 N).filter Squarefree).card
      ≤ (Finset.Icc 1 N).card := Finset.card_filter_le _ _
    _ ≤ N := by simp [Nat.card_Icc]

-- ════════════════════════════════════════════════════════════════
-- §2. DIRECT LOWER BOUND ON THE RECIPROCAL SUM
-- ════════════════════════════════════════════════════════════════

/-- The squarefree reciprocal sum (same as in CoprimeDiagonal). -/
def sqfreeReciprocalSum (N : ℕ) : ℝ :=
  ∑ k ∈ Icc 1 N, if Squarefree k then (1 : ℝ) / ↑k else 0

/-- The harmonic number H(N) = Σ_{k=1}^{N} 1/k. -/
def harmonicSum (N : ℕ) : ℝ :=
  ∑ k ∈ Icc 1 N, (1 : ℝ) / ↑k

/-- The non-squarefree reciprocal sum Σ_{non-sqfree k≤N} 1/k. -/
def nonsqfreeReciprocalSum (N : ℕ) : ℝ :=
  ∑ k ∈ Icc 1 N, if ¬Squarefree k then (1 : ℝ) / ↑k else 0

/-- **LEMMA**: sqfree + non-sqfree = harmonic. -/
theorem sqfree_plus_nonsqfree (N : ℕ) :
    sqfreeReciprocalSum N + nonsqfreeReciprocalSum N = harmonicSum N := by
  unfold sqfreeReciprocalSum nonsqfreeReciprocalSum harmonicSum
  rw [← Finset.sum_add_distrib]
  apply Finset.sum_congr rfl
  intro k hk
  have hk_pos : (0 : ℝ) < k := by
    simp [Finset.mem_Icc] at hk; exact_mod_cast hk.1
  split_ifs with h
  · simp
  · simp
-- The non-squarefree reciprocal sum is bounded by H(N)/2.
-- Proof uses the prime-square sieve: each non-sqfree k has some
-- squarefree d ≥ 2 with d²|k, giving an injective map into
-- {sqfree d ≥ 2} × {1,...,⌊N/d²⌋}.
-- The key numerical fact: Σ_{sqfree d≥2} 1/d² = 1 - 6/π² ≈ 0.392 < 1/2.

/-- **LEMMA**: Monotonicity of the harmonic sum. -/
theorem harmonicSum_mono {M N : ℕ} (h : M ≤ N) :
    harmonicSum M ≤ harmonicSum N := by
  unfold harmonicSum
  apply Finset.sum_le_sum_of_subset_of_nonneg
  · intro x hx; simp [Finset.mem_Icc] at hx ⊢; omega
  · intro k _ _; positivity

/- **Shadow Absorption Argument** (used in nonsqfree_le_sqfree below):
   Every non-squarefree k factors uniquely as k = d²·m with m squarefree, d ≥ 2.
   For each squarefree m, the shadow sum Σ_{d≥2} 1/(d²m) = (1/m)·(π²/6 - 1).
   Since π²/6 - 1 ≈ 0.645 < 1: nonsqfree ≤ (π²/6-1)·sqfree < sqfree. -/
/-- Every non-squarefree k is divisible by p² for some prime p ≥ 2. -/
private lemma not_sqfree_has_sq_dvd {k : ℕ} (_hk : 1 ≤ k) (hns : ¬Squarefree k) :
    ∃ d : ℕ, 2 ≤ d ∧ d ^ 2 ∣ k := by
  rw [Nat.squarefree_iff_prime_squarefree] at hns
  push Not at hns
  obtain ⟨p, hp, hpk⟩ := hns
  exact ⟨p, hp.two_le, by rwa [sq]⟩

/-- Σ_{k: m²|k, k≤N} 1/k = (1/m²) · H(⌊N/m²⌋) ≤ (1/m²) · H(N).
    Proof: reindex k = m²·j, so 1/k = 1/(m²j) = (1/m²)·(1/j). -/
private lemma multiples_sq_reciprocal_le (N m : ℕ) (hm : 2 ≤ m) :
    ∑ k ∈ (Icc 1 N).filter (fun k => m ^ 2 ∣ k),
      (1 : ℝ) / ↑k ≤ (1 / (m : ℝ) ^ 2) * harmonicSum N := by
  have hm_sq_pos : (0 : ℕ) < m ^ 2 := by positivity
  -- Step 1: Rewrite each term 1/k = (1/m²)·(1/(k/m²)) when m²|k
  have h_eq : ∀ k ∈ (Icc 1 N).filter (fun k => m ^ 2 ∣ k),
      (1 : ℝ) / ↑k = (1 / (m : ℝ) ^ 2) * (1 / (↑(k / m ^ 2) : ℝ)) := by
    intro k hk
    rw [Finset.mem_filter] at hk
    have hk_dvd := hk.2
    have h_eq_nat : k = m ^ 2 * (k / m ^ 2) := (Nat.mul_div_cancel' hk_dvd).symm
    have hj_pos : (0 : ℝ) < ↑(k / m ^ 2) := by
      have hk1 : 1 ≤ k := by simp [Finset.mem_Icc] at hk; omega
      exact_mod_cast Nat.div_pos (Nat.le_of_dvd (by omega) hk_dvd) hm_sq_pos
    have hk_pos : (0 : ℝ) < k := by
      simp [Finset.mem_Icc] at hk; exact_mod_cast hk.1.1
    rw [show (1 : ℝ) / ↑k = (1 / (m : ℝ) ^ 2) * (1 / ↑(k / m ^ 2)) from by
      rw [div_mul_div_comm, one_mul]
      congr 1
      have : (k : ℝ) = (m : ℝ) ^ 2 * ↑(k / m ^ 2) := by exact_mod_cast h_eq_nat
      linarith]
  rw [Finset.sum_congr rfl h_eq, ← Finset.mul_sum]
  -- Step 2: Bound Σ 1/(k/m²) ≤ H(N)
  apply mul_le_mul_of_nonneg_left _ (by positivity)
  unfold harmonicSum
  -- The map k ↦ k/m² is injective on the filtered set, and its image ⊆ Icc 1 N.
  -- So Σ_{k∈filtered} f(k/m²) = Σ_{j∈image} f(j) ≤ Σ_{j∈Icc 1 N} f(j).
  set S := (Icc 1 N).filter (fun k => m ^ 2 ∣ k) with hS_def
  -- Rewrite the sum over S as sum over image
  have h_inj : Set.InjOn (· / m ^ 2) (↑S) := by
    intro a ha b hb hab
    rw [Finset.mem_coe, Finset.mem_filter] at ha hb
    have := congr_arg (· * m ^ 2) hab
    simp only [Nat.div_mul_cancel ha.2, Nat.div_mul_cancel hb.2] at this
    exact this
  rw [← Finset.sum_image (f := fun j => (1 : ℝ) / ↑j)
    (fun a ha b hb hab => h_inj (Finset.mem_coe.mpr ha) (Finset.mem_coe.mpr hb) hab)]
  apply Finset.sum_le_sum_of_subset_of_nonneg
  · -- Image ⊆ Icc 1 N
    intro j hj
    rw [Finset.mem_image] at hj
    obtain ⟨k, hk, rfl⟩ := hj
    rw [Finset.mem_filter] at hk
    rw [Finset.mem_Icc] at hk ⊢
    exact ⟨Nat.div_pos (Nat.le_of_dvd (by omega) hk.2) hm_sq_pos,
           le_trans (Nat.div_le_self k _) hk.1.2⟩
  · intro j _ _; positivity

private lemma nonsqfree_le_union_bound (N : ℕ) :
    nonsqfreeReciprocalSum N ≤
    ∑ d ∈ Icc 2 N, ∑ k ∈ (Icc 1 N).filter (fun k => d ^ 2 ∣ k),
      (1 : ℝ) / ↑k := by
  unfold nonsqfreeReciprocalSum
  -- Step 1: Bound pointwise: (if ¬sqfree k then 1/k else 0)
  --   ≤ Σ_{d ∈ (Icc 2 N).filter(d²|k)} (1/k)
  have h_pw : ∀ k ∈ Icc 1 N,
      (if ¬Squarefree k then (1 : ℝ) / ↑k else 0) ≤
      ∑ d ∈ (Icc 2 N).filter (fun d => d ^ 2 ∣ k), (1 : ℝ) / ↑k := by
    intro k hk
    rw [Finset.mem_Icc] at hk
    by_cases h_ns : Squarefree k
    · -- k squarefree: LHS = 0, RHS ≥ 0
      rw [if_neg (not_not.mpr h_ns)]
      exact Finset.sum_nonneg (fun _ _ => by positivity)
    · -- k not squarefree: LHS = 1/k, RHS contains 1/k
      rw [if_pos h_ns]
      obtain ⟨d, hd_ge, hd_dvd⟩ := not_sqfree_has_sq_dvd (by omega) h_ns
      have hd_le_N : d ≤ N := by
        calc d ≤ d ^ 2 := le_self_pow₀ (by omega : 1 ≤ d) (by omega)
          _ ≤ k := Nat.le_of_dvd (by omega) hd_dvd
          _ ≤ N := hk.2
      have hd_mem : d ∈ (Icc 2 N).filter (fun d => d ^ 2 ∣ k) :=
        Finset.mem_filter.mpr ⟨Finset.mem_Icc.mpr ⟨hd_ge, hd_le_N⟩, hd_dvd⟩
      exact Finset.single_le_sum (f := fun _ => (1 : ℝ) / ↑k) (fun _ _ => by positivity) hd_mem
  -- Step 2: Sum the pointwise bound
  calc ∑ k ∈ Icc 1 N, (if ¬Squarefree k then (1 : ℝ) / ↑k else 0)
      ≤ ∑ k ∈ Icc 1 N, ∑ d ∈ (Icc 2 N).filter (fun d => d ^ 2 ∣ k), (1 : ℝ) / ↑k :=
        Finset.sum_le_sum h_pw
    _ = ∑ d ∈ Icc 2 N, ∑ k ∈ (Icc 1 N).filter (fun k => d ^ 2 ∣ k), (1 : ℝ) / ↑k := by
        rw [Finset.sum_comm']
        intro k d; simp only [Finset.mem_filter, Finset.mem_Icc]; tauto

/-- Every non-squarefree k is divisible by p² for some *prime* p. -/
private lemma not_sqfree_has_prime_sq_dvd {k : ℕ} (_hk : 1 ≤ k) (hns : ¬Squarefree k) :
    ∃ p : ℕ, Nat.Prime p ∧ p ^ 2 ∣ k := by
  rw [Nat.squarefree_iff_prime_squarefree] at hns
  push Not at hns
  obtain ⟨p, hp, hpk⟩ := hns
  exact ⟨p, hp, by rwa [sq]⟩

/-- **Prime-restricted union bound**: nonsqfree ≤ Σ_{p prime} Σ_{p²|k} 1/k.
    Since not_sqfree_has_sq_dvd extracts a prime d via squarefree_iff_prime_squarefree,
    the non-squarefree sum is bounded by a sum over prime divisors only. -/
private lemma nonsqfree_le_prime_union_bound (N : ℕ) :
    nonsqfreeReciprocalSum N ≤
    ∑ p ∈ (Icc 2 N).filter Nat.Prime, ∑ k ∈ (Icc 1 N).filter (fun k => p ^ 2 ∣ k),
      (1 : ℝ) / ↑k := by
  unfold nonsqfreeReciprocalSum
  -- Pointwise bound: for non-sqfree k, pick a prime d with d²|k
  have h_pw : ∀ k ∈ Icc 1 N,
      (if ¬Squarefree k then (1 : ℝ) / ↑k else 0) ≤
      ∑ p ∈ ((Icc 2 N).filter Nat.Prime).filter (fun p => p ^ 2 ∣ k), (1 : ℝ) / ↑k := by
    intro k hk
    rw [Finset.mem_Icc] at hk
    by_cases h_ns : Squarefree k
    · rw [if_neg (not_not.mpr h_ns)]
      exact Finset.sum_nonneg (fun _ _ => by positivity)
    · rw [if_pos h_ns]
      obtain ⟨p, hp, hpk⟩ := not_sqfree_has_prime_sq_dvd (by omega) h_ns
      have hk_pos : 0 < k := by omega
      have hp_le_N : p ≤ N := le_trans (le_trans (Nat.le_self_pow (by omega : 2 ≠ 0) p)
        (Nat.le_of_dvd hk_pos hpk)) hk.2
      have hp_mem : p ∈ ((Icc 2 N).filter Nat.Prime).filter (fun p => p ^ 2 ∣ k) :=
        Finset.mem_filter.mpr ⟨Finset.mem_filter.mpr ⟨Finset.mem_Icc.mpr ⟨hp.two_le, hp_le_N⟩, hp⟩, hpk⟩
      exact Finset.single_le_sum (f := fun _ => (1 : ℝ) / ↑k) (fun _ _ => by positivity) hp_mem
  calc ∑ k ∈ Icc 1 N, (if ¬Squarefree k then (1 : ℝ) / ↑k else 0)
      ≤ ∑ k ∈ Icc 1 N, ∑ p ∈ ((Icc 2 N).filter Nat.Prime).filter (fun p => p ^ 2 ∣ k),
          (1 : ℝ) / ↑k :=
        Finset.sum_le_sum h_pw
    _ = ∑ p ∈ (Icc 2 N).filter Nat.Prime,
          ∑ k ∈ (Icc 1 N).filter (fun k => p ^ 2 ∣ k), (1 : ℝ) / ↑k := by
        rw [Finset.sum_comm']
        intro k p; simp only [Finset.mem_filter, Finset.mem_Icc]; tauto

private lemma inv_odd_sq_le (p : ℕ) (hp_ge : 3 ≤ p) (hp_odd : p % 2 = 1) :
    let m : ℕ := (p - 1) / 2
    (1 : ℝ) / (p : ℝ) ^ 2 ≤ (1 : ℝ) / (4 * (m : ℝ) * ((m : ℝ) + 1)) := by
  intro m
  have hm_ge : 1 ≤ m := by omega
  have hm_eq : p = 2 * m + 1 := by omega
  have hp_pos : (0 : ℝ) < (p : ℝ) := by positivity
  have hdenom_pos : (0 : ℝ) < 4 * (m : ℝ) * ((m : ℝ) + 1) := by
    apply mul_pos (mul_pos (by norm_num : (0:ℝ) < 4) _) _
    · exact_mod_cast show 0 < m by omega
    · linarith [show (0 : ℝ) ≤ (m : ℝ) from by exact_mod_cast show 0 ≤ m by omega]
  rw [div_le_div_iff₀ (sq_pos_of_pos hp_pos) hdenom_pos]
  rw [one_mul, one_mul]
  have hp_cast : (p : ℝ) = 2 * (m : ℝ) + 1 := by exact_mod_cast hm_eq
  rw [hp_cast]; ring_nf; nlinarith

private lemma telescoping_eq (M : ℕ) :
    ∑ m ∈ Icc 1 M, (1 / (m : ℝ) - 1 / ((m : ℝ) + 1)) = 1 - 1 / ((M : ℝ) + 1) := by
  induction M with
  | zero => simp
  | succ n ih =>
    rw [show Icc 1 (n + 1) = insert (n + 1) (Icc 1 n) from by
      ext x; simp only [Finset.mem_insert, Finset.mem_Icc]; omega]
    rw [Finset.sum_insert (show (n + 1) ∉ Icc 1 n from by simp only [Finset.mem_Icc]; omega)]
    rw [ih]
    have h1 : (0 : ℝ) < (↑n : ℝ) + 1 := by positivity
    have h2 : (0 : ℝ) < (↑n : ℝ) + 2 := by positivity
    field_simp
    push_cast; ring

private lemma partial_frac_nonneg (m : ℕ) (hm : 1 ≤ m) :
    (0 : ℝ) ≤ 1 / (m : ℝ) - 1 / ((m : ℝ) + 1) := by
  have hm_pos : (0 : ℝ) < (m : ℝ) := by exact_mod_cast show 0 < m by omega
  have hm1_pos : (0 : ℝ) < (m : ℝ) + 1 := by linarith
  rw [div_sub_div _ _ (ne_of_gt hm_pos) (ne_of_gt hm1_pos)]
  exact div_nonneg (by linarith) (le_of_lt (mul_pos hm_pos hm1_pos))

private lemma sum_telescoping_le_one (S : Finset ℕ) (hS : ∀ m ∈ S, 1 ≤ m) :
    ∑ m ∈ S, (1 / (m : ℝ) - 1 / ((m : ℝ) + 1)) ≤ 1 := by
  rcases S.eq_empty_or_nonempty with rfl | hne
  · simp
  · have hS_sub : S ⊆ Icc 1 (S.max' hne) := by
      intro m hm; exact Finset.mem_Icc.mpr ⟨hS m hm, Finset.le_max' S m hm⟩
    calc ∑ m ∈ S, (1 / (m : ℝ) - 1 / ((m : ℝ) + 1))
        ≤ ∑ m ∈ Icc 1 (S.max' hne), (1 / (m : ℝ) - 1 / ((m : ℝ) + 1)) := by
          apply Finset.sum_le_sum_of_subset_of_nonneg hS_sub
          intro m hm _
          exact partial_frac_nonneg m (Finset.mem_Icc.mp hm).1
      _ = 1 - 1 / ((S.max' hne : ℝ) + 1) := telescoping_eq _
      _ ≤ 1 := by linarith [show (0 : ℝ) ≤ 1 / ((S.max' hne : ℝ) + 1) from by positivity]

private lemma prime_sq_reciprocal_le_half (N : ℕ) :
    ∑ p ∈ (Icc 2 N).filter Nat.Prime, (1 : ℝ) / (p : ℝ) ^ 2 ≤ 1 / 2 := by
  set S := (Icc 2 N).filter Nat.Prime with hS_def
  -- Step 1: Split off p = 2
  have h_split : ∑ p ∈ S, (1 : ℝ) / ↑p ^ 2 ≤
      1 / 4 + ∑ p ∈ S.erase 2, (1 : ℝ) / ↑p ^ 2 := by
    by_cases h2 : (2 : ℕ) ∈ S
    · rw [← Finset.add_sum_erase _ _ h2]; norm_num
    · rw [Finset.erase_eq_self.mpr h2]
      linarith [Finset.sum_nonneg (fun p (_ : p ∈ S) => show (0 : ℝ) ≤ 1 / ↑p ^ 2 from by positivity)]
  -- Properties of p ∈ S.erase 2
  have h_props : ∀ p ∈ S.erase 2, 3 ≤ p ∧ Nat.Prime p ∧ p % 2 = 1 := by
    intro p hp
    have hp_ne2 : p ≠ 2 := (Finset.mem_erase.mp hp).1
    have hp_S := Finset.erase_subset 2 S hp
    rw [hS_def, Finset.mem_filter, Finset.mem_Icc] at hp_S
    have hp_prime := hp_S.2
    have hp_ge : 2 ≤ p := hp_S.1.1
    have hp_odd : p % 2 = 1 := by
      have hne : ¬Even p := fun hev => absurd (hp_prime.even_iff.mp hev) hp_ne2
      rw [Nat.even_iff] at hne
      omega
    exact ⟨by omega, hp_prime, hp_odd⟩
  -- Step 2: Bound each odd prime term by 1/(4m(m+1))
  have h_odd_bound : ∑ p ∈ S.erase 2, (1 : ℝ) / ↑p ^ 2 ≤
      ∑ p ∈ S.erase 2, (1 : ℝ) / (4 * ↑((p - 1) / 2) * (↑((p - 1) / 2) + 1)) :=
    Finset.sum_le_sum fun p hp => inv_odd_sq_le p (h_props p hp).1 (h_props p hp).2.2
  -- Step 3: Factor out 1/4
  have h_factor : ∑ p ∈ S.erase 2,
      (1 : ℝ) / (4 * ↑((p - 1) / 2) * (↑((p - 1) / 2) + 1)) =
      (1 / 4) * ∑ p ∈ S.erase 2,
        (1 : ℝ) / (↑((p - 1) / 2) * (↑((p - 1) / 2) + 1)) := by
    rw [Finset.mul_sum]; congr 1; ext p
    have : (4 : ℝ) ≠ 0 := by norm_num
    field_simp
  -- Step 4: Rewrite 1/(m(m+1)) as partial fractions
  have h_pf : ∀ p ∈ S.erase 2,
      (1 : ℝ) / (↑((p - 1) / 2) * (↑((p - 1) / 2) + 1)) =
      1 / (↑((p - 1) / 2) : ℝ) - 1 / ((↑((p - 1) / 2) : ℝ) + 1) := by
    intro p hp
    have ⟨hp3, _, _⟩ := h_props p hp
    have hm_pos : (0 : ℝ) < (((p - 1) / 2 : ℕ) : ℝ) := by
      exact_mod_cast show 0 < (p - 1) / 2 by omega
    field_simp; ring
  have h_sum_eq : ∑ p ∈ S.erase 2,
      (1 : ℝ) / (↑((p - 1) / 2) * (↑((p - 1) / 2) + 1)) =
      ∑ p ∈ S.erase 2,
      (1 / (↑((p - 1) / 2) : ℝ) - 1 / ((↑((p - 1) / 2) : ℝ) + 1)) :=
    Finset.sum_congr rfl h_pf
  -- Step 5: Reindex and apply telescoping
  have h_inj : ∀ a ∈ S.erase 2, ∀ b ∈ S.erase 2,
      (a - 1) / 2 = (b - 1) / 2 → a = b := by
    intro a ha b hb hab
    have ⟨ha3, _, ha_odd⟩ := h_props a ha
    have ⟨hb3, _, hb_odd⟩ := h_props b hb
    omega
  have h_tele : ∑ p ∈ S.erase 2,
      (1 / (↑((p - 1) / 2) : ℝ) - 1 / ((↑((p - 1) / 2) : ℝ) + 1)) ≤ 1 := by
    have h_reindex : ∑ p ∈ S.erase 2,
        (1 / (↑((p - 1) / 2) : ℝ) - 1 / ((↑((p - 1) / 2) : ℝ) + 1)) =
        ∑ m ∈ (S.erase 2).image (fun (p : ℕ) => (p - 1) / 2),
          (1 / (m : ℝ) - 1 / ((m : ℝ) + 1)) := by
      symm
      exact Finset.sum_image h_inj
    rw [h_reindex]
    apply sum_telescoping_le_one
    intro m hm
    rw [Finset.mem_image] at hm
    obtain ⟨p, hp, rfl⟩ := hm
    have ⟨hp3, _, _⟩ := h_props p hp
    omega
  -- Combine: ≤ 1/4 + (1/4) · 1 = 1/2
  linarith

theorem nonsqfree_le_sqfree (N : ℕ) :
    nonsqfreeReciprocalSum N ≤ sqfreeReciprocalSum N := by
  have hpart := sqfree_plus_nonsqfree N
  suffices h : nonsqfreeReciprocalSum N ≤ harmonicSum N / 2 by linarith
  calc nonsqfreeReciprocalSum N
      ≤ ∑ p ∈ (Icc 2 N).filter Nat.Prime,
          ∑ k ∈ (Icc 1 N).filter (fun k => p ^ 2 ∣ k), (1 : ℝ) / ↑k :=
        nonsqfree_le_prime_union_bound N
    _ ≤ ∑ p ∈ (Icc 2 N).filter Nat.Prime,
          (1 / (p : ℝ) ^ 2) * harmonicSum N := by
        apply Finset.sum_le_sum
        intro p hp
        rw [Finset.mem_filter] at hp
        exact multiples_sq_reciprocal_le N p (hp.2.two_le)
    _ = (∑ p ∈ (Icc 2 N).filter Nat.Prime, 1 / (p : ℝ) ^ 2) * harmonicSum N := by
        rw [Finset.sum_mul]
    _ ≤ (1 / 2) * harmonicSum N := by
        apply mul_le_mul_of_nonneg_right _ (by unfold harmonicSum; exact Finset.sum_nonneg fun _ _ => by positivity)
        exact prime_sq_reciprocal_le_half N
    _ = harmonicSum N / 2 := by ring

/-- **THEOREM**: nonsqfreeReciprocalSum N ≤ harmonicSum N / 2.

    From nonsqfree ≤ sqfree (theorem) and nonsqfree + sqfree = H (proved). -/
theorem nonsqfree_upper (N : ℕ) :
    nonsqfreeReciprocalSum N ≤ harmonicSum N / 2 := by
  have hpart := sqfree_plus_nonsqfree N
  linarith [nonsqfree_le_sqfree N]

/-- **LEMMA**: H(N) ≥ logN for N ≥ 1.

    Standard integral comparison: 1/k ≥ log(k+1) - log(k) for k ≥ 1,
    since 1/k ≥ ∫_k^{k+1} 1/x dx = log((k+1)/k).
    Telescoping: H(N) = Σ 1/k ≥ Σ [log(k+1) - log(k)] = log(N+1) - log(1) = log(N+1) ≥ log(N). -/
theorem harmonicSum_ge_log (N : ℕ) (hN : 1 ≤ N) :
    Real.log ↑N ≤ harmonicSum N := by
  unfold harmonicSum
  -- Use: H(N) ≥ log(N+1) ≥ log(N)
  -- Each term 1/k ≥ log((k+1)/k) = log(k+1) - log(k)
  -- Sum telescopes to log(N+1) - log(1) = log(N+1)
  -- We prove: log(N) ≤ log(N+1) ≤ H(N)
  -- For the second inequality, use induction
  suffices h : Real.log (↑N + 1) ≤ ∑ k ∈ Icc 1 N, (1 : ℝ) / ↑k by
    have : Real.log ↑N ≤ Real.log (↑N + 1) :=
      Real.log_le_log (by exact_mod_cast hN : (0:ℝ) < N) (by linarith)
    linarith
  -- Prove log(N+1) ≤ H(N) by induction
  induction N with
  | zero => omega
  | succ n ih =>
    by_cases hn : n = 0
    · subst hn; simp [Finset.Icc_self]
      -- Goal should be: log(↑(0 : ℕ) + 1 + 1) ≤ 1, i.e. log 2 ≤ 1
      norm_num
      exact le_of_lt (by
        rw [Real.log_lt_iff_lt_exp (by norm_num : (0:ℝ) < 2)]
        linarith [Real.exp_one_gt_d9])
    · have hn1 : 1 ≤ n := by omega
      -- Split: Icc 1 (n+1) = Icc 1 n ∪ {n+1}
      have h_split : Finset.Icc 1 (n + 1) = Finset.Icc 1 n ∪ {n + 1} := by
        ext k; simp [Finset.mem_Icc]; omega
      have h_disj : Disjoint (Finset.Icc 1 n) {n + 1} := by
        rw [Finset.disjoint_singleton_right]; simp [Finset.mem_Icc]
      rw [h_split, Finset.sum_union h_disj, Finset.sum_singleton]
      -- By induction: log(n+1) ≤ Σ_{k=1}^n 1/k
      have h_ind := ih hn1
      -- Need: log(n+2) ≤ log(n+1) + 1/(n+1)
      -- i.e. log(n+2) - log(n+1) ≤ 1/(n+1)
      -- i.e. log((n+2)/(n+1)) ≤ 1/(n+1)
      -- From: log(1+x) ≤ x for x ≥ 0, with x = 1/(n+1)
      have hn1_pos : (0 : ℝ) < ↑(n + 1) := by positivity
      have h_log_step : Real.log (↑(n + 1) + 1) - Real.log (↑(n + 1)) ≤
          1 / (↑(n + 1) : ℝ) := by
        rw [← Real.log_div (by positivity) (by positivity)]
        have h_eq : (↑(n + 1) + 1 : ℝ) / ↑(n + 1) = 1 + 1 / ↑(n + 1) := by
          field_simp
        rw [h_eq]
        -- log(1 + x) ≤ x for all x (from exp(x) ≥ 1 + x)
        have h_exp_bound := Real.add_one_le_exp (1 / (↑(n + 1) : ℝ))
        -- exp(1/(n+1)) ≥ 1 + 1/(n+1), so log(1 + 1/(n+1)) ≤ 1/(n+1)
        have h1 : (0 : ℝ) < 1 + 1 / ↑(n + 1) := by positivity
        rw [Real.log_le_iff_le_exp h1]
        linarith
      push_cast at h_ind h_log_step ⊢
      linarith

/-- **THEOREM** (THE GRADUATION TARGET):
    Σ_{sqfree k≤N} 1/k ≥ (1/2)·logN  for N ≥ 3.

    Proof: sqfree = harmonic − non-sqfree ≥ H(N) − H(N)/2 = H(N)/2 ≥ logN/2

    This graduates the axiom in CoprimeDiagonal.lean. -/
theorem sqfreeReciprocal_lower_bound (N : ℕ) (hN : 3 ≤ N) :
    (1 : ℝ) / 2 * Real.log ↑N ≤ sqfreeReciprocalSum N := by
  have hN1 : 1 ≤ N := by omega
  -- H(N) ≥ logN
  have hH_log := harmonicSum_ge_log N hN1
  -- non-sqfree ≤ H(N)/2
  have hNS := nonsqfree_upper N
  -- sqfree = H(N) − non-sqfree
  have hSum := sqfree_plus_nonsqfree N
  -- sqfree ≥ H(N) − H(N)/2 = H(N)/2 ≥ logN/2
  linarith

-- ════════════════════════════════════════════════════════════════
-- §3. CONNECTING TO CoprimeDiagonal
-- ════════════════════════════════════════════════════════════════

/-- The definitions match between this file and CoprimeDiagonal. -/
theorem definitions_agree (N : ℕ) :
    sqfreeReciprocalSum N =
    Cathedral.Physics.GramWiring.CoprimeDiagonal.squarefreeReciprocalSum N := by
  unfold sqfreeReciprocalSum Cathedral.Physics.GramWiring.CoprimeDiagonal.squarefreeReciprocalSum
  rfl

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit (Updated May 20, 2026)

### Axiom Status: FULLY GRADUATED ✅
  - `nonsqfree_le_sqfree`: FULLY PROVED ✓
  - `harmonicSum_ge_log`: FULLY PROVED ✓
  - `multiples_sq_reciprocal_le`: FULLY PROVED ✓ (Finset.sum_image reindex)
  - `nonsqfree_le_union_bound`: FULLY PROVED ✓ (sum_comm' swap + single_le_sum)
  - `nonsqfree_le_prime_union_bound`: FULLY PROVED ✓ (direct pointwise + swap)
  - `inv_odd_sq_le`: FULLY PROVED ✓ (algebraic bound: 4m(m+1) ≤ (2m+1)²)
  - `prime_sq_reciprocal_le_half`: FULLY PROVED ✓ (telescoping + reindex)

### Sorry Count: 0 🎉

### PROVED:
| # | Result | Status |
|---|--------|--------|
| 1 | `sqfreeCount`, `sqfreeReciprocalSum`, `harmonicSum`, `nonsqfreeReciprocalSum` | **📐 DEFINITIONS** |
| 2 | `sqfreeCount_one` | **🎓 THEOREM** |
| 3 | `sqfreeCount_le` | **🎓 THEOREM** (Q ≤ N) |
| 4 | `sqfree_plus_nonsqfree` | **🎓 THEOREM** (partition) |
| 5 | `harmonicSum_ge_log` | **🎓 THEOREM** (H(N) ≥ logN) |
| 6 | `harmonicSum_mono` | **🎓 THEOREM** |
| 7 | `not_sqfree_has_sq_dvd` | **🎓 THEOREM** |
| 8 | `not_sqfree_has_prime_sq_dvd` | **🎓 THEOREM** (prime version) |
| 9 | `multiples_sq_reciprocal_le` | **🎓 THEOREM** (reindex) |
| 10 | `nonsqfree_le_union_bound` | **🎓 THEOREM** (sum swap) |
| 11 | `nonsqfree_le_prime_union_bound` | **🎓 THEOREM** (prime-restricted) |
| 12 | `inv_odd_sq_le` | **🎓 THEOREM** (algebraic bound) |
| 13 | `telescoping_eq` | **🎓 THEOREM** (induction on M) |
| 14 | `partial_frac_nonneg` | **🎓 THEOREM** |
| 15 | `sum_telescoping_le_one` | **🎓 THEOREM** (subset + telescoping) |
| 16 | `prime_sq_reciprocal_le_half` | **🎓 THEOREM** (split + reindex + telescope) |
| 17 | `nonsqfree_le_sqfree` | **🎓 THEOREM** (chains 11 + 9 + 16) |
| 18 | `nonsqfree_upper` | **🎓 THEOREM** |
| 19 | `sqfreeReciprocal_lower_bound` | **🎓 THEOREM** (the graduation target) |
| 20 | `definitions_agree` | **🎓 THEOREM** |

### Architecture
The final theorem `sqfreeReciprocal_lower_bound` is FULLY PROVED from
two intermediate results:
  1. `harmonicSum_ge_log`: H(N) ≥ logN  (FULLY PROVED)
  2. `nonsqfree_le_sqfree`: nonsqfree ≤ sqfree (FULLY PROVED)
     ← chains: prime_union_bound → multiples_sq_reciprocal_le → prime_sq_reciprocal_le_half
Combined: sqfree = H − nonsqfree ≥ H − sqfree ⟹ sqfree ≥ H/2 ≥ logN/2 ✓

### Critical Path Impact
The `squarefree_reciprocal_lower` axiom in CoprimeDiagonal.lean is
FULLY GRADUATED by `sqfreeReciprocal_lower_bound` (modulo the definitions_agree
compatibility lemma). This file contains ZERO sorries.
-/

end Cathedral.NumberTheory.SquarefreeReciprocal

end
