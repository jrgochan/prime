/-
  Cathedral.Physics.MertensBridge
  ================================

  THE BRIDGE: Physics Layer ↔ PNT Layer

  Connects the overcancellation decomposition (AbelHammer, LogCorr, CotRes)
  with PNT sub-sums for the Mertens weight family.

  Key identities:
    σ = -A₁ + A₂/ln(N)      where A₁ = Σ μ(k)/(k+1), A₂ = Σ μ(k)·ln(k+1)/(k+1)
    S = -B₁ + B₂/ln(N)      where B₁ = Σ μ(k)/(k+1)², B₂ = Σ μ(k)·ln(k+1)/(k+1)²

  Status: 0 sorry
  Dependencies: MertensHarmony.lean
  Created: May 21, 2026 — Path 4.5, Step 1
-/

import Cathedral.Physics.Mertens.MertensHarmony
import Mathlib.Tactic.FieldSimp
import Mathlib.Algebra.BigOperators.Field

noncomputable section
open Real Finset Cathedral.AbelHammer Cathedral.MertensHarmony

namespace Cathedral.MertensBridge

-- ════════════════════════════════════════════════════════
-- §1. PNT-STYLE SUB-SUMS (Fin N indexed)
-- ════════════════════════════════════════════════════════

/-- A₁(N) = Σ μ(k)/(k+1) — the Möbius harmonic sum. By PNT: → 0. -/
noncomputable def moebSum1 (N : ℕ) (μ : ℕ → ℝ) : ℝ :=
  ∑ k : Fin N, μ (k : ℕ) / (↑(k : ℕ) + 1 : ℝ)

/-- A₂(N) = Σ μ(k)·ln(k+1)/(k+1). By PNT derivative: → -1. -/
noncomputable def moebSum2 (N : ℕ) (μ : ℕ → ℝ) : ℝ :=
  ∑ k : Fin N, μ (k : ℕ) * Real.log (↑(k : ℕ) + 1 : ℝ) / (↑(k : ℕ) + 1 : ℝ)

/-- B₁(N) = Σ μ(k)/(k+1)². Converges to 6/π² unconditionally. -/
noncomputable def moebSumSq1 (N : ℕ) (μ : ℕ → ℝ) : ℝ :=
  ∑ k : Fin N, μ (k : ℕ) / ((↑(k : ℕ) + 1 : ℝ) * (↑(k : ℕ) + 1 : ℝ))

/-- B₂(N) = Σ μ(k)·ln(k+1)/(k+1)². -/
noncomputable def moebSumSq2 (N : ℕ) (μ : ℕ → ℝ) : ℝ :=
  ∑ k : Fin N, μ (k : ℕ) * Real.log (↑(k : ℕ) + 1 : ℝ) /
    ((↑(k : ℕ) + 1 : ℝ) * (↑(k : ℕ) + 1 : ℝ))

-- ════════════════════════════════════════════════════════
-- §2. SIGMA BRIDGE
-- ════════════════════════════════════════════════════════

/-- **THEOREM**: σ for Mertens weights = -A₁ + A₂/ln(N).

    Proof: Expand mertensWeight, distribute the sum, and collect.
    The key technique: rewrite each summand via `congr` + `ring`,
    then use `sum_add_distrib` to split into two sums. -/
theorem sigma_decomp (N : ℕ) (μ : ℕ → ℝ) :
    moebiusSigma N (mertensWeight N μ) =
    -moebSum1 N μ + moebSum2 N μ / Real.log (N : ℝ) := by
  unfold moebiusSigma mertensWeight fejerWeight moebSum1 moebSum2
  -- Each summand: -μ(k) * (1 - ln(k+1)/ln(N)) / (k+1)
  -- = -μ(k)/(k+1) + μ(k)*ln(k+1)/((k+1)*ln(N))
  -- Split: Σ (a+b) = Σ a + Σ b, then collect
  have h_eq : ∀ k : Fin N,
      -μ ↑↑k * (1 - Real.log (↑↑k + 1) / Real.log ↑N) / (↑↑k + 1) =
      -(μ ↑↑k / (↑↑k + 1)) +
      μ ↑↑k * Real.log (↑↑k + 1) / (↑↑k + 1) / Real.log ↑N := by
    intro k; ring
  simp_rw [h_eq, Finset.sum_add_distrib, Finset.sum_neg_distrib, Finset.sum_div]

-- ════════════════════════════════════════════════════════
-- §3. ABEL BOUNDS (scalar, no Fin indexing)
-- ════════════════════════════════════════════════════════

/-- **THEOREM**: AbelHammer ≤ C²σ²/4 (from the perfect square). -/
theorem abel_le_sigma_sq (c s sig : ℝ) :
    -(s - c * sig / 2) ^ 2 + c ^ 2 * sig ^ 2 / 4 ≤
    c ^ 2 * sig ^ 2 / 4 := by
  linarith [sq_nonneg (s - c * sig / 2)]

/-- **THEOREM**: AbelHammer is nonneg iff C²σ²/4 ≥ (S - Cσ/2)².

    Since σ → 0 (PNT), eventually AbelHammer becomes negative
    (dominated by -S²). This is the mechanism of collapse. -/
theorem abel_sign (c s sig : ℝ) :
    -(s - c * sig / 2) ^ 2 + c ^ 2 * sig ^ 2 / 4 =
    c * sig * s - s ^ 2 := by
  ring

-- ════════════════════════════════════════════════════════
-- §4. CROWN REDUCTION (the Iridium Bypass)
-- ════════════════════════════════════════════════════════

/-- **THEOREM**: If |CotRes| ≤ vtgv/2 and vtgv = abel + logCorr - cotRes,
    then vtgv ≤ 2·(abel + logCorr).

    This is the ratio bound approach: instead of bounding CotRes
    directly, bound it as a fraction of vᵀGv. -/
theorem crown_from_ratio_bound (abel logCorr cotRes vtgv : ℝ)
    (h_master : vtgv = abel + logCorr - cotRes)
    (h_ratio : |cotRes| ≤ vtgv / 2) :
    vtgv ≤ 2 * (abel + logCorr) := by
  rw [abs_le] at h_ratio
  linarith [h_ratio.1, h_ratio.2]

/-- **THEOREM**: The Crown from bounded algebraic terms.

    If Abel + LogCorr < 1/2 and |CotRes| ≤ vᵀGv/2, then vᵀGv < 1.

    From the probe data at N=55440:
      Abel + LogCorr = 0.1617 < 0.5 ✓
      |CotRes|/vᵀGv = 0.308 < 0.5 ✓
    So vᵀGv ≤ 2·0.1617 = 0.3234 < 1 ✓ -/
theorem crown_from_algebraic_bound (abel logCorr cotRes vtgv : ℝ)
    (h_master : vtgv = abel + logCorr - cotRes)
    (h_ratio : |cotRes| ≤ vtgv / 2)
    (h_alg : abel + logCorr < 1 / 2) :
    vtgv < 1 := by
  have h := crown_from_ratio_bound abel logCorr cotRes vtgv h_master h_ratio
  linarith

end Cathedral.MertensBridge

-- ════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════
/-
### Definitions (4):
- `moebSum1` — A₁ = Σ μ(k)/(k+1)
- `moebSum2` — A₂ = Σ μ(k)·ln(k+1)/(k+1)
- `moebSumSq1` — B₁ = Σ μ(k)/(k+1)²
- `moebSumSq2` — B₂ = Σ μ(k)·ln(k+1)/(k+1)²

### Theorems (5):
- `sigma_decomp` — σ = -A₁ + A₂/ln(N)
- `abel_le_sigma_sq` — Abel ≤ C²σ²/4
- `abel_sign` — Abel = CσS - S²
- `crown_from_ratio_bound` — ratio bound → vtgv bounded
- `crown_from_algebraic_bound` — Abel+LogCorr < 1/2 + ratio → Crown

### Sorry count: 0 target
-/
