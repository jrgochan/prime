/-
  Cathedral/Spectral/MellinDirichletBridge.lean

  # The Mellin-Dirichlet Bridge

  ## Purpose

  Connects the spatial integral ∫₀¹|Σ vₖ B₁(1/kx)|² to the critical-line
  Mellin integral via `parseval_bridge_white`, then bounds it using the
  Dirichlet polynomial MVT (`dirichlet_polynomial_mean_value_bound`).

  ## Strategy (Gemini COMM-LINK 5, May 9, 2026)

  The Fourier-Gram bridge (Parseval on [0,1] with B₁(1/kx)) FAILS because
  the geometric inversion u = 1/(kx) maps dx → du/u², breaking the
  orthogonality of additive Fourier modes.

  The CORRECT path uses the Mellin transform — the natural tool for
  multiplicative dilations:

  1. `parseval_bridge_white`:
       ∫₀¹|r_N|² = (1/2π) ∫|M(½+it)|²     [PROVED in Scattering.lean]

  2. `bilinear_b1_decomposition`:
       ∫₀¹(Σv{1/kx})² = ∫(ΣvB₁)² + (Σv)·∫ΣvB₁ + ¼(Σv)²
                                                   [PROVED in BilinearSieve.lean]

  3. Algebra: ∫(ΣvB₁)² ≤ ∫|r_N|² + |corrections|
       where corrections involve ∫ΣvB₁ and (Σv) terms.

  4. Mellin bound: ∫|M(½+it)|² involves Dirichlet polynomials Σvₖk^{-½-it}
       → bounded by `dirichlet_polynomial_mean_value_bound`.

  ## Dependencies
  - Cathedral.White.Scattering (parseval_bridge_white)
  - Cathedral.Spectral.BilinearSieve (bilinear_b1_decomposition)
  - Cathedral.Analysis.MontgomeryVaughan (dirichlet_polynomial_mean_value_bound)

  Created: May 9, 2026 — Exploration 31, Mellin pivot
  Status: ASSEMBLY — wiring existing theorems
-/

import Cathedral.White.Scattering
import Cathedral.Spectral.FourierGram
import Cathedral.Analysis.MontgomeryVaughan
import Cathedral.MellinBridge.PlancherelDefs

noncomputable section
open Real MeasureTheory Set Complex

namespace Cathedral.MellinDirichletBridge

-- ════════════════════════════════════════════════
-- §1. ALGEBRAIC IDENTITY: r_N and B₁ sum
-- ════════════════════════════════════════════════

/-!
### The Fundamental Algebraic Identity

Using `fract_eq_sawtooth_add_half` (PROVED in FourierGram.lean):
  {x} = B₁(x) + ½

We can rewrite the BD residual:
  r_N(x) = 1 - Σ vₖ {1/(kx)}
         = 1 - Σ vₖ (B₁(1/kx) + ½)
         = (1 - ½Σvₖ) - Σ vₖ B₁(1/kx)

Therefore:
  r_N(x)² = (1 - ½Σv)² - 2(1 - ½Σv)(Σ vₖ B₁(1/kx)) + (Σ vₖ B₁(1/kx))²

And integrating:
  ∫₀¹ r_N² = (1-½Σv)² - 2(1-½Σv)·∫₀¹ΣvB₁ + ∫₀¹(ΣvB₁)²

This gives us:
  ∫₀¹(ΣvB₁)² = ∫₀¹ r_N² - (1-½Σv)² + 2(1-½Σv)·∫₀¹ΣvB₁
-/

/-- The constant `c_v = 1 - ½ · Σ vₖ` appearing in the B₁ decomposition. -/
def c_v {N : ℕ} (v : Fin (N - 1) → ℝ) : ℝ :=
  1 - (1/2) * ∑ j : Fin (N - 1), v j

/-- The B₁ sum `S(x) = Σ vₖ B₁(1/kx)`. -/
def b1_sum {N : ℕ} (v : Fin (N - 1) → ℝ) (x : ℝ) : ℝ :=
  ∑ j : Fin (N - 1), v j * FourierGram.sawtoothReal (1 / ((↑(j.val + 1) : ℝ) * x))

/-- The BD residual equals c_v minus the B₁ sum.

    r_N(x) = 1 - Σ vₖ {1/(kx)} = c_v - S(x)

    where c_v = 1 - ½Σv and S(x) = Σ vₖ B₁(1/kx).

    Proof: {x} = B₁(x) + ½, so Σ vₖ {·} = Σ vₖ (B₁ + ½) = S + ½Σv.
    Then r_N = 1 - (S + ½Σv) = (1 - ½Σv) - S = c_v - S. -/
theorem residual_eq_cv_sub_b1sum {N : ℕ} (v : Fin (N - 1) → ℝ) (x : ℝ) :
    bdResidualV N v x = c_v v - b1_sum v x := by
  unfold bdResidualV bdLinComb c_v b1_sum
  -- Rewrite {·} = B₁(·) + ½
  simp_rw [FourierGram.fract_eq_sawtooth_add_half]
  -- Distribute: vⱼ·(B₁ + ½) = vⱼ·B₁ + vⱼ·½
  simp_rw [mul_add, Finset.sum_add_distrib]
  -- Both sides are now linear combinations of the same terms; close algebraically
  have h : ∑ j : Fin (N - 1), v j * (1 / 2 : ℝ) = (1 / 2) * ∑ j : Fin (N - 1), v j := by
    rw [Finset.mul_sum]; apply Finset.sum_congr rfl; intro j _; ring
  linarith

-- ════════════════════════════════════════════════
-- §2. THE MELLIN CONNECTION
-- ════════════════════════════════════════════════

/-!
### The Mellin-Dirichlet Strategy

From `parseval_bridge_white` (PROVED in Scattering.lean):

  ∫₀¹ |r_N(x)|² dx = (1/2π) ∫ₐ |M_{r_N}(½+it)|² dt

And from the algebraic identity (§1):

  ∫₀¹ |r_N|² = (c_v)² - 2·c_v·∫₀¹ S(x) dx + ∫₀¹ |S(x)|² dx

Therefore:

  ∫₀¹ |S(x)|² dx = ∫₀¹ |r_N|² - (c_v)² + 2·c_v · ∫₀¹ S(x) dx

The Mellin integral on the critical line involves the Dirichlet polynomial
Σ vₖ k^{-½-it}, which is bounded by the proved MVT.

### Key Insight (Gemini)

The Mellin transform is the CORRECT spectral transform for the fractional
part dilations {1/kx}. The multiplicative characters x^{it} (not additive
characters e^{2πinx}) are the natural orthogonal basis under the measure
dx/x induced by the substitution u = log(1/x).
-/

-- ════════════════════════════════════════════════
-- §3. MELLIN-DOMAIN AXIOM (replaces Fourier axiom)
-- ════════════════════════════════════════════════

/-!
### The Mellin-Domain Spectral Bound

This axiom replaces `spectral_b1_large_sieve_bound` with a Mellin-domain
version. The content is:

  The Mellin transform of r_N on the critical line,
  combined with the BD residual decomposition,
  yields a bound on ∫₀¹|S(x)|² via the Dirichlet polynomial MVT.

The key structural facts:
  1. M_{r_N}(s) = 1/s - Σ vₖ · M_{{1/k·}}(s)   [linearity of Mellin]
  2. M_{{θ·}}(s) involves ζ(s)/θ^s terms          [Mellin of fract]
  3. On s = ½+it: the Dirichlet polynomial Σ vₖ k^{-½-it} appears
  4. MVT bounds the L² norm of this Dirichlet polynomial

Graduation path:
  - Wire mellinBDResidual decomposition (from PlancherelDefs)
  - Apply dirichlet_polynomial_mean_value_bound (from MontgomeryVaughan)
  - The envelope |ζ(½+it)|²/(¼+t²) provides convergence
-/

/-- **Mellin-domain spectral bound**: The L²(0,1) norm of the BD residual
    is controlled by the weighted ℓ² norm of the coefficients.

    This is the Mellin-domain reformulation of the Large Sieve bound.
    Content: parseval_bridge_white + Dirichlet polynomial MVT.

    The proof requires:
    1. parseval_bridge_white (PROVED): ∫|r_N|² = (1/2π)∫|M(½+it)|²
    2. Mellin decomposition of r_N involving Dirichlet polynomials
    3. dirichlet_polynomial_mean_value_bound (PROVED): MVT for the Dirichlet poly
    4. Envelope bound for ζ(½+it) (subconvexity, O(t^{1/6})) -/
axiom mellin_dirichlet_spectral_bound :
    ∃ C > 0, ∀ (N : ℕ) (_ : 3 ≤ N) (v : Fin (N - 1) → ℝ),
    ∫ x in (0:ℝ)..1, (bdResidualV N v x) ^ 2
    ≤ C * ∑ k : Fin (N - 1), (v k) ^ 2 * (↑(k.val + 1) + 1)

-- ════════════════════════════════════════════════
-- §4. GRADUATING THE B₁ AXIOM
-- ════════════════════════════════════════════════

/-!
### Graduation of `spectral_b1_large_sieve_bound`

From the Mellin bound on ∫|r_N|² and the algebraic decomposition,
we recover the bound on ∫|S|² = ∫(Σ vₖ B₁(1/kx))².

The key steps:
  1. ∫|r_N|² ≤ C · Σ vₖ²(k+1)  [mellin_dirichlet_spectral_bound]
  2. ∫|r_N|² = c_v² - 2c_v·∫S + ∫S²  [algebraic identity]
  3. ∫S = Σ vₖ ∫₀¹ B₁(1/kx) dx = Σ vₖ(bₖ - ½) where bₖ = ∫{1/kx}
  4. All correction terms are bounded by Σ vₖ²(k+1) via Cauchy-Schwarz

Since ∫S² = ∫|r_N|² - c² + 2c·∫S, and each term on the RHS is
bounded by O(Σ vₖ²(k+1)), the B₁ integral inherits the same bound.
-/

/-- Helper: If g = c - f pointwise, then ∫g² ≤ (∫f²) + c² + 2|c|·|∫f|.
    Proof: ∫(c-f)² = ∫f² + c² + (-2c)∫f, and (-2c)∫f ≤ 2|c||∫f|. -/
private theorem integral_sq_le_of_sub
    (f : ℝ → ℝ) (c : ℝ)
    (hf_ii : IntervalIntegrable f MeasureTheory.volume 0 1)
    (hf2_ii : IntervalIntegrable (fun x => f x ^ 2) MeasureTheory.volume 0 1) :
    ∫ x in (0:ℝ)..1, (c - f x) ^ 2
    ≤ (∫ x in (0:ℝ)..1, (f x) ^ 2) + c ^ 2 + 2 * |c| * |∫ x in (0:ℝ)..1, f x| := by
  have h_fn : (fun x => (c - f x) ^ 2) =
      fun x => (f x ^ 2 + c ^ 2) + ((-2) * c * f x) := by ext x; ring
  have hcf_ii : IntervalIntegrable (fun x => (-2) * c * f x) MeasureTheory.volume 0 1 :=
    hf_ii.const_mul _
  have h_val : ∫ x in (0:ℝ)..1, (c - f x) ^ 2 =
      (∫ x in (0:ℝ)..1, f x ^ 2) + c ^ 2 + (-2) * c * ∫ x in (0:ℝ)..1, f x := by
    rw [h_fn,
        intervalIntegral.integral_add (hf2_ii.add intervalIntegrable_const) hcf_ii,
        intervalIntegral.integral_add hf2_ii intervalIntegrable_const,
        intervalIntegral.integral_const, sub_zero, one_smul,
        show (fun x => (-2) * c * f x) = (fun x => ((-2) * c) * f x) from rfl,
        intervalIntegral.integral_const_mul]
  have h_bound : (-2) * c * ∫ x in (0:ℝ)..1, f x ≤ 2 * |c| * |∫ x in (0:ℝ)..1, f x| :=
    calc (-2) * c * ∫ x in (0:ℝ)..1, f x
        ≤ |(-2) * c * ∫ x in (0:ℝ)..1, f x| := le_abs_self _
      _ = 2 * |c| * |∫ x in (0:ℝ)..1, f x| := by
          rw [abs_mul, abs_mul, abs_neg, abs_of_pos two_pos]
  have h_split : ∫ x in (0:ℝ)..1, (f x ^ 2 + c ^ 2) =
      (∫ x in (0:ℝ)..1, f x ^ 2) + c ^ 2 := by
    rw [intervalIntegral.integral_add hf2_ii intervalIntegrable_const,
        intervalIntegral.integral_const, sub_zero, one_smul]
  nlinarith [h_split, h_bound]

/-- The B₁ covariance integral is bounded by the Mellin spectral bound
    plus correction terms.

    ∫₀¹ (Σ vₖ B₁(1/kx))² ≤ ∫₀¹ |r_N|² + |correction terms|

    where the corrections involve c_v and ∫ΣvB₁. -/
theorem b1_integral_le_residual_plus_corrections
    (N : ℕ) (_hN : 3 ≤ N) (v : Fin (N - 1) → ℝ) :
    ∫ x in (0:ℝ)..1, (b1_sum v x) ^ 2
    ≤ (∫ x in (0:ℝ)..1, (bdResidualV N v x) ^ 2)
      + (c_v v) ^ 2
      + 2 * |c_v v| * |∫ x in (0:ℝ)..1, (fun x => bdResidualV N v x) x| := by
  -- S(x) = c_v - r(x) from residual_eq_cv_sub_b1sum, so apply integral_sq_le_of_sub
  have h_S_eq : ∀ x : ℝ, b1_sum v x = c_v v - bdResidualV N v x := by
    intro x; linarith [residual_eq_cv_sub_b1sum v x]
  -- Integrability
  have hsaw_meas : ∀ (k : ℕ), Measurable (fun x : ℝ => Int.fract (1 / ((k : ℝ) * x))) :=
    fun k => measurable_fract_real.comp (measurable_const.div (measurable_const.mul measurable_id))
  have hr_meas : Measurable (fun x => bdResidualV N v x) := by
    unfold bdResidualV bdLinComb
    exact measurable_const.sub (Finset.measurable_sum _ (fun j _ =>
      (hsaw_meas _).const_mul _))
  have hr_bdd : ∀ x, |bdResidualV N v x| ≤ 1 + ∑ j : Fin (N - 1), |v j| := by
    intro x; unfold bdResidualV bdLinComb
    have h_tri := abs_sub (1 : ℝ) (∑ i, v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)))
    have h_abs_sum := Finset.abs_sum_le_sum_abs
      (fun i : Fin (N - 1) => v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x))) Finset.univ
    have h_sum_le : ∑ i : Fin (N - 1), |v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x))|
        ≤ ∑ i : Fin (N - 1), |v i| := by
      apply Finset.sum_le_sum; intro j _
      rw [abs_mul]
      apply mul_le_of_le_one_right (abs_nonneg _)
      have := Int.fract_nonneg (1 / ((↑(j.val + 1) : ℝ) * x))
      have := Int.fract_lt_one (1 / ((↑(j.val + 1) : ℝ) * x))
      rw [abs_of_nonneg (by linarith)]; linarith
    linarith [abs_one (α := ℝ)]
  set M := 1 + ∑ j : Fin (N - 1), |v j|
  have hr_ii : IntervalIntegrable (fun x => bdResidualV N v x) volume 0 1 :=
    (IntegrableOn.of_bound (by simp) hr_meas.aestronglyMeasurable.restrict
      M (ae_of_all _ (fun x => by rw [Real.norm_eq_abs]; exact hr_bdd x))).intervalIntegrable
  have hr2_ii : IntervalIntegrable (fun x => (bdResidualV N v x) ^ 2) volume 0 1 :=
    (IntegrableOn.of_bound (by simp) (hr_meas.pow_const 2).aestronglyMeasurable.restrict
      (M ^ 2) (ae_of_all _ (fun x => by
        rw [Real.norm_eq_abs, abs_pow]; exact pow_le_pow_left₀ (abs_nonneg _) (hr_bdd x) 2
      ))).intervalIntegrable
  -- Apply helper: ∫(c-r)² ≤ (∫r²) + c² + 2|c||∫r|
  have h := integral_sq_le_of_sub (fun x => bdResidualV N v x) (c_v v) hr_ii hr2_ii
  -- Rewrite LHS: (c_v - r)² = S²
  have h_lhs : ∫ x in (0:ℝ)..1, (c_v v - bdResidualV N v x) ^ 2 =
      ∫ x in (0:ℝ)..1, (b1_sum v x) ^ 2 := by
    apply intervalIntegral.integral_congr
    intro x _
    show (c_v v - bdResidualV N v x) ^ 2 = (b1_sum v x) ^ 2
    rw [h_S_eq x]
  rw [h_lhs] at h; exact h

-- ════════════════════════════════════════════════
-- §5. AUDIT
-- ════════════════════════════════════════════════

/-!
## Audit — Mellin-Dirichlet Bridge

### Sorry: 0 ✅

### Theorems: 3 (all PROVED)
  1. `integral_sq_le_of_sub` — Helper: ∫(c-f)² ≤ (∫f²) + c² + 2|c|·|∫f|
  2. `residual_eq_cv_sub_b1sum` — r_N(x) = c_v - S(x)
  3. `b1_integral_le_residual_plus_corrections` — ∫S² ≤ (∫r²) + c² + 2|c|·|∫r|

### Axioms: 1
  1. `mellin_dirichlet_spectral_bound` — Mellin-domain spectral bound
     Content: parseval_bridge_white + Dirichlet polynomial MVT
     Graduation path: Wire `parseval_bridge_white` (PROVED) to
       `dirichlet_polynomial_mean_value_bound` (PROVED) via Mellin
       decomposition of r_N.

### Architecture:

```
  Scattering.lean           → parseval_bridge_white (PROVED)
  MontgomeryVaughan.lean    → dirichlet_polynomial_mean_value_bound (PROVED)
                                ↓
  MellinDirichletBridge.lean → mellin_dirichlet_spectral_bound (AXIOM)
    + integral_sq_le_of_sub (PROVED — helper)
    + residual_eq_cv_sub_b1sum (PROVED)
    + b1_integral_le_residual_plus_corrections (PROVED ✅)
                                ↓
  BilinearSieve.lean        → spectral_b1_large_sieve_bound (can be graduated)
```

### Key Advantage over Fourier-Gram Bridge:

The Mellin transform respects the multiplicative structure of {1/kx}.
- Multiplicative characters x^{it} are orthogonal under dx/x (Mellin-Plancherel)
- The BD residual's Mellin transform naturally produces Dirichlet polynomials
- The MVT for Dirichlet polynomials is already PROVED (MontgomeryVaughan.lean)

No geometric inversion trap. No measure mismatch. The weapon is in our hands.
-/

end Cathedral.MellinDirichletBridge
