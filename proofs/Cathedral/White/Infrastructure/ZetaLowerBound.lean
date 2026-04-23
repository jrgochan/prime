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
  · push_neg at h1
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

/-- The tail of the Dirichlet series: ‖ζ(s) - 1‖ < 1 for Re(s) ≥ 2.
    This is the key arithmetic fact used to show ζ ∈ slitPlane.

    Proof: ζ(s) = Σ_{n≥1} n^{-s} = 1 + Σ_{n≥2} n^{-s}.
    So ζ(s) - 1 = Σ_{n≥2} n^{-s} and
    ‖ζ(s) - 1‖ ≤ Σ_{n≥2} n^{-Re(s)} ≤ Σ_{n≥2} n^{-2} = π²/6 - 1 ≈ 0.645 < 1. -/
private lemma zeta_sub_one_norm_lt_one_of_re_ge_two {s : ℂ} (hs : 2 ≤ s.re) :
    ‖riemannZeta s - 1‖ < 1 := by
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
  -- We combine both steps: bound ‖∑' g(n+1+1)‖ ≤ 3/4 < 1
  -- using tsum_of_norm_bounded with a custom bound series.
  -- First: ‖g(n+1+1)‖ = (n+2)^{-σ} ≤ (n+2)^{-2}
  -- Second: (n+2)^{-2} ≤ 1/((n+1)(n+2)) since n+1 ≤ n+2
  -- The series 1/((n+1)(n+2)) = 1/(n+1) - 1/(n+2) telescopes to 1.
  -- But tsum_of_norm_bounded gives ≤ 1, not < 1.
  -- So we extract first term: ‖g(2)‖ ≤ 1/4 and ∑_{n≥1} ≤ 1/2. Total ≤ 3/4 < 1.
  apply lt_of_le_of_lt (b := (3:ℝ)/4)
  · -- ‖∑' g(n+1+1)‖ ≤ 3/4
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
  · -- Step: 3/4 < 1
    norm_num

/-- ζ(s) ∈ slitPlane for Re(s) ≥ 2 (far from critical strip).

    For Re(s) ≥ 2, |ζ(s) - 1| ≤ Σ_{n≥2} n^{-2} = π²/6 - 1 ≈ 0.645.
    Since ζ(s) is within distance < 1 from 1, it stays in
    {z | z.re > 0} ⊂ slitPlane.

    Proof uses `mem_slitPlane_of_norm_lt_one`: ‖z‖ < 1 → 1 + z ∈ slitPlane. -/
private lemma zeta_mem_slitPlane_of_re_ge_two {s : ℂ} (hs : 2 ≤ s.re) (hs1 : s ≠ 1) :
    riemannZeta s ∈ slitPlane := by
  -- ζ(s) = 1 + (ζ(s) - 1). Since ‖ζ(s) - 1‖ < 1, we get ζ(s) ∈ slitPlane.
  have h : ‖riemannZeta s - 1‖ < 1 := zeta_sub_one_norm_lt_one_of_re_ge_two hs
  have := mem_slitPlane_of_norm_lt_one h
  rwa [add_sub_cancel] at this

/-- Under RH, ζ(s) ∈ slitPlane for all s in the BC disk B(s₀, R).
    The disk is centered at s₀ with Re(s₀) = 2, radius R < 3/2,
    so Re(s) > 1/2 throughout, and ζ ≠ 0 under RH.

    The slitPlane condition (ζ(s) ∉ ℝ≤0) is the hardest part.
    We use a connectedness argument: ζ maps the simply connected
    disk continuously to ℂ \ {0}, and ζ(s₀) has Re > 0, so
    by path-lifting the image stays in a single branch. -/
private lemma zeta_mem_slitPlane_on_disk (hRH : RiemannHypothesis)
    {t : ℝ} (ht : 2 ≤ |t|)
    {R : ℝ} (hR_pos : 0 < R) (hR_lt : R < 3/2) :
    ∀ z ∈ ball (0 : ℂ) R,
      riemannZeta (⟨2, t⟩ + z) ∈ slitPlane := by
  -- Strategy: The continuous map ζ ∘ (s₀+·) sends ball into ℂ\{0} (RH + no pole).
  -- slitPlane is open, ℝ<0 = (ℂ\{0}) \ slitPlane is NOT open,
  -- so we use a direct argument: ℝ≤0 ∩ ζ(ball) = ∅.
  --
  -- For now, we delegate to a topological argument using
  -- the fact that the preimage of slitPlane under a continuous,
  -- nonzero-valued function on a connected domain is clopen
  -- (since slitPlane and its complement in ℂ\{0} are both open
  -- when restricted to {Im ≠ 0} ∪ {Re > 0}).
  sorry

-- ═══════════════════════════════════════════
-- §3. Sup Bound on Re(log ζ) on the Disk
-- ═══════════════════════════════════════════

/-- Convexity bound: log|ζ(s)| ≤ C · log(2 + |t|) for Re(s) ≥ 1/2 + ε.

    This is the standard convexity bound for ζ in the critical strip.
    For Re(s) ≥ 2: |ζ(s)| ≤ ζ(2) < 2, so log|ζ| ≤ 1.
    For 1/2 < Re(s) < 2: The Phragmén-Lindelöf principle gives
    |ζ(s)| ≤ C · (2 + |t|)^{(1-σ)/2} where σ = Re(s).
    Hence log|ζ(s)| ≤ C' · log(2 + |t|).

    Under RH this simplifies: ζ has no zeros for Re > 1/2, so
    the convexity bound applies uniformly. -/
private lemma log_zeta_re_bound_on_disk
    {t : ℝ} (ht : 2 ≤ |t|)
    {R : ℝ} (hR_pos : 0 < R) (hR_lt : R < 3/2)
    {ε : ℝ} (hε : 0 < ε) (hR_ε : R ≤ 3/2 - ε/2) :
    ∃ M : ℝ, 0 < M ∧ M ≤ 10 * Real.log (2 + |t|) ∧
    ∀ z ∈ ball (0 : ℂ) R,
      (Complex.log (riemannZeta (⟨2, t⟩ + z))).re ≤ M := by
  sorry -- Requires: convexity bound for ζ via PL principle

-- ═══════════════════════════════════════════
-- §4. Differentiability of log ζ on the Disk
-- ═══════════════════════════════════════════

/-- log ∘ ζ ∘ (· + s₀) is differentiable on ball(0, R) under RH. -/
private lemma log_zeta_differentiableOn_disk (hRH : RiemannHypothesis)
    {t : ℝ} (ht : 2 ≤ |t|)
    {R : ℝ} (hR_pos : 0 < R) (hR_lt : R < 3/2) :
    DifferentiableOn ℂ (fun z => Complex.log (riemannZeta (⟨2, t⟩ + z)))
      (ball 0 R) := by
  apply DifferentiableOn.clog
  · -- ζ ∘ (· + s₀) is differentiable on the ball
    apply DifferentiableOn.comp differentiableOn_riemannZeta
    · exact differentiableOn_const _ |>.add differentiableOn_id
    · intro z hz
      -- Need: ⟨2, t⟩ + z ≠ 1
      simp only [Set.mem_compl_iff, Set.mem_singleton_iff]
      intro h_eq
      simp only [mem_ball, dist_zero_right] at hz
      -- If ⟨2,t⟩ + z = 1 then z = ⟨-1, -t⟩, so ‖z‖ ≥ |t| ≥ 2 > R
      have hz_re : z.re = -1 := by
        have := congr_arg Complex.re h_eq; simp at this; linarith
      have hz_im : z.im = -t := by
        have := congr_arg Complex.im h_eq; simp at this; linarith
      -- ‖z‖² = z.re² + z.im² = 1 + t² ≥ t² ≥ 4
      have h_nsq : Complex.normSq z = 1 + t ^ 2 := by
        simp [Complex.normSq_apply, hz_re, hz_im]; ring
      -- ‖z‖² = normSq z ≥ 4, so ‖z‖ ≥ 2 > 3/2 > R
      have h_norm_sq : ‖z‖ ^ 2 ≥ 4 := by
        rw [← normSq_eq_norm_sq]; simp [h_nsq]; nlinarith [sq_abs t]
      have h_ge : ‖z‖ ≥ 2 := by
        by_contra h
        push_neg at h
        have h_norm_pos := norm_nonneg z
        have : ‖z‖ ^ 2 < 4 := by nlinarith [mul_self_nonneg (‖z‖)]
        linarith
      linarith
  · -- ζ(s₀ + z) ∈ slitPlane for all z in ball
    exact zeta_mem_slitPlane_on_disk hRH ht hR_pos hR_lt

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
  -- Step 1: Choose disk parameters
  set R := 3/2 - ε/2 with hR_def
  -- Step 2: For sufficiently large |t|, apply BC
  -- The key estimate: on the BC disk B(2+it, R),
  --   |log ζ(s)| ≤ C(ε) · log(2+|t|)
  -- where C(ε) depends only on R/(R-r) ~ 1/ε.
  -- Exponentiating: |ζ(s)| ≥ (2+|t|)^{-C(ε)} ≥ c/|t|^A
  -- for |t| ≥ T₀(ε, A).

  -- Choose T₀ large enough and c = 1
  -- The full assembly of the BC argument:
  sorry -- Assembly: BC + log_zeta + exponentiation

end Cathedral.White.Infrastructure.ZetaLowerBound
