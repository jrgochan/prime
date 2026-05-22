/-
  Cathedral/Structural/TailSumBound.lean

  ## Tail Sum Bound: Σ_{k>N} d(k)²/k³ ≤ C/N

  The final piece of the graduation chain for λ_min ≥ c/N.
  Combined with:
  - telescoping (PROVED)
  - divisor_drop_bound (AXIOM)
  - lambdaMin_from_drop_bound (PROVED)

  Architecture:
  - §1: Divisor count bound (d(n)² ≤ 4n)
  - §2: Reciprocal square sum bound (Σ 1/k² ≤ 1/N)
  - §3: Tail sum bound for d²/k³
  - §4: The graduation theorem
-/

import Cathedral.Structural.DivisorDropBound

noncomputable section
open Real Finset

-- ════════════════════════════════════════════════
-- §1: DIVISOR COUNT BOUND
-- ════════════════════════════════════════════════

/-- **Divisor count bound**: d(n)² ≤ 4n for all n ≥ 1.

    Proof: d(n) ≤ 2⌊√n⌋ by the standard pairing argument:
    split n.divisors into lo = {d | d ≤ √n} and hi = {d | d > √n}.
    The map d ↦ n/d injects hi → lo (since d∣n and d > √n implies
    n/d ≤ √n, and the map is injective on divisors of n).
    Since |lo| ≤ √n, we get d(n) ≤ 2√n, so d(n)² ≤ 4n. -/
lemma divisor_count_sq_le (n : ℕ) (hn : 1 ≤ n) :
    (n.divisors.card : ℝ) ^ 2 ≤ 4 * (n : ℝ) := by
  have hn_ne : n ≠ 0 := by omega
  -- Suffices to show d(n) ≤ 2√n at the ℕ level
  suffices h_le : n.divisors.card ≤ 2 * n.sqrt by
    have h_sq : (n.sqrt : ℝ) ^ 2 ≤ (n : ℝ) := by exact_mod_cast Nat.sqrt_le' n
    calc (n.divisors.card : ℝ) ^ 2
        ≤ (2 * (n.sqrt : ℝ)) ^ 2 := by
          apply sq_le_sq'
          · linarith [Nat.cast_nonneg (α := ℝ) n.divisors.card]
          · exact_mod_cast h_le
      _ = 4 * (n.sqrt : ℝ) ^ 2 := by ring
      _ ≤ 4 * (n : ℝ) := by linarith
  -- Prove d(n) ≤ 2·√n by splitting into lo and hi
  -- d(n) = |lo| + |hi| where lo = {d ≤ √n}, hi = {d > √n}
  have h_split := (Finset.card_filter_add_card_filter_not
    (p := (· ≤ n.sqrt)) (s := n.divisors)).symm
  -- |lo| ≤ √n: elements of lo ⊆ {1, ..., √n}
  have h_lo : (n.divisors.filter (· ≤ n.sqrt)).card ≤ n.sqrt := by
    have h_sub : n.divisors.filter (· ≤ n.sqrt) ⊆ Finset.Icc 1 n.sqrt := by
      intro d hd
      rw [Finset.mem_filter] at hd
      exact Finset.mem_Icc.mpr ⟨Nat.pos_of_mem_divisors hd.1, hd.2⟩
    calc (n.divisors.filter (· ≤ n.sqrt)).card
        ≤ (Finset.Icc 1 n.sqrt).card := Finset.card_le_card h_sub
      _ = n.sqrt := by simp
  -- |hi| ≤ √n: inject via d ↦ n/d into {1, ..., √n}
  have h_hi : (n.divisors.filter (fun a => ¬ a ≤ n.sqrt)).card ≤ n.sqrt := by
    -- First show the injection, then bound the target
    set hi := n.divisors.filter (fun a => ¬ a ≤ n.sqrt)
    have h_maps : Set.MapsTo (fun d => n / d) (↑hi) (↑(Finset.Icc 1 n.sqrt)) := by
      intro d hd
      rw [Finset.mem_coe, Finset.mem_filter] at hd
      rw [Finset.mem_coe]
      refine Finset.mem_Icc.mpr ⟨Nat.div_pos (Nat.le_of_dvd (by omega) ((Nat.mem_divisors.mp hd.1).1)) (by omega), ?_⟩
      by_contra h_bad
      push Not at h_bad
      have h_dvd := (Nat.mem_divisors.mp hd.1).1
      have : (n.sqrt + 1) * (n.sqrt + 1) ≤ n := by
        calc (n.sqrt + 1) * (n.sqrt + 1)
            ≤ (n / d) * d := Nat.mul_le_mul h_bad (by omega : n.sqrt + 1 ≤ d)
          _ = n := Nat.div_mul_cancel h_dvd
      linarith [Nat.lt_succ_sqrt n]
    have h_inj : Set.InjOn (fun d => n / d) (↑hi) := by
      intro a ha b hb hab
      rw [Finset.mem_coe, Finset.mem_filter] at ha hb
      have ha_dvd := (Nat.mem_divisors.mp ha.1).1
      have hb_dvd := (Nat.mem_divisors.mp hb.1).1
      have h_a : (n / a) * a = n := Nat.div_mul_cancel ha_dvd
      have h_b : (n / b) * b = n := Nat.div_mul_cancel hb_dvd
      -- hab : n/a = n/b. So (n/a)*a = n = (n/b)*b = (n/a)*b
      have hab' : n / a = n / b := hab
      have h_pos : 0 < n / a := Nat.div_pos (Nat.le_of_dvd (by omega) ha_dvd) (by omega)
      have h_eq : (n / a) * a = (n / a) * b := by rw [h_a, hab', h_b]
      exact Nat.eq_of_mul_eq_mul_left h_pos h_eq
    calc hi.card
        ≤ (Finset.Icc 1 n.sqrt).card := Finset.card_le_card_of_injOn _ h_maps h_inj
      _ = n.sqrt := by simp
  linarith

/-- Consequence: d(n)² / n³ ≤ 4 / n² for n ≥ 1.

    Proof: d²/n³ = (d²/n) · (1/n²) ≤ 4 · (1/n²) = 4/n². -/
lemma divisor_sq_div_cube_le (n : ℕ) (hn : 1 ≤ n) :
    (n.divisors.card : ℝ) ^ 2 / (n : ℝ) ^ 3 ≤ 4 / (n : ℝ) ^ 2 := by
  have hn_pos : (0 : ℝ) < (n : ℝ) := Nat.cast_pos.mpr (by omega)
  have h := divisor_count_sq_le n hn
  -- Factor: d²/n³ = (d²/n) · (1/n²), and d²/n ≤ 4
  have h_inv_sq_pos : (0 : ℝ) ≤ 1 / (n : ℝ) ^ 2 := by positivity
  calc (n.divisors.card : ℝ) ^ 2 / (n : ℝ) ^ 3
      = ((n.divisors.card : ℝ) ^ 2 / (n : ℝ)) * (1 / (n : ℝ) ^ 2) := by ring
    _ ≤ 4 * (1 / (n : ℝ) ^ 2) := by
        apply mul_le_mul_of_nonneg_right _ h_inv_sq_pos
        -- d²/n ≤ 4
        have hn_ne : (n : ℝ) ≠ 0 := ne_of_gt hn_pos
        rwa [div_le_iff₀ hn_pos]
    _ = 4 / (n : ℝ) ^ 2 := by ring

-- ════════════════════════════════════════════════
-- §2: RECIPROCAL SQUARE SUM BOUND
-- ════════════════════════════════════════════════

/-- Per-term bound: 1/k² ≤ 1/(k-1) - 1/k for natural k ≥ 2.
    Equivalently: 1/k² ≤ 1/((k-1)·k) since (k-1)·k ≤ k². -/
private lemma inv_sq_le_diff (k : ℕ) (hk : 2 ≤ k) :
    (1 : ℝ) / (k : ℝ) ^ 2 ≤ 1 / ((k : ℝ) - 1) - 1 / (k : ℝ) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := by positivity
  have hkm1_pos : (0 : ℝ) < (k : ℝ) - 1 := by
    have : (2 : ℝ) ≤ (k : ℝ) := by exact_mod_cast hk
    linarith
  -- Rewrite RHS as 1/((k-1)·k)
  have hrhs : 1 / ((k : ℝ) - 1) - 1 / (k : ℝ) =
      1 / (((k : ℝ) - 1) * (k : ℝ)) := by field_simp; ring
  rw [hrhs]
  -- Need: 1/k² ≤ 1/((k-1)·k), i.e. (k-1)·k ≤ k²
  -- div_le_div_of_nonneg_left : 0 < a → 0 < b → b ≤ c → a/c ≤ a/b
  -- So we want a=1, b=(k-1)·k, c=k², and need (k-1)·k ≤ k²
  have h_denom_le : ((k : ℝ) - 1) * (k : ℝ) ≤ (k : ℝ) ^ 2 := by nlinarith
  exact div_le_div_of_nonneg_left (by norm_num : (0 : ℝ) ≤ 1)
    (mul_pos hkm1_pos hk_pos) h_denom_le

/-- Telescoping sum: Σ_{k∈Ico(N+1)(M+1)} (1/(k-1) - 1/k) = 1/N - 1/M.
    The range Ico(N+1)(M+1) = {N+1, ..., M}, so:
    (1/N - 1/(N+1)) + (1/(N+1) - 1/(N+2)) + ⋯ + (1/(M-1) - 1/M) = 1/N - 1/M.
    When M = N the range is empty and 1/N - 1/N = 0. -/
private lemma telescope_sum (N M : ℕ) (_hN : 1 ≤ N) (hM : N ≤ M) :
    ∑ k ∈ Finset.Ico (N + 1) (M + 1),
      (1 / ((k : ℝ) - 1) - 1 / (k : ℝ)) = 1 / (N : ℝ) - 1 / ((M : ℝ)) := by
  obtain ⟨d, rfl⟩ := Nat.exists_eq_add_of_le hM
  induction d with
  | zero =>
    simp only [Nat.add_zero, Finset.Ico_self, Finset.sum_empty, sub_self]
  | succ d ih =>
    rw [show N + (d + 1) + 1 = (N + d + 1) + 1 from by omega]
    rw [Finset.sum_Ico_succ_top (show N + 1 ≤ N + d + 1 by omega)]
    rw [ih (by omega)]
    -- Goal: (1/↑N - 1/↑(N+d)) + (1/(↑(N+d+1) - 1) - 1/↑(N+d+1)) = 1/↑N - 1/↑(N+(d+1))
    -- Step 1: ↑(N+d+1) - 1 = ↑(N+d) (as reals)
    have h_cast : ((N + d + 1 : ℕ) : ℝ) - 1 = ((N + d : ℕ) : ℝ) := by push_cast; ring
    rw [h_cast]
    -- Step 2: ↑(N+(d+1)) = ↑(N+d+1)
    have h_eq : ((N + (d + 1) : ℕ) : ℝ) = ((N + d + 1 : ℕ) : ℝ) := by push_cast; ring
    rw [h_eq]
    -- Goal: (1/↑N - 1/↑(N+d)) + (1/↑(N+d) - 1/↑(N+d+1)) = 1/↑N - 1/↑(N+d+1)
    -- This is exactly: a - b + (b - c) = a - c
    have := sub_add_sub_cancel (1 / (N : ℝ)) (1 / ((N + d : ℕ) : ℝ)) (1 / ((N + d + 1 : ℕ) : ℝ))
    linarith

/-- **Telescoping bound for reciprocal squares.**

    Σ_{k=N+1}^{M} 1/k² ≤ 1/N for all M ≥ N ≥ 1.

    Proof: 1/k² ≤ 1/(k-1) - 1/k (inv_sq_le_diff), then sum telescopes. -/
lemma reciprocal_sq_sum_le (N M : ℕ) (hN : 1 ≤ N) (hM : N ≤ M) :
    ∑ k ∈ Finset.Ico (N + 1) (M + 1),
      (1 : ℝ) / ((k : ℝ) ^ 2) ≤ 1 / (N : ℝ) := by
  -- Step 1: bound each term using inv_sq_le_diff
  have h1 : ∑ k ∈ Finset.Ico (N + 1) (M + 1), (1 : ℝ) / ((k : ℝ) ^ 2)
      ≤ ∑ k ∈ Finset.Ico (N + 1) (M + 1), (1 / ((k : ℝ) - 1) - 1 / (k : ℝ)) := by
    apply Finset.sum_le_sum
    intro k hk
    rw [Finset.mem_Ico] at hk
    exact inv_sq_le_diff k (by omega)
  -- Step 2: the RHS telescopes to 1/N - 1/M ≤ 1/N
  have h2 := telescope_sum N M hN hM
  have : (0 : ℝ) ≤ 1 / (M : ℝ) := by positivity
  linarith

-- ════════════════════════════════════════════════
-- §3: TAIL SUM BOUND FOR d²/k³
-- ════════════════════════════════════════════════

/-- **Tail sum bound**: Σ_{k=N+1}^{M} d(k)²/k³ ≤ 4/N.

    Chains divisor_sq_div_cube_le with reciprocal_sq_sum_le:
    Σ d(k)²/k³ ≤ Σ 4/k² = 4 · Σ 1/k² ≤ 4/N. -/
theorem tail_sum_divisor_bound (N M : ℕ) (hN : 1 ≤ N) (hM : N ≤ M) :
    ∑ k ∈ Finset.Ico (N + 1) (M + 1),
      ((k : ℕ).divisors.card : ℝ) ^ 2 / ((k : ℝ) ^ 3) ≤
    4 / (N : ℝ) := by
  calc ∑ k ∈ Finset.Ico (N + 1) (M + 1),
        ((k : ℕ).divisors.card : ℝ) ^ 2 / ((k : ℝ) ^ 3)
      ≤ ∑ k ∈ Finset.Ico (N + 1) (M + 1), 4 / ((k : ℝ) ^ 2) := by
        apply Finset.sum_le_sum
        intro k hk
        rw [Finset.mem_Ico] at hk
        exact divisor_sq_div_cube_le k (by omega)
    _ = 4 * ∑ k ∈ Finset.Ico (N + 1) (M + 1), 1 / ((k : ℝ) ^ 2) := by
        simp_rw [show ∀ k : ℕ, (4 : ℝ) / ((k : ℝ) ^ 2) = 4 * (1 / ((k : ℝ) ^ 2))
          from fun k => by ring]
        rw [← Finset.mul_sum]
    _ ≤ 4 * (1 / (N : ℝ)) := by
        apply mul_le_mul_of_nonneg_left (reciprocal_sq_sum_le N M hN hM)
        norm_num
    _ = 4 / (N : ℝ) := by ring

-- ════════════════════════════════════════════════
-- §4: THE GRADUATION THEOREM
-- ════════════════════════════════════════════════

/-- **Eigenvalue linear scaling** (from telescoping + drop bound + tail sum).

    Chains lambdaMin_from_drop_bound with tail_sum_divisor_bound:
    λ_min(N) ≥ λ_min(N₀) - C · Σ d(k+1)²/(k+1)³
             ≥ λ_min(N₀) - C · 4/N₀
             = λ_min(N₀) - 4C/N₀ -/
theorem lambdaMin_constant_lower_bound (N₀ N : ℕ)
    (h₀ : 4 ≤ N₀) (hN : N₀ ≤ N) :
    ∃ C : ℝ, 0 < C ∧
    lambdaMin N ≥ lambdaMin N₀ - 4 * C / (N₀ : ℝ) := by
  -- Get lambdaMin_from_drop_bound
  obtain ⟨C, hC_pos, h_drop⟩ := lambdaMin_from_drop_bound N₀ N (by omega) hN
  refine ⟨C, hC_pos, ?_⟩
  -- h_drop: λ_min(N) ≥ λ_min(N₀) - C · Σ_{k∈Ico(N₀,N)} d(k+1)²/(k+1)³
  -- Suffices: Σ_{k∈Ico(N₀,N)} d(k+1)²/(k+1)³ ≤ 4/N₀
  -- Then: λ_min(N₀) - 4C/N₀ ≤ λ_min(N₀) - C·Σ ≤ λ_min(N)
  suffices h_sum : C * ∑ k ∈ Finset.Ico N₀ N,
      ((k + 1 : ℕ).divisors.card : ℝ) ^ 2 / ((k + 1 : ℕ) : ℝ) ^ 3
      ≤ 4 * C / (N₀ : ℝ) by linarith
  -- Factor out C: C · Σ ≤ C · 4/N₀ ↔ Σ ≤ 4/N₀
  have h_C_mul : 4 * C / (N₀ : ℝ) = C * (4 / (N₀ : ℝ)) := by ring
  rw [h_C_mul]
  apply mul_le_mul_of_nonneg_left _ (le_of_lt hC_pos)
  -- Need: Σ_{k∈Ico(N₀,N)} d(k+1)²/(k+1)³ ≤ 4/N₀
  -- Reindex: j = k+1 maps Ico(N₀,N) → Ico(N₀+1,N+1)
  -- So this sum equals Σ_{j∈Ico(N₀+1,N+1)} d(j)²/j³
  -- which is exactly tail_sum_divisor_bound N₀ N
  have h_reindex : ∑ k ∈ Finset.Ico N₀ N,
      ((k + 1 : ℕ).divisors.card : ℝ) ^ 2 / ((k + 1 : ℕ) : ℝ) ^ 3
    = ∑ j ∈ Finset.Ico (N₀ + 1) (N + 1),
      ((j : ℕ).divisors.card : ℝ) ^ 2 / ((j : ℝ) ^ 3) := by
    apply Finset.sum_nbij' (fun k => k + 1) (fun j => j - 1)
    · intro k hk; simp only [Finset.mem_Ico] at hk ⊢; omega
    · intro j hj; simp only [Finset.mem_Ico] at hj ⊢; omega
    · intro k hk; omega
    · intro j hj; simp only [Finset.mem_Ico] at hj; omega
    · intro k hk; simp
  rw [h_reindex]
  exact tail_sum_divisor_bound N₀ N (by omega) hN

end
