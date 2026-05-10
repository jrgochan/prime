/-
  Cathedral/Covariance/DotProductBound.lean

  ## Dot Product Bound from x^{3/4} Mertens

  Proves |1 - bᵀv| ≤ C_dot / log N under |M(x)| ≤ C·x^{3/4},
  using s1_decay, s2_decay, and s3_uniform_bound_from_mertens.

  Extracted from PerronCrown.lean to avoid circular imports
  when GramFormProof.lean needs the dot product bound.

  ### Sorry: 0
  ### Axioms: 0 (beyond kernel)

  Created: April 25, 2026
-/

import Cathedral.Defs
import Cathedral.NymanBeurling.BDBridge
import Cathedral.AbelTail.S1Decay
import Cathedral.AbelTail.S2Decay
import Cathedral.AbelTail.S3UniformBound
import Cathedral.Covariance.DotProductIdentity
import Cathedral.Covariance.CalcBounds

noncomputable section
open Real Matrix Finset Filter Cathedral.Vasyunin ArithmeticFunction

/-- **PROVED**: The dot product bᵀv ≈ 1 at rate O(1/log N), using x^{3/4} directly.

    Uses s1_decay, s2_decay (Abel tail rates from Mertens x^{3/4}),
    and s3_uniform_bound_from_mertens (Abel Bypass — no PNT₃ needed).

    PROVED, 0 axioms. -/
theorem moebius_dot_product_approx_one_uniform_34
    (C_34 : ℝ) (hC : 0 < C_34)
    (hMertens34 : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_34 * x ^ ((3:ℝ)/4))
    (hPNT₁ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) / (k : ℝ)) atTop (nhds 0))
    (hPNT₂ : Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
        (↑(moebius k) : ℝ) * Real.log (k : ℝ) / (k : ℝ)) atTop (nhds (-1))) :
    ∃ C_dot : ℝ, C_dot > 0 ∧ ∀ (N : ℕ), 10 ≤ N →
    |1 - dotProduct (fun (i : Fin (N - 1)) =>
        vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight N)| ≤
    C_dot / Real.log ↑N := by
  -- s1_decay and s2_decay take the x^{3/4} form directly
  obtain ⟨C₁, hC₁_pos, h_s1⟩ := s1_decay C_34 hC hMertens34 hPNT₁
  obtain ⟨C₂, hC₂_pos, h_s2⟩ := s2_decay C_34 hC hMertens34 hPNT₂
  obtain ⟨B₂, _hB₂_ge, h_s2_univ⟩ := tendsto_universal_bound hPNT₂
  -- THE ABEL BYPASS: use s3_uniform_bound_from_mertens instead of tendsto_universal_bound hPNT₃
  obtain ⟨B₃, _hB₃_ge, h_s3_univ⟩ := s3_uniform_bound_from_mertens C_34 hC hMertens34
  refine ⟨2 * C₁ + 10 * C₂ + B₂ + B₃ + 4, by linarith, fun N hN => ?_⟩
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have hlogN_pos : (0 : ℝ) < Real.log ↑N :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  have hlogN_ne : Real.log (↑N : ℝ) ≠ 0 := ne_of_gt hlogN_pos
  have hN1_ge2 : 2 ≤ N - 1 := by omega
  have h_identity := one_minus_dotProduct_identity N (by omega) hlogN_ne
  have h_s1_N := h_s1 (N - 1) hN1_ge2
  have h_s2_N := h_s2 (N - 1) hN1_ge2
  have h_s2_abs : |S₂_at (N - 1)| ≤ B₂ + 1 := by
    have h1 := h_s2_univ (N - 1)
    unfold S₂_at
    have h2 := abs_le.mp h1
    exact abs_le.mpr ⟨by linarith, by linarith⟩
  -- ABEL BYPASS: direct bound, no limit value needed
  have h_s3_abs : |S₃_at (N - 1)| ≤ B₃ := h_s3_univ (N - 1)
  rw [h_identity]
  have h_calc1 := rpow_quarter_logN_le_two N hN
  have h_calc2 := rpow_quarter_logsq_le_ten N hN
  have h_s1_logN : |S₁_at (N - 1)| * Real.log ↑N ≤ 2 * C₁ := by
    calc |S₁_at (N - 1)| * Real.log ↑N
        ≤ C₁ * (↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log ↑N :=
          mul_le_mul_of_nonneg_right h_s1_N (le_of_lt hlogN_pos)
      _ = C₁ * ((↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log ↑N) := by ring
      _ ≤ C₁ * 2 := mul_le_mul_of_nonneg_left h_calc1 hC₁_pos.le
      _ = 2 * C₁ := by ring
  have h_s2_logN : |S₂_at (N - 1) - (-1)| * Real.log ↑N ≤ 10 * C₂ := by
    calc |S₂_at (N - 1) - (-1)| * Real.log ↑N
        ≤ C₂ * (↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log (↑(N - 1) : ℝ) * Real.log ↑N :=
          mul_le_mul_of_nonneg_right h_s2_N (le_of_lt hlogN_pos)
      _ = C₂ * ((↑(N - 1) : ℝ) ^ (-(1:ℝ)/4) * Real.log (↑(N - 1) : ℝ) * Real.log ↑N) := by ring
      _ ≤ C₂ * 10 := mul_le_mul_of_nonneg_left h_calc2 hC₂_pos.le
      _ = 10 * C₂ := by ring
  suffices h_main : |(1 - eulerMascheroniConstant) * S₁_at (N - 1) +
      (S₂_at (N - 1) + 1) -
      ((1 - eulerMascheroniConstant) * S₂_at (N - 1) + S₃_at (N - 1)) /
        Real.log ↑N| * Real.log ↑N ≤
      2 * C₁ + 10 * C₂ + B₂ + B₃ + 4 by
    rw [le_div_iff₀ hlogN_pos]
    linarith
  have h_s2_eq : S₂_at (N - 1) + 1 = S₂_at (N - 1) - (-1) := by ring
  have h_num : |(1 - eulerMascheroniConstant) * S₂_at (N - 1) +
      S₃_at (N - 1)| ≤ B₂ + B₃ + 3 := by
    have hγ01 : 0 < 1 - eulerMascheroniConstant ∧
        1 - eulerMascheroniConstant < 1 := by
      constructor
      · linarith [eulerMascheroniConstant_lt_two_thirds]
      · linarith [one_half_lt_eulerMascheroniConstant]
    have h_s2_bound : -(B₂ + 1) ≤ (1 - eulerMascheroniConstant) * S₂_at (N - 1) ∧
        (1 - eulerMascheroniConstant) * S₂_at (N - 1) ≤ B₂ + 1 := by
      constructor
      · nlinarith [abs_le.mp h_s2_abs]
      · nlinarith [abs_le.mp h_s2_abs]
    -- ABEL BYPASS: h_s3_abs gives |S₃_at _| ≤ B₃ directly
    have h_s3_bound := abs_le.mp h_s3_abs
    exact abs_le.mpr ⟨by nlinarith, by nlinarith⟩
  have h_div_logN : |((1 - eulerMascheroniConstant) * S₂_at (N - 1) +
      S₃_at (N - 1)) / Real.log ↑N| * Real.log ↑N ≤ B₂ + B₃ + 3 := by
    rw [abs_div, abs_of_pos hlogN_pos, div_mul_cancel₀ _ hlogN_ne]
    exact h_num
  have h_term1_logN : |(1 - eulerMascheroniConstant) * S₁_at (N - 1)| *
      Real.log ↑N ≤ 2 * C₁ := by
    have hγ_bound : |1 - eulerMascheroniConstant| ≤ 1 := by
      apply abs_le.mpr; constructor
      · have := eulerMascheroniConstant_lt_two_thirds; linarith
      · have := one_half_lt_eulerMascheroniConstant; linarith
    have h1 : |(1 - eulerMascheroniConstant) * S₁_at (N - 1)| ≤
        |S₁_at (N - 1)| := by
      rw [abs_mul]
      exact le_trans (mul_le_mul_of_nonneg_right hγ_bound (abs_nonneg _))
        (by rw [one_mul])
    calc |(1 - eulerMascheroniConstant) * S₁_at (N - 1)| * Real.log ↑N
        ≤ |S₁_at (N - 1)| * Real.log ↑N :=
          mul_le_mul_of_nonneg_right h1 (le_of_lt hlogN_pos)
      _ ≤ 2 * C₁ := h_s1_logN
  have h_tri1 : ∀ a b c : ℝ, |a + b - c| ≤ |a| + |b| + |c| := by
    intro a b c
    have hab : |a + b| ≤ |a| + |b| := by
      rcases le_or_gt 0 (a + b) with h | h
      · rw [abs_of_nonneg h]; linarith [le_abs_self a, le_abs_self b]
      · rw [abs_of_neg h]; linarith [neg_abs_le a, neg_abs_le b]
    have habc : |a + b - c| ≤ |a + b| + |c| := by
      rcases le_or_gt 0 (a + b - c) with h | h
      · rw [abs_of_nonneg h]; linarith [le_abs_self (a + b), neg_abs_le c]
      · rw [abs_of_neg h]; linarith [neg_abs_le (a + b), le_abs_self c]
    linarith
  calc |(1 - eulerMascheroniConstant) * S₁_at (N - 1) +
        (S₂_at (N - 1) + 1) -
        ((1 - eulerMascheroniConstant) * S₂_at (N - 1) + S₃_at (N - 1)) /
          Real.log ↑N| * Real.log ↑N
      ≤ (|(1 - eulerMascheroniConstant) * S₁_at (N - 1)| +
         |S₂_at (N - 1) + 1| +
         |((1 - eulerMascheroniConstant) * S₂_at (N - 1) + S₃_at (N - 1)) /
           Real.log ↑N|) * Real.log ↑N := by
        apply mul_le_mul_of_nonneg_right _ (le_of_lt hlogN_pos)
        exact h_tri1 _ _ _
    _ = |(1 - eulerMascheroniConstant) * S₁_at (N - 1)| * Real.log ↑N +
        |S₂_at (N - 1) + 1| * Real.log ↑N +
        |((1 - eulerMascheroniConstant) * S₂_at (N - 1) + S₃_at (N - 1)) /
          Real.log ↑N| * Real.log ↑N := by ring
    _ ≤ 2 * C₁ + 10 * C₂ + (B₂ + B₃ + 3) := by
        rw [h_s2_eq]
        linarith [h_term1_logN, h_s2_logN, h_div_logN]
    _ ≤ 2 * C₁ + 10 * C₂ + B₂ + B₃ + 4 := by linarith

end
