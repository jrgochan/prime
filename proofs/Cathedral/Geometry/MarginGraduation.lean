/-
  Cathedral/Geometry/MarginGraduation.lean

  GRADUATION OF euler_mascheroni_rate: (1 - bv) lnN -> gamma + 1

  This file proves the key building blocks for graduating the
  euler_mascheroni_rate axiom from the existing PNT infrastructure.

  Created: June 7, 2026
-/

import Cathedral.PNT.AbelMean
import Cathedral.Geometry.EulerMascheroniRate
import Mathlib.Analysis.SpecialFunctions.Pow.Asymptotics

noncomputable section
open Real Finset Filter

namespace Cathedral.Geometry.MarginGraduation

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

end Cathedral.Geometry.MarginGraduation

end
