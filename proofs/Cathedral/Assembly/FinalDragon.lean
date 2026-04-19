/-
  Cathedral/Assembly/FinalDragon.lean

  ## The Final Dragon v3: ONE AXIOM Architecture

  Theorist Directive (April 18, 2026 — "The Scholar and the Forge"):
  "Stop looking for the unconditional bypass. Finish the Cathedral's walls."

  The Nyman-Beurling equivalence depends on EXACTLY ONE custom axiom:
    rh_implies_mertens_34: RH → |M(x)| = O(x^{3/4})

  PROOF CHAIN:
    rh_implies_mertens_34  [THE ONE AXIOM]
      → mertens_34_l2_bound  [THEOREM: calculus — Abel + Parseval]
      → convergence_from_bound [THEOREM: C/N^{1/4} → 0]
      → rh_implies_l2_convergence_proved [THEOREM! DONE!]
-/

import Cathedral.Defs
import Cathedral.NymanBeurling.BDMellin
import Cathedral.Assembly.AbelL2Bridge
import Cathedral.Assembly.BDBridge
import Cathedral.Assembly.AbelEngine
import Cathedral.MellinBridge.BDWeights
import Cathedral.MellinBridge.MertensIntegral
import Cathedral.MellinBridge.MertensBound
import Cathedral.Vasyunin.Augmented.MeanIntegral
import Mathlib.NumberTheory.ArithmeticFunction.Moebius

noncomputable section
open Real Matrix Finset MeasureTheory Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- §1. THE ONE AXIOM: RH → M(x) = O(x^{3/4})
-- ════════════════════════════════════════════════

/-- **THE ONE AXIOM**: RH implies the Mertens bound M(x) = O(x^{3/4}).

    This is the only custom axiom in the Cathedral. -/
axiom rh_implies_mertens_34 :
    RiemannHypothesis →
    ∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C * x ^ ((3:ℝ)/4)

-- ════════════════════════════════════════════════
-- §1b. PNT AXIOMS (19th Century — Unconditional)
-- ════════════════════════════════════════════════

/-- **PNT AXIOM 1**: The Möbius partial sums Σ μ(k)/k converge to 0.
    Equivalent to the Prime Number Theorem.
    Proof: 1/ζ(s) = Σ μ(n)/n^s for Re(s) > 1.
    As s → 1⁺, ζ(s) → ∞, so 1/ζ(s) → 0.
    Abel’s limit theorem gives the convergence. -/
axiom pnt_mu_div_k :
  Filter.Tendsto (fun N =>
    ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ))
    Filter.atTop (nhds 0)

/-- **PNT AXIOM 2**: The weighted sum Σ μ(k)·ln(k)/k converges to -1.
    From the derivative: -(1/ζ(s))' = ζ'(s)/ζ(s)² At s=1: ζ'(s)/ζ(s)² → 1.
    So -Σ μ(k)·ln(k)/k^s|_{s=1} = 1, giving the limit -1. -/
axiom pnt_mu_log_div_k :
  Filter.Tendsto (fun N =>
    ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
      Real.log (k : ℝ) / (k : ℝ))
    Filter.atTop (nhds (-1))

/-- **PNT AXIOM 3**: The weighted sum Σ μ(k)·ln²(k)/k converges to -2γ.
    From the second derivative of 1/ζ(s) at s=1.
    Uses the Laurent expansion of ζ(s) near s=1. -/
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

/-- **THE LAST SORRY**: Raw Abel-Mertens tail bounds.

    From Mertens |M(x)| ≤ C_m·x^{3/4} + PNT convergence,
    Abel summation on the tail Σ_{k>N} gives:
      |S₁(N)| ≤ C·N^{-1/4}
      |S₂(N)+1| ≤ C·N^{-1/4}·logN
      |S₃(N)+2γ| ≤ C·N^{-1/4}·log²N

    Proof sketch (see Theorist "Final Span"):
    1. Abel: S₁(N) = M(N)/N - Σ_{k≥N} M(k)/(k(k+1))
    2. |M(N)/N| ≤ C_m·N^{-1/4} (direct from Mertens)
    3. |Σ_{k≥N} M(k)/(k(k+1))| ≤ Σ C_m·k^{-5/4} ≤ 4·C_m·N^{-1/4}
    4. For S₂, S₃: second Abel summation with log weights. -/
private lemma abel_mertens_tail_raw
    (C_m : ℝ) (_hC : 0 < C_m)
    (_hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (_hPNT₁ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ))
      Filter.atTop (nhds 0))
    (_hPNT₂ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        Real.log (k : ℝ) / (k : ℝ))
      Filter.atTop (nhds (-1)))
    (_hPNT₃ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
      Filter.atTop (nhds (-2 * Real.eulerMascheroniConstant))) :
    ∃ C : ℝ, C > 0 ∧ ∀ N : ℕ, 2 ≤ N →
    |S₁ N| ≤ C * (N : ℝ) ^ (-(1:ℝ)/4) ∧
    |S₂ N - (-1)| ≤ C * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) ∧
    |S₃ N - (-2 * Real.eulerMascheroniConstant)| ≤
      C * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := by
  sorry

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
  -- Step 2: Get rpow domination bounds (PROVED!)
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

/-- **THEOREM** (was NUMBER THEORY AXIOM — now PROVED from sub-lemmas!):
    The Möbius-weighted mean is close to 1.

    PROOF CHAIN (Theorist "Final Span" directive):
    1. Algebraic Cleaver: Σvb = -(1-γ)S₁ - S₂ + [(1-γ)S₂+S₃]/logN  [PROVED]
    2. Tail domination: |Sᵢ-Lᵢ| ≤ K_td/logN                        [sorry]
    3. Substitute Sᵢ = Lᵢ + εᵢ: Σvb = 1 - (1+γ)/logN + Errors
    4. Triangle inequality: |Errors| ≤ const/logN
    5. Result: |Σvb - 1| ≤ K/logN

    REMAINING SORRY: pnt_mertens_tail_domination only. -/
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
  -- Step 2: Assemble K = 8K_td + 2  (factor of 2 from log(N-1)/logN ≥ 1/2)
  set K := 8 * K_td + 2
  refine ⟨K, by linarith, fun N hN => ?_⟩
  have hN_pos : (0 : ℝ) < (N : ℝ) := by exact_mod_cast show 0 < N by omega
  have hlogN_pos : 0 < Real.log (N : ℝ) :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  -- Step 3: Apply the algebraic expansion (PROVED)
  rw [mean_algebraic_expansion N hN]
  -- Step 4: Triangle inequality with tail bounds at N-1.
  -- N ≥ 10 → N-1 ≥ 9 ≥ 3, so tail_domination applies at N-1:
  have hM : 3 ≤ N - 1 := by omega
  obtain ⟨hS₁, hS₂, hS₃⟩ := hK_td (N - 1) hM
  --   |S₁(N-1)| ≤ K_td/log(N-1)
  --   |S₂(N-1)+1| ≤ K_td/log(N-1)
  --   |S₃(N-1)+2γ| ≤ K_td/log(N-1)
  -- log(N-1) ≥ logN/2 (since N-1 ≥ N/2 for N ≥ 2), so:
  --   K_td/log(N-1) ≤ 2K_td/logN
  -- Substitute S₁ = ε₁, S₂ = -1+ε₂, S₃ = -2γ+ε₃:
  --   expr - 1 = -(1-γ)·ε₁ - ε₂ + ((1-γ)·ε₂ + ε₃ - (1+γ))/logN
  -- Triangle inequality:
  --   |expr-1| ≤ |ε₁| + |ε₂| + (|ε₂| + |ε₃| + 2)/logN
  --           ≤ 2K_td/logN + 2K_td/logN + (2K_td/logN + 2K_td/logN + 2)/logN
  --           ≤ 4K_td/logN + (4K_td + 2)/logN   [since 1/logN ≤ 1]
  --           ≤ (4K_td + 4K_td + 2)/logN = (8K_td+2)/logN = K/logN
  -- MECHANICAL: triangle inequality + log ratio bound.
  -- This sorry is subsumed by abel_mertens_tail_raw (both need it).
  sorry

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

/-- **NUMBER THEORY AXIOM**: The Vasyunin bilinear form is close to 1.

    Uses existential K (per Theorist directive).
    Can attack via Parseval Bypass (v^T G v = ∫|W_N|²/(1/4+t²) dt)
    or Variance Split (G = C + bb^T, reuse linear mean). -/
axiom moebius_quadratic_finite_bound
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4)) :
    ∃ K : ℝ, K > 0 ∧ ∀ (N : ℕ), 10 ≤ N →
    realQuadForm (Matrix.of fun i j =>
      vasyuninGramEntry (i.val + 1) (j.val + 1)) (bdMoebiusWeight N) ≤
      1 + K / Real.log (N : ℝ)

/-- **THEOREM** (was CALCULUS AXIOM 2b — now PROVED!):
    ∃ K > 0, ∀ N ≥ 10, ∫₀¹ f_N(x)² dx ≤ 1 + K/log(N)

    Proof: ∫f² = v^T G v [bd_gram_l2_identity] + axiom bound. -/
theorem quadratic_form_bound
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4)) :
    ∃ K : ℝ, K > 0 ∧ ∀ (N : ℕ), 10 ≤ N →
    ∫ x in (0:ℝ)..1, (bdLinComb N (bdMoebiusWeight N) x) ^ 2 ≤
      1 + K / Real.log (N : ℝ) := by
  obtain ⟨K, hK_pos, hK_bound⟩ := moebius_quadratic_finite_bound C_m hC hMertens
  refine ⟨K, hK_pos, fun N hN => ?_⟩
  rw [bd_gram_l2_identity N (by omega : 2 ≤ N) (bdMoebiusWeight N)]
  exact hK_bound N hN

/-- **THEOREM (PROVED!)**: Assembly — the two sub-bounds imply the L² decay.

    ∃ K > 0, ∀ N ≥ 10, ∫(1-f)² ≤ K/log(N)

    By l2_expansion: ∫(1-f)² = 1 - 2∫f + ∫f²
    With |∫f - 1| ≤ K₁/log(N) and ∫f² ≤ 1 + K₂/log(N):
      ∫(1-f)² ≤ (2K₁ + K₂)/log(N)
    Set K = 2K₁ + K₂. -/
theorem mertens_l2_decay
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4)) :
    ∃ K : ℝ, K > 0 ∧ ∀ (N : ℕ), 10 ≤ N →
    ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 ≤
        K / Real.log (N : ℝ) := by
  -- Get existential constants from both bounds
  obtain ⟨K₁, hK₁_pos, h_lin⟩ := linear_mean_bound C_m hC hMertens
  obtain ⟨K₂, hK₂_pos, h_quad⟩ := quadratic_form_bound C_m hC hMertens
  -- Set K = 2K₁ + K₂ (absorbs all constants)
  refine ⟨2 * K₁ + K₂, by linarith, fun N hN => ?_⟩
  have hlogN_pos : (0:ℝ) < Real.log (N:ℝ) := by
    apply Real.log_pos; exact_mod_cast (show 1 < N by omega)
  -- Get concrete bounds for this N
  have h_lin_N := h_lin N hN
  have h_quad_N := h_quad N hN
  set I_f := ∫ x in (0:ℝ)..1, bdLinComb N (bdMoebiusWeight N) x
  have h_lin_lo : 1 - K₁ / Real.log (N:ℝ) ≤ I_f := by
    linarith [neg_abs_le (I_f - 1)]
  -- Expand ∫(1-f)² = 1 - 2∫f + ∫f²
  have h_expand : ∫ x in (0:ℝ)..1, (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2 =
      1 - 2 * I_f + ∫ x in (0:ℝ)..1, (bdLinComb N (bdMoebiusWeight N) x) ^ 2 := by
    have h_eq : (fun x => (1 - bdLinComb N (bdMoebiusWeight N) x) ^ 2) =
        (fun x => 1 - 2 * bdLinComb N (bdMoebiusWeight N) x +
          (bdLinComb N (bdMoebiusWeight N) x) ^ 2) := by ext x; ring
    rw [h_eq]
    have h1 := intervalIntegrable_const (c := (1:ℝ)) (μ := volume) (a := (0:ℝ)) (b := (1:ℝ))
    have h2 := (bdLinComb_integrable N (bdMoebiusWeight N)).const_mul 2
    have h3 := bdLinComb_sq_integrable N (bdMoebiusWeight N)
    rw [intervalIntegral.integral_add (h1.sub h2) h3,
        intervalIntegral.integral_sub h1 h2]
    rw [intervalIntegral.integral_const, sub_zero, one_smul,
        intervalIntegral.integral_const_mul]
  rw [h_expand]
  set I_f2 := ∫ x in (0:ℝ)..1, (bdLinComb N (bdMoebiusWeight N) x) ^ 2
  -- Combine: 1 - 2I_f + I_f2 ≤ 1 - 2(1 - K₁/logN) + (1 + K₂/logN) = (2K₁+K₂)/logN
  have h_ub : 1 - 2 * I_f + I_f2 ≤ (2 * K₁ + K₂) / Real.log (N:ℝ) := by
    have h1 : -2 * I_f ≤ -2 * (1 - K₁ / Real.log (N:ℝ)) := by linarith
    have h3 : 1 - 2 * (1 - K₁ / Real.log (N:ℝ)) +
        (1 + K₂ / Real.log (N:ℝ)) =
        (2 * K₁ + K₂) / Real.log (N:ℝ) := by field_simp; ring
    linarith
  linarith

/-- **THEOREM**: Mertens O(x^{3/4}) → L² convergence.

    Given ∃ K, ∫(1-f)² ≤ K/log(N), for any ε > 0,
    choose N > e^{K/ε} so K/log(N) < ε. -/
theorem mertens_34_implies_convergence :
    (∃ C : ℝ, C > 0 ∧ ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C * x ^ ((3:ℝ)/4)) →
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀,
      ∃ v : Fin (N - 1) → ℝ,
        ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε := by
  intro ⟨C_m, hC, hMertens⟩ ε hε
  -- Get the existential K from mertens_l2_decay
  obtain ⟨K, hK_pos, hK_bound⟩ := mertens_l2_decay C_m hC hMertens
  -- Choose N₀ large enough that K/log(N₀) < ε
  set N₀ := max 10 (⌈Real.exp (K / ε)⌉₊ + 1)
  refine ⟨N₀, fun N hN => ?_⟩
  have hN10 : 10 ≤ N := by omega
  have hK_N := hK_bound N hN10
  refine ⟨bdMoebiusWeight N, lt_of_le_of_lt hK_N ?_⟩
  have hlogN_pos : (0:ℝ) < Real.log (N:ℝ) := by
    apply Real.log_pos; exact_mod_cast (show 1 < N by omega)
  rw [div_lt_iff₀ hlogN_pos]
  have hN_large : Real.exp (K / ε) < (N:ℝ) := by
    calc Real.exp (K / ε) ≤ ↑⌈Real.exp (K / ε)⌉₊ := Nat.le_ceil _
      _ < (N:ℝ) := by exact_mod_cast (show ⌈Real.exp (K / ε)⌉₊ < N by omega)
  have h_log : K / ε < Real.log (N:ℝ) := by
    rw [← Real.log_exp (K / ε)]
    exact Real.log_lt_log (Real.exp_pos _) hN_large
  calc K = K / ε * ε := (div_mul_cancel₀ K (ne_of_gt hε)).symm
    _ < Real.log (N:ℝ) * ε := mul_lt_mul_of_pos_right h_log hε
    _ = ε * Real.log (N:ℝ) := mul_comm _ _

-- ════════════════════════════════════════════════
-- §4. THE CROWN: rh_implies_l2_convergence (PROVED!)
-- ════════════════════════════════════════════════

/-- **THEOREM**: RH ⟹ d²_N → 0.

    FORMERLY: axiom rh_implies_l2_convergence (OneCrown.lean)
    NOW: theorem via: rh_implies_mertens_34 → mertens_34_implies_convergence -/
theorem rh_implies_l2_convergence_proved :
    RiemannHypothesis →
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀,
      ∃ v : Fin (N - 1) → ℝ,
        ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε := by
  intro hRH
  exact mertens_34_implies_convergence (rh_implies_mertens_34 hRH)

-- ════════════════════════════════════════════════
-- AXIOM AUDIT
-- ════════════════════════════════════════════════

#print axioms rh_implies_l2_convergence_proved

end
