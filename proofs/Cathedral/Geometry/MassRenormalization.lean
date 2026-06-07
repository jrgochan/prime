/-
  Cathedral/Geometry/MassRenormalization.lean

  ## THE MASS RENORMALIZATION THEOREM

  ════════════════════════════════════════════════════════════════

  THE ALGEBRAIC IDENTITY:

  d²(v) · logN = (vᵀGv - 1) · logN + 2 · (1 - bᵀv) · logN

  If we define:
    K₁ = lim_{N→∞} (1 - bᵀv) · logN = 1 + γ
    L₁ = lim_{N→∞} (vᵀGv - 1) · logN = -γ - log(4π)

  Then:
    L₁ + 2·K₁ = (-γ - log4π) + 2(1 + γ)
               = -γ - log4π + 2 + 2γ
               = 2 + γ - log4π
               = c_holes

  This algebraic identity is EXACT and does not depend on any
  analytic estimates. It shows that if the two components converge
  to their predicted limits, d²(v)·logN necessarily converges to
  the Báez-Duarte constant c_holes.

  This file proves the algebraic glue. The analytic lemmas
  (K₁ and L₁ limits) are stated as axioms for now.

  Created: June 7, 2026 — Mass Renormalization Campaign 🌀
-/

import Cathedral.Vasyunin.Defs
import Cathedral.Vasyunin.Witness
import Cathedral.Geometry.BernoulliDiagonal

set_option maxHeartbeats 800000

noncomputable section
open Real Finset

namespace Cathedral.Geometry.MassRenormalization

open Cathedral.Vasyunin
open Cathedral.Geometry.BernoulliDiagonal

-- ════════════════════════════════════════════════════════════════
-- §1. THE CORE ALGEBRAIC DECOMPOSITION
-- ════════════════════════════════════════════════════════════════

/-- **THE PYTHAGOREAN DECOMPOSITION**: The BD distance splits as
    d²(v) = (vᵀGv - 1) + 2·(1 - bᵀv)

    This is pure algebra: 1 - 2x + y = (y - 1) + 2(1 - x). -/
theorem distance_sq_decomposition (btv vtGv : ℝ) :
    1 - 2 * btv + vtGv = (vtGv - 1) + 2 * (1 - btv) := by ring

/-- **THE SCALED DECOMPOSITION**: Multiplying by logN:
    d²(v) · logN = (vᵀGv - 1) · logN + 2 · (1 - bᵀv) · logN -/
theorem distance_sq_scaled_decomposition (btv vtGv logN : ℝ) :
    (1 - 2 * btv + vtGv) * logN =
    (vtGv - 1) * logN + 2 * (1 - btv) * logN := by ring

-- ════════════════════════════════════════════════════════════════
-- §2. THE CONSTANT IDENTITY
-- ════════════════════════════════════════════════════════════════

/-- **c_holes = L₁ + 2·K₁**:

    The Báez-Duarte constant decomposes as:
      c_holes = 2 + γ - log(4π)
              = (-γ - log(4π)) + 2·(1 + γ)
              = L₁ + 2·K₁

    where K₁ = 1 + γ and L₁ = -γ - log(4π).

    This is the algebraic self-consistency of the mass renormalization:
    the two individually divergent components sum to the physical constant. -/
theorem c_holes_decomposition (γ : ℝ) (log4pi : ℝ) :
    let K₁ := 1 + γ
    let L₁ := -γ - log4pi
    let c_holes := 2 + γ - log4pi
    c_holes = L₁ + 2 * K₁ := by
  simp only []
  ring

-- ════════════════════════════════════════════════════════════════
-- §3. THE CONVERGENCE FRAMEWORK
-- ════════════════════════════════════════════════════════════════

/-- If two sequences converge, their linear combination converges
    to the corresponding linear combination of limits.

    This is the bridge: given K₁ and L₁ limits,
    d²(v)·logN converges to L₁ + 2·K₁ = c_holes. -/
theorem limit_sum_eq {f g : ℕ → ℝ} {a b : ℝ}
    (hf : Filter.Tendsto f Filter.atTop (nhds a))
    (hg : Filter.Tendsto g Filter.atTop (nhds b)) :
    Filter.Tendsto (fun n => f n + 2 * g n)
      Filter.atTop (nhds (a + 2 * b)) := by
  exact hf.add (hg.const_mul 2)

-- ════════════════════════════════════════════════════════════════
-- §4. THE AXIOMS (analytic lemmas, to be graduated)
-- ════════════════════════════════════════════════════════════════

/-- **MERTENS LEMMA (Lemma 1)**:
    (1 - bᵀv) · logN → K₁ = 1 + γ

    This follows from:
    bᵀv = -Σ μ(k)/k · (logk + 1 - γ) · (1 - logk/logN)
    and the Mertens estimates Σ μ(k)logk/k → -1, Σ μ(k)/k → 0.

    STATUS: Axiomatized. Requires PNT-level Mertens estimates. -/
axiom margin_limit (btv_seq : ℕ → ℝ) (γ_val : ℝ)
    (hγ : γ_val = Real.eulerMascheroniConstant)
    (h_btv : ∀ N : ℕ, 3 ≤ N → btv_seq N =
      ∑ i : Fin N, logCutoffWitness N i * vasyuninMeanEntry (i.val + 1)) :
    Filter.Tendsto (fun N => (1 - btv_seq N) * Real.log ↑N)
      Filter.atTop (nhds (1 + γ_val))

/-- **GRAM ASYMPTOTICS (Lemma 2)**:
    (vᵀGv - 1) · logN → L₁ = -γ - log(4π)

    This follows from analyzing the double Möbius sum
    vᵀGv = Σ_{j,k} μ(j)μ(k)·taper(j)·taper(k)·G(j,k)
    using GCD stratification and Euler products.

    STATUS: Axiomatized. Requires Gram quadratic form analysis. -/
axiom gram_limit (vtGv_seq : ℕ → ℝ) (γ_val : ℝ)
    (hγ : γ_val = Real.eulerMascheroniConstant)
    (h_vtGv : ∀ N : ℕ, 3 ≤ N → vtGv_seq N =
      ∑ i : Fin N, ∑ j : Fin N,
        logCutoffWitness N i * vasyuninGramEntry (i.val + 1) (j.val + 1) *
        logCutoffWitness N j) :
    Filter.Tendsto (fun N => (vtGv_seq N - 1) * Real.log ↑N)
      Filter.atTop (nhds (-γ_val - Real.log (4 * Real.pi)))

-- ════════════════════════════════════════════════════════════════
-- §5. THE MAIN THEOREM
-- ════════════════════════════════════════════════════════════════

/-- **THE MASS RENORMALIZATION THEOREM**:

    d²(v) · logN → c_holes = 2 + γ - log(4π)

    Chain:
    1. d²(v) = (vᵀGv - 1) + 2·(1 - bᵀv)     [algebraic]
    2. (vᵀGv - 1)·logN → L₁ = -γ - log4π     [Gram asymptotics]
    3. (1 - bᵀv)·logN → K₁ = 1 + γ            [Mertens]
    4. d²(v)·logN → L₁ + 2K₁ = c_holes         [sum of limits]

    The log-cutoff Möbius witness is ASYMPTOTICALLY OPTIMAL:
    it achieves the Báez-Duarte constant in the limit. -/
theorem mass_renormalization
    (btv_seq vtGv_seq d2_seq : ℕ → ℝ)
    (γ_val : ℝ)
    (hγ : γ_val = Real.eulerMascheroniConstant)
    (h_d2 : ∀ N, d2_seq N = 1 - 2 * btv_seq N + vtGv_seq N)
    (h_margin : Filter.Tendsto (fun N => (1 - btv_seq N) * Real.log ↑N)
                  Filter.atTop (nhds (1 + γ_val)))
    (h_gram : Filter.Tendsto (fun N => (vtGv_seq N - 1) * Real.log ↑N)
                Filter.atTop (nhds (-γ_val - Real.log (4 * Real.pi)))) :
    Filter.Tendsto (fun N => d2_seq N * Real.log ↑N)
      Filter.atTop (nhds (2 + γ_val - Real.log (4 * Real.pi))) := by
  -- Step 1: Rewrite d²(v) using algebraic decomposition
  have h_decomp : ∀ N, d2_seq N * Real.log ↑N =
      (vtGv_seq N - 1) * Real.log ↑N + 2 * ((1 - btv_seq N) * Real.log ↑N) := by
    intro N; rw [h_d2 N]; ring
  -- Step 2: The limit is L₁ + 2·K₁
  have h_target : 2 + γ_val - Real.log (4 * Real.pi) =
      (-γ_val - Real.log (4 * Real.pi)) + 2 * (1 + γ_val) := by ring
  rw [h_target]
  -- Step 3: Apply limit_sum_eq
  have h_sum := limit_sum_eq h_gram h_margin
  exact Filter.Tendsto.congr (fun N => (h_decomp N).symm) h_sum

-- ════════════════════════════════════════════════════════════════
-- §6. COROLLARY: APPROXIMATION ERROR VANISHES
-- ════════════════════════════════════════════════════════════════

/-- **COROLLARY**: ‖δ‖²_G · logN → 0.

    Since d²(v) = d²_opt + ‖δ‖²_G and d²_opt·logN → c_holes,
    the approximation error ‖δ‖²_G · logN → 0.

    The log-cutoff witness produces zero relative error at scale. -/
theorem approx_error_vanishes
    (d2_seq d2opt_seq delta_sq_seq : ℕ → ℝ)
    (c_holes : ℝ)
    (h_pyth : ∀ N, d2_seq N = d2opt_seq N + delta_sq_seq N)
    (h_d2 : Filter.Tendsto (fun N => d2_seq N * Real.log ↑N)
              Filter.atTop (nhds c_holes))
    (h_opt : Filter.Tendsto (fun N => d2opt_seq N * Real.log ↑N)
              Filter.atTop (nhds c_holes)) :
    Filter.Tendsto (fun N => delta_sq_seq N * Real.log ↑N)
      Filter.atTop (nhds 0) := by
  have h_sub : ∀ N, delta_sq_seq N * Real.log ↑N =
      d2_seq N * Real.log ↑N - d2opt_seq N * Real.log ↑N := by
    intro N; rw [h_pyth N]; ring
  have h_diff := Filter.Tendsto.sub h_d2 h_opt
  simp only [sub_self] at h_diff
  exact Filter.Tendsto.congr (fun N => (h_sub N).symm) h_diff

-- ════════════════════════════════════════════════════════════════
-- §7. AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit (June 7, 2026 — Mass Renormalization Theorem)

### Sorry: 0 ✅
### Custom Axioms: 2
  - `margin_limit`: (1-bᵀv)·logN → 1+γ (Mertens-type, needs PNT)
  - `gram_limit`: (vᵀGv-1)·logN → -γ-log4π (Gram asymptotics)

### Theorems PROVED:
| # | Result | Status | Content |
|---|--------|--------|---------|
| 1 | `distance_sq_decomposition` | ✅ | d² = (vGv-1) + 2(1-bv) |
| 2 | `distance_sq_scaled_decomposition` | ✅ | Scaled version |
| 3 | `c_holes_decomposition` | ✅ | c = L₁ + 2K₁ |
| 4 | `limit_sum_eq` | ✅ | Sum of limits |
| 5 | `mass_renormalization` | ✅ | THE MAIN THEOREM |
| 6 | `approx_error_vanishes` | ✅ | ‖δ‖²_G·logN → 0 |
-/

end Cathedral.Geometry.MassRenormalization

end
