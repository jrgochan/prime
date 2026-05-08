/-
  Cathedral/Structural/BDFloorArithmetic.lean

  ## BD-basis floor arithmetic for linear independence.

  Key result: on the open interval (1/(n+1), 1/n), the floor ⌊1/(mx)⌋
  is CONSTANT for every positive integer m, equal to ⌊n/m⌋.

  This is because 1/(mx) ∈ (n/m, (n+1)/m) on this interval,
  and no integer lies strictly between n/m and (n+1)/m
  (that would require an integer strictly between n and n+1).

  Used by: Independence.lean to graduate bd_nyman_beurling_lin_indep.
-/

import Cathedral.Defs
import Cathedral.Gram.NbLinComb

noncomputable section
open Complex Real MeasureTheory

-- ════════════════════════════════════════════════
-- PART I: FLOOR CONSTANCY ON (1/(n+1), 1/n)
-- ════════════════════════════════════════════════

/-- No integer lies strictly between n/m and (n+1)/m for positive integers n, m.
    Proof: if q ∈ (n/m, (n+1)/m) then n < q*m < n+1, impossible for integers. -/
private lemma no_int_between_div (n m : ℕ) (hm : 1 ≤ m) :
    ∀ q : ℤ, ¬((n : ℝ) / m < q ∧ (q : ℝ) < (n + 1 : ℝ) / m) := by
  intro q ⟨h1, h2⟩
  have hm_pos : (0 : ℝ) < m := by exact_mod_cast show 0 < m by omega
  have h1' : (n : ℝ) < q * m := by rwa [div_lt_iff₀ hm_pos] at h1
  have h2' : (q : ℝ) * m < n + 1 := by rwa [lt_div_iff₀ hm_pos] at h2
  have h_int : (n : ℤ) < q * m ∧ q * m < n + 1 := by
    constructor
    · exact_mod_cast h1'
    · exact_mod_cast h2'
  omega

/-- On (1/(n+1), 1/n), ⌊1/(mx)⌋ = ⌊n/m⌋ for m ≥ 1, n ≥ 1. -/
theorem bd_floor_constant {n m : ℕ} (hn : 1 ≤ n) (hm : 1 ≤ m)
    {x : ℝ} (hx_lo : 1 / ((n : ℝ) + 1) < x) (hx_hi : x < 1 / (n : ℝ)) :
    ⌊1 / ((m : ℝ) * x)⌋ = ⌊(n : ℝ) / m⌋ := by
  have hm_pos : (0 : ℝ) < m := by exact_mod_cast show 0 < m by omega
  have hn_pos : (0 : ℝ) < n := by exact_mod_cast show 0 < n by omega
  have hn1_pos : (0 : ℝ) < (n : ℝ) + 1 := by linarith
  have hx_pos : 0 < x := by
    calc (0 : ℝ) < 1 / ((n : ℝ) + 1) := by positivity
    _ < x := hx_lo
  have hmx_pos : 0 < m * x := mul_pos hm_pos hx_pos
  -- Key bounds: x > 1/(n+1) means (n+1)*x > 1, and x < 1/n means n*x < 1
  have h_nx_lt : (n : ℝ) * x < 1 := by
    have := hx_hi; rwa [lt_div_iff₀ hn_pos, mul_comm] at this
  have h_n1x_gt : 1 < ((↑n : ℝ) + 1) * x := by
    have := hx_lo; rwa [div_lt_iff₀ hn1_pos, mul_comm] at this
  -- 1/(mx) ∈ (n/m, (n+1)/m)
  have h_lo : (n : ℝ) / m < 1 / (m * x) := by
    rw [div_lt_div_iff₀ hm_pos hmx_pos, one_mul]
    nlinarith [mul_comm (m : ℝ) ((n : ℝ) * x), mul_comm (n : ℝ) x, mul_comm (m : ℝ) x]
  have h_hi : 1 / ((m : ℝ) * x) < ((n : ℝ) + 1) / m := by
    rw [div_lt_div_iff₀ hmx_pos hm_pos, one_mul]
    nlinarith [mul_comm (m : ℝ) (((n : ℝ) + 1) * x), mul_comm ((n : ℝ) + 1) x, mul_comm (m : ℝ) x]
  -- Floor is constant because no integer in (n/m, (n+1)/m)
  rw [Int.floor_eq_iff]
  constructor
  · -- ⌊n/m⌋ ≤ 1/(mx)
    exact le_of_lt (lt_of_le_of_lt (Int.floor_le _) h_lo)
  · -- 1/(mx) < ⌊n/m⌋ + 1
    by_contra h_not
    simp only [not_lt] at h_not
    -- h_not : ↑⌊↑n / ↑m⌋ + 1 ≤ 1 / (↑m * x)
    -- Need: ↑(⌊↑n / ↑m⌋ + 1) ≤ 1 / (↑m * x)
    have h_q : ((⌊(n : ℝ) / m⌋ + 1 : ℤ) : ℝ) ≤ 1 / (↑m * x) := by push_cast; exact h_not
    have h_q' : (n : ℝ) / m < (⌊(n : ℝ) / m⌋ + 1 : ℤ) := by
      exact_mod_cast Int.lt_floor_add_one ((n : ℝ) / m)
    have h_q'' : ((⌊(n : ℝ) / m⌋ + 1 : ℤ) : ℝ) < ((n : ℝ) + 1) / m :=
      lt_of_le_of_lt h_q h_hi
    exact no_int_between_div n m hm (⌊(n : ℝ) / m⌋ + 1) ⟨h_q', h_q''⟩

/-- Fractional part formula: on (1/(n+1), 1/n), {1/(mx)} = 1/(mx) - ⌊n/m⌋. -/
theorem bd_fract_on_interval {n m : ℕ} (hn : 1 ≤ n) (hm : 1 ≤ m)
    {x : ℝ} (hx_lo : 1 / ((n : ℝ) + 1) < x) (hx_hi : x < 1 / (n : ℝ)) :
    Int.fract (1 / ((m : ℝ) * x)) = 1 / ((m : ℝ) * x) - ↑⌊(n : ℝ) / m⌋ := by
  simp only [Int.fract, bd_floor_constant hn hm hx_lo hx_hi]

-- ════════════════════════════════════════════════
-- PART II: LINEAR COMBINATION ON (1/(n+1), 1/n)
-- ════════════════════════════════════════════════

/-- On (1/(n+1), 1/n), nbLinComb N w x = B/x - C_n where
    B = Σ wᵢ/(i+1) and C_n = Σ wᵢ · ⌊n/(i+1)⌋. -/
theorem bd_nbLinComb_affine (N : ℕ) (w : Fin (N - 1) → ℝ)
    (n : ℕ) (hn : 1 ≤ n)
    {x : ℝ} (hx_lo : 1 / ((n : ℝ) + 1) < x) (hx_hi : x < 1 / (n : ℝ)) :
    nbLinComb N w x =
    (∑ i : Fin (N - 1), w i / (↑(i.val + 1) : ℝ)) * (1 / x) -
    (∑ i : Fin (N - 1), w i * ↑⌊(n : ℝ) / (↑(i.val + 1) : ℝ)⌋) := by
  have hx_pos : 0 < x := by
    calc (0 : ℝ) < 1 / ((n : ℝ) + 1) := by positivity
    _ < x := hx_lo
  unfold nbLinComb
  -- Rewrite each fractional part using floor constancy
  have h_fract : ∀ i : Fin (N - 1),
      Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) =
      1 / ((↑(i.val + 1) : ℝ) * x) - ↑⌊(n : ℝ) / (↑(i.val + 1) : ℝ)⌋ :=
    fun i => bd_fract_on_interval hn (by omega : 1 ≤ i.val + 1) hx_lo hx_hi
  simp_rw [h_fract, mul_sub, Finset.sum_sub_distrib]
  congr 1
  -- Need: Σ wᵢ * (1/(mᵢ*x)) = (Σ wᵢ/mᵢ) * (1/x)
  have h_eq : ∀ i : Fin (N - 1),
      w i * (1 / ((↑(i.val + 1) : ℝ) * x)) =
      w i / (↑(i.val + 1) : ℝ) * (1 / x) := by
    intro i
    have hi_pos : (0 : ℝ) < ↑(i.val + 1) := by positivity
    field_simp
  simp_rw [h_eq, ← Finset.sum_mul]

-- ════════════════════════════════════════════════
-- PART III: INDUCTIVE EXTRACTION (B = 0 CASE)
-- ════════════════════════════════════════════════

/-- If C₁ = C₂ = ... = C_{k-1} = 0 and w₀ = w₁ = ... = w_{k-2} = 0,
    then C_k = w_{k-1}. This is because ⌊k/k⌋ = 1 and all lower
    terms vanish. -/
private lemma C_extract (N : ℕ) (w : Fin (N - 1) → ℝ)
    (k : ℕ) (hk : 1 ≤ k) (hkN : k ≤ N - 1)
    (hw_zero : ∀ i : Fin (N - 1), i.val < k - 1 → w i = 0) :
    (∑ i : Fin (N - 1), w i * ↑⌊(k : ℝ) / (↑(i.val + 1) : ℝ)⌋) =
    w ⟨k - 1, by omega⟩ := by
  have h_terms : ∀ i : Fin (N - 1),
      w i * ↑⌊(k : ℝ) / (↑(i.val + 1) : ℝ)⌋ =
      if i.val = k - 1 then w ⟨k - 1, by omega⟩ else 0 := by
    intro ⟨i, hi⟩
    by_cases heq : i = k - 1
    · subst heq
      simp only [ite_true]
      have hkk : (k - 1 + 1 : ℕ) = k := by omega
      have hk_pos : (0 : ℝ) < (k : ℝ) := by exact_mod_cast show 0 < k by omega
      have h_floor : ⌊(k : ℝ) / (↑(k - 1 + 1) : ℝ)⌋ = 1 := by
        rw [show (↑(k - 1 + 1 : ℕ) : ℝ) = (k : ℝ) from by exact_mod_cast hkk]
        rw [div_self (ne_of_gt hk_pos)]
        simp
      rw [h_floor]; push_cast; ring
    · by_cases hlt : i < k - 1
      · rw [hw_zero ⟨i, hi⟩ hlt, zero_mul, if_neg heq]
      · have hgt : i ≥ k := by omega
        have h_floor : ⌊(k : ℝ) / (↑(i + 1) : ℝ)⌋ = 0 := by
          rw [Int.floor_eq_zero_iff.mpr]
          constructor
          · positivity
          · rw [div_lt_one (by positivity : (0 : ℝ) < ↑(i + 1))]
            exact_mod_cast show (k : ℕ) < i + 1 by omega
        rw [h_floor]; simp [if_neg heq]
  simp_rw [h_terms]
  -- Sum of if-then-else over Fin collapses to the matching term
  -- The condition is on i.val = k - 1, so we transform to Fin comparison
  have : ∀ i : Fin (N - 1),
      (if i.val = k - 1 then w ⟨k - 1, by omega⟩ else 0) =
      (if i = ⟨k - 1, by omega⟩ then w ⟨k - 1, by omega⟩ else 0) := by
    intro i
    simp only [Fin.ext_iff]
  simp_rw [this]
  simp [Finset.sum_ite_eq', Finset.mem_univ]

/-- If w ≠ 0, there exists n such that C_n ≠ 0. -/
theorem bd_exists_nonzero_C (N : ℕ) (hN : 2 ≤ N) (w : Fin (N - 1) → ℝ) (hw : w ≠ 0) :
    ∃ n : ℕ, 1 ≤ n ∧ n ≤ N - 1 ∧
    (∑ i : Fin (N - 1), w i * ↑⌊(n : ℝ) / (↑(i.val + 1) : ℝ)⌋) ≠ 0 := by
  -- w ≠ 0 means some w_j ≠ 0
  have hw_exists : ∃ j : Fin (N - 1), w j ≠ 0 := by
    by_contra h; simp only [not_exists, ne_eq, not_not] at h; exact hw (funext h)
  -- Find the smallest index with w_{j₀} ≠ 0
  let S := Finset.filter (fun i : Fin (N - 1) => w i ≠ 0) Finset.univ
  have hS : S.Nonempty := by
    obtain ⟨j₀, hj₀_ne⟩ := hw_exists
    exact ⟨j₀, Finset.mem_filter.mpr ⟨Finset.mem_univ _, hj₀_ne⟩⟩
  set j_min := S.min' hS
  have hj_min_ne : w j_min ≠ 0 := (Finset.mem_filter.mp (Finset.min'_mem S hS)).2
  have hj_min_le : ∀ i : Fin (N - 1), w i ≠ 0 → j_min ≤ i :=
    fun i hi => Finset.min'_le S i (Finset.mem_filter.mpr ⟨Finset.mem_univ _, hi⟩)
  have hw_below : ∀ i : Fin (N - 1), i.val < j_min.val → w i = 0 := by
    intro i hi
    by_contra h_ne
    exact absurd (hj_min_le i h_ne) (not_le.mpr (Fin.lt_def.mpr hi))
  refine ⟨j_min.val + 1, by omega, by omega, ?_⟩
  rw [C_extract N w (j_min.val + 1) (by omega) (by omega) (by intro i hi; exact hw_below i (by omega))]
  exact hj_min_ne

-- ════════════════════════════════════════════════
-- PART IV: NONZERO SOMEWHERE
-- ════════════════════════════════════════════════

/-- If w ≠ 0, nbLinComb is nonzero on some open subinterval of (0,1). -/
theorem bd_nbLinComb_nonzero_somewhere (N : ℕ) (hN : 2 ≤ N)
    (w : Fin (N - 1) → ℝ) (hw : w ≠ 0) :
    ∃ c d : ℝ, 0 ≤ c ∧ c < d ∧ d ≤ 1 ∧
    (∀ x, x ∈ Set.Ioo c d → nbLinComb N w x ≠ 0) := by
  -- Abbreviations for the leading coefficient and constant term
  -- We use `set` so that `B` and its unfolding are interchangeable
  set B := ∑ i : Fin (N - 1), w i / (↑(i.val + 1) : ℝ) with B_def
  by_cases hB : B ≠ 0
  · -- Case 1: B ≠ 0. On (1/2, 1), nbLinComb(x) = B*(1/x) - C₁.
    set C₁ := ∑ i : Fin (N - 1), w i * ↑⌊(↑(1 : ℕ) : ℝ) / (↑(i.val + 1) : ℝ)⌋ with C₁_def
    have h_eval : ∀ x : ℝ, 1/2 < x → x < 1 →
        nbLinComb N w x = B * (1/x) - C₁ := by
      intro x hlo hhi
      have hlo' : 1 / ((↑(1 : ℕ) : ℝ) + 1) < x := by push_cast; linarith
      have hhi' : x < 1 / (↑(1 : ℕ) : ℝ) := by push_cast; linarith
      have h := bd_nbLinComb_affine N w 1 le_rfl hlo' hhi'
      -- Fold the raw sum for B back; C₁ already matches since we used ↑(1:ℕ)
      rw [← B_def] at h
      exact h
    -- Core lemma: if B*(1/x) = C₁ and B*(1/y) = C₁ with B ≠ 0, then x = y
    have h_inj : ∀ x y : ℝ, 0 < x → 0 < y →
        B * (1/x) = C₁ → B * (1/y) = C₁ → x = y := by
      intro x y hx hy h1 h2
      have : B * (1/x) = B * (1/y) := by linarith
      have := mul_left_cancel₀ hB this
      field_simp at this; linarith
    -- Either ¬∃ zero in (1/2, 3/4), or ¬∃ zero in (3/4, 1)
    by_cases h_lo : ∀ x, x ∈ Set.Ioo (1/2 : ℝ) (3/4) → B * (1/x) - C₁ ≠ 0
    · refine ⟨1/2, 3/4, by linarith, by linarith, by linarith, ?_⟩
      intro x hx
      have hx1 : x < 1 := lt_trans hx.2 (by norm_num : (3:ℝ)/4 < 1)
      rw [h_eval x hx.1 hx1]; exact h_lo x hx
    · -- There exists x₀ ∈ (1/2, 3/4) with B*(1/x₀) = C₁
      simp only [not_forall, not_not, exists_prop] at h_lo
      obtain ⟨x₀, hx₀_mem, hx₀_eq⟩ := h_lo
      have hx₀_eq : B * (1/x₀) = C₁ := by linarith
      have hx₀_pos : (0:ℝ) < x₀ := by linarith [hx₀_mem.1]
      -- Then for all y ∈ (3/4, 1), y ≠ x₀, so B*(1/y) ≠ C₁
      refine ⟨3/4, 1, by linarith, by linarith, le_refl _, ?_⟩
      intro y ⟨hy_lo, hy_hi⟩
      rw [h_eval y (by linarith) hy_hi]
      intro heq
      have hy_pos : (0:ℝ) < y := by linarith
      have : y = x₀ := h_inj y x₀ hy_pos hx₀_pos (by linarith) hx₀_eq
      linarith [hx₀_mem.2]
  · -- Case 2: B = 0. nbLinComb = -C_n on each (1/(n+1), 1/n)
    simp only [ne_eq, not_not] at hB
    obtain ⟨n, hn_pos, hn_le, hCn⟩ := bd_exists_nonzero_C N hN w hw
    have hn_real_pos : (0 : ℝ) < n := by exact_mod_cast show 0 < n by omega
    have hn1_real_pos : (0 : ℝ) < (n : ℝ) + 1 := by linarith
    refine ⟨1 / ((n : ℝ) + 1), 1 / (n : ℝ),
      by positivity,
      by rw [div_lt_div_iff₀ hn1_real_pos hn_real_pos]; linarith,
      ?_, ?_⟩
    · rw [div_le_one hn_real_pos]; exact_mod_cast show 1 ≤ n by omega
    · intro x ⟨hx_lo, hx_hi⟩
      have h_affine := bd_nbLinComb_affine N w n (by omega) hx_lo hx_hi
      -- Fold the leading coefficient sum back into B, then use hB : B = 0
      rw [← B_def] at h_affine
      rw [h_affine, hB, zero_mul, zero_sub]
      exact neg_ne_zero.mpr hCn

end
