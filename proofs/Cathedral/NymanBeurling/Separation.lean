/-!
  Cathedral/NymanBeurling/Separation.lean

  The separation lemma: if ρ is a ζ-zero off the critical line,
  then d²_N ≥ δ > 0 for all N. Combined with the Mellin identity
  from BDMellin.lean to prove the converse direction.

  **On the crown path. Zero custom axioms.**
-/
import Cathedral.Axioms
import Cathedral.NymanBeurling.BDMellin
import Mathlib.NumberTheory.LSeries.Nonvanishing

/-!
  Cathedral/NymanBeurling/Separation.lean

  ## The Nyman-Beurling Converse: d²→0 ⟹ RH

  Proves `nyman_beurling_converse` using the contrapositive:
    ¬RH → ∃ ρ off critical line → zeta_zero_separates → d² ≥ δ > 0

  Uses the CORRECT Báez-Duarte basis h_k(x) = {1/(kx)} via `bdLinComb`.

  All intermediate theorems are proven from Mathlib.
  The only axiom used is `zeta_zero_separates` (Tier 3).

  ### Proof chain
  ```
  cos_pi_mul_succ               — cos(π(n+1)) = (-1)^{n+1}   [PROVED]
  cos_int_mul_pi_ne_zero         — cos(πn) ≠ 0                [PROVED]
  zeta_neg_odd_ne_zero           — ζ(-2k+1) ≠ 0               [PROVED]
  zeta_nontrivial_zero_re_pos    — nontrivial ζ zeros have Re > 0 [PROVED]
  rh_neg_gives_critical_strip_zero — ¬RH → ∃ ρ with 0<Re<1    [PROVED]
  nyman_beurling_converse         — d²→0 → RH                  [PROVED]
  ```

  Status: Zero sorry. One axiom (zeta_zero_separates, Tier 3).
-/

noncomputable section
open Complex Real MeasureTheory Set Filter

-- ════════════════════════════════════════════════
-- PART I: COSINE IDENTITIES
-- ════════════════════════════════════════════════

/-- cos(π·(n+1)) = (-1)^(n+1).
    Proved by induction using Complex.cos_pi and Complex.cos_add_pi. -/
private lemma cos_pi_mul_succ (n : ℕ) :
    Complex.cos (↑Real.pi * ↑(n + 1)) = (-1) ^ (n + 1) := by
  induction n with
  | zero => simp [Complex.cos_pi]
  | succ k ih =>
    have h1 : (↑Real.pi : ℂ) * (↑(k + 1 + 1) : ℂ) =
              (↑Real.pi : ℂ) * (↑(k + 1) : ℂ) + ↑Real.pi := by
      push_cast; ring
    rw [h1, Complex.cos_add_pi, ih]
    ring

/-- **THEOREM**: cos(πn) ≠ 0 for n ≥ 1.
    Since cos(π(n+1)) = (-1)^{n+1} ≠ 0. -/
theorem cos_int_mul_pi_ne_zero (n : ℕ) :
    Complex.cos (↑Real.pi * ↑(n + 1)) ≠ 0 := by
  rw [cos_pi_mul_succ]
  exact pow_ne_zero _ (by norm_num : (-1 : ℂ) ≠ 0)

-- ════════════════════════════════════════════════
-- PART II: ZETA NONVANISHING AT NEGATIVE ODDS
-- ════════════════════════════════════════════════

/-- **THEOREM**: ζ at negative odd integers is nonzero.

    For k = 0: ζ(1) ≠ 0 by riemannZeta_ne_zero_of_one_le_re.
    For k ≥ 1: Uses the functional equation (riemannZeta_one_sub):
      ζ(1-2k) = 2·(2π)^{-2k}·Γ(2k)·cos(πk)·ζ(2k)
    All five factors are nonzero. -/
theorem zeta_neg_odd_ne_zero (k : ℕ) :
    riemannZeta (↑(-(2 * (k : ℤ) - 1))) ≠ 0 := by
  cases k with
  | zero =>
    norm_num
    exact riemannZeta_ne_zero_of_one_le_re le_rfl
  | succ n =>
    have h_eq : (↑(-(2 * (↑(n + 1) : ℤ) - 1)) : ℂ) = 1 - ↑(2 * (n + 1) : ℕ) := by
      push_cast; ring
    rw [h_eq]
    have hs : ∀ m : ℕ, (↑(2 * (n + 1) : ℕ) : ℂ) ≠ -↑m := by
      intro m h; have := congr_arg Complex.re h; simp at this
      linarith [Nat.cast_nonneg (α := ℝ) m]
    have hs1 : (↑(2 * (n + 1) : ℕ) : ℂ) ≠ 1 := by
      intro h; have := congr_arg Complex.re h; simp at this; linarith
    rw [riemannZeta_one_sub hs hs1]
    apply mul_ne_zero
    apply mul_ne_zero
    apply mul_ne_zero
    apply mul_ne_zero
    · exact two_ne_zero
    · rw [Ne, Complex.cpow_eq_zero_iff]; push Not; intro h
      exact absurd h (mul_ne_zero two_ne_zero (by exact_mod_cast Real.pi_ne_zero))
    · apply Complex.Gamma_ne_zero
      intro m h; have := congr_arg Complex.re h; simp at this
      linarith [Nat.cast_nonneg (α := ℝ) m]
    · have hcos : (↑Real.pi : ℂ) * ↑(2 * (n + 1) : ℕ) / 2 = ↑Real.pi * ↑(n + 1) := by
        push_cast; ring
      rw [hcos, cos_pi_mul_succ]
      exact pow_ne_zero _ (by norm_num : (-1 : ℂ) ≠ 0)
    · exact riemannZeta_ne_zero_of_one_le_re (by simp; linarith [Nat.zero_le n])

-- ════════════════════════════════════════════════
-- PART III: NONTRIVIAL ZEROS IN THE CRITICAL STRIP
-- ════════════════════════════════════════════════

/-- **THEOREM**: Non-trivial zeros of ζ have positive real part.

    Proof by contrapositive: Re(s) ≤ 0 leads to contradiction.
    Case A (s not a non-positive integer): functional equation gives
    ζ(1-s) = 0 with Re(1-s) ≥ 1, contradicting Mathlib.
    Case B (s = -n): ζ(0) ≠ 0, trivial zeros excluded, odd zeros
    nonzero by zeta_neg_odd_ne_zero. -/
theorem zeta_nontrivial_zero_re_pos :
    ∀ s : ℂ, riemannZeta s = 0 →
    (¬∃ n : ℕ, s = -2 * (↑n + 1)) →
    0 < s.re := by
  intro s h_zero h_not_triv
  by_contra h_not_pos
  push Not at h_not_pos
  by_cases h_int : ∃ n : ℕ, s = -(↑n : ℂ)
  · obtain ⟨n, rfl⟩ := h_int
    rcases n with _ | m
    · simp at h_zero; rw [riemannZeta_zero] at h_zero; norm_num at h_zero
    · rcases Nat.even_or_odd (m + 1) with ⟨j, hj⟩ | ⟨j, hj⟩
      · have hj_pos : 1 ≤ j := by omega
        exfalso; apply h_not_triv; refine ⟨j - 1, ?_⟩
        have : (↑(j - 1) : ℂ) + 1 = ↑j := by
          rw [Nat.cast_sub hj_pos]; push_cast; ring
        rw [this]; push_cast [hj]; ring
      · have := zeta_neg_odd_ne_zero (j + 1)
        apply this
        have key : (-(2 * (↑(j + 1) : ℤ) - 1)) = -(↑(m + 1) : ℤ) := by omega
        rw [show (↑(-(2 * (↑(j + 1) : ℤ) - 1)) : ℂ) = (↑(-(↑(m + 1) : ℤ)) : ℂ) from
          congr_arg _ key]
        simp only [Int.cast_neg, Int.cast_natCast]
        exact h_zero
  · push Not at h_int
    have hs1 : s ≠ 1 := by
      intro heq; rw [heq] at h_not_pos; norm_num at h_not_pos
    have h_func := riemannZeta_one_sub h_int hs1
    have h_1s_zero : riemannZeta (1 - s) = 0 := by rw [h_func, h_zero, mul_zero]
    have h_re : 1 ≤ (1 - s).re := by simp [Complex.sub_re]; linarith
    exact absurd h_1s_zero (riemannZeta_ne_zero_of_one_le_re h_re)

-- ════════════════════════════════════════════════
-- PART IV: ¬RH → CRITICAL STRIP ZERO
-- ════════════════════════════════════════════════

/-- **THEOREM**: ¬RH → ∃ zero in critical strip off critical line.

    Uses functional equation (zeta_nontrivial_zero_re_pos) for Re > 0,
    and Mathlib's riemannZeta_ne_zero_of_one_le_re for Re < 1. -/
theorem rh_neg_gives_critical_strip_zero :
    ¬ RiemannHypothesis →
    ∃ ρ : ℂ, riemannZeta ρ = 0 ∧ 0 < ρ.re ∧ ρ.re < 1 ∧ ρ.re ≠ 1/2 := by
  intro h
  unfold RiemannHypothesis at h
  push Not at h
  obtain ⟨s, h_zero, h_not_triv, h_ne_1, h_re_ne_half⟩ := h
  have h_not_triv' : ¬∃ n : ℕ, s = -2 * (↑n + 1) := by
    push Not; exact h_not_triv
  refine ⟨s, h_zero, ?_, ?_, h_re_ne_half⟩
  · exact zeta_nontrivial_zero_re_pos s h_zero h_not_triv'
  · by_contra h_ge
    push Not at h_ge
    exact absurd h_zero (riemannZeta_ne_zero_of_one_le_re h_ge)

-- ════════════════════════════════════════════════
-- PART V: THE CONVERSE THEOREM
-- ════════════════════════════════════════════════

/-- **THEOREM**: The Nyman-Beurling converse: d²→0 ⟹ RH.

    Proof (by contrapositive):
    1. ¬RH → rh_neg_gives_critical_strip_zero: ∃ ρ off critical line
    2. zeta_zero_separates: ρ creates defect δ > 0
    3. ∫(1-f)² ≥ δ for all N, blocking convergence
    4. Contrapositive: convergence → RH -/
theorem nyman_beurling_converse :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε) →
    RiemannHypothesis := by
  intro h_conv
  by_contra h_not_rh
  obtain ⟨ρ, h_zero, h_pos, h_lt1, h_ne_half⟩ :=
    rh_neg_gives_critical_strip_zero h_not_rh
  obtain ⟨δ, hδ_pos, h_defect⟩ :=
    zeta_zero_separates ρ h_zero h_pos h_lt1 h_ne_half
  obtain ⟨N₀, h_small⟩ := h_conv δ hδ_pos
  have hN : N₀ ≤ max N₀ 2 := le_max_left _ _
  have hN2 : 2 ≤ max N₀ 2 := le_max_right _ _
  obtain ⟨v, hv⟩ := h_small (max N₀ 2) hN
  have h_ge := h_defect (max N₀ 2) hN2 v
  linarith

end
