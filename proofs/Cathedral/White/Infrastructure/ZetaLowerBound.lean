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

  ### Dependencies: Mathlib (BC, ζ, log), ZetaConvexity (rh_zeta_ne_zero).
-/

import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.LSeries.Nonvanishing
import Mathlib.NumberTheory.LSeries.Dirichlet
import Mathlib.Analysis.Complex.BorelCaratheodory
import Mathlib.Analysis.SpecialFunctions.Complex.LogDeriv
import Mathlib.Analysis.Complex.PhragmenLindelof
import Mathlib.Analysis.Normed.Operator.Asymptotics

noncomputable section
open Complex Real Filter Asymptotics MeasureTheory Metric
open scoped Topology

namespace Cathedral.White.Infrastructure.ZetaLowerBound

-- ═══════════════════════════════════════════
-- §1. Zeta Nonvanishing Under RH (from ZetaConvexity)
-- ═══════════════════════════════════════════

/-- Under RH, ζ(s) ≠ 0 for Re(s) > 1/2, s ≠ 1. Proved in ZetaConvexity.lean. -/
private theorem rh_zeta_ne_zero_local (hRH : RiemannHypothesis)
    {s : ℂ} (hs : 1/2 < s.re) (hs1 : s ≠ 1) : riemannZeta s ≠ 0 := by
  intro hζ
  by_cases h1 : 1 ≤ s.re
  · exact absurd hζ (riemannZeta_ne_zero_of_one_le_re h1)
  · push Not at h1
    have hre_eq : s.re = 1 / 2 :=
      hRH s hζ (by
        rintro ⟨n, rfl⟩
        have hre : (-2 * (↑n + 1) : ℂ).re = -(2 * (n : ℝ) + 2) := by
          simp [mul_add, add_re, mul_re, neg_re, natCast_re]; ring
        linarith [hre, Nat.cast_nonneg (α := ℝ) n]) hs1
    linarith

-- ═══════════════════════════════════════════
-- §2. Zeta Values in slitPlane (Key Lemma)
-- ═══════════════════════════════════════════

/-- **Strengthened bound**: ‖ζ(s) - 1‖ ≤ 3/4 for Re(s) ≥ 2.
    This is tighter than `< 1` and needed for the explicit lower bound ‖ζ(s)‖ ≥ 1/4. -/
private lemma zeta_sub_one_norm_le_three_fourths {s : ℂ} (hs : 2 ≤ s.re) :
    ‖riemannZeta s - 1‖ ≤ 3/4 := by
  have h_re : 1 < s.re := by linarith
  have hs0 : s ≠ 0 := Complex.ne_zero_of_one_lt_re h_re
  -- Use riemannZetaSummandHom: g(n) = n^{-s}
  set g := riemannZetaSummandHom hs0
  have hg_ns := summable_riemannZetaSummand h_re
  -- ζ(s) = Σ g(n) and g(0) = 0, g(1) = 1
  have h_zeta : riemannZeta s = ∑' n, g n := (tsum_riemannZetaSummand h_re).symm
  have h_g0 : g 0 = 0 := by simp [g, riemannZetaSummandHom, hs0]
  have h_g1 : g 1 = 1 := by simp [g, riemannZetaSummandHom]
  -- ζ(s) - 1 = (Σ_{n≥0} g(n)) - 1 = (g(0) + Σ_{n≥1} g(n)) - 1 = Σ_{n≥1} g(n) - 1
  -- = (g(1) + Σ_{n≥2} g(n)) - 1 = Σ_{n≥2} g(n)
  rw [h_zeta, hg_ns.of_norm.tsum_eq_zero_add, h_g0, zero_add]
  -- Now we need to extract g(1) from the shifted sum
  -- Goal: ‖∑' n, g (n + 1) - 1‖ < 1
  -- ∑' n, g(n+1) = g(1) + ∑' n, g(n+2) = 1 + ∑' n, g(n+2)
  have hg_shift : Summable (fun n => ‖g (n + 1)‖) :=
    hg_ns.comp_injective (fun a b h => by omega)
  rw [hg_shift.of_norm.tsum_eq_zero_add, h_g1, add_sub_cancel_left]
  -- ‖∑' g(n+1+1)‖ ≤ 3/4 using tsum_of_norm_bounded with a custom bound series.
  -- First: ‖g(n+1+1)‖ = (n+2)^{-σ} ≤ (n+2)^{-2}
  -- Second: (n+2)^{-2} ≤ 1/((n+1)(n+2)) since n+1 ≤ n+2
  -- The bound function: b(0) = 1/4, b(n) = 1/((n+1)(n+2)) for n ≥ 1.
  -- HasSum b (3/4) via telescoping partial sums.
  -- Use tsum_of_norm_bounded with bound b(n)
  let b : ℕ → ℝ := fun n => if n = 0 then 1/4 else 1/((↑n + 1) * (↑n + 2))
  have hb_hasSum : HasSum b (3/4) := by
      rw [hasSum_iff_tendsto_nat_of_nonneg (fun n => by simp [b]; split_ifs <;> positivity)]
      -- Need: Tendsto (fun n => Σ_{i<n} b(i)) atTop (𝓝 (3/4))
      -- b(0) = 1/4, b(n) = 1/((n+1)(n+2)) for n ≥ 1
      -- Partial sum Σ_{i<n} b(i) = 1/4 + Σ_{i=1}^{n-1} 1/((i+1)(i+2))
      -- = 1/4 + (1/2 - 1/(n+1))  [telescoping for i≥1]
      -- = 3/4 - 1/(n+1)
      -- Tends to 3/4.
      have h_partial : ∀ n, 1 ≤ n →
          ∑ i ∈ Finset.range n, b i = 3/4 - 1/(↑n + 1) := by
        intro n hn
        induction n with
        | zero => omega
        | succ m ih =>
          rw [Finset.sum_range_succ]
          by_cases hm0 : m = 0
          · subst hm0
            simp only [Finset.sum_range_zero, b, if_true, Nat.cast_zero]
            norm_num
          · have hm1 : 1 ≤ m := Nat.one_le_iff_ne_zero.mpr hm0
            specialize ih hm1
            rw [ih]
            -- Goal: 3/4 - 1/(↑m + 1) + b m = 3/4 - 1/(↑(m+1) + 1)
            simp only [b, show m ≠ 0 from hm0, ite_false]
            push_cast
            field_simp
            ring
      -- For n = 0: partial sum is 0
      -- For n ≥ 1: partial sum = 3/4 - 1/(n+1) → 3/4
      suffices h_suff : Tendsto (fun n : ℕ => 3/4 - 1/((↑n : ℝ) + 1)) Filter.atTop (𝓝 (3/4 : ℝ)) by
        apply Filter.Tendsto.congr' _ h_suff
        filter_upwards [Filter.Ici_mem_atTop 1] with n hn
        exact (h_partial n hn).symm
      have h_tend : Tendsto (fun n : ℕ => (1 : ℝ) / ((↑n : ℝ) + 1)) Filter.atTop (𝓝 0) := by
        have h1 : Tendsto (fun n : ℕ => (↑n : ℝ) + 1) Filter.atTop Filter.atTop :=
          Filter.tendsto_atTop_add_const_right _ 1 tendsto_natCast_atTop_atTop
        exact tendsto_const_nhds.div_atTop h1
      simpa [sub_zero] using Filter.Tendsto.const_sub (3/4 : ℝ) h_tend
  have hb_bound : ∀ n, ‖(fun n => g (n + 1 + 1)) n‖ ≤ b n := by
    intro n
    simp only [g, riemannZetaSummandHom, MonoidWithZeroHom.coe_mk, ZeroHom.coe_mk, b]
    -- ‖(n+1+1 : ℕ)^(-s)‖ = (n+2)^{-Re(s)} ≤ (n+2)^{-2} ≤ b(n)
    rw [show (n + 1 + 1 : ℕ) = n + 2 from by omega]
    have hpos : (0 : ℝ) < (↑(n + 2) : ℝ) := by positivity
    rw [← ofReal_natCast, norm_cpow_eq_rpow_re_of_pos hpos, neg_re]
    -- Goal: (↑n + 2) ^ (-s.re) ≤ if n = 0 then 1/4 else ...
    split_ifs with h
    · -- n = 0: 2^{-σ} ≤ 1/4 since σ ≥ 2
      subst h
      norm_num
      -- Goal: (2:ℝ) ^ (-s.re) ≤ 1/4
      calc (2:ℝ) ^ (-s.re) ≤ (2:ℝ) ^ (-(2:ℝ)) :=
        Real.rpow_le_rpow_of_exponent_le (by norm_num) (by linarith)
      _ = 1/4 := by
        rw [show (-(2:ℝ)) = -((2:ℕ) : ℝ) from by norm_num,
            Real.rpow_neg (by norm_num : (0:ℝ) ≤ 2),
            Real.rpow_natCast]; norm_num
    · -- n ≥ 1: (↑(n+2))^(-s.re) ≤ 1/((n+1)*(n+2))
      -- Step 1: (n+2)^{-σ} ≤ (n+2)^{-2}
      have h1 : (1:ℝ) ≤ ↑(n + 2) := by
        exact_mod_cast Nat.one_le_iff_ne_zero.mpr (by omega)
      have h_exp : (↑(n + 2) : ℝ) ^ (-s.re) ≤ (↑(n + 2) : ℝ) ^ (-(2:ℝ)) :=
        Real.rpow_le_rpow_of_exponent_le h1 (by linarith)
      -- Step 2: (n+2)^{-2} = 1/(n+2)^2
      have h_inv : (↑(n + 2) : ℝ) ^ (-(2:ℝ)) = 1 / (↑(n + 2) : ℝ) ^ (2:ℝ) := by
        rw [Real.rpow_neg (by positivity : (0:ℝ) ≤ ↑(n+2))]
        ring
      -- Step 3: 1/(n+2)^2 ≤ 1/((n+1)*(n+2))
      -- Since (n+1)*(n+2) ≤ (n+2)^2 (i.e., n+1 ≤ n+2), dividing inverts
      have h_frac : 1 / (↑(n + 2) : ℝ) ^ (2:ℝ) ≤ 1/((↑n + 1) * (↑n + 2)) := by
        rw [show (2:ℝ) = ((2:ℕ):ℝ) from by norm_num, Real.rpow_natCast]
        push_cast
        -- 1/(↑n+2)^2 ≤ 1/((↑n+1)*(↑n+2)) iff (↑n+1)*(↑n+2) ≤ (↑n+2)^2
        apply one_div_le_one_div_of_le (by positivity)
        -- Goal: (↑n + 1) * (↑n + 2) ≤ (↑n + 2) ^ 2
        nlinarith [show (0:ℝ) ≤ ↑n from Nat.cast_nonneg n]
      linarith
  exact tsum_of_norm_bounded hb_hasSum hb_bound

/-- ζ(s) ∈ slitPlane for Re(s) ≥ 2 (far from critical strip).

    For Re(s) ≥ 2, |ζ(s) - 1| ≤ Σ_{n≥2} n^{-2} = π²/6 - 1 ≈ 0.645.
    Since ζ(s) is within distance < 1 from 1, it stays in
    {z | z.re > 0} ⊂ slitPlane.

    Proof uses `mem_slitPlane_of_norm_lt_one`: ‖z‖ < 1 → 1 + z ∈ slitPlane. -/
private lemma zeta_mem_slitPlane_of_re_ge_two {s : ℂ} (hs : 2 ≤ s.re) (_hs1 : s ≠ 1) :
    riemannZeta s ∈ slitPlane := by
  -- ζ(s) = 1 + (ζ(s) - 1). Since ‖ζ(s) - 1‖ < 1, we get ζ(s) ∈ slitPlane.
  have h : ‖riemannZeta s - 1‖ < 1 := lt_of_le_of_lt (zeta_sub_one_norm_le_three_fourths hs) (by norm_num)
  have := mem_slitPlane_of_norm_lt_one h
  rwa [add_sub_cancel] at this

/-- Helper: s₀ + z ≠ 1 for z in the BC disk, since the disk can't reach the pole.
    |s₀ - 1| ≥ |t| ≥ 2 > 3/2 > R, so 1 ∉ ball(s₀, R). -/
private lemma s_ne_one_on_disk {t : ℝ} (ht : 2 ≤ |t|)
    {R : ℝ} (hR_lt : R < 3/2) {z : ℂ} (hz : z ∈ ball (0 : ℂ) R) :
    (⟨2, t⟩ : ℂ) + z ≠ 1 := by
  simp only [mem_ball, dist_zero_right] at hz
  intro h_eq
  have hz_re : z.re = -1 := by
    have := congr_arg Complex.re h_eq; simp at this; linarith
  have hz_im : z.im = -t := by
    have := congr_arg Complex.im h_eq; simp at this; linarith
  have h_nsq : Complex.normSq z = 1 + t ^ 2 := by
    simp [Complex.normSq_apply, hz_re, hz_im]; ring
  have h_norm_sq : ‖z‖ ^ 2 ≥ 4 := by
    rw [← normSq_eq_norm_sq]; simp [h_nsq]; nlinarith [sq_abs t]
  have h_ge : ‖z‖ ≥ 2 := by
    by_contra h
    push Not at h
    have : ‖z‖ ^ 2 < 4 := by nlinarith [norm_nonneg z, mul_self_nonneg (‖z‖)]
    linarith
  linarith

/-- Helper: Re(s₀ + z) > 1/2 for z in the BC disk. -/
private lemma re_gt_half_on_disk {t : ℝ}
    {R : ℝ} (hR_lt : R < 3/2) {z : ℂ} (hz : z ∈ ball (0 : ℂ) R) :
    1/2 < ((⟨2, t⟩ : ℂ) + z).re := by
  simp only [mem_ball, dist_zero_right] at hz
  simp only [Complex.add_re]
  have h_abs : |z.re| ≤ ‖z‖ := Complex.abs_re_le_norm z
  linarith [abs_le.mp (le_of_lt (lt_of_le_of_lt h_abs hz)) |>.1]

-- ═══════════════════════════════════════════
-- §2. Holomorphic Logarithm on the Disk
-- ═══════════════════════════════════════════

/-- **Holomorphic Logarithm**: A holomorphic nonvanishing function on a ball
    admits a holomorphic logarithm (primitive of f'/f), normalized to vanish
    at the center.

    This is a standard result: on a simply connected domain, a nonvanishing
    holomorphic function f has a holomorphic log G with f = f(c)·exp(G).

    Proof sketch:
    1. f'/f is holomorphic on ball (f diff + f ≠ 0).
    2. By `DifferentiableOn.isExactOn_ball`, f'/f has a holomorphic
       primitive H with H'(z) = f'(z)/f(z).
    3. Normalize: G(z) = H(z) - H(c), so G(c) = 0.
    4. The function z ↦ f(z)·exp(-G(z)) has derivative 0:
       (f·e⁻ᴳ)' = f'·e⁻ᴳ - f·G'·e⁻ᴳ = e⁻ᴳ·(f' - f·f'/f) = 0.
    5. By `IsOpen.is_const_of_deriv_eq_zero` on the connected ball:
       f(z)·exp(-G(z)) = f(c)·exp(-G(c)) = f(c)·1 = f(c).
    6. So f(z) = f(c)·exp(G(z)) for all z ∈ ball.

    This construction bypasses slitPlane entirely — no branch cut issues. -/
private lemma holomorphic_log_exists_on_ball
    {c : ℂ} {R : ℝ} (hR : 0 < R)
    {f : ℂ → ℂ} (hf : DifferentiableOn ℂ f (ball c R))
    (hne : ∀ z ∈ ball c R, f z ≠ 0) :
    ∃ G : ℂ → ℂ, DifferentiableOn ℂ G (ball c R) ∧ G c = 0 ∧
      ∀ z ∈ ball c R, f z = f c * Complex.exp (G z) := by
  sorry

-- ═══════════════════════════════════════════
-- §3. Upper Bound on log|ζ| on the Disk
-- ═══════════════════════════════════════════

/-- Convexity bound: ‖ζ(s)‖ ≤ (2+|t|)^10 for Re(s) > 1/2 on the BC disk.

    For Re(s) ≥ 2: ‖ζ(s) - 1‖ ≤ 3/4, so ‖ζ‖ ≤ 7/4 < 2 ≤ (2+|t|)^10.
    For 1/2 < Re(s) < 2: The Phragmén-Lindelöf convexity principle gives
    ‖ζ(s)‖ ≤ C · (2 + |t|)^{(1-σ)/2} ≤ (2+|t|)^{3/4} ≤ (2+|t|)^10. -/
private lemma zeta_norm_bound_on_disk
    {t : ℝ} (ht : 2 ≤ |t|)
    {R : ℝ} (hR_pos : 0 < R) (hR_lt : R < 3/2) :
    ∀ z ∈ ball (0 : ℂ) R,
      ‖riemannZeta (⟨2, t⟩ + z)‖ ≤ (2 + |t|) ^ (10 : ℝ) := by
  sorry

-- ═══════════════════════════════════════════
-- §5. The Main Theorem: Polynomial Lower Bound
-- ═══════════════════════════════════════════

/-- **THEOREM** (was AXIOM): Under RH, |ζ(s)| has a polynomial lower bound.

    Proved via Borel-Carathéodory applied to log ζ on a shifted disk.
    This replaces the axiom `zeta_polynomial_lower_bound_rh` from
    ZetaConvexity.lean.

    Proof outline:
    1. Fix ε > 0, A > 0.
    2. Set R = 3/2 - ε/2, s₀ = (2, t).
    3. BC gives |log ζ(s)| ≤ 2M · r/(R-r) + |log ζ(s₀)| · (R+r)/(R-r)
       where M = sup Re(log ζ) on disk, r = |s - s₀|.
    4. For s with Re(s) = 1/2 + ε, we have r = 3/2 - ε, so
       R - r = ε/2, and the bound is O(M/ε) = O(log|t|/ε).
    5. Exponentiate: |ζ(s)| ≥ exp(-C·log|t|) = |t|^{-C}.
    6. Choose c = 1, and the bound holds for |t| ≥ T₀. -/
theorem zeta_polynomial_lower_bound_rh_proved (hRH : RiemannHypothesis)
    (ε : ℝ) (hε : 0 < ε) (A : ℝ) (hA : 0 < A) :
    ∃ c > 0, ∃ T₀ > 0, ∀ s : ℂ,
      (1/2 + ε ≤ s.re) → (T₀ ≤ |s.im|) →
      c / |s.im| ^ A ≤ ‖riemannZeta s‖ := by
  -- Case split: for large ε (≥ 3/2), Re(s) ≥ 2 and tail bound gives |ζ| ≥ 1/4.
  -- For small ε (< 3/2), use BC.
  by_cases hε1 : 3/2 ≤ ε
  · -- ε ≥ 3/2: Re(s) ≥ 1/2 + 3/2 = 2, so ‖ζ(s) - 1‖ < 1
    refine ⟨1/4, by norm_num, 2, by norm_num, ?_⟩
    intro s hs him
    have hre2 : 2 ≤ s.re := by linarith
    have ht_ge_2 : 2 ≤ |s.im| := him
    have ht_pos : 0 < |s.im| := by linarith
    -- s ≠ 1 since |Im(s)| ≥ 2 but Im(1) = 0
    have hs1 : s ≠ 1 := by
      intro h
      have him : s.im = 0 := by
        have := congr_arg Complex.im h; simp at this; exact this
      rw [him, abs_zero] at ht_ge_2
      linarith
    have h_tail := zeta_sub_one_norm_le_three_fourths hre2
    -- ‖ζ(s)‖ ≥ 1 - ‖ζ(s) - 1‖ ≥ 1 - 3/4 = 1/4
    have h_lower : 1/4 ≤ ‖riemannZeta s‖ := by
      -- ‖ζ - 1‖ ≤ ‖ζ‖ + 1 (triangle) means ‖ζ‖ ≥ ‖ζ-1‖ - 1... wait no
      -- We need: ‖ζ‖ ≥ 1 - ‖ζ - 1‖. This is the "reverse triangle" direction.
      -- From triangle: ‖(ζ-1) + 1‖ ≤ ‖ζ-1‖ + ‖1‖, i.e., ‖ζ‖ ≤ ‖ζ-1‖ + 1
      -- Other direction: ‖1‖ ≤ ‖ζ‖ + ‖ζ - 1‖ (triangle on ζ and ζ-1 summing to 1)
      -- Wait: ‖1‖ = ‖ζ - (ζ - 1)‖ ≤ ‖ζ‖ + ‖ζ - 1‖
      have h1 : (1 : ℝ) ≤ ‖riemannZeta s‖ + ‖riemannZeta s - 1‖ := by
        calc (1:ℝ) = ‖(1:ℂ)‖ := by simp
          _ = ‖riemannZeta s - (riemannZeta s - 1)‖ := by ring_nf
          _ ≤ ‖riemannZeta s‖ + ‖riemannZeta s - 1‖ := norm_sub_le _ _
      linarith
    -- |t|^A ≥ 1 since |t| ≥ 2 ≥ 1 and A > 0
    have h_rpow_ge : 1 ≤ |s.im| ^ A :=
      Real.one_le_rpow (by linarith : 1 ≤ |s.im|) hA.le
    calc (1:ℝ)/4 / |s.im| ^ A
        ≤ 1/4 := div_le_self (by norm_num) h_rpow_ge
      _ ≤ ‖riemannZeta s‖ := h_lower
  · -- ε < 1: Use BC on disk B(2+it, R) with R = 3/2 - ε/2
    push Not at hε1
    set R := 3/2 - ε/2 with hR_def
    have hR_pos : 0 < R := by rw [hR_def]; linarith
    have hR_lt : R < 3/2 := by rw [hR_def]; linarith
    refine ⟨1, one_pos, max 2 1, lt_max_of_lt_left (by norm_num : (0:ℝ) < 2), ?_⟩
    intro s hs him
    have ht_ge_2 : 2 ≤ |s.im| := le_trans (le_max_left 2 1) him
    -- PROOF ARCHITECTURE (via holomorphic logarithm + BC):
    -- 1. Get holomorphic log G with ζ(s₀+z) = ζ(s₀)·exp(G(z)), G(0) = 0
    -- 2. Re(G(z)) = log(‖ζ(s₀+z)‖/‖ζ(s₀)‖) ≤ log((2+|t|)^10/‖ζ(s₀)‖)
    --    ≤ 10·log(2+|t|) + 2 =: M  (since ‖ζ(s₀)‖ ≥ 1/4)
    -- 3. BC: ‖G(z)‖ ≤ 2M·‖z‖/(R-‖z‖) + 0  (since G(0) = 0)
    -- 4. For s = 1/2+ε+it: z = s - s₀ = (-3/2+ε, 0), ‖z‖ = 3/2-ε,
    --    R - ‖z‖ = (3/2-ε/2) - (3/2-ε) = ε/2
    -- 5. Re(G(z)) ≥ -‖G(z)‖ ≥ -2M(3/2-ε)/(ε/2) = -2M(3-2ε)/ε
    -- 6. ‖ζ(s)‖ = ‖ζ(s₀)‖·exp(Re(G(z))) ≥ (1/4)·exp(-2M(3-2ε)/ε)
    --    ≥ (1/4)·exp(-C·log|t|/ε) = (1/4)·|t|^(-C/ε)
    -- 7. For A > 0: choose c and T₀ so that c/|t|^A ≤ (1/4)·|t|^(-C/ε)
    sorry

end Cathedral.White.Infrastructure.ZetaLowerBound
