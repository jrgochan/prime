/-
  Cathedral/Assembly/MellinResidualExpansion.lean

  ## Mellin Residual Expansion: Path 2 for Crown Axiom Graduation

  ### Mathematical Content

  The BD residual r_N(x) = 1 - Σ v_k {1/(kx)} has Mellin transform:

    M_{r_N}(s) = ∫₀¹ r_N(x) x^{s-1} dx

  Using linearity and the proved formula `mellin_fractBasis`:

    M[{k/·}](s) = k/(s(s-1)) + (k^s/s)(Σ_{m<k}(m+1)^{-s} - ζ(s))

  we can write:

    M_{r_N}(s) = 1/s - Σ_{k=1}^{N-1} v_k · M[{k/·}](s)

  where v_k = -μ(k)·(1 - log(k)/logN) are the BD Möbius weights.

  ### Crown Axiom Graduation Strategy (Path 2)

  On the critical line s = 1/2 + it:

    M_{r_N}(1/2+it) = 1/(1/2+it) - Σ_k v_k · [k/((1/2+it)(-1/2+it))
                       + (k^{1/2+it}/(1/2+it))·(Σ_{m<k}(m+1)^{-1/2-it} - ζ(1/2+it))]

  The key observation: after expanding, M_{r_N}(1/2+it) is a FINITE sum
  of terms involving k^{it} (Dirichlet polynomial structure).

  Applying the Montgomery-Vaughan MVT:
    (1/2π)∫|M_{r_N}(1/2+it)|² dt ≤ Σ|c_k|²(2T + 2πk)/(2πT)

  As T → ∞ (or with the proved finite-T bound):
    ≤ Σ|c_k|²

  Under RH with v_k = -μ(k)·logWeight, the coefficient bound
    Σ|c_k|² = O(1/logN)
  follows from the PNT sums Σ μ(k)/k → 0 and Σ μ(k)log(k)/k → -1.

  ### Status: Assembly scaffolding — April 27, 2026
  ### Dependencies: FloorDivMellin.lean, PlancherelDefs.lean, BDWeights.lean
-/

import Cathedral.MellinBridge.FloorDivMellin
import Cathedral.MellinBridge.PlancherelDefs
import Cathedral.MellinBridge.BDWeights
import Cathedral.Assembly.MellinVarianceProof

noncomputable section
open Complex Real MeasureTheory Set Filter Finset BigOperators

-- ═══════════════════════════════════════════════
-- §1. MELLIN RESIDUAL DECOMPOSITION
-- ═══════════════════════════════════════════════

/-- The BD Mellin basis integral: ∫₀¹ {1/(kx)} · x^{s-1} dx.
    This is the Mellin transform of the TRUE BD basis h_k(x) = {1/(kx)}
    (not {k/x} which is the high-frequency basis). -/
def bdMellinBasis (k : ℕ) (s : ℂ) : ℂ :=
  ∫ x in Set.Ioo (0 : ℝ) 1,
    ((Int.fract (1 / ((k : ℝ) * x)) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1)

/-- The Mellin residual decomposes into target minus basis sum.

    M_{r_N}(s) = 1/s - Σ_{i} v_i · bdMellinBasis(i+1, s)

    where 1/s = ∫₀¹ x^{s-1} dx (target Mellin transform)
    and bdMellinBasis(k,s) = ∫₀¹ {1/(kx)} x^{s-1} dx.

    PROOF: Direct integral linearity — expand bdResidualV = 1 - Σ v_i {1/((i+1)x)},
    distribute over the integral, then evaluate ∫₀¹ x^{s-1} = 1/s. -/
theorem mellin_residual_decomp (N : ℕ) (v : Fin (N - 1) → ℝ)
    (s : ℂ) (hs : 0 < s.re) :
    mellinBDResidual N v s =
    1 / s - ∑ i : Fin (N - 1), (v i : ℂ) *
      bdMellinBasis (i.val + 1) s := by
  have hs0 : 0 < s.re := hs
  -- Unfold to the integral level
  unfold mellinBDResidual bdResidualV bdMellinBasis
  -- Step 1: Expand the integrand
  have h_expand : ∀ x : ℝ,
      ((1 - bdLinComb N v x : ℝ) : ℂ) * (x : ℂ) ^ (s - 1) =
      (x : ℂ) ^ (s - 1) - ∑ i : Fin (N - 1),
        ((v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1) := by
    intro x; rw [Complex.ofReal_sub, Complex.ofReal_one, sub_mul, one_mul]; congr 1
    rw [show (bdLinComb N v x : ℂ) = ∑ i : Fin (N - 1),
      ((v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) : ℝ) : ℂ) from by
      simp [bdLinComb, Complex.ofReal_sum, Complex.ofReal_mul]]
    rw [Finset.sum_mul]
  -- Step 2: Integrability
  have h_cpow_int : IntegrableOn (fun x : ℝ => (x : ℂ) ^ (s - 1)) (Set.Ioc 0 1) := by
    have h_dom : IntegrableOn (fun x : ℝ => x ^ (s.re - 1)) (Set.Ioc 0 1) := by
      rw [← intervalIntegrable_iff_integrableOn_Ioc_of_le (by norm_num : (0:ℝ) ≤ 1)]
      exact intervalIntegral.intervalIntegrable_rpow' (show -1 < s.re - 1 by linarith)
    exact Integrable.mono h_dom (Measurable.aestronglyMeasurable (by fun_prop)) (by
      filter_upwards [self_mem_ae_restrict measurableSet_Ioc] with x hx
      rw [Complex.norm_cpow_eq_rpow_re_of_pos hx.1 (s - 1),
          show (s - 1).re = s.re - 1 from by simp [Complex.sub_re],
          Real.norm_of_nonneg (Real.rpow_nonneg (le_of_lt hx.1) _)])
  have h_term_int : ∀ i : Fin (N - 1), i ∈ Finset.univ →
      IntegrableOn (fun x => ((v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) : ℝ) : ℂ) *
        (x : ℂ) ^ (s - 1)) (Set.Ioc 0 1) := by
    intro i _
    apply Integrable.bdd_mul h_cpow_int
    · exact (Complex.continuous_ofReal.measurable.comp
        ((measurable_const.mul (measurable_fract_real.comp
          (measurable_const.div (measurable_const.mul measurable_id)))))).aestronglyMeasurable
    · exact Filter.Eventually.of_forall (fun x => by
        rw [Complex.norm_real]
        calc |v i * Int.fract (1 / (↑(i.val + 1) * x))|
            = |v i| * |Int.fract (1 / (↑(i.val + 1) * x))| := abs_mul _ _
          _ ≤ |v i| * 1 := mul_le_mul_of_nonneg_left
              ((abs_of_nonneg (Int.fract_nonneg _)).le.trans (Int.fract_lt_one _).le) (abs_nonneg _)
          _ = |v i| := mul_one _)
  -- Step 3: Split the integral
  rw [← integral_Ioc_eq_integral_Ioo]
  simp_rw [h_expand]
  rw [integral_sub h_cpow_int (integrable_finset_sum _ h_term_int),
      integral_finset_sum _ h_term_int]
  -- Step 4: Factor out v_i and convert Ioc → Ioo
  congr 1
  · -- ∫ x^{s-1} = 1/s
    -- Convert Ioc → interval integral → evaluate via integral_cpow
    rw [← intervalIntegral.integral_of_le (by norm_num : (0:ℝ) ≤ 1)]
    rw [integral_cpow (Or.inl (show -1 < (s - 1).re from by simp [Complex.sub_re]; linarith))]
    rw [show (s - 1) + 1 = s from by ring]
    have hs_ne : s ≠ 0 := by intro h; rw [h, Complex.zero_re] at hs; linarith
    simp only [Complex.ofReal_one, Complex.ofReal_zero, Complex.one_cpow,
               Complex.zero_cpow hs_ne, sub_zero]
  · -- Σ v_i · ∫ = Σ v_i · bdMellinBasis
    apply Finset.sum_congr rfl
    intro i _
    -- Factor v_i out of integral
    rw [show (fun x : ℝ => ((v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) : ℝ) : ℂ) *
      (x : ℂ) ^ (s - 1)) = (fun x => (v i : ℂ) *
      (((Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) : ℝ) : ℂ) * (x : ℂ) ^ (s - 1))) from by
      ext x; push_cast; ring]
    rw [integral_const_mul, integral_Ioc_eq_integral_Ioo]

/-- The BD Mellin basis has an explicit formula via bd_mellin_reduction_proved:

    bdMellinBasis(k, s) = (1/k - k^{-s})/(s-1) + k^{-s} · (1/(s-1) - ζ(s)/s)

    For Re(s) > 1 and s ≠ 1. Combines bd_mellin_reduction_proved + bd_mellin_base_case. -/
theorem bdMellinBasis_explicit (k : ℕ) (hk : 1 ≤ k) (s : ℂ) (hs : 0 < s.re) (hs1 : s ≠ 1) :
    bdMellinBasis k s =
    (1 / k - (k : ℂ) ^ (-s)) / (s - 1) +
    (k : ℂ) ^ (-s) * (1 / (s - 1) - riemannZeta s / s) := by
  unfold bdMellinBasis
  rw [bd_mellin_reduction_proved k hk s hs hs1, bd_mellin_base_case s hs hs1]

/-- The Mellin residual fully expanded via bdMellinBasis_explicit.

    M_{r_N}(s) = 1/s - Σ_k v_k [(1/k - k^{-s})/(s-1) + k^{-s}·(1/(s-1) - ζ(s)/s)]

    This is a finite, explicit formula: no axioms, no ζ-poles needed.
    The ζ(s) terms appear but are multiplied by the BD weights,
    creating massive cancellation under the optimal Möbius choice. -/
theorem mellin_residual_explicit (N : ℕ) (v : Fin (N - 1) → ℝ)
    (s : ℂ) (hs : 0 < s.re) (hs1 : s ≠ 1) :
    mellinBDResidual N v s =
    1 / s - ∑ i : Fin (N - 1), (v i : ℂ) *
      ((1 / ↑(i.val + 1 : ℕ) - (↑(i.val + 1 : ℕ) : ℂ) ^ (-s)) / (s - 1) +
       (↑(i.val + 1 : ℕ) : ℂ) ^ (-s) * (1 / (s - 1) - riemannZeta s / s)) := by
  rw [mellin_residual_decomp N v s hs]
  congr 1
  apply Finset.sum_congr rfl
  intro i _
  congr 1
  exact bdMellinBasis_explicit (i.val + 1) (by omega) s hs hs1

-- ═══════════════════════════════════════════════
-- §2. SIMPLIFIED MELLIN BASIS
-- ═══════════════════════════════════════════════

/-- The BD Mellin basis simplifies to:
    bdMellinBasis(k, s) = 1/(k(s-1)) - k^{-s} · ζ(s)/s

    Proof: algebraic simplification of the explicit formula. -/
theorem bdMellinBasis_simplified (k : ℕ) (hk : 1 ≤ k) (s : ℂ) (hs : 0 < s.re) (hs1 : s ≠ 1) :
    bdMellinBasis k s =
    1 / ((k : ℂ) * (s - 1)) - (k : ℂ) ^ (-s) * (riemannZeta s / s) := by
  rw [bdMellinBasis_explicit k hk s hs hs1]
  have hs1' : s - 1 ≠ 0 := sub_ne_zero.mpr hs1
  have hk_ne : (k : ℂ) ≠ 0 := by exact_mod_cast ne_of_gt (show 0 < k by omega)
  field_simp
  ring

/-- The Mellin residual in its most transparent form:
    M_{r_N}(s) = [1/s - Σ v_k/(k(s-1))] + [ζ(s)/s · Σ v_k k^{-s}]

    The first bracket is a rational function of s (pole structure).
    The second bracket contains ζ(s) times a Dirichlet polynomial.
    Under RH, ζ(s) ≠ 0 on Re(s) = 1/2, so this is well-defined. -/
theorem mellin_residual_structural (N : ℕ) (v : Fin (N - 1) → ℝ)
    (s : ℂ) (hs : 0 < s.re) (hs1 : s ≠ 1) :
    mellinBDResidual N v s =
    (1 / s - ∑ i : Fin (N - 1), (v i : ℂ) / ((↑(i.val + 1 : ℕ) : ℂ) * (s - 1))) +
    (riemannZeta s / s) *
      ∑ i : Fin (N - 1), (v i : ℂ) * (↑(i.val + 1 : ℕ) : ℂ) ^ (-s) := by
  rw [mellin_residual_decomp N v s hs]
  -- Expand each bdMellinBasis using the simplified form
  have h_simp : ∀ i : Fin (N - 1),
      bdMellinBasis (i.val + 1) s =
      1 / ((↑(i.val + 1 : ℕ) : ℂ) * (s - 1)) -
      (↑(i.val + 1 : ℕ) : ℂ) ^ (-s) * (riemannZeta s / s) :=
    fun i => bdMellinBasis_simplified (i.val + 1) (by omega) s hs hs1
  simp_rw [h_simp]
  -- Goal algebra: 1/s - Σ v_k(a_k - b_k) = (1/s - Σ v_k·a_k) + (ζ/s · Σ v_k·b_k')
  simp only [mul_sub]
  rw [Finset.sum_sub_distrib]
  -- Now: 1/s - (Σ v·a - Σ v·b) = 1/s - Σ v·a + Σ v·b
  -- Factor ζ(s)/s from the second sum: Σ v_k · (k^{-s} · ζ/s) = (ζ/s) · Σ v_k · k^{-s}
  have h_factor : ∑ i : Fin (N - 1),
      (v i : ℂ) * ((↑(i.val + 1 : ℕ) : ℂ) ^ (-s) * (riemannZeta s / s)) =
    (riemannZeta s / s) * ∑ i : Fin (N - 1),
      (v i : ℂ) * (↑(i.val + 1 : ℕ) : ℂ) ^ (-s) := by
    rw [Finset.mul_sum]
    congr 1; ext i; ring
  rw [h_factor]
  -- Goal: 1/s - (Σ v·a - (ζ/s)·Σ v·b) = (1/s - Σ v·a) + (ζ/s)·(Σ v·b)
  ring_nf

-- ═══════════════════════════════════════════════
-- §3. THE BD DIRICHLET POLYNOMIAL
-- ═══════════════════════════════════════════════

/-- The BD Dirichlet polynomial: D_N(s) = Σ_{k=1}^{N-1} v_k · k^{-s}.

    This is the finite Dirichlet polynomial formed by the BD weights.
    The Mean Value Theorem bounds its L² norm on the critical line. -/
def bdDirichletPoly (N : ℕ) (v : Fin (N - 1) → ℝ) (s : ℂ) : ℂ :=
  ∑ i : Fin (N - 1), (v i : ℂ) * (↑(i.val + 1 : ℕ) : ℂ) ^ (-s)

/-- The rational part: R_N(s) = 1/s - Σ v_k/(k(s-1)).

    This has poles at s = 0 and s = 1 but is bounded on the critical line. -/
def bdRationalPart (N : ℕ) (v : Fin (N - 1) → ℝ) (s : ℂ) : ℂ :=
  1 / s - ∑ i : Fin (N - 1), (v i : ℂ) / ((↑(i.val + 1 : ℕ) : ℂ) * (s - 1))

/-- The Mellin residual = rational part + ζ(s)/s · Dirichlet polynomial. -/
theorem mellin_residual_poly_form (N : ℕ) (v : Fin (N - 1) → ℝ)
    (s : ℂ) (hs : 0 < s.re) (hs1 : s ≠ 1) :
    mellinBDResidual N v s =
    bdRationalPart N v s + (riemannZeta s / s) * bdDirichletPoly N v s := by
  unfold bdRationalPart bdDirichletPoly
  exact mellin_residual_structural N v s hs hs1

-- ═══════════════════════════════════════════════
-- §4. CROWN GRADUATION TARGETS
-- ═══════════════════════════════════════════════

/-- **TARGET**: Crown Axiom graduation.

    The Crown Axiom `critical_line_mellin_variance_proved` states:
      (1/2π) ∫ |M_{r_N}(1/2+it)|² dt ≤ C/logN

    By `mellin_residual_poly_form`:
      M_{r_N}(s) = R_N(s) + (ζ(s)/s) · D_N(s)

    On the critical line s = 1/2 + it:
    - R_N(1/2+it) = 1/(1/2+it) - Σ v_k/(k(-1/2+it)) — bounded by Σ|v_k|/k
    - D_N(1/2+it) = Σ v_k k^{-1/2-it} — Dirichlet polynomial
    - ζ(1/2+it)/s — bounded under RH (no zeros on critical line)

    The MVT bounds ∫|D_N|² ≤ Σ|v_k|²/k · (2T+2πk)
    Under v_k = -μ(k)·logWeight: Σ|v_k|²/k = O(1/logN)

    Combining: the full integral is O(1/logN). -/
theorem crown_graduation_target
    (hRH : RiemannHypothesis)
    (N : ℕ) (hN : 10 ≤ N) :
    ∃ C : ℝ, C > 0 ∧ ∃ N₀ : ℕ, ∀ N' : ℕ, N' ≥ N₀ → N' ≥ 3 →
      (1 / (2 * Real.pi)) *
      ∫ t : ℝ, ‖mellinBDResidual N' (bdMoebiusWeight N')
        ((1/2 : ℂ) + t * Complex.I)‖ ^ 2
      ≤ C / Real.log ↑N' := by
  sorry  -- Full assembly:
         -- 1. mellin_residual_poly_form decomposes M_{r_N} (PROVED)
         -- 2. Triangle inequality: |R + ζ/s · D|² ≤ 2|R|² + 2|ζ/s|²|D|²
         -- 3. |R(1/2+it)|² bounded (rational, explicit)
         -- 4. |ζ(1/2+it)/s|² bounded under RH (uses rh_zeta_lower_bound)
         -- 5. MVT: ∫|D(1/2+it)|² ≤ Σ|v_k|²/k (NEARLY PROVED)
         -- 6. Σ|v_k|²/k = O(1/logN) from PNT sums (PROVED infrastructure)

-- ═══════════════════════════════════════════════
-- §5. AUDIT
-- ═══════════════════════════════════════════════

-- PROVED (zero sorry — 7 theorems):
--   ✅ bdMellinBasis — definition
--   ✅ mellin_residual_decomp — M_{r_N}(s) = 1/s - Σ v_i · bdMellinBasis(i+1, s)
--   ✅ bdMellinBasis_explicit — (1/k - k^{-s})/(s-1) + k^{-s}(1/(s-1) - ζ/s)
--   ✅ mellin_residual_explicit — full expansion chaining decomp + explicit
--   ✅ bdMellinBasis_simplified — = 1/(k(s-1)) - k^{-s}·ζ(s)/s
--   ✅ mellin_residual_structural — = R_N(s) + (ζ(s)/s)·D_N(s)
--   ✅ mellin_residual_poly_form — same via defs
--
-- SORRY (1):
--   🔴 crown_graduation_target — the full Crown Axiom assembly
--
-- ARCHITECTURE:
--   The original 1 opaque Crown Axiom sorry has been decomposed into
--   a structural form where 7 theorems are proved and 1 sorry remains.
--   The remaining sorry requires:
--   (a) Triangle inequality on the critical line
--   (b) RH → zeta lower bound (existing axiom)
--   (c) MVT for Dirichlet polynomials (1 sorry upstream)
--   (d) PNT sum bound for Σ|v_k|²/k (existing infrastructure)

end
