/-
  Cathedral/Physics/SmithSpectralGap.lean

  THE SMITH SPECTRAL GAP: G⁽²⁾ is Positive Definite

  All proofs are parameterized by a base offset b ≥ 1, giving both
  the +2 version (for Smith's original theorem) and the +1 version
  (for the GlassComparison indexing convention).

  Dependencies: DarkGramMatrix (Smith PSD, Jordan totient)
  Created: May 15, 2026
-/

import Cathedral.Gram.DarkGramMatrix

noncomputable section
open Real Finset Cathedral.Gram.DarkGramMatrix

namespace Cathedral.Physics.GramWiring.SmithSpectralGap

-- ════════════════════════════════════════════════════════════════
-- §1. GENERALIZED DIVISOR TRANSFORM (base offset b)
-- ════════════════════════════════════════════════════════════════

/-- Generalized divisor sum with base offset b: y_d = Σ_{i: d|(i+b)} z_i -/
noncomputable def divisorSumB (N b : ℕ) (z : Fin N → ℝ) (d : ℕ) : ℝ :=
  ∑ i : Fin N, if d ∣ (i.val + b) then z i else 0

/-- If z_j = 0 for all j > i, then divisorSumB at d = i+b equals z_i.
    Works for any base b ≥ 1 because the divisor matrix is upper triangular. -/
theorem divisor_sum_self_gen (N b : ℕ) (hb : 1 ≤ b) (z : Fin N → ℝ) (i : Fin N)
    (hz_high : ∀ j : Fin N, i.val < j.val → z j = 0) :
    divisorSumB N b z (i.val + b) = z i := by
  unfold divisorSumB
  have hother : ∀ j : Fin N, j ≠ i →
      (if (i.val + b) ∣ (j.val + b) then z j else 0) = 0 := by
    intro j hj
    split_ifs with hdvd
    · have hne : j.val ≠ i.val := fun h => hj (Fin.ext h)
      have hgt : i.val < j.val := by
        obtain ⟨c, hc⟩ := hdvd
        have : c ≠ 1 := by intro heq; rw [heq, mul_one] at hc; exact hne (by omega)
        have : 0 < c := by nlinarith
        have : 2 ≤ c := by omega
        nlinarith
      exact hz_high j hgt
    · rfl
  rw [Finset.sum_eq_single_of_mem i (Finset.mem_univ i) (fun j _ hj => hother j hj)]
  simp [dvd_refl]

-- ════════════════════════════════════════════════════════════════
-- §2. GENERALIZED TRIANGULAR INJECTIVITY
-- ════════════════════════════════════════════════════════════════

/-- The generalized divisor transform is injective for any base b ≥ 1. -/
theorem divisor_transform_injective_gen (N b : ℕ) (hb : 1 ≤ b) (z : Fin N → ℝ)
    (hy : ∀ d, b ≤ d → d ≤ N - 1 + b → divisorSumB N b z d = 0) :
    z = 0 := by
  have key : ∀ i : Fin N, (∀ j : Fin N, i.val < j.val → z j = 0) → z i = 0 := by
    intro i hz_high
    have h1 := divisor_sum_self_gen N b hb z i hz_high
    have h2 := hy (i.val + b) (by omega) (by omega)
    linarith
  ext ⟨k, hk⟩; simp only [Pi.zero_apply]
  suffices ∀ gap m (hm : m < N), m + gap = N → z ⟨m, hm⟩ = 0 by
    exact this (N - k) k hk (by omega)
  intro gap
  induction gap using Nat.strongRecOn with
  | _ gap ih =>
    intro m hm heq
    apply key ⟨m, hm⟩
    intro j hjgt
    have hj_le_N : j.val ≤ N := by omega
    have hgap' : N - j.val < gap := by
      calc N - j.val < N - m := Nat.sub_lt_sub_left (by omega) hjgt
        _ = gap := by omega
    exact ih (N - j.val) hgap' j.val j.isLt (Nat.add_sub_cancel' hj_le_N)

-- ════════════════════════════════════════════════════════════════
-- §3. SPECIALIZED VERSIONS (b = 2)
-- ════════════════════════════════════════════════════════════════

/-- divisorSum with base 2 (original Smith form). -/
noncomputable def divisorSum (N : ℕ) (z : Fin N → ℝ) (d : ℕ) : ℝ := divisorSumB N 2 z d

theorem divisor_transform_injective (N : ℕ) (z : Fin N → ℝ)
    (hy : ∀ d, 2 ≤ d → d ≤ N + 1 → divisorSum N z d = 0) :
    z = 0 := by
  rcases N with _ | n
  · exact funext (fun i => i.elim0)
  · apply divisor_transform_injective_gen (n + 1) 2 (by omega) z
    intro d hd_ge hd_le
    exact hy d hd_ge (by omega)

-- ════════════════════════════════════════════════════════════════
-- §4. SMITH IDENTITY (b = 2, extracted from smith_gcd_matrix_psd)
-- ════════════════════════════════════════════════════════════════

set_option linter.unnecessarySeqFocus false in
set_option maxHeartbeats 400000 in
theorem smith_gcd_identity (N : ℕ) (z : Fin N → ℝ) :
    ∑ i : Fin N, ∑ j : Fin N,
      (Nat.gcd (i.val + 2) (j.val + 2) : ℝ) ^ 4 * z i * z j =
    ∑ d ∈ Finset.Icc 1 (N + 1), jordanTotient4 d * (divisorSum N z d) ^ 2 := by
  simp only [divisorSum, divisorSumB]
  have ysq : ∀ d, (∑ i : Fin N, if d ∣ (i.val + 2) then z i else 0) ^ 2 =
      ∑ i : Fin N, ∑ j : Fin N,
        (if d ∣ (i.val + 2) then z i else 0) * (if d ∣ (j.val + 2) then z j else 0) := by
    intro d; rw [sq]; exact Fintype.sum_mul_sum _ _
  simp_rw [ysq, Finset.mul_sum]
  rw [Finset.sum_comm (s := Finset.Icc 1 (N + 1)) (t := Finset.univ)]
  simp_rw [Finset.sum_comm (s := Finset.Icc 1 (N + 1)) (t := Finset.univ)]
  congr 1; ext i; congr 1; ext j
  rw [show (Nat.gcd (i.val + 2) (j.val + 2) : ℝ) ^ 4 * z i * z j =
    (∑ d ∈ (Nat.gcd (i.val + 2) (j.val + 2)).divisors, jordanTotient4 d) * z i * z j from by
      rw [jordan_dirichlet_identity _ (Nat.gcd_pos_of_pos_left _ (by omega))]]
  rw [jordan_sum_as_filter (i.val + 2) (j.val + 2) (by omega) (by omega)
      (Finset.Icc 1 (N + 1))
      (fun d hd => by
        rw [Finset.mem_Icc]
        exact ⟨Nat.pos_of_mem_divisors hd,
          by have := Nat.le_of_dvd (by omega)
              (dvd_trans (Nat.dvd_of_mem_divisors hd) (Nat.gcd_dvd_left _ _)); omega⟩)]
  rw [Finset.sum_mul, Finset.sum_mul]
  congr 1; ext d
  split_ifs <;> simp_all <;> ring

-- ════════════════════════════════════════════════════════════════
-- §5. STRICT POSITIVITY (b = 2)
-- ════════════════════════════════════════════════════════════════

theorem smith_gcd_matrix_pd (N : ℕ) (z : Fin N → ℝ) (hz : z ≠ 0) :
    0 < ∑ i : Fin N, ∑ j : Fin N,
      (Nat.gcd (i.val + 2) (j.val + 2) : ℝ) ^ 4 * z i * z j := by
  rw [smith_gcd_identity]
  by_contra hle
  simp only [not_lt] at hle
  have hge : 0 ≤ ∑ d ∈ Finset.Icc 1 (N + 1), jordanTotient4 d * (divisorSum N z d) ^ 2 :=
    Finset.sum_nonneg fun d hd =>
      mul_nonneg (le_of_lt (jordan_totient4_pos d (by rw [Finset.mem_Icc] at hd; omega)))
        (sq_nonneg _)
  have heq := le_antisymm hle hge
  have hterms :=
    (Finset.sum_eq_zero_iff_of_nonneg (fun d hd =>
      mul_nonneg (le_of_lt (jordan_totient4_pos d (by rw [Finset.mem_Icc] at hd; omega)))
        (sq_nonneg _))).mp heq
  have hdiv_zero : ∀ d, 2 ≤ d → d ≤ N + 1 → divisorSum N z d = 0 := by
    intro d hd_ge hd_le
    have h0 := hterms d (Finset.mem_Icc.mpr ⟨by omega, hd_le⟩)
    exact eq_zero_of_pow_eq_zero
      ((mul_eq_zero.mp h0).resolve_left (ne_of_gt (jordan_totient4_pos d (by omega))))
  exact hz (divisor_transform_injective N z hdiv_zero)

-- ════════════════════════════════════════════════════════════════
-- §6. DARK GRAM STRICT POSITIVITY
-- ════════════════════════════════════════════════════════════════

theorem dark_gram_strict_positivity (N : ℕ) (x : Fin N → ℝ) (hx : x ≠ 0) :
    0 < ∑ i : Fin N, ∑ j : Fin N,
      darkGramEntry_n2 (i.val + 2) (j.val + 2) * x i * x j := by
  set z : Fin N → ℝ := fun i => x i / ((i.val + 2 : ℝ) ^ 2)
  have hz_ne : z ≠ 0 := by
    intro h; apply hx; ext i
    have := congr_fun h i; simp only [Pi.zero_apply] at this
    exact (div_eq_zero_iff.mp this).resolve_right (by positivity)
  have hconv : ∀ (i j : Fin N),
      darkGramEntry_n2 (i.val + 2) (j.val + 2) * x i * x j =
      (1 / 180) * ((Nat.gcd (i.val + 2) (j.val + 2) : ℝ) ^ 4 * z i * z j) := by
    intro i j; unfold darkGramEntry_n2; simp only [z]
    rw [show (i.val + 2 : ℝ) = ((i.val + 2 : ℕ) : ℝ) from by push_cast; ring]
    rw [show (j.val + 2 : ℝ) = ((j.val + 2 : ℕ) : ℝ) from by push_cast; ring]
    have : ((i.val + 2 : ℕ) : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
    have : ((j.val + 2 : ℕ) : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
    field_simp
  simp_rw [hconv, ← Finset.mul_sum]
  exact mul_pos (by norm_num) (smith_gcd_matrix_pd N z hz_ne)

-- ════════════════════════════════════════════════════════════════
-- §7. DARK SPECTRAL GAP (+1 offset)
-- ════════════════════════════════════════════════════════════════

set_option linter.unnecessarySeqFocus false in
set_option maxHeartbeats 400000 in
theorem smith_gcd_identity1 (N : ℕ) (z : Fin N → ℝ) :
    ∑ i : Fin N, ∑ j : Fin N,
      (Nat.gcd (i.val + 1) (j.val + 1) : ℝ) ^ 4 * z i * z j =
    ∑ d ∈ Finset.Icc 1 N, jordanTotient4 d * (divisorSumB N 1 z d) ^ 2 := by
  have ysq : ∀ d, (divisorSumB N 1 z d) ^ 2 =
      ∑ i : Fin N, ∑ j : Fin N,
        (if d ∣ (i.val + 1) then z i else 0) * (if d ∣ (j.val + 1) then z j else 0) := by
    intro d; rw [sq]; simp only [divisorSumB]; exact Fintype.sum_mul_sum _ _
  simp_rw [ysq, Finset.mul_sum]
  rw [Finset.sum_comm (s := Finset.Icc 1 N) (t := Finset.univ)]
  simp_rw [Finset.sum_comm (s := Finset.Icc 1 N) (t := Finset.univ)]
  congr 1; ext i; congr 1; ext j
  rw [show (Nat.gcd (i.val + 1) (j.val + 1) : ℝ) ^ 4 * z i * z j =
    (∑ d ∈ (Nat.gcd (i.val + 1) (j.val + 1)).divisors, jordanTotient4 d) * z i * z j from by
      rw [jordan_dirichlet_identity _ (Nat.gcd_pos_of_pos_left _ (by omega))]]
  rw [jordan_sum_as_filter (i.val + 1) (j.val + 1) (by omega) (by omega)
      (Finset.Icc 1 N)
      (fun d hd => by
        rw [Finset.mem_Icc]
        exact ⟨Nat.pos_of_mem_divisors hd,
          by have := Nat.le_of_dvd (by omega)
              (dvd_trans (Nat.dvd_of_mem_divisors hd) (Nat.gcd_dvd_left _ _)); omega⟩)]
  rw [Finset.sum_mul, Finset.sum_mul]
  congr 1; ext d
  split_ifs <;> simp_all <;> ring

theorem smith_gcd_matrix_pd1 (N : ℕ) (z : Fin N → ℝ) (hz : z ≠ 0) :
    0 < ∑ i : Fin N, ∑ j : Fin N,
      (Nat.gcd (i.val + 1) (j.val + 1) : ℝ) ^ 4 * z i * z j := by
  rw [smith_gcd_identity1]
  by_contra hle
  simp only [not_lt] at hle
  have hge : 0 ≤ ∑ d ∈ Finset.Icc 1 N, jordanTotient4 d * (divisorSumB N 1 z d) ^ 2 :=
    Finset.sum_nonneg fun d hd =>
      mul_nonneg (le_of_lt (jordan_totient4_pos d (by rw [Finset.mem_Icc] at hd; omega)))
        (sq_nonneg _)
  have heq := le_antisymm hle hge
  have hterms :=
    (Finset.sum_eq_zero_iff_of_nonneg (fun d hd =>
      mul_nonneg (le_of_lt (jordan_totient4_pos d (by rw [Finset.mem_Icc] at hd; omega)))
        (sq_nonneg _))).mp heq
  have hdiv_zero : ∀ d, 1 ≤ d → d ≤ N - 1 + 1 → divisorSumB N 1 z d = 0 := by
    intro d hd_ge hd_le
    have hN_pos : 0 < N := by
      by_contra h; simp only [not_lt] at h; interval_cases N; exact hz (funext (fun i => i.elim0))
    have h0 := hterms d (Finset.mem_Icc.mpr ⟨hd_ge, by omega⟩)
    exact eq_zero_of_pow_eq_zero
      ((mul_eq_zero.mp h0).resolve_left (ne_of_gt (jordan_totient4_pos d (by omega))))
  exact hz (divisor_transform_injective_gen N 1 (by omega) z hdiv_zero)

theorem dark_spectral_gap (N : ℕ) (x : Fin N → ℝ) (hx : x ≠ 0) :
    0 < ∑ i : Fin N, ∑ j : Fin N,
      darkGramEntry_n2 (i.val + 1) (j.val + 1) * x i * x j := by
  set z : Fin N → ℝ := fun i => x i / ((i.val + 1 : ℝ) ^ 2)
  have hz_ne : z ≠ 0 := by
    intro h; apply hx; ext i
    have := congr_fun h i; simp only [Pi.zero_apply] at this
    exact (div_eq_zero_iff.mp this).resolve_right (by positivity)
  have hconv : ∀ (i j : Fin N),
      darkGramEntry_n2 (i.val + 1) (j.val + 1) * x i * x j =
      (1 / 180) * ((Nat.gcd (i.val + 1) (j.val + 1) : ℝ) ^ 4 * z i * z j) := by
    intro i j; unfold darkGramEntry_n2; simp only [z]
    rw [show (i.val + 1 : ℝ) = ((i.val + 1 : ℕ) : ℝ) from by push_cast; ring]
    rw [show (j.val + 1 : ℝ) = ((j.val + 1 : ℕ) : ℝ) from by push_cast; ring]
    have : ((i.val + 1 : ℕ) : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
    have : ((j.val + 1 : ℕ) : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
    field_simp
  simp_rw [hconv, ← Finset.mul_sum]
  exact mul_pos (by norm_num) (smith_gcd_matrix_pd1 N z hz_ne)

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit

### Sorry: 0 🎓

### PROVED
| # | Result | Status |
|---|--------|--------|
| 1 | `divisor_sum_self_gen` | 🎓 PROVED (generalized for base b ≥ 1) |
| 2 | `divisor_transform_injective_gen` | 🎓 PROVED (descending strong induction) |
| 3 | `divisor_transform_injective` | 🎓 PROVED (b = 2 specialization) |
| 4 | `smith_gcd_identity` | 🎓 PROVED (b = 2 Smith identity) |
| 5 | `smith_gcd_matrix_pd` | 🎓 PROVED (b = 2 strict positivity) |
| 6 | `dark_gram_strict_positivity` | 🎓 PROVED (+2 offset) |
| 7 | `smith_gcd_identity1` | 🎓 PROVED (b = 1 Smith identity) |
| 8 | `smith_gcd_matrix_pd1` | 🎓 PROVED (b = 1 strict positivity) |
| 9 | `dark_spectral_gap` | 🎓 PROVED (+1 offset) |

### Custom Axioms: 0
-/

end Cathedral.Physics.GramWiring.SmithSpectralGap

end
