/-
  Cathedral/PNT/AbelMean.lean

  ## PNT Axioms, Abel Tail Bounds, and the Mean Bound

  [MIXED — pnt_mu_log_div_k is ON crown path (Axiom 1);
   pnt_mu_log_sq_div_k is OFF crown path (eliminated v9, Abel Bypass)]

  Contains:
  - PNT theorems (pnt_mu_div_k 🎓, pnt_mu_log_div_k 🎓) and axiom (pnt_mu_log_sq_div_k)
  - Abel tail analysis (rpow_quarter_log_bounded/cube_bounded)
  - The graduated abel_mertens_tail_raw theorem 🎓
  - PNT sub-sum tail domination
  - The moebius_mean_finite_bound theorem
  - The linear_mean_bound theorem

  This is the "alternative chain" for the crown, used by
  MillenniumWall.lean. The crown itself uses the Direct BD Path
  (DirectL2Crown.lean), which bypasses all of this.

  Extracted from FinalDragon.lean §1b–§2b (April 22, 2026).
-/

import Cathedral.Defs
import Cathedral.NymanBeurling.BDMellin
-- Cathedral.PNT.Bridge: re-enabled via local PNTAnd clone (v4.29 patched)
import Cathedral.PNT.Bridge
import Cathedral.PNT.LogBridge
import Cathedral.AbelTail.L2Bridge
import Cathedral.NymanBeurling.BDBridge
import Cathedral.AbelTail.Engine
import Cathedral.MellinBridge.BDWeights
import Cathedral.MellinBridge.MertensIntegral
import Cathedral.MellinBridge.MertensBound
import Cathedral.Vasyunin.Augmented.MeanIntegral
import Cathedral.Vasyunin.Proof.LambdaTrick
import Cathedral.AbelTail.S1Decay
import Cathedral.AbelTail.S2Decay
import Cathedral.AbelTail.S3Decay
import Mathlib.NumberTheory.ArithmeticFunction.Moebius

noncomputable section
open Real Matrix Finset MeasureTheory Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- §1b. PNT AXIOMS (19th Century — Unconditional)
-- ════════════════════════════════════════════════

/-- **PNT THEOREM 1** (GRADUATED 🎓 — was axiom):
    The Möbius partial sums Σ μ(k)/k converge to 0.
    Equivalent to the Prime Number Theorem.
    Proof: From PrimeNumberTheoremAnd.mu_pnt_alt via Cathedral.PNT.Bridge. -/
theorem pnt_mu_div_k :
  Filter.Tendsto (fun N =>
    ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ))
    Filter.atTop (nhds 0) :=
  pnt_moebius_sum_div_tendsto

/-- **PNT THEOREM 2** (GRADUATED 🎓 — was axiom):
    The weighted sum Σ μ(k)·ln(k)/k converges to -1.
    From the derivative: -(1/ζ(s))' = ζ'(s)/ζ(s)² At s=1: ζ'(s)/ζ(s)² → 1.
    So -Σ μ(k)·ln(k)/k^s|_{s=1} = 1, giving the limit -1.
    Proof: From PrimeNumberTheoremAnd via Cathedral.PNT.LogBridge.
    Uses: μ·log * ζ = -Λ identity + ψ(x)/x → 1 + Abel summation. -/
-- GRADUATED: May 12, 2026 (Exploration 36) — was AXIOM CLASS: CLASSICAL-PNT
theorem pnt_mu_log_div_k :
  Filter.Tendsto (fun N =>
    ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
      Real.log (k : ℝ) / (k : ℝ))
    Filter.atTop (nhds (-1)) :=
  pnt_mu_log_div_k_proved

/-- **PNT AXIOM 3** (the last PNT axiom): The weighted sum Σ μ(k)·ln²(k)/k converges to -2γ.
    From the second derivative of 1/ζ(s) at s=1.
    Uses the Laurent expansion of ζ(s) near s=1.
    NOTE: This axiom is OFF CROWN PATH (eliminated in v9 via Abel Bypass). -/
-- AXIOM CLASS: CLASSICAL-PNT (last 1 of original 3) — will close when PNTAnd formalizes
axiom pnt_mu_log_sq_div_k :
  Filter.Tendsto (fun N =>
    ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
      (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
    Filter.atTop (nhds (-2 * Real.eulerMascheroniConstant))

-- ════════════════════════════════════════════════
-- §2. MERTENS → L² BOUND: The Abel-Parseval Bridge
-- ════════════════════════════════════════════════

-- ════════════════════════════════════════════════
-- §2a. PNT SUB-SUMS & TAIL BOUNDS
-- ════════════════════════════════════════════════

-- Define the PNT sub-sums for the algebraic expansion
private def S₁ (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ)

private def S₂ (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) *
    Real.log (k : ℝ) / (k : ℝ)

private def S₃ (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) *
    (Real.log (k : ℝ)) ^ 2 / (k : ℝ)

/-- **PROVED**: x^{-1/4}·log(x) ≤ 4 for all N ≥ 1.

    Standard calculus: log grows slower than any power.
    Max at x = e⁴ ≈ 54.6, value = 4/e ≈ 1.47. B = 4 suffices. -/
private lemma rpow_quarter_log_bounded :
    ∃ B : ℝ, B > 0 ∧ ∀ N : ℕ, 1 ≤ N →
    (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ≤ B := by
  refine ⟨4, by norm_num, fun N hN => ?_⟩
  have hN_pos : (0 : ℝ) < (N : ℝ) := by exact_mod_cast show 0 < N by omega
  have hN_ge1 : (1 : ℝ) ≤ (N : ℝ) := by exact_mod_cast show 1 ≤ N by omega
  set t := (N : ℝ) ^ ((1:ℝ)/4) with ht_def
  have ht_pos : 0 < t := Real.rpow_pos_of_pos hN_pos _
  have ht_ge1 : 1 ≤ t := by
    rw [ht_def, ← Real.rpow_zero (N : ℝ)]
    exact Real.rpow_le_rpow_of_exponent_le hN_ge1 (by norm_num)
  have h_log_le : Real.log t ≤ t := by
    linarith [Real.add_one_le_exp (Real.log t), Real.exp_log (lt_of_lt_of_le one_pos ht_ge1)]
  have h_log_eq : Real.log (N : ℝ) = 4 * Real.log t := by
    rw [ht_def, Real.log_rpow hN_pos]; ring
  have h_log_bound : Real.log (N : ℝ) ≤ 4 * t := by linarith
  have h_cancel : (N : ℝ) ^ (-(1:ℝ)/4) * t = 1 := by
    rw [ht_def, ← Real.rpow_add hN_pos]; norm_num
  calc (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ)
    _ ≤ (N : ℝ) ^ (-(1:ℝ)/4) * (4 * t) := by
        apply mul_le_mul_of_nonneg_left h_log_bound
        exact le_of_lt (Real.rpow_pos_of_pos hN_pos _)
    _ = 4 * ((N : ℝ) ^ (-(1:ℝ)/4) * t) := by ring
    _ = 4 * 1 := by rw [h_cancel]
    _ = 4 := by ring

/-- **PROVED**: N^{-1/4}·log³N ≤ 1728 for N ≥ 1.
    Polynomial crushes log (Theorist "Domination Bypass").
    Proof: (N^{-1/12}·logN)³ ≤ 12³ = 1728. -/
private lemma rpow_quarter_log_cube_bounded :
    ∀ N : ℕ, 1 ≤ N →
    (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 3 ≤ 1728 := by
  intro N hN
  have hN_pos : (0 : ℝ) < (N : ℝ) := by exact_mod_cast show 0 < N by omega
  have hN_ge1 : (1 : ℝ) ≤ (N : ℝ) := by exact_mod_cast show 1 ≤ N by omega
  set t := (N : ℝ) ^ ((1:ℝ)/12) with ht_def
  have ht_pos : 0 < t := Real.rpow_pos_of_pos hN_pos _
  have ht_ge1 : 1 ≤ t := by
    rw [ht_def, ← Real.rpow_zero (N : ℝ)]
    exact Real.rpow_le_rpow_of_exponent_le hN_ge1 (by norm_num)
  have h_log_le : Real.log t ≤ t := by
    linarith [Real.add_one_le_exp (Real.log t), Real.exp_log (lt_of_lt_of_le one_pos ht_ge1)]
  have h_log_eq : Real.log (N : ℝ) = 12 * Real.log t := by
    rw [ht_def, Real.log_rpow hN_pos]; ring
  have h_unit : (N : ℝ) ^ (-(1:ℝ)/12) * t = 1 := by
    rw [ht_def, ← Real.rpow_add hN_pos]; norm_num
  have h_piece : (N : ℝ) ^ (-(1:ℝ)/12) * Real.log (N : ℝ) ≤ 12 := by
    calc (N : ℝ) ^ (-(1:ℝ)/12) * Real.log (N : ℝ)
      _ = (N : ℝ) ^ (-(1:ℝ)/12) * (12 * Real.log t) := by rw [h_log_eq]
      _ = 12 * ((N : ℝ) ^ (-(1:ℝ)/12) * Real.log t) := by ring
      _ ≤ 12 * ((N : ℝ) ^ (-(1:ℝ)/12) * t) := by
          apply mul_le_mul_of_nonneg_left
          · exact mul_le_mul_of_nonneg_left h_log_le
              (le_of_lt (Real.rpow_pos_of_pos hN_pos _))
          · norm_num
      _ = 12 * 1 := by rw [h_unit]
      _ = 12 := by ring
  have h_exp : (N : ℝ) ^ (-(1:ℝ)/4) = ((N : ℝ) ^ (-(1:ℝ)/12)) ^ 3 := by
    rw [← Real.rpow_natCast ((N : ℝ) ^ (-(1:ℝ)/12)) 3,
        ← Real.rpow_mul (le_of_lt hN_pos)]
    norm_num
  calc (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) ^ 3
    _ = ((N : ℝ) ^ (-(1:ℝ)/12)) ^ 3 * Real.log (N : ℝ) ^ 3 := by rw [h_exp]
    _ = ((N : ℝ) ^ (-(1:ℝ)/12) * Real.log (N : ℝ)) ^ 3 := by ring
    _ ≤ 12 ^ 3 := by
        exact pow_le_pow_left₀ (by positivity) h_piece 3
    _ = 1728 := by norm_num

/-- **THEOREM** (was THE ABEL ENGINE AXIOM — now GRADUATED to theorem! 🎓)

    From Mertens |M(x)| ≤ C_m·x^{3/4} + PNT convergence,
    Abel summation on the tail Σ_{k>N} gives:
      |S₁(N)| ≤ C·N^{-1/4}
      |S₂(N)+1| ≤ C·N^{-1/4}·logN
      |S₃(N)+2γ| ≤ C·N^{-1/4}·log²N

    PROOF (April 22, 2026 — The Graduation):
    Each bound is proved independently in the AbelTail module:
      s1_decay: |S₁(N)| ≤ C₁·N^{-1/4}           [AbelTail/S1Decay.lean]
      s2_decay: |S₂(N)+1| ≤ C₂·N^{-1/4}·logN     [AbelTail/S2Decay.lean]
      s3_decay: |S₃(N)+2γ| ≤ C₃·N^{-1/4}·log²N   [AbelTail/S3Decay.lean]
    Combined with C = max(C₁, max(C₂, C₃)).

    The proofs use:
    1. Abel summation engine (partial summation with quantitative bounds)
    2. Log-weighted tail bounds (iterated sum-swap, M-independent)
    3. Discrete product rule (DPR for log^j(k)/k)
    4. ε-argument (le_of_forall_pos_lt_add + boundary vanishing) -/
theorem abel_mertens_tail_raw
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (hPNT₁ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ))
      Filter.atTop (nhds 0))
    (hPNT₂ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        Real.log (k : ℝ) / (k : ℝ))
      Filter.atTop (nhds (-1)))
    (hPNT₃ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
      Filter.atTop (nhds (-2 * Real.eulerMascheroniConstant))) :
    ∃ C : ℝ, C > 0 ∧ ∀ N : ℕ, 2 ≤ N →
    |S₁ N| ≤ C * (N : ℝ) ^ (-(1:ℝ)/4) ∧
    |S₂ N - (-1)| ≤ C * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) ∧
    |S₃ N - (-2 * Real.eulerMascheroniConstant)| ≤
      C * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := by
  -- Get individual constants from the three decay theorems
  obtain ⟨C₁, hC₁_pos, h₁⟩ := s1_decay C_m hC hMertens hPNT₁
  obtain ⟨C₂, hC₂_pos, h₂⟩ := s2_decay C_m hC hMertens hPNT₂
  obtain ⟨C₃, hC₃_pos, h₃⟩ := s3_decay C_m hC hMertens
    (-2 * Real.eulerMascheroniConstant) hPNT₃
  -- Combine: C = max(C₁, max(C₂, C₃))
  set C := max C₁ (max C₂ C₃)
  refine ⟨C, by positivity, fun N hN => ?_⟩
  -- The private defs S₁, S₂, S₃ are definitionally equal to S₁_at, S₂_at, S₃_at
  have hS₁_eq : S₁ N = S₁_at N := rfl
  have hS₂_eq : S₂ N = S₂_at N := rfl
  have hS₃_eq : S₃ N = S₃_at N := rfl
  rw [hS₁_eq, hS₂_eq, hS₃_eq]
  refine ⟨?_, ?_, ?_⟩
  · -- S₁: |S₁_at(N)| ≤ C₁·N^{-1/4} ≤ C·N^{-1/4}
    calc |S₁_at N| ≤ C₁ * (N : ℝ) ^ (-(1:ℝ)/4) := h₁ N hN
      _ ≤ C * (N : ℝ) ^ (-(1:ℝ)/4) := by
          apply mul_le_mul_of_nonneg_right _ (le_of_lt (Real.rpow_pos_of_pos
            (Nat.cast_pos.mpr (by omega)) _))
          exact le_max_left C₁ _
  · -- S₂: |S₂_at(N)+1| ≤ C₂·N^{-1/4}·logN ≤ C·N^{-1/4}·logN
    calc |S₂_at N - (-1)| ≤ C₂ * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := h₂ N hN
      _ ≤ C * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := by
          apply mul_le_mul_of_nonneg_right _ (Real.log_nonneg
            (by exact_mod_cast show 1 ≤ N by omega))
          apply mul_le_mul_of_nonneg_right _ (le_of_lt (Real.rpow_pos_of_pos
            (Nat.cast_pos.mpr (by omega)) _))
          exact le_trans (le_max_left C₂ C₃) (le_max_right C₁ _)
  · -- S₃: |S₃_at(N)+2γ| ≤ C₃·N^{-1/4}·log²N ≤ C·N^{-1/4}·log²N
    calc |S₃_at N - (-2 * Real.eulerMascheroniConstant)|
        ≤ C₃ * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := h₃ N hN
      _ ≤ C * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := by
          apply mul_le_mul_of_nonneg_right _ (sq_nonneg _)
          apply mul_le_mul_of_nonneg_right _ (le_of_lt (Real.rpow_pos_of_pos
            (Nat.cast_pos.mpr (by omega)) _))
          exact le_trans (le_max_right C₂ C₃) (le_max_right C₁ _)

/-- **PROVED**: Tail domination — converts raw N^{-1/4} bounds to K/logN.

    Uses the PROVED rpow domination lemmas:
      N^{-1/4}·logN ≤ 4   (rpow_quarter_log_bounded)
      N^{-1/4}·log³N ≤ 1728 (rpow_quarter_log_cube_bounded) -/
private lemma pnt_mertens_tail_domination
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (hPNT₁ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ))
      Filter.atTop (nhds 0))
    (hPNT₂ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        Real.log (k : ℝ) / (k : ℝ))
      Filter.atTop (nhds (-1)))
    (hPNT₃ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
      Filter.atTop (nhds (-2 * Real.eulerMascheroniConstant))) :
    ∃ K : ℝ, K > 0 ∧ ∀ N : ℕ, 3 ≤ N →
    |S₁ N| ≤ K / Real.log (N : ℝ) ∧
    |S₂ N - (-1)| ≤ K / Real.log (N : ℝ) ∧
    |S₃ N - (-2 * Real.eulerMascheroniConstant)| ≤ K / Real.log (N : ℝ) := by
  -- Step 1: Get raw Abel-Mertens tail bounds
  obtain ⟨C_raw, hC_raw_pos, hraw⟩ := abel_mertens_tail_raw C_m hC hMertens hPNT₁ hPNT₂ hPNT₃
  -- Step 2: Get rpow domination bounds — PROVED
  obtain ⟨B₁, hB₁_pos, hB₁⟩ := rpow_quarter_log_bounded  -- N^{-1/4}·logN ≤ B₁ for N ≥ 1
  -- Step 3: Assemble K
  -- |S₁(N)| ≤ C·N^{-1/4} = C·(N^{-1/4}·logN)/logN ≤ C·B₁/logN
  -- |S₂(N)+1| ≤ C·N^{-1/4}·logN = C·(N^{-1/4}·log²N)/logN
  --            = C·(N^{-1/4}·logN)·logN/logN ≤ C·B₁  ← NOT K/logN!
  -- Need: C·N^{-1/4}·logN ≤ K/logN ↔ C·N^{-1/4}·log²N ≤ K
  -- N^{-1/4}·log²N = (N^{-1/8}·logN)² ≤ (8)² = 64
  -- |S₃(N)+2γ| ≤ C·N^{-1/4}·log²N ≤ C·K₃/logN  where K₃ uses log³N bound
  -- Use the cube bound: N^{-1/4}·log³N ≤ 1728
  -- So C·N^{-1/4}·log²N = C·N^{-1/4}·log³N / logN ≤ C·1728/logN
  set K := C_raw * 1728 + 1
  refine ⟨K, by linarith, fun N hN => ?_⟩
  obtain ⟨h₁, h₂, h₃⟩ := hraw N (by omega)
  have hN_pos : (0 : ℝ) < (N : ℝ) := by exact_mod_cast show 0 < N by omega
  have hlogN_pos : 0 < Real.log (N : ℝ) :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  have hcube := rpow_quarter_log_cube_bounded N (by omega)
  -- For S₁: |S₁(N)| ≤ C·N^{-1/4} ≤ C·N^{-1/4}·log³N / log³N ≤ C·1728/log³N ≤ C·1728/logN
  -- Simpler: N^{-1/4} = N^{-1/4}·logN / logN ≤ B₁/logN
  have hB₁_at_N := hB₁ N (by omega)  -- N^{-1/4}·logN ≤ B₁
  have h_rpow_pos : 0 < (N : ℝ) ^ (-(1:ℝ)/4) := Real.rpow_pos_of_pos hN_pos _
  -- Bound S₁:
  -- |S₁(N)| ≤ C·N^{-1/4}
  -- We need: C·N^{-1/4} ≤ K/logN ↔ C·N^{-1/4}·logN ≤ K
  -- C·N^{-1/4}·logN ≤ C·N^{-1/4}·log³N ≤ C·1728 ≤ K  (for logN ≥ 1)
  have hlogN_ge1 : 1 ≤ Real.log (N : ℝ) := by
    rw [show (1 : ℝ) = Real.log (Real.exp 1) from (Real.log_exp 1).symm]
    apply Real.log_le_log (Real.exp_pos 1)
    calc Real.exp 1 ≤ 3 := le_of_lt Real.exp_one_lt_three
      _ ≤ (N : ℝ) := by exact_mod_cast show 3 ≤ N by omega
  have hS₁ : |S₁ N| ≤ K / Real.log (N : ℝ) := by
    rw [le_div_iff₀ hlogN_pos]
    calc |S₁ N| * Real.log (N : ℝ)
      _ ≤ C_raw * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) :=
          mul_le_mul_of_nonneg_right h₁ (le_of_lt hlogN_pos)
      _ ≤ C_raw * ((N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 3) := by
          rw [mul_assoc]
          apply mul_le_mul_of_nonneg_left _ (le_of_lt hC_raw_pos)
          calc (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ)
            _ = (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 1 := by ring
            _ ≤ (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 3 := by
                apply mul_le_mul_of_nonneg_left _ (le_of_lt h_rpow_pos)
                exact pow_right_mono₀ hlogN_ge1 (by omega)
      _ ≤ C_raw * 1728 :=
          mul_le_mul_of_nonneg_left hcube (le_of_lt hC_raw_pos)
      _ ≤ K := by linarith
  -- Bound S₂: |S₂(N)+1| ≤ C·N^{-1/4}·logN ≤ C·B₁ ≤ C·1728
  -- But we need ≤ K/logN, which requires C·N^{-1/4}·log²N ≤ K
  -- N^{-1/4}·log²N ≤ N^{-1/4}·log³N ≤ 1728 (for logN ≥ 1, which holds for N ≥ 3)
  have hS₂ : |S₂ N - (-1)| ≤ K / Real.log (N : ℝ) := by
    rw [le_div_iff₀ hlogN_pos]
    calc |S₂ N - (-1)| * Real.log (N : ℝ)
      _ ≤ C_raw * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) * Real.log (N : ℝ) :=
          mul_le_mul_of_nonneg_right h₂ (le_of_lt hlogN_pos)
      _ = C_raw * ((N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2) := by ring
      _ ≤ C_raw * ((N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 3) := by
          apply mul_le_mul_of_nonneg_left _ (le_of_lt hC_raw_pos)
          apply mul_le_mul_of_nonneg_left _ (le_of_lt h_rpow_pos)
          exact pow_right_mono₀ hlogN_ge1 (by omega)
      _ ≤ C_raw * 1728 :=
          mul_le_mul_of_nonneg_left hcube (le_of_lt hC_raw_pos)
      _ ≤ K := by linarith
  -- Bound S₃: |S₃(N)+2γ| ≤ C·N^{-1/4}·log²N
  -- Need: ≤ K/logN, so C·N^{-1/4}·log³N ≤ K
  have hS₃ : |S₃ N - (-2 * Real.eulerMascheroniConstant)| ≤ K / Real.log (N : ℝ) := by
    rw [le_div_iff₀ hlogN_pos]
    calc |S₃ N - (-2 * eulerMascheroniConstant)| * Real.log (N : ℝ)
      _ ≤ C_raw * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 * Real.log (N : ℝ) :=
          mul_le_mul_of_nonneg_right h₃ (le_of_lt hlogN_pos)
      _ = C_raw * ((N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 3) := by ring
      _ ≤ C_raw * 1728 :=
          mul_le_mul_of_nonneg_left hcube (le_of_lt hC_raw_pos)
      _ ≤ K := by linarith
  exact ⟨hS₁, hS₂, hS₃⟩

/-- **THE ALGEBRAIC CLEAVER** (Theorist directive, April 18, 2026):
    Pure polynomial identity with dummy variables.
    Lean's `ring` proves it instantly because it treats every
    complex term as a simple polynomial variable. -/
private lemma bd_summand_algebra (M Lk LN K G : ℝ) :
    (-M * (1 - Lk / LN)) * ((G + Lk) / K) =
    -G * (M / K) - (M * Lk / K) +
    (G / LN) * (M * Lk / K) + (1 / LN) * (M * Lk ^ 2 / K) := by
  ring

/-- Algebraic expansion of the Möbius-weighted mean.

    The Fin-indexed sum decomposes into PNT sub-sums:
    Σ v_k·b_k = -(1-γ)·S₁(M) - S₂(M) + [(1-γ)·S₂(M) + S₃(M)]/logN

    PROOF: The Algebraic Cleaver (Theorist directive).
    1. bd_summand_algebra with ring (dummy variables)
    2. Pointwise substitution via sum_congr
    3. Sum shattering via sum_add_distrib + mul_sum -/
private lemma mean_algebraic_expansion (N : ℕ) (hN : 10 ≤ N) :
    ∑ i : Fin (N - 1), bdMoebiusWeight N i *
      ((Real.log ↑(i.val + 1) + 1 - Real.eulerMascheroniConstant) /
        ↑(i.val + 1)) =
    -(1 - Real.eulerMascheroniConstant) * S₁ (N - 1) -
    S₂ (N - 1) +
    ((1 - Real.eulerMascheroniConstant) * S₂ (N - 1) + S₃ (N - 1)) /
      Real.log (N : ℝ) := by
  -- Step 0: Unfold bdMoebiusWeight and logWeight
  simp only [bdMoebiusWeight, logWeight]
  -- Step 1: Apply the Algebraic Cleaver pointwise
  conv_lhs =>
    arg 2; ext i
    rw [show (-(↑(ArithmeticFunction.moebius (i.val + 1)) : ℝ) *
        (1 - Real.log ↑(i.val + 1) / Real.log ↑N)) *
        ((Real.log ↑(i.val + 1) + 1 - eulerMascheroniConstant) / ↑(i.val + 1)) =
      (-(↑(ArithmeticFunction.moebius (i.val + 1)) : ℝ) *
        (1 - Real.log ↑(i.val + 1) / Real.log ↑N)) *
        (((1 - eulerMascheroniConstant) + Real.log ↑(i.val + 1)) / ↑(i.val + 1))
      from by ring]
    rw [bd_summand_algebra
      (↑(ArithmeticFunction.moebius (i.val + 1)) : ℝ)
      (Real.log ↑(i.val + 1))
      (Real.log ↑N)
      (↑(i.val + 1) : ℝ)
      (1 - eulerMascheroniConstant)]
  -- Step 2: Shatter the sum using sum distribution
  simp_rw [Finset.sum_add_distrib, Finset.sum_sub_distrib, ← Finset.mul_sum]
  -- Step 3: Convert each Fin sum to Icc sum, then fold into S₁, S₂, S₃
  -- Each Fin sum has the form ∑ i : Fin(N-1), f(i.val+1)
  -- which equals ∑ k ∈ Icc 1 (N-1), f(k) by fin_sum_eq_icc_sum
  have hN2 : 2 ≤ N := by omega
  have h₁ : ∑ i : Fin (N - 1),
      (↑(ArithmeticFunction.moebius (i.val + 1)) : ℝ) / ↑(i.val + 1) =
      S₁ (N - 1) := by
    unfold S₁
    exact fin_sum_eq_icc_sum hN2
      (fun k => (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ))
  have h₂ : ∑ i : Fin (N - 1),
      (↑(ArithmeticFunction.moebius (i.val + 1)) : ℝ) *
      Real.log ↑(i.val + 1) / ↑(i.val + 1) = S₂ (N - 1) := by
    unfold S₂
    exact fin_sum_eq_icc_sum hN2
      (fun k => (↑(ArithmeticFunction.moebius k) : ℝ) * Real.log (k : ℝ) / (k : ℝ))
  have h₃ : ∑ i : Fin (N - 1),
      (↑(ArithmeticFunction.moebius (i.val + 1)) : ℝ) *
      Real.log ↑(i.val + 1) ^ 2 / ↑(i.val + 1) = S₃ (N - 1) := by
    unfold S₃
    exact fin_sum_eq_icc_sum hN2
      (fun k => (↑(ArithmeticFunction.moebius k) : ℝ) * (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
  rw [h₁, h₂, h₃]
  -- Step 4: The algebra ((1-γ)/L·S₂ + 1/L·S₃ = ((1-γ)·S₂ + S₃)/L) follows by ring
  ring
/-- THE FORGE: Regroup expanded expression into error terms (Theorist directive). -/
private lemma mean_error_shift (S1 S2 S3 LN G : ℝ) :
    -(1 - G) * S1 - S2 + ((1 - G) * S2 + S3) / LN - 1 =
    -(1 - G) * S1 - (S2 + 1) + ((1 - G) * (S2 + 1) + (S3 + 2 * G) - (1 + G)) / LN := by
  ring

/-- THE FORGE: Log ratio bound via square bypass (Theorist directive).
    For N ≥ 10: N ≤ (N-1)², so logN ≤ 2·log(N-1), hence 1/log(N-1) ≤ 2/logN. -/
private lemma log_ratio_bound {N : ℕ} (hN : 10 ≤ N) :
    1 / Real.log ((N - 1 : ℕ) : ℝ) ≤ 2 / Real.log (N : ℝ) := by
  have hn_pos : (0 : ℝ) < Real.log ((N - 1 : ℕ) : ℝ) :=
    Real.log_pos (by exact_mod_cast show 1 < N - 1 by omega)
  have hn2_pos : (0 : ℝ) < Real.log (N : ℝ) :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  rw [div_le_div_iff₀ hn_pos hn2_pos, one_mul]
  have hN1_pos : (0 : ℝ) < ((N - 1 : ℕ) : ℝ) := by exact_mod_cast show 0 < N - 1 by omega
  have h_sq : (N : ℝ) ≤ ((N - 1 : ℕ) : ℝ) * ((N - 1 : ℕ) : ℝ) := by
    have h1 : (10 : ℝ) ≤ (N : ℝ) := by exact_mod_cast hN
    have h2 : (9 : ℝ) ≤ ((N - 1 : ℕ) : ℝ) := by exact_mod_cast show 9 ≤ N - 1 by omega
    have h3 : ((N - 1 : ℕ) : ℝ) = (N : ℝ) - 1 := by
      rw [Nat.cast_sub (by omega : 1 ≤ N)]; simp
    rw [h3]; nlinarith
  have h_log_sq := Real.log_le_log (by exact_mod_cast show 0 < N by omega) h_sq
  rw [Real.log_mul (ne_of_gt hN1_pos) (ne_of_gt hN1_pos)] at h_log_sq
  linarith

-- ════════════════════════════════════════════════
-- §2b. THE MEAN BOUND (was AXIOM → now THEOREM!)
-- ════════════════════════════════════════════════

/-- **THEOREM** (was NUMBER THEORY AXIOM — now PROVED from sub-lemmas!):
    The Möbius-weighted mean is close to 1.

    PROOF CHAIN (Theorist "Assembly Shredder" directive):
    1. Algebraic Cleaver: Σvb = -(1-γ)S₁ - S₂ + [(1-γ)S₂+S₃]/logN
    2. Error shift: regroup into ε₁, ε₂, ε₃ terms via ring
    3. Log ratio bound: 1/log(N-1) ≤ 2/logN via square bypass
    4. Triangle inequality shredder: step-by-step abs decomposition
    5. Gamma evasion: K defined using |1-γ|, |1+γ| abstractly -/
theorem moebius_mean_finite_bound
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4)) :
    ∃ K : ℝ, K > 0 ∧ ∀ (N : ℕ), 10 ≤ N →
    |∑ i : Fin (N - 1), bdMoebiusWeight N i *
      ((Real.log ↑(i.val + 1) + 1 - Real.eulerMascheroniConstant) /
        ↑(i.val + 1)) - 1| ≤
      K / Real.log (N : ℝ) := by
  -- Step 1: Get tail domination bounds (THE ONE SORRY)
  obtain ⟨K_td, hK_td_pos, hK_td⟩ := pnt_mertens_tail_domination C_m hC hMertens
    pnt_mu_div_k pnt_mu_log_div_k pnt_mu_log_sq_div_k
  -- Step 2: The Gamma-Evasion K (Theorist "Assembly Shredder" directive)
  set G := Real.eulerMascheroniConstant with hG_def
  set L10 := Real.log (10 : ℝ) with hL10_def
  set B := |1 - G| * (2 * K_td) + 2 * K_td with hB_def
  -- K absorbs γ without needing numerical approximation!
  set K := B + B / L10 + |1 + G| with hK_def
  have hL10_pos : 0 < L10 := Real.log_pos (by norm_num)
  have hB_nonneg : 0 ≤ B := by
    have : 0 ≤ K_td := hK_td_pos.le; positivity
  have hK_pos : 0 < K := by
    have : 0 < K_td := hK_td_pos; positivity
  refine ⟨K, hK_pos, fun N hN => ?_⟩
  -- Step 3: Get tail bounds at N-1 and apply expansion
  have hM : 3 ≤ N - 1 := by omega
  obtain ⟨hS₁, hS₂, hS₃⟩ := hK_td (N - 1) hM
  rw [mean_algebraic_expansion N hN]
  -- Generalize sums to hide from linarith/ring (Theorist directive)
  set LN := Real.log (N : ℝ) with hLN_def
  have hLN_pos : 0 < LN := Real.log_pos (by exact_mod_cast show 1 < N by omega)
  -- Step 4: Regroup into error terms
  rw [show -(1 - G) * S₁ (N - 1) - S₂ (N - 1) +
      ((1 - G) * S₂ (N - 1) + S₃ (N - 1)) / LN - 1 =
      -(1 - G) * S₁ (N - 1) - (S₂ (N - 1) + 1) +
      ((1 - G) * (S₂ (N - 1) + 1) + (S₃ (N - 1) + 2 * G) - (1 + G)) / LN
    from by ring]
  -- Step 5: Scale tails from log(N-1) to log(N) via square bypass
  have h_ratio := log_ratio_bound hN
  have hE1 : |S₁ (N - 1)| ≤ 2 * K_td / LN := by
    calc |S₁ (N - 1)| ≤ K_td / Real.log ((N - 1 : ℕ) : ℝ) := hS₁
      _ = K_td * (1 / Real.log ((N - 1 : ℕ) : ℝ)) := by ring
      _ ≤ K_td * (2 / LN) := mul_le_mul_of_nonneg_left h_ratio hK_td_pos.le
      _ = 2 * K_td / LN := by ring
  have hE2 : |S₂ (N - 1) - (-1)| ≤ 2 * K_td / LN := by
    calc |S₂ (N - 1) - (-1)| ≤ K_td / Real.log ((N - 1 : ℕ) : ℝ) := hS₂
      _ = K_td * (1 / Real.log ((N - 1 : ℕ) : ℝ)) := by ring
      _ ≤ K_td * (2 / LN) := mul_le_mul_of_nonneg_left h_ratio hK_td_pos.le
      _ = 2 * K_td / LN := by ring
  -- Convert |S₂ - (-1)| to |S₂ + 1|
  have hE2' : |S₂ (N - 1) + 1| ≤ 2 * K_td / LN := by
    have : S₂ (N - 1) + 1 = S₂ (N - 1) - (-1) := by ring
    rw [this]; exact hE2
  have hE3 : |S₃ (N - 1) - (-2 * G)| ≤ 2 * K_td / LN := by
    calc |S₃ (N - 1) - (-2 * G)| ≤ K_td / Real.log ((N - 1 : ℕ) : ℝ) := hS₃
      _ = K_td * (1 / Real.log ((N - 1 : ℕ) : ℝ)) := by ring
      _ ≤ K_td * (2 / LN) := mul_le_mul_of_nonneg_left h_ratio hK_td_pos.le
      _ = 2 * K_td / LN := by ring
  have hE3' : |S₃ (N - 1) + 2 * G| ≤ 2 * K_td / LN := by
    have : S₃ (N - 1) + 2 * G = S₃ (N - 1) - (-2 * G) := by ring
    rw [this]; exact hE3
  -- Step 6: The Final Triangle Inequality Shredder
  have h_inv_LN_le : 1 / LN ≤ 1 / L10 := by
    exact one_div_le_one_div_of_le hL10_pos
      (Real.log_le_log (by norm_num) (by exact_mod_cast hN))
  calc |-(1 - G) * S₁ (N - 1) - (S₂ (N - 1) + 1) +
       ((1 - G) * (S₂ (N - 1) + 1) + (S₃ (N - 1) + 2 * G) - (1 + G)) / LN|
    _ ≤ |-(1 - G) * S₁ (N - 1) - (S₂ (N - 1) + 1)| +
        |((1 - G) * (S₂ (N - 1) + 1) + (S₃ (N - 1) + 2 * G) - (1 + G)) / LN| :=
        abs_add_le _ _
    _ ≤ |1 - G| * |S₁ (N - 1)| + |S₂ (N - 1) + 1| +
        (|1 - G| * |S₂ (N - 1) + 1| + |S₃ (N - 1) + 2 * G| + |1 + G|) / LN := by
        -- Leading terms: |a - b| ≤ |a| + |b|
        have h_lead : |-(1 - G) * S₁ (N - 1) - (S₂ (N - 1) + 1)| ≤
            |1 - G| * |S₁ (N - 1)| + |S₂ (N - 1) + 1| := by
          rw [show -(1 - G) * S₁ (N - 1) - (S₂ (N - 1) + 1) =
              (-(1 - G) * S₁ (N - 1)) + (-(S₂ (N - 1) + 1)) from by ring]
          calc _ ≤ |-(1 - G) * S₁ (N - 1)| + |-(S₂ (N - 1) + 1)| := abs_add_le _ _
            _ = |1 - G| * |S₁ (N - 1)| + |S₂ (N - 1) + 1| := by
                simp only [abs_neg, abs_mul]
        -- Numerator: |(p + q - r)| ≤ |p| + |q| + |r|
        have h_num : |(1 - G) * (S₂ (N - 1) + 1) + (S₃ (N - 1) + 2 * G) - (1 + G)| ≤
            |1 - G| * |S₂ (N - 1) + 1| + |S₃ (N - 1) + 2 * G| + |1 + G| := by
          rw [show (1 - G) * (S₂ (N - 1) + 1) + (S₃ (N - 1) + 2 * G) - (1 + G) =
              ((1 - G) * (S₂ (N - 1) + 1) + (S₃ (N - 1) + 2 * G)) + (-(1 + G)) from by ring]
          calc _ ≤ |(1 - G) * (S₂ (N - 1) + 1) + (S₃ (N - 1) + 2 * G)| + |-(1 + G)| :=
                  abs_add_le _ _
            _ ≤ (|(1 - G) * (S₂ (N - 1) + 1)| + |S₃ (N - 1) + 2 * G|) + |1 + G| := by
                  rw [abs_neg]; linarith [abs_add_le ((1 - G) * (S₂ (N - 1) + 1)) (S₃ (N - 1) + 2 * G)]
            _ = |1 - G| * |S₂ (N - 1) + 1| + |S₃ (N - 1) + 2 * G| + |1 + G| := by
                  rw [abs_mul]
        -- Fractional bound: |expr/LN| ≤ bound/LN
        have h_frac : |((1 - G) * (S₂ (N - 1) + 1) + (S₃ (N - 1) + 2 * G) - (1 + G)) / LN| ≤
            (|1 - G| * |S₂ (N - 1) + 1| + |S₃ (N - 1) + 2 * G| + |1 + G|) / LN := by
          rw [abs_div, abs_of_pos hLN_pos]
          exact div_le_div_of_nonneg_right h_num hLN_pos.le
        linarith
    _ ≤ |1 - G| * (2 * K_td / LN) + (2 * K_td / LN) +
        (|1 - G| * (2 * K_td / LN) + (2 * K_td / LN) + |1 + G|) / LN := by
        have h1G := abs_nonneg (1 - G)
        linarith [mul_le_mul_of_nonneg_left hE1 h1G,
                  mul_le_mul_of_nonneg_left hE2' h1G,
                  div_le_div_of_nonneg_right
                    (show |1 - G| * |S₂ (N - 1) + 1| + |S₃ (N - 1) + 2 * G| + |1 + G| ≤
                         |1 - G| * (2 * K_td / LN) + (2 * K_td / LN) + |1 + G|
                     from by linarith [mul_le_mul_of_nonneg_left hE2' h1G])
                    hLN_pos.le]
    _ = B / LN + B * (1 / LN) / LN + |1 + G| / LN := by
        rw [hB_def]; ring
    _ ≤ B / LN + B * (1 / L10) / LN + |1 + G| / LN := by
        linarith [div_le_div_of_nonneg_right
          (mul_le_mul_of_nonneg_left h_inv_LN_le hB_nonneg) hLN_pos.le]
    _ = K / LN := by rw [hK_def]; ring

/-- **THEOREM** (was CALCULUS AXIOM 2a — now PROVED!):
    ∃ K > 0, ∀ N ≥ 10, |(∫₀¹ f_N dx) - 1| ≤ K / log(N)

    Proof chain: ∫ → Σ → closed form → number theory axiom. -/
theorem linear_mean_bound
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4)) :
    ∃ K : ℝ, K > 0 ∧ ∀ (N : ℕ), 10 ≤ N →
    |(∫ x in (0:ℝ)..1, bdLinComb N (bdMoebiusWeight N) x) - 1| ≤
      K / Real.log (N : ℝ) := by
  -- Get the existential K from the number theory axiom
  obtain ⟨K, hK_pos, hK_bound⟩ := moebius_mean_finite_bound C_m hC hMertens
  refine ⟨K, hK_pos, fun N hN => ?_⟩
  -- Steps 1-3: Reduce integral to finite sum (all proved)
  have h_sum := integral_bdLinComb_eq_sum N (bdMoebiusWeight N)
  have h_entry : ∀ i : Fin (N - 1),
    ∫ x in (0:ℝ)..1, Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) =
      (Real.log ↑(i.val + 1) + 1 - Real.eulerMascheroniConstant) / ↑(i.val + 1) := by
    intro i
    exact (mean_entry_eq_integral (i.val + 1) (by omega)).symm
  rw [h_sum]; simp_rw [h_entry]
  -- Step 4: Apply number theory bound
  exact hK_bound N hN

end
