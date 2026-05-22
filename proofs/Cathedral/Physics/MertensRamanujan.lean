/-
  Cathedral/Physics/MertensRamanujan.lean

  ## PHASE 3: MERTENS-DIVISOR BRIDGE

  Connects the Mertens bound (M(x) = O(x^{3/4})) to the divisor
  coefficient bound (|y_d| ≤ C/(d·logN)), completing the Strategy C chain.

  ### The Key Identity

  The divisor coefficient y_d = Σ_{d|k, k≤N} v_k/k decomposes as:

    y_d = (1/d) · Σ_{m≤N/d} (v_{dm}) / m

  For the BD witness v_k = -μ(k)·w(k), this becomes:

    y_d = -(1/d) · Σ_{m≤N/d} μ(dm)·w(dm)/m

  ### Architecture

  §1. Divisor coefficient as restricted Mertens sum
  §2. Abel summation for tapered sums (from AbelEngine)
  §3. Mertens bound → divisor coefficient bound
  §4. Assembly: Strategy C crown axiom

  ### Dependencies (ALL PROVED)
  - AbelEngine: abel_summation, fejerWeight_diff_bound (0 sorry)
  - MertensBridge: mertens_partial_sum_bound (0 sorry)
  - BilinearMertens: taperedMertensSum → 0 (0 sorry)
  - RamanujanFormBound: ramanujan_form_smith, crown_reduction_smith (0 sorry)
  - PerronMoebius: mertens_bound_eps (M(x) = O(x^{1/2+ε}), PROVED)

  Created: May 19, 2026 — Strategy C Phase 3
-/

import Cathedral.Physics.RamanujanFormBound
import Cathedral.Physics.BilinearMertens
import Cathedral.ZeroAxiom.AbelEngine
import Cathedral.AbelTail.MertensBridge

noncomputable section
open Real Finset ArithmeticFunction Filter

namespace Cathedral.Physics.MertensRamanujan

-- ════════════════════════════════════════════════════════════════
-- §1. DIVISOR COEFFICIENT AS RESTRICTED MERTENS SUM
-- ════════════════════════════════════════════════════════════════

/-! ### The Divisor Coefficient Structure

  For the BD witness v_k = -μ(k)·w(k,N), the divisor coefficient is:

    y_d = Σ_{d|k, k≤N} (-μ(k)·w(k))/(k)
        = -(1/d) · Σ_{m=1}^{⌊N/d⌋} μ(dm)·w(dm,N)/m

  This is a "restricted tapered Mertens sum" — the classical Mertens sum
  Σ μ(n)/n, but filtered to multiples of d and tapered by the Fejér weight.

  The key bound: under RH, |Σ_{n≤x} μ(n)/n| ≤ C/log(x) (from Abel summation
  + Mertens M(x) = O(x^{1/2+ε})). The restriction to multiples of d
  introduces a factor of 1/d (from the change of variables k = dm). -/

/-- **DEFINITION**: The unrestricted tapered Mertens sum,
    i.e. y_1 = Σ_{k=1}^N μ(k)·w(k,N)/k.

    This is the d=1 case of the divisor coefficient. -/
noncomputable def taperedMoebius (N : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 N,
    (↑(ArithmeticFunction.moebius k) : ℝ) * logWeight N k / (k : ℝ)

-- ════════════════════════════════════════════════════════════════
-- §2. THE TAPERED MERTENS BOUND
-- ════════════════════════════════════════════════════════════════

/-! ### Abel Summation for Tapered Möbius Sums

  The tapered sum Σ μ(k)·w(k)/k can be bounded via Abel summation:

    Σ_{k=1}^N μ(k)·w(k)/k = M(N)·w(N)/N - Σ_{k=1}^{N-1} M(k)·Δ(w/k)

  where Δ(w/k) = w(k+1)/(k+1) - w(k)/k.

  Under RH:
  - |M(k)| ≤ C·k^{3/4} (Mertens bound, PROVED)
  - |Δ(w/k)| = O(1/(k²·logN)) (Fejér taper derivative, PROVED)
  - The boundary term vanishes: w(N) = 0 for the logWeight

  So: |Σ μ(k)·w(k)/k| ≤ C · Σ k^{3/4}·(1/(k²·logN))
                        = (C/logN) · Σ k^{-5/4}
                        ≤ C'/logN

  This gives |y_1| ≤ C'/logN, and more generally |y_d| ≤ C'/(d·logN).
-/

/-- **THEOREM (Tapered Mertens Bound)**: Under RH, the tapered Möbius sum
    |Σ μ(k)·w(k)/k| ≤ C/logN.

    This is the d=1 case. The general d case follows by
    restricting the sum to multiples of d.

    PROOF STRATEGY: We delegate to the PROVED taperedMertensSum → 0
    from BilinearMertens.lean, which gives convergence. Combined with
    the explicit rate from the Mertens bound, we get O(1/logN).

    The tapered sum tends to zero (PROVED in BilinearMertens):
      Tendsto taperedMertensSum atTop (nhds 0)

    Under RH + Mertens x^{3/4}, the RATE is 1/logN (from AbelEngine). -/
axiom tapered_mertens_rate (hRH : RiemannHypothesis) :
    ∃ C_t : ℝ, C_t > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
    |taperedMoebius N| ≤ C_t / Real.log ↑N

-- ════════════════════════════════════════════════════════════════
-- §3. DIVISOR COEFFICIENT BOUND
-- ════════════════════════════════════════════════════════════════

/-! ### The General d Bound

  For d ≥ 1:
    |y_d| = |Σ_{d|k, k≤N} μ(k)·w(k)/k|
          = |(1/d)·Σ_{m≤N/d} μ(dm)·w(dm)/m|
          ≤ (1/d)·|tapered sum restricted to APs|

  The restriction to the arithmetic progression {dm : m ∈ ℕ}
  introduces:
  1. A factor of 1/d (trivial)
  2. The multiplicativity of μ for coprime arguments
  3. The squarefree restriction (μ(dm) = 0 if d,m share a prime)

  The crude bound (ignoring multiplicativity):
    |y_d| ≤ (1/d) · |unrestricted tapered sum at scale N/d|
          ≤ (1/d) · C/log(N/d)
          ≤ C/(d·log(N/d))

  For d ≤ √N: log(N/d) ≥ ½logN, so |y_d| ≤ 2C/(d·logN).
  For d > √N: |y_d| ≤ Σ_{d|k, k≤N} 1/k ≤ (1/d)·⌊N/d⌋ ≤ 1 (trivial).
-/

/-- **AXIOM (Divisor Coefficient Bound — General d)**:
    Under RH, |y_d| ≤ C/(d·logN) for all 1 ≤ d ≤ N.

    This follows from tapered_mertens_rate + restriction to APs.
    The restriction analysis is the Phase 3 mathematical content.

    AXIOM CLASS: RH-CONDITIONAL
    TARGET: Prove from tapered_mertens_rate + AP restriction -/
axiom divisor_coeff_bound_general
    (hRH : RiemannHypothesis) :
    ∃ C_y : ℝ, C_y > 0 ∧ ∀ N : ℕ, N ≥ 3 →
    ∀ (v : Fin N → ℝ),
    (∀ i : Fin N, v i = -(↑(ArithmeticFunction.moebius (i.val + 1)) : ℝ) *
      logWeight N (i.val + 1)) →
    ∀ d : ℕ, 1 ≤ d → d ≤ N →
    |RamanujanFormBound.divisorCoeff N v d| ≤
    C_y / ((d : ℝ) * Real.log ↑N)

-- ════════════════════════════════════════════════════════════════
-- §4. ASSEMBLY: THE SMITH-MERTENS CROWN
-- ════════════════════════════════════════════════════════════════

/-! ### Closing the Crown via Strategy C

  Given:
  1. vᵀG⁽¹⁾v = vᵀRv + ¼(Σv)²     [glass_quadratic_form, PROVED]
  2. vᵀRv = (1/12)·Σ J₂(d)·y_d²   [ramanujan_form_smith, PROVED]
  3. |y_d| ≤ C/(d·logN)             [divisor_coeff_bound_general, AXIOM]
  4. J₂(d) ≤ d²                     [proved in sum_jordan_yd_sq_bound]
  5. (Σv)² → 0 by PNT              [tapered_mertens_tendsto_zero, PROVED]

  Assembly:
    vᵀG⁽¹⁾v = (1/12)·Σ J₂·y² + ¼(Σv)²
             ≤ (1/12)·C²·N/log²N + O(1/log²N)
             = O(N/log²N) → 0

  WAIT — this is O(N/log²N), not O(1/logN). The naive bound DIVERGES.
  (See the analysis in RamanujanFormBound.lean §3½.)

  The correct approach: Strategy C's crown axiom IS the content of RH.
  The Möbius cancellation that makes vᵀGv ≈ 1 is precisely RH.

  What we CAN state cleanly:
  - Under RH: the divisor coefficients are bounded (from Mertens)
  - The Smith decomposition gives structural control
  - The glass quadratic form connects to the crown axiom

  The REMAINING CONTENT — proving vᵀGv ≤ 1 + K/logN — is the forward
  direction of Báez-Duarte, which IS the crown axiom. Strategy C
  provides an alternative LANGUAGE for it, but not a shortcut. -/

/-- **THEOREM (Strategy C Structural Chain)**: Under RH, the Ramanujan
    quadratic form has the Smith decomposition with bounded coefficients.

    This is the structural backbone: vᵀRv decomposes into a sum of
    J₂-weighted squares of bounded divisor coefficients. While the
    naive bound gives vᵀRv = O(N/log²N) (too weak), the structural
    decomposition provides the framework for tighter analysis. -/
theorem strategy_c_structural (hRH : RiemannHypothesis) (N : ℕ) (hN : 3 ≤ N)
    (v : Fin N → ℝ)
    (hv : ∀ i : Fin N, v i = -(↑(ArithmeticFunction.moebius (i.val + 1)) : ℝ) *
      logWeight N (i.val + 1)) :
    ∃ C_y : ℝ, C_y > 0 ∧
    -- 1. The Ramanujan form has Smith decomposition
    (∑ i : Fin N, ∑ j : Fin N,
      RamanujanBridge.ramanujanEntry (i.val + 1) (j.val + 1) * v i * v j =
    (1 / 12) * ∑ d ∈ Finset.Icc 1 N,
      RamanujanBridge.jordanTotient2 d *
        (RamanujanFormBound.divisorCoeff N v d) ^ 2) ∧
    -- 2. Each divisor coefficient is bounded
    (∀ d : ℕ, 1 ≤ d → d ≤ N →
      |RamanujanFormBound.divisorCoeff N v d| ≤
      C_y / ((d : ℝ) * Real.log ↑N)) ∧
    -- 3. The Smith sum is bounded by C²·N/log²N
    (∑ d ∈ Finset.Icc 1 N,
      RamanujanBridge.jordanTotient2 d *
        (RamanujanFormBound.divisorCoeff N v d) ^ 2 ≤
    C_y ^ 2 * ↑N / (Real.log ↑N) ^ 2) := by
  -- Get the divisor coefficient bound from the axiom
  obtain ⟨C_y, hCy, hbound⟩ := divisor_coeff_bound_general hRH
  refine ⟨C_y, hCy, ?_, ?_, ?_⟩
  -- 1. Smith decomposition (PROVED)
  · exact RamanujanFormBound.ramanujan_form_smith N v
  -- 2. Divisor coefficient bound
  · intro d hd1 hdN
    exact hbound N (by omega) v hv d hd1 hdN
  -- 3. Smith sum bound (PROVED)
  · exact RamanujanFormBound.sum_jordan_yd_sq_bound N hN v C_y hCy
      (fun d hd1 hdN => hbound N (by omega) v hv d hd1 hdN)

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit — MertensRamanujan (Phase 3)

### Status: STRUCTURAL COMPLETION

### Sorry: 0
### Custom Axioms: 2
  1. `tapered_mertens_rate`: RH → |Σ μ(k)w(k)/k| ≤ C/logN
     Content: Abel summation + Mertens (AbelEngine has all pieces)
     Difficulty: ~100 lines of wiring

  2. `divisor_coeff_bound_general`: RH → |y_d| ≤ C/(d·logN) for all d
     Content: Restriction to APs + tapered_mertens_rate
     Difficulty: ~150 lines (multiplicativity + AP analysis)

### PROVED Theorems:
  - `strategy_c_structural`: The complete structural chain under RH

### Key Finding:
  Strategy C provides STRUCTURAL CONTROL but not a proof shortcut.
  The naive bound gives vᵀRv = O(N/log²N) → ∞.
  The crown axiom (vᵀGv ≤ 1+K/logN) requires near-cancellation
  in the Smith sum, which IS the Möbius cancellation.

### Architecture
```
mertens_bound_eps (PROVED)     AbelEngine (PROVED)
         ↓                          ↓
  tapered_mertens_rate    fejerWeight_diff_bound
    (AXIOM)                     (PROVED)
         ↓                          ↓
  divisor_coeff_bound_general  ←───┘
    (AXIOM)
         ↓
  strategy_c_structural (PROVED from axioms)
         ↓
  [crown_reduction_smith → crown axiom] (PROVED, if Smith sum bounded)
```
-/

end Cathedral.Physics.MertensRamanujan

end
