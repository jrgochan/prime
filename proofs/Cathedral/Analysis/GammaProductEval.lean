/-
  Cathedral/Analysis/GammaProductEval.lean

  ## Evaluation of ∑ log Γ((1+k)/q) via Stirling's formula

  This file provides the key identity:

    ∑_{k=0}^{q-1} log Γ((1+k)/q) = (q-1)/2 · log(2π) - 1/2 · log q

  The proof uses Stirling's formula, the logGammaSeq limit, and a
  combinatorial bijection. This is isolated from the main
  GammaMultiplication file to avoid namespace pollution from the
  Stirling import.

  Created: May 1, 2026 (The Vasyunin Bridge — May Campaign)
-/

import Mathlib.Analysis.SpecialFunctions.Gamma.BohrMollerup
import Mathlib.Analysis.SpecialFunctions.Gamma.Beta
import Mathlib.Analysis.SpecialFunctions.Stirling

noncomputable section
open Real MeasureTheory Filter Finset Stirling BohrMollerup
open scoped Nat ENNReal Topology Real

namespace Cathedral.Analysis.GammaProductEval

-- ── Infrastructure: finite sum of limits ──

private lemma tendsto_finset_sum' {ι : Type*} (S : Finset ι) {f : ι → ℕ → ℝ} {a : ι → ℝ}
    (hf : ∀ k ∈ S, Tendsto (f k) atTop (nhds (a k))) :
    Tendsto (fun n => ∑ k ∈ S, f k n) atTop (nhds (∑ k ∈ S, a k)) := by
  classical
  induction S using Finset.induction_on with
  | empty =>
    simp only [Finset.sum_empty]
    exact tendsto_const_nhds
  | @insert k s' hk ih =>
    simp only [Finset.sum_insert hk]
    exact (hf k (Finset.mem_insert_self k s')).add
      (ih (fun j hj => hf j (Finset.mem_insert_of_mem hj)))

-- ── Infrastructure: (n+1)(log n - log(n+1)) + 1 → 0 ──

private lemma tendsto_n_succ_mul_log_ratio :
    Tendsto (fun n : ℕ => ((n : ℝ) + 1) *
      (Real.log (n : ℝ) - Real.log ((n : ℝ) + 1)) + 1) atTop (nhds 0) := by
  rw [Metric.tendsto_atTop]
  intro ε hε
  obtain ⟨N, hN⟩ := exists_nat_gt (1/ε)
  refine ⟨N + 1, fun n hn => ?_⟩
  have hn_pos : (0:ℝ) < n := Nat.cast_pos.mpr (by omega)
  have hn1_pos : (0:ℝ) < (n:ℝ) + 1 := by positivity
  rw [Real.dist_eq, sub_zero]
  have hlog_upper := log_le_sub_one_of_pos (div_pos hn_pos hn1_pos)
  rw [Real.log_div hn_pos.ne' hn1_pos.ne'] at hlog_upper
  have hlog_lower := one_sub_inv_le_log_of_pos (div_pos hn_pos hn1_pos)
  rw [inv_div, Real.log_div hn_pos.ne' hn1_pos.ne'] at hlog_lower
  -- Upper bound: f(n) ≤ 0
  have hupper : ((n:ℝ)+1) * (log ↑n - log (↑n+1)) + 1 ≤ 0 := by
    have h := mul_le_mul_of_nonneg_left hlog_upper hn1_pos.le
    have key : ((n:ℝ)+1) * ((n:ℝ) / ((n:ℝ)+1) - 1) = -1 := by
      have : (n:ℝ) + 1 ≠ 0 := hn1_pos.ne'
      field_simp; ring
    linarith
  -- Lower bound: f(n) ≥ -1/n
  have hlower : -(1/(n:ℝ)) ≤ ((n:ℝ)+1) * (log ↑n - log (↑n+1)) + 1 := by
    have h := mul_le_mul_of_nonneg_left hlog_lower hn1_pos.le
    have key : ((n:ℝ)+1) * (1 - ((n:ℝ)+1)/(n:ℝ)) = -((n:ℝ)+1)/(n:ℝ) := by
      field_simp; ring
    have key2 : -((n:ℝ)+1)/(n:ℝ) + 1 = -(1/(n:ℝ)) := by
      field_simp; ring
    linarith
  -- |f(n)| ≤ 1/n < ε
  have habs : |((n:ℝ)+1) * (log ↑n - log (↑n+1)) + 1| ≤ 1/n := by
    rw [abs_le]; constructor <;> linarith
  have hN_pos : (0:ℝ) < (↑N : ℝ) := by linarith [show (0:ℝ) < 1/ε from by positivity]
  calc |((n:ℝ)+1) * (log ↑n - log (↑n+1)) + 1|
      ≤ 1/↑n := habs
    _ ≤ 1/↑N := div_le_div_of_nonneg_left one_pos.le hN_pos
        (by exact_mod_cast (show N ≤ n by omega))
    _ < ε := (one_div_lt hN_pos hε).mpr hN

-- ── Infrastructure: weighted log ratio → 0 ──

set_option maxHeartbeats 1600000 in
lemma tendsto_weighted_log_ratio (c : ℝ) :
    Tendsto (fun n : ℕ => (c * (n : ℝ) + c + 1/2) *
      (Real.log (n : ℝ) - Real.log ((n : ℝ) + 1)) + c) atTop (nhds 0) := by
  -- Factor: f(n) = ((cn+c+1/2)/(n+1)) · ((n+1)(log n - log(n+1)) + 1) - 1/(2(n+1))
  suffices hfact : Tendsto (fun n : ℕ =>
    ((c * (n:ℝ) + c + 1/2) / ((n : ℝ) + 1)) *
      (((n : ℝ) + 1) * (Real.log (n : ℝ) - Real.log ((n : ℝ) + 1)) + 1) -
    1 / (2 * ((n : ℝ) + 1))) atTop (nhds 0) by
    refine hfact.congr (fun n => ?_)
    have hn1 : (n:ℝ) + 1 ≠ 0 := by positivity
    field_simp; ring
  have htop : Tendsto (fun n : ℕ => ((n : ℝ) + 1)) atTop atTop :=
    tendsto_natCast_atTop_atTop.atTop_add tendsto_const_nhds
  -- (cn+c+1/2)/(n+1) = c + 1/(2(n+1)) → c
  have h1 : Tendsto (fun n : ℕ => (c * (n:ℝ) + c + 1/2) / ((n : ℝ) + 1)) atTop (nhds c) := by
    have h : Tendsto (fun n : ℕ => 1 / (2 * ((n : ℝ) + 1))) atTop (nhds 0) :=
      Tendsto.div_atTop tendsto_const_nhds (htop.const_mul_atTop (by norm_num : (0:ℝ) < 2))
    have h2 : Tendsto (fun n : ℕ => c + 1 / (2 * ((n : ℝ) + 1))) atTop (nhds (c + 0)) :=
      Filter.Tendsto.add tendsto_const_nhds h
    rw [add_zero] at h2
    refine h2.congr (fun n => ?_)
    have : (n:ℝ) + 1 ≠ 0 := by positivity
    field_simp
  -- 1/(2(n+1)) → 0
  have h3 : Tendsto (fun n : ℕ => 1 / (2 * ((n : ℝ) + 1))) atTop (nhds 0) :=
    Tendsto.div_atTop tendsto_const_nhds (htop.const_mul_atTop (by norm_num : (0:ℝ) < 2))
  have h4 := h1.mul tendsto_n_succ_mul_log_ratio; rw [mul_zero] at h4
  have h5 := h4.sub h3; rwa [sub_zero] at h5

-- ── Infrastructure: Stirling correction limit ──

private lemma tendsto_stirling_correction (q : ℕ) (hq : 1 ≤ q) :
    Tendsto (fun n : ℕ => (q : ℝ) * Real.log (stirlingSeq n) -
      Real.log (stirlingSeq ((n+1)*q))) atTop (nhds ((q - 1 : ℝ)/2 * Real.log Real.pi)) := by
  have hlog_sqrt : Tendsto (fun n => Real.log (stirlingSeq n))
      atTop (nhds (Real.log (√Real.pi))) :=
    (Real.continuousAt_log (sqrt_ne_zero'.mpr pi_pos)).tendsto.comp tendsto_stirlingSeq_sqrt_pi
  have htop : Tendsto (fun n : ℕ => (n+1)*q) atTop atTop := by
    apply Filter.tendsto_atTop.mpr; intro b
    filter_upwards [Filter.eventually_ge_atTop b] with n hn
    calc b ≤ n := hn
      _ ≤ n * 1 := by omega
      _ ≤ n * q := Nat.mul_le_mul_left n hq
      _ ≤ (n+1) * q := Nat.mul_le_mul_right q (Nat.le_succ n)
  have h3 := (hlog_sqrt.const_mul (q : ℝ)).sub (hlog_sqrt.comp htop)
  suffices (q : ℝ) * Real.log (√Real.pi) - Real.log (√Real.pi) =
      ((q:ℝ) - 1) / 2 * Real.log Real.pi by rwa [this] at h3
  rw [Real.log_sqrt pi_pos.le]; ring

-- ── Combinatorial: ∑ k in range q of k = q*(q-1)/2 ──

private lemma sum_range_cast (q : ℕ) :
    (∑ k ∈ range q, (k : ℝ)) = (q : ℝ) * ((q : ℝ) - 1) / 2 := by
  induction q with
  | zero => simp
  | succ n ih => rw [Finset.sum_range_succ, ih]; push_cast; ring

-- ── Combinatorial: arithmetic sum ──

lemma sum_arith_over_q (q : ℕ) (hq : 1 ≤ q) :
    ∑ k ∈ range q, ((1 + (k : ℝ)) / (q : ℝ)) = ((q : ℝ) + 1) / 2 := by
  have hq_ne : (q : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  rw [← Finset.sum_div, Finset.sum_add_distrib, Finset.sum_const, Finset.card_range,
      nsmul_eq_mul, mul_one, sum_range_cast]
  field_simp; ring

-- ── Combinatorial: ∑ log(j+1) = log(N!) ──

private lemma sum_log_eq_log_factorial (N : ℕ) :
    ∑ j ∈ range N, Real.log ((j : ℝ) + 1) = Real.log (N !) := by
  induction N with
  | zero => simp
  | succ n ih =>
    rw [Finset.sum_range_succ, ih, Nat.factorial_succ, Nat.cast_mul, Nat.cast_succ,
        add_comm (Real.log _) (Real.log _)]
    exact (Real.log_mul (by positivity : (↑n + 1 : ℝ) ≠ 0)
      (Nat.cast_ne_zero.mpr (Nat.factorial_ne_zero n))).symm

-- ── Combinatorial: double sum via bijection (k,m) ↦ k+m·q ──

private lemma double_sum_eq_factorial_log (q n : ℕ) (hq : 1 ≤ q) :
    ∑ k ∈ range q, ∑ m ∈ range (n+1), Real.log ((1 : ℝ) + ↑k + ↑m * ↑q) =
    Real.log (((n+1)*q) !) := by
  rw [← sum_log_eq_log_factorial, ← Finset.sum_product']
  apply Finset.sum_nbij (fun (p : ℕ × ℕ) => p.1 + p.2 * q)
  · -- Membership
    intro ⟨k, m⟩ hmem
    simp only [Finset.mem_product, Finset.mem_range] at hmem ⊢
    obtain ⟨hk, hm⟩ := hmem
    calc k + m * q < q + m * q := by omega
      _ = (m + 1) * q := by ring
      _ ≤ (n + 1) * q := Nat.mul_le_mul_right q (by omega)
  · -- Injectivity
    intro ⟨k₁, m₁⟩ hk1 ⟨k₂, m₂⟩ hk2 heq
    simp only [Finset.mem_coe, Finset.mem_product, Finset.mem_range] at hk1 hk2
    obtain ⟨hk1a, _⟩ := hk1; obtain ⟨hk2a, _⟩ := hk2
    dsimp only at heq
    have hmod : (k₁ + m₁ * q) % q = (k₂ + m₂ * q) % q := by rw [heq]
    rw [Nat.add_mul_mod_self_right, Nat.add_mul_mod_self_right,
        Nat.mod_eq_of_lt hk1a, Nat.mod_eq_of_lt hk2a] at hmod
    subst hmod
    have hm : m₁ = m₂ := mul_right_cancel₀ (by omega : q ≠ 0) (by omega)
    subst hm; rfl
  · -- Surjectivity
    intro j hj
    simp only [Set.mem_image, Finset.coe_product, Finset.coe_range, Set.mem_prod, Set.mem_Iio]
    refine ⟨(j % q, j / q), ⟨Nat.mod_lt j (by omega),
      (Nat.div_lt_iff_lt_mul (by omega)).mpr (Finset.mem_range.mp hj)⟩, ?_⟩
    exact Nat.mod_add_div' j q
  · -- Function identity
    intro ⟨k, m⟩ _; congr 1; push_cast; ring

-- ── Combinatorial: double sum log decomposition ──

private lemma double_sum_log_decompose (q n : ℕ) (hq : 1 ≤ q) :
    ∑ k ∈ range q, ∑ m ∈ range (n+1), Real.log ((1 + ↑k) / (↑q : ℝ) + ↑m) =
    Real.log (((n+1)*q) !) - ↑q * (↑n + 1) * Real.log ↑q := by
  have hq_ne : (q : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have h_rw : ∀ k m : ℕ, Real.log ((1 + (k:ℝ)) / (q:ℝ) + (m:ℝ)) =
      Real.log (1 + ↑k + ↑m * ↑q) - Real.log ↑q := by
    intro k m
    have hnum : (0:ℝ) < 1 + ↑k + ↑m * ↑q := by positivity
    rw [show (1+(k:ℝ))/(q:ℝ)+(m:ℝ) = (1+↑k+↑m*↑q)/↑q from by field_simp]
    exact Real.log_div hnum.ne' hq_ne
  simp_rw [h_rw, Finset.sum_sub_distrib, Finset.sum_const, Finset.card_range, nsmul_eq_mul,
           double_sum_eq_factorial_log q n hq]
  push_cast; ring

-- ── The combinatorial identity for logGammaSeq ──

private lemma sum_logGammaSeq_eq (q : ℕ) (hq : 1 ≤ q) (n : ℕ) :
    ∑ k ∈ range q, logGammaSeq ((1 + ↑k) / ↑q) n =
    ((q + 1 : ℝ) / 2) * Real.log n + (q : ℝ) * Real.log (n !)
    - Real.log (((n + 1) * q) !) + (q : ℝ) * ((n : ℝ) + 1) * Real.log q := by
  simp only [logGammaSeq, Finset.sum_sub_distrib, Finset.sum_add_distrib]
  rw [← Finset.sum_mul, sum_arith_over_q q hq,
      Finset.sum_const, Finset.card_range, nsmul_eq_mul,
      double_sum_log_decompose q n hq]; ring

-- ── Stirling decomposition of logGammaSeq sum ──

set_option maxHeartbeats 400000 in
private lemma sum_logGammaSeq_decompose (q : ℕ) (hq : 1 ≤ q) (n : ℕ) (hn : 1 ≤ n) :
    ∑ k ∈ range q, logGammaSeq ((1 + ↑k) / ↑q) n =
    ((q : ℝ) * Real.log (stirlingSeq n) - Real.log (stirlingSeq ((n+1)*q)))
    + (((q : ℝ) - 1) / 2 * Real.log 2 - 1/2 * Real.log q)
    + (((q : ℝ) * (n : ℝ) + (q : ℝ) + 1/2) *
       (Real.log n - Real.log ((n : ℝ) + 1)) + (q : ℝ)) := by
  rw [sum_logGammaSeq_eq q hq n]
  have hn_pos : (0 : ℝ) < n := Nat.cast_pos.mpr (by omega)
  have hq_pos : (0 : ℝ) < q := Nat.cast_pos.mpr (by omega)
  have hn1_pos : (0 : ℝ) < (n : ℝ) + 1 := by positivity
  have hlog_nfac : Real.log (n !) = Real.log (stirlingSeq n) +
    1/2 * (Real.log 2 + Real.log n) + (n : ℝ) * (Real.log n - 1) := by
    have := log_stirlingSeq_formula n
    rw [Real.log_mul (by positivity : (2:ℝ) ≠ 0) hn_pos.ne',
        Real.log_div hn_pos.ne' (by positivity : rexp 1 ≠ 0), Real.log_exp] at this
    linarith
  have hlog_nqfac : Real.log (((n + 1) * q) !) = Real.log (stirlingSeq ((n+1)*q)) +
    1/2 * (Real.log 2 + Real.log ((n:ℝ)+1) + Real.log q) +
    ((n:ℝ)+1) * (q:ℝ) * (Real.log ((n:ℝ)+1) + Real.log q - 1) := by
    have := log_stirlingSeq_formula ((n+1)*q)
    have hc1 : (2 : ℝ) * ((↑((n+1)*q) : ℝ)) = 2 * ((n:ℝ)+1) * (q:ℝ) := by push_cast; ring
    have hc2 : ((↑((n+1)*q) : ℝ)) = ((n:ℝ)+1) * (q:ℝ) := by push_cast; ring
    rw [hc1, hc2,
        Real.log_mul (by positivity : 2*((n:ℝ)+1) ≠ 0) hq_pos.ne',
        Real.log_mul (by positivity : (2:ℝ) ≠ 0) hn1_pos.ne',
        Real.log_div (by positivity : ((n:ℝ)+1)*(q:ℝ) ≠ 0) (by positivity : rexp 1 ≠ 0),
        Real.log_mul hn1_pos.ne' hq_pos.ne', Real.log_exp] at this
    linarith
  rw [hlog_nfac, hlog_nqfac]; ring

-- ── Limit: sum of logGammaSeq → ∑ log Γ ──

private lemma tendsto_sum_logGammaSeq (q : ℕ) (hq : 1 ≤ q) :
    Tendsto (fun n => ∑ k ∈ range q, logGammaSeq ((1 + ↑k) / ↑q) n)
      atTop (nhds (∑ k ∈ range q, Real.log (Real.Gamma ((1 + ↑k) / ↑q)))) :=
  tendsto_finset_sum' _ fun k _ =>
    tendsto_log_gamma (div_pos (by positivity : (0:ℝ) < 1 + ↑k)
      (Nat.cast_pos.mpr (by omega)))

-- ── The key limit evaluation ──

/-- The sum of log Γ values at equally-spaced points. -/
theorem sum_log_gamma_eq_target (q : ℕ) (hq : 1 ≤ q) :
    ∑ k ∈ range q, Real.log (Real.Gamma ((1 + ↑k) / ↑q)) =
    ((q : ℝ) - 1) / 2 * Real.log (2 * Real.pi) - 1/2 * Real.log q := by
  have h_target : Tendsto (fun n : ℕ =>
    ((q : ℝ) * Real.log (stirlingSeq n) - Real.log (stirlingSeq ((n+1)*q)))
    + (((q : ℝ) - 1) / 2 * Real.log 2 - 1/2 * Real.log q)
    + (((q : ℝ) * (n : ℝ) + (q : ℝ) + 1/2) *
       (Real.log n - Real.log ((n : ℝ) + 1)) + (q : ℝ)))
    atTop (nhds (((q : ℝ) - 1) / 2 * Real.log (2 * Real.pi) - 1/2 * Real.log q)) := by
    have htarget_eq : ((q : ℝ) - 1) / 2 * Real.log (2 * Real.pi) - 1/2 * Real.log q =
        ((q - 1 : ℝ)/2 * Real.log Real.pi) +
        (((q : ℝ) - 1) / 2 * Real.log 2 - 1/2 * Real.log q) + 0 := by
      rw [Real.log_mul (by positivity : (2:ℝ) ≠ 0) pi_pos.ne']; ring
    rw [htarget_eq]
    exact ((tendsto_stirling_correction q hq).add tendsto_const_nhds).add
      (tendsto_weighted_log_ratio q)
  have h_eq : ∀ᶠ n : ℕ in atTop,
    ∑ k ∈ range q, logGammaSeq ((1 + ↑k) / ↑q) n =
    ((q : ℝ) * Real.log (stirlingSeq n) - Real.log (stirlingSeq ((n+1)*q)))
    + (((q : ℝ) - 1) / 2 * Real.log 2 - 1/2 * Real.log q)
    + (((q : ℝ) * (n : ℝ) + (q : ℝ) + 1/2) *
       (Real.log n - Real.log ((n : ℝ) + 1)) + (q : ℝ)) :=
    Filter.eventually_atTop.mpr ⟨1, fun n hn => sum_logGammaSeq_decompose q hq n hn⟩
  exact tendsto_nhds_unique (tendsto_sum_logGammaSeq q hq)
    (h_target.congr' (Filter.EventuallyEq.symm h_eq))

end Cathedral.Analysis.GammaProductEval
