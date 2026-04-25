/-
  Cathedral/White/Infrastructure/ZetaDiskBounds.lean

  ## Zeta Disk Geometry & Upper Bounds

  Infrastructure for the Borel-Carathéodory lower bound proof.
  Contains the disk geometry lemmas, holomorphic logarithm construction,
  and zeta upper bounds on the shifted disk.

  ### Contents
  - §1. Zeta nonvanishing under RH
  - §2. Zeta values in slitPlane / disk lemmas
  - §3. Holomorphic logarithm on the disk
  - §4. Upper bound on |ζ| on the disk

  ### Dependencies: Mathlib (ζ, log, BC), ZetaConvexityBound.
-/

import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.LSeries.Nonvanishing
import Mathlib.NumberTheory.LSeries.Dirichlet
import Mathlib.Analysis.Complex.BorelCaratheodory
import Mathlib.Analysis.SpecialFunctions.Complex.LogDeriv
import Mathlib.Analysis.Complex.PhragmenLindelof
import Mathlib.Analysis.Complex.HasPrimitives
import Mathlib.Analysis.Calculus.FDeriv.Analytic
import Mathlib.Analysis.Normed.Operator.Asymptotics
import Cathedral.White.Infrastructure.ZetaConvexityBound

noncomputable section
open Complex Real Filter Asymptotics MeasureTheory Metric
open scoped Topology

namespace Cathedral.White.Infrastructure.ZetaDiskBounds

-- ═══════════════════════════════════════════
-- §1. Zeta Nonvanishing Under RH
-- ═══════════════════════════════════════════

/-- Under RH, ζ(s) ≠ 0 for Re(s) > 1/2, s ≠ 1. Proved in ZetaConvexity.lean. -/
theorem rh_zeta_ne_zero (hRH : RiemannHypothesis)
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
-- §2. Tail Bound & Disk Geometry
-- ═══════════════════════════════════════════

/-- **Strengthened bound**: ‖ζ(s) - 1‖ ≤ 3/4 for Re(s) ≥ 2.
    This is tighter than `< 1` and needed for the explicit lower bound ‖ζ(s)‖ ≥ 1/4. -/
theorem zeta_sub_one_norm_le_three_fourths {s : ℂ} (hs : 2 ≤ s.re) :
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
  -- ζ(s) - 1 = Σ_{n≥2} g(n)
  rw [h_zeta, hg_ns.of_norm.tsum_eq_zero_add, h_g0, zero_add]
  have hg_shift : Summable (fun n => ‖g (n + 1)‖) :=
    hg_ns.comp_injective (fun a b h => by omega)
  rw [hg_shift.of_norm.tsum_eq_zero_add, h_g1, add_sub_cancel_left]
  -- Bound via telescoping: b(0) = 1/4, b(n) = 1/((n+1)(n+2))
  let b : ℕ → ℝ := fun n => if n = 0 then 1/4 else 1/((↑n + 1) * (↑n + 2))
  have hb_hasSum : HasSum b (3/4) := by
      rw [hasSum_iff_tendsto_nat_of_nonneg (fun n => by simp [b]; split_ifs <;> positivity)]
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
            simp only [b, show m ≠ 0 from hm0, ite_false]
            push_cast
            field_simp
            ring
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
    rw [show (n + 1 + 1 : ℕ) = n + 2 from by omega]
    have hpos : (0 : ℝ) < (↑(n + 2) : ℝ) := by positivity
    rw [← ofReal_natCast, norm_cpow_eq_rpow_re_of_pos hpos, neg_re]
    split_ifs with h
    · -- n = 0: 2^{-σ} ≤ 1/4 since σ ≥ 2
      subst h
      norm_num
      calc (2:ℝ) ^ (-s.re) ≤ (2:ℝ) ^ (-(2:ℝ)) :=
        Real.rpow_le_rpow_of_exponent_le (by norm_num) (by linarith)
      _ = 1/4 := by
        rw [show (-(2:ℝ)) = -((2:ℕ) : ℝ) from by norm_num,
            Real.rpow_neg (by norm_num : (0:ℝ) ≤ 2),
            Real.rpow_natCast]; norm_num
    · -- n ≥ 1: bound via (n+2)^{-2} ≤ 1/((n+1)(n+2))
      have h1 : (1:ℝ) ≤ ↑(n + 2) := by
        exact_mod_cast Nat.one_le_iff_ne_zero.mpr (by omega)
      have h_exp : (↑(n + 2) : ℝ) ^ (-s.re) ≤ (↑(n + 2) : ℝ) ^ (-(2:ℝ)) :=
        Real.rpow_le_rpow_of_exponent_le h1 (by linarith)
      have h_inv : (↑(n + 2) : ℝ) ^ (-(2:ℝ)) = 1 / (↑(n + 2) : ℝ) ^ (2:ℝ) := by
        rw [Real.rpow_neg (by positivity : (0:ℝ) ≤ ↑(n+2))]
        ring
      have h_frac : 1 / (↑(n + 2) : ℝ) ^ (2:ℝ) ≤ 1/((↑n + 1) * (↑n + 2)) := by
        rw [show (2:ℝ) = ((2:ℕ):ℝ) from by norm_num, Real.rpow_natCast]
        push_cast
        apply one_div_le_one_div_of_le (by positivity)
        nlinarith [show (0:ℝ) ≤ ↑n from Nat.cast_nonneg n]
      linarith
  exact tsum_of_norm_bounded hb_hasSum hb_bound

/-- ζ(s) ∈ slitPlane for Re(s) ≥ 2 (far from critical strip). -/
theorem zeta_mem_slitPlane_of_re_ge_two {s : ℂ} (hs : 2 ≤ s.re) (_hs1 : s ≠ 1) :
    riemannZeta s ∈ slitPlane := by
  have h : ‖riemannZeta s - 1‖ < 1 := lt_of_le_of_lt (zeta_sub_one_norm_le_three_fourths hs) (by norm_num)
  have := mem_slitPlane_of_norm_lt_one h
  rwa [add_sub_cancel] at this

/-- s₀ + z ≠ 1 for z in the BC disk, since |s₀ - 1| ≥ |t| ≥ 2 > 3/2 > R. -/
theorem s_ne_one_on_disk {t : ℝ} (ht : 2 ≤ |t|)
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

/-- Re(s₀ + z) > 1/2 for z in the BC disk. -/
theorem re_gt_half_on_disk {t : ℝ}
    {R : ℝ} (hR_lt : R < 3/2) {z : ℂ} (hz : z ∈ ball (0 : ℂ) R) :
    1/2 < ((⟨2, t⟩ : ℂ) + z).re := by
  simp only [mem_ball, dist_zero_right] at hz
  simp only [Complex.add_re]
  have h_abs : |z.re| ≤ ‖z‖ := Complex.abs_re_le_norm z
  linarith [abs_le.mp (le_of_lt (lt_of_le_of_lt h_abs hz)) |>.1]

-- ═══════════════════════════════════════════
-- §3. Holomorphic Logarithm on the Disk
-- ═══════════════════════════════════════════

/-- **Holomorphic Logarithm**: A holomorphic nonvanishing function on a ball
    admits a holomorphic logarithm (primitive of f'/f), normalized to vanish
    at the center.

    This construction bypasses slitPlane entirely — no branch cut issues.
    Proof: (1) f'/f holomorphic, (2) primitive H via isExactOn_ball,
    (3) normalize G = H - H(c), (4) f·exp(-G) constant by deriv = 0. -/
theorem holomorphic_log_exists_on_ball
    {c : ℂ} {R : ℝ} (hR : 0 < R)
    {f : ℂ → ℂ} (hf : DifferentiableOn ℂ f (ball c R))
    (hne : ∀ z ∈ ball c R, f z ≠ 0) :
    ∃ G : ℂ → ℂ, DifferentiableOn ℂ G (ball c R) ∧ G c = 0 ∧
      ∀ z ∈ ball c R, f z = f c * Complex.exp (G z) := by
  -- Step 1: log derivative f'/f is differentiable on ball
  have hf_analytic := hf.analyticOnNhd isOpen_ball
  have hderiv_f_diffOn : DifferentiableOn ℂ (deriv f) (ball c R) :=
    hf_analytic.deriv.differentiableOn
  have hlogDeriv_diffOn : DifferentiableOn ℂ (fun z => deriv f z / f z) (ball c R) :=
    DifferentiableOn.fun_div hderiv_f_diffOn hf hne
  -- Step 2: Primitive H via isExactOn_ball
  have hExact : IsExactOn (fun z => deriv f z / f z) (ball c R) :=
    DifferentiableOn.isExactOn_ball hlogDeriv_diffOn
  -- Step 3: Normalize G(c) = 0
  -- IsExactOn gives ∃ g, ∀ z ∈ U, HasDerivAt g (f z) z
  -- Define G z = g z - g c to normalize G(c) = 0
  obtain ⟨g₀, hg₀⟩ := hExact
  set G : ℂ → ℂ := fun z => g₀ z - g₀ c with hG_def
  have hG0 : G c = 0 := by simp [hG_def]
  have hGderiv : ∀ z ∈ ball c R, HasDerivAt G (deriv f z / f z) z := by
    intro z hz
    have h := (hg₀ z hz).sub (hasDerivAt_const z (g₀ c))
    simp only [sub_zero] at h
    exact h
  have hG_diff : DifferentiableOn ℂ G (ball c R) := by
    intro z hz
    exact (hGderiv z hz).differentiableAt.differentiableWithinAt
  -- Step 4: f · exp(-G) has zero derivative → constant
  set h : ℂ → ℂ := fun z => f z * Complex.exp (-G z) with hh_def
  have hh_diff : DifferentiableOn ℂ h (ball c R) := by
    apply DifferentiableOn.mul hf
    exact DifferentiableOn.cexp (DifferentiableOn.neg hG_diff)
  have hh_deriv_zero : (ball c R).EqOn (deriv h) 0 := by
    intro z hz
    have hGd := hGderiv z hz
    have hfd : DifferentiableAt ℂ f z :=
      hf.differentiableAt (isOpen_ball.mem_nhds hz)
    have hnd : HasDerivAt (fun z => -G z) (-(deriv f z / f z)) z := hGd.neg
    have hexp_hd : HasDerivAt (fun z => Complex.exp (-G z))
        (Complex.exp (-G z) * (-(deriv f z / f z))) z :=
      HasDerivAt.cexp hnd
    have hf_hd : HasDerivAt f (deriv f z) z := hfd.hasDerivAt
    have hh_hd : HasDerivAt h
        (deriv f z * Complex.exp (-G z) +
         f z * (Complex.exp (-G z) * (-(deriv f z / f z)))) z :=
      hf_hd.mul hexp_hd
    rw [Pi.zero_apply]
    have hfz := hne z hz
    have : deriv f z * Complex.exp (-G z) +
      f z * (Complex.exp (-G z) * (-(deriv f z / f z))) = 0 := by
      field_simp; ring
    rw [← this]
    exact hh_hd.deriv
  -- Step 5: h constant on ball
  have hh_const : ∀ z ∈ ball c R, h z = h c :=
    fun z hz => isOpen_ball.is_const_of_deriv_eq_zero
      isPreconnected_ball hh_diff hh_deriv_zero hz (mem_ball_self hR)
  -- Step 6: h(c) = f(c)
  have hh_center : h c = f c := by
    simp [hh_def, hG0]
  -- Step 7: f(z) = f(c) · exp(G(z))
  refine ⟨G, hG_diff, hG0, fun z hz => ?_⟩
  have := hh_const z hz
  rw [hh_center] at this
  have hexp_ne : Complex.exp (-G z) ≠ 0 := Complex.exp_ne_zero _
  calc f z = f z * Complex.exp (-G z) * Complex.exp (G z) := by
        rw [mul_assoc, ← Complex.exp_add]; simp
    _ = f c * Complex.exp (G z) := by
        congr 1

-- ═══════════════════════════════════════════
-- §4. Upper Bound on |ζ| on the Disk
-- ═══════════════════════════════════════════

/-- **Convexity bound** (from ZetaConvexityBound.lean, zero sorry):
    ‖ζ(s)‖ ≤ (2 + |Im(s)|)^2 for 1/2 < Re(s) ≤ 2, |Im(s)| ≥ 1/2. -/
theorem zeta_norm_convexity_bound {s : ℂ}
    (hrs : 1/2 < s.re) (hrs2 : s.re ≤ 2) (him : 1/2 ≤ |s.im|) :
    ‖riemannZeta s‖ ≤ (2 + |s.im|) ^ (2 : ℝ) :=
  ZetaConvexityBound.zeta_norm_convexity_bound hrs hrs2 him

/-- **Disk upper bound**: ‖ζ(s₀+z)‖ ≤ (2+|t|)^10 on ball(0, R).

    Case split: Re(s₀+z) ≥ 2 → tail bound, Re(s₀+z) < 2 → convexity bound.
    Both ≤ (2+|t|)^10 since (2+|t|)^10 ≥ 4^10 > 10^6. -/
theorem zeta_norm_bound_on_disk
    {t : ℝ} (ht : 2 ≤ |t|)
    {R : ℝ} (_hR_pos : 0 < R) (hR_lt : R < 3/2) :
    ∀ z ∈ ball (0 : ℂ) R,
      ‖riemannZeta (⟨2, t⟩ + z)‖ ≤ (2 + |t|) ^ (10 : ℝ) := by
  intro z hz
  set s := (⟨2, t⟩ : ℂ) + z with hs_def
  by_cases hre : 2 ≤ s.re
  · -- Case 1: Re(s) ≥ 2. Tail bound gives ‖ζ(s)-1‖ ≤ 3/4 → ‖ζ‖ ≤ 7/4
    have h74 : ‖riemannZeta s‖ ≤ 7/4 := by
      have hsub := zeta_sub_one_norm_le_three_fourths hre
      have h1 : ‖riemannZeta s‖ ≤ ‖riemannZeta s - 1‖ + 1 := by
        have := norm_le_insert' (riemannZeta s) (1 : ℂ)
        simp at this; linarith
      linarith
    calc ‖riemannZeta s‖ ≤ 7/4 := h74
      _ ≤ 2 := by norm_num
      _ ≤ 2 + |t| := le_add_of_nonneg_right (abs_nonneg t)
      _ ≤ (2 + |t|) ^ (10 : ℝ) := by
          have hbase : (1 : ℝ) ≤ 2 + |t| := by linarith [abs_nonneg t]
          have : (2 + |t|) ^ (1 : ℝ) ≤ (2 + |t|) ^ (10 : ℝ) :=
            rpow_le_rpow_of_exponent_le hbase (by norm_num : (1 : ℝ) ≤ 10)
          rwa [rpow_one] at this
  · -- Case 2: Re(s) < 2. Use convexity bound.
    simp only [not_le] at hre
    have hrs : 1/2 < s.re := re_gt_half_on_disk hR_lt hz
    have him : 1/2 ≤ |s.im| := by
      simp only [hs_def, Complex.add_im]
      simp only [mem_ball, dist_zero_right] at hz
      have hzim_bound : |z.im| < R := by
        exact lt_of_le_of_lt (Complex.abs_im_le_norm z) hz
      have hzim_lt : |z.im| < 3/2 := lt_trans hzim_bound hR_lt
      have key : |t + z.im| ≥ |t| - |z.im| := by
        rcases le_or_gt 0 t with ht' | ht'
        · rw [abs_of_nonneg ht']
          rcases le_or_gt 0 z.im with hzi | hzi
          · rw [abs_of_nonneg hzi, abs_of_nonneg (by linarith)]; linarith
          · rw [abs_of_neg hzi]
            rcases le_or_gt 0 (t + z.im) with h | h
            · rw [abs_of_nonneg h]; linarith
            · rw [abs_of_neg h]; linarith
        · rw [abs_of_neg ht']
          rcases le_or_gt 0 z.im with hzi | hzi
          · rw [abs_of_nonneg hzi]
            rcases le_or_gt 0 (t + z.im) with h | h
            · rw [abs_of_nonneg h]; linarith
            · rw [abs_of_neg h]; linarith
          · rw [abs_of_neg hzi, abs_of_neg (by linarith)]; linarith
      linarith
    have hconv := zeta_norm_convexity_bound hrs (le_of_lt hre) him
    have him_bound : |s.im| < |t| + 3/2 := by
      simp only [hs_def, Complex.add_im]
      simp only [mem_ball, dist_zero_right] at hz
      calc |t + z.im| ≤ |t| + |z.im| := abs_add_le t z.im
        _ < |t| + 3/2 := by linarith [Complex.abs_im_le_norm z]
    have h_base : (1 : ℝ) ≤ 2 + |t| := by linarith [abs_nonneg t]
    have him_upper : 2 + |s.im| ≤ 2 * (2 + |t|) := by linarith
    have h2pos : (0 : ℝ) ≤ 2 + |s.im| := by linarith [abs_nonneg s.im]
    rw [show (10 : ℝ) = ((10 : ℕ) : ℝ) from by norm_num] at *
    rw [show (2 : ℝ) = ((2 : ℕ) : ℝ) from by norm_num] at hconv
    rw [rpow_natCast] at hconv
    rw [rpow_natCast]
    calc ‖riemannZeta s‖
        ≤ (2 + |s.im|) ^ 2 := hconv
      _ ≤ (2 * (2 + |t|)) ^ 2 := by nlinarith
      _ = 4 * (2 + |t|) ^ 2 := by ring
      _ ≤ (2 + |t|) ^ 2 * (2 + |t|) ^ 2 := by
          have : 4 ≤ (2 + |t|) ^ 2 := by nlinarith [abs_nonneg t]
          nlinarith [sq_nonneg ((2 + |t|) ^ 1)]
      _ = (2 + |t|) ^ 4 := by ring
      _ ≤ (2 + |t|) ^ 10 := pow_le_pow_right₀ h_base (by norm_num : 4 ≤ 10)

end Cathedral.White.Infrastructure.ZetaDiskBounds
