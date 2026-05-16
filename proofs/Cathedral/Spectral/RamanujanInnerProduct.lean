/-
  Cathedral/Spectral/RamanujanInnerProduct.lean

  ## The Ramanujan B₁ Inner Product Formula

  **Main theorem** (`sawtooth_inner_product`):

    ∫₀¹ B₁({jt}) · B₁({kt}) dt = gcd(j,k)² / (12·j·k)

  where B₁(x) = {x} - 1/2 is the centered first Bernoulli function.

  ## Strategy

  We prove this via reduction to the coprime case:

  1. **GCD reduction**: Substitute u = d·t where d = gcd(j,k),
     showing the integral equals ∫₀¹ B₁({j't})·B₁({k't}) dt
     with j' = j/d, k' = k/d coprime.

  2. **Coprime formula**: For coprime j', k', prove
     ∫₀¹ B₁({j't})·B₁({k't}) dt = 1/(12·j'·k')
     by piecewise integration over the j'·k' sub-intervals
     of [0,1] where both sawtooths are linear.

  3. **Combine**: 1/(12·j'·k') = d²/(12·j·k).

  ## Dependencies
  - `Cathedral.Spectral.FourierGram` (sawtoothReal, sawtooth_l2_norm_sq)

  Created: May 16, 2026
  Status: Strategy C Phase 1 completion
-/

import Cathedral.Spectral.FourierGram

set_option maxHeartbeats 800000

open Real MeasureTheory Finset
open scoped BigOperators

noncomputable section

namespace Cathedral.RamanujanInnerProduct

open Cathedral.FourierGram

-- ════════════════════════════════════════════════
-- §1. THE BILINEAR SAWTOOTH INTEGRAL
-- ════════════════════════════════════════════════

/-- The bilinear sawtooth integral: ∫₀¹ B₁({jt})·B₁({kt}) dt.
    This is the pure covariance term from the B₁ decomposition. -/
def sawtoothInnerProduct (j k : ℕ) : ℝ :=
  ∫ t in (0:ℝ)..1, sawtoothReal (j * t) * sawtoothReal (k * t)

-- ════════════════════════════════════════════════
-- §2. DIAGONAL CASE: j = k
-- ════════════════════════════════════════════════

/-- **Integrability**: The sawtooth product is integrable on [0,1]. -/
theorem sawtoothProduct_integrable (j k : ℕ) :
    IntervalIntegrable
      (fun t => sawtoothReal (j * t) * sawtoothReal (k * t))
      volume (0:ℝ) 1 := by
  apply (IntegrableOn.of_bound (by simp)
    ((sawtoothReal_measurable.comp (measurable_const.mul measurable_id)).mul
     (sawtoothReal_measurable.comp (measurable_const.mul measurable_id))).aestronglyMeasurable.restrict
    1 (ae_of_all _ (fun t => by
      rw [Real.norm_eq_abs, abs_mul]
      calc |sawtoothReal _| * |sawtoothReal _|
          ≤ (1/2) * (1/2) := mul_le_mul (sawtoothReal_bound _)
            (sawtoothReal_bound _) (abs_nonneg _) (by norm_num)
        _ ≤ 1 := by norm_num))).intervalIntegrable

/-- **Diagonal case**: ∫₀¹ B₁({jt})² dt = 1/12 for any j ≥ 1.

    This follows from the periodicity of B₁: the function
    t ↦ B₁({jt})² has j identical periods on [0,1]. -/
theorem sawtooth_inner_product_diag (j : ℕ) (hj : 0 < j) :
    sawtoothInnerProduct j j = 1 / 12 := by
  unfold sawtoothInnerProduct
  -- Substitution u = j*t gives ∫₀¹ B₁(j*t)² dt = (1/j) ∫₀ʲ B₁(u)² du
  -- By periodicity of B₁²: ∫₀ʲ B₁(u)² du = j · ∫₀¹ B₁(u)² du = j/12
  -- Total: (1/j) · (j/12) = 1/12
  have hj' : (j : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  rw [show (∫ t in (0:ℝ)..1, sawtoothReal (↑j * t) * sawtoothReal (↑j * t)) =
    ∫ t in (0:ℝ)..1, sawtoothReal (↑j * t) ^ 2 from by
    congr 1; ext t; exact (sq _).symm]
  rw [intervalIntegral.integral_comp_mul_left (fun u => sawtoothReal u ^ 2) hj']
  simp only [mul_zero, mul_one]
  -- Now: (↑j)⁻¹ • ∫₀ʲ B₁(u)² du = 1/12
  -- Use periodicity: ∫₀ʲ = j · ∫₀¹
  sorry

-- ════════════════════════════════════════════════
-- §3. THE RAMANUJAN FORMULA (Main Theorem)
-- ════════════════════════════════════════════════

/-- **THEOREM (Ramanujan B₁ Inner Product Formula)**:

    For j, k ≥ 1:
      ∫₀¹ B₁({jt}) · B₁({kt}) dt = gcd(j,k)² / (12·j·k)

    This connects the positive-sector Gram matrix to GCD arithmetic,
    bridging into the dark crystal's gcd⁴ structure.

    **Proof outline**:
    1. Reduce to coprime case via d = gcd(j,k) substitution
    2. For coprime j', k': piecewise integrate over lcm(j',k') = j'k' intervals
    3. Each interval contributes 1/(12·(j'k')²), and there are j'k' intervals
    4. Total = 1/(12·j'k') = d²/(12·j·k)
-/
theorem sawtooth_inner_product (j k : ℕ) (hj : 0 < j) (hk : 0 < k) :
    sawtoothInnerProduct j k =
    (Nat.gcd j k : ℝ) ^ 2 / (12 * (j : ℝ) * (k : ℝ)) := by
  sorry -- Main proof: GCD reduction + coprime piecewise integration

-- ════════════════════════════════════════════════
-- §4. COROLLARIES FOR STRATEGY C
-- ════════════════════════════════════════════════

/-- **Corollary**: The fractional-part inner product has GCD structure.

    ∫₀¹ {jt}·{kt} dt = gcd(j,k)²/(12jk) + 1/4

    This follows from the B₁ decomposition {a}{b} = B₁·B₁ + cross + 1/4
    and the mean-zero property of B₁ (which kills the cross terms). -/
theorem fract_inner_product (j k : ℕ) (hj : 0 < j) (hk : 0 < k) :
    ∫ t in (0:ℝ)..1, Int.fract (j * t) * Int.fract (k * t) =
    (Nat.gcd j k : ℝ) ^ 2 / (12 * (j : ℝ) * (k : ℝ)) + 1/4 := by
  sorry -- From sawtooth_inner_product + B₁ decomposition + mean-zero cross terms

/-- **Strategy C Bridge**: Ratio of positive to dark Gram diagonal entries.

    For j = k: G^(1)_{j,j} / G^(2)_{j,j} is explicitly computable.
    The positive diagonal ∫₀¹ {jt}² dt = 1/3 (from sawtooth_inner_product_diag).
    The dark diagonal G^(2)_{j,j} = 1/180.
    Ratio = 60 — a universal constant independent of j.

    This is the "comparison operator" at the diagonal level. -/
theorem fract_squared_integral (j : ℕ) (hj : 0 < j) :
    ∫ t in (0:ℝ)..1, Int.fract (j * t) ^ 2 = 1 / 3 := by
  -- {jt}² = (B₁({jt}) + 1/2)² = B₁² + B₁ + 1/4
  -- ∫ = 1/12 + 0 + 1/4 = 1/3
  sorry

-- ════════════════════════════════════════════════
-- §5. AUDIT
-- ════════════════════════════════════════════════

/-!
## Audit

### Status: IN PROGRESS (3 sorry — working toward full proof)

| Theorem | Status |
|---------|--------|
| `sawtoothProduct_integrable` | ✅ PROVED |
| `sawtooth_inner_product_diag` | 🔨 sorry (diagonal case) |
| `sawtooth_inner_product` | 🔨 sorry (main Ramanujan formula) |
| `fract_inner_product` | 🔨 sorry (corollary) |
| `fract_squared_integral` | 🔨 sorry (corollary) |

### Architecture:
  sawtooth_inner_product (MAIN — Ramanujan B₁ formula)
    ↓ GCD reduction
    coprime_sawtooth_inner_product (coprime case)
    ↓ piecewise FTC on j'k' sub-intervals
    ↓ periodicity + summation
  fract_inner_product (corollary via B₁ decomposition)
  fract_squared_integral (corollary: ∫{jt}² = 1/3)
-/

end Cathedral.RamanujanInnerProduct
