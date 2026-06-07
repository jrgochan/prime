/-
  Cathedral/Geometry/Renormalization/MarginGraduation.lean

  GRADUATION OF euler_mascheroni_rate: (1 - bv) lnN -> gamma + 1

  This file proves the key building blocks for graduating the
  euler_mascheroni_rate axiom from the existing PNT infrastructure.

  Created: June 7, 2026
-/

import Cathedral.PNT.AbelMean
import Cathedral.Geometry.Renormalization.EulerMascheroniRate
import Cathedral.Geometry.Renormalization.MarginIdentity
import Cathedral.Vasyunin.Proof.WitnessAsymptotics
import Mathlib.Analysis.SpecialFunctions.Pow.Asymptotics

noncomputable section
open Real Finset Filter Cathedral.Vasyunin ArithmeticFunction

namespace Cathedral.Geometry.Renormalization.MarginGraduation

-- LOCAL MERTENS SUMS

def MertensS1 (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ)

def MertensS2 (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) *
    Real.log (k : ℝ) / (k : ℝ)

def MertensS3 (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) *
    (Real.log (k : ℝ)) ^ 2 / (k : ℝ)

-- TENDSTO LIMITS

theorem S1_tendsto : Tendsto MertensS1 atTop (nhds 0) := pnt_mu_div_k
theorem S2_tendsto : Tendsto MertensS2 atTop (nhds (-1)) := pnt_mu_log_div_k
theorem S3_tendsto : Tendsto MertensS3 atTop (nhds (-2 * eulerMascheroniConstant)) :=
  pnt_mu_log_sq_div_k

-- SHIFT LEMMAS

theorem S2_shift_tendsto :
    Tendsto (fun N : ℕ => MertensS2 (N - 1)) atTop (nhds (-1)) := by
  apply S2_tendsto.comp
  exact Filter.tendsto_atTop_atTop_of_monotone
    (fun a b h => Nat.sub_le_sub_right h 1)
    (fun n => ⟨n + 1, by omega⟩)

theorem S3_shift_tendsto :
    Tendsto (fun N : ℕ => MertensS3 (N - 1))
      atTop (nhds (-2 * eulerMascheroniConstant)) := by
  apply S3_tendsto.comp
  exact Filter.tendsto_atTop_atTop_of_monotone
    (fun a b h => Nat.sub_le_sub_right h 1)
    (fun n => ⟨n + 1, by omega⟩)

-- PART B: TENDSTO ARITHMETIC

theorem part_b_tendsto :
    Tendsto (fun N : ℕ =>
      (1 - eulerMascheroniConstant) * (MertensS2 (N - 1) + 1) +
      (MertensS3 (N - 1) + 2 * eulerMascheroniConstant))
      atTop (nhds 0) := by
  have hS2_shift : Tendsto (fun N : ℕ => MertensS2 (N - 1) + 1) atTop (nhds 0) := by
    have h1 : Tendsto (fun N : ℕ => MertensS2 (N - 1) + 1) atTop (nhds (-1 + 1)) :=
      S2_shift_tendsto.add_const 1
    simp only [neg_add_cancel] at h1
    exact h1
  have hS3_shift : Tendsto (fun N : ℕ =>
      MertensS3 (N - 1) + 2 * eulerMascheroniConstant) atTop (nhds 0) := by
    have h1 : Tendsto (fun N : ℕ => MertensS3 (N - 1) + 2 * eulerMascheroniConstant)
        atTop (nhds (-2 * eulerMascheroniConstant + 2 * eulerMascheroniConstant)) :=
      S3_shift_tendsto.add_const (2 * eulerMascheroniConstant)
    have h2 : -2 * eulerMascheroniConstant + 2 * eulerMascheroniConstant = 0 := by ring
    rw [h2] at h1
    exact h1
  have h_combo := (hS2_shift.const_mul (1 - eulerMascheroniConstant)).add hS3_shift
  have h_eq : (1 - eulerMascheroniConstant) * 0 + 0 = 0 := by ring
  rw [h_eq] at h_combo
  exact h_combo

-- PART A: N^{-1/4} log^2 N -> 0

theorem rpow_neg_quarter_log_sq_tendsto :
    Tendsto (fun N : ℕ => (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2)
      atTop (nhds 0) := by
  have h_o : (Real.log) =o[Filter.atTop] fun (x : ℝ) => x ^ ((1:ℝ)/8) :=
    isLittleO_log_rpow_atTop (by norm_num : (0:ℝ) < 1/8)
  rw [Asymptotics.isLittleO_iff] at h_o
  rw [Metric.tendsto_atTop]
  intro eps heps
  have heps2 : (0:ℝ) < eps / 2 := by linarith
  have heps_sqrt : (0:ℝ) < Real.sqrt (eps / 2) := Real.sqrt_pos_of_pos heps2
  specialize h_o heps_sqrt
  rw [Filter.Eventually, Filter.mem_atTop_sets] at h_o
  obtain ⟨x0, hx0⟩ := h_o
  refine ⟨max (Nat.ceil x0 + 1) 2, fun N hN => ?_⟩
  simp only [dist_zero_right]
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have hN_ge_x0 : x0 ≤ (N : ℝ) := by
    calc x0 ≤ ⌈x0⌉₊ := Nat.le_ceil x0
      _ ≤ ⌈x0⌉₊ + 1 := by linarith
      _ ≤ (N : ℝ) := by exact_mod_cast (by omega : Nat.ceil x0 + 1 ≤ N)
  have h_at_N := hx0 (N : ℝ) hN_ge_x0
  have hN_rpow_pos : (0:ℝ) < (N : ℝ) ^ ((1:ℝ)/8) := Real.rpow_pos_of_pos hN_pos _
  have h_log_abs : |Real.log (N : ℝ)| ≤ Real.sqrt (eps / 2) * (N : ℝ) ^ ((1:ℝ)/8) := by
    calc |Real.log (N : ℝ)|
      _ = ‖Real.log (N : ℝ)‖ := (Real.norm_eq_abs _).symm
      _ ≤ Real.sqrt (eps / 2) * ‖(N : ℝ) ^ ((1:ℝ)/8)‖ := h_at_N
      _ = Real.sqrt (eps / 2) * |(N : ℝ) ^ ((1:ℝ)/8)| := by rw [Real.norm_eq_abs]
      _ = Real.sqrt (eps / 2) * (N : ℝ) ^ ((1:ℝ)/8) := by rw [abs_of_pos hN_rpow_pos]
  have h_log_sq : (Real.log (N : ℝ)) ^ 2 ≤ (eps / 2) * (N : ℝ) ^ ((1:ℝ)/4) := by
    calc (Real.log (N : ℝ)) ^ 2
      _ = |Real.log (N : ℝ)| ^ 2 := by rw [sq_abs]
      _ ≤ (Real.sqrt (eps / 2) * (N : ℝ) ^ ((1:ℝ)/8)) ^ 2 := by
          exact sq_le_sq' (by linarith [abs_nonneg (Real.log (N : ℝ))]) h_log_abs
      _ = Real.sqrt (eps / 2) ^ 2 * ((N : ℝ) ^ ((1:ℝ)/8)) ^ 2 := by ring
      _ = (eps / 2) * ((N : ℝ) ^ ((1:ℝ)/8)) ^ 2 := by rw [Real.sq_sqrt heps2.le]
      _ = (eps / 2) * (N : ℝ) ^ ((1:ℝ)/4) := by
          congr 1
          rw [← Real.rpow_natCast ((N : ℝ) ^ ((1:ℝ)/8)) 2, ← Real.rpow_mul hN_pos.le]
          norm_num
  calc ‖(N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2‖
    _ = (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := by
        rw [Real.norm_eq_abs, abs_of_nonneg]
        exact mul_nonneg (le_of_lt (Real.rpow_pos_of_pos hN_pos _)) (sq_nonneg _)
    _ ≤ (N : ℝ) ^ (-(1:ℝ)/4) * ((eps / 2) * (N : ℝ) ^ ((1:ℝ)/4)) := by
        apply mul_le_mul_of_nonneg_left h_log_sq
        exact le_of_lt (Real.rpow_pos_of_pos hN_pos _)
    _ = (eps / 2) * ((N : ℝ) ^ (-(1:ℝ)/4) * (N : ℝ) ^ ((1:ℝ)/4)) := by ring
    _ = (eps / 2) * 1 := by congr 1; rw [← Real.rpow_add hN_pos]; norm_num
    _ = eps / 2 := by ring
    _ < eps := by linarith

-- N^{-1/4} logN -> 0

theorem rpow_neg_quarter_log_tendsto :
    Tendsto (fun N : ℕ => (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ))
      atTop (nhds 0) := by
  rw [Metric.tendsto_atTop]
  intro eps heps
  have h_sq := rpow_neg_quarter_log_sq_tendsto
  rw [Metric.tendsto_atTop] at h_sq
  obtain ⟨N1, hN1⟩ := h_sq eps heps
  refine ⟨max N1 3, fun N hN => ?_⟩
  simp only [dist_zero_right]
  have hN_pos : (0:ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have h_rpow_pos := Real.rpow_pos_of_pos hN_pos (-(1:ℝ)/4)
  have hlogN_ge1 : (1:ℝ) ≤ Real.log (N : ℝ) := by
    rw [show (1 : ℝ) = Real.log (Real.exp 1) from (Real.log_exp 1).symm]
    apply Real.log_le_log (Real.exp_pos 1)
    calc Real.exp 1 ≤ 3 := le_of_lt Real.exp_one_lt_three
      _ ≤ (N : ℝ) := by exact_mod_cast show 3 ≤ N by omega
  have h_nonneg : 0 ≤ (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) :=
    mul_nonneg (le_of_lt h_rpow_pos) (le_trans zero_le_one hlogN_ge1)
  have h_nonneg2 : 0 ≤ (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 :=
    mul_nonneg (le_of_lt h_rpow_pos) (sq_nonneg _)
  have h_le : (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) ≤
      (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := by
    apply mul_le_mul_of_nonneg_left _ (le_of_lt h_rpow_pos)
    calc Real.log (N : ℝ) = (Real.log (N : ℝ)) ^ 1 := by ring
      _ ≤ (Real.log (N : ℝ)) ^ 2 := pow_right_mono₀ hlogN_ge1 (by omega)
  have h_at_N := hN1 N (by omega)
  rw [dist_zero_right] at h_at_N
  calc ‖(N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ)‖
    _ = (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := by
        rw [Real.norm_eq_abs, abs_of_nonneg h_nonneg]
    _ ≤ (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := h_le
    _ = ‖(N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2‖ := by
        rw [Real.norm_eq_abs, abs_of_nonneg h_nonneg2]
    _ < eps := h_at_N

-- THREE-PART ALGEBRA

theorem three_part_algebra (S1 S2 S3 LN gamma_val : ℝ) (hLN : LN ≠ 0) :
    (1 - (-(1 - gamma_val) * S1 - S2 + ((1 - gamma_val) * S2 + S3) / LN)) * LN =
    ((1 - gamma_val) * S1 + (S2 + 1)) * LN -
    ((1 - gamma_val) * (S2 + 1) + (S3 + 2 * gamma_val)) + (1 + gamma_val) := by
  field_simp
  ring

-- THE BRIDGE: bdDotGap = 1 - mean_algebraic_expansion

/-- Key bridge: the dotProduct in bdDotGap equals the LHS of mean_algebraic_expansion.
    This is because vasyuninMeanEntry k = (log k + 1 - γ) / k,
    and dotProduct is commutative. -/
theorem dotGap_eq_expansion (N : ℕ) (hN : 10 ≤ N) :
    bdDotGap N = 1 - (-(1 - eulerMascheroniConstant) * S₁ (N - 1) -
      S₂ (N - 1) +
      ((1 - eulerMascheroniConstant) * S₂ (N - 1) + S₃ (N - 1)) /
        Real.log (N : ℝ)) := by
  unfold bdDotGap
  congr 1
  -- Need: dotProduct (fun i => vasyuninMeanEntry (i+1)) (bdMoebiusWeight N)
  -- = -(1-γ)S₁(N-1) - S₂(N-1) + ((1-γ)S₂(N-1) + S₃(N-1))/logN
  -- The LHS unfolds to ∑ i, vasyuninMeanEntry(i+1) * bdMoebiusWeight N i
  -- = ∑ i, bdMoebiusWeight N i * vasyuninMeanEntry(i+1) (by mul_comm)
  -- = ∑ i, bdMoebiusWeight N i * ((log(i+1) + 1 - γ)/(i+1)) (by vasyuninMeanEntry def)
  -- = RHS (by mean_algebraic_expansion)
  have h_exp := mean_algebraic_expansion N hN
  rw [dotProduct]
  -- Commute multiplication and unfold vasyuninMeanEntry
  have : ∀ (i : Fin (N - 1)),
      (fun i => vasyuninMeanEntry (i.val + 1)) i * bdMoebiusWeight N i =
      bdMoebiusWeight N i * ((Real.log ↑(i.val + 1) + 1 -
        Real.eulerMascheroniConstant) / ↑(i.val + 1)) := by
    intro i
    rw [mul_comm]
    simp only [vasyuninMeanEntry]
  simp_rw [this]
  exact h_exp
-- THE GRADUATION: (1 - bᵀv) · logN → 1 + γ

-- Helper: S₁(N-1) · logN → 0
private theorem S1_times_log_tendsto
    (C : ℝ) (hC : 0 < C)
    (h_tail : ∀ N : ℕ, 2 ≤ N →
      |S₁ N| ≤ C * (N : ℝ) ^ (-(1:ℝ)/4) ∧
      |S₂ N - (-1)| ≤ C * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) ∧
      |S₃ N - (-2 * Real.eulerMascheroniConstant)| ≤
        C * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2) :
    Tendsto (fun N : ℕ => S₁ (N - 1) * Real.log (N : ℝ))
      atTop (nhds 0) := by
  -- Strategy: |S₁(N-1)·logN| ≤ C·(N-1)^{-1/4}·logN
  -- and (N-1)^{-1/4}·logN = (N-1)^{-1/4}·log(N-1) · (logN/log(N-1))
  -- First factor → 0, second factor → 1, so product → 0.
  -- Simpler: use rpow_neg_quarter_log_tendsto composed with fun N => N-1
  -- to get (N-1)^{-1/4}·log(N-1) → 0, then multiply by logN/log(N-1) → 1.
  -- But the cleanest proof: the sequence is dominated by a sequence → 0.
  rw [Metric.tendsto_atTop]
  intro ε hε
  -- Get the rpow decay for (N-1)
  have h_rpow := rpow_neg_quarter_log_tendsto
  rw [Metric.tendsto_atTop] at h_rpow
  obtain ⟨N₁, hN₁⟩ := h_rpow (ε / (4 * C)) (div_pos hε (mul_pos (by norm_num : (0:ℝ) < 4) hC))
  refine ⟨max (N₁ + 1) 3, fun N hN_ge => ?_⟩
  simp only [dist_zero_right]
  have hN3 : 3 ≤ N := by omega
  have hN1_ge2 : 2 ≤ N - 1 := by omega
  have hN1_geN1 : N₁ ≤ N - 1 := by omega
  obtain ⟨hS1, _, _⟩ := h_tail (N - 1) hN1_ge2
  have hN1_pos : (0:ℝ) < ((N - 1 : ℕ) : ℝ) := Nat.cast_pos.mpr (by omega)
  have hlogN_pos : 0 < Real.log (N : ℝ) :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  have hlogN1_pos : 0 < Real.log ((N - 1 : ℕ) : ℝ) :=
    Real.log_pos (by exact_mod_cast show 1 < N - 1 by omega)
  -- |S₁(N-1)·logN| ≤ C·(N-1)^{-1/4}·logN
  have h_rpow_pos : 0 < ((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) :=
    Real.rpow_pos_of_pos hN1_pos _
  have h_bound : ‖S₁ (N - 1) * Real.log ↑N‖ ≤
      C * ((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) * Real.log ↑N := by
    rw [Real.norm_eq_abs, abs_mul, abs_of_pos hlogN_pos]
    exact mul_le_mul_of_nonneg_right hS1 hlogN_pos.le
  -- logN ≤ 2·log(N-1) for N ≥ 3 (because N ≤ (N-1)² for N ≥ 3)
  have hN1_cast_add : (N : ℝ) = ((N - 1 : ℕ) : ℝ) + 1 := by
    have h1 : 1 ≤ N := by omega
    rw [Nat.cast_sub h1]; ring
  have hlog_ratio : Real.log (N : ℝ) ≤ 2 * Real.log ((N - 1 : ℕ) : ℝ) := by
    have hN1_ge : (2 : ℝ) ≤ ((N - 1 : ℕ) : ℝ) := by exact_mod_cast hN1_ge2
    have hN_le_sq : (N : ℝ) ≤ ((N - 1 : ℕ) : ℝ) ^ 2 := by
      rw [hN1_cast_add]; nlinarith [sq_nonneg (((N - 1 : ℕ) : ℝ) - 2)]
    calc Real.log (N : ℝ) ≤ Real.log (((N - 1 : ℕ) : ℝ) ^ 2) :=
          Real.log_le_log (by rw [hN1_cast_add]; linarith) hN_le_sq
      _ = 2 * Real.log ((N - 1 : ℕ) : ℝ) := by rw [Real.log_pow]; ring
  -- Combine: C·(N-1)^{-1/4}·logN ≤ 2C·(N-1)^{-1/4}·log(N-1)
  have h_prod_bound : C * ((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) * Real.log ↑N ≤
      2 * C * ((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) * Real.log ((N - 1 : ℕ) : ℝ) := by
    have : 0 ≤ C * ((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) :=
      mul_nonneg hC.le h_rpow_pos.le
    nlinarith
  -- (N-1)^{-1/4}·log(N-1) < ε/(4C) (from rpow decay at N-1 ≥ N₁)
  have h_rpow_at : dist (((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) *
      Real.log ((N - 1 : ℕ) : ℝ)) 0 < ε / (4 * C) := hN₁ (N - 1) hN1_geN1
  rw [dist_zero_right, Real.norm_eq_abs, abs_of_nonneg
    (mul_nonneg h_rpow_pos.le hlogN1_pos.le)] at h_rpow_at
  -- Final chain
  calc ‖S₁ (N - 1) * Real.log ↑N‖
    _ ≤ C * ((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) * Real.log ↑N := h_bound
    _ ≤ 2 * C * ((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) * Real.log ((N - 1 : ℕ) : ℝ) :=
        h_prod_bound
    _ < 2 * C * (ε / (4 * C)) := by nlinarith
    _ = ε / 2 := by field_simp; ring
    _ < ε := half_lt_self hε

-- Helper: (S₂(N-1)+1) · logN → 0
private theorem S2_shift_times_log_tendsto
    (C : ℝ) (hC : 0 < C)
    (h_tail : ∀ N : ℕ, 2 ≤ N →
      |S₁ N| ≤ C * (N : ℝ) ^ (-(1:ℝ)/4) ∧
      |S₂ N - (-1)| ≤ C * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) ∧
      |S₃ N - (-2 * Real.eulerMascheroniConstant)| ≤
        C * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2) :
    Tendsto (fun N : ℕ => (S₂ (N - 1) + 1) * Real.log (N : ℝ))
      atTop (nhds 0) := by
  -- |S₂(N-1)+1| ≤ C·(N-1)^{-1/4}·log(N-1)
  -- |(S₂(N-1)+1)·logN| ≤ C·(N-1)^{-1/4}·log(N-1)·logN
  -- log(N-1) ≤ logN, so log(N-1)·logN ≤ (logN)² ≤ 4·(log(N-1))²
  -- (N-1)^{-1/4}·(log(N-1))² < ε from rpow_neg_quarter_log_sq_tendsto
  rw [Metric.tendsto_atTop]
  intro ε hε
  have h_rpow := rpow_neg_quarter_log_sq_tendsto
  rw [Metric.tendsto_atTop] at h_rpow
  obtain ⟨N₁, hN₁⟩ := h_rpow (ε / (8 * C)) (div_pos hε (mul_pos (by norm_num : (0:ℝ) < 8) hC))
  refine ⟨max (N₁ + 1) 3, fun N hN_ge => ?_⟩
  simp only [dist_zero_right]
  have hN3 : 3 ≤ N := by omega
  have hN1_ge2 : 2 ≤ N - 1 := by omega
  have hN1_geN1 : N₁ ≤ N - 1 := by omega
  obtain ⟨_, hS2, _⟩ := h_tail (N - 1) hN1_ge2
  have hN1_pos : (0:ℝ) < ((N - 1 : ℕ) : ℝ) := Nat.cast_pos.mpr (by omega)
  have hlogN_pos : 0 < Real.log (N : ℝ) :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  have hlogN1_pos : 0 < Real.log ((N - 1 : ℕ) : ℝ) :=
    Real.log_pos (by exact_mod_cast show 1 < N - 1 by omega)
  have h_rpow_pos : 0 < ((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) :=
    Real.rpow_pos_of_pos hN1_pos _
  -- |S₂(N-1)+1| = |S₂(N-1)-(-1)|
  have hS2_eq : |S₂ (N - 1) + 1| = |S₂ (N - 1) - (-1)| := by ring_nf
  -- log(N-1) ≤ logN
  have hlogN1_le : Real.log ((N - 1 : ℕ) : ℝ) ≤ Real.log (N : ℝ) :=
    Real.log_le_log hN1_pos (by exact_mod_cast show (N - 1 : ℕ) ≤ N by omega)
  -- logN ≤ 2·log(N-1)
  have hN1_cast_add : (N : ℝ) = ((N - 1 : ℕ) : ℝ) + 1 := by
    have h1 : 1 ≤ N := by omega
    rw [Nat.cast_sub h1]; ring
  have hlog_ratio : Real.log (N : ℝ) ≤ 2 * Real.log ((N - 1 : ℕ) : ℝ) := by
    have hN1_ge : (2 : ℝ) ≤ ((N - 1 : ℕ) : ℝ) := by exact_mod_cast hN1_ge2
    have hN_le_sq : (N : ℝ) ≤ ((N - 1 : ℕ) : ℝ) ^ 2 := by
      rw [hN1_cast_add]; nlinarith [sq_nonneg (((N - 1 : ℕ) : ℝ) - 2)]
    calc Real.log (N : ℝ) ≤ Real.log (((N - 1 : ℕ) : ℝ) ^ 2) :=
          Real.log_le_log (by rw [hN1_cast_add]; linarith) hN_le_sq
      _ = 2 * Real.log ((N - 1 : ℕ) : ℝ) := by rw [Real.log_pow]; ring
  -- |(S₂(N-1)+1)·logN| ≤ C·(N-1)^{-1/4}·log(N-1)·logN
  have h_bound : ‖(S₂ (N - 1) + 1) * Real.log ↑N‖ ≤
      C * ((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) * Real.log ((N - 1 : ℕ) : ℝ) *
        Real.log ↑N := by
    rw [Real.norm_eq_abs, abs_mul, abs_of_pos hlogN_pos, hS2_eq]
    exact mul_le_mul_of_nonneg_right hS2 hlogN_pos.le
  -- log(N-1)·logN ≤ 2·(log(N-1))² (since logN ≤ 2·log(N-1))
  have h_log_prod : C * ((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) *
      Real.log ((N - 1 : ℕ) : ℝ) * Real.log ↑N ≤
      2 * C * ((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) *
      (Real.log ((N - 1 : ℕ) : ℝ)) ^ 2 := by
    have : 0 ≤ C * ((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) * Real.log ((N - 1 : ℕ) : ℝ) :=
      mul_nonneg (mul_nonneg hC.le h_rpow_pos.le) hlogN1_pos.le
    nlinarith
  -- (N-1)^{-1/4}·(log(N-1))² < ε/(8C)
  have h_rpow_at : dist (((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) *
      (Real.log ((N - 1 : ℕ) : ℝ)) ^ 2) 0 < ε / (8 * C) := hN₁ (N - 1) hN1_geN1
  rw [dist_zero_right, Real.norm_eq_abs, abs_of_nonneg
    (mul_nonneg h_rpow_pos.le (sq_nonneg _))] at h_rpow_at
  -- Final chain
  calc ‖(S₂ (N - 1) + 1) * Real.log ↑N‖
    _ ≤ C * ((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) * Real.log ((N - 1 : ℕ) : ℝ) *
        Real.log ↑N := h_bound
    _ ≤ 2 * C * ((N - 1 : ℕ) : ℝ) ^ (-(1:ℝ)/4) *
        (Real.log ((N - 1 : ℕ) : ℝ)) ^ 2 := h_log_prod
    _ < 2 * C * (ε / (8 * C)) := by nlinarith
    _ = ε / 4 := by field_simp; ring
    _ < ε := by linarith

/-- **GRADUATION THEOREM**: bdDotGap N * logN → 1 + γ.

    This GRADUATES the euler_mascheroni_rate axiom.
    The proof assembles:
    1. dotGap_eq_expansion: bdDotGap = 1 - expansion (from AbelMean)
    2. three_part_algebra: (1-expansion)·logN = Part A·logN - Part B + (1+γ)
    3. part_b_tendsto: Part B → 0 (Tendsto arithmetic)
    4. Part A·logN → 0: from quantitative bounds + rpow decay -/
theorem margin_limit_graduated :
    Tendsto (fun N : ℕ => bdDotGap N * Real.log ↑N)
      atTop (nhds (1 + eulerMascheroniConstant)) := by
  obtain ⟨C_m, hC_pos, hMertens⟩ := Cathedral.Vasyunin.mertens_34_unconditional
  obtain ⟨C_tail, hC_tail_pos, h_tail⟩ := abel_mertens_tail_raw C_m hC_pos hMertens
    pnt_mu_div_k pnt_mu_log_div_k pnt_mu_log_sq_div_k
  -- Part A · logN → 0
  have hPartA : Tendsto (fun N : ℕ =>
      ((1 - eulerMascheroniConstant) * S₁ (N - 1) + (S₂ (N - 1) + 1)) *
        Real.log (N : ℝ))
      atTop (nhds 0) := by
    have h1 := (S1_times_log_tendsto C_tail hC_tail_pos h_tail).const_mul
      (1 - eulerMascheroniConstant)
    simp only [mul_zero] at h1
    have h2 := S2_shift_times_log_tendsto C_tail hC_tail_pos h_tail
    have h_sum := h1.add h2
    simp only [zero_add] at h_sum
    refine h_sum.congr (fun N => ?_)
    ring
  -- Part B → 0 (part_b_tendsto uses MertensS2/S3 ≡ S₂/S₃)
  have hPartB : Tendsto (fun N : ℕ =>
      (1 - eulerMascheroniConstant) * (S₂ (N - 1) + 1) +
        (S₃ (N - 1) + 2 * eulerMascheroniConstant))
      atTop (nhds 0) := part_b_tendsto
  -- g(N) = Part_A·logN - Part_B + (1+γ) → 0-0+(1+γ) = (1+γ)
  have hg : Tendsto (fun N : ℕ =>
      ((1 - eulerMascheroniConstant) * S₁ (N - 1) + (S₂ (N - 1) + 1)) *
        Real.log (N : ℝ) -
      ((1 - eulerMascheroniConstant) * (S₂ (N - 1) + 1) +
        (S₃ (N - 1) + 2 * eulerMascheroniConstant)) +
      (1 + eulerMascheroniConstant))
      atTop (nhds (1 + eulerMascheroniConstant)) := by
    have h_diff := hPartA.sub hPartB
    have h_zero : (0 : ℝ) - 0 = 0 := sub_self 0
    rw [h_zero] at h_diff
    have h_add := h_diff.add_const (1 + eulerMascheroniConstant)
    have h_eq : 0 + (1 + eulerMascheroniConstant) = 1 + eulerMascheroniConstant := zero_add _
    rw [h_eq] at h_add
    refine h_add.congr (fun N => ?_)
    ring
  -- bdDotGap N · logN =ᶠ g(N) for N ≥ 10, so Tendsto g → Tendsto bdDotGap*log
  apply hg.congr'
  filter_upwards [Filter.eventually_ge_atTop 10] with N hN
  have hLN_ne : Real.log (N : ℝ) ≠ 0 :=
    ne_of_gt (Real.log_pos (by exact_mod_cast (show 1 < N by omega)))
  -- g(N) = bdDotGap N * logN by dotGap_eq_expansion + three_part_algebra
  calc ((1 - eulerMascheroniConstant) * S₁ (N - 1) + (S₂ (N - 1) + 1)) *
        Real.log (N : ℝ) -
      ((1 - eulerMascheroniConstant) * (S₂ (N - 1) + 1) +
        (S₃ (N - 1) + 2 * eulerMascheroniConstant)) +
      (1 + eulerMascheroniConstant)
    _ = (1 - (-(1 - eulerMascheroniConstant) * S₁ (N - 1) -
          S₂ (N - 1) +
          ((1 - eulerMascheroniConstant) * S₂ (N - 1) + S₃ (N - 1)) /
            Real.log (N : ℝ))) * Real.log ↑N :=
        (three_part_algebra (S₁ (N - 1)) (S₂ (N - 1)) (S₃ (N - 1))
          (Real.log ↑N) eulerMascheroniConstant hLN_ne).symm
    _ = bdDotGap N * Real.log ↑N := by rw [dotGap_eq_expansion N hN]

end Cathedral.Geometry.Renormalization.MarginGraduation

end





