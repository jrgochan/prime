import Cathedral.Zeta.DirichletInverse
import Mathlib.NumberTheory.LSeries.HurwitzZetaValues
import Mathlib.NumberTheory.ZetaValues

/-!
  # The Basel-Möbius Connection

  ## Σ μ(d)/d² = 6/π² = 1/ζ(2)

  ════════════════════════════════════════════════════════════════

  This file connects Euler's Basel problem (1734) to the Möbius function:

    Σ_{d=1}^∞ μ(d)/d² = 6/π²

  The proof chain:
  1. `hasSum_zeta_two` (Mathlib): Σ 1/n² = π²/6
  2. `riemannZeta_two` (Mathlib): ζ(2) = π²/6 (complex version)
  3. `moebius_lseries_eq_inv_zeta` (Cathedral): L(μ,s) = 1/ζ(s) for Re(s)>1
  4. Specialize to s=2: L(μ,2) = 1/ζ(2) = 6/π²

  ## Status
  All theorems PROVED. Zero sorry. Zero warnings.

  ## Dependencies
  - Cathedral.Zeta.DirichletInverse
  - Mathlib.NumberTheory.LSeries.HurwitzZetaValues
  - Mathlib.NumberTheory.ZetaValues

  Created: May 14, 2026 — Squarefree Axiom Graduation Campaign
-/

noncomputable section
open Complex Real ArithmeticFunction BigOperators Finset
open scoped LSeries.notation ArithmeticFunction.Moebius

namespace Cathedral.NumberTheory.BaselMoebius

-- ════════════════════════════════════════════════════════════════
-- §1. L(μ, 2) = 6/π² (complex)
-- ════════════════════════════════════════════════════════════════

/-- `Re(2) > 1`, the hypothesis for convergence. -/
private lemma two_re_gt_one : (1 : ℝ) < (2 : ℂ).re := by norm_num

/-- **THEOREM**: L(μ, 2) = 6/π² as complex numbers.

    Chain: moebius_lseries_eq_inv_zeta at s=2, then riemannZeta_two. -/
theorem moebius_lseries_at_two :
    LSeries (↗μ) 2 = (6 : ℂ) / (↑π) ^ 2 := by
  rw [Cathedral.Zeta.moebius_lseries_eq_inv_zeta two_re_gt_one]
  rw [riemannZeta_two]
  -- Goal: 1 / (↑π ^ 2 / 6) = 6 / ↑π ^ 2
  have hpi : (↑π : ℂ) ^ 2 ≠ 0 := by
    apply pow_ne_zero; exact_mod_cast Real.pi_ne_zero
  field_simp

-- ════════════════════════════════════════════════════════════════
-- §2. REAL PARTIAL SUMS
-- ════════════════════════════════════════════════════════════════

/-- The real partial sum Σ_{d=1}^{N} μ(d)/d². -/
def moebiusSqPartialSum (N : ℕ) : ℝ :=
  ∑ d ∈ Icc 1 N, (↑(μ d) : ℝ) / (d : ℝ) ^ 2

/-- **THEOREM**: The partial sums are bounded by 2.

    |Σ_{d≤N} μ(d)/d²| ≤ Σ_{d≤N} 1/d² ≤ ζ(2) = π²/6 < 2.
    Proof: Each |μ(d)/d²| ≤ 1/d², and the series converges to π²/6 < 2. -/
theorem moebiusSqPartialSum_abs_le (N : ℕ) :
    |moebiusSqPartialSum N| ≤ 2 := by
  unfold moebiusSqPartialSum
  -- Step 1: |Σ μ(d)/d²| ≤ Σ |μ(d)/d²| ≤ Σ 1/d²
  calc |∑ d ∈ Icc 1 N, (↑(μ d) : ℝ) / (d : ℝ) ^ 2|
      ≤ ∑ d ∈ Icc 1 N, |(↑(μ d) : ℝ) / (d : ℝ) ^ 2| :=
        Finset.abs_sum_le_sum_abs _ _
    _ ≤ ∑ d ∈ Icc 1 N, 1 / (d : ℝ) ^ 2 := by
        apply Finset.sum_le_sum; intro d hd
        rw [abs_div, abs_of_nonneg (sq_nonneg (d : ℝ))]
        apply div_le_div_of_nonneg_right _ (sq_nonneg _)
        exact_mod_cast abs_moebius_le_one
    _ ≤ 2 := by
        -- Convert 1/d² to (d²)⁻¹ and use sum_Ioo_inv_sq_le
        have h_eq : ∀ d ∈ Icc 1 N, (1:ℝ) / (d : ℝ) ^ 2 = ((d : ℝ) ^ 2)⁻¹ := by
          intro d _; rw [one_div]
        rw [Finset.sum_congr rfl h_eq]
        -- Icc 1 N ⊆ Ioo 0 (N+1) for ℕ
        have h_sub : Icc 1 N ⊆ Ioo 0 (N + 1) := by
          intro d hd; simp only [mem_Icc] at hd; simp only [mem_Ioo]; omega
        apply le_trans (Finset.sum_le_sum_of_subset_of_nonneg h_sub
          (fun d _ _ => inv_nonneg.mpr (sq_nonneg _)))
        calc ∑ i ∈ Ioo 0 (N + 1), ((i : ℝ) ^ 2)⁻¹
            ≤ 2 / ((0 : ℕ) + 1 : ℝ) := sum_Ioo_inv_sq_le 0 (N + 1)
          _ = 2 := by norm_num

-- ════════════════════════════════════════════════════════════════
-- §3. TAIL BOUND
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: The tail Σ_{d>N} μ(d)/d² has absolute value ≤ 2/N.

    Chain: |∑' μ/d²| ≤ ∑' ‖μ/d²‖ ≤ ∑' 1/d² ≤ 2/(N+1) ≤ 2/N.
    The last step uses `sum_Ioo_inv_sq_le` from Mathlib.Analysis.PSeries. -/
theorem moebiusSqTail_le (N : ℕ) (hN : 1 ≤ N) :
    |∑' d : {d : ℕ // N < d}, (↑(μ (d : ℕ)) : ℝ) / ((d : ℕ) : ℝ) ^ 2| ≤ 2 / ↑N := by
  have hN_pos : (0 : ℝ) < ↑N := Nat.cast_pos.mpr (by omega)
  -- ── Summability infrastructure ──
  have h_base : Summable (fun n : ℕ => (1 : ℝ) / (n : ℝ) ^ 2) :=
    hasSum_zeta_two.summable
  have h_sub : Summable (fun d : {d : ℕ // N < d} =>
      (1 : ℝ) / ((d : ℕ) : ℝ) ^ 2) :=
    h_base.comp_injective Subtype.val_injective
  have h_mu : Summable (fun d : {d : ℕ // N < d} =>
      (↑(μ (d : ℕ)) : ℝ) / ((d : ℕ) : ℝ) ^ 2) :=
    Summable.of_norm_bounded h_sub (fun ⟨d, _⟩ => by
      rw [norm_div, norm_pow, Real.norm_natCast]
      apply div_le_div_of_nonneg_right _ (pow_nonneg (Nat.cast_nonneg _) _)
      rw [Real.norm_eq_abs, ← Int.cast_abs]
      exact_mod_cast abs_moebius_le_one)
  -- ── Tail bound: ∑'_{d>N} 1/d² ≤ 2/N ──
  have h_tail : ∑' d : {d : ℕ // N < d}, (1 : ℝ) / ((d : ℕ) : ℝ) ^ 2 ≤ 2 / ↑N := by
    -- Reindex via ℕ ≃ {d // N < d}, k ↦ k + (N+1)
    let φ : ℕ ≃ {d : ℕ // N < d} :=
      { toFun := fun k => ⟨k + (N + 1), by omega⟩
        invFun := fun d => (d : ℕ) - (N + 1)
        left_inv := fun k => by simp
        right_inv := fun ⟨d, hd⟩ => by ext; simp; omega }
    rw [(φ.tsum_eq (fun d : {d // N < d} => (1 : ℝ) / ((d : ℕ) : ℝ) ^ 2)).symm]
    simp only [φ]
    apply Real.tsum_le_of_sum_range_le (fun k => by positivity)
    intro n
    calc ∑ k ∈ Finset.range n, (1 : ℝ) / ((↑(k + (N + 1)) : ℝ)) ^ 2
        = ∑ k ∈ Finset.range n, ((↑(k + (N + 1)) : ℝ) ^ 2)⁻¹ := by
          congr 1; ext k; rw [one_div]
      _ = ∑ d ∈ (Finset.range n).image (· + (N + 1)), ((d : ℝ) ^ 2)⁻¹ := by
          rw [Finset.sum_image (fun a _ b _ (hab : a + (N+1) = b + (N+1)) => by omega)]
      _ ≤ ∑ d ∈ Ioo N (n + N + 1), ((d : ℝ) ^ 2)⁻¹ := by
          apply Finset.sum_le_sum_of_subset_of_nonneg
          · intro d hd
            simp only [Finset.mem_image, Finset.mem_range] at hd
            obtain ⟨k, hk, rfl⟩ := hd
            simp only [Finset.mem_Ioo]; omega
          · intro _ _ _; positivity
      _ ≤ 2 / ((N : ℝ) + 1) := sum_Ioo_inv_sq_le N (n + N + 1)
      _ ≤ 2 / ↑N := by
          apply div_le_div_of_nonneg_left (by positivity : (0:ℝ) ≤ 2) hN_pos
          linarith
  -- ── Main chain: |∑' μ/d²| ≤ ∑' ‖μ/d²‖ ≤ ∑' 1/d² ≤ 2/N ──
  have h_norm : Summable (fun d : {d : ℕ // N < d} =>
      ‖(↑(μ (d : ℕ)) : ℝ) / ((d : ℕ) : ℝ) ^ 2‖) :=
    summable_norm_iff.mpr h_mu
  -- ‖∑' f‖ ≤ ∑' ‖f‖
  have step1 : ‖∑' d : {d : ℕ // N < d}, (↑(μ (d : ℕ)) : ℝ) / ((d : ℕ) : ℝ) ^ 2‖ ≤
      ∑' d : {d : ℕ // N < d}, ‖(↑(μ (d : ℕ)) : ℝ) / ((d : ℕ) : ℝ) ^ 2‖ :=
    norm_tsum_le_tsum_norm h_norm
  -- ∑' ‖f‖ ≤ ∑' 1/d²
  have step2 : ∑' d : {d : ℕ // N < d}, ‖(↑(μ (d : ℕ)) : ℝ) / ((d : ℕ) : ℝ) ^ 2‖ ≤
      ∑' d : {d : ℕ // N < d}, (1 : ℝ) / ((d : ℕ) : ℝ) ^ 2 := by
    apply h_norm.tsum_le_tsum _ h_sub
    intro ⟨d, _⟩
    rw [norm_div, norm_pow, Real.norm_natCast]
    apply div_le_div_of_nonneg_right _ (pow_nonneg (Nat.cast_nonneg _) _)
    rw [Real.norm_eq_abs, ← Int.cast_abs]
    exact_mod_cast abs_moebius_le_one
  rw [Real.norm_eq_abs] at step1
  linarith

-- ════════════════════════════════════════════════════════════════
-- §4. ℂ→ℝ BRIDGE: Real HasSum from LSeries
-- ════════════════════════════════════════════════════════════════

/-- Each LSeries term at s=2 equals the real Möbius quotient cast to ℂ. -/
private lemma term_eq_ofReal (n : ℕ) :
    LSeries.term (↗μ) 2 n = ↑((↑(μ n) : ℝ) / ((n : ℝ)) ^ 2) := by
  by_cases hn : n = 0
  · simp [hn, LSeries.term, ArithmeticFunction.map_zero]
  · simp [LSeries.term, hn]

/-- The LSeries value at s=2 as a real-cast complex number. -/
private lemma lseries_val_ofReal :
    LSeries (↗μ) 2 = ↑((6 : ℝ) / π ^ 2) := by
  rw [Cathedral.Zeta.moebius_lseries_eq_inv_zeta two_re_gt_one, riemannZeta_two]
  push_cast [Complex.ofReal_div]; field_simp

/-- **LEMMA**: The real sum μ(n)/n² is summable.

    Bridge from `LSeriesSummable (↗μ) 2` via `hasSum_ofReal`. -/
lemma summable_moebius_div_sq :
    Summable (fun n : ℕ => (↑(μ n) : ℝ) / ((n : ℝ)) ^ 2) := by
  have hls : LSeriesSummable (↗μ) 2 :=
    LSeriesSummable_moebius_iff.mpr (by norm_num : (1:ℝ) < (2:ℂ).re)
  have h : (fun n => (↑((↑(μ n) : ℝ) / ((n : ℝ)) ^ 2) : ℂ)) = LSeries.term (↗μ) 2 := by
    ext n; exact (term_eq_ofReal n).symm
  exact Complex.summable_ofReal.mp (h ▸ hls)

/-- **LEMMA**: ∑' n, μ(n)/n² has sum 6/π² (real HasSum).

    Chain: `hasSum_ofReal` ← `LSeriesSummable.hasSum` ← `moebius_lseries_at_two`. -/
lemma real_hasSum_moebius_div_sq :
    HasSum (fun n : ℕ => (↑(μ n) : ℝ) / ((n : ℝ)) ^ 2) (6 / π ^ 2) := by
  rw [← Complex.hasSum_ofReal]
  have h : (fun n => (↑((↑(μ n) : ℝ) / ((n : ℝ)) ^ 2) : ℂ)) = LSeries.term (↗μ) 2 := by
    ext n; exact (term_eq_ofReal n).symm
  rw [h]
  convert (LSeriesSummable_moebius_iff.mpr
    (by norm_num : (1:ℝ) < (2:ℂ).re)).hasSum using 1
  exact lseries_val_ofReal.symm

/-- **LEMMA**: ∑' n, μ(n)/n² = 6/π² (real tsum). -/
theorem tsum_moebius_div_sq :
    ∑' n, (↑(μ n) : ℝ) / ((n : ℝ)) ^ 2 = 6 / π ^ 2 :=
  real_hasSum_moebius_div_sq.tsum_eq

/-- Splitting: ∑_{i<N+1} f(i) = ∑_{d ∈ Icc 1 N} f(d), since f(0) = 0. -/
private lemma sum_range_eq_partial (N : ℕ) :
    ∑ i ∈ Finset.range (N + 1), (↑(μ i) : ℝ) / ((i : ℝ)) ^ 2 =
    ∑ d ∈ Icc 1 N, (↑(μ d) : ℝ) / (d : ℝ) ^ 2 := by
  rw [Finset.sum_range_succ']
  simp only [ArithmeticFunction.map_zero, Int.cast_zero, zero_div, add_zero]
  conv_rhs => rw [show Icc 1 N = (Finset.range N).map
      ⟨(· + 1), Nat.succ_injective⟩ from by
    ext x; simp [Finset.mem_Icc, Finset.mem_range, Finset.mem_map]; constructor
    · intro ⟨h1, h2⟩; exact ⟨x - 1, by omega, by omega⟩
    · rintro ⟨a, ha, rfl⟩; omega]
  rw [Finset.sum_map]; simp

/-- Reindexing: shifted tsum ∑' k, f(k+N+1) = subtype tsum ∑'_{d>N} f(d). -/
private lemma tail_eq_subtype (N : ℕ) :
    ∑' k, (↑(μ (k + (N + 1))) : ℝ) / ((k + (N + 1) : ℕ) : ℝ) ^ 2 =
    ∑' d : {d : ℕ // N < d}, (↑(μ (d : ℕ)) : ℝ) / ((d : ℕ) : ℝ) ^ 2 := by
  let φ : ℕ ≃ {d : ℕ // N < d} :=
    { toFun := fun k => ⟨k + (N + 1), by omega⟩
      invFun := fun d => (d : ℕ) - (N + 1)
      left_inv := fun k => by simp
      right_inv := fun ⟨d, hd⟩ => by ext; simp; omega }
  rw [← φ.tsum_eq]; congr

-- ════════════════════════════════════════════════════════════════
-- §5. THE KEY THEOREM: PARTIAL SUM LOWER BOUND
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: Σ_{d=1}^{N} μ(d)/d² ≥ 6/π² − 2/N for N ≥ 1.

    The partial sum approaches 6/π² from below (roughly),
    with an error bounded by the tail 2/N.

    Proof: Split ∑' μ/d² = partial + tail via `sum_add_tsum_nat_add`,
    then use `moebiusSqTail_le` to bound `|tail| ≤ 2/N`.

    This is the key ingredient for the squarefree counting function. -/
theorem moebiusSqPartialSum_lower (N : ℕ) (hN : 1 ≤ N) :
    6 / π ^ 2 - 2 / ↑N ≤ moebiusSqPartialSum N := by
  unfold moebiusSqPartialSum
  set f := fun n : ℕ => (↑(μ n) : ℝ) / ((n : ℝ)) ^ 2
  -- ── Splitting: partial + tail = 6/π² ──
  have h_split := summable_moebius_div_sq.sum_add_tsum_nat_add (N + 1)
  rw [tsum_moebius_div_sq] at h_split
  -- ── partial = 6/π² - tail ──
  have h_partial : ∑ i ∈ Finset.range (N + 1), f i =
      6 / π ^ 2 - ∑' k, f (k + (N + 1)) := by linarith
  rw [← sum_range_eq_partial N, h_partial]
  -- ── |tail| ≤ 2/N via moebiusSqTail_le ──
  have h_tail := moebiusSqTail_le N hN
  rw [← tail_eq_subtype N] at h_tail
  change |∑' k, f (k + (N + 1))| ≤ 2 / ↑N at h_tail
  -- ── Conclude: 6/π² - 2/N ≤ 6/π² - tail ──
  linarith [le_abs_self (∑' k, f (k + (N + 1)))]

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit (updated May 22, 2026)

### Sorry Count: 0 ✅

### PROVED:
| # | Result | Status |
|---|--------|--------|
| 1 | `moebius_lseries_at_two` | **🎓 THEOREM** (L(μ,2) = 6/π², complex) |
| 2 | `moebiusSqPartialSum_abs_le` | **🎓 THEOREM** (|partial sum| ≤ 2) |
| 3 | `moebiusSqTail_le` | **🎓 THEOREM** (|tail| ≤ 2/N) |
| 4 | `summable_moebius_div_sq` | **🎓 LEMMA** (real summability) |
| 5 | `real_hasSum_moebius_div_sq` | **🎓 LEMMA** (real HasSum = 6/π²) |
| 6 | `tsum_moebius_div_sq` | **🎓 THEOREM** (∑' μ/d² = 6/π², real) |
| 7 | `moebiusSqPartialSum_lower` | **🎓 THEOREM** (partial sum ≥ 6/π² - 2/N) |
| 8 | `moebiusSqPartialSum` | **📐 DEFINITION** |

### Architecture
- **§1**: Complex LSeries value via `moebius_lseries_eq_inv_zeta` + `riemannZeta_two`
- **§2**: Partial sum bounds via `abs_moebius_le_one` + `sum_Ioo_inv_sq_le`
- **§3**: Tail bound via norm chain + `Equiv.tsum_eq` reindexing
- **§4**: ℂ→ℝ bridge via `hasSum_ofReal` + `summable_ofReal`
- **§5**: Lower bound via `sum_add_tsum_nat_add` splitting + tail bound
-/

end Cathedral.NumberTheory.BaselMoebius

end
