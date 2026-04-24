/-
  Cathedral/White/Infrastructure/ZetaLowerBound.lean

  ## Polynomial Lower Bound on |ζ(s)| via Borel-Carathéodory

  PHYSICS: Free energy lower bound from boundary entropy control.
  MATH: BC theorem applied to log ζ on shifted disk → |ζ(s)| ≥ c/|t|^A.

  ### Strategy (Approach C from Implementation Plan)

  For ε > 0, A > 0, we show |ζ(σ+it)| ≥ c/|t|^A for σ ≥ 1/2+ε, |t| ≥ T₀.

  1. Center disk at s₀ = 2 + it, radius R = 3/2 - ε/2.
  2. Show log ζ is analytic on B(s₀, R) under RH (ζ ≠ 0 + slitPlane).
  3. Bound sup Re(log ζ) = sup log|ζ| ≤ M on disk (convexity bound).
  4. Apply BC: |log ζ(s)| ≤ 2M·r/(R-r) + |log ζ(s₀)|·(R+r)/(R-r).
  5. Exponentiate: |ζ(s)| ≥ exp(-bound) ≥ c/|t|^A.

  ### Dependencies: ZetaDiskBounds (disk geometry, holomorphic log, upper bounds).
-/

import Mathlib.Analysis.Complex.BorelCaratheodory
import Mathlib.Analysis.SpecialFunctions.Pow.Real
import Cathedral.White.Infrastructure.ZetaDiskBounds

noncomputable section
open Complex Real Filter Asymptotics MeasureTheory Metric
open scoped Topology

namespace Cathedral.White.Infrastructure.ZetaLowerBound
open Cathedral.White.Infrastructure.ZetaDiskBounds

-- ═══════════════════════════════════════════
-- §1. Sub-lemmas for the BC Assembly
-- ═══════════════════════════════════════════

/-- For a complex number with zero imaginary part, the norm equals |re|. -/
private lemma norm_mk_sub {a b : ℝ} (hb : b = 0) :
    ‖(⟨a, b⟩ : ℂ)‖ = |a| := by
  subst hb
  exact (Complex.abs_re_eq_norm.mpr rfl).symm

/-- `ζ ∘ (s₀ + ·)` is differentiable on `ball 0 R` when 1 ∉ ball(s₀, R). -/
private lemma zeta_differentiableOn_shifted_ball
    {t : ℝ} (ht : 2 ≤ |t|)
    {R : ℝ} (_hR_pos : 0 < R) (hR_lt : R < 3/2) :
    DifferentiableOn ℂ (fun w => riemannZeta (⟨2, t⟩ + w)) (ball 0 R) := by
  intro w hw
  have hw1 := s_ne_one_on_disk ht hR_lt hw
  exact (differentiableAt_riemannZeta hw1).comp w
    ((differentiableAt_const (⟨2, t⟩ : ℂ)).add differentiableAt_id) |>.differentiableWithinAt

/-- If `f(z) = f(0) · exp(G(z))` on a ball, `‖f(0)‖ ≥ c > 0`,
    and `‖f(z)‖ ≤ B` on the ball, then `Re(G(z)) ≤ log(B/c)`. -/
private lemma re_G_le_of_norm_bound
    {R : ℝ} (_hR : 0 < R)
    {f G : ℂ → ℂ}
    (hG_eq : ∀ z ∈ ball (0 : ℂ) R, f z = f 0 * Complex.exp (G z))
    (_hf_ne : f 0 ≠ 0)
    (hf_bound : ∀ z ∈ ball (0 : ℂ) R, ‖f z‖ ≤ (B : ℝ))
    (hc : (c : ℝ) ≤ ‖f 0‖) (hc_pos : 0 < c)
    {w : ℂ} (hw : w ∈ ball (0 : ℂ) R) :
    (G w).re ≤ Real.log B - Real.log c := by
  have hfw := hG_eq w hw
  have hf0_pos : (0 : ℝ) < ‖f 0‖ := lt_of_lt_of_le hc_pos hc
  have h_norm_fw : ‖f w‖ = ‖f 0‖ * Real.exp ((G w).re) := by
    rw [hfw, norm_mul, Complex.norm_exp]
  have h_exp_val : Real.exp ((G w).re) = ‖f w‖ / ‖f 0‖ := by
    have hne : ‖f 0‖ ≠ 0 := ne_of_gt hf0_pos
    rw [h_norm_fw, mul_div_cancel_left₀ _ hne]
  have hB_pos : 0 < B := by
    have : 0 < ‖f w‖ := by
      rw [h_norm_fw]; exact mul_pos hf0_pos (Real.exp_pos _)
    linarith [hf_bound w hw]
  have h_exp_le : Real.exp ((G w).re) ≤ B / c := by
    rw [h_exp_val]
    rw [div_le_div_iff₀ hf0_pos hc_pos]
    calc ‖f w‖ * c ≤ ‖f w‖ * ‖f 0‖ := by
          exact mul_le_mul_of_nonneg_left hc (norm_nonneg _)
      _ = ‖f 0‖ * ‖f w‖ := by ring
      _ ≤ ‖f 0‖ * B := by
          exact mul_le_mul_of_nonneg_left (hf_bound w hw) (le_of_lt hf0_pos)
      _ = B * ‖f 0‖ := by ring
  have hBc_pos : 0 < B / c := div_pos hB_pos hc_pos
  calc (G w).re ≤ Real.log (Real.exp ((G w).re)) := le_of_eq (Real.log_exp _).symm
    _ ≤ Real.log (B / c) := Real.log_le_log (Real.exp_pos _) h_exp_le
    _ = Real.log B - Real.log c := Real.log_div (ne_of_gt hB_pos) (ne_of_gt hc_pos)

/-- `a/b ≤ c/d` when `a ≤ c`, `d ≤ b`, and `0 < d`, `0 < b`. -/
private lemma div_le_div_of_le_of_le
    {a b c d : ℝ} (hac : a ≤ c) (hdb : d ≤ b) (hd : 0 < d) (hb : 0 < b) (ha : 0 ≤ a) :
    a / b ≤ c / d := by
  rw [div_le_div_iff₀ hb hd]
  calc a * d ≤ a * b := by exact mul_le_mul_of_nonneg_left hdb ha
    _ ≤ c * b := by exact mul_le_mul_of_nonneg_right hac (le_of_lt hb)

-- ═══════════════════════════════════════════
-- §2. BC Inner Bound (Zero Sorry)
-- ═══════════════════════════════════════════

/-- **BC inner bound**: For Re(s) ≥ 1/2 + ε, |Im(s)| ≥ 2, under RH,
    ‖ζ(s)‖ ≥ (1/4) · exp(-C_ε · log(2+|t|)) where C_ε depends only on ε.

    Proof via Borel-Carathéodory on the holomorphic log of ζ.
    ZERO SORRY — fully machine-checked. -/
private lemma bc_inner_bound (hRH : RiemannHypothesis)
    (ε : ℝ) (hε : 0 < ε) (hε1 : ε < 3/2)
    (s : ℂ) (hs : 1/2 + ε ≤ s.re) (ht : 2 ≤ |s.im|) :
    (1/4 : ℝ) * Real.exp (-(2 * (Real.log 4 + 10 * Real.log (2 + |s.im|)) *
      (3/2 - ε) / (ε/2))) ≤ ‖riemannZeta s‖ := by
  by_cases hre_le : s.re ≤ 2
  case pos =>
    set t := s.im with ht_def
    set s₀ : ℂ := ⟨2, t⟩ with hs₀_def
    set R := 3/2 - ε/2 with hR_def
    have hR_pos : 0 < R := by linarith
    have hR_lt : R < 3/2 := by linarith
    -- s lies in ball(s₀, R)
    set z : ℂ := s - s₀ with hz_def
    have hz_re : z.re = s.re - 2 := by simp [hz_def, hs₀_def]
    have hz_im : z.im = 0 := by simp [hz_def, hs₀_def, ht_def]
    have hz_norm : ‖z‖ = 2 - s.re := by
      have h1 : ‖z‖ = |z.re| := by
        have hq := @norm_mk_sub z.re z.im hz_im
        rw [← Complex.eta z] at hq; exact hq
      rw [h1, hz_re, abs_of_nonpos (by linarith)]; ring
    have hz_norm_bound : ‖z‖ ≤ 3/2 - ε := by rw [hz_norm]; linarith
    have hz_lt_R : ‖z‖ < R := by linarith
    have hz_ball : z ∈ ball (0 : ℂ) R := by
      simp only [mem_ball, dist_zero_right]; exact hz_lt_R
    have hgap : ε/2 ≤ R - ‖z‖ := by rw [hz_norm, hR_def]; ring_nf; linarith
    -- ζ holomorphic and nonvanishing on ball
    have hζ_diff : DifferentiableOn ℂ (fun w => riemannZeta (s₀ + w)) (ball 0 R) :=
      zeta_differentiableOn_shifted_ball ht hR_pos hR_lt
    have hζ_ne : ∀ w ∈ ball (0 : ℂ) R, riemannZeta (s₀ + w) ≠ 0 := by
      intro w hw
      have hw1 := s_ne_one_on_disk ht hR_lt hw
      exact rh_zeta_ne_zero hRH (re_gt_half_on_disk hR_lt hw) hw1
    -- Holomorphic log G with ζ(s₀+w) = ζ(s₀)·exp(G w), G(0) = 0
    obtain ⟨G, hG_diff, hG0, hG_eq⟩ :=
      holomorphic_log_exists_on_ball hR_pos hζ_diff hζ_ne
    -- Center bound: ‖ζ(s₀)‖ ≥ 1/4
    have h_center_bound : 1/4 ≤ ‖riemannZeta s₀‖ := by
      have h2 : (2 : ℝ) ≤ s₀.re := by simp [hs₀_def]
      have h_tail := zeta_sub_one_norm_le_three_fourths h2
      have h1 : (1 : ℝ) ≤ ‖riemannZeta s₀‖ + ‖riemannZeta s₀ - 1‖ := by
        calc (1:ℝ) = ‖(1:ℂ)‖ := by simp
          _ = ‖riemannZeta s₀ - (riemannZeta s₀ - 1)‖ := by ring_nf
          _ ≤ ‖riemannZeta s₀‖ + ‖riemannZeta s₀ - 1‖ := norm_sub_le _ _
      linarith
    set M := Real.log 4 + 10 * Real.log (2 + |t|) with hM_def
    have hM_pos : 0 < M := by
      have : 0 < Real.log 4 := Real.log_pos (by norm_num)
      have : 0 < Real.log (2 + |t|) := Real.log_pos (by linarith [abs_nonneg t])
      linarith
    -- Re(G w) ≤ M via re_G_le_of_norm_bound
    have hζs₀_ne : riemannZeta (s₀ + 0) ≠ 0 := by
      simp; intro h; simp [h] at h_center_bound; linarith
    have hG_re_le : Set.MapsTo G (ball 0 R) {z | z.re ≤ M} := by
      intro w hw
      simp only [Set.mem_setOf_eq]
      have h_disk := zeta_norm_bound_on_disk ht hR_pos hR_lt w hw
      have h_center' : (1:ℝ)/4 ≤ ‖riemannZeta (s₀ + 0)‖ := by
        rw [add_zero]; exact h_center_bound
      have h_re := re_G_le_of_norm_bound hR_pos hG_eq hζs₀_ne
        (fun z hz => zeta_norm_bound_on_disk ht hR_pos hR_lt z hz)
        h_center' (by norm_num : (0:ℝ) < 1/4) hw
      have ht_base : (0:ℝ) < 2 + |t| := by linarith [abs_nonneg t]
      have h_eq : Real.log ((2 + |t|) ^ (10:ℝ)) - Real.log (1/4) = M := by
        rw [Real.log_rpow ht_base, Real.log_div (by norm_num) (by norm_num : (4:ℝ) ≠ 0),
            Real.log_one, hM_def]
        ring
      linarith [h_re]
    -- Apply BC theorem
    have hBC := Complex.borelCaratheodory_zero hM_pos hG_diff hG_re_le hR_pos hz_ball hG0
    -- Lower bound on ‖ζ(s)‖
    have hs_eq : s = s₀ + z := by simp [hz_def, hs₀_def]
    have hG_eq_s := hG_eq z hz_ball
    rw [hs_eq, hG_eq_s, norm_mul, Complex.norm_exp]
    simp only [add_zero]
    have hre_ge : -(G z).re ≤ ‖G z‖ := by
      linarith [neg_abs_le (G z).re, Complex.abs_re_le_norm (G z)]
    have hexp_ge : Real.exp (-(‖G z‖)) ≤ Real.exp ((G z).re) := by
      apply Real.exp_le_exp.mpr; linarith
    have hGz_bound : ‖G z‖ ≤ 2 * M * (3/2 - ε) / (ε/2) := by
      have hR_sub_pos : 0 < R - ‖z‖ := by linarith
      have h_num : 2 * M * ‖z‖ ≤ 2 * M * (3/2 - ε) :=
        mul_le_mul_of_nonneg_left hz_norm_bound (by positivity)
      have h_den : ε/2 ≤ R - ‖z‖ := hgap
      exact le_trans hBC (div_le_div_of_le_of_le h_num h_den (by linarith) hR_sub_pos (by positivity))
    calc (1/4 : ℝ) * Real.exp (-(2 * M * (3/2 - ε) / (ε/2)))
        ≤ ‖riemannZeta s₀‖ * Real.exp (-(‖G z‖)) := by
          apply mul_le_mul h_center_bound _ (by positivity) (by positivity)
          exact Real.exp_le_exp.mpr (neg_le_neg hGz_bound)
      _ ≤ ‖riemannZeta s₀‖ * Real.exp ((G z).re) :=
          mul_le_mul_of_nonneg_left hexp_ge (by positivity)
  case neg =>
    -- Re(s) > 2: tail bound gives ‖ζ‖ ≥ 1/4
    push Not at hre_le
    have h2 : 2 ≤ s.re := le_of_lt hre_le
    have hs1 : s ≠ 1 := by
      intro h; have him := congr_arg Complex.im h; simp at him
      have : |s.im| = 0 := by rw [him]; simp
      linarith
    have h_tail := zeta_sub_one_norm_le_three_fourths h2
    have h_lower : 1/4 ≤ ‖riemannZeta s‖ := by
      have h1 : (1 : ℝ) ≤ ‖riemannZeta s‖ + ‖riemannZeta s - 1‖ := by
        calc (1:ℝ) = ‖(1:ℂ)‖ := by simp
          _ = ‖riemannZeta s - (riemannZeta s - 1)‖ := by ring_nf
          _ ≤ ‖riemannZeta s‖ + ‖riemannZeta s - 1‖ := norm_sub_le _ _
      linarith
    calc (1/4 : ℝ) * Real.exp (-(2 * (Real.log 4 + 10 * Real.log (2 + |s.im|)) *
        (3/2 - ε) / (ε/2)))
        ≤ 1/4 * 1 := by
          apply mul_le_mul_of_nonneg_left _ (by norm_num)
          apply Real.exp_le_one_iff.mpr
          apply neg_nonpos_of_nonneg
          apply div_nonneg
          · apply mul_nonneg
            · apply mul_nonneg (by positivity)
              apply add_nonneg
              · exact le_of_lt (Real.log_pos (by norm_num))
              · apply mul_nonneg (by norm_num)
                exact le_of_lt (Real.log_pos (by linarith [abs_nonneg s.im]))
            · linarith
          · linarith
      _ = 1/4 := by ring
      _ ≤ ‖riemannZeta s‖ := h_lower

-- ═══════════════════════════════════════════
-- §3. The Main Theorem: Polynomial Lower Bound
-- ═══════════════════════════════════════════

/-- **THEOREM** (was AXIOM): Under RH, |ζ(s)| has a polynomial lower bound.

    Proved via Borel-Carathéodory applied to log ζ on a shifted disk.
    This replaces the axiom `zeta_polynomial_lower_bound_rh` from
    ZetaConvexity.lean.

    The BC inner bound (bc_inner_bound) is ZERO SORRY.
    The existential wrapper case-splits on A vs B_ε:
    - A ≥ B_ε (= 20(3-2ε)/ε): FULLY PROVED (zero sorry)
    - A < B_ε: ε-rescaling trick (ε' = 60/(A+40), B_{ε'} = A):
      • Re(s) ≥ 1/2+ε': FULLY PROVED (zero sorry)
      • 1/2+ε ≤ Re(s) < 1/2+ε': 1 sorry (needs Hadamard/PL) -/
theorem zeta_polynomial_lower_bound_rh_proved (hRH : RiemannHypothesis)
    (ε : ℝ) (hε : 0 < ε) (A : ℝ) (hA : 0 < A) :
    ∃ c > 0, ∃ T₀ > 0, ∀ s : ℂ,
      (1/2 + ε ≤ s.re) → (T₀ ≤ |s.im|) →
      c / |s.im| ^ A ≤ ‖riemannZeta s‖ := by
  by_cases hε1 : 3/2 ≤ ε
  · -- ε ≥ 3/2: Re(s) ≥ 2, tail bound gives |ζ| ≥ 1/4
    refine ⟨1/4, by norm_num, 2, by norm_num, ?_⟩
    intro s hs him
    have hre2 : 2 ≤ s.re := by linarith
    have ht_ge_2 : 2 ≤ |s.im| := him
    have ht_pos : 0 < |s.im| := by linarith
    have hs1 : s ≠ 1 := by
      intro h
      have him : s.im = 0 := by
        have := congr_arg Complex.im h; simp at this; exact this
      rw [him, abs_zero] at ht_ge_2
      linarith
    have h_tail := zeta_sub_one_norm_le_three_fourths hre2
    have h_lower : 1/4 ≤ ‖riemannZeta s‖ := by
      have h1 : (1 : ℝ) ≤ ‖riemannZeta s‖ + ‖riemannZeta s - 1‖ := by
        calc (1:ℝ) = ‖(1:ℂ)‖ := by simp
          _ = ‖riemannZeta s - (riemannZeta s - 1)‖ := by ring_nf
          _ ≤ ‖riemannZeta s‖ + ‖riemannZeta s - 1‖ := norm_sub_le _ _
      linarith
    have h_rpow_ge : 1 ≤ |s.im| ^ A :=
      Real.one_le_rpow (by linarith : 1 ≤ |s.im|) hA.le
    calc (1:ℝ)/4 / |s.im| ^ A
        ≤ 1/4 := div_le_self (by norm_num) h_rpow_ge
      _ ≤ ‖riemannZeta s‖ := h_lower
  · -- ε < 3/2: Use BC inner bound
    simp only [not_le] at hε1
    -- BC parameters: K = 2(3/2-ε)/(ε/2) = (6-4ε)/ε, B_ε = 10K = 20(3-2ε)/ε
    set K_ε := 2 * (3/2 - ε) / (ε/2) with hK_def
    set B_ε := 10 * K_ε with hB_def
    have hε2_pos : 0 < ε / 2 := by linarith
    have hK_pos : 0 < K_ε := by rw [hK_def]; exact div_pos (by linarith) hε2_pos
    have hB_pos : 0 < B_ε := by rw [hB_def]; linarith
    -- Case split: A ≥ B_ε (provable) vs A < B_ε (needs iterated BC)
    by_cases hAB : B_ε ≤ A
    · -- ══ Case A ≥ B_ε: Full proof via rpow chain ══
      -- Witness: c₀ = (1/4) · 4^{-K} · 2^{-B_ε}
      -- This satisfies c₀/|t|^A ≤ c₀/|t|^{B_ε} = (1/4)·4^{-K}·(2|t|)^{-B_ε}
      --                         ≤ (1/4)·4^{-K}·(2+|t|)^{-B_ε} = BC(|t|) ≤ ‖ζ‖
      set c₀ := (1/4 : ℝ) * (4 : ℝ) ^ (-K_ε) * (2 : ℝ) ^ (-B_ε) with hc₀_def
      have hc₀_pos : 0 < c₀ := by positivity
      refine ⟨c₀, hc₀_pos, 2, by norm_num, ?_⟩
      intro s hs him
      have ht_ge_2 : 2 ≤ |s.im| := him
      have ht_pos : 0 < |s.im| := by linarith
      have ht_ge_1 : 1 ≤ |s.im| := by linarith
      have hbc := bc_inner_bound hRH ε hε hε1 s hs ht_ge_2
      -- The BC exponent matches K_ε · (log 4 + 10·log(2+|t|))
      -- which equals 2·(log 4 + 10·log(2+|t|))·(3/2-ε)/(ε/2)
      -- The proof uses exp/log arithmetic to avoid rpow complexity.
      -- Key chain: c₀/|t|^A ≤ (1/4)·exp(-E) ≤ ‖ζ(s)‖
      -- where E = 2·(log 4 + 10·log(2+|t|))·(3/2-ε)/(ε/2)
      --
      -- Strategy: take log of both sides.
      -- log(c₀) - A·log|t| ≤ log(1/4) - E
      -- ⟺ E ≤ (log c₀ - log(1/4)) · (-1) + A·log|t|
      -- ⟺ K·(log 4 + 10·log(2+|t|)) ≤ (2K + B_ε)·log 2 + A·log|t|
      -- ⟺ 10K·log(2+|t|) ≤ 10K·log 2 + A·log|t|
      -- ⟺ B_ε·log((2+|t|)/2) ≤ A·log|t|
      -- This holds since (2+|t|)/2 ≤ |t| and A ≥ B_ε.
      --
      -- To avoid log arithmetic in Lean, we use an equivalent exp formulation:
      -- |t|^{-A} ≤ ((2+|t|)/2)^{-B_ε} (from the key inequality)
      -- and ((2+|t|)/2)^{-B_ε} = 2^{B_ε}·(2+|t|)^{-B_ε}
      -- combined with 4^{-K} = 2^{-2K}, this gives the result.
      calc c₀ / |s.im| ^ A
          ≤ (1/4 : ℝ) * Real.exp (-(2 * (Real.log 4 + 10 * Real.log (2 + |s.im|)) *
              (3/2 - ε) / (ε/2))) := by
            -- Reduce to comparing exponents
            rw [hc₀_def]
            -- Convert rpow to exp for comparison
            have h2t_pos : 0 < 2 + |s.im| := by linarith
            have h_half_pos : 0 < (2 + |s.im|) / 2 := by linarith
            have h_half_le : (2 + |s.im|) / 2 ≤ |s.im| := by linarith
            -- Key inequality: B_ε·log((2+|t|)/2) ≤ A·log|t|
            have h_log_t_pos : 0 ≤ Real.log |s.im| := Real.log_nonneg ht_ge_1
            have h_log_le : Real.log ((2 + |s.im|) / 2) ≤ Real.log |s.im| :=
              Real.log_le_log h_half_pos h_half_le
            have h_key : B_ε * Real.log ((2 + |s.im|) / 2) ≤ A * Real.log |s.im| :=
              calc B_ε * Real.log ((2 + |s.im|) / 2)
                  ≤ B_ε * Real.log |s.im| :=
                    mul_le_mul_of_nonneg_left h_log_le hB_pos.le
                _ ≤ A * Real.log |s.im| :=
                    mul_le_mul_of_nonneg_right hAB h_log_t_pos
            -- The exponent identity: K·log 4 + B_ε·log(2+|t|) = the BC expression
            have h_exp_identity : K_ε * Real.log 4 + B_ε * Real.log (2 + |s.im|) =
                2 * (Real.log 4 + 10 * Real.log (2 + |s.im|)) * (3/2 - ε) / (ε/2) := by
              rw [hB_def]; ring
            -- log(2+|t|) = log 2 + log((2+|t|)/2)
            have h_log_split : Real.log (2 + |s.im|) =
                Real.log 2 + Real.log ((2 + |s.im|) / 2) := by
              rw [← Real.log_mul (by norm_num : (2:ℝ) ≠ 0) (ne_of_gt h_half_pos)]
              congr 1; ring
            -- 2K·log 2 + B_ε·log((2+|t|)/2) ≤ A·log|t| (from above)
            -- since K·log 4 = 2K·log 2
            have h_log4 : Real.log 4 = 2 * Real.log 2 := by
              rw [show (4:ℝ) = 2^2 from by norm_num, Real.log_pow]; ring
            -- Convert rpow quantities to exp form
            have h_4_rpow : (4:ℝ) ^ (-K_ε) = Real.exp (-(K_ε * Real.log 4)) := by
              rw [Real.rpow_def_of_pos (by norm_num : (0:ℝ) < 4)]; ring_nf
            have h_2_rpow : (2:ℝ) ^ (-B_ε) = Real.exp (-(B_ε * Real.log 2)) := by
              rw [Real.rpow_def_of_pos (by norm_num : (0:ℝ) < 2)]; ring_nf
            have h_t_rpow : |s.im| ^ A = Real.exp (A * Real.log |s.im|) := by
              rw [Real.rpow_def_of_pos ht_pos]; ring_nf
            -- Direct approach: use h_4_rpow, h_2_rpow, h_t_rpow to convert, then
            -- show the inequality via the monotonicity chain.
            -- c₀ = (1/4)·4^{-K}·2^{-B_ε}
            -- c₀ / |t|^A = c₀ · |t|^{-A}
            -- We use: |t|^{-A} ≤ ((2+|t|)/2)^{-B_ε} (from h_key + exp comparison)
            -- and ((2+|t|)/2)^{-B_ε} = 2^{B_ε}·(2+|t|)^{-B_ε} ... complex
            --
            -- SIMPLER: Work entirely in exp space.
            -- c₀/|t|^A = (1/4)·exp(-K·log4 - B_ε·log2 - A·log|t|)
            -- target = (1/4)·exp(-(K·log4 + B_ε·log(2+|t|)))
            -- Need: -(K·log4 + B_ε·log2 + A·log|t|) ≤ -(K·log4 + B_ε·log(2+|t|))
            -- i.e., K·log4 + B_ε·log(2+|t|) ≤ K·log4 + B_ε·log2 + A·log|t|
            -- i.e., B_ε·(log(2+|t|) - log2) ≤ A·log|t|
            -- i.e., B_ε·log((2+|t|)/2) ≤ A·log|t| ← h_key!
            --
            -- Translate: c₀/|t|^A = c₀ * (1/|t|^A)
            have hA_rpow_pos : 0 < |s.im| ^ A := Real.rpow_pos_of_pos ht_pos A
            -- Reformulate: a/b ≤ c ↔ a ≤ c * b (for b > 0)
            rw [show c₀ / |s.im| ^ A ≤ _ ↔ c₀ ≤ _ * |s.im| ^ A from
              div_le_iff₀ hA_rpow_pos]
            rw [hc₀_def]
            -- Convert all rpow to exp
            rw [h_4_rpow, h_2_rpow, h_t_rpow]
            -- (1/4)*exp(-K·log4)*exp(-B_ε·log2) ≤ (1/4)*exp(-E)*exp(A·log|t|)
            -- Combine exp on each side
            have h_combine_l : (1:ℝ)/4 * Real.exp (-(K_ε * Real.log 4)) *
                Real.exp (-(B_ε * Real.log 2)) =
                1/4 * Real.exp (-(K_ε * Real.log 4 + B_ε * Real.log 2)) := by
              rw [mul_assoc]
              congr 1
              rw [← Real.exp_add]
              congr 1
              ring
            have h_combine_r : (1:ℝ)/4 * Real.exp (-(2 * (Real.log 4 +
                10 * Real.log (2 + |s.im|)) * (3/2 - ε) / (ε/2))) *
                Real.exp (A * Real.log |s.im|) =
                1/4 * Real.exp (-(2 * (Real.log 4 + 10 * Real.log (2 + |s.im|)) *
                (3/2 - ε) / (ε/2)) + A * Real.log |s.im|) := by
              rw [mul_assoc]
              congr 1
              rw [← Real.exp_add]
            rw [h_combine_l, h_combine_r]
            apply mul_le_mul_of_nonneg_left _ (by norm_num : (0:ℝ) ≤ 1/4)
            apply Real.exp_le_exp.mpr
            -- Goal: -(K·log4 + B_ε·log2)
            --     ≤ -(2·(log4 + 10·log(2+|t|))·(3/2-ε)/(ε/2)) + A·log|t|
            -- = -(K·log4 + B_ε·log(2+|t|)) + A·log|t|   (via h_exp_identity)
            -- So need: B_ε·log(2+|t|) - B_ε·log2 ≤ A·log|t|
            have h_rearrange : B_ε * (Real.log (2 + |s.im|) - Real.log 2) =
                B_ε * Real.log ((2 + |s.im|) / 2) := by
              rw [← Real.log_div (ne_of_gt h2t_pos) (by norm_num : (2:ℝ) ≠ 0)]
            linarith [h_key, h_rearrange, h_exp_identity]
        _ ≤ ‖riemannZeta s‖ := hbc
    · -- ══ Case A < B_ε: ε-rescaling trick ══
      -- Choose ε' = 60/(A+40) so B_{ε'} = A, then case-split on Re(s).
      simp only [not_le] at hAB
      -- ε' = 60/(A+40): chosen so that 20*(3-2ε')/ε' = A
      set ε' := 60 / (A + 40) with hε'_def
      have hA40_pos : 0 < A + 40 := by linarith
      have hε'_pos : 0 < ε' := by rw [hε'_def]; positivity
      have hε'_lt : ε' < 3/2 := by
        rw [hε'_def]
        rw [div_lt_iff₀ hA40_pos]
        nlinarith
      -- ε' > ε (consequence of A < B_ε)
      have hε_lt_ε' : ε < ε' := by
        rw [hε'_def]
        -- Need ε < 60/(A+40), i.e., ε*(A+40) < 60
        have hBε_eq : B_ε = 20 * (3 - 2 * ε) / ε := by
          rw [hB_def, hK_def]; field_simp; ring
        -- A < B_ε = 20*(3-2ε)/ε means A*ε < 20*(3-2ε) = 60-40ε
        have hAε : A * ε < 60 - 40 * ε := by
          have h1 := mul_lt_mul_of_pos_right (by linarith [hBε_eq] : A < B_ε) hε
          rw [hBε_eq, div_mul_cancel₀ _ (ne_of_gt hε)] at h1
          linarith
        have h_eps_bound : ε * (A + 40) < 60 := by nlinarith [hAε]
        rwa [lt_div_iff₀ hA40_pos]
      -- K_{ε'} and B_{ε'}
      set K_ε' := 2 * (3/2 - ε') / (ε'/2) with hK'_def
      set B_ε' := 10 * K_ε' with hB'_def
      -- B_{ε'} = A (exact)
      have hB'_eq_A : B_ε' = A := by
        rw [hB'_def, hK'_def, hε'_def]; field_simp; ring
      have hB'_pos : 0 < B_ε' := by rw [hB'_eq_A]; exact hA
      -- Witness: c₀(ε') = (1/4)·4^{-K_{ε'}}·2^{-A}
      set c₀ := (1/4 : ℝ) * (4 : ℝ) ^ (-K_ε') * (2 : ℝ) ^ (-B_ε') with hc₀_def
      have hc₀_pos : 0 < c₀ := by positivity
      refine ⟨c₀, hc₀_pos, 2, by norm_num, ?_⟩
      intro s hs him
      have ht_ge_2 : 2 ≤ |s.im| := him
      have ht_pos : 0 < |s.im| := by linarith
      have ht_ge_1 : 1 ≤ |s.im| := by linarith
      by_cases hre : (1/2 + ε' : ℝ) ≤ s.re
      · -- Case A: Re(s) ≥ 1/2+ε' → use bc_inner_bound(ε')
        have hbc' := bc_inner_bound hRH ε' hε'_pos hε'_lt s hre ht_ge_2
        -- Exactly the A ≥ B_{ε'} proof (since B_{ε'} = A)
        have h2t_pos : 0 < 2 + |s.im| := by linarith
        have h_half_pos : 0 < (2 + |s.im|) / 2 := by linarith
        have h_half_le : (2 + |s.im|) / 2 ≤ |s.im| := by linarith
        have h_log_t_pos : 0 ≤ Real.log |s.im| := Real.log_nonneg ht_ge_1
        have h_log_le : Real.log ((2 + |s.im|) / 2) ≤ Real.log |s.im| :=
          Real.log_le_log h_half_pos h_half_le
        have hAB' : B_ε' ≤ A := le_of_eq hB'_eq_A
        have h_key : B_ε' * Real.log ((2 + |s.im|) / 2) ≤ A * Real.log |s.im| :=
          calc B_ε' * Real.log ((2 + |s.im|) / 2)
              ≤ B_ε' * Real.log |s.im| :=
                mul_le_mul_of_nonneg_left h_log_le hB'_pos.le
            _ ≤ A * Real.log |s.im| :=
                mul_le_mul_of_nonneg_right hAB' h_log_t_pos
        have h_exp_identity : K_ε' * Real.log 4 + B_ε' * Real.log (2 + |s.im|) =
            2 * (Real.log 4 + 10 * Real.log (2 + |s.im|)) * (3/2 - ε') / (ε'/2) := by
          rw [hB'_def]; ring
        -- rpow → exp
        have h_4_rpow : (4:ℝ) ^ (-K_ε') = Real.exp (-(K_ε' * Real.log 4)) := by
          rw [Real.rpow_def_of_pos (by norm_num : (0:ℝ) < 4)]; ring_nf
        have h_2_rpow : (2:ℝ) ^ (-B_ε') = Real.exp (-(B_ε' * Real.log 2)) := by
          rw [Real.rpow_def_of_pos (by norm_num : (0:ℝ) < 2)]; ring_nf
        have h_t_rpow : |s.im| ^ A = Real.exp (A * Real.log |s.im|) := by
          rw [Real.rpow_def_of_pos ht_pos]; ring_nf
        -- Use calc: c₀/|t|^A ≤ (1/4)·exp(-E') ≤ ‖ζ(s)‖
        -- First step: c₀/|t|^A ≤ (1/4)·exp(-E')
        have h_step1 : c₀ / |s.im| ^ A ≤ (1/4 : ℝ) * Real.exp (-(2 * (Real.log 4 +
            10 * Real.log (2 + |s.im|)) * (3/2 - ε') / (ε'/2))) := by
          have hA_rpow_pos : 0 < |s.im| ^ A := Real.rpow_pos_of_pos ht_pos A
          rw [div_le_iff₀ hA_rpow_pos, hc₀_def, h_4_rpow, h_2_rpow, h_t_rpow]
          -- Need: 1/4*exp(-K'log4)*exp(-B'log2) ≤ (1/4)*exp(-E')*exp(A*log|t|)
          -- Combine LHS
          have h_combine_l : (1:ℝ)/4 * Real.exp (-(K_ε' * Real.log 4)) *
              Real.exp (-(B_ε' * Real.log 2)) =
              1/4 * Real.exp (-(K_ε' * Real.log 4 + B_ε' * Real.log 2)) := by
            rw [mul_assoc]; congr 1; rw [← Real.exp_add]; congr 1; ring
          rw [h_combine_l]
          -- Need: 1/4*exp(X) ≤ (1/4*exp(Y))*exp(Z)
          -- = 1/4*(exp(Y)*exp(Z)) = 1/4*exp(Y+Z)
          -- So need exp(X) ≤ exp(Y+Z), i.e., X ≤ Y+Z
          have h_rhs_eq : (1:ℝ)/4 * Real.exp (-(2 * (Real.log 4 +
              10 * Real.log (2 + |s.im|)) * (3/2 - ε') / (ε'/2))) *
              Real.exp (A * Real.log |s.im|) =
              1/4 * Real.exp (-(2 * (Real.log 4 + 10 * Real.log (2 + |s.im|)) *
              (3/2 - ε') / (ε'/2)) + A * Real.log |s.im|) := by
            rw [mul_assoc]; congr 1; rw [← Real.exp_add]
          rw [h_rhs_eq]
          apply mul_le_mul_of_nonneg_left _ (by norm_num : (0:ℝ) ≤ 1/4)
          apply Real.exp_le_exp.mpr
          have h_rearrange : B_ε' * (Real.log (2 + |s.im|) - Real.log 2) =
              B_ε' * Real.log ((2 + |s.im|) / 2) := by
            rw [← Real.log_div (ne_of_gt h2t_pos) (by norm_num : (2:ℝ) ≠ 0)]
          linarith [h_key, h_rearrange, h_exp_identity]
        linarith [hbc']
      · -- Case B: 1/2+ε ≤ Re(s) < 1/2+ε' (thin strip)
        --
        -- MATHEMATICAL OBSTRUCTION (verified by bc-witness-analysis):
        -- The BC bound with ε gives ‖ζ‖ ≥ C·(2+|t|)^{-B_ε} where B_ε > A.
        -- The witness c₀ = (1/4)·4^{-K_{ε'}}·2^{-A} yields
        -- c₀/|t|^A ∼ C'·|t|^{-A} which decays SLOWER than (2+|t|)^{-B_ε}
        -- since A < B_ε. So c₀/|t|^A > BC lower bound for large |t|.
        --
        -- The theorem IS true under RH (Hadamard factorization gives
        -- ‖ζ(s)‖ ≥ c·exp(-C·(log|t|)^{2-2σ+ε}) for σ > 1/2),
        -- but BC alone is too coarse to prove it for A < B_ε.
        --
        -- PROOF PATHS to close this sorry:
        --   (1) Hadamard factorization: log ζ(s) = Σ log(1-s/ρ) + ...
        --       Under RH, |s - ρ| ≥ σ - 1/2 ≥ ε, giving log|ζ| ≥ -C·log²|t|
        --   (2) Jensen's formula + zero density: N(T) = (T/2π)·log(T/2πe) + ...
        --       controls the number of nearby zeros, bounding log|ζ| from below
        --   (3) Phragmén-Lindelöf in the strip [1/2+ε, 1/2+ε']
        --
        -- STATUS: 1 sorry. The BC inner bound (bc_inner_bound) is ZERO SORRY.
        -- This sorry is the only remaining gap in the full proof chain.
        simp only [not_le] at hre
        have hbc := bc_inner_bound hRH ε hε hε1 s hs ht_ge_2
        sorry

end Cathedral.White.Infrastructure.ZetaLowerBound
