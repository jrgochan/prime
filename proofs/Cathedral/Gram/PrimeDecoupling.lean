/-
  Cathedral/Gram/PrimeDecoupling.lean

  ## Prime/Composite Gram Entry Bounds

  Establishes quantitative bounds on the Gram matrix entries G(j,k)
  decomposed by the prime/composite structure of the indices.

  ### Key Results (PROVED from Vasyunin formula + Mathlib constants)

  **Vasyunin Coefficient Bound (proved):**
    ln(2π) - γ > 5/6  (data-free, from Mathlib bounds on ln(2), π, γ)

  **Diagonal Lower Bound (proved):**
    G(k,k) ≥ 1/(4k) for k ≥ 2  (from Vasyunin + coefficient bound)

  ### Status: 2 theorems graduated from axioms! 🎓
  ### Dependencies: Cathedral.Vasyunin.Defs

  Created: May 12, 2026 (Exploration 36)
  Updated: May 12, 2026 (graduated gram_diag_lower_bound)
-/

import Cathedral.Vasyunin.Defs
import Cathedral.Vasyunin.Witness
import Cathedral.Vasyunin.Augmented.DiagBound
import Cathedral.PNT.PNTAndBridge
import Mathlib.Data.Nat.Prime.Basic
import Mathlib.Analysis.Complex.ExponentialBounds
import Mathlib.Analysis.Real.Pi.Bounds

noncomputable section
open Real Cathedral.Vasyunin

-- ════════════════════════════════════════════════════════
-- §1. THE VASYUNIN COEFFICIENT BOUND (DATA-FREE)
-- ════════════════════════════════════════════════════════

/-- **ln(π) > 1**: since π > 3 > e, we have ln(π) > ln(e) = 1. -/
private lemma log_pi_gt_one : 1 < Real.log π := by
  rw [show (1 : ℝ) = Real.log (Real.exp 1) from (Real.log_exp 1).symm]
  exact Real.log_lt_log (Real.exp_pos 1) (lt_trans Real.exp_one_lt_three Real.pi_gt_three)

/-- **ln(2) > 1/2**: from Mathlib's tight bound ln(2) > 0.693... -/
private lemma log_two_gt_half : (1 : ℝ) / 2 < Real.log 2 := by
  linarith [Real.log_two_gt_d9]

/-- **ln(2π) > 3/2**: from ln(2) > 1/2 and ln(π) > 1. -/
private lemma log_two_pi_gt : (3 : ℝ) / 2 < Real.log (2 * π) := by
  rw [Real.log_mul (by norm_num : (2:ℝ) ≠ 0) (ne_of_gt Real.pi_pos)]
  linarith [log_two_gt_half, log_pi_gt_one]

/-- **THEOREM (graduated 🎓): The Vasyunin diagonal coefficient bound.**

    ln(2π) - γ > 5/6

    Proof: ln(2π) > 3/2 (from ln(2) > 1/2 and ln(π) > 1)
           γ < 2/3 (Mathlib: eulerMascheroniConstant_lt_two_thirds)
           So ln(2π) - γ > 3/2 - 2/3 = 5/6. ∎

    This is a pure numerical fact, proved entirely from Mathlib bounds
    on ln(2), π, and γ. No GPU data. No numerical computation. -/
theorem vasyunin_coeff_gt_five_sixths :
    Real.log (2 * π) - Real.eulerMascheroniConstant > 5 / 6 := by
  linarith [log_two_pi_gt, Real.eulerMascheroniConstant_lt_two_thirds]

/-- Corollary: ln(2π) - γ ≥ 3/4 (weaker but cleaner). -/
theorem vasyunin_coeff_ge_three_quarter :
    Real.log (2 * π) - Real.eulerMascheroniConstant ≥ 3 / 4 := by
  linarith [vasyunin_coeff_gt_five_sixths]

/-- **Upper bound**: ln(2π) - γ < 3/2.
    Since ln(2π) < 2 (proved in DiagBound.lean, re-derived here) and γ > 1/2. -/
private lemma log_two_pi_lt_two : Real.log (2 * π) < 2 := by
  rw [Real.log_lt_iff_lt_exp (by positivity : (0:ℝ) < 2 * π)]
  calc 2 * π < 2 * 3.1416 :=
        mul_lt_mul_of_pos_left Real.pi_lt_d4 (by norm_num)
    _ = 6.2832 := by norm_num
    _ < Real.exp 2 := by
        have h := Real.sum_le_exp_of_nonneg (show (0:ℝ) ≤ 2 by norm_num) 5
        simp only [Finset.sum_range_succ, Nat.factorial] at h
        norm_num at h; linarith

theorem vasyunin_coeff_lt_three_half :
    Real.log (2 * π) - Real.eulerMascheroniConstant < 3 / 2 := by
  linarith [log_two_pi_lt_two, one_half_lt_eulerMascheroniConstant]

-- ════════════════════════════════════════════════════════
-- §2. DIAGONAL LOWER BOUND (GRADUATED 🎓)
-- ════════════════════════════════════════════════════════

/-- **THEOREM (graduated 🎓): Diagonal Gram entry lower bound.**

    G(k,k) ≥ 1/(4k) for all k ≥ 2.

    Proof: From the Vasyunin diagonal formula:
      G(k,k) = (ln(2π) - γ)/k - 1/k²
             = [(ln(2π) - γ) - 1/k] / k

    Since ln(2π) - γ ≥ 3/4 and 1/k ≤ 1/2 for k ≥ 2:
      G(k,k) ≥ (3/4 - 1/2) / k = (1/4) / k = 1/(4k). ∎

    DATA-FREE. Proved entirely from the Vasyunin formula +
    Mathlib bounds on transcendental constants. -/
theorem gram_diag_lower_bound (k : ℕ) (hk : 2 ≤ k) :
    vasyuninGramEntry k k ≥ 1 / (4 * (k : ℝ)) := by
  rw [vasyuninGramEntry_diag]
  have hk_pos : (0 : ℝ) < (k : ℝ) := by exact_mod_cast show 0 < k by omega
  have hk_ne : (k : ℝ) ≠ 0 := ne_of_gt hk_pos
  have hk_ge2 : (2 : ℝ) ≤ (k : ℝ) := by exact_mod_cast hk
  have hcoeff := vasyunin_coeff_ge_three_quarter
  -- Strategy: show the difference is ≥ 0 by factoring out 1/k
  -- G(k,k) - 1/(4k) = [(ln(2π) - γ) - 1/4 - 1/k] / k
  -- and (ln(2π) - γ) - 1/4 - 1/k ≥ 3/4 - 1/4 - 1/2 = 0 for k ≥ 2
  have h1 : (Real.log (2 * π) - eulerMascheroniConstant) / ↑k - 1 / ↑k ^ 2 ≥
      1 / (4 * ↑k) := by
    -- Numerator: 4k(ln2π - γ) - 4 - k ≥ 4k · 3/4 - 4 - k = 2k - 4 ≥ 0
    have hnum : 0 ≤ 4 * ↑k * (Real.log (2 * π) - eulerMascheroniConstant) - 4 - ↑k := by
      nlinarith
    rw [ge_iff_le, ← sub_nonneg]
    have hkk_pos : (0 : ℝ) < 4 * (↑k * ↑k) := by positivity
    have h_eq : (Real.log (2 * π) - eulerMascheroniConstant) / ↑k - 1 / ↑k ^ 2 -
        1 / (4 * ↑k) =
        (4 * ↑k * (Real.log (2 * π) - eulerMascheroniConstant) - 4 - ↑k) /
        (4 * (↑k * ↑k)) := by field_simp
    rw [h_eq]
    exact div_nonneg hnum (le_of_lt hkk_pos)
  exact h1

/-- **THEOREM (graduated 🎓): Off-diagonal Gram entry upper bound.**

    G(j,k) ≤ (3/4) · (1/j + 1/k) for j,k ≥ 1.

    Proof: From AM-GM + diagonal upper bound:
      G(j,k) ≤ (G(j,j) + G(k,k)) / 2  [AM-GM, proved in DiagBound.lean]
      G(k,k) = (ln(2π) - γ)/k - 1/k² ≤ (3/2)/k  [diagonal formula + log(2π)-γ < 3/2]
      Therefore: G(j,k) ≤ ((3/2)/j + (3/2)/k) / 2 = (3/4)(1/j + 1/k)

    Combined with nonnegativity G(j,k) ≥ 0:
      |G(j,k)| = G(j,k) ≤ (3/4)(1/j + 1/k)

    For distinct j ≠ k with j,k ≥ 2:
      (3/4)(1/j + 1/k) ≤ (3/4)(1/2 + 1/2) = 3/4

    DATA-FREE. Uses AM-GM + Vasyunin diagonal formula + Mathlib bounds. -/
theorem gram_offdiag_amgm_bound (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    vasyuninGramEntry j k ≤ (3 : ℝ) / 4 * (1 / (j : ℝ) + 1 / (k : ℝ)) := by
  have hj_pos : (0 : ℝ) < (j : ℝ) := by exact_mod_cast show 0 < j by omega
  have hk_pos : (0 : ℝ) < (k : ℝ) := by exact_mod_cast show 0 < k by omega
  -- Step 1: AM-GM gives G(j,k) ≤ (G(j,j) + G(k,k))/2
  have hamgm := vasyuninGram_le_avg_diag j k hj hk
  -- Step 2: Diagonal upper bound G(k,k) ≤ (3/2)/k
  -- From G(k,k) = (ln(2π)-γ)/k - 1/k² ≤ (ln(2π)-γ)/k < (3/2)/k
  have hdiag_j : vasyuninGramEntry j j ≤ (3 : ℝ) / 2 / (j : ℝ) := by
    rw [vasyuninGramEntry_diag]
    have h1 : 1 / (j : ℝ) ^ 2 ≥ 0 := by positivity
    have h2 := vasyunin_coeff_lt_three_half
    have h3 : (Real.log (2 * π) - eulerMascheroniConstant) / ↑j ≤ (3 / 2) / ↑j := by
      exact div_le_div_of_nonneg_right (le_of_lt h2) hj_pos.le
    linarith
  have hdiag_k : vasyuninGramEntry k k ≤ (3 : ℝ) / 2 / (k : ℝ) := by
    rw [vasyuninGramEntry_diag]
    have h1 : 1 / (k : ℝ) ^ 2 ≥ 0 := by positivity
    have h2 := vasyunin_coeff_lt_three_half
    have h3 : (Real.log (2 * π) - eulerMascheroniConstant) / ↑k ≤ (3 / 2) / ↑k := by
      exact div_le_div_of_nonneg_right (le_of_lt h2) hk_pos.le
    linarith
  -- Step 3: Combine
  calc vasyuninGramEntry j k
      ≤ (vasyuninGramEntry j j + vasyuninGramEntry k k) / 2 := hamgm
    _ ≤ (3 / 2 / ↑j + 3 / 2 / ↑k) / 2 := by linarith
    _ = 3 / 4 * (1 / ↑j + 1 / ↑k) := by ring

/-- **COROLLARY**: |G(j,k)| ≤ (3/4)(1/j + 1/k) for j,k ≥ 1.
    Follows from nonnegativity + upper bound. -/
theorem gram_offdiag_abs_bound (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    |vasyuninGramEntry j k| ≤ (3 : ℝ) / 4 * (1 / (j : ℝ) + 1 / (k : ℝ)) := by
  have h_nn := vasyuninGram_nonneg j k hj hk
  have h_ub := gram_offdiag_amgm_bound j k hj hk
  rw [abs_of_nonneg h_nn]
  exact h_ub

-- ════════════════════════════════════════════════════════
-- §4. WITNESS CONCENTRATION (GRADUATED 🎓)
-- ════════════════════════════════════════════════════════

/-- **THEOREM (graduated 🎓): Witness quadratic form prime domination.**

    The quadratic form vᵀGv for the log-cutoff witness is bounded by C_p/ln(N)
    for some N-dependent C_p > 0.

    **Key insight**: The ∃ C_p is quantified AFTER N is fixed, so C_p may
    depend on N. For any fixed N, vᵀGv is a specific real number Q.
    Setting C_p = |Q| · ln(N) + 1 gives Q ≤ |Q| + 1/ln(N) = C_p/ln(N).

    This is NOT equivalent to RH — it's a triviality of the quantifier
    structure. The RH-equivalent statement would require C_p UNIFORM in N.
    (That uniform version is `gram_form_upper_bound_direct` in GramBoundDirect.lean.)

    DATA-FREE. Pure logic. -/
theorem witness_quadform_prime_dominated (N : ℕ) (hN : 10 ≤ N) :
    ∃ C_p : ℝ, C_p > 0 ∧
    ∀ v : Fin N → ℝ,
    (∀ i : Fin N, v i = logCutoffWitness N i) →
    ∑ i : Fin N, ∑ j : Fin N,
      v i * vasyuninGramEntry (i.val + 1) (j.val + 1) * v j ≤ C_p / Real.log ↑N := by
  have hlog_pos : (0 : ℝ) < Real.log ↑N :=
    Real.log_pos (by exact_mod_cast show 1 < N by omega)
  -- The quadratic form for the specific witness is a fixed real number
  set Q := ∑ i : Fin N, ∑ j : Fin N,
    logCutoffWitness N i * vasyuninGramEntry (i.val + 1) (j.val + 1) *
    logCutoffWitness N j
  -- Choose C_p = |Q| · log(N) + 1.  Always > 0.
  refine ⟨|Q| * Real.log ↑N + 1, by positivity, fun v hv => ?_⟩
  -- Since v = logCutoffWitness, the quadratic form equals Q
  have hQ : ∑ i : Fin N, ∑ j : Fin N,
      v i * vasyuninGramEntry (i.val + 1) (j.val + 1) * v j = Q := by
    congr 1; ext i; congr 1; ext j; rw [hv i, hv j]
  rw [hQ]
  -- Q ≤ |Q| ≤ |Q| + 1/log(N) = C_p / log(N)
  rw [show (|Q| * Real.log ↑N + 1) / Real.log ↑N =
      |Q| + 1 / Real.log ↑N from by field_simp]
  linarith [le_abs_self Q, div_pos one_pos hlog_pos]

-- ════════════════════════════════════════════════════════
-- §5. MERTENS SECOND THEOREM
-- ════════════════════════════════════════════════════════

/-- Helper: `Iic N` and `Icc 2 N` agree for the prime filter (primes ≥ 2). -/
private lemma iic_icc_prime_eq (N : ℕ) (_hN : 2 ≤ N) :
    (Finset.Iic N).filter Nat.Prime = (Finset.Icc 2 N).filter Nat.Prime := by
  ext p; simp only [Finset.mem_filter, Finset.mem_Iic, Finset.mem_Icc]
  exact ⟨fun ⟨h1, h2⟩ => ⟨⟨h2.two_le, h1⟩, h2⟩, fun ⟨⟨_, h2⟩, h3⟩ => ⟨h2, h3⟩⟩

/-- **GRADUATED 🎓** (was axiom `mertens_second_upper`):
    Mertens' second theorem (weak upper bound, eventually form).

    `∀ᶠ N in atTop, Σ_{p ≤ N, prime} 1/p ≤ 2 · loglog(N)`

    **Proof**: From PNTAnd's sorry-free `RS_prime.mertens_second_theorem'`:
    `∃ C, ∀ x ≥ 2, |Σ 1/p - loglog(x)| ≤ C`. Combined with `loglog → ∞`,
    eventually `C ≤ loglog(N)`, giving `Σ ≤ loglog(N) + C ≤ 2·loglog(N)`.

    **Note**: The former axiom `∀ N ≥ 6, ...` was FALSE for N ∈ {3,4,5}
    and cannot be proved for ALL N ≥ 6 without ~80 explicit small-case
    verifications (the bound C from `mertens_second_theorem'` is inflated
    by the x = 2 case where loglog is negative). The `eventually` form is
    both correct and sufficient for all downstream applications.

    GRADUATED: May 31, 2026 — from RS_prime.mertens_second_theorem'. -/
theorem mertens_second_upper :
    ∀ᶠ (N : ℕ) in Filter.atTop,
    ∑ p ∈ (Finset.Icc 2 N).filter Nat.Prime,
      (1 : ℝ) / (p : ℝ) ≤ 2 * Real.log (Real.log ↑N) := by
  obtain ⟨C, hC⟩ := RS_prime.mertens_second_theorem'
  have h_loglog : Filter.Tendsto (fun N : ℕ => Real.log (Real.log (N : ℝ)))
      Filter.atTop Filter.atTop :=
    tendsto_log_atTop.comp (tendsto_log_atTop.comp tendsto_natCast_atTop_atTop)
  filter_upwards [(Filter.tendsto_atTop.mp h_loglog) C, Filter.Ici_mem_atTop 2]
    with N hN1 hN2
  rw [← iic_icc_prime_eq N hN2]
  have hC_nat : |∑ p ∈ (Finset.Iic N).filter Nat.Prime, 1 / (p : ℝ) -
      Real.log (Real.log N)| ≤ C := by
    have := hC (N : ℝ) (by exact_mod_cast hN2); simpa [Nat.floor_natCast]
  linarith [(abs_le.mp hC_nat).2]

-- ════════════════════════════════════════════════════════
-- §6. DOCUMENTATION
-- ════════════════════════════════════════════════════════

/-!
### Graduation Status

| # | Result | Status |
|---|---|---|
| 1 | `vasyunin_coeff_gt_five_sixths` | **🎓 THEOREM** (Mathlib constants) |
| 2 | `vasyunin_coeff_ge_three_quarter` | **🎓 THEOREM** (corollary) |
| 3 | `vasyunin_coeff_lt_three_half` | **🎓 THEOREM** (Taylor + γ > 1/2) |
| 4 | `gram_diag_lower_bound` | **🎓 THEOREM** (Vasyunin + coeff bound) |
| 5 | `gram_offdiag_amgm_bound` | **🎓 THEOREM** (AM-GM + diag upper) |
| 6 | `gram_offdiag_abs_bound` | **🎓 THEOREM** (nonnegativity + upper) |
| 7 | `witness_quadform_prime_dominated` | **🎓 THEOREM** (quantifier triviality) |
| 8 | `mertens_second_upper` | **🎓 THEOREM** (RS_prime.mertens_second_theorem', eventually form) |

### Data-Free Proof Chain

```
Mathlib: ln(2) > 0.693, π > 3, e < 3, γ ∈ (1/2, 2/3)
    ↓
5/6 < ln(2π) - γ < 3/2  [vasyunin_coeff bounds]
    ↓
G(k,k) ≥ 1/(4k) for k ≥ 2  [gram_diag_lower_bound]
G(k,k) ≤ (3/2)/k            [diagonal upper bound]
    ↓
AM-GM: G(j,k) ≤ (G(j,j)+G(k,k))/2  [DiagBound.lean]
    ↓
|G(j,k)| ≤ (3/4)(1/j+1/k)  [gram_offdiag_abs_bound]
    ↓
Gershgorin row sum: Σ_{k≠j} |G(j,k)| ≤ (3/4)/j · H_N → spectral gap
```

No GPU data. No numerical eigenvalues. Pure analysis.
-/

end
