/-
  Cathedral/IntegralBasis/IntegralQuadForm.lean

  ## THE INTEGRAL QUADRATIC FORM — L² Structure of vᵀGv

  ════════════════════════════════════════════════════════════════

  **CORE THEOREM**: The Gram quadratic form is an L² norm:

    vᵀGv = ∫₀¹ |f_N(x)|² dx

  where f_N(x) = Σⱼ₌₁ᴺ vⱼ · {1/(jx)}.

  This bypasses cotangent sums entirely. The integral representation
  gives direct access to:

  1. **Automatic positivity**: vᵀGv ≥ 0 (it's a squared norm)
  2. **Pointwise bounds**: |f_N(x)| ≤ ‖v‖₁ since 0 ≤ {1/(jx)} < 1
  3. **Per-segment analysis**: On (1/(j(m+1)), 1/(jm)], {1/(jx)} = 1/(jx) - m,
     giving polynomial structure within each segment

  Created: May 27, 2026 — The Integral Route
  Status: Building...
-/

import Cathedral.IntegralBasis.BaezDuarte
import Cathedral.Analysis.FractIntegrable
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic
import Mathlib.MeasureTheory.Function.Floor
import Mathlib.Algebra.Order.BigOperators.Ring.Finset
import Mathlib.Tactic

noncomputable section
open Real MeasureTheory Filter Finset BigOperators

namespace Cathedral.IntegralBasis.IntegralQuadForm

-- ════════════════════════════════════════════════
-- §1. THE BASIS AND ITS PROPERTIES
-- ════════════════════════════════════════════════

/-- The Báez-Duarte basis function: h_j(x) = {1/(jx)}. -/
def h (j : ℕ) (x : ℝ) : ℝ := Int.fract (1 / ((j : ℝ) * x))

lemma h_nonneg (j : ℕ) (x : ℝ) : 0 ≤ h j x := Int.fract_nonneg _

lemma h_lt_one (j : ℕ) (x : ℝ) : h j x < 1 := Int.fract_lt_one _

lemma h_abs_le_one (j : ℕ) (x : ℝ) : |h j x| ≤ 1 := by
  rw [abs_of_nonneg (h_nonneg j x)]; linarith [h_lt_one j x]

lemma h_measurable (j : ℕ) : Measurable (h j) :=
  Measurable.fract (measurable_const.div (measurable_const.mul measurable_id))

-- ════════════════════════════════════════════════
-- §2. THE LINEAR COMBINATION f_N
-- ════════════════════════════════════════════════

/-- f_N(x) = Σⱼ vⱼ · h(j+1, x). -/
def fN (N : ℕ) (v : Fin N → ℝ) (x : ℝ) : ℝ :=
  ∑ j : Fin N, v j * h (j.val + 1) x

lemma fN_measurable (N : ℕ) (v : Fin N → ℝ) : Measurable (fN N v) := by
  apply Finset.measurable_sum
  intro j _; exact measurable_const.mul (h_measurable (j.val + 1))

-- ════════════════════════════════════════════════
-- §3. POINTWISE BOUNDS ON f_N
-- ════════════════════════════════════════════════

/-- |f_N(x)| ≤ Σ |vⱼ|. -/
theorem fN_abs_le_l1 (N : ℕ) (v : Fin N → ℝ) (x : ℝ) :
    |fN N v x| ≤ ∑ j : Fin N, |v j| := by
  unfold fN
  calc |∑ j : Fin N, v j * h (↑j + 1) x|
      ≤ ∑ j : Fin N, |v j * h (↑j + 1) x| := abs_sum_le_sum_abs _ _
    _ ≤ ∑ j : Fin N, |v j| := by
        apply Finset.sum_le_sum; intro j _
        rw [abs_mul]
        calc |v j| * |h (↑j + 1) x| ≤ |v j| * 1 :=
          mul_le_mul_of_nonneg_left (h_abs_le_one _ _) (abs_nonneg _)
          _ = |v j| := mul_one _

/-- f_N(x)² ≤ (Σ |vⱼ|)². -/
theorem fN_sq_le_l1_sq (N : ℕ) (v : Fin N → ℝ) (x : ℝ) :
    fN N v x ^ 2 ≤ (∑ j : Fin N, |v j|) ^ 2 := by
  have h1 := fN_abs_le_l1 N v x
  have h2 : 0 ≤ ∑ j : Fin N, |v j| := Finset.sum_nonneg (fun _ _ => abs_nonneg _)
  nlinarith [abs_nonneg (fN N v x), sq_abs (fN N v x)]

-- ════════════════════════════════════════════════
-- §4. INTEGRABILITY
-- ════════════════════════════════════════════════

lemma fN_sq_intervalIntegrable (N : ℕ) (v : Fin N → ℝ) :
    IntervalIntegrable (fun x => fN N v x ^ 2) volume 0 1 := by
  apply IntervalIntegrable.mono_fun (intervalIntegrable_const (c := (∑ j : Fin N, |v j|) ^ 2))
  · exact ((fN_measurable N v).pow_const 2).aestronglyMeasurable.restrict
  · apply ae_of_all; intro x
    simp only [Real.norm_eq_abs]
    rw [abs_of_nonneg (sq_nonneg _), abs_of_nonneg (sq_nonneg _)]
    exact fN_sq_le_l1_sq N v x

-- ════════════════════════════════════════════════
-- §5. THE GRAM ENTRY AS AN INTEGRAL
-- ════════════════════════════════════════════════

theorem gramEntry_eq_integral (j k : ℕ) :
    BaezDuarte.bdGramEntry j k = ∫ x in (0:ℝ)..1, h j x * h k x := by
  unfold BaezDuarte.bdGramEntry BaezDuarte.bdBasis h; rfl

-- ════════════════════════════════════════════════
-- §6. THE QUADRATIC FORM AS AN INTEGRAL
-- ════════════════════════════════════════════════

def gramQuadForm (N : ℕ) (v : Fin N → ℝ) : ℝ :=
  ∑ i : Fin N, ∑ j : Fin N,
    v i * v j * BaezDuarte.bdGramEntry (i.val + 1) (j.val + 1)

private lemma h_prod_intble (i j : ℕ) :
    IntervalIntegrable (fun x => h i x * h j x) volume 0 1 := by
  apply IntervalIntegrable.mono_fun (intervalIntegrable_const (c := (1:ℝ)))
  · exact ((h_measurable i).mul (h_measurable j)).aestronglyMeasurable.restrict
  · apply ae_of_all; intro x
    simp only [Real.norm_eq_abs, abs_one]
    exact Vasyunin.FractIntegrable.norm_fract_mul_fract_le _ _

/-- **CORE THEOREM**: vᵀGv = ∫₀¹ f_N(x)² dx. -/
theorem gramQuadForm_eq_integral (N : ℕ) (v : Fin N → ℝ) :
    gramQuadForm N v = ∫ x in (0:ℝ)..1, fN N v x ^ 2 := by
  -- Step 1: Expand fN² as double sum
  have h_expand : ∀ x, fN N v x ^ 2 =
      ∑ i : Fin N, ∑ j : Fin N, v i * v j * (h (i.val + 1) x * h (j.val + 1) x) := by
    intro x; unfold fN; rw [sq, Finset.sum_mul_sum]
    apply Finset.sum_congr rfl; intro i _
    apply Finset.sum_congr rfl; intro j _; ring
  -- Step 2: Each term is integrable
  have h_intble : ∀ (i j : Fin N),
      IntervalIntegrable (fun x => v i * v j * (h (i.val + 1) x * h (j.val + 1) x))
        volume 0 1 :=
    fun i j => (h_prod_intble (i.val + 1) (j.val + 1)).const_mul _
  -- Step 3: We prove ∫ f² = ΣΣ vᵢvⱼ G(i,j) = gramQuadForm
  unfold gramQuadForm
  symm
  -- Rewrite integrand as double sum
  conv_lhs => rw [show (fun x => fN N v x ^ 2) =
    (fun x => ∑ i : Fin N, ∑ j : Fin N,
      v i * v j * (h (i.val + 1) x * h (j.val + 1) x))
    from funext h_expand]
  -- Inner sum integrability (pointwise function form)
  have h_inner_intble : ∀ (i : Fin N),
      IntervalIntegrable (fun x => ∑ j : Fin N,
        v i * v j * (h (i.val + 1) x * h (j.val + 1) x)) volume 0 1 := by
    intro i
    have : (fun x => ∑ j : Fin N, v i * v j * (h (i.val + 1) x * h (j.val + 1) x)) =
        ∑ j : Fin N, (fun x => v i * v j * (h (i.val + 1) x * h (j.val + 1) x)) := by
      ext x; simp [Finset.sum_apply]
    rw [this]
    exact IntervalIntegrable.sum Finset.univ (fun j _ => h_intble i j)
  -- Swap outer sum
  rw [intervalIntegral.integral_finset_sum (fun i _ => h_inner_intble i)]
  apply Finset.sum_congr rfl; intro i _
  -- Swap inner sum
  rw [intervalIntegral.integral_finset_sum (fun j _ => h_intble i j)]
  apply Finset.sum_congr rfl; intro j _
  -- Factor out constant
  rw [intervalIntegral.integral_const_mul, gramEntry_eq_integral]

-- ════════════════════════════════════════════════
-- §7. POSITIVITY
-- ════════════════════════════════════════════════

/-- vᵀGv ≥ 0 (integral of a square is nonneg). -/
theorem gramQuadForm_nonneg (N : ℕ) (v : Fin N → ℝ) :
    0 ≤ gramQuadForm N v := by
  rw [gramQuadForm_eq_integral]
  apply intervalIntegral.integral_nonneg_of_forall (by norm_num : (0:ℝ) ≤ 1)
  intro x; exact sq_nonneg _

-- ════════════════════════════════════════════════
-- §8. CRUDE UPPER BOUND
-- ════════════════════════════════════════════════

/-- vᵀGv ≤ (Σ |vⱼ|)². -/
theorem gramQuadForm_le_l1_sq (N : ℕ) (v : Fin N → ℝ) :
    gramQuadForm N v ≤ (∑ j : Fin N, |v j|) ^ 2 := by
  rw [gramQuadForm_eq_integral]
  calc ∫ x in (0:ℝ)..1, fN N v x ^ 2
      ≤ ∫ x in (0:ℝ)..1, (∑ j : Fin N, |v j|) ^ 2 := by
        apply intervalIntegral.integral_mono_on (by norm_num : (0:ℝ) ≤ 1)
          (fN_sq_intervalIntegrable N v)
          (intervalIntegrable_const)
          (fun x _ => fN_sq_le_l1_sq N v x)
    _ = (∑ j : Fin N, |v j|) ^ 2 := by
        rw [intervalIntegral.integral_const]; simp

-- ════════════════════════════════════════════════
-- §9. TIGHTER BOUND: Cauchy-Schwarz
-- ════════════════════════════════════════════════

/-- vᵀGv ≤ N · Σ vⱼ² (Cauchy-Schwarz applied to the L¹ bound). -/
theorem gramQuadForm_le_N_mul_l2_sq (N : ℕ) (v : Fin N → ℝ) :
    gramQuadForm N v ≤ N * ∑ j : Fin N, v j ^ 2 := by
  calc gramQuadForm N v
      ≤ (∑ j : Fin N, |v j|) ^ 2 := gramQuadForm_le_l1_sq N v
    _ ≤ N * ∑ j : Fin N, v j ^ 2 := by
        -- Use Cauchy-Schwarz: (Σ fᵢgᵢ)² ≤ (Σ fᵢ²)(Σ gᵢ²)
        -- with fᵢ = |vⱼ|, gᵢ = 1
        have h_cs := Finset.sum_mul_sq_le_sq_mul_sq (Finset.univ : Finset (Fin N))
          (fun j => |v j|) (fun _ => (1:ℝ))
        simp only [mul_one, one_pow, Finset.sum_const, Finset.card_univ,
          Fintype.card_fin, nsmul_eq_mul, sq_abs] at h_cs
        linarith

-- ════════════════════════════════════════════════
-- §10. PER-SEGMENT STRUCTURE
-- ════════════════════════════════════════════════

/-- On (1/(j·(m+1)), 1/(j·m)], {1/(jx)} = 1/(jx) - m. -/
theorem h_on_segment (j m : ℕ) (hj : 1 ≤ j) (x : ℝ)
    (hx_lo : 1 / ((j : ℝ) * ((m : ℝ) + 1)) < x)
    (hx_hi : x ≤ 1 / ((j : ℝ) * (m : ℝ))) (hm : 1 ≤ m) :
    h j x = 1 / ((j : ℝ) * x) - (m : ℝ) := by
  unfold h
  have hj_pos : (0 : ℝ) < (j : ℝ) := Nat.cast_pos.mpr (by omega)
  have hm_pos : (0 : ℝ) < (m : ℝ) := Nat.cast_pos.mpr (by omega)
  have hm1_pos : (0 : ℝ) < (m : ℝ) + 1 := by linarith
  have hx_pos : 0 < x := by linarith [div_pos (one_pos) (mul_pos hj_pos hm1_pos)]
  have hjx_pos : 0 < (j : ℝ) * x := mul_pos hj_pos hx_pos
  -- 1/(jx) ≥ m (from x ≤ 1/(jm))
  have h_lo : (m : ℝ) ≤ 1 / ((j : ℝ) * x) := by
    rw [le_div_iff₀ hjx_pos]
    -- Need: m·j·x ≤ 1. From hx_hi: x ≤ 1/(jm), so j·x ≤ 1/m, so m·(j·x) ≤ 1.
    have hjx_le : (j : ℝ) * x ≤ 1 / (m : ℝ) := by
      have h1 : (j : ℝ) * x ≤ (j : ℝ) * (1 / ((j : ℝ) * (m : ℝ))) :=
        mul_le_mul_of_nonneg_left hx_hi hj_pos.le
      have h2 : (j : ℝ) * (1 / ((j : ℝ) * (m : ℝ))) = 1 / (m : ℝ) := by field_simp
      linarith
    calc (m : ℝ) * ((j : ℝ) * x) ≤ (m : ℝ) * (1 / (m : ℝ)) :=
          mul_le_mul_of_nonneg_left hjx_le hm_pos.le
      _ = 1 := by field_simp
  -- 1/(jx) < m + 1 (from x > 1/(j(m+1)))
  have h_hi : 1 / ((j : ℝ) * x) < (m : ℝ) + 1 := by
    rw [div_lt_iff₀ hjx_pos]
    have hjx_gt : (j : ℝ) * (1 / ((j : ℝ) * ((m : ℝ) + 1))) < (j : ℝ) * x :=
      mul_lt_mul_of_pos_left hx_lo hj_pos
    have h1 : (j : ℝ) * (1 / ((j : ℝ) * ((m : ℝ) + 1))) = 1 / ((m : ℝ) + 1) := by field_simp
    have hjx_gt' : 1 / ((m : ℝ) + 1) < (j : ℝ) * x := by linarith
    calc 1 = ((m : ℝ) + 1) * (1 / ((m : ℝ) + 1)) := by field_simp
      _ < ((m : ℝ) + 1) * ((j : ℝ) * x) :=
        mul_lt_mul_of_pos_left hjx_gt' hm1_pos
  -- ⌊1/(jx)⌋ = m
  have h_floor : ⌊1 / ((j : ℝ) * x)⌋ = (m : ℤ) := by
    apply le_antisymm
    · -- ⌊1/(jx)⌋ ≤ m: since 1/(jx) < m+1, ⌊⌋ ≤ 1/(jx) < m+1, so ⌊⌋ ≤ m
      have h1 : (⌊1 / ((j : ℝ) * x)⌋ : ℝ) ≤ 1 / ((j : ℝ) * x) := Int.floor_le _
      have h2 : (⌊1 / ((j : ℝ) * x)⌋ : ℝ) < (m : ℝ) + 1 := lt_of_le_of_lt h1 h_hi
      rw [show (m : ℝ) + 1 = ((m + 1 : ℕ) : ℝ) from by push_cast; ring] at h2
      have h3 : ⌊1 / ((j : ℝ) * x)⌋ < (m + 1 : ℕ) := by exact_mod_cast h2
      omega
    · -- m ≤ ⌊1/(jx)⌋: since m ≤ 1/(jx)
      exact Int.le_floor.mpr (by exact_mod_cast h_lo)
  rw [Int.fract, h_floor]
  push_cast; ring

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

/-!
## Audit — IntegralQuadForm (May 27, 2026)

### Architecture

```
         f_N(x) = Σ vⱼ · {1/(jx)}
              ↓
  gramQuadForm_eq_integral: vᵀGv = ∫₀¹ f_N² dx
         ↓               ↓                ↓
  gramQuadForm_nonneg   gramQuadForm_le_l1_sq   h_on_segment
  (positivity)          (‖v‖₁² bound)           (per-segment structure)
                           ↓
              gramQuadForm_le_N_mul_l2_sq
              (N · ‖v‖₂² bound via Cauchy-Schwarz)
```
-/

end Cathedral.IntegralBasis.IntegralQuadForm
