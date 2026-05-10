/-
  Cathedral/Vasyunin/Augmented/DiagBound.lean

  ## Vasyunin Gram Entry Bounds for the BD Basis {1/(kx)}

  ### Key Theorems (all PROVED, 0 axioms):

  1. `bd_fract_product_integrable` — {1/(jx)}·{1/(kx)} integrable on [0,1]
  2. `vasyuninGram_diag_nonneg` — G(k,k) ≥ 0
  3. `vasyuninGram_nonneg` — G(j,k) ≥ 0
  4. `vasyuninGram_le_avg_diag` — G(j,k) ≤ (G(j,j)+G(k,k))/2 (AM-GM)

  These are used for bounding the quadratic form vᵀGv in the L² bound proof.

  Status: PROVED, 0 axioms.
  Created: April 22, 2026.
-/

import Cathedral.Vasyunin.Defs
import Cathedral.Vasyunin.Augmented.IntegralBridge

noncomputable section
open Real MeasureTheory

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- §1. INTEGRABILITY OF BD BASIS PRODUCTS
-- ════════════════════════════════════════════════

/-- Product of two BD basis functions {1/(jx)}·{1/(kx)} is integrable on [0,1]. -/
theorem bd_fract_product_integrable (j k : ℕ) :
    IntervalIntegrable (fun x : ℝ =>
      Int.fract (1 / ((j:ℝ) * x)) * Int.fract (1 / ((k:ℝ) * x)))
      MeasureTheory.volume 0 1 := by
  apply IntervalIntegrable.mono_fun
    (intervalIntegral.intervalIntegrable_const (c := (1:ℝ)))
  · have h1 : Measurable (fun x : ℝ => Int.fract (1 / ((j:ℝ) * x))) :=
      measurable_fract_real.comp (measurable_const.div (measurable_const.mul measurable_id))
    have h2 : Measurable (fun x : ℝ => Int.fract (1 / ((k:ℝ) * x))) :=
      measurable_fract_real.comp (measurable_const.div (measurable_const.mul measurable_id))
    exact (h1.mul h2).aestronglyMeasurable.restrict
  · filter_upwards with x
    rw [Real.norm_eq_abs,
        abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _)),
        Real.norm_eq_abs, abs_of_nonneg (by norm_num : (0:ℝ) ≤ 1)]
    nlinarith [Int.fract_nonneg (1/((j:ℝ)*x)), Int.fract_lt_one (1/((j:ℝ)*x)),
               Int.fract_nonneg (1/((k:ℝ)*x)), Int.fract_lt_one (1/((k:ℝ)*x))]

-- ════════════════════════════════════════════════
-- §2. NONNEGATIVITY
-- ════════════════════════════════════════════════

/-- **THEOREM**: G(k,k) ≥ 0 since it equals ∫₀¹ {1/(kx)}² dx ≥ 0. -/
theorem vasyuninGram_diag_nonneg (k : ℕ) (hk : 1 ≤ k) :
    0 ≤ vasyuninGramEntry k k := by
  have h := vasyunin_eq_integral k k (by omega : k ≥ 1) (by omega : k ≥ 1)
  rw [h]
  apply intervalIntegral.integral_nonneg (by norm_num : (0:ℝ) ≤ 1)
  intro x _
  exact mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _)

/-- **THEOREM**: G(j,k) ≥ 0 for j,k ≥ 1. -/
theorem vasyuninGram_nonneg (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    0 ≤ vasyuninGramEntry j k := by
  have h := vasyunin_eq_integral j k (by omega : j ≥ 1) (by omega : k ≥ 1)
  rw [h]
  apply intervalIntegral.integral_nonneg (by norm_num : (0:ℝ) ≤ 1)
  intro x _
  exact mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _)

-- ════════════════════════════════════════════════
-- §3. AM-GM FOR BD GRAM ENTRIES
-- ════════════════════════════════════════════════

/-- **THEOREM**: G(j,k) ≤ (G(j,j)+G(k,k))/2 (AM-GM for BD Gram entries).
    Since {a}·{b} ≤ ({a}²+{b}²)/2 pointwise. -/
theorem vasyuninGram_le_avg_diag (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    vasyuninGramEntry j k ≤
      (vasyuninGramEntry j j + vasyuninGramEntry k k) / 2 := by
  -- Rewrite all three Gram entries to integrals
  have hjk_eq := vasyunin_eq_integral j k (by omega : j ≥ 1) (by omega : k ≥ 1)
  have hjj_eq := vasyunin_eq_integral j j (by omega : j ≥ 1) (by omega : j ≥ 1)
  have hkk_eq := vasyunin_eq_integral k k (by omega : k ≥ 1) (by omega : k ≥ 1)
  -- Integrability
  have hjk := bd_fract_product_integrable j k
  have hjj := bd_fract_product_integrable j j
  have hkk := bd_fract_product_integrable k k
  -- The key inequality: integral mono from pointwise AM-GM
  have hint := intervalIntegral.integral_mono_on (by norm_num : (0:ℝ) ≤ 1)
    hjk ((hjj.add hkk).div_const 2)
    (fun x _ => by nlinarith [sq_nonneg (Int.fract (1/((j:ℝ)*x)) - Int.fract (1/((k:ℝ)*x)))])
  -- Linearize the integral of the sum: ∫(f+g)/2 = (∫f + ∫g)/2
  have hlin : ∫ x in (0:ℝ)..1,
      (Int.fract (1/((j:ℝ)*x)) * Int.fract (1/((j:ℝ)*x)) +
       Int.fract (1/((k:ℝ)*x)) * Int.fract (1/((k:ℝ)*x))) / 2 =
      (vasyuninGramEntry j j + vasyuninGramEntry k k) / 2 := by
    rw [hjj_eq, hkk_eq]
    rw [show ∀ f : ℝ → ℝ, (fun x => f x / 2) = fun x => (1/2 : ℝ) * f x from
          fun f => funext (fun x => by ring)]
    rw [intervalIntegral.integral_const_mul, show (1:ℝ)/2 = 2⁻¹ from by norm_num,
        inv_mul_eq_div]
    congr 1
    exact intervalIntegral.integral_add hjj hkk
  rw [hjk_eq]
  exact le_of_le_of_eq hint hlin

-- ════════════════════════════════════════════════
-- §4. DIAGONAL BOUND: G(k,k) < 1/2 FROM CLOSED FORM
-- ════════════════════════════════════════════════

/-- log(2π) < 2. Since 2π < e² (verified: 2π ≈ 6.283 < e² ≈ 7.389).
    Proof via Taylor: exp(2) ≥ 1+2+2+4/3+2/3 = 7 > 6.2832 ≥ 2π. -/
private theorem log_two_pi_lt_two : Real.log (2 * Real.pi) < 2 := by
  have h2pi_pos : (0:ℝ) < 2 * Real.pi := by positivity
  rw [Real.log_lt_iff_lt_exp h2pi_pos]
  calc 2 * Real.pi < 2 * 3.1416 := by
        exact mul_lt_mul_of_pos_left Real.pi_lt_d4 (by norm_num)
    _ = 6.2832 := by norm_num
    _ < Real.exp 2 := by
        -- exp(2) ≥ Σ_{k=0}^{4} 2^k/k! = 1+2+2+4/3+2/3 = 7 > 6.2832
        have h := Real.sum_le_exp_of_nonneg (show (0:ℝ) ≤ 2 by norm_num) 5
        -- Evaluate the sum: Σ_{i=0}^{4} 2^i/i!
        simp only [Finset.sum_range_succ, Nat.factorial] at h
        norm_num at h
        linarith

/-- log(2π) - γ < 3/2. Since log(2π) < 2 and γ > 1/2 (Mathlib). -/
private theorem log_two_pi_sub_gamma_lt : Real.log (2 * Real.pi) - eulerMascheroniConstant < 3 / 2 := by
  have h1 := log_two_pi_lt_two
  have h2 := one_half_lt_eulerMascheroniConstant
  linarith

/-- **THEOREM**: G(k,k) < 1/2 for all k ≥ 1.

    The diagonal Gram entry has the closed form:
      G(k,k) = (log(2π) - γ)/k - 1/k²

    Since log(2π) - γ < 3/2 (from log(2π) < 2 and γ > 1/2):
    - For k = 1: G(1,1) < 3/2 - 1 = 1/2
    - For k = 2: G(2,2) < 3/4 - 1/4 = 1/2
    - For k ≥ 3: G(k,k) < (3/2)/3 = 1/2

    Uses Mathlib's `one_half_lt_eulerMascheroniConstant` (David Loeffler, 2024). -/
theorem vasyuninGram_diag_lt_half (k : ℕ) (hk : 1 ≤ k) :
    vasyuninGramEntry k k < 1 / 2 := by
  rw [vasyuninGramEntry_diag]
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hk_cast : (1 : ℝ) ≤ (k : ℝ) := by exact_mod_cast hk
  have h_bound := log_two_pi_sub_gamma_lt
  -- Strategy: show (log(2π)-γ)/k - 1/k² < 1/2
  -- by showing (log(2π)-γ)/k < 1/2 + 1/k², i.e., multiplying by k:
  -- log(2π)-γ < k/2 + 1/k
  -- Since log(2π)-γ < 3/2, it suffices to show 3/2 ≤ k/2 + 1/k.
  -- For k≥1: k/2 + 1/k ≥ 1/2 + 1 = 3/2. ✓
  suffices h : (Real.log (2 * Real.pi) - eulerMascheroniConstant) < (k : ℝ) / 2 + 1 / (k : ℝ) by
    have hk_ne2 : (k:ℝ) ≠ 0 := ne_of_gt hk_pos
    have heq2 : ((k:ℝ)/2 + 1/(k:ℝ)) / (k:ℝ) = 1/2 + 1/(k:ℝ)^2 := by
      field_simp
    have hthis := div_lt_div_of_pos_right h hk_pos
    rw [heq2] at hthis
    linarith
  calc Real.log (2 * Real.pi) - eulerMascheroniConstant
      < 3 / 2 := h_bound
    _ ≤ (k : ℝ) / 2 + 1 / (k : ℝ) := by
        -- k/2 + 1/k = (k²+2)/(2k). Need (k²+2)/(2k) ≥ 3/2, i.e., k²+2 ≥ 3k.
        suffices h : 0 ≤ (k:ℝ)/2 + 1/(k:ℝ) - 3/2 by linarith
        have hk_ne : (k:ℝ) ≠ 0 := ne_of_gt hk_pos
        have heq : (k:ℝ)/2 + 1/(k:ℝ) - 3/2 = ((k:ℝ)^2 - 3*(k:ℝ) + 2) / (2*(k:ℝ)) := by
          field_simp
          ring
        rw [heq]
        apply div_nonneg _ (by positivity)
        -- k²-3k+2 = (k-1)(k-2) ≥ 0 for k : ℕ, k ≥ 1
        -- Since k is a nat, k ≥ 1, so (k:ℝ) ≥ 1.
        -- For k=1: 1-3+2=0. For k=2: 4-6+2=0. For k≥3: both factors pos.
        -- nlinarith needs: k ≥ 1 and k*(k-1) ≥ 0 (since k ≥ 1) and (k-1)*(k-2) ≥ 0
        -- Key: k ∈ ℕ, so k ≥ 1 means k-1 ≥ 0, k-2 ≥ -1.
        -- But (k:ℝ)-2 might be negative for k=1.
        -- Use: k²-3k+2 = k² - k - 2k + 2 = k(k-1) - 2(k-1) = (k-1)(k-2)
        -- For k : ℕ with k ≥ 1: either k=1 (gives 0) or k ≥ 2 (gives ≥ 0).
        rcases Nat.lt_or_ge k 2 with hlt | hle
        · -- k < 2, so k = 1 (since k ≥ 1)
          have : k = 1 := by omega
          subst this; norm_num
        · -- k ≥ 2: (k-1) ≥ 1 > 0 and (k-2) ≥ 0
          have : (2:ℝ) ≤ (k:ℝ) := by exact_mod_cast hle
          nlinarith

-- ════════════════════════════════════════════════
-- §5. UNIVERSAL BOUND: G(j,k) < 1/2 FOR ALL j,k ≥ 1
-- ════════════════════════════════════════════════

/-- **COROLLARY**: G(j,k) ≤ G_max < 1/2 for all j,k ≥ 1.
    From AM-GM + diagonal bound. -/
theorem vasyuninGram_lt_half (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    vasyuninGramEntry j k < 1 / 2 := by
  calc vasyuninGramEntry j k
      ≤ (vasyuninGramEntry j j + vasyuninGramEntry k k) / 2 :=
        vasyuninGram_le_avg_diag j k hj hk
    _ < (1/2 + 1/2) / 2 := by
        apply div_lt_div_of_pos_right _ (by norm_num : (0:ℝ) < 2)
        exact add_lt_add (vasyuninGram_diag_lt_half j hj) (vasyuninGram_diag_lt_half k hk)
    _ = 1/2 := by norm_num

-- ════════════════════════════════════════════════
-- §6. QUADRATIC FORM BOUND: vᵀGv ≤ (1/2)·‖v‖₁²
-- ════════════════════════════════════════════════

/-- **THEOREM**: vᵀGv ≤ (1/2) · (Σ|vᵢ|)² for the Vasyunin Gram matrix.

    Since G(j,k) < 1/2 and G(j,k) ≥ 0:
      vᵀGv = ΣΣ vⱼ·vₖ·G(j,k) ≤ (1/2)·ΣΣ |vⱼ|·|vₖ| = (1/2)·(Σ|vᵢ|)²

    This bounds the quadratic form in terms of the ℓ¹ norm of v,
    which is exactly what the Mertens-Abel summation controls. -/
theorem vasyuninQuadForm_le_half_l1_sq {n : ℕ} (v : Fin n → ℝ) :
    ∑ i : Fin n, ∑ j : Fin n,
      v i * v j * vasyuninGramEntry (i.val + 1) (j.val + 1)
    ≤ (1 / 2) * (∑ i : Fin n, |v i|) ^ 2 := by
  -- Bound each term: v_i * v_j * G(i+1,j+1) ≤ |v_i| * |v_j| * (1/2)
  have h_entry_bound : ∀ i j : Fin n,
      v i * v j * vasyuninGramEntry (i.val + 1) (j.val + 1) ≤
      (1/2) * (|v i| * |v j|) := by
    intro i j
    have h_nonneg := vasyuninGram_nonneg (i.val+1) (j.val+1) (by omega) (by omega)
    have h_lt := vasyuninGram_lt_half (i.val+1) (j.val+1) (by omega) (by omega)
    calc v i * v j * vasyuninGramEntry (i.val+1) (j.val+1)
        ≤ |v i * v j| * vasyuninGramEntry (i.val+1) (j.val+1) := by
          exact mul_le_mul_of_nonneg_right (le_abs_self _) h_nonneg
      _ = |v i| * |v j| * vasyuninGramEntry (i.val+1) (j.val+1) := by
          rw [abs_mul]
      _ ≤ |v i| * |v j| * (1/2) := by
          apply mul_le_mul_of_nonneg_left (le_of_lt h_lt)
          exact mul_nonneg (abs_nonneg _) (abs_nonneg _)
      _ = (1/2) * (|v i| * |v j|) := by ring
  -- Sum the bounds
  calc ∑ i : Fin n, ∑ j : Fin n,
        v i * v j * vasyuninGramEntry (i.val+1) (j.val+1)
      ≤ ∑ i : Fin n, ∑ j : Fin n, (1/2) * (|v i| * |v j|) :=
        Finset.sum_le_sum fun i _ =>
          Finset.sum_le_sum fun j _ => h_entry_bound i j
    _ = (1/2) * ∑ i : Fin n, ∑ j : Fin n, |v i| * |v j| := by
        simp_rw [Finset.mul_sum]
    _ = (1/2) * (∑ i : Fin n, |v i|) ^ 2 := by
        congr 1
        rw [sq]
        simp_rw [Finset.sum_mul, Finset.mul_sum]

end Cathedral.Vasyunin
